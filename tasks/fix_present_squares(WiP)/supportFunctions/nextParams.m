function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.

% choose how long the joystick hold duration required for the upcoming
% trial will be:
p.trVars.fixDurReq = p.trVars.fixDurReqMin + ...
    (p.trVars.fixDurReqMax - p.trVars.fixDurReqMin)*rand;

% log joyPressReq as a status variable:
p.status.fixDurReq = p.trVars.fixDurReq;

% Choose a row of "p.init.trialsArray" for the upcoming trial.
p = chooseRow(p);

% Trial type information:
% - cue elevation / eccentricity / motion direction / change?
% - foil elevation / eccentricity / motion direcection / on? / change?
% p = trialTypeInfo(p);

% Cue / foil locations in cartesian coordinates and rectangle outlining the
% cue-ring.
p = locationInfo(p);

p = chooseStimulus(p);

% Timing info:
% - cue / foil change times, reward timing, dot duration
% p = timingInfo(p);

end

%%
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

% define fixation point radius from trVars, fixation point line weight
% from trVars, and fixation point rectangle.
% p.draw.fixPointRadius = p.trVars.fixPointRadPix;
% p.draw.fixPointWidth = p.trVars.fixPointLinePix;
p.draw.fixPointRect = repmat(p.draw.fixPointPix, 1, 2) + ...
    p.draw.fixPointRadius*[-1 -1 1 1];

end


%%

function p = chooseStimulus(p)

% Timing stuff
totalDurationperPresentation = p.trVars.presentationDur + p.trVars.pauseDur;

for i = 1:p.trVars.numPresentations
    p.trVars.timeStimOnset(i) = p.trVars.preStimDur + (i-1)*totalDurationperPresentation;
    p.trVars.timeStimOffset(i) = p.trVars.timeStimOnset(i) + p.trVars.presentationDur;
end

% Initialize presentationCounter to 1 (used in run)
p.trVars.presentationCounter = 1;

% Time when trial is over and reward should be delivered
p.trVars.timeReward = p.trVars.preStimDur + ...
    (p.trVars.presentationDur+ p.trVars.pauseDur)...
    *p.trVars.numPresentations + ...
    p.trVars.postStimDur;


%stimulusTypeCol = strcmp(p.init.trialArrayColumnNames, 'stimulusType');
%p.trVars.stimulusType   = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
%    stimulusTypeCol);
%switch p.trVars.stimulusType

    switch p.init.exptType
        case 'sparseNoise' % sparseNoise

            % Create grid of possible positions to present stimuli at
            xGrid = linspace (p.trVars.sparseNoiseXMin, p.trVars.sparseNoiseXMax, ...
                p.trVars.sparseNoiseGridSizeX);
            yGrid = linspace (p.trVars.sparseNoiseYMin, p.trVars.sparseNoiseYMax, ...
                p.trVars.sparseNoiseGridSizeY);
                
            XYCoords = [];
            for i = 1:numel(xGrid)
            	for j = 1:numel(yGrid)
            		XYCoords = [XYCoords; xGrid(i) yGrid(j)];	
            	end
            end
            p.trVars.sparseNoiseXYCoords = p.draw.middleXY + [1, -1] .* ...
            				   pds.deg2pix(XYCoords, p);    

	
            % Randomly select a subset of the possible positions to present at 
            p.trVars.sparseNoisePresentationSites = randsample (1:length(p.trVars.sparseNoiseXYCoords), ...
                p.trVars.numPresentations*p.trVars.sparseNoiseNumSquares);

            % Define square size in pixels
            p.trVars.sparseNoiseSquareSizePix = pds.deg2pix(p.trVars.squareSize, p);

            % Create the list of rectangles
            for i = 1:length(p.trVars.sparseNoisePresentationSites)
                
                ithRect = repmat(p.trVars.sparseNoiseXYCoords(p.trVars.sparseNoisePresentationSites(i), :), 1, 2) + ...
                    [-p.trVars.sparseNoiseSquareSizePix/2 -p.trVars.sparseNoiseSquareSizePix/2 ...
                    p.trVars.sparseNoiseSquareSizePix/2 p.trVars.sparseNoiseSquareSizePix/2];

                p.trVars.sparseNoiseRectList (:, i) = ithRect;


            end



        case 'denseNoise' % denseNoise

            % Determine total number of squares to fill screen

            p.trVars.squareSizePix = pds.deg2pix(p.trVars.squareSize, p);

            p.trVars.numSquaresX = ceil((p.draw.middleXY(1)*2)/p.trVars.squareSizePix);
            p.trVars.numSquaresY = ceil((p.draw.middleXY(2)*2)/p.trVars.squareSizePix);
            p.trVars.numSquares = p.trVars.numSquaresX*p.trVars.numSquaresY;


            % Randomly generate frames
            % Note: only need to make a matrix of random values per frame,
            % it will be stretched when calling DrawTexture
            p.trVars.denseNoiseFrames = reshape (randsample(p.trVars.denseNoiseCLUTIndices, ...
                p.trVars.numSquares*p.trVars.numPresentations, true), ...
                p.trVars.numSquaresX, p.trVars.numSquaresY, p.trVars.numPresentations);


            % Make textures for each frame
            for i = 1:p.trVars.numPresentations
                p.draw.denseNoiseTexture (i) = Screen ('MakeTexture', p.draw.window, p.trVars.denseNoiseFrames(:, :, i)');
            end


        case 'checkerboard' % checkerboard

            % Determine total number of squares to fill screen

            p.trVars.squareSizePix = pds.deg2pix(p.trVars.squareSize, p);

            p.trVars.numSquaresX = ceil((p.draw.middleXY(1)*2)/p.trVars.squareSizePix);
            p.trVars.numSquaresY = ceil((p.draw.middleXY(2)*2)/p.trVars.squareSizePix);
            
            
            checkI0 = p.trVars.checkerboardCLUTIndices(1);
            checkI1 = p.trVars.checkerboardCLUTIndices(2);

	        baseCheckerboard1 = repmat ([checkI1 checkI0; checkI0 checkI1], ...
                ceil(p.trVars.numSquaresX/2), ceil(p.trVars.numSquaresY/2));
	        baseCheckerboard0 = repmat ([checkI0 checkI1; checkI1 checkI0], ...
                ceil(p.trVars.numSquaresX/2), ceil(p.trVars.numSquaresY/2));


            swapCounter = round(rand);

            for i = 1:p.trVars.numPresentations
                if swapCounter == 0
                    p.trVars.checkerboardFrames(:, :, i) = baseCheckerboard0;
                    swapCounter = swapCounter + 1;
                elseif swapCounter == 1
                    p.trVars.checkerboardFrames(:, :, i) = baseCheckerboard1;
                    swapCounter = swapCounter - 1;
                end
	    
                p.draw.checkerboardTexture (i) = Screen ('MakeTexture', p.draw.window, p.trVars.checkerboardFrames (:, :, i)');
            end

    end

p.trVars.expCLUT = p.draw.clut.expColors;
p.trVars.subCLUT = p.draw.clut.subColors;

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
