function p = gSac_jph_run(p)
%   p = gSac_jph_run(p)
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
% joystick position. When certain positions are met, the state variable is updated

%%

% (1) mark start time.
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = ...
    pds.getTimes;

%% (2) while-loop
% The while loop has 3 sections:
%   (1) STATE-DEPENDENT section: sets variables as a function of state
%   (2) TIME-DEPENDENT section: sets variables as a function of time 
%   (3) DRAW section: PTB-based drawing


while ~p.trVars.exitWhileLoop
    
    % iterate while-loop counter
    p.trVars.whileLoopIdx = p.trVars.whileLoopIdx + 1;
    
    % Update eye / joystick & Mouse position:
    p = pds.getEyeJoy(p);   
    p = pds.getMouse(p);
    
    % store just-sampled gaze position and calculate eye velocity
    p = onlineGazeCalcs(p);
    
    % STATE DEPENDENT section
    p = stateMachine(p);
    
    % TIME-DEPENDENT section
    p = timingMachine(p);
    
    % DRAW:
    p = drawMachine(p);
     
end % while loop

end

%% ---------------------

function p = stateMachine(p)

% p = stateMachine(p)

%% (1) state-dependent section
% Within each state, some variables are set (eg colors of things to
% draw), some timings are recorded (eg time of fixation acquisition) as
% well as strobed to the ephys recording system.
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
        p.trVars.currentState        = p.state.waitForJoy;
        
        
    case p.state.waitForJoy
        %% STATE 2:
        %   WAITING FOR SUBJECT TO HOLD JOYSTICK DOWN
        
        % If joystick is held down, onwards to state 0.25
        % If not, onward to state 3.3 (non-start)
        if pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyPress);
            p.trData.timing.joyPress    = timeNow;
            p.trVars.currentState    = p.state.showFix;
            
        elseif ~pds.joyHeld(p) && (timeNow > p.trVars.joyWaitDur)
            p.trVars.currentState    = p.state.nonStart;
        end
        
