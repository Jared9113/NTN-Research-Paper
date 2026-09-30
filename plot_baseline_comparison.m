% plot_baseline_comparison.m
% Comprehensive baseline comparison: FRS, DAARS, elevation/zone-based
% (Mandawaria 2022b-style), and HARQ-based retransmission (Prasad
% 2023-style), addressing all three reviewers' "only FRS is tested"
% criticism. Reports success rate and delay with 95% confidence
% intervals for each.

clc; clear; close all
N_MC = 100;
N_UE = 50;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;

names = {'FRS (Nrep=2)', 'Zone-based', 'HARQ', 'DAARS'};
succ = zeros(1,4); succ_ci = zeros(1,4);
delay = zeros(1,4); delay_ci = zeros(1,4);

ci95 = @(x) 1.96*std(x)/sqrt(numel(x));

% --- FRS ---
s = zeros(N_MC,1); d = zeros(N_MC,1);
for mc=1:N_MC
    stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,100e3, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,2,PL_threshold);
    s(mc)=stats.success_rate; d(mc)=stats.avg_delay;
end
succ(1)=mean(s); succ_ci(1)=ci95(s); delay(1)=mean(d,'omitnan'); delay_ci(1)=ci95(d(~isnan(d)));

% --- Zone-based ---
Zone_params.elev_bounds_deg = [30, 60];
Zone_params.Nrep_by_zone = [3, 2, 1];
s = zeros(N_MC,1); d = zeros(N_MC,1);
for mc=1:N_MC
    stats = simulate_ZoneBased_run(sim_time,dt,N_steps,N_UE,100e3, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,Zone_params,PL_threshold);
    s(mc)=stats.success_rate; d(mc)=stats.avg_delay;
end
succ(2)=mean(s); succ_ci(2)=ci95(s); delay(2)=mean(d,'omitnan'); delay_ci(2)=ci95(d(~isnan(d)));

% --- HARQ ---
s = zeros(N_MC,1); d = zeros(N_MC,1);
for mc=1:N_MC
    stats = simulate_HARQ_run(sim_time,dt,N_steps,N_UE,100e3, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,PL_threshold);
    s(mc)=stats.success_rate; d(mc)=stats.avg_delay;
end
succ(3)=mean(s); succ_ci(3)=ci95(s); delay(3)=mean(d,'omitnan'); delay_ci(3)=ci95(d(~isnan(d)));

% --- DAARS ---
DAARS_params.DNrep_1 = 1; DAARS_params.DNrep_2 = 2; DAARS_params.DNrep_3 = 3;
DAARS_params.DNrep_priority = 1; DAARS_params.Twindow_threshold = 30;
DAARS_params.DNrep_window = 1; DAARS_params.Nrep_max = 5;
s = zeros(N_MC,1); d = zeros(N_MC,1);
for mc=1:N_MC
    stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,100e3, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold);
    s(mc)=stats.success_rate; d(mc)=stats.avg_delay;
end
succ(4)=mean(s); succ_ci(4)=ci95(s); delay(4)=mean(d,'omitnan'); delay_ci(4)=ci95(d(~isnan(d)));

for i=1:4
    fprintf('%-16s success=%.4f (+/-%.4f)  delay=%.4f (+/-%.4f)\n', names{i}, succ(i), succ_ci(i), delay(i), delay_ci(i));
end

figure;
subplot(1,2,1);
bar(succ); hold on;
errorbar(1:4, succ, succ_ci, 'k.', 'LineWidth',1.5);
set(gca,'XTickLabel',names); xtickangle(20);
ylabel('Paging Success Probability'); grid on;
title('Success Probability (95% CI)');

subplot(1,2,2);
bar(delay); hold on;
errorbar(1:4, delay, delay_ci, 'k.', 'LineWidth',1.5);
set(gca,'XTickLabel',names); xtickangle(20);
ylabel('Average Delay (s)'); grid on;
title('Registration Delay (95% CI)');

set(gcf,'units','centimeters','position',[2,2,24,10]);
print(gcf,'DAARS_Baseline_Comparison','-depsc2');
