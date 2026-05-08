function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% column descriptions
p.init.trialArrayColumnNames = {'trialType', 'numStim', 'stimDur', 'interStimInterval', ...
    'stimPeriod', 'currentThresholdMultiplier', 'interElectrodeSpacing', ...
    'no of trials', 'trialCode'};

%**** Notes about how array columns are used:
% For visual trials, numStim is number of visual stimuli, stimDur is
% duration of stimuli in ms, and interStimInterval is duration in ms between
% presentation of first and second visual stimulus. Remaining parameters
% are not used for visual trials so should always be set to 0
%
% For microstim trials, numStim is number of microstim commands, stimDur is
% number of pulses sent per command, interStimInterval is number of 33.333
% us clock cycles between end of stim train 1 and beginning of stim train
% 2, stimPeriod is the number of 33.333 us clock cycles between individual
% pulses of a train, currentThresholdMultiplier is multiplied by the C50 of
% each electrode to determine the current amplitude used, and
% interElectrodeSpacing is the distance in um between stimulation sites



% table definition
switch p.init.exptType
    case 'spatial'
        table = spatial_table;
    case 'temporal'
        table = temporal_table;
end          

% Make "n" copies of each row in the table, where n is in the "no of trials" column.
% Add a column to indicate which rows of the array have been completed in a
% given block. First, initialize the "trials" array to hold the
% repetitions. Next initialize a variable to indicate which row we're
% currently at.
nCols = length(p.init.trialArrayColumnNames);
p.init.trialsArray = zeros(sum(table(:, nCols - 1)), nCols);
currentRow = 1;

% which column tells us how many repetitions of a given trial type will be
% included?
repCol = find(strcmp(p.init.trialArrayColumnNames, 'no of trials'));

% loop over each row of the table.
for i = 1:size(table, 1)
    % how many repetitions of the current row do we need?
    nReps = table(i, repCol);
    
    try
    % place the repeated row into the "trials" array
    p.init.trialsArray(currentRow:(currentRow + nReps - 1), :) = ...
        repmat(table(i, :), nReps, 1);
    catch me
        keyboard
    end
    
    % iterate the "currentRow" variable.
    currentRow = currentRow + nReps;
end

% store length of block
p.init.blockLength = size(p.init.trialsArray, 1);

end


function table = spatial_table
table = [
    % visual, 1 stimulus, 24111 trial code
    1 1 120 0 0 0 0 0 24111; ... % 120 ms stim duration
    1 1 160 0 0 0 0 0 24111; ... 
    1 1 200 0 0 0 0 0 24111; ... 

    % visual, 2 stimuli, 24112 trial code
    1 2 120 0 0 0 0 0 24112; ... % 120 ms stim duration
    1 2 160 0 0 0 0 0 24112; ... 
    1 2 200 0 0 0 0 0 24112; ... 

    % microstim, 1 cmd, 24121 trial code
    2 1 50 0 100 1.5 0 0 24121; ... % 50 pulses, 100 period, 1.5x threshold
    2 1 50 0 100 2.0 0 0 24121; ... 
    2 1 50 0 100 2.5 0 0 24121; ... 

    % microstim, 2 cmd, 24122 trial code
    2 2 50 0 100 1.5 75 0 24122; ... % 50 pulses, 100 period, 1.5x threshold, 75 um spacing
    2 2 50 0 100 2.0 75 0 24122; ... 
    2 2 50 0 100 2.5 75 0 24122; ... 
    2 2 50 0 100 1.5 150 0 24122; ... 
    2 2 50 0 100 2.0 150 0 24122; ... 
    2 2 50 0 100 2.5 150 0 24122; ... 
    2 2 50 0 100 1.5 225 0 24122; ... 
    2 2 50 0 100 2.0 225 0 24122; ... 
    2 2 50 0 100 2.5 225 0 24122; ... 

    ];
end

function table = temporal_table
table = [
    % visual, 1 stimulus, 24211 trial code
    1 1 240 0 0 0 0 0 24211; ... % 240 ms stim duration
    1 1 320 0 0 0 0 0 24211; ... 
    1 1 400 0 0 0 0 0 24211; ... 
    1 1 480 0 0 0 0 0 24211; ... 
    1 1 560 0 0 0 0 0 24211; ... 
    1 1 640 0 0 0 0 0 24211; ... 
    1 1 720 0 0 0 0 0 24211; ... 
    1 1 800 0 0 0 0 0 24211; ... 
    
    % visual, 2 stimuli, 24212 trial code
    1 2 120 30 0 0 0 0 24212; ... % 120 ms stim duration, 30 ms interstim interval
    1 2 120 90 0 0 0 0 24212; ... 
    1 2 120 150 0 0 0 0 24212; ... 
    1 2 120 210 0 0 0 0 24212; ... 
    1 2 120 270 0 0 0 0 24212; ... 
    1 2 120 330 0 0 0 0 24212; ...  
    1 2 120 400 0 0 0 0 24212; ...   
    1 2 160 30 0 0 0 0 24212; ...   
    1 2 160 90 0 0 0 0 24212; ...   
    1 2 160 150 0 0 0 0 24212; ...   
    1 2 160 210 0 0 0 0 24212; ...   
    1 2 160 270 0 0 0 0 24212; ...   
    1 2 160 330 0 0 0 0 24212; ...  
    1 2 160 400 0 0 0 0 24212; ...   
    1 2 200 30 0 0 0 0 24212; ...   
    1 2 200 90 0 0 0 0 24212; ...   
    1 2 200 150 0 0 0 0 24212; ... 
    1 2 200 210 0 0 0 0 24212; ...  
    1 2 200 270 0 0 0 0 24212; ...  
    1 2 200 330 0 0 0 0 24212; ...  
    1 2 200 400 0 0 0 0 24212; ...  

    % microstim, 1 cmd, 24221 trial code
    2 1 0 0 0 0 0 0 24221; ... %

    % microstim, 2 cmd, 24222 trial code
    2 2 0 0 0 0 0 0 24222; ... %

    ];
end





