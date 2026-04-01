# Module 3 Report: LSTM Energy Consumption Prediction

**Project:** Hybrid Approach of Ant Colony System and Recurrent Neural Network for Energy Efficient Routing in Cognitive Wireless Sensor Networks

**Module:** 3 of 5 — LSTM-Based Per-Node Energy Forecasting

---

## 1. Objective

Module 2 demonstrated that EACO+DPAC improves energy conservation (+1.1%) and throughput (+4.5%) over LEACH, but the average first node death (Rd 387) fell short of LEACH (Rd 393) due to pheromone stochasticity — occasionally electing nodes that are close to depletion.

Module 3 trains a Long Short-Term Memory (LSTM) recurrent neural network to predict each node's residual energy one round ahead. These predictions are fed back into the DPAC cluster-head eligibility calculation in Module 4, proactively excluding energy-critical nodes from CH election before they fail.

---

## 2. Model Architecture

The LSTM network follows the specification in the paper exactly:

```
Input Layer    : 4 features × 10 time steps
LSTM Layer 1   : 64 units  — OutputMode: sequence
Dropout        : p = 0.20
LSTM Layer 2   : 64 units  — OutputMode: last
Dropout        : p = 0.20
FC Layer       : 1 unit (linear) — predicts E(t+1) in Joules
Loss           : Mean Squared Error (MSE)
```

### 2.1 LSTM Cell Equations

Each LSTM cell at time step t computes:

| Gate | Equation |
|------|----------|
| Input gate | `i_t = σ(W_i · [x_t; h_{t-1}] + b_i)` |
| Forget gate | `f_t = σ(W_f · [x_t; h_{t-1}] + b_f)` |
| Output gate | `o_t = σ(W_o · [x_t; h_{t-1}] + b_o)` |
| Cell candidate | `g_t = tanh(W_g · [x_t; h_{t-1}] + b_g)` |
| Cell state | `c_t = f_t ⊙ c_{t-1} + i_t ⊙ g_t` |
| Hidden state | `h_t = o_t ⊙ tanh(c_t)` |

The **forget gate** determines what past energy history to retain; the **input gate** controls how new observations update the cell memory; the **visibility gate** (output) controls what is exposed to the next layer. Together they capture long-range temporal dependencies in per-node energy depletion patterns.

### 2.2 Information Flow

```
[Round t−9 ... Round t]  →  LSTM Layer 1  →  Dropout  →
→  LSTM Layer 2  →  Dropout  →  FC  →  Ê(t+1)
```

Layer 1 processes the full 10-step sequence and passes its hidden states at every step to Layer 2. Layer 2 summarises the sequence into a single context vector (last hidden state), which the FC layer maps to the predicted energy scalar.

---

## 3. Training Dataset

| Property | Value |
|----------|-------|
| Source file | `lstm_training_data.mat` |
| Total samples | 10,000 |
| Time steps per sample | 10 |
| Features per step | 4 |
| Train / Validation split | 8,000 / 2,000 (80% / 20%) |

### 3.1 Input Features

| Feature | Description | Range |
|---------|-------------|-------|
| Residual energy | Node's remaining energy (J) | 0–2 J |
| Transmission load | Packets sent this round | 0 or 1 |
| CH history | Cumulative CH elections / round | 0–1 |
| Neighbourhood density | Alive nodes within 100 m / total | 0–1 |

All features are normalised to [0, 1] using training-set min/max parameters saved in `lstm_model.mat`, ensuring identical scaling is applied at inference time.

### 3.2 Target Variable

- **Y**: residual energy at round t+1 (Joules)
- Range: 0.309 J – 1.996 J (dead nodes excluded from dataset)

---

## 4. Training Configuration

| Hyperparameter | Value |
|----------------|-------|
| Optimiser | Adam |
| Learning rate | 0.001 |
| β₁ / β₂ | 0.9 / 0.999 |
| Batch size | 32 |
| Max epochs | 100 |
| Early stopping patience | 10 validation checks |
| Weight initialisation | Xavier (Glorot) |
| Dropout rate | 0.20 (inverted dropout) |

---

## 5. Training Results

### 5.1 Loss Convergence

| Epoch | Train MSE | Val MSE |
|-------|-----------|---------|
| 10 | 0.009206 | 0.001073 |
| 20 | 0.005135 | 0.000225 |
| 23 | — | — *(early stop)* |

Training converged in **23 epochs** — well before the 100-epoch budget. The validation loss dropped sharply from epoch 10 to 20, then plateaued, triggering the early stopping criterion (no improvement for 10 checks).

The rapid convergence (< 25 epochs) indicates the energy depletion patterns in the dataset are highly regular and learnable — consistent with the deterministic physics of the first-order radio energy model.

### 5.2 Validation Performance

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Validation RMSE | 0.018 J | **0.0125 J** | **PASS** |
| Improvement over target | — | **+30.6%** better | — |

The validation RMSE of **0.0125 J** means the model's per-node energy predictions are accurate to within ±12.5 mJ on average. Given that a node holds 2 J and the depletion threshold is 1 mJ, this precision is more than sufficient for CH eligibility decisions.

---

## 6. Integration into Module 4

The trained model is saved to `lstm_model.mat` containing:

| Variable | Contents |
|----------|----------|
| `params` | Weight matrices W1, b1, W2, b2, Wfc, bfc |
| `norm_params` | feat_min, feat_max, feat_range (for runtime normalisation) |
| `rmse_val` | 0.0125 J (validation benchmark) |

At each simulation round in Module 4, `lstm_predict.m` is called with the last 10 rounds of per-node features. Nodes whose predicted energy at t+1 falls below a threshold (set as a fraction of mean network energy) are flagged and excluded from the DPAC CH eligibility pool for that round.

This proactive exclusion mechanism targets the root cause of Module 2's first-death shortfall: nodes that EACO would otherwise elect as CH despite being close to depletion.

---

## 7. Summary and Transition to Module 4

Module 3 has:

1. Implemented a 2-layer LSTM (64 units each) with dropout using BPTT and Adam optimisation.
2. Achieved validation RMSE of **0.0125 J** — 30% better than the paper's target of 0.018 J.
3. Trained to convergence in 23 epochs (early stopping).
4. Saved inference-ready model to `lstm_model.mat` with normalisation parameters.

**Module 4** will integrate this model into the full simulation loop:
- At each round: predict E(t+1) for all alive nodes via `lstm_predict.m`
- Exclude predicted-critical nodes from CH eligibility
- Run EACO on the eligible set; run DPAC for cluster formation
- Record all 8 performance metrics matching the paper's figures

Expected outcome: first node death > Round 450, throughput > 1.50 Mbps, packet delay reduction vs LEACH.

---

*Report prepared for: Network Management Project — Module 3*
*Simulation tool: MATLAB | Training samples: 10,000 | Validation RMSE: 0.0125 J*
*Model file: `lstm_model.mat`*
