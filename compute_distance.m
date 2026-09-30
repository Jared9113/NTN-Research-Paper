function d = compute_distance(sat_pos, UE_pos)
% Euclidean slant range between satellite and UE (m)
d = norm(sat_pos - UE_pos);
end
