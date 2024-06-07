function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.

% if we're using p.init.trialsArray to determine target locations, do the
% book keeping for that here:
if p.trVars.setTargLocViaTrialArray
    p = chooseRow(p);
end

% Trial type information:
% vis- or mem-guided saccade
p = trialTypeInfo(p);

% set fixation and target locations for next trial:
p = setLocations(p);

% Timing info:
% target onset/offset time
p = timingInfo(p);

end

function p = redefClut(p)

% what color do we want to make "invisible" to the monkey.
bgRGB = p.draw.clut.combinedClut(p.draw.color.background+1, :);

% redefine CLUT using current background color:

mutGreen = [0.5 0.9 0.4];
redISH = [225 0 76]/255;
orangeISH = [255 146 0]/255;
blueISH = [11 97 164]/255;
greenISH = [112 229 0]/255;
oldGreen = [0.45, 0.63, 0.45];
visGreen = [0.1 0.9 0.1];
memMagenta = [1 0 1];
% colors for exp's display
% black 0
% grey-1 (grid-lines) 1
% grey-2 (background) 2
% grey-3 (fix-window) 3
% white (fix-point) 4
% red 5
% orange 6
% blue 7
% cue ring 8
% muted green (fixation) 9
p.draw.clut.expColors = ...
    [ 0, 0, 0; % 0
    0.25, 0.25, 0.25; % 1
    bgRGB; % 2
    0.7, 0.7, 0.7; % 3
    1, 1, 1; % 4
    redISH; % 5
    orangeISH; % 6
    blueISH; % 7
    0, 1, 1; % 8
    0.9,0.9,0.9; % 9
    mutGreen; % 10
    greenISH; % 11
    0, 0, 0; % 12
    oldGreen; % 13
    visGreen; % 14
    memMagenta; % 15
    0, 1, 1; % 16
    p.draw.clut.combinedClut(18:25,:)]; % 17-24

% colors for subject's display
% black 0
% grey-2 (grid-lines) 2
% grey-2 (background) 2
% grey-2 (fix-window) 3
% white (fix-point) 4
% grey-2 (red) 2
% grey-2 (green) 2
% grey-2 (blue) 2
% cuering 8
% muted green (fixation) 9
p.draw.clut.subColors = ...
    [0, 0, 0; % 0
    bgRGB; % 1
    bgRGB; % 2
    bgRGB; % 3
    1, 1, 1; % 4
    bgRGB; % 5
    bgRGB; % 6
    bgRGB; % 7
    0, 1, 1; % 8
    bgRGB; % 9
    mutGreen; % 10
    bgRGB; % 11
    bgRGB; % 12
    oldGreen; % 13
    bgRGB; % 14
    bgRGB; % 15
    bgRGB; % 16
    p.draw.clut.combinedClut(18:25,:)]; % 17-24

% fill the remaining LUT slots with background RGB.
nColors         = size(p.draw.clut.subColors,1);
nTotalColors    = 256;
p.draw.clut.expColors(nColors+1:nTotalColors, :) = ...
    repmat(bgRGB, nTotalColors-nColors, 1);
p.draw.clut.subColors(nColors+1:nTotalColors, :) = ...
    repmat(bgRGB, nTotalColors-nColors, 1);

% populate the rest with 0's
p.draw.clut.ffc      = nColors + 1;
p.draw.clut.expCLUT  = p.draw.clut.expColors;
p.draw.clut.subCLUT  = p.draw.clut.subColors;

% Push (possibly new) color look-up table to ViewPIXX based on
% current frame (frame determined based on time in trial).
% Screen('LoadNormalizedGammaTable', p.draw.window, ...
%     [p.draw.clut.subCLUT; p.draw.clut.expCLUT], 2);

Datapixx('SetVideoClut', [p.draw.clut.subCLUT; p.draw.clut.expCLUT]);

end

%
function p = trialTypeInfo(p)

% decide whether this will be a visually or memory guided saccade:
if rand() <= p.trVars.propVis
    p.trVars.isVisSac = 1;
else
    p.trVars.isVisSac = 0;
end

% assuming we're using the trials array, determine which stimulus
% configuration (target and background color) we're using in this trial:
if p.trVars.setTargLocViaTrialArray
    p.trVars.stimConfigIdx = p.init.trialsArray(...
        p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'tgtBkgndCond'));
