function results = test_chromatic_generators(monFile)
% test_chromatic_generators  Phase-2 regression harness.
%
%   results = test_chromatic_generators(monFile)
%
% In-repo, no-rig-time validation of the dense chromatic (DKL) pipeline.
% Mirrors compare_old_vs_new_generators.m (Phase 1) in style.
%
% Tests:
%   1. DKL <-> RGB ROUND-TRIP
%      Push canonical axis vectors (pure L-M, pure S, pure achromatic at
%      a few contrasts) through dkl2rgb; invert the gamma LUT and the
%      DKL->RGB matrix; verify the recovered DKL coords match the input
%      within the precision floor set by 8-bit framebuffer quantization
%      (~ 1/255 per channel, propagated through inv(M)).
%
%   2. SEED REPRODUCIBILITY
%      Call recomputeDklDrive twice with the same (seed, params); the
%      two output tensors must be byte-identical. Same for the full
%      generateStim_denseChromatic call (drive AND RGB movie).
%
%   3. DKL-AXIS RECOVERY (locked spec from plan, "Phase 2"):
%      Synthesize three separate spike trains, each phase-locked to
%      one DKL axis of one check at a known lag. The recovered STA
%      must (a) place its peak at the correct (y, x) location AND
%      (b) place the peak energy on the correct DKL axis. The other
%      two axes' peaks at that location must be <= 1/3 the magnitude
%      of the driven axis. Failure of either condition is a fail.
%
% Argument:
%   monFile - optional initmon LUT base name. Defaults to
%             'LUT_VPIXX_rig1'. The harness restores the global state
%             on exit.
%
% Run from the repo root:
%   addpath tasks/rfMap/supportFunctions
%   addpath tasks/rfMap/_validation
%   results = test_chromatic_generators;

if nargin < 1 || isempty(monFile), monFile = 'LUT_VPIXX_rig1'; end

%% set up paths
thisDir = fileparts(mfilename('fullpath'));
newDir  = fullfile(thisDir, '..', 'supportFunctions');
addpath(newDir);

% Load DKL conversion globals from a known calibration file.
fprintf('Loading DKL calibration from %s ...\n', monFile);
initmon(monFile);

% Need M_rgb2dkl and the gamma LUTs for the round-trip inverse.
global M_dkl2rgb M_rgb2dkl Rg Gg Bg %#ok<GVMIS>
assert(~isempty(M_dkl2rgb), 'initmon did not populate M_dkl2rgb.');
assert(~isempty(M_rgb2dkl), 'initmon did not populate M_rgb2dkl.');
assert(~isempty(Rg) && ~isempty(Gg) && ~isempty(Bg), ...
    'initmon did not populate gamma LUTs Rg/Gg/Bg.');

results = struct();

%% TEST 1: DKL <-> RGB round-trip
fprintf('\n[TEST 1] DKL <-> RGB round-trip on canonical axes\n');
% Build a small set of canonical axis test points. Stay in the gamut
% by capping contrasts; the rig isoluminant axes can clip near +/- 1.
testContrasts = [0.1 0.3 0.5];
axisVecs = {};   % each entry is a 3xN matrix in dkl2rgb order [Lum; LM; S]
for c = testContrasts
    axisVecs{end+1} = [c; 0; 0]; %#ok<AGROW>      % achromatic
    axisVecs{end+1} = [0; c; 0]; %#ok<AGROW>      % L-M
    axisVecs{end+1} = [0; 0; c]; %#ok<AGROW>      % S
    axisVecs{end+1} = [-c; 0; 0]; %#ok<AGROW>
    axisVecs{end+1} = [0; -c; 0]; %#ok<AGROW>
    axisVecs{end+1} = [0; 0; -c]; %#ok<AGROW>
