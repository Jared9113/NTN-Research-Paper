clc; clear;
N_MC = 25;
N_UE = 50;
Nslots_per_step = 100;
PL_threshold = 195;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);

% The two traffic points where DAARS underperformed FRS
high_traffic_rates = [25.857, 30.000] / 60; % back to per-second

Nrep_max_candidates = [2, 3, 4, 5];

% FRS reference (doesn't depend on Nrep_max) - compute once per traffic rate
FRS_util = zeros(size(high_traffic_rates));
FRS_succ = zeros(size(high_traffic_rates));
for r = 1:numel(high_traffic_rates)
    uu = zeros(N_MC,1); ss = zeros(N_MC,1);
    for mc = 1:N_MC
        stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
            2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
            1e-3, Nslots_per_step, high_traffic_rates(r), 1/300, 2, PL_threshold);
        uu(mc) = stats.slot_utilization; ss(mc) = stats.success_rate;
    end
    FRS_util(r) = mean(uu); FRS_succ(r) = mean(ss);
end

for r = 1:numel(high_traffic_rates)
    fprintf('\n=== Traffic rate = %.3f/min ===\n', high_traffic_rates(r)*60);
    fprintf('FRS:            util=%.4f succ=%.4f\n', FRS_util(r), FRS_succ(r));
    for nm = 1:numel(Nrep_max_candidates)
        Nrep_max = Nrep_max_candidates(nm);
        uu = zeros(N_MC,1); ss = zeros(N_MC,1);
        for mc = 1:N_MC
            DAARS_params.DNrep_1 = 1;
            DAARS_params.DNrep_2 = 2;
            DAARS_params.DNrep_3 = 3;
            DAARS_params.DNrep_priority = 1;
            DAARS_params.Twindow_threshold = 30;
            DAARS_params.DNrep_window = 1;
            DAARS_params.Nrep_max = Nrep_max;
            stats = simulate_DAARS_run(sim_time, dt, N_steps, N_UE, 100e3, ...
                2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
                1e-3, Nslots_per_step, high_traffic_rates(r), 1/300, DAARS_params, PL_threshold);
            uu(mc) = stats.slot_utilization; ss(mc) = stats.success_rate;
        end
        fprintf('DAARS Nrep_max=%d: util=%.4f succ=%.4f (vs FRS succ delta=%+.4f)\n', ...
            Nrep_max, mean(uu), mean(ss), mean(ss)-FRS_succ(r));
    end
end
