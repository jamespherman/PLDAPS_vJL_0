function [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
    staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, frameDurS, ...
    dklDriveTensor, trialStartFrame, nFramesTrial, nLags)
% updateSTA_denseChromatic  Accumulate STA for dense chromatic (DKL) noise.
%
%   [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
%       staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
%       frameDurS, dklDriveTensor, trialStartFrame, nFramesTrial, ...
%       nLags)
%
%   For each spike, identifies which dense noise frame was on screen,
%   then accumulates the per-check DKL drive vector at each temporal lag
%   into the running STA accumulator. Output per channel has shape
%   [nY, nX, 3, nLags] where the 3rd dim is DKL axes (1=L-M, 2=S, 3=Achro).
%
%   Stimulus convention:
%     dklDriveTensor is a [nY, nX, 3, nTotalFrames] single-precision
%     tensor of signed contrasts. The drive is already zero-mean by
%     construction (balanced binary signs on each axis), so values are
%     used directly without further mean subtraction.
%
%   Lag convention (matches updateSTA_denseAchromatic):
%     lagIdx 1 -> stimulus at spike time (0 ms delay)
%     lagIdx k -> stimulus (k-1) frames before spike

nChannels    = length(spikeTimesPerChan);
nTotalFrames = size(dklDriveTensor, 4);

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
                stimFrame = double(dklDriveTensor(:, :, :, stimIdx));
                staAccum{ch}(:, :, :, lagIdx) = ...
                    staAccum{ch}(:, :, :, lagIdx) + stimFrame;
            end
        end
    end
end

end
