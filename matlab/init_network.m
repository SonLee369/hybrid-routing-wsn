% =========================================================
% MODULE 1 - STEP 1: Network Initialization
% Project: Hybrid EACO + LSTM for Energy-Efficient Routing in CWSN
% =========================================================

function net = init_network()

    % --- Field Parameters ---
    net.field_x = 500;          % Field width  (meters)
    net.field_y = 500;          % Field height (meters)
    net.num_nodes = 500;        % Total sensor nodes
    net.num_rounds = 500;       % Total simulation rounds (seconds)
    net.num_runs   = 20;        % Independent runs for statistical consistency

    % --- Gateway (Base Station) - fixed at center ---
    net.gateway.x = net.field_x / 2;   % 250 m
    net.gateway.y = net.field_y / 2;   % 250 m

    % --- Energy Model (First-Order Radio Model) ---
    net.E_init   = 2;           % Initial energy per node (Joules)
    net.E_elec   = 50e-9;       % Electronics energy: 50 nJ/bit
    net.E_amp    = 100e-12;     % Amplification energy: 100 pJ/bit/m^2
    net.packet_size = 4000;     % Packet size in bits
    net.E_thresh = 0.001;       % Node considered dead below this (Joules)

    % --- Cognitive Spectrum Model (ON-OFF Markov Process) ---
    net.num_channels = 10;      % Number of available spectrum channels
    net.P_idle2busy  = 0.3;     % Prob: idle channel -> busy (LU arrives)
    net.P_busy2idle  = 0.6;     % Prob: busy channel -> idle (LU departs)
    % Note: Higher P_busy2idle means channels free up faster

    % --- Deploy Nodes Randomly ---
    net.nodes = deploy_nodes(net);

    fprintf('=== Network Initialized ===\n');
    fprintf('Field       : %dm x %dm\n', net.field_x, net.field_y);
    fprintf('Nodes       : %d sensor nodes\n', net.num_nodes);
    fprintf('Gateway     : (%.0f, %.0f)\n', net.gateway.x, net.gateway.y);
    fprintf('Init Energy : %.1f J per node\n', net.E_init);
    fprintf('Channels    : %d (ON-OFF Markov)\n', net.num_channels);
    fprintf('===========================\n');
end


% ---------------------------------------------------------
% Sub-function: Deploy sensor nodes randomly on the field
% ---------------------------------------------------------
function nodes = deploy_nodes(net)
    for i = 1 : net.num_nodes
        nodes(i).id          = i;
        nodes(i).x           = rand() * net.field_x;   % Random X position
        nodes(i).y           = rand() * net.field_y;   % Random Y position
        nodes(i).energy      = net.E_init;              % Full energy at start
        nodes(i).alive       = true;                    % Node is alive
        nodes(i).is_CH       = false;                   % Not a cluster head yet
        nodes(i).cluster_id  = 0;                       % Not assigned to cluster
        nodes(i).ch_history  = 0;                       % Times it was CH
        nodes(i).tx_load     = 0;                       % Transmission load counter
        nodes(i).channel     = randi(net.num_channels); % Assigned channel
        nodes(i).ch_state    = 'idle';                  % Channel starts idle
    end
end
