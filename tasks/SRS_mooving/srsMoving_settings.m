function p = srsMoving_settings
%SRSMOVING_SETTINGS SRS variant with Dubey-style randomized target locations.
%
% Reward, salience, timing, correction and display logic are inherited from
% SRS_Task_Smooth. Target identity stays attached to T1/T2 while the screen
% position is resampled on every normal trial attempt.
%
% Geometry:
%   - both targets lie on one eccentricity circle around fixation;
%   - T1 angle is uniform on [0,360) deg;
%   - T2 is conditionally uniform subject to a minimum shortest angular
%     separation;
%   - forced correction repeats restore the exact original coordinates.
%
% IMPORTANT SPATIAL DEFINITIONS
%   T1PhysicalSide/T2PhysicalSide: horizontal hemifield only
%       0 = vertical meridian, 1 = right, 2 = left
%   T1VerticalSide/T2VerticalSide: vertical hemifield only
%       0 = horizontal meridian, 1 = upper, 2 = lower
%   rightmost/leftmost and uppermost/lowermost are RELATIVE comparisons
%   between the two targets and therefore remain meaningful even when both
%   targets occupy the same hemifield.

thisTaskFolder = fileparts(mfilename('fullpath'));
tasksFolder = fileparts(thisTaskFolder);
baseTaskFolder = fullfile(tasksFolder, 'SRS_Task_Smooth');
baseSupportFolder = fullfile(baseTaskFolder, 'supportFunctions');
baseActionsFolder = fullfile(baseTaskFolder, 'actions');

if ~isfolder(baseTaskFolder)
    error('SRS_mooving:MissingBaseTask', ...
        ['SRS_mooving requires the sibling folder tasks/SRS_Task_Smooth. ', ...
         'Expected it at: %s'], baseTaskFolder);
end

% Moving-specific overrides must resolve before the shared base helpers.
addpath(thisTaskFolder, '-begin');
addpath(fullfile(thisTaskFolder, 'supportFunctions'), '-begin');
addpath(baseTaskFolder, '-end');
if isfolder(baseSupportFolder)
    addpath(baseSupportFolder, '-end');
end
if isfolder(baseActionsFolder)
    addpath(baseActionsFolder, '-end');
end

p = srsSmooth_settings;

% Force PLDAPS to use the moving wrapper files.
p.init.taskName = 'srsMoving';
p.init.exptType = 'srs_moving';
p.init.protocol_title = 'srsMoving_task';
p.init.pldapsFolder = thisTaskFolder;
p.init.outputFolder = fullfile(thisTaskFolder, 'output');
p.init.figureFolder = fullfile(p.init.outputFolder, 'figures');
p.init.sessionId = [p.init.date '_t' p.init.time '_srsMoving'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);
p.init.taskFiles.init = 'srsMoving_init.m';
p.init.taskFiles.next = 'srsMoving_next.m';
p.init.taskFiles.run = 'srsMoving_run.m';
p.init.taskFiles.finish = 'srsMoving_finish.m';
p.init.srsMovingBaseTaskFolder = baseTaskFolder;

%% Dubey-style moving geometry
p.trVarsInit.movingTargetsEnabled = true;
p.trVarsInit.movingTargetEccDeg = 10;
p.trVarsInit.movingTargetMinSeparationDeg = 90;

% Trial-resolved geometry. These values are overwritten before every normal
% trial and restored exactly during forced correction repeats.
p.trVarsInit.movingT1AngleDeg = 0;
p.trVarsInit.movingT2AngleDeg = 180;
p.trVarsInit.movingAngularSeparationDeg = 180;
p.trVarsInit.movingT1Angle_x10 = 0;
p.trVarsInit.movingT2Angle_x10 = 1800;
p.trVarsInit.movingSeparation_x10 = 1800;
p.trVarsInit.movingEccentricity_x100 = 1000;

