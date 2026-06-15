% test_multitask_population.m  Validate shared population architecture.
%
% Headless test: generates a population, builds kernel banks for
% denseAchromatic and checkerboard stim types from the same population,
% runs a short sim (50 trials denseAchromatic), computes RF centers and
% quality scores, and verifies consistency.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
figDir = fullfile(projRoot, 'tasks', 'rfMap', '_validation', 'figs_multitask');
if ~isfolder(figDir), mkdir(figDir); end

fprintf('=== MULTI-TASK POPULATION TEST ===\n\n');

%% Step 1: Generate a population
popFile = fullfile(figDir, 'test_population.mat');
pop = simGeneratePopulation( ...
    'nNeurons', 8, ...
    'nChannels', 64, ...
    'hemifield', 'left', ...
    'eccentricityRange', [1 5], ...
    'elevationRange', [-3 3], ...
    'seed', 99, ...
    'baseRate', 2, ...
    'peakRate', 20, ...
    'saveFile', popFile);

fprintf('\n--- Population neurons ---\n');
fprintf('  ch | center(dva)  | sigma | pol | base | peak | DKL\n');
fprintf('  ---+--------------+-------+-----+------+------+----\n');
for k = 1:numel(pop.neurons)
    n = pop.neurons(k);
    fprintf('  %2d | (%+5.1f,%+5.1f) | %4.2f  |  %+d | %4.1f | %4.1f | [%.1f %.1f %.1f]\n', ...
        n.channelIdx, n.centerDeg(1), n.centerDeg(2), ...
        n.sigmaCenterDeg, n.polarity, n.baseRate, n.peakRate, ...
        n.dklWeights(1), n.dklWeights(2), n.dklWeights(3));
end
fprintf('  Noise channels: %d\n\n', numel(pop.noiseChannels));

%% Step 2: Verify population file loads correctly
tmp = load(popFile, 'population');
assert(numel(tmp.population.neurons) == 8, 'Population should have 8 neurons');
assert(tmp.population.nChannels == 64, 'Population should have 64 channels');
fprintf('Population file verified: %s\n\n', popFile);

%% Step 3: Build kernel bank for denseAchromatic (headless, no p struct)
% We need to simulate enough of the p struct for simLoadPopulation.
% Compute grid geometry the same way rfMap_init does.
nLags = 8; checkSizeDeg = 2.0;
frameDurMs = 100; nChannels = 64;

screenW = 1920; screenH = 1080;

% Minimal p struct for kernel bank construction.
p = struct();
p.trVarsInit.nChannels = nChannels;
p.trVarsInit.nSTALags = nLags;
p.trVarsInit.checkSizeDeg = checkSizeDeg;
p.trVarsInit.noiseFrameHold = 1;
p.trVarsInit.fixDegX = 0;
p.trVarsInit.fixDegY = 0;
p.trVarsInit.rfCenterThreshFrac = 0.5;
p.init.stimType = 'denseAchromatic';
p.draw.middleXY = [screenW/2 screenH/2];
p.rig.frameDuration = 0.01;  % 100 Hz
p.rig.screenh = 0.30;       % 30 cm screen height
p.rig.screenhpix = 1080;    % vertical resolution
p.rig.viewdist = 0.60;      % 60 cm viewing distance (~38 pix/deg)

