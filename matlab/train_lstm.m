% =========================================================
% train_lstm.m
% Module 3 — Manual LSTM (no Deep Learning Toolbox required)
%
% Implements a 2-layer LSTM with dropout using plain MATLAB.
% Trains via mini-batch BPTT with Adam optimiser.
%
% Input:  lstm_training_data.mat  (X:[N x T x F], Y:[N x 1])
% Output: lstm_model.mat          (params, norm_params, rmse_val)
% =========================================================

clc; clear; close all;
rng(42);

fprintf('Loading LSTM training data...\n');
data = load('lstm_training_data.mat');
X_raw = data.X;   % [N x T x F]
Y_raw = data.Y;   % [N x 1]
[N, T, F] = size(X_raw);
H = 64;           % hidden units per layer
fprintf('Dataset: %d samples | %d time steps | %d features\n', N, T, F);

%% 1. Normalise features to [0,1]
X_flat = reshape(X_raw, N*T, F);
feat_min   = min(X_flat, [], 1);
feat_max   = max(X_flat, [], 1);
feat_range = feat_max - feat_min;
feat_range(feat_range == 0) = 1;
X_norm = reshape((X_flat - feat_min) ./ feat_range, N, T, F);

% Reorder to [F x T x N] — easier for batch matrix ops
X_all = permute(X_norm, [3 2 1]);   % [F x T x N]
Y_all = Y_raw(:);                    % [N x 1]

%% 2. Train / validation split (80/20)
perm    = randperm(N);
n_train = round(0.8 * N);
tr_idx  = perm(1:n_train);
va_idx  = perm(n_train+1:end);

X_tr = X_all(:,:,tr_idx);   Y_tr = Y_all(tr_idx);
X_va = X_all(:,:,va_idx);   Y_va = Y_all(va_idx);
fprintf('Train: %d | Validation: %d\n\n', n_train, numel(va_idx));

%% 3. Initialise parameters (Xavier)
params = init_params(F, H);

%% 4. Adam state
lr = 0.001;  beta1 = 0.9;  beta2 = 0.999;  eps_a = 1e-8;
adam   = init_adam(params);
adam_t = 0;

%% 5. Training
BATCH    = 32;
N_EPOCH  = 100;
DROP_P   = 0.2;
PATIENCE = 10;

tr_loss  = zeros(N_EPOCH, 1);
val_loss = zeros(N_EPOCH, 1);
best_val = Inf;
p_count  = 0;
best_p   = params;
n_batch  = floor(n_train / BATCH);
last_ep  = N_EPOCH;

fprintf('Training (%d epochs, batch=%d, lr=%.4f)...\n', N_EPOCH, BATCH, lr);
fprintf('%-10s %-14s %-14s\n', 'Epoch', 'Train MSE', 'Val MSE');
fprintf('%s\n', repmat('-', 1, 40));

for ep = 1:N_EPOCH
    shuf   = randperm(n_train);
    Xsh    = X_tr(:,:,shuf);
    Ysh    = Y_tr(shuf);
    ep_loss = 0;

    for b = 1:n_batch
        bi = (b-1)*BATCH+1 : b*BATCH;
        Xb = Xsh(:,:,bi);          % [F x T x BATCH]
        Yb = Ysh(bi);              % [BATCH x 1]

        [pred, fwd] = fwd_pass(params, Xb, DROP_P, true);
        diff = pred - Yb;
        ep_loss = ep_loss + mean(diff.^2);

        dloss = 2 * diff / BATCH;       % [BATCH x 1]
        grads = bwd_pass(params, fwd, dloss);

        adam_t = adam_t + 1;
        [params, adam] = adam_step(params, grads, adam, adam_t, ...
                                   lr, beta1, beta2, eps_a);
    end

    tr_loss(ep)  = ep_loss / n_batch;
    vp           = fwd_pass(params, X_va, 0, false);
    val_loss(ep) = mean((vp - Y_va).^2);

    if mod(ep, 10) == 0
        fprintf('%-10d %-14.6f %-14.6f\n', ep, tr_loss(ep), val_loss(ep));
    end

    % Early stopping
    if val_loss(ep) < best_val - 1e-6
        best_val = val_loss(ep);
        best_p   = params;
        p_count  = 0;
    else
        p_count = p_count + 1;
        if p_count >= PATIENCE
            fprintf('Early stopping at epoch %d.\n', ep);
            last_ep = ep;  break;
        end
    end
end

params = best_p;