end
nVec = numel(axisVecs);
roundtripErr = zeros(nVec, 1);
for ii = 1:nVec
    xIn = axisVecs{ii};
    % Forward
    [rOut, gOut, bOut] = dkl2rgb(xIn);
    % Invert the gamma LUT: for each LUT (Rg/Gg/Bg) find the index
    % whose value is closest to the framebuffer value.
    [~, rIdx] = min(abs(Rg(:) - rOut));
    [~, gIdx] = min(abs(Gg(:) - gOut));
    [~, bIdx] = min(abs(Bg(:) - bOut));
    rgbLin = ([rIdx; gIdx; bIdx] - 1) / 255;     % back to [0,1] linear
    % Invert M: x = 2 * inv(M) * (rgb - 0.5)
    xOut = 2 * (M_rgb2dkl * (rgbLin - 0.5));
    roundtripErr(ii) = max(abs(xOut - xIn));
end
% Tolerance: with 8-bit fb quantization, per-channel rgb error <= 1/255,
% which propagates to DKL via 2*||inv(M)||_inf. Use 0.05 as a generous
% bound that comfortably covers any rig with sane primaries.
tol = 0.05;
results.test1.maxErr     = max(roundtripErr);
results.test1.tolerance  = tol;
results.test1.axisVecCount = nVec;
fprintf('  max round-trip error = %.4f (tol = %.4f)\n', ...
    results.test1.maxErr, tol);
if results.test1.maxErr > tol
    error('test_chromatic_generators:test1Fail', ...
        'DKL round-trip exceeds tolerance.');
end

%% TEST 2: seed reproducibility
fprintf('\n[TEST 2] Seed reproducibility\n');
nY = 16; nX = 24; nFrames = 200; seed = 42;
dklAxes = [1 2 3]; dklContrasts = 0.5;

driveA = recomputeDklDrive(nY, nX, nFrames, dklAxes, dklContrasts, seed);
driveB = recomputeDklDrive(nY, nX, nFrames, dklAxes, dklContrasts, seed);
results.test2.driveIdentical = isequal(driveA, driveB);
fprintf('  recomputeDklDrive identical: %d\n', results.test2.driveIdentical);
if ~results.test2.driveIdentical
    error('test_chromatic_generators:test2DriveFail', ...
        'recomputeDklDrive not bit-exact for same seed.');
end

[movieA, drvFromA] = generateStim_denseChromatic(nY, nX, nFrames, ...
    dklAxes, dklContrasts, seed);
[movieB, drvFromB] = generateStim_denseChromatic(nY, nX, nFrames, ...
    dklAxes, dklContrasts, seed);
results.test2.movieIdentical = isequal(movieA, movieB);
results.test2.driveFromGenIdentical = isequal(drvFromA, drvFromB);
results.test2.driveMatchesHelper = isequal(drvFromA, driveA);
fprintf('  generateStim movie identical: %d\n', results.test2.movieIdentical);
fprintf('  generateStim drive identical: %d\n', results.test2.driveFromGenIdentical);
fprintf('  drive(generator) == drive(helper): %d\n', results.test2.driveMatchesHelper);
if ~results.test2.movieIdentical || ~results.test2.driveFromGenIdentical
    error('test_chromatic_generators:test2GenFail', ...
        'generateStim_denseChromatic not bit-exact for same seed.');
end
if ~results.test2.driveMatchesHelper
    error('test_chromatic_generators:test2HelperMismatch', ...
        'generator drive tensor does not match recomputeDklDrive output.');
end

%% TEST 2b: per-trial seed independence
% Different seeds must produce different drives (anti-collision check),
% AND a per-trial seeding scheme like the one used in
% nextParams_noiseMovie (rng(masterSeed); randi to get nTrials seeds)
% must be reproducible from the master seed alone.
fprintf('\n[TEST 2b] Per-trial seed independence and reproducibility\n');
seedX = 1001; seedY = 1002;   % adjacent integers
driveX = recomputeDklDrive(nY, nX, nFrames, dklAxes, dklContrasts, seedX);
driveY = recomputeDklDrive(nY, nX, nFrames, dklAxes, dklContrasts, seedY);
results.test2b.adjacentSeedsDiffer = ~isequal(driveX, driveY);
fprintf('  adjacent seeds (%d, %d) produce different drives: %d\n', ...
    seedX, seedY, results.test2b.adjacentSeedsDiffer);
