clc; clear;
traffic_rates = [1/60, 1/2]; % lowest and highest only
N_UE = 50;
Nslots_per_step = 120;
PL_threshold = 195;

for k=1:numel(traffic_rates)
    tic;
    stats = simulate_FRS_run(600, 0.1, 6000, N_UE, 100e3, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, traffic_rates(k), 1/300, 2, PL_threshold);
    fprintf('FRS  rate=%.4f: %.2fs, util=%.4f, success=%.4f\n', traffic_rates(k), toc, stats.slot_utilization, stats.success_rate);

    DAARS_params.DNrep_1 = 1;
    DAARS_params.DNrep_2 = 2;
    DAARS_params.DNrep_3 = 3;
    DAARS_params.DNrep_priority = 1;
    DAARS_params.Twindow_threshold = 30;
    DAARS_params.DNrep_window = 1;
    DAARS_params.Nrep_max = 5;
    tic;
    stats = simulate_DAARS_run(600, 0.1, 6000, N_UE, 100e3, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, traffic_rates(k), 1/300, DAARS_params, PL_threshold);
    fprintf('DAARS rate=%.4f: %.2fs, util=%.4f, success=%.4f\n', traffic_rates(k), toc, stats.slot_utilization, stats.success_rate);
end
