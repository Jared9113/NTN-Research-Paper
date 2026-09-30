function stats = simulate_HARQ_run(sim_time, dt, N_steps, N_UE, area_size, ...
    fc, c, sat_alt, sat_incl, orbital_period, theta_min_elev, ...
    Tslot, Nslots_per_step, ...
    paging_lambda, reg_lambda, PL_threshold, PERmodel, UE_pos_in)
% HARQ-based retransmission baseline, adapted from Prasad et al.
% ("Enhanced Hybrid Automatic Repeat Request Scheduling for
% Non-Terrestrial IoT Networks", IEEE OJ-COMS 2023): retransmits using
% standard HARQ timing rather than a fixed or Doppler-adaptive repetition
% COUNT - representative of current 3GPP NTN practice, per Reviewer 2's
% Weakness 4. Matches the paper's own baseline description exactly
% ("retransmits control messages using standard HARQ timing rather than
% a fixed or Doppler-adaptive repetition count"), which says nothing
% about combining gain.
%
% Each HARQ round is a SINGLE transmission (1 slot), unlike FRS/DAARS
% which send Nrep back-to-back copies per attempt. On failure, the
% message is simply retried at a later timestep (via the same
% retry-on-failure mechanism FRS/DAARS use) - each round's PER is
% recomputed fresh from that round's own Doppler/fading state, with NO
% combining gain carried over from prior failed rounds. (An earlier
% version of this file added a Chase-combining SNR bonus of
% 10*log10(round) dB per round; that has been removed - it wasn't part
% of the baseline as specified and made HARQ an apples-to-oranges
% comparison against FRS/DAARS, which get no such bonus either.)
% harq_round is still tracked, purely for reporting avg_reps (rounds
% needed per success) - it no longer feeds into the PER calculation.

if nargin < 17 || isempty(PERmodel)
    PERmodel = struct('SNR0_dB', 8, 'delta_f_SCS', 15e3, 'L_bits', 100);
end
if ~isfield(PERmodel, 'K_dB')
    PERmodel.K_dB = 7;
end

Re = 6371e3;
nadir_ref = [0, 0, Re];

if nargin < 18 || isempty(UE_pos_in)
    UE_pos = generate_UE_positions(N_UE, area_size);
else
    UE_pos = UE_pos_in;
end
[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period);
[msg_queue, orig_times] = generate_control_requests(N_UE, N_steps, dt, paging_lambda, reg_lambda);

msg_status = zeros(size(msg_queue,1),1);
msg_done_time = NaN(size(msg_queue,1),1);
harq_round = ones(size(msg_queue,1),1); % which HARQ round this message is on

slots_used = 0;
total_success = 0;
total_delay = 0;
total_rounds = 0; % rounds consumed by winning messages only

for t = 1:N_steps
    curr_time = (t-1)*dt;
    vis = false(N_UE,1);
    for u = 1:N_UE
        vis(u) = is_UE_visible(UE_pos(u,:), sat_pos(t,:), theta_min_elev);
    end

    pending = [];
    for i = 1:size(msg_queue,1)
        if msg_status(i)==0 && vis(msg_queue(i,3)) && msg_queue(i,4) <= curr_time
            pending = [pending; i, msg_queue(i,:)];
        end
    end
    if isempty(pending), continue; end

    [~, sort_idx] = sortrows([pending(:,6), pending(:,5)], [-1 1]);
    pending = pending(sort_idx,:);

    slots_avail = Nslots_per_step;
    for p = 1:size(pending,1)
        if slots_avail < 1, break; end
        idx = pending(p,1);
        ue = pending(p,4);

        d = compute_distance(sat_pos(t,:), UE_pos(ue,:));
        PL = compute_path_loss(d, fc, c);
        if PL > PL_threshold, continue; end

        v_rel = sat_vel(t,:);
        r_rel = sat_pos(t,:) - UE_pos(ue,:);
        fD = calculate_doppler(fc, c, v_rel, r_rel);
        r_rel_nom = sat_pos(t,:) - nadir_ref;
        fD_nom = calculate_doppler(fc, c, v_rel, r_rel_nom);
        fD_residual = fD - fD_nom;

        fading_dB = rician_fading_dB(PERmodel.K_dB);
        PER = per_from_doppler(fD_residual, PERmodel.SNR0_dB + fading_dB, ...
            PERmodel.delta_f_SCS, PERmodel.L_bits);

        success = rand < (1 - PER); % single transmission per round, not PER^Nrep
        slots_used = slots_used + 1;

        if success
            msg_status(idx) = 1;
            msg_done_time(idx) = curr_time;
            total_success = total_success + 1;
            total_delay = total_delay + (curr_time - orig_times(idx));
            total_rounds = total_rounds + harq_round(idx);
        else
            harq_round(idx) = harq_round(idx) + 1; % next attempt combines one more round
        end
        slots_avail = slots_avail - 1;
    end
end

msg_status(msg_status == 0) = -1;
total_slots_available = N_steps * Nslots_per_step;
Ntot = size(msg_queue,1);
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
        stats.avg_reps = total_rounds / total_success; % HARQ rounds needed, winners only
    end
end
stats.slot_utilization = slots_used / max(1, total_slots_available);
stats.msg_status = msg_status;
stats.msg_queue = msg_queue;
stats.UE_pos = UE_pos;
end
