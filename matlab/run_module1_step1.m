% =========================================================
% MODULE 1 - MAIN RUNNER (Step 1 Test)
% Run this file in MATLAB to verify network setup
% =========================================================

clc; clear; close all;

% Add matlab folder to path
addpath(pwd);

% Step 1: Initialize the network
net = init_network();

% Step 2: Visualize the deployment
visualize_network(net);

% Step 3: Test one round of spectrum update
net.nodes = update_spectrum(net.nodes, net);

% Count channel states after one round
idle_count = sum(strcmp({net.nodes.ch_state}, 'idle'));
busy_count = sum(strcmp({net.nodes.ch_state}, 'busy'));

fprintf('\n=== Spectrum State After Round 1 ===\n');
fprintf('Idle nodes (can transmit) : %d\n', idle_count);
fprintf('Busy nodes (LU occupied)  : %d\n', busy_count);
fprintf('====================================\n');

% Step 4: Verify node structure of first 3 nodes
fprintf('\n--- Sample Node Data (Node 1-3) ---\n');
for i = 1:3
    fprintf('Node %d | Pos:(%.1f,%.1f) | Energy:%.2fJ | Channel:%d | State:%s\n', ...
        net.nodes(i).id, net.nodes(i).x, net.nodes(i).y, ...
        net.nodes(i).energy, net.nodes(i).channel, net.nodes(i).ch_state);
end
