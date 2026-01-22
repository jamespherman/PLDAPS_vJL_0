function p = gSac_4factors_init(p)
%   p = gSac_4factors_init(p)
%
% Part of the quintet of PLDAPS functions:
%   settings function - defines default parameters
%   init function     - one-time setup (this file)
%   next function     - runs before each trial
%   run function      - executes each trial
%   finish function   - runs after each trial
%
% This initialization function executes once after the settings file
% has run and settings have been stored in "m", "c", and "s" structs.
% It may also be run directly from the GUI by clicking "Initialization".

%%

% Load rig-specific configuration (monitor distance, etc.)
p   = pds.initRigConfigFile(p);

% Define color look-up-table (CLUT) for dual-display gamma correction
p   = initClut(p);

% Initialize VIEWPixx/DATAPixx hardware for timing and display
p   = pds.initDataPixx(p);

% Load image textures (faces, non-faces) into GPU memory
p = initImageTextures(p);

% Define audio waveforms (reward tones, etc.) and load to VIEWPixx
p   = pds.initAudio(p);

% Define online-plotting windows (and reposition others).
p   = extraWindowSetup(p);

% Define grid line locations for experimenter display overlay
p   = pds.defineGridLines(p);

% Initialize task codes for event strobing to neural recording system
p.init.codes = pds.initCodes;

% Initialize list of possible target locations
p = initTargetLocationList(p);

% Build the trial structure array defining all trial types
p   = initTrialStructure(p);

% Initialize connection to Ripple neural recording system
p = pds.initRipple(p);

%% Define 'strb' as classyStrobe object
% classyStrobe is a class for managing event strobes.
% Main methods:
%   addValue - queues a value to be strobed on next strobe call
%   strobe   - sends all queued values to the recording system
p.init.strb = pds.classyStrobe;

end
