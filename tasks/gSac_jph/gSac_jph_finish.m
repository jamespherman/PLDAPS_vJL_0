function p = gSac_jph_finish(p)
%   p = gSac_jph_finish(p)
%
% Part of the quintet of pldpas functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% finish function runs at the end of every trial and is usually used to
% save data, update online plots, set stimulus for next trial, etc.


%% In this function:

% fill screen with background color
Screen('FillRect', p.draw.window, p.draw.color.background);
Screen('Flip', p.draw.window);

% read buffered ADC and DIN data from DATAPixx
p           = pds.readDatapixxBuffers(p);

% Was the previous trial aborted?
p.trData.trialRepeatFlag = ismember(p.trData.trialEndState, ...
    [p.state.fixBreak, p.state.joyBreak, p.state.nonStart]);

% (2) strobe trial data
p           = pds.strobeTrialData(p);

% and strobe end of trial once:
timeNow = GetSecs - p.trData.timing.trialStartPTB; % timeNow is relative to trial Start
p.trData.timing.trialEnd   = timeNow;
p.init.strb.strobeNow(p.init.codes.trialEnd);

% save strobed codes:
p.trData.strobed = p.init.strb.strobedList;

% (3) pause ephys
% pds.stopOmniPlex;


% wait for joystick release
p           = pds.waitForJoystickRelease(p);

% if a "time-out" is desired, make it happen here. Note: the way this works
% at present is: we only advance from here if the desired interval of time
% has elapsed since the end of the previous trial. This means that if the
% monkey has held the joystick down for a "long time" since the end of the
% last trial, the "time-out" window has passed and there won't be an
% ADDITIONAL time out.
postTrialTimeOut(p);

% retreive data from ripple "NIP" if connected:
if p.rig.ripple.status
    p = pds.getRippleData(p);
end

% calculate saccade parameters (start & end point, peak velocity, reaction
% time).
p = calcSacParams(p);

% (5) auto save backup
pds.saveP(p);

% (6) update status variables
p           = updateStatusVariables(p);

% (7) update trials list IF we're using the trials array.
if p.trVars.setTargLocViaTrialArray
    p           = updateTrialsList(p);
end

% post-trial add-on gui interaction
p = postTrialGui(p);

% flush strobe "veto" & "strobed" list
p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

% keyboard

end

%%
function p = postTrialGui(p)

% If the last trial was a success, update the list of upcoming target
% locations accordingly, and pass spike / event data to GUI.
if p.trData.trialEndState == p.state.sacComplete

    % If the saccade target location used in the just-completed trial is
    % already present in "sacDataArray", find what row it's in, add the
    % saccade parameters from the current trial and mark the row as
    % complete. Otherwise, add the data to the end of the array.
    rowIndex = p.rig.guiData.sacDataArray(:, 1) == p.trVars.targDegX & ...
        p.rig.guiData.sacDataArray(:, 2) == p.trVars.targDegY;
    if any(rowIndex)
        p.rig.guiData.sacDataArray(rowIndex, 3:end) = [...
            p.trData.preSacXY, p.trData.postSacXY, ...
            p.trData.peakVel, p.trData.SRT, true];
    else
        try
        p.rig.guiData.sacDataArray(end + 1, :) = [...
            p.trVars.targDegX, p.trVars.targDegY, p.trData.preSacXY, ...
        p.trData.postSacXY, p.trData.peakVel, p.trData.SRT, true];
        catch me
            keyboard
        end
    end

    % JPH - 2 / 22 / 2023
    % here we will get existing spike times / event values / event times
    % from the GUI, then append the ones from the just-completed trial,
    % then assign them to "p.rig.guiData.spikesAndEvents" all at once to
    % trigger a single update of the spike plot(s).

    % first, logically index all the spike times from the current trial.
    % This is necessary because Ripple's buffer includes the last 1024
    % spikes regardless of how recently we've retreived them so we want to
    % make sure we''re keeping only new spikes:
    if ~isempty(p.trData.spikeTimes) && ~isempty(p.trData.eventValues)
        newSpikes = p.trData.spikeTimes(...
            p.trData.spikeTimes > p.trData.eventTimes(1) & ...
            p.trData.spikeTimes < p.trData.eventTimes(end));


        % if p.rig.guiData.spikesAndEvents is empty, this is the first
        % successful trial and we're going to populate spikesAndEvents with
        % several cell arrays for the first time. Otherwise we're going to
        % append the new data to those existing cell arrays:
        if isempty(p.rig.guiData.spikesAndEvents)
            tempSAE = struct;
            tempSAE.spikeTimes = {newSpikes};
            tempSAE.eventTimes = {p.trData.eventTimes};
            tempSAE.eventValues = {p.trData.eventValues};
        else
            tempSAE = p.rig.guiData.spikesAndEvents;
            tempSAE.spikeTimes(end+1) = {newSpikes};
            tempSAE.eventTimes(end+1) = {p.trData.eventTimes};
            tempSAE.eventValues(end+1) = {p.trData.eventValues};
        end

        % assign "tempSAE" to p.rig.guiData.spikesAndEvents:
        p.rig.guiData.spikesAndEvents = tempSAE;
    end

