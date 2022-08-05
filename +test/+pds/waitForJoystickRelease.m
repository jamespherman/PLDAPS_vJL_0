function p = waitForJoystickRelease(p)
%
% p = waitForJoystickRelease(p)
%

% get eye/joy voltages
p = pds.getEyeJoy(p);

% note the time
startTime = GetSecs;

% if the joystick is depressed, enter and stay in the while loop until it's
% been released.
while pds.joyHeld(p) && ~p.trVars.passJoy
    
    % Update registers for GetAdcStatus. Then check status, and enable
    % free running mode if there's no schedule running.
    Datapixx('RegWrRd');
    status = Datapixx('GetAdcStatus');
    if ~status.scheduleRunning && status.freeRunning == 0
        Datapixx('EnableAdcFreeRunning');
    end
    
    % Given joystick state, determine color for joystick indicator:
    [~, joyState] = pds.joyHeld(p);
    switch joyState
        case -1 % pressed in low voltage
            p.draw.color.joyInd = p.draw.clutIdx.expBlue_subBg;   
        case 0 % released
            p.draw.color.joyInd = p.draw.clutIdx.expGrey70_subBg;   
        case 1 % pressed in high voltage
            p.draw.color.joyInd = p.draw.clutIdx.expOrange_subBg;   
        otherwise % neither press nor released
            p.draw.color.joyInd = p.draw.clutIdx.expGrey25_subBg;   
    end

    % now calculate size of joystick-fill rectangle
    joyRectNow = pds.joyRectFillCalc(p);
    
    % check time - subject has a "c.trVars.postTrialFreeDur" second grace
    % period during which time he can hold down the joystick with no
    % audiovisual consequences. After that, the screen starts to flip from
    % light to dark with random interval accompanied by the "low" tone.
    currTime = GetSecs - startTime;
    if currTime > p.trVars.joyReleaseWaitDur && p.trVars.wantEndFlicker
        if currTime > p.trData.timing.lastFrameTime + ...
                p.rig.frameDuration - p.rig.magicNumber
            
            % fill screen with white
            Screen('FillRect', p.draw.window, ...
                p.draw.clutIdx.expWhite_subWhite)
            
            % Draw the joystick-bar graphic.
            Screen('FrameRect', p.draw.window, p.draw.color.joyInd, ...
                p.draw.joyRect);
            Screen('FillRect', p.draw.window, p.draw.color.joyInd, ...
                joyRectNow);
            
            % flip and record time of flip.
             p.trData.timing.flipTime(p.trVars.flipIdx) = ...
                 Screen('Flip', p.draw.window) - p.trData.timing.trialStartPTB;
             p.trData.timing.lastFrameTime = ...
                 p.trData.timing.flipTime(p.trVars.flipIdx);
        end
        
        % random-inter flicker / tone interval
        WaitSecs(0.05 + randn*0.05);
        
        % play low-freq tone
        p = playTone(p, 'low');
    end
    
    % check time - the monkey has a 3 second grace period during which time
    % he can hold down the joystick with no audiovisual consequences. After
    % that, the scren starts to randomly flicker and the "low" tone is
    % played with each switch from light to dark.
    currTime = GetSecs - startTime;
    if currTime > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber
        
        % fill screen with background color
        Screen('FillRect', p.draw.window, p.draw.color.background)
        
        % Draw the joystick-bar graphic.
        Screen('FrameRect', p.draw.window, p.draw.color.joyInd, p.draw.joyRect);
        Screen('FillRect', p.draw.window, p.draw.color.joyInd, joyRectNow);
        
        % flip and record time of flip.
        p.trData.timing.flipTime(p.trVars.flipIdx) = Screen('Flip', p.draw.window) - p.trData.timing.trialStartPTB;
        p.trData.timing.lastFrameTime = p.trData.timing.flipTime(p.trVars.flipIdx);
        
    end
    
    % random inter-loop interval
    WaitSecs(0.05 + randn*0.05);
    
    % get eye/joy voltages
    p = pds.getEyeJoy(p);
end