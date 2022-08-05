function inWindowLogical = eyeInWindow(p, whichWinString)
%
% inWindowLogical = eyeInWindow(p, ['target' / 'fixation'])
%
% Checks whether the current eye positions is within the 'target' or
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
        inWindowLogical = (abs(p.trVars.eyeDegX - p.trVars.fixDegX) < p.trVars.fixWinWidthDeg && ...
            abs(p.trVars.eyeDegY - p.trVars.fixDegY) < p.trVars.fixWinHeightDeg) || p.trVars.passEye;
    
    case 'target'
        inWindowLogical = (abs(p.trVars.eyeDegX - p.trVars.targDegX) < p.trVars.targWinWidthDeg && ...
            abs(p.trVars.eyeDegY - p.trVars.targDegY) < p.trVars.targWinHeightDeg) || p.trVars.passEye;
        
    case 'image'
      inWindowLogical = (abs(p.trVars.eyeDegX - p.trVars.fixDegX) < p.trVars.imageWinWidthDeg && ...
            abs(p.trVars.eyeDegY - p.trVars.fixDegY) < p.trVars.imageWinHeightDeg) || p.trVars.passEye;
        
end

end