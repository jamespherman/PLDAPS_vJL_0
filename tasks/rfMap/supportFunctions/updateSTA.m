function [staAccum, staSpikeCount] = updateSTA(stimType, ...
    staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, frameDurS, ...
    stimTensor, trialStartFrame, nFramesTrial, nLags, jitterX, jitterY)
% updateSTA  Stim-type dispatcher for online STA accumulation.
%
%   [staAccum, staSpikeCount] = updateSTA(stimType, ...
%       staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, ...
%       frameDurS, stimTensor, trialStartFrame, nFramesTrial, nLags, ...
%       jitterX, jitterY)
%
%   Routes to the per-stim-type estimator. stimType is the string from
%   p.init.stimType; the dispatcher does not consult any settings file.
%
%   stimTensor is the per-type stimulus representation:
%     denseAchromatic / sparse : [nY, nX, nFrames] noise movie (uint8 or int8)
%     denseChromatic           : [nY, nX, 3, nFrames] single drive tensor
%     checkerboard             : Phase-3 stub (polarity sequence + condition)
%
%   The caller (rfMap_finish.accumulateSTA) is responsible for selecting
%   the right tensor for the active stim type and passing it here.
%
%   Phase 1 active paths: 'denseAchromatic', 'sparse'.
%   Phase 2 active path:  'denseChromatic'.
%   Phase 3 stub:         'checkerboard'.
%
%   Jitter offsets default to (0, 0); pass nonzero values only after
%   Phase 4 activates the offset-aware accumulator path.

if nargin < 11 || isempty(jitterX), jitterX = 0; end
if nargin < 12 || isempty(jitterY), jitterY = 0; end

switch stimType
    case 'denseAchromatic'
        [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
            staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, ...
            frameDurS, stimTensor, trialStartFrame, nFramesTrial, ...
            nLags, jitterX, jitterY);

    case 'sparse'
        [staAccum, staSpikeCount] = updateSTA_sparse( ...
            staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, ...
            frameDurS, stimTensor, trialStartFrame, nFramesTrial, ...
            nLags, jitterX, jitterY);

    case 'denseChromatic'
        [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
            staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, ...
            frameDurS, stimTensor, trialStartFrame, nFramesTrial, ...
            nLags, jitterX, jitterY);

    case 'checkerboard'
        % Phase-3 stub. Phase 3 will replace stimTensor /
        % trialStartFrame with polaritySequence / conditionPerFrame at
        % the call site.
        [staAccum, staSpikeCount] = updateSTA_checkerboard( ...
            staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, ...
            frameDurS, stimTensor, trialStartFrame, nLags, ...
            jitterX, jitterY);

    otherwise
        error('updateSTA:badStimType', ...
            ['Unrecognized stimType ''%s''. Expected one of: ' ...
             'denseAchromatic, denseChromatic, sparse, checkerboard.'], ...
            stimType);
end

end
