function p = getMouse(p)
%   p = getMouse(p)
%
% Uses PTB GetMouse function to get mouse cursor location and store it in
% the pldaps struct 'p'.
 
[p.trVars.mouseCursorX, p.trVars.mouseCursorY] = GetMouse(0);

end