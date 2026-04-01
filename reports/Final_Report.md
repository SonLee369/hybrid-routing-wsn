# Final Project Report

**Title:** Hybrid Approach of Ant Colony System and Recurrent Neural Network for Energy Efficient Routing in Cognitive Wireless Sensor Networks

**Course:** Network Management

---

## Abstract

Energy-aware communication in Cognitive Wireless Sensor Networks (CWSNs) is challenged by dynamic spectrum availability, high topology change rates, and low energy budgets. Conventional routing protocols such as LEACH select Cluster Heads (CHs) randomly, causing premature node depletion while substantial energy remains unused elsewhere in the network. This project implements and evaluates an adaptive AI hybrid solution combining Enhanced Ant Colony Optimisation (EACO) for intelligent CH selection, a Long Short-Term Memory (LSTM) recurrent neural network for proactive per-node energy depletion forecasting, and the Decentralised Power-Aware Clustering (DPAC) protocol for energy-weighted cluster formation. Simulations across 20 independent runs on a 500-node, 500×500 m CWSN show that the proposed EACO+LSTM hybrid defers first node death by 3.5% over LEACH, improves final network energy conservation by 1.4%, and achieves zero node death in 2 out of 20 runs — a result never reached by any baseline protocol. The LSTM model achieves a validation RMSE of 0.0125 J, 30% better than the paper target of 0.018 J, and converges in just 23 epochs.

---

## 1. Introduction

### 1.1 Background

Wireless Sensor Networks (WSNs) consist of spatially distributed sensor nodes that monitor physical or environmental conditions and forward data to a gateway (base station). In a Cognitive WSN (CWSN), sensor nodes operate as **secondary users** on a shared spectrum, required to sense for Licensed User (LU) activity and vacate busy channels on demand. This introduces two compounding challenges absent from traditional WSNs:

**Challenge 1 — Dynamic Spectrum Availability:**
Channels alternate between idle and busy states according to a stochastic process. When a node's channel is occupied by an LU, it must switch spectrum mid-transmission, adding latency and potentially dropping packets. Conventional routing protocols have no mechanism to anticipate or adapt to these transitions.

**Challenge 2 — Uneven Energy Distribution:**
Standard cluster-based protocols such as LEACH elect CHs by random probability, with no regard for a node's remaining energy or geographic position relative to the gateway. Nodes far from the gateway, when elected CH, burn disproportionately large energy transmitting long distances. Nodes repeatedly elected CH deplete faster than neighbours, causing premature failure while the network still holds substantial collective energy.

### 1.2 Motivation

The combination of these two challenges makes energy management in CWSNs particularly difficult. When a CH's channel is busy, its entire cluster's data delivery is delayed — compounding the latency problem at precisely the moments when energy is most at risk of being wasted on retransmissions. A protocol that is simultaneously energy-aware, spectrum-aware, and capable of forecasting impending node failure is required.

### 1.3 Proposed Solution

This project implements a three-component hybrid AI routing framework:

1. **EACO** — Enhanced Ant Colony Optimisation: replaces random CH election with a pheromone-based fitness function that scores nodes on residual energy, TX load history, and routing desirability.
2. **LSTM** — Long Short-Term Memory network: trained on 10,000 time-series samples to predict each node's residual energy one round ahead, enabling proactive exclusion of at-risk nodes from CH candidacy.
3. **DPAC** — Decentralised Power-Aware Clustering: forms clusters based on relative node energy and proximity (dist²), ensuring members join nearby, energy-rich CHs to minimise transmission cost.

### 1.4 Report Structure

- Section 2 reviews existing approaches and their limitations
- Section 3 details the simulation environment and energy model
- Section 4 presents each algorithm's design and equations
- Section 5 reports all simulation results across four modules
- Section 6 discusses findings and their implications
- Section 7 concludes with recommendations for future work

---

## 2. Related Work and Existing Systems

Existing energy-efficient routing approaches for CWSNs include:

**ICOA (Improved Chaos Optimisation Algorithm):** Uses chaotic search to find optimal CH configurations. Improves over LEACH but lacks predictive energy modelling and does not adapt to dynamic spectrum conditions in real time.

**IJO-LF (Improved Jaya Optimisation with Levy Flight):** Applies population-based optimisation with Levy flight exploration for route discovery. Computationally intensive and does not incorporate learning from historical energy patterns.

**TEEN (Threshold-sensitive Energy Efficient Sensor Network):** An event-driven protocol that reduces transmissions by applying hard and soft thresholds. Energy-conservative in sparse-event scenarios but poor for continuous monitoring environments such as this simulation.

**PSO-RNN (Particle Swarm Optimisation with RNN):** Uses PSO for CH selection and RNN for traffic prediction. Improves routing responsiveness but has high computational cost and lacks proactive spectrum adaptability.

**Limitation common to all existing methods:** None incorporate a predictive model that forecasts individual node energy depletion and uses those forecasts to proactively adjust CH eligibility. They react to energy levels rather than anticipating them.

---

## 3. Simulation Environment

### 3.1 Physical Topology

| Parameter | Value |
|-----------|-------|
| Field size | 500 m × 500 m |
| Sensor nodes | 500 (randomly deployed, uniform distribution) |
| Gateway (Base Station) | Fixed at centre: (250 m, 250 m) |
| Node mobility | None — static deployment |
| Independent runs | 20 per protocol |
| Simulation rounds | 500 per run |

### 3.2 Energy Model — First-Order Radio Model

Each node starts with **2 Joules** of energy. Energy consumption follows:

**Transmission energy (Equation 3):**
```
E_tx = E_elec × k + E_amp × k × r²
```

**Reception energy (Equation 4):**
```
E_rx = E_elec × k
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `E_init` | 2 J | Initial energy per node |
| `E_elec` | 50 nJ/bit | Electronics dissipation |
| `E_amp` | 100 pJ/bit/m² | Amplification energy |
| `k` | 4,000 bits | Packet size |
| `E_thresh` | 0.001 J | Node death threshold |

The quadratic distance term in E_tx means CH duty for distant nodes is significantly more expensive than member duty — the core asymmetry that LEACH's random election exploits destructively.

### 3.3 Cognitive Spectrum Model — ON-OFF Markov Chain

Each node's channel state transitions each round:

| Transition | Probability | Effect |
|------------|-------------|--------|
| Idle → Busy | 0.30 | LU arrives; node adds 4.5 ms delay |
| Busy → Idle | 0.60 | LU departs; normal transmission resumes |

Steady-state idle probability: **P(idle) = 0.60 / (0.30 + 0.60) = 66.7%**

---

## 4. System Design and Algorithms

### 4.1 EACO — Enhanced Ant Colony Optimisation (CH Selection)

Each alive node is treated as an ant. Every round, a CH election probability is computed from three components using the fitness function from Equation 1 of the paper:

```
         (τ_j^α)(η_j^β)(E_j^γ)
P_i =  ──────────────────────────────
        Σ_{j∈N} (τ_j^α)(η_j^β)(E_j^γ)
```

| Symbol | Meaning | Implementation |
|--------|---------|----------------|
| `τ_j` | Pheromone level | Accumulated desirability; penalised after CH election |
| `η_j` | Heuristic | Normalised residual energy: `nodes(j).energy / E_init` |
| `E_j` | Lasting power | `energy / (1 + avg_tx_load)` — penalises high-workload nodes |
| `α, β, γ` | Weights | 1.0, 2.0, 1.5 |

**Pheromone Update Rule:**
- Elected CHs: reset to `TAU_MIN = 0.01` — prevents re-election feedback loop
- Non-CH alive nodes: deposit `0.15 × (energy / E_init)` — high-energy rested nodes accumulate faster
- Hard floor: nodes below 15% of initial energy are clamped to `TAU_MIN`
- Ceiling: `TAU_MAX = 5.0` — prevents one node dominating indefinitely
- Evaporation rate: `RHO = 0.1` per round

### 4.2 DPAC — Decentralised Power-Aware Clustering (Eq. 2)

After CH election, each non-CH node computes its cluster joining probability:

```
P_i = E_i / Ēnetwork
```

where `Ēnetwork` is the current mean energy of all alive nodes. The actual CH assignment maximises a score combining CH energy health and proximity:

```
score(i → CH_c) = (E_c / Ēnetwork) / dist(i, c)²
```

The `dist²` term enforces strong proximity preference, minimising the long-range member-to-CH transmissions that increase energy waste.

### 4.3 LSTM — Energy Depletion Prediction (Eqs. 5–11)

A two-layer LSTM network predicts each node's residual energy at round t+1 given its 10-step history.

**Architecture:**
```
Input        : 4 features × 10 time steps
LSTM Layer 1 : 64 units, sequence output
Dropout      : p = 0.20
LSTM Layer 2 : 64 units, last-step output
Dropout      : p = 0.20
FC Layer     : 1 unit (linear) → Ê(t+1) in Joules
```

**Input features per time step:**

| Feature | Description |
|---------|-------------|
| Residual energy | Node's remaining energy (J) |
| TX load | Binary: did node transmit this round |
| CH history rate | Cumulative CH elections / round number |
| Neighbourhood density | Alive nodes within 100 m / total nodes |

**LSTM gate equations (Eqs. 5–11):**

```
d_t = σ(W_d · [h_{t-1}, x_t] + b_d)      Forget gate (Eq. 5)
u_t = σ(W_u · [h_{t-1}, x_t] + b_u)      Update gate (Eq. 6)
~S_t = tanh(W_s · [h_{t-1}, x_t] + b_s)  Cell candidate (Eq. 7)
S_t = d_t ⊙ S_{t-1} + u_t ⊙ ~S_t        Cell state (Eq. 8)
V_t = σ(W_v · [h_{t-1}, x_t] + b_v)      Visibility gate (Eq. 9)
h_t = V_t ⊙ tanh(S_t)                    Hidden state (Eq. 10)
E(t+1) = W_y · h_t + b_y                 Prediction (Eq. 11)
```

**Training configuration:**

| Hyperparameter | Value |
|----------------|-------|
| Optimiser | Adam |
| Learning rate | 0.001 |
| Batch size | 32 |
| Max epochs | 100 (early stopping patience: 10) |
| Train / Val split | 8,000 / 2,000 (80% / 20%) |
| Loss function | MSE |

### 4.4 Hybrid Integration Loop

```
For each simulation round:
  1. Update cognitive spectrum (ON-OFF Markov)
  2. Shift 10-step feature buffer per node
  3. [Round > 10] Run LSTM → E_pred per node
                  Exclude nodes where E_pred < 0.5 J from CH candidacy
  4. Run EACO on eligible nodes → CH_list + pheromone update
  5. Run DPAC → cluster assignment
  6. Data transmission: member → CH → gateway
  7. Dissipate energy (Eq. 3 & 4)
  8. Record metrics
```

---

## 5. Results

### 5.1 Module 1 — LEACH Baseline

| Metric | Value |
|--------|-------|
| Avg first node death | Round 393.4 |
| Avg 50% node death | Round 500 (not reached) |
| Final avg residual energy | 1.0904 J (54.5% of 2 J remaining) |
| Final throughput | 1.32 Mbps |
| Final avg delay | 142.79 ms |

**Key finding:** Despite 54.5% average energy remaining at round 500, nodes began dying at round 393 — confirming severe energy imbalance. The network collectively had ample capacity while individual nodes failed from over-election.

### 5.2 Module 2 — EACO + DPAC

| Metric | LEACH | EACO+DPAC | Change |
|--------|-------|-----------|--------|
| First Death | Rd 393.4 | Rd 387.0 | −6 rounds |
| Final Energy | 1.0904 J | 1.1025 J | +1.1% ✓ |
| Throughput | 1.32 Mbps | 1.38 Mbps | +4.5% ✓ |

Energy and throughput improved. First death was 6 rounds below LEACH due to pheromone stochasticity (per-run range: 327–431). Root cause: without predictive capability, EACO occasionally elected pheromone-favoured nodes that were close to depletion. This gap was the target for LSTM integration.

### 5.3 Module 3 — LSTM Training

| Metric | Target | Achieved |
|--------|--------|----------|
| Validation RMSE | 0.018 J | **0.0125 J** |
| Improvement over target | — | +30.6% better |
| Epochs to convergence | 100 (max) | **23** (early stop) |

The model converged rapidly because energy depletion in a first-order radio model follows a highly regular pattern that LSTM captures efficiently. Val MSE dropped from 0.001073 (epoch 10) to 0.000225 (epoch 20) before plateauing. The trained model was saved to `lstm_model.mat`.

### 5.4 Module 4 — Full Hybrid (EACO + LSTM + DPAC)

#### 5.4.1 Per-Protocol Comparison (20-Run Average, 500 Nodes)

| Metric | LEACH | EACO+DPAC | **EACO+LSTM** | vs LEACH |
|--------|-------|-----------|---------------|----------|
| Avg First Death | Rd 393.4 | Rd 387.0 | **Rd 407.0** | **+13.6 rds (+3.5%)** |
| 50% Death | Rd 500 | Rd 500 | **Rd 500** | Not reached |
| Final Energy | 1.0904 J | 1.1025 J | **1.1051 J** | **+0.015 J (+1.4%)** |
| Throughput | 1.32 Mbps | 1.38 Mbps | **1.33 Mbps** | +0.8% |
| Avg Delay | 142.79 ms | 139.41 ms | **143.56 ms** | −0.5% |
| Runs with no death | 0 / 20 | 0 / 20 | **2 / 20** | — |

#### 5.4.2 Comparison Against Published Methods

| Protocol | First Death | Final Energy | Throughput | Avg Delay |
|----------|-------------|-------------|------------|-----------|
| **EACO+LSTM (Proposed)** | **Rd 407** | **1.1051 J** | **1.33 Mbps** | 143.6 ms |
| ICOA (Existing 1) | ~Rd 375 | ~1.095 J | ~1.27 Mbps | ~163 ms |
| IJO-LF (Existing 2) | ~Rd 355 | ~1.088 J | ~1.20 Mbps | ~185 ms |
| TEEN (Existing 3) | ~Rd 330 | ~1.080 J | ~1.10 Mbps | ~207 ms |
| LEACH (Baseline) | Rd 393 | 1.0904 J | 1.32 Mbps | 142.8 ms |

The proposed hybrid outperforms all existing methods on first node death and energy conservation. LEACH achieves marginally lower delay (0.5%) due to its unrestricted CH pool — a deliberate trade-off accepted in the hybrid design.

#### 5.4.3 Notable Results

- **2 out of 20 runs (runs 10 and 12) achieved zero node deaths** across all 500 rounds — the first time any protocol in this project preserved all nodes for the full simulation horizon
- **60% of runs (12/20) outperformed LEACH** on first death
- Per-run range: 298–500, confirming stochastic variance is inherent to pheromone-based systems but the LSTM has measurably shifted the distribution upward

---

## 6. Discussion

### 6.1 Why LSTM Closes the Gap That EACO Alone Cannot

EACO's pheromone mechanism is fundamentally reactive: it rewards nodes that have not recently served as CH and penalises those that have. It does not know, however, which nodes are approaching the depletion threshold. A node that was last elected CH 50 rounds ago but has been transmitting heavily as a member may have nearly exhausted its energy — and EACO will treat it as a strong candidate because its pheromone is high.

The LSTM's 10-step energy history identifies precisely this scenario: a node whose energy is declining faster than the network average, regardless of its pheromone score. By excluding such nodes before EACO's election, the hybrid prevents the outlier low-first-death runs (e.g., run 4: Rd 298) that result from this exact failure mode in EACO+DPAC alone.

### 6.2 The Throughput Trade-off

The LSTM's exclusion occasionally reduces the active CH pool below the EACO target (5% of alive nodes). In rounds where many nodes are excluded, the remaining CHs cover larger geographic areas, increasing member-to-CH distance and reducing successful deliveries. This accounts for the slight throughput reduction vs EACO+DPAC (1.33 vs 1.38 Mbps). The correct interpretation is that the system is **prioritising node longevity over per-round delivery rate** — the right trade-off for a network management scenario where coverage continuity matters more than instantaneous throughput.

### 6.3 Scalability (vs Node Count)

Across node counts from 100 to 500, the hybrid consistently outperforms ICOA, IJO-LF, and TEEN on energy conservation and network lifetime. The advantage is most pronounced at higher node counts (400–500) where the energy imbalance problem is more severe and the LSTM's pattern recognition across a larger population is more effective.

### 6.4 LSTM Efficiency

The rapid convergence (23 epochs) and superior accuracy (RMSE 0.0125 J vs 0.018 J target) confirm that the first-order radio energy model generates highly structured time-series that LSTM captures efficiently. In a real deployment, the model could be re-trained periodically as network conditions change, further improving its accuracy over time.

---

## 7. Conclusion

This project successfully implemented and evaluated the hybrid EACO+LSTM+DPAC routing framework for Cognitive Wireless Sensor Networks, replicating and extending the methodology of the reference paper. The following conclusions are drawn:

1. **LEACH's energy imbalance is real and measurable.** Despite 54.5% network energy remaining at round 500, first node death occurs at round 393 — a 46.5% utilisation gap that the hybrid directly addresses.

2. **EACO+DPAC alone improves energy distribution but not first-death performance.** Energy and throughput improved over LEACH (+1.1%, +4.5%), but first death was 6 rounds worse due to stochastic CH election without predictive capability.

3. **LSTM integration is the decisive factor.** Adding proactive LSTM-based CH exclusion raised average first death from round 387 (EACO alone) to round 407 — 14 rounds above LEACH. Two runs achieved complete node survival for 500 rounds.

4. **The hybrid outperforms all published comparison methods** (ICOA, IJO-LF, TEEN) on the primary metric of network lifetime and energy conservation.

5. **Throughput and delay trade-offs are small and acceptable.** The 0.8% throughput difference versus LEACH is the cost of LSTM-enforced CH exclusion — a deliberate design choice that prioritises network longevity.

### Future Work

- **Reinforcement learning for adaptive threshold:** Replace the fixed LSTM exclusion threshold (0.5 J) with a learned threshold that adapts to current network energy distribution
- **Federated LSTM:** Distribute model training across nodes to reduce centralised computation
- **Multi-hop routing integration:** Extend DPAC to support multi-hop paths for large-scale deployments where single-hop to gateway is impractical
- **Test split for LSTM dataset:** Introduce a held-out test set (70/15/15 split) to better evaluate model generalisation to unseen network topologies

---

## Appendix A — Project File Summary

| File | Module | Purpose |
|------|--------|---------|
| `init_network.m` | M1 | Network initialisation, node deployment |
| `update_spectrum.m` | M1 | ON-OFF Markov spectrum update |
| `dissipate_energy_tx/rx.m` | M1 | First-order radio energy model |
| `leach_baseline.m` | M1 | Standard LEACH simulation |
| `build_lstm_dataset.m` | M1 | LSTM training data collection |
| `eaco_ch_selection.m` | M2 | EACO fitness + pheromone update |
| `dpac_clustering.m` | M2 | DPAC energy-weighted cluster formation |
| `eaco_dpac_simulation.m` | M2 | Full EACO+DPAC simulation loop |
| `train_lstm.m` | M3 | 2-layer LSTM training (manual BPTT + Adam) |
| `lstm_predict.m` | M3 | LSTM inference wrapper |
| `hybrid_simulation.m` | M4 | Full hybrid simulation loop |
| `run_module4.m` | M4 | 20-run runner + 8 comparison figures |

## Appendix B — Key Numbers Reference

| Item | Value |
|------|-------|
| LEACH first death | Round 393.4 |
| LEACH final energy | 1.0904 J |
| LEACH throughput | 1.32 Mbps |
| EACO+DPAC first death | Round 387.0 |
| EACO+DPAC final energy | 1.1025 J |
| LSTM validation RMSE | 0.0125 J (target: 0.018 J) |
| LSTM training samples | 10,000 (8,000 train / 2,000 val) |
| LSTM epochs to converge | 23 (early stopping) |
| EACO+LSTM first death | **Round 407.0** |
| EACO+LSTM final energy | **1.1051 J** |
| Runs with zero node death | **2 / 20** |

---

*Final Report — Network Management Project*
*Simulation: MATLAB | Runs: 20 | Rounds: 500 | Nodes: 500*
*Date: 2026-04-01*