%% 6. Final evaluation
val_pred = fwd_pass(params, X_va, 0, false);
rmse_val = sqrt(mean((val_pred - Y_va).^2));
fprintf('\n=== Validation RMSE: %.4f J ===\n', rmse_val);
if rmse_val <= 0.022
    fprintf('PASS — within acceptable range (target: 0.018).\n');
else
    fprintf('WARNING — RMSE above target. Consider more data or epochs.\n');
end

%% 7. Save
norm_params.feat_min   = feat_min;
norm_params.feat_max   = feat_max;
norm_params.feat_range = feat_range;
save('lstm_model.mat', 'params', 'norm_params', 'rmse_val');
fprintf('Model saved to lstm_model.mat\n');

%% 8. Plots
figure('Name', 'Predicted vs Actual');
scatter(Y_va, val_pred, 5, 'filled', 'MarkerFaceAlpha', 0.3);
hold on;
lims = [min(Y_va) max(Y_va)];
plot(lims, lims, 'r--', 'LineWidth', 1.5);
xlabel('Actual Energy (J)'); ylabel('Predicted Energy (J)');
title(sprintf('Validation  RMSE = %.4f J', rmse_val)); grid on;

figure('Name', 'Training Progress');
plot(tr_loss(1:last_ep),  'b-',  'LineWidth', 1.2); hold on;
plot(val_loss(1:last_ep), 'r--', 'LineWidth', 1.2);
xlabel('Epoch'); ylabel('MSE Loss');
title('LSTM Training Progress');
legend('Train Loss', 'Val Loss'); grid on;

fprintf('\nModule 3 training complete.\n');

% =========================================================
%  LOCAL FUNCTIONS
% =========================================================

function p = init_params(F, H)
    s1 = sqrt(2/(F+H));   s2 = sqrt(2/(H+H));   sfc = sqrt(2/H);
    p.W1  = randn(4*H, F+H) * s1;   p.b1  = zeros(4*H, 1);
    p.W2  = randn(4*H, H+H) * s2;   p.b2  = zeros(4*H, 1);
    p.Wfc = randn(1,   H)   * sfc;  p.bfc = 0;
end

function a = init_adam(p)
    fn = fieldnames(p);
    for k = 1:numel(fn)
        a.m.(fn{k}) = zeros(size(p.(fn{k})));
        a.v.(fn{k}) = zeros(size(p.(fn{k})));
    end
end

function [p, a] = adam_step(p, g, a, t, lr, b1, b2, ep)
    fn = fieldnames(p);
    for k = 1:numel(fn)
        f = fn{k};
        a.m.(f) = b1*a.m.(f) + (1-b1)*g.(f);
        a.v.(f) = b2*a.v.(f) + (1-b2)*g.(f).^2;
        mh = a.m.(f) / (1-b1^t);
        vh = a.v.(f) / (1-b2^t);
        p.(f) = p.(f) - lr * mh ./ (sqrt(vh) + ep);
    end
end

function s = sigm(x)
    % Numerically stable sigmoid
    s = zeros(size(x));
    idx = x >= 0;
    s( idx) = 1 ./ (1 + exp(-x(idx)));
    ex = exp(x(~idx));
    s(~idx) = ex ./ (1 + ex);
end

% --- Single LSTM layer forward ---
function [h_seq, c_seq, cache] = lstm_fwd(W, b, x_seq, h0, c0)
    % x_seq : [Fin x T x B]
    % h0,c0 : [H x B]
    [Fin, T, B] = size(x_seq);
    H = size(h0, 1);

    h_seq = zeros(H,T,B); c_seq = zeros(H,T,B);
    ci = zeros(H,T,B); cf = zeros(H,T,B);
    co = zeros(H,T,B); cg = zeros(H,T,B);
    cxh = zeros(Fin+H, T, B);

    h = h0;  c = c0;
    for t = 1:T
        x_t  = reshape(x_seq(:,t,:), Fin, B);
        xh_t = [x_t; h];                          % [(Fin+H) x B]
        z    = W * xh_t + b;                       % [4H x B]
        i_t  = sigm(z(1:H,:));
        f_t  = sigm(z(H+1:2*H,:));
        o_t  = sigm(z(2*H+1:3*H,:));
        g_t  = tanh(z(3*H+1:4*H,:));
        c    = f_t .* c + i_t .* g_t;
        h    = o_t .* tanh(c);
        h_seq(:,t,:)=h;  c_seq(:,t,:)=c;
        ci(:,t,:)=i_t;   cf(:,t,:)=f_t;
        co(:,t,:)=o_t;   cg(:,t,:)=g_t;
        cxh(:,t,:)=xh_t;
    end
    cache = struct('i',ci,'f',cf,'o',co,'g',cg, ...
                   'xh',cxh,'c',c_seq,'c0',c0, ...
                   'T',T,'Fin',Fin,'H',H,'B',B);
