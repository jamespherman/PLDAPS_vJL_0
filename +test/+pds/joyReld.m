function joyReleasedLogical = joyReld(c)
%
% joyHeldLogical = joyReld(c)
%
% returns true if joystick voltage is larger than the joystick release
% voltage threshold.

joyReleasedLogical = (c.joyVolt > c.joyThreshRelease) || c.passJoy;

end