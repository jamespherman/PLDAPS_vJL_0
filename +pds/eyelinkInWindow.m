function inWindowLogical = eyelinkInWindow(p, whichWinString)
%
% inWindowLogical = eyelinkInWindow(p, ['target' / 'fixation'])
%
% Checks whether the current eyelink-supplied (or other eye tracker that
% provides gaze location in pixels) gaze is within the 'target' or
% 'fixation' window. Returns "true" if the eye is in the window or if
% "passEye" is set to "true".


% if no argument was passed to say whether we're checking relative to
% target or fixation, assume we're checking relative to fixation.
if nargin < 2
    whichWinString = 'fixation';
end

% check "in-window-ness" appropriately
switch whichWinString
    case 'fixation'
        inWindowLogical = ...
            (abs(p.trVars.eyePixX - p.trVars.fixPixX) < ...
            p.trVars.fixWinWidthDeg && ...
            abs(p.trVars.eyePixY - p.trVars.fixPixY) < ...
            p.trVars.fixWinHeightDeg) || p.trVars.passEye;
    
    case 'target'
        inWindowLogical = ...
            (abs(p.trVars.eyePixX - p.trVars.targPixX) < ...
            p.trVars.targWinWidthDeg && ...
            abs(p.trVars.eyePixY - p.trVars.targPixY) < ...
            p.trVars.targWinHeightDeg) || p.trVars.passEye;
        
    case 'image'
      inWindowLogical = ...
          (abs(p.trVars.eyePixX - p.trVars.fixPixX) < ...
          p.trVars.imageWinWidthDeg && ...
            abs(p.trVars.eyePixY - p.trVars.fixPixY) < ...
            p.trVars.imageWinHeightDeg) || p.trVars.passEye;
        
end

end