function p = joystick_release_for_fix_and_stim_dim_run(p)
%   p = joystick_release_for_fix_off_run(p)
%
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
        
        % show fixation point & strobe fixation onset:
        if p.trData.timing.fixOn < 0
            p.draw.color.fix = p.draw.clutIdx.expWhite_subWhite;
            p.init.strb.addValueOnce(p.init.codes.fixOn);
        end
        
        % If "fixOn" time hasn't been defined, and we haven't already
        % indicated that "fixOn" should be defined after the next flip,
        % indicate that "fixOn" should be defined after the next flip and
        % strobe "fixOn" after the next flip.
        if p.trData.timing.fixOn < 0 ...
                && ~ismember('fixOn', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
            p.init.strb.addValueOnce(p.init.codes.fixOn);
        end
        
        % If fixation is aquired within alotted time, and joystick is
        % still held, onwards to p.state.dontMove:
        if pds.eyeInWindow(p) && pds.joyHeld(p) && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
                
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
        %   "DON'T MOVE" - SUBJECT HOLDS FIXATION AND JOYSTICK.
        
        % Calculate elapsed time since fixation acquisition
        timeFromFixAq = timeNow - p.trData.timing.fixAq;

        % If fixation has been held for the requisite duration and the
        % joystick has not been released:
        % (1) On a "release after fixation dim" trial, dim fixation and go
        % to state 5: "make decision".
        % (2) On a "release after reward" trial, go to "correct reject"
        % state.
        if p.trData.timing.fixAq > 0 && ...
                timeFromFixAq > p.trVars.fixDurReq && pds.eyeInWindow(p)

            % if this is a "release after fixation dim" trial:
            if p.trVars.isChangeTrial

                % dim fixation, mark time that dimming occurred and go to 
                % next state (make decision):
                p.trData.timing.fixHoldReqMet = timeNow;
                p.trVars.currentState      = p.state.makeDecision;
                p.draw.color.fix           = p.draw.fixDimClutId;

            elseif pds.joyHeld(p)

                % this is a correct reject:
                p.init.strb.addValue(p.init.codes.cr);
                p.trVars.currentState      = p.state.cr;
                p = playTone(p, 'high');
            end
            
        elseif ~pds.eyeInWindow(p)

            % this is a fixation break; hide fixation; strobe fix break,
            % note time of fix break, and go to next state (fixBreak).
            p.draw.color.fix                = p.draw.clutIdx.expBg_subBg;
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak   = timeNow;
            p.trVars.currentState      = p.state.fixBreak;

        elseif ~pds.joyHeld(p)

            % this is a false alarm; strobe 
            p.init.strb.addValue(p.init.codes.fa);
            p.trData.timing.joyRelease      = timeNow;
            p.trVars.currentState           = p.state.fa;
        end

    case p.state.makeDecision

        % Calculate elapsed time since fixation hold duration requirement
        % was met:
        timeFromFixHoldMet = timeNow - p.trData.timing.fixHoldReqMet;

        % if maximum allowed duration after fixation hold duration
        % requirement has been reached, this is a miss, go to miss state:
        if timeFromFixHoldMet > p.trVars.joyMaxLatency

            % if maximum time allowed to release joystick has passed, this
            % is a MISS
            p.trVars.currentState = p.state.miss;

        elseif timeFromFixHoldMet < p.trVars.joyMinLatency && ...
                ~pds.joyHeld(p)

            % if minimum time after dimming for joystick release to be
            % allowed hasn't passed yet, but joystick has been released,
            % this is a false alarm; strobe false alarm, note time of
            % joystick release, and go to next state (false alarm).
            p.init.strb.addValue(p.init.codes.fa);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.fa;

        elseif ~pds.joyHeld(p) || (p.trVars.passJoy && ...
                timeFromFixHoldMet > p.trVars.joyMinLatency)

            % if joystick has been released 
            p.init.strb.addValue(p.init.codes.hit);
            p.trVars.currentState           = p.state.hit;
            p.trData.timing.joyRelease      = timeNow;
            p.trData.timing.reactionTime    = timeFromFixHoldMet;
        end

        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial COMPLETED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.hit
        %% HIT!

        % play tone:
        p = playTone(p, 'high');

        % hide fixation point
        p.draw.color.fix                = p.draw.clutIdx.expBg_subBg;

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
        p = playTone(p, 'high');
        p.trVars.exitWhileLoop = true;

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