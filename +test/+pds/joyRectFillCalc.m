function rectOut = joyRectFillCalc(p)

% how many steps do we want the joystick vertical position indicator broken
% down into? (this makes the display more stable in case of fluctuating
% voltage from the joystick).
nDivs   = 15;

% how big is each chunk?
divSize = 1/nDivs;

% find "slope" and "intercept" for converting between joystick voltage
% range (joyVoltageMin - joyVoltageMax) and the interval 0 - 1.
m = 1/(p.rig.joyVoltageMin - p.rig.joyVoltageMax);
b = 0 - m*p.rig.joyVoltageMax;

% calculate "scaled" joystick position (value between 0 and 1).
scaledJoyPos = (p.trVars.joyVolt*m + b);

% discretize scaled joystick position using "divSize" specified above: if
% the value is smaller than divSize, set it to "0", if it's larger than
% (nDivs-1)*divSize, set it to "1". Otherwise, let it vary continuously.
if scaledJoyPos < divSize
    scaledJoyPos = 0;
elseif scaledJoyPos > (nDivs-1)*divSize
    scaledJoyPos = 1;
end

rectOut = [p.draw.joyRect(1:3), p.draw.joyRect(2) + ...
    (p.draw.joyRect(4)-p.draw.joyRect(2))*scaledJoyPos];

end