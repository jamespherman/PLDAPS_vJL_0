function p = human_psychophysical_threshold_finish(p)
%
%   p = human_psychophysical_threshold_finish(p)
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
% (1) Clear "Screen".
% (2) Strobe current trial's information (stimulus params, etc) to ephys
%     system.
% (3) Pause ephys.
% (4) Store data in PDS structure (eye position traces, spike times, etc.).
% (5) Auto save backup (if desired).
% (6) Update status variables.
% (7) Update trials list (shuffle back in trials to be repeated, take care
%     of transitions between blocks, etc.).
% (8) Update online plots.

% (1) fill screen with background color (if we're not playing a movie)
if ~isfield(p.draw, 'movie')
    Screen('FillRect', p.draw.window, ...
        fix(255*p.draw.clut.subColors(p.draw.color.background + 1, :)));
    Screen('Flip', p.draw.window);
end

% read buffered ADC and DIN data from DATAPixx
% p           = pds.readDatapixxBuffers(p);

% Was the previous trial aborted?
p.trData.trialRepeatFlag = (p.trData.trialEndState > 10) & ...
    (p.trData.trialEndState < 20);                                                       

%% strobes:
% strobe trial data:
% p           = pds.strobeTrialData(p);

% strobe and mark end of trial:
timeNow = GetSecs - p.trData.timing.trialStartPTB; % timeNow is relative to trial Start
p.trData.timing.trialEnd   = timeNow;

% if we're in the phase of the experiment where we're presenting a fixed
% signal strength, iterate our count of fixed signal strength trials.
if p.status.fixSignalStrength && ~p.trData.trialRepeatFlag
    p.status.numTrialsSinceFixSig = ...
        p.status.numTrialsSinceFixSig + 1;
end

% store missed frames count
p.trData.missedFrameCount = nnz(diff(p.trData.timing.flipTime) > ...
    p.rig.frameDuration * 1.5);
p.status.missedFrames = p.status.missedFrames + p.trData.missedFrameCount;

% decide if the response was "correct" (if the trial completed correctly)
if ~p.trData.trialRepeatFlag
    cVect = [9 7 1 3];
    p.trData.responseCorrect = cVect(p.trVars.stimChgIdx) == ...
        str2double(p.trData.responseValue);

    % play audio feedback based on response (correct / incorrect)
    if p.trData.responseCorrect
        sound(p.audio.rightTone, p.audio.audsplfq);
    else
        sound(p.audio.wrongTone, p.audio.audsplfq)
    end
end

% (5) auto save backup
pds.saveP(p);

% (6) if we're using QUEST, compute the posterior and update the parameter
% estimates here
p           = updateQuest(p);
if isfield(p.init.questObj, 'threshEst')
    p.status.questThreshEst = p.init.questObj.threshEst(end);
end

% if the trialcount for the quest object is larger than
% p.trVars.numThreshCheckTrials + 1, check whether the change in
% threshold estimate has been below a criterion value for the last
% p.trvars.numThreshCheckTrials trials. Also, we only check this if the
% variable "p.status.fixSignalStrength" is false - if that variable is
% true that means we've already decided to fix the signal strength so
% there's no need3 to do this check.
threshChangeCrit = (p.trVars.maxSignalStrength - ...
    p.trVars.minSignalStrength) / p.trVars.divFactorNoThreshChg;
if ~p.status.fixSignalStrength && ...
        (p.init.questObj.trialCount > p.trVars.numThreshCheckTrials)
    
    tempThreshChange = abs(diff(p.init.questObj.threshEst));

    if ~isempty(findall(0, 'Name', 'ThreshChangeFig'))
        close(findall(0, 'Name', 'ThreshChangeFig'));
    end
    figure('Name', 'ThreshChangeFig');
    plot(2:(length(tempThreshChange)+1), tempThreshChange);
    hold on
    plot(xlim, threshChangeCrit*[1 1]);
    xlabel('Trial Number')
    ylabel('Change in threshold estimate from previous trial')

    if all(tempThreshChange(end-p.trVars.numThreshCheckTrials+1:end) < ...
            threshChangeCrit)

        % set "fixSignalStrength" to true 79
        p.status.fixSignalStrength       = true;
    end

end

% (8) update trials list
p           = updateTrialsList(p);

% (7) update status variables
p           = updateStatusVariables(p);

% (8) if we're using online plots, update them now:
if isfield(p.trVars, 'wantOnlinePlots') && p.trVars.wantOnlinePlots
    p       = updateOnlinePlots(p);
end

% Instead of stopping after the threshold estimate has stabilized, we want
% to stop after 20 trials have been run FOLLOWING the stabilized threshold
% estimate. Below is the code that should be executed once we get to that
% point. I'm not sure what the criterion is for that.
if p.status.numTrialsSinceFixSig >= 20

    % Put tracker in idle/offline mode before closing file.
    Eyelink('SetOfflineMode');

    % Clear Host PC backdrop graphics at the end of the experiment
    Eyelink('Command', 'clear_screen 0');

    % Allow some time before closing and transferring file
    WaitSecs(0.5);

    % Close EDF file on Host PC
    Eyelink('CloseFile');

    % Transfer a copy of the EDF file to Display PC
    p = transferEdfFile(p);

    % stop the PLDAPS GUI:
    p.runFlag = false;

    % calculate correct response rate over final "fixed signal strength"
    % trials:
    [pctCorrect, pctCorrectCI] = binofit(...
        sum(p.init.questObj.response(p.init.questObj.trialCount - ...
        p.status.numTrialsSinceFixSig:p.init.questObj.trialCount)), ...
        p.status.numTrialsSinceFixSig);

    % make error bar "fill" X & Y
    fillX = [-0.5 0.5 0.5 -0.5 -0.5];
    fillY = [pctCorrectCI(1) pctCorrectCI(1) pctCorrectCI(2) ...
        pctCorrectCI(2) pctCorrectCI(1)];

    % at what trial did we fix signal strength?
    fixSigTrialNum = (p.init.questObj.trialCount - ...
        p.status.numTrialsSinceFixSig);

    % make a plot to see a summary of the data:
    figure('MenuBar', 'None', 'ToolBar', 'None', 'NextPlot', 'Add')
    ax(1) = axes('Position', [0.1 0.1 0.65 0.85], 'TickDir', 'Out', ...
        'NextPlot', 'Add');
    ax(2) = axes('Position', [0.8 0.1 0.1 0.85], 'TickDir', 'Out', ...
        'NextPlot', 'Add', 'YAxisLocation', 'Right', 'YTick', ...
        0:0.25:1, 'YLim', [0 1], 'XLim', [-1 1], 'XTickLabel', []);
    plot(ax(1), p.init.questObj.threshEst)
    plot(ax(1), fixSigTrialNum* [1 1], ax(1).YLim, 'k--');
    plot(ax(1), [fixSigTrialNum, p.init.questObj.trialCount], ...
        p.init.questObj.fixedSignalStrength * [1 1], ':', ...
        'Color', [1 0.1 0.1])
    xlabel(ax(1), 'Trial Number')
    ylabel(ax(1), 'Threshold Estimate (arb)')
    fill(ax(2), fillX, fillY, 0.8*[1 1 1], 'EdgeColor', 'none');
    plot(ax(2), [-0.55 0.55], pctCorrect*[1 1], 'k', 'LineWidth', 2)
    ylabel(ax(2), 'Percent Correct (fixed signal)')
end

end