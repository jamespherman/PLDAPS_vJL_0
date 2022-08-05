function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.


% Choose a row of "p.init.trialsArray" for the upcoming trial.
p = chooseRow(p);

% Trial type information:
% - cue elevation / eccentricity / motion direction / change?
% - foil elevation / eccentricity / motion direcection / on? / change?
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

    
% 1st: cue side 1, single patch trials
if any(p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) == 1 & ...
        p.status.trialsArrayRowsPossible)
    g = p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) == 1 & ...
        p.status.trialsArrayRowsPossible;
    
    % 2nd: cue side 1, two patch trials
elseif any(p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) > 1 & ...
        p.status.trialsArrayRowsPossible)
    g = p.init.trialsArray(:, 1) == 1 & p.init.trialsArray(:, 2) > 1 & ...
        p.status.trialsArrayRowsPossible;
    
    % 3rd: cue side 2, single patch trials
elseif any(p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) == 1 & ...
        p.status.trialsArrayRowsPossible)
    g = p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) == 1 & ...
        p.status.trialsArrayRowsPossible;
    
    
    % 4th: cue side 2, two patch trials
elseif any(p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) > 1 & ...
        p.status.trialsArrayRowsPossible)
    g = p.init.trialsArray(:, 1) == 2 & p.init.trialsArray(:, 2) > 1 & ...
        p.status.trialsArrayRowsPossible;
end

% choose 1st available row after shuffling list of available rows.
tempList = shuff(find(g));
p.trVars.currentTrialsArrayRow = tempList(1);

end

%%
function p = trialTypeInfo(p)

% June 19th, 2019
% retreive random seed values ("trialSeed" and "stimSeed" from trials
% array.
p.trVars.stimSeed   = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'stim seed'));
p.trVars.trialSeed  = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'trial seed'));

% use trialSeed to determine following pseudorandom number sequence
rng(p.trVars.trialSeed);

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
    
    % don't evaluate the arrayEvalString if the currently considered feature is "hue"
    if ~strcmp(p.stim.featureValueNames{i}, 'hue')
        eval(regexprep(arrayEvalString, patternString, p.stim.featureValueNames{i}));
    end
    
    % evaluate the varArrayEvalString if the currently considered feature
    % is "orientation", "hue", "luminance", or "saturation"
    if any(strcmp(varArrayFeatures, p.stim.featureValueNames{i}))
        eval(regexprep(varArrayEvalString, patternString, p.stim.featureValueNames{i}));
    end
end

% assign stimulus 1 or stimulus 2 an initial color of purple or green
% depending on trialsarray
p.stim.primStim     = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'primary'));

if p.stim.primStim == 1
    p.stim.hueArray     = repmat(...
        [p.trVars.hueInit; p.trVars.hueInit + 180], 1, p.trVars.nEpochs);
else
    p.stim.hueArray     = repmat(...
        [p.trVars.hueInit + 180; p.trVars.hueInit], 1, p.trVars.nEpochs);
end
if p.trVars.nPatches == 1
        p.stim.hueArray(2, :) = [];
end

% which side will the cue ring be presented on?
p.stim.cueSide  = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'cue side'));

% depending on the info present in the current row of the trials array
% ("p.init.trialsArray"), define the "stimulus feature value arrays."
% These have one entry for each stimulus patch (one row per patch) and
% each "epoch" (one column per epoch).

% First, which stimulus is changing on the current trial?
stimChgIdx = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'stim chg'));

% loop over stimulus features
for i = 1:p.stim.nFeatures
    
    % does the presently considered feature change on this trial?
    tempDelta = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
        ~cellfun(@isempty, strfind(p.init.trialArrayColumnNames, ...
        p.stim.featureValueNames{i})));
    
    % if saturation is going to change, it should go radially outward for
    % increase and inward for decrease, so we need to check what the
    % initial hue angle is before assigning a saturation delta.
%     if strcmp(p.stim.featureValueNames{i}, 'sat') && stimChgIdx ~= 0
%         signMult = sign(sind(p.stim.hueArray(stimChgIdx, 1)))
%     else
%         signMult = 1;
%     end
    
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

% which stimuli are shown in the current trial?
p.trVars.cueOn      = logical(...
    p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'cue on')));

p.trVars.foilOn     = logical(...
    p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'foil on')));

% set a couple simple variable that will be helpful during "run"
p.trVars.isCueChangeTrial    = stimChgIdx == p.stim.cueSide;
p.trVars.isFoilChangeTrial   = stimChgIdx ~= p.stim.cueSide && ...
    stimChgIdx ~= 0;
p.trVars.isNoChangeTrial     = stimChgIdx == 0;

% define a variable indicating if this is a contrast change trial
p.trVars.isContrastChangeTrial = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
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

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

% depending on which side the cue ring will be presented on, define
% locations of cue / foil stimulus patches.
if  p.stim.cueSide == 1
    % cue / foil elevation in degrees
    p.trVars.cueElevDeg     = p.trVars.stimLoc1Elev;
    p.trVars.foilElevDeg    = p.trVars.stimLoc2Elev;
    p.trVars.cueEccDeg      = p.trVars.stimLoc1Ecc;
    p.trVars.foilEccDeg     = p.trVars.stimLoc2Ecc;
else
    % cue / foil elevation in degrees
    p.trVars.cueElevDeg     = p.trVars.stimLoc2Elev;
    p.trVars.foilElevDeg    = p.trVars.stimLoc1Elev;
    p.trVars.cueEccDeg      = p.trVars.stimLoc2Ecc;
    p.trVars.foilEccDeg     = p.trVars.stimLoc1Ecc;
