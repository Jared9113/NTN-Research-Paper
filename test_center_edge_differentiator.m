clc; clear;
N_MC = 25;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
PL_threshold = 195; Nslots_per_step = 100;
paging_lambda = 1/20; reg_lambda = 1/450;
Re = 6371e3;

N_center = 10; N_edge = 10; % fixed group sizes - removes sampling noise
                             % entirely, regardless of area_size

DAARS_params.DNrep_1 = 1; DAARS_params.DNrep_2 = 2; DAARS_params.DNrep_3 = 3;
DAARS_params.DNrep_priority = 1; DAARS_params.Twindow_threshold = 30;
DAARS_params.DNrep_window = 1; DAARS_params.Nrep_max = 5;

% area_size candidates (half-width x2); center/edge radii scaled to 10%/
% 35-50% of the half-width, same proportions as the 100km case
area_candidates = [100e3, 300e3, 500e3, 800e3];

for a = 1:numel(area_candidates)
    area_size = area_candidates(a);
    half_width = area_size/2;
    center_radius = 0.15*half_width;
    edge_band = [0.70*half_width, 1.00*half_width];

    center_succ_FRS = zeros(N_MC,1); edge_succ_FRS = zeros(N_MC,1);
    center_succ_DAARS = zeros(N_MC,1); edge_succ_DAARS = zeros(N_MC,1);

    for mc = 1:N_MC
        % Stratified UE_pos: N_center UEs uniformly in the center disk,
        % N_edge UEs uniformly (by area) in the edge annulus, rest
        % filling out N_UE=50 total uniformly over the whole square (so
        % the traffic/visibility/contention profile stays realistic).
        N_UE = 50;
        n_fill = N_UE - N_center - N_edge;

        theta_c = 2*pi*rand(N_center,1); rad_c = center_radius*sqrt(rand(N_center,1));
        xy_center = [rad_c.*cos(theta_c), rad_c.*sin(theta_c)];

        theta_e = 2*pi*rand(N_edge,1);
        rad_e = sqrt(edge_band(1)^2 + (edge_band(2)^2-edge_band(1)^2)*rand(N_edge,1));
        xy_edge = [rad_e.*cos(theta_e), rad_e.*sin(theta_e)];

        xy_fill = (rand(n_fill,2)-0.5)*area_size;

        xy_all = [xy_center; xy_edge; xy_fill];
        z_all = sqrt(Re^2 - sum(xy_all.^2,2));
        UE_pos = [xy_all, z_all];

        center_idx = (1:N_center)';
        edge_idx = (N_center+1:N_center+N_edge)';

        stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, area_size, ...
            2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
            1e-3, Nslots_per_step, paging_lambda, reg_lambda, 2, PL_threshold, [], UE_pos);
        cm = find(ismember(stats.msg_queue(:,3), center_idx));
        em = find(ismember(stats.msg_queue(:,3), edge_idx));
        center_succ_FRS(mc) = sum(stats.msg_status(cm)==1)/max(1,numel(cm));
        edge_succ_FRS(mc)   = sum(stats.msg_status(em)==1)/max(1,numel(em));

        stats_D = simulate_DAARS_run(sim_time, dt, N_steps, N_UE, area_size, ...
            2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
            1e-3, Nslots_per_step, paging_lambda, reg_lambda, DAARS_params, PL_threshold, [], UE_pos);
        cmD = find(ismember(stats_D.msg_queue(:,3), center_idx));
        emD = find(ismember(stats_D.msg_queue(:,3), edge_idx));
        center_succ_DAARS(mc) = sum(stats_D.msg_status(cmD)==1)/max(1,numel(cmD));
        edge_succ_DAARS(mc)   = sum(stats_D.msg_status(emD)==1)/max(1,numel(emD));
    end

    fprintf('\n=== area_size=%.0fkm (center<%.0fkm, edge %.0f-%.0fkm) ===\n', ...
        area_size/1e3, center_radius/1e3, edge_band(1)/1e3, edge_band(2)/1e3);
    fprintf('FRS:   center=%.4f edge=%.4f (gap=%.4f)\n', mean(center_succ_FRS), mean(edge_succ_FRS), mean(center_succ_FRS)-mean(edge_succ_FRS));
    fprintf('DAARS: center=%.4f edge=%.4f (gap=%.4f)\n', mean(center_succ_DAARS), mean(edge_succ_DAARS), mean(center_succ_DAARS)-mean(edge_succ_DAARS));
end
