clc; clear;
Re = 6371e3; hsat = 1200e3; rorbit = Re+hsat;
Torbit = 108*60; omega = 2*pi/Torbit;
theta_min = 10*pi/180;

% True visibility window: solve for gamma where elevation = theta_min
gammas = linspace(0, pi/2, 2000001);
h = rorbit*cos(gammas) - Re;
s = rorbit*sin(gammas);
elev = atan2(h, s);
idx = find(elev <= theta_min, 1, 'first');
gamma_boundary = gammas(idx);
t_half_true = gamma_boundary/omega;
fprintf('True 10-deg elevation boundary: gamma=%.5f rad, t_half=%.2f s, full window=%.2f s = %.3f min\n', ...
    gamma_boundary, t_half_true, 2*t_half_true, 2*t_half_true/60);

% Elevation at the edge of the SIMULATED 600s window (tmid at center, so
% edge is at 300s from CPA)
sim_time = 600; t_half_sim = sim_time/2;
gamma_sim = omega*t_half_sim;
h_sim = rorbit*cos(gamma_sim) - Re;
s_sim = rorbit*sin(gamma_sim);
elev_sim_edge = atan2(h_sim, s_sim)*180/pi;
fprintf('Elevation at the edge of the simulated %ds window: %.2f deg\n', sim_time, elev_sim_edge);
