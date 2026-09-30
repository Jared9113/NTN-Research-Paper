function fading_dB = rician_fading_gain_dB(K_dB)
% Instantaneous Rician small-scale fading power gain, in dB, per Eq. 9
% (Section II.C): r(t) = sqrt(K/(K+1))*A + sqrt(1/(K+1))*X(t), with A the
% constant LOS component (unit amplitude) and X(t) ~ CN(0,1) the
% scattered component. Normalized so E[|r|^2]=1 (unit mean power), so
% this modulates instantaneous SNR around the nominal SNR0 without
% shifting its long-run average - draw once per attempt and add to
% SNR0_dB before calling per_from_doppler.
%
% K_dB = 7 for both NTN-TDL-C (Urban) and NTN-TDL-D (Hilly) per TR
% 38.811 Section 6.9.2, as already cited in the paper's Section II.C.
% NOTE: this is the single flat value the paper's own text commits to,
% not a continuous function of elevation angle - TR 38.811's full tables
% do vary K by elevation, but pulling exact per-elevation values wasn't
% done here to avoid citing table entries from memory without
% verification. If elevation-dependence is wanted, source concrete K
% values per elevation bin from TR 38.811 Table 6.9.2-4/6.9.2-5 directly.
K_lin = 10^(K_dB/10);
A = 1;
X = (randn + 1i*randn)/sqrt(2);
r = sqrt(K_lin/(K_lin+1))*A + sqrt(1/(K_lin+1))*X;
fading_dB = 10*log10(abs(r)^2);
end
