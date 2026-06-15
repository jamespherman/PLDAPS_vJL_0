function [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
    staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, frameDurS, ...
    noiseMovie, trialStartFrame, nFramesTrial, nLags)
% updateSTA_denseAchromatic  Accumulate STA for dense achromatic noise.
%
%   [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
%       staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
%       frameDurS, noiseMovie, trialStartFrame, nFramesTrial, nLags)
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

nChannels    = length(spikeTimesPerChan);
nTotalFrames = size(noiseMovie, 3);

for ch = 1:nChannels
    theseSpikes = spikeTimesPerChan{ch};
    if isempty(theseSpikes)
        continue
    end

    for s = 1:length(theseSpikes)
        tRel          = theseSpikes(s) - stimOnTime;
        noiseFrameIdx = floor(tRel / frameDurS) + 1;
        if noiseFrameIdx < 1 || noiseFrameIdx > nFramesTrial
            continue
        end

        globalIdx = trialStartFrame + noiseFrameIdx - 1;

        for lagIdx = 1:nLags
            stimIdx = globalIdx - lagIdx + 1;
            if stimIdx >= 1 && stimIdx <= nTotalFrames
                staSpikeCount(ch, lagIdx) = staSpikeCount(ch, lagIdx) + 1;
                stimFrame = double(noiseMovie(:, :, stimIdx)) - 0.5;
                staAccum{ch}(:, :, lagIdx) = ...
                    staAccum{ch}(:, :, lagIdx) + stimFrame;
            end
        end
    end
end

end