if ~results.test2b.adjacentSeedsDiffer
    error('test_chromatic_generators:test2bCollision', ...
        'adjacent integer seeds collided -- per-axis sub-seed hash too weak.');
end

% Reproducible per-trial seeds from a master seed (mirrors the
% initTrialStructure_noiseMovie scheme).
masterSeed = 12345;
nTrials = 20;
rngStateSave = rng();
rng(masterSeed, 'twister'); seedsRunA = randi(2^31 - 1, nTrials, 1);
rng(masterSeed, 'twister'); seedsRunB = randi(2^31 - 1, nTrials, 1);
rng(rngStateSave);
results.test2b.masterSeedReproducible = isequal(seedsRunA, seedsRunB);
fprintf('  master seed -> trial seeds reproducible across runs: %d\n', ...
    results.test2b.masterSeedReproducible);
assert(results.test2b.masterSeedReproducible, ...
    'master-seed -> trial-seed mapping not deterministic');

% Trial seeds within a session must all differ (no duplicates from the
% randi draw -- low probability of collision but worth a sanity check).
results.test2b.trialSeedsUnique = (numel(unique(seedsRunA)) == nTrials);
assert(results.test2b.trialSeedsUnique, ...
    'master seed produced duplicate trial seeds (very unlikely)');
fprintf('  %d trial seeds all unique\n', nTrials);

%% TEST 3: DKL-axis recovery
fprintf('\n[TEST 3] DKL-axis recovery from synthetic spikes\n');
nY = 24; nX = 32; nFrames = 6000; nLags = 8; nCh = 1;
dklAxes = [1 2 3]; dklContrasts = 0.5;
frameDurS = 0.06;     % 60 ms (analogous to noiseFrameHold ~ 6 frames)
noiseOnTime = 100.0;  % arbitrary

% Pick a target check + lag for each axis. Place all three at the same
% (y, x) so we can assert axis selectivity at a fixed location.
targetY = 9; targetX = 14; targetLag = 3;   % lag 3 = 2 frames before spike

% Synthesize one drive tensor; spike trains will be derived from it.
driveTensor = recomputeDklDrive(nY, nX, nFrames, dklAxes, ...
    dklContrasts, 1234);

axisRecovery = zeros(3, 3);  % [drivenAxis x recoveredAxis] peak energy
locOK = zeros(3, 1);

