% delay_cdf_200mc.m
% Proper re-check of Fig. 6 (registration delay CDF) at Table II's stated
% N_MC=200: pools ACTUAL per-message successful registration delays
% (msg_done_time - orig_times, for msg_type==2 & msg_status==1) across all
% 200 runs, not just each run's aggregate avg_delay. This is what a CDF
% plot actually needs.

clc; clear; close all
N_MC = 200;
N_UE = 50;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 100e3;

FRS_reg_delays = [];
DAARS_reg_delays = [];
succ_FRS = zeros(N_MC,1);
succ_DAARS = zeros(N_MC,1);

for mc = 1:N_MC
    UE_pos = generate_UE_positions(N_UE, area_size);

    statsF = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
        2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
        paging_lambda,reg_lambda,2,PL_threshold,[],UE_pos);
    succ_FRS(mc) = statsF.success_rate;
    mq = statsF.msg_queue; ms = statsF.msg_status;
    is_reg = mq(:,1)==2; is_succ = ms==1;
    sel = is_reg & is_succ;
    d = statsF.msg_done_time(sel) - statsF.orig_times(sel);
    FRS_reg_delays = [FRS_reg_delays; d]; %#ok<AGROW>

    DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
    DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
    DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;
    statsD = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
        2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
        paging_lambda,reg_lambda,DAARS_params,PL_threshold,[],UE_pos);
    succ_DAARS(mc) = statsD.success_rate;
    mq = statsD.msg_queue; ms = statsD.msg_status;
    is_reg = mq(:,1)==2; is_succ = ms==1;
    sel = is_reg & is_succ;
    d = statsD.msg_done_time(sel) - statsD.orig_times(sel);
    DAARS_reg_delays = [DAARS_reg_delays; d]; %#ok<AGROW>

    if mod(mc,25)==0, fprintf('mc=%d/%d done\n', mc, N_MC); end
end

fprintf('\nRESULT N_MC=200, pooled per-message REGISTRATION delays:\n');
fprintf('RESULT FRS   n=%d mean=%.5f std=%.5f min=%.5f max=%.5f median=%.5f p95=%.5f\n', ...
    numel(FRS_reg_delays), mean(FRS_reg_delays), std(FRS_reg_delays), ...
    min(FRS_reg_delays), max(FRS_reg_delays), median(FRS_reg_delays), prctile(FRS_reg_delays,95));
fprintf('RESULT DAARS n=%d mean=%.5f std=%.5f min=%.5f max=%.5f median=%.5f p95=%.5f\n', ...
    numel(DAARS_reg_delays), mean(DAARS_reg_delays), std(DAARS_reg_delays), ...
    min(DAARS_reg_delays), max(DAARS_reg_delays), median(DAARS_reg_delays), prctile(DAARS_reg_delays,95));

fprintf('RESULT FRS unique delay values (s): '); disp(unique(round(FRS_reg_delays,4))');
fprintf('RESULT DAARS unique delay values (s): '); disp(unique(round(DAARS_reg_delays,4))');

figure('Position',[100 100 700 500]);
[fF,xF] = ecdf(FRS_reg_delays);
[fD,xD] = ecdf(DAARS_reg_delays);
plot(xD,fD,'k-','LineWidth',2); hold on;
plot(xF,fF,'r-','LineWidth',2);
xlabel('Registration Delay (s)'); ylabel('CDF');
legend('DAARS','FRS','Location','southeast'); grid on;
title('Registration Delay CDF (N\_MC=200, single-attempt semantics)');
saveas(gcf,'delay_cdf_200mc.png');

save('delay_cdf_200mc_results.mat','FRS_reg_delays','DAARS_reg_delays','succ_FRS','succ_DAARS');