% Compute grid size exactly as rfMap_init:generateStimForTask does.
checkSizePix = pds.deg2pix(checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end
gridWidthPix = screenW / 2;  % left hemifield
gridCenterX  = screenW / 4;
nX = ceil(gridWidthPix / checkSizePix);
nY = ceil(screenH / checkSizePix);
p.init.noiseGridSize = [nY nX];
p.init.noiseGridCenterPix = [gridCenterX, screenH/2];
fprintf('Grid: %dx%d checks (checkSizePix=%d, left hemifield)\n', nY, nX, checkSizePix);

% Test that simLoadPopulation runs.
p = simLoadPopulation(p, popFile);
bank = p.init.simKernelBank;

fprintf('\n--- Kernel bank (denseAchromatic) ---\n');
rfCount = 0;
noiseCount = 0;
for ch = 1:bank.nChannels
    k = bank.kernels{ch};
    if isempty(k), continue; end
    if isfield(k, 'isNoise') && k.isNoise
        noiseCount = noiseCount + 1;
    else
        rfCount = rfCount + 1;
        fprintf('  ch%02d: RF at fix(%+5.1f,%+5.1f) grid(%.1f,%.1f) gStd=%.3f\n', ...
            ch, k.rfCenterFixFrame(1), k.rfCenterFixFrame(2), ...
            k.rfCenterGridFrame(1), k.rfCenterGridFrame(2), k.gStd);
    end
end
fprintf('  RF channels: %d, noise channels: %d\n\n', rfCount, noiseCount);

assert(rfCount == 8, 'Expected 8 RF channels');
assert(noiseCount > 0, 'Expected noise channels');

%% Step 4: Run a denseAchromatic sim
nTrials = 300;
framesPerTrial = 15;
nTotalFrames = nTrials * framesPerTrial;
rng(12345, 'twister');
noiseMovie = uint8(rand(nY, nX, nTotalFrames) > 0.5);
frameDurS = frameDurMs / 1000;
fprintf('Noise movie: [%d x %d x %d]\n', nY, nX, nTotalFrames);

% Accumulate STA.
staAccum = cell(nChannels, 1);
for ch = 1:nChannels, staAccum{ch} = zeros(nY, nX, nLags); end
staSpikeCount = zeros(nChannels, nLags);
totalSpikes = 0;

fprintf('Simulating %d trials of denseAchromatic (%dx%d grid)...\n', nTrials, nY, nX);
for trial = 1:nTrials
    f0 = (trial-1) * framesPerTrial + 1;
    f1 = f0 + framesPerTrial - 1;
    S = double(noiseMovie(:,:,f0:f1)) - 0.5;

    spikeTimesPerChan = cell(nChannels, 1);
    stimOnTime = 0;

    for ch = 1:nChannels
        k = bank.kernels{ch};
        if isempty(k), continue; end

        seed = mod(42 + ch + 10000*trial, 2^32 - 1);
        chRs = RandStream('mt19937ar', 'Seed', uint32(seed));

        if isfield(k, 'isNoise') && k.isNoise
            g = zeros(framesPerTrial, 1);
            spkRel = simLNPSpikes(g, k.baseRate, 0, frameDurS, chRs);
        else
            sk = k.spatialKernel;
            sFlat = reshape(S, [], framesPerTrial);
            proj = sk(:)' * sFlat;
            g = filter(k.temporalKernel, 1, proj(:));
            g = g / k.gStd;
            spkRel = simLNPSpikes(g, k.baseRate, k.peakRate, frameDurS, chRs);
        end

        if ~isempty(spkRel)
            spikeTimesPerChan{ch} = stimOnTime + spkRel;
            totalSpikes = totalSpikes + numel(spkRel);
        end
    end

    [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
        staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
        frameDurS, noiseMovie, f0, framesPerTrial, nLags);

    if mod(trial, 50) == 0
        fprintf('  Trial %d: %d total spikes\n', trial, totalSpikes);
    end
end

%% Step 5: Compute RF centers and quality scores
p.init.staAccum = staAccum;
p.init.staSpikeCount = staSpikeCount;
p.trVars.checkSizeDeg = checkSizeDeg;
p.draw.fixPointPix = p.draw.middleXY;

rfCenters = computeRFCenters(p);

% Compute quality scores.
quality = computeChannelQuality(p);

fprintf('\n=== CHANNEL QUALITY SCORES ===\n');
fprintf('  ch | spikes | peakSNR | spatSNR | spread(deg) | center(dva)   | pass | reasons\n');
fprintf('  ---+--------+---------+---------+-------------+---------------+------+--------\n');

nPass = 0;
rfErrors = [];
for ch = 1:nChannels
    q = quality(ch);
    if q.spikeCount == 0 && isnan(q.peakSNR), continue; end

    passStr = 'FAIL';
    if q.passGo, passStr = 'PASS'; nPass = nPass + 1; end

    reasonStr = strjoin(q.failReasons, ', ');
    if isempty(reasonStr), reasonStr = '-'; end

    fprintf('  %2d | %6d | %7.1f | %7.1f | %11.2f | (%+5.1f,%+5.1f) | %s | %s\n', ...
        ch, q.spikeCount, q.peakSNR, q.spatialSNR, q.rfSpreadDeg, ...
        q.rfCenterDeg(1), q.rfCenterDeg(2), passStr, reasonStr);

    % Compute error for RF channels.
    k = bank.kernels{ch};
    if ~isempty(k) && ~(isfield(k, 'isNoise') && k.isNoise) && ~any(isnan(q.rfCenterDeg))
        gtX = k.rfCenterFixFrame(1);
        gtY = k.rfCenterFixFrame(2);
        err = sqrt((q.rfCenterDeg(1) - gtX)^2 + (q.rfCenterDeg(2) - gtY)^2);
        rfErrors = [rfErrors; ch err]; %#ok<AGROW>
    end
end

fprintf('\n  Channels passing go/no-go: %d / %d RF channels\n', nPass, rfCount);

if ~isempty(rfErrors)
    fprintf('\n--- RF center recovery (population-loaded kernels) ---\n');
    fprintf('  ch | error(dva) | error(checks)\n');
    fprintf('  ---+------------+--------------\n');
    for i = 1:size(rfErrors, 1)
        fprintf('  %2d | %10.3f | %13.2f\n', ...
            rfErrors(i,1), rfErrors(i,2), rfErrors(i,2) / checkSizeDeg);
    end
    fprintf('  Median error: %.3f dva (%.2f checks)\n', ...
        median(rfErrors(:,2)), median(rfErrors(:,2)) / checkSizeDeg);
end

%% Step 6: Figure — STA gallery + quality
nRF = rfCount;
fig = figure('Visible', 'off', 'Position', [0 0 1200 400]);
rfIdx = 0;
for ch = 1:nChannels
    k = bank.kernels{ch};
    if isempty(k) || (isfield(k, 'isNoise') && k.isNoise), continue; end
    rfIdx = rfIdx + 1;

    counts = max(staSpikeCount(ch,:), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, []);
    energy = squeeze(sum(sum(sta.^2,1),2))';
    energy = energy .* counts;
    [~, pk] = max(energy);
    slice = sta(:,:,pk);

    subplot(2, nRF, rfIdx);
    imagesc(slice); axis image;
    cLim = max(abs(slice(:)));
    if cLim > 0, caxis([-cLim cLim]); end
    colormap(gca, bluewhitered(256));

    q = quality(ch);
    if q.passGo
        titleColor = [0 0.5 0];
    else
        titleColor = [0.8 0 0];
    end
    title(sprintf('ch%d %s', ch, ternary(q.passGo, 'PASS', 'FAIL')), ...
        'FontSize', 7, 'Color', titleColor);
    set(gca, 'XTick', [], 'YTick', []);

    % Mark ground truth.
    hold on;
    gtGrid = k.rfCenterGridFrame;
    plot(gtGrid(1)/checkSizeDeg + 0.5, gtGrid(2)/checkSizeDeg + 0.5, ...
        'g+', 'MarkerSize', 12, 'LineWidth', 2);

    % Quality bar chart below.
    subplot(2, nRF, nRF + rfIdx);
    vals = [q.peakSNR / 3, q.spatialSNR / 4, ...
            min(q.spikeCount, 200) / 100, ...
            max(0, 1 - q.rfSpreadDeg / 3)];
    vals = max(vals, 0);
    b = bar(vals, 'FaceColor', 'flat');
    for bi = 1:4
        if vals(bi) >= 1
            b.CData(bi,:) = [0.2 0.7 0.2];
        else
            b.CData(bi,:) = [0.8 0.3 0.2];
        end
    end
    set(gca, 'XTickLabel', {'tSNR','sSNR','N','tight'}, 'FontSize', 6);
    yline(1, 'k--');
    ylim([0 3]);
    title(sprintf('err=%.1fchk', rfErrors(rfIdx,2)/checkSizeDeg), 'FontSize', 7);
end
sgtitle(sprintf('Population sim: %d trials, %d/%d pass', nTrials, nPass, nRF));
print(fig, fullfile(figDir, 'multitask_quality.png'), '-dpng', '-r150');
close(fig);
fprintf('\nSaved multitask_quality.png\n');

fprintf('\n=== TEST COMPLETE ===\n');
exit;


function cmap = bluewhitered(n)
if nargin < 1, n = 256; end
half = floor(n/2);
r = [linspace(0,1,half), ones(1,n-half)]';
g = [linspace(0,1,half), linspace(1,0,n-half)]';
b = [ones(1,half), linspace(1,0,n-half)]';
cmap = [r g b];
end

function v = ternary(cond, a, b)
if cond, v = a; else, v = b; end
end
