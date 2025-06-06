function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.

% Choose a row of "p.init.trialsArray" for the upcoming trial.
p = chooseRow(p);

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

% keyboard

% June 19th, 2019
% retreive random seed values ("trialSeed" and "stimSeed" from trials
% array.
p.trVars.stimSeed = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'stim seed'));
p.trVars.trialSeed = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'trial seed'));

% use trialSeed to determine following pseudorandom number sequence
rng(p.trVars.trialSeed);

% On a certain proportion of trials, we want the peripheral stimulus to
% change in some feature without dimming. We use a random number draw to
% decide which trials this should happen on. First let's check to make sure
% the variable that governs this behavior is actually here, then do the
% random draw:
if isfield(p.trVars, 'propHueChgOnly')
    featureChangeOnly = rand < p.propHueChgOnly;
else
    featureChangeOnly = false;
end

% how many stimuli will be shown on this trial?
p.stim.nStim = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'n stim'));

% randomize gabor orientation
p.trVars.orientInit = randi(360);

% Define stimulus arrays for all features EXCEPT hue which has to be
% handled slightly differently.
arrayEvalString = ...
    'p.stim.FEATUREArray = p.trVars.FEATUREInit * ones(p.trVars.nPatches, p.trVars.nEpochs);';
varArrayEvalString = ...
    'p.stim.FEATUREVarArray = p.trVars.FEATUREVar * ones(p.trVars.nPatches, p.trVars.nEpochs);';
patternString = 'FEATURE';
varArrayFeatures = {'orient', 'hue', 'lum', 'sat'};

% loop over features and use "regexprep.m" to modify "arrayEvalString" and
% / or "varArrayEvalString" as needed for each feature.
for i = 1:p.stim.nFeatures
    
    % don't evaluate the arrayEvalString if the currently considered
    % feature is "hue"
    if ~strcmp(p.stim.featureValueNames{i}, 'hue')
        eval(regexprep(arrayEvalString, patternString, ...
            p.stim.featureValueNames{i}));
    end
    
    % evaluate the varArrayEvalString if the currently considered feature
    % is "orientation", "hue", "luminance", or "saturation"
    if any(strcmp(varArrayFeatures, p.stim.featureValueNames{i}))
        eval(regexprep(varArrayEvalString, patternString, ...
            p.stim.featureValueNames{i}));
    end
end

% Determine which stimulus is "primary"
p.stim.primStim     = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'primary'));

% Redefine Hue array so that each patch has a unique hue:
p.stim.hueArray = repmat(...
    circshift(p.trVars.hueInit + [0; 90; 180; 270], ...
    p.stim.primStim - 1), 1, p.trVars.nEpochs);

% Redefine orientation array so that each patch has a unique orientation:
p.stim.orientArray = repmat(...
    circshift(p.trVars.orientInit + [0; 45; 90; 135], ...
    p.stim.primStim - 1), 1, p.trVars.nEpochs);

% which stimulus location is the "cued" location?
p.stim.cueLoc  = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'cue loc'));

% depending on the info present in the current row of the trials array
% ("p.init.trialsArray"), define the "stimulus feature value arrays."
% These have one entry for each stimulus patch (one row per patch) and
% each "epoch" (one column per epoch).

% First, which stimulus is changing on the current trial?
stimChgIdx = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'stim chg'));

try
% loop over stimulus features
for i = 1:p.stim.nFeatures
    
    % does the presently considered feature change on this trial?
    tempDelta = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
        ~cellfun(@isempty, strfind(p.init.trialArrayColumnNames, ...
        p.stim.featureValueNames{i})));

    % if this is a trial in which we want to force only the stimulus
    % feature to change with no dimming, adjust the "tempDelta" for
    % luminance here:
    if featureChangeOnly && strcmp(p.stim.featureValueNames{i}, 'lum')
        tempDelta = 0;
    end
    
    % if "tempDelta" is non-zero, add the corresponding feature delta
    % to the appropriate entry of the feature array
    if tempDelta ~= 0
        % find the right delta, and multiply by "tempDelta" to allow
        % for "increases" and "decreases" of various features.
        featureDelta = tempDelta * ...
            p.trVars.([p.stim.featureValueNames{i} 'Delta']);
        
        % add to stim array
        p.stim.([p.stim.featureValueNames{i} ...
            'Array'])(stimChgIdx, 2) = ...
            p.stim.([p.stim.featureValueNames{i} ...
            'Array'])(stimChgIdx, 2) + featureDelta;
    end
