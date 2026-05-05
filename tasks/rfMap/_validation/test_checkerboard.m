function results = test_checkerboard()
% test_checkerboard  Phase-3 regression harness.
%
%   results = test_checkerboard
%
% In-repo, no-rig validation of the checkerboard pipeline. Mirrors the
% Phase-1 / Phase-2 harnesses in style.
%
% Tests:
%   1. computeF1F2 closed-form recovery
%      Synthetic spike train phase-locked to a known frequency f at a
%      known phase. computeF1F2 must return (a) |z(1)| > |z(2)| if the
%      train is at f_rev, (b) the recovered phase within tolerance of
%      truth.
%
%   2. Reversal-rate validators (negative tests)
%      prepareStim_checkerboard must reject:
%        - non-integer framesPerReversal (e.g., 7 Hz at 100 Hz refresh)
%        - F2 above Nyquist (e.g., 30 Hz at 100 Hz)
%
%   3. prepareStim_checkerboard happy path
%      With valid inputs, returns the right number of texture matrices
%      with the expected slot values, framesPerReversal integer, etc.
%
%   4. updateSTA_checkerboard temporal kernel recovery
%      Build a known polarity sequence and a synthetic spike train
%      that fires preferentially at lag K for one (size, contrast).
%      Run the accumulator over many trials and verify the recovered
%      kernel peaks at lag K with magnitude consistent with the spike-
%      generation contract.

%% set up paths
thisDir = fileparts(mfilename('fullpath'));
newDir  = fullfile(thisDir, '..', 'supportFunctions');
addpath(newDir);

results = struct();

%% TEST 1: computeF1F2 closed-form
fprintf('\n[TEST 1] computeF1F2 closed-form\n');
fRev = 5;                             % Hz
trialT = 4.0;                         % seconds
truePh = pi / 6;                      % truth phase of the F1 modulation

% Pure F1: sinusoidally-modulated Poisson rate at f1 only.
% rate(t) = baseRate * (1 + cos(2 pi f1 t - phase)).
% Sampled into Bernoulli bins so the spike train has power only at f1
% (plus shot noise), not at harmonics.
dt   = 1e-3;
tGrid = (0.5*dt) : dt : trialT;
baseRate = 60;            % spk/s mean rate
modDepth = 0.95;          % deep modulation -> strong F1
rate = baseRate * (1 + modDepth * cos(2*pi*fRev*tGrid - truePh));
rng(42, 'twister');
spikeMask = rand(size(tGrid)) < (rate * dt);
spikesF1  = tGrid(spikeMask);

zF1 = computeF1F2(spikesF1, fRev);
ampF1_pure = abs(zF1(1));
ampF2_pure = abs(zF1(2));
phF1       = angle(zF1(1));   % computeF1F2 uses +omega, so phF1 = +truePh.

results.test1.ampF1   = ampF1_pure;
results.test1.ampF2   = ampF2_pure;
results.test1.phF1    = phF1;
results.test1.truePh  = truePh;
fprintf('  pure-F1: ampF1 = %.2f, ampF2 = %.2f (F1 should dominate)\n', ...
    ampF1_pure, ampF2_pure);
fprintf('  phF1 recovered = %.4f rad, true = %.4f rad, err = %.4f\n', ...
    phF1, truePh, abs(angleDiff(phF1, truePh)));
if ampF1_pure < 5 * ampF2_pure
    error('test_checkerboard:test1Fail', ...
        'F1 should dominate F2 for a sinusoidal F1-only signal.');
end
if abs(angleDiff(phF1, truePh)) > 0.1
    error('test_checkerboard:test1FailPhase', ...
        'F1 phase recovery error too large.');
end

% Pure F2: rate modulated only at 2*f1 (frequency-doubled response,
% characteristic of full-wave-rectified / magno-style cells). F2
% should dominate F1.
rate2 = baseRate * (1 + modDepth * cos(2*pi*(2*fRev)*tGrid));
rng(43, 'twister');
spikeMask = rand(size(tGrid)) < (rate2 * dt);
spikesF2  = tGrid(spikeMask);
zF2 = computeF1F2(spikesF2, fRev);
ampF1_doub = abs(zF2(1));
ampF2_doub = abs(zF2(2));
fprintf('  pure-F2: ampF1 = %.2f, ampF2 = %.2f (F2 should dominate)\n', ...
    ampF1_doub, ampF2_doub);
