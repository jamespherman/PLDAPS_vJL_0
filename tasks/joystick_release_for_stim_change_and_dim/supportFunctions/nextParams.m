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
% block 1 and we should set "p.status.blockNumber" accordingly. At the
% beginning of each block, we also need to calculate the probability of a
% change event happening at the cued location so we can draw the cue
% accordingly (proportion of cue arc colored = probability of event at
% location). Note this cue arc proportion coloring is only for multiple
% stimulus trials, in which there's the possibility of changes occuring
% somewhere other than the cued location.
if isempty(p.status.trialsArrayRowsPossible)
    p.status.trialsArrayRowsPossible =  true(p.init.blockLength, 1);
    p.status.blockNumber = 1;

    % define a vector of booleans to determine which trials will have a
    % free reward after they're completed and which will not:
    p.status.freeRewardsAvailable = false(p.init.blockLength, 1);

    % how many free rewards per block?
    nFreeRewards = ceil(p.init.blockLength / 10);

    % pick trials to have free rewards:
    p.status.freeRewardsAvailable(...
        randi(p.init.blockLength, [nFreeRewards, 1])) = true;

    % define cue arc color proportion based on number of change trials at
    % cued location versus change trials at other locations; note that this
    % assumes the proportion of change trials at the cued location is the
    % same for all cued locations in a block. To calculate this we need to
    % know the number of stimuli for each trial the location of the
    % change in each trial, and the location of the cue in each trial:
    nStim   = p.init.trialsArray(:, ...
        strcmp(p.init.trialArrayColumnNames, 'n stim'));
    cueLoc = p.init.trialsArray(:, ...
        strcmp(p.init.trialArrayColumnNames, 'cue loc'));
    chgLoc = p.init.trialsArray(:, ...
        strcmp(p.init.trialArrayColumnNames, 'stim chg'));
    arcAngleProp = nnz(nStim > 1 & cueLoc == chgLoc) / ...
        nnz(nStim > 1 & chgLoc > 0);

    % Here we define the proportion of the cue arc that will be colored.
    % Later in "defineVisuals.m" we calculate the actual angles of the
    % start & end of the colored / gray proportions.
    p.draw.cueArcProp = arcAngleProp;

end

% To choose a row of "p.init.trialsArray", we define a logical vector "g"
% including all the trials that haven't been completed yet, with additional
% ordering criteria based on number of stimuli and cue location. We first
% check to see if there's more than one cue location defined; if there is
% we first go through all the trials with the lowest cue location, then all
% the trials at the next (larger) cue location, etc. Within each cue
% location we first go through all the single stimulus trials, then all the
% 2 stimulus trials, et cetera. Our first step is to define a vector gC
% including the trials for the smallest available cue location:
cueLocs = p.init.trialsArray(:, ...
    strcmp(p.init.trialArrayColumnNames, 'cue loc'));
if any(cueLocs == 1 & p.status.trialsArrayRowsPossible)
    gC = cueLocs == 1 & p.status.trialsArrayRowsPossible;
elseif any(cueLocs == 2 & p.status.trialsArrayRowsPossible)
    gC = cueLocs == 2 & p.status.trialsArrayRowsPossible;
elseif any(cueLocs == 3 & p.status.trialsArrayRowsPossible)
    gC = cueLocs == 3 & p.status.trialsArrayRowsPossible;
elseif any(cueLocs == 4 & p.status.trialsArrayRowsPossible)
    gC = cueLocs == 4 & p.status.trialsArrayRowsPossible;
else
    gC = p.status.trialsArrayRowsPossible;
end

% now we further select based on number of stimuli in the trial:
nStim = p.init.trialsArray(:, ...
    strcmp(p.init.trialArrayColumnNames, 'n stim'));

% 1st: single stimulus trials
if any(nStim == 1 & p.status.trialsArrayRowsPossible & gC)
    g = nStim == 1 & ...
        p.status.trialsArrayRowsPossible & gC;
    
    % 2nd: two stimulus trials
elseif any(nStim == 2 & p.status.trialsArrayRowsPossible & gC)
    g = nStim == 2 & ...
        p.status.trialsArrayRowsPossible & gC;
    
    % 3rd: three stimulus trials
elseif any(nStim == 3 & p.status.trialsArrayRowsPossible & gC)
    g = nStim == 3 & ...
        p.status.trialsArrayRowsPossible & gC;
    
    % 4th: four stimulus trials
