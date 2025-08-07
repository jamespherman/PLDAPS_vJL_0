function p = initImageTextures(p)
% initImageTextures
%
% DEFINITIVE VERSION: Loads images and creates simple, single-layer indexed
% textures. It uses the mask to set background pixels to a specific CLUT
% index, avoiding the need for an alpha channel.

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
CLUT_BACKGROUND_INDEX = 17;
CLUT_STIM_START_INDEX = 18;
CLUT_STIM_END_INDEX   = 255;
n_stim_levels         = CLUT_STIM_END_INDEX - CLUT_STIM_START_INDEX + 1;

%% 3. Pre-process Images and Create Textures
n_images = length(image_struct);
p.stim.faceTextures    = [];
p.stim.nonFaceTextures = [];

fprintf('  Processing %d images and creating single-layer indexed textures...\n', n_images);

for i = 1:n_images
    % Categorize Image Based on Row Index
    isMonkeyFace = (i >= 1 && i <= 15);
    isNonFaceObject = (i >= 31 && i <= 150);
    
    if ~isMonkeyFace && ~isNonFaceObject, continue; end
    
    % Get the original image matrix (0-255) and mask
    original_image = image_struct(i).singleobject_pixelmatrix;
    original_mask  = logical(image_struct(i).singleobject_originalmask);
    
    % --- Create the final single-layer index matrix ---
    [height, width] = size(original_image);
    final_indices = zeros(height, width);
    
    % Set the background pixels to the background CLUT index
    final_indices(~original_mask) = CLUT_BACKGROUND_INDEX;
    
    % Get the stimulus-only pixels from the original image
    stim_pixels = double(original_image(original_mask));
    
    % Remap the intensity of the stimulus pixels to the stimulus CLUT range
    remapped_stim_indices = round((stim_pixels / 255) * (n_stim_levels - 1)) + CLUT_STIM_START_INDEX;
    
    % Place the remapped stimulus pixels into the final matrix
    final_indices(original_mask) = remapped_stim_indices;
    
    % --- Create the simple, single-layer indexed texture ---
    texture_handle = Screen('MakeTexture', p.draw.window, final_indices);
    
    % --- Store Texture Handle in the Correct List ---
    if isMonkeyFace
        p.stim.faceTextures(end+1) = texture_handle;
    elseif isNonFaceObject
        p.stim.nonFaceTextures(end+1) = texture_handle;
    end
end

fprintf('  ... done. Loaded %d face textures and %d non-face textures.\n\n', ...
    length(p.stim.faceTextures), length(p.stim.nonFaceTextures));

end