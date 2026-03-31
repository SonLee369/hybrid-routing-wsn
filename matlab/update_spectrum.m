% =========================================================
% MODULE 1 - STEP 2: ON-OFF Markov Spectrum Model
% Updates channel states each round based on transition probabilities
% =========================================================

function nodes = update_spectrum(nodes, net)
% Each node's channel flips between 'idle' and 'busy' using the
% Markov transition matrix defined in init_network.

    for i = 1 : length(nodes)
        if ~nodes(i).alive
            continue;
        end

        r = rand();  % Random draw [0, 1]

        if strcmp(nodes(i).ch_state, 'idle')
            % Idle -> Busy with probability P_idle2busy
            if r < net.P_idle2busy
                nodes(i).ch_state = 'busy';
                % Node must switch to a different free channel
                nodes(i).channel  = randi(net.num_channels);
            end
            % else stays idle — can transmit normally

        else  % Currently busy
            % Busy -> Idle with probability P_busy2idle
            if r < net.P_busy2idle
                nodes(i).ch_state = 'idle';
            end
            % else stays busy — LU still occupying channel
        end
    end
end
