function [staAccum, staSpikeCount] = updateSTA_checkerboard( ...
    staAccum, staSpikeCount, spikeTimesPerChan, noiseOnTime, frameDurS, ...
    polaritySequence, conditionPerFrame, nLags, ...
    jitterX, jitterY) %#ok<INUSD>
% updateSTA_checkerboard  PHASE 3 STUB.
%
%   Per-(checkSize, contrast) condition reverse-correlation against the
%   +/-1 polarity sequence. Two outputs in Phase 3:
%     1. Temporal kernel: [nLags, nCheckSize, nContrast, nCh]
%     2. F1/F2 amplitude: [2, nCheckSize, nContrast, nCh]
%   Helper computeF1F2.m provides the per-trial complex sums.
%
%   Phase 1 plumbing keeps the same jitterX/jitterY arguments as the
%   other estimators so the dispatcher can hand them in uniformly.

error('updateSTA_checkerboard:notImplemented', ...
    ['Checkerboard temporal STA + F1/F2 is a Phase-3 deliverable. ' ...
     'See analysisPlanningDocs/rfMap_unified_merge_plan.md  ->  Phase 3.']);

end
