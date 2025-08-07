function p = gSac_4factors_run(p)
%   p = gSac_4factors_run(p)
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

     % if mouseEyeSim is set to 1, use mouse position to simulate:
    if p.trVars.mouseEyeSim == 1

        % assign mouse pixels to eyePixX / Y
        p.trVars.eyePixX   = p.trVars.mouseCursorX - p.draw.middleXY(1);
        p.trVars.eyePixY   = p.trVars.mouseCursorY - p.draw.middleXY(2);

        % convert eyePixX / Y to degrees:
        p.trVars.eyeDegX   = pds.pix2deg(p.trVars.eyePixX, p);
        p.trVars.eyeDegY   = pds.pix2deg(-p.trVars.eyePixY, p);
    end
    
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
% CORRECTED VERSION: Uses the new, streamlined clutIdx names.

% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

switch p.trVars.currentState
    case p.state.trialBegun
        %% STATE 1: TRIAL HAS BEGUN
        p.init.strb.addValue(p.init.codes.trialBegin);
        p.trData.timing.trialBegin      = timeNow;
        p.trVars.currentState        = p.state.waitForJoy;
        
    case p.state.waitForJoy
        %% STATE 2: WAITING FOR JOYSTICK
        if pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyPress);
            p.trData.timing.joyPress    = timeNow;
            p.trVars.currentState    = p.state.showFix;
            
        elseif ~pds.joyHeld(p) && (timeNow > p.trVars.joyWaitDur)
            p.trVars.currentState    = p.state.nonStart;
        end
        
    case p.state.showFix
        %% STATE 3: SHOW FIXATION
        % Use the new, simplified clutIdx names
        p.draw.color.fix    = p.draw.clutIdx.black; % Fixation point is white
        p.draw.color.fixWin = p.draw.clutIdx.fixWin;  % Use the experimenter's fix window color
        p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
        
        p.init.strb.addValueOnce(p.init.codes.fixOn);
        if p.trData.timing.fixOn < 0
            p.trData.timing.fixOn = timeNow;
        end
        
        if pds.eyeInWindow(p) && pds.joyHeld(p) && timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            p.init.strb.addValue(p.init.codes.fixAq);
            p.trData.timing.fixAq      = timeNow;
            p.trVars.currentState      = p.state.dontMove;
            
        elseif ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.joyBreak;
            
        elseif timeNow > (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            p.init.strb.addValue(p.init.codes.nonStart);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.nonStart;
        end
        
    case p.state.dontMove
        %% STATE 4: HOLD FIXATION
        
        % Set target window color for experimenter. Since this task is
        % always memory-guided, we can remove the old if/else logic.
        p.draw.color.targWin = p.draw.clutIdx.fixWin;
        
        % Thicken fix window to show subject has acquired fixation
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
        %% STATE 5: GO SIGNAL
        
        % Turn off fixation point by setting its color to the background index
        p.draw.color.fix = p.draw.color.background;
        
        % ... (rest of the logic for this state is OK) ...
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.joyBreak;
        end
        if ~pds.eyeInWindow(p) && timeNow < (p.trData.timing.fixOff + p.trVars.goLatencyMin)
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
        elseif (~pds.eyeInWindow(p) && timeNow > (p.trData.timing.fixOff + p.trVars.goLatencyMin) && timeNow < (p.trData.timing.fixOff + p.trVars.goLatencyMax) && gazeVelThreshCheck(p, timeNow)) || p.trVars.passEye
            p.init.strb.addValue(p.init.codes.saccadeOnset);
            p.trData.timing.saccadeOnset    = timeNow;
            p.trVars.currentState           = p.state.checkLanding;
            p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
        elseif timeNow > (p.trData.timing.fixOff + p.trVars.goLatencyMax)  
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
        end

    % --- The rest of the states (checkLanding, holdTarg, and all end states) ---
    % --- do not reference the old clutIdx names and do not need to be changed. ---
    
    % ... (pasting the rest of the switch statement for completeness) ...
      case p.state.checkLanding
        if ~pds.joyHeld(p), p.init.strb.addValue(p.init.codes.joyRelease); p.trData.timing.joyRelease  = timeNow; p.trVars.currentState = p.state.joyBreak; end
        sacInFlight = gazeVelThreshCheck(p, timeNow);
        sinceFixOffLogical = p.trData.onlineGaze(:,3) > p.trData.timing.fixOff & p.trData.onlineGaze(:,3) < timeNow;
        blinkDetected = any(any(abs(p.trData.onlineGaze(sinceFixOffLogical, 1:2)) > 35));
        gazeInTargetWin = pds.eyeInWindow(p, 'target');
        if sacInFlight, elseif blinkDetected, disp('blink detected'); p.init.strb.addValue(p.init.codes.blinkDuringSac); p.trData.timing.fixBreak = timeNow; p.trVars.currentState = p.state.fixBreak;
        elseif gazeInTargetWin || p.trVars.passEye, p.init.strb.addValue(p.init.codes.saccadeOffset); p.trData.timing.saccadeOffset = timeNow; p.trVars.currentState = p.state.holdTarg; p.init.strb.addValue(p.init.codes.targetAq); p.trData.timing.targetAq = timeNow; p.draw.targWinPenDraw = p.draw.targWinPenThick;
        elseif ~gazeInTargetWin || ~p.trVars.passEye, p.init.strb.addValue(p.init.codes.fixBreak); p.trData.timing.fixBreak = timeNow; p.trVars.currentState = p.state.fixBreak; p.draw.targWinPenDraw = p.draw.targWinPenThin; end
      case p.state.holdTarg
        if ~pds.joyHeld(p), p.init.strb.addValue(p.init.codes.joyRelease); p.trData.timing.joyRelease  = timeNow; p.trVars.currentState = p.state.joyBreak; end
        eyeInTargetWin = pds.eyeInWindow(p, 'target');
        if eyeInTargetWin && timeNow > p.trData.timing.saccadeOffset + p.trVars.targHoldDuration, p.trVars.currentState = p.state.sacComplete; p.draw.targWinPenDraw = p.draw.targWinPenThick;
        elseif ~eyeInTargetWin, p.init.strb.addValue(p.init.codes.fixBreak); p.trData.timing.fixBreak = timeNow; p.trVars.currentState = p.state.fixBreak; p.draw.targWinPenDraw = p.draw.targWinPenThin; disp('target break'); end
    case p.state.sacComplete
        if p.trData.timing.reward < 0, p = pds.deliverReward(p);
        elseif p.trData.timing.reward > 0 && (timeNow - p.trData.timing.reward) > (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + p.trVars.rewardDurationMs/1000), p.trVars.exitWhileLoop = true; end
    case p.state.fixBreak
        p = playTone(p, 'low'); p.trVars.exitWhileLoop = true;
    case p.state.joyBreak
        p = playTone(p, 'low'); p.trVars.exitWhileLoop = true;
    case p.state.nonStart
        p = playTone(p, 'low'); p.trVars.exitWhileLoop = true;
end

if p.trVars.exitWhileLoop
    p.draw.color.fix = p.draw.color.background;
    p.draw.color.fixWin = p.draw.color.background;
    p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
    p.draw.targWinPenDraw = p.draw.targWinPenThin;
    p.trData.trialEndState = p.trVars.currentState;
end
end

%%


function p = drawMachine(p)
% drawMachine
%
% This is the final version for the gSac_4factors task. It dynamically sets
% the background color based on trial type and draws the correct stimulus
% (Image Texture or Procedural Bullseye) using the static CLUT.

% time is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

%% 1. Set Dynamic Background Color for this Trial
% Based on the 6-level stimType, set the background to the correct CLUT index.
idx = p.draw.clutIdx;
switch p.trVars.stimType
    case {1, 2} % Face or Non-Face Image Trial
        p.draw.color.background = idx.bg_image;
        
    case 3 % Bullseye: High Salience, Target 0 deg
        p.draw.color.background = idx.dkl_180;
        
    case 4 % Bullseye: Low Salience, Target 0 deg
        p.draw.color.background = idx.dkl_45;
        
    case 5 % Bullseye: High Salience, Target 180 deg
        p.draw.color.background = idx.dkl_0;
        
    case 6 % Bullseye: Low Salience, Target 180 deg
        p.draw.color.background = idx.dkl_225;
end

%% 2. Drawing (if it's time for the next frame)
if timeNow > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber
    
    % Fill the window with the background color we just selected.
    Screen('FillRect', p.draw.window, p.draw.color.background);
    
    % Draw the grid, gaze position, and fixation/target windows
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], p.draw.color.gridMajor);
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, [p.trVars.eyePixX p.trVars.eyePixY p.trVars.eyePixX p.trVars.eyePixY] + [-1 -1 1 1]*p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2));
    Screen('FrameRect',p.draw.window, p.draw.color.targWin, repmat(p.draw.targPointPix, 1, 2) +  [-p.draw.targWinWidthPix -p.draw.targWinHeightPix p.draw.targWinWidthPix p.draw.targWinHeightPix], p.draw.targWinPenDraw);
    Screen('FrameRect',p.draw.window, p.draw.color.fixWin, repmat(p.draw.fixPointPix, 1, 2) +  [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix p.draw.fixWinWidthPix p.draw.fixWinHeightPix], p.draw.fixWinPenDraw);
    
    % If this is a high reward trial, draw an extra target window for the experimenter
    if p.trVars.reward == 1 % Updated to use new 'reward' variable
        Screen('FrameRect',p.draw.window, idx.rwd_high, repmat(p.draw.targPointPix, 1, 2) + fix(1.1 * [-p.draw.targWinWidthPix -p.draw.targWinHeightPix p.draw.targWinWidthPix p.draw.targWinHeightPix]), p.draw.targWinPenDraw);
    end
    
    % Draw the target stimulus (if it is time)
    if p.trVars.targetIsOn
        if p.trVars.stimType <= 2 % It's an Image Trial
            % Draw the 6-degree image texture
            stimSize_pix = pds.deg2pix(p.stim.stimDiamDeg, p);
            targRect = CenterRectOnPoint([0 0 stimSize_pix stimSize_pix], p.draw.targPointPix(1), p.draw.targPointPix(2));
            Screen('DrawTexture', p.draw.window, p.stim.currentTexture, [], targRect);
            
        else % It's a Bullseye Trial
            % Determine the target's hue for this condition
            if p.trVars.stimType <= 4 % Type A target
                target_hue_idx = idx.dkl_0;
            else % Type B target
                target_hue_idx = idx.dkl_180;
            end
            
            % Draw two concentric rectangular rings for the bullseye
            % Outer ring at 4 degrees
            stimSize_pix_outer = pds.deg2pix(4, p);
            targRect_outer = CenterRectOnPoint([0 0 stimSize_pix_outer stimSize_pix_outer], p.draw.targPointPix(1), p.draw.targPointPix(2));
            Screen('FrameRect', p.draw.window, target_hue_idx, targRect_outer, 18);
            
            % Inner ring at 2 degrees
            stimSize_pix_inner = pds.deg2pix(2, p);
            targRect_inner = CenterRectOnPoint([0 0 stimSize_pix_inner stimSize_pix_inner], p.draw.targPointPix(1), p.draw.targPointPix(2));
            Screen('FrameRect', p.draw.window, target_hue_idx, targRect_inner, 18);
        end
    end
    
    % Draw fixation spot
    Screen('FrameRect',p.draw.window, p.draw.color.fix, repmat(p.draw.fixPointPix, 1, 2) + p.draw.fixPointRadius*[-1 -1 1 1], p.draw.fixPointWidth);
    
    % Flip the screen and manage timing
    [p.trData.timing.flipTime(p.trVars.flipIdx)] = Screen('Flip', p.draw.window, GetSecs + 0.00);
    p.trData.timing.lastFrameTime = p.trData.timing.flipTime(p.trVars.flipIdx) - p.trData.timing.trialStartPTB;
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