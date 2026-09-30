% plot_paging_success_vs_UE_position.m
% Paging success probability for center vs. edge UEs, FRS vs. DAARS.
% Plots the actual simulated success probabilities directly - no
% post-hoc rescaling.

clc; clear; close all
N_MC = 200;
N_UE = 50;
area_size = 100e3; % was 1000e3 - didn't match Table II or any other
                    % script in this project (100km x 100km service area)
sim_time = 600; dt = 0.1; N_steps = round(sim_time/dt);
PL_threshold = 195; % matches plot_delay_CDF_avg.m / plot_slot_utilization_vs_traffic.m
Nslots_per_step = 8; % dt/Tslot physically allows up to 100 one-ms slots
                        % per 100ms step; 8 models a realistic reserved
                        % control-plane fraction (~8%) rather than
                        % assuming the whole step is available for
                        % control-plane traffic

% Center/edge distance thresholds, scaled to the corrected 100km area
% (was <100km / 400-600km, which assumed the buggy 1000km area - under
% a 100km x 100km area, i.e. UEs within +-50km, no UE could ever be
% 400-600km out, so "edge_idx" would always have been empty and every
% edge_success value silently 0/0 -> 0).
% "center": within 15 km of the beam center; "edge": 35-50 km out (near
% the 50km half-width of the service area, i.e. close to its boundary).
% A tighter center radius (e.g. 10 km) was tried first, but with only 50
% UEs in a 100km box, its expected UE count is ~1.6 - about a 1-in-5
% chance of a draw with ZERO center UEs, silently forcing a spurious 0
% into that average via the max(1,...) guard below. 15 km drops that
% to ~3%, small enough to not matter over N_MC=200 draws.
center_radius = 15e3;
edge_band = [35e3, 50e3];

paging_lambda = 1/20; % matches Table II (1 request per UE every 10-30s);
reg_lambda = 1/450;   % was 1/120 and 1/1200 - much slower than Table II
                       % and inconsistent with every other script here

center_success_FRS = zeros(N_MC,1);
edge_success_FRS = zeros(N_MC,1);
center_success_DAARS = zeros(N_MC,1);
edge_success_DAARS = zeros(N_MC,1);

DAARS_params.DNrep_1 = 1;
DAARS_params.DNrep_2 = 2;
DAARS_params.DNrep_3 = 3;
DAARS_params.DNrep_priority = 1;
DAARS_params.Twindow_threshold = 30;
DAARS_params.DNrep_window = 1;
DAARS_params.Nrep_max = 5;
% Was DNrep_1/2/3=2/4/6, DNrep_priority=2, DNrep_window=4, Nrep_max=12
% ("aggressive adaptation") - roughly 2x Table II across the board and
% inconsistent with every other figure built from the same parameters.

for mc=1:N_MC
    % Generate UE positions ONCE per iteration and pass the SAME layout
    % into both FRS and DAARS. Previously this script generated its own
    % UE_pos here just to compute center_idx/edge_idx, while
    % simulate_FRS_run/simulate_DAARS_run each generated their OWN
    % independent random UE_pos internally - so the center/edge
    % categorization was being checked against completely unrelated
    % positions from the ones that actually produced stats.msg_queue.
    % That made the whole center-vs-edge comparison meaningless. Passing
    % UE_pos in (now supported by both functions) fixes this, and as a
    % bonus gives FRS and DAARS a paired comparison (same UE layout)
    % instead of two independent random draws.
    UE_pos = generate_UE_positions(N_UE, area_size);
    r = sqrt(sum(UE_pos(:,1:2).^2,2));
    center_idx = find(r < center_radius);
    edge_idx   = find(r >= edge_band(1) & r <= edge_band(2));

    % FRS
    stats = simulate_FRS_run(sim_time, dt, N_steps, N_UE, area_size, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, paging_lambda, reg_lambda, 2, PL_threshold, [], UE_pos);

    center_msgs = find(ismember(stats.msg_queue(:,3), center_idx));
    edge_msgs   = find(ismember(stats.msg_queue(:,3), edge_idx));
    center_success_FRS(mc) = sum(stats.msg_status(center_msgs)==1) / max(1,length(center_msgs));
    edge_success_FRS(mc)   = sum(stats.msg_status(edge_msgs)==1) / max(1,length(edge_msgs));

    % DAARS
    stats_DAARS = simulate_DAARS_run(sim_time, dt, N_steps, N_UE, area_size, ...
        2e9, 3e8, 1200e3, 87.9, 108*60, 10, ...
        1e-3, Nslots_per_step, paging_lambda, reg_lambda, DAARS_params, PL_threshold, [], UE_pos);

    center_msgs_D = find(ismember(stats_DAARS.msg_queue(:,3), center_idx));
    edge_msgs_D   = find(ismember(stats_DAARS.msg_queue(:,3), edge_idx));
    center_success_DAARS(mc) = sum(stats_DAARS.msg_status(center_msgs_D)==1) / max(1,length(center_msgs_D));
    edge_success_DAARS(mc)   = sum(stats_DAARS.msg_status(edge_msgs_D)==1) / max(1,length(edge_msgs_D));
end

% Plot the actual simulated values directly - no rescaling
data = [mean(center_success_FRS), mean(edge_success_FRS); ...
        mean(center_success_DAARS), mean(edge_success_DAARS)];
ci95 = @(x) 1.96*std(x)/sqrt(numel(x));
data_ci = [ci95(center_success_FRS), ci95(edge_success_FRS); ...
           ci95(center_success_DAARS), ci95(edge_success_DAARS)];

figure;
b = bar(data); hold on;
% Error bars at each bar's actual x-position (bar() groups by row, two
% bars per group - x-offsets below match MATLAB's default bar spacing)
ngroups = size(data,1); nbars = size(data,2);
groupwidth = min(0.8, nbars/(nbars+1.5));
for i = 1:nbars
    x = (1:ngroups) - groupwidth/2 + (2*i-1)*groupwidth/(2*nbars);
    errorbar(x, data(:,i), data_ci(:,i), 'k.', 'LineWidth',1.5);
end
set(gca,'XTickLabel',{'FRS','DAARS'});
ylabel('Paging Success Probability');
legend(b, {'Center UEs','Edge UEs'},'Location','NorthWest'); % was 'Edge','Center' -
    % backwards from bar()'s column order (col 1 = center, col 2 = edge)
grid on;
ylim([0 1]);
yticks(0:0.1:1);

% Set figure size and font
xini = 2; yini = 2; xsize = 15; ysize = 9; % Example size in centimeters
set(gcf,'units','centimeters','position',[xini,yini,xsize,ysize]);
set(gca,'FontSize',10,'FontName','Times');

% Save as .eps (Encapsulated PostScript)
print('Paging_Success_for_Center_vs_Edge_UEs','-depsc2');
