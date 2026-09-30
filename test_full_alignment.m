clc; clear;
N_UE = 50; area_size = 100e3; Re = 6371e3;
sat_alt = 1200e3; sat_incl = 87.9; orbital_period = 108*60;
fc = 2e9; c = 3e8;
N_steps = 6000; dt = 0.1;

UE_pos = generate_UE_positions(N_UE, area_size);
[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period);

nadir_ref = [0,0,Re];
distances = sqrt(sum(UE_pos(:,1:2).^2,2));
[~, center_idx] = min(distances);

d_to_center = vecnorm(sat_pos - UE_pos(center_idx,:), 2, 2);
[dmin, idx_min] = min(d_to_center);
tvec = (0:N_steps-1)*dt/60;
fprintf('Closest approach to selected UE at t=%.3f min (idx %d), sim midpoint is t=%.3f min\n', ...
    tvec(idx_min), idx_min, (N_steps*dt/2)/60);

fD_vec = zeros(N_steps,1); fD_res_vec = zeros(N_steps,1);
for t=1:N_steps
    v_rel = sat_vel(t,:);
    r_rel = sat_pos(t,:) - UE_pos(center_idx,:);
    fD_vec(t) = fc*dot(v_rel, r_rel/norm(r_rel))/c;
    r_rel_nom = sat_pos(t,:) - nadir_ref;
    fD_nom = fc*dot(v_rel, r_rel_nom/norm(r_rel_nom))/c;
    fD_res_vec(t) = fD_vec(t) - fD_nom;
end
fprintf('Raw Doppler: min %.4f kHz, max %.3f kHz\n', min(abs(fD_vec))/1e3, max(abs(fD_vec))/1e3);
fprintf('Residual Doppler: min %.4f kHz, max %.4f kHz\n', min(abs(fD_res_vec))/1e3, max(abs(fD_res_vec))/1e3);
[~,idxZero] = min(abs(fD_vec));
fprintf('Raw Doppler zero-crossing at t=%.3f min\n', tvec(idxZero));
