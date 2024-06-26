function p = human_psychophysical_threshold_init(p)
%
%   p = human_psychophysical_threshold_init(p)
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

%% In this fuction, you may expect:
% (1) Add path(s) for support functions.
% (2) Rig-specific initrmation is defined (geometry, etc.)
% (3) Color look-up-table (lut) is defined.
% (4) Psychophysics toolbox and VIEWPixx/DATAPixx are initialized.
% (5) Audio waveforms are defined and loaded to the VIEWPixx.
% (6) Trial structure is initialized / defined.
% (7) Windows for online plotting are defined. MATLAB and PLDAPS gui
%     windows are repositioned and old windows are closed.

% % (1) add paths (loop over p.pathList elements and add each).
% for iP = 1:numel(p.pathList)
%     if isdir(p.pathList{iP})
%         addpath(genpath(p.pathList{iP}));
%     else
%         warning(['could not add the path ' p.pathList{iP} ...
%             ' because I couldn''t find it'])
%     end
% end

% (2) define rig-specific information
p   = pds.initRigConfigFile(p);

% (3) define color look-up-table (lut). 
p   = initClut(p);

% (4) initialize PsychToolbox:
p = pds.initPsychToolbox(p);

% (5) initialize EyeLink:
setGuiMessage(...
    'Eyelink Setup. Init Continues After Eyelink Interaction Is Done');
p = pds.initEyelink(p);
disp('pds.initEyelink execution has completed.');
setGuiMessage(...
    'Eyelink Setup Complete!');
ListenChar(1);

% If this is the "speed" task, we need to redefine some variables
% incorporating the screen refresh rate:
if contains(p.init.settingsFile, 'speed')
    
    % define minimum and maximum "speed" based on refresh rate:
    p.stim.minSpeed = 2 * pi / p.rig.refreshRate;
    p.stim.maxSpeed = 2 * pi / (p.rig.refreshRate / 12);

    % define "initSpeed" to be the middle of the minSpeed / maxSpeed range:
    p.trVarsInit.speedInit = mean([p.stim.minSpeed, p.stim.maxSpeed]);

    % variables related to "QUEST" (adaptive threshold estimation)
    p.trVarsInit.minSignalStrength       = 0;    % what is the smallest signal we want to test?
    p.trVarsInit.maxSignalStrength       = p.trVarsInit.speedInit - p.stim.minSpeed;     % what is the largest signal we want to test?
    p.trVarsInit.supraSignalStrength     = p.trVarsInit.maxSignalStrength;      % what is a signal strength that is very likely to be above threshold?

    % now assign to "trVarsGuiComm
    p.trVarsGuiComm = p.trVarsInit;
end

% (6) define trial structure
p   = initTrialStructure(p);

% (7) define online-plotting windows (and reposition others).
p   = plotWindowSetup(p);

% (8) define in-line functions
p   = inLineDefs(p);

% define audio waveforms
p   = initAudio(p);

% create keyboard queue to collect subject responses:
p   = makeKbQueue(p);

% set task codes:
p.init.codes = pds.initCodes;

% initialize the random seed:
RandStream.setGlobalStream(RandStream('mt19937ar','Seed', 0));

end

function p                      = inLineDefs(p)

% get rid of blank spaces.
p.stim.funs.dewhite = @(x)x(x~=' ');

% vectorize array
p.stim.funs.flatten = @(x)x(:);

% vectorize array & chop off last entry
p.stim.funs.flatchp = @(x)x(1:end-1);

% make a 2d array 3d by replicating along 3rd dimension
p.stim.funs.repFr   = @(x,n)reshape(repmat(x(:),n,1),[size(x),n]);

% rotate one or more 2D vectors by ONE angle
p.stim.funs.rotVcts = @(x,theta)[cosd(theta), -sind(theta); ...
    sind(theta), cosd(theta)]*x;

% rotate ONE 2D vector by several angles
p.stim.funs.rtAngls = @(x,thetas)reshape([cosd(thetas), -sind(thetas); ...
    sind(thetas), cosd(thetas)]*x,size(thetas,1),size(x,2)*2);

% generate an array of of size s with values drawn from a uniform
% distribution on the interval [l,h]
p.stim.funs.unfrnd  = @(l,h,s)rand(s)*(h-l) + l;

% generate an array of size s with values drawn from a Gaussian
% distribution with mean mu and variance sigma
p.stim.funs.nrmrnd  = @(mu,sig,s)randn(s)*sig + mu;

% anti-"cumsum": fidiff(cumsum(x)) = x;
p.stim.funs.fidiff  = @(x)[x(1) diff(x)];

% returns "true" (1) for even integers and "false" (0) for odds
p.stim.funs.iseven  = @(x)round(x/2) == x/2;

end

function setGuiMessage(messageString)
    uiData = guidata(findall(0, 'Name', 'PLDAPS_vK2_GUI'));
    set(uiData.handles.uiStatusString, 'String', ...
        messageString);
%     drawnow;
end




