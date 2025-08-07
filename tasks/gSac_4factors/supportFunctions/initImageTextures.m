function p = initImageTextures(p)
% initImageTextures
%
% CORRECTED VERSION: This version creates a more precise mask to ensure that
% black pixels (intensity=0) within the stimulus shape are also mapped to the
% background CLUT index, making them truly transparent.

fprintf('--- Loading and processing image stimuli ---\n');

%% 1. Define Paths and Load Stimulus File
stimulus_folder = fullfile(p.init.pldapsFolder, 'stimuli', 'gSac_4factors');
stimulus_file   = fullfile(stimulus_folder, 'images.mat');
if ~exist(stimulus_file, 'file'), error('FATAL: Stimulus file not found at %s', stimulus_file); end
fprintf('  Loading stimuli from: %s\n', stimulus_file);
stim_data = load(stimulus_file);
image_struct = stim_data.image;

%% 2. Get CLUT Mapping Info
CLUT_BACKGROUND_INDEX = p.draw.color.background;
CLUT_STIM_START_INDEX = p.draw.clutIdx.stimStart;
n_stim_levels         = p.stim.nStimLevels;

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
    shape_mask     = logical(image_struct(i).singleobject_originalmask);
    
    % --- Create the final single-layer index matrix ---
    [height, width] = size(original_image);
    final_indices = zeros(height, width);
    
    % --- NEW LOGIC: Create a more precise mask ---
    % A pixel is part of the stimulus ONLY if it's inside the shape mask AND not black.
    stimulus_pixel_mask = shape_mask & (original_image > 0);
    
    % All other pixels (outside the shape OR black inside the shape) are background.
    background_pixel_mask = ~stimulus_pixel_mask;
    
    % Set the background pixels to the background CLUT index
    final_indices(background_pixel_mask) = CLUT_BACKGROUND_INDEX;
    
    % Get only the non-black stimulus pixels
    stim_pixels = double(original_image(stimulus_pixel_mask));
    
    % Remap the intensity of these pixels to the stimulus CLUT range
    remapped_stim_indices = round((stim_pixels / 255) * (n_stim_levels - 1)) + CLUT_STIM_START_INDEX;
    
    % Place the remapped stimulus pixels into the final matrix
    final_indices(stimulus_pixel_mask) = remapped_stim_indices;
    
    % --- Create the simple, single-layer indexed texture ---
    texture_handle = Screen('MakeTexture', p.draw.window, final_indices);
    
    % --- Store Texture Handle ---
    if isMonkeyFace
        p.stim.faceTextures(end+1) = texture_handle;
    elseif isNonFaceObject
        p.stim.nonFaceTextures(end+1) = texture_handle;
    end
end

fprintf('  ... done. Loaded %d face textures and %d non-face textures.\n\n', ...
    length(p.stim.faceTextures), length(p.stim.nonFaceTextures));

end