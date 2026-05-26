function rfPost = replayBarsweepRF(trial, rfPre, draw)
% rfPost = replayBarsweepRF(trial, rfPre, draw)
%
% Pure offline replay of one trial's RF accumulation. Reconstructs the
% minimal p struct that accumulateBarsweepRF needs from a saved
% trial####.mat (or an in-memory struct of the same shape) plus a
% pre-trial snapshot of p.init.barsweepRF, then calls the live
% accumulator and returns the post-trial RF state.
%
% Lets the validator (validateBarsweepSession) compare the live per-trial
% update against a deterministic replay using only saved fields -- no
% Ripple, no GPU, no figure handles. Also reusable by anyone doing
% post-hoc RF replay against a fresh latency / position-bin / channel
% choice.
%
% Inputs:
%   trial   struct with fields {trVars, trData, status, init} matching
%           the on-disk trial####.mat layout (see +pds/saveP.m).
%   rfPre   pre-trial snapshot of p.init.barsweepRF (the rf struct
%           returned by initBarsweepRF, with the post-prior-trial state
%           of spikeHist/dwellTime/spikeCount/trialsByDirection).
%   draw    (optional) p.draw struct from the session-level p.mat. When
%           provided, the accumulator's on-screen mask uses
%           draw.screenRect to skip frames whose bar center was outside
%           the rendered viewport. When omitted, the on-screen mask is
%           a no-op (frames not filtered) -- matches pre-fix behavior so
%           old replay callers (validateBarsweepSession) keep agreeing
%           against the live accumulator output.
%
% Output:
%   rfPost  the post-trial rf struct. For nonStart trials (which the
%           live path skips entirely; they shouldn't appear on disk
%           because pds.saveP returns before writing the trial file)
%           rfPost == rfPre. The struct preserves figData by reference
%           if rfPre carried one.

assert(isstruct(trial), 'replayBarsweepRF: trial must be a struct.');
assert(isstruct(rfPre), 'replayBarsweepRF: rfPre must be a struct.');
required = {'trVars', 'trData', 'status', 'init'};
for ii = 1:numel(required)
    assert(isfield(trial, required{ii}), ...
        'replayBarsweepRF: trial missing field "%s".', required{ii});
end
assert(isfield(trial.init, 'codes') && isfield(trial.init.codes, 'stimOn'), ...
    'replayBarsweepRF: trial.init.codes.stimOn is required (saved by pds.saveP from p.init).');

% nonStart short-circuit: per plan §0 acceptance criterion #5 the live
% accumulator skips these. saveP returns before writing the file, so we
% should not normally see them, but guard anyway.
if isfield(trial.init, 'state') && ...
        isfield(trial.init.state, 'nonStart') && ...
        isfield(trial.trData, 'trialEndState') && ...
        trial.trData.trialEndState == trial.init.state.nonStart
    rfPost = rfPre;
    return
end

% Build the minimal p struct that accumulateBarsweepRF reads from.
p = struct();
p.trVars              = trial.trVars;
p.trData              = trial.trData;
p.status              = trial.status;
p.init                = struct();
p.init.codes          = trial.init.codes;
p.init.barsweepRF     = rfPre;
p.init.exptType       = trial.init.exptType;
if nargin >= 3 && ~isempty(draw)
    p.draw = draw;
end
% accumulateBarsweepRF also references p.init.barsweepRF.enabled. If the
% caller passed a pre-init snapshot with enabled=false (e.g. Ripple was
% unavailable on the original session), preserve that and short-circuit.
if ~isfield(rfPre, 'enabled') || ~rfPre.enabled
    rfPost = rfPre;
    return
end

p = accumulateBarsweepRF(p);
rfPost = p.init.barsweepRF;

end
