function p = initClut(p)
% initClut
%
% 1. Initializes the DKL color palette for the experiment.
% 2. Builds a full, default CLUT for both subject and experimenter so that
%    pds.initDataPixx can open the PTB window without errors.

%% 1. Define empirically measured isoluminant DKL color palette
satRad      = 0.4;
dklLum      = [-0.4888, -0.4871, -0.4958, -0.4944, -0.4975, -0.5012, ...
               -0.4974, -0.4922, -0.4896];
dklThetas   = 0:45:360;

dkl_palette_rgb = zeros(length(dklThetas), 3);
for i = 1:length(dklThetas)
    dkl_color = [dklLum(i); satRad * cosd(dklThetas(i)); satRad * ...
        sind(dklThetas(i))];
    dkl_palette_rgb(i, :) = dkl2rgb(dkl_color);
end

p.draw.colors.dklPalette = dkl_palette_rgb;
mean_lum = mean(dklLum);
p.draw.colors.isolumGray = dkl2rgb([mean_lum; 0; 0]);

%% 2. Build the initial, default CLUTs
% These full 256x3 matrices are required to open the PTB window.
% We will use the isoluminant gray as the default background.
default_bg = p.draw.colors.isolumGray;

% Pre-allocate full 256x3 matrices
expCLUT = zeros(256, 3);
subCLUT = zeros(256, 3);

% Define some named colors for the static entries
mutGreen    = [0.5 0.9 0.4];
redISH      = [225 0 76]/255;
orangeISH   = [255 146 0]/255;
blueISH     = [11 97 164]/255;
oldGreen    = [0.45, 0.63, 0.45];

% --- Fill static entries (0-16) based on clutIdx from settings ---
% Note: MATLAB uses 1-based indexing, so we add 1 to each clutIdx
idx = p.draw.clutIdx;

% Experimenter CLUT (visible colors)
expCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
expCLUT(idx.expGrey25_subBg + 1, :)         = [0.25 0.25 0.25];
expCLUT(idx.expBg_subBg + 1, :)             = default_bg;
expCLUT(idx.expGrey70_subBg + 1, :)         = [0.7 0.7 0.7];
expCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
expCLUT(idx.expRed_subBg + 1, :)            = redISH;
expCLUT(idx.expOrange_subBg + 1, :)         = orangeISH;
expCLUT(idx.expBlue_subBg + 1, :)           = blueISH;
expCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
expCLUT(idx.expMutGreen_subBg + 1, :)       = mutGreen;
expCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
% ... (other static colors would be defined here) ...

% Subject CLUT (many elements match the default background)
subCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
subCLUT(idx.expGrey25_subBg + 1, :)         = default_bg;
subCLUT(idx.expBg_subBg + 1, :)             = default_bg;
subCLUT(idx.expGrey70_subBg + 1, :)         = default_bg;
subCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
subCLUT(idx.expRed_subBg + 1, :)            = default_bg;
subCLUT(idx.expOrange_subBg + 1, :)         = default_bg;
subCLUT(idx.expBlue_subBg + 1, :)           = default_bg;
subCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
subCLUT(idx.expMutGreen_subBg + 1, :)       = default_bg;
subCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
% ... (other static colors would be defined here) ...

% Fill the rest of the CLUT (indices 17-255) with the default background
expCLUT(18:256, :) = repmat(default_bg, 256-17, 1);
subCLUT(18:256, :) = repmat(default_bg, 256-17, 1);

% --- Store the final CLUTs in the p struct ---
p.draw.clut.expCLUT = expCLUT;
p.draw.clut.subCLUT = subCLUT;
end