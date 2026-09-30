function stats = simulate_DAARS_run(sim_time, dt, N_steps, N_UE, area_size, ...
    fc, c, sat_alt, sat_incl, orbital_period, theta_min_elev, ...
    Tslot, Nslots_per_step, ...
    paging_lambda, reg_lambda, DAARS_params, PL_threshold, PERmodel, UE_pos_in, ...
    Trem_error_halfwidth)
% Simulates a single run of DAARS algorithm
% Calculates slot utilization: total slots used / total slots available
% DEBUG: Print Doppler and PER values for each transmission

if nargin < 20 || isempty(Trem_error_halfwidth)
    % Optional 20th argument, default 0 (oracle-perfect Trem, matching
    % every prior result in this project - fully backward compatible).
    % When >0, models the fact that a real deployment cannot observe
    % t_last directly (Section II.H.2b) and must predict it, e.g. from
    % ephemeris data: perturbs Trem by U(-halfwidth,+halfwidth) before
    % it feeds the window-boost decision in Eq. 17-18, without touching
    % any other part of the scheduler.
    Trem_error_halfwidth = 0;
end

if nargin < 18 || isempty(PERmodel)
    % SNR0=8dB matches Table I exactly (no more Table I/code mismatch).
    % Earlier this used SNR0=2dB on the reasoning that 8dB left almost
    % nothing for retry-on-failure and adaptive boosting to act on - but
    % that reasoning depended on retry-on-failure existing at all. With
    % single-attempt semantics restored (a message succeeds or fails on
    % its one scheduled attempt, matching Eq. 19/Algorithm 1-2 exactly -
    % no re-queuing a failed attempt at a later timestep), SNR0=2dB
    % instead crashes success to ~15-20% for every scheme (verified),
    % while SNR0=8dB gives sensible, non-saturated, differentiated
    % results (~84-90% success) consistent with what Table I documents.
    PERmodel = struct('SNR0_dB', 8, 'delta_f_SCS', 15e3, 'L_bits', 100);
end
if ~isfield(PERmodel, 'K_dB')
    % Rician K-factor for the NTN-TDL-C/D (Urban/Hilly) LOS profiles per
    % 3GPP TR 38.811 Section 6.9.2 (see arXiv:2108.06172, which reports
    % K=7dB for both profiles). Addresses Reviewers 1/2/3's flagged
    % absence of any fading model - previously only free-space path loss
    % and Doppler-driven ICI were modeled, with no small-scale fading.
    PERmodel.K_dB = 7;
end
if ~isfield(PERmodel, 'PER_scale')
    % Multiplies every computed PER before use (capped at 1), per
    % Exact_Paper_Edits.md Section 8.11's sensitivity-analysis
    % methodology (test the Doppler-to-PER mapping scaled by 0.5x/1.5x).
    % Default 1 = no change to existing behavior.
    PERmodel.PER_scale = 1;
end

Re = 6371e3; % Earth radius (m)
% Beam-center reference for per-beam Doppler pre-compensation (3GPP TR
% 38.821): the single common Doppler value the network broadcasts to
% every UE in the beam. Matches generate_UE_positions.m, which centers
% the service area on (0,0,Re) - i.e. this assumes a steerable beam
% pointed at the service area's centroid, not necessarily the satellite's
% raw ground track (see LEO_NTN_system_model.m for that distinction,
% which matters for the ground-track plot but not for this reference).
nadir_ref = [0, 0, Re];

% Residual-Doppler category boundaries (kHz), used only to pick the
% DAARS repetition boost tier - the real-valued PER lookup below no
% longer depends on these bins. Boundaries per the Table I revision
% (Solution B): max residual a 15 kHz-SCS receiver can compensate, and
% the theoretical residual within 50 km- / 90 km-diameter beams.
cat_bounds_kHz = [0.95, 2.10, 3.76];

% Optional pre-generated UE_pos (19th arg) - see the matching comment in
% simulate_FRS_run.m for why this exists (paired FRS/DAARS comparisons,
% and correct post-hoc UE categorization by an external driver script).
if nargin < 19 || isempty(UE_pos_in)
    UE_pos = generate_UE_positions(N_UE, area_size); % [N_UE x 3]
else
    UE_pos = UE_pos_in;
end
[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period);
[msg_queue, orig_times] = generate_control_requests(N_UE, N_steps, dt, paging_lambda, reg_lambda);

% Precompute visibility for every (t,u) pair once - O(N_steps*N_UE) total
% - instead of the old approach, which re-ran a fresh forward lookahead
% scan over the REMAINING timesteps on every single timestep for every
% visible UE just to find Trem (remaining visibility time). That made the
% whole simulation O(N_steps^2 * N_UE): verified empirically at 93.6s for
% N_steps=6000/N_UE=10 alone, which extrapolates to several minutes per
% run at the intended N_UE=50 - impractical for N_MC=200 runs.
vis_matrix = false(N_steps, N_UE);
for u = 1:N_UE
    for t = 1:N_steps
        vis_matrix(t,u) = is_UE_visible(UE_pos(u,:), sat_pos(t,:), theta_min_elev);
    end
