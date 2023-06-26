function p = joystick_release_for_stim_change_and_dim_run(p)
%   p = joystick_release_for_stim_change_and_dim_run(p)
% Part of the quintet of pldpas functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Execution of this m-file accomplishes 1 complete trial
% It is part of the loop controlled by the 'Run' action from the GUI;
%   it is preceded by 'next_trial' and followed by 'finish_trial'
%
% The whole function runs as WHILE loop, checking for changes in eye and
% joystick position. When certain positions are met, the state variable is
% updated

% % %% In this fuction, you may expect:
% % % (1)   Mark start time.
% % % (2)   While-loop:
% % % (2a)  Get voltages for eye position / diameter and joystick position.
% % % (2b)  Check current "state" and respond accordingly.
% % % (2c)  Draw.
% % % (2d)  Wait for joystick relese.

% (1) mark start time in PTB and DP time:
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = ...
    pds.getTimes;

%% (2) while-loop
% The while loop has 3 sections:
%   (1) STATE-DEPENDENT section: sets variables as a function of state
%   (2) TIME-DEPENDENT section: sets variables as a function of time 
%   (3) DRAW section: PTB-based drawing

% hide fixation point (this shouldn't be necessrary; figure out why it is
% here and then fix the problem and get rid of it 10/11/22).
p.draw.color.fix                = p.draw.clutIdx.expBg_subBg;

% initialize online eye position storage index:
i = 0;

% Loop until the trial is over (p.trVars.exitWhileLoop == true).
while ~p.trVars.exitWhileLoop
    
    % Get latest eye / joystick position:
    p = pds.getEyeJoy(p);

    % iterate counter
    i = i + 1;

    % store most recent eye position samples
    p.trData.onlineEyeX(i) = p.trVars.eyeDegX;
    p.trData.onlineEyeY(i) = p.trVars.eyeDegY;
    
    % STATE DEPENDENT section
    p = stateMachine(p);
    
    % DRAW:
    p = drawMachine(p);
     
end % while loop

end

function p = stateMachine(p)

% c = stateMachine(p)
%

%% (1) state-dependent section
% Within each state, some variables are set (eg colors of things to
% draw), some timings are recorded (eg time of fixation acquisition) as
% well as strobed to the ephys recirding system.
%
% Transition from one state to another is deteremined by evaluating
% whether a meaningful event has occured (eg fixation acquired,
% stimulus appeared, etc), or whether a certain amount of time has
% elapsed.
%
% Each state can do a myriad of things, sure, but let it be clear:
% THE CRITICAL COMPONENTS OF EACH STATE ARE:
%   (a) strobing to ehpys reocrding system
%   (b) recording of the time at which the event occured
%   (c) setting 'p.trVars.currentState' to the next state
%

%%
% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

    %%
