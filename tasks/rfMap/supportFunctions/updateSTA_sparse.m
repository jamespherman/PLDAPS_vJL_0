function [staAccum, staSpikeCount] = updateSTA_sparse( ...
    staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, frameDurS, ...
    noiseMovie, trialStartFrame, nFramesTrial, nLags)
% updateSTA_sparse  Accumulate STA for sparse balanced noise.
%
%   [staAccum, staSpikeCount] = updateSTA_sparse( ...
%       staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
%       frameDurS, noiseMovie, trialStartFrame, nFramesTrial, nLags)
%
%   Stimulus convention:
%     Sparse movie is int8 with values in {-1, 0, +1}. The balanced
%     TwinDeck construction guarantees per-frame mean = 0 exactly
%     (N/2 white + N/2 black per frame), so the values are used
%     directly without mean-subtraction.
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

        globalIdx         = trialStartFrame + noiseFrameIdx - 1;
        staSpikeCount(ch) = staSpikeCount(ch) + 1;

        for lagIdx = 1:nLags
            stimIdx = globalIdx - lagIdx + 1;
            if stimIdx >= 1 && stimIdx <= nTotalFrames
                stimFrame = double(noiseMovie(:, :, stimIdx));
                staAccum{ch}(:, :, lagIdx) = ...
                    staAccum{ch}(:, :, lagIdx) + stimFrame;
            end
        end
    end
end

end
