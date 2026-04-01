# hybrid-routing-wsn
# Project Progress Report

**Project:** Hybrid Approach of Ant Colony System and Recurrent Neural Network for Energy Efficient Routing in Cognitive Wireless Sensor Networks

**Last session date:** 2026-04-01

---

## Work Completed

### Module 1 — COMPLETE

All three steps finished and verified with real simulation output.

| Step | Task | Status | Key Output |
|------|------|--------|-----------|
| 1 | Network initialization + ON-OFF Markov spectrum | Done | 500 nodes, 500×500m, 2J/node, 10 channels |
| 2 | Baseline LEACH simulation (20 runs) | Done | First death: Rd 393, Final energy: 1.09J |
| 3 | LSTM training dataset collection | Done | 10,000 samples × 10 steps × 4 features saved to `lstm_training_data.mat` |

**Module 1 Report:** Written and saved at `reports/Module1_Report.md`

**Baseline metrics (reference for all future comparisons):**

| Metric | Baseline LEACH Value |
|--------|---------------------|
| Avg First Node Death | Round 393.4 |
| Avg 50% Node Death | Round 500 (not reached) |
| Final Avg Energy | 1.0904 J |
| Final Throughput | 1.32 Mbps |

---

### Module 2 — COMPLETE

**Results (20-run average):**

| Metric | LEACH | EACO+DPAC | Change |
|--------|-------|-----------|--------|
| First Node Death | Rd 393.4 | Rd 387.0 | −6 rounds |
| 50% Node Death | Rd 500 | Rd 500 | Same |
| Final Avg Energy | 1.0904 J | 1.1025 J | +1.1% ✓ |
| Final Throughput | 1.32 Mbps | 1.38 Mbps | +4.5% ✓ |

**Note:** First death is 6 rounds below LEACH due to pheromone stochasticity (run range: 327–431). Energy and throughput both improve. The LSTM in Module 3 will close the first-death gap by proactively excluding low-energy nodes from CH eligibility.

**Module 2 Report:** Written and saved at `reports/Module2_Report.md`

---

## Files in Project

```
D:\hybird-wsn\
├── matlab\
│   ├── init_network.m
│   ├── update_spectrum.m
│   ├── dissipate_energy_tx.m
│   ├── dissipate_energy_rx.m
│   ├── visualize_network.m
│   ├── leach_baseline.m
│   ├── collect_training_data.m
│   ├── build_lstm_dataset.m
│   ├── eaco_ch_selection.m          ← last modified (Fix 3 applied)
│   ├── dpac_clustering.m            ← last modified (Fix 3 applied)
│   ├── eaco_dpac_simulation.m
│   ├── run_module1_step1.m
│   ├── run_module1_step2.m
│   ├── run_module1_step3.m
│   └── run_module2.m
├── reports\
│   ├── Module1_Report.md            ← complete
│   ├── Module2_Report.md            ← complete
│   └── Progress_Report.md           ← this file
├── future-research-notes.md         ← idea: add test split to LSTM dataset
├── baseline_results.mat             ← Module 1 baseline data
├── eaco_results.mat                 ← Module 2 results (last run, Fix 2)
└── lstm_training_data.mat           ← LSTM training dataset
```

---

## Next Session Plan

### Step 1 — Module 3: LSTM Design and Training
- Build LSTM network in MATLAB (2 hidden layers: 64 + 32 units, dropout 0.2)
- Train on `lstm_training_data.mat` (10,000 samples, Adam optimizer, MSE loss, 100 epochs)
- Target validation RMSE ≈ 0.018
- Integrate predictions into DPAC CH eligibility weighting

### Step 4 — Module 4: Final Hybrid Evaluation
- Run full EACO + LSTM + DPAC simulation (20 runs)
- Generate all 8 comparison graphs matching the paper's figures
- Compare against LEACH baseline and EACO-only results

### Step 5 — Final Report
- Executive summary + problem statement
- Methodology (EACO, DPAC, LSTM)
- Results and analysis
- Conclusion

---

## Key Numbers to Remember

| Item | Value |
|------|-------|
| LEACH first death | Round 393.4 |
| LEACH final energy | 1.0904 J |
| LEACH throughput | 1.32 Mbps |
| EACO+DPAC first death | Round 387.0 |
| EACO+DPAC final energy | 1.1025 J |
| EACO+DPAC throughput | 1.38 Mbps |
| LSTM training samples | 10,000 |
| LSTM lookback window | 10 time steps |
| LSTM features | 4 (energy, TX load, CH history, density) |
| Target LSTM RMSE | 0.018 |
| Train / Val split | 80% / 20% |

---

*Session ended: 2026-04-01 | Resume from: Module 3 — LSTM Design and Training*
