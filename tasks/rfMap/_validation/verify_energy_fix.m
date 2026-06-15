% verify_energy_fix.m  Confirm the energy metric fix produces correct
% peak lags in the 20260602_t1253 sim session (ran with per-lag spike
% counts but BEFORE the energy*N_k fix in the online code).
%
% We reconstruct offline with the corrected metric and compare against
% the ground-truth temporal kernel peak.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
outDir = fullfile(projRoot, 'output', '20260602_t1253_rfMap_denseChromatic');

trialFiles = dir(fullfile(outDir, 'trial*.mat'));
trialNums  = cellfun(@(f) sscanf(f, 'trial%d.mat'), {trialFiles.name});
[trialNums, sortIdx] = sort(trialNums);
trialFiles = trialFiles(sortIdx);
nTrialFiles = numel(trialFiles);

d1 = load(fullfile(outDir, trialFiles(1).name));
dLast = load(fullfile(outDir, trialFiles(end).name));

nCh       = d1.trVars.nChannels;
nLags     = d1.trVars.nSTALags;
nY        = d1.init.noiseGridSize(1);
nX        = d1.init.noiseGridSize(2);
frameDurS = d1.trVars.noiseFrameDurS;
frameDurMs = frameDurS * 1000;
lagAxisMs  = (0:nLags-1) * frameDurMs;
stimOnCode = d1.init.codes.stimOn;

fprintf('Session: %s\n', outDir);
fprintf('Trials: %d | nCh=%d | nLags=%d | frameDur=%.0fms\n', ...
    nTrialFiles, nCh, nLags, frameDurMs);
fprintf('Lag axis: [%s] ms\n', num2str(lagAxisMs, '%.0f '));

% Ground truth from kernel bank
bank = dLast.init.simKernelBank;
nSimCh = bank.nSimulated;
fprintf('Simulated channels: %d\n', nSimCh);

gtPeakLag = zeros(nSimCh, 1);
for ch = 1:nSimCh
    k = bank.kernels{ch};
    [~, gtPeakLag(ch)] = max(abs(k.temporalKernel));
end
fprintf('Ground truth peak lag (ch1): idx=%d = %.0fms\n', ...
    gtPeakLag(1), lagAxisMs(gtPeakLag(1)));
fprintf('Ground truth temporal kernel (ch1): %s\n', ...
    num2str(bank.kernels{1}.temporalKernel', '%.4f '));

%% Reconstruct STA offline
staAccum      = cell(nCh, 1);
for ch = 1:nCh, staAccum{ch} = zeros(nY, nX, 3, nLags, 'double'); end
staSpikeCount = zeros(nCh, nLags);
goodTrials    = 0;

for ti = 1:nTrialFiles
    T = load(fullfile(outDir, trialFiles(ti).name), 'trData', 'trVars');
    if isempty(T.trData.spikeTimes), continue; end
    evIdx = find(T.trData.eventValues == stimOnCode, 1, 'last');
    if isempty(evIdx), continue; end
    stimOnTime = T.trData.eventTimes(evIdx);
    trialDurS  = T.trVars.nFramesThisTrial * frameDurS;
    inWin = T.trData.spikeTimes >= stimOnTime & ...
            T.trData.spikeTimes <  stimOnTime + trialDurS;
    spikeTimes    = T.trData.spikeTimes(inWin);
    spikeClusters = T.trData.spikeClusters(inWin);
    if isempty(spikeTimes), continue; end
    spikeTimesPerChan = cell(nCh, 1);
    for ch = 1:nCh
        spikeTimesPerChan{ch} = spikeTimes(spikeClusters == ch);
    end
    dklDrive = T.trVars.thisTrialDklDrive;
    [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
        staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
        frameDurS, dklDrive, 1, T.trVars.nFramesThisTrial, nLags);
    goodTrials = goodTrials + 1;
end
fprintf('\nReconstructed STA from %d trials\n', goodTrials);

%% Compute energy with corrected metric
fprintf('\n=== ENERGY METRIC VERIFICATION ===\n');
fprintf('  ch | N(lag1) | GT peak | uncorrected peak | corrected peak | match?\n');
fprintf('  ---+---------+---------+------------------+----------------+-------\n');

nCorrect_uncorr = 0;
nCorrect_corr   = 0;
for ch = 1:nSimCh
    if max(staSpikeCount(ch, :)) < 1, continue; end
    counts = max(staSpikeCount(ch, :), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, 1, []);
    staMag = squeeze(sqrt(sum(sta.^2, 3)));

    % Uncorrected energy (old behavior)
    energyUncorr = squeeze(sum(sum(staMag.^2, 1), 2))';
    [~, peakUncorr] = max(energyUncorr);

    % Corrected energy (new behavior)
    energyCorr = energyUncorr .* counts;
    [~, peakCorr] = max(energyCorr);

    gtPk = gtPeakLag(ch);
    matchUncorr = peakUncorr == gtPk;
    matchCorr   = peakCorr == gtPk;
    nCorrect_uncorr = nCorrect_uncorr + matchUncorr;
    nCorrect_corr   = nCorrect_corr + matchCorr;

    fprintf('  %2d | %7d | %3.0fms   | %3.0fms             | %3.0fms           | %s\n', ...
        ch, staSpikeCount(ch, 1), lagAxisMs(gtPk), ...
        lagAxisMs(peakUncorr), lagAxisMs(peakCorr), ...
        ternary(matchCorr, 'YES', 'no'));
end

fprintf('\nPeak lag accuracy:\n');
fprintf('  Uncorrected: %d/%d correct\n', nCorrect_uncorr, nSimCh);
fprintf('  Corrected:   %d/%d correct\n', nCorrect_corr, nSimCh);

%% Also show energy profiles for ch1 both ways
ch = 1;
counts = max(staSpikeCount(ch, :), 1);
sta = staAccum{ch} ./ reshape(counts, 1, 1, 1, []);
staMag = squeeze(sqrt(sum(sta.^2, 3)));
energyUncorr = squeeze(sum(sum(staMag.^2, 1), 2))';
energyCorr = energyUncorr .* counts;

fprintf('\nch1 energy profiles:\n');
fprintf('  Lag (ms):      %s\n', num2str(lagAxisMs, '%6.0f'));
fprintf('  N_k:           %s\n', num2str(counts, '%6d'));
fprintf('  Uncorrected:   %s\n', num2str(energyUncorr, '%6.4f'));
fprintf('  Corrected:     %s\n', num2str(energyCorr, '%6.1f'));
fprintf('  GT temporal:   %s\n', num2str(bank.kernels{1}.temporalKernel', '%6.4f'));

exit;

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
