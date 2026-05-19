function p = barsweep_run(p)
%   p = barsweep_run(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% State machine for barsweep task:
%   trialBegun (1) -> showFix (2) -> holdFixAndSweep (3) -> trialComplete (21)
%   Fixation break during sweep -> fixBreak (11)
%   Fixation never acquired      -> nonStart (13)
%
% Emits exactly one trialRunDone strobe at the end of the run loop,
% regardless of outcome. Does NOT emit trialEnd (that is _finish.m's job).

% (0) Post-completion no-op gate. Per the plan's session-termination
% mechanism, the harness still calls _run.m once after _next.m raises
% the session-done flag; short-circuit immediately, no behavioral state
% machine, no flips, no strobes.
if p.trVars.barsweepSessionDone
    p.trVars.exitWhileLoop = true;
    return;
end

% (1) Mark start time in PTB and DP time.
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = ...
    pds.getTimes;

% Hide fixation point initially.
p.draw.color.fix = p.draw.clutIdx.expBg_subBg;

% Online eye-position storage index.
i = 0;

% Frame index into the bar sweep (1..sweepFrames). Persisted on p.trVars
% so state machine and draw machine can both read/write through `p`.
% Incremented after each flip that drew the bar.
p.trVars.sweepFrameIdx = 1;

while ~p.trVars.exitWhileLoop

    p = pds.getEyeJoy(p);

    % Mouse-eye simulation (debug pathway).
    if p.trVars.mouseEyeSim
        p = pds.getMouse(p);
        p.trVars.eyePixX = p.trVars.mouseCursorX - p.draw.middleXY(1);
        p.trVars.eyePixY = p.trVars.mouseCursorY - p.draw.middleXY(2);
        p.trVars.eyeDegX = pds.pix2deg(p.trVars.eyePixX, p);
        p.trVars.eyeDegY = pds.pix2deg(-p.trVars.eyePixY, p);
    end

    i = i + 1;
    p.trData.onlineEyeX(i) = p.trVars.eyeDegX;
    p.trData.onlineEyeY(i) = p.trVars.eyeDegY;

    p = stateMachine(p);
    p = drawMachine(p);

end

% Strobe trialRunDone once, after the run loop exits, regardless of
% outcome. Distinct from trialEnd (which fires in _finish.m). Trial-
% relative timestamp consistent with other timing variables in this file.
p.trData.timing.trialRunDone = GetSecs - p.trData.timing.trialStartPTB;
p.init.strb.strobeNow(p.init.codes.trialRunDone);

end

%% -------------------- STATE MACHINE --------------------
function p = stateMachine(p)

timeNow = GetSecs - p.trData.timing.trialStartPTB;

switch p.trVars.currentState

    case p.state.trialBegun
        % STATE 1: TRIAL BEGUN
        p.init.strb.strobeNow(p.init.codes.trialBegin);
        p.trData.timing.trialBegin = timeNow;
        p.trVars.currentState      = p.state.showFix;

    case p.state.showFix
        % STATE 2: SHOW FIXATION POINT, WAIT FOR ACQUISITION
        p.draw.color.fix    = p.draw.clutIdx.expWhite_subWhite;
        p.draw.color.fixWin = p.draw.clutIdx.expGrey25_subBg;
        p.draw.fixWinPenDraw = p.draw.fixWinPenPre;

        if p.trData.timing.fixOn < 0 ...
                && ~ismember('fixOn', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
            p.init.strb.addValueOnce(p.init.codes.fixOn);
        end

        if pds.eyeInWindow(p) && p.trData.timing.fixOn > 0 && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            p.init.strb.strobeNow(p.init.codes.fixAq);
            p.trData.timing.fixAq = timeNow;
            p.trVars.currentState = p.state.holdFixAndSweep;

        elseif p.trData.timing.fixOn > 0 && ...
                timeNow > (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            p.init.strb.strobeNow(p.init.codes.nonStart);
            p.trData.timing.nonStart = timeNow;
            p.trVars.currentState = p.state.nonStart;
        end

    case p.state.holdFixAndSweep
        % STATE 3: HOLD FIXATION AND PRESENT SWEEP
        % Per the plan's ordering rule: fixation-break check fires
        % BEFORE the completion-transition check. Reward is reachable
        % only via trialComplete, which is only entered when fixation
        % was in-window on every visible-bar frame including the last.
        p.draw.fixWinPenDraw = p.draw.fixWinPenPost;

        % Arm stimOn post-flip and strobe on the first iteration in
        % this state (before the first bar flip).
        if p.trData.timing.stimOn < 0 ...
                && ~ismember('stimOn', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOn';
            p.init.strb.addValueOnce(p.init.codes.stimOn);
        end

        % (3a) Fixation-break check FIRST.
        if ~pds.eyeInWindow(p)
            % fixBreak is a BEHAVIORAL event -> strobeNow immediately.
            % The visual consequences (bar removed, fix point removed)
            % happen on the next flip and are tagged via postFlip.
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;
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
            return;
        end

        % (3b) Completion check (only with fixation still held).
        % p.trVars.sweepFrameIdx is the frame ABOUT to be drawn this
        % iteration; drawMachine increments it after a successful flip.
        % If sweepFrameIdx > sweepFrames, the bar has already been drawn
        % for sweepFrames flips; arm stimOff and fixOff for the next
        % blank flip, hide the fix point, and gate the transition to
        % trialComplete on stimOff being assigned (i.e., the next flip
        % happened and the queued stimOff strobe was flushed). This
        % prevents the reward strobeNow from racing ahead of the stimOff
        % postFlip strobe when run-loop iterations outpace frame flips.
        if p.trVars.sweepFrameIdx > p.trVars.sweepFrames
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
                p.trVars.currentState = p.state.trialComplete;
            end
        end

    case p.state.trialComplete
        % STATE 21: SWEEP COMPLETE -- DELIVER REWARD
        if p.trData.timing.reward < 0
            p = pds.deliverReward(p);
        end

        % Wait through the reward pulse, then exit. The plan-mandated
        % postRewardDuration WaitSecs lives in _finish.m (single source
        % of truth). Here we only ensure the reward solenoid pulse has
        % finished before letting the run loop exit.
        if p.trData.timing.reward > 0 && ...
                (timeNow - p.trData.timing.reward) > ...
                (p.rig.dp.dacPadDur + (p.trVars.rewardDurationMs / 1000))
            p.trVars.exitWhileLoop = true;
        end

    case p.state.fixBreak
        % STATE 11: FIXATION BREAK
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.nonStart
        % STATE 13: NON-START
        p.trVars.exitWhileLoop = true;
end

if p.trVars.exitWhileLoop
    p.draw.color.fix    = p.draw.color.background;
    p.draw.color.fixWin = p.draw.color.background;
    p.trData.trialEndState = p.trVars.currentState;
end

end

%% -------------------- DRAW MACHINE --------------------
function p = drawMachine(p)

timeNow = GetSecs - p.trData.timing.trialStartPTB;

% Only draw when it's time for the next screen flip.
if timeNow > p.trData.timing.lastFrameTime + ...
        p.rig.frameDuration - p.rig.magicNumber

    % 1. Background.
    bgClut = p.stim.luminanceLevels(p.trVars.backgroundLumIdx);
    Screen('FillRect', p.draw.window, bgClut);

    % 2. Grid.
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], ...
        p.draw.color.gridMajor);

    % 3. Eye position indicator.
    gazePosition = ...
        [p.trVars.eyePixX p.trVars.eyePixY ...
         p.trVars.eyePixX p.trVars.eyePixY] + ...
        [-1 -1 1 1] * p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2);
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, gazePosition);

    % 4. Fixation window (drawn before the bar so its background-colored
    % outline on the subject display does not cut a slot out of the bar
    % where the two overlap).
    if ~isempty(p.draw.fixWinPenDraw)
        Screen('FrameRect', p.draw.window, p.draw.color.fixWin, ...
            repmat(p.draw.fixPointPix, 1, 2) + ...
            [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix ...
              p.draw.fixWinWidthPix  p.draw.fixWinHeightPix], ...
            p.draw.fixWinPenDraw);
    end

    % 5. Bar (only during holdFixAndSweep, only for visible frames).
    drewBar = false;
    if p.trVars.currentState == p.state.holdFixAndSweep && ...
            p.trVars.sweepFrameIdx <= p.trVars.sweepFrames
        f = p.trVars.sweepFrameIdx;
        cx = p.trVars.sweepCenterPix(1, f);
        cy = p.trVars.sweepCenterPix(2, f);
        destRect = CenterRectOnPoint(p.draw.barDestRectAtOrigin, cx, cy);
        Screen('DrawTexture', p.draw.window, ...
            p.trVars.barTextures(f), [], destRect, ...
            p.trVars.barRotationDeg, 0);

        % Sweep endpoints overlay (experimenter display).
        Screen('FrameOval', p.draw.window, p.draw.color.gridMajor, ...
            [p.trVars.sweepStartPix(1) - 4, p.trVars.sweepStartPix(2) - 4, ...
             p.trVars.sweepStartPix(1) + 4, p.trVars.sweepStartPix(2) + 4]);
        Screen('FrameOval', p.draw.window, p.draw.color.gridMajor, ...
            [p.trVars.sweepEndPix(1) - 4, p.trVars.sweepEndPix(2) - 4, ...
             p.trVars.sweepEndPix(1) + 4, p.trVars.sweepEndPix(2) + 4]);

        drewBar = true;
    end

    % 6. Fixation point (kept on top so the animal always has a fixation
    % anchor, even when the bar passes through the fovea).
    Screen('FrameRect', p.draw.window, p.draw.color.fix, ...
        repmat(p.draw.fixPointPix, 1, 2) + ...
        p.draw.fixPointRadius * [-1 -1 1 1], p.draw.fixPointWidth);

    % 7. Flip and store time.
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, ~] = ...
        Screen('Flip', p.draw.window);
    p.trData.timing.lastFrameTime = ...
        p.trData.timing.flipTime(p.trVars.flipIdx) - ...
        p.trData.timing.trialStartPTB;

    % 8. Strobe pending values.
    if p.init.strb.armedToStrobe
        p.init.strb.strobeList;
    end

    % 9. postFlip timing assignments.
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

    % 9b. Capture the flip index that rendered stimOn. Runs after the
    % postFlip block (so timing.stimOn has just been assigned a real
    % timestamp) and before flipIdx increments below, so flipIdx still
    % points at the flip that just rendered the bar's first frame.
    % accumulateBarsweepRF slices flipTime starting at this index.
    if p.trData.timing.stimOn > 0 && p.trData.timing.flipIdxStimOn < 0
        p.trData.timing.flipIdxStimOn = p.trVars.flipIdx;
    end

    % 10. Increment flip index; advance sweep frame iff a bar frame
    % was actually drawn (not on pre/post-sweep blank flips).
    p.trVars.flipIdx = p.trVars.flipIdx + 1;
    if drewBar
        p.trVars.sweepFrameIdx = p.trVars.sweepFrameIdx + 1;
    end
end

end
