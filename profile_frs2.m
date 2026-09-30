clc; clear;
PL_threshold = 195;

configs = {
    struct('sim_time',600,'dt',0.1,'N_UE',10),
    struct('sim_time',60,'dt',0.1,'N_UE',50),
    struct('sim_time',600,'dt',0.1,'N_UE',50)
};
for k=1:numel(configs)
    cfg = configs{k};
    N_steps = round(cfg.sim_time/cfg.dt);
    tic;
    stats = simulate_FRS_run(cfg.sim_time, cfg.dt, N_steps, cfg.N_UE, 100e3, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, round(cfg.dt/1e-3), 1/20, 1/450, 2, PL_threshold);
    el = toc;
    fprintf('N_steps=%d N_UE=%d: %.2f s (msgs=%d)\n', N_steps, cfg.N_UE, el, size(stats.msg_queue,1));
end
