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

% Which stimulus is changing on the current trial? Note, in this "human
% psychophysical threshold task", NO STIMULI ARE CHANGING. Instead, one
% stimulus has a different feature value than the others. I think we can
% hijack our usual way of doing things so we can retain the existing system
% for tracking which stimulus is changing and use it to track which
% stimulus is different instead.
stimChgIdx = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'stim chg'));

% which stimulus location is the "cued" location?
p.stim.cueLoc  = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'cue loc'));

% set a couple simple variables that will be helpful during "run"
p.trVars.isNoChangeTrial    = stimChgIdx == 0;
p.trVars.isStimChangeTrial  = ~p.trVars.isNoChangeTrial;

% how many stimuli will be shown on this trial?
p.stim.nStim = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'n stim'));

% randomize gabor orientation
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
    
    % evaluate the arrayEvalString
    eval([regexprep(arrayEvalString1, patternString, ...
        p.stim.featureValueNames{i}), arrayEvalString2]);
    
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
% p.stim.hueArray = repmat(...
%     circshift(p.trVars.hueInit + [0; 90; 180; 270], ...
%     p.stim.primStim - 1), 1, p.trVars.nEpochs);

% Redefine orientation array so that each patch has a unique orientation:
% p.stim.orientArray = repmat(...
%     circshift(p.trVars.orientInit + [0; 45; 90; 135], ...
%     p.stim.primStim - 1), 1, p.trVars.nEpochs);

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
    
    % if "tempDelta" is non-zero, add the corresponding feature delta
    % to the appropriate entry of the feature array
    if tempDelta ~= 0
        % find the right delta, and multiply by "tempDelta" to allow
        % for "increases" and "decreases" of various features.
        featureDelta = tempDelta * ...
            p.trVars.([p.stim.featureValueNames{i} 'Delta']);
        
        % add to stim array
        p.stim.([p.stim.featureValueNames{i} ...
            'Array'])(stimChgIdx, 1) = ...
            p.stim.([p.stim.featureValueNames{i} ...
            'Array'])(stimChgIdx, 1) + featureDelta;
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
p.trVars.fixPixX = p.draw.fixPointPix(1);
p.trVars.fixPixY = p.draw.fixPointPix(2);

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

% calculate "source rectangles" - we generate a single texture that
% contains all the stimulus patches, then we draw portions of that texture
% to distinct "destination rectangles" defined below:
p.stim.sourceRects = [(1:p.stim.patchDiamPix:p.stim.patchDiamPix * ...
    (p.trVars.nPatches - 1) + 1)', ones(p.trVars.nPatches, 1), ...
    (1:p.stim.patchDiamPix:p.stim.patchDiamPix * ...
    (p.trVars.nPatches - 1) + 1)' + p.stim.patchDiamPix-1, ...
    p.stim.patchDiamPix * ones(p.trVars.nPatches, 1)];

% loop over stimulus locations to compute "destination rectangles" for
% drawing stimulus patches:
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
if p.trVars.chgWinDur == 0
    p.trVars.stimChangeTime = -1;
else
    p.trVars.stimChangeTime  = p.trVars.fix2StimOnIntvl + ...
        p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;
end

% Compute latest acceptable joystick release time relative to stimulus
% change. This is computed multiple times in "run", so it's useful to
% compute it once per trial here:
if p.trVars.chgWinDur == 0
    p.trVars.joyMaxLatencyAfterChange = -1;
else
    p.trVars.joyMaxLatencyAfterChange = p.trVars.stimChangeTime + ...
        p.trVars.joyMaxLatency;
end

% Reward timing:
% Stimulus change   - reward is delivered 1s after change (for a hit)
% No change         - reward is delivered 1s after (unseen) change.
%
% Calculate reward delivery time for hits and correct rejects. Hit reward
% time is determined by cued change time, CR reward is randomly delivered
% some time between "max latency" and max stimulus display time.
if p.trVars.joyMaxLatencyAfterChange == -1
    p.trVars.hitRwdTime        = p.trVars.fix2StimOnIntvl + ...
        p.trVars.stim2ChgIntvl + p.trVars.rewardDelay;
    p.trVars.corrRejRwdTime    = p.trVars.hitRwdTime;
else
p.trVars.hitRwdTime        = p.trVars.stimChangeTime + ...
    p.trVars.rewardDelay;
p.trVars.corrRejRwdTime    = p.trVars.stimChangeTime + ...
    p.trVars.joyMaxLatency + ...
    rand*(p.trVars.chgWinDur + p.trVars.stim2ChgIntvl + ...
    p.trVars.fix2StimOnIntvl - p.trVars.stimChangeTime - ...
    p.trVars.joyMaxLatency);
end

% When should stimuli turn off? Depends on trial type:
% (1) Stimulus change trials - change time + max latency
% (3) No change trials - reward time
if p.trVars.chgWinDur == 0
    p.trVars.fix2StimOffIntvl = p.trVars.fix2StimOnIntvl + ...
        p.trVars.stim2ChgIntvl;
elseif p.trVars.isStimChangeTrial
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
if p.trVars.chgWinDur == 0
    stimOnToStimChgIntvl = p.trVars.stim2ChgIntvl;
    p.stim.epochFrames = fix(...
    stimOnToStimChgIntvl / p.rig.frameDuration);
else
stimOnToStimChgIntvl = p.trVars.stimChangeTime - ...
    p.trVars.fix2StimOnIntvl;
stimChgToStimOffIntvl = p.trVars.stimDur - stimOnToStimChgIntvl;
p.stim.epochFrames = fix(...
    [stimOnToStimChgIntvl,  stimChgToStimOffIntvl] / p.rig.frameDuration);
end

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