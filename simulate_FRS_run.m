function stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, area_size, ...
    fc, c, sat_alt, sat_incl, orbital_period, theta_min_elev, ...
    Tslot, Nslots_per_step, ...
    paging_lambda, reg_lambda, Nrep_fixed, PL_threshold, PERmodel, UE_pos_in)
% Simulates a single run of the FRS baseline
% Calculates slot utilization: total slots used / total slots available
% DEBUG: Print Doppler and PER values for each transmission

if nargin < 18 || isempty(PERmodel)
    % Same default as simulate_DAARS_run.m (SNR0=8dB, matching Table I
    % exactly) - must match so FRS and DAARS are compared under the same
    % channel model. See the comment in simulate_DAARS_run.m for why
    % this changed from an earlier SNR0=2dB default.
    PERmodel = struct('SNR0_dB', 8, 'delta_f_SCS', 15e3, 'L_bits', 100);
end
if ~isfield(PERmodel, 'K_dB')
    % Same Rician K-factor default as simulate_DAARS_run.m - see the
    % comment there (3GPP TR 38.811 NTN-TDL-C/D, K=7dB per arXiv:2108.06172).
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
% Beam-center reference for per-beam Doppler pre-compensation - must
% match simulate_DAARS_run.m's nadir_ref for a fair comparison.
nadir_ref = [0, 0, Re];

% Optional pre-generated UE_pos (19th arg) lets a caller do a PAIRED
% comparison against simulate_DAARS_run.m (same UE layout for both), and
% lets a caller categorize UEs (e.g. center vs. edge) using the EXACT
% positions this run actually used, rather than a separate independent
% draw that has nothing to do with this run's msg_queue - see
% plot_paging_success_vs_UE_position.m for why this matters. If omitted,
% behavior is unchanged (generates its own, as before).
if nargin < 19 || isempty(UE_pos_in)
    UE_pos = generate_UE_positions(N_UE, area_size);
else
    UE_pos = UE_pos_in;
end
[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period);
[msg_queue, orig_times] = generate_control_requests(N_UE, N_steps, dt, paging_lambda, reg_lambda);

msg_status = zeros(size(msg_queue,1),1); % 0: pending, 1: success, -1: failed
msg_done_time = NaN(size(msg_queue,1),1);

slots_used = 0;
total_success = 0;
total_msgs = 0;
total_delay = 0;

% DEBUG counters
doppler_debug = [];      % raw Doppler (kHz) of each scheduled transmission
doppler_res_debug = [];  % residual Doppler (kHz) after pre-compensation
PER_debug = [];

