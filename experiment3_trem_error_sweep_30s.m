% experiment3_trem_error_sweep.m
% Tests robustness of DAARS's window-boost mechanism (Eq. 17-18) to
% realistic visibility-prediction error, per the paper's own admitted gap
% (Conclusion: a real deployment cannot observe t_last directly and must
% predict it from ephemeris data). Trem_error_halfwidth adds
% U(-halfwidth,+halfwidth) noise to Trem before the window-boost decision
% (simulate_DAARS_run.m's new 20th argument), leaving everything else
% about DAARS unchanged.
%
% FRS/Zone-based/ThresholdBased do not depend on Trem at all, so they are
% NOT re-run here - their N_MC=200 reference numbers already exist in
% comprehensive_baseline_results3.mat at the same 600s duration, and are
% loaded for reference rather than wastefully re-simulated 5 times over.

clc; clear;
N_MC = 200;
N_UE = 50;
sim_time = 30; dt = 0.1; N_steps = round(sim_time/dt);
Nslots_per_step = 8;
PL_threshold = 195;
paging_lambda = 1/20;
reg_lambda = 1/450;
area_size = 100e3;

error_levels = [0, 1, 5, 10, 30]; % seconds, half-width of U(-L,+L) noise on Trem
NL = numel(error_levels);
succ = zeros(NL,1); succ_std = zeros(NL,1);
delay = zeros(NL,1); delay_std = zeros(NL,1);
reps = zeros(NL,1); reps_std = zeros(NL,1);

DAARS_params.DNrep_1=1; DAARS_params.DNrep_2=2; DAARS_params.DNrep_3=3;
DAARS_params.DNrep_priority=1; DAARS_params.Twindow_threshold=30;
DAARS_params.DNrep_window=1; DAARS_params.Nrep_max=5;

for li = 1:NL
    L = error_levels(li);
    s = zeros(N_MC,1); d = zeros(N_MC,1); r = zeros(N_MC,1);
    for mc = 1:N_MC
        UE_pos = generate_UE_positions(N_UE, area_size);
        stats = simulate_DAARS_run(sim_time,dt,N_steps,N_UE,area_size, ...
            2e9,3e8,1200e3,87.9,108*60,10,1e-3,Nslots_per_step, ...
            paging_lambda,reg_lambda,DAARS_params,PL_threshold,[],UE_pos,L);
        s(mc) = stats.success_rate; d(mc) = stats.avg_delay; r(mc) = stats.avg_reps;
    end
    succ(li) = mean(s); succ_std(li) = std(s);
    delay(li) = mean(d,'omitnan'); delay_std(li) = std(d,'omitnan');
    reps(li) = mean(r,'omitnan'); reps_std(li) = std(r,'omitnan');
    fprintf('RESULT Trem_error=+-%ds: succ=%.4f+-%.4f delay=%.4f+-%.4f reps=%.4f+-%.4f\n', ...
        L, succ(li), succ_std(li), delay(li), delay_std(li), reps(li), reps_std(li));
    % Save after every level, not just at the end.
    save('experiment3_trem_error_30s_results.mat','error_levels','succ','succ_std','delay','delay_std','reps','reps_std','li');
end

fprintf('\nSaved experiment3_trem_error_results.mat\n');
