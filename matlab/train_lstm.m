% =========================================================
% train_lstm.m
% Module 3 — LSTM Energy Consumption Prediction
%
% Trains a 2-layer LSTM network to predict the residual
% energy of a sensor node one round ahead.
%
% Input data: lstm_training_data.mat
%   X : [10000 x 10 x 4]  (samples x timesteps x features)
%   Y : [10000 x 1]        (target: energy at t+1)
%
% Output: lstm_model.mat  (trained network + norm params)
% =========================================================

clc; clear; close all;

%% 1. Load dataset
fprintf('Loading LSTM training data...\n');
data = load('lstm_training_data.mat');
X_raw = data.X;   % [10000 x 10 x 4]
Y_raw = data.Y;   % [10000 x 1]

N = size(X_raw, 1);   % 10000 samples
T = size(X_raw, 2);   % 10 time steps
F = size(X_raw, 3);   %  4 features

fprintf('Dataset: %d samples | %d time steps | %d features\n', N, T, F);

%% 2. Normalise features
% Normalise each feature channel to [0, 1] using training set stats.
% Store params so lstm_predict.m can apply the same transform at runtime.

X_flat = reshape(X_raw, N*T, F);   % [(N*T) x 4]

feat_min = min(X_flat, [], 1);      % [1 x 4]
feat_max = max(X_flat, [], 1);      % [1 x 4]
feat_range = feat_max - feat_min;
feat_range(feat_range == 0) = 1;    % avoid divide-by-zero

X_norm_flat = (X_flat - feat_min) ./ feat_range;
X_norm = reshape(X_norm_flat, N, T, F);  % [10000 x 10 x 4]

% Normalise Y (energy) — already in [0, 2J]; keep as-is (regression target)
Y = Y_raw;

%% 3. Train / validation split  (80 / 20)
rng(42);
idx = randperm(N);
n_train = round(0.8 * N);   % 8000

train_idx = idx(1:n_train);
val_idx   = idx(n_train+1:end);

% Convert to MATLAB LSTM cell format: each cell = [F x T]
to_cell = @(idx_list) arrayfun(@(i) squeeze(X_norm(i,:,:))', ...
                                idx_list, 'UniformOutput', false);

X_train = to_cell(train_idx)';    % {8000 x 1} cell, each [4 x 10]
X_val   = to_cell(val_idx)';      % {2000 x 1} cell

Y_train = Y(train_idx);           % [8000 x 1]
Y_val   = Y(val_idx);             % [2000 x 1]

fprintf('Train: %d | Validation: %d\n', n_train, N - n_train);

%% 4. Define network architecture
% Per paper: 2 LSTM layers (64 units each), dropout 0.2, dense output
layers = [
    sequenceInputLayer(F, 'Name', 'input')

    lstmLayer(64, 'OutputMode', 'sequence', 'Name', 'lstm1')
    dropoutLayer(0.2, 'Name', 'drop1')

    lstmLayer(64, 'OutputMode', 'last', 'Name', 'lstm2')
    dropoutLayer(0.2, 'Name', 'drop2')

    fullyConnectedLayer(1, 'Name', 'fc')
    regressionLayer('Name', 'output')
];

%% 5. Training options
% Per paper: Adam, MSE loss, lr=0.001, 100 epochs, early stopping on val loss
options = trainingOptions('adam', ...
    'MaxEpochs',          100, ...
    'MiniBatchSize',      32, ...
    'InitialLearnRate',   0.001, ...
    'GradientThreshold',  1, ...
    'Shuffle',            'every-epoch', ...
    'ValidationData',     {X_val, Y_val}, ...
    'ValidationFrequency', 50, ...
    'OutputFcn',          @(info) stopIfValLossStagnates(info), ...
    'Plots',              'training-progress', ...
    'Verbose',            true, ...
    'VerboseFrequency',   10);

%% 6. Train
fprintf('\nTraining LSTM...\n');
tic;
[net, info] = trainNetwork(X_train, Y_train, layers, options);
elapsed = toc;
fprintf('Training complete in %.1f seconds.\n', elapsed);

%% 7. Evaluate on validation set
Y_pred = predict(net, X_val);
rmse_val = sqrt(mean((Y_pred - Y_val).^2));
fprintf('\n=== Validation RMSE: %.4f J ===\n', rmse_val);
fprintf('Target RMSE: 0.018 J\n');

if rmse_val <= 0.022
    fprintf('PASS — RMSE within acceptable range.\n');
else
    fprintf('WARNING — RMSE above target. Consider tuning or more epochs.\n');
end

%% 8. Save model + normalisation parameters
save('lstm_model.mat', 'net', 'feat_min', 'feat_max', 'feat_range', ...
     'rmse_val', 'info');
fprintf('\nModel saved to lstm_model.mat\n');

%% 9. Diagnostic plot — predicted vs actual (validation set)
figure('Name', 'LSTM Validation: Predicted vs Actual');
scatter(Y_val, Y_pred, 5, 'filled', 'MarkerFaceAlpha', 0.3);
hold on;
plot([min(Y_val) max(Y_val)], [min(Y_val) max(Y_val)], 'r--', 'LineWidth', 1.5);
xlabel('Actual Energy (J)');
ylabel('Predicted Energy (J)');
title(sprintf('LSTM Validation — RMSE = %.4f J', rmse_val));
legend('Predictions', 'Perfect fit', 'Location', 'northwest');
grid on;

figure('Name', 'Training & Validation Loss');
plot(info.TrainingLoss, 'b-', 'LineWidth', 1.2); hold on;
plot(info.ValidationLoss, 'r--', 'LineWidth', 1.2);
xlabel('Iteration'); ylabel('MSE Loss');
title('LSTM Training Progress');
legend('Training Loss', 'Validation Loss');
grid on;

fprintf('\nModule 3 training complete. Ready for lstm_predict.m integration.\n');

% =========================================================
% Helper: early stopping if validation loss does not improve
%         for 10 consecutive validation checks
% =========================================================
function stop = stopIfValLossStagnates(info)
    persistent best_val patience_counter
    stop = false;
    if isempty(best_val)
        best_val = Inf;
        patience_counter = 0;
    end
    if ~isempty(info.ValidationLoss)
        if info.ValidationLoss < best_val - 1e-5
            best_val = info.ValidationLoss;
            patience_counter = 0;
        else
            patience_counter = patience_counter + 1;
        end
        if patience_counter >= 10
            fprintf('Early stopping triggered at epoch %d.\n', info.Epoch);
            stop = true;
        end
    end
end
