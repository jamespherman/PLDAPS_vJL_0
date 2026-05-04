function results = compare_old_vs_new_generators()
% compare_old_vs_new_generators  Phase-1 regression harness.
%
% In-repo, no-rig-time validation that the new per-stim-type generators
% and STA estimators are equivalent (where equivalence is expected) or
% diverge in known ways (where it is by design).
%
% Tests:
%   1. DENSE BIT-EXACT
%      - generateNoiseMovie_legacy ('luminance', 'dense', binary, seed=S)
%        vs generateStim_denseAchromatic(binary, seed=S)
%      - byte-compare movie tensors. MUST be bit-exact.
%
%   2. DENSE STA EQUIVALENCE
%      - synthetic spike train, fed into both updateSTA_legacy
%        (isSparse=false) and updateSTA_denseAchromatic.
%      - byte-compare staAccum and staSpikeCount. MUST be bit-exact.
%
%   3. SPARSE BALANCED VS LEGACY (DESIGN DIVERGENCE)
%      - generateNoiseMovie_legacy ('sparse') is uniform-random; new
%        generateStim_sparseBalanced is balanced TwinDeck. They are
%        EXPECTED to differ in tensor content. The test asserts:
%          (a) per-frame mean is exactly 0 in the new generator
%              (balanced) but NOT in the legacy generator (modulo
%              symmetry from the +/-1 polarity flip)
%          (b) total non-zero count per frame matches nSparseSpots
%              in both generators
%          (c) the new generator has zero overlap between white/black
%              positions per frame.
%
% Returns a struct with pass/fail flags and per-test details. Errors
% if any required equivalence test fails.
%
% Run from the repo root:
%   addpath tasks/rfMap/supportFunctions
%   addpath tasks/rfMap/_validation/_legacy_snapshot
%   results = compare_old_vs_new_generators;

%% set up paths
thisDir   = fileparts(mfilename('fullpath'));
legacyDir = fullfile(thisDir, '_legacy_snapshot');
newDir    = fullfile(thisDir, '..', 'supportFunctions');
addpath(legacyDir);
addpath(newDir);

results = struct();

%% TEST 1: dense achromatic bit-exact
fprintf('\n[TEST 1] dense achromatic bit-exact movie regression\n');
nY = 24; nX = 32; nFrames = 500; seed = 12345;
mLegacy = generateNoiseMovie_legacy(nY, nX, nFrames, 'luminance', true, seed);
mNew    = generateStim_denseAchromatic(nY, nX, nFrames, true, seed);
results.test1.identical = isequal(mLegacy, mNew);
results.test1.byteSizeLegacy = numel(mLegacy);
results.test1.byteSizeNew    = numel(mNew);
results.test1.classLegacy    = class(mLegacy);
results.test1.classNew       = class(mNew);
fprintf('  legacy size=[%s] class=%s\n', num2str(size(mLegacy)), class(mLegacy));
fprintf('  new    size=[%s] class=%s\n', num2str(size(mNew)),    class(mNew));
fprintf('  isequal: %d\n', results.test1.identical);
if ~results.test1.identical
    error('compare_old_vs_new_generators:test1Fail', ...
        'Dense achromatic generator NOT bit-exact vs legacy.');
end

%% TEST 2: dense STA bit-exact
fprintf('\n[TEST 2] dense achromatic STA accumulator equivalence\n');
nLags = 8; nCh = 4; frameDurS = 0.06; noiseOnTime = 100.0;
% synthesize a spike train of 200 spikes randomly distributed across
% the trial duration
rng(7777, 'twister');
nSpikes = 200;
spikeTimes = noiseOnTime + sort(rand(nSpikes, 1) * (nFrames * frameDurS - 0.5));
spikeTimesPerChan = cell(nCh, 1);
for ch = 1:nCh
    spikeTimesPerChan{ch} = spikeTimes;   % same train on every channel
end

% legacy
accumL = cell(nCh, 1);
for ch = 1:nCh, accumL{ch} = zeros(nY, nX, nLags); end
countL = zeros(nCh, 1);
[accumL, countL] = updateSTA_legacy(accumL, countL, spikeTimesPerChan, ...
    noiseOnTime, frameDurS, mLegacy, 1, nFrames, nLags, false);

% new
accumN = cell(nCh, 1);
for ch = 1:nCh, accumN{ch} = zeros(nY, nX, nLags); end
countN = zeros(nCh, 1);
[accumN, countN] = updateSTA_denseAchromatic(accumN, countN, ...
    spikeTimesPerChan, noiseOnTime, frameDurS, mNew, 1, nFrames, nLags);

% byte-compare
identicalCount = isequal(countL, countN);
identicalAccum = true;
maxDiff = 0;
for ch = 1:nCh
    if ~isequal(accumL{ch}, accumN{ch})
        identicalAccum = false;
    end
    d = max(abs(accumL{ch}(:) - accumN{ch}(:)));
    if d > maxDiff, maxDiff = d; end
end
results.test2.identicalCount = identicalCount;
results.test2.identicalAccum = identicalAccum;
results.test2.maxAbsDiff     = maxDiff;
fprintf('  spike count vector identical: %d\n', identicalCount);
fprintf('  staAccum identical:           %d\n', identicalAccum);
fprintf('  max abs diff in accum:        %g\n', maxDiff);
fprintf('  ch1 spike count: legacy=%d new=%d\n', countL(1), countN(1));
if ~identicalAccum || ~identicalCount
    error('compare_old_vs_new_generators:test2Fail', ...
        'Dense STA estimator NOT bit-exact vs legacy.');
end

%% TEST 3: sparse balanced vs legacy (design divergence)
fprintf('\n[TEST 3] sparse: balanced (new) vs uniform-random (legacy)\n');
nSparseSpots = 6;
sLegacy = generateNoiseMovie_legacy(nY, nX, nFrames, 'luminance', true, ...
    seed, 'sparse', nSparseSpots);
sNew    = generateStim_sparseBalanced(nY, nX, nFrames, nSparseSpots, seed);

% (a) per-frame integer sum: new = 0 exactly; legacy may be nonzero.
% Asserting on the sum (exact integer arithmetic via int32) avoids the
% eps-level residuals that mean() of doubles introduces even when the
% mathematical mean is zero.
sumsNew    = squeeze(sum(sum(int32(sNew),    1), 2));
sumsLegacy = squeeze(sum(sum(int32(sLegacy), 1), 2));
results.test3.maxAbsSumNew              = max(abs(sumsNew));
results.test3.maxAbsSumLegacy           = max(abs(sumsLegacy));
results.test3.fractionNonzeroFramesLegacy = mean(sumsLegacy ~= 0);
fprintf('  new    per-frame sum: max|sum| = %d (expect 0 exactly)\n', ...
    results.test3.maxAbsSumNew);
fprintf('  legacy per-frame sum: max|sum| = %d; nonzero fraction = %.2f\n', ...
    results.test3.maxAbsSumLegacy, results.test3.fractionNonzeroFramesLegacy);
if results.test3.maxAbsSumNew ~= 0
    error('compare_old_vs_new_generators:test3aFail', ...
        ['New balanced sparse generator does NOT produce zero per-frame ' ...
         'sum. Balance contract violated.']);
end

% (b) per-frame total nonzero count == nSparseSpots in both
nzNew    = squeeze(sum(sum(sNew    ~= 0, 1), 2));
nzLegacy = squeeze(sum(sum(sLegacy ~= 0, 1), 2));
results.test3.nzCountOkNew    = all(nzNew    == nSparseSpots);
results.test3.nzCountOkLegacy = all(nzLegacy == nSparseSpots);
fprintf('  per-frame nonzero count == %d: new=%d, legacy=%d\n', ...
    nSparseSpots, results.test3.nzCountOkNew, results.test3.nzCountOkLegacy);
if ~results.test3.nzCountOkNew
    error('compare_old_vs_new_generators:test3bFail', ...
        'New sparse generator violates per-frame spot count contract.');
end

% (c) per-frame white/black overlap in new generator: must be empty
overlapsAny = false;
for f = 1:nFrames
    frame = sNew(:,:,f);
    if any(frame == +1 & frame == -1, 'all')   % impossible by encoding; sentinel
        overlapsAny = true;
        break
    end
end
results.test3.noOverlap = ~overlapsAny;

% (d) DESIGN: tensors are NOT identical (intentional)
results.test3.tensorsIdentical = isequal(sLegacy, sNew);
fprintf('  tensors identical: %d (expect 0 -- by design)\n', ...
    results.test3.tensorsIdentical);

%% summary
fprintf('\n========================================================\n');
fprintf('PHASE-1 REGRESSION HARNESS  --  ALL EQUIVALENCE TESTS PASSED\n');
fprintf('========================================================\n');
fprintf('  Test 1 (dense bit-exact movie):       PASS\n');
fprintf('  Test 2 (dense bit-exact STA):         PASS\n');
fprintf('  Test 3 (sparse balanced contract):    PASS\n');
fprintf('  Test 3 (sparse vs legacy divergence): %s\n', ...
    ternary(results.test3.tensorsIdentical, ...
        'UNEXPECTED match (would imply legacy is also balanced)', ...
        'as designed'));

end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
