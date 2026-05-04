function [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
    staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, frameDurS, ...
    dklDriveTensor, trialStartFrame, nFramesTrial, nLags, ...
    jitterX, jitterY) %#ok<INUSD>
% updateSTA_denseChromatic  PHASE 2 STUB.
%
%   Accumulates STA against the per-check DKL drive vector (3-vector
%   per cell per frame: L-M, S, achromatic), producing an output of
%   shape [nY, nX, 3, nLags, nCh]. The drive tensor is reconstructed
%   on the fly from (rngSeed, nY, nX, nFrames, dklAxes, dklContrasts)
%   in Phase 2 -- it is NOT saved to disk because typical sizes are
%   ~400 MB per session.
%
%   Phase 1 plumbing keeps the same jitterX/jitterY arguments as the
%   other estimators so the dispatcher can hand them in uniformly.

error('updateSTA_denseChromatic:notImplemented', ...
    ['Dense chromatic STA is a Phase-2 deliverable. See ' ...
     'analysisPlanningDocs/rfMap_unified_merge_plan.md  ->  Phase 2.']);

end
