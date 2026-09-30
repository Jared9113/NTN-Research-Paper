clc; clear;
N_MC = 5;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt); N_UE = 50;
PL_threshold = 195;

% [Nslots_per_step, paging_lambda, reg_lambda, label]
configs = {
    {1, 1/20, 1/450, 'slots=1, base load'},
    {1, 1/5,  1/60,  'slots=1, high load'},
    {2, 1/5,  1/60,  'slots=2, high load'},
};

for k=1:numel(configs)
    cfg = configs{k};
    Nslots_per_step = cfg{1}; paging_lambda = cfg{2}; reg_lambda = cfg{3};
    FRS_delay = []; DAARS_delay = [];
    FRS_succ = []; DAARS_succ = [];
    for mc=1:N_MC
        stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
            2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
            1e-3, Nslots_per_step, paging_lambda, reg_lambda, 2, PL_threshold);
        FRS_delay = [FRS_delay; stats.avg_delay];
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
            1e-3, Nslots_per_step, paging_lambda, reg_lambda, DAARS_params, PL_threshold);
        DAARS_delay = [DAARS_delay; stats.avg_delay];
        DAARS_succ = [DAARS_succ; stats.success_rate];
    end
    fprintf('\n=== %s ===\n', cfg{4});
    fprintf('FRS:   delay mean=%.4f std=%.4f | success mean=%.4f\n', mean(FRS_delay), std(FRS_delay), mean(FRS_succ));
    fprintf('DAARS: delay mean=%.4f std=%.4f | success mean=%.4f\n', mean(DAARS_delay), std(DAARS_delay), mean(DAARS_succ));
end
