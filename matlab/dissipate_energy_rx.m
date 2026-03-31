% =========================================================
% Reception Energy Dissipation (First-Order Radio Model)
% E_rx = E_elec * k
% =========================================================

function nodes = dissipate_energy_rx(nodes, receiver_id, net)

    if ~nodes(receiver_id).alive
        return;
    end

    k    = net.packet_size;
    E_rx = net.E_elec * k;
    nodes(receiver_id).energy = nodes(receiver_id).energy - E_rx;

    if nodes(receiver_id).energy <= net.E_thresh
        nodes(receiver_id).alive  = false;
        nodes(receiver_id).energy = 0;
    end
end