%         disp(num2str(double(timeNow > p.trVars.joyWaitDur)))
    case p.state.showFix
        %% STATE 3:
        %   JOYSTICK IS HELD, SO SHOW FIXATION POINT AND WAIT FOR
        %   SUBJECT TO ACQUIRE FIXATION.
        
        % show fixation point & fixation window on exp-display
        p.draw.color.fix    = p.draw.clutIdx.expWhite_subWhite;

        p.draw.color.fixWin         = p.draw.clutIdx.expGrey70_subBg;
        p.draw.fixWinPenDraw        = p.draw.fixWinPenThin;
        
        % strobe fixation onset (we only want to strobe this once):
        p.init.strb.addValueOnce(p.init.codes.fixOn);
        
        % note time of fixation onset if it hasn't yet been set
        if p.trData.timing.fixOn < 0
            p.trData.timing.fixOn          = timeNow;
        end
        
        % If fixation is aquired within alotted time, and joystick is
        % still held, onwards to p.state.dontMove:
        if pds.eyeInWindow(p) && pds.joyHeld(p) && ...
            timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
    
            p.init.strb.addValue(p.init.codes.fixAq);
            p.trData.timing.fixAq      = timeNow;
            p.trVars.currentState      = p.state.dontMove;
            
        elseif ~pds.joyHeld(p)
            % joystick released when it wasn't supposed to:
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.joyBreak;
            
        elseif timeNow > (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            % fixation was never acquired
            p.init.strb.addValue(p.init.codes.nonStart);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.nonStart;
        end
        
    case p.state.dontMove
        %% STATE 4:
        %   "DON'T MOVE" - SUBJECT HOLDS FIXATION AND JOYSTICK.
        %   STUFF HAPPENS ON SCREEN (eg cue flashes, target appears,
        %   but these are determined in the time-dependant section,
        %   below). HERE, THE KEY THING IS THAT THE SUSBJECT SHOULD NOT
        %   DO A SINGLE THING.
        %
        %   The next state is money time, where subject is to either 
        %   respond or not, and the outcome of the trial is determiend.
        
        % show target window to experimenter
        if p.trVars.isVisSac
            p.draw.color.targWin    = p.draw.clutIdx.expVisGreen_subBg;
        else
            p.draw.color.targWin    = p.draw.clutIdx.expMemMagenta_subBg;
        end
        
        % increase the thickness of the fixation window to inform
        % the experimenter that the subject has acquired fixation.
        p.draw.fixWinPenDraw = p.draw.fixWinPenThick;
        
        if (timeNow - p.trData.timing.fixAq) > p.trVars.timeFixOffset
            p.init.strb.addValue(p.init.codes.fixOff);
            p.trData.timing.fixOff    = timeNow;
            p.trVars.currentState     = p.state.makeSaccade;
        
        elseif ~pds.eyeInWindow(p)
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
        elseif ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.joyBreak;
        end
        
    case p.state.makeSaccade
        %% STATE 5:
        %   MAKE A SACCADE!
        % Fixation point has disappeared. This is the 'go' signal. 
        % Subject is required to saccade within a specified time window and
        % land in the target window.
        % joystick should be held throughout.
        
        % turn off fixation point "go signal"
        p.draw.color.fix = p.draw.clutIdx.expBg_subBg;
        
        % if joystick is broken then to hell with all this
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.joyBreak;
        end
        
        % if sub left window before goTime + minLatency, that's a fixBreak:
        if ~pds.eyeInWindow(p) && ...
                timeNow < (p.trData.timing.fixOff + p.trVars.goLatencyMin)
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
        % if left window within specified time window, that's great! We
        % note that as the real-time estimate of saccade onset.
        % strobe/note saccade onset and move to next state
        elseif (~pds.eyeInWindow(p) && ...
                timeNow > ...
                (p.trData.timing.fixOff + p.trVars.goLatencyMin) && ...
                timeNow < ...
                (p.trData.timing.fixOff + p.trVars.goLatencyMax) && ...
                gazeVelThreshCheck(p, timeNow)) || p.trVars.passEye
            
            % strobe saccade onset, mark time of strobe and set state
            % "checkLanding".
            p.init.strb.addValue(p.init.codes.saccadeOnset);
            p.trData.timing.saccadeOnset    = timeNow;
            p.trVars.currentState           = p.state.checkLanding;
            
            % decrease the thickness of the fixation window to inform
            % the experimenter that the subject has acquired fixation.
            p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
            
        % and if neither has happened and the goLatencyMax is elapsed, move
        % to breakFix
        elseif timeNow > (p.trData.timing.fixOff + p.trVars.goLatencyMax)  
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
        end
        
      case p.state.checkLanding
        %% STATE 6:
        %   CHECK LANDING POINT
        % Subject has saccaded, sure, but we have yet to check where! This
        % state checks whether he has landed in the target window or not. 
        % joystick should be held throughout. 
        
          
        % if joystick is broken then to hell with all this
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.joyBreak;
        end
        
        % calculate several relevant quantities:
        % (1) is gaze velocity above threshold?
        sacInFlight     = gazeVelThreshCheck(p, timeNow);
        
        % (2) logically index all times since fixation offset, then check
        % if eye position has exceeded 35 in any of those samples to check
        % for blinks:
        sinceFixOffLogical = p.trData.onlineGaze(:,3) > ...
            p.trData.timing.fixOff & p.trData.onlineGaze(:,3) < timeNow;
        blinkDetected   = any(any(...
            abs(p.trData.onlineGaze(sinceFixOffLogical, 1:2)) > 35));
        
        % (3) is gaze inside the target window?
        gazeInTargetWin = pds.eyeInWindow(p, 'target');
        
        % First check if the saccade is ongoing (eye velocity above
        % threshold). If it is, do nothing, go through the while-loop
        % again. If saccade is NOT ongoing, there are 3 possibilities: (1)
        % subject blinked during saccade (trial abort); (2) saccade landed
        % inside target window (move on to checking target fixation); (3)
        % saccade landed outside target window (trial abort).
        if sacInFlight
            % saccade IN-FLIGHT, do nothing, check again next time through
            % the while-loop.
            
        elseif blinkDetected
    
            % Blink during saccade.
            disp('blink detected')
            p.init.strb.addValue(p.init.codes.blinkDuringSac);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
        elseif gazeInTargetWin || p.trVars.passEye
            % if the eyes entered the target window we consdier that
            % the real-time estiamte of saccade offset:
            p.init.strb.addValue(p.init.codes.saccadeOffset);
            p.trData.timing.saccadeOffset   = timeNow;
            p.trVars.currentState           = p.state.holdTarg;
            % and 'target acquired':
            p.init.strb.addValue(p.init.codes.targetAq);
            p.trData.timing.targetAq        = timeNow;
            
            % and thicken up that targWin:
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
            
        elseif ~gazeInTargetWin || ~p.trVars.passEye
            % this means subject got into the target win too late. Likely
            % performed an intermediate saccade. This is unacceptable. 
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
            % and thin up that targWin:
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
        end
           
      case p.state.holdTarg
        %% STATE 7:
        %   HOLD TARGET FIXATION!
        % Subject has made a saccade into the target window, check to see
        % if target fixation is maintained for sufficient duration to count
        % the saccade as "completed"; joystick should be held throughout. 
        
        % if joystick is broken then to hell with all this
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.joyBreak;
        end
 
        % we reached this state because the eyes have entered the target
        % window. If they exit the window before the holdTargDuration has
        % elapsed, it is a breakFix.
       
        % check if eyes are in target window:
        eyeInTargetWin = pds.eyeInWindow(p, 'target');
        
        % if eyes stayed on target for full duration, bravo!
        if eyeInTargetWin && timeNow > p.trData.timing.saccadeOffset + ...
                p.trVars.targHoldDuration
            p.trVars.currentState = p.state.sacComplete;
            
            % and thicken up that targWin:
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
            
        elseif ~eyeInTargetWin
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
            % and thin up that targWin:
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            
            disp('target break')
            
        end
        
   
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% end states: trial COMPLETED %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    case p.state.sacComplete
        %% SACCADE COMPLETE!
        % STATE 21 = get reward delivery
        
        % if the delay for reward delivery has elapsed and reward delivery
        % hasn't yet been triggered, deliver the reward.
        if p.trData.timing.reward < 0
            p = pds.deliverReward(p);
    
        % if reward delivery has been triggered and the interval to wait
        % after reward delivery has elapsed, it's time to exit the
        % while-loop.
        elseif p.trData.timing.reward > 0 && (timeNow - p.trData.timing.reward) > (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + p.trVars.rewardDurationMs/1000)
            p.trVars.exitWhileLoop = true;
        end
        
  
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% end states: trial ABORTED %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.fixBreak
        %% FIXATION BREAK
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
        
    case p.state.joyBreak
        %% JOYSTICK BREAK
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
        
    case p.state.nonStart
        %% NON-START
        % subject did not hold the joystick within the alloted time and
        % trila is considered a non-start.
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
end

if p.trVars.exitWhileLoop
    %% TRIAL END
    %  All done with while loop regardless to whether trial was a
    % success or failure.
    % - All colors are set to to background color
    % - strobe 'trial end' and note time.
    % - break out of the while loop.
    
    % turn off fixation and fixation window: reset fixation / target window
    % thickness.
    p.draw.color.fix          = p.draw.color.background;
    p.draw.color.fixWin       = p.draw.color.background;
    
    % increase the thickness of the fixation window to inform
    % the experimenter that the subject has acquired fixation.
    p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
    p.draw.targWinPenDraw = p.draw.targWinPenThin;
    
    % note trial end state
    p.trData.trialEndState = p.trVars.currentState;
    
    % STROBING TAKES PLACE IN 'finish' function!
    
end
% Done with state-dependent section

end


%%

function p = timingMachine(p)
%
% c = timingMachine(c)
%

% time is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% Also calculate a time in "frames" relative to trial-start
p.trData.timing.frameNow    = fix(timeNow * p.rig.refreshRate);

% SET COLORS AS A FUNCTION OF ELAPSED TIME

% function of time (and may span multiple states)
if p.trData.timing.fixAq > 0
    
    % time elapsed from fixation acquisition:
    timeFromFixAq = timeNow - p.trData.timing.fixAq;

    % Determine if target should be on:
    if timeFromFixAq >= p.trVars.timeTargOnset && ...
            timeFromFixAq < p.trVars.timeTargOffset && ...
            p.trData.timing.targetOn < 0

        % target should be on, set "targetIsOn" to true, strobe target
        % onset, and log target onset time:
        p.trVars.targetIsOn       = true;
        p.init.strb.addValueOnce(p.init.codes.targetOn);
        p.trData.timing.targetOn = timeNow;

    elseif ~p.trVars.isVisSac && ...
            (p.trVars.currentState == p.state.holdTarg || ...
            (p.trData.timing.fixOff > 0 && ...
            p.trVars.targTrainingDelay >= 0 && ...
            timeNow > (p.trData.timing.fixOff + ...
            p.trVars.targTrainingDelay)))

        % if this is a MemSac trial (e.g. NOT VisSac) and it's time to
        % reilluminate the target (either after the primary saccade in a
        % fully trained animal, or after fixation offset + a delay in an
        % animal undergoing training), set "targetIsOn" to true, strobe
        % target reillumination, and log target reillumination time:
        p.trVars.targetIsOn       = true;

        % only strobe / assign target reillumination time once:
        if p.trData.timing.targetReillum < 0
            p.init.strb.addValueOnce(p.init.codes.targetReillum);
            p.trData.timing.targetReillum = timeNow;
        end

    elseif ~(timeFromFixAq < p.trVars.timeTargOffset)

        % if the target shouldn't be on set "targetIsOn" to false, strobe
        % target offset, and log time of target offset (if it's not already
        % set).
        p.trVars.targetIsOn       = false;
        p.init.strb.addValueOnce(p.init.codes.targetOff);

        % check to see that target offset time has not already been
        % defined before we set it:
        if p.trData.timing.targetOff < 0 && p.trData.timing.targetOn > 0
            p.trData.timing.targetOff = timeNow;
        end
    end
    
end

end

%%


function p = drawMachine(p)

% time is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;
%% set Joystick indicator
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

%% if we're close enough to next screen flip, start drawing:

if timeNow > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber
    
    % Fill the window with the background color.
    Screen('FillRect', p.draw.window, p.draw.color.background);
    
    % Draw the grid
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], p.draw.color.gridMajor);
    
    % draw mouse cursor:
    if p.trVarsInit.setTargLocViaMouse
        Screen('FillRect', p.draw.window, p.draw.color.mouseCursor, [p.trVars.mouseCursorX p.trVars.mouseCursorY p.trVars.mouseCursorX p.trVars.mouseCursorY] + [-1 -1 1 1] * p.draw.cursorW)
    end
        
    % Draw the gaze position, MUST DRAW THE GAZE BEFORE THE
    % FIXATION. Otherwise, when the gaze indicator goes over any
    % stimuli it will change the occluded stimulus' color!
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, [p.trVars.eyePixX p.trVars.eyePixY p.trVars.eyePixX p.trVars.eyePixY] + [-1 -1 1 1]*p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2));
    
    % draw targWin:
    Screen('FrameRect',p.draw.window, p.draw.color.targWin, repmat(p.draw.targPointPix, 1, 2) +  [-p.draw.targWinWidthPix -p.draw.targWinHeightPix p.draw.targWinWidthPix p.draw.targWinHeightPix], p.draw.targWinPenDraw)   
    
    % draw fixation window
    Screen('FrameRect',p.draw.window, p.draw.color.fixWin, repmat(p.draw.fixPointPix, 1, 2) +  [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix p.draw.fixWinWidthPix p.draw.fixWinHeightPix], p.draw.fixWinPenDraw)
    

    % draw the target (if it is time)
    if p.trVars.targetIsOn
        
        % draw target:
        Screen('FrameRect', p.draw.window, p.draw.color.targ, repmat(p.draw.targPointPix, 1, 2) + p.trVars.targRadius*[-1 -1 1 1], p.trVars.targWidth);
        
    end
    
    % draw fixation spot
    Screen('FrameRect',p.draw.window, p.draw.color.fix, repmat(p.draw.fixPointPix, 1, 2) + p.draw.fixPointRadius*[-1 -1 1 1], p.draw.fixPointWidth);
    
    
        % Draw the joystick-bar graphic.
    Screen('FrameRect', p.draw.window, p.draw.color.joyInd, p.draw.joyRect);
    Screen('FillRect',  p.draw.window, p.draw.color.joyInd, joyRectNow);
    
    % flip and record time of flip.
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, frMs] = Screen('Flip', p.draw.window, GetSecs + 0.00);
    p.trData.timing.lastFrameTime   = p.trData.timing.flipTime(p.trVars.flipIdx) - p.trData.timing.trialStartPTB;
    p.init.rigConfigFile     = which('rigConfigFiles.rigConfig_rig1'); 
    
    % strobe all values that are in the strobe list with the
    % classyStrobe class:
    if p.init.strb.armedToStrobe
        p.init.strb.strobeList;
    end
    
    % increment flip index
    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end


