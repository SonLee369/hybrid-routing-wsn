% =========================================================
% Transmission Energy Dissipation (First-Order Radio Model)
% E_tx = E_elec * k + E_amp * k * r^2
% =========================================================

function nodes = dissipate_energy_tx(nodes, sender_id, receiver_x, receiver_y, net)

    if ~nodes(sender_id).alive
        return;
    end

    dx  = nodes(sender_id).x - receiver_x;
    dy  = nodes(sender_id).y - receiver_y;
    r   = sqrt(dx^2 + dy^2);
    k   = net.packet_size;

    E_tx = (net.E_elec * k) + (net.E_amp * k * r^2);
    nodes(sender_id).energy  = nodes(sender_id).energy - E_tx;
    nodes(sender_id).tx_load = nodes(sender_id).tx_load + 1;

    if nodes(sender_id).energy <= net.E_thresh
        nodes(sender_id).alive  = false;
        nodes(sender_id).energy = 0;
    end
end
