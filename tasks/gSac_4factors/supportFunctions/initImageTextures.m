function p = initImageTextures(p)
% initImageTextures
%
% CORRECTED VERSION: Selects specific stimuli based on their row index in
% the source .mat file. Loads stimuli, compresses intensity, and creates
% indexed textures for use in L48 mode.
%
% Called once during task initialization.

fprintf('--- Loading and processing image stimuli ---\n');

%% 1. Define Paths and Load Stimulus File
stimulus_folder = fullfile(p.init.pldapsFolder, 'stimuli', 'gSac_4factors');
stimulus_file   = fullfile(stimulus_folder, 'images.mat');

if ~exist(stimulus_file, 'file')
    error('FATAL: Stimulus file not found at %s', stimulus_file);
end

fprintf('  Loading stimuli from: %s\n', stimulus_file);
stim_data = load(stimulus_file);
image_struct = stim_data.image;

%% 2. Define CLUT Mapping
CLUT_STIM_START_INDEX = 18;
CLUT_STIM_END_INDEX   = 255;
n_stim_levels         = CLUT_STIM_END_INDEX - CLUT_STIM_START_INDEX + 1;


% --- In initImageTextures.m ---

%% 3. Pre-process Images and Create Textures (TRANSPARENCY VERSION)
n_images = length(image_struct);
p.stim.faceTextures    = [];
p.stim.nonFaceTextures = [];

fprintf('  Processing %d images and creating RGBA textures for transparency test...\n', n_images);

for i = 1:n_images
    isMonkeyFace = (i >= 1 && i <= 15);
    isNonFaceObject = (i >= 31 && i <= 150);
    
    if ~isMonkeyFace && ~isNonFaceObject, continue; end
    
    % Get the original grayscale image to use as the alpha channel
    % Note: The original mask is not needed for this method.
    alpha_channel = 255 - image_struct(i).singleobject_pixelmatrix;
    
    % --- NEW, CORRECTED CODE ---
    % Get the size of the image
    [height, width] = size(alpha_channel);

    % Pre-allocate a 4-channel (RGBA) matrix of the correct size
    rgba_matrix = zeros(height, width, 4, 'uint8');

    % Explicitly set the first 3 channels (R, G, B) to 255 (solid white)
    rgba_matrix(:,:,1:3) = 255;

    % Set the 4th channel (Alpha) to be the grayscale image
    rgba_matrix(:,:,4) = alpha_channel;

    
    % Create the RGBA texture
    texture_handle = Screen('MakeTexture', p.draw.window, rgba_matrix);
    
    % Store the texture handle
    if isMonkeyFace
        p.stim.faceTextures(end+1) = texture_handle;
    elseif isNonFaceObject
        p.stim.nonFaceTextures(end+1) = texture_handle;
    end
end

fprintf('  ... done. Loaded %d face textures and %d non-face textures.\n\n', ...
    length(p.stim.faceTextures), length(p.stim.nonFaceTextures));

end
