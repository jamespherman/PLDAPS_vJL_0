function p = initImageTextures(p)
% initImageTextures
%
% CORRECTED VERSION: Uses the correct variable names from the settings file
% to find the start of the grayscale ramp in the CLUT.

fprintf('--- Loading and processing image stimuli ---\n');

%% 1. Define Paths and Load Stimulus File
stimulus_folder = fullfile(p.init.pldapsFolder, 'stimuli', 'gSac_4factors');
stimulus_file   = fullfile(stimulus_folder, 'images.mat');
if ~exist(stimulus_file, 'file'), error('FATAL: Stimulus file not found at %s', stimulus_file); end
fprintf('  Loading stimuli from: %s\n', stimulus_file);
stim_data = load(stimulus_file);
image_struct = stim_data.image;

%% 2. Get CLUT Mapping Info from the p struct
CLUT_BACKGROUND_INDEX = p.draw.clutIdx.expGrey_subBg;
CLUT_STIM_START_INDEX = p.draw.clutIdx.grayscale_ramp_start;
n_stim_levels         = p.draw.clutIdx.grayscale_ramp_end - p.draw.clutIdx.grayscale_ramp_start + 1;

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
    
    % CRITICAL: Convert image to double BEFORE doing math
    original_image = double(image_struct(i).singleobject_pixelmatrix);
    shape_mask     = logical(image_struct(i).singleobject_originalmask);
    
    % A pixel is part of the stimulus ONLY if it's inside the shape mask AND not black.
    stimulus_pixel_mask = shape_mask & (original_image > 0);
    background_pixel_mask = ~stimulus_pixel_mask;
    
    % Create the final single-layer index matrix
    [height, width] = size(original_image);
    final_indices = zeros(height, width);
    
    % Set the background pixels to the background CLUT index
    final_indices(background_pixel_mask) = CLUT_BACKGROUND_INDEX;
    
    % Get only the non-black stimulus pixels
    stim_pixels = original_image(stimulus_pixel_mask);
    
    % Remap the intensity of these pixels to the stimulus CLUT range
    remapped_stim_indices = round((stim_pixels / 255) * (n_stim_levels - 1)) + CLUT_STIM_START_INDEX;
    
    % Place the remapped stimulus pixels into the final matrix
    final_indices(stimulus_pixel_mask) = remapped_stim_indices;
    
    % Create the simple, single-layer indexed texture
    texture_handle = Screen('MakeTexture', p.draw.window, final_indices);
    
    % Store Texture Handle in the Correct List
    if isMonkeyFace
        p.stim.faceTextures(end+1) = texture_handle;
    elseif isNonFaceObject
        p.stim.nonFaceTextures(end+1) = texture_handle;
    end
end

fprintf('  ... done. Loaded %d face textures and %d non-face textures.\n\n', ...
    length(p.stim.faceTextures), length(p.stim.nonFaceTextures));

end