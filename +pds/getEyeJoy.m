function p = getEyeJoy(p)

% reads DATAPixx ADC voltages and returns:
% p.EyeX    - eye x position in pixels
% p.EyeY    - eye y position in pixels
% p.EyeXd   - eye x position in degrees
% p.EyeYd   - eye y position in degrees
% p.joy     - joystick voltage

% update DATAPixx registers
Datapixx('RegWrRd');

% read voltages
V       = Datapixx('GetAdcVoltages');

% convert eye-voltages into screen-pixels (sign change in X to account for
% camera inversion.
p.trVars.eyePixX   =sign(V(1)) * pds.deg2pix(4 * abs(V(1)), p);
p.trVars.eyePixY   = -sign(V(2)) * pds.deg2pix(4 * abs(V(2)), p);

% also return eye position in degrees
p.trVars.eyeDegX   =4 * V(1);
p.trVars.eyeDegY   = -4 * V(2);

% assign joy-voltage
p.trVars.joyVolt   = V(4);

end