% plot_Doppler_PER_mapping.m
% Smooth curve for the analytical Doppler-to-PER mapping (Section II.E,
% Eq. D-1--D-3), evaluated directly via per_from_doppler.m - the same
% function used by simulate_DAARS_run.m and simulate_FRS_run.m - so this
% figure always matches whatever the simulations actually use.
%
% NOTE: the x-axis is RESIDUAL Doppler shift (after per-beam
% pre-compensation), not raw Doppler shift. Raw Doppler for this system
% spans ~0-38 kHz (see LEO_NTN_system_model.m); residual Doppler is the
% much smaller sub-kHz-to-few-kHz quantity Table I is calibrated against.

clc; clear; close all

% Same default operating point as simulate_DAARS_run.m / simulate_FRS_run.m
SNR0_dB = 8;
delta_f_SCS = 15e3;
L_bits = 100;

fd_max_kHz = 6; % PER saturates to ~100% by here with the values above
fd_curve_kHz = linspace(0, fd_max_kHz, 300);
PER_curve = arrayfun(@(fd) per_from_doppler(fd*1e3, SNR0_dB, delta_f_SCS, L_bits), fd_curve_kHz);

figure;
plot(fd_curve_kHz, PER_curve*100, 'k-', 'LineWidth',2); % PER in percentage
xlabel('Residual Doppler Shift Magnitude |f_D| (kHz)');
ylabel('Packet Error Rate (PER, %)'); % y-axis is now in percent
grid on;
ylim([0 100]); % Range in percent

% Set figure size and font
xini = 2; yini = 2; xsize = 16; ysize = 9; % Example size in centimeters
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');

% Save as .eps (Encapsulated PostScript)
print('Doppler-to-PER_Mapping_for_Control_Messages','-depsc2');
