function p = srs_run(p)
%   p = srs_run(p)
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






%% ------------------------------------------------------------
% Optional i1 measurement mode
% ------------------------------------------------------------
% If enabled, measure the SRS red luminance ramp and return immediately.
% This is meant to be launched from the PLDAPS GUI using the Run button.

if isfield(p.trVars, 'measureRedLumRampWithI1') && ...
        p.trVars.measureRedLumRampWithI1

    if isfield(p.trVars, 'i1RampNRepeats')
        nRepeats = p.trVars.i1RampNRepeats;
    else
        nRepeats = 3;
    end

    if isfield(p.trVars, 'i1RampSettleTime')
        settleTime = p.trVars.i1RampSettleTime;
    else
        settleTime = 0.25;
    end

    p = i1MeasureSrsRedLumRamp(p, ...
        'nRepeats', nRepeats, ...
        'settleTime', settleTime);

    p.status.i1RampMeasurementDone = true;
    if ~isfield(p, 'trData'), p.trData = struct(); end
    if ~isfield(p.trData, 'timing'), p.trData.timing = struct(); end
    p.trData.timing.trialStartPTB = GetSecs;
    return
end


if isfield(p.trVars, 'scanDklRedLumWithI1') && ...
        p.trVars.scanDklRedLumWithI1

    p = i1ScanDklRedLumAxis(p, ...
        'nRepeats', 3, ...
        'settleTime', 0.25, ...
        'targetLow', 0.01, ...
        'targetHigh', 12.15, ...
        'lumGrid', linspace(-1.00, 0.20, 61));

    p.status.i1RampMeasurementDone = true;

    if ~isfield(p, 'trData')
        p.trData = struct();
    end

    if ~isfield(p.trData, 'timing')
        p.trData.timing = struct();
    end

    p.trData.timing.trialStartPTB = GetSecs;

    return
end

%% ------------------------------------------------------------
% Optional i1 gray background measurement mode
% ------------------------------------------------------------
if isfield(p.trVars, 'findGrayBgWithI1') && ...
        p.trVars.findGrayBgWithI1

    p = i1FindGrayBackgroundLum(p, ...
        'targetCdM2', 47.5, ...
        'nRepeats', 3, ...
        'settleTime', 0.25, ...
        'dklGrid', linspace(-1.00, 0.40, 71));

    p.status.i1GrayBgMeasurementDone = true;

    if ~isfield(p, 'trData')
        p.trData = struct();
    end

    if ~isfield(p.trData, 'timing')
        p.trData.timing = struct();
    end

    p.trData.timing.trialStartPTB = GetSecs;

    return
end



% (1) mark start time in PTB and DP time:
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = ...
    pds.getTimes;

%% (2) while-loop
% The while loop has 3 sections:
%   (1) STATE-DEPENDENT section: sets variables as a function of state
%   (2) TIME-DEPENDENT section: sets variables as a function of time 
%   (3) DRAW section: PTB-based drawing

