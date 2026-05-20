function spkRel = simLNPSpikes(g, baseRate, peakRate, frameDurS, rngStream)
% simLNPSpikes  Generate Poisson spikes from a per-frame drive signal.
%
%   spkRel = simLNPSpikes(g, baseRate, peakRate, frameDurS, rngStream)
%
%   Sigmoid nonlinearity + 1 ms Bernoulli-approximation Poisson sampling.
%   Math mirrors testSTA.m steps 3c-3d so the simulator is directly
%   comparable to the offline LNP reference.
%
%   Inputs:
%     g          - [nFrames x 1] generator signal (already variance-normalized
%                  by the caller so the sigmoid sits in its quasi-linear regime).
%     baseRate   - baseline firing rate, spikes/s.
%     peakRate   - peak driven rate, spikes/s. Total instantaneous rate is
%                  baseRate + peakRate * sigmoid(g).
%     frameDurS  - stimulus frame duration, seconds.
%     rngStream  - RandStream object; spike sampling uses rand(rngStream, ...).
%                  Pass per-(channel, trial) streams for full reproducibility.
%
%   Output:
%     spkRel     - column vector of spike times in seconds, relative to
%                  the start of g (i.e. seconds since stimOn).

g(~isfinite(g)) = 0;
rate = baseRate + peakRate ./ (1 + exp(-g));

dtFine        = 0.001;
nBinsPerFrame = max(1, round(frameDurS / dtFine));
ratePerBin    = repelem(rate(:), nBinsPerFrame);

u         = rand(rngStream, numel(ratePerBin), 1);
spikeMask = u < ratePerBin * dtFine;
spkRel    = (find(spikeMask) - 0.5) * dtFine;

end
