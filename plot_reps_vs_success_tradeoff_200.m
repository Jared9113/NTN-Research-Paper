% plot_reps_vs_success_tradeoff.m
% Trade-off curve: avg repetitions vs paging success probability

clc; clear; close all
N_MC = 200;
N_UE = 50;
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 8; % dt/Tslot physically allows up to 100 one-ms slots
                        % per 100ms step; 8 models a realistic reserved
                        % control-plane fraction (~8%)
PL_threshold = 195; % was 185 - harmonized with every other script here
paging_lambda = 1/20; % was 1/60 - outside Table II's 10-30s range
reg_lambda = 1/450;   % was 1/600 - harmonized with every other script here

% FRS: Nrep=2..5 - extended from {2,3} per Reviewer 2's Weakness
% ("what is the optimal fixed Nrep... Nrep=4 or 5 might close the gap
% with DAARS"), so the trade-off curve can actually answer that question
% rather than leaving it untested.
FRS_reps = [2, 3, 4, 5];
success_FRS = zeros(1,numel(FRS_reps));

for i=1:numel(FRS_reps)
    Nrep = FRS_reps(i);
    success_FRS_mc = zeros(N_MC,1);
    for mc = 1:N_MC
        stats = simulate_FRS_run(sim_time,dt,N_steps,N_UE,100e3, ...
            2e9,3e8,1200e3,87.9,108*60,10, ...
            1e-3,Nslots_per_step,paging_lambda,reg_lambda,Nrep,PL_threshold);
        success_FRS_mc(mc) = stats.success_rate;
    end
    success_FRS(i) = mean(success_FRS_mc);
    fprintf('RESULT FRS Nrep=%d: success=%.4f\n', Nrep, success_FRS(i));
end

% DAARS: sweep Nrep_max from 2 to 8 (integers only - Nrep_max caps a
% physical repetition count, so a fractional cap like 2.25 would let
% Nrep=min(uncapped,2.25) evaluate to 2.25 reps and 2.25 slots consumed,
% neither of which any real system can do. Was 2:0.25:8.)
Nrep_vals = 2:8;
success_DAARS = zeros(size(Nrep_vals));
avg_reps_DAARS = zeros(size(Nrep_vals));

for k=1:length(Nrep_vals)
    Nrep_max = Nrep_vals(k);
    success_DAARS_mc = zeros(N_MC,1);
    avg_reps_DAARS_mc = zeros(N_MC,1);
    for mc = 1:N_MC
        DAARS_params.DNrep_1 = 1;         % Moderate
        DAARS_params.DNrep_2 = 2;         % Severe
        DAARS_params.DNrep_3 = 3;         % Critical
        DAARS_params.DNrep_priority = 1;  % Paging boost
        DAARS_params.Twindow_threshold = 30; % seconds, last 30s of vis
        DAARS_params.DNrep_window = 1;    % Window boost
        DAARS_params.Nrep_max = Nrep_max;        % Cap
        stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,100e3, ...
            2e9,3e8,1200e3,87.9,108*60,10, ...
            1e-3,Nslots_per_step,paging_lambda,reg_lambda,DAARS_params,PL_threshold);
        success_DAARS_mc(mc) = stats.success_rate;
        avg_reps_DAARS_mc(mc) = stats.avg_reps;
    end
    success_DAARS(k) = mean(success_DAARS_mc);
    % omitnan: stats.avg_reps is NaN for any run with zero successes
    % (no "winning attempt" to average) - without this, a single such
    % run would silently NaN out this entire sweep point.
    avg_reps_DAARS(k) = mean(avg_reps_DAARS_mc, 'omitnan');
    fprintf('RESULT DAARS Nrep_max=%d: avg_reps=%.4f success=%.4f\n', Nrep_max, avg_reps_DAARS(k), success_DAARS(k));
end

figure;
plot(FRS_reps, success_FRS, 'ro', 'LineWidth',2, 'MarkerFaceColor','r','MarkerSize',10); hold on;
plot(avg_reps_DAARS, success_DAARS, 'ks-','LineWidth',2,'MarkerFaceColor','k','MarkerSize',8);
xlabel('Average Number of Repetitions');
ylabel('Paging Success Probability');
legend('FRS Nrep=2..5','DAARS','Location','SouthEast');
grid on;
% Expected: DAARS curve rises above and left of two FRS points.

% Set figure size and font
xini = 2; yini = 2; xsize = 15; ysize = 9; % Example size in centimeters
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');

% Save as .eps (Encapsulated PostScript)
print('DAARS_vs_FRS_Reps_vs_SuccessProbability_200','-depsc2');
print(gcf,'DAARS_vs_FRS_Reps_vs_SuccessProbability_200','-dpng','-r150');
save('tradeoff_200_results.mat','FRS_reps','success_FRS','Nrep_vals','success_DAARS','avg_reps_DAARS');
