# Future Research Notes

## 1. Add Held-Out Test Set to LSTM Dataset Split

**Current implementation:** 80% train / 20% validation (follows the paper exactly)

**Proposed improvement:** Split into 70% train / 15% validation / 15% test

**Why:**
- The paper reports a final validation RMSE of 0.018, but without a separate test set, this number may be optimistic (the val set was used for early stopping, so it influenced training indirectly)
- A held-out test set — never seen during training or hyperparameter tuning — gives an unbiased final RMSE
- Standard ML practice requires train/val/test separation for credible performance reporting

**How to apply:**
- In `run_module1_step3.m`, replace the 80/20 split block with a three-way split
- Save `X_test` and `Y_test` alongside train/val in `lstm_training_data.mat`
- After LSTM training in Module 3, evaluate on `X_test`/`Y_test` and report that RMSE separately from validation RMSE