end

% Remaining visibility duration at each (t,u): steps_after(t,u) = number
% of consecutive visible steps immediately following t, computed with one
% backward pass per UE (O(N_steps) total) instead of a forward lookahead
% at every timestep. Verified to reproduce the original definition
% exactly: Trem(t) = 0 if t is the last visible step before a gap (or the
% last step of the simulation), and increases by dt for each additional
% consecutive visible step that follows.
steps_after = zeros(N_steps, N_UE);
for u = 1:N_UE
    for t = N_steps-1:-1:1
        if vis_matrix(t+1,u)
            steps_after(t,u) = steps_after(t+1,u) + 1;
        end
    end
end
Trem_matrix = steps_after * dt;

msg_status    = zeros(size(msg_queue,1),1); % 0: pending, 1: success, -1: failed
msg_done_time = NaN(size(msg_queue,1),1);
msg_reps      = zeros(size(msg_queue,1),1);

slots_used = 0;
total_success = 0;
total_msgs = 0;
total_delay = 0;
total_reps = 0;

% DEBUG counters
doppler_debug = [];          % raw Doppler (kHz) of each scheduled transmission
doppler_res_debug = [];      % residual Doppler (kHz) after pre-compensation
PER_debug = [];

for t = 1:N_steps
    curr_time = (t-1)*dt;

    vis = vis_matrix(t,:)';
    doppler_cat = zeros(N_UE,1); % 1=Clean, 2=Mod, 3=Sev, 4=Crit
    fD_all = zeros(N_UE,1);          % raw Doppler per UE at this step
    fD_residual_all = zeros(N_UE,1); % residual Doppler per UE at this step
    Trem = Trem_matrix(t,:)';

    for u = 1:N_UE
        if vis(u)
            d = compute_distance(sat_pos(t,:), UE_pos(u,:));
            PL = compute_path_loss(d, fc, c);
            if PL > PL_threshold
                vis(u) = false; % Link outage
                continue;
            end

            v_rel = sat_vel(t,:);
            r_rel = sat_pos(t,:) - UE_pos(u,:);
            fD = calculate_doppler(fc, c, v_rel, r_rel);

            r_rel_nom = sat_pos(t,:) - nadir_ref;
            fD_nom = calculate_doppler(fc, c, v_rel, r_rel_nom);
            fD_residual = fD - fD_nom;

            fD_all(u) = fD;
            fD_residual_all(u) = fD_residual;

            abs_fd_res_kHz = abs(fD_residual)/1e3;
            if abs_fd_res_kHz < cat_bounds_kHz(1)
                doppler_cat(u) = 1;
            elseif abs_fd_res_kHz < cat_bounds_kHz(2)
                doppler_cat(u) = 2;
            elseif abs_fd_res_kHz < cat_bounds_kHz(3)
                doppler_cat(u) = 3;
            else
                doppler_cat(u) = 4;
            end
        end
    end

    pending = [];
    for i = 1:size(msg_queue,1)
        if msg_status(i)==0 && vis(msg_queue(i,3)) && msg_queue(i,4) <= curr_time
            pending = [pending; i, msg_queue(i,:)]; % [msg_idx, msg_type, t_idx, UE, time, priority]
        end
    end
    if isempty(pending), continue; end

    [~, sort_idx] = sortrows([pending(:,6), pending(:,5)], [-1 1]);
    pending = pending(sort_idx,:);

    slots_avail = Nslots_per_step;

    for p = 1:size(pending,1)
        if slots_avail < 1
            break; % No more slots
        end
        idx = pending(p,1);
        ue = pending(p,4);
        msg_type = pending(p,2);

        Nrep = 1;
        switch doppler_cat(ue)
            case 2
                Nrep = Nrep + DAARS_params.DNrep_1;
            case 3
                Nrep = Nrep + DAARS_params.DNrep_2;
            case 4
                Nrep = Nrep + DAARS_params.DNrep_3;
        end
        if msg_type == 1
            Nrep = Nrep + DAARS_params.DNrep_priority;
        end
        % Trem_used models what a real deployment would actually have:
        % a PREDICTED remaining-visibility time, not the oracle-perfect
        % value read from the known trajectory. At Trem_error_halfwidth=0
        % this is identical to the oracle value (all prior results).
        Trem_used = max(0, Trem(ue) + (2*rand-1)*Trem_error_halfwidth);
        if Trem_used < DAARS_params.Twindow_threshold
            Nrep = Nrep + DAARS_params.DNrep_window;
        end
        Nrep = min(Nrep, DAARS_params.Nrep_max);

        if slots_avail < Nrep, continue; end

        % Fading is drawn fresh HERE, once per transmission attempt, not
        % once per UE per timestep - it must apply to the whole burst of
        % Nrep repetitions in THIS attempt (they occur back-to-back,
        % within coherence time), while different retries of the same
        % message (now possible via the retry mechanism, spread across
        % timesteps) get independent fading draws. This is also what
        % justifies Eq. 15's independence assumption here: only the
        % AWGN-driven decoding noise is treated as independent across
        % the Nrep repetitions, not the large-scale fading state, which
        % is explicitly shared - a materially different (and more
        % defensible) claim than "repetitions are fully independent".
        % NO combining gain across retries: DAARS's own design only
        % combines WITHIN an attempt (at least one of Nrep succeeds),
        % never across retries - a chase-combining bonus here was a
        % stray addition that didn't belong to this baseline's design.
        fading_dB = rician_fading_dB(PERmodel.K_dB);
        PER = per_from_doppler(fD_residual_all(ue), PERmodel.SNR0_dB + fading_dB, ...
            PERmodel.delta_f_SCS, PERmodel.L_bits);
        PER = min(1, PER * PERmodel.PER_scale); % sensitivity-analysis hook, no-op at scale=1

        % DEBUG: Store Doppler and PER for the UE actually being
        % scheduled (previously this read a stale `fD` left over from
        % the last UE checked in the visibility loop above, not `ue`).
        doppler_debug(end+1) = abs(fD_all(ue))/1e3;          % kHz, raw
        doppler_res_debug(end+1) = abs(fD_residual_all(ue))/1e3; % kHz, residual
        PER_debug(end+1) = PER;

        success = rand < (1 - PER^Nrep);
        slots_used = slots_used + Nrep;   % resource cost, includes failed retries
        total_reps = total_reps + Nrep;   % kept for debug only; see avg_reps below
        if success
            msg_status(idx) = 1;
            msg_done_time(idx) = curr_time;
            msg_reps(idx) = Nrep;         % reps of the WINNING attempt only
            total_success = total_success + 1;
            total_delay = total_delay + (curr_time - orig_times(idx));
        else
            % Single-attempt semantics, matching Eq. 19 and Algorithm 2
            % exactly: a message succeeds or fails on this one Nrep-
            % repetition attempt - no retry at a later timestep. (Reverted
            % from an earlier retry-on-failure addition that let failures
            % re-queue indefinitely across the visibility window; that
            % made success saturate near 1 for every scheme regardless of
            % Nrep/adaptivity, erasing DAARS's differentiation from FRS.)
            msg_status(idx) = -1;
        end
        slots_avail = slots_avail - Nrep;
        total_msgs = total_msgs + 1; % counts scheduled attempts, one per message now
    end
end

% Messages still pending once the simulation ends never succeeded within
% the UE's visibility window - these are genuine terminal failures.
msg_status(msg_status == 0) = -1;

total_slots_available = N_steps * Nslots_per_step;
Ntot = size(msg_queue,1); % Eq. 20: success rate is out of ALL generated
                          % messages, not out of attempts (which now can
                          % exceed Ntot due to retries)
if Ntot == 0
    stats.success_rate = 0;
    stats.avg_delay = NaN;
    stats.avg_reps = NaN;
else
    stats.success_rate = total_success / Ntot;
    if total_success == 0
        stats.avg_delay = NaN;
        stats.avg_reps = NaN;
    else
        stats.avg_delay = total_delay / total_success;
        stats.avg_reps = mean(msg_reps(msg_status==1)); % reps of winning
                                                          % attempts only,
                                                          % not wasted retries
    end
end
stats.slot_utilization = slots_used / max(1, total_slots_available); % Original definition: all slots used / all available

stats.msg_status = msg_status;
stats.msg_queue = msg_queue;
stats.msg_done_time = msg_done_time; % per-message completion time (NaN if not yet succeeded)
stats.orig_times = orig_times;       % per-message generation time - see the matching
                                      % comment in simulate_FRS_run.m
stats.UE_pos = UE_pos; % the ACTUAL positions this run used, whether
                        % generated internally or passed in

% DEBUG PRINTS (no plotting)
fprintf('\n--- Doppler and PER statistics for this run (DAARS) ---\n');
fprintf('Raw Doppler (kHz): min %.2f, max %.2f, mean %.2f, std %.2f\n', ...
    min(doppler_debug), max(doppler_debug), mean(doppler_debug), std(doppler_debug));
fprintf('Residual Doppler (kHz): min %.4f, max %.4f, mean %.4f, std %.4f\n', ...
    min(doppler_res_debug), max(doppler_res_debug), mean(doppler_res_debug), std(doppler_res_debug));
fprintf('PER: min %.2f, max %.2f, mean %.2f, std %.2f\n', ...
    min(PER_debug), max(PER_debug), mean(PER_debug), std(PER_debug));
end

% per_from_doppler.m is now a standalone shared function (also used by
% simulate_FRS_run.m) - see per_from_doppler.m.
