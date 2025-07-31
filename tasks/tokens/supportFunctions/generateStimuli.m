function p = generateStimuli(p)
%
% p = generateStimuli(p)
%
% This function is responsible for creating the visual stimuli for the
% 'tokens' task. It reads an image file and creates a PTB texture.

    % It's good practice to close any texture from the previous trial
    if isfield(p.stim, 'cue') && isfield(p.stim.cue, 'texture') ...
            && Screen(p.stim.cue.texture, 'WindowKind') == 1
        Screen('Close', p.stim.cue.texture);
    end
    p.stim.cue.texture = nan; % Default to NaN (Not a Number)

    % --- Create the Cue Texture ---
    
    % Only proceed if the current trial is not a 'blank' trial
    if ~strcmp(p.trVars.cueFile, 'blank.jpg')
    
        % Define the path to your stimuli folder.
        % NOTE: You may need to adjust this path to match your setup.
        stimulus_folder = fullfile(p.init.pldaps_path, 'stimuli', ...
            'tokens');
        image_path = fullfile(stimulus_folder, p.trVars.cueFile);

        % Check that the image file actually exists before trying to load
        if exist(image_path, 'file')
            % Load the image data from the file
            img_data = imread(image_path);
            
            % Create the Psychtoolbox texture from the image data
            p.stim.cue.texture = Screen('MakeTexture', p.draw.window, ...
                img_data);
        else
            % If the file doesn't exist, issue a warning to the command 
            % window
            warning('generateStimuli: Image file not found: %s', ...
                image_path);
        end
    end

end