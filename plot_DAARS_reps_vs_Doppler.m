% plot_DAARS_reps_vs_Doppler.m
% Number of repetitions assigned by DAARS vs. RESIDUAL Doppler shift
% magnitude (after per-beam pre-compensation), compared to the fixed FRS
% baselines. This reflects only the Doppler-dependent term of Eq. 17
% (Nrep = 1 + DNdoppler + DNpriority + DNwindow); priority and
% visibility-window boosts are separate additive terms not shown here.

clc; clear; close all

% Doppler-dependent repetition tiers - must match simulate_DAARS_run.m's
% cat_bounds_kHz and DAARS_params (Table II: DNrep_1=1, DNrep_2=2, DNrep_3=3).
cat_bounds_kHz = [0.95, 2.10, 3.76];
DNrep_1 = 1; % Moderately Degraded boost
DNrep_2 = 2; % Severely Degraded boost
DNrep_3 = 3; % Critically Degraded boost

fd_max_kHz = 6; % same range as plot_Doppler_PER_mapping.m
fd_vals = linspace(0, fd_max_kHz, 2000); % Residual Doppler, kHz

DAARS_reps_curve = ones(size(fd_vals)); % base Nrep = 1 (Doppler-Clean)
DAARS_reps_curve(fd_vals >= cat_bounds_kHz(1)) = 1 + DNrep_1;
DAARS_reps_curve(fd_vals >= cat_bounds_kHz(2)) = 1 + DNrep_2;
DAARS_reps_curve(fd_vals >= cat_bounds_kHz(3)) = 1 + DNrep_3;

FRS2_reps = 2*ones(size(fd_vals));
FRS3_reps = 3*ones(size(fd_vals)); % was 4 - didn't match its own "Nrep=3" label

figure;
plot(fd_vals, FRS2_reps, 'r--', 'LineWidth',1.5); hold on;
plot(fd_vals, FRS3_reps, 'b--', 'LineWidth',1.5);
stairs(fd_vals, DAARS_reps_curve, 'k-', 'LineWidth',2); % step, not smoothed -
                                                          % the tiering is
                                                          % genuinely discrete
xlabel('Residual Doppler Shift Magnitude |f_D| (kHz)');
ylabel('Assigned Number of Repetitions');
legend('FRS Nrep=2','FRS Nrep=3','DAARS (Doppler term only)','Location','NorthWest');
grid on;
ylim([0 5]); % Nrep_max = 5 (Table II)

% Set figure size and font
xini = 2; yini = 2; xsize = 15; ysize = 9; % Example size in centimeters
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');

% Save as .eps (Encapsulated PostScript)
print('DAARS_vs_FRS_Reps_vs_Doppler1','-depsc2');
