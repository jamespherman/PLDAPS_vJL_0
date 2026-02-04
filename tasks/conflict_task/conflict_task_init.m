function p = conflict_task_init(p)
%   p = conflict_task_init(p)
%
% Part of the quintet of PLDAPS functions:
%   settings function - defines default parameters
%   init function     - one-time setup (this file)
%   next function     - runs before each trial
%   run function      - executes each trial
%   finish function   - runs after each trial
%
% This initialization function executes once after the settings file
% has run. It may also be run directly from the GUI by clicking "Initialization".

%%

% Load rig-specific configuration (monitor distance, etc.)
p   = pds.initRigConfigFile(p);

% Define color look-up-table (CLUT) for dual-display gamma correction
p   = initClut(p);

% Initialize VIEWPixx/DATAPixx hardware for timing and display
p   = pds.initDataPixx(p);

% Define audio waveforms (reward tones, etc.) and load to VIEWPixx
p   = pds.initAudio(p);

% Define grid line locations for experimenter display overlay
p   = pds.defineGridLines(p);

% Initialize task codes for event strobing to neural recording system
p.init.codes = pds.initCodes;

% Build the trial structure array defining all trial types
% (must run before extraWindowSetup so deltaTValues is available for plotting)
p   = initTrialStructure(p);

% Define online-plotting windows (tachometric curve, etc.)
p   = extraWindowSetup(p);

% Initialize connection to Ripple neural recording system
p = pds.initRipple(p);

%% Define 'strb' as classyStrobe object
p.init.strb = pds.classyStrobe;

end
