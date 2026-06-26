function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.

% choose how long the joystick hold duration required for the upcoming
% % trial will be:
% p.trVars.fixDurReq = p.trVars.fixDurReqMin + ...
%     (p.trVars.fixDurReqMax - p.trVars.fixDurReqMin)*rand;

% log joyPressReq as a status variable:
% p.status.fixDurReq = p.trVars.fixDurReq;

% Choose a row of "p.init.trialsArray" for the upcoming trial.
% p = chooseRow(p);

% Trial type information:
% - cue elevation / eccentricity / motion direction / change?
% - foil elevation / eccentricity / motion direcection / on? / change?
% p = trialTypeInfo(p);

% Cue / foil locations in cartesian coordinates and rectangle outlining the
% cue-ring.

p = trialTypeInfo(p)
p = locationInfo(p);
p = setLocations(p);

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
%% Choosing Block, and type of trial

%% If new block         
if p.status.CurrentBlockNumber == 0
    % If First Block ; Choose randomly the type of the block
    p.status.CurrentBlockType = randi([1 2]);
    p = ChangeBlock(p);

elseif p.status.RemainingCongruent + p.status.RemainingConflict == 0
    % If Block is finished and we need to start a new block ;
    % So RemainingCong + RemainingConf = 0 ;
    % Switch to the other block type 1-> 2 & 2 -> 1

    p.status.CurrentBlockType = 3 - p.status.CurrentBlockType; % Switch block type
    p = ChangeBlock(p);
end

%% If within a block:
%Draw a reward noise value from Gaussian SD 0.015ml =(14ms)

x = randn * 14;
% Calculate the actual reward durations for the upcoming trial
p.status.ActualRichReward = p.status.BlockRichMeanDuration + x;
p.status.ActualPoorReward = p.status.BlockPoorMeanDuration + x;

% Choose the Trial type ; Congruent (1) or Conflict (2) within the remaining  
if p.status.RemainingConflict == 0 
    p.status.ActualTrialType = 1;
elseif p.status.RemainingCongruent == 0
    p.status.ActualTrialType = 2;
else
    p.status.ActualTrialType = randi([1, 2]); % Randomly choose trial type
end 


p = AssignTrialType(p);

end

function p = AssignTrialType(p)
%% Assign the ActualRichReward and ActualPoorReward to the targets corresponding depending on the block
%% Assign the good visual cues for exp
disp('Before Assignement')

disp(p.status.iTrial);
disp(p.status.CurrentBlockType);
disp(p.status.ActualTrialType);
disp(p.status.highSalienceSide);

if p.status.CurrentBlockType == 1
    % Assign Reward
    p.trVars.rewardDurationLeft = double(p.status.ActualPoorReward) ;
    p.trVars.rewardDurationRight = double(p.status.ActualRichReward) ;
   
else    %if Block Type = 2
    % Assign Reward
    p.trVars.rewardDurationLeft = double(p.status.ActualRichReward) ;
    p.trVars.rewardDurationRight = double(p.status.ActualPoorReward) ;
end

    %Assign Target Properties
if p.status.ActualTrialType == 1    % If Congruent
    p.status.highSalienceSide = p.status.highRewardSide;
else                                % If Conflict
    p.status.highSalienceSide =  3- p.status.highRewardSide;
end


disp('After Assignement')

disp(p.status.iTrial);
disp(p.status.CurrentBlockType);
disp(p.status.ActualTrialType);
disp(p.status.highSalienceSide);

% Display all information for the trial and block ; 
displayTrialStatus(p)
end


function p = ChangeBlock(p)
%% Choose the number of trial for this block ; between 60 and 100 and mod 4. Normal distrib + 80.
% And update Block numbers
x = Inf; while x < 60 || x > 100 || mod(x, 4) ~=0, x = 80+ round(5* randn); end
p.status.TotalTrialsPerBlock = x;
p.status.RemainingConflict = x/2;
p.status.RemainingCongruent = x/2;

% Update block
p.status.CurrentBlockNumber = p.status.CurrentBlockNumber+ 1 ;
p.status.RemainingBlock = p.status.RemainingBlock - 1;


if p.status.CurrentBlockType == 1
    p.status.highRewardSide = 1;
else
    p.status.highRewardSide = 2;
end

p = ChooseBlockReward(p);
end 

function p = ChooseBlockReward(p)
%% Choose the reward given for High and poor target
% Range of mean : reward  0.04ml =(37ms) to 0.21ml =(191ms) with  minimum
% 0.044ml difference =(40ms)
% We chose a mean reward for rich and poor per block, and we add (LATER) a Gaussian
% noise with SD = 0.015ml =(14ms)
x = [0 0]
while x(1)-x(2) < 40, x = unifrnd(37, 191, [1, 2]); end
p.status.BlockRichMeanDuration = max(x);
p.status.BlockPoorMeanDuration = min(x);

end


function p = locationInfo(p)

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

% define fixation point radius from trVars, fixation point line weight
% from trVars, and fixation point rectangle.
p.draw.fixPointRadius = p.trVars.fixPointRadPix;
p.draw.fixPointWidth = p.trVars.fixPointLinePix;
p.draw.fixPointRect = repmat(p.draw.fixPointPix, 1, 2) + ...
    p.draw.fixPointRadius*[-1 -1 1 1];

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
    

%% Target hold duration (To allow Go Signal)
p.trVars.fixDurReq = unifrnd(...
    p.trVars.fixDurReqMin, p.trVars.fixDurReqMax);


%% Target hold duration (after saccade lands)
p.trVars.targHoldDuration = unifrnd(...
    p.trVars.targHoldDurationMin, p.trVars.targHoldDurationMax);


end


function p = setLocations(p)
%% T1
% Set the color
p.trVars.T1_colorIdx         = p.draw.clutIdx.expRed_subRed;

% NEW: Convert T1 position from degrees to pixels

p.draw.T1_locPixX = p.draw.middleXY(1) + ...
pds.deg2pix(p.trVars.T1_locDegX, p);
p.draw.T1_locPixY = p.draw.middleXY(2) - ...
pds.deg2pix(p.trVars.T1_locDegY, p); % negative because screen Y is inverted

% Convert T1 dimensions from degrees to pixels

p.draw.T1_longAxisPix = pds.deg2pix(p.trVars.T1_longAxisDeg, p);
p.draw.T1_shortAxisPix = pds.deg2pix(p.trVars.T1_shortAxisDeg, p);

%% T2
%Set the color
p.trVars.T2_colorIdx         = p.draw.clutIdx.expRed_subRed;

% NEW: Convert T1 position from degrees to pixels

p.draw.T2_locPixX = p.draw.middleXY(1) + ...
pds.deg2pix(p.trVars.T2_locDegX, p);
p.draw.T2_locPixY = p.draw.middleXY(2) - ...
pds.deg2pix(p.trVars.T2_locDegY, p); % negative because screen Y is inverted

% Convert T2 dimensions from degrees to pixels

p.draw.T2_longAxisPix = pds.deg2pix(p.trVars.T2_longAxisDeg, p);
p.draw.T2_shortAxisPix = pds.deg2pix(p.trVars.T2_shortAxisDeg, p);

end
%%

function y = shuff(x)
    y = x(randperm(length(x)));
end

