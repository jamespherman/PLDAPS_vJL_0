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
        
        % strobing trial start time and onward to state 3 - Show Fixation
        p.init.strb.addValue(p.init.codes.trialBegin);
        p.trData.timing.trialBegin      = timeNow;
        p.trVars.currentState           = p.state.showFix;
        
    case p.state.showFix
        %% STATE 3:
        %   SHOW FIXATION POINT AND WAIT FOR SUBJECT TO ACQUIRE FIXATION.
        
        % Show fixation point
        p.draw.color.fix                = p.draw.clutIdx.expWhite_subWhite;
        
        % Write message to EDF file to mark the start time of stimulus
        % presentation.
        Eyelink('Message', 'FIX_ONSET');   

        % If "fixOn" time hasn't been defined, and we haven't already
        % indicated that "fixOn" should be defined after the next flip,
        % indicate that "fixOn" should be defined after the next flip and
        % strobe "fixOn" after the next flip. This also means we need to
        % display the fixation!
        if p.trData.timing.fixOn < 0 ...
                && ~ismember('fixOn', p.trVars.postFlip.varNames)

            % I don't think we want to strobe anything, but I do think it
            % makes sense to write messages to the Eyelink "EDF" file after
            % the "next" flip.
            p.draw.color.fix = p.draw.clutIdx.expWhite_subWhite;
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
            % p.init.strb.addValueOnce(p.init.codes.fixOn);
        end
        
        % If fixation is aquired within alotted time move onwards next
        % state.
        if pds.eyeInWindow(p) && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            
            Eyelink('Message', 'FIX_ACQ');
            p.trData.timing.fixAq      = timeNow;
            p.trVars.currentState      = p.state.dontMove;
            
        elseif p.trData.timing.fixOn > 0 && timeNow > ...
                (p.trData.timing.fixOn + p.trVars.fixWaitDur) 
            % fixation was never acquired
            Eyelink('Message', 'FIX_ACQ');
            p.trData.timing.joyRelease = timeNow;
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
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOn';
            % p.init.strb.addValueOnce(p.init.codes.stimOn);
            p.trVars.stimIsOn                = true;
        elseif timeFromFixAq > p.trVars.fix2StimOffIntvl
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'stimOff';
            p.trVars.currentState               = p.state.makeDecision;
            p.trVars.stimIsOn                   = false;
        end

        % If subject breaks fixation, abort.
        if ~pds.eyeInWindow(p)

            Eyelink('Message', 'FIX_BREAK');
            % p.init.strb.addValue(p.init.codes.fixBreak);
            p.trData.timing.fixBreak   = timeNow;
            p.trVars.currentState      = p.state.fixBreak;
        end

    case p.state.makeDecision

        %% STATE 5:
        %   MAKE A DECISON!
        %   Stimulus presentation has concluded. Collect a response from
        %   the subject.

        if p.trVars.stimFrameIdx <= p.trVars.stimFrames
        else
            p.trVars.currentState = p.state.hit;
        end

        % INSERT CODE HERE to collect response. I'm quite uncertain about
        % this because we want the experimenter to be able to use the
        % keyboard. Maybe we should be using the button box?
        KbWait
        
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
%             p = pds.deliverReward(p);
                
        % if reward delivery has been triggered and the interval to wait
        % after reward delivery has elapsed, it's time to exit the
        % while-loop.
        elseif p.trData.timing.reward > 0 && ...
                (timeNow - p.trData.timing.reward) > ...
                (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + ...
                (p.trVars.rewardDurationMs/1000))
            p.trVars.exitWhileLoop = true;
        end

        
        % if the delay for reward delivery has elapsed and reward delivery
        % hasn't yet been triggered, deliver the reward.
        if (timeNow - p.trData.timing.fixHoldReqMet) > ...
                p.trVars.rewardDelay && p.trData.timing.reward < 0

%             p = pds.deliverReward(p);

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
%         p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

    case p.state.fa

        %% FALSE ALARM
%         p = playTone(p, 'noise');
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

% if we're close enouframegh in time to the next screen flip, start drawing.
if timeNow > p.trData.timing.lastFrameTime + ...
        p.rig.frameDuration - p.rig.magicNumber

    % Fill the window with the background color.
    Screen('FillRect', p.draw.window, ...
        p.draw.clut.subColors(p.draw.color.background + 1, :));

    % calculate which stimulus frame we're in based on time since
    % stimulus onset - stimuli should be drawn in the frame that their
    % onset time is defined ("p.trData.timing.stimOn") for this reason,
    % we force "stimFrameIdx" to a value of "1" until the stimulus
    % onset time has been defined.
    p.trVars.stimFrameIdx  = ...
        (fix((timeNow - p.trData.timing.stimOn) / ...
        p.rig.frameDuration)) * (p.trData.timing.stimOn > 0) + 1;
    disp(p.trVars.stimFrameIdx)
    
    % if stimuli should be drawn (based on time in trial), draw them.
    if p.trVars.stimIsOn && ...
            (p.trVars.stimFrameIdx <= p.trVars.stimFrames)
        
        % draw FIXED textures to screen (one per stimulus)
        for i = p.trVars.nPatches
            Screen('DrawTexture', p.draw.window, ...
                p.stim.stimTextures(p.trVars.stimFrameIdx), ...
                p.stim.sourceRects(i, :), ...
                p.trVars.stimRects(i,:));
        end
    end

    % draw fixation spot
    Screen('FrameRect',p.draw.window, ...
        p.draw.clut.subColors(p.draw.color.fix + 1, :), ...
        p.draw.fixPointRect, p.draw.fixPointWidth);

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