end

%%

function p = onlineGazeCalcs(p)

% Store gaze X, Y, and sample time; leave an extra slot for
% yet-to-be-calculated velocity
p.trData.onlineGaze(p.trVars.whileLoopIdx, :) = ...
    [p.trVars.eyeDegX, p.trVars.eyeDegY, ...
    GetSecs - p.trData.timing.trialStartPTB, NaN];

% If we've collected at least "p.trVarsInit.eyeVelFiltTaps" samples,
% compute eye velocity.
if p.trVars.whileLoopIdx > p.trVarsInit.eyeVelFiltTaps
    
    % compute diff of gaze position / sample time array
    tempDiff = diff(...
        p.trData.onlineGaze(...
        (p.trVars.whileLoopIdx - ...
        p.trVarsInit.eyeVelFiltTaps + 1):p.trVars.whileLoopIdx, 1:3));
    
    % compute rectified total gaze velocity (combined across X & Y).
    p.trData.onlineGaze(p.trVars.whileLoopIdx, 4) = ...
        sqrt(sum(mean((tempDiff(:, 1:2) ./ ...
        repmat(tempDiff(:, 3), 1, 2)).^2)));
end

end

%%

function logOut = gazeVelThreshCheck(p, timeNow)

% Several possible logical conditions that can make the value returned by
% this function "true"
% (1) Gaze velocity is above threshold and we're using the gaze velocity
% threshold.
% (2) We're not using the gaze velocity threshold but saccade onset hasn't
% yet ocurred.
% (3) We're not using the gaze velocity threshold but we're within the
% maximum acceptable saccade duration window.
% 
% check if gaze velocity is above threshold and that we're using the
% velocity threshold, or if we're not using the velocity threshold, that
% the time since saccade onset 
logOut = (p.trData.onlineGaze(p.trVars.whileLoopIdx, 4) > ...
    p.trVars.eyeVelThresh);

end
