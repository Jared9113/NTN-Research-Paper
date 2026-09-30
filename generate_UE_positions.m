function UE_pos = generate_UE_positions(N_UE, area_size)
% Randomly generate positions on Earth's surface, centered on the
% sub-satellite/beam-center reference (0,0,Re).
% Output: [N_UE x 3] array (x, y, z)
Re = 6371e3; % Earth radius (m)
xy = area_size*(rand(N_UE,2)-0.5);
z = sqrt(Re^2 - sum(xy.^2,2));
UE_pos = [xy, z];
end