end
catch me
    
    keyboard
end

% which stimuli are shown in the current trial?
for i = 1:p.trVars.nPatches
p.trVars.(['stim' num2str(i) 'On']) = logical(...
    p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, ['stim' num2str(i) ' on'])));
end

% make a numerical list of the stimulus locations that are on in this
% trial:
p.trVars.stimOnList = find(...
    [p.trVars.stim1On, p.trVars.stim2On, ...
    p.trVars.stim3On, p.trVars.stim4On, ...
    ]);

% set a couple simple variable that will be helpful during "run"
p.trVars.isCueChangeTrial    = stimChgIdx == p.stim.cueLoc;
p.trVars.isFoilChangeTrial   = stimChgIdx ~= p.stim.cueLoc && ...
    stimChgIdx ~= 0;
p.trVars.isNoChangeTrial     = stimChgIdx == 0;

% Will this be a release on fixation dim trial or a release after reward
% trial?
p.trVars.isChangeTrial = ~p.trVars.isNoChangeTrial;

% If this is a change trial, we choose among "lowDimVal", "midDimVal", and
% "highDimVal" with equal probability. We also need to choose whether the
% peripheral stimulus AND the fixation will dim or only the peripheral
% stimulus. If this is isn't a change trial, we set "p.trData.dimVal" to 0.
if p.trVars.isChangeTrial
    
    % draw random number to decide which dimVal is selected:
    tempRand = rand;
    if tempRand < 1/3
        p.trData.dimVal = p.trVars.lowDimVal;
    elseif tempRand < 2/3
        p.trData.dimVal = p.trVars.midDimVal;
    else
        p.trData.dimVal = p.trVars.highDimVal;
    end

    % draw random number to decide whether peripheral stimulus and fixation
    % will both dim or if peripheral stimulus only will dim:
    tempRand = rand;
    p.trVars.isStimDimOnlyTrial = ...
        tempRand < p.trVars.propPeriphDimOnly;

else
    p.trData.dimVal = 0;
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
p.draw.clut.expColors(p.draw.clutIdx.expFixDim_subFixDim + 1, :) = ...
    fxDimRGB;
p.draw.clut.subColors(p.draw.clutIdx.expFixDim_subFixDim + 1, :) = ...
    fxDimRGB;
myClut = p.draw.clut.combinedClut;
myClut([p.draw.clutIdx.expFixDim_subFixDim + 1; ...
    256 + p.draw.clutIdx.expFixDim_subFixDim + 1], :) = ...
    repmat(fxDimRGB, 2, 1);
Datapixx('SetVideoClut', myClut);
p.draw.clut.combinedClut = myClut;

% define a variable indicating if this is a contrast change trial
p.trVars.isContrastChangeTrial = ...
    p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'contrast')) == 1;

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

% based on stimulus radius and size of boxes / "checks" in pixels,
% calculate patch diameter in pixels (rounded to the nearest box) and the
% patch diameter in boxes / checks.
p.stim.patchDiamPix = round(p.trVars.stimRadius * 2 * pds.deg2pix(1, p) ...
    / p.trVars.boxSizePix) * p.trVars.boxSizePix;
p.stim.patchDiamBox = floor(p.stim.patchDiamPix / p.trVars.boxSizePix);

% Define stimulus elevations and eccentricities. Assume we have 4 stimulus
% locations:
p.trVars.stimElevs = p.trVars.stimLoc1Elev + [0 90 180 270];
p.trVars.stimEccs  = p.trVars.stimLoc1Ecc * [1 1 1 1];

% If we have non-zero values of "stimLoc#Elev" or "stimLoc#Ecc", redefine
% the elevation / eccentricity of the stimuli accordingly:
tweakElevs = [0 p.trVars.stimLoc2Elev p.trVars.stimLoc3Elev ...
    p.trVars.stimLoc4Elev];
tweakEccs = [0 p.trVars.stimLoc2Ecc p.trVars.stimLoc3Ecc ...
    p.trVars.stimLoc4Ecc];
if any(tweakElevs > 0)
    p.trVars.stimElevs(tweakElevs > 0) = tweakElevs(tweakElevs > 0);
end
if any(tweakEccs > 0)
    p.trVars.stimEccs(tweakEccs > 0) = tweakEccs(tweakEccs > 0);
end

% depending on which side the cue ring will be presented on, define
% locations of cue / foil stimulus patches.
% if  p.stim.cueSide == 1
%     % cue / foil elevation in degrees
%     p.trVars.cueElevDeg     = p.trVars.stimLoc1Elev;
%     p.trVars.foilElevDeg    = p.trVars.stimLoc2Elev;
%     p.trVars.cueEccDeg      = p.trVars.stimLoc1Ecc;
%     p.trVars.foilEccDeg     = p.trVars.stimLoc2Ecc;
% else
%     % cue / foil elevation in degrees
%     p.trVars.cueElevDeg     = p.trVars.stimLoc2Elev;
%     p.trVars.foilElevDeg    = p.trVars.stimLoc1Elev;
%     p.trVars.cueEccDeg      = p.trVars.stimLoc2Ecc;
%     p.trVars.foilEccDeg     = p.trVars.stimLoc1Ecc;
% end

% loop over stimulus locations:
for i = 1:length(p.trVars.stimElevs)

    % calculate locations of stimulus patches in cartesian coordinates.
    % Must invert "y" value for psychtoolbox (down = positive).
    p.trVars.stimLocCart(i, :) = p.trVars.stimEccs(i) * ...
        [cosd(p.trVars.stimElevs(i)), -sind(p.trVars.stimElevs(i))];

    % calculate stimulus patch location centers in pixels
    p.trVars.stimLocCartPix(i, :)  = pds.deg2pix(...
        p.trVars.stimLocCart(i, :), p) + ...
        p.draw.fixPointPix;

    % calculate rectangles containing stimulus patches
    p.trVars.stimRects(i, :)       = ...
        repmat(p.trVars.stimLocCartPix(i, :), 1, 2) +  ...
        p.stim.patchDiamPix / 2 * [-1 -1 1 1];
end

% compute rectangle containing cue-ring (in pixels).
ringRadPix  = pds.deg2pix(p.draw.ringRadDeg, p);
p.draw.cueRingRect = [...
    p.trVars.stimLocCartPix(p.stim.cueLoc, 1) - ringRadPix...
    p.trVars.stimLocCartPix(p.stim.cueLoc, 2) - ringRadPix ...
    p.trVars.stimLocCartPix(p.stim.cueLoc, 1) + ringRadPix ...
    p.trVars.stimLocCartPix(p.stim.cueLoc, 2) + ringRadPix];

% convert ring thickness in degrees to pixels
p.draw.ringThickPix = pds.deg2pix(p.draw.ringThickDeg, p);

end

%%
function p = timingInfo(p)

% choose how long the joystick hold duration required for the upcoming
% trial will be:
p.trVars.fixDurReq = p.trVars.fixDurReqMin + ...
    (p.trVars.fixDurReqMax - p.trVars.fixDurReqMin)*rand + ...
    (~p.trVars.isChangeTrial)*0.5;

% log fixDurReq as a status variable:
p.status.fixDurReq = p.trVars.fixDurReq;