while ~p.trVars.exitWhileLoop

    % Increment while-loop iteration counter (used to index onlineGaze etc.)
    p.trVars.whileLoopIdx = p.trVars.whileLoopIdx + 1;

    % Update eye / joystick position:
    p = pds.getEyeJoy(p);
    
    %% Mouse based gaze
    p = pds.getMouse(p);
    if isfield(p.trVars, 'mouseEyeSim') && p.trVars.mouseEyeSim == 1
    p.trVars.eyePixX = p.trVars.mouseCursorX - p.draw.middleXY(1);
    p.trVars.eyePixY = p.trVars.mouseCursorY - p.draw.middleXY(2);
    p.trVars.eyeDegX = pds.pix2deg(p.trVars.eyePixX, p);
    p.trVars.eyeDegY = pds.pix2deg(-p.trVars.eyePixY, p);
    end

    p.trData.onlineEyeX(p.trVars.whileLoopIdx) = p.trVars.eyeDegX;
    p.trData.onlineEyeY(p.trVars.whileLoopIdx) = p.trVars.eyeDegY;
    
     % Store gaze position and compute online eye velocity
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
        p.init.strb.strobeNow(p.init.codes.trialBegin);
        p.trData.timing.trialBegin      = timeNow;
        p.trVars.currentState           = p.state.showFix;

    case p.state.showFix
        %% STATE 3:
        %   SHOW FIXATION POINT AND WAIT FOR
        %   SUBJECT TO ACQUIRE FIXATION.
        
        % show fixatoin point & fixation window on exp-display
        p.draw.color.fix                = p.draw.clutIdx.expWhite_subWhite;
        
        % set fixation window color:
        p.draw.color.fixWin         = p.draw.clutIdx.expGrey25_subBg;
        p.draw.fixWinPenDraw = p.draw.fixWinPenPre;
        
        % we only want to strobe this once:
        p.init.strb.addValueOnce(p.init.codes.fixOn);
        
        % If "fixOn" time hasn't been defined, and we haven't already
        % indicated that "fixOn" should be defined after the next flip,
        % indicate that "fixOn" should be defined after the next flip and
        % strobe "fixOn" after the next flip.
        if p.trData.timing.fixOn < 0 ...
                && ~ismember('fixOn', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical           = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOn';
            p.init.strb.addValueOnce(p.init.codes.fixOn);
        end
        
        % If fixation is aquired within alotted time, move on to 
        % p.state.dontMove:
        if pds.eyeInWindow(p) && ...
                timeNow < (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            
            p.init.strb.strobeNow(p.init.codes.fixAq);
            p.trData.timing.fixAq      = timeNow;
            p.trVars.currentState      = p.state.dontMove;
            
        elseif p.trData.timing.fixOn > 0 && timeNow > ...
                (p.trData.timing.fixOn + p.trVars.fixWaitDur)
            % fixation was never acquired
            p.init.strb.strobeNow(p.init.codes.nonStart);
            p.trData.timing.joyRelease = timeNow;
            p.trVars.currentState      = p.state.nonStart;
        end
        
    case p.state.dontMove
        %% STATE 4:
        %   "DON'T MOVE" - SUBJECT HOLDS FIXATION.
        
        % Calculate elapsed time since fixation acquisition
        timeFromFixAq = timeNow - p.trData.timing.fixAq;
        
        % If fixation has been held for the requisite duration: 
        % strobe "hit" code to recording system,
        % 
        % advance to the "hit" state,
        % and play a tone indicating successful trial completion.
        if p.trData.timing.fixAq > 0 && ...
                timeFromFixAq > p.trVars.fixDurReq
            % p.init.strb.strobeNow(p.init.codes.hit); % Must change to fixation completed
            p.trData.timing.fixHoldReqMet = timeNow;
            
            p.trVars.currentState = p.state.MakeSaccade;

            % p.trVars.currentState      = p.state.hit; %Will go on end
            % p = playTone(p, 'high'); % When completed
            
        elseif ~pds.eyeInWindow(p)
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak   = timeNow;
            p.trVars.currentState      = p.state.fixBreak;
            
        end


    case p.state.MakeSaccade
        %% State 
        % After The go signal, the subject must make a saccade to one ef
        % the two targets
        %
        % Give the GoSignal
        % Calculate the time since go signal
        % Wait for a saccade 
        %   - Eye Velocity increase
        %   - Fixqtion break
        %   - Within the given time
        % If Saccade detected ;
            % Check Landing of saccade ;
            %   - If landing point is within the acceptable distance ;
            %       - Give reward
            %   -If out ;
            %       -abort
        % Else ; 
            % No response
        %Next trial


        % Go signal given - 
        %   show T1 now
        %   show T2 now
        %   erase Fixation
        p.trVars.fixationVisible = false;
        p.trVars.T1_visible = p.trVars.T1_present;
        p.trVars.T2_visible = p.trVars.T2_present;
        p.draw.color.fix = p.draw.color.background;

        %Strobe Go signal

        % Ensure go-signal (fixation offset) is timestamped once on a real flip
        if p.trData.timing.fixOff < 0 && ...
                ~ismember('fixOff', p.trVars.postFlip.varNames)
            p.trVars.postFlip.logical = true;
            p.trVars.postFlip.varNames{end + 1} = 'fixOff';

            % Strobe fixOff once, if code exists
            if isfield(p.init.codes, 'fixOff')
                p.init.strb.addValueOnce(p.init.codes.fixOff);
            end
        end

        
        timeSinceGo = -1;
        % Calculate time since Go :
        if p.trData.timing.fixOff > 0 || p.trVars.passEye
            timeSinceGo = timeNow - p.trData.timing.fixOff;         %Time since go doesnt exist if not fixOff or passeye
        end

        % Check for saccade :
        eyeLeftFixWin = ~pds.eyeInWindow(p);
        velocityExceedsThresh = gazeVelThreshCheck(p, timeNow) || p.trVars.passEye;
        
        if (eyeLeftFixWin && velocityExceedsThresh && ...
                timeSinceGo < p.trVars.responseWindow) || p.trVars.passEye
        % Valid saccade initiation
            p.init.strb.strobeNow(p.init.codes.saccadeOnset);
            p.trData.timing.saccadeOnset = timeNow;
            % disp(p.trData.timing.saccadeOnset)
            p.trVars.currentState = p.state.checkLanding;
            p.draw.fixWinPenDraw = p.draw.fixWinPenThin;
            disp('saccadeMade')

        elseif p.trData.timing.fixOff > 0 && ...
                timeSinceGo > p.trVars.responseWindow

            % No saccade within response window
            p.init.strb.strobeNow(p.init.codes.noResponse);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.noResponse;
            disp(['no response after ' num2str(timeSinceGo * 1000) ' ms'])

        end

    case p.state.checkLanding
        %% State Check Landing
        % Check Landing of saccade ;
        %   - If landing point is within the acceptable distance ;
        %       - Give reward
        %   -If out ;
        %       -abort 


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

        % Check only target windows that are actually presented.
        gazeInT2Target = p.trVars.T2_present && eyeInTargetWindow(p, 'T2');
        gazeInT1Target = p.trVars.T1_present && eyeInTargetWindow(p, 'T1');

        % In passEye mode, choose the only shown target on instruction
        % trials and the rich target on two-target trials.
        if p.trVars.passEye
            simulatedSide = simulatedChoiceSide(p);
            gazeInT1Target = p.trVars.T1_present && p.trVars.T1Side == simulatedSide;
            gazeInT2Target = p.trVars.T2_present && p.trVars.T2Side == simulatedSide;
            sacInFlight = false;
            blinkDetected = false;
        end

        if sacInFlight
            % Saccade still in flight - continue waiting

        elseif blinkDetected
            disp('blink detected');
            p.init.strb.strobeNow(p.init.codes.blinkDuringSac);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;

        elseif gazeInT2Target
            % Saccade landed in the T2 target window, wherever T2 is.
            p.init.strb.strobeNow(p.init.codes.saccadeOffset);
            p.trData.timing.saccadeOffset = timeNow;
            p.trData.chosenTargetID = 2;
            p.trData.chosenSide = p.trVars.T2Side;
            p.trVars.currentState = p.state.holdTarg;
            p.init.strb.strobeNow(p.init.codes.targetAq);
            p.trData.timing.targetAq = timeNow;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;

        elseif gazeInT1Target
            % Saccade landed in the T1 target window, wherever T1 is.
            p.init.strb.strobeNow(p.init.codes.saccadeOffset);
            p.trData.timing.saccadeOffset = timeNow;
            p.trData.chosenTargetID = 1;
            p.trData.chosenSide = p.trVars.T1Side;
            p.trVars.currentState = p.state.holdTarg;
            p.init.strb.strobeNow(p.init.codes.targetAq);
            p.trData.timing.targetAq = timeNow;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;

        else
            % Saccade landed outside both target windows - inaccurate
            p.init.strb.strobeNow(p.init.codes.inaccurate);
            p.trData.timing.fixBreak = timeNow;
            p.trData.chosenSide = 0;
            p.trData.chosenTargetID = 0;
            p.trVars.currentState = p.state.inaccurate;
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            disp('inaccurate - outside both targets')
        end


    case p.state.holdTarg
        %% State On tqrget
        % p.trData.chosenSide stores the spatial side (1=right, 2=left),
        % while p.trData.chosenTargetID stores target identity (T1/T2).

        % Check the window belonging to the chosen TARGET ID. Target
        % identity can switch sides from one trial to the next.
        if p.trData.chosenTargetID == 1
            eyeInChosenTarget = eyeInTargetWindow(p, 'T1');
        elseif p.trData.chosenTargetID == 2
            eyeInChosenTarget = eyeInTargetWindow(p, 'T2');
        else
            eyeInChosenTarget = false;
        end

        % disp("Chosen Target ;");
        % disp(eyeInChosenTarget)

        % Check if target hold duration has been met
        holdTimeElapsed = ...
            timeNow > p.trData.timing.saccadeOffset + p.trVars.targHoldDuration;
    
        % disp('Hold Time elapsed ;');
        % disp(holdTimeElapsed)

        if eyeInChosenTarget && holdTimeElapsed || p.trVars.passEye
            % Successfully held target - proceed to reward/outcome
            p.trVars.currentState = p.state.sacComplete;
            p.draw.targWinPenDraw = p.draw.targWinPenThick;
        elseif ~eyeInChosenTarget
            % Gaze left target window before hold complete
            p.init.strb.strobeNow(p.init.codes.fixBreak);
            p.trData.timing.fixBreak = timeNow;
            p.trVars.currentState = p.state.fixBreak;
            p.draw.targWinPenDraw = p.draw.targWinPenThin;
            disp('target break');
        end


    case p.state.noResponse
        %% State noResponse
        % If subject doesnt make a saccade in the correct delay after Go
        % Abort trial
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true; 
        
    case p.state.inaccurate
        %% State Inaccurate : saccade too away from target
        p = playTone(p, 'low');
        p.trVars.exitWhileLoop = true;


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% end states: trial COMPLETED %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    case p.state.sacComplete
        % Trial completed - determine outcome and deliver reward

        % disp('Enter in state SacComplete');

        % Classify instruction trials separately from two-target choices.
        if p.trVars.nStim == 1
            p.trData.choseHighSalience = true;
            if p.trVars.singleTargetID == 1
                p.trData.outcome = 'SINGLE_T1_CORRECT';
                p.trData.outcomeCode = 10;
            else
                p.trData.outcome = 'SINGLE_T2_CORRECT';
                p.trData.outcomeCode = 11;
            end
        elseif p.trData.chosenSide == p.status.highSalienceSide
            p.trData.choseHighSalience = true;
            p.trData.outcome = 'CHOSE_HIGH_SAL';
            p.trData.outcomeCode = 1;
        else
            p.trData.choseHighSalience = false;
            p.trData.outcome = 'CHOSE_LOW_SAL';
            p.trData.outcomeCode = 2;
        end

        % Give the reward corresponding
        % Determine reward based on chosen SIDE (left or right)
        if p.trData.chosenSide == 2
            % Chose LEFT target
            p.trVars.currentRewardDuration = round(p.trVars.rewardDurationLeft);
        else
            % Chose RIGHT target
            p.trVars.currentRewardDuration = round(p.trVars.rewardDurationRight);
        end


         % Check if reward given & delay  ; exit loop
         
        if p.trData.timing.reward < 0
            % Reward not yet delivered - deliver it now
            % Temporarily set rewardDurationMs for the pds.deliverReward function
            p.trVars.rewardDurationMs = p.trVars.currentRewardDuration;
            % disp(p.trVars.rewardDurationMs)
            p = playTone(p, 'high');
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


    case p.state.hit
        %% HIT!
        % STATE 21 = reward delivery
        p.trVars.T1_visible = false;  % Desapear T1
        
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

    % note trial end state
    p.trData.trialEndState = p.trVars.currentState;
    
    % and strobe end of trial once:
    p.init.strb.strobeNow(p.init.codes.trialEnd);
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

% In DKL hue mode, exp-only colors need subject rows that match the
% current DKL background, otherwise the subject sees debug overlays.
p.draw.color.joyInd = expOnlyColorForCurrentBg(p, p.draw.color.joyInd);

% now calculate size of joystick-fill rectangle
joyRectNow = pds.joyRectFillCalc(p);


% if we're close enough in time to the next screen flip, start drawing.
if timeNow > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber

    % Fill the window with the background color.
    Screen('FillRect', p.draw.window, p.draw.color.background);
    
    % Draw the grid
    Screen('DrawLines', p.draw.window, p.draw.gridXY, [], expOnlyColorForCurrentBg(p, p.draw.color.gridMajor));
    
    % Draw the gaze position, MUST DRAW THE GAZE BEFORE THE
    % FIXATION. Otherwise, when the gaze indicator goes over any
    % stimuli it will change the occluded stimulus' color!
    gazePosition = [p.trVars.eyePixX p.trVars.eyePixY p.trVars.eyePixX p.trVars.eyePixY] + ...
        [-1 -1 1 1]*p.draw.eyePosWidth + repmat(p.draw.middleXY, 1, 2);
    Screen('FillRect', p.draw.window, expOnlyColorForCurrentBg(p, p.draw.color.eyePos), gazePosition);
    
  
    % draw fixation spot
    Screen('FrameRect',p.draw.window, p.draw.color.fix, repmat(p.draw.fixPointPix, 1, 2) + ...
        p.draw.fixPointRadius*[-1 -1 1 1], p.draw.fixPointWidth);
    
    % draw fixation window
    Screen('FrameRect',p.draw.window, expOnlyColorForCurrentBg(p, p.draw.color.fixWin), repmat(p.draw.fixPointPix, 1, 2) +  ...
        [-p.draw.fixWinWidthPix -p.draw.fixWinHeightPix ...
        p.draw.fixWinWidthPix p.draw.fixWinHeightPix], p.draw.fixWinPenDraw)
    
    % Draw the joystick-bar graphic.
    Screen('FrameRect', p.draw.window, p.draw.color.joyInd, p.draw.joyRect);
    Screen('FillRect',  p.draw.window, p.draw.color.joyInd, joyRectNow);

    %% Draw T1 and T2
    
        % Draw T1 rectangle (3:1 ratio, long axis = 2°)
    if p.trVars.T1_visible
    % Create rectangle centered at T1 position
    % T1 is a rectangle with width = shortAxis, height = longAxis
    T1_rect = CenterRectOnPoint(...
    [0 0 p.draw.T1_longAxisPix p.draw.T1_shortAxisPix], ...
    p.draw.T1_locPixX, p.draw.T1_locPixY);
   
    % Draw filled rectangle
    Screen('FillRect', p.draw.window, p.trVars.T1_colorIdx, T1_rect);
    
    % % Optionally draw a border
    % Screen('FrameRect', p.draw.window, p.draw.clutIdx.expBlack_subBg, ...
    % T1_rect, 2); % 2-pixel border
    end

        % Draw T2 rectangle (3:1 ratio, long axis = 2°) vertical
    if p.trVars.T2_visible
    % Create rectangle centered at T2 position
    % T2 is a rectangle with width = longAxis, height =  shortAxis
    T2_rect = CenterRectOnPoint(...
    [0 0 p.draw.T2_shortAxisPix p.draw.T2_longAxisPix], ...
    p.draw.T2_locPixX, p.draw.T2_locPixY);
    
    % Draw filled rectangle
    Screen('FillRect', p.draw.window, p.trVars.T2_colorIdx, T2_rect);

    % % Optionally draw a border
    % Screen('FrameRect', p.draw.window, p.draw.clutIdx.expBlack_subBg, ...
    % T2_rect, 2); % 2-pixel border
    end

    %% Draw target acceptance windows (same geometry as eyeInTargetWindow)
    % Convert half-width/half-height from deg -> pix
    targHalfWpix = pds.deg2pix(p.trVars.targWinWidthDeg, p);
    targHalfHpix = pds.deg2pix(p.trVars.targWinHeightDeg, p);
    % Choose color/pen (reuse existing style vars if present)
    if isfield(p.draw, 'targWinColor')
        targWinColor = p.draw.targWinColor;
    else
        targWinColor = p.draw.clutIdx.expGrey70_subBg;
    end
    if isfield(p.draw, 'targWinPenDraw')
        targWinPen = p.draw.targWinPenDraw;
    else
        targWinPen = 2;
    end
    % Draw only acceptance windows belonging to presented targets.
    if p.trVars.T1_present
        T1_winRect = [ ...
            p.draw.T1_locPixX - targHalfWpix, ...
            p.draw.T1_locPixY - targHalfHpix, ...
            p.draw.T1_locPixX + targHalfWpix, ...
            p.draw.T1_locPixY + targHalfHpix];
        Screen('FrameRect', p.draw.window, ...
            expOnlyColorForCurrentBg(p, targWinColor), T1_winRect, targWinPen);
    end

    if p.trVars.T2_present
        T2_winRect = [ ...
            p.draw.T2_locPixX - targHalfWpix, ...
            p.draw.T2_locPixY - targHalfHpix, ...
            p.draw.T2_locPixX + targHalfWpix, ...
            p.draw.T2_locPixY + targHalfHpix];
        Screen('FrameRect', p.draw.window, ...
            expOnlyColorForCurrentBg(p, targWinColor), T2_winRect, targWinPen);
    end

%   %% Draw high-reward indicator (green frame around high-reward target)
% % Convention in this task:
% %   highRewardTargetID identifies T1/T2 independently of side
    % disp(p.status.highRewardSide)
    % Draw the rich-target indicator only if that identity is present.
    richTargetPresent = ...
        (p.status.highRewardTargetID == 1 && p.trVars.T1_present) || ...
        (p.status.highRewardTargetID == 2 && p.trVars.T2_present);

    if isfield(p.status, 'highRewardTargetID') && richTargetPresent
        s = 1.15;
        hw = s * pds.deg2pix(p.trVars.targWinWidthDeg, p);
        hh = s * pds.deg2pix(p.trVars.targWinHeightDeg, p);

        if p.status.highRewardTargetID == 1
            cx = p.draw.T1_locPixX;
            cy = p.draw.T1_locPixY;
        else
            cx = p.draw.T2_locPixX;
            cy = p.draw.T2_locPixY;
        end

        rewardRect = [cx-hw cy-hh cx+hw cy+hh];
        Screen('FrameRect', p.draw.window, ...
            expOnlyColorForCurrentBg(p, p.draw.clutIdx.expGreen_subBg), ...
            rewardRect, 4);
    end

    % if p.status.ActualTrialType == 1, trialtype = 'Congruent' ;
    % else,    trialtype = 'Conflict'; end        
    % disp('Actual trial type');
    % disp(trialtype);
    % disp('Salience Side ;');
    % disp(p.status.highSalienceSide);
    % disp('Reward Side ;');
    % disp(p.status.highRewardSide);


    % flip and store time of flip.
    [p.trData.timing.flipTime(p.trVars.flipIdx), ~, ~, frMs] = Screen('Flip', p.draw.window);
    p.trData.timing.lastFrameTime   = p.trData.timing.flipTime(p.trVars.flipIdx) - ...
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




%% -------------------- EXP-ONLY COLOR MAPPING FOR DKL BACKGROUND --------------------
function outIdx = expOnlyColorForCurrentBg(p, inIdx)
% Convert exp-only colors to variants whose subject color matches the
% current DKL background.
%
% Only do this in hue/contrast mode. In luminance mode, the normal SRS
% background is used, so the original _subBg colors are already correct.

outIdx = inIdx;

if ~isfield(p.trVars, 'salienceType') || p.trVars.salienceType ~= 1
    return
end

idx = p.draw.clutIdx;
bgIdx = p.trVars.backgroundHueIdx;

if bgIdx == 1
    if inIdx == idx.expGrey25_subBg
        outIdx = idx.expGrey25_subDkl0;
    elseif inIdx == idx.expGrey70_subBg
        outIdx = idx.expGrey70_subDkl0;
    elseif inIdx == idx.expGrey90_subBg
        outIdx = idx.expGrey90_subDkl0;
    elseif inIdx == idx.expBlue_subBg
        outIdx = idx.expBlue_subDkl0;
    elseif inIdx == idx.expOrange_subBg
        outIdx = idx.expOrange_subDkl0;
    elseif inIdx == idx.expGreen_subBg
        outIdx = idx.expGreen_subDkl0;
    elseif inIdx == idx.expBlack_subBg
        outIdx = idx.expBlack_subDkl0;
    end
else
    if inIdx == idx.expGrey25_subBg
        outIdx = idx.expGrey25_subDkl180;
    elseif inIdx == idx.expGrey70_subBg
        outIdx = idx.expGrey70_subDkl180;
    elseif inIdx == idx.expGrey90_subBg
        outIdx = idx.expGrey90_subDkl180;
    elseif inIdx == idx.expBlue_subBg
        outIdx = idx.expBlue_subDkl180;
    elseif inIdx == idx.expOrange_subBg
        outIdx = idx.expOrange_subDkl180;
    elseif inIdx == idx.expGreen_subBg
        outIdx = idx.expGreen_subDkl180;
    elseif inIdx == idx.expBlack_subBg
        outIdx = idx.expBlack_subDkl180;
    end
end

end

%% -------------------- EYE IN TARGET WINDOW --------------------
function inWindow = eyeInTargetWindow(p, targetID)
% Check if eye position is within specified target window.
% targetID: 'T1' or 'T2'

if strcmp(targetID, 'T1')
    targX = p.trVars.T1_locDegX;
    targY = p.trVars.T1_locDegY;
else
    targX = p.trVars.T2_locDegX;
    targY = p.trVars.T2_locDegY;
end

% Check if gaze is within target window (using half-widths)
halfWidth = p.trVars.targWinWidthDeg;
halfHeight = p.trVars.targWinHeightDeg;

inWindow = abs(p.trVars.eyeDegX - targX) < halfWidth && ...
           abs(p.trVars.eyeDegY - targY) < halfHeight;

end
%% -------------------- TARGET IDENTITY / SIDE HELPERS --------------------
function targetID = targetAtSide(p, side)
%TARGETATSIDE Return target identity currently assigned to a spatial side.

if p.trVars.T1Side == side
    targetID = 1;
elseif p.trVars.T2Side == side
    targetID = 2;
else
    targetID = 0;
end

end

function side = simulatedChoiceSide(p)
%SIMULATEDCHOICESIDE Select a valid side when passEye is enabled.

if p.trVars.nStim == 1
    if p.trVars.singleTargetID == 1
        side = p.trVars.T1Side;
    else
        side = p.trVars.T2Side;
    end
else
    side = p.status.highRewardSide;
end

end
