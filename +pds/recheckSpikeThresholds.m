function p = recheckSpikeThresholds(p, chans)
% pds.recheckSpikeThresholds  Mid-session RMS re-estimation and optional threshold update.
%
%   p = pds.recheckSpikeThresholds(p)
%   p = pds.recheckSpikeThresholds(p, chans)
%
%   Runs the same waveform-based noise RMS estimation as setSpikeThreshFromRMS,
%   but designed for mid-session use. Compares the current noise sigma to the
%   init-time sigma (stored in p.rig.ripple.spikeThresh) and reports drift.
%
%   By default, this function DOES NOT automatically update thresholds —
%   it reports what changed and stores the comparison on
%   p.status.threshRecheck. Set p.trVarsInit.threshAutoAdjust = true to
%   enable automatic threshold updates (thresholds are set to
%   -mult * currentSigma for channels that have drifted beyond tolerance).
%
%   This function temporarily sets a low test threshold (-3 uV) for 0.3s
%   to acquire noise waveforms. During this window, many noise crossings
%   will be generated and transmitted to Trellis. Call during ITI only.
%
%   Inputs:
%     p     - PLDAPS struct with active Ripple connection.
%     chans - Optional channel list (default: p.rig.ripple.recChans).

if nargin < 2 || isempty(chans)
    chans = p.rig.ripple.recChans;
end
chans = chans(:)';

if ~p.rig.ripple.status
    warning('pds:recheckSpikeThresholds:noRipple', 'Ripple not connected.');
    return;
end

testThresh   = -3;
testDurSec   = 0.3;
nBaselinePre = 10;
driftTol     = 0.5;   % flag if sigma changed by more than 50%
autoAdjust   = false;
if isfield(p.trVarsInit, 'threshAutoAdjust')
    autoAdjust = p.trVarsInit.threshAutoAdjust;
end
mult = 4;
if isfield(p.rig.ripple, 'spikeThresh') && isfield(p.rig.ripple.spikeThresh, 'mult')
    mult = p.rig.ripple.spikeThresh.mult;
end

% Save current thresholds.
currentThresh = pds.xippmex('spike-thresh', chans);
currentThresh = currentThresh(:)';

restored = false;
try
    % Set permissive test threshold.
    pds.xippmex('spike-thresh', chans, testThresh * ones(1, numel(chans)));

    % Flush stale buffer.
    pds.xippmex('spike', chans, 0);
    WaitSecs(testDurSec);

    % Pull noise-crossing waveforms.
    [~, ~, waves, ~] = pds.xippmex('spike', chans, 0);

    % Estimate sigma per channel.
    sigma = nan(numel(chans), 1);
    nWavesPer = zeros(numel(chans), 1);
    for c = 1:numel(chans)
        w = waves{c};
        if isempty(w), continue; end
        w = double(w);
        if size(w, 2) < nBaselinePre, continue; end
        b = w(:, 1:nBaselinePre);
        sigma(c)     = std(b(:));
        nWavesPer(c) = size(w, 1);
    end

    % Restore thresholds (or update if autoAdjust).
    newThresh = currentThresh;
    valid = ~isnan(sigma) & sigma > 0;
    nDrifted = 0;
    driftedChans = [];

    if isfield(p.rig.ripple, 'spikeThresh') && ...
            isfield(p.rig.ripple.spikeThresh, 'sigma')
        initSigma = p.rig.ripple.spikeThresh.sigma(:);
        sigmaRatio = nan(numel(chans), 1);
        sigmaRatio(valid) = sigma(valid) ./ max(initSigma(valid), 0.01);
        drifted = valid & (abs(sigmaRatio - 1) > driftTol);
        nDrifted = sum(drifted);
        driftedChans = chans(drifted);

        if autoAdjust && nDrifted > 0
            newThresh(drifted) = -mult * sigma(drifted)';
            fprintf('  recheckSpikeThresholds: AUTO-ADJUSTED %d channels.\n', nDrifted);
        end
    else
        sigmaRatio = nan(numel(chans), 1);
    end

    pds.xippmex('spike-thresh', chans, newThresh);
    restored = true;

catch ME
    if ~restored
        pds.xippmex('spike-thresh', chans, currentThresh);
    end
    rethrow(ME);
end

% Store results.
p.status.threshRecheck = struct( ...
    'chans',          chans, ...
    'currentSigma',   sigma(:)', ...
    'initSigma',      [], ...
    'sigmaRatio',     sigmaRatio(:)', ...
    'nDrifted',       nDrifted, ...
    'driftedChans',   driftedChans, ...
    'threshApplied',  newThresh, ...
    'autoAdjusted',   autoAdjust && nDrifted > 0, ...
    'nipTime',        pds.xippmex('time'), ...
    'nWaveforms',     nWavesPer(:)');
if isfield(p.rig.ripple, 'spikeThresh') && ...
        isfield(p.rig.ripple.spikeThresh, 'sigma')
    p.status.threshRecheck.initSigma = p.rig.ripple.spikeThresh.sigma;
end

% Report.
if nDrifted > 0
    fprintf(['  recheckSpikeThresholds: %d/%d channels drifted >%.0f%% ' ...
             '(ch: %s). %s\n'], ...
        nDrifted, sum(valid), 100*driftTol, num2str(driftedChans), ...
        ternary(autoAdjust, 'Thresholds updated.', ...
                'Set threshAutoAdjust=true to auto-correct.'));
else
    fprintf('  recheckSpikeThresholds: %d channels checked, no significant drift.\n', ...
        sum(valid));
end

end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
