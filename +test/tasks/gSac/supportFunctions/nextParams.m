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

%
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
    % if targets have been inputted by user, take the.
    %       go through this list of targets.
    % else
    %       default to the random method
    %       p.trVars.setTargLocViaMouse = false;
    % end
end

if p.trVars.setTargLocViaTrialArray
    
    % which columns of "trialsArray" contain "stimX", "stimY", and
    % "isVisSac"?
    xCol    = strcmp(p.init.trialArrayColumnNames, 'stimX');
    yCol    = strcmp(p.init.trialArrayColumnNames, 'stimY');
    vsCol   = strcmp(p.init.trialArrayColumnNames, 'isVisSac');
    
    % use the current row of the trialsArray to select the target location
    % and to determine if the trial will be vissac or memsac
    p.trVars.targDegX   = p.init.trialsArray(p.trVars.currentTrialsArrayRow, xCol);
    p.trVars.targDegY   = p.init.trialsArray(p.trVars.currentTrialsArrayRow, yCol);
    p.trVars.isVisSac   = p.init.trialsArray(p.trVars.currentTrialsArrayRow, vsCol);
    
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
p.trVars.timeTargOnset          = unifrnd(p.trVars.targOnsetMin, p.trVars.targOnsetMax);

% time of target offset wrt fixAcq:
if p.trVars.isVisSac
    % infinity for vis"
    p.trVars.timeTargOffset     = Inf;
else
    % flash for mem:
    p.trVars.timeTargOffset     = p.trVars.timeTargOnset + p.trVars.targetFlashDuration;
end

% time of fix offset wrt fix acquired:
p.trVars.timeFixOffset          = p.trVars.timeTargOnset + unifrnd(p.trVars.goTimePostTargMin, p.trVars.goTimePostTargMax);

%         p.trVars.postFlashFixDur       = unifrnd(p.trVars.postFlashFixMin, p.trVars.postFlashFixMax);
p.trVars.targHoldDuration         = unifrnd(p.trVars.targHoldDurationMin, p.trVars.targHoldDurationMax);


end

function p = chooseRow(p)

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