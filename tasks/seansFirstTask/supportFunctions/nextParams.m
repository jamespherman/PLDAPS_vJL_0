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

if rand <= p.trVars.propVis
    p.trVars.isVisSac = 1;
else
    p.trVars.isVisSac = 0;
end

end

%
% function p = setTargetLocation(p)
function p = setLocations(p)

% Define target location for next trial. First define which column of the
% trials array contains the "numDots" information, then choose a target
% location.
numDotsCol = strcmp(p.init.trialArrayColumnNames, 'numDots');
p.trVars.numDots   = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    numDotsCol);

% Where will the target be displayed? We want the 1-dot target to always
% appear above the fixation and the 2-dot target to always appear below the
% fixation. We use a little trick to make this happen:
p.trVars.targDegX   = 0;
p.trVars.targDegY   = p.trVars.targDegY * (-1)^((p.trVars.numDots == 1)+1);

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

% what is the separation between the two dots (when there are two dots
% shown) in pixels?
p.draw.twoDotSepPix = pds.deg2pix(p.trVars.twoDotSepDeg, p);

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