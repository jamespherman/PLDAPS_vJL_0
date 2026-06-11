function spikeTimesPerChan = simBarsweepTrial(pop, bank, pathAngleDeg, params, trialSeed)
% simBarsweepTrial  Simulate one bar-sweep trial for all channels.
%
%   spikeTimesPerChan = simBarsweepTrial(pop, bank, pathAngleDeg, params, trialSeed)
%
%   For each neuron, the bar's position along the sweep axis is projected
%   through the neuron's 1D DOG spatial profile (marginal along the sweep
%   direction), temporally filtered, and passed through the LNP pipeline
%   to generate spikes.
%
%   Inputs:
%     pop          - population struct from simGeneratePopulation
%     bank         - struct with fields: nChannels, neurons (cell array
%                    with centerDeg, sigmaCenterDeg, sigmaSurrDeg,
%                    surrWeight, excPeakMs, inhPeakMs, inhWeight,
%                    polarity, baseRate, peakRate, channelIdx)
%     pathAngleDeg - sweep direction in degrees (0=right, 90=up, etc.)
%     params       - struct with: speedDegPerSec, pathLengthDeg,
%                    barWidthDeg, frameDurS, pathCenterDeg [x,y]
%     trialSeed    - RNG seed for reproducibility
%
%   Output:
%     spikeTimesPerChan - cell{nCh,1} of spike times relative to sweep onset

nCh = bank.nChannels;
spikeTimesPerChan = cell(nCh, 1);

sweepDurS = params.pathLengthDeg / params.speedDegPerSec;
nFrames = round(sweepDurS / params.frameDurS);
if nFrames < 2, return; end

thetaRad = pathAngleDeg * pi / 180;
dirVec = [cos(thetaRad), sin(thetaRad)];

startPos = params.pathCenterDeg - (params.pathLengthDeg / 2) * dirVec;
barPosDeg = zeros(nFrames, 2);
for f = 1:nFrames
    frac = (f - 1) / (nFrames - 1);
    barPosDeg(f, :) = startPos + frac * params.pathLengthDeg * dirVec;
end

% Project bar positions onto sweep axis (scalar position along direction).
barPosAlongAxis = barPosDeg * dirVec';

for k = 1:numel(pop.neurons)
    n = pop.neurons(k);
    ch = n.channelIdx;
    if ch > nCh, continue; end

    seed = mod(trialSeed + ch, 2^32 - 1);
    rs = RandStream('mt19937ar', 'Seed', uint32(seed));

    rfPosAlongAxis = n.centerDeg * dirVec';

    sigC = n.sigmaCenterDeg;
    sigS = n.sigmaSurrDeg;
    wS   = n.surrWeight;

    % Finite bar width: convolving a rect(barWidth) with a Gaussian(sigma)
    % broadens the effective sigma. Approximate rect variance = w^2/12.
    barSig = params.barWidthDeg / sqrt(12);
    sigCeff = sqrt(sigC^2 + barSig^2);
    sigSeff = sqrt(sigS^2 + barSig^2);

    dist = barPosAlongAxis - rfPosAlongAxis;
    spatialDrive = exp(-dist.^2 / (2 * sigCeff^2)) - wS * exp(-dist.^2 / (2 * sigSeff^2));
    spatialDrive = n.polarity * spatialDrive;

    % Temporal filter (biphasic).
    noiseFrameDurMs = params.frameDurS * 1000;
    excPeak = max(n.excPeakMs, noiseFrameDurMs * 0.8);
    inhPeak = excPeak * (n.inhPeakMs / max(n.excPeakMs, 1));
    nLags = min(30, nFrames);
    lagMs = (0:nLags-1) * noiseFrameDurMs;
    tk = exp(-lagMs / excPeak) .* (lagMs / excPeak) - ...
         n.inhWeight * exp(-lagMs / inhPeak) .* (lagMs / inhPeak);
    tk = tk(:) / max(abs(tk));

    g = filter(tk, 1, spatialDrive(:));

    spatialEnergy = sum(spatialDrive(:).^2) / nFrames;
    tempEnergy = sum(tk(:).^2);
    gStd = sqrt(spatialEnergy * tempEnergy);
    if gStd > 0, g = g / gStd; end

    spkRel = simLNPSpikes(g, n.baseRate, n.peakRate, params.frameDurS, rs);
    if ~isempty(spkRel)
        spikeTimesPerChan{ch} = spkRel;
    end
end

% Noise channels.
for i = 1:numel(pop.noiseChannels)
    ch = pop.noiseChannels(i);
    if ch > nCh, continue; end
    seed = mod(trialSeed + ch + 50000, 2^32 - 1);
    rs = RandStream('mt19937ar', 'Seed', uint32(seed));
    g = zeros(nFrames, 1);
    spkRel = simLNPSpikes(g, pop.noiseRates(i), 0, params.frameDurS, rs);
    if ~isempty(spkRel)
        spikeTimesPerChan{ch} = spkRel;
    end
end

end
