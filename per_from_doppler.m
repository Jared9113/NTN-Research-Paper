function PER = per_from_doppler(fD_residual, SNR0_dB, delta_f_SCS, L_bits)
% Analytical Doppler-to-PER mapping (Section II.E, Eq. D-1--D-3):
% closed-form SNR degradation from residual CFO in OFDM, QPSK/AWGN BER,
% converted to a block PER via the control-message length L_bits.
% fD_residual must be RESIDUAL Doppler (post per-beam pre-compensation),
% not raw Doppler - see LEO_NTN_system_model.m / simulate_DAARS_run.m.
epsilon = fD_residual / delta_f_SCS;
if abs(epsilon) < 1e-12
    s = 1;
else
    s = sin(pi*epsilon) / (pi*epsilon);
end
SNR0_lin = 10^(SNR0_dB/10);
D = 1 + SNR0_lin * (1/s^2 - 1);
D_dB = 10*log10(D);
SNR_eff_dB = SNR0_dB - D_dB;
BER = 0.5 * erfc(sqrt(10^(SNR_eff_dB/10)));
PER = 1 - (1 - BER)^L_bits;
end
