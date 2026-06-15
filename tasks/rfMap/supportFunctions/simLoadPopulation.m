function p = simLoadPopulation(p, populationFile)
% simLoadPopulation  Build a task-specific kernel bank from a saved population.
%
%   p = simLoadPopulation(p, populationFile)
%
%   Drop-in replacement for simInitKernelBank when a shared population file
%   is available. Loads the population spec and converts it into the same
%   p.init.simKernelBank structure that simulateRippleData expects.
%
%   The population file contains neuron-level properties (RF center, sigma,
%   temporal dynamics, DKL weights, channel mapping, rates). This function
%   builds the task-specific kernel (spatial, temporal, gStd) using the
%   current session's grid geometry and stim type, then populates noise
%   channels from the population's noise channel list.
%
%   This enables running multiple tasks (denseAchromatic, denseChromatic,
%   checkerboard, barsweep) against the same ground-truth LGN population,
%   so recovered RF centers can be cross-validated across tasks.

if ~exist(populationFile, 'file')
    error('simLoadPopulation:fileNotFound', ...
        'Population file not found: %s', populationFile);
end
tmp = load(populationFile, 'population');
pop = tmp.population;

stimType = p.init.stimType;
nTotalCh = p.trVarsInit.nChannels;
nLags    = p.trVarsInit.nSTALags;

if nTotalCh ~= pop.nChannels
    warning('simLoadPopulation:channelMismatch', ...
        'Session nChannels=%d but population has %d. Using min.', ...
        nTotalCh, pop.nChannels);
    nTotalCh = min(nTotalCh, pop.nChannels);
end

