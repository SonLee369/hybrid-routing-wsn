% =========================================================
% MODULE 2 RUNNER: EACO + DPAC vs Baseline LEACH
% Runs 20 independent trials, then plots comparative graphs
% matching the paper's figures (Fig 1-4 style)
% =========================================================

clc; clear; close all;
addpath(pwd);

% Load baseline results from Module 1
load('baseline_results.mat');  % loads 'baseline' struct
rounds = baseline.rounds;

fprintf('>>> Module 2: EACO + DPAC Simulation (20 runs)...\n\n');

all_energy     = zeros(20, 500);
all_alive      = zeros(20, 500);
all_throughput = zeros(20, 500);
all_delay      = zeros(20, 500);
first_dead     = zeros(1, 20);
half_dead      = zeros(1, 20);

for run = 1 : 20
    fprintf('  Run %2d / 20 ...', run);
    rng(run + 200);   % Different seeds from Module 1 runs
    net = init_network();
    m   = eaco_dpac_simulation(net);

    all_energy(run, :)     = m.residual_energy;
    all_alive(run, :)      = m.alive_nodes;
    all_throughput(run, :) = m.throughput;
    all_delay(run, :)      = m.packet_delay;
    first_dead(run)        = m.first_dead_round;
    half_dead(run)         = m.half_dead_round;
    fprintf(' done. First death: round %d\n', m.first_dead_round);
end

% Average across 20 runs
eaco.avg_energy     = mean(all_energy, 1);
eaco.avg_alive      = mean(all_alive, 1);
eaco.avg_throughput = mean(all_throughput, 1);
eaco.avg_delay      = mean(all_delay, 1);
eaco.first_dead_avg = mean(first_dead);
eaco.half_dead_avg  = mean(half_dead);
eaco.rounds         = 1:500;

save('eaco_results.mat', 'eaco');

% =================== SUMMARY ===================
fprintf('\n========== Module 2 Summary ==========\n');
fprintf('                    LEACH     EACO+DPAC\n');
fprintf('First Node Death  : Rd %-5.0f   Rd %-5.0f\n', ...
    baseline.first_dead_avg, eaco.first_dead_avg);
fprintf('50%% Node Death    : Rd %-5.0f   Rd %-5.0f\n', ...
    baseline.half_dead_avg, eaco.half_dead_avg);
fprintf('Final Avg Energy  : %.4f J   %.4f J\n', ...
    baseline.avg_energy(end), eaco.avg_energy(end));
fprintf('Final Throughput  : %.2f Mb  %.2f Mb\n', ...
    baseline.avg_throughput(end), eaco.avg_throughput(end));
fprintf('=======================================\n');

% =================== PLOTS ===================

% Fig 1 style: Energy Consumption vs Simulation Time
figure('Name','Fig1 - Energy Consumption vs Time','NumberTitle','off');
plot(rounds, baseline.avg_energy, 'k--', 'LineWidth', 2); hold on;
plot(rounds, eaco.avg_energy,     'b-',  'LineWidth', 2);
xlabel('Simulation Time (sec)');
ylabel('Average Residual Energy (J)');
title('Energy Consumption vs Simulation Time');
legend('LEACH (Baseline)', 'EACO+DPAC (Proposed)', 'Location', 'northeast');
grid on; hold off;

% Fig 2 style: Network Lifetime (%) vs Simulation Time
figure('Name','Fig2 - Network Lifetime vs Time','NumberTitle','off');
baseline_pct = (baseline.avg_alive / 500) * 100;
eaco_pct     = (eaco.avg_alive / 500) * 100;
plot(rounds, baseline_pct, 'k--', 'LineWidth', 2); hold on;
plot(rounds, eaco_pct,     'b-',  'LineWidth', 2);
xlabel('Simulation Time (sec)');
ylabel('Network Lifetime (% Alive Nodes)');
title('System Reliability vs Simulation Time');
legend('LEACH (Baseline)', 'EACO+DPAC (Proposed)', 'Location', 'southwest');
grid on; hold off;

% Fig 3 style: Mean Throughput vs Simulation Time
figure('Name','Fig3 - Throughput vs Time','NumberTitle','off');
plot(rounds, baseline.avg_throughput, 'k--', 'LineWidth', 2); hold on;
plot(rounds, eaco.avg_throughput,     'b-',  'LineWidth', 2);
xlabel('Simulation Time (sec)');
ylabel('Mean Throughput (Mbps)');
title('Mean Throughput vs Simulation Time');
legend('LEACH (Baseline)', 'EACO+DPAC (Proposed)', 'Location', 'northwest');
grid on; hold off;

% Fig 4 style: Packet Delay vs Simulation Time
figure('Name','Fig4 - Packet Delay vs Time','NumberTitle','off');
plot(rounds, baseline.avg_delay, 'k--', 'LineWidth', 2); hold on;
plot(rounds, eaco.avg_delay,     'b-',  'LineWidth', 2);
xlabel('Simulation Time (sec)');
ylabel('Packet Delay (ms)');
title('Packet Delay vs Simulation Time');
legend('LEACH (Baseline)', 'EACO+DPAC (Proposed)', 'Location', 'northeast');
grid on; hold off;

fprintf('\nComparative graphs plotted. Results saved to eaco_results.mat\n');
fprintf('>>> Module 2 complete. Ready for Module 3: LSTM Integration.\n');
