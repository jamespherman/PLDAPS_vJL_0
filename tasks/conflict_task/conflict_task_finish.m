function p = conflict_task_finish(p)
%   p = conflict_task_finish(p)
%
% Part of the quintet of PLDAPS functions:
%   settings function - defines default parameters
%   init function     - one-time setup
%   next function     - runs before each trial
%   run function      - executes each trial
%   finish function   - runs after each trial (this file)
%
% This function runs at the end of every trial. It handles data saving,
% online plot updates, trial status updates, and next trial preparation.

%% Clear screen and read buffered data

% Fill screen with background color to clear display
Screen('FillRect', p.draw.window, p.draw.color.background);
Screen('Flip', p.draw.window);

% Read buffered ADC (eye position) and DIN data from DATAPixx
p = pds.readDatapixxBuffers(p);

% Determine if trial should be repeated (was it an error?)
% Repeat if: fixBreak, joyBreak, nonStart, noResponse, or inaccurate
% Do NOT repeat: sacComplete (goal-directed or capture are both valid)
p.trData.trialRepeatFlag = ismember(p.trData.trialEndState, ...
    [p.state.fixBreak, p.state.joyBreak, p.state.nonStart, ...
     p.state.noResponse, p.state.inaccurate]);

%% Strobe trial data to neural recording system

p = pds.strobeTrialData(p);

% Strobe end-of-trial code
timeNow = GetSecs - p.trData.timing.trialStartPTB;
p.trData.timing.trialEnd = timeNow;
p.init.strb.strobeNow(p.init.codes.trialEnd);

% Save list of strobed codes for this trial
p.trData.strobed = p.init.strb.strobedList;

%% Wait for joystick release before proceeding

p = pds.waitForJoystickRelease(p);

% Apply time-out if trial was an error
if p.trData.trialRepeatFlag
    postTrialTimeOut(p);
end

%% Retrieve neural data from Ripple if connected

if p.rig.ripple.status && ~isempty(p.rig.ripple.recChans)
    p = pds.getRippleData(p);
end

%% Calculate saccade parameters (endpoints, velocity, reaction time)

p = calcSacParams(p);

%% Save data backup

pds.saveP(p);

%% Update status variables (trial counts, outcome counts, etc.)

p = updateStatusVariables(p);

%% Update online plots (tachometric curve) for completed trials

if p.trData.trialEndState == p.state.sacComplete
    p = updateOnlinePlots(p);
end

%% Update trials list if using trial array method

if p.trVars.setTargLocViaTrialArray
    p = updateTrialsList(p);
end

%% Flush strobe lists for next trial

p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

end

%% -------------------- CALCULATE SACCADE PARAMETERS --------------------
function p = calcSacParams(p)
% Computes saccade metrics: start/end positions, peak velocity, reaction
% time, and processing time.

