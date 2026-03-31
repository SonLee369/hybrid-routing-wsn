% =========================================================
% MODULE 1 - STEP 3: Per-Node Time-Series Data Collection
% Records 4 features per node per round for LSTM training:
%   1. Residual energy
%   2. Transmission load (packets sent this round)
%   3. CH history (cumulative times node was CH)
%   4. Neighborhood density (alive neighbors within 100m)
%      + distance to current CH
% =========================================================

function [node_series] = collect_training_data(net)
% Returns node_series(node_id, round, feature)
% Shape: [500 x num_rounds x 5]
%   Feature 1: residual_energy
%   Feature 2: tx_load_this_round
%   Feature 3: ch_history (normalized)
%   Feature 4: neighbor_density (alive nodes within 100m)
%   Feature 5: distance_to_CH (normalized)

    NEIGHBOR_RADIUS = 100;  % meters — sensing range for density
    CH_PROB = 0.05;

    N = net.num_nodes;
    R = net.num_rounds;

    % Pre-allocate: nodes x rounds x features
    node_series = zeros(N, R, 5);

    nodes = net.nodes;

    for round = 1 : R

        % Spectrum update
        nodes = update_spectrum(nodes, net);

        % --- CH Election (same as baseline LEACH) ---
        CH_list = [];
        for i = 1:N
            nodes(i).is_CH = false;
            if nodes(i).alive && rand() < CH_PROB
                nodes(i).is_CH = true;
                nodes(i).ch_history = nodes(i).ch_history + 1;
                CH_list(end+1) = i;
            end
        end
        if isempty(CH_list)
            energies = arrayfun(@(n) n.energy * n.alive, nodes);
            [~, best] = max(energies);
            nodes(best).is_CH = true;
            nodes(best).ch_history = nodes(best).ch_history + 1;
            CH_list = best;
        end

        % --- Cluster Formation ---
        dist_to_CH = zeros(1, N);
        for i = 1:N
            if ~nodes(i).alive || nodes(i).is_CH
                continue;
            end
            min_dist = inf;
            best_ch  = CH_list(1);
            for c = 1:length(CH_list)
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
            dist_to_CH(i) = min_dist;
        end
        % CHs: distance to gateway as their "dist_to_CH"
        for c = 1:length(CH_list)
            ch_id = CH_list(c);
            dx = nodes(ch_id).x - net.gateway.x;
            dy = nodes(ch_id).y - net.gateway.y;
            dist_to_CH(ch_id) = sqrt(dx^2 + dy^2);
        end

        % --- Compute Neighborhood Density ---
        neighbor_density = zeros(1, N);
        for i = 1:N
            if ~nodes(i).alive, continue; end
            count = 0;
            for j = 1:N
                if i == j || ~nodes(j).alive, continue; end
                dx = nodes(i).x - nodes(j).x;
                dy = nodes(i).y - nodes(j).y;
                if sqrt(dx^2 + dy^2) <= NEIGHBOR_RADIUS
                    count = count + 1;
                end
            end
            neighbor_density(i) = count;
        end

        % --- Data Transmission & TX Load Tracking ---
        tx_this_round = zeros(1, N);  % packets sent this round

        for i = 1:N
            if ~nodes(i).alive || nodes(i).is_CH, continue; end
            ch_id = nodes(i).cluster_id;
            if ch_id == 0 || ~nodes(ch_id).alive, continue; end
            if strcmp(nodes(i).ch_state, 'idle')
                nodes = dissipate_energy_tx(nodes, i, ...
                    nodes(ch_id).x, nodes(ch_id).y, net);
                nodes = dissipate_energy_rx(nodes, ch_id, net);
                tx_this_round(i) = 1;
            end
        end
        for c = 1:length(CH_list)
            ch_id = CH_list(c);
            if ~nodes(ch_id).alive, continue; end
            if strcmp(nodes(ch_id).ch_state, 'idle')
                nodes = dissipate_energy_tx(nodes, ch_id, ...
                    net.gateway.x, net.gateway.y, net);
                tx_this_round(ch_id) = 1;
            end
        end

        % --- Record Features for This Round ---
        max_dist = sqrt(net.field_x^2 + net.field_y^2);  % ~707m
        for i = 1:N
            node_series(i, round, 1) = nodes(i).energy;                         % residual energy
            node_series(i, round, 2) = tx_this_round(i);                         % tx load
            node_series(i, round, 3) = nodes(i).ch_history / max(round, 1);      % CH history (normalized)
            node_series(i, round, 4) = neighbor_density(i) / N;                  % density (normalized)
            node_series(i, round, 5) = dist_to_CH(i) / max_dist;                 % dist to CH (normalized)
        end

        if alive_check(nodes) == 0, break; end
    end
end

function count = alive_check(nodes)
    count = sum([nodes.alive]);
end
