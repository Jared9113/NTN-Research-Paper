% Diagnostic script - reproduces the Doppler computation from
% LEO_NTN_full_system_model.m without any plotting, to inspect
% the actual numeric curve.

N_UE = 50;
area_size = 100e3;
fc = 2e9;
c = 3e8;
sat_alt = 1200e3;
sat_incl = 87.9;
orbital_period = 108*60;
sim_time = 600;
dt = 1;
N_steps = round(sim_time/dt);
theta_min_elev = 10;

Re = 6371e3;
r_orbit = Re + sat_alt;

rng(1); % fixed seed for reproducibility
xy = [(rand(N_UE,1)-0.5)*area_size, (rand(N_UE,1)-0.5)*area_size];
z = sqrt(Re^2 - sum(xy.^2,2));
UE_pos = [xy, z];

omega = 2*pi/orbital_period;
t_mid = sim_time/2;
theta0 = pi/2 - omega * t_mid;

sat_pos = zeros(N_steps,3); sat_vel = zeros(N_steps,3);
for t = 1:N_steps
    theta = omega * ((t-1) * dt) + theta0;
    x = r_orbit * cos(theta);
    y = r_orbit * sin(theta) * cosd(sat_incl);
    z2 = r_orbit * sin(theta) * sind(sat_incl);
    sat_pos(t,:) = [x, y, z2];
    vx = -r_orbit * omega * sin(theta);
    vy = r_orbit * omega * cos(theta) * cosd(sat_incl);
    vz = r_orbit * omega * cos(theta) * sind(sat_incl);
    sat_vel(t,:) = [vx, vy, vz];
end

distances = sqrt(sum(UE_pos(:,1:2).^2, 2));
[~, center_idx] = min(distances);

fD_vec = zeros(N_steps,1);
visible_vec = false(N_steps,1);
for t = 1:N_steps
    vec_UE_sat = sat_pos(t,:) - UE_pos(center_idx,:);
    elev_angle_deg = atan2(vec_UE_sat(3), norm(vec_UE_sat(1:2))) * 180/pi;
    visible_vec(t) = elev_angle_deg > theta_min_elev;

    v_rel = sat_vel(t,:);
    r_rel = sat_pos(t,:) - UE_pos(center_idx,:);
    r_hat = r_rel / norm(r_rel);
    v_radial = dot(v_rel, r_hat);
    fD_vec(t) = fc * v_radial / c;
end

tvec = (0:N_steps-1)*dt/60;

fprintf('center UE pos (km): %.3f %.3f %.3f\n', UE_pos(center_idx,:)/1e3);
fprintf('t=0   min:  fD = %.3f kHz, elev = %.2f deg\n', fD_vec(1)/1e3, atan2(sat_pos(1,3)-UE_pos(center_idx,3), norm(sat_pos(1,1:2)-UE_pos(center_idx,1:2)))*180/pi);
[minAbs, idxMin] = min(abs(fD_vec));
fprintf('min |fD| = %.6f kHz at t = %.3f min (index %d)\n', minAbs/1e3, tvec(idxMin), idxMin);
[maxAbs, idxMax] = max(abs(fD_vec));
fprintf('max |fD| = %.3f kHz at t = %.3f min (index %d)\n', maxAbs/1e3, tvec(idxMax), idxMax);
fprintf('fD at t=0:   %.3f kHz\n', fD_vec(1)/1e3);
fprintf('fD at t~5min (idx 300): %.3f kHz\n', fD_vec(300)/1e3);
fprintf('fD at t~10min (idx end): %.3f kHz\n', fD_vec(end)/1e3);

fprintf('\nSample every 60 steps (1 min):\n');
for i = 1:60:N_steps
    fprintf('t=%.2f min  fD=%.3f kHz  |fD|=%.3f kHz  visible=%d\n', tvec(i), fD_vec(i)/1e3, abs(fD_vec(i))/1e3, visible_vec(i));
end
fprintf('num visible steps: %d / %d\n', sum(visible_vec), N_steps);
