% =========================================================
% MODULE 1 - STEP 3 RUNNER: Training Data Collection
% Runs 2 full simulation runs with per-node tracking,
% then builds a 10,000-sample dataset for LSTM training.
% =========================================================

clc; clear; close all;
addpath(pwd);

TARGET_SAMPLES = 10000;

fprintf('>>> Module 1 Step 3: Collecting LSTM Training Data\n');
fprintf('    Target: %d samples (10-step windows, 4 features)\n\n', TARGET_SAMPLES);

all_series = [];

% We run 2 independent simulations to gather enough data
% 500 nodes x (500-10) rounds = 245,000 possible windows per run
% So 1 run is more than enough — we use 2 for variety
for run = 1 : 2
    fprintf('  Data collection run %d / 2 ...\n', run);
    rng(run + 100);             % Different seed from baseline runs
    net = init_network();

    node_series = collect_training_data(net);   % [500 x 500 x 5]

    if isempty(all_series)
        all_series = node_series;
    else
        % Stack along node dimension for more variety
        all_series = cat(1, all_series, node_series);
    end
    fprintf('  Run %d complete. Series shape: [%d x %d x %d]\n\n', ...
        run, size(all_series,1), size(all_series,2), size(all_series,3));
end

% Build the sliding-window dataset
fprintf('>>> Extracting %d training samples...\n', TARGET_SAMPLES);
[X, Y] = build_lstm_dataset(all_series, TARGET_SAMPLES);

% Verify shapes
fprintf('\n=== Dataset Summary ===\n');
fprintf('X shape : [%d x %d x %d]  (samples x time_steps x features)\n', ...
    size(X,1), size(X,2), size(X,3));
fprintf('Y shape : [%d x 1]         (target: next-round energy)\n', size(Y,1));
fprintf('Y range : [%.6f  to  %.6f] J\n', min(Y), max(Y));
fprintf('Y mean  : %.6f J\n', mean(Y));
fprintf('=======================\n');

% Split 80% train / 20% validation (from paper)
split_idx   = floor(0.8 * size(X,1));
X_train     = X(1:split_idx, :, :);
Y_train     = Y(1:split_idx);
X_val       = X(split_idx+1:end, :, :);
Y_val       = Y(split_idx+1:end);

fprintf('\nTrain samples : %d (80%%)\n', size(X_train,1));
fprintf('Val   samples : %d (20%%)\n', size(X_val,1));

% Save dataset
save('lstm_training_data.mat', 'X', 'Y', 'X_train', 'Y_train', 'X_val', 'Y_val');
fprintf('\nDataset saved to lstm_training_data.mat\n');

% --- Plot sample feature distributions ---
figure('Name','Training Data - Feature Distributions','NumberTitle','off');

feat_names = {'Residual Energy (J)', 'TX Load', 'CH History (norm)', 'Neighbor Density (norm)'};
for f = 1:4
    subplot(2,2,f);
    % Extract feature f across all samples and all time steps
    feat_vals = reshape(X(:,:,f), [], 1);
    histogram(feat_vals, 40, 'FaceColor', [0.2 0.5 0.8]);
    xlabel(feat_names{f});
    ylabel('Count');
    title(['Feature ' num2str(f) ': ' feat_names{f}]);
    grid on;
end
sgtitle('LSTM Training Dataset — Feature Distributions');

figure('Name','Training Data - Target Energy Distribution','NumberTitle','off');
histogram(Y, 50, 'FaceColor', [0.8 0.3 0.2]);
xlabel('Target Residual Energy (J)');
ylabel('Sample Count');
title('Distribution of Target Values (Next-Round Energy)');
grid on;

fprintf('\n>>> Step 3 complete. Ready for Module 1 Report writing.\n');
fprintf('    Next: Module 2 — EACO + DPAC Implementation\n');