% Absolute horizontal/vertical hemifields.
p.trVarsInit.T1PhysicalSide = 1;       % 0=midline, 1=right, 2=left
p.trVarsInit.T2PhysicalSide = 2;
p.trVarsInit.T1VerticalSide = 0;       % 0=midline, 1=upper, 2=lower
p.trVarsInit.T2VerticalSide = 0;

% Relative geometry between the two targets.
p.trVarsInit.movingTargetsStraddleLR = 1;
p.trVarsInit.movingTargetsStraddleUD = 0;
p.trVarsInit.rightmostTargetID = 1;
p.trVarsInit.leftmostTargetID = 2;
p.trVarsInit.uppermostTargetID = 0;
p.trVarsInit.lowermostTargetID = 0;
p.trVarsInit.chosenHorizontalRank = 0; % 0=undefined,1=rightmost,2=leftmost
p.trVarsInit.chosenVerticalRank = 0;   % 0=undefined,1=uppermost,2=lowermost

p.status.highRewardPhysicalSide = 0;
p.status.highSaliencePhysicalSide = 0;
p.status.correctionTrialTriggerTargetID = 0;

% Fixed T1/T2 positions are not meaningful GUI controls in this task.
p.rig.guiVars{7} = 'movingTargetEccDeg';
p.rig.guiVars{8} = 'movingTargetMinSeparationDeg';
p.rig.guiVars{9} = 'targWinWidthDeg';
p.rig.guiVars{10} = 'targWinHeightDeg';

%% Moving-task strobes
% Every name here MUST exist in +pds/initCodes.m. srsMoving_init performs a
% hard startup check so a stale initCodes.m cannot silently start a session.
p.init.strobeList(end+1:end+11, :) = { ...
    'movingT1Angle_x10',        'p.trVars.movingT1Angle_x10'; ...
    'movingT2Angle_x10',        'p.trVars.movingT2Angle_x10'; ...
    'movingSeparation_x10',     'p.trVars.movingSeparation_x10'; ...
    'movingEccentricity_x100',  'p.trVars.movingEccentricity_x100'; ...
    'T1PhysicalSide',           'p.trVars.T1PhysicalSide'; ...
    'T2PhysicalSide',           'p.trVars.T2PhysicalSide'; ...
    'chosenPhysicalSide',       'p.trData.chosenPhysicalSide'; ...
    'movingTargetsStraddleLR',  'p.trVars.movingTargetsStraddleLR'; ...
    'movingTargetsStraddleUD',  'p.trVars.movingTargetsStraddleUD'; ...
    'chosenHorizontalRank',     'p.trData.chosenHorizontalRank'; ...
    'chosenVerticalRank',       'p.trData.chosenVerticalRank'};

% Legacy spatial strobes retain their literal spatial meaning. In this
% moving task T1Side/T2Side from the block schedule are only balancing slots,
% so the ephys spatial strobes are redirected to the actual screen geometry.
p.init.strobeList = setStrobeExpression(p.init.strobeList, ...
    'T1Side', 'p.trVars.T1PhysicalSide');
p.init.strobeList = setStrobeExpression(p.init.strobeList, ...
    'T2Side', 'p.trVars.T2PhysicalSide');
p.init.strobeList = setStrobeExpression(p.init.strobeList, ...
    'highRewardLocation', 'p.status.highRewardPhysicalSide');
p.init.strobeList = setStrobeExpression(p.init.strobeList, ...
    'highSalienceLocation', 'p.status.highSaliencePhysicalSide');
p.init.strobeList = setStrobeExpression(p.init.strobeList, ...
    'chosenTarget', 'p.trData.chosenPhysicalSide');

p.trVarsGuiComm = p.trVarsInit;

end

function strobeList = setStrobeExpression(strobeList, codeName, expression)
row = find(strcmp(strobeList(:,1), codeName));
if numel(row) ~= 1
    error('SRS_mooving:StrobeListMismatch', ...
        'Expected exactly one strobeList row named %s.', codeName);
end
strobeList{row,2} = expression;
end
