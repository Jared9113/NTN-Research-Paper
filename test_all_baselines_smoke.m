clc; clear;
N_UE = 50; sim_time=600; dt=0.1; N_steps=round(sim_time/dt);
Nslots_per_step=100; PL_threshold=195; paging_lambda=1/20; reg_lambda=1/450;
area_size = 100e3;

for Nrep = 2:5
    tic;
    stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,Nslots_per_step,paging_lambda,reg_lambda,Nrep,PL_threshold);
    fprintf('FRS Nrep=%d: %.2fs succ=%.4f delay=%.4f\n', Nrep, toc, stats.success_rate, stats.avg_delay);
end

tic;
stats = simulate_ElevAware_run(sim_time,dt,N_steps,N_UE,area_size, ...
    2e9,3e8,1200e3,87.9,108*60,10, ...
    1e-3,Nslots_per_step,paging_lambda,reg_lambda,[20 40],[3 2 1],PL_threshold);
fprintf('ElevAware: %.2fs succ=%.4f delay=%.4f avg_reps=%.4f\n', toc, stats.success_rate, stats.avg_delay, stats.avg_reps);

tic;
stats = simulate_HARQ_run(sim_time,dt,N_steps,N_UE,area_size, ...
    2e9,3e8,1200e3,87.9,108*60,10, ...
    1e-3,Nslots_per_step,paging_lambda,reg_lambda,PL_threshold);
fprintf('HARQ: %.2fs succ=%.4f delay=%.4f avg_rounds=%.4f\n', toc, stats.success_rate, stats.avg_delay, stats.avg_reps);

DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;
tic;
stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
    2e9,3e8,1200e3,87.9,108*60,10, ...
    1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold);
fprintf('DAARS: %.2fs succ=%.4f delay=%.4f avg_reps=%.4f\n', toc, stats.success_rate, stats.avg_delay, stats.avg_reps);
