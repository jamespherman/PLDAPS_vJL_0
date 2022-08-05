function p = getEyeJoy(p)

% Reads the newest available sample of DATAPixx ADC voltages and returns:
% p.trVars.eyePixX      - eye x position in pixels
% p.trVars.eyePixY      - eye y position in pixels
% p.trVars.eyeDegX      - eye x position in degrees
% p.trVars.eyeDegY      - eye y position in degrees
% p.trVars.joyVolt      - joystick voltage

% Update DATAPixx registers
Datapixx('RegWrRd');

% Read voltages
V       = Datapixx('GetAdcVoltages');

% Convert eyelink analog voltages into screen pixels. Because screen pixels
% are numerically indexed from the top of the screen down to the bottom, we
% have to invert the sign of the vertical signal from the eyelink which
% outputs a positive voltage for upward deviations and a negative voltage
% for downward deviations.
p.trVars.eyePixX   =sign(V(1)) * pds.deg2pix(4 * abs(V(1)), p);
p.trVars.eyePixY   = -sign(V(2)) * pds.deg2pix(4 * abs(V(2)), p);

% Return eye position in degrees
p.trVars.eyeDegX   = 4 * V(1);
p.trVars.eyeDegY   = 4 * V(2);

% assign joy-voltage
p.trVars.joyVolt   = V(4);

end