% ablation_200_makeplot.m
% Reconstructs the N_MC=200 ablation results (already computed in
% run_200_batch.log before a heap-corruption crash during figure export
% lost the .mat/figure) from that log's printed values. Saves the .mat
% FIRST, then attempts figure export defensively.

clc; clear; close all

results = struct('name',{},'success',{},'success_ci',{},'delay',{},'delay_ci',{},'reps',{});
results(1) = struct('name','FRS (no adaptation)','success',0.8571,'success_ci',0.0013,'delay',0.0500,'delay_ci',0.0001,'reps',2.0000);
results(2) = struct('name','Doppler-only',        'success',0.8593,'success_ci',0.0011,'delay',0.0501,'delay_ci',0.0001,'reps',2.1352);
results(3) = struct('name','Doppler+Priority',     'success',0.8599,'success_ci',0.0012,'delay',0.0500,'delay_ci',0.0001,'reps',2.1383);
results(4) = struct('name','Full DAARS',           'success',0.8617,'success_ci',0.0012,'delay',0.0501,'delay_ci',0.0001,'reps',2.1899);

save('ablation_study_200_results.mat','results');
fprintf('Saved ablation_study_200_results.mat\n');

try
    fig = figure('Renderer','painters');
    subplot(1,2,1);
    bar([results.success]); hold on;
    errorbar(1:numel(results), [results.success], [results.success_ci], 'k.', 'LineWidth',1.5);
    set(gca,'XTickLabel',{results.name}); xtickangle(30);
    ylabel('Paging Success Probability'); grid on; ylim([0.84 0.87]);
    title('Ablation: Success Probability (N\_MC=200)');

    subplot(1,2,2);
    bar([results.delay]); hold on;
    errorbar(1:numel(results), [results.delay], [results.delay_ci], 'k.', 'LineWidth',1.5);
    set(gca,'XTickLabel',{results.name}); xtickangle(30);
    ylabel('Average Delay (s)'); grid on;
    title('Ablation: Registration Delay (N\_MC=200)');

    set(gcf,'units','centimeters','position',[2,2,24,10]);
    drawnow;
    print(fig,'DAARS_Ablation_Study_200','-depsc2');
    print(fig,'DAARS_Ablation_Study_200','-dpng','-r150');
    fprintf('Saved DAARS_Ablation_Study_200.png/.eps\n');
catch ME
    fprintf('Figure export failed (data already safely saved to .mat): %s\n', ME.message);
end
