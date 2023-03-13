function p = getEyelink(p)

% Reads the newest available sample of Eyelink gaze position data and
% returns:
% p.trVars.eyePixX      - eye x position in pixels
% p.trVars.eyePixY      - eye y position in pixels

% Check if a new sample is available online via the link. This is
% equivalent to eyeLink_newest_float_sample() in C API. See EyeLink
% Programmers Guide manual > Function Lists > Message and Command
% Sending/Receiving > Functions
if Eyelink('NewFloatSampleAvailable') > 0

    % Get sample data in a Matlab structure. This is equivalent to
    % eyeLink_newest_float_sample() in C API. See EyeLink Programmers
    % Guide manual > Function Lists > Message and Command Sending/Receiving
    % > Functions
    evt = Eyelink('NewestFloatSample');

    % Save sample properties as variables. See EyeLink Programmers Guide
    % manual > Data Structures > FSAMPLE
    p.trVars.eyePixX = evt.gx(p.init.el.eyeUsed + 1);
    p.trVars.eyePixY = evt.gy(p.init.el.eyeUsed + 1);
end