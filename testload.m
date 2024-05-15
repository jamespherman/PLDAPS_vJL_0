% Convert the image to a list of directories
directories = {
    '20240215_t1008_joystick_release_for_stim_change_and_dim'
    '20240215_t1011_joystick_release_for_stim_change_and_dim'
    '20240215_t1015_joystick_release_for_stim_change_and_dim'
    '20240215_t1017_joystick_release_for_stim_change_and_dim'
    '20240215_t1053_joystick_release_for_stim_change_and_dim'
    '20240216_t0959_joystick_release_for_stim_change_and_dim'
    '20240220_t0937_joystick_release_for_stim_change_and_dim'
    '20240222_t0952_joystick_release_for_stim_change_and_dim'
    '20240226_t0944_joystick_release_for_stim_change_and_dim'
    '20240227_t1009_joystick_release_for_stim_change_and_dim'
    '20240227_t1101_joystick_release_for_stim_change_and_dim'
    '20240227_t1242_joystick_release_for_stim_change_and_dim'
    '20240227_t1245_joystick_release_for_stim_change_and_dim'
    '20240227_t1252_joystick_release_for_stim_change_and_dim'
    '20240227_t1253_joystick_release_for_stim_change_and_dim'
    '20240227_t1305_joystick_release_for_stim_change_and_dim'
    '20240227_t1306_joystick_release_for_stim_change_and_dim'
    '20240227_t1314_joystick_release_for_stim_change_and_dim'
    '20240227_t1322_joystick_release_for_stim_change_and_dim'
    '20240227_t1323_joystick_release_for_stim_change_and_dim'
    '20240227_t1328_joystick_release_for_stim_change_and_dim'
    '20240227_t1357_joystick_release_for_stim_change_and_dim'
    '20240227_t1438_joystick_release_for_stim_change_and_dim'
    '20240227_t1441_joystick_release_for_stim_change_and_dim'
    '20240227_t1443_joystick_release_for_stim_change_and_dim'
    '20240227_t1447_joystick_release_for_stim_change_and_dim'
    '20240227_t1449_joystick_release_for_stim_change_and_dim'
    '20240228_t1007_joystick_release_for_stim_change_and_dim'
    '20240229_t1023_joystick_release_for_stim_change_and_dim'
    '20240229_t1028_joystick_release_for_stim_change_and_dim'
    '20240305_t0958_joystick_release_for_stim_change_and_dim'
    '20240306_t1019_joystick_release_for_stim_change_and_dim'
    '20240307_t1004_joystick_release_for_stim_change_and_dim'
    '20240307_t1037_joystick_release_for_stim_change_and_dim'
    '20240307_t1053_joystick_release_for_stim_change_and_dim'
    '20240308_t1007_joystick_release_for_stim_change_and_dim'
    '20240311_t1041_joystick_release_for_stim_change_and_dim'
    '20240312_t1051_joystick_release_for_stim_change_and_dim'
    '20240313_t1000_joystick_release_for_stim_change_and_dim'
    '20240318_t0939_joystick_release_for_stim_change_and_dim'
    '20240319_t1012_joystick_release_for_stim_change_and_dim'
    '20240320_t1027_joystick_release_for_stim_change_and_dim'
    '20240320_t1137_joystick_release_for_stim_change_and_dim'
    '20240320_t1138_joystick_release_for_stim_change_and_dim'
    '20240321_t1050_joystick_release_for_stim_change_and_dim'
    '20240325_t1010_joystick_release_for_stim_change_and_dim'
    '20240409_t1025_joystick_release_for_stim_change_and_dim'
    '20240409_t1030_joystick_release_for_stim_change_and_dim'
};

% Add the prefix 'output/' to each directory
directories = cellfun(@(x) fullfile('output', x), directories, 'UniformOutput', false);

% Initialize a scalar struct to store the extracted data
extractedData = struct('directory', {{}}, 'cuedHitCount', [], 'cuedTotalCount', [], ...
    'uncuedHitCount', [], 'uncuedTotalCount', []);

% Iterate over each directory
for i = 1:length(directories)
    % Get the list of .mat files in the current directory
    matFiles = dir(fullfile(directories{i}, '*.mat'));
    
    % Find the highest-numbered .mat file
    fileNumbers = cellfun(@(x) str2double(x(6:end-4)), {matFiles.name});
    [maxNumber, maxIndex] = max(fileNumbers);
    
    % Search for the highest-numbered trial file containing the "status" struct
    found = false;
    while ~found & (maxIndex > 0)
        % Load the trial file
        trialFile = fullfile(directories{i}, matFiles(maxIndex).name);
        vars = who('-file', trialFile);
        
        % Check if the "status" struct exists in the trial file
        if ismember('status', vars)
            load(trialFile, 'status');
            found = true;
        else
            maxIndex = maxIndex - 1;
        end
    end
    
    % Extract the desired data from the status struct and assign it to the struct arrays
    extractedData(i).directory = directories{i};
    if found
        extractedData(i).cuedHitCount = status.cuedHitCount.global;
        extractedData(i).cuedTotalCount = status.cuedTotalCount.global;
        extractedData(i).uncuedHitCount = status.uncuedHitCount.global;
        extractedData(i).uncuedTotalCount = status.uncuedTotalCount.global;
    else
        warning('No trial file containing the "status" struct found in directory: %s', directories{i});
    end
end

% Display the extracted data struct
disp(extractedData);