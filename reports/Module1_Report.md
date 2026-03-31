# Module 1 Report: Network Fundamentals & Telemetry Setup

**Project:** Hybrid Approach of Ant Colony System and Recurrent Neural Network for Energy Efficient Routing in Cognitive Wireless Sensor Networks

**Module:** 1 of 5 — Simulation Environment & Baseline Telemetry

---

## 1. Problem Statement

Cognitive Wireless Sensor Networks (CWSNs) are energy-constrained systems that must share spectrum with Licensed Users (LUs). Unlike traditional WSNs, sensor nodes in a CWSN operate as **secondary users** — they must continuously sense the spectrum, vacate busy channels, and reroute data around LU interference. This introduces two compounding challenges:

**Challenge 1 — Dynamic Spectrum Availability:**
Channels alternate between idle and busy states unpredictably. When a node's channel is occupied by a LU, it must switch spectrum mid-transmission, adding delay and potentially dropping packets. Conventional routing protocols have no mechanism to anticipate or adapt to these transitions.

**Challenge 2 — Uneven Energy Distribution:**
Standard cluster-based protocols such as LEACH select Cluster Heads (CHs) by random probability, with no regard for a node's remaining energy or its geographic position relative to the gateway. This causes two failure modes:
- Nodes far from the gateway, when elected as CH, burn disproportionately large amounts of energy transmitting long distances.
- Nodes that are repeatedly elected CH deplete faster than their neighbours, causing **premature node failure** while the rest of the network still has significant energy reserves.

The baseline simulation in this module confirms both failure modes with measured data, establishing the benchmark against which the hybrid EACO + LSTM model (Modules 2–4) will be compared.

---

## 2. Simulation Environment

### 2.1 Physical Topology

| Parameter | Value |
|-----------|-------|
| Field size | 500 m × 500 m (2D square) |
| Sensor nodes | 500, deployed randomly (uniform distribution) |
| Gateway (Base Station) | Fixed at centre: (250 m, 250 m) |
| Node mobility | None — static deployment to isolate routing efficacy |
| Independent runs | 20 (to ensure statistical consistency) |
| Simulation rounds | 500 per run |

Nodes are kept immobile so that performance differences between protocols are attributable purely to routing and energy management decisions, not physical movement.

### 2.2 Energy Model — First-Order Radio Model

Each sensor node is initialised with **2 Joules** of energy. Energy is consumed at every transmission and reception event according to the first-order radio model:

**Transmission energy (Equation 3 from paper):**
```
E_tx = E_elec × k + E_amp × k × r²
```

**Reception energy (Equation 4 from paper):**
```
E_rx = E_elec × k
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `E_init` | 2 J | Initial energy per node |
| `E_elec` | 50 nJ/bit | Electronics dissipation (TX & RX) |
| `E_amp` | 100 pJ/bit/m² | Amplification energy |
| `k` (packet size) | 4,000 bits | Data payload per packet |
| `E_thresh` | 0.001 J | Node declared dead below this |

The amplification term (`E_amp × k × r²`) grows quadratically with distance, meaning nodes elected as CH that must transmit long distances to the gateway pay a significantly higher energy cost than close-range member nodes. This asymmetry is a root cause of energy imbalance under LEACH.

### 2.3 Cognitive Spectrum Model — ON-OFF Markov Process

The cognitive behaviour of the network is modelled using a **binary ON-OFF Markov chain** per channel. At each simulation round, every node's channel transitions probabilistically between two states:

| State | Meaning | Action |
|-------|---------|--------|
| **Idle** | Channel free — no LU activity | Node transmits normally |
| **Busy** | Channel occupied by Licensed User | Node must switch channel (adds delay) |

**Transition probabilities:**

| Transition | Probability | Effect |
|------------|-------------|--------|
| Idle → Busy | `P_idle2busy = 0.30` | LU arrives; node forced to switch |
| Busy → Idle | `P_busy2idle = 0.60` | LU departs; channel becomes available |

With these parameters, the **steady-state probability** of a channel being idle is:

```
P(idle) = P_busy2idle / (P_idle2busy + P_busy2idle)
        = 0.60 / (0.30 + 0.60)
        = 0.667  (≈ 67% of channels available at any round)
