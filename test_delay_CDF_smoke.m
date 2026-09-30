clc; clear;
N_MC = 3;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt); N_UE = 50;
PL_threshold = 195;

FRS_delay = []; DAARS_delay = [];
FRS_succ = []; DAARS_succ = [];
tic;
for mc=1:N_MC
    stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, round(dt/1e-3), 1/20, 1/450, 2, PL_threshold);
    if ~isnan(stats.avg_delay), FRS_delay = [FRS_delay; stats.avg_delay]; end
    FRS_succ = [FRS_succ; stats.success_rate];

    DAARS_params.DNrep_1 = 1;
    DAARS_params.DNrep_2 = 2;
    DAARS_params.DNrep_3 = 3;
    DAARS_params.DNrep_priority = 1;
    DAARS_params.Twindow_threshold = 30;
    DAARS_params.DNrep_window = 1;
    DAARS_params.Nrep_max = 5;
    stats = simulate_DAARS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, round(dt/1e-3), 1/20, 1/450, DAARS_params, PL_threshold);
    if ~isnan(stats.avg_delay), DAARS_delay = [DAARS_delay; stats.avg_delay]; end
    DAARS_succ = [DAARS_succ; stats.success_rate];
    fprintf('=== mc=%d done, elapsed=%.1fs ===\n', mc, toc);
end

fprintf('\nFRS avg_delay: '); disp(FRS_delay');
fprintf('DAARS avg_delay: '); disp(DAARS_delay');
fprintf('FRS success_rate: '); disp(FRS_succ');
fprintf('DAARS success_rate: '); disp(DAARS_succ');
