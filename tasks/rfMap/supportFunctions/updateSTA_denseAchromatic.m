function [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
    staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, frameDurS, ...
    noiseMovie, trialStartFrame, nFramesTrial, nLags, jitterX, jitterY)
% updateSTA_denseAchromatic  Accumulate STA for dense achromatic noise.
%
%   [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
%       staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, ...
%       frameDurS, noiseMovie, trialStartFrame, nFramesTrial, nLags, ...
%       jitterX, jitterY)
%
%   For each spike, identifies which dense noise frame was on screen,
%   then accumulates the mean-subtracted stimulus at each temporal lag
%   into the running STA accumulators.
%
%   Stimulus convention:
%     Dense achromatic movie is uint8 with values 0/1. We convert to
%     -0.5/+0.5 (mean-subtracted) before accumulation, per Chichilnisky
%     (2001), so the STA is unbiased for binary white noise.
%
%   Lag convention:
%     lagIdx 1  ->  stimulus at spike time (0 ms delay)
%     lagIdx k  ->  stimulus (k-1) frames before spike (frameDurS * (k-1) delay)
%
%   Phase 4 (jitter): jitterX, jitterY are per-trial pixel-grid offsets
%   into a margin-padded noise tensor. Phase 1 always passes (0,0); the
%   arguments are present in the signature so Phase 4 does not need to
%   re-touch this file. Defaults are 0 if unspecified.

if nargin < 10 || isempty(jitterX), jitterX = 0; end
if nargin < 11 || isempty(jitterY), jitterY = 0; end

if jitterX ~= 0 || jitterY ~= 0
    error('updateSTA_denseAchromatic:jitterUnsupported', ...
        ['Phase-1 estimator does not support nonzero jitter. ' ...
         'Phase 4 will activate the jitter offset path.']);
end

nChannels    = length(spikeTimesPerChan);
nTotalFrames = size(noiseMovie, 3);

for ch = 1:nChannels
    theseSpikes = spikeTimesPerChan{ch};
    if isempty(theseSpikes)
        continue
    end

    for s = 1:length(theseSpikes)
        tRel          = theseSpikes(s) - noiseOnTime;
        noiseFrameIdx = floor(tRel / frameDurS) + 1;
        if noiseFrameIdx < 1 || noiseFrameIdx > nFramesTrial
            continue
        end

        globalIdx           = trialStartFrame + noiseFrameIdx - 1;
        staSpikeCount(ch)   = staSpikeCount(ch) + 1;

        for lagIdx = 1:nLags
            stimIdx = globalIdx - lagIdx + 1;
            if stimIdx >= 1 && stimIdx <= nTotalFrames
                stimFrame = double(noiseMovie(:, :, stimIdx)) - 0.5;
                staAccum{ch}(:, :, lagIdx) = ...
                    staAccum{ch}(:, :, lagIdx) + stimFrame;
            end
        end
    end
end

end
