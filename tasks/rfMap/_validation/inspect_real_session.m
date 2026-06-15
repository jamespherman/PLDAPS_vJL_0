% inspect_real_session.m  Examine structure of real LGN denseChromatic data.
projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
outDir = fullfile(projRoot, 'output', '20260601_t1258_rfMap_denseChromatic');

d = load(fullfile(outDir, 'trial0001.mat'));
fprintf('stimType: %s\n', d.init.stimType);
fprintf('nChannels: %d\n', d.trVars.nChannels);
fprintf('nSTALags: %d\n', d.trVars.nSTALags);
fprintf('noiseFrameDurS: %.4f\n', d.trVars.noiseFrameDurS);
fprintf('noiseFrameHold: %d\n', d.trVars.noiseFrameHold);
fprintf('nFramesThisTrial: %d\n', d.trVars.nFramesThisTrial);
fprintf('checkSizeDeg: %.2f\n', d.trVars.checkSizeDeg);
fprintf('noiseGridSize: [%d %d]\n', d.init.noiseGridSize);
fprintf('Has simKernelBank: %d\n', isfield(d.init, 'simKernelBank'));
fprintf('staSpikeCount size: [%s]\n', num2str(size(d.init.staSpikeCount)));
fprintf('staAccum empty: %d\n', isempty(d.init.staAccum));

fprintf('\nTrial 1 spike data:\n');
fprintf('  spikeTimes: %d spikes\n', numel(d.trData.spikeTimes));
if ~isempty(d.trData.spikeClusters)
    uCh = unique(d.trData.spikeClusters);
    fprintf('  Unique channels: %d\n', numel(uCh));
    fprintf('  Channels: %s\n', num2str(uCh'));
end

% Seed fields for stimulus reconstruction
fnames = fieldnames(d.trVars);
seedFields = fnames(contains(fnames, 'eed', 'IgnoreCase', true));
fprintf('\nSeed-related trVars: %s\n', strjoin(seedFields, ', '));
if isfield(d.trVars, 'dklDriveRngSeed')
    fprintf('dklDriveRngSeed: %d\n', d.trVars.dklDriveRngSeed);
end

% Last trial accumulated counts
dLast = load(fullfile(outDir, 'trial0221.mat'));
fprintf('\n=== LAST TRIAL (221) ===\n');
sc = dLast.init.staSpikeCount;
fprintf('staSpikeCount size: [%s]\n', num2str(size(sc)));
fprintf('Max spike count: %d\n', max(sc(:)));
nActive = sum(max(sc, [], 2) > 0);
fprintf('Channels with spikes: %d\n', nActive);
if nActive > 0
    fprintf('\nPer-channel spike counts (all lags):\n');
    for ch = 1:size(sc,1)
        if max(sc(ch,:)) > 0
            fprintf('  ch%02d: %s\n', ch, num2str(sc(ch,:), '%6d'));
        end
    end
end

% RF centers
if isfield(dLast.init, 'lastRFCentersDeg')
    rc = dLast.init.lastRFCentersDeg;
    fprintf('\nRF centers (non-NaN):\n');
    nValid = 0;
    for ch = 1:size(rc,1)
        if ~any(isnan(rc(ch,:)))
            fprintf('  ch%02d: (%.2f, %.2f) dva\n', ch, rc(ch,1), rc(ch,2));
            nValid = nValid + 1;
        end
    end
    fprintf('Total channels with RF centers: %d\n', nValid);
else
    fprintf('\nNo lastRFCentersDeg field.\n');
end

% Check if old staSpikeCount was 1D (pre-fix)
if size(sc, 2) == 1
    fprintf('\n*** staSpikeCount is 1D — session ran BEFORE per-lag fix ***\n');
else
    fprintf('\n*** staSpikeCount is 2D [nCh x %d] — session ran AFTER per-lag fix ***\n', size(sc,2));
end

exit;
