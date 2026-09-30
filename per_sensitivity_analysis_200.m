% per_sensitivity_analysis.m
% Sensitivity of DAARS/FRS results to the Doppler-to-PER mapping itself,
% per Exact_Paper_Edits.md Section 8.11: re-evaluate against the
% baseline Table I values, all values x0.5 (more favorable), and all
% values x1.5 (harsher, capped at 100%). Distinct from the Fig. 11
% ablation study, which varies DAARS's own components, not the channel
% model.

clc; clear; close all
N_MC = 200;
N_UE = 50;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 100e3;

UE_pos_draws = cell(N_MC,1);
for mc=1:N_MC
    UE_pos_draws{mc} = generate_UE_positions(N_UE, area_size);
end

scale_labels = {'x0.5 (favorable)', 'x1.0 (baseline)', 'x1.5 (harsher)'};
scale_values = [0.5, 1.0, 1.5];

results = struct();
for si = 1:numel(scale_values)
    PERmodel = struct('SNR0_dB', 8, 'delta_f_SCS', 15e3, 'L_bits', 100, ...
        'K_dB', 7, 'PER_scale', scale_values(si));

    succ_FRS = zeros(N_MC,1); delay_FRS = zeros(N_MC,1);
    succ_DAARS = zeros(N_MC,1); delay_DAARS = zeros(N_MC,1);
    for mc = 1:N_MC
        stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10, ...
            1e-3,Nslots_per_step,paging_lambda,reg_lambda,2,PL_threshold,PERmodel,UE_pos_draws{mc});
        succ_FRS(mc) = stats.success_rate; delay_FRS(mc) = stats.avg_delay;

        DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
        DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
        DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;
        stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10, ...
            1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold,PERmodel,UE_pos_draws{mc});
        succ_DAARS(mc) = stats.success_rate; delay_DAARS(mc) = stats.avg_delay;
    end

    results(si).label = scale_labels{si};
    results(si).succ_FRS_mean = mean(succ_FRS); results(si).succ_FRS_std = std(succ_FRS);
    results(si).delay_FRS_mean = mean(delay_FRS,'omitnan'); results(si).delay_FRS_std = std(delay_FRS,'omitnan');
    results(si).succ_DAARS_mean = mean(succ_DAARS); results(si).succ_DAARS_std = std(succ_DAARS);
    results(si).delay_DAARS_mean = mean(delay_DAARS,'omitnan'); results(si).delay_DAARS_std = std(delay_DAARS,'omitnan');

    fprintf('RESULT %-18s FRS   succ=%.4f+-%.4f delay=%.4f+-%.4f\n', scale_labels{si}, ...
        results(si).succ_FRS_mean, results(si).succ_FRS_std, results(si).delay_FRS_mean, results(si).delay_FRS_std);
    fprintf('RESULT %-18s DAARS succ=%.4f+-%.4f delay=%.4f+-%.4f\n', scale_labels{si}, ...
        results(si).succ_DAARS_mean, results(si).succ_DAARS_std, results(si).delay_DAARS_mean, results(si).delay_DAARS_std);
end

save('per_sensitivity_200_results.mat', 'results', 'scale_labels', 'scale_values');
