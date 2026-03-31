% =========================================================
% MODULE 1 - STEP 2: Baseline LEACH Protocol
% Standard LEACH: CH selected by random probability only.
% No energy-awareness, no AI. This is our baseline benchmark.
% =========================================================

function metrics = leach_baseline(net)

    CH_PROB = 0.05;     % Standard LEACH: 5% nodes become CH each round

    % --- Preallocate metric arrays ---
    metrics.residual_energy  = zeros(1, net.num_rounds);  % Avg energy (J)
    metrics.alive_nodes      = zeros(1, net.num_rounds);  % # alive nodes
    metrics.throughput       = zeros(1, net.num_rounds);  % Packets delivered
    metrics.packet_delay     = zeros(1, net.num_rounds);  % Avg delay (ms)
    metrics.first_dead_round = net.num_rounds;            % When 1st node dies
    metrics.half_dead_round  = net.num_rounds;            % When 50% nodes die

    nodes = net.nodes;  % Local copy of nodes for this run
    first_dead_logged = false;
    half_dead_logged  = false;

    % ===================== MAIN SIMULATION LOOP =====================
    for round = 1 : net.num_rounds

        % -- Update spectrum state (Markov channel transitions) --
        nodes = update_spectrum(nodes, net);

        % ---- PHASE 1: Cluster Head Election (Random Probability) ----
        CH_list = [];
        for i = 1 : net.num_nodes
            nodes(i).is_CH = false;
            if nodes(i).alive && rand() < CH_PROB
                nodes(i).is_CH = true;
                nodes(i).ch_history = nodes(i).ch_history + 1;
                CH_list(end+1) = i;
            end
        end

        % Fallback: if no CH elected, pick the node with most energy
        if isempty(CH_list)
            energies = arrayfun(@(n) n.energy * n.alive, nodes);
            [~, best] = max(energies);
            nodes(best).is_CH = true;
            nodes(best).ch_history = nodes(best).ch_history + 1;
            CH_list = best;
        end

        % ---- PHASE 2: Cluster Formation (join nearest CH) ----
        for i = 1 : net.num_nodes
            if ~nodes(i).alive || nodes(i).is_CH
                continue;
            end
            % Find nearest alive CH
            min_dist = inf;
            best_ch  = CH_list(1);
            for c = 1 : length(CH_list)
                ch_id = CH_list(c);
                if ~nodes(ch_id).alive, continue; end
                dx = nodes(i).x - nodes(ch_id).x;
                dy = nodes(i).y - nodes(ch_id).y;
                d  = sqrt(dx^2 + dy^2);
                if d < min_dist
                    min_dist = d;
                    best_ch  = ch_id;
                end
            end
            nodes(i).cluster_id = best_ch;
        end

        % ---- PHASE 3: Data Transmission ----
        packets_delivered = 0;
        total_delay       = 0;
        delay_count       = 0;

        % (a) Member nodes -> their CH
        for i = 1 : net.num_nodes
            if ~nodes(i).alive || nodes(i).is_CH
                continue;
            end
            ch_id = nodes(i).cluster_id;
            if ch_id == 0 || ~nodes(ch_id).alive
                continue;
            end

            % Only transmit if channel is idle (cognitive constraint)
            if strcmp(nodes(i).ch_state, 'idle')
                nodes = dissipate_energy_tx(nodes, i, ...
                    nodes(ch_id).x, nodes(ch_id).y, net);
                nodes = dissipate_energy_rx(nodes, ch_id, net);
                packets_delivered = packets_delivered + 1;

                % Delay model: proportional to distance (ms)
                dx = nodes(i).x - nodes(ch_id).x;
                dy = nodes(i).y - nodes(ch_id).y;
                d  = sqrt(dx^2 + dy^2);
                total_delay = total_delay + (d / 300) * 1000; % ms
                delay_count = delay_count + 1;
            else
                % Channel busy — spectrum switching penalty delay (ms)
                total_delay = total_delay + 4.5;
                delay_count = delay_count + 1;
            end
        end

        % (b) CH nodes -> Gateway (aggregated packet)
        for c = 1 : length(CH_list)
            ch_id = CH_list(c);
            if ~nodes(ch_id).alive, continue; end

            if strcmp(nodes(ch_id).ch_state, 'idle')
                nodes = dissipate_energy_tx(nodes, ch_id, ...
                    net.gateway.x, net.gateway.y, net);
                packets_delivered = packets_delivered + 1;

                dx = nodes(ch_id).x - net.gateway.x;
                dy = nodes(ch_id).y - net.gateway.y;
                d  = sqrt(dx^2 + dy^2);
                total_delay = total_delay + (d / 300) * 1000;
                delay_count = delay_count + 1;
            else
                total_delay = total_delay + 4.5;
                delay_count = delay_count + 1;
            end
        end

        % ---- PHASE 4: Collect Round Metrics ----
        alive_count    = sum([nodes.alive]);
        total_energy   = sum([nodes.energy]);
        avg_energy     = total_energy / net.num_nodes;
        avg_delay      = 0;
        if delay_count > 0
            avg_delay = total_delay / delay_count;
        end
        % Throughput: packets delivered per second -> scale to Mbps approx
        throughput_mbps = (packets_delivered * net.packet_size) / 1e6;

        metrics.residual_energy(round) = avg_energy;
        metrics.alive_nodes(round)     = alive_count;
        metrics.throughput(round)      = throughput_mbps;
        metrics.packet_delay(round)    = avg_delay;

        % Log first dead node round
        if ~first_dead_logged && alive_count < net.num_nodes
            metrics.first_dead_round = round;
            first_dead_logged = true;
        end

        % Log half-dead round
        if ~half_dead_logged && alive_count <= (net.num_nodes / 2)
            metrics.half_dead_round = round;
            half_dead_logged = true;
        end

        % Early exit if all nodes dead
        if alive_count == 0
            fprintf('  All nodes dead at round %d\n', round);
            break;
        end
    end

    % Store node final state
    metrics.final_nodes = nodes;
end
