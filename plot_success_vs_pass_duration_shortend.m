% plot_success_vs_pass_duration_shortend.m
% High-N_MC re-run of the short-pass end (60-180s) of the pass-duration
% sweep, to firm up significance of the DAARS vs FRS3 crossover seen at
% N_MC=20 in plot_success_vs_pass_duration.m.

clc; clear; close all
N_MC = 100;
N_UE = 50;
dt = 0.1;
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 100e3;

pass_durations = [60 90 120 150 180];
Np = numel(pass_durations);
succ_FRS2 = zeros(Np,1); succ_FRS3 = zeros(Np,1); succ_DAARS = zeros(Np,1);
std_FRS2 = zeros(Np,1); std_FRS3 = zeros(Np,1); std_DAARS = zeros(Np,1);

for pi = 1:Np
    sim_time = pass_durations(pi);
    N_steps = round(sim_time/dt);
    s2 = zeros(N_MC,1); s3 = zeros(N_MC,1); sD = zeros(N_MC,1);
    for mc = 1:N_MC
        UE_pos = generate_UE_positions(N_UE, area_size);
        stats2 = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
            paging_lambda,reg_lambda,2,PL_threshold,[],UE_pos);
        stats3 = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
            paging_lambda,reg_lambda,3,PL_threshold,[],UE_pos);
        DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
        DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
        DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;
        statsD = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
            paging_lambda,reg_lambda,DAARS_params,PL_threshold,[],UE_pos);
        s2(mc) = stats2.success_rate; s3(mc) = stats3.success_rate; sD(mc) = statsD.success_rate;
    end
    succ_FRS2(pi) = mean(s2); std_FRS2(pi) = std(s2);
    succ_FRS3(pi) = mean(s3); std_FRS3(pi) = std(s3);
    succ_DAARS(pi) = mean(sD); std_DAARS(pi) = std(sD);

    % Paired t-test (same UE_pos_draws per mc across schemes) - more
    % powerful than the unpaired comparison used to eyeball the N_MC=20 run.
    diff_D_vs_3 = sD - s3;
    t_D_vs_3 = mean(diff_D_vs_3) / (std(diff_D_vs_3)/sqrt(N_MC));
    diff_D_vs_2 = sD - s2;
    t_D_vs_2 = mean(diff_D_vs_2) / (std(diff_D_vs_2)/sqrt(N_MC));

    fprintf('RESULT pass=%ds FRS2=%.4f+-%.4f FRS3=%.4f+-%.4f DAARS=%.4f+-%.4f | paired_t(DAARSvsFRS3)=%.2f paired_t(DAARSvsFRS2)=%.2f\n', ...
        sim_time, succ_FRS2(pi), std_FRS2(pi), succ_FRS3(pi), std_FRS3(pi), succ_DAARS(pi), std_DAARS(pi), ...
        t_D_vs_3, t_D_vs_2);
end

save('pass_duration_shortend_results.mat','pass_durations','succ_FRS2','succ_FRS3','succ_DAARS','std_FRS2','std_FRS3','std_DAARS');