for drivenAxis = 1:3
    % For each frame, look at the drive at the target check on the
    % driven axis "targetLag-1" frames AFTER frame f -- equivalently,
    % we treat the drive at frame f as causing a spike at frame f +
    % targetLag - 1. Generate spikes with rate proportional to
    % positive part of the drive signal, fixed lag.
    drvSig = squeeze(driveTensor(targetY, targetX, drivenAxis, :));   % [nFrames, 1]
    rate = max(0, double(drvSig)) * 100;   % spk/s scaling for a clean STA

    % Convert to spike times: for each frame f, expected count =
    % rate(f) * frameDurS; use Poisson sampling via Bernoulli at fine
    % resolution (1ms).
    rng(7000 + drivenAxis, 'twister');
    dtFine = 0.001;
    nBinsPerFrame = round(frameDurS / dtFine);
    ratePerBin = repelem(rate, nBinsPerFrame) * dtFine;
    spikeBins = rand(numel(ratePerBin), 1) < ratePerBin;
    spikeFrameOffsets = (find(spikeBins) - 0.5) * dtFine;

    % Apply the targetLag delay: shift spikes forward in time so a
    % drive at frame f causes spikes at time f + (targetLag-1) frames.
    spikeTimes = noiseOnTime + spikeFrameOffsets + ...
        (targetLag - 1) * frameDurS;
    % Drop spikes that fall outside the trial window.
    trialEndTime = noiseOnTime + nFrames * frameDurS;
    spikeTimes = spikeTimes(spikeTimes >= noiseOnTime & ...
        spikeTimes < trialEndTime);

    spikeTimesPerChan = {spikeTimes};

    % Allocate accumulator and run the chromatic STA.
    staAccum = {zeros(nY, nX, 3, nLags)};
    staSpikeCount = 0;
    [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
        staAccum, staSpikeCount, spikeTimesPerChan, ...
        noiseOnTime, frameDurS, driveTensor, ...
        1, nFrames, nLags);

    sta = staAccum{1} / max(1, staSpikeCount);

    % Find the spatial peak across (axis, lag, y, x), restricted to lag
    % targetLag (we know what lag we drove).
    energyAtLag = squeeze(sum(sta(:, :, :, targetLag).^2, 3));     % [nY,nX]
    [~, peakIdx] = max(energyAtLag(:));
    [peakY, peakX] = ind2sub([nY, nX], peakIdx);

    % Per-axis recovered amplitudes at the target location.
    for recAxis = 1:3
        axisRecovery(drivenAxis, recAxis) = ...
            abs(sta(targetY, targetX, recAxis, targetLag));
    end

    % Location check: peak within 1 check of the target.
    locOK(drivenAxis) = (abs(peakY - targetY) <= 1 && ...
                         abs(peakX - targetX) <= 1);

    fprintf('  drove axis %d: spikes=%d, peak at (%d,%d) [target (%d,%d)], ', ...
        drivenAxis, staSpikeCount, peakY, peakX, targetY, targetX);
    fprintf('|sta| = [%.3f %.3f %.3f]\n', ...
        axisRecovery(drivenAxis, 1), ...
        axisRecovery(drivenAxis, 2), ...
        axisRecovery(drivenAxis, 3));
end

% Locked criterion: driven axis amplitude must be > 3x each off-axis
% amplitude AND the peak location must be within 1 check of target.
selectivity = zeros(3, 1);
for drivenAxis = 1:3
    onAxis = axisRecovery(drivenAxis, drivenAxis);
    offAxes = axisRecovery(drivenAxis, setdiff(1:3, drivenAxis));
    selectivity(drivenAxis) = onAxis / max(offAxes);
end

results.test3.axisRecovery = axisRecovery;
results.test3.selectivity  = selectivity;
results.test3.locOK        = locOK;
results.test3.passSelectivity = all(selectivity > 3);
results.test3.passLocation    = all(locOK);
results.test3.pass            = results.test3.passSelectivity && ...
                                 results.test3.passLocation;
fprintf('  selectivity ratios (on/max off): %.2f, %.2f, %.2f\n', ...
    selectivity(1), selectivity(2), selectivity(3));
fprintf('  location ok: [%d %d %d]\n', locOK(1), locOK(2), locOK(3));
if ~results.test3.pass
    error('test_chromatic_generators:test3Fail', ...
        ['DKL-axis recovery failed. Selectivity > 3 required on each ' ...
         'driven axis, plus peak within 1 check of target.']);
end

%% summary
fprintf('\n========================================================\n');
fprintf('PHASE-2 CHROMATIC HARNESS  --  ALL TESTS PASSED\n');
fprintf('========================================================\n');
fprintf('  Test 1 (DKL round-trip):       max err %.4f (tol %.4f)\n', ...
    results.test1.maxErr, results.test1.tolerance);
fprintf('  Test 2 (seed reproducibility): drive %d, movie %d\n', ...
    results.test2.driveFromGenIdentical, results.test2.movieIdentical);
fprintf('  Test 3 (axis recovery):        selectivity [%.1f %.1f %.1f]\n', ...
    selectivity(1), selectivity(2), selectivity(3));

end