try
    if p.trVars.passEye
        % Generate simulated saccade data for testing
        P = [0.0085 -0.4509 6.6532 9.9220 256.3290];
        myFun = @(x)P(1)*x.^4 + P(2)*x.^3 + P(3)*x.^2 + ...
            P(4)*x + P(5) + randn(size(x)).*(x*4 + 25);

        % Use chosen target location for simulated endpoint
        if p.trData.chosenSide == 1
            % Chose LEFT target
            targX = p.trVars.leftTarg_degX;
            targY = p.trVars.leftTarg_degY;
        else
            % Chose RIGHT target
            targX = p.trVars.rightTarg_degX;
            targY = p.trVars.rightTarg_degY;
        end

        p.trData.postSacXY = [targX, targY] + randn(1,2)/20;
        p.trData.peakVel = myFun(sum(p.trData.postSacXY.^2)^0.5);
        p.trData.preSacXY = [0, 0];
        p.trData.SRT = 0.25 + randn/10;
        p.trData.processingTime = p.trData.SRT + p.trVars.deltaT/1000;

        p.trData.trialEndState = p.state.sacComplete;

    elseif p.trData.trialEndState == p.state.sacComplete

        % Get ADC buffered gaze data (X, Y, T)
        T = p.trData.timing.trialStartPTB + p.trData.eyeT - ...
            p.trData.timing.trialStartDP;
        X = 4 * p.trData.eyeX;
        Y = 4 * p.trData.eyeY;

        % Compute total velocity using smoothed differentiation
        Vsd = ((1000*smoothdiff(X)).^2 + ...
            (1000*smoothdiff(Y)).^2).^0.5;

        % Index samples before and after saccade
        sacOnsetPTB = p.trData.timing.saccadeOnset + ...
            p.trData.timing.trialStartPTB;
        preSacFix = Vsd < p.trVars.eyeVelThreshOffline & ...
            T < sacOnsetPTB;
        postSacFix = Vsd < p.trVars.eyeVelThreshOffline & ...
            T > (sacOnsetPTB + 0.01);

        % Compute saccade onset and offset times (in absolute PTB time)
        saccadeOnsetTimeAbs = max(T(preSacFix));
        saccadeOffsetTimeAbs = min(T(postSacFix));

        % Convert to trial-relative time for consistency with other timing variables
        saccadeOnsetTime = saccadeOnsetTimeAbs - p.trData.timing.trialStartPTB;
        saccadeOffsetTime = saccadeOffsetTimeAbs - p.trData.timing.trialStartPTB;

        if ~isempty(saccadeOnsetTimeAbs) && ~isempty(saccadeOffsetTimeAbs)

            % Find peak velocity during saccade (use absolute times for comparison with T)
            g = T > saccadeOnsetTimeAbs & T < saccadeOffsetTimeAbs;
            p.trData.peakVel = max(Vsd(g));

            % Compute mean gaze position 5ms before and after saccade
            preSacTime = T < saccadeOnsetTimeAbs & ...
                T >= (saccadeOnsetTimeAbs - 0.005);
            postSacTime = T > saccadeOffsetTimeAbs & ...
                T <= (saccadeOffsetTimeAbs + 0.005);

            p.trData.preSacXY = ...
                [mean(X(preSacTime)), mean(Y(preSacTime))];
            p.trData.postSacXY = ...
                [mean(X(postSacTime)), mean(Y(postSacTime))];

            % Compute saccade reaction time relative to go signal
            p.trData.SRT = saccadeOnsetTime - p.trData.timing.fixOff;

            % Compute processing time (RT + delta-t)
            % Processing time = time available for stimulus to inform choice
            p.trData.processingTime = p.trData.SRT + p.trVars.deltaT/1000;

        else
            p.trData.peakVel = NaN;
            p.trData.preSacXY = NaN(1,2);
            p.trData.postSacXY = NaN(1,2);
            p.trData.SRT = NaN;
            p.trData.processingTime = NaN;
        end
    else
        p.trData.peakVel = NaN;
        p.trData.preSacXY = NaN(1,2);
        p.trData.postSacXY = NaN(1,2);
        p.trData.SRT = NaN;
        p.trData.processingTime = NaN;
    end
catch me
    % Error during calculation - allow debugging
    disp('Error in calcSacParams:');
    disp(me.message);
end

end

%% -------------------- SMOOTHED DIFFERENTIATION FILTER --------------------
function y = smoothdiff(x)
% Applies a smoothed differentiation filter to compute velocity.

b = zeros(29,1);
b(1)  = -4.3353241e-04 * 2*pi;
b(2)  = -4.3492899e-04 * 2*pi;
b(3)  = -4.8506188e-04 * 2*pi;
b(4)  = -3.6747546e-04 * 2*pi;
b(5)  = -2.0984645e-05 * 2*pi;
b(6)  =  5.7162272e-04 * 2*pi;
b(7)  =  1.3669190e-03 * 2*pi;
b(8)  =  2.2557429e-03 * 2*pi;
b(9)  =  3.0795928e-03 * 2*pi;
b(10) =  3.6592020e-03 * 2*pi;
b(11) =  3.8369002e-03 * 2*pi;
b(12) =  3.5162346e-03 * 2*pi;
b(13) =  2.6923104e-03 * 2*pi;
b(14) =  1.4608032e-03 * 2*pi;
b(15) =  0.0;
b(16:29) = -b(14:-1:1);

x = x(:);
y = filter(b, 1, x);
y = [y(15:length(x), :); zeros(14, 1)]';

end
