clc; clear;
N_UE = 50; sim_time=600; dt=0.1; N_steps=round(sim_time/dt);
Nslots_per_step = 8; PL_threshold=195;
rate_per_sec = 0.5; % highest point in the traffic sweep (30/min)

tic;
stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,100e3, ...
    2e9,3e8,1200e3,87.9,108*60,10, ...
    1e-3,Nslots_per_step,rate_per_sec,1/300,2,PL_threshold);
fprintf('FRS @ 30/min, Nslots=8: %.2fs util=%.4f succ=%.4f\n', toc, stats.slot_utilization, stats.success_rate);

DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;
tic;
stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,100e3, ...
    2e9,3e8,1200e3,87.9,108*60,10, ...
    1e-3,Nslots_per_step,rate_per_sec,1/300,DAARS_params,PL_threshold);
fprintf('DAARS @ 30/min, Nslots=8: %.2fs util=%.4f succ=%.4f\n', toc, stats.slot_utilization, stats.success_rate);
