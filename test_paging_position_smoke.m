clc; clear;
N_UE = 50; area_size = 100e3;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
PL_threshold = 195; Nslots_per_step = 100;
center_radius = 15e3; edge_band = [35e3, 50e3];
paging_lambda = 1/20; reg_lambda = 1/450;

DAARS_params.DNrep_1 = 1; DAARS_params.DNrep_2 = 2; DAARS_params.DNrep_3 = 3;
DAARS_params.DNrep_priority = 1; DAARS_params.Twindow_threshold = 30;
DAARS_params.DNrep_window = 1; DAARS_params.Nrep_max = 5;

n_center = zeros(5,1); n_edge = zeros(5,1);
for mc=1:5
    UE_pos = generate_UE_positions(N_UE, area_size);
    r = sqrt(sum(UE_pos(:,1:2).^2,2));
    center_idx = find(r < center_radius);
    edge_idx   = find(r >= edge_band(1) & r <= edge_band(2));
    n_center(mc) = numel(center_idx); n_edge(mc) = numel(edge_idx);

    tic;
    stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, area_size, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, paging_lambda, reg_lambda, 2, PL_threshold, [], UE_pos);
    fprintf('mc=%d FRS: %.2fs, n_center=%d n_edge=%d, succ=%.4f, UE_pos matches=%d\n', ...
        mc, toc, n_center(mc), n_edge(mc), stats.success_rate, isequal(stats.UE_pos, UE_pos));

    tic;
    stats_D = simulate_DAARS_run(sim_time, dt, N_steps, N_UE, area_size, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, paging_lambda, reg_lambda, DAARS_params, PL_threshold, [], UE_pos);
    fprintf('mc=%d DAARS: %.2fs, succ=%.4f, UE_pos matches=%d\n', ...
        mc, toc, stats_D.success_rate, isequal(stats_D.UE_pos, UE_pos));
end
fprintf('mean n_center=%.2f mean n_edge=%.2f\n', mean(n_center), mean(n_edge));
