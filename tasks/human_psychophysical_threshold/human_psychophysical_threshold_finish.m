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

% save strobed codes:
% p.trData.strobed = p.init.strb.strobedList;

% flush strobe "veto" & "strobed" list
% p.init.strb.flushVetoList;
% p.init.strb.flushStrobedList;

% (3) pause ephys
% pds.stopOmniPlex;

% if a "time-out" is desired, make it happen here. Note: the way this works
% at present is: we only advance from here if the desired interval of time
% has elapsed since the end of the previous trial. This means that if the
% monkey has held the joystick down for a "long time" since the end of the
% last trial, the "time-out" window has passed and there won't be an
% ADDITIONAL time out.
% postTrialTimeOut(p);

% % % p.trData.spikeAndStrobeTimes(p.trData.spikeAndStrobeTimes(:,1)==4, 3)
% % % 
% % % keyboard

% store missed frames count
p.trData.missedFrameCount = nnz(diff(p.trData.timing.flipTime) > ...
    p.rig.frameDuration * 1.5);
p.status.missedFrames = p.status.missedFrames + p.trData.missedFrameCount;

% decide if the response was "correct" (if the trial completed correctly)
if ~p.trData.trialRepeatFlag
    cVect = [9 7 1 3];
    p.trData.responseCorrect = cVect(p.trVars.stimChgIdx) == ...
        str2double(p.trData.responseValue);
end

% (5) auto save backup
pds.saveP(p);

% (6) if we're using QUEST, compute the posterior and update the parameter
% estimates here
p           = updateQuest(p);
if isfield(p.init.questObj, 'threshEst')
    p.status.questThreshEst = p.init.questObj.threshEst(end);
end

% (8) update trials list
p           = updateTrialsList(p);

% (7) update status variables
p           = updateStatusVariables(p);

% (8) if we're using online plots, update them now:
if isfield(p.trVars, 'wantOnlinePlots') && p.trVars.wantOnlinePlots
    p       = updateOnlinePlots(p);
end

% if the trialcount for the quest object is larger than
% p.trVars.numThreshCheckTrials + 1, check whether the change in
% threshold estimate has been below a criterion value for the last
% p.trvars.numThreshCheckTrials trials. If it has, stop running
% because we consider our threshold estimate to be stable.
threshChangeCrit = (p.trVars.maxSignalStrength - ...
    p.trVars.minSignalStrength) / 1000;
if p.init.questObj.trialCount > p.trVars.numThreshCheckTrials
    tempThreshChange = abs(diff(p.init.questObj.threshEst));
    if all(tempThreshChange(end-p.trVars.numThreshCheckTrials+1:end) < ...
            threshChangeCrit)

        % Put tracker in idle/offline mode before closing file. Eyelink('SetOfflineMode') is recommended.
        % However if Eyelink('Command', 'set_idle_mode') is used, allow 50ms before closing the file as shown in the commented code:
        % Eyelink('Command', 'set_idle_mode');% Put tracker in idle/offline mode
        % WaitSecs(0.05); % Allow some time for transition
        Eyelink('SetOfflineMode'); % Put tracker in idle/offline mode
        Eyelink('Command', 'clear_screen 0'); % Clear Host PC backdrop graphics at the end of the experiment
        WaitSecs(0.5); % Allow some time before closing and transferring file
        Eyelink('CloseFile'); % Close EDF file on Host PC
        % Transfer a copy of the EDF file to Display PC
        p = transferFile(p); % See transferFile function below

        % stop the gui:
        p.runFlag = false;
    end
end
end

% Function for transferring copy of EDF file to the experiment folder on Display PC.
% Allows for optional destination path which is different from experiment folder
function p = transferFile(p)
try
    if p.init.elDummyMode == 0 % If connected to EyeLink

        % Show 'Receiving data file...' text until file transfer is complete
        Screen('FillRect', p.draw.window, p.init.el.backgroundcolour); % Prepare background on backbuffer
        Screen('DrawText', p.draw.window, 'Receiving data file...', 5, p.draw.screenRect(end)-35, 0); % Prepare text
        Screen('Flip', p.draw.window); % Present text
        fprintf('Receiving data file ''%s.edf''\n', p.init.edfFile); % Print some text in Matlab's Command Window

        % Transfer EDF file to Host PC
        % [status =] Eyelink('ReceiveFile',['src'], ['dest'], ['dest_is_path'])
        status = Eyelink('ReceiveFile');
        % Optionally uncomment below to change edf file name when a copy is transferred to the Display PC
        % % If <src> is omitted, tracker will send last opened data file.
        % % If <dest> is omitted, creates local file with source file name.
        % % Else, creates file using <dest> as name.  If <dest_is_path> is supplied and non-zero
        % % uses source file name but adds <dest> as directory path.
        % newName = ['Test_',char(datetime('now','TimeZone','local','Format','y_M_d_HH_mm')),'.edf'];
        % status = Eyelink('ReceiveFile', [], newName, 0);

        % Check if EDF file has been transferred successfully and print file size in Matlab's Command Window
        if status > 0
            fprintf('EDF file size: %.1f KB\n', status/1024); % Divide file size by 1024 to convert bytes to KB
        end
        % Print transferred EDF file path in Matlab's Command Window
        fprintf('Data file ''%s.edf'' can be found in ''%s''\n', p.init.edfFile, pwd);
    else
        fprintf('No EDF file saved in Dummy mode\n');
    end
catch % Catch a file-transfer error and print some text in Matlab's Command Window
    fprintf('Problem receiving data file ''%s''\n', p.init.edfFile);
    psychrethrow(psychlasterror);
end
end