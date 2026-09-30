% experiment12_duration_sweep.m
% Combined Experiment 1 (full 865.2s pass, the paper's own Eq.6-bounded
% 10-deg-to-90-deg-to-10-deg visibility window) and Experiment 2
% (short-pass sweep across all 5 schemes, not just FRS2/FRS3/DAARS).
% The 865.2s duration point below IS Experiment 1 - no need to run it
% twice. Schemes: FRS Nrep=2, FRS Nrep=3, Zone-based, ThresholdBased,
% DAARS (HARQ excluded per the requested scheme set). N_MC=200 per
% (duration, scheme) cell, saved incrementally after every cell so a
% crash loses at most one cell, not the whole sweep.

clc; clear;
N_MC = 200;
N_UE = 50;
dt = 0.1;
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 100e3;

% 865.2s bounded by Eq. 6's theta_elev>=10deg criterion at these orbital
% parameters (1200km alt, 87.9deg incl): verified 865.19s full window.
durations = [30, 60, 120, 180, 300, 600, 865.2];
scheme_names = {'FRS Nrep=2','FRS Nrep=3','Zone-based','ThresholdBased','DAARS'};
ND = numel(durations); NS = numel(scheme_names);

succ_all = nan(ND,NS,N_MC); delay_all = nan(ND,NS,N_MC);
reps_all = nan(ND,NS,N_MC); util_all = nan(ND,NS,N_MC);

Zone_params.elev_bounds_deg = [20, 40];
Zone_params.Nrep_by_zone = [3, 2, 1];
DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;

if isfile('experiment12_progress.mat')
    load('experiment12_progress.mat');
    fprintf('Resuming from saved progress: di=%d si=%d\n', di_start, si_start);
else
    di_start = 1; si_start = 1;
end

for di = di_start:ND
    sim_time = durations(di);
    N_steps = round(sim_time/dt);
    for si = si_start:NS
        s = zeros(N_MC,1); d = zeros(N_MC,1); r = zeros(N_MC,1); u = zeros(N_MC,1);
        for mc = 1:N_MC
            UE_pos = generate_UE_positions(N_UE, area_size);
            switch si
                case 1
                    stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
                        2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
                        paging_lambda,reg_lambda,2,PL_threshold,[],UE_pos);
                case 2
                    stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
                        2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
                        paging_lambda,reg_lambda,3,PL_threshold,[],UE_pos);
                case 3
                    stats = simulate_ZoneBased_run(sim_time,dt,N_steps,N_UE,area_size, ...
                        2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
                        paging_lambda,reg_lambda,Zone_params,PL_threshold,[],UE_pos);
                case 4
                    stats = simulate_ThresholdBased_run(sim_time,dt,N_steps,N_UE,area_size, ...
                        2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
                        paging_lambda,reg_lambda,2,PL_threshold,[],UE_pos);
                case 5
                    stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
                        2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
                        paging_lambda,reg_lambda,DAARS_params,PL_threshold,[],UE_pos);
            end
            s(mc) = stats.success_rate; d(mc) = stats.avg_delay;
            r(mc) = stats.avg_reps; u(mc) = stats.slot_utilization;
        end
        succ_all(di,si,:) = s; delay_all(di,si,:) = d;
        reps_all(di,si,:) = r; util_all(di,si,:) = u;
        fprintf('RESULT dur=%.1fs %-16s succ=%.4f+-%.4f delay=%.4f+-%.4f reps=%.4f+-%.4f util=%.4f+-%.4f\n', ...
            sim_time, scheme_names{si}, mean(s), std(s), mean(d,'omitnan'), std(d,'omitnan'), ...
            mean(r,'omitnan'), std(r,'omitnan'), mean(u), std(u));

        si_start = si+1;
        save('experiment12_progress.mat','di_start','si_start','di','succ_all','delay_all','reps_all','util_all','durations','scheme_names');
    end
    si_start = 1;
    di_start = di+1;
    save('experiment12_progress.mat','di_start','si_start','di','succ_all','delay_all','reps_all','util_all','durations','scheme_names');
end

save('experiment12_duration_sweep_results.mat','succ_all','delay_all','reps_all','util_all','durations','scheme_names');
fprintf('\nALL DONE - saved experiment12_duration_sweep_results.mat\n');
