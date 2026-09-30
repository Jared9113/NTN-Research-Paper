clc; clear;
Re = 6371e3; h = 1200e3; r_orbit = Re+h;
elev_min = 10; % deg
fc = 2e9; c = 3e8;
incl = 87.9; period = 108*60;
omega = 2*pi/period;

% Geometric max visibility half-angle (zenith pass)
lambda = acosd((Re/r_orbit)*cosd(elev_min)) - elev_min;
vis_duration_min = 2*lambda / (360/period*60); % minutes
fprintf('Central half-angle lambda = %.3f deg\n', lambda);
fprintf('Theoretical max visibility duration (zenith pass) = %.3f min (%.1f s)\n', vis_duration_min, vis_duration_min*60);

% Orbital velocity
v_orbital = sqrt(3.986004418e14/r_orbit); % GM_earth / r, m/s
fprintf('Orbital velocity = %.1f m/s\n', v_orbital);
fD_theoretical_max = fc*v_orbital/c;
fprintf('Theoretical absolute max Doppler (v fully radial) = %.2f kHz\n', fD_theoretical_max/1e3);

% Now actually simulate a FULL zenith pass (extended sim_time) and find
% Doppler at the moment elevation crosses exactly 10 deg, using the
% project's own generate_satellite_trajectory / generate_UE_positions.
sim_time_full = vis_duration_min*60*1.05; % small margin
dt = 0.1; N_steps = round(sim_time_full/dt);
UE_pos = generate_UE_positions(50, 100e3);
r = sqrt(sum(UE_pos(:,1:2).^2,2));
[~, center_idx] = min(r);
[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, h, incl, period);

elev_deg = zeros(N_steps,1); fD = zeros(N_steps,1);
nadir_ref = [0,0,Re];
for t=1:N_steps
    elev_deg(t) = compute_elevation_deg(UE_pos(center_idx,:), sat_pos(t,:));
    v_rel = sat_vel(t,:);
    r_rel = sat_pos(t,:) - UE_pos(center_idx,:);
    r_hat = r_rel/norm(r_rel);
    fD(t) = fc*dot(v_rel,r_hat)/c;
end

vis_idx = find(elev_deg > elev_min);
fprintf('\nSimulated (extended-duration) pass:\n');
fprintf('Actual simulated visible duration = %.2f min (%d/%d steps)\n', numel(vis_idx)*dt/60, numel(vis_idx), N_steps);
fprintf('Doppler at first visible step (elev=%.2fdeg): %.3f kHz\n', elev_deg(vis_idx(1)), abs(fD(vis_idx(1)))/1e3);
fprintf('Doppler at last visible step (elev=%.2fdeg): %.3f kHz\n', elev_deg(vis_idx(end)), abs(fD(vis_idx(end)))/1e3);
fprintf('Max |Doppler| over whole visible period: %.3f kHz\n', max(abs(fD(vis_idx)))/1e3);

% Compare against the ORIGINAL 600s (10-min) truncated window's boundary
fprintf('\nFor comparison, original 600s window (elev at t=0 and t=600s):\n');
idx_600 = round(600/dt);
% Center the 600s window the same way the original scripts do (CPA at
% temporal midpoint of a 600s run) - approximate by finding CPA index
% here (max elevation) and taking +-300s around it.
[~, cpa_idx] = max(elev_deg);
lo = cpa_idx - round(300/dt); hi = cpa_idx + round(300/dt);
lo = max(1,lo); hi = min(N_steps,hi);
fprintf('600s-window boundary elevations: %.2f deg (start), %.2f deg (end)\n', elev_deg(lo), elev_deg(hi));
fprintf('600s-window boundary |Doppler|: %.3f kHz (start), %.3f kHz (end)\n', abs(fD(lo))/1e3, abs(fD(hi))/1e3);
