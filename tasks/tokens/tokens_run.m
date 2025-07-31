function p = tokens_run(p)
%   p = tokens_run(p)
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

i = 0;
while ~p.trVars.exitWhileLoop
    
    % Update eye / joystick position:
    p = pds.getEyeJoy(p);

    i = i + 1;
    p.trData.onlineEyeX(i) = p.trVars.eyeDegX;
    p.trData.onlineEyeY(i) = p.trVars.eyeDegY;
    
    % STATE DEPENDENT section
    p = stateMachine(p);
    
    % DRAW:
    p = drawMachine(p);
     
end % while loop

end

function p = stateMachine(p)
% This function implements the state machine for the 'tokens' task.
% It is called on every frame of the 'run' loop.

% Get the time elapsed since the trial started
timeNow = GetSecs - p.trData.timing.trialStartPTB;

%% --- The State Machine ---
switch p.trVars.currentState
    
    case p.state.trialBegun
        % --- State 1: Trial Begun ---
        % This state runs only once to set up the ITI timer correctly.
        
        % Strobe the trial start code
        p.init.strb.addValue(p.init.codes.trialBegin);
        
        % Determine the start time for the ITI calculation.
        if p.status.lastTrialEndTime ~= 0
            % For the very first trial, the ITI starts when the trial begins.
            startTime = p.trData.timing.trialStartPTB;
        else
            % For all subsequent trials, the ITI starts when the previous
            % trial's 'run' loop ended.
            startTime = p.status.lastTrialEndTime;
        end
        
        % Set the absolute time for when the ITI should end.
        p.trVars.ITI_EndTime = startTime + p.trVars.iti;
        
        % Immediately transition to the ITI waiting state.
        p.trVars.currentState = p.state.waitForITI;
        
    case p.state.waitForITI
        % --- State 2: Wait for ITI ---
        % Pauses the trial for the duration of the calculated ITI.
        
        if timeNow >= p.trVars.ITI_EndTime
            % After the ITI, check if this trial requires fixation
            if p.trVars.isFixationRequired
                % If yes, proceed to show the cue
                p.trVars.currentState = p.state.showCue;
            else
                % If no (a free reward trial), skip to the outcome
                p.trVars.currentState = p.state.showOutcome;
            end
        end
        
    case p.state.showCue
        % --- State 3: Show the Cue ---
        % This state signals the 'drawMachine' to start drawing the cue.
        
        % Use the post-flip timing mechanism to precisely log when the cue appears
        if p.trData.timing.cueOn < 0
            p.trVars.postFlip.logical = true;
            p.trVars.postFlip.varNames{end + 1} = 'cueOn';
            p.init.strb.addValueOnce(p.init.codes.CUE_ON);
        end
        
        % Transition to waiting for the monkey to fixate
        p.trVars.currentState = p.state.waitForFix;
        
    case p.state.waitForFix
        % --- State 4: Wait for Fixation ---
        % Waits for the monkey's gaze to enter the fixation window.
        
        % Check if the eye is in the fixation window
        if pds.eyeInWindow(p)
            % If yes, log the time, strobe, and transition
            p.trData.timing.fixAq = timeNow;
            p.init.strb.addValue(p.init.codes.fixAq);
            p.trVars.currentState = p.state.holdFix;
            
        % Check for a timeout if fixation is not acquired
        elseif timeNow > (p.trData.timing.cueOn + p.trVars.fixAqDur)
            % If time is up, abort the trial
            p.status.trialRepeatFlag = true;
            p.init.strb.addValue(p.init.codes.noFix);
            p.trVars.currentState = p.state.noFix;
        end
        
    case p.state.holdFix
        % --- State 5: Hold Fixation ---
        % Ensures the monkey maintains fixation for the required duration.
        
        % Check if the hold duration has been met
        if timeNow > (p.trData.timing.fixAq + p.trVars.fixDur)
            % If yes, the fixation requirement is complete. Proceed to the outcome.
            p.trVars.currentState = p.state.showOutcome;
            
        % Check if the eye has left the window (fixation break)
        elseif ~pds.eyeInWindow(p)
            % If fixation is broken, abort the trial
            p.trData.timing.fixBreak = timeNow;
            p.status.trialRepeatFlag = true;
            p.init.strb.addValue(p.init.codes.fixBreak);
            p.trVars.currentState = p.state.fixBreak;
        end
        
    case p.state.showOutcome
        % --- State 6: Show the Outcome ---
        % Displays the tokens on the screen.
        
        % Log the precise time the outcome is shown
        if p.trData.timing.outcomeOn < 0
            p.trVars.postFlip.logical = true;
            p.trVars.postFlip.varNames{end + 1} = 'outcomeOn';
            p.init.strb.addValueOnce(p.codes.OUTCOME_DIST_BASE + p.trVars.dist);
        end
        
        % Set a timer for the pause before the "cash in" animation begins
        p.trVars.cashInStartTime = timeNow + p.trVars.outcomeDelay;
        
        % Initialize a counter for the token animation
        p.trVars.tokenI = 1;
        p.trVars.juiceGiven_thisToken = false;
        
        % Transition to the token animation state
        p.trVars.currentState = p.state.cashInTokens;
        
    case p.state.cashInTokens
        % --- State 7: Cash In Tokens ---
        % Manages the timed animation of tokens and reward delivery.
        
        % Wait for the initial outcome delay to pass
        if timeNow < p.trVars.cashInStartTime
            return; % Do nothing until it's time to start
        end
        
        % Check if all rewards have been delivered
        if p.trVars.tokenI > p.trVars.rewardAmt
            % If yes, the trial is a success
            p.trVars.currentState = p.state.success;
        else
            % If we haven't delivered juice for the current token yet...
            if ~p.trVars.juiceGiven_thisToken
                % Deliver juice and strobe the event code
                p = pds.giveJuice(p);
                p.init.strb.addValue(p.codes.REWARD_GIVEN);
                
                % Set the timer for when to advance to the next token
                p.trVars.nextTokenTime = timeNow + p.trVars.juicePause;
                p.trVars.juiceGiven_thisToken = true;
            end
            
            % Check if it's time to move to the next token
            if timeNow >= p.trVars.nextTokenTime
                p.trVars.tokenI = p.trVars.tokenI + 1;
                p.trVars.juiceGiven_thisToken = false;
            end
        end
        
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% --- End States --- %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    case p.state.success
        % --- State 21: SUCCESS ---
        % A successfully completed trial.
        
        % Set the flag to exit the main trial loop
        p.trVars.exitWhileLoop = true;
        
    case p.state.fixBreak
        % --- State 11: Fixation Break ---
        % The monkey looked away during the hold period.
        
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
        
    case p.state.noFix
        % --- State 12: No Fixation ---
        % The monkey never acquired fixation on the cue.
        
        % No tone for this, as it's a non-start
        p.trVars.exitWhileLoop = true;
