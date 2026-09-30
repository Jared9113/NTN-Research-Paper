clc; clear;
sim_time = 60; dt = 0.1; N_steps = round(sim_time/dt); N_UE = 10;
PL_threshold = 195;
tic;
stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
    2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
    1e-3, round(dt/1e-3), 1/20, 1/450, 2, PL_threshold);
fprintf('Small FRS run (N_steps=%d, N_UE=%d): %.2f s\n', N_steps, N_UE, toc);
