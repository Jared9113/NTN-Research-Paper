function [msg_queue, orig_times] = generate_control_requests(N_UE, N_steps, dt, paging_lambda, reg_lambda)
% Independent Poisson arrival processes per UE for paging and
% registration requests (Eq. 14-16). paging_lambda/reg_lambda are mean
% arrival RATES in events/second/UE (e.g. 1/20 = one every 20 s on
% average). Uses inverse-transform sampling for exponential
% inter-arrival times (no Statistics Toolbox dependency).
%
% msg_queue columns: [msg_type, tidx, UE, torig, priority]
% msg_type: 1 = paging, 2 = registration
% priority: 2 = paging (higher), 1 = registration (lower)

sim_time = N_steps * dt;
msg_queue = zeros(0,5);

for u = 1:N_UE
    % Paging requests (msg_type = 1, priority = 2)
    t = -log(rand()) / paging_lambda;
    while t <= sim_time
        tidx = min(max(round(t/dt)+1, 1), N_steps);
        msg_queue(end+1,:) = [1, tidx, u, t, 2]; %#ok<AGROW>
        t = t - log(rand()) / paging_lambda;
    end

    % Registration requests (msg_type = 2, priority = 1)
    t = -log(rand()) / reg_lambda;
    while t <= sim_time
        tidx = min(max(round(t/dt)+1, 1), N_steps);
        msg_queue(end+1,:) = [2, tidx, u, t, 1]; %#ok<AGROW>
        t = t - log(rand()) / reg_lambda;
    end
end

orig_times = msg_queue(:,4);
end
