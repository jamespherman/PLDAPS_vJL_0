function p = rigConfig_rig1(p)

% this is the rig config file for rig 1
% Here we note rig- and animal-specific details such as screen size or
% distance from screen etc. 
% 
% Please save the file in the format:
% 
%   rigConfig_rig#_yyyymmdd
% 
% where 
%   # is uppercase rig letter (e.g. "A") 
%   name is lowercase monkey name (e.g. ridley)
%   yyyymmdd is the date (e.g. 19830531)

%% Geometry
p.rig.viewdist        = 410;      % viewing distance (mm)
p.rig.screenhpix      = 1200;     % screen height (pixels)
p.rig.screenh         = 302.40;   % screen height (mm)
p.rig.deg2PixConstant = p.rig.viewdist * p.rig.screenhpix / p.rig.screenh;

%% Screen
p.rig.screen_name       = 'viewpixx';
p.rig.screen_number     = 1;                    % zero for one screen set-up, 1 or 2 for multiscreen
p.rig.refreshRate       = 100;                  % display refresh rate (Hz).
p.rig.frameDuration     = 1/p.rig.refreshRate;  % display frame duration (s);
p.rig.magicNumber       = 0.008;                % time to wait for screen flip

%% Reward (some systems have slightly different calibrations):
p.rig.baseReward        = 189;

%% Joystick
% joystick can be either pressed down, at rest, or pressed. 
% Hence, each joystick has a min, rest, and max Voltage.
% User must measure output of rig joystick and write output here. These 
% don't actually get used, but they inform ojystick thresholds which are 
% set in the "Joystick THresholds" section, below
p.rig.joyVoltageMin     = 0.8540;
p.rig.joyVoltageRest    = 2.7873;
p.rig.joyVoltageMax     = 4.6079;

%% Joystick thresholds
% When at rest, the joystick has a vertain voltage. Then it can either be
% pressed in the 'high voltage' direction or 'low voltage' direction
% relative to that rest point. 
% The following thresholds are for pressing (within either the high or low
% voltage regimes) and releasing from those states back to rest. We first
% define a fraction of the range (between joyVoltageRest and either 
% joyVoltageMin or joyVoltageMax) for determining the threshold voltages,
% then calculate the threshold values.
p.rig.joyThresh.rangeFractPress  = 4/5;
p.rig.joyThresh.rangeFractRels   = 1/10;
fracFun = @(a, b, x)a*(1-x) + b*x;

p.rig.joyThresh.highVoltPress    = fracFun(p.rig.joyVoltageRest,  ...
    p.rig.joyVoltageMax, p.rig.joyThresh.rangeFractPress);
p.rig.joyThresh.highVoltRelease  = fracFun(p.rig.joyVoltageRest,  ...
    p.rig.joyVoltageMax, p.rig.joyThresh.rangeFractRels);
p.rig.joyThresh.lowVoltPress     = fracFun(p.rig.joyVoltageRest,  ...
    p.rig.joyVoltageMin, p.rig.joyThresh.rangeFractPress);
p.rig.joyThresh.lowVoltRelease   = fracFun(p.rig.joyVoltageRest,  ...
    p.rig.joyVoltageMin, p.rig.joyThresh.rangeFractRels);

%% datapixx - vars related to datapixx schedule settings

p.rig.dp.useDataPixxBool       = p.init.useDataPixxBool;        % using datapixx
p.rig.dp.adcRate               = 1000;     % define ADC sampling rate (Hz).
p.rig.dp.maxDurADC             = 15;       % what is the maximum duration to preallocate for ADC buffering?
p.rig.dp.adcBuffAddr           = 4e6;      % VIEWPixx / DATAPixx internal ADC memory buffer address.
p.rig.dp.dacRate               = 1000;     % define DAC sampling rate (Hz);
p.rig.dp.dacPadDur             = 0.01;     % how much time to pad the DAC +4V with +0V?
p.rig.dp.dacBuffAddr           = 10e6;     % DAC buffer base address
p.rig.dp.dacChannelOut         = 0;        % Which channel to use for DAC outpt control of reward system.

%%
p.rig.connectToOmniplex   = false;

% open connection to omniplex PC MATLAB instance 
if p.rig.connectToOmniplex
    p = pds.openPortToServer(p);
end



end
