% LEO_NTN_system_model.m
% System model for a LEO-based Non-Terrestrial Network
% Shows: LEO satellite in orbit, ground UEs, satellite pass trajectory, and Doppler shift dynamics

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
dt = 0.1;                    % Step (s)
N_steps = round(sim_time/dt);
theta_min_elev = 10;         % Minimum elevation (deg)
Re = 6371e3;                 % Earth radius (m)

%% --- Generate satellite trajectory ---
% Recommended theta0 for realistic pass (not always visible)
omega = 2*pi/orbital_period;
t_mid = sim_time/2;
theta0 = pi/2 - omega * t_mid;

[sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, sat_incl, orbital_period, theta0);

%% --- Local East-North-Up frame, anchored at the true sub-satellite (nadir)
%% point at closest approach (theta = pi/2), so the ground track and the
%% UE service area share one consistent local frame ---
nadir_ref = Re * [0, cosd(sat_incl), sind(sat_incl)]; % sub-satellite point at CPA
up_vec = nadir_ref / norm(nadir_ref);
helper = [0 0 1];
if abs(dot(up_vec, helper)) > 0.999
    helper = [1 0 0];
end
e_east = cross(helper, up_vec); e_east = e_east / norm(e_east);
e_north = cross(up_vec, e_east);

%% --- Generate UE positions around the true nadir reference ---
[UE_pos, UE_local] = generate_UE_positions(N_UE, area_size, Re, nadir_ref, e_east, e_north);

%% --- Ground track in the same local East-North frame (km) ---
ground_pts = Re * sat_pos ./ vecnorm(sat_pos, 2, 2); % sub-satellite points on the sphere
rel = ground_pts - nadir_ref;
track_E = (rel * e_east') / 1e3;
track_N = (rel * e_north') / 1e3;

%% --- Pick UE closest to center for Doppler analysis ---
distances = sqrt(sum(UE_local.^2, 2));
[~, center_idx] = min(distances);

% Idealized beam-center reference (true nadir at CPA) - this is the single
% common Doppler value the network would broadcast as per-beam
% pre-compensation (3GPP TR 38.821).
beam_center_pos = nadir_ref;

fD_vec = zeros(N_steps,1);          % raw Doppler at the selected UE
fD_nominal_vec = zeros(N_steps,1);  % nominal (beam-center) Doppler
visible_vec = false(N_steps,1);
for t = 1:N_steps
    visible_vec(t) = is_UE_visible(UE_pos(center_idx,:), sat_pos(t,:), theta_min_elev, up_vec);
    v_rel = sat_vel(t,:);
    r_rel = sat_pos(t,:) - UE_pos(center_idx,:);
    fD_vec(t) = calculate_doppler(fc, c, v_rel, r_rel);
    r_rel_nom = sat_pos(t,:) - beam_center_pos;
    fD_nominal_vec(t) = calculate_doppler(fc, c, v_rel, r_rel_nom);
end

% Residual Doppler after the network applies the common per-beam
% pre-compensation (fD_nominal_vec) to every UE in the beam.
fD_residual_vec = fD_vec - fD_nominal_vec;

%% --- Plot: System Model ---
km_per_cm = 50;              % physical map scale: 1 cm = 50 km
axes_size_cm = 8.5;          % left panel footprint, same as before the rescale
zoom_half_range_km = axes_size_cm/2 * km_per_cm; % range implied by the scale

left_margin_cm   = 2.0;
bottom_margin_cm = 1.8;
top_margin_cm    = 1.8;
gap_cm           = 2.2;
right_ax_width_cm  = 8.5;
right_ax_height_cm = axes_size_cm; % match the left panel's footprint
right_margin_cm  = 4.0; % room for the right plot's legend

fig_width_cm  = left_margin_cm + axes_size_cm + gap_cm + right_ax_width_cm + right_margin_cm;
fig_height_cm = bottom_margin_cm + max(axes_size_cm, right_ax_height_cm) + top_margin_cm;

fig = figure('Units','centimeters','Position',[2 2 fig_width_cm fig_height_cm]);

% --- Left: Ground Track, UEs, Area (to scale: 1 cm = 50 km) ---
ax1 = axes('Parent',fig,'Units','centimeters', ...
    'Position',[left_margin_cm bottom_margin_cm axes_size_cm axes_size_cm]);
hold(ax1,'on');
h_area = plot(ax1, nan, nan, 'g-', 'LineWidth', 2, 'DisplayName', 'Simulated Area');
rectangle('Parent',ax1,'Position',[-area_size/2/1e3, -area_size/2/1e3, area_size/1e3, area_size/1e3],...
    'EdgeColor','g','LineWidth',2,'HandleVisibility','off'); % Simulated area
plot(ax1, track_E, track_N, 'b-', 'LineWidth', 2, 'DisplayName', 'Satellite Ground Track');
scatter(ax1, UE_local(:,1), UE_local(:,2), 40, 'ro', 'filled', 'DisplayName', 'UEs');
scatter(ax1, UE_local(center_idx,1), UE_local(center_idx,2), 80, 'ko', 'filled', 'DisplayName', 'Selected UE');
xlabel(ax1, 'East-West (km)'); ylabel(ax1, 'North-South (km)');
xlim(ax1, [-zoom_half_range_km, zoom_half_range_km]);
ylim(ax1, [-zoom_half_range_km, zoom_half_range_km]);
daspect(ax1, [1 1 1]); % enforce identical km-per-cm in both directions
legend(ax1, 'Location','northwest');
grid(ax1, 'on'); hold(ax1,'off');

% --- Right: Residual Doppler Shift for Selected UE (after per-beam pre-compensation) ---
ax2 = axes('Parent',fig,'Units','centimeters', ...
    'Position',[left_margin_cm+axes_size_cm+gap_cm bottom_margin_cm right_ax_width_cm right_ax_height_cm]);
tvec = (0:N_steps-1)*dt/60; % min
plot(ax2, tvec, abs(fD_residual_vec)/1e3, 'r-', 'LineWidth',2); hold(ax2,'on');
plot(ax2, tvec(visible_vec), abs(fD_residual_vec(visible_vec))/1e3, 'b.', 'MarkerSize',10);
ymax = max(abs(fD_residual_vec))/1e3 * 1.05;
% Annotate visible period
if any(visible_vec)
    visible_times = tvec(visible_vec);
    vis_start = visible_times(1); vis_end = visible_times(end);
    fill(ax2, [vis_start vis_end vis_end vis_start],[0 0 ymax ymax],'b','FaceAlpha',0.08,'EdgeColor','none');
end
xlabel(ax2, 'Time (min)');
ylabel(ax2, '|Residual Doppler Shift| (kHz)');
legend(ax2, 'Residual Doppler Shift','Visible Period','Visibility Window','Location','northwest');
grid(ax2, 'on'); hold(ax2,'off');

% Save as .eps (Encapsulated PostScript), preserving the 1cm=50km scale
set(fig,'PaperPositionMode','manual','PaperUnits','centimeters', ...
    'PaperSize',[fig_width_cm fig_height_cm],'PaperPosition',[0 0 fig_width_cm fig_height_cm]);
print(fig, 'LEO System Model','-depsc2');

%% --- Supporting Functions ---

function [UE_pos, UE_local] = generate_UE_positions(N_UE, area_size, Re, nadir_ref, e_east, e_north)
% Uniform random in a local East-North square centered on nadir_ref,
% projected onto Earth's surface.
UE_local = (rand(N_UE,2)-0.5)*area_size; % [E, N] offsets in meters
tangent_pts = nadir_ref + UE_local(:,1).*e_east + UE_local(:,2).*e_north;
UE_pos = Re * tangent_pts ./ vecnorm(tangent_pts, 2, 2); % project onto sphere
UE_local = UE_local / 1e3; % return in km
end

function [sat_pos, sat_vel] = generate_satellite_trajectory(N_steps, dt, sat_alt, incl, period, theta0)
% Returns ECEF positions and velocities for a single pass
Re = 6371e3; % Earth radius (m)
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

function visible = is_UE_visible(UE_pos, sat_pos, theta_min_elev, up_vec)
% Returns true if satellite above min elevation from UE, using the local
% vertical direction up_vec (valid across the local service area since
% its extent is small relative to Earth's radius).
vec_UE_sat = sat_pos - UE_pos; % from UE to sat
vertical = dot(vec_UE_sat, up_vec);
horizontal = norm(vec_UE_sat - vertical*up_vec);
elev_angle = atan2d(vertical, horizontal);
visible = elev_angle > theta_min_elev;
end

function fD = calculate_doppler(fc, c, v_rel, r_rel)
% Doppler shift for moving satellite relative to UE
r_hat = r_rel / norm(r_rel);
v_radial = dot(v_rel, r_hat);
fD = fc * v_radial / c;
end
