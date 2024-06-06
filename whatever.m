p.state.hit             = 21;
p.state.cr              = 22;
p.state.miss            = 23;
p.state.foilFa          = 24;
p.state.fa              = 25;


% Specify the directory containing the trial files
directory = 'output/20240603_t1150_joystick_release_for_stim_change_and_dim';

% Get the list of trial files in the directory
trialFiles = dir(fullfile(directory, 'trial*.mat'));

% Initialize arrays to store the extracted data
noChg = [];
reactionTimes = [];
trialEndStates = [];
stimOn = [];
stimChg = [];

% Iterate over each trial file
for i = 1:length(trialFiles)
    % Load the trial file
    trialFile = fullfile(directory, trialFiles(i).name);
    load(trialFile, 'trVars', 'status', 'trData');
   
    if isfield(trVars, 'isNoChangeTrial') & isfield(status, 'trialEndStates') & isfield(status, 'reactionTimes')
        if length(status.trialEndStates) > 0
            noChg(end+1) = trVars.isNoChangeTrial;
            trialEndStates(end+1) = status.trialEndStates(end);
            reactionTimes(end+1) = status.reactionTimes(end);
            stimOn(end+1) = trData.timing.stimOn;
            stimChg(end+1) = trData.timing.stimChg;
        end
    else
        warning('Fields orientInit and/or orientDelta not found in file: %s', trialFiles(i).name);
    end
end
Fa = trialEndStates == p.state.fa;
