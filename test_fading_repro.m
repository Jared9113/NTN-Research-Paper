clc; clear;
fprintf('which rician_fading_dB: '); which('rician_fading_dB')
fprintf('exist rician_fading_dB: %d\n', exist('rician_fading_dB'));
fprintf('pwd: %s\n', pwd);
try
    stats = simulate_FRS_run(60,0.1,600,50,100e3, ...
        2e9,3e8,1200e3,87.9,108*60,10,1e-3,8, ...
        1/20,1/450,2,195,[],[]);
    fprintf('simulate_FRS_run SUCCEEDED: success_rate=%.4f\n', stats.success_rate);
catch ME
    fprintf('simulate_FRS_run FAILED: %s\n', ME.message);
end
