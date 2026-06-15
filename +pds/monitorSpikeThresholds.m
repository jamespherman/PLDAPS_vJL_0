function p = monitorSpikeThresholds(p)
% pds.monitorSpikeThresholds  Track per-channel spike rate drift mid-session.
%
%   p = pds.monitorSpikeThresholds(p)
%
%   Called after each successful trial in rfMap_finish (or any _finish).
%   Tracks per-channel crossing rates over a sliding window and compares
%   to the session baseline (first baselineTrials good trials). Channels
%   whose rate drops below driftLowFrac of baseline or rises above
%   driftHighFrac are flagged. A summary is stored on p.status.threshMon
%   for the online display to consume.
%
%   Does NOT read waveforms or modify thresholds — purely passive. Use
%   pds.recheckSpikeThresholds for an active RMS re-estimation that
%   requires a brief waveform acquisition.
%
%   Expected fields on p:
%     p.rig.ripple.recChans     - channel indices
%     p.trData.spikeClusters    - per-spike channel assignment this trial
%     p.trData.spikeTimes       - spike times this trial (already trimmed)
%     p.status.iGoodTrial       - current good trial count
%
%   Configurable parameters (via p.trVarsInit, with defaults):
%     threshMonBaselineTrials   - how many initial trials form the baseline (20)
%     threshMonWindowTrials     - sliding window for recent rate (20)
%     threshMonDriftLowFrac     - flag if recent/baseline < this (0.4)
%     threshMonDriftHighFrac    - flag if recent/baseline > this (3.0)

if ~isfield(p.rig, 'ripple') || ~p.rig.ripple.status
    return;
end

nCh = p.trVarsInit.nChannels;
iGood = p.status.iGoodTrial;

baselineTrials = getOr(p.trVarsInit, 'threshMonBaselineTrials', 20);
windowTrials   = getOr(p.trVarsInit, 'threshMonWindowTrials',   20);
driftLowFrac   = getOr(p.trVarsInit, 'threshMonDriftLowFrac',   0.4);
driftHighFrac  = getOr(p.trVarsInit, 'threshMonDriftHighFrac',  3.0);

% Initialize the rate history on first call.
if ~isfield(p.status, 'threshMon') || isempty(p.status.threshMon)
    p.status.threshMon = struct( ...
        'rateHistory',      zeros(nCh, 0), ...
        'baselineRate',     nan(nCh, 1), ...
        'recentRate',       nan(nCh, 1), ...
        'driftRatio',       nan(nCh, 1), ...
        'flaggedLow',       false(nCh, 1), ...
        'flaggedHigh',      false(nCh, 1), ...
        'baselineSet',      false, ...
        'lastCheckTrial',   0);
end
mon = p.status.threshMon;

% Count spikes per channel this trial.
spkPerCh = zeros(nCh, 1);
if ~isempty(p.trData.spikeClusters)
    for ch = 1:nCh
        spkPerCh(ch) = sum(p.trData.spikeClusters == ch);
    end
end
mon.rateHistory(:, end+1) = spkPerCh;

% Set baseline once we have enough trials.
if ~mon.baselineSet && iGood >= baselineTrials
    mon.baselineRate = mean(mon.rateHistory(:, 1:baselineTrials), 2);
    mon.baselineSet = true;
end

% Compute recent rate over the sliding window.
nHist = size(mon.rateHistory, 2);
winStart = max(1, nHist - windowTrials + 1);
mon.recentRate = mean(mon.rateHistory(:, winStart:end), 2);

% Compute drift ratio and flag channels.
if mon.baselineSet
    safeBaseline = max(mon.baselineRate, 0.1);
    mon.driftRatio = mon.recentRate ./ safeBaseline;
    mon.flaggedLow  = mon.driftRatio < driftLowFrac & mon.baselineRate > 1;
    mon.flaggedHigh = mon.driftRatio > driftHighFrac & mon.baselineRate > 1;
    mon.lastCheckTrial = iGood;
end

p.status.threshMon = mon;

% Print warning if any channels are flagged.
nLow  = sum(mon.flaggedLow);
nHigh = sum(mon.flaggedHigh);
if nLow > 0 || nHigh > 0
    lowCh  = find(mon.flaggedLow);
    highCh = find(mon.flaggedHigh);
    if nLow > 0
        fprintf('  *** THRESH DRIFT: %d ch rate DROP (<%d%% baseline): ch %s\n', ...
            nLow, round(100*driftLowFrac), num2str(lowCh(:)'));
    end
    if nHigh > 0
        fprintf('  *** THRESH DRIFT: %d ch rate SURGE (>%dx baseline): ch %s\n', ...
            nHigh, round(driftHighFrac), num2str(highCh(:)'));
    end
end

end


function v = getOr(s, f, d)
if isfield(s, f), v = s.(f); else, v = d; end
end
