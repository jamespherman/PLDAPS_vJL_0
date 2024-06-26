function p = human_psychophysical_threshold_run(p)
%   p = human_psychophysical_threshold_run(p)
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
p.trData.timing.trialStartPTB = GetSecs;

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

    % Get latest gaze position:
    p = pds.getEyelink(p);

    % iterate counter
    i = i + 1;

    % store most recent eye position samples
    p.trData.onlineEyeX(i) = p.trVars.eyePixX;
    p.trData.onlineEyeY(i) = p.trVars.eyePixY;

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
%   (1) recording of the time at which the event occured
%   (2) setting 'p.trVars.currentState' to the next state
%

%%
% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

%% Big SWITCH that implements state-dependency
switch p.trVars.currentState
    case p.state.trialBegun
        %% STATE 1:
        %   TRIAL HAS BEGUN!

        % Store trial start time and move to to state 3 - Show Fixation
        p.trData.timing.trialBegin      = timeNow;
        p.trVars.currentState           = p.state.showFix;

    case p.state.showFix
        %% STATE 3:
        %   SHOW FIXATION POINT AND WAIT FOR SUBJECT TO ACQUIRE FIXATION.

        % If "fixOn" time hasn't been defined, and we haven't already
        % indicated that "fixOn" should be defined after the next flip,
        % indicate that "fixOn" should be defined after the next flip and
        % send a "FIX_ON" message to eyelink. We also set the color of the
        % fixation point ("p.draw.color.fix") to green, indicating to the
        % subject that the state of the task is "waiting for the subject to
        % acquire fixation".
        if p.trData.timing.fixOn < 0 ...
                && ~ismember('fixOn', p.trVars.postFlip.varNames)

            % Draw green fixation
            p.draw.color.fix = p.draw.clutIdx.expMutGreen_subMutGreen;

            % Do necessary steps to write "FIX_ON" message to Eyelink's EDF
            % file after next flip.
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
            p.trVars.postFlip.msgNames{end + 1} = 'FIX_ON';
        end

        % Once fixation has been illuminated, if subject acquires fixation
        % within duration alloted for fixation acquisition, turn fixation
        % point white to indicate to the subject that stimulus presentation
        % is about to happen, then write "FIX_ACQ" message to Eyelink's EDF
        % file, note time of fixation acquisition, and move on to next
        % state ("dontMove").
        if pds.eyeInWindowEL(p) && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)

            % Draw fixation point white instead of green
            p.draw.color.fix = p.draw.clutIdx.expWhite_subWhite;

            % write FIX_ACQ message to Eyelink's EDF
            Eyelink('Message', 'FIX_ACQ');

            % Note time of fixation acquisition
            p.trData.timing.fixAq      = timeNow;

            % move on to next state
            p.trVars.currentState      = p.state.dontMove;

        elseif p.trData.timing.fixOn > 0 && timeNow > ...
                (p.trData.timing.fixOn + p.trVars.fixWaitDur)

            % fixation was not acquired within alotted time. Write
            % "FIX_NACQ" message to Eyelink's EDF.
            Eyelink('Message', 'FIX_NACQ');

            % Move on to "nonStart" state.
            p.trVars.currentState      = p.state.nonStart;
        end

    case p.state.dontMove
        %% STATE 4:
        % "DON'T MOVE" - SUBJECT HOLDS FIXATION WHILE STIMULI ARE
        % PRESENTED.

        % The next state (STATE 5 - MAKE DECISION) is the money time,
        % where subject is to either respond or not, and the outcome of
        % the trial is determiend.

        % Calculate elapsed time since fixation acquisition
        timeFromFixAq = timeNow - p.trData.timing.fixAq;

        % Determine if peripheral stimuli should be on. If it/they should
        % and we haven't already indicated that "stimOn" should be defined
        % after the next flip, indicate that "stimOn" should be defined
        % after the next flip and strobe "stimOn" after the next flip. Then
        % stay in this state until stimulus presentation has concluded, and
        % move on to the "makeDecision" state.
        if timeFromFixAq >= p.trVars.fix2StimOnIntvl && ...
                timeFromFixAq < p.trVars.fix2StimOffIntvl && ...
                ~ismember('stimOn', p.trVars.postFlip.varNames)

            % Do necessary steps to write "STIM_ON" message to Eyelink's
            % EDF file after next flip.
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOn';
            p.trVars.postFlip.msgNames{end + 1} = 'STIM_ON';

            % change value of boolean "stimIsOn" variable to "true" so we
            % know we need to draw it.
            p.trVars.stimIsOn                = true;

            % Flush and start KbQueue for subject's response collection
            % device:
            KbQueueFlush(p.init.respDevIdx);
            KbQueueStart(p.init.respDevIdx);

        elseif timeFromFixAq > p.trVars.fix2StimOffIntvl

            % If it's time to turn the stimuli off, do steps necessary to
            % write "STIM_OFF" message to Eyelink's EDF file after next
            % flip.
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOff';
            p.trVars.postFlip.msgNames{end + 1} = 'STIM_OFF';

            % Move on to next state "makeDecision"
            p.trVars.currentState               = p.state.makeDecision;

            % change value of boolean "stimIsOn" variable to "false" so we
            % know we no longer need to draw it.
            p.trVars.stimIsOn                   = false;

            % change fixation point color to indicate to the subject that
            % they should press a key to give their response:
            p.draw.color.fix = p.draw.clutIdx.expBlue_subBg;
        end

        % If subject breaks fixation, abort.
        if ~pds.eyeInWindowEL(p)

            Eyelink('Message', 'FIX_BREAK');
            % p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak   = timeNow;
            p.trVars.currentState      = p.state.fixBreak;
        end

        %

    case p.state.makeDecision

        %% STATE 5:
        %   MAKE A DECISON!
        %   Stimulus presentation has concluded. Collect a response from
        %   the subject.

        % if "passJoy" is true...
        if p.trVars.passJoy

            % generate and store random response time / value:
            p.trData.timing.responseTime = normrnd(0.55, 0.05);
            p.trData.responseValue = num2str(randi(4));

            % tell eyelink which key was pressed
            Eyelink('Message', ['RSP_' p.trData.responseValue]);

            % move on to "trialCompleted" state
            p.trVars.currentState = p.state.trialCompleted;

        else
            % keep fixation point color to indicate to the subject that
            % they should press a key to give their response:
            p.draw.color.fix = p.draw.clutIdx.expBlue_subBg;

            % check if a key has been pressed:
            [pressed, firstPress] = ...
                KbQueueCheck(p.init.respDevIdx);

            % if a response has been made, store it and move on to
            % "trialCompleted" state:
            if pressed

                % get last keypress time and which key was pressed, and store.
                p.trData.timing.responseTime = firstPress(logical(firstPress));
                p.trData.responseValue = KbName(firstPress);

                % tell eyelink which key was pressed
                Eyelink('Message', ['RSP_' p.trData.responseValue]);

                % stop KbQueue
                KbQueueStop(p.init.respDevIdx);

                % move on to "trialCompleted" state
                p.trVars.currentState = p.state.trialCompleted;
            end
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial COMPLETED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case  p.state.trialCompleted
        p.trVars.exitWhileLoop = true;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial ABORTED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.fixBreak
        %% FIXATION BREAK
        % p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.nonStart
        %% NON-START
        % subject did not hold the joystick within the alloted time and
        % trila is considered a non-start.
        % p = playTone(p, 'low');
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
        p.trVars.postFlip.msgNames{end + 1} = 'STIM_OFF';
    end

    % turn off fixation and fixation window:
    p.draw.color.fix          = p.draw.color.background;
    p.draw.color.fixWin       = p.draw.color.background;

    % note trial end state
    p.trData.trialEndState = p.trVars.currentState;

    % Mark time of trial completion (PTB), send a message to Eyelink
    % indicating trial completion to be recorded in the EDF file, and stop
    % the EDF recording (don't close out the EDF file, just "pause" the
    % recording until the beginning of the next trial).
    p.trData.timing.trialEnd   = timeNow;
    Eyelink('Message', 'TRIAL_END');
    Eyelink('StopRecording')
