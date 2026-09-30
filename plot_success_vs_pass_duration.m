% plot_success_vs_pass_duration.m
% Fig. 5's actual claim: DAARS's advantage concentrates in SHORT pass
% durations (window-boost mechanism), converging toward FRS Nrep=3 as
% pass duration grows. Never re-tested with corrected (single-attempt,
% SNR0=8dB) code - everything else in the corrected batch used the full
% 600s pass, where the window boost rarely fires (see ablation study).

clc; clear; close all
N_MC = 20;
N_UE = 50;
dt = 0.1;
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 100e3;

pass_durations = [60 120 180 240 300 360 420 480 540 600];
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
    fprintf('RESULT pass=%ds FRS2=%.4f+-%.4f FRS3=%.4f+-%.4f DAARS=%.4f+-%.4f\n', ...
        sim_time, succ_FRS2(pi), std_FRS2(pi), succ_FRS3(pi), std_FRS3(pi), succ_DAARS(pi), std_DAARS(pi));
end

figure('Position',[100 100 700 500]);
errorbar(pass_durations, succ_FRS2, std_FRS2, '--r','LineWidth',1.5); hold on
errorbar(pass_durations, succ_FRS3, std_FRS3, '--b','LineWidth',1.5);
errorbar(pass_durations, succ_DAARS, std_DAARS, '-k','LineWidth',2);
xlabel('Satellite Pass Duration (s)'); ylabel('Paging Success Probability');
legend('FRS N_{rep}=2','FRS N_{rep}=3','DAARS','Location','SouthEast');
grid on
save('pass_duration_results.mat','pass_durations','succ_FRS2','succ_FRS3','succ_DAARS','std_FRS2','std_FRS3','std_DAARS');
