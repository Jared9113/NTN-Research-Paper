% correlated_fading_experiment.m
% Tests the independence assumption behind Eq. 19 (P_success = 1-PER^Nrep)
% by replacing the current "one shared fading draw per attempt" model
% with an AR(1)-correlated fading SEQUENCE across a message's Nrep
% repetitions: r_k = rho*r_{k-1} + sqrt(1-rho^2)*w_k on the complex
% scattered component, w_k ~ CN(0,1) fresh each repetition. rho=0 means
% each repetition gets an independent fading draw (best case for
% diversity); rho->1 approaches the current model's "one shared value
% for the whole attempt" behavior.
%
% For each (fD_residual, Nrep, rho) combination: draws N_TRIALS
% independent attempts, each attempt drawing an Nrep-long AR(1) fading
% sequence, computing a PER per repetition from that repetition's own
% fading-adjusted SNR, and declaring the attempt successful if at least
% one repetition decodes (matching Algorithm 1/2's "success if at least
% one repetition is error-free"). Empirical P_success = fraction of
% attempts succeeding. Theoretical P_success is Eq. 19 exactly as
% written in the paper: 1 - PER_nominal^Nrep, with PER_nominal computed
% at the nominal SNR0 (no fading term at all - Eq. 19 as stated does not
% include fading).

clc; clear;
SNR0_dB = 8; delta_f_SCS = 15e3; L_bits = 100; K_dB = 7;
N_TRIALS = 20000;

fD_vals = [0.5, 1.5, 2.5, 4.0]*1e3; % Hz, matching Table I's illustrative points
Nrep_vals = [2, 3];
rho_vals = [1.0];

K_lin = 10^(K_dB/10);
A = 1;

results = [];
row = 0;
for fi = 1:numel(fD_vals)
    fD = fD_vals(fi);
    PER_nominal = per_from_doppler(fD, SNR0_dB, delta_f_SCS, L_bits);
    for ni = 1:numel(Nrep_vals)
        Nrep = Nrep_vals(ni);
        P_theory = 1 - PER_nominal^Nrep;
        for ri = 1:numel(rho_vals)
            rho = rho_vals(ri);
            successes = false(N_TRIALS,1);
            for trial = 1:N_TRIALS
                rep_success = false(Nrep,1);
                X_prev = (randn + 1i*randn)/sqrt(2); % first repetition: fresh draw
                for k = 1:Nrep
                    if k > 1
                        w = (randn + 1i*randn)/sqrt(2);
                        X_prev = rho*X_prev + sqrt(1-rho^2)*w;
                    end
                    r = sqrt(K_lin/(K_lin+1))*A + sqrt(1/(K_lin+1))*X_prev;
                    fading_dB = 10*log10(abs(r)^2);
                    PER_k = per_from_doppler(fD, SNR0_dB + fading_dB, delta_f_SCS, L_bits);
                    rep_success(k) = rand < (1 - PER_k);
                end
                successes(trial) = any(rep_success);
            end
            P_empirical = mean(successes);
            P_empirical_ci95 = 1.96*sqrt(P_empirical*(1-P_empirical)/N_TRIALS);
            row = row+1;
            results(row).fD_kHz = fD/1e3;
            results(row).Nrep = Nrep;
            results(row).rho = rho;
            results(row).PER_nominal = PER_nominal;
            results(row).P_theory = P_theory;
            results(row).P_empirical = P_empirical;
            results(row).P_empirical_ci95 = P_empirical_ci95;
            results(row).gap = P_theory - P_empirical;
            fprintf('RESULT fD=%.1fkHz Nrep=%d rho=%.2f: P_theory(Eq19)=%.4f P_empirical=%.4f+-%.4f gap=%.4f\n', ...
                fD/1e3, Nrep, rho, P_theory, P_empirical, P_empirical_ci95, P_theory-P_empirical);
        end
    end
end

save('correlated_fading_rho1_results.mat','results');
fprintf('\nSaved correlated_fading_results.mat\n');