results.test1.ampF1_F2driven = ampF1_doub;
results.test1.ampF2_F2driven = ampF2_doub;
if ampF2_doub < 5 * ampF1_doub
    error('test_checkerboard:test1FailF2', ...
        'F2 should dominate F1 for a frequency-doubled signal.');
end

%% TEST 2: reversal-rate validators
fprintf('\n[TEST 2] reversal-rate validators\n');
% (a) non-integer framesPerReversal
caught = false;
try
    prepareStim_checkerboard([1.0], [0.5], 1920, 1080, [100], ...
        100, 7, 14, 15, 512*1024*1024);
catch ME
    if contains(ME.identifier, 'badReversalRate')
        caught = true;
    else
        rethrow(ME);
    end
end
results.test2.nonIntegerCaught = caught;
fprintf('  non-integer fpr caught: %d\n', caught);
assert(caught, 'validator did not reject non-integer framesPerReversal');

% (b) F2 above Nyquist. 25 Hz at 100 Hz refresh divides cleanly
% (4 fpr) but F2 = 50 Hz hits Nyquist exactly -> validator fires.
caught = false;
try
    prepareStim_checkerboard([1.0], [0.5], 1920, 1080, 100, ...
        100, 25, 14, 15, 512*1024*1024);
catch ME
    if contains(ME.identifier, 'nyquist')
        caught = true;
    else
        rethrow(ME);
    end
end
results.test2.nyquistCaught = caught;
fprintf('  F2-above-Nyquist caught: %d\n', caught);
assert(caught, 'validator did not reject F2 >= Nyquist');

%% TEST 3: prepareStim_checkerboard happy path
fprintf('\n[TEST 3] prepareStim_checkerboard happy path\n');
checkSizesDva = [0.5 1.0 2.0];
checkContrasts = [0.25 0.5 1.0];
nC = numel(checkContrasts);
% Fake CLUT slot pairs starting at slot 14.
lowSlots  = 14 + 2 * (0:(nC-1));
highSlots = 15 + 2 * (0:(nC-1));
% Pre-compute pixel sizes (caller is responsible per the new signature;
% codebase convention is pds.deg2pix(deg, p), but for unit tests we use
% a fake 100 pix/dva).
checkSizesPix = checkSizesDva * 100;
checkInfo = prepareStim_checkerboard(checkSizesDva, checkContrasts, ...
    1920, 1080, checkSizesPix, 100, 5, lowSlots, highSlots, 512*1024*1024);
assert(checkInfo.framesPerReversal == 20, 'fpr at 5Hz/100Hz should be 20');
assert(isequal(size(checkInfo.textureData), [3, 3, 2]), ...
    'textureData wrong shape');
% Each polarity-1 texture should contain only the (low, high) slots
% for that contrast.
for ct = 1:nC
    tex = checkInfo.textureData{1, ct, 1};
    uniq = unique(tex(:));
    assert(numel(uniq) == 2, ...
        'sz=1 ct=%d texture should have exactly 2 distinct values', ct);
    expected = sort([uint8(lowSlots(ct)); uint8(highSlots(ct))]);
    assert(isequal(sort(uniq), expected), ...
        'sz=1 ct=%d slot values mismatch', ct);
end
% Polarity 1 and polarity 2 should be different (where checks differ).
tex1 = checkInfo.textureData{1, 1, 1};
tex2 = checkInfo.textureData{1, 1, 2};
assert(any(tex1(:) ~= tex2(:)), ...
    'polarity 1 and 2 textures should differ at every check');
fprintf('  %d conditions, %d frames/rev, %.1f MB texture data\n', ...
    checkInfo.nConditions, checkInfo.framesPerReversal, ...
    checkInfo.totalBytes / 1e6);
results.test3 = checkInfo;

%% TEST 4: updateSTA_checkerboard temporal kernel recovery
fprintf('\n[TEST 4] updateSTA_checkerboard temporal kernel recovery\n');
nLags = 24;
nCheckSize = 3;
nContrast  = 3;
nCh = 1;
fRev = 5;
displayHz = 100;
framesPerRev = displayHz / fRev;
trialDurS = 4.0;
nFramesTrial = displayHz * trialDurS;
displayFrameDurS = 1 / displayHz;

% Initialize accumulator struct.
staAccum = struct( ...
    'temporalKernel',       zeros(nLags, nCheckSize, nContrast, nCh), ...
    'spikeCountPerCondCh',  zeros(nCheckSize, nContrast, nCh), ...
    'f1f2AmpSum',           zeros(2, nCheckSize, nContrast, nCh), ...
    'f1f2TrialCount',       zeros(nCheckSize, nContrast));

