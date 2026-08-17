function p = srsSmooth_init(p)
%   p = srsSmooth_init(p)
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

% (3) define color look-up-table (lut). The CLUT structures are still
% initialized in direct-RGB mode because other task code expects their
% metadata, but the C24 display never uses them to draw the targets.
p   = initClut(p);

% (4) initialize VIEWPixx/DATAPixx. salienceType 3 uses true C24 RGB
% passthrough; hue and DKL-luminance modes retain the standard L48 window.
salienceType = getInitialSalienceType(p);
if salienceType == 3
    p = loadSrsDirectRgbCalibration(p);
    p = initDataPixxC24(p);
else
    p = pds.initDataPixx(p);
    p.draw.displayMode = 'L48_DUAL_CLUT';
    p.draw.isDirectRgb = false;
end

% (5) define audio waveforms and load to VIEWPixx
p   = pds.initAudio(p);
if isfield(p.trVarsInit, 'useThreeOutcomeTones') && ...
        logical(p.trVarsInit.useThreeOutcomeTones)
    p = initSrsFeedbackAudio(p);
end

% (6) define trial structure
p   = initTrialStructure(p);

% (7) define online-plotting windows (and reposition others).
p   = plotWindowSetup(p);

% Direct-RGB C24 cannot hide overlays on the mirrored DATAPixx console.
% Create a separate experimenter-only preview on the MATLAB desktop.
if isfield(p.draw, 'isDirectRgb') && p.draw.isDirectRgb
    p = initDirectRgbExperimenterPreview(p);
end

% Live correction controls are available in every salience mode. The task
% reads these controls before each trial, so activation and parameter
% changes take effect without restarting the session.
p = initCorrectionControlWindow(p);

% (8) define in-line functions
p   = inLineDefs(p);

% set task codes:
p.init.codes = pds.initCodes;

% initialize the random seed:
%RandStream.setGlobalStream(RandStream('mt19937ar','Seed', 0));

%% define 'strb' as classyStrboe
% this is a class.
% It's main methods:
%   addValue - adds a vlaue to the valueList, which will be strobed
%              once the 'strobe' method is called
%   strobe - when called strobes all values that are in the valueList.
p.init.strb = pds.classyStrobe;


%% init a mat file that will hold all data. 
% Here I save struct p the good ol' fashioned way using 'save'. I then
% define the mat file as an object using 'matfile' such that I may append
% trial-by-trial data to it (in finish function). 

% % % save:
% % save(p.init.output_path, '-struct', 'p', '-v7.3')
% % 
% % % crate object to access saved file:
% % p.init.mp = matfile(p.init.output_path, 'writable', true);




end

function salienceType = getInitialSalienceType(p)
%GETINITIALSALIENCETYPE Resolve the display mode before trial variables run.

salienceType = 1;
if isfield(p, 'trVarsGuiComm') && ...
        isfield(p.trVarsGuiComm, 'salienceType')
    salienceType = double(p.trVarsGuiComm.salienceType);
elseif isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'salienceType')
    salienceType = double(p.trVarsInit.salienceType);
elseif isfield(p, 'trVars') && isfield(p.trVars, 'salienceType')
    salienceType = double(p.trVars.salienceType);
end
if ~isscalar(salienceType) || ~ismember(salienceType, [1 2 3])
    error('salienceType must be 1 (hue), 2 (DKL luminance), or 3 (direct RGB).');
end

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
p.stim.funs.rotVcts = @(x,theta)[cosd(theta), -sind(theta); sind(theta), cosd(theta)]*x;

% rotate ONE 2D vector by several angles
p.stim.funs.rtAngls = @(x,thetas)reshape([cosd(thetas), -sind(thetas); sind(thetas), cosd(thetas)]*x,size(thetas,1),size(x,2)*2);

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



