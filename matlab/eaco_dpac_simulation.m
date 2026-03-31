% =========================================================
% MODULE 2 - STEP 3: Full EACO + DPAC Simulation
% Replaces random LEACH CH election with EACO fitness-based
% selection, and proximity-only clustering with DPAC.
% =========================================================

function metrics = eaco_dpac_simulation(net)

    N = net.num_nodes;
    R = net.num_rounds;

    % --- Preallocate metrics ---
    metrics.residual_energy  = zeros(1, R);
    metrics.alive_nodes      = zeros(1, R);
    metrics.throughput       = zeros(1, R);
    metrics.packet_delay     = zeros(1, R);
    metrics.first_dead_round = R;
    metrics.half_dead_round  = R;

    % --- Initialize pheromone trails (one per node) ---
    % All nodes start equal — EACO learns over time
    pheromone = ones(1, N);

    nodes = net.nodes;
    first_dead_logged = false;
    half_dead_logged  = false;

    % =================== MAIN SIMULATION LOOP ===================
    for round_num = 1 : R

        % -- Cognitive spectrum update --
        nodes = update_spectrum(nodes, net);

        % ---- PHASE 1: EACO — Energy-Aware CH Election ----
        [CH_list, pheromone] = eaco_ch_selection(nodes, net, pheromone, round_num);

        % ---- PHASE 2: DPAC — Power-Aware Cluster Formation ----
        nodes = dpac_clustering(nodes, CH_list, net);

        % ---- PHASE 3: Data Transmission ----
        packets_delivered = 0;
        total_delay       = 0;
        delay_count       = 0;

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

                dx = nodes(i).x - nodes(ch_id).x;
                dy = nodes(i).y - nodes(ch_id).y;
                d  = sqrt(dx^2 + dy^2);
                total_delay = total_delay + (d / 300) * 1000;
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

        % ---- PHASE 4: Collect Metrics ----
        alive_count     = sum([nodes.alive]);
        avg_energy      = sum([nodes.energy]) / N;
        throughput_mbps = (packets_delivered * net.packet_size) / 1e6;
        avg_delay       = 0;
        if delay_count > 0
            avg_delay = total_delay / delay_count;
        end

        metrics.residual_energy(round_num) = avg_energy;
        metrics.alive_nodes(round_num)     = alive_count;
        metrics.throughput(round_num)      = throughput_mbps;
        metrics.packet_delay(round_num)    = avg_delay;

        if ~first_dead_logged && alive_count < N
            metrics.first_dead_round = round_num;
            first_dead_logged = true;
        end
        if ~half_dead_logged && alive_count <= (N / 2)
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
