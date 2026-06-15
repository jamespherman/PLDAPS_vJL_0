% diagnose_chromatic_sim.m  Check lag parameters and per-lag spike counts.
projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
outDir = fullfile(projRoot, 'output', '20260602_t1241_rfMap_denseChromatic');

d = load(fullfile(outDir, 'trial0001.mat'));
fprintf('nSTALags = %d\n', d.trVars.nSTALags);
fprintf('noiseFrameDurS = %.4f\n', d.trVars.noiseFrameDurS);
fprintf('noiseFrameHold = %d\n', d.trVars.noiseFrameHold);
fprintf('nFramesThisTrial = %d\n', d.trVars.nFramesThisTrial);
fprintf('frameDurMs = %.1f\n', d.trVars.noiseFrameDurS * 1000);
fprintf('maxLagMs = %.0f\n', (d.trVars.nSTALags - 1) * d.trVars.noiseFrameDurS * 1000);
fprintf('trialDurS = %.2f\n', d.trVars.nFramesThisTrial * d.trVars.noiseFrameDurS);

p = load(fullfile(outDir, 'p.mat'));
fprintf('\nstaSpikeCount size: [%s]\n', num2str(size(p.init.staSpikeCount)));

nCh = size(p.init.staSpikeCount, 1);
nLags = d.trVars.nSTALags;
fprintf('\nPer-lag spike counts (first 8 active channels):\n');
shown = 0;
for ch = 1:nCh
    counts = p.init.staSpikeCount(ch, :);
    if max(counts) > 0
        fprintf('  ch%02d: %s\n', ch, num2str(counts, '%6d'));
        shown = shown + 1;
        if shown >= 8, break; end
    end
end

% Compute ratio of lag-N to lag-1 counts
fprintf('\nLag count ratios (ch1): ');
c1 = p.init.staSpikeCount(1,:);
for k = 1:nLags
    fprintf('%.3f ', c1(k) / max(c1(1), 1));
end
fprintf('\n');

% Also check: temporal kernel from simKernelBank to see expected peak
if isfield(p.init, 'simKernelBank')
    bank = p.init.simKernelBank;
    k = bank.kernels{1};
    fprintf('\nGround truth temporal kernel (ch1): %s\n', ...
        num2str(k.temporalKernel', '%.4f '));
    [~, peakIdx] = max(abs(k.temporalKernel));
    noiseFrameDurMs = d.trVars.noiseFrameDurS * 1000;
    fprintf('Peak at lagIdx=%d = %.0fms\n', peakIdx, (peakIdx-1)*noiseFrameDurMs);
end

exit;