else
    p.trVars.stimConfigIdx = randi(8);
end

% define colors of backround and target for upcoming trial:
switch p.trVars.stimConfigIdx
    case 1 % "high" saliency
        c1 = p.draw.clutIdx.dkl_0;
        c2 = p.draw.clutIdx.dkl_180;

    case 2 % "high" saliency
        c1 = p.draw.clutIdx.dkl_180;
        c2 = p.draw.clutIdx.dkl_0;

    case 3 % "high" saliency
        c1 = p.draw.clutIdx.dkl_90;
        c2 = p.draw.clutIdx.dkl_270;

    case 4 % "high" saliency
        c1 = p.draw.clutIdx.dkl_270;
        c2 = p.draw.clutIdx.dkl_90;

    case 5 % "low" saliency
        c1 = p.draw.clutIdx.dkl_0;
        c2 = p.draw.clutIdx.dkl_45;

    case 6 % "low" saliency
        c1 = p.draw.clutIdx.dkl_90;
        c2 = p.draw.clutIdx.dkl_135;

    case 7 % "low" saliency
        c1 = p.draw.clutIdx.dkl_180;
        c2 = p.draw.clutIdx.dkl_225;

    case 8 % "low" saliency
        c1 = p.draw.clutIdx.dkl_270;
        c2 = p.draw.clutIdx.dkl_315;
end

p.draw.color.targ       = c1;
p.draw.color.background = c2;
p.draw.color.fix          = p.draw.color.background;
p.draw.color.fixWin       = p.draw.color.background;

% redefine CLUT and upload to VIEWPixx:
p = redefClut(p);

end


% function p = setTargetLocation(p)
function p = setLocations(p)
% set fixation and target locations for next trial.
% Location can be set via a number of methods: mouse, gui, or random.
%
% * If mouse, a target will appear at the current location of the mouse
%   cursor at trial start.
% * If GUI, multiple targets can be set ahead of time, and will be
%   presented one by one.
% * If neither, target will be presented at random (without replacement)
%   from the targetLocationList (set in init).

% if set by mouse: First, get mouse location. Then, check that mouse is
% located within confounds of screen, otherwise, set mouse method to false:
if p.trVars.setTargLocViaMouse
    
    [mX, mY]                = GetMouse(0);
    
    p.draw.screenRect
    
    if mX >= p.draw.screenRect(1) && mX <= p.draw.screenRect(3) && ...
            mY >= p.draw.screenRect(2) && mY <= p.draw.screenRect(4)
        temp = pds.pix2deg([mX, mY] - p.draw.middleXY, p);
        p.trVars.targDegX = temp(1);
        p.trVars.targDegY = temp(2);
        p.trVars.targDegY = -p.trVars.targDegY; % flip y, PTB y is flipped.
    else
        
        p.trVars.setTargLocViaMouse = false;
    end
end

if p.trVars.setTargLocViaGui
    
    % if the gui button indicating a specified target location should be
    % used next, grab that position.
    if get(p.rig.guiData.handles.hSpecTgtButton, 'Value')
        p.trVars.targDegX = ...
            str2double(get(p.rig.guiData.handles.hXVal, 'String'));
        p.trVars.targDegY = ...
            str2double(get(p.rig.guiData.handles.hYVal, 'String'));

        % in this version of the task, when "specified" is selected, we
        % want to (at random) choose either the "specified" location or
        % its mirror image:
        if rand < 0.5
            p.trVars.targDegX = -p.trVars.targDegX;
            p.trVars.targDegY = -p.trVars.targDegY;
        end
    else
        % Logically index which rows of "sacDataArray" contain target
        % locations that have not been visited (or have been marked as
        % unvisited by the experimenter).
        availRows = ~p.rig.guiData.sacDataArray(:, end);
        
        % if there are any unvisited locations, choose one at random to use
        % in the next rtrial.
        if any(availRows)
            Xtemp = p.rig.guiData.sacDataArray(availRows, 1);
            Ytemp = p.rig.guiData.sacDataArray(availRows, 2);
            p.trVars.targDegX = Xtemp(1);
            p.trVars.targDegY = Ytemp(1);
        else %if ~p.trData.trialRepeatFlag
        % specify a target location by randomizing target elevation and
        % choosing radius to keep the target in a square annulus.
        targetTheta     = 360*rand;
        targetRadius    = getRadius(targetTheta, ...
            p.trVars.minTargAmp, ...
            p.trVars.maxHorzTargAmp, ...
            p.trVars.maxVertTargAmp);
        
        % convert target elevation and radius (polar) to X & Y components
        % (cartesian).
        p.trVars.targDegX = targetRadius * cosd(targetTheta);
        p.trVars.targDegY = targetRadius * sind(targetTheta);
        end
    end
        
