function [noiseMovie, dklDriveTensor] = generateStim_denseChromatic(...
    nChecksY, nChecksX, nFrames, dklAxes, dklContrasts, rngSeed) %#ok<INUSD>
% generateStim_denseChromatic  PHASE 2 STUB.
%
%   Phase 1 of the rfMap unified merge ships the dispatcher
%   architecture; the chromatic generator is implemented in Phase 2
%   per analysisPlanningDocs/rfMap_unified_merge_plan.md. Loading
%   rfMap_denseChromatic_settings and pressing Initialize will reach
%   this function and error out with a clear message.
%
%   Phase 2 will implement:
%     - DKL coordinate generation per check (3-vector per cell per frame)
%     - dkl2rgb conversion using the calibrated 3x3 matrix from
%       Phase 1.5 (calibration audit)
%     - return both the displayable RGB movie and the per-check DKL
%       drive tensor (used by the STA accumulator; recomputable from
%       the seed, not saved to the session file)

error('generateStim_denseChromatic:notImplemented', ...
    ['Dense chromatic (DKL) noise is a Phase-2 deliverable and is ' ...
     'not implemented yet. See analysisPlanningDocs/' ...
     'rfMap_unified_merge_plan.md  ->  Phase 2.']);

% Suppressed declarations (so the function signature is in place for
% Phase-2 plumbing without unused-variable warnings).
noiseMovie     = [];
dklDriveTensor = [];

end
