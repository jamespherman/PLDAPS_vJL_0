% check_lag_dilution.m  Verify lag-dependent spike count dilution in
% denseChromatic STA due to per-trial stimulus tensor starting at frame 1.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
outDir = fullfile(projRoot, 'output', '20260602_t1157_rfMap_denseChromatic');
d = load(fullfile(outDir, 'trial0001.mat'));

nLags    = d.trVars.nSTALags;
nFrames  = d.trVars.nFramesThisTrial;
fDurMs   = d.trVars.noiseFrameDurS * 1000;
nCh      = d.trVars.nChannels;

fprintf('nLags=%d  nFramesThisTrial=%d  frameDurMs=%.1f  nCh=%d\n\n', ...
    nLags, nFrames, fDurMs, nCh);

fprintf('Predicted dilution (chromatic trialStartFrame=1):\n');
for k = 1:nLags
    frac = (nFrames - k + 1) / nFrames;
    fprintf('  lag %d (%3.0fms): %.1f%% contribute\n', ...
        k, (k-1)*fDurMs, 100*frac);
end

% Measure actual per-lag contributions from saved trial data.
trialFiles = dir(fullfile(outDir, 'trial*.mat'));
nTrials    = numel(trialFiles);
perLag     = zeros(1, nLags);
total      = 0;

for ti = 1:nTrials
    d = load(fullfile(outDir, trialFiles(ti).name));
    evIdx = find(d.trData.eventValues == d.init.codes.stimOn, 1, 'last');
    if isempty(evIdx), continue; end
    stimOn = d.trData.eventTimes(evIdx);
    fDurS  = d.trVars.noiseFrameDurS;
    nF     = d.trVars.nFramesThisTrial;

    for ch = 1:nCh
        spk = d.trData.spikeTimes(d.trData.spikeClusters == ch);
        for s = 1:numel(spk)
            tRel = spk(s) - stimOn;
            fIdx = floor(tRel / fDurS) + 1;
            if fIdx < 1 || fIdx > nF, continue; end
            total = total + 1;
            for k = 1:nLags
                if fIdx - k + 1 >= 1
                    perLag(k) = perLag(k) + 1;
                end
            end
        end
    end
end

fprintf('\nActual per-lag contributions (%d trials, %d total spikes):\n', nTrials, total);
for k = 1:nLags
    fprintf('  lag %d: %d / %d = %.1f%%\n', k, perLag(k), total, 100*perLag(k)/total);
end
fprintf('\nDone.\n');
exit;
