function p = initClut(p)
% initClut
%
% VERSION
% 1. Correctly calls dkl2rgb to initialize the DKL color palette.
% 2. Correctly builds a full, default CLUT for the PTB window.

% initialize DKL conversion variables
p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

%% 1. Define empirically measured isoluminant DKL color palette
satRad      = 0.4;
p.rig.dklLum      = [-0.4888, -0.4871, -0.4958, -0.4944, -0.4975, -0.5012, ...
               -0.4974, -0.4922, -0.4896];
dklThetas   = 0:45:360;

% Call dkl2rgb to capture all 3 outputs (r, g, b)
dkl_palette_dkl = zeros(length(dklThetas), 3); % To store DKL coordinates
dkl_palette_rgb = zeros(length(dklThetas), 3); % To store final RGB values

for i = 1:length(dklThetas)
    % Define the color in DKL coordinates
    dkl_color_vec = [p.rig.dklLum(i); satRad * cosd(dklThetas(i)); satRad * sind(dklThetas(i))];
    
    % Store the DKL coordinates (transposed to be a row vector)
    dkl_palette_dkl(i, :) = dkl_color_vec';
    
    % Convert to RGB and store the result
    [r, g, b] = dkl2rgb(dkl_color_vec);
    dkl_palette_rgb(i, :) = [r, g, b];
end

% --- Store palettes for later use ---
p.draw.colors.dklPalette_dkl = dkl_palette_dkl;
p.draw.colors.dklPalette_rgb = dkl_palette_rgb;

% Correctly call dkl2rgb for isoluminant gray
mean_lum = mean(p.rig.dklLum);
[r_gray, g_gray, b_gray] = dkl2rgb([mean_lum; 0; 0]);
p.draw.colors.isolumGray = [r_gray, g_gray, b_gray];

%% 2. Build the initial, default CLUTs
default_bg = p.draw.colors.isolumGray;

expCLUT = zeros(256, 3);
subCLUT = zeros(256, 3);

mutGreen    = [0.5 0.9 0.4];
redISH      = [225 0 76]/255;
orangeISH   = [255 146 0]/255;
blueISH     = [11 97 164]/255;
oldGreen    = [0.45, 0.63, 0.45];

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

% Fill the rest of the CLUT (indices 17-255) explicitly
expCLUT(18:256, 1) = default_bg(1);
expCLUT(18:256, 2) = default_bg(2);
expCLUT(18:256, 3) = default_bg(3);
subCLUT(18:256, 1) = default_bg(1);
subCLUT(18:256, 2) = default_bg(2);
subCLUT(18:256, 3) = default_bg(3);

p.draw.clut.expCLUT = expCLUT;
p.draw.clut.subCLUT = subCLUT;

end