elseif any(nStim == 4 & p.status.trialsArrayRowsPossible & gC)
    g = nStim == 4 & ...
        p.status.trialsArrayRowsPossible & gC;
end

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

% Which stimulus is changing on the current trial?
p.stim.stimChgIdx = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'stim chg'));

% which stimulus location is the "cued" location?
p.stim.cueLoc  = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'cue loc'));

% set a couple simple variables that will be helpful during "run"
p.trVars.isNoChangeTrial    = p.stim.stimChgIdx == 0;
p.trVars.isStimChangeTrial  = ~p.trVars.isNoChangeTrial;

% how many stimuli will be shown on this trial?
p.stim.nStim = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'n stim'));

% On a certain proportion of trials, we want the peripheral stimulus to
% change in some feature without dimming. We use a random number draw to
% decide which trials this should happen on. At the moment (6/29/23) we're
% training Feynman on the multiple stimulus version of the task. For that
% purpose, we want "propHueChgOnly" to influence only change trials with
% multiple stimuli, not change trials with single stimuli. Figure all that
% out here:
if p.trVars.isStimChangeTrial

    % If this is a change trial with multiple stimuli, draw a random number
    % between 0 & 1 and compare it to "propHueChgOnly" to decide if this
    % will be a stim + dim change or just a stim change; if it's instead a
    % change trial with 1 stimulus, it will always be a stim change with no
    % dim.
    if p.stim.nStim > 1 || ~p.trVars.chgAndDimOnMultiOnly
        p.trVars.isStimChgNoDim = rand < p.trVars.propHueChgOnly;
    else
        p.trVars.isStimChgNoDim = true;
    end
else
    p.trVars.isStimChgNoDim = false;
end

% randomize initial gabor orientation for "primary" stimulus location
p.trVars.orientInit = randi(360);

% Define stimulus arrays for several features. We do this by defining a
% generic string with "FEATURE" in certain places that gets replaced by
% regexp in the loop below. We furthe break down each string into a 1st and
% 2nd part (this is mostly to make it possible to keep our code organized
% but also, the 1st part of the string contains the "FEATURE" bit to be
% replaced and the 2nd part of the string doesn't).
arrayEvalString1 = ...
    'p.stim.FEATUREArray = p.trVars.FEATUREInit * ';
arrayEvalString2 = 'ones(p.trVars.nPatches, p.trVars.nEpochs);';
varArrayEvalString1 = ...
    'p.stim.FEATUREVarArray = p.trVars.FEATUREVar * ';
varArrayEvalString2 = 'ones(p.trVars.nPatches, p.trVars.nEpochs);';
patternString = 'FEATURE';
varArrayFeatures = {'orient', 'hue', 'lum', 'sat'};

% loop over features and use "regexprep.m" to modify "arrayEvalString" and
% / or "varArrayEvalString" as needed for each feature.
for i = 1:p.stim.nFeatures
    
    % don't evaluate the arrayEvalString if the currently considered
    % feature is "hue"
    if ~strcmp(p.stim.featureValueNames{i}, 'hue')
        eval([regexprep(arrayEvalString1, patternString, ...
            p.stim.featureValueNames{i}), arrayEvalString2]);
    end
    
    % evaluate the varArrayEvalString if the currently considered feature
    % is "orientation", "hue", "luminance", or "saturation"
    if any(strcmp(varArrayFeatures, p.stim.featureValueNames{i}))
        eval([regexprep(varArrayEvalString1, patternString, ...
            p.stim.featureValueNames{i}), varArrayEvalString2]);
    end
end

% Determine which stimulus is "primary"
p.stim.primStim     = p.init.trialsArray(p.trVars.currentTrialsArrayRow,...
    strcmp(p.init.trialArrayColumnNames, 'primary'));

% Redefine Hue array so that each patch has a unique hue:
p.stim.hueArray = repmat(...
    circshift(p.trVars.hueInit + [0; 90; 180; 270], ...
    p.stim.primStim - 1), 1, p.trVars.nEpochs);

% Redefine orientation array so that each patch has a unique orientation:
p.stim.orientArray = repmat(...
    circshift(p.trVars.orientInit + [0; 45; 90; 135], ...
    p.stim.primStim - 1), 1, p.trVars.nEpochs);

% depending on the info present in the current row of the trials array
% ("p.init.trialsArray"), define the "stimulus feature value arrays."
% These have one entry for each stimulus patch (one row per patch) and
% each "epoch" (one column per epoch).

try
% loop over stimulus features
for i = 1:p.stim.nFeatures
    
    % does the presently considered feature change on this trial?
    tempDelta = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
        contains(p.init.trialArrayColumnNames, ...
        p.stim.featureValueNames{i}));

    % if this is a trial in which we want to force only the stimulus
    % feature to change with no dimming, adjust the "tempDelta" for
    % luminance here:
    if p.trVars.isStimChgNoDim && ...
            strcmp(p.stim.featureValueNames{i}, 'lum')
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
            'Array'])(p.stim.stimChgIdx, 2) = ...
            p.stim.([p.stim.featureValueNames{i} ...
            'Array'])(p.stim.stimChgIdx, 2) + featureDelta;
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

