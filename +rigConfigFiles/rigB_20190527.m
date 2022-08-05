function p = rigB_20190527(p)

% this is the rig config file
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
p.rig.screen_name           = 'viewpixx';
p.rig.screen_number         = 1;                    % zero for one screen set-up, 1 or 2 for multiscreen
p.rig.refreshRate           = 100;                  % display refresh rate (Hz).
p.rig.frameDuration         = 1/p.rig.refreshRate;  % display frame duration (s);
p.rig.magicNumber           = 0.006;                % time to wait for screen flip

%% strobeToScreenLatency:
% %his is the duration elapsed from the command 'Flip' (and strobing that the
% screen flipped) and until the screen physcially changed (measured by a
% photometer placed at the top of the screen, center).
p.rig.latencyStrobeToScreen     = 0.008; % in s

%% latencyScreenTopToBottom
% Most screen draw one row at a time. The viewpixx has 8 LED rows, and the
% latency from top ro to bottom is 8ms (measured by a photodiode places at 
% the top of the screen, center, and again at bottom, center.
p.rig.latencyScreenTopToBottom  = 0.008; % in s

%% Joystick
% joystick can be either pressed down, at rest, or pressed. 
% Hence, each joystick has a min, rest, and max Voltage.
% User must measure output of rig joystick and write output here. These 
% don't actually get used, but they inform ojystick thresholds which are 
% set in the "Joystick THresholds" section, below
p.rig.joyVoltageMin     = 0.003;
p.rig.joyVoltageRest    = 2.26;
p.rig.joyVoltageMax     = 4.42;

%% Joystick thresholds
% When at rest, the joystick has a vertain voltage. Then it can either be
% pressed in the 'high voltage' direction or 'low voltage' direction
% relative to that rest point. 
% The following thresholds are for pressing (within either the high or low
% voltage regimes) and releasing from those states back to rest:
    
p.rig.joyThresh.highVoltPress    = 4;
p.rig.joyThresh.highVoltRelease  = 2.5;
p.rig.joyThresh.lowVoltPress     = 0.5;
p.rig.joyThresh.lowVoltRelease   = 2;

%% datapixx - vars related to datapixx schedule settings

p.rig.dp.useDataPixxBool       = 1;        % using datapixx
p.rig.dp.adcRate               = 1000;     % define ADC sampling rate (Hz).
p.rig.dp.maxDurADC             = 15;       % what is the maximum duration to preallocate for ADC buffering?
p.rig.dp.adcBuffAddr           = 4e6;      % VIEWPixx / DATAPixx internal ADC memory buffer address.
p.rig.dp.dacRate               = 1000;     % define DAC sampling rate (Hz);
p.rig.dp.dacPadDur             = 0.01;     % how much time to pad the DAC +4V with +0V?
p.rig.dp.dacBuffAddr           = 10e6;     % DAC buffer base address
p.rig.dp.dacChannelOut         = 0;        % Which channel to use for DAC outpt control of reward system.

%%
% omniplex IP address
% p.rig.omniplexIP = xxxxxx;

p.rig.connectToOmniplex   = false;

% open connection to omniplex PC MATLAB instance 
if p.rig.connectToOmniplex
    p = pds.openPortToServer(p);
end



end