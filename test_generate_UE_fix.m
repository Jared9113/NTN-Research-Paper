clc; clear;
N_UE = 50; area_size = 100e3; Re = 6371e3;
sat_alt = 1200e3; sat_incl = 87.9; orbital_period = 108*60;
fc = 2e9; c = 3e8;
N_steps = 6000; dt = 0.1;

UE_pos = generate_UE_positions(N_UE, area_size);
fprintf('UE z range: %.1f to %.1f km (should be near Re=%.1f km)\n', ...
    min(UE_pos(:,3))/1e3, max(UE_pos(:,3))/1e3, Re/1e3);

omega = 2*pi/orbital_period;
theta0 = pi/2 - omega*(N_steps*dt/2);
r_orbit = Re + sat_alt;
sat_pos = zeros(N_steps,3); sat_vel = zeros(N_steps,3);
for t = 1:N_steps
    theta = omega*((t-1)*dt) + theta0;
    sat_pos(t,:) = [r_orbit*cos(theta), r_orbit*sin(theta)*cosd(sat_incl), r_orbit*sin(theta)*sind(sat_incl)];
    sat_vel(t,:) = [-r_orbit*omega*sin(theta), r_orbit*omega*cos(theta)*cosd(sat_incl), r_orbit*omega*cos(theta)*sind(sat_incl)];
end

nadir_ref = [0,0,Re];
distances = sqrt(sum(UE_pos(:,1:2).^2,2));
[~, center_idx] = min(distances);

fD_vec = zeros(N_steps,1); fD_res_vec = zeros(N_steps,1);
for t=1:N_steps
    v_rel = sat_vel(t,:);
    r_rel = sat_pos(t,:) - UE_pos(center_idx,:);
    r_hat = r_rel/norm(r_rel);
    fD_vec(t) = fc*dot(v_rel,r_hat)/c;
    r_rel_nom = sat_pos(t,:) - nadir_ref;
    r_hat_nom = r_rel_nom/norm(r_rel_nom);
    fD_nom = fc*dot(v_rel,r_hat_nom)/c;
    fD_res_vec(t) = fD_vec(t) - fD_nom;
end

fprintf('Raw Doppler: min %.3f kHz, max %.3f kHz\n', min(abs(fD_vec))/1e3, max(abs(fD_vec))/1e3);
fprintf('Residual Doppler: min %.4f kHz, max %.4f kHz\n', min(abs(fD_res_vec))/1e3, max(abs(fD_res_vec))/1e3);
fprintf('Selected UE offset from center (km): %.3f, %.3f\n', UE_pos(center_idx,1)/1e3, UE_pos(center_idx,2)/1e3);
