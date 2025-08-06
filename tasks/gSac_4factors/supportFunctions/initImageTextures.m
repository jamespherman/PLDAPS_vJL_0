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


%% 3. Pre-process Images and Create Textures
n_images = length(image_struct);
p.stim.faceTextures    = [];
p.stim.nonFaceTextures = [];

fprintf('  Processing %d images and creating indexed textures...\n', n_images);

for i = 1:n_images
    % --- Categorize Image Based on Row Index ---
    isMonkeyFace = (i >= 1 && i <= 15);
    isNonFaceObject = (i >= 31 && i <= 150);
    
    % Skip this image if it's not in one of our desired categories
    if ~isMonkeyFace && ~isNonFaceObject
        continue;
    end
    
    % Get the original image matrix (0-255) and mask
    original_image = image_struct(i).singleobject_pixelmatrix;
    original_mask  = image_struct(i).singleobject_originalmask;
    
    % --- Compress Intensity Range ---
    img_double = double(original_image);
    remapped_indices = round((img_double / 255) * (n_stim_levels - 1));
    final_indices = remapped_indices + CLUT_STIM_START_INDEX;
    
    % --- Combine with Alpha Mask ---
    alpha_mask = uint8(original_mask * 255);
    indexed_image_with_alpha = cat(3, final_indices, alpha_mask);
    
    % --- Create Indexed Texture ---
    texture_handle = Screen('MakeTexture', p.draw.window, indexed_image_with_alpha);
    
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