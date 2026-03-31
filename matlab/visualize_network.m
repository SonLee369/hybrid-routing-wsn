% =========================================================
% MODULE 1 - STEP 3: Network Topology Visualization
% Run this after init_network() to see your deployment
% =========================================================

function visualize_network(net)

    figure('Name', 'CWSN Node Deployment', 'NumberTitle', 'off');
    hold on;

    % Plot sensor nodes
    for i = 1 : net.num_nodes
        if net.nodes(i).alive
            plot(net.nodes(i).x, net.nodes(i).y, 'b.', 'MarkerSize', 6);
        end
    end

    % Plot gateway (base station)
    plot(net.gateway.x, net.gateway.y, 'rp', ...
         'MarkerSize', 18, 'MarkerFaceColor', 'red');

    % Labels
    text(net.gateway.x + 8, net.gateway.y, 'Gateway', ...
         'Color', 'red', 'FontWeight', 'bold');

    xlim([0 net.field_x]);
    ylim([0 net.field_y]);
    xlabel('X Position (m)');
    ylabel('Y Position (m)');
    title('CWSN: 500 Sensor Nodes on 500m x 500m Field');
    legend('Sensor Nodes', 'Gateway (Base Station)', 'Location', 'northeast');
    grid on;
    hold off;

    fprintf('Topology plot generated.\n');
end
