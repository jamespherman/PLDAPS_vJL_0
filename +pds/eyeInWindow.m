function inWindowLogical = eyeInWindow(p, whichWinString, varargin)
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
elseif nargin > 2
    targRow = varargin{1}; % first input for varargin should be the specified target number
else
    targRow = 1; % If no value is passed in for varargin, simply take the value of targDegX and Y
end

% check "in-window-ness" appropriately
switch whichWinString
    case 'fixation'
        inWindowLogical = ...
            (abs(p.trVars.eyeDegX - p.trVars.fixDegX) < ...
            p.trVars.fixWinWidthDeg && ...
            abs(p.trVars.eyeDegY - p.trVars.fixDegY) < ...
            p.trVars.fixWinHeightDeg) || p.trVars.passEye;
    
    case 'target'
        inWindowLogical = ...
            (abs(p.trVars.eyeDegX - p.trVars.targDegX (targRow)) < ...
            p.trVars.targWinWidthDeg && ...
            abs(p.trVars.eyeDegY - p.trVars.targDegY (targRow)) < ...
            p.trVars.targWinHeightDeg) || p.trVars.passEye;
        
    case 'image'
      inWindowLogical = ...
          (abs(p.trVars.eyeDegX - p.trVars.fixDegX) < ...
          p.trVars.imageWinWidthDeg && ...
            abs(p.trVars.eyeDegY - p.trVars.fixDegY) < ...
            p.trVars.imageWinHeightDeg) || p.trVars.passEye;
      
end

end
