function p = sacc_to_phosph_run(p)
%   p = seansFirstTask_run(p)
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


% (1) mark start time in PTB and DP time:
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = pds.getTimes;

%% (2) while-loop
% The while loop has 3 sections:
%   (1) STATE-DEPENDENT section: sets variables as a function of state
%   (2) TIME-DEPENDENT section: sets variables as a function of time 
%   (3) DRAW section: PTB-based drawing


while ~p.trVars.exitWhileLoop
    
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
    
    
    % STATE DEPENDENT section
    p = stateMachine(p);
    
    % TIME-DEPENDENT section
    p = timingMachine(p);
    
    % DRAW:
    p = drawMachine(p);
     
end % while loop
    
% Strobe trialRunDone once, after the run loop exits, regardless of
% outcome. Distinct from trialEnd (which fires in _finish.m). Trial-
% relative timestamp consistent with other timing variables in this file.
p.trData.timing.trialRunDone = GetSecs - p.trData.timing.trialStartPTB;
p.init.strb.strobeNow(p.init.codes.trialRunDone);

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
        p.init.strb.strobeNow(p.init.codes.trialBegin);
        p.trData.timing.trialBegin      = timeNow;
        p.trVars.currentState           = p.state.showFix;
        
    case p.state.showFix
        %% STATE 3:
        %   TRIAL HAS BEGUN, SO SHOW FIXATION POINT AND WAIT FOR
        %   SUBJECT TO ACQUIRE FIXATION.
        
        % show fixatoin point & fixation window on exp-display
        p.draw.color.fix            = p.draw.clutIdx.expWhite_subWhite;

        p.draw.color.fixWin         = p.draw.clutIdx.expGrey70_subBg;
        p.draw.fixWinPenDraw        = p.draw.fixWinPenThin;
        
        % we only want to strobe this once:
        p.init.strb.addValueOnce(p.init.codes.fixOn);
        
        % note time of fixation onset if it hasn't yet been set
        if p.trData.timing.fixOn < 0
            p.trData.timing.fixOn          = timeNow;
        end
        
        % If fixation is aquired within alotted time, onwards to p.state.dontMove:
        if pds.eyeInWindow(p) && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
                
            p.init.strb.strobeNow(p.init.codes.fixAq);
            p.trData.timing.fixAq      = timeNow;
            p.trVars.currentState      = p.state.dontMove;
            
            
        elseif timeNow > (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            % fixation was never acquired
            p.trVars.currentState      = p.state.nonStart;
        end
        
    case p.state.dontMove
        %% STATE 4:
        %   "DON'T MOVE" - SUBJECT HOLDS FIXATION
        %   STUFF HAPPENS ON SCREEN (eg cue flashes, target appears,
        %   but these are determined in the time-dependant section,
        %   below). HERE, THE KEY THING IS THAT THE SUSBJECT SHOULD NOT
        %   DO A SINGLE THING.
        %
        %   The next state is money time, where subject is to either 
        %   respond or not, and the outcome of the trial is determiend.
        
        % show target window to experimenter

        p.draw.color.targWin                = p.draw.clutIdx.expVisGreen_subBg;

        
        % increase the thickness of the fixation window to inform
        % the experimenter that the subject has acquired fixation.
        p.draw.fixWinPenDraw = p.draw.fixWinPenThick;
        
        timeFromFixation = timeNow - p.trData.timing.fixAq;
        
        if timeFromFixation > p.trVars.timeFixOffset
            p.init.strb.addValue(p.init.codes.fixOff);
            p.trData.timing.fixOff    = timeNow;
            p.trVars.currentState     = p.state.makeSaccade;
        
        elseif ~pds.eyeInWindow(p)
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
        end
        
    case p.state.makeSaccade
        %% STATE 5:
        %   MAKE A SACCADE!
        % Fixation point has disappeared. This is the 'go' signal. 
        % Subject is required to saccade within a specified time window and
        % land in the target window.
        
        % turn off fixation point "go signal"
        p.draw.color.fix = p.draw.clutIdx.expBg_subBg;

        
        % if sub left window before goTime + minLatency, that's a breakFix:
        if ~pds.eyeInWindow(p) && timeNow < (p.trData.timing.fixOff + p.trVars.goLatencyMin)
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
        % if left window within specified time window, that's great! We
        % note that as the real-time estimate of saccade onset.
        % strobe/note saccade onset and move to next state
        elseif (~pds.eyeInWindow(p)...
                && timeNow > (p.trData.timing.fixOff + p.trVars.goLatencyMin)...
                && timeNow < (p.trData.timing.fixOff + p.trVars.goLatencyMax)) || p.trVars.passEye;
            p.init.strb.strobeNow(p.init.codes.saccadeOnset);
            p.trData.timing.saccadeOnset    = timeNow;
            p.trVars.currentState           = p.state.checkLanding;
            
            % decrease the thickness of the fixation window to inform
            % the experimenter that the subject has acquired fixation.
            p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
            
        % and if neither has happened and the goLatencyMax is elapsed, move
        % to heldFix
        elseif timeNow > (p.trData.timing.fixOff + p.trVars.goLatencyMax)
            p.trVars.currentState       = p.state.heldFix;
        end
        
      case p.state.checkLanding
        %% STATE 6:
        %   CHECK LANDING POINT
        % Subject has saccaded, sure, but we have yet to check where! This
        % state checks whether he has landed in the target window or not. 

        % check if eyes are in target windows
        eyeInTargetWin = pds.eyeInWindow(p, 'target');
      
        if ~eyeInTargetWin && (timeNow < p.trData.timing.saccadeOnset + p.trVars.maxSacDurationToAccept)
            % do nothing. Wait for monkey to get into targWin, but no
            % longer than the maxSacDurationToAccept.
%         elseif ~eyeInTargetWin && (timeNow > p.trData.timing.saccadeOnset + p.trVars.maxSacDurationToAccept)
%             p.init.strb.addValue(p.init.codes.fixBreak);
%             p.trData.timing.fixBreak    = timeNow;
%             p.trVars.currentState       = p.state.fixBreak;
%       
	elseif (eyeInTargetWin && (timeNow < p.trData.timing.saccadeOnset + p.trVars.maxSacDurationToAccept)) || p.trVars.passEye
	    % if the eyes entered target window 1 we onsider that the real-time estimate of saccade offset
            p.init.strb.strobeNow(p.init.codes.saccadeOffset);
            p.trData.timing.saccadeOffset    = timeNow;
            % and 'target acquired':
            p.init.strb.strobeNow(p.init.codes.targetAq);
            p.trData.timing.targetAq        = timeNow;

	    % strobe to indicate we looked at target 1
	    p.init.strb.strobeNow(p.init.codes.saccToTargetOne);
		
	    % Switch state to holdTarg
                p.trVars.currentState           = p.state.holdTarg;
                % and thicken up that targWin:
            	p.draw.targWinPenDraw = p.draw.targWinPenThick;

	    
        else %if (eyeInTargetWin && (timeNow > p.trData.timing.saccadeOnset + p.trVars.maxSacDurationToAccept)) %|| ~p.trVars.passEye
            % this means subject got into the target win too late. Likely
            % performed an intermediate saccade. This is unacceptable. 
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.fixBreak;
            
            % and thin up that targWin:
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            
        end
        
         
           
      case p.state.holdTarg
        %% STATE 7:
        %   HOLD TARGET FIXATION!
        % Subject has saccaded, sure, but we have yet to check where! This
        % state checks whether he has landed in the target window and
        % whether he maintains it for long enough in order to move to the
        % final state- saccadeCompleted.

             
        % we reached this state because the eyes have entered the target
        % window. If they exit the window before the holdTargDuration has
        % elapsed, it is a breakFix.
       
        % check if eyes are in target window:
        eyeInTargetWin = pds.eyeInWindow(p, 'target');
        
        
        % if eyes stayed on target for full duration, bravo!
        if eyeInTargetWin && timeNow > p.trData.timing.saccadeOffset + p.trVars.targHoldDuration
            p.trVars.currentState = p.state.sacComplete;
            
            % and thicken up that targWin:
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
            
        elseif ~eyeInTargetWin
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak    = timeNow;
            p.trVars.currentState       = p.state.failedToHoldTarg;
            
            % and thin up that targWin:
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            
        end
        
               
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% end states: trial COMPLETED %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    case p.state.sacComplete
        %% SACCADE COMPLETE!
        % STATE 21 = get reward delivery if not nostim trial

        % If this was visual or microstim, this means he did it correctly
        if p.trVars.trialType == 1 || p.trVars.trialType == 2

        % if the delay for reward delivery has elapsed and reward delivery
        % hasn't yet been triggered, deliver the reward.
            if p.trData.timing.reward < 0
                p = pds.deliverReward(p);
                
            disp ('reward');

        % if reward delivery has been triggered and the interval to wait
        % after reward delivery has elapsed, it's time to exit the
        % while-loop.
            elseif p.trData.timing.reward > 0 && (timeNow - p.trData.timing.reward) > (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + p.trVars.rewardDurationMs/1000)
                p.trVars.exitWhileLoop = true;            
            end
        
        % If this was nostim, this means he did it incorrectly
        elseif p.trVars.trialType == 3
            % p = playTone(p, 'low');
            p.trVars.exitWhileLoop = true;
        end



    case p.state.heldFix
        %% Held fixation (indicating he did not see anything to saccade to)
        % STATE 22 

        % If this was visual or microstim, this means he did it incorrectly
        if p.trVars.trialType == 1 || p.trVars.trialType == 2
            % p = playTone(p, 'low');
            p.trVars.exitWhileLoop = true;


        % If this was nostim, this means he did it incorrectly
        elseif p.trVars.trialType == 3
        
        % if the delay for reward delivery has elapsed and reward delivery
        % hasn't yet been triggered, deliver the reward.
            if p.trData.timing.reward < 0
                p = pds.deliverReward(p);
                
            disp ('reward');

        % if reward delivery has been triggered and the interval to wait
        % after reward delivery has elapsed, it's time to exit the
        % while-loop.
            elseif p.trData.timing.reward > 0 && (timeNow - p.trData.timing.reward) > (p.trVars.postRewardDuration + p.rig.dp.dacPadDur + p.trVars.rewardDurationMs/1000)
                p.trVars.exitWhileLoop = true;            
            end
        end


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% end states: trial ABORTED %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    case p.state.fixBreak
        %% FIXATION BREAK

        % p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;

        % p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;
        
    case p.state.nonStart
        %% NON-START
        % subject did not look at fix within the alloted time and
        % trial is considered a non-start.

        % p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;   
               
    case p.state.failedToHoldTarg
        %% FAILED TO HOLD TARGET
        % Subject looked away after looking at target location

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

% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% Also calculate a time in "frames" relative to trial-start
p.trData.timing.frameNow    = fix(timeNow * p.rig.refreshRate);

% SET COLORS AS A FUNCTION OF ELAPSED TIME

% function of time (and may span multiple states)
if p.trData.timing.fixAq > 0
    
    % time elapsed from fixation acquisition:
    timeFromFixAq = timeNow - p.trData.timing.fixAq;
    
    %% Determine if stim should be on/off:
    
    if (p.trData.timing.stimOn == -1 && ...
        timeFromFixAq >= p.trVars.timeStimOnset && timeFromFixAq < p.trVars.timeStimOffset)
            p.trVars.stimIsOn    = true;
            p.trData.timing.stimOn   = timeNow;
            
            if p.trVars.trialType == 1 % if visual trial, send strobe on next flip
                p.init.strb.addValueOnce(p.init.codes.stimOn);
            end

    elseif (p.trData.timing.stimOn ~= -1 && p.trData.timing.stimOff == -1 && ...
        timeFromFixAq >= p.trVars.timeStimOffset)
            p.trVars.stimIsOn   = false;
            p.trVars.timing.stimOff  = timeNow;

            if p.trVars.trialType == 1 % if visual trial, send strobe on next flip
                p.init.strb.addValueOnce(p.init.codes.stimOff);
            end
    end
    
    

    %% Determine if target should be on/off and send appropriate strobes:
    
    % if target is off, but time now is after timeTargOnset, turn it on:
    if (p.trData.timing.targetOn == -1 && ...
        timeFromFixAq >= p.trVars.timeTargOnset && timeFromFixAq < p.trVars.timeTargOffset)
        p.trVars.targetIsOn       = true;
        p.trData.timing.targetOn  = timeNow;
        % p.init.strb.addValueOnce(p.init.codes.targetOn);
    
    % if this is memSac, and target is on but it's time to turn it off, then turn it off:
    elseif (p.trData.timing.targetOn~=-1 && p.trData.timing.targetOff==-1 && ...
            timeFromFixAq >= p.trVars.timeTargOffset)
            p.trVars.targetIsOn       = false;
            p.trData.timing.targetOff = timeNow;
            % p.init.strb.addValueOnce(p.init.codes.targetOff);
    end
    
end

end

%%


function p = drawMachine(p)

% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

%% if we're close enough to next screen flip, start drawing:

if timeNow > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber
    
    % Fill the window with the background color.
    Screen('FillRect', p.draw.window, p.draw.color.background);
    
    % Draw the grid
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], p.draw.color.gridMajor);
    
    % draw mouse cursor:
    % Screen('FillRect', p.draw.window, p.draw.color.mouseCursor, [p.trVars.mouseCursorX p.trVars.mouseCursorY p.trVars.mouseCursorX p.trVars.mouseCursorY] + [-1 -1 1 1] * p.draw.cursorW)
        
        
    % Draw the gaze position, MUST DRAW THE GAZE BEFORE THE
    % FIXATION. Otherwise, when the gaze indicator goes over any
    % stimuli it will change the occluded stimulus' color!
    Screen('FillRect', p.draw.window, p.draw.color.eyePos, [p.trVars.eyePixX p.trVars.eyePixY p.trVars.eyePixX p.trVars.eyePixY] + [-1 -1 1 1]*p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2));
    
    % draw targWin:
    
    Screen('FrameRect',p.draw.window, p.draw.color.targWin, ...
                repmat(p.draw.targPointPix, 1, 2) +  [-p.draw.targWinWidthPix -p.draw.targWinHeightPix p.draw.targWinWidthPix p.draw.targWinHeightPix], p.draw.targWinPenDraw)   
    	

    % draw fixation window
    Screen('FrameRect',p.draw.window, p.draw.color.fixWin, repmat(p.draw.fixPointPix, 1, 2) +  [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix p.draw.fixWinWidthPix p.draw.fixWinHeightPix], p.draw.fixWinPenDraw)
    

    % depending on trialType, drawstimulus or send microstim command
    if p.trVars.stimIsOn
        if p.trVars.trialType == 1 % Visual stimulus
            Screen('DrawTexture', p.draw.window, p.draw.stimTexture, [], repmat(p.draw.stimPointPix, 1, 2) + ...
            [-p.draw.textureWindowDimensions/2 -p.draw.textureWindowDimensions/2 p.draw.textureWindowDimensions/2 p.draw.textureWindowDimensions/2]);

        elseif p.trVars.trialType == 2 && p.trData.timing.microstimSent == -1 % Electrode microstimulation
            
            disp (append ('microstim @ ', num2str(p.trVars.stimAmplitude), 'uA / ', num2str(p.trVars.stimCurrentSteps), ' steps on channel #', num2str(p.trVars.stimulatedElectrode)));
            p.trData.timing.microstimSent = timeNow;
            p.init.strb.strobeNow(p.init.codes.microStimOn);
            
            pds.xippmex ('stimseq', p.trVars.cmd); % Send microstim command

        elseif p.trVars.trialType == 3 % No stimulus
            % do nothing
        end
    end


    % draw fixation spot
    Screen('FrameRect',p.draw.window, p.draw.color.fix, repmat(p.draw.fixPointPix, 1, 2) + p.draw.fixPointRadius*[-1 -1 1 1], p.draw.fixPointWidth);
    
    
    % flip and record time of flip.
    p.trData.timing.flipTime(p.trVars.flipIdx) = ...
        Screen('Flip', p.draw.window) - p.trData.timing.trialStartPTB;
    if p.trVars.flipIdx > 1
    p.trData.timing.lastFrameDiff(p.trVars.flipIdx) = p.trData.timing.flipTime(p.trVars.flipIdx) - p.trData.timing.lastFrameTime;
    end
    p.trData.timing.lastFrameTime = ...
        p.trData.timing.flipTime(p.trVars.flipIdx);
    
    % strobe all values that are in the strobe list with the
    % classyStrobe class:
    if p.init.strb.armedToStrobe
        p.init.strb.strobeList;
    end
    
    % increment flip index
    p.trVars.flipIdx = p.trVars.flipIdx + 1;
end


end

