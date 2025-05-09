function p = joystickPress_run(p)
%   p = joystickPress_run(p)
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
        
        % If joystick is held down, onwards to state 0.25
        % If not, onward to state 3.3 (non-start)
        if pds.joyHeld(p)
            p.init.strb.addValue(p.init.codes.joyPress);
            p.trData.timing.joyPress    = timeNow;
            p.trVars.currentState       = p.state.holdJoy;
            
        elseif ~pds.joyHeld(p) && (timeNow > p.trVars.joyWaitDur)
            p.trVars.currentState       = p.state.nonStart;
        end
        
    case p.state.holdJoy
        %% STATE 3:
        %   JOYSTICK IS HELD, WAIT UNTIL REQUIRED TIME HAS ELAPSED THEN GO
        %   TO REWARD DELIVERY.

        % If joystick has been held down for the requisite duration: strobe
        % "hit" code to recording system, log the time that the joystick
        % hold duration requirement was met, advance to the "hit" state,
        % and play a tone indicating successful trial completion.
        if p.trData.timing.joyPress > 0 && ...
                timeNow > (p.trData.timing.joyPress + ...
                p.trVars.joyPressReq)
            p.init.strb.addValue(p.init.codes.hit);
            p.trData.timing.joyHoldReqMet = timeNow;
            p.trVars.currentState      = p.state.hit;
            p = playTone(p, 'high');
            
        elseif ~pds.joyHeld(p)
            % joystick released when it wasn't supposed to:
            p.init.strb.addValue(p.init.codes.joyRelease);
            p.init.strb.addValue(p.init.codes.miss);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.miss;
        end

        % If it's time to deliver opto stim and neither the "optoStim" nor
        % the "optoStimSham" time values have been set (they are both < 0),
        % either deliver the opto stim or mark the sham opto stim time. If
        % opto stim time + opto stim duration has passed, make sure opto
        % stim is turned off.
        if p.trData.timing.joyPress > 0 && ...
                timeNow > (p.trData.timing.joyPress + ...
                p.trVars.optoStimTime) && all([p.trData.timing.optoStim ...
                p.trData.timing.optoStimSham] < 0)
            % if this is an opto stim trial, deliver the stim. Otherwise,
            % strobe the sham stim time:
            if p.trVars.isOptoStimTrial && p.trData.timing.optoStim < 0
                p = pds.deliverOptoStim(p);
            elseif p.trData.timing.optoStimSham < 0
                p.trData.timing.optoStimSham = timeNow;
                p.init.strb.strobeNow(p.init.codes.optoStimSham);
            end
        elseif p.trData.timing.joyPress > 0 && ...
                timeNow > (p.trData.timing.joyPress + ...
                p.trVars.optoStimTime + p.trVars.optoStimDurSec + 0.075)

            % Zero out DAC voltage on opto stim channel:
            Datapixx('SetDacVoltages', [p.rig.dp.optoDacChan 0]);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial COMPLETED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.hit
        %% HIT!
        % STATE 21 = reward delivery
        p = pds.deliverReward(p);

        p.trVars.exitWhileLoop = true;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial ABORTED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.fixBreak
        %% FIXATION BREAK
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
        
    case p.state.miss
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

    % make sure opto stim is turned off:
    % Zero out DAC voltage on opto stim channel:
    Datapixx('SetDacVoltages', [p.rig.dp.optoDacChan 0]);

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
if timeNow > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber
    
    % Return next frame in movie, in sync with current playback
    % time and sound.
    % tex is either the positive texture handle or zero if no
    % new frame is ready yet in non-blocking mode (blocking == 0).
    % It is -1 if something went wrong and playback needs to be stopped:
    movieTex = Screen('GetMovieImage', p.draw.window, ...
        p.draw.movie.movieHandle, p.draw.movie.blocking);

    % Fill the window with the background color.
    % Screen('FillRect', p.draw.window, p.draw.color.background);
    
    % Draw the grid
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], p.draw.color.gridMajor);
    
    % Draw the gaze position, MUST DRAW THE GAZE BEFORE THE
    % FIXATION. Otherwise, when the gaze indicator goes over any
    % stimuli it will change the occluded stimulus' color!
    gazePosition = [p.trVars.eyePixX p.trVars.eyePixY p.trVars.eyePixX p.trVars.eyePixY] + ...
        [-1 -1 1 1]*p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2);
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, gazePosition);
    
    % Draw the joystick-bar graphic.
    Screen('FrameRect', p.draw.window, p.draw.color.joyInd, p.draw.joyRect);
    Screen('FillRect',  p.draw.window, p.draw.color.joyInd, joyRectNow);
    
    % Draw the new movie frame immediately to screen if there's one available.
    if movieTex > 0
        Screen('DrawTexture', p.draw.window, movieTex, [], ...
            p.draw.movie.dstRect, [], [], [], [], p.draw.movie.shader);
    elseif movieTex < 0
        % we need to reset the movie time index to the beginning to play again.
        Screen('SetMovieTimeIndex', p.draw.movie.movieHandle, 0);
    end

    % flip and store time of flip.
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, frMs] = ...
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
    
    % close out old movie texture:
    Screen('Close'); 
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