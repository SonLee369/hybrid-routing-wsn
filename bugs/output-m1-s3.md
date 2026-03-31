> > > Module 1 Step 3: Collecting LSTM Training Data

    Target: 10000 samples (10-step windows, 4 features)

Data collection run 1 / 2 ...
=== Network Initialized ===
Field : 500m x 500m
Nodes : 500 sensor nodes
Gateway : (250, 250)
Init Energy : 2.0 J per node
Channels : 10 (ON-OFF Markov)
===========================
Run 1 complete. Series shape: [500 x 500 x 5]

Data collection run 2 / 2 ...
=== Network Initialized ===
Field : 500m x 500m
Nodes : 500 sensor nodes
Gateway : (250, 250)
Init Energy : 2.0 J per node
Channels : 10 (ON-OFF Markov)
===========================
Run 2 complete. Series shape: [1000 x 500 x 5]

> > > Extracting 10000 training samples...
> > > Dataset built: 10000 samples x 10 time steps x 4 features

=== Dataset Summary ===
X shape : [10000 x 10 x 4] (samples x time_steps x features)
Y shape : [10000 x 1] (target: next-round energy)
Y range : [0.309133 to 1.996336] J
Y mean : 1.536374 J
=======================

Train samples : 8000 (80%)
Val samples : 2000 (20%)

Dataset saved to lstm_training_data.mat

> > > Step 3 complete. Ready for Module 1 Report writing.

    Next: Module 2 — EACO + DPAC Implementation

> >
