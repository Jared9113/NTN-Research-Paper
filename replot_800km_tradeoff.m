clc; clear; close all
FRS_reps = [2, 3];
success_FRS = [0.6841, 0.6420];
avg_reps_DAARS = [1.9969, 2.7467, 3.1771, 3.2562, 3.2653, 3.2602, 3.2773];
success_DAARS = [0.6852, 0.6624, 0.6402, 0.6118, 0.6242, 0.6371, 0.6205];

figure;
plot(FRS_reps, success_FRS, 'ro', 'LineWidth',2, 'MarkerFaceColor','r','MarkerSize',10); hold on;
plot(avg_reps_DAARS, success_DAARS, 'ks-','LineWidth',2,'MarkerFaceColor','k','MarkerSize',8);
xlabel('Average Number of Repetitions');
ylabel('Paging Success Probability');
legend('FRS Nrep=2,3','DAARS','Location','SouthEast');
grid on;
title('800km x 800km service area (N_{MC}=20, paired UE positions)');
ylim([0.55 0.72]);

xini = 2; yini = 2; xsize = 15; ysize = 9;
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');
print(gcf,'tradeoff_800km_recovered','-dpng','-r150');
