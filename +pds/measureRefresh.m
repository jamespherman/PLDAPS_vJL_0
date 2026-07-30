function [refreshRate, frameDuration] = measureRefresh(window)
% [refreshRate, frameDuration] = measureRefresh(window)
%
% Return the display refresh rate (Hz) and frame duration (s) for an open
% Psychtoolbox window. Measured from the calibrated flip interval
% (Screen('GetFlipInterval')) when available -- that is the value PTB
% measured at OpenWindow and is more precise than FrameRate, which rounds
% to an integer. Falls back to FrameRate if the flip-interval estimate is
% not yet available.
%
% Also LOGS the measured rate and WARNS (does not error) if it is not
% within tolerance of a supported rig rate. Timing-critical tasks assume
% this value for their per-frame flip scheduling and noise-update
% derivation, so a mis-detect (usually a failed PTB sync test or a wrong
% display mode) should be visible. We warn rather than error so an
% unusual-but-real rate still runs -- and so a 100 Hz rig is not treated as
% broken just because another rig runs at 120 Hz.

flipInterval = Screen('GetFlipInterval', window);
if isfinite(flipInterval) && flipInterval > 0
    frameDuration = flipInterval;
    refreshRate   = 1 / flipInterval;
else
    refreshRate   = FrameRate(window);
    frameDuration = 1 / refreshRate;
end

% Supported rig refresh rates. A measured rate far from all of these is
% almost always a configuration/sync problem, not a real display.
supportedRatesHz = [100 120];

fprintf(['pds.measureRefresh: display refresh = %.3f Hz ' ...
    '(frame duration = %.4f ms).\n'], ...
    refreshRate, 1000 * frameDuration);

if min(abs(refreshRate - supportedRatesHz)) > 2
    warning('pds:measureRefresh:unexpectedRefresh', ...
        ['Measured refresh %.2f Hz is not within 2 Hz of a supported rig ' ...
         'rate (%s Hz). Timing-critical tasks assume the measured rate; ' ...
         'verify the display mode and PsychToolbox sync test before ' ...
         'recording.'], refreshRate, num2str(supportedRatesHz));
end

end
