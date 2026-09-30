function fD = calculate_doppler(fc, c, v_rel, r_rel)
% Doppler shift for moving satellite relative to UE (Eq. 10)
r_hat = r_rel / norm(r_rel);
v_radial = dot(v_rel, r_hat);
fD = fc * v_radial / c;
end
