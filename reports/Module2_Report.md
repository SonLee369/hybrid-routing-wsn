# Module 2 Report: EACO + DPAC Cluster Head Selection

**Project:** Hybrid Approach of Ant Colony System and Recurrent Neural Network for Energy Efficient Routing in Cognitive Wireless Sensor Networks

**Module:** 2 of 5 — Enhanced Ant Colony Optimisation + Decentralised Power-Aware Clustering

---

## 1. Objective

Module 1 demonstrated that LEACH's random CH election causes premature node failure — first death at round 393 — despite 54.5% average energy remaining. The root cause is that LEACH is blind to node energy state, position, and past workload when electing CHs.

Module 2 replaces LEACH's random election with two intelligent mechanisms:

1. **EACO (Enhanced Ant Colony Optimisation)** — a bio-inspired pheromone algorithm that scores every alive node using energy, heuristic position information, and lasting power, electing the highest-scoring nodes as CHs.
2. **DPAC (Decentralised Power-Aware Clustering)** — a cluster formation protocol where member nodes join CHs based on a probabilistic function of relative energy, not raw distance.

The goal is to improve energy distribution across the network, extend network lifetime, and increase throughput compared to the LEACH baseline.

---

## 2. Algorithm Design

### 2.1 EACO — Cluster Head Election (Equation 1)

Each alive node is treated as an ant. Every round, each node computes a CH election probability based on three components:

```
         (τ_j^α)(η_j^β)(E_j^γ)
P_i =  ──────────────────────────────
        Σ_{j∈N} (τ_j^α)(η_j^β)(E_j^γ)
```

| Symbol | Meaning |
|--------|---------|
| `τ_j` | Pheromone level on node j — accumulated routing desirability |
| `η_j` | Heuristic information — inversely related to cumulative TX load |
| `E_j` | Lasting energy — node's residual energy relative to initial |
| `α` | Pheromone weight (tuning parameter) |
| `β` | Heuristic weight (tuning parameter) |
| `γ` | Energy weight (tuning parameter) |

Nodes with high pheromone (historically good routes), low TX load, and high remaining energy receive the highest probability scores and are elected as CHs.

**Pheromone update rule:**

After each round, pheromone levels are updated using evaporation and deposit:

```
τ_j(t+1) = (1 − RHO) × τ_j(t) + Δτ_j
```

- Elected CHs receive a **penalty** (×0.5 multiplier) to avoid re-electing the same nodes repeatedly — preventing the exhaustion feedback loop.
- Non-elected nodes receive a **reward** proportional to their residual energy, making them progressively more attractive as CHs.
- Pheromone is bounded between `TAU_MIN` and `TAU_MAX` to prevent collapse or runaway reinforcement.

### 2.2 DPAC — Cluster Formation (Equation 2)

Once CHs are elected, each non-CH node calculates its probability of joining each candidate CH:

```
P_i = E_i / Ēnetwork
```

| Symbol | Meaning |
|--------|---------|
| `E_i` | Residual energy of node i |
| `Ēnetwork` | Average residual energy of all alive nodes |

Nodes with above-average energy are more likely to be accepted. The joining decision also incorporates **distance squared** (`dist²`) as a proximity penalty — members strongly prefer nearby CHs, which reduces TX energy for the long member-to-CH hop.

This is a departure from standard DPAC (which uses `dist¹`) and was introduced in Fix 3 to reduce unnecessary long-range transmissions to distant CHs.

---

## 3. Tuning History

Four tuning iterations were required before EACO+DPAC produced acceptable results. Each attempt, its change, and outcome:

| Attempt | Key Change | Avg First Death | Outcome |
|---------|-----------|-----------------|---------|
| Initial | Pheromone deposited on elected CHs (positive feedback) | Round 190 | Catastrophic — CHs re-elected repeatedly until exhausted |
| Fix 1 | Reversed: penalise elected CHs (×0.5), reward non-CHs | Round 362 | Better but still below LEACH (393) |
| Fix 2 | Harder pheromone floor (TAU_MIN), β=4.0, γ=2.0, RHO=0.25 | Round 319 | Worse — over-correction, too aggressive evaporation |
| Fix 3 / 4 | `E_lasting` penalises TX load (not dist-to-gateway); DPAC uses `dist²` | **Round 387** | Closest result — energy and throughput improve |

