> > > Module 2: EACO + DPAC Simulation (20 runs)...

Run 1 / 20 ...=== Network Initialized ===
Field : 500m x 500m
Nodes : 500 sensor nodes
Gateway : (250, 250)
Init Energy : 2.0 J per node
Channels : 10 (ON-OFF Markov)
===========================
Index exceeds the number of array elements (1).

Error in eaco_ch_selection (line 25)
TARGET_CH = max(1, round(0.05 \* sum([nodes.alive]))); %
~5% alive nodes

Error in eaco_dpac_simulation (line 35)
[CH_list, pheromone] = eaco_ch_selection(nodes, net,
pheromone, round);

Error in run_module2 (line 27)
m = eaco_dpac_simulation(net);

> >
