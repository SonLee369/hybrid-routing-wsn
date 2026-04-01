% =========================================================
% lstm_predict.m
% Module 3 — LSTM Inference Wrapper
%
% Called each round by the hybrid simulation to predict
% next-round residual energy for every alive node.
%
% Usage:
%   E_pred = lstm_predict(params, norm_params, node_history)
%
% Inputs:
%   params       — trained LSTM params struct (from lstm_model.mat)
%   norm_params  — struct: feat_min, feat_max, feat_range
%   node_history — [N x T x F]  last 10 rounds of features per node
%                  Features: [energy, tx_load, ch_history, density]
%
% Output:
%   E_pred       — [N x 1]  predicted residual energy at t+1 (Joules)
% =========================================================

function E_pred = lstm_predict(params, norm_params, node_history)

[N, T, F] = size(node_history);

%% Normalise using training-set parameters
flat      = reshape(node_history, N*T, F);
flat_norm = (flat - norm_params.feat_min) ./ norm_params.feat_range;
flat_norm = max(0, min(1, flat_norm));
X_norm    = reshape(flat_norm, N, T, F);

%% Reorder to [F x T x N] for matrix ops
X = permute(X_norm, [3 2 1]);

%% Forward pass (no dropout at inference)
E_pred = lstm_fwd_pass(params, X);

end

% =========================================================
%  LOCAL FUNCTIONS
% =========================================================

function s = sigm(x)
    s = zeros(size(x));
    idx = x >= 0;
    s( idx) = 1 ./ (1 + exp(-x(idx)));
    ex = exp(x(~idx));
    s(~idx) = ex ./ (1 + ex);
end

function h_seq = lstm_fwd_seq(W, b, x_seq, h0, c0)
    % Full sequence output — used for layer 1
    [Fin, T, B] = size(x_seq);
    H = size(h0, 1);
    h_seq = zeros(H, T, B);
    h = h0;  c = c0;
    for t = 1:T
        x_t  = reshape(x_seq(:,t,:), Fin, B);
        z    = W * [x_t; h] + b;
        i_t  = sigm(z(1:H,:));
        f_t  = sigm(z(H+1:2*H,:));
        o_t  = sigm(z(2*H+1:3*H,:));
        g_t  = tanh(z(3*H+1:4*H,:));
        c    = f_t .* c + i_t .* g_t;
        h    = o_t .* tanh(c);
        h_seq(:,t,:) = h;
    end
end

function h_last = lstm_fwd_last(W, b, x_seq, h0, c0)
    % Last-step output only — used for layer 2
    [Fin, T, B] = size(x_seq);
    H = size(h0, 1);
    h = h0;  c = c0;
    for t = 1:T
        x_t = reshape(x_seq(:,t,:), Fin, B);
        z   = W * [x_t; h] + b;
        i_t = sigm(z(1:H,:));
        f_t = sigm(z(H+1:2*H,:));
        o_t = sigm(z(2*H+1:3*H,:));
        g_t = tanh(z(3*H+1:4*H,:));
        c   = f_t .* c + i_t .* g_t;
        h   = o_t .* tanh(c);
    end
    h_last = h;
end

function pred = lstm_fwd_pass(params, X)
    % X: [F x T x N]
    [~, ~, N] = size(X);
    H  = size(params.W1, 1) / 4;
    h0 = zeros(H, N);
    c0 = zeros(H, N);

    h1      = lstm_fwd_seq( params.W1, params.b1, X,  h0, c0);
    h2_last = lstm_fwd_last(params.W2, params.b2, h1, h0, c0);
    pred    = (params.Wfc * h2_last + params.bfc)';   % [N x 1]
end