end
   
end

%% 

function p = calcSacParams(p)

try
% If passEye is true, generate fake saccade parameter data to test mapping
% gui integration. Otherwise 
if p.trVars.passEye
    P = [0.0085 -0.4509 6.6532 9.9220 256.3290];
    myFun = @(x)P(1)*x.^4 + P(2)*x.^3 + P(3)*x.^2 + P(4)*x + P(5) + ...
        randn(size(x)).*(x*4 + 25);
    
    p.trData.postSacXY  = [p.trVars.targDegX, p.trVars.targDegY] + ...
        randn(1,2)/20;
    p.trData.peakVel   = myFun(sum(p.trData.postSacXY.^2)^0.5);
    p.trData.preSacXY  = [0, 0];
    p.trData.SRT       = 0.25 + randn/10;
    
    p.trData.trialEndState = p.state.sacComplete;
    
elseif p.trData.trialEndState == p.state.sacComplete
    
    % get ADC buffered gaze X, Y & T.
    T   = p.trData.eyeT - p.trData.timing.trialStartPTB;
    X  = -4 * p.trData.eyeX;
    Y  = -4 * p.trData.eyeY;
    
    % compute total velocity using "smoothdiff"
    Vsd = ((1000*smoothdiff(X)).^2 + (1000*smoothdiff(Y)).^2).^0.5;
    
    % separately index all the samples before and after saccade onset where
    % eye velocity is below (offline) velocity threshold).
    preSacFix   = Vsd < p.trVars.eyeVelThreshOffline & ...
        T < p.trData.timing.saccadeOnset;
    postSacFix  = Vsd < p.trVarsInit.eyeVelThreshOffline & ...
        T > p.trData.timing.saccadeOnset;
    
    % compute time of last sample before saccade and first sample after
    % saccade
    saccadeOnsetTime    = max(T(preSacFix));
    saccadeOffsetTime   = min(T(postSacFix));
    
    % if everything has done to plan, we have good estimates of when the
    % saccade started and ended from the online eye velocity.
    if ~isempty(saccadeOnsetTime) && ~isempty(saccadeOffsetTime)
        
        % look for maximum velocity after saccade onset and before saccade
        % offset.
        g = T > saccadeOnsetTime & T <saccadeOffsetTime;
        p.trData.peakVel = max(Vsd(g));
        
        % calculate mean gaze position over the 5ms before saccade and
        % after saccade. First logically index those time windows
        preSacTime  = T < saccadeOnsetTime & ...
            T >= (saccadeOnsetTime - 0.005);
        postSacTime = T > saccadeOffsetTime & ...
            T <= (saccadeOffsetTime + 0.005);
        
        % compute mean gaze positions.
        p.trData.preSacXY    = [mean(X(preSacTime)), mean(Y(preSacTime))];
        p.trData.postSacXY   = [mean(X(postSacTime)), mean(Y(postSacTime))];
        
        % compute saccade reaction time
        p.trData.SRT         = saccadeOnsetTime - p.trData.timing.fixOff;
        
    else
        p.trData.peakVel    = NaN;
        p.trData.preSacXY   = NaN(1,2);
        p.trData.postSacXY  = NaN(1,2);
        p.trData.SRT        = NaN;
    end
else
    p.trData.peakVel    = NaN;
        p.trData.preSacXY   = NaN(1,2);
        p.trData.postSacXY  = NaN(1,2);
        p.trData.SRT        = NaN;
end
catch me
    keyboard
end

end

%%

function y = smoothdiff(x)

% define filter & filter coefficients
b           = zeros(29,1);
b(1)        =  -4.3353241e-04 * 2*pi;
b(2)        =  -4.3492899e-04 * 2*pi;
b(3)        =  -4.8506188e-04 * 2*pi;
b(4)        =  -3.6747546e-04 * 2*pi;
b(5)        =  -2.0984645e-05 * 2*pi;
b(6)        =   5.7162272e-04 * 2*pi;
b(7)        =   1.3669190e-03 * 2*pi;
b(8)        =   2.2557429e-03 * 2*pi;
b(9)        =   3.0795928e-03 * 2*pi;
b(10)       =   3.6592020e-03 * 2*pi;
b(11)       =   3.8369002e-03 * 2*pi;
b(12)       =   3.5162346e-03 * 2*pi;
b(13)       =   2.6923104e-03 * 2*pi;
b(14)       =   1.4608032e-03 * 2*pi;
b(15)       =   0.0;
b(16:29)    = -b(14:-1:1);

% make x a column vector
x = x(:);

% apply filter to "x"
y = filter(b, 1, x);

% get rid of leading and trailing edges of y (these will be noisy due to
% filter length).
y = [y(15:length(x), :); zeros(14, 1)]';

end