end

% if we are setting the larget location using the trials array, we pull the
% desired target location from the "fixed" field(s) in the saccade mapping
% gui. If the user hasn't selected "fixed" we instead use the default
% target location specified in the settings file:
if p.trVars.setTargLocViaTrialArray

    % if "fixed" is selected, use the target location defined there:
    if isfield(p.rig, 'guiData') && ...
            get(p.rig.guiData.handles.hSpecTgtButton, 'Value')
        p.trVars.targDegX = ...
            str2double(get(p.rig.guiData.handles.hXVal, 'String'));
        p.trVars.targDegY = ...
            str2double(get(p.rig.guiData.handles.hYVal, 'String'));
    else
    end

    % depending on whether the current trials array row indicates target
    % location 1 or location 2, either leave the target location alone or
    % negate it:
    if p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
            strcmp(p.init.trialArrayColumnNames, 'targetLocIdx')) == 2
        p.trVars.targDegX = -p.trVars.targDegX;
        p.trVars.targDegY = -p.trVars.targDegY;
    end
    
end

% if neither mouse nor gui are used, default to the random method.
if ~any([p.trVars.setTargLocViaMouse, p.trVars.setTargLocViaGui, ...
        p.trVars.setTargLocViaTrialArray])
    
    % random-base location: targList has a random order of target 
    % locations. Choose alocation from the list and increase the iterator:
    p.trVars.targDegX           = ...
        p.stim.targetLocationListX(p.status.iTarget);
    p.trVars.targDegY           = ....
        p.stim.targetLocationListY(p.status.iTarget);

    % increment iterator:
    p.status.iTarget            = mod(p.status.iTarget, ...
        p.stim.nTargetLocations) + 1;
    
end

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);
p.draw.targPointPix     =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targDegX, p.trVars.targDegY], p);

% fixation window width and height in pixels.
p.draw.fixWinWidthPix       = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix      = pds.deg2pix(p.trVars.fixWinHeightDeg, p);

% target window width and height in pixels.
p.draw.targWinWidthPix      = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix     = pds.deg2pix(p.trVars.targWinHeightDeg, p);

% Convert target X & Y into radius and theta so that we can strobe:
% (can't strobe negative values, so r/th solves that)
[tmpTheta, tmpRadius]   = cart2pol(p.trVars.targDegX, p.trVars.targDegY);
% In order to strobe I need round positive numbers. 
% For theta, I multiply by 10 ('_x10') and round. That gives 1 decimlal 
% point precision, good enough!
p.trVars.targTheta_x10  = round(mod(tmpTheta * 180 / pi, 360) * 10); 
% For radius, I multiply by 100 ('_x100') and round. That gives 2 decimlal
% point precision, goo enough!
p.trVars.targRadius_x100 = round(tmpRadius * 100);

end

%
function p = timingInfo(p)

% time of target onset wrt fixAcq:
p.trVars.timeTargOnset       = unifrnd(p.trVars.targOnsetMin, ...
    p.trVars.targOnsetMax);

% time of target offset wrt fixAcq:
if p.trVars.isVisSac
    % infinity for vis"
    p.trVars.timeTargOffset = Inf;
else
    % flash for mem:
    p.trVars.timeTargOffset = p.trVars.timeTargOnset + ...
        p.trVars.targetFlashDuration;
end

% time of fix offset wrt fix acquired:
p.trVars.timeFixOffset      = p.trVars.timeTargOnset + ...
    unifrnd(p.trVars.goTimePostTargMin, p.trVars.goTimePostTargMax);

% target fixation duration required
p.trVars.targHoldDuration =  unifrnd(p.trVars.targHoldDurationMin, ...
    p.trVars.targHoldDurationMax);

% reward duration depends on whether this is a "high" or "low" reward
% trial. We add or subtract "rewardDurDelta" from "rewardDurationMs" for
% "high" and "low" reward trials, respectively.
if p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'highLowRwd')) == 1
    p.trVars.rewardDurationMs = p.trVarsInit.rewardDurationMs + ...
        p.trVarsInit.rewardDurDelta;