```

The remaining ~33% of nodes at any given round face a spectrum-switching penalty, contributing directly to observed packet delay in the baseline measurements.

---

## 3. Baseline Protocol — Standard LEACH

Before introducing AI-driven optimisation, the network was simulated using the standard **LEACH (Low-Energy Adaptive Clustering Hierarchy)** protocol to establish baseline performance.

### 3.1 LEACH Operation

Each round follows three phases:

**Phase 1 — CH Election:**
Every alive node independently generates a random number. If that number falls below the fixed threshold `CH_PROB = 0.05`, the node declares itself a Cluster Head for that round. On average, **5% of alive nodes (≈ 25 nodes)** become CHs per round. Crucially, this selection is **blind to energy** — a node with 0.1 J remaining has the same chance as a node with 1.9 J.

**Phase 2 — Cluster Formation:**
Each non-CH node joins the geographically nearest alive CH, forming clusters based purely on proximity with no regard for load balancing.

**Phase 3 — Data Transmission:**
- Member nodes transmit one packet to their CH (if channel is idle).
- CHs aggregate received packets and forward one packet to the gateway (if channel is idle).
- Busy-channel nodes incur a 4.5 ms penalty delay per round.

### 3.2 Baseline Telemetry Results (20-Run Average)

| Metric | Result |
|--------|--------|
| Average first node death | **Round 393.4** (78.7% through simulation) |
| Average 50% node death | **Not reached** within 500 rounds |
| Final average residual energy | **1.090 J** (54.5% of initial 2 J remaining) |

### 3.3 Interpretation — The Energy Imbalance Problem

The most critical finding from the baseline is the **contrast between average energy and node deaths**:

- The network's average residual energy after 500 rounds is **1.090 J** — more than half the initial capacity is still stored across the network.
- Yet individual nodes begin failing at round **~393**, creating **network partitions** where entire areas lose coverage despite the network collectively having ample energy.

This demonstrates the core failure of LEACH: energy is not distributed equitably. Nodes randomly over-selected as CH, particularly those positioned far from the gateway, exhaust their batteries while their neighbours remain largely untouched. The result is:

1. **Premature node failure** — nodes die with energy still present in the network.
2. **Undetected high-drain nodes** — LEACH has no mechanism to forecast which nodes are approaching depletion.
3. **Spectrum-switching amplification** — when a CH's channel is busy, the entire cluster's data delivery is delayed, compounding the latency problem.

These are precisely the weaknesses that the EACO + LSTM hybrid addresses:
- **EACO** ensures CH selection is energy-aware and position-aware.
- **LSTM** predicts future energy depletion, allowing proactive re-routing before failure occurs.

---

## 4. Training Dataset for LSTM (Module 3)

To train the Long Short-Term Memory (LSTM) model that will be integrated in Module 3, a rich time-series dataset was harvested from the baseline simulation environment.

### 4.1 Collection Methodology

Two independent simulation runs (seeds 101 and 102) were executed with **per-node feature recording** at every round. This produced a raw time-series matrix of shape:

```
node_series: [1000 nodes × 500 rounds × 5 features]
```

From this matrix, **sliding windows of 10 consecutive time steps** were extracted per node, producing input-output pairs where:
- **Input X**: 10-step history of 4 node features
- **Output Y**: residual energy at the next round (prediction target)

### 4.2 Dataset Specification

| Property | Value |
|----------|-------|
| Total samples | 10,000 |
| Time steps per sample (lookback) | 10 |
| Features per time step | 4 |
| Train / Validation split | 8,000 / 2,000 (80% / 20%) |
| File | `lstm_training_data.mat` |

### 4.3 Features Recorded

| Feature | Description | Normalisation |
|---------|-------------|---------------|
| **Residual energy** | Node's remaining energy (J) | Raw value (0–2 J) |
| **Transmission load** | Packets sent this round (0 or 1) | Binary |
| **CH history** | Cumulative CH elections / round number | Normalised 0–1 |
| **Neighbourhood density** | Alive nodes within 100 m radius | Normalised by total nodes |

### 4.4 Target Variable Distribution

| Statistic | Value |
|-----------|-------|
| Y minimum | 0.309 J |
| Y maximum | 1.996 J |
| Y mean | 1.536 J |

The minimum target energy of **0.309 J** (not 0) confirms the dataset contains only samples from alive, active nodes. Dead nodes (energy ≤ 0.001 J) were excluded from collection, ensuring the LSTM learns the energy dynamics of operational nodes — the exact population it will need to manage in production.

---

## 5. Summary and Transition to Module 2

Module 1 has established:

1. A fully parameterised CWSN simulation environment (500 nodes, 500 m × 500 m, 2 J initial energy, ON-OFF Markov spectrum model).
2. Baseline LEACH telemetry confirming the energy imbalance problem: first node death at round 393 despite 54% average energy remaining.
3. A 10,000-sample LSTM training dataset (10-step windows, 4 features) ready for Module 3.

**Module 2** will replace the random LEACH CH election with the **Enhanced Ant Colony Optimisation (EACO)** algorithm, which uses a pheromone-based fitness function incorporating residual energy, node location, and traffic load to elect CHs intelligently. The **DPAC** protocol will then form clusters based on energy-weighted joining probabilities.

The baseline metrics recorded in this module (energy, throughput, delay, lifetime) will serve as the comparison reference for all subsequent modules.

---

*Report prepared for: Network Management Project — Module 1*
*Simulation tool: MATLAB | Runs: 20 | Rounds per run: 500*
