function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.

% Choose a row of "p.init.trialsArray" for the upcoming trial.
% p = chooseRow(p);

% Trial type information:
% is this a release on fix off trial or a release after reward trial?
p = trialTypeInfo(p);

% Cue / foil locations in cartesian coordinates and rectangle outlining the
% cue-ring.
p = locationInfo(p);

% Timing info:
% - cue / foil change times, reward timing, dot duration
p = timingInfo(p);

end

%%
function p = chooseRow(p)

% If p.status.trialsArrayRowsPossible is empty, we're at the beginning of
% the experiment and we need to define it. This also means we're starting
% block 1 and we should set "p.status.blockNumber" accordingly.
if isempty(p.status.trialsArrayRowsPossible)
    p.status.trialsArrayRowsPossible =  true(p.init.blockLength, 1);
    p.status.blockNumber = 1;
end

% choose a row of "p.init.trialsArray"
g = p.status.trialsArrayRowsPossible;

    
% % 1st: cue side 1, single patch trials
% if any(p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) == 1 & ...
%         p.status.trialsArrayRowsPossible)
%     g = p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) == 1 & ...
%         p.status.trialsArrayRowsPossible;
%     
%     % 2nd: cue side 1, two patch trials
% elseif any(p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) > 1 & ...
%         p.status.trialsArrayRowsPossible)
%     g = p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) > 1 & ...
%         p.status.trialsArrayRowsPossible;
%     
%     % 3rd: cue side 2, single patch trials
% elseif any(p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) == 1 & ...
%         p.status.trialsArrayRowsPossible)
%     g = p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) == 1 & ...
%         p.status.trialsArrayRowsPossible;
%     
%     
%     % 4th: cue side 2, two patch trials
% elseif any(p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) > 1 & ...
%         p.status.trialsArrayRowsPossible)
%     g = p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) > 1 & ...
%         p.status.trialsArrayRowsPossible;
% end

% choose 1st available row after shuffling list of available rows.
tempList = shuff(find(g));
p.trVars.currentTrialsArrayRow = tempList(1);

end

%%
function p = trialTypeInfo(p)

% Will this be a release on fixation dim trial or a release after reward
% trial?
p.trVars.isChangeTrial = rand < p.trVars.propChangeTrials;

% If this is a change trial, we choose among "lowDimVal", "midDimVal", and
% "highDimVal" with equal probability. If this is isn't a change trial, we
% set "p.trData.dimVal" to 0.
if p.trVars.isChangeTrial
    tempRand = rand;
    if tempRand < 1/3
        p.trData.dimVal = p.trVars.lowDimVal;
    elseif tempRand < 2/3
        p.trData.dimVal = p.trVars.midDimVal;
    else
        p.trData.dimVal = p.trVars.highDimVal;
    end
else p.trData.dimVal = 0;
end

% Based on the "dimVal", we generate a new RGB triplet for the appearance
% of the fixation after dimming. The first step is to retrieve the
% background RGB value from the CLUT, then we take the difference between
% the default / initial fixation RGB and the background RGB, multiply it by
% the "dimVal", then add it back to the background RGB. Once we've
% generated that value, we need to update the CLUT on the VIEWPixx.
bgRGB = p.draw.clut.combinedClut(p.draw.clutIdx.expBg_subBg + 1, :);
fxRGB = p.draw.clut.combinedClut(p.draw.clutIdx.expWhite_subWhite + 1, :);
fxDimRGB = bgRGB + p.trData.dimVal*(fxRGB-bgRGB);
myClut = p.draw.clut.combinedClut;
myClut(p.draw.clutIdx.expFixDim_subFixDim + 1, :) = fxDimRGB;
Datapixx('SetVideoClut', myClut);
p.draw.clut.combinedClut = myClut;

% if we're using QUEST run "getQuestSuggestedDelta" - this both gets a
% suggested signal strength AND initializes the QUEST object if it doesn't
% yet exist (though it only stores the suggested signal strength if this is
% a cue change trial).
if isfield(p.trVars, 'useQuest') && p.trVars.useQuest
    p = getQuestSuggestedDelta(p);
end
    
end

%%
function p = locationInfo(p)

% randomize fixation point location
tempX = p.trVars.fixDegX + (rand - 0.5)*p.trVars.fixLocRandX;
tempY = p.trVars.fixDegY + (rand - 0.5)*p.trVars.fixLocRandY;

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([tempX, tempY], p);

% define fixation point radius from trVars, fixation point line weight
% from trVars, and fixation point rectangle.
p.draw.fixPointRadius = p.trVars.fixPointRadPix;
p.draw.fixPointWidth = p.trVars.fixPointLinePix;
p.draw.fixPointRect = repmat(p.draw.fixPointPix, 1, 2) + ...
    p.draw.fixPointRadius*[-1 -1 1 1];

% store fix point after adding random bit
p.trVars.fixDegX = tempX;
p.trVars.fixDegY = tempY;

end

%%
function p = timingInfo(p)

% choose how long the joystick hold duration required for the upcoming
% trial will be:
p.trVars.fixDurReq = p.trVars.fixDurReqMin + ...
    (p.trVars.fixDurReqMax - p.trVars.fixDurReqMin)*rand;

% log joyPressReq as a status variable:
p.status.fixDurReq = p.trVars.fixDurReq;
    
end

%%

function y = shuff(x)
    y = x(randperm(length(x)));
end
