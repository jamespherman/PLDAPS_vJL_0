function p = gSac_4factors_init(p)
%   p = gSac_4factors_init(p)
%
% Part of the quintet of pldpas functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Initialization function
% Executed only 1 time, after the *_settings file has run and settings have 
% been stored in "m", "c", and "s" structures. 
% May also be run directly from the gui by clicking "Initialization".

%%

% define rig-specific information
p   = pds.initRigConfigFile(p);

% define color look-up-table (clut). 
p   = initClut(p);

% initialize VIEWPixx/DATAPixx
p   = pds.initDataPixx(p);

% define audio waveforms and load to VIEWPixx
p   = pds.initAudio(p);

% define online-plotting windows (and reposition others).
p   = extraWindowSetup(p);

% define grid line locations:
p   = pds.defineGridLines(p);

% set task codes:
p.init.codes = pds.initCodes;

% initialize target locations list:
p = initTargetLocationList(p);

% initialize trial structure:
p   = initTrialStructure(p);

% initialize connection to Ripple:
p = pds.initRipple(p);

%% define 'strb' as classyStrboe
% this is a class.
% It's main methods:
%   addValue - adds a vlaue to the valueList, which will be strobed
%              once the 'strobe' method is called
%   strobe - when called strobes all values that are in the valueList.
p.init.strb = pds.classyStrobe;

end