end

% calculate locations of stimulus patches in cartesian coordinates. Must
% invert "y" value for psychtoolbox (down = positive).
p.trVars.cueLocCart     = p.trVars.cueEccDeg * ...
    [cosd(p.trVars.cueElevDeg), -sind(p.trVars.cueElevDeg)];
p.trVars.foilLocCart    = p.trVars.foilEccDeg * ...
    [cosd(p.trVars.foilElevDeg), -sind(p.trVars.foilElevDeg)];

% calculate cue and foil stimulus patch location centers in pixels
p.trVars.cueLocCartPix  = pds.deg2pix(p.trVars.cueLocCart, p) + ...
    p.draw.fixPointPix;
p.trVars.foilLocCartPix = pds.deg2pix(p.trVars.foilLocCart, p) + ...
    p.draw.fixPointPix;

% based on stimulus radius and size of boxes / "checks" in pixels,
% calculate patch diameter in pixels (rounded to the nearest box) and the
% patch diameter in boxes / checks.
p.stim.patchDiamPix = round(p.trVars.stimRadius * 2 * pds.deg2pix(1, p) ...
    / p.trVars.boxSizePix) * p.trVars.boxSizePix;
p.stim.patchDiamBox = floor(p.stim.patchDiamPix / p.trVars.boxSizePix);

% calculate rectangles containing stimulus patches
p.trVars.stimRects      = [repmat(p.trVars.cueLocCartPix, 1, 2) + ...
    p.stim.patchDiamPix / 2 * [-1 -1 1 1]; ...
    repmat(p.trVars.foilLocCartPix, 1, 2) + ...
    p.stim.patchDiamPix / 2 * [-1 -1 1 1]];
    
% repmat(fix(pds.deg2pix(p.stim.funs.rtAngls([1; 0], ...
%     [p.trVars.cueElevDeg; p.trVars.foilElevDeg]) * ...
%     p.trVarsInit.stimLocEcc, p)), 1, 2) + ...
%     repmat(p.stim.patchDiamPix / 2 * [-1 -1 1 1] + ...
%     p.draw.middleXY(1)*[1 0 1 0] + p.draw.middleXY(2)*[0 1 0 1], ...
%     p.trVars.nPatches, 1);

% compute rectangle containing cue-ring (in pixels).
ringRadPix  = pds.deg2pix(p.draw.ringRadDeg, p);
p.draw.cueRingRect = [p.trVars.cueLocCartPix(1) - ringRadPix...
    p.trVars.cueLocCartPix(2) - ringRadPix ...
    p.trVars.cueLocCartPix(1) + ringRadPix ...
    p.trVars.cueLocCartPix(2) + ringRadPix];

% convert ring thickness in degrees to pixels
p.draw.ringThickPix = pds.deg2pix(p.draw.ringThickDeg, p);

end

%%
function p = timingInfo(p)

% Time between acquiring fixation and stim onset in seconds.
p.trVars.fix2StimOnIntvl = p.trVars.fix2CueIntvl + p.trVars.cueDur + p.trVars.cue2StimItvl;

% Calculate a time for the motion-direction-change to occur for both cue
% and foil stimulus (relative to fixation acquisition).
p.trVars.cueChangeTime  = p.trVars.fix2StimOnIntvl + p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;
p.trVars.foilChangeTime = p.trVars.fix2StimOnIntvl + p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;

% Reward timing:
% Cued change   - reward is delivered 1s after change
% Foil change   - reward is delivered 1s after (unseen) cue change time.
% No change     - reward is delivered 1s after (unseen) cue change time.
%
% Calculate reward delivery time for hits and correct rejects. Hit reward
% time is determined by cued change time, CR reward is randomly delivered
% some time between "max latency" and max stimulus display time.
p.trVars.hitRwdTime        = p.trVars.cueChangeTime + p.trVars.rewardDelay;
p.trVars.corrRejRwdTime    = p.trVars.foilChangeTime + p.trVars.joyMaxLatency + ...
    rand*(p.trVars.chgWinDur + p.trVars.stim2ChgIntvl + ...
    p.trVars.fix2StimOnIntvl - p.trVars.foilChangeTime - p.trVars.joyMaxLatency);

% How long to display dots? Depends on trial type:
% (1) cue change trials - change time + max latency
% (2) foil change trials - reward time
% (3) no change trials - reward time
% we also need to know which change time to use for calculating the change
% "frame"
if p.trVars.isCueChangeTrial
    p.trVars.fix2StimOffIntvl = p.trVars.cueChangeTime + p.trVars.joyMaxLatency;
else
    p.trVars.fix2StimOffIntvl = p.trVars.corrRejRwdTime;
end

% what's the maximum posisble stimulus display duration in seconds?
p.trVars.stimDur = p.trVars.stim2ChgIntvl + p.trVars.chgWinDur + p.trVars.joyMaxLatency;

% for stimulus generation, we need to know the duration of each "epoch" in
% frames. specify that here:
if p.trVars.isCueChangeTrial
    stimOnToStimChgIntvl = p.trVars.cueChangeTime - p.trVars.fix2StimOnIntvl;
elseif p.trVars.isFoilChangeTrial
    stimOnToStimChgIntvl = p.trVars.foilChangeTime - p.trVars.fix2StimOnIntvl;
else
    stimOnToStimChgIntvl = p.trVars.cueChangeTime - p.trVars.fix2StimOnIntvl;
end

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