% depending on how long the fixation will be illuminated for, define when
% the peripheral stimulus is illuminated. To start with let's have the
% peripheral stimulus on for 75% of the time that the fixation will be
% illuminated:
p.trVars.fix2StimOnIntvl = 0.25 * p.trVars.fixDurReq;

% Time between acquiring fixation and stim onset in seconds.
% p.trVars.fix2StimOnIntvl = p.trVars.fix2CueIntvl + p.trVars.cueDur + p.trVars.cue2StimItvl;

% Calculate a time for the motion-direction-change to occur for both cue
% and foil stimulus (relative to fixation acquisition).
% p.trVars.cueChangeTime  = p.trVars.fix2StimOnIntvl + p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;
% p.trVars.foilChangeTime = p.trVars.fix2StimOnIntvl + p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;

% Reward timing:
% Cued change   - reward is delivered 1s after change
% Foil change   - reward is delivered 1s after (unseen) cue change time.
% No change     - reward is delivered 1s after (unseen) cue change time.
%
% Calculate reward delivery time for hits and correct rejects. Hit reward
% time is determined by cued change time, CR reward is randomly delivered
% some time between "max latency" and max stimulus display time.
% p.trVars.hitRwdTime        = p.trVars.cueChangeTime + p.trVars.rewardDelay;
% p.trVars.corrRejRwdTime    = p.trVars.foilChangeTime + p.trVars.joyMaxLatency + ...
%     rand*(p.trVars.chgWinDur + p.trVars.stim2ChgIntvl + ...
%     p.trVars.fix2StimOnIntvl - p.trVars.foilChangeTime - p.trVars.joyMaxLatency);

% How long to display dots? Depends on trial type:
% (1) cue change trials - change time + max latency
% (2) foil change trials - reward time
% (3) no change trials - reward time
% we also need to know which change time to use for calculating the change
% "frame"
% if p.trVars.isCueChangeTrial
%     p.trVars.fix2StimOffIntvl = p.trVars.cueChangeTime + p.trVars.joyMaxLatency;
% else
%     p.trVars.fix2StimOffIntvl = p.trVars.corrRejRwdTime;
% end
p.trVars.fix2StimOffIntvl = p.trVars.fixDurReqMax;

% what's the maximum posisble stimulus display duration in seconds?
% p.trVars.stimDur = p.trVars.stim2ChgIntvl + p.trVars.chgWinDur + p.trVars.joyMaxLatency;
p.trVars.stimDur    = p.trVars.fixDurReqMax + p.trVars.joyMaxLatency;

% for stimulus generation, we need to know the duration of each "epoch" in
% frames. specify that here:
% if p.trVars.isCueChangeTrial
%     stimOnToStimChgIntvl = p.trVars.cueChangeTime - p.trVars.fix2StimOnIntvl;
% elseif p.trVars.isFoilChangeTrial
%     stimOnToStimChgIntvl = p.trVars.foilChangeTime - p.trVars.fix2StimOnIntvl;
% else
%     stimOnToStimChgIntvl = p.trVars.cueChangeTime - p.trVars.fix2StimOnIntvl;
% end
stimOnToStimChgIntvl = p.trVars.fixDurReq - p.trVars.fix2StimOnIntvl;

stimChgToStimOffIntvl = p.trVars.stimDur - stimOnToStimChgIntvl;
p.stim.epochFrames = fix(...
    [stimOnToStimChgIntvl,  stimChgToStimOffIntvl] / p.rig.frameDuration);

% number of frames up to the "end-1"th epoch (not useful when there are
% only 2 epochs but very useful when there are more epochs).
p.stim.chgFrames     = cumsum(p.stim.epochFrames(1:end - 1));

% how many total frames per stimulus patch?
p.trVars.stimFrames     = sum(p.stim.epochFrames);

% how many epochs?
p.trVars.nEpochs          = length(p.stim.epochFrames);

end

%%

function y = shuff(x)
    y = x(randperm(length(x)));
end