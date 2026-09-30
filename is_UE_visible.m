function visible = is_UE_visible(UE_pos, sat_pos, theta_min_elev)
% Returns true if satellite above min elevation from UE.
%
% Reviewer 1 (Eq. 5) flagged that global Z is not generally the UE's
% local zenith direction. Previously this function used global Z as
% "up" for every UE, an approximation only valid for UEs very close to
% the beam center (0,0,Re) - fine at the paper's 100km service area
% (max tilt ~0.6 deg at the corners) but not at wider areas (e.g. our
% own 800km investigation: up to ~5 deg tilt at the corners, silently
% biasing every elevation-gated result there on top of the Doppler
% pre-compensation issue that was flagged at the time).
%
% Fix: use each UE's OWN local zenith (UE_pos/norm(UE_pos), i.e. the
% radial direction from Earth's center through that UE), which is
% exact for any UE on Earth's surface regardless of position - no
% shared reference point or extra parameter needed. Factored out into
% compute_elevation_deg.m since the zone-based baseline also needs the
% angle value itself, not just this boolean.
elev_angle_deg = compute_elevation_deg(UE_pos, sat_pos);
visible = elev_angle_deg > theta_min_elev;
end