else
    p.trVars.rewardDurationMs = p.trVarsInit.rewardDurationMs - ...
        p.trVarsInit.rewardDurDelta;
end

end

function p = chooseRow(p)

% if p.status.trialsArrayRowsPossible is empty, we're at the beginning of
% the experiment and we need to define it. Here we also define whether
% target location 1 will be high reward first or target location 2 will be
% high reward first.
if ~isfield(p.status, 'trialsArrayRowsPossible') || ...
        isempty(p.status.trialsArrayRowsPossible)
    p.status.trialsArrayRowsPossible =  true(p.init.blockLength, 1);
    
    % flip a coin to decide whether target location 1 or target location 2
    % will be "high reward" first:
    p.status.tLoc1HighRwdFirst = rand < 0;
end

% Depending on which target location is "high reward" first, and which
% trials have been completed, define which rows of the trials array are
% available. To do this easily and legibly we first define variables that
% tell us which rows of the trials array are for target location 1 /2 and
% high reward / low reward:
tLoc = p.init.trialsArray(:, ...
    strcmp(p.init.trialArrayColumnNames, 'targetLocIdx'));
rwdSize = p.init.trialsArray(:, ...
    strcmp(p.init.trialArrayColumnNames, 'highLowRwd'));
if p.status.tLoc1HighRwdFirst

    % if target location 1 is high reward first, and there are any of those
    % trials left to run in this block, define those trials as available to
    % select from. Otherwise, select from any rows of the trials array that
    % haven't been run yet ("are still possible") since these must be the
    % trials where target location 1 is not high reward.
    g = ((tLoc == 1 & rwdSize == 1) | (tLoc == 2 & rwdSize == 2)) & ...
        p.status.trialsArrayRowsPossible;
    if ~any(g)
        g = p.status.trialsArrayRowsPossible;
    end
else
    % if target location 2 is high reward first, and there are any of those
    % trials left to run in this block, define those trials as available to
    % select from. Otherwise, select from any rows of the trials array that
    % haven't been run yet ("are still possible") since these must be the
    % trials where target location 1 is not high reward.
    g = ((tLoc == 1 & rwdSize == 2) | (tLoc == 2 & rwdSize == 1)) & ...
        p.status.trialsArrayRowsPossible;
    if ~any(g)
        g = p.status.trialsArrayRowsPossible;
    end
end

% shuffle the list of possible rows of trialsArray
tempList = shuff(find(g));

% choose the first row number in the shuffled list.
p.trVars.currentTrialsArrayRow = tempList(1);

% store "rwdSize" for use elsewhere:
p.trVars.rwdSize = rwdSize(p.trVars.currentTrialsArrayRow);

end

%
function y = shuff(x)
    y = x(randperm(length(x)));
end

function r = getRadius(theta, a, bX, bY)

% Choose radius to lie in a rectangular annulus with inner "radius" = a and
% outer radius = b, depending on angle. First step is calculating a
% "special case" angle because the annulus is rectangular.
spAng = atand(bY/bX);

% There are several cases for ranges of theta; I suspect there's a way to
% do this more cleanly / simply. Let's see what LNK has to say tomorrow!
if (theta > (360 - spAng) || theta <= spAng) || ...
        (theta > (180 - spAng) && theta <= (180 + spAng))
    r = abs((a./cosd(theta)) + ...
        rand*((bX./cosd(theta)) - (a./cosd(theta))));
elseif (theta > spAng && theta <= 45)
    r = abs((a./cosd(theta)) + ...
        rand*((bY./sind(theta)) - (a./cosd(theta))));
elseif (theta > 135 && theta <= (180 - spAng))
    r = abs(-(a./cosd(theta)) + ...
        rand*((bY./sind(theta)) + (a./cosd(theta))));
elseif (theta > (180 + spAng) && theta <= 225)
    r = abs(-(a./cosd(theta)) + ...
        rand*(-(bY./sind(theta)) + (a./cosd(theta))));
elseif (theta > 315 && theta <= (270 + spAng))
    r = abs((a./cosd(theta)) + ...
        rand*(-(bY./sind(theta)) - (a./cosd(theta))));
else
    r = abs((a./sind(theta)) + ...
        rand*((bY./sind(theta)) - (a./sind(theta))));
end

end