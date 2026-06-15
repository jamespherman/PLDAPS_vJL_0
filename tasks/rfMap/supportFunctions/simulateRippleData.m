function p = simulateRippleData(p)
% simulateRippleData  Drop-in replacement for pds.getRippleData under sim mode.
%
%   p = simulateRippleData(p)
%
%   Fabricates p.trData.spikeTimes / .spikeClusters / .eventTimes /
%   .eventValues from the per-channel LNP kernel bank on
%   p.init.simKernelBank. Signature mirrors pds.getRippleData so the
%   injection in rfMap_finish is a one-line branch.
%
%   Per-channel pipeline (mirrors testSTA.m):
%     1. Build per-frame drive g(t) for this trial:
%          denseAchromatic/sparse : proj = sum K_s(:,:) * S_meanzero(:,:,t)
%          denseChromatic         : proj = sum K_s(:,:) * sum_c wDKL_c * D(:,:,c,t)
%          checkerboard           : proj = gain(sz,ct) * polarity(t)
%     2. g = filter(temporalKernel, 1, proj) / gStd       (causal temporal filter)
%     3. rate = baseRate + peakRate * sigmoid(g)          (sigmoid nonlinearity)
%     4. spikes ~ Bernoulli(rate * dtFine) at dtFine = 1 ms (Poisson approx)
%
%   The "Ripple clock" anchor is p.trData.timing.stimOn (PTB time). Spike
%   times are written as stimOnTime + spkRel. accumulateSTA in
%   rfMap_finish locates trial onset via
%       find(p.trData.eventValues == p.init.codes.stimOn, 1, 'last')
%   so we MUST write at least one stimOn event into the fabricated event
%   stream.
%
%   Aborted trials (stimOn < 0) leave the fields empty -- the existing
%   guard in rfMap_finish skips STA accumulation in that case, matching
%   real Ripple behavior on a trial with no stimulus presentation.

% Reset spike / event buffers exactly as pds.getRippleData would.
p.trData.spikeTimes    = [];
p.trData.spikeClusters = [];
p.trData.eventTimes    = [];
p.trData.eventValues   = [];

if ~isfield(p.init, 'simKernelBank') || isempty(p.init.simKernelBank)
    error('simulateRippleData:noBank', ...
        ['p.init.simKernelBank is missing. simInitKernelBank must be ' ...
         'called from rfMap_init when useSimulatedSpikes is true.']);
end

stimOnTimeSim = p.trData.timing.stimOn;
if ~(stimOnTimeSim > 0)
    % Aborted trial: stimulus never came on. accumulateSTA's
    % ~isempty(spikeTimes) guard in finish.m skips us; nothing else to do.
    return;
end

% Always write a stimOn event into the event stream so accumulateSTA can
% locate trial onset. Column-vector shape matches pds.getRippleData.
p.trData.eventValues = double(p.init.codes.stimOn);
p.trData.eventTimes  = double(stimOnTimeSim);

bank      = p.init.simKernelBank;
stimType  = p.init.stimType;
nFrames   = p.trVars.nFramesThisTrial;
iTrial    = p.status.iTrial;

if nFrames <= 0
    return;
end

if strcmp(stimType, 'checkerboard')
    frameDurS = p.rig.frameDuration;
else
    frameDurS = p.trVars.noiseFrameDurS;
end

% --- Build a stimulus-tensor reference for this trial. ---
switch stimType
    case 'denseAchromatic'
        % p.init.noiseMovie is [nY, nX, nNoiseFrames] uint8 (0/1).
        f0 = p.trVars.trialStartFrame;
        f1 = p.trVars.trialEndFrame;
        S  = double(p.init.noiseMovie(:, :, f0:f1)) - 0.5;
    case 'sparse'
        % p.init.noiseMovie is int8 with values in {-1, 0, +1}; already
        % zero-mean by balanced TwinDeck construction.
        f0 = p.trVars.trialStartFrame;
        f1 = p.trVars.trialEndFrame;
        S  = double(p.init.noiseMovie(:, :, f0:f1));
    case 'denseChromatic'
        % nextParams stores the per-trial drive tensor on trVars.
        if ~isfield(p.trVars, 'thisTrialDklDrive') || ...
                isempty(p.trVars.thisTrialDklDrive)
            error('simulateRippleData:noDrive', ...
                ['denseChromatic sim mode requires ' ...
                 'p.trVars.thisTrialDklDrive (regenerated in nextParams). ' ...
                 'Drive tensor not present this trial.']);
        end
        D = p.trVars.thisTrialDklDrive;            % [nY, nX, 3, nFrames]
    case 'checkerboard'
        polarity = double(p.trVars.checkPolaritySequence(:)');
        szIdx    = p.trVars.checkSizeIdx;
        ctIdx    = p.trVars.contrastIdx;
end

baseSeed = bank.baseSeed;

% --- Per-channel LNP loop. ---
nTotalCh     = bank.nChannels;
allSpkAbs    = cell(nTotalCh, 1);
allSpkClust  = cell(nTotalCh, 1);

for ch = 1:nTotalCh
    k = bank.kernels{ch};
    if isempty(k), continue; end

    % Per-(channel, trial) reproducible RNG.
    seed = mod(baseSeed + ch + 10000 * iTrial, 2^32 - 1);
    rs   = RandStream('mt19937ar', 'Seed', uint32(seed));

    if isfield(k, 'isNoise') && k.isNoise
        % Noise channel: Poisson at baseRate, no stimulus drive.
        g = zeros(nFrames, 1);
        spkRel = simLNPSpikes(g, k.baseRate, 0, frameDurS, rs);
    else
        % RF-bearing channel: full LNP pipeline.
        switch stimType
            case {'denseAchromatic', 'sparse'}
                sk = k.spatialKernel;                  % [nY, nX]
                sFlat = double(reshape(S, [], nFrames));
                proj  = sk(:)' * sFlat;

            case 'denseChromatic'
                sk   = k.spatialKernel;                % [nY, nX]
                wDKL = k.wDKL;                         % [1, 3]
                Dcollapsed = squeeze( ...
                    wDKL(1) * D(:, :, 1, :) + ...
                    wDKL(2) * D(:, :, 2, :) + ...
                    wDKL(3) * D(:, :, 3, :));          % [nY, nX, nFrames]
                sFlat = double(reshape(Dcollapsed, [], nFrames));
                proj  = sk(:)' * sFlat;

            case 'checkerboard'
                g0 = k.gainTable(szIdx, ctIdx);
                proj = g0 * polarity;
        end

        tk = k.temporalKernel;
        g  = filter(tk, 1, proj(:));
        g  = g / k.gStd;

        spkRel = simLNPSpikes(g, k.baseRate, k.peakRate, frameDurS, rs);
    end

    if isempty(spkRel), continue; end

    spkAbs = stimOnTimeSim + spkRel;
    allSpkAbs{ch}   = spkAbs(:);
    allSpkClust{ch} = repmat(double(ch), numel(spkAbs), 1);
end

% Concatenate -- matches the non-online-sort branch of pds.getRippleData
% (spikeClusters holds channel index, spikeTimes holds Ripple-clock secs).
spikeTimes    = vertcat(allSpkAbs{:});
spikeClusters = vertcat(allSpkClust{:});

p.trData.spikeTimes    = spikeTimes;
p.trData.spikeClusters = spikeClusters;

end