% If this is a change trial, we set "dimVal" to 1, otherwise to 0. This is
% left over from the previous training step. It's a hack (of course). We
% need to change this. JPH (11/7/2022).
if p.trVars.isStimChangeTrial
    p.trData.dimVal = 1;
else
    p.trData.dimVal = 0;
end

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
%
% p = timingInfo(p)
%
% In which we calculate the timing of stimulus and reward events. The
% majority of these are calculated relative to the time that fixation is
% aquired.

% Time between acquiring fixation and stimulus onset in seconds.
p.trVars.fix2StimOnIntvl = p.trVars.fix2CueIntvl + p.trVars.cueDur + ...
    p.trVars.cue2StimItvl;

% Stimulus change time; regardless of whether there actually is a stimulus
% change in the current trial, we calculate a change time to keep the
% distributions of stimulus presentation durations and reward timings the
% same between change and no-change trials.
p.trVars.stimChangeTime  = p.trVars.fix2StimOnIntvl + ...
    p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;

% Compute latest acceptable joystick release time relative to stimulus
% change. This is computed multiple times in "run", so it's useful to
% compute it once per trial here:
p.trVars.joyMaxLatencyAfterChange = p.trVars.stimChangeTime + ...
    p.trVars.joyMaxLatency;

% Reward timing:
% Stimulus change   - reward is delivered 1s after change (for a hit)
% No change         - reward is delivered 1s after (unseen) change.
%
% Calculate reward delivery time for hits and correct rejects. Hit reward
% time is determined by cued change time, CR reward is randomly delivered
% some time between "max latency" and max stimulus display time.
p.trVars.hitRwdTime        = p.trVars.stimChangeTime + ...
    p.trVars.rewardDelay;
p.trVars.corrRejRwdTime    = p.trVars.stimChangeTime + ...
    p.trVars.joyMaxLatency + ...
    rand*(p.trVars.chgWinDur + p.trVars.stim2ChgIntvl + ...
    p.trVars.fix2StimOnIntvl - p.trVars.stimChangeTime - ...
    p.trVars.joyMaxLatency);

% When should stimuli turn off? Depends on trial type:
% (1) Stimulus change trials - change time + max latency
% (3) No change trials - reward time
if p.trVars.isStimChangeTrial
    p.trVars.fix2StimOffIntvl = p.trVars.stimChangeTime + ...
        p.trVars.joyMaxLatency;
else
    p.trVars.fix2StimOffIntvl = p.trVars.corrRejRwdTime;
end

% What's the maximum posisble stimulus display duration in seconds?
p.trVars.stimDur = p.trVars.stim2ChgIntvl + p.trVars.chgWinDur + ...
    p.trVars.joyMaxLatency;

% For stimulus generation, we need to know the duration of each "epoch" in
% frames. An "epoch" is some duration over which the features of the
% stimuli don't change (e.g. the hue distribution doesn't change). We first
% calculate the duration of each "epoch" in seconds then convert to frames:
stimOnToStimChgIntvl = p.trVars.stimChangeTime - ...
    p.trVars.fix2StimOnIntvl;
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

% how long is the reward schedule including padding?
p.trVars.rewardScheduleDur = p.trVars.rewardDurationMs/1000 + ...
    p.rig.dp.dacPadDur;

% how long to wait after reward delivery before we potentially deliver a
% free inter-trial interval reward?
p.trVars.postRewardDuration = rand * (p.trVars.postRewardDurMax - ...
    p.trVars.postRewardDurMin) + p.trVars.postRewardDurMin;

end

%%

function y = shuff(x)
    y = x(randperm(length(x)));
end