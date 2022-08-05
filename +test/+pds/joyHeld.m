function [joyHeldLogical, joyState] = joyHeld(p)
%
% [joyHeldLogical, joyState] = joyHeld(p)
%
% joyHeldLogical checks the state of the joystick by comparing its voltage 
% to the user-defined thresholds supplied in the struct joyThresh.
% States can be:
%   pressed down (joyState = 1) 
%   released / at rest (joyState = 0)
%   in between (joyState = nan);
%       * at this point, I do not consider a "raised" position, where the
%       joystick is raised upwards. I'm only considering pressed downwards, 
%       relaesed, or in  between.
%
% if p.trVars.passJoy is set to TRUE the function returns 1.
%
% Standard joystick placement is such that pressing down increases voltage. 
% But sometimes we turn joystick upsidedown. That's why we need threshold
% for either state. These are defined in:
%   p.rig.joyThresh - struct with fields that determine the voltages at 
%   which joyStates change:
%       .highVoltPress
%       .highVoltRelease
%       .lowVoltPress
%       .lowVoltRelease
%
% This function knows the orientation of the joystick given:
%   p.trVars.joyPressVoltDir
% if set to 1, pressing the joy takes the voltage down (default)
% if set to 2, pressing the joy takes the voltage down ("upsidedown")

% 20180802 - lnk elaborated the previous joyHeld function which I now
% renamed joyHeld_version1

% default:
if ~isfield(p.trVars, 'joyPressVoltDir')
    p.trVars.joyPressVoltDir = 1;
end

%% check joyState 

% If joystick is in standard position, then pressing down DECREASES volt:
if p.trVars.joyPressVoltDir == 1 
    if p.trVars.joyVolt < p.rig.joyThresh.lowVoltPress
        joyState = 1; % pressed 
    
    elseif  p.trVars.joyVolt >= p.rig.joyThresh.lowVoltPress && p.trVars.joyVolt <= p.rig.joyThresh.lowVoltRelease
        joyState = nan; % in between pressed & released
        
    elseif p.trVars.joyVolt > p.rig.joyThresh.lowVoltRelease
        joyState = 0; % released
    end
    
% If joystick is in "upsidedown" position, then pressing down INCREASES volt:
elseif p.trVars.joyPressVoltDir == 2   
    if p.trVars.joyVolt > p.rig.joyThresh.highVoltPress
        joyState = 1; % pressed
    
    elseif  p.trVars.joyVolt <= p.rig.joyThresh.highVoltPress && p.trVars.joyVolt >= p.rig.joyThresh.highVoltRelease
        joyState = nan; % in between pressed & released
        
    elseif p.trVars.joyVolt < p.rig.joyThresh.highVoltRelease
        joyState = 0; % released
    end
else
    warning('your ''joyPressVoltDir'' is ill-defined and you will suffer the consequences! Setting ''joyState'' to nan');
    joyState = nan;
end

%% return joyHeldLogical

joyHeldLogical = p.trVars.passJoy | joyState == 1; % return TRUE if joystick pressed.


