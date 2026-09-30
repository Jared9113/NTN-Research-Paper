clc; clear;
N_MC = 8;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt); N_UE = 50;
PL_threshold = 195;
Nslots_per_step = 100;

per_configs = {
    [2, 100],
    [1, 100],
    [0, 100],
    [2, 150],
};

for k=1:numel(per_configs)
    SNR0_dB = per_configs{k}(1); L_bits = per_configs{k}(2);
    FRS_delay = []; DAARS_delay = [];
    FRS_succ = []; DAARS_succ = [];
    for mc=1:N_MC
        PERmodel = struct('SNR0_dB', SNR0_dB, 'delta_f_SCS', 15e3, 'L_bits', L_bits);
        stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
            2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
            1e-3, Nslots_per_step, 1/20, 1/450, 2, PL_threshold, PERmodel);
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
            1e-3, Nslots_per_step, 1/20, 1/450, DAARS_params, PL_threshold, PERmodel);
        DAARS_delay = [DAARS_delay; stats.avg_delay];
        DAARS_succ = [DAARS_succ; stats.success_rate];
    end
    fprintf('\n=== SNR0=%d dB, L=%d bits ===\n', SNR0_dB, L_bits);
    fprintf('FRS:   delay mean=%.4f std=%.4f | success mean=%.4f\n', mean(FRS_delay), std(FRS_delay), mean(FRS_succ));
    fprintf('DAARS: delay mean=%.4f std=%.4f | success mean=%.4f\n', mean(DAARS_delay), std(DAARS_delay), mean(DAARS_succ));
    fprintf('Relative delay improvement: %.1f%%\n', 100*(mean(FRS_delay)-mean(DAARS_delay))/mean(FRS_delay));
end
