function inWindowLogical = eyeInWindowEL(p, whichWinString)
%
% inWindowLogical = eyeInWindowEL(p, ['target' / 'fixation'])
%
% Checks whether the current eye positions IN PIXELS are within the
% 'target' or 'fixation' window. Returns "true" if the eye is in the window
% or if "passEye" is set to "true".


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
            p.trVars.fixWinWidthPix && ...
            abs(p.trVars.eyePixY - p.trVars.fixPixY) < ...
            p.trVars.fixWinHeightPix) || p.trVars.passEye;
    
    case 'target'
        inWindowLogical = ...
            (abs(p.trVars.eyePixX - p.trVars.targPixX) < ...
            p.trVars.targWinWidthPix && ...
            abs(p.trVars.eyePixY - p.trVars.targPixY) < ...
            p.trVars.targWinHeightPix) || p.trVars.passEye;
        
    case 'image'
      inWindowLogical = ...
          (abs(p.trVars.eyePixX - p.trVars.fixPixX) < ...
          p.trVars.imageWinWidthPix && ...
            abs(p.trVars.eyePixY - p.trVars.fixPixY) < ...
            p.trVars.imageWinHeightPix) || p.trVars.passEye;
        
end

end