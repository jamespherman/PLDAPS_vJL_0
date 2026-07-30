function stopRunButton()
% stopRunButton  Robustly stop the PLDAPS GUI run loop.
%
%   pds.stopRunButton()
%
% Drives the GUI "Run" toggle button's Value to false so the main trial
% loop in PLDAPS_vK2_GUI breaks on its next continuation check (the
% `if ~get(runButton,'Value'); break; end` at the bottom of the loop).
%
% Tasks call this from their _finish function once the session's target
% trial count has been reached, so the experimenter does not have to
% un-click Run and the command window does not flood with rapid no-op
% trials.
%
% Guards (these are why this is a shared helper rather than an inline
% `obj.Value = false`):
%   - empty result (button not built yet, or GUI closed): no-op.
%   - multi-element result (e.g. more than one GUI instance open, both
%     tagged 'runButton'): act on the FIRST handle only. A `.Value = false`
%     assignment onto a graphics ARRAY is version-dependent and may target
%     the wrong object or error, which would leave the loop spinning.

rb = findall(groot, 'Tag', 'runButton');
if ~isempty(rb)
    set(rb(1), 'Value', false);
end

end
