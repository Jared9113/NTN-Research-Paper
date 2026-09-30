% comprehensive_baseline_comparison.m
% Full baseline comparison: FRS{2,3}, Zone-based, HARQ-based,
% Threshold-based, DAARS. Reports mean +/- std per the requested results
% table. Chase-combining gain removed from ALL schemes (was incorrectly
% wired into FRS/DAARS too, not just HARQ - see chat history).

clc; clear; close all
N_MC = 200;
N_UE = 50;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 100e3;

UE_pos_draws = cell(N_MC,1);
for mc=1:N_MC
    UE_pos_draws{mc} = generate_UE_positions(N_UE, area_size);
end

names = {'FRS Nrep=2','FRS Nrep=3','Zone-based','HARQ-based','ThresholdBased','DAARS'};
N = numel(names);
succ_all = zeros(N_MC,N); delay_all = zeros(N_MC,N); reps_all = zeros(N_MC,N); util_all = zeros(N_MC,N);

Zone_params.elev_bounds_deg = [20, 40];
Zone_params.Nrep_by_zone = [3, 2, 1]; % low elevation -> high Nrep

for mc = 1:N_MC
    for ci = 1:2
        Nrep = ci+1; % 2, 3
        stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10, ...
            1e-3,Nslots_per_step,paging_lambda,reg_lambda,Nrep,PL_threshold,[],UE_pos_draws{mc});
        succ_all(mc,ci) = stats.success_rate; delay_all(mc,ci) = stats.avg_delay;
        reps_all(mc,ci) = stats.avg_reps; util_all(mc,ci) = stats.slot_utilization;
    end

    stats = simulate_ZoneBased_run(sim_time,dt,N_steps,N_UE,area_size, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,Zone_params,PL_threshold,[],UE_pos_draws{mc});
    succ_all(mc,3) = stats.success_rate; delay_all(mc,3) = stats.avg_delay;
    reps_all(mc,3) = stats.avg_reps; util_all(mc,3) = stats.slot_utilization;

    stats = simulate_HARQ_run(sim_time,dt,N_steps,N_UE,area_size, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,PL_threshold,[],UE_pos_draws{mc});
    succ_all(mc,4) = stats.success_rate; delay_all(mc,4) = stats.avg_delay;
    reps_all(mc,4) = stats.avg_reps; util_all(mc,4) = stats.slot_utilization;

    % Threshold-based: Nrep=2 (Doppler-Clean) else Nrep=3 (per Exact_
    % Paper_Edits.md 8.10: Nrep_fixed if clean, else Nrep_fixed+1)
    stats = simulate_ThresholdBased_run(sim_time,dt,N_steps,N_UE,area_size, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,2,PL_threshold,[],UE_pos_draws{mc});
    succ_all(mc,5) = stats.success_rate; delay_all(mc,5) = stats.avg_delay;
    reps_all(mc,5) = stats.avg_reps; util_all(mc,5) = stats.slot_utilization;

    DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
    DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
    DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;
    stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold,[],UE_pos_draws{mc});
    succ_all(mc,6) = stats.success_rate; delay_all(mc,6) = stats.avg_delay;
    reps_all(mc,6) = stats.avg_reps; util_all(mc,6) = stats.slot_utilization;

    fprintf('mc=%d/%d done\n', mc, N_MC);
end

fprintf('\n%-16s %18s %20s %16s %14s\n', 'Scheme', 'Success(mean+-std)', 'Delay,s(mean+-std)', 'Avg_Nrep', 'SlotUtil%%');
for c = 1:N
    s_mean = mean(succ_all(:,c)); s_std = std(succ_all(:,c));
    d_mean = mean(delay_all(:,c),'omitnan'); d_std = std(delay_all(:,c),'omitnan');
    r_mean = mean(reps_all(:,c),'omitnan'); r_std = std(reps_all(:,c),'omitnan');
    u_mean = mean(util_all(:,c))*100; u_std = std(util_all(:,c))*100;
    fprintf('RESULT %-16s %.4f+-%.4f  %.4f+-%.4f  %.4f+-%.4f  %.2f+-%.2f\n', ...
        names{c}, s_mean, s_std, d_mean, d_std, r_mean, r_std, u_mean, u_std);
    s_ci95 = 1.96*s_std/sqrt(N_MC); d_ci95 = 1.96*d_std/sqrt(N_MC);
    fprintf('RESULT95CI %-16s succ=%.4f+-%.4f(95%%CI) delay=%.4f+-%.4f(95%%CI)\n', ...
        names{c}, s_mean, s_ci95, d_mean, d_ci95);
end

save('comprehensive_baseline_results3.mat', 'succ_all', 'delay_all', 'reps_all', 'util_all', 'names');
