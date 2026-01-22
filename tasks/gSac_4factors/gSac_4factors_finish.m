function p = gSac_4factors_finish(p)
%   p = gSac_4factors_finish(p)
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

% Determine if trial should be repeated (was it aborted?)
p.trData.trialRepeatFlag = ismember(p.trData.trialEndState, ...
    [p.state.fixBreak, p.state.joyBreak, p.state.nonStart]);

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

% Apply time-out if desired (only adds delay if not enough time has
% elapsed since trial end)
postTrialTimeOut(p);

%% Retrieve neural data from Ripple if connected

if p.rig.ripple.status && ~isempty(p.rig.ripple.recChans)
    p = pds.getRippleData(p);
end

%% Calculate saccade parameters (endpoints, velocity, reaction time)

p = calcSacParams(p);

%% Save data backup

pds.saveP(p);

%% Update status variables (trial counts, success rates, etc.)

p = updateStatusVariables(p);

%% Update online plots for successful trials
% Always update metrics plots (pkV, RT, err by target location) for
% successful trials. Gaze trace plots are only updated if wantOnlinePlots
% is true (controlled within updateOnlinePlots).

if p.trData.trialEndState == p.state.sacComplete
    p = updateOnlinePlots(p);
end

%% Update trials list if using trial array method

if p.trVars.setTargLocViaTrialArray
    p = updateTrialsList(p);
end

%% Post-trial GUI interaction (if saccade mapping GUI is present)

if isfield(p.rig, 'guiData')
    p = postTrialGui(p);
end

%% Flush strobe lists for next trial

p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

end

%% -------------------- POST-TRIAL GUI UPDATE --------------------
function p = postTrialGui(p)
% Updates saccade mapping GUI with data from successful trials.
% Stores saccade parameters and spike/event data for online analysis.

% Only process successful trials
if p.trData.trialEndState == p.state.sacComplete

    % Check if target location already exists in sacDataArray
    rowIndex = ...
        p.rig.guiData.sacDataArray(:, 1) == p.trVars.targDegX & ...
        p.rig.guiData.sacDataArray(:, 2) == p.trVars.targDegY;

    if any(rowIndex)
        % Update existing row with saccade parameters
        p.rig.guiData.sacDataArray(rowIndex, 3:end) = [...
            p.trData.preSacXY, p.trData.postSacXY, ...
            p.trData.peakVel, p.trData.SRT, true];
    else
        % Add new row for this target location
        try
            p.rig.guiData.sacDataArray(end + 1, :) = [...
                p.trVars.targDegX, p.trVars.targDegY, ...
                p.trData.preSacXY, p.trData.postSacXY, ...
                p.trData.peakVel, p.trData.SRT, true];
        catch me
            keyboard
        end
    end

    % Get spike times and event data for online neural analysis
    % Ripple's buffer includes last 1024 spikes regardless of retrieval
    % time, so filter to only new spikes within this trial's events
    if ~isempty(p.trData.spikeTimes) && ~isempty(p.trData.eventValues)
        newSpikes = p.trData.spikeTimes(...
            p.trData.spikeTimes > p.trData.eventTimes(1) & ...
            p.trData.spikeTimes < p.trData.eventTimes(end));

        % Initialize or append to spikesAndEvents structure
        if isempty(p.rig.guiData.spikesAndEvents)
            % First successful trial - create structure
            tempSAE = struct;
            tempSAE.spikeTimes = {newSpikes};
            tempSAE.eventTimes = {p.trData.eventTimes};
            tempSAE.eventValues = {p.trData.eventValues};
        else
            % Append to existing structure
            tempSAE = p.rig.guiData.spikesAndEvents;
            tempSAE.spikeTimes(end+1) = {newSpikes};
            tempSAE.eventTimes(end+1) = {p.trData.eventTimes};
            tempSAE.eventValues(end+1) = {p.trData.eventValues};
        end

        % Assign to trigger GUI update
        p.rig.guiData.spikesAndEvents = tempSAE;
    end

end

end

%% -------------------- CALCULATE SACCADE PARAMETERS --------------------
function p = calcSacParams(p)
% Computes saccade metrics: start/end positions, peak velocity, and
% reaction time. Uses offline velocity threshold for precision.

try
    if p.trVars.passEye
        % Generate simulated saccade data for GUI testing
        P = [0.0085 -0.4509 6.6532 9.9220 256.3290];
        myFun = @(x)P(1)*x.^4 + P(2)*x.^3 + P(3)*x.^2 + ...
            P(4)*x + P(5) + randn(size(x)).*(x*4 + 25);

        p.trData.postSacXY = ...
            [p.trVars.targDegX, p.trVars.targDegY] + randn(1,2)/20;
        p.trData.peakVel = myFun(sum(p.trData.postSacXY.^2)^0.5);
        p.trData.preSacXY = [0, 0];
        p.trData.SRT = 0.25 + randn/10;

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

        % Index samples before and after saccade with velocity below
        % offline threshold
        sacOnsetPTB = p.trData.timing.saccadeOnset + ...
            p.trData.timing.trialStartPTB;
        preSacFix = Vsd < p.trVars.eyeVelThreshOffline & ...
            T < sacOnsetPTB;
        postSacFix = Vsd < p.trVars.eyeVelThreshOffline & ...
            T > (sacOnsetPTB + 0.01);

        % Compute saccade onset and offset times
        saccadeOnsetTime = max(T(preSacFix));
        saccadeOffsetTime = min(T(postSacFix));

        % Calculate saccade parameters if timing is valid
        if ~isempty(saccadeOnsetTime) && ~isempty(saccadeOffsetTime)

            % Find peak velocity during saccade
            g = T > saccadeOnsetTime & T < saccadeOffsetTime;
            p.trData.peakVel = max(Vsd(g));

            % Compute mean gaze position 5ms before and after saccade
            preSacTime = T < saccadeOnsetTime & ...
                T >= (saccadeOnsetTime - 0.005);
            postSacTime = T > saccadeOffsetTime & ...
                T <= (saccadeOffsetTime + 0.005);

            % Store mean pre- and post-saccade positions
            p.trData.preSacXY = ...
                [mean(X(preSacTime)), mean(Y(preSacTime))];
            p.trData.postSacXY = ...
                [mean(X(postSacTime)), mean(Y(postSacTime))];

            % Compute saccade reaction time relative to go signal
            p.trData.SRT = saccadeOnsetTime - p.trData.timing.fixOff;

        else
            % Invalid timing - set NaN values
            p.trData.peakVel = NaN;
            p.trData.preSacXY = NaN(1,2);
            p.trData.postSacXY = NaN(1,2);
            p.trData.SRT = NaN;
        end
    else
        % Non-successful trial - set NaN values
        p.trData.peakVel = NaN;
        p.trData.preSacXY = NaN(1,2);
        p.trData.postSacXY = NaN(1,2);
        p.trData.SRT = NaN;
    end
catch me
    % Error during calculation - allow debugging
end

end

%% -------------------- SMOOTHED DIFFERENTIATION FILTER --------------------
function y = smoothdiff(x)
% Applies a smoothed differentiation filter to compute velocity.
% This filter reduces noise while preserving saccade dynamics.

% Define 29-tap differentiator filter coefficients
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

% Mirror coefficients for antisymmetric filter
b(16:29) = -b(14:-1:1);

% Ensure x is a column vector
x = x(:);

% Apply filter
y = filter(b, 1, x);

% Remove filter edge artifacts (14 samples at start and end)
y = [y(15:length(x), :); zeros(14, 1)]';

end
