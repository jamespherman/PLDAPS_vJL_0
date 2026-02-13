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

% if this is a "speed" task we must compute speeds here now that we have a
% "pixels per degree" value specified:
if contains(p.init.settingsFile, 'speed')

    % define spatial frequency of gabor in cycles per pixel:
    p.trVarsInit.freqCycPx               = p.trVarsInit.freqInit / ...
        pds.deg2pix(1,p);

    % Our minimum speed is based on the assumption that we change the phase
    % by 1 pixel per frame. Note, this is also the smallest difference in
    % speed that can be achieved. The maximum speed is instead just based
    % on the assumption that we don't want to move more than 1/4 cycle per
    % frame:
    p.stim.minSpeed                      = p.trVarsInit.freqCycPx * 2 * pi;
    p.stim.maxSpeed                      = pi / 2;

    % In these speed tasks 3/4 stimuli have one speed and the 4th, outlier
    % stimulus has a different speed. We specify the speed for 3/4 stimuli
    % as the value halfway between the minimum and the maximum, then
    % specify our minimum and maximum signal strength based on the range
    % between that midpoint and the top / bottom of the range:
    p.stim.midSpeed                      = (p.stim.maxSpeed + ...
        p.stim.minSpeed) / 2;
    p.trVarsInit.minSignalStrength       = p.stim.minSpeed;
    p.trVarsInit.maxSignalStrength       = p.stim.maxSpeed - ...
        p.stim.midSpeed;
    p.trVarsInit.supraSignalStrength     = p.trVarsInit.maxSignalStrength;
    p.trVarsInit.speedInit               = p.stim.midSpeed;

    % We define the "SD" and the "grain" based on the min/max signal
    % strengths:
    p.trVarsInit.initQuestSD             = ...
        (p.trVarsInit.maxSignalStrength - ...
        p.trVarsInit.minSignalStrength) / 6;
    p.trVarsInit.questGrain              = p.stim.minSpeed / 2;

    % define the initial speed delta and the initial threshold guess as the
    % midpoint between the minimum and maximum signal strengths. We do this
    % because "QuestCreate" defines the psychometric function under this
    % assumption and we'll get out-of-range errors if we choose a different
    % value:
    p.trVarsInit.initQuestThreshGuess    = p.stim.minSpeed + ...
        p.trVarsInit.maxSignalStrength / 2;
end

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




