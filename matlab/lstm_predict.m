% =========================================================
% lstm_predict.m
% Module 3 — LSTM Inference Wrapper
%
% Called each round by the hybrid simulation to predict
% the next-round residual energy for every alive node.
%
% Usage:
%   E_pred = lstm_predict(net, norm_params, node_history)
%
% Inputs:
%   net          — trained LSTM network (from lstm_model.mat)
%   norm_params  — struct with fields: feat_min, feat_max, feat_range
%   node_history — [N x 10 x 4]  last 10 rounds of features for N nodes
%                  Features: [energy, tx_load, ch_history, density]
%
% Output:
%   E_pred       — [N x 1]  predicted residual energy at t+1 (Joules)
% =========================================================

function E_pred = lstm_predict(net, norm_params, node_history)

N = size(node_history, 1);   % number of alive nodes
T = size(node_history, 2);   % 10 time steps
F = size(node_history, 3);   %  4 features

%% Normalise using training-set parameters
flat = reshape(node_history, N*T, F);
flat_norm = (flat - norm_params.feat_min) ./ norm_params.feat_range;
flat_norm = max(0, min(1, flat_norm));   % clip to [0,1]
X_norm = reshape(flat_norm, N, T, F);

%% Convert to cell array  {N x 1}, each cell [4 x 10]
X_cell = arrayfun(@(i) squeeze(X_norm(i,:,:))', ...
                  (1:N)', 'UniformOutput', false);

%% Run inference
E_pred = predict(net, X_cell);   % [N x 1]

end
