function elev_deg = compute_elevation_deg(UE_pos, sat_pos)
% Elevation angle (deg) of the satellite as seen from UE_pos, using the
% UE's own local zenith direction (see is_UE_visible.m). Factored out as
% its own function since the zone-based baseline needs the actual angle
% value, not just the visibility boolean.
up_vec = UE_pos / norm(UE_pos);
vec_UE_sat = sat_pos - UE_pos;
vertical = dot(vec_UE_sat, up_vec);
horizontal = norm(vec_UE_sat - vertical*up_vec);
elev_deg = atan2d(vertical, horizontal);
end
