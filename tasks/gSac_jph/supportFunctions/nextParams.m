function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.


% Trial type information:
% vis- or mem-guided saccade
p = trialTypeInfo(p);

% if we're using p.init.trialsArray to determine target locations, do the
% book keeping for that here:
if p.trVars.setTargLocViaTrialArray
    p = chooseRow(p);
end

% set fixation and target locations for next trial:
p = setLocations(p);

% Timing info:
% target onset/offset time
p = timingInfo(p);

end

%
function p = trialTypeInfo(p)

if rand() + double(p.trVars.setTargLocViaTrialArray) <= p.trVars.propVis
    p.trVars.isVisSac = 1;
else
    p.trVars.isVisSac = 0;
end

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
        p.trVars.targDegY = -p.trVars.targDegY; % flip y because PTB y is flipped..
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

if p.trVars.setTargLocViaTrialArray
    
    % use the current row of the trialsArray to select the target elevation
    
    % saccade target elevation in degrees
    p.trVars.targElevDeg    = p.init.trialsArray(p.trVars.currentTrialsArrayRow, 3);

    % saccade target location in cartesian coordinates
    p.trVars.targDegX       = p.trVarsInit.staticTargAmp * cosd(p.trVars.targElevDeg);
    p.trVars.targDegY       = p.trVarsInit.staticTargAmp * sind(p.trVars.targElevDeg);
    
end

% if neither mouse nor gui are used, default to the random method.
if ~any([p.trVars.setTargLocViaMouse, p.trVars.setTargLocViaGui, ...
        p.trVars.setTargLocViaTrialArray])
    
    % random-base location: targList has a random order of target locations. Choose a
    % location from the list and increase the iterator:
    p.trVars.targDegX           = p.stim.targetLocationListX(p.status.iTarget);
    p.trVars.targDegY           = p.stim.targetLocationListY(p.status.iTarget);

    % increment iterator:
    p.status.iTarget            = mod(p.status.iTarget, p.stim.nTargetLocations) + 1;
    
end

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
% p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);
% p.draw.targPix          =  p.draw.middleXY + [1, -1] .* pds.deg2pix([p.trVars.targDegX ,p.trVars.targDegY], p);

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);
p.draw.targPointPix     =  p.draw.middleXY + [1, -1] .* pds.deg2pix([p.trVars.targDegX, p.trVars.targDegY], p);

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
p.trVars.timeTargOnset          = unifrnd(p.trVars.targOnsetMin, ...
    p.trVars.targOnsetMax);

% time of target offset wrt fixAcq:
if p.trVars.isVisSac
    % infinity for vis"
    p.trVars.timeTargOffset     = Inf;
else
    % flash for mem:
    p.trVars.timeTargOffset     = p.trVars.timeTargOnset + ...
        p.trVars.targetFlashDuration;
end

% time of fix offset wrt fix acquired:
p.trVars.timeFixOffset          = p.trVars.timeTargOnset + unifrnd(p.trVars.goTimePostTargMin, p.trVars.goTimePostTargMax);

%         p.trVars.postFlashFixDur       = unifrnd(p.trVars.postFlashFixMin, p.trVars.postFlashFixMax);
p.trVars.targHoldDuration         = unifrnd(p.trVars.targHoldDurationMin, p.trVars.targHoldDurationMax);


end

function p = chooseRow(p)

% if this is the "two_locs" version of this task (in "all_locs" we use 6
% locations, lok at the PSTHs, then choose which 2 are best, and run the
% "two_locs" version), get rid of rows other than those selected in the
% gui.
if strcmp(p.init.exptType, 'two_locs')
    
    % which rows of the trialsArray do NOT contain trial information for
    % the two stimulus location IDs in the gui?
    ridRows = ~ismember(...
        p.init.trialsArray(:,1), ...
        [p.trVars.stimLocId1, p.trVars.stimLocId2]);
    
    % get rid of those rows.
    p.init.trialsArray(ridRows, :) = [];
    
    % redefine p.init.blockLength
    p.init.blockLength = size(p.init.trialArray, 1);
    
    % redefine "finish"
    p.trVars.finish = p.init.blockLength;
end

% if p.status.trialsArrayRowsPossible is empty, we're at the beginning of
% the experiment and we need to define it.
if ~isfield(p.status, 'trialsArrayRowsPossible') || ...
        isempty(p.status.trialsArrayRowsPossible)
    p.status.trialsArrayRowsPossible =  true(p.init.blockLength, 1);
end

% otherwise, choose an available row with no constraints: all stimulus
% locations are intermixed.
g = p.status.trialsArrayRowsPossible;

% shuffle the list of possible rows of trialsArray
tempList = shuff(find(g));

% choose the first row number in the shuffled list.
p.trVars.currentTrialsArrayRow = tempList(1);

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