function texturePairs = prepareStim_checkerboard(...
    checkSizesDva, checkContrasts, screenWidthPx, screenHeightPx, ...
    pixPerDeg, rngSeed) %#ok<INUSD>
% prepareStim_checkerboard  PHASE 3 STUB.
%
%   Phase 1 of the rfMap unified merge ships the dispatcher
%   architecture; the checkerboard preparer is implemented in Phase 3
%   per analysisPlanningDocs/rfMap_unified_merge_plan.md. Loading
%   rfMap_checkerboard_settings and pressing Initialize will reach
%   this function and error out with a clear message.
%
%   Phase 3 will pre-render a polarity texture pair per (checkSize,
%   contrast) condition (named prepare* rather than generate* because
%   this is texture pre-rendering, not a frame-indexed movie tensor).
%   Reversal scheduling is handled in rfMap_run.m.
%
%   Validators that Phase 3 must enforce at settings time:
%     1. checkReversalHz must divide refreshRate evenly.
%     2. F2 = 2 * checkReversalHz must be below Nyquist (refreshRate / 2).
%     3. Peak texture-memory usage must be below ~512 MB.

error('prepareStim_checkerboard:notImplemented', ...
    ['Contrast-reversing checkerboard is a Phase-3 deliverable and ' ...
     'is not implemented yet. See analysisPlanningDocs/' ...
     'rfMap_unified_merge_plan.md  ->  Phase 3.']);

texturePairs = struct([]);

end
