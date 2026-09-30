% plot_delay_CDF_avg.m
% CDF of registration delay for FRS and DAARS, via genuine Monte Carlo
% trials (simulate_FRS_run.m / simulate_DAARS_run.m - the "_avg" analytic
% variants are no longer used).

clc; clear; close all
N_MC = 200; % Monte Carlo runs (Table II)
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt); N_UE = 50;

% Single shared outage threshold - previously FRS used 180 and DAARS used
% 195, which silently gave DAARS an easier channel (higher threshold =
% more path loss tolerated before a link counts as outage) and biased
% the whole comparison in its favor. Both MUST use the same value.
PL_threshold = 195; % TODO: confirm this is the actually-intended value
Nslots_per_step = 8; % dt/Tslot physically allows up to 100 one-ms slots
                      % per 100ms step; 8 models a realistic reserved
                      % control-plane fraction (~8%). Was round(dt/1e-3)
                      % = 100 inline at each call site - named here so
                      % this stays in sync with the other scripts.

FRS_delay = []; DAARS_delay = [];
for mc=1:N_MC
    % FRS (Nrep=2)
    stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, 1/20, 1/450, 2, PL_threshold);
    if ~isnan(stats.avg_delay), FRS_delay = [FRS_delay; stats.avg_delay]; end

    % DAARS
    DAARS_params.DNrep_1 = 1;
    DAARS_params.DNrep_2 = 2;
    DAARS_params.DNrep_3 = 3;
    DAARS_params.DNrep_priority = 1;
    DAARS_params.Twindow_threshold = 30;
    DAARS_params.DNrep_window = 1;
    DAARS_params.Nrep_max = 5;
    stats = simulate_DAARS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, 1/20, 1/450, DAARS_params, PL_threshold);
    if ~isnan(stats.avg_delay), DAARS_delay = [DAARS_delay; stats.avg_delay]; end
end

% Plot CDF - DAARS first/black, FRS second/red, matching both the legend
% order and the color convention used elsewhere in the paper (previously
% FRS was plotted first in black and DAARS second in red, while the
% legend still read 'DAARS','FRS' - every curve was mislabeled)
figure;
[f,x] = ecdf(DAARS_delay); plot(x,f,'k','LineWidth',2); hold on;
[f,x] = ecdf(FRS_delay); plot(x,f,'r','LineWidth',2);
xlabel('Registration Delay (s)'); ylabel('CDF');
legend('DAARS','FRS','Location','SouthEast');
grid on;

% Set figure size and font
xini = 2; yini = 2; xsize = 15; ysize = 9; % Example size in centimeters
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');

% Save as .eps (Encapsulated PostScript)
print('CDF_of_Registration_Delay_FRS_vs_DAARS','-depsc2');
