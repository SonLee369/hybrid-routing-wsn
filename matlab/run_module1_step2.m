% =========================================================
% MODULE 1 - STEP 2 RUNNER: Baseline LEACH Simulation
% Runs 20 independent trials, averages results, plots graphs
% =========================================================

clc; clear; close all;
addpath(pwd);

net = init_network();

fprintf('\n>>> Starting Baseline LEACH Simulation (%d runs)...\n', net.num_runs);

% Preallocate storage for all runs
all_energy    = zeros(net.num_runs, net.num_rounds);
all_alive     = zeros(net.num_runs, net.num_rounds);
all_throughput= zeros(net.num_runs, net.num_rounds);
all_delay     = zeros(net.num_runs, net.num_rounds);
first_dead    = zeros(1, net.num_runs);
half_dead     = zeros(1, net.num_runs);

for run = 1 : net.num_runs
    fprintf('  Run %2d / %d ...', run, net.num_runs);
    rng(run);  % Different seed each run for independence
    net_run = init_network();   % Fresh network per run
    m = leach_baseline(net_run);

    all_energy(run, :)     = m.residual_energy;
    all_alive(run, :)      = m.alive_nodes;
    all_throughput(run, :) = m.throughput;
    all_delay(run, :)      = m.packet_delay;
    first_dead(run)        = m.first_dead_round;
    half_dead(run)         = m.half_dead_round;
    fprintf(' done. First death: round %d\n', m.first_dead_round);
end

% --- Average across all 20 runs ---
avg_energy     = mean(all_energy, 1);
avg_alive      = mean(all_alive, 1);
avg_throughput = mean(all_throughput, 1);
avg_delay      = mean(all_delay, 1);

% --- Save baseline results for later comparison ---
baseline.avg_energy     = avg_energy;
baseline.avg_alive      = avg_alive;
baseline.avg_throughput = avg_throughput;
baseline.avg_delay      = avg_delay;
baseline.first_dead_avg = mean(first_dead);
baseline.half_dead_avg  = mean(half_dead);
baseline.rounds         = 1 : net.num_rounds;
save('baseline_results.mat', 'baseline');

fprintf('\n=== Baseline Summary ===\n');
fprintf('Avg First Node Death : Round %.1f\n', baseline.first_dead_avg);
fprintf('Avg 50%% Node Death   : Round %.1f\n', baseline.half_dead_avg);
fprintf('Final Avg Energy     : %.6f J\n', avg_energy(end));
fprintf('========================\n');

% ===================== PLOT BASELINE GRAPHS =====================
rounds = 1 : net.num_rounds;

figure('Name', 'Baseline LEACH - Residual Energy', 'NumberTitle', 'off');
plot(rounds, avg_energy, 'k-', 'LineWidth', 2);
xlabel('Simulation Time (sec / round)');
ylabel('Average Residual Energy (J)');
title('Energy Consumption vs Simulation Time - Baseline LEACH');
legend('LEACH Baseline');
grid on;

figure('Name', 'Baseline LEACH - Network Lifetime', 'NumberTitle', 'off');
alive_pct = (avg_alive / net.num_nodes) * 100;
plot(rounds, alive_pct, 'k-', 'LineWidth', 2);
xlabel('Simulation Time (sec / round)');
ylabel('Network Lifetime (% Alive Nodes)');
title('System Reliability vs Simulation Time - Baseline LEACH');
legend('LEACH Baseline');
grid on;

figure('Name', 'Baseline LEACH - Mean Throughput', 'NumberTitle', 'off');
plot(rounds, avg_throughput, 'k-', 'LineWidth', 2);
xlabel('Simulation Time (sec / round)');
ylabel('Mean Throughput (Mbps)');
title('Mean Throughput vs Simulation Time - Baseline LEACH');
legend('LEACH Baseline');
grid on;

figure('Name', 'Baseline LEACH - Packet Delay', 'NumberTitle', 'off');
plot(rounds, avg_delay, 'k-', 'LineWidth', 2);
xlabel('Simulation Time (sec / round)');
ylabel('Packet Delay (ms)');
title('Packet Delay vs Simulation Time - Baseline LEACH');
legend('LEACH Baseline');
grid on;

fprintf('\nBaseline graphs plotted. Results saved to baseline_results.mat\n');
fprintf('>>> Step 2 complete. Ready for Step 3: Training Data Collection.\n');
