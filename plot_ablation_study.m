% plot_ablation_study.m
% Ablation study isolating DAARS's three repetition-boost components
% (Doppler, priority, visibility-window), addressing Reviewer 2's
% Weakness: "does not isolate the contribution of each component."
%
% Variants (each built by zeroing specific DAARS_params increments):
%   Doppler-only:            priority boost = 0, window boost = 0
%   Doppler + priority:      window boost = 0
%   Full DAARS:              all three active (as in every other figure)
% FRS (Nrep=2) included as the zero-adaptation reference point.

clc; clear; close all
N_MC = 100;
N_UE = 50;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;

variants = struct( ...
    'name', {'FRS (no adaptation)', 'Doppler-only', 'Doppler+Priority', 'Full DAARS'}, ...
    'DNrep_priority', {[], 1, 1, 1}, ...
    'DNrep_window',   {[], 0, 0, 1}, ...
    'is_FRS', {true, false, false, false});
% Doppler+priority variant disables ONLY the window boost (priority
% stays on) - i.e. each variant after Doppler-only adds exactly one more
% component, so the deltas between adjacent rows isolate that component.

results = struct('name',{},'success',{},'delay',{},'reps',{});

for v = 1:numel(variants)
    succ_mc = zeros(N_MC,1); delay_mc = zeros(N_MC,1); reps_mc = zeros(N_MC,1);
    for mc = 1:N_MC
        if variants(v).is_FRS
            stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,100e3, ...
                2e9,3e8,1200e3,87.9,108*60,10, ...
                1e-3,Nslots_per_step,paging_lambda,reg_lambda,2,PL_threshold);
        else
            DAARS_params.DNrep_1 = 1;
            DAARS_params.DNrep_2 = 2;
            DAARS_params.DNrep_3 = 3;
            DAARS_params.DNrep_priority = variants(v).DNrep_priority;
            DAARS_params.Twindow_threshold = 30;
            DAARS_params.DNrep_window = variants(v).DNrep_window;
            DAARS_params.Nrep_max = 5;
            stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,100e3, ...
                2e9,3e8,1200e3,87.9,108*60,10, ...
                1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold);
        end
        succ_mc(mc) = stats.success_rate;
        delay_mc(mc) = stats.avg_delay;
        reps_mc(mc) = stats.avg_reps;
    end
    results(v).name = variants(v).name;
    results(v).success = mean(succ_mc);
    results(v).success_ci = 1.96*std(succ_mc)/sqrt(N_MC); % 95% CI half-width
    results(v).delay = mean(delay_mc, 'omitnan');
    results(v).delay_ci = 1.96*std(delay_mc(~isnan(delay_mc)))/sqrt(sum(~isnan(delay_mc)));
    results(v).reps = mean(reps_mc, 'omitnan');
    fprintf('%-20s success=%.4f (+/-%.4f)  delay=%.4f (+/-%.4f)  reps=%.4f\n', ...
        results(v).name, results(v).success, results(v).success_ci, ...
        results(v).delay, results(v).delay_ci, results(v).reps);
end

figure;
subplot(1,2,1);
bar([results.success]); hold on;
errorbar(1:numel(results), [results.success], [results.success_ci], 'k.', 'LineWidth',1.5);
set(gca,'XTickLabel',{results.name}); xtickangle(30);
ylabel('Paging Success Probability'); grid on; ylim([0.83 0.88]); % was [0.99 1], stale from pre-correction data (~0.99 success);
% corrected single-attempt/SNR0=8dB results sit at ~0.857-0.862, which
% would have been entirely clipped off-screen at the old range
title('Ablation: Success Probability');

subplot(1,2,2);
bar([results.delay]); hold on;
errorbar(1:numel(results), [results.delay], [results.delay_ci], 'k.', 'LineWidth',1.5);
set(gca,'XTickLabel',{results.name}); xtickangle(30);
ylabel('Average Delay (s)'); grid on;
title('Ablation: Registration Delay');

set(gcf,'units','centimeters','position',[2,2,24,10]);
print(gcf,'DAARS_Ablation_Study','-depsc2');