for t = 1:N_steps
    curr_time = (t-1)*dt;
    vis = false(N_UE,1);
    for u = 1:N_UE
        vis(u) = is_UE_visible(UE_pos(u,:), sat_pos(t,:), theta_min_elev);
    end

    pending = [];
    for i = 1:size(msg_queue,1)
        if msg_status(i)==0 && vis(msg_queue(i,3)) && msg_queue(i,4) <= curr_time
            pending = [pending; i, msg_queue(i,:)]; % [msg_idx, msg_type, tidx, UE, torig, priority]
        end
    end
    if isempty(pending), continue; end

    % Sort by priority (descending), then generation time (ascending) -
    % matches Algorithm 1: "Slots are allocated based purely on message
    % priority and availability." Previously sorted by [torig, UE] with
    % priority never used at all.
    [~, sort_idx] = sortrows([pending(:,6), pending(:,5)], [-1 1]);
    pending = pending(sort_idx,:);

    slots_avail = Nslots_per_step;
    for p = 1:size(pending,1)
        if slots_avail < Nrep_fixed
            break; % No more slots
        end
        idx = pending(p,1);
        ue = pending(p,4);

        d = compute_distance(sat_pos(t,:), UE_pos(ue,:));
        PL = compute_path_loss(d, fc, c);
        if PL > PL_threshold
            continue; % Outage
        end

        v_rel = sat_vel(t,:);
        r_rel = sat_pos(t,:) - UE_pos(ue,:);
        fD = calculate_doppler(fc, c, v_rel, r_rel);

        r_rel_nom = sat_pos(t,:) - nadir_ref;
        fD_nom = calculate_doppler(fc, c, v_rel, r_rel_nom);
        fD_residual = fD - fD_nom;

        % Fading drawn fresh per attempt (shared across this attempt's
        % Nrep_fixed repetitions, independent across retries) - see the
        % matching comment in simulate_DAARS_run.m. NO combining gain
        % across retries: FRS's own design only combines WITHIN an
        % attempt (at least one of Nrep_fixed succeeds), never across
        % retries - a chase-combining bonus here was a stray addition
        % that didn't belong to this baseline's actual design.
        fading_dB = rician_fading_dB(PERmodel.K_dB);
        PER = per_from_doppler(fD_residual, PERmodel.SNR0_dB + fading_dB, ...
            PERmodel.delta_f_SCS, PERmodel.L_bits);
        PER = min(1, PER * PERmodel.PER_scale); % sensitivity-analysis hook, no-op at scale=1

        % DEBUG: Store Doppler and PER for each transmission
        doppler_debug(end+1) = abs(fD)/1e3;          % kHz, raw
        doppler_res_debug(end+1) = abs(fD_residual)/1e3; % kHz, residual
        PER_debug(end+1) = PER;

        % Monte Carlo: random trial for success
        success = rand < (1 - PER^Nrep_fixed);
        slots_used = slots_used + Nrep_fixed; % resource cost, includes failed retries

        if success
            msg_status(idx) = 1;
            msg_done_time(idx) = curr_time;
            total_success = total_success + 1;
            total_delay = total_delay + (curr_time - orig_times(idx));
        else
            % Single-attempt semantics, matching Eq. 19 and Algorithm 1
            % exactly: a message succeeds or fails on this one
            % Nrep_fixed-repetition attempt - no retry at a later
            % timestep. (Reverted from an earlier retry-on-failure
            % addition that let failures re-queue indefinitely across
            % the visibility window; that made success saturate near 1
            % for every scheme regardless of Nrep/adaptivity, which
            % contradicts Eq. 19 as written.)
            msg_status(idx) = -1;
        end
        slots_avail = slots_avail - Nrep_fixed;
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
else
    stats.success_rate = total_success / Ntot;
    stats.avg_delay = total_delay / max(1,total_success);
end
stats.slot_utilization = slots_used / max(1, total_slots_available); % Original definition: all slots used / all available
stats.avg_reps = Nrep_fixed; % constant by construction (every attempt -
                              % winning or not - uses the same fixed
                              % Nrep_fixed, so this needs no retry-aware
                              % recomputation like DAARS's does)
stats.msg_status = msg_status;
stats.msg_queue = msg_queue;
stats.msg_done_time = msg_done_time; % per-message completion time (NaN if not yet succeeded)
stats.orig_times = orig_times;       % per-message generation time - together with
                                      % msg_done_time and msg_status, lets a caller
                                      % build a true per-message delay CDF (Fig. 6),
                                      % not just this run's aggregate avg_delay.
stats.UE_pos = UE_pos; % the ACTUAL positions this run used, whether
                        % generated internally or passed in

% DEBUG PRINTS (no plotting)
fprintf('\n--- Doppler and PER statistics for this run (FRS) ---\n');
fprintf('Raw Doppler (kHz): min %.2f, max %.2f, mean %.2f, std %.2f\n', ...
    min(doppler_debug), max(doppler_debug), mean(doppler_debug), std(doppler_debug));
fprintf('Residual Doppler (kHz): min %.4f, max %.4f, mean %.4f, std %.4f\n', ...
    min(doppler_res_debug), max(doppler_res_debug), mean(doppler_res_debug), std(doppler_res_debug));
fprintf('PER: min %.2f, max %.2f, mean %.2f, std %.2f\n', ...
    min(PER_debug), max(PER_debug), mean(PER_debug), std(PER_debug));
end
