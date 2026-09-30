clc; clear;
N_MC = 200;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
PL_threshold = 195; Nslots_per_step = 100;
paging_lambda = 1/20; reg_lambda = 1/450;
Re = 6371e3;
N_UE = 50;
N_center = 10; N_edge = 10;

DAARS_params.DNrep_1 = 1; DAARS_params.DNrep_2 = 2; DAARS_params.DNrep_3 = 3;
DAARS_params.DNrep_priority = 1; DAARS_params.Twindow_threshold = 30;
DAARS_params.DNrep_window = 1; DAARS_params.Nrep_max = 5;

area_size = 800e3;
half_width = area_size/2;
center_radius = 0.15*half_width;
edge_band = [0.70*half_width, 1.00*half_width];

center_succ_FRS = zeros(N_MC,1); edge_succ_FRS = zeros(N_MC,1);
center_succ_DAARS = zeros(N_MC,1); edge_succ_DAARS = zeros(N_MC,1);

n_fill = N_UE - N_center - N_edge;
center_idx = (1:N_center)';
edge_idx = (N_center+1:N_center+N_edge)';

for mc = 1:N_MC
    theta_c = 2*pi*rand(N_center,1); rad_c = center_radius*sqrt(rand(N_center,1));
    xy_center = [rad_c.*cos(theta_c), rad_c.*sin(theta_c)];

    theta_e = 2*pi*rand(N_edge,1);
    rad_e = sqrt(edge_band(1)^2 + (edge_band(2)^2-edge_band(1)^2)*rand(N_edge,1));
    xy_edge = [rad_e.*cos(theta_e), rad_e.*sin(theta_e)];

    xy_fill = (rand(n_fill,2)-0.5)*area_size;

    xy_all = [xy_center; xy_edge; xy_fill];
    z_all = sqrt(Re^2 - sum(xy_all.^2,2));
    UE_pos = [xy_all, z_all];

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

    if mod(mc,20)==0
        fprintf('mc=%d/%d done\n', mc, N_MC);
    end
end

save('center_edge_800km_results.mat', 'center_succ_FRS','edge_succ_FRS','center_succ_DAARS','edge_succ_DAARS');

fprintf('\n=== FINAL: area_size=800km, N_MC=200 ===\n');
fprintf('FRS:   center mean=%.4f std=%.4f | edge mean=%.4f std=%.4f\n', ...
    mean(center_succ_FRS), std(center_succ_FRS), mean(edge_succ_FRS), std(edge_succ_FRS));
fprintf('DAARS: center mean=%.4f std=%.4f | edge mean=%.4f std=%.4f\n', ...
    mean(center_succ_DAARS), std(center_succ_DAARS), mean(edge_succ_DAARS), std(edge_succ_DAARS));

% Paired difference (same UE_pos per MC draw for FRS and DAARS)
d_center = center_succ_DAARS - center_succ_FRS;
d_edge = edge_succ_DAARS - edge_succ_FRS;
[~,p_center,~,tstat_c] = ttest(d_center);
[~,p_edge,~,tstat_e] = ttest(d_edge);
fprintf('\nPaired t-test DAARS-FRS, center: mean diff=%.4f, p=%.2e, t=%.2f\n', mean(d_center), p_center, tstat_c.tstat);
fprintf('Paired t-test DAARS-FRS, edge:   mean diff=%.4f, p=%.2e, t=%.2f\n', mean(d_edge), p_edge, tstat_e.tstat);

fprintf('\nFailure-rate reduction:\n');
fprintf('Center: FRS fail=%.4f DAARS fail=%.4f -> relative reduction=%.1f%%\n', ...
    1-mean(center_succ_FRS), 1-mean(center_succ_DAARS), 100*(1 - (1-mean(center_succ_DAARS))/(1-mean(center_succ_FRS))));
fprintf('Edge:   FRS fail=%.4f DAARS fail=%.4f -> relative reduction=%.1f%%\n', ...
    1-mean(edge_succ_FRS), 1-mean(edge_succ_DAARS), 100*(1 - (1-mean(edge_succ_DAARS))/(1-mean(edge_succ_FRS))));
