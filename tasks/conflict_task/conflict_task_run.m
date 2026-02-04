function p = conflict_task_run(p)
%   p = conflict_task_run(p)
%
% Main trial execution function for the Conflict Task.
% Contains the state machine, drawing routines, and timing logic.
%
% Key differences from gSac_4factors:
%   - Two targets displayed simultaneously
%   - Delta-t manipulation (stimulus onset relative to go signal)
%   - Two-alternative choice (goal-directed vs capture)

%% Mark trial start time in both PTB and DATAPixx time bases
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = ...
    pds.getTimes;

%% Main while-loop: runs until trial ends (success or failure)
while ~p.trVars.exitWhileLoop

    % Increment while-loop iteration counter
    p.trVars.whileLoopIdx = p.trVars.whileLoopIdx + 1;

    % Sample current eye position from ADC and joystick state
    p = pds.getEyeJoy(p);
    p = pds.getMouse(p);

    % If mouse simulation mode is enabled, use mouse as eye position
    if p.trVars.mouseEyeSim == 1
        p.trVars.eyePixX = p.trVars.mouseCursorX - p.draw.middleXY(1);
        p.trVars.eyePixY = p.trVars.mouseCursorY - p.draw.middleXY(2);
        p.trVars.eyeDegX = pds.pix2deg(p.trVars.eyePixX, p);
        p.trVars.eyeDegY = pds.pix2deg(-p.trVars.eyePixY, p);
    end

    % Store gaze position and compute online eye velocity
    p = onlineGazeCalcs(p);

    % STATE MACHINE: handle state transitions based on behavior
    p = stateMachine(p);

    % TIMING MACHINE: handle stimulus timing events (delta-t)
    p = timingMachine(p);

    % DRAW MACHINE: update visual display
    p = drawMachine(p);

end

end

%% -------------------- STATE MACHINE --------------------
function p = stateMachine(p)
% Manages trial state transitions based on eye position, joystick,
% and elapsed time. Strobes event codes at state transitions.

timeNow = GetSecs - p.trData.timing.trialStartPTB;

switch p.trVars.currentState

    case p.state.trialBegun
        % Trial has just started - strobe trial begin code
        p.init.strb.addValue(p.init.codes.trialBegin);
        p.trData.timing.trialBegin = timeNow;
        p.trVars.currentState = p.state.waitForJoy;

    case p.state.waitForJoy
        % Waiting for subject to press joystick to initiate trial
        if pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyPress);
            p.trData.timing.joyPress = timeNow;
            p.trVars.currentState = p.state.showFix;
        elseif ~pds.joyHeld(p) && (timeNow > p.trVars.joyWaitDur)
            % Joystick not pressed within allowed time
            p.trVars.currentState = p.state.nonStart;
        end

    case p.state.showFix
        % Fixation point is visible - waiting for eye to enter window
        p.draw.color.fix = p.draw.clutIdx.expBlack_subBlack;
        p.draw.color.fixWin = p.draw.clutIdx.expGrey70_subBg;
        p.draw.fixWinPenDraw = p.draw.fixWinPenThin;

        % Mark fixation onset time on first frame fixation is shown
        if p.trData.timing.fixOn < 0 && ...
                ~ismember('fixOn', p.trVars.postFlip.varNames)
            p.init.strb.addValueOnce(p.init.codes.fixOn);
            p.trVars.postFlip.logical = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
        end

        % Check joystick first (doesn't depend on fixOn timing)
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState = p.state.joyBreak;
            return
        end

        % Only check fixation timing if fixOn has been assigned (>0)
        % Timing variables set via postFlip may still be -1 initially
        if p.trData.timing.fixOn > 0
            % Check if eye entered fixation window while holding joystick
            if pds.eyeInWindow(p) && pds.joyHeld(p) && ...
                    timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
                p.init.strb.addValue(p.init.codes.fixAq);
                p.trData.timing.fixAq = timeNow;
                p.trVars.currentState = p.state.dontMove;
            elseif timeNow > (p.trData.timing.fixOn + p.trVars.fixWaitDur)
                p.init.strb.addValue(p.init.codes.nonStart);
                p.trData.timing.joyRelease = timeNow;
                p.trVars.currentState = p.state.nonStart;
            end
        end

    case p.state.dontMove
        % Subject is fixating - waiting for go signal (fixation offset)
        % Note: Stimuli may appear before go signal (negative delta-t)

        p.draw.color.targWin = p.draw.clutIdx.expGrey70_subBg;
        p.draw.fixWinPenDraw = p.draw.fixWinPenThick;

        % Check if fixation hold period has elapsed (time for go signal)
        if (timeNow - p.trData.timing.fixAq) > p.trVars.timeGoSignal
            p.init.strb.addValue(p.init.codes.fixOff);
            if p.trData.timing.fixOff < 0 && ...
                    ~ismember('fixOff', p.trVars.postFlip.varNames)
                p.trVars.postFlip.logical = true;
                p.trVars.postFlip.varNames{end + 1} = 'fixOff';
            end
            p.trVars.fixationVisible = false;
            p.trVars.currentState = p.state.makeSaccade;
        elseif ~pds.eyeInWindow(p)
            % Eye left fixation window during delay
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;
        elseif ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState = p.state.joyBreak;
        end

    case p.state.makeSaccade
        % Go signal given - subject should make saccade to one of two targets

        p.draw.color.fix = p.draw.color.background;

        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState = p.state.joyBreak;
            return
        end

        % Calculate time since go signal
        % IMPORTANT: Only compute if fixOff has been assigned (>0).
        % Timing variables are initialized to -1 and set via postFlip,
        % so they may still be -1 on the first iteration after state transition.
        if p.trData.timing.fixOff > 0
            timeSinceGo = timeNow - p.trData.timing.fixOff;
        else
            % fixOff not yet assigned - skip timing checks this iteration
            return
        end

        % Check for saccade initiation
        eyeLeftFixWin = ~pds.eyeInWindow(p);
        velocityExceedsThresh = gazeVelThreshCheck(p, timeNow) || p.trVars.passEye;

        if eyeLeftFixWin && velocityExceedsThresh && ...
                timeSinceGo < p.trVars.responseWindow
            % Valid saccade initiation
            p.init.strb.addValue(p.init.codes.saccadeOnset);
            p.trData.timing.saccadeOnset = timeNow;
            p.trVars.currentState = p.state.checkLanding;
            p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
            disp('saccadeMade')

        elseif timeSinceGo > p.trVars.responseWindow
            % No saccade within response window
            p.init.strb.addValue(p.init.codes.noResponse);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.noResponse;
            disp(['no response after ' num2str(timeSinceGo * 1000) ' ms'])
        end

    case p.state.checkLanding
        % Saccade initiated - checking where it lands

        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState = p.state.joyBreak;
            return
        end

        % Check if saccade is still in flight (high velocity)
        sacInFlight = gazeVelThreshCheck(p, timeNow);

        % Get gaze samples since fixation offset for blink detection
        % Only compute if fixOff has been assigned (>0)
        if p.trData.timing.fixOff > 0
            sinceFixOffLogical = ...
                p.trData.onlineGaze(:,3) > p.trData.timing.fixOff & ...
                p.trData.onlineGaze(:,3) < timeNow;
        else
            % fixOff not assigned - use all samples up to now
            sinceFixOffLogical = p.trData.onlineGaze(:,3) < timeNow;
        end

        % Detect blinks
        blinkDetected = ...
            any(any(abs(p.trData.onlineGaze(sinceFixOffLogical, 1:2)) > 35));

        % Check if gaze is within either target window (left or right)
        gazeInLeftTarget = eyeInTargetWindow(p, 'left');
        gazeInRightTarget = eyeInTargetWindow(p, 'right');

        if sacInFlight
            % Saccade still in flight - continue waiting

        elseif blinkDetected
            disp('blink detected');
            p.init.strb.addValue(p.init.codes.blinkDuringSac);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;

        elseif gazeInLeftTarget || p.trVars.passEye
            % Saccade landed in LEFT target window
            p.init.strb.addValue(p.init.codes.saccadeOffset);
            p.trData.timing.saccadeOffset = timeNow;
            p.trData.chosenSide = 1;  % left
            p.trVars.currentState = p.state.holdTarg;
            p.init.strb.addValue(p.init.codes.targetAq);
            p.trData.timing.targetAq = timeNow;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
            disp('targHold - LEFT target')

        elseif gazeInRightTarget
            % Saccade landed in RIGHT target window
            p.init.strb.addValue(p.init.codes.saccadeOffset);
            p.trData.timing.saccadeOffset = timeNow;
            p.trData.chosenSide = 2;  % right
            p.trVars.currentState = p.state.holdTarg;
            p.init.strb.addValue(p.init.codes.targetAq);
            p.trData.timing.targetAq = timeNow;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
            disp('targHold - RIGHT target')

        else
            % Saccade landed outside both target windows - inaccurate
            p.init.strb.addValue(p.init.codes.inaccurate);
            p.trData.timing.fixBreak = timeNow;
            p.trData.chosenSide = 0;
            p.trVars.currentState = p.state.inaccurate;
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            disp('inaccurate - outside both targets')
        end

    case p.state.holdTarg
        % Gaze in chosen target window - must hold fixation for reward

        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState = p.state.joyBreak;
            return
        end

        % Check if gaze is still in the chosen target window
        if p.trData.chosenSide == 1
            eyeInChosenTarget = eyeInTargetWindow(p, 'left');
        else
            eyeInChosenTarget = eyeInTargetWindow(p, 'right');
        end

        % Check if target hold duration has been met
        holdTimeElapsed = ...
            timeNow > p.trData.timing.saccadeOffset + p.trVars.targHoldDuration;

        if eyeInChosenTarget && holdTimeElapsed
            % Successfully held target - proceed to reward/outcome
            p.trVars.currentState = p.state.sacComplete;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
        elseif ~eyeInChosenTarget
            % Gaze left target window before hold complete
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            disp('target break');
        end

    case p.state.sacComplete
        % Trial completed - determine outcome and deliver reward

        % Classify outcome based on chosen side and high salience location
        if p.trData.chosenSide == p.trVars.highSalienceSide
            % Chose high-salience target
            p.trData.choseHighSalience = true;
            p.trData.outcome = 'CHOSE_HIGH_SAL';
            p.trData.outcomeCode = 1;
        else
            % Chose low-salience target
            p.trData.choseHighSalience = false;
            p.trData.outcome = 'CHOSE_LOW_SAL';
            p.trData.outcomeCode = 2;
        end

        % Determine reward based on chosen SIDE (left or right)
        if p.trData.chosenSide == 1
            % Chose LEFT target
            p.trVars.currentRewardDuration = p.trVars.rewardDurationLeft;
        else
            % Chose RIGHT target
            p.trVars.currentRewardDuration = p.trVars.rewardDurationRight;
        end

        if p.trData.timing.reward < 0
            % Reward not yet delivered - deliver it now
            % Temporarily set rewardDurationMs for the pds.deliverReward function
            p.trVars.rewardDurationMs = p.trVars.currentRewardDuration;
            p = pds.deliverReward(p);
        elseif p.trData.timing.reward > 0
            % Check if post-reward delay has elapsed
            rewardEndTime = p.trData.timing.reward + ...
                p.trVars.postRewardDuration + ...
                p.rig.dp.dacPadDur + ...
                p.trVars.currentRewardDuration/1000;
            if timeNow > rewardEndTime
                p.trVars.exitWhileLoop = true;
            end
        end

    case p.state.fixBreak
        p.trData.outcome = 'FIX_BREAK';
        p.trData.outcomeCode = 3;
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.joyBreak
        p.trData.outcome = 'JOY_BREAK';
        p.trData.outcomeCode = 4;
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.nonStart
        p.trData.outcome = 'NON_START';
        p.trData.outcomeCode = 5;
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.noResponse
        p.trData.outcome = 'NO_RESPONSE';
        p.trData.outcomeCode = 6;
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.inaccurate
        p.trData.outcome = 'INACCURATE';
        p.trData.outcomeCode = 7;
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
end

% On trial exit, reset visual elements to background
if p.trVars.exitWhileLoop
    p.draw.color.fix = p.draw.color.background;
    p.draw.color.fixWin = p.draw.color.background;
    p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
    p.draw.targWinPenDraw = p.draw.targWinPenThin;
    p.trData.trialEndState = p.trVars.currentState;
end

end

%% -------------------- TIMING MACHINE --------------------
function p = timingMachine(p)
% Controls timing of stimulus events with delta-t manipulation.
% Delta-t = stimulus onset time relative to go signal
%   Negative delta-t: stimuli appear BEFORE go signal
%   Positive delta-t: stimuli appear AFTER go signal

timeNow = GetSecs - p.trData.timing.trialStartPTB;
p.trData.timing.frameNow = fix(timeNow * p.rig.refreshRate);

% Only process timing events after fixation is acquired
if p.trData.timing.fixAq > 0
    timeFromFixAq = timeNow - p.trData.timing.fixAq;

    % Calculate stimulus onset time relative to fixation acquisition
    % timeStimOnset = timeGoSignal + deltaT (deltaT in seconds)
    stimOnsetTime = p.trVars.timeStimOnset;

    % Check if stimuli should turn ON
    if timeFromFixAq >= stimOnsetTime && ~p.trVars.stimuliVisible
        % Turn on BOTH stimuli simultaneously
        p.trVars.stimuliVisible = true;
        if p.trData.timing.stimOn < 0 && ...
                ~ismember('stimOn', p.trVars.postFlip.varNames)
            p.init.strb.addValueOnce(p.init.codes.targetOn);
            p.trVars.postFlip.logical = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOn';
        end
    end
end

end

%% -------------------- DRAW MACHINE --------------------
function p = drawMachine(p)
% Handles all visual display updates. Draws fixation, two target stimuli,
% windows, and eye position marker.

timeNow = GetSecs - p.trData.timing.trialStartPTB;

%% Draw frame if enough time has elapsed since last frame
frameDue = p.trData.timing.lastFrameTime + ...
    p.rig.frameDuration - p.rig.magicNumber;

if timeNow > frameDue

    % Fill background (color is set per-trial in nextParams based on hue condition)
    Screen('FillRect', p.draw.window, p.draw.color.background);

    % Draw grid overlay for experimenter
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], ...
        p.draw.color.gridMajor);

    % Draw eye position marker
    eyeRect = [...
        p.trVars.eyePixX p.trVars.eyePixY ...
        p.trVars.eyePixX p.trVars.eyePixY] + ...
        [-1 -1 1 1]*p.draw.eyePosWidth + ...
        repmat(p.draw.middleXY, 1, 2);
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, eyeRect);

    % Draw LEFT target window frame
    leftTargWinRect = repmat(p.draw.leftTargPointPix, 1, 2) + ...
        [-p.draw.targWinWidthPix -p.draw.targWinHeightPix ...
         p.draw.targWinWidthPix p.draw.targWinHeightPix];
    Screen('FrameRect', p.draw.window, p.draw.color.targWin, ...
        leftTargWinRect, p.draw.targWinPenDraw);

    % Draw RIGHT target window frame
    rightTargWinRect = repmat(p.draw.rightTargPointPix, 1, 2) + ...
        [-p.draw.targWinWidthPix -p.draw.targWinHeightPix ...
         p.draw.targWinWidthPix p.draw.targWinHeightPix];
    Screen('FrameRect', p.draw.window, p.draw.color.targWin, ...
        rightTargWinRect, p.draw.targWinPenDraw);

    % Draw high-reward indicator (green frame around high-reward target)
    % Phase 1: both equal (show both with same indicator)
    % Phase 2: right is high reward
    % Phase 3: left is high reward
    if p.trVars.phaseNumber == 1
        % Equal rewards - show small green indicator on both
        leftRewardRect = repmat(p.draw.leftTargPointPix, 1, 2) + ...
            fix(1.1 * [-p.draw.targWinWidthPix -p.draw.targWinHeightPix ...
            p.draw.targWinWidthPix p.draw.targWinHeightPix]);
        rightRewardRect = repmat(p.draw.rightTargPointPix, 1, 2) + ...
            fix(1.1 * [-p.draw.targWinWidthPix -p.draw.targWinHeightPix ...
            p.draw.targWinWidthPix p.draw.targWinHeightPix]);
        Screen('FrameRect', p.draw.window, p.draw.clutIdx.expGreen_subBg, ...
            leftRewardRect, p.draw.targWinPenThin);
        Screen('FrameRect', p.draw.window, p.draw.clutIdx.expGreen_subBg, ...
            rightRewardRect, p.draw.targWinPenThin);
    elseif p.trVars.rewardRatioLeft > p.trVars.rewardRatioRight
        % LEFT is high reward (phase 3)
        rewardRect = repmat(p.draw.leftTargPointPix, 1, 2) + ...
            fix(1.1 * [-p.draw.targWinWidthPix -p.draw.targWinHeightPix ...
            p.draw.targWinWidthPix p.draw.targWinHeightPix]);
        Screen('FrameRect', p.draw.window, p.draw.clutIdx.expGreen_subBg, ...
            rewardRect, p.draw.targWinPenDraw);
    else
        % RIGHT is high reward (phase 2)
        rewardRect = repmat(p.draw.rightTargPointPix, 1, 2) + ...
            fix(1.1 * [-p.draw.targWinWidthPix -p.draw.targWinHeightPix ...
            p.draw.targWinWidthPix p.draw.targWinHeightPix]);
        Screen('FrameRect', p.draw.window, p.draw.clutIdx.expGreen_subBg, ...
            rewardRect, p.draw.targWinPenDraw);
    end

    % Draw fixation window frame
    fixWinRect = repmat(p.draw.fixPointPix, 1, 2) + ...
        [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix ...
         p.draw.fixWinWidthPix p.draw.fixWinHeightPix];
    Screen('FrameRect', p.draw.window, p.draw.color.fixWin, ...
        fixWinRect, p.draw.fixWinPenDraw);

    % Draw target stimuli if they should be visible
    if p.trVars.stimuliVisible
        % Draw both bullseyes simultaneously
        % Each target has its own hue based on salience:
        %   - High salience target: 180° from background (max contrast)
        %   - Low salience target: 45° from background (low contrast)
        % Hue assignments are set in nextParams.m based on highSalienceSide

        leftHueIdx = p.trVars.leftTargHueIdx;
        rightHueIdx = p.trVars.rightTargHueIdx;

        % Compute bullseye sizes in pixels
        stimSize_pix_outer = pds.deg2pix(p.draw.bullseyeOuterDeg, p);
        stimSize_pix_inner = pds.deg2pix(p.draw.bullseyeInnerDeg, p);

        % Draw LEFT target bullseye (outer ring then inner ring)
        leftRect_outer = CenterRectOnPoint(...
            [0 0 stimSize_pix_outer stimSize_pix_outer], ...
            p.draw.leftTargPointPix(1), p.draw.leftTargPointPix(2));
        Screen('FrameRect', p.draw.window, leftHueIdx, ...
            leftRect_outer, p.trVarsInit.targWidth);

        leftRect_inner = CenterRectOnPoint(...
            [0 0 stimSize_pix_inner stimSize_pix_inner], ...
            p.draw.leftTargPointPix(1), p.draw.leftTargPointPix(2));
        Screen('FrameRect', p.draw.window, leftHueIdx, ...
            leftRect_inner, p.trVarsInit.targWidth);

        % Draw RIGHT target bullseye
        rightRect_outer = CenterRectOnPoint(...
            [0 0 stimSize_pix_outer stimSize_pix_outer], ...
            p.draw.rightTargPointPix(1), p.draw.rightTargPointPix(2));
        Screen('FrameRect', p.draw.window, rightHueIdx, ...
            rightRect_outer, p.trVarsInit.targWidth);

        rightRect_inner = CenterRectOnPoint(...
            [0 0 stimSize_pix_inner stimSize_pix_inner], ...
            p.draw.rightTargPointPix(1), p.draw.rightTargPointPix(2));
        Screen('FrameRect', p.draw.window, rightHueIdx, ...
            rightRect_inner, p.trVarsInit.targWidth);
    end

    % Draw fixation point (if visible)
    if p.trVars.fixationVisible
        fixRect = repmat(p.draw.fixPointPix, 1, 2) + ...
            p.draw.fixPointRadius*[-1 -1 1 1];
        Screen('FrameRect', p.draw.window, p.draw.color.fix, ...
            fixRect, p.draw.fixPointWidth);
    end

    % Execute flip and record timing
    p.trData.timing.flipTime(p.trVars.flipIdx) = ...
        Screen('Flip', p.draw.window, GetSecs + 0.00);
    p.trData.timing.lastFrameTime = ...
        p.trData.timing.flipTime(p.trVars.flipIdx) - ...
        p.trData.timing.trialStartPTB;

    % Strobe all queued event codes after flip
    if p.init.strb.armedToStrobe
        p.init.strb.strobeList;
    end

    % Record timing of stimulus events based on flip time
    if p.trVars.postFlip.logical
        for j = 1:length(p.trVars.postFlip.varNames)
            varName = p.trVars.postFlip.varNames{j};
            if p.trData.timing.(varName) < 0
                p.trData.timing.(varName) = p.trData.timing.lastFrameTime;
            end
        end
        p.trVars.postFlip.logical = false;
        p.trVars.postFlip.varNames = cell(0);
    end

    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end

