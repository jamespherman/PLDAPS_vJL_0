function p = gSac_4factors_run(p)
%   p = gSac_4factors_run(p)
%
% Main trial execution function for the 4-factors guided saccade task.
% Contains the state machine, drawing routines, and timing logic.

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
        p.trVars.eyePixX   = ...
            p.trVars.mouseCursorX - p.draw.middleXY(1);
        p.trVars.eyePixY   = ...
            p.trVars.mouseCursorY - p.draw.middleXY(2);
        p.trVars.eyeDegX   = pds.pix2deg(p.trVars.eyePixX, p);
        p.trVars.eyeDegY   = pds.pix2deg(-p.trVars.eyePixY, p);
    end

    % Store gaze position and compute online eye velocity
    p = onlineGazeCalcs(p);

    % STATE MACHINE: handle state transitions based on behavior
    p = stateMachine(p);

    % TIMING MACHINE: handle stimulus timing events
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
        p.trData.timing.trialBegin      = timeNow;
        p.trVars.currentState        = p.state.waitForJoy;

    case p.state.waitForJoy
        % Waiting for subject to press joystick to initiate trial
        if pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyPress);
            p.trData.timing.joyPress    = timeNow;
            p.trVars.currentState    = p.state.showFix;
        elseif ~pds.joyHeld(p) && (timeNow > p.trVars.joyWaitDur)
            % Joystick not pressed within allowed time
            p.trVars.currentState    = p.state.nonStart;
        end

    case p.state.showFix
        % Fixation point is visible - waiting for eye to enter window
        p.draw.color.fix    = p.draw.clutIdx.expBlack_subBlack;
        p.draw.color.fixWin = p.draw.clutIdx.expGrey70_subBg;
        p.draw.fixWinPenDraw = p.draw.fixWinPenThin;

        % Mark fixation onset time on first frame fixation is shown
        if p.trData.timing.fixOn < 0 && ...
                ~ismember('fixOn', p.trVars.postFlip.varNames)
            p.init.strb.addValueOnce(p.init.codes.fixOn);
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
        end

        % Check if eye entered fixation window while holding joystick
        if pds.eyeInWindow(p) && pds.joyHeld(p) && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            p.init.strb.addValue(p.init.codes.fixAq);
            p.trData.timing.fixAq      = timeNow;
            p.trVars.currentState      = p.state.dontMove;
        elseif ~pds.joyHeld(p)
            % Joystick released before fixation acquired
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.joyBreak;
        elseif timeNow > (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            % Fixation not acquired within allowed time
            p.init.strb.addValue(p.init.codes.nonStart);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.nonStart;
        end

    case p.state.dontMove
        % Subject is fixating - waiting for go signal (fixation offset)

        % Set target window color for experimenter display
        p.draw.color.targWin = p.draw.clutIdx.expGrey70_subBg;

        % Thicken fixation window outline to indicate acquired fixation
        p.draw.fixWinPenDraw = p.draw.fixWinPenThick;

        % Check if delay period has elapsed (time for go signal)
        if (timeNow - p.trData.timing.fixAq) > p.trVars.timeFixOffset
            p.init.strb.addValue(p.init.codes.fixOff);
            if p.trData.timing.fixOff < 0 && ...
                    ~ismember('fixOff', p.trVars.postFlip.varNames)
                p.trVars.postFlip.logical           = true;
                p.trVars.postFlip.varNames{end + 1} = 'fixOff';
            end
            p.trVars.currentState     = p.state.makeSaccade;
        elseif ~pds.eyeInWindow(p)
            % Eye left fixation window during delay
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
        elseif ~pds.joyHeld(p)
            % Joystick released during delay
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.joyBreak;
        end

    case p.state.makeSaccade
        % Go signal given - subject should make saccade to target

        % Hide fixation point by setting color to background
        p.draw.color.fix = p.draw.color.background;

        % Check for joystick release (failure condition)
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState       = p.state.joyBreak;
        end

        % Calculate time since go signal
        timeSinceGo = timeNow - p.trData.timing.fixOff;

        % Check for premature saccade (before minimum latency)
        if ~pds.eyeInWindow(p) && timeSinceGo < p.trVars.goLatencyMin
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;

        % Check for valid saccade initiation within latency window
        elseif ~pds.eyeInWindow(p) && ...
                timeSinceGo > p.trVars.goLatencyMin && ...
                timeSinceGo < p.trVars.goLatencyMax && ...
                (gazeVelThreshCheck(p, timeNow) || p.trVars.passEye)
            p.init.strb.addValue(p.init.codes.saccadeOnset);
            p.trData.timing.saccadeOnset    = timeNow;
            p.trVars.currentState           = p.state.checkLanding;
            p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
            disp('saccadeMade')

        % Check for failure to initiate saccade in time
        elseif timeSinceGo > p.trVars.goLatencyMax
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            disp('fixBreak')
            disp(num2str(p.trVars.goLatencyMax))
        end

    case p.state.checkLanding
        % Saccade initiated - checking where it lands

        % Check for joystick release during saccade
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState = p.state.joyBreak;
        end

        % Check if saccade is still in flight (high velocity)
        sacInFlight = gazeVelThreshCheck(p, timeNow);

        % Get gaze samples since fixation offset for blink detection
        sinceFixOffLogical = ...
            p.trData.onlineGaze(:,3) > p.trData.timing.fixOff & ...
            p.trData.onlineGaze(:,3) < timeNow;

        % Detect blinks: gaze position > 35 deg indicates blink artifact
        blinkDetected = ...
            any(any(abs(p.trData.onlineGaze(sinceFixOffLogical, 1:2)) ...
            > 35));

        % Check if gaze is within target window
        gazeInTargetWin = pds.eyeInWindow(p, 'target');

        if sacInFlight
            % Saccade still in flight - continue waiting

        elseif blinkDetected
            % Blink detected during saccade - abort trial
            disp('blink detected');
            p.init.strb.addValue(p.init.codes.blinkDuringSac);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;

        elseif gazeInTargetWin || p.trVars.passEye
            % Saccade landed in target window - success so far
            p.init.strb.addValue(p.init.codes.saccadeOffset);
            p.trData.timing.saccadeOffset = timeNow;
            p.trVars.currentState = p.state.holdTarg;
            p.init.strb.addValue(p.init.codes.targetAq);
            p.trData.timing.targetAq = timeNow;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
            disp('targHold')

        elseif ~gazeInTargetWin || ~p.trVars.passEye
            % Saccade landed outside target window - failure
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            disp('fixBreak')
        end

    case p.state.holdTarg
        % Gaze in target window - must hold fixation for reward

        % Check for joystick release
        if ~pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.trData.timing.joyRelease  = timeNow;
            p.trVars.currentState = p.state.joyBreak;
        end

        eyeInTargetWin = pds.eyeInWindow(p, 'target');

        % Check if target hold duration has been met
        holdTimeElapsed = ...
            timeNow > p.trData.timing.saccadeOffset + ...
            p.trVars.targHoldDuration;

        if eyeInTargetWin && holdTimeElapsed
            % Successfully held target - proceed to reward
            p.trVars.currentState = p.state.sacComplete;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
        elseif ~eyeInTargetWin
            % Gaze left target window before hold complete
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            disp('target break');
        end

    case p.state.sacComplete
        % Trial completed successfully - deliver reward
        if p.trData.timing.reward < 0
            % Reward not yet delivered - deliver it now
            p = pds.deliverReward(p);
        elseif p.trData.timing.reward > 0
            % Check if post-reward delay has elapsed
            rewardEndTime = p.trData.timing.reward + ...
                p.trVars.postRewardDuration + ...
                p.rig.dp.dacPadDur + ...
                p.trVars.rewardDurationMs/1000;
            if timeNow > rewardEndTime
                p.trVars.exitWhileLoop = true;
            end
        end

    case p.state.fixBreak
        % Trial ended due to fixation break - play error tone
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.joyBreak
        % Trial ended due to joystick release - play error tone
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.nonStart
        % Trial ended due to failure to initiate - play error tone
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

%% -------------------- DRAW MACHINE --------------------
function p = drawMachine(p)
% Handles all visual display updates. Draws stimuli, windows, and
% eye position marker. Updates occur at frame rate.

timeNow = GetSecs - p.trData.timing.trialStartPTB;

%% Set dynamic background color based on stimulus type
% Each stimulus condition has a unique background for the subject
switch p.trVars.stimType
    case {1, 2}
        % Face or Non-Face Image Trial: grey background
        p.draw.color.background = p.draw.clutIdx.expGrey_subBg;
    case 3
        % Bullseye High Salience, Target 0 deg: 180 deg DKL background
        p.draw.color.background = p.draw.clutIdx.expDkl180_subDkl180;
    case 4
        % Bullseye Low Salience, Target 0 deg: 45 deg DKL background
        p.draw.color.background = p.draw.clutIdx.expDkl45_subDkl45;
    case 5
        % Bullseye High Salience, Target 180 deg: 0 deg DKL background
        p.draw.color.background = p.draw.clutIdx.expDkl0_subDkl0;
    case 6
        % Bullseye Low Salience, Target 180 deg: 225 deg DKL background
        p.draw.color.background = p.draw.clutIdx.expDkl225_subDkl225;
end

%% Draw frame if enough time has elapsed since last frame
frameDue = p.trData.timing.lastFrameTime + ...
    p.rig.frameDuration - p.rig.magicNumber;

if timeNow > frameDue

    % Fill background
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

    % Draw target window frame
    targWinRect = repmat(p.draw.targPointPix, 1, 2) + ...
        [-p.draw.targWinWidthPix -p.draw.targWinHeightPix ...
         p.draw.targWinWidthPix p.draw.targWinHeightPix];
    Screen('FrameRect', p.draw.window, p.draw.color.targWin, ...
        targWinRect, p.draw.targWinPenDraw);

    % Draw fixation window frame
    fixWinRect = repmat(p.draw.fixPointPix, 1, 2) + ...
        [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix ...
         p.draw.fixWinWidthPix p.draw.fixWinHeightPix];
    Screen('FrameRect', p.draw.window, p.draw.color.fixWin, ...
        fixWinRect, p.draw.fixWinPenDraw);

    % Draw high-reward indicator if applicable
    if p.trVars.reward == 1
        rewardRect = repmat(p.draw.targPointPix, 1, 2) + ...
            fix(1.1 * [-p.draw.targWinWidthPix ...
            -p.draw.targWinHeightPix ...
            p.draw.targWinWidthPix p.draw.targWinHeightPix]);
        Screen('FrameRect', p.draw.window, ...
            p.draw.clutIdx.expGreen_subBg, ...
            rewardRect, p.draw.targWinPenDraw);
    end

    % Draw target stimulus if it should be visible
    if p.trVars.targetIsOn
        if p.trVars.stimType <= 2
            % Image trial: draw texture (face or non-face)
            stimSize_pix = pds.deg2pix(p.stim.stimDiamDeg, p);
            targRect = CenterRectOnPoint(...
                [0 0 stimSize_pix stimSize_pix], ...
                p.draw.targPointPix(1), p.draw.targPointPix(2));
            try
                Screen('DrawTexture', p.draw.window, ...
                    p.stim.currentTexture, [], targRect);
            catch me
                keyboard
            end
        else
            % Bullseye trial: draw concentric rectangular rings

            % Determine target hue based on stimulus type
            if p.trVars.stimType <= 4
                % Type A target: 0 deg DKL hue
                target_hue_idx = p.draw.clutIdx.expDkl0_subDkl0;
            else
                % Type B target: 180 deg DKL hue
                target_hue_idx = p.draw.clutIdx.expDkl180_subDkl180;
            end

            % Draw outer ring at 4 degrees
            stimSize_pix_outer = pds.deg2pix(4, p);
            targRect_outer = CenterRectOnPoint(...
                [0 0 stimSize_pix_outer stimSize_pix_outer], ...
                p.draw.targPointPix(1), p.draw.targPointPix(2));
            Screen('FrameRect', p.draw.window, target_hue_idx, ...
                targRect_outer, p.trVarsInit.targWidth);

            % Draw inner ring at 2 degrees
            stimSize_pix_inner = pds.deg2pix(2, p);
            targRect_inner = CenterRectOnPoint(...
                [0 0 stimSize_pix_inner stimSize_pix_inner], ...
                p.draw.targPointPix(1), p.draw.targPointPix(2));
            Screen('FrameRect', p.draw.window, target_hue_idx, ...
                targRect_inner, p.trVarsInit.targWidth);
        end
    end

    % Draw fixation point
    fixRect = repmat(p.draw.fixPointPix, 1, 2) + ...
        p.draw.fixPointRadius*[-1 -1 1 1];
    Screen('FrameRect', p.draw.window, p.draw.color.fix, ...
        fixRect, p.draw.fixPointWidth);

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
        % Loop over variable names and assign flip time
        for j = 1:length(p.trVars.postFlip.varNames)
            varName = p.trVars.postFlip.varNames{j};
            if p.trData.timing.(varName) < 0
                p.trData.timing.(varName) = ...
                    p.trData.timing.lastFrameTime;
            end
        end
        % Reset post-flip tracking
        p.trVars.postFlip.logical  = false;
        p.trVars.postFlip.varNames = cell(0);
    end

    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end

end

%% -------------------- ONLINE GAZE CALCULATIONS --------------------
function p = onlineGazeCalcs(p)
% Stores current gaze position and computes online eye velocity.
% Used for saccade detection during the trial.

% Store [X, Y, time, velocity] for this sample
p.trData.onlineGaze(p.trVars.whileLoopIdx, :) = [...
    p.trVars.eyeDegX, p.trVars.eyeDegY, ...
    GetSecs - p.trData.timing.trialStartPTB, NaN];

% Compute velocity once we have enough samples for the filter
if p.trVars.whileLoopIdx > p.trVarsInit.eyeVelFiltTaps

    % Get recent samples for velocity calculation
    startIdx = p.trVars.whileLoopIdx - p.trVarsInit.eyeVelFiltTaps + 1;
    endIdx = p.trVars.whileLoopIdx;
    tempDiff = diff(p.trData.onlineGaze(startIdx:endIdx, 1:3));

    % Compute velocity: sqrt of mean squared velocity in X and Y
    velXY = tempDiff(:, 1:2) ./ repmat(tempDiff(:, 3), 1, 2);
    p.trData.onlineGaze(p.trVars.whileLoopIdx, 4) = ...
        sqrt(sum(mean(velXY.^2)));
end

end

%% -------------------- GAZE VELOCITY THRESHOLD CHECK --------------------
function logOut = gazeVelThreshCheck(p, timeNow)
% Returns true if current eye velocity exceeds threshold.
% Used to detect saccade onset and offset.

logOut = ...
    p.trData.onlineGaze(p.trVars.whileLoopIdx, 4) > p.trVars.eyeVelThresh;

end

%% -------------------- TIMING MACHINE --------------------
function p = timingMachine(p)
% Controls timing of stimulus events (target onset/offset).
% Timing is relative to fixation acquisition.

timeNow = GetSecs - p.trData.timing.trialStartPTB;
p.trData.timing.frameNow = fix(timeNow * p.rig.refreshRate);

% Only process timing events after fixation is acquired
if p.trData.timing.fixAq > 0
    timeFromFixAq = timeNow - p.trData.timing.fixAq;

    % Check if target should turn ON
    targetOnWindow = timeFromFixAq >= p.trVars.timeTargOnset && ...
        timeFromFixAq < p.trVars.timeTargOffset;

    if targetOnWindow && p.trData.timing.targetOn < 0
        % Target onset time reached
        p.trVars.targetIsOn = true;
        if ~ismember('targetOn', p.trVars.postFlip.varNames)
            p.init.strb.addValueOnce(p.init.codes.targetOn);
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'targetOn';
        end

    % Check for target re-illumination (memory-guided saccade)
    elseif ~p.trVars.isVisSac && ...
            (p.trVars.currentState == p.state.holdTarg || ...
            (p.trData.timing.fixOff > 0 && ...
            p.trVars.targTrainingDelay >= 0 && ...
            timeNow > (p.trData.timing.fixOff + ...
            p.trVars.targTrainingDelay)))
        p.trVars.targetIsOn = true;
        if p.trData.timing.targetReillum < 0 && ...
                ~ismember('targetReillum', p.trVars.postFlip.varNames)
            p.init.strb.addValueOnce(p.init.codes.targetReillum);
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'targetReillum';
        end

    % Check if target should turn OFF
    elseif ~(timeFromFixAq < p.trVars.timeTargOffset)
        p.trVars.targetIsOn = false;
        if p.trData.timing.targetOff < 0 && ...
                p.trData.timing.targetOn > 0 && ...
                ~ismember('targetOff', p.trVars.postFlip.varNames)
            p.init.strb.addValueOnce(p.init.codes.targetOff);
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'targetOff';
        end
    end
end

end
