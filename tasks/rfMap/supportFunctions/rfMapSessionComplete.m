function tf = rfMapSessionComplete(p)
% tf = rfMapSessionComplete(p)
%
% True when the rfMap session has reached its target and the run loop
% should stop (auto-stop). Derived ENTIRELY from persistent state
% (p.status / p.init) so it can be evaluated at the top of _next BEFORE the
% per-trial `p.trVars = p.trVarsGuiComm` copy, and again in _finish. Do NOT
% store the result on p.trVars and read it back next trial -- that copy
% would wipe it (this is the trap the plan review flagged).
%
%   checkerboard : done when the (checkSize, contrast) trial array is fully
%                  consumed (p.status.trialsArrayRowsPossible is empty).
%   STA modes    : done after targetNoiseCycles complete passes of the
%                  noise movie. One pass ~ movieDurationMin of stimulus.
%                  noiseCycleCount counts wraps already taken by
%                  nextParams; (noiseFrameIdx > nNoiseFrames) flags the
%                  final pass that has finished (playback cursor advanced
%                  past the last frame in _finish) but not yet been wrapped
%                  by the next nextParams call. Summing the two stops the
%                  session at the end of pass targetNoiseCycles rather than
%                  one trial into the next pass.

tf = false;

% Never terminate before the first real trial has run.
if p.status.iTrial < 1
    return;
end

if strcmp(p.init.stimType, 'checkerboard')
    tf = isfield(p.status, 'trialsArrayRowsPossible') && ...
        isempty(p.status.trialsArrayRowsPossible);
    return;
end

% STA noise-movie modes (denseAchromatic, denseChromatic, sparse).
if ~isfield(p.init, 'nNoiseFrames') || isempty(p.init.nNoiseFrames) || ...
        p.init.nNoiseFrames < 1
    return;
end

% Read the target from the always-present GUI-comm mirror (p.trVars may be
% the previous trial's copy at _next-top; p.trVarsGuiComm always holds the
% live value).
target = 1;
if isfield(p, 'trVarsGuiComm') && ...
        isfield(p.trVarsGuiComm, 'targetNoiseCycles') && ...
        ~isempty(p.trVarsGuiComm.targetNoiseCycles)
    target = p.trVarsGuiComm.targetNoiseCycles;
end

cyclesDone = p.init.noiseCycleCount + ...
    double(p.init.noiseFrameIdx > p.init.nNoiseFrames);
tf = cyclesDone >= target;

end
