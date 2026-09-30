% LEO_NTN_system_model.m (as pasted, unmodified) - diagnostic copy
clc; clear; close all

N_UE = 50;
area_size = 100e3;
fc = 2e9;
c = 3e8;
sat_alt = 1200e3;
sat_incl = 87.9;
orbital_period = 108*60;
sim_time = 600;
dt = 0.1;
N_steps = round(sim_time/dt);
theta_min_elev = 10;

UE_pos = generate_UE_positions(N_UE, area_size);

omega = 2*pi/orbital_period;
t_mid = sim_time/2;
theta0 = pi/2 - omega * t_mid;

[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period, theta0);

distances = sqrt(sum(UE_pos(:,1:2).^2, 2));
[~, center_idx] = min(distances);

fD_vec = zeros(N_steps,1);
visible_vec = false(N_steps,1);
for t = 1:N_steps
    visible_vec(t) = is_UE_visible(UE_pos(center_idx,:), sat_pos(t,:), theta_min_elev);
    v_rel = sat_vel(t,:);
    r_rel = sat_pos(t,:) - UE_pos(center_idx,:);
    fD_vec(t) = calculate_doppler(fc, c, v_rel, r_rel);
end

fprintf('BUGGY VERSION (UE z=0):\n');
fprintf('min |fD| = %.6f kHz\n', min(abs(fD_vec))/1e3);
fprintf('max |fD| = %.6f kHz\n', max(abs(fD_vec))/1e3);
fprintf('fD(1)=%.6f kHz  fD(mid)=%.6f kHz  fD(end)=%.6f kHz\n', fD_vec(1)/1e3, fD_vec(round(N_steps/2))/1e3, fD_vec(end)/1e3);

function UE_pos = generate_UE_positions(N_UE, area_size)
UE_pos = [(rand(N_UE,1)-0.5)*area_size, (rand(N_UE,1)-0.5)*area_size, zeros(N_UE,1)];
end

function [sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, incl, period, theta0)
Re = 6371e3;
r_orbit = Re + sat_alt;
omega = 2*pi/period;
sat_pos = zeros(N_steps,3);
sat_vel = zeros(N_steps,3);
for t = 1:N_steps
    theta = omega * ((t-1) * dt) + theta0;
    x = r_orbit * cos(theta);
    y = r_orbit * sin(theta) * cosd(incl);
    z = r_orbit * sin(theta) * sind(incl);
    sat_pos(t,:) = [x, y, z];
    vx = -r_orbit * omega * sin(theta);
    vy = r_orbit * omega * cos(theta) * cosd(incl);
    vz = r_orbit * omega * cos(theta) * sind(incl);
    sat_vel(t,:) = [vx, vy, vz];
end
end

function visible = is_UE_visible(UE_pos, sat_pos, theta_min_elev)
vec_UE_sat = sat_pos - UE_pos;
elev_angle = asind(vec_UE_sat(3)/norm(vec_UE_sat));
visible = elev_angle > theta_min_elev;
end

function fD = calculate_doppler(fc, c, v_rel, r_rel)
r_hat = r_rel / norm(r_rel);
v_radial = dot(v_rel, r_hat);
fD = fc * v_radial / c;
end
