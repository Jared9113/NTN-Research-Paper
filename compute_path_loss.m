function PL = compute_path_loss(d, fc, c)
% Free-space path loss (Eq. 7): L(d)_dB = 20*log10(4*pi*d*fc/c) + Latm.
% Latm (atmospheric loss) is neglected, per the paper's own LoS
% simplification in Section II.B.
PL = 20*log10(4*pi*d*fc/c);
end
