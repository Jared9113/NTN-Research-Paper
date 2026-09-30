% LEO_NTN_full_system_model.m
% Comprehensive system model for LEO-based Non-Terrestrial Network
% Visualizes: Earth, LEO satellite in orbit, ground UEs, satellite-UE link, Doppler shift over time

clc; clear; close all

%% --- Parameters ---
N_UE = 50;
area_size = 100e3;           % 100 km x 100 km square
fc = 2e9;                    % 2 GHz carrier
c = 3e8;                     % Speed of light (m/s)
sat_alt = 1200e3;            % Satellite altitude (m)
sat_incl = 87.9;             % Inclination (deg)
orbital_period = 108*60;     % 6480 s
sim_time = 600;              % 10 min simulation (s)
dt = 1;                      % Step (s) for animation
N_steps = round(sim_time/dt);
theta_min_elev = 10;         % Minimum elevation (deg)

Re = 6371e3;                 % Earth radius (m)
r_orbit = Re + sat_alt;      % Orbit radius (m)

%% --- Generate UE positions ---
UE_pos = generate_UE_positions(N_UE, area_size, Re); % [N_UE x 3], on Earth's surface

%% --- Recommended theta0 for realistic pass (not always visible) ---
omega = 2*pi/orbital_period;
t_mid = sim_time/2;
theta0 = pi/2 - omega * t_mid;

[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period, theta0);

%% --- Doppler for UE closest to center ---
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

%% --- Figure 1: Z vs X orbit ---
fig1 = figure('Units','normalized','OuterPosition',[0 0 0.5 1]);
ax1 = axes('Parent', fig1);
hold(ax1,'on');

theta_circle = linspace(0,2*pi,300);

% Earth
earth_x = Re * cos(theta_circle) / 1e3;
earth_z = Re * sin(theta_circle) / 1e3;
plot(ax1, earth_x, earth_z, 'Color', [0.6 0.8 1], 'LineWidth', 2);

% Orbit path
orbit_x = r_orbit*cos(theta_circle)/1e3;
orbit_z = r_orbit*sin(theta_circle)/1e3;
plot(ax1, orbit_x, orbit_z, 'b--', 'LineWidth', 1.2);

% Selected UE
scatter(ax1, UE_pos(center_idx,1)/1e3, UE_pos(center_idx,3)/1e3, ...
        100, 'k', 'filled');

% Satellite position (handle kept for the animation loop below)
sat_km_x = sat_pos(1,1)/1e3;
sat_km_z = sat_pos(1,3)/1e3;
sat_plot2d = plot(ax1, sat_km_x, sat_km_z, 'mo', ...
     'MarkerSize', 12, 'MarkerFaceColor', 'm');

% Link line (handle kept for the animation loop below)
link_plot2d = plot(ax1, [sat_km_x, UE_pos(center_idx,1)/1e3], ...
     [sat_km_z, UE_pos(center_idx,3)/1e3], ...
     'm-', 'LineWidth',2);

xlabel(ax1, 'X (km)');
ylabel(ax1, 'Z (km)');
legend(ax1, 'Earth','LEO Orbit','Selected UE','Satellite','Link', ...
       'Location','bestoutside');

%% --- Slight zoom out (expanded limits) ---
zoom_factor = 1.15;  % increase this if you want more zoom out

xlim(ax1, zoom_factor * [-Re/1e3-1500, Re/1e3+1500]);
ylim(ax1, zoom_factor * [-Re/1e3-500,  Re/1e3+500]);

axis(ax1, 'equal');
grid(ax1, 'on');
set(ax1,'FontSize',12,'FontName','Times');
hold(ax1,'off');

% Save Figure 1 as its own EPS
print(fig1, 'LEO_NTN_2DOrbit', '-dpng', '-r150');

%% --- Figure 2: Doppler ---
fig2 = figure('Units','normalized','OuterPosition',[0.5 0 0.5 1]);
ax2 = axes('Parent', fig2);
hold(ax2,'on');

tvec = (0:N_steps-1)*dt/60;

plot(ax2, tvec, abs(fD_vec)/1e3, 'r-', 'LineWidth',2);
plot(ax2, tvec(visible_vec), ...
     abs(fD_vec(visible_vec))/1e3, ...
     'b.', 'MarkerSize',10);

ymax = max(abs(fD_vec))/1e3 * 1.05;

if any(visible_vec)
    visible_times = tvec(visible_vec);
    vis_start = visible_times(1);
    vis_end   = visible_times(end);

    fill(ax2, [vis_start vis_end vis_end vis_start], ...
         [0 0 ymax ymax], ...
         'b','FaceAlpha',0.08,'EdgeColor','none');
end

xlabel(ax2, 'Time (min)');
ylabel(ax2, '|Doppler Shift| (kHz)');
grid(ax2, 'on');
set(ax2,'FontSize',12,'FontName','Times');
hold(ax2,'off');

% Save Figure 2 as its own EPS
print(fig2, 'LEO_NTN_Doppler', '-dpng', '-r150');

%% --- Supporting Functions ---
function UE_pos = generate_UE_positions(N_UE, area_size, Re)
    % Uniform random in square centered at origin, projected onto Earth surface
    xy = [(rand(N_UE,1)-0.5)*area_size, (rand(N_UE,1)-0.5)*area_size];
    z = sqrt(Re^2 - sum(xy.^2,2)); % place on Earth's surface (z>0)
    UE_pos = [xy, z];
end

function [sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, incl, period, theta0)
    Re = 6371e3; r_orbit = Re + sat_alt; omega = 2*pi/period;
    sat_pos = zeros(N_steps,3); sat_vel = zeros(N_steps,3);
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
    % Returns true if satellite above min elevation from UE
    vec_UE_sat = sat_pos - UE_pos;
    elev_angle = atan2(vec_UE_sat(3), norm(vec_UE_sat(1:2))); % radians
    elev_angle_deg = elev_angle * 180/pi;
    visible = elev_angle_deg > theta_min_elev;
end

function fD = calculate_doppler(fc, c, v_sat, r_rel)
    r_hat = r_rel / norm(r_rel);
    v_radial = dot(v_sat, r_hat);
    fD = fc * v_radial / c;
end
