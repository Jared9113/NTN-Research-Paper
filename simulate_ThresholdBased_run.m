function stats = simulate_ThresholdBased_run(sim_time, dt, N_steps, N_UE, area_size, ...
    fc, c, sat_alt, sat_incl, orbital_period, theta_min_elev, ...
    Tslot, Nslots_per_step, ...
    paging_lambda, reg_lambda, Nrep_fixed, PL_threshold, PERmodel, UE_pos_in)
% Threshold-based adaptive repetition baseline, per Exact_Paper_Edits.md
% Section 8.10: NOT a DAARS variant and NOT the same as the ablation
% study's "Doppler only" configuration (which still uses DAARS's full
% four-category tiering). This uses a single BINARY threshold:
%   Nrep = Nrep_fixed             if Doppler-Clean (residual < 0.95 kHz)
%   Nrep = Nrep_fixed + 1         otherwise
% No priority boost, no window boost, no four-way severity tiering.
% Isolates how much of DAARS's benefit comes from having ANY Doppler
% awareness at all, versus the additional granularity DAARS adds on top.

if nargin < 18 || isempty(PERmodel)
    PERmodel = struct('SNR0_dB', 8, 'delta_f_SCS', 15e3, 'L_bits', 100);
end
if ~isfield(PERmodel, 'K_dB')
    PERmodel.K_dB = 7;
end

Re = 6371e3;
nadir_ref = [0, 0, Re];
clean_threshold_kHz = 0.95; % same Doppler-Clean boundary DAARS uses

if nargin < 19 || isempty(UE_pos_in)
    UE_pos = generate_UE_positions(N_UE, area_size);
else
    UE_pos = UE_pos_in;
end
[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period);
[msg_queue, orig_times] = generate_control_requests(N_UE, N_steps, dt, paging_lambda, reg_lambda);

msg_status = zeros(size(msg_queue,1),1);
msg_done_time = NaN(size(msg_queue,1),1);
msg_reps = zeros(size(msg_queue,1),1);

slots_used = 0;
total_success = 0;
total_delay = 0;

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

    % Same priority-then-time scheduling order as FRS/DAARS/Zone-based, so
    % the comparison isolates the repetition RULE, not the queueing policy.
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

        if abs(fD_residual)/1e3 < clean_threshold_kHz
            Nrep = Nrep_fixed;
        else
            Nrep = Nrep_fixed + 1;
        end
        if slots_avail < Nrep, continue; end

        fading_dB = rician_fading_dB(PERmodel.K_dB);
        PER = per_from_doppler(fD_residual, PERmodel.SNR0_dB + fading_dB, ...
            PERmodel.delta_f_SCS, PERmodel.L_bits);

        success = rand < (1 - PER^Nrep);
        slots_used = slots_used + Nrep;
        if success
            msg_status(idx) = 1;
            msg_done_time(idx) = curr_time;
            msg_reps(idx) = Nrep;
            total_success = total_success + 1;
            total_delay = total_delay + (curr_time - orig_times(idx));
        else
            % Single-attempt semantics matching FRS/DAARS - no retry
            % across timesteps on a failed attempt.
            msg_status(idx) = -1;
        end
        slots_avail = slots_avail - Nrep;
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
        stats.avg_reps = mean(msg_reps(msg_status==1));
    end
end
stats.slot_utilization = slots_used / max(1, total_slots_available);
stats.msg_status = msg_status;
stats.msg_queue = msg_queue;
stats.UE_pos = UE_pos;
end
