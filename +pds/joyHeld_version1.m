function joyHeldLogical = joyHeld(p)
%
% joyHeldLogical = joyHeld(c)
%
% returns true if joystick voltage is smaller than the joystick hold
% voltage threshold.

joyHeldLogical = (p.trVars.joyVolt < p.rig.joyThreshPress) || p.trVars.passJoy;

end