end

% --- Single LSTM layer backward ---
function [dW, db, dx_seq, dh0, dc0] = lstm_bwd(W, cache, dh_ext, dc_last)
    % dh_ext : [H x T x B]  external gradient at each time step
    % dc_last: [H x B]
    T=cache.T; Fin=cache.Fin; H=cache.H; B=cache.B;
    dW=zeros(size(W)); db=zeros(4*H,1);
    dx_seq=zeros(Fin,T,B);
    dh_next=zeros(H,B); dc_acc=dc_last;

    for t = T:-1:1
        i_t  = reshape(cache.i(:,t,:), H,B);
        f_t  = reshape(cache.f(:,t,:), H,B);
        o_t  = reshape(cache.o(:,t,:), H,B);
        g_t  = reshape(cache.g(:,t,:), H,B);
        xh_t = reshape(cache.xh(:,t,:), Fin+H, B);
        c_t  = reshape(cache.c(:,t,:), H,B);
        if t > 1; c_prev = reshape(cache.c(:,t-1,:), H,B);
        else;     c_prev = cache.c0; end

        dh_t   = reshape(dh_ext(:,t,:), H,B) + dh_next;
        tanh_c = tanh(c_t);
        do_t   = dh_t .* tanh_c;
        dc_t   = dh_t .* o_t .* (1 - tanh_c.^2) + dc_acc;
        df_t   = dc_t .* c_prev;
        di_t   = dc_t .* g_t;
        dg_t   = dc_t .* i_t;

        dz = [di_t .* i_t .* (1-i_t);
              df_t .* f_t .* (1-f_t);
              do_t .* o_t .* (1-o_t);
              dg_t .* (1-g_t.^2)];       % [4H x B]

        dW = dW + dz * xh_t';
        db = db + sum(dz, 2);
        dxh     = W' * dz;               % [(Fin+H) x B]
        dx_seq(:,t,:) = dxh(1:Fin,:);
        dh_next = dxh(Fin+1:end,:);
        dc_acc  = dc_t .* f_t;
    end
    dh0 = dh_next;
    dc0 = dc_acc;
end

% --- Full forward pass ---
function [pred, fwd] = fwd_pass(params, X, drop_p, training)
    [F,T,B] = size(X);
    H = size(params.W1,1)/4;
    h0=zeros(H,B); c0=zeros(H,B);

    % Layer 1 (sequence output)
    [h1, ~, cache1] = lstm_fwd(params.W1, params.b1, X, h0, c0);

    % Dropout 1
    if training && drop_p > 0
        mask1 = double(rand(H,T,B) > drop_p) / (1-drop_p);
    else
        mask1 = ones(H,T,B);
    end
    h1d = h1 .* mask1;

    % Layer 2 (last-step output)
    [h2, ~, cache2] = lstm_fwd(params.W2, params.b2, h1d, h0, c0);
    h2_last = reshape(h2(:,T,:), H, B);

    % Dropout 2
    if training && drop_p > 0
        mask2 = double(rand(H,B) > drop_p) / (1-drop_p);
    else
        mask2 = ones(H,B);
    end
    h2d = h2_last .* mask2;

    % FC
    pred = (params.Wfc * h2d + params.bfc)';   % [B x 1]

    fwd = struct('cache1',cache1,'h1',h1,'mask1',mask1, ...
                 'cache2',cache2,'h2d',h2d,'mask2',mask2, ...
                 'H',H,'T',T,'B',B);
end

% --- Full backward pass ---
function grads = bwd_pass(params, fwd, dloss)
    H=fwd.H; T=fwd.T; B=fwd.B;
    dl = dloss';                                  % [1 x B]

    % FC backward
    grads.Wfc = dl * fwd.h2d';                   % [1 x H]
    grads.bfc = sum(dl, 2);
    dh2d      = params.Wfc' * dl;                % [H x B]

    % Dropout 2
    dh2_last  = dh2d .* fwd.mask2;

    % LSTM 2 backward (gradient only at last time step)
    dh_ext2 = zeros(H,T,B);
    dh_ext2(:,T,:) = dh2_last;
    [grads.W2, grads.b2, dx2, ~, ~] = lstm_bwd(params.W2, fwd.cache2, ...
                                                dh_ext2, zeros(H,B));

    % Dropout 1
    dx2m = dx2 .* fwd.mask1;

    % LSTM 1 backward
    [grads.W1, grads.b1, ~, ~, ~]   = lstm_bwd(params.W1, fwd.cache1, ...
                                                dx2m, zeros(H,B));
end
