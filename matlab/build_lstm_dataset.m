% =========================================================
% MODULE 1 - STEP 3b: Build LSTM Training Dataset
% Extracts sliding 10-step windows from node_series
%
% Input  : node_series [N x R x 5]
% Output : X [samples x 10 x 4]  — input features (4 features)
%          Y [samples x 1]        — target: next-round residual energy
%
% Features used for LSTM (matching the paper):
%   1. Residual energy
%   2. Transmission load
%   3. CH history
%   4. Neighborhood density
% (distance_to_CH stored in feature 5, kept for reference)
% =========================================================

function [X, Y] = build_lstm_dataset(node_series, target_samples)

    LOOKBACK = 10;      % 10 time-step history window (from paper)
    NUM_FEAT = 4;       % Features per time step fed to LSTM

    [N, R, ~] = size(node_series);

    X_raw = [];
    Y_raw = [];

    for i = 1 : N
        % Skip nodes that were always dead (zero energy throughout)
        if all(node_series(i, :, 1) == 0)
            continue;
        end

        for t = LOOKBACK : (R - 1)
            % Input window: t-9 to t (10 steps, 4 features)
            window = squeeze(node_series(i, t-LOOKBACK+1:t, 1:NUM_FEAT));
            % window is [10 x 4]

            % Target: residual energy at next time step (t+1)
            target = node_series(i, t+1, 1);

            X_raw(end+1, :, :) = window;   % append [1 x 10 x 4]
            Y_raw(end+1)        = target;
        end

        % Stop early if we have enough samples
        if size(X_raw, 1) >= target_samples * 2
            break;
        end
    end

    % Randomly sample target_samples rows
    total = size(X_raw, 1);
    if total > target_samples
        idx = randperm(total, target_samples);
        X = X_raw(idx, :, :);
        Y = Y_raw(idx)';
    else
        X = X_raw;
        Y = Y_raw';
    end

    fprintf('Dataset built: %d samples x %d time steps x %d features\n', ...
        size(X,1), size(X,2), size(X,3));
end
