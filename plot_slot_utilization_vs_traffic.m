% plot_slot_utilization_vs_traffic.m
% Slot utilization efficiency for varying control message traffic loads.
% Plots the actual simulated utilization directly - no post-hoc rescaling.

clc; clear; close all

traffic_rates = linspace(1/60,1/2,8);  % Paging rate per UE, 1/min to 30/min (0.5/sec)
N_MC = 8; % was 25 - reduced because Nslots_per_step=8 (down from 100)
          % makes the top traffic points ~100x slower per run (measured:
          % 76-134s/run at 30/min, vs <1s before) due to genuine
          % contention/retry load, not a bug - N_MC=25 here would take
          % hours
N_UE = 50;
Nslots_per_step = 8; % dt/Tslot (0.1s/1ms) physically allows up to 100
                        % slots per step; 8 models a realistic reserved
                        % control-plane fraction (~8%) rather than
                        % assuming the whole step is available
PL_threshold = 195; % matches plot_delay_CDF_avg.m

FRS_util = zeros(size(traffic_rates));
DAARS_util = zeros(size(traffic_rates));
FRS_succ = zeros(size(traffic_rates));
DAARS_succ = zeros(size(traffic_rates));
FRS_util_ci = zeros(size(traffic_rates));   % 95% CI half-width
DAARS_util_ci = zeros(size(traffic_rates));

ci95 = @(x) 1.96*std(x)/sqrt(numel(x));

for k=1:length(traffic_rates)
    util_FRS = zeros(N_MC,1); util_DAARS = zeros(N_MC,1);
    succ_FRS = zeros(N_MC,1); succ_DAARS = zeros(N_MC,1);
    for mc=1:N_MC
        stats = simulate_FRS_run(600, 0.1, 6000, N_UE, 100e3, ...
            2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
            1e-3, Nslots_per_step, traffic_rates(k), 1/300, 2, PL_threshold);
        util_FRS(mc) = stats.slot_utilization;
        succ_FRS(mc) = stats.success_rate;

        DAARS_params.DNrep_1 = 1;
        DAARS_params.DNrep_2 = 2;
        DAARS_params.DNrep_3 = 3;
        DAARS_params.DNrep_priority = 1;
        DAARS_params.Twindow_threshold = 30;
        DAARS_params.DNrep_window = 1;
        DAARS_params.Nrep_max = 5;
        stats = simulate_DAARS_run(600, 0.1, 6000, N_UE, 100e3, ...
            2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
            1e-3, Nslots_per_step, traffic_rates(k), 1/300, DAARS_params, PL_threshold);
        util_DAARS(mc) = stats.slot_utilization;
        succ_DAARS(mc) = stats.success_rate;
    end
    FRS_util(k) = mean(util_FRS);
    DAARS_util(k) = mean(util_DAARS);
    FRS_succ(k) = mean(succ_FRS);
    DAARS_succ(k) = mean(succ_DAARS);
    FRS_util_ci(k) = ci95(util_FRS);
    DAARS_util_ci(k) = ci95(util_DAARS);
    fprintf('rate=%.3f/min: FRS util=%.3f (+/-%.4f) succ=%.3f | DAARS util=%.3f (+/-%.4f) succ=%.3f\n', ...
        traffic_rates(k)*60, FRS_util(k), FRS_util_ci(k), FRS_succ(k), DAARS_util(k), DAARS_util_ci(k), DAARS_succ(k));
end

figure;
errorbar(traffic_rates*60, FRS_util*100, FRS_util_ci*100, 'r-o', 'LineWidth',2, 'MarkerFaceColor','r'); hold on;
errorbar(traffic_rates*60, DAARS_util*100, DAARS_util_ci*100, 'k-s', 'LineWidth',2, 'MarkerFaceColor','k');
xlabel('Mean Paging Arrival Rate (per UE per minute)');
ylabel('Slot Utilization (%)');
legend('FRS','DAARS','Location','NorthWest');
grid on;
ylim([0 100]);

% Set figure size and font
xini = 2; yini = 2; xsize = 15; ysize = 9; % Example size in centimeters
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');

% Save as .eps (Encapsulated PostScript)
print('Slot_Utilization_Efficiency_for_FRS_and_DAARS','-depsc2');
