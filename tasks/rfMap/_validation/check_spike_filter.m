% check_spike_filter.m  Verify that the temporal window filter in
% rfMap_finish.m produced clean saved data (no out-of-window spikes).
%
% Usage:
%   check_spike_filter
%   check_spike_filter('output/20260602_t1157_rfMap_denseChromatic')

function check_spike_filter(outDir)

if nargin < 1
    outDir = 'output/20260602_t1157_rfMap_denseChromatic';
end

trialFiles = dir(fullfile(outDir, 'trial*.mat'));
nTrials = numel(trialFiles);
fprintf('Checking %d trial files in %s\n\n', nTrials, outDir);

nBeforeTotal = 0;
nAfterTotal  = 0;

for ti = 1:nTrials
    f = fullfile(outDir, trialFiles(ti).name);
    d = load(f);

    nSpk = numel(d.trData.spikeTimes);

    stimOnCode = d.init.codes.stimOn;
    evIdx = find(d.trData.eventValues == stimOnCode, 1, 'last');
    if isempty(evIdx)
        fprintf('  Trial %02d: no stimOn event, %d spikes (aborted)\n', ti, nSpk);
        continue;
    end
    stimOn = d.trData.eventTimes(evIdx);

    frameDurS = d.trVars.noiseFrameDurS;
    nFrames   = d.trVars.nFramesThisTrial;
    trialDur  = nFrames * frameDurS;
    winEnd    = stimOn + trialDur;

    nBefore = sum(d.trData.spikeTimes < stimOn);
    nAfter  = sum(d.trData.spikeTimes >= winEnd);
    nBeforeTotal = nBeforeTotal + nBefore;
    nAfterTotal  = nAfterTotal + nAfter;

    if nSpk > 0
        minOff = min(d.trData.spikeTimes) - stimOn;
        maxOff = max(d.trData.spikeTimes) - stimOn;
    else
        minOff = NaN;
        maxOff = NaN;
    end

    nCh = numel(unique(d.trData.spikeClusters));
    fprintf('  Trial %02d: %4d spikes, %2d channels | before=%d after=%d | offset [%.4f, %.4f]s\n', ...
        ti, nSpk, nCh, nBefore, nAfter, minOff, maxOff);
end

fprintf('\n--- Summary ---\n');
fprintf('Total out-of-window: %d before + %d after = %d\n', ...
    nBeforeTotal, nAfterTotal, nBeforeTotal + nAfterTotal);
if nBeforeTotal + nAfterTotal == 0
    fprintf('PASS: All saved spikes are within stimulus window.\n');
else
    fprintf('FAIL: %d spikes outside stimulus window.\n', nBeforeTotal + nAfterTotal);
end

end
