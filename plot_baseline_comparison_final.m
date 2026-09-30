% plot_baseline_comparison_final.m
% Final Fig. 12: all 6 schemes (FRS2, FRS3, Zone-based, HARQ-based,
% ThresholdBased, DAARS), success probability and average delay, with
% 95% CI error bars, from comprehensive_baseline_results3.mat (N_MC=200,
% single-attempt semantics, SNR0=8dB - the most current data).

clc; clear; close all
load('comprehensive_baseline_results3.mat'); % succ_all, delay_all, reps_all, util_all, names
N_MC = size(succ_all,1);
N = numel(names);

s_mean = mean(succ_all,1); s_ci95 = 1.96*std(succ_all,0,1)/sqrt(N_MC);
d_mean = mean(delay_all,1,'omitnan'); d_ci95 = 1.96*std(delay_all,0,1,'omitnan')/sqrt(N_MC);

fig = figure('Position',[100 100 1000 450]);

subplot(1,2,1);
b1 = bar(s_mean,'FaceColor',[0.30 0.55 0.80]); hold on;
errorbar(1:N, s_mean, s_ci95, 'k.', 'LineWidth',1.3,'CapSize',8);
set(gca,'XTick',1:N,'XTickLabel',names,'XTickLabelRotation',20);
ylabel('Paging Success Probability'); ylim([0.75 1.02]);
title('Success Probability (95% CI)'); grid on;

subplot(1,2,2);
b2 = bar(d_mean,'FaceColor',[0.80 0.40 0.30]); hold on;
errorbar(1:N, d_mean, d_ci95, 'k.', 'LineWidth',1.3,'CapSize',8);
set(gca,'XTick',1:N,'XTickLabel',names,'XTickLabelRotation',20);
ylabel('Average Delay (s)'); ylim([0 0.09]);
title('Registration Delay (95% CI)'); grid on;

sgtitle('Baseline Comparison: FRS, Zone-based, HARQ-based, ThresholdBased, DAARS (N\_MC=200)');

saveas(fig,'baseline_comparison_final.png');
print(fig,'baseline_comparison_final','-dpng','-r150');

fprintf('Saved baseline_comparison_final.png\n');
for c=1:N
    fprintf('RESULT %-16s succ=%.4f+-%.4f(95%%CI) delay=%.4f+-%.4f(95%%CI)\n', ...
        names{c}, s_mean(c), s_ci95(c), d_mean(c), d_ci95(c));
end
