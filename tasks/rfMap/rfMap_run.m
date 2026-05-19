function p = rfMap_run(p)
%   p = rfMap_run(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% State machine for rfMap task:
%   trialBegun (1) -> showFix (2) -> holdFixAndPlay (3) -> noiseComplete (21)
%   Fixation break during noise -> fixBreak (11)
%   Fixation never acquired -> nonStart (13)

% If movie is exhausted, exit immediately (nextParams already flagged this)
if p.trVars.movieExhausted
    p.trVars.exitWhileLoop = true;
    return;
end

% (1) mark start time in PTB and DP time:
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = ...
    pds.getTimes;

% hide fixation point initially
p.draw.color.fix = p.draw.clutIdx.expBg_subBg;

% initialize online eye position storage index:
i = 0;

% Loop until the trial is over
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

    % DRAW section
    p = drawMachine(p);

end % while loop

% Strobe trialRunDone once, after the run loop exits, regardless of
% outcome. Distinct from trialEnd (which fires in _finish.m after the
% paired info strobes). Trial-relative timestamp consistent with other
% timing variables in this file.
p.trData.timing.trialRunDone = GetSecs - p.trData.timing.trialStartPTB;
p.init.strb.strobeNow(p.init.codes.trialRunDone);

end

%% -------------------- STATE MACHINE --------------------
function p = stateMachine(p)

% timeNow is relative to trial start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

switch p.trVars.currentState

    case p.state.trialBegun
        %% STATE 1: TRIAL HAS BEGUN
        % Strobe trial start and advance to showFix.

        p.init.strb.strobeNow(p.init.codes.trialBegin);
        p.trData.timing.trialBegin = timeNow;
        p.trVars.currentState      = p.state.showFix;

    case p.state.showFix
        %% STATE 2: SHOW FIXATION POINT, WAIT FOR ACQUISITION
        % Show fixation point on gray background. Once monkey fixates,
        % advance to holdFixAndPlay. If timeout, go to nonStart.

        p.draw.color.fix = p.draw.clutIdx.expWhite_subWhite;
        p.draw.color.fixWin = p.draw.clutIdx.expGrey25_subBg;
        p.draw.fixWinPenDraw = p.draw.fixWinPenPre;

        % Mark fixOn via postFlip (once)
        if p.trData.timing.fixOn < 0 ...
                && ~ismember('fixOn', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
            p.init.strb.addValueOnce(p.init.codes.fixOn);
        end

        % Check for fixation acquisition
        if pds.eyeInWindow(p) && p.trData.timing.fixOn > 0 && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)

            p.init.strb.strobeNow(p.init.codes.fixAq);
            p.trData.timing.fixAq = timeNow;
            p.trVars.currentState = p.state.holdFixAndPlay;

        elseif p.trData.timing.fixOn > 0 && ...
                timeNow > (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            % fixation was never acquired
            p.init.strb.strobeNow(p.init.codes.nonStart);
            p.trVars.currentState = p.state.nonStart;
        end

    case p.state.holdFixAndPlay
        %% STATE 3: HOLD FIXATION AND PLAY NOISE
        % Present noise frames while monitoring fixation. On completion,
        % advance to noiseComplete. On fixation break, go to fixBreak.

        % Thicken fixation window to indicate noise is playing
        p.draw.fixWinPenDraw = p.draw.fixWinPenPost;

        % Enable noise display
        p.trVars.noiseIsOn = true;

        % Mark stimOn via postFlip (once)
        if p.trData.timing.stimOn < 0 ...
                && ~ismember('stimOn', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOn';
            p.init.strb.addValueOnce(p.init.codes.stimOn);
            p.trVars.noiseStartFlipIdx = p.trVars.flipIdx;
        end

        % Determine which noise frame to show (time-based)
        if p.trData.timing.stimOn > 0
            displayFramesSinceStimOn = floor( ...
                (timeNow - p.trData.timing.stimOn) / p.rig.frameDuration);
            p.trVars.currentNoiseIdx = floor( ...
                displayFramesSinceStimOn / p.trVars.noiseFrameHold) + 1;
        end

        % Check if all noise frames have been shown
        if p.trVars.currentNoiseIdx > p.trVars.nFramesThisTrial && ...
                p.trData.timing.stimOn > 0
            % Stim presentation complete. Stop drawing noise; hide fix
            % point and fix window on the next flip; tag stimOff and
            % fixOff at that flip via postFlip. Gate the transition to
            % noiseComplete on stimOff actually being assigned (i.e., the
            % flip happened and the queued stimOff strobe was flushed) so
            % the reward strobeNow can't race ahead of the stimOff
            % postFlip strobe.
            p.trVars.noiseIsOn  = false;
            p.draw.color.fix    = p.draw.clutIdx.expBg_subBg;
            p.draw.color.fixWin = p.draw.clutIdx.expBg_subBg;

            if p.trData.timing.stimOff < 0 ...
                    && ~ismember('stimOff', p.trVars.postFlip.varNames)
                p.trVars.postFlip.logical           = true;
                p.trVars.postFlip.varNames{end + 1} = 'stimOff';
                p.init.strb.addValueOnce(p.init.codes.stimOff);
            end
            if p.trData.timing.fixOff < 0 ...
                    && ~ismember('fixOff', p.trVars.postFlip.varNames)
                p.trVars.postFlip.logical           = true;
                p.trVars.postFlip.varNames{end + 1} = 'fixOff';
                p.init.strb.addValueOnce(p.init.codes.fixOff);
            end

            if p.trData.timing.stimOff > 0
                p.trVars.currentState = p.state.noiseComplete;
            end

        elseif ~pds.eyeInWindow(p) && p.trData.timing.stimOn > 0
            % Fixation broken during noise. fixBreak is a BEHAVIORAL
            % event -> strobeNow immediately. The visual consequences
            % (stimOff, fixOff) happen on the next flip and are tagged
            % via postFlip.
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.noiseIsOn  = false;
            p.draw.color.fix    = p.draw.clutIdx.expBg_subBg;
            p.draw.color.fixWin = p.draw.clutIdx.expBg_subBg;

            if p.trData.timing.stimOff < 0 ...
                    && ~ismember('stimOff', p.trVars.postFlip.varNames)
                p.trVars.postFlip.logical           = true;
                p.trVars.postFlip.varNames{end + 1} = 'stimOff';
                p.init.strb.addValueOnce(p.init.codes.stimOff);
            end
            if p.trData.timing.fixOff < 0 ...
                    && ~ismember('fixOff', p.trVars.postFlip.varNames)
                p.trVars.postFlip.logical           = true;
                p.trVars.postFlip.varNames{end + 1} = 'fixOff';
                p.init.strb.addValueOnce(p.init.codes.fixOff);
            end

            p.trVars.currentState = p.state.fixBreak;
        end

    %% ---- End states: trial COMPLETED ----
    case p.state.noiseComplete
        %% STATE 21: NOISE COMPLETE - DELIVER REWARD

        % Deliver reward if not yet delivered
        if p.trData.timing.reward < 0
            p = pds.deliverReward(p);
        end

        % Wait for post-reward duration then exit
        if p.trData.timing.reward > 0 && ...
                (timeNow - p.trData.timing.reward) > ...
                (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + ...
                 (p.trVars.rewardDurationMs / 1000))
            p.trVars.exitWhileLoop = true;
        end

    %% ---- End states: trial ABORTED ----
    case p.state.fixBreak
        %% STATE 11: FIXATION BREAK
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.nonStart
        %% STATE 13: NON-START
        p.trVars.exitWhileLoop = true;
end

% On exit, record trial end state. trialEnd is strobed in _finish.m
% (after pds.strobeTrialData has emitted the paired info strobes), not
% here. trialRunDone is strobed in the caller, after the while loop.
if p.trVars.exitWhileLoop
    p.draw.color.fix    = p.draw.color.background;
    p.draw.color.fixWin = p.draw.color.background;

    p.trData.trialEndState = p.trVars.currentState;
end

end

%% -------------------- DRAW MACHINE --------------------
function p = drawMachine(p)

% timeNow is relative to trial start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% Only draw when it's time for the next screen flip
if timeNow > p.trData.timing.lastFrameTime + ...
        p.rig.frameDuration - p.rig.magicNumber

    % 1. Fill screen with background
    Screen('FillRect', p.draw.window, p.draw.color.background);

    % 2. Draw grid (experimenter display)
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], ...
        p.draw.color.gridMajor);

    % 3. Draw gaze position indicator
    gazePosition = ...
        [p.trVars.eyePixX p.trVars.eyePixY ...
         p.trVars.eyePixX p.trVars.eyePixY] + ...
        [-1 -1 1 1] * p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2);
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, gazePosition);

    % 4. Draw fixation window (drawn before the noise so its background-
    % colored outline on the subject display does not cut a slot out of
    % the noise where the two overlap; the clear patch is much smaller
    % than the window, so most of the window outline sits on noise).
    if ~isempty(p.draw.fixWinPenDraw)
        Screen('FrameRect', p.draw.window, p.draw.color.fixWin, ...
            repmat(p.draw.fixPointPix, 1, 2) + ...
            [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix ...
             p.draw.fixWinWidthPix  p.draw.fixWinHeightPix], ...
            p.draw.fixWinPenDraw);
    end

    % 5. Draw noise texture (if noise is on and valid frame exists)
    if p.trVars.noiseIsOn && p.trVars.currentNoiseIdx >= 1 && ...
            p.trVars.currentNoiseIdx <= p.trVars.nFramesThisTrial

        % Per-stim-type texture lookup. denseAchromatic / sparse /
        % denseChromatic use one texture per noise frame
        % (p.trVars.noiseTextures, generated each trial). Checkerboard
        % uses one of the persistent (size, contrast, polarity) textures
        % pre-rendered at session init.
        if strcmp(p.init.stimType, 'checkerboard')
            polSign = double( ...
                p.trVars.checkPolaritySequence(p.trVars.currentNoiseIdx));
            polIdx  = (polSign < 0) + 1;     % 1 if +1, 2 if -1
            texHandle = p.init.checkInfo.textures( ...
                p.trVars.checkSizeIdx, p.trVars.contrastIdx, polIdx);

            % Detect a polarity flip vs the previous frame and queue a
            % reversal-event strobe. addValue() is buffered; the queued
            % values are written out by p.init.strb.strobeList AFTER the
            % flip below, so we never block the per-flip loop on
            % synchronous DataPixx writes.
            if p.trVars.currentNoiseIdx > 1
                prevPol = double( ...
                    p.trVars.checkPolaritySequence( ...
                        p.trVars.currentNoiseIdx - 1));
                if polSign ~= prevPol
                    p.init.strb.addValue( ...
                        p.init.codes.rfMapCheckReversalEvent);
                    % Map +1 -> 1, -1 -> 2 (so all strobed values are
                    % positive integers per the strobe-code contract).
                    p.init.strb.addValue(polIdx);
                end
            end
        else
            texHandle = p.trVars.noiseTextures(p.trVars.currentNoiseIdx);
        end

        % Draw noise texture with nearest-neighbor filtering (0)
        Screen('DrawTexture', p.draw.window, ...
            texHandle, [], p.draw.noiseDestRect, [], 0);

        % 6. Draw clearing patch over fixation area
        if ~isempty(p.draw.clearPatchRect)
            if p.trVars.clearPatchShape == 1  % disk
                Screen('FillOval', p.draw.window, ...
                    p.draw.color.background, p.draw.clearPatchRect);
            else  % square
                Screen('FillRect', p.draw.window, ...
                    p.draw.color.background, p.draw.clearPatchRect);
            end
        end
    end

    % 7. Draw fixation point (on top of everything)
    Screen('FrameRect', p.draw.window, p.draw.color.fix, ...
        repmat(p.draw.fixPointPix, 1, 2) + ...
        p.draw.fixPointRadius * [-1 -1 1 1], p.draw.fixPointWidth);

    % 8. Flip and store time
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, ~] = ...
        Screen('Flip', p.draw.window);
    p.trData.timing.lastFrameTime = ...
        p.trData.timing.flipTime(p.trVars.flipIdx) - ...
        p.trData.timing.trialStartPTB;

    % 9. Strobe pending values
    if p.init.strb.armedToStrobe
        p.init.strb.strobeList;
    end

    % 10. Handle postFlip timing assignments
    if p.trVars.postFlip.logical
        for j = 1:length(p.trVars.postFlip.varNames)
            if p.trData.timing.(p.trVars.postFlip.varNames{j}) < 0
                p.trData.timing.(p.trVars.postFlip.varNames{j}) = ...
                    p.trData.timing.lastFrameTime;
            end
        end
        p.trVars.postFlip.logical  = false;
        p.trVars.postFlip.varNames = cell(0);
    end

    % 11. Increment flip index
    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end

end

% playTone is in supportFunctions/playTone.m (copied from fixate task)
