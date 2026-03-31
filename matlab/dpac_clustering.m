% =========================================================
% MODULE 2 - STEP 2: Decentralized Power-Aware Clustering (DPAC)
%
% Joining probability (Equation 2 from paper):
%   P_i = E_i / E_network
%
% Where:
%   E_i       = residual energy of node i
%   E_network = average energy of all alive nodes
%
% Each non-CH node joins the CH that maximises a combined
% score of energy-weighted probability AND proximity.
% =========================================================

function nodes = dpac_clustering(nodes, CH_list, net)

    N = net.num_nodes;

    % --- Compute E_network: average energy of all alive nodes ---
    alive_energies = [nodes([nodes.alive]).energy];
    if isempty(alive_energies)
        return;
    end
    E_network = mean(alive_energies);

    % --- Assign each non-CH node to best CH ---
    for i = 1 : N
        if ~nodes(i).alive || nodes(i).is_CH
            continue;
        end

        % DPAC joining probability for node i (Equation 2)
        % Higher residual energy -> higher probability of being detected as CH
        % (used here as a weight for preferring energy-rich CHs)
        P_i = nodes(i).energy / E_network;

        best_ch    = -1;
        best_score = -inf;

        for c = 1 : length(CH_list)
            ch_id = CH_list(c);
            if ~nodes(ch_id).alive, continue; end

            % Distance from node i to this CH
            dx   = nodes(i).x - nodes(ch_id).x;
            dy   = nodes(i).y - nodes(ch_id).y;
            dist = sqrt(dx^2 + dy^2) + 1e-6;  % +epsilon avoids div-by-zero

            % CH fitness: strong distance^2 penalty ensures members join
            % the nearest viable CH (minimises member TX energy cost).
            % ch_energy_ratio provides a secondary preference for healthier CHs.
            ch_energy_ratio = nodes(ch_id).energy / E_network;
            score = ch_energy_ratio / (dist^2);

            if score > best_score
                best_score = score;
                best_ch    = ch_id;
            end
        end

        if best_ch ~= -1
            nodes(i).cluster_id = best_ch;
        end
    end

    % CHs are their own cluster head
    for c = CH_list
        nodes(c).cluster_id = c;
    end
end