switch p.trVars.currentState
    case p.state.trialBegun
        %% STATE 1:
        %   TRIAL HAS BEGUN!
        
        % strobing trial start time and onward to state 0.1.
        p.init.strb.addValue(p.init.codes.trialBegin);
        p.trData.timing.trialBegin      = timeNow;
        p.trVars.currentState           = p.state.waitForJoy;
        
    case p.state.waitForJoy
        %% STATE 2:
        %   WAITING FOR SUBJECT TO HOLD JOYSTICK DOWN
        
        % If joystick is held down, onwards to state "showFix"
        % If not, onward to state 3.3 (non-start)
        if pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyPress);
            p.trData.timing.joyPress    = timeNow;
            p.trVars.currentState       = p.state.showFix;
            
        elseif ~pds.joyHeld(p) && (timeNow > p.trVars.joyWaitDur)
            p.trVars.currentState       = p.state.nonStart;
        end
        
    case p.state.showFix
        %% STATE 3:
        %   JOYSTICK IS HELD, SHOW FIXATION POINT AND WAIT FOR
        %   SUBJECT TO ACQUIRE FIXATION.
        
        % Show fixation point
        p.draw.color.fix                = p.draw.clutIdx.expWhite_subWhite;
        
        % Set fixation window color depending on trial type and display it
        % on experimenter display:
        % Orange for peripheral stimulus change with no dimming
        % Blue for peripheral stimulus change + dimming
        % Black for no change
        if p.trVars.isStimChgNoDim
            p.draw.color.fixWin         = p.draw.clutIdx.expOrange_subBg;
        elseif p.trVars.isFoilChangeTrial
            p.draw.color.fixWin         = p.draw.clutIdx.expBlue_subBg;
        else
            p.draw.color.fixWin         = p.draw.clutIdx.expBlack_subBg;
        end
        p.draw.fixWinPenDraw = p.draw.fixWinPenPre;

        % If "fixOn" time hasn't been defined, and we haven't already
        % indicated that "fixOn" should be defined after the next flip,
        % indicate that "fixOn" should be defined after the next flip and
        % strobe "fixOn" after the next flip. This also means we need to
        % display the fixation!
        if p.trData.timing.fixOn < 0 ...
                && ~ismember('fixOn', p.trVars.postFlip.varNames)

            % Do we need to add strobe values to "postFlip" and to
            % "addValueOnce"? (11/8/2022 - JPH)
            p.draw.color.fix = p.draw.clutIdx.expWhite_subWhite;
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
            p.init.strb.addValueOnce(p.init.codes.fixOn);
        end
        
        % If fixation is aquired within alotted time, and joystick is
        % still held, onwards to p.state.dontMove:
        if pds.eyeInWindow(p) && pds.joyHeld(p) && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur) ...
                && p.trData.timing.fixOn > 0
                
            p.init.strb.addValue(p.init.codes.fixAq);
            p.trData.timing.fixAq      = timeNow;
            p.trVars.currentState      = p.state.dontMove;
            
        elseif ~pds.joyHeld(p)

            % joystick released early; in this case, it's a joystick break
            % "joyBreak" since he hasn't yet acquired fixation. As soon as
            % the subject acquires fixation, joystick release becomes a
            % false alarm:
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.joyBreak;

            % Compute "reaction time"
            p.trData.timing.reactionTime    = ...
                    p.trData.timing.joyRelease - p.trVars.stimChangeTime;
            
            % hide fixation point
            p.draw.color.fix                = p.draw.clutIdx.expBg_subBg;
            
        elseif p.trData.timing.fixOn > 0 && timeNow > ...
                (p.trData.timing.fixOn + p.trVars.fixWaitDur) 
            % fixation was never acquired
            p.init.strb.addValue(p.init.codes.nonStart);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.nonStart;
        end
        
    case p.state.dontMove
        %% STATE 4:
        % "DON'T MOVE" - SUBJECT HOLDS FIXATION AND JOYSTICK.
        % STUFF HAPPENS ON SCREEN (eg cue flashes, stimulus appears,
        % but these are determined in the time-dependent section,
        % below). HERE, THE KEY THING IS THAT THE SUBJECT SHOULD NOT
        % DO A SINGLE THING.
        %
        % The next state (STATE 5 - MAKE DECISION) is the money time,
        % where subject is to either respond or not, and the outcome of
        % the trial is determiend.
        
        % Calculate elapsed time since fixation acquisition
        timeFromFixAq = timeNow - p.trData.timing.fixAq;

        % Determine if cue should be on. If it should and we haven't
        % already indicated that "cueOn" should be defined after the next
        % flip, indicate that "cueOn" should be defined after the next flip
        % and strobe "cueOn" after the next flip. Conversely, also
        % determine if the cue should be off, etc.
        if timeFromFixAq >= p.trVars.fix2CueIntvl && ...
                timeFromFixAq < ...
                (p.trVars.fix2CueIntvl + p.trVars.cueDur) && ...
                ~ismember('cueOn', p.trVars.postFlip.varNames)
            p.trVars.cueIsOn                    = true;
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'cueOn';
            p.init.strb.addValueOnce(p.init.codes.cueOn);
            
        elseif ~ismember('cueOff', p.trVars.postFlip.varNames)
            p.trVars.cueIsOn                    = false;
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'cueOff';
            p.init.strb.addValueOnce(p.init.codes.cueOff);
        end
        
        % Determine if peripheral stimuli should be on. If it/they should
        % and we haven't already indicated that "stimOn" should be defined
        % after the next flip, indicate that "stimOn" should be defined
        % after the next flip and strobe "stimOn" after the next flip.
        if timeFromFixAq >= p.trVars.fix2StimOnIntvl && ...
                timeFromFixAq < p.trVars.fix2StimOffIntvl && ...
                ~ismember('stimOn', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOn';
            p.init.strb.addValueOnce(p.init.codes.stimOn);
            p.trVars.stimIsOn                = true;
        end

        % Hang out in this state until a stimChangeTime has passed, then go
        % to "makeDecision". If at any time the monkey breaks fixation or
        % joystick, go to appropriate terminal state.
        if p.trVars.isStimChangeTrial && ...
                ((timeNow - p.trData.timing.fixAq) >= ...
                p.trVars.stimChangeTime) && ...
                ~ismember('stimChg', p.trVars.postFlip.varNames)
            
            p.trVars.currentState               = p.state.makeDecision;
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimChg';
            p.init.strb.addValue(p.init.codes.stimChange);
            
        elseif p.trVars.isNoChangeTrial && ...
                ((timeNow - p.trData.timing.fixAq) >= ...
                p.trVars.stimChangeTime) && ...
                ~ismember('noChg', p.trVars.postFlip.varNames)
            
            p.trVars.currentState               = p.state.makeDecision;
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'noChg';
            p.init.strb.addValue(p.init.codes.noChange);
            
        elseif ~pds.eyeInWindow(p)

            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak   = timeNow;
            p.trVars.currentState      = p.state.fixBreak;
            
        elseif ~pds.joyHeld(p)

            % strobe joy release and mark time
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease    = timeNow;

            % Compute "reaction time"
            p.trData.timing.reactionTime    = ...
                    p.trData.timing.joyRelease - p.trVars.stimChangeTime;
            
            % if stimuli are on, this is a false alarm, otherwise it's a
            % joy break:
            if p.trVars.stimIsOn && ...
                    ((timeNow - p.trData.timing.fixAq) > ...
                    (p.trVars.fix2StimOnIntvl + p.trVars.joyMinLatency))

                p.trVars.currentState  = p.state.fa;
            else

                p.trVars.currentState  = p.state.joyBreak;

            end
            
        end

    case p.state.makeDecision

        %% STATE 5:
        %   MAKE A DECISON!
        %   THE STIMULUS CHANGE (OR LACK THEREOF) HAS OCCURED, AND
        %   MONKEY IS REQUIRED TO DECIDE WHETHER TO RESPOND OR NOT
        %
        % Either the cue or foil patch have changed, or neither (ie the
        % psuedo-change time has passed).
        %
        % In order to evaluate which state should follow, we inspect
        % animal joystick behavior (release/hold) within a prescribed
        % tempoarl window (eg "from 0.1s to 0.5s post change") for each
        % trial type:
        %
        % Joy is released:
        %   if in stim-change --> Hit
        %   if in noChange --> FA
        %
        % Joy is held:
        %   if in stim-change --> Miss
        %   if in noChange --> CR
        %
        % And of course, evaluation depends on the temporal range
        % within a response
        
        % change the thickness of the fixation window to inform
        % the experimenter that a change has happened.
        p.draw.fixWinPenDraw = p.draw.fixWinPenPost;

        % If fixation is broken, no need to check other cases:
        if ~pds.eyeInWindow(p)
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak   = timeNow;
            p.trVars.currentState      = p.state.fixBreak;
            
        % If joystick is released, evaluate trial type & time to decide
        % what happens next:
        elseif ~pds.joyHeld(p) || p.trVars.passJoy

            % Strobe joyRelease and mark time.  and calculate time of
            % joyRelease relative to fixation acquisition:
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;

            % Compute time of joyRelease relative to fixation acquisition:
            joyRelFromFixAqTime         = p.trData.timing.joyRelease - ...
                p.trData.timing.fixAq;

            % Compute "reaction time"
            p.trData.timing.reactionTime    = ...
                    p.trData.timing.joyRelease - p.trVars.stimChangeTime;
            
            % If joystick is released after a change and within
            % the tepmoral window (ie between min & max latency),
            % it's a Hit!
            if p.trVars.isStimChangeTrial && ...
                    ((joyRelFromFixAqTime > ...
                    (p.trVars.stimChangeTime + p.trVars.joyMinLatency) ...
                    && (joyRelFromFixAqTime <  ...
                    p.trVars.joyMaxLatencyAfterChange)) ...
                    || p.trVars.passJoy)

                % Move on to next state and play tone indicating that this
                % was a hit.
                p.trVars.currentState           = p.state.hit;
                p = playTone(p, 'high');

            % If joystick is released after a change but before the
            % "p.trVars.joyMinLatency", or if this is a no-change trial,
            % this is a fa (false alarm).
            elseif ((p.trVars.isStimChangeTrial && ...
                    joyRelFromFixAqTime < ...
                (p.trVars.stimChangeTime + p.trVars.joyMinLatency)) || ...
                    p.trVars.isNoChangeTrial)
                
                % Move on to next state:
                p.trVars.currentState               = p.state.fa;
            end
            
        % If joystick is held:
        else

            % If this is a stimulus change trial - Miss!
            if p.trVars.isStimChangeTrial && ...
                    (timeNow - p.trData.timing.fixAq) > ...
                    p.trVars.joyMaxLatencyAfterChange
                
                p.trVars.currentState      = p.state.miss;
                
            % If this is a no-change trial - CR!
            elseif p.trVars.isNoChangeTrial && ...
                    (timeNow - p.trData.timing.fixAq) > ...
                    p.trVars.joyMaxLatencyAfterChange

                p.trVars.currentState      = p.state.cr;

            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial COMPLETED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.hit
        %% HIT!
        % DELIVER REWARD AFTER SOME DELAY AND WAIT UNTIL POST REWARD
        % DURATION HAS ELAPSED, THEN EXIT LOOP

        % if the delay for reward delivery has elapsed and reward delivery
        % hasn't yet been triggered, deliver the reward.
        if (timeNow - p.trData.timing.fixAq) > p.trVars.hitRwdTime && ...
                p.trData.timing.reward < 0

            p = pds.deliverReward(p);
                
        % if reward delivery has been triggered and the interval to wait
        % after reward delivery has elapsed, it's time to exit the
        % while-loop.
        elseif p.trData.timing.reward > 0 && ...
                (timeNow - p.trData.timing.reward) > ...
                (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + ...
                (p.trVars.rewardDurationMs/1000))

            p.trVars.exitWhileLoop = true;

        end

    case p.state.miss

        %% MISS
        % state 23 = play low tone, then turn things off and move on
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.fa

        %% FALSE ALARM
        p = playTone(p, 'noise');
        p.trVars.exitWhileLoop = true;

    case p.state.cr

        %% CORRECT REJECT

        % 	DELIVER REWARD AFTER SOME DELAY
        % if the delay for reward delivery has elapsed and reward delivery
        % hasn't yet been triggered, deliver the reward.
        if (timeNow - p.trData.timing.fixHoldReqMet) > ...
                p.trVars.rewardDelay && p.trData.timing.reward < 0

            p = pds.deliverReward(p);

        % if reward delivery has been triggered and the interval to wait
        % after reward delivery has elapsed, it's time to exit the
        % while-loop.
        elseif p.trData.timing.reward > 0 && ...
                (timeNow - p.trData.timing.reward) > ...
                (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + ...
                (p.trVars.rewardDurationMs/1000))

            % exit while loop
            p.trVars.exitWhileLoop = true;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial ABORTED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.fixBreak
        %% FIXATION BREAK
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.joyBreak
        %% JOYSTICK BREAK (MISS)
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
        
    case p.state.nonStart
        %% NON-START
        % subject did not hold the joystick within the alloted time and
        % trila is considered a non-start.
%         p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
end

if p.trVars.exitWhileLoop
    %% TRIAL END
    %  All done with while loop regardless to whether trial was a
    % success or failure.
    % - All colors are set to to background color
    % - strobe 'trial end' and note time.
    % - break out of the while loop.

    % Calculate elapsed time since fixation acquisition
    timeFromFixAq = timeNow - p.trData.timing.fixAq;
    
    % if stimuli should be off, mark their offset
    if timeFromFixAq >= p.trVars.fix2StimOffIntvl && ...
            ~ismember('stimOff', p.trVars.postFlip.varNames)
        p.trVars.stimIsOn                   = false;
        p.trVars.postFlip.logical           = true;
        p.trVars.postFlip.varNames{end + 1} = 'stimOff';
        p.init.strb.addValueOnce(p.init.codes.stimOff);
    end
    
    % turn off fixation and fixation window:
    p.draw.color.fix          = p.draw.color.background;
    p.draw.color.fixWin       = p.draw.color.background;

    % note trial end state
    p.trData.trialEndState = p.trVars.currentState;
    
    % and strobe end of trial once:
    p.init.strb.addValueOnce(p.init.codes.trialEnd);
    p.trData.timing.trialEnd   = timeNow;
end
% Done with state-dependent section

end

function p = drawMachine(p)

% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% Given joystick state, determine color for joystick indicator:
[~, joyState] = pds.joyHeld(p);
if isnan(joyState)
    p.draw.color.joyInd = p.draw.clutIdx.expGrey25_subBg;   % neither press nor released
elseif joyState == 0
    p.draw.color.joyInd = p.draw.clutIdx.expGrey70_subBg;   % released
elseif joyState == -1
    p.draw.color.joyInd = p.draw.clutIdx.expBlue_subBg;   % pressed in low voltage
elseif joyState == 1
    p.draw.color.joyInd = p.draw.clutIdx.expOrange_subBg;   % pressed in high voltage
end

% now calculate size of joystick-fill rectangle
joyRectNow = pds.joyRectFillCalc(p);

% if we're close enouframegh in time to the next screen flip, start drawing.
if timeNow > p.trData.timing.lastFrameTime + ...
        p.rig.frameDuration - p.rig.magicNumber

    % Fill the window with the background color.
    Screen('FillRect', p.draw.window, p.draw.color.background);
    
    % Draw the grid
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], ...
        p.draw.color.gridMajor);
    
    % Draw the gaze position, MUST DRAW THE GAZE BEFORE THE
    % FIXATION. Otherwise, when the gaze indicator goes over any
    % stimuli it will change the occluded stimulus' color!
    gazePosition = ...
        [p.trVars.eyePixX p.trVars.eyePixY ...
        p.trVars.eyePixX p.trVars.eyePixY] + ...
        [-1 -1 1 1]*p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2);
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, gazePosition);
    
    % draw the cue-ring (if desired)
    if p.trVars.cueIsOn
        Screen('FrameOval', p.draw.window, p.draw.color.cueRing, ...
            p.draw.cueRingRect, p.draw.ringThickPix);
    end

    % calculate which stimulus frame we're in based on time since
    % stimulus onset - stimuli should be drawn in the frame that their
    % onset time is defined ("p.trData.timing.stimOn") for this reason,
    % we force "stimFrameIdx" to a value of "1" until the stimulus
    % onset time has been defined.
    p.trVars.stimFrameIdx  = ...
        (fix((timeNow - p.trData.timing.stimOn) / ...
        p.rig.frameDuration)) * (p.trData.timing.stimOn > 0) + 1;
    
    % if stimuli should be drawn (based on time in trial), draw them.
    if p.trVars.stimIsOn && ...
            (p.trVars.stimFrameIdx <= p.trVars.stimFrames)

        % Push (possibly new) color look-up table to ViewPIXX based on
        % current frame (frame determined based on time in trial).
        Datapixx('SetVideoClut', p.draw.myCLUTs(:, : , ...
            p.trVars.stimFrameIdx));
        
        % draw FIXED textures to screen (one per stimulus)
        for i = p.trVars.stimOnList
            if isempty(p.draw.stimTex{i})
                keyboard
            end
            Screen('DrawTexture', p.draw.window, p.draw.stimTex{i}, [], ...
                p.trVars.stimRects(i,:));
        end
    end

    % draw fixation spot
    Screen('FrameRect',p.draw.window, p.draw.color.fix, ...
        p.draw.fixPointRect, p.draw.fixPointWidth);
    
    % draw fixation window
    Screen('FrameRect',p.draw.window, p.draw.color.fixWin, ...
        repmat(p.draw.fixPointPix, 1, 2) +  ...
        [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix ...
        p.draw.fixWinWidthPix p.draw.fixWinHeightPix], ...
        p.draw.fixWinPenDraw)
    
    % Draw the joystick-bar graphic.
    Screen('FrameRect', p.draw.window, p.draw.color.joyInd, p.draw.joyRect);
    Screen('FillRect',  p.draw.window, p.draw.color.joyInd, joyRectNow);

    % flip and store time of flip.
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, ~] = ...
        Screen('Flip', p.draw.window);
    p.trData.timing.lastFrameTime   = ...
        p.trData.timing.flipTime(p.trVars.flipIdx) - ...
        p.trData.timing.trialStartPTB;
    
    % strobe all values that are in the strobe list with the
    % classyStrobe class:
    if p.init.strb.armedToStrobe
        p.init.strb.strobeList;
    end
    
    % if a stimulus event has occurred, mark the time of that event based
    % on the previously recorded fliptime.
    if p.trVars.postFlip.logical
        
        % loop over the "varNames" field of "p.trVars.postFlip" and assign
        % "p.trData.timing.lastFrameTime" to
        % "p.trData.timing.(varNames{j})".
        for j = 1:length(p.trVars.postFlip.varNames)
            if p.trData.timing.(p.trVars.postFlip.varNames{j}) < 0
                p.trData.timing.(p.trVars.postFlip.varNames{j}) = ...
                    p.trData.timing.lastFrameTime;
            end
        end
        
        % reset the logical variable indicaing we have a time to log and
        % empty the list of variable names.
        p.trVars.postFlip.logical           = false;
        p.trVars.postFlip.varNames          = cell(0);
    end
    
    % increment flip index
    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end

end