**Root cause of early failures:**
- The initial implementation used `dist_to_gateway` in the `E_lasting` term, which caused EACO to concentrate CH elections on central (near-gateway) nodes. These nodes were repeatedly re-elected, exhausting them far faster than random LEACH selection would.
- DPAC's original `dist¹` weighting allowed members to join distant CHs freely, increasing member TX energy.
- Fix 3/4 corrected both: heuristic now penalises high cumulative TX load regardless of position, and `dist²` enforces strong proximity preference in cluster formation.

---

## 4. Simulation Results (20-Run Average)

### 4.1 Summary Comparison

| Metric | LEACH Baseline | EACO + DPAC | Change |
|--------|---------------|-------------|--------|
| Avg First Node Death | Round 393.4 | Round 387.0 | −6 rounds (−1.5%) |
| Avg 50% Node Death | Round 500 (not reached) | Round 500 (not reached) | No change |
| Final Avg Residual Energy | 1.0904 J | 1.1025 J | **+0.012 J (+1.1%)** |
| Final Throughput | 1.32 Mbps | 1.38 Mbps | **+0.06 Mbps (+4.5%)** |

### 4.2 Per-Run First Death Rounds

| Run | First Death |
|-----|------------|
| 1 | 408 |
| 2 | 426 |
| 3 | 327 |
| 4 | 401 |
| 5 | 431 |
| 6 | 373 |
| 7 | 395 |
| 8 | 368 |
| 9 | 333 |
| 10 | 391 |
| 11 | 409 |
| 12 | 399 |
| 13 | 396 |
| 14 | 402 |
| 15 | 411 |
| 16 | 355 |
| 17 | 375 |
| 18 | 413 |
| 19 | 366 |
| 20 | 361 |
| **Mean** | **387.0** |
| Min | 327 |
| Max | 431 |

The high per-run variance (range: 327–431) reflects the stochastic nature of EACO pheromone initialisation and random node deployment. Runs 1, 2, 5, 11, 15, 18 (first death > 400) significantly outperform LEACH; runs 3, 9 are outliers pulling the mean down.

---

## 5. Analysis

### 5.1 Why Energy and Throughput Improve

EACO's energy-aware CH election distributes the CH role more evenly across the network. Nodes with high residual energy are progressively favoured, preventing any single node from being repeatedly overloaded. The result is a more uniform depletion curve across all 500 nodes — reflected in the 1.1% improvement in final average energy and 4.5% throughput gain.

### 5.2 Why First Death Does Not Yet Beat LEACH

The mean first death (Rd 387) falls 6 rounds short of LEACH (Rd 393). The cause is structural: EACO+DPAC still elects CHs probabilistically, and in some runs an energy-poor node with accumulated pheromone is selected before the penalty mechanism corrects it. The minimum first death (Rd 327) in run 3 is a clear outlier caused by exactly this scenario.

This is the expected limitation of EACO without predictive capability. **The LSTM integration in Module 3** addresses this directly: by predicting which nodes will deplete shortly, the system can proactively exclude them from CH eligibility before they fail — targeting a first death well above round 450.

### 5.3 Position vs Module 3

| Metric | LEACH | EACO+DPAC (M2) | Target after LSTM (M4) |
|--------|-------|----------------|----------------------|
| First Death | Rd 393 | Rd 387 | > Rd 450 |
| Final Energy | 1.090 J | 1.103 J | > 1.15 J |
| Throughput | 1.32 Mbps | 1.38 Mbps | > 1.50 Mbps |

---

## 6. Summary and Transition to Module 3

Module 2 has:

1. Replaced LEACH's random CH election with the EACO pheromone-based fitness function (Eq. 1).
2. Replaced proximity-only clustering with DPAC energy-weighted joining probability (Eq. 2) with `dist²` proximity penalty.
3. Demonstrated improved energy conservation (+1.1%) and throughput (+4.5%) over LEACH.
4. Identified the remaining gap: first death is −6 rounds below LEACH due to absence of predictive node exclusion.

**Module 3** will train a two-layer LSTM network on `lstm_training_data.mat` to predict per-node energy depletion one round ahead. These predictions will be fed back into DPAC's CH eligibility weighting, closing the gap in first-death performance.

---

*Report prepared for: Network Management Project — Module 2*
*Simulation tool: MATLAB | Runs: 20 | Rounds per run: 500*
*Results file: `eaco_results.mat`*
