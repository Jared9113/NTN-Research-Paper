% pass_duration_final_makeplot.m
% Reconstructs the N_MC=200 pass-duration sweep results (already computed
% in pass_duration_final.log before a heap-corruption crash during figure
% export lost the .mat/.png) from that log's RESULT lines, saves the .mat
% FIRST (so data survives even if export crashes again), then attempts
% the figure export defensively.

clc; clear; close all

pass_durations = [60 120 180 240 300 360 420 480 540 600];
succ_FRS2  = [0.8472 0.8490 0.8484 0.8510 0.8523 0.8542 0.8548 0.8552 0.8562 0.8570];
std_FRS2   = [0.0302 0.0201 0.0171 0.0127 0.0128 0.0116 0.0102 0.0099 0.0093 0.0086];
succ_FRS3  = [0.8736 0.8751 0.8762 0.8790 0.8797 0.8819 0.8815 0.8816 0.8824 0.8831];
std_FRS3   = [0.0270 0.0183 0.0142 0.0126 0.0122 0.0107 0.0102 0.0098 0.0090 0.0081];
succ_DAARS = [0.8699 0.8645 0.8645 0.8634 0.8633 0.8620 0.8610 0.8607 0.8615 0.8612];
std_DAARS  = [0.0271 0.0198 0.0157 0.0138 0.0119 0.0112 0.0102 0.0091 0.0096 0.0086];
N_MC = 200;

% Save data FIRST, before any plotting/export that could crash.
save('pass_duration_final_results.mat','pass_durations','succ_FRS2','succ_FRS3','succ_DAARS','std_FRS2','std_FRS3','std_DAARS','N_MC');
fprintf('Saved pass_duration_final_results.mat\n');

try
    fig = figure('Position',[100 100 700 500],'Renderer','painters');
    errorbar(pass_durations, succ_FRS2, 1.96*std_FRS2/sqrt(N_MC), 'r--s','LineWidth',1.5,'MarkerFaceColor','r'); hold on;
    errorbar(pass_durations, succ_FRS3, 1.96*std_FRS3/sqrt(N_MC), 'b--^','LineWidth',1.5,'MarkerFaceColor','b');
    errorbar(pass_durations, succ_DAARS, 1.96*std_DAARS/sqrt(N_MC), 'k-o','LineWidth',2,'MarkerFaceColor','k');
    xlabel('Satellite Pass Duration (s)'); ylabel('Paging Success Probability');
    legend('FRS N_{rep}=2','FRS N_{rep}=3','DAARS','Location','southeast');
    title('Success Probability vs. Pass Duration (N\_MC=200, 95% CI)');
    grid on; ylim([0.80 0.92]);
    drawnow;
    print(fig,'pass_duration_final','-dpng','-r150','-painters');
    fprintf('Saved pass_duration_final.png\n');
catch ME
    fprintf('Figure export failed (data already safely saved to .mat): %s\n', ME.message);
end
