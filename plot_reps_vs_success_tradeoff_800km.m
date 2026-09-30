% plot_reps_vs_success_tradeoff_800km.m
% Same as plot_reps_vs_success_tradeoff.m but at an 800km x 800km service
% area, with PAIRED UE positions (same layout for FRS and DAARS on each
% MC draw) so the comparison isn't confounded by independent random
% draws - important here since success rates are far from saturated,
% so which specific UEs get generated matters a lot per draw.

clc; clear; close all
N_MC = 20; % reduced from 100 - each run costs ~7s here (vs ~1s at 100km)
           % due to much heavier retry activity from lower success rates
N_UE = 50;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 100;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 800e3;

FRS_reps = [2, 3];
success_FRS = zeros(1,2);

% Generate the UE_pos draws ONCE, reused across FRS Nrep values AND the
% DAARS Nrep_max sweep, so every configuration is compared on the exact
% same N_MC layouts.
UE_pos_draws = cell(N_MC,1);
for mc=1:N_MC
    UE_pos_draws{mc} = generate_UE_positions(N_UE, area_size);
end

for i=1:2
    Nrep = FRS_reps(i);
    success_FRS_mc = zeros(N_MC,1);
    for mc = 1:N_MC
        stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10, ...
            1e-3,Nslots_per_step,paging_lambda,reg_lambda,Nrep,PL_threshold,[],UE_pos_draws{mc});
        success_FRS_mc(mc) = stats.success_rate;
    end
    success_FRS(i) = mean(success_FRS_mc);
    fprintf('FRS Nrep=%d: success=%.4f\n', Nrep, success_FRS(i));
end

Nrep_vals = 2:8;
success_DAARS = zeros(size(Nrep_vals));
avg_reps_DAARS = zeros(size(Nrep_vals));

for k=1:length(Nrep_vals)
    Nrep_max = Nrep_vals(k);
    success_DAARS_mc = zeros(N_MC,1);
    avg_reps_DAARS_mc = zeros(N_MC,1);
    for mc = 1:N_MC
        DAARS_params.DNrep_1 = 1;
        DAARS_params.DNrep_2 = 2;
        DAARS_params.DNrep_3 = 3;
        DAARS_params.DNrep_priority = 1;
        DAARS_params.Twindow_threshold = 30;
        DAARS_params.DNrep_window = 1;
        DAARS_params.Nrep_max = Nrep_max;
        stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10, ...
            1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold,[],UE_pos_draws{mc});
        success_DAARS_mc(mc) = stats.success_rate;
        avg_reps_DAARS_mc(mc) = stats.avg_reps;
    end
    success_DAARS(k) = mean(success_DAARS_mc);
    avg_reps_DAARS(k) = mean(avg_reps_DAARS_mc, 'omitnan');
    fprintf('DAARS Nrep_max=%d: avg_reps=%.4f success=%.4f\n', Nrep_max, avg_reps_DAARS(k), success_DAARS(k));
end

figure;
plot(FRS_reps, success_FRS, 'ro', 'LineWidth',2, 'MarkerFaceColor','r','MarkerSize',10); hold on;
plot(avg_reps_DAARS, success_DAARS, 'ks-','LineWidth',2,'MarkerFaceColor','k','MarkerSize',8);
xlabel('Average Number of Repetitions');
ylabel('Paging Success Probability');
legend('FRS Nrep=2,3','DAARS','Location','SouthEast');
grid on;
title('800km x 800km service area');

xini = 2; yini = 2; xsize = 15; ysize = 9;
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');

print('DAARS_vs_FRS_Reps_vs_SuccessProbability_800km','-depsc2');
