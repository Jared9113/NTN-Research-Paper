function [sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, incl, period)
Re = 6371e3; % Earth radius (m)
r_orbit = Re + sat_alt;
omega = 2*pi/period;

% --- Recommended initial phase ---
sim_time = N_steps*dt;
t_mid = sim_time/2;
theta0 = pi/2 - omega * t_mid;

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
