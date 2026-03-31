% =========================================================
% MODULE 2 - STEP 1: Enhanced Ant Colony Optimization (EACO)
% CH selection using adaptive pheromone + energy-aware heuristic
%
% Fitness function (Equation 1 from paper):
%   P_i = (tau_j^alpha)(eta_j^beta)(E_j^gamma)
%         / SUM_{j in N} (tau_j^alpha)(eta_j^beta)(E_j^gamma)
%
% Where:
%   tau   = pheromone level (rotation memory — resets after CH service)
%   eta   = heuristic: normalized residual energy
%   E     = lasting power: energy adjusted for cumulative TX workload
%   alpha, beta, gamma = tuning parameters
% =========================================================

function [CH_list, pheromone] = eaco_ch_selection(nodes, net, pheromone, curr_round)

    % --- EACO Tuning Parameters ---
    ALPHA   = 1.0;   % Pheromone influence weight
    BETA    = 2.0;   % Residual energy heuristic weight
    GAMMA   = 1.5;   % Lasting power weight
    RHO     = 0.1;   % Pheromone evaporation rate
    TAU_MIN = 0.01;  % Pheromone floor (avoid zero probability)
    TAU_MAX = 5.0;   % Pheromone ceiling (avoid one node dominating)
    TARGET_CH = max(1, round(0.05 * sum([nodes.alive])));  % ~5% alive nodes

    N = net.num_nodes;

    % --- Step 1: Pheromone Evaporation ---
    pheromone = pheromone * (1 - RHO);
    pheromone = max(pheromone, TAU_MIN);

    % --- Step 2: Compute Fitness Score ---
    fitness = zeros(1, N);

    for i = 1 : N
        if ~nodes(i).alive
            fitness(i) = 0;
            continue;
        end

        % tau: current pheromone level (rotation eligibility)
        tau = pheromone(i);

        % eta: normalized residual energy — core energy-aware heuristic
        eta = nodes(i).energy / net.E_init;

        % E_lasting: "lasting power" — how long can this node sustain CH duty?
        % Penalize nodes with high cumulative TX load relative to their energy.
        % Nodes that have transmitted a lot but have little energy left
        % are poor CH candidates even if current energy looks adequate.
        avg_tx = nodes(i).tx_load / max(curr_round, 1);   % avg packets/round
        E_lasting = nodes(i).energy / (1 + avg_tx);

        % Fitness = Equation 1 from paper
        fitness(i) = (tau^ALPHA) * (eta^BETA) * (E_lasting^GAMMA);
    end

    % Normalize to probability distribution
    total_fitness = sum(fitness);
    if total_fitness == 0
        energies = arrayfun(@(n) n.energy * n.alive, nodes);
        [~, best] = max(energies);
        CH_list = best;
        return;
    end
    prob = fitness / total_fitness;

    % --- Step 3: Roulette Wheel CH Selection ---
    alive_ids  = find([nodes.alive]);
    CH_list    = [];
    candidates = alive_ids;

    for k = 1 : min(TARGET_CH, length(candidates))
        if isempty(candidates), break; end

        sub_prob = prob(candidates);
        sub_prob = sub_prob / sum(sub_prob);
        cumprob  = cumsum(sub_prob);
        r        = rand();
        idx      = find(cumprob >= r, 1, 'first');
        if isempty(idx), idx = length(candidates); end

        chosen = candidates(idx);
        CH_list(end+1) = chosen;
        candidates(candidates == chosen) = [];
    end

    % Mark elected CHs
    for i = 1:N
        nodes(i).is_CH = false;
    end
    for c = CH_list
        nodes(c).is_CH      = true;
        nodes(c).ch_history = nodes(c).ch_history + 1;
    end

    % --- Step 4: Pheromone Update (Rotation Mechanism) ---
    % Elected CHs: reset to TAU_MIN — they just served, step aside
    for c = CH_list
        pheromone(c) = TAU_MIN;
    end

    % Non-CH alive nodes: deposit proportional to residual energy
    % High-energy rested nodes accumulate faster -> natural energy-driven rotation
    for i = 1 : N
        if ~nodes(i).alive || nodes(i).is_CH, continue; end
        deposit = 0.15 * (nodes(i).energy / net.E_init);
        pheromone(i) = min(pheromone(i) + deposit, TAU_MAX);
    end

    % Hard floor: critically low-energy nodes cannot be CH
    for i = 1 : N
        if nodes(i).alive && nodes(i).energy < (0.15 * net.E_init)
            pheromone(i) = TAU_MIN;
        end
    end
end