end
% Done with state-dependent section

end

function p = drawMachine(p)

% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;
Eyelink('Message', 'TRIAL_END');
% if we're close enouframegh in time to the next screen flip, start drawing.
if timeNow > p.trData.timing.lastFrameTime + ...
        p.rig.frameDuration - p.rig.magicNumber

    % Fill the window with the background color.
    Screen('FillRect', p.draw.window, ...
        fix(255*p.draw.bgRGB));

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

        % draw FIXED textures to screen (one per stimulus)
        % for i = p.trVars.nPatches
        %     Screen('DrawTexture', p.draw.window, ...
        %         p.stim.stimTextures(p.trVars.stimFrameIdx), ...
        %         p.stim.sourceRects(i, :), ...
        %         p.trVars.stimRects(i,:));
        % end
        Screen('DrawTexture', p.draw.window, ...
            p.stim.stimTextures(p.trVars.stimFrameIdx), ...
            p.stim.sourceRects(1, :), ...
            p.trVars.stimRects(1,:));
        Screen('DrawTexture', p.draw.window, ...
            p.stim.stimTextures(p.trVars.stimFrameIdx), ...
            p.stim.sourceRects(2, :), ...
            p.trVars.stimRects(2,:));
        Screen('DrawTexture', p.draw.window, ...
            p.stim.stimTextures(p.trVars.stimFrameIdx), ...
            p.stim.sourceRects(3, :), ...
            p.trVars.stimRects(3,:));
        Screen('DrawTexture', p.draw.window, ...
            p.stim.stimTextures(p.trVars.stimFrameIdx), ...
            p.stim.sourceRects(4, :), ...
            p.trVars.stimRects(4,:));
    end

    % draw fixation spot
    Screen('FrameRect',p.draw.window, ...
        fix(255*p.draw.clut.expColors(p.draw.color.fix + 1, :)), ...
        p.draw.fixPointRect, 6);

    % flip and store time of flip.
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, ~] = ...
        Screen('Flip', p.draw.window);
    p.trData.timing.lastFrameTime   = ...
        p.trData.timing.flipTime(p.trVars.flipIdx) - ...
        p.trData.timing.trialStartPTB;

    % if a stimulus event has occurred, mark the time of that event based
    % on the previousstrobely recorded fliptime.
    if p.trVars.postFlip.logical

        % loop over the "varNames" field of "p.trVars.postFlip" and assign
        % "p.trData.timing.lastFrameTime" to
        % "p.trData.timing.(varNames{j})", and send a message to eyelink
        % indicating the event has occurred:
        for j = 1:length(p.trVars.postFlip.varNames)
            if p.trData.timing.(p.trVars.postFlip.varNames{j}) < 0

                % log time
                p.trData.timing.(p.trVars.postFlip.varNames{j}) = ...
                    p.trData.timing.lastFrameTime;

                % send message to eyelink:
                Eyelink('Message', p.trVars.postFlip.msgNames{j});
            end
        end

        % reset the logical variable indicaing we have a time to log and
        % empty the list of variable names.
        p.trVars.postFlip.logical           = false;
        p.trVars.postFlip.varNames          = cell(0);
        p.trVars.postFlip.msgNames          = cell(0);
    end

    % increment flip index
    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end

end