nNeurons = numel(pop.neurons);
bank = struct( ...
    'nChannels',  nTotalCh, ...
    'nSimulated', nNeurons, ...
    'baseSeed',   double(pop.seed), ...
    'stimType',   stimType, ...
    'kernels',    {cell(nTotalCh, 1)}, ...
    'templateCenters', reshape([pop.neurons.centerDeg], 2, [])');

switch stimType
    case {'denseAchromatic', 'sparse', 'denseChromatic'}
        bank = buildSpatialKernels(p, pop, bank, stimType, nLags);
    case 'checkerboard'
        bank = buildCheckerboardKernels(p, pop, bank, nLags);
    otherwise
        error('simLoadPopulation:badStimType', ...
            'Unrecognized stimType ''%s''.', stimType);
end

% Noise channels from population spec.
nNoiseCh = 0;
for i = 1:numel(pop.noiseChannels)
    ch = pop.noiseChannels(i);
    if ch > nTotalCh, continue; end
    bank.kernels{ch} = struct('isNoise', true, ...
        'baseRate', pop.noiseRates(i), 'peakRate', 0);
    nNoiseCh = nNoiseCh + 1;
end
bank.nNoiseChannels = nNoiseCh;
bank.populationFile = populationFile;

p.init.simKernelBank = bank;

fprintf(['simLoadPopulation: %d RF + %d noise / %d total channels ' ...
         '(stimType=%s, from %s)\n'], ...
    nNeurons, nNoiseCh, nTotalCh, stimType, populationFile);

end


function bank = buildSpatialKernels(p, pop, bank, stimType, nLags)

nY = p.init.noiseGridSize(1);
nX = p.init.noiseGridSize(2);
checkSizeDeg    = p.trVarsInit.checkSizeDeg;
noiseFrameDurMs = p.trVarsInit.noiseFrameHold * p.rig.frameDuration * 1000;
isChrom = strcmp(stimType, 'denseChromatic');

% Grid center offset from fixation (mirrors simInitKernelBank).
fixPxX = p.draw.middleXY(1) + pds.deg2pix(p.trVarsInit.fixDegX, p);
fixPxY = p.draw.middleXY(2) - pds.deg2pix(p.trVarsInit.fixDegY, p);
gridCenterDegX = pds.pix2deg(p.init.noiseGridCenterPix(1) - fixPxX, p);
gridCenterDegY = pds.pix2deg(fixPxY - p.init.noiseGridCenterPix(2), p);

% Contrast vector for chromatic gStd.
if isChrom
    contrastVec = zeros(1, 3);
    dklAxes = p.trVarsInit.dklAxes;
    if isscalar(p.trVarsInit.dklContrasts)
        contrastVec(dklAxes) = p.trVarsInit.dklContrasts;
    else
        contrastVec(dklAxes) = p.trVarsInit.dklContrasts(:)';
    end
else
    contrastVec = [];
end

for k = 1:numel(pop.neurons)
    n = pop.neurons(k);
    ch = n.channelIdx;
    if ch > bank.nChannels, continue; end

    cFix = n.centerDeg;
    cGrid = [ cFix(1) - gridCenterDegX + nX * checkSizeDeg / 2, ...
             -(cFix(2) - gridCenterDegY) + nY * checkSizeDeg / 2 ];

    % Scale temporal peak to the noise frame duration so the biphasic
    % kernel has nontrivial support across the lag axis.
    excPeakScaled = max(n.excPeakMs, noiseFrameDurMs * 0.8);
    inhPeakScaled = excPeakScaled * (n.inhPeakMs / max(n.excPeakMs, 1));

    rfp = struct( ...
        'nChecksX',         nX, ...
        'nChecksY',         nY, ...
        'checkSizeDeg',     checkSizeDeg, ...
        'rfCenterDeg',      cGrid, ...
        'rfSigmaCenterDeg', n.sigmaCenterDeg, ...
        'rfSigmaSurrDeg',   n.sigmaSurrDeg, ...
        'rfSurrWeight',     n.surrWeight, ...
        'rfExcPeakMs',      excPeakScaled, ...
        'rfInhPeakMs',      inhPeakScaled, ...
        'rfInhWeight',      n.inhWeight, ...
        'nSTALags',         nLags, ...
        'noiseFrameDurMs',  noiseFrameDurMs);
    [~, spatialKernel, temporalKernel] = buildGroundTruthRF(rfp);
    temporalKernel = n.polarity * temporalKernel;

    % DKL weights: use neuron's chromatic preference, masked by session axes.
    wDKL = n.dklWeights;
    if isChrom
        wDKL(contrastVec == 0) = 0;
        wn = norm(wDKL);
        if wn > 0, wDKL = wDKL / wn; end
    else
        wDKL = [];
    end

    % Analytic gStd (mirrors simInitKernelBank).
    spatialEnergy = sum(spatialKernel(:).^2);
    tempEnergy    = sum(temporalKernel(:).^2);
    if isChrom
        stimVar = sum((wDKL .* contrastVec).^2);
        if stimVar <= 0, stimVar = 0.25; end
    elseif strcmp(stimType, 'sparse')
        nPos = nY * nX;
        nSpots = 6;
        if isfield(p.trVarsInit, 'nSparseSpots')
            nSpots = p.trVarsInit.nSparseSpots;
        end
        stimVar = nSpots / max(1, nPos);
    else
        stimVar = 0.25;
    end
    gStd = sqrt(spatialEnergy * tempEnergy * stimVar);
    if ~(gStd > 0), gStd = 1; end

    bank.kernels{ch} = struct( ...
        'spatialKernel',     spatialKernel, ...
        'temporalKernel',    temporalKernel, ...
        'wDKL',              wDKL, ...
        'baseRate',          n.baseRate, ...
        'peakRate',          n.peakRate, ...
        'gStd',              gStd, ...
        'polarity',          n.polarity, ...
        'rfCenterFixFrame',  cFix, ...
        'rfCenterGridFrame', cGrid, ...
        'templateIdx',       k);
end

end


function bank = buildCheckerboardKernels(p, pop, bank, nLags)

displayFrameMs = p.rig.frameDuration * 1000;
nSize = numel(p.trVarsInit.checkSizesDva);
nCt   = numel(p.trVarsInit.checkContrasts);
checkSizes = p.trVarsInit.checkSizesDva;

for k = 1:numel(pop.neurons)
    n = pop.neurons(k);
    ch = n.channelIdx;
    if ch > bank.nChannels, continue; end

    rfp = struct( ...
        'nSTALags',        nLags, ...
        'noiseFrameDurMs', displayFrameMs, ...
        'rfExcPeakMs',     n.excPeakMs, ...
        'rfInhPeakMs',     n.inhPeakMs);
    [~, ~, temporalKernel] = buildGroundTruthRF(rfp);
    temporalKernel = n.polarity * temporalKernel;

    % Gain table from the RF's modulation transfer function (MTF).
    % A checkerboard of check size c has fundamental SF = 1/(2c) cpd.
    % The DOG RF's MTF: |exp(-2pi^2 f^2 sigma_c^2) - w * exp(-2pi^2 f^2 sigma_s^2)|
    % This gives realistic check-size tuning: gain peaks when the check
    % SF matches the RF's preferred SF and rolls off for both larger
    % (low SF, surround cancellation) and smaller (high SF, center
    % averaging) checks.
    sigC = n.sigmaCenterDeg;
    sigS = n.sigmaSurrDeg;
    wS   = n.surrWeight;
    gainTable = zeros(nSize, nCt);
    for sz = 1:nSize
        fStim = 1 / (2 * checkSizes(sz));
        mtf = abs(exp(-2 * pi^2 * fStim^2 * sigC^2) - ...
                   wS * exp(-2 * pi^2 * fStim^2 * sigS^2));
        for ct = 1:nCt
            gainTable(sz, ct) = p.trVarsInit.checkContrasts(ct) * mtf;
        end
    end

    tempEnergy = sum(temporalKernel(:).^2);
    gStd = max(gainTable(:)) * sqrt(tempEnergy);
    if ~(gStd > 0), gStd = 1; end

    bank.kernels{ch} = struct( ...
        'temporalKernel', temporalKernel, ...
        'gainTable',      gainTable, ...
        'baseRate',       n.baseRate, ...
        'peakRate',       n.peakRate, ...
        'gStd',           gStd, ...
        'polarity',       n.polarity, ...
        'templateIdx',    k, ...
        'sigmaCenterDeg', sigC);
end

end