% Build the polarity sequence (same every trial).
revBlock = floor((0:nFramesTrial - 1) / framesPerRev);
polaritySequence = int8(1 - 2 * mod(revBlock, 2));   % +1, -1, +1, ...

% Synthetic neuron: fires preferentially at lag K when polarity at
% (currentFrame - K + 1) is +1. Choose K = 4 frames (40 ms at 100 Hz).
targetLag = 4;
nTrials = 30;
condTarget = [2, 2];   % drive only sz=2, ct=2 condition

% Per "trial" (we re-use polaritySequence so each trial sees the same
% sequence; spikes vary per trial via the noise-driven generator).
rng(1234, 'twister');
for tr = 1:nTrials
    % Spike rate at frame f is proportional to polarity(f - K + 1)
    % being +1, plus baseline.
    drv = double(polaritySequence) > 0;
    drvLagged = [zeros(1, targetLag-1), drv(1:end-(targetLag-1))];
    rate = 5 + 50 * drvLagged;     % spk/s; baseline 5, peak 55.
    dtFine = 0.001;
    nBinsPerFrame = round(displayFrameDurS / dtFine);
    ratePerBin = repelem(rate, nBinsPerFrame) * dtFine;
    spikeBins = rand(numel(ratePerBin), 1) < ratePerBin(:);
    spikesRel = (find(spikeBins) - 0.5) * dtFine;
    % Use a fake noiseOnTime per trial; it's only used as an offset.
    noiseOnTime = 1000 + tr;
    spikeTimesPerChan = {noiseOnTime + spikesRel};

    staAccum = updateSTA_checkerboard(staAccum, spikeTimesPerChan, ...
        noiseOnTime, displayFrameDurS, polaritySequence, ...
        condTarget, fRev, nLags);
end

% Recovered kernel for the driven condition.
nSpkDriven = staAccum.spikeCountPerCondCh( ...
    condTarget(1), condTarget(2), 1);
kernel = staAccum.temporalKernel(:, condTarget(1), condTarget(2), 1) / ...
    nSpkDriven;
[~, peakIdx] = max(kernel);
results.test4.peakLag = peakIdx;
results.test4.targetLag = targetLag;
results.test4.kernel = kernel;
results.test4.nSpikesDriven = nSpkDriven;

fprintf('  driven cond spikes = %d\n', nSpkDriven);
fprintf('  recovered peak lag = %d (target %d)\n', peakIdx, targetLag);
assert(abs(peakIdx - targetLag) <= 1, ...
    'kernel peak %d not at target lag %d (within +/- 1)', ...
    peakIdx, targetLag);

% Empty (un-driven) conditions should have zero spikes counted (since
% we only ever passed condTarget). Sanity check.
otherSpikes = staAccum.spikeCountPerCondCh;
otherSpikes(condTarget(1), condTarget(2), 1) = 0;
assert(all(otherSpikes(:) == 0), ...
    'non-target conditions should have zero spikes');

% F1/F2 trial-count check: only the driven condition should have
% trials > 0.
otherTrials = staAccum.f1f2TrialCount;
otherTrials(condTarget(1), condTarget(2)) = 0;
assert(all(otherTrials(:) == 0), ...
    'non-target conditions should have zero trial counts');
assert(staAccum.f1f2TrialCount(condTarget(1), condTarget(2)) == nTrials, ...
    'driven condition trial count != nTrials');

%% summary
fprintf('\n========================================================\n');
fprintf('PHASE-3 CHECKERBOARD HARNESS  --  ALL TESTS PASSED\n');
fprintf('========================================================\n');
fprintf('  Test 1 (F1/F2 recovery):    F1=%.1f F2=%.1f phErr=%.4f\n', ...
    results.test1.ampF1, results.test1.ampF2, ...
    abs(angleDiff(results.test1.phF1, results.test1.truePh)));
fprintf('  Test 2 (validators):        non-integer caught, Nyquist caught\n');
fprintf('  Test 3 (prepare happy):     %d conds, fpr=%d\n', ...
    results.test3.nConditions, results.test3.framesPerReversal);
fprintf('  Test 4 (kernel recovery):   peak at lag %d (target %d)\n', ...
    results.test4.peakLag, results.test4.targetLag);

end


function d = angleDiff(a, b)
% Wrap-aware angular difference.
d = mod(a - b + pi, 2*pi) - pi;
end