end


%% --- End of Trial ---
% This section runs ONCE after any state transitions to an end state.
if p.trVars.exitWhileLoop
    % Log the final state of the trial
    p.trData.trialEndState = p.trVars.currentState;
    
    % Strobe the generic 'trial end' code
    p.init.strb.addValueOnce(p.init.codes.trialEnd);
    p.trData.timing.trialEnd = timeNow;
end

end % End of stateMachine function

function p = drawMachine(p)
% This function handles all of the drawing commands for the 'tokens' task.

% Get the time elapsed since the trial started
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% Only bother drawing if we are close to the next screen flip.
if timeNow > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber
    
    % --- Start Drawing ---
    
    % 1. Fill the window with the background color.
    Screen('FillRect', p.draw.window, p.draw.color.background);
    
    % 2. Draw the reference grid for the experimenter.
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], p.draw.color.gridMajor);
    
    % 3. Draw the gaze position indicator.
    gazePosition = [p.trVars.eyePixX p.trVars.eyePixY p.trVars.eyePixX p.trVars.eyePixY] + ...
        [-1 -1 1 1]*p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2);
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, gazePosition);
    
    % 4. Draw the Cue Image (if applicable)
    % Only draw if we are in a state where the cue should be visible
    % and if a valid texture was created for this trial.
    if ismember(p.trVars.currentState, [p.state.showCue, p.state.waitForFix, p.state.holdFix]) && ~isnan(p.stim.cue.texture)
        Screen('DrawTexture', p.draw.window, p.stim.cue.texture, [], p.stim.cue.rect, 0);
    end
    
    % 5. Draw the Token Stimuli (if applicable)
    % Only draw if we are in a state where tokens should be visible
    % and if it's a token trial.
    if ismember(p.trVars.currentState, [p.state.showOutcome, p.state.cashInTokens]) && p.trVars.isToken
        % Determine which tokens to draw. During the 'cashInTokens' state,
        % p.trVars.tokenI is incremented, so fewer tokens are drawn over time.
        tokens_to_draw = p.trVars.tokenI : p.trVars.rewardAmt;
        
        if ~isempty(tokens_to_draw)
            % Get the screen positions for the tokens that are left
            token_positions = p.stim.token.pos(tokens_to_draw, :)'; % Transpose for DrawDots
            token_diameter_pix = pds.deg2pix(2 * p.stim.token.radius, p);
            
            Screen('DrawDots', p.draw.window, token_positions, token_diameter_pix, p.stim.token.color, p.draw.middleXY, 1);
        end
    end
    
    % 6. Draw the fixation spot and fixation window.
    Screen('FrameRect',p.draw.window, p.draw.color.fix, repmat(p.draw.fixPointPix, 1, 2) + ...
        p.draw.fixPointRadius*[-1 -1 1 1], p.draw.fixPointWidth);
        
    Screen('FrameRect',p.draw.window, p.draw.color.fixWin, repmat(p.draw.fixPointPix, 1, 2) +  ...
        [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix ...
        p.draw.fixWinWidthPix p.draw.fixWinHeightPix], p.draw.fixWinPenDraw);
    
    
    % --- Finish Drawing ---
    
    % 7. Flip the screen and record the timestamp.
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, ~] = Screen('Flip', p.draw.window);
    p.trData.timing.lastFrameTime = p.trData.timing.flipTime(p.trVars.flipIdx) - ...
        p.trData.timing.trialStartPTB;
    
    % 8. Strobe any values that are queued for this frame.
    if p.init.strb.armedToStrobe
        p.init.strb.strobeList;
    end
    
    % 9. Log precise timing for any events that just occurred.
    if p.trVars.postFlip.logical
        for j = 1:length(p.trVars.postFlip.varNames)
            if p.trData.timing.(p.trVars.postFlip.varNames{j}) < 0
                p.trData.timing.(p.trVars.postFlip.varNames{j}) = p.trData.timing.lastFrameTime;
            end
        end
        p.trVars.postFlip.logical = false;
        p.trVars.postFlip.varNames = cell(0);
    end
    
    % Increment flip index
    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end

end % End of drawMachine function