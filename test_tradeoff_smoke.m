clc; clear;
N_UE = 50; sim_time=600; dt=0.1; N_steps=round(sim_time/dt);
Nslots_per_step=100; PL_threshold=195; paging_lambda=1/20; reg_lambda=1/450;

tic;
stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,100e3, ...
    2e9,3e8,1200e3,87.9,108*60,10, ...
    1e-3,Nslots_per_step,paging_lambda,reg_lambda,2,PL_threshold);
fprintf('FRS Nrep=2: %.2fs succ=%.4f\n', toc, stats.success_rate);

DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=8;
tic;
stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,100e3, ...
    2e9,3e8,1200e3,87.9,108*60,10, ...
    1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold);
fprintf('DAARS Nrep_max=8: %.2fs succ=%.4f avg_reps=%.4f\n', toc, stats.success_rate, stats.avg_reps);
