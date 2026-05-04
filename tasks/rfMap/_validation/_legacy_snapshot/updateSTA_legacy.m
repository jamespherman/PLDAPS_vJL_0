function [staAccum, staSpikeCount] = updateSTA_legacy(staAccum, staSpikeCount, ...
    spikeTimesPerChan, noiseOnTime, frameDurS, noiseMovie, ...
    trialStartFrame, nFramesTrial, nLags, isSparse)
% updateSTA_legacy  Frozen pre-merge estimator for regression.
%
% Snapshot of supportFunctions/updateSTA.m at the rfMap-pre-unified-merge
% tag. Used by _validation/compare_old_vs_new_generators.m as the
% "old" reference in the bit-exact regression contract. Do not edit
% beyond the rename.
%
%   [staAccum, staSpikeCount] = updateSTA(staAccum, staSpikeCount, ...
%       spikeTimesPerChan, noiseOnTime, frameDurS, noiseMovie, ...
%       trialStartFrame, nFramesTrial, nLags)
%
%   For each spike, identifies which noise frame was on screen, then
%   accumulates the mean-subtracted stimulus at each temporal lag into
%   the running STA accumulators.
%
%   Inputs:
%     staAccum          - cell array {nChannels}, each [nY, nX, nLags] double
%     staSpikeCount     - [nChannels, 1] cumulative spike counts
%     spikeTimesPerChan - cell array {nChannels}, each a vector of spike
%                         times in seconds (same clock as noiseOnTime)
%     noiseOnTime       - noise onset time for this trial (seconds)
%     frameDurS         - duration of one noise frame (seconds)
%     noiseMovie        - full noise movie [nY, nX, nTotalFrames] uint8
%     trialStartFrame   - first global frame index for this trial
%     nFramesTrial      - number of noise frames in this trial
%     nLags             - number of STA temporal lags to compute
%
%   Outputs:
%     staAccum          - updated accumulators (modified in place via copy)
%     staSpikeCount     - updated spike counts
%
%   Lag convention:
%     lagIdx 1 -> stimulus at spike time (0 ms delay)
%     lagIdx 2 -> stimulus 1 frame before spike (frameDurS delay)
%     lagIdx k -> stimulus (k-1) frames before spike
%
%   Dense mode: stimulus is mean-subtracted before accumulation (binary
%   0/1 -> -0.5/+0.5). Essential for unbiased STA with white noise
%   (Chichilnisky, 2001).
%
%   Sparse mode: stimulus is already zero-mean ({-1, 0, +1} with spots
%   placed randomly and symmetrically), so values are used directly.
%
%   The isSparse flag (optional; defaults to auto-detect via data type)
%   selects between these two treatments. Pass isSparse = true for sparse
%   noise, false for dense.

if nargin < 10 || isempty(isSparse)
    isSparse = isa(noiseMovie, 'int8');
end

nChannels = length(spikeTimesPerChan);
nTotalFrames = size(noiseMovie, 3);

for ch = 1:nChannels
    theseSpikes = spikeTimesPerChan{ch};
    if isempty(theseSpikes)
        continue;
    end

    for s = 1:length(theseSpikes)
        % Time of this spike relative to noise onset
        tRel = theseSpikes(s) - noiseOnTime;

        % Which noise frame was on screen at this spike time?
        noiseFrameIdx = floor(tRel / frameDurS) + 1;

        % Skip if spike is outside the stimulus period
        if noiseFrameIdx < 1 || noiseFrameIdx > nFramesTrial
            continue;
        end

        % Global frame index in the movie matrix
        globalIdx = trialStartFrame + noiseFrameIdx - 1;

        % Count this spike once (not per-lag)
        staSpikeCount(ch) = staSpikeCount(ch) + 1;

        % Accumulate STA at each lag
        for lagIdx = 1:nLags
            stimIdx = globalIdx - lagIdx + 1;
            if stimIdx >= 1 && stimIdx <= nTotalFrames
                if isSparse
                    % Sparse movie is int8 {-1, 0, +1}; already zero-mean.
                    stimFrame = double(noiseMovie(:, :, stimIdx));
                else
                    % Dense: convert uint8 0/1 to double -0.5/+0.5.
                    stimFrame = double(noiseMovie(:, :, stimIdx)) - 0.5;
                end
                staAccum{ch}(:, :, lagIdx) = ...
                    staAccum{ch}(:, :, lagIdx) + stimFrame;
            end
        end
    end
end

end
