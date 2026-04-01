% =========================================================
% hybrid_simulation.m
% Module 4 — Full Hybrid: EACO + LSTM Prediction + DPAC
%
% Extends eaco_dpac_simulation with per-round LSTM energy
% forecasting. Nodes predicted to deplete soon are excluded
% from EACO's CH candidate pool before election.
%
% Usage:
%   metrics = hybrid_simulation(net, lstm_params, norm_params)
% =========================================================

function metrics = hybrid_simulation(net, lstm_params, norm_params)

    N = net.num_nodes;
    R = net.num_rounds;

    % LSTM integration settings
    LSTM_WARMUP = 10;               % rounds before LSTM activates
    LSTM_THRESH = 0.25 * net.E_init; % exclude if predicted E < 0.5 J

    % --- Preallocate metrics ---
    metrics.residual_energy  = zeros(1, R);
    metrics.alive_nodes      = zeros(1, R);
    metrics.throughput       = zeros(1, R);
    metrics.packet_delay     = zeros(1, R);
    metrics.first_dead_round = R;
    metrics.half_dead_round  = R;

    % --- Initialise pheromone ---
    pheromone = ones(1, N);

    nodes = net.nodes;
    first_dead_logged = false;
    half_dead_logged  = false;

    % --- Precompute pairwise distance matrix (positions are static) ---
    px = [nodes.x]';   py = [nodes.y]';          % [N x 1]
    D  = sqrt((px - px').^2 + (py - py').^2);    % [N x N]

    % --- Rolling feature history buffer  [N x 10 x 4] ---
    % Features: [energy, did_tx, ch_history_rate, density]
    hist_buf = zeros(N, 10, 4);
    did_tx   = zeros(N, 1);   % tracks which nodes transmitted last round

    % =================== MAIN SIMULATION LOOP ===================
    for round_num = 1 : R

        % -- Cognitive spectrum update --
        nodes = update_spectrum(nodes, net);

        %% ---- LSTM: Update history buffer ----
        alive_mask = [nodes.alive];                          % [1 x N]
        density    = sum(D <= 100 & repmat(alive_mask,N,1), 2) / N; % [N x 1]

        for i = 1 : N
            feat = [nodes(i).energy, ...
                    did_tx(i), ...
                    nodes(i).ch_history / max(round_num-1, 1), ...
                    density(i)];
            hist_buf(i, 1:9, :) = hist_buf(i, 2:10, :);   % shift left
            hist_buf(i, 10,  :) = feat;                     % append
        end

        %% ---- LSTM Exclusion (after warmup) ----
        lstm_excluded = false(N, 1);

        if round_num > LSTM_WARMUP
            E_pred = lstm_predict(lstm_params, norm_params, hist_buf);
            for i = 1 : N
                if nodes(i).alive && E_pred(i) < LSTM_THRESH
                    lstm_excluded(i) = true;
                end
            end
        end

        %% ---- PHASE 1: EACO — with LSTM exclusion ----
        % Temporarily zero energy of excluded nodes so EACO ignores them
        saved_energy = zeros(N, 1);
        for i = 1 : N
            if lstm_excluded(i)
                saved_energy(i)  = nodes(i).energy;
                nodes(i).energy  = 0;
            end
        end

        [CH_list, pheromone] = eaco_ch_selection(nodes, net, pheromone, round_num);

        % Restore energies
        for i = 1 : N
            if lstm_excluded(i)
                nodes(i).energy = saved_energy(i);
            end
        end

        %% ---- PHASE 2: DPAC — cluster formation ----
        % Mark CHs on the working nodes struct
        for i = 1 : N;  nodes(i).is_CH = false;  end
        for c = CH_list; nodes(c).is_CH = true;   end

        nodes = dpac_clustering(nodes, CH_list, net);

        %% ---- PHASE 3: Data Transmission ----
        packets_delivered = 0;
        total_delay       = 0;
        delay_count       = 0;
        did_tx(:)         = 0;   % reset for this round

        % (a) Member nodes -> their CH
        for i = 1 : N
            if ~nodes(i).alive || nodes(i).is_CH, continue; end
            ch_id = nodes(i).cluster_id;
            if ch_id <= 0 || ~nodes(ch_id).alive, continue; end

            if strcmp(nodes(i).ch_state, 'idle')
                nodes = dissipate_energy_tx(nodes, i, ...
                    nodes(ch_id).x, nodes(ch_id).y, net);
                nodes = dissipate_energy_rx(nodes, ch_id, net);
                packets_delivered = packets_delivered + 1;
                did_tx(i)         = 1;

                dx = nodes(i).x - nodes(ch_id).x;
                dy = nodes(i).y - nodes(ch_id).y;
                total_delay = total_delay + (sqrt(dx^2+dy^2)/300)*1000;
                delay_count = delay_count + 1;
            else
                total_delay = total_delay + 4.5;
                delay_count = delay_count + 1;
            end
        end

        % (b) CH nodes -> Gateway
        for c = 1 : length(CH_list)
            ch_id = CH_list(c);
            if ~nodes(ch_id).alive, continue; end

            if strcmp(nodes(ch_id).ch_state, 'idle')
                nodes = dissipate_energy_tx(nodes, ch_id, ...
                    net.gateway.x, net.gateway.y, net);
                packets_delivered = packets_delivered + 1;
                did_tx(ch_id)     = 1;

                dx = nodes(ch_id).x - net.gateway.x;
                dy = nodes(ch_id).y - net.gateway.y;
                total_delay = total_delay + (sqrt(dx^2+dy^2)/300)*1000;
                delay_count = delay_count + 1;
            else
                total_delay = total_delay + 4.5;
                delay_count = delay_count + 1;
            end
        end

        %% ---- PHASE 4: Record Metrics ----
        alive_count = sum([nodes.alive]);
        metrics.residual_energy(round_num) = sum([nodes.energy]) / N;
        metrics.alive_nodes(round_num)     = alive_count;
        metrics.throughput(round_num)      = (packets_delivered * net.packet_size) / 1e6;
        metrics.packet_delay(round_num)    = 0;
        if delay_count > 0
            metrics.packet_delay(round_num) = total_delay / delay_count;
        end

        if ~first_dead_logged && alive_count < N
            metrics.first_dead_round = round_num;
            first_dead_logged = true;
        end
        if ~half_dead_logged && alive_count <= (N/2)
            metrics.half_dead_round = round_num;
            half_dead_logged = true;
        end
        if alive_count == 0
            fprintf('  All nodes dead at round %d\n', round_num);
            break;
        end
    end

    metrics.final_nodes = nodes;
end
