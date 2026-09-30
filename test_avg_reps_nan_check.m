clc; clear;
N_UE = 50;
DAARS_params.DNrep_1 = 1; DAARS_params.DNrep_2 = 2; DAARS_params.DNrep_3 = 3;
DAARS_params.DNrep_priority = 1; DAARS_params.Twindow_threshold = 30;
DAARS_params.DNrep_window = 1; DAARS_params.Nrep_max = 2; % tightest cap - worst case
for mc=1:10
    stats = simulate_DAARS_run(600,0.1,6000,N_UE,100e3, ...
        2e9,3e8,1200e3,87.9,108*60,10, ...
        1e-3,100,1/20,1/450,DAARS_params,195);
    fprintf('mc=%d success=%.4f avg_reps=%.4f isnan=%d\n', mc, stats.success_rate, stats.avg_reps, isnan(stats.avg_reps));
end