end

%% -------------------- ONLINE GAZE CALCULATIONS --------------------
function p = onlineGazeCalcs(p)
% Stores current gaze position and computes online eye velocity.

p.trData.onlineGaze(p.trVars.whileLoopIdx, :) = [...
    p.trVars.eyeDegX, p.trVars.eyeDegY, ...
    GetSecs - p.trData.timing.trialStartPTB, NaN];

if p.trVars.whileLoopIdx > p.trVarsInit.eyeVelFiltTaps
    startIdx = p.trVars.whileLoopIdx - p.trVarsInit.eyeVelFiltTaps + 1;
    endIdx = p.trVars.whileLoopIdx;
    tempDiff = diff(p.trData.onlineGaze(startIdx:endIdx, 1:3));

    velXY = tempDiff(:, 1:2) ./ repmat(tempDiff(:, 3), 1, 2);
    p.trData.onlineGaze(p.trVars.whileLoopIdx, 4) = ...
        sqrt(sum(mean(velXY.^2)));
end

end

%% -------------------- GAZE VELOCITY THRESHOLD CHECK --------------------
function logOut = gazeVelThreshCheck(p, timeNow)
% Returns true if current eye velocity exceeds threshold.

logOut = ...
    p.trData.onlineGaze(p.trVars.whileLoopIdx, 4) > p.trVars.eyeVelThresh;

end

%% -------------------- EYE IN TARGET WINDOW --------------------
function inWindow = eyeInTargetWindow(p, targetID)
% Check if eye position is within specified target window.
% targetID: 'left' or 'right'

if strcmp(targetID, 'left')
    targX = p.trVars.leftTarg_degX;
    targY = p.trVars.leftTarg_degY;
else
    targX = p.trVars.rightTarg_degX;
    targY = p.trVars.rightTarg_degY;
end

% Check if gaze is within target window (using half-widths)
halfWidth = p.trVars.targWinWidthDeg;
halfHeight = p.trVars.targWinHeightDeg;

inWindow = abs(p.trVars.eyeDegX - targX) < halfWidth && ...
           abs(p.trVars.eyeDegY - targY) < halfHeight;

end
