function p = initClut(p)
% initClut
%
% DEFINITIVE FINAL VERSION (August 7, 2025)
% 1. Initializes the DKL color palette (both DKL and RGB versions).
% 2. Programmatically calculates stimStart/End indices based on nStimLevels from settings.
% 3. Builds the complete STATIC 17-row portions of the exp/sub CLUTs.
% 4. Builds a full, default CLUT for opening the PTB window.

fprintf('--- Initializing color palette and static CLUT portions ---\n');

%% 1. Define DKL color palette
p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

satRad      = 0.4;
p.rig.dklLum      = [-0.4888, -0.4871, -0.4958, -0.4944, -0.4975, -0.5012, ...
                   -0.4974, -0.4922, -0.4896];
dklThetas   = 0:45:360;

% Pre-allocate matrices for both DKL and RGB palettes
dkl_palette_dkl = zeros(length(dklThetas), 3);
dkl_palette_rgb = zeros(length(dklThetas), 3);

for i = 1:length(dklThetas)
    dkl_color_vec = [p.rig.dklLum(i); satRad * cosd(dklThetas(i)); satRad * sind(dklThetas(i))];
    dkl_palette_dkl(i, :) = dkl_color_vec';
    [r, g, b] = dkl2rgb(dkl_color_vec);
    dkl_palette_rgb(i, :) = [r, g, b];
end
p.draw.colors.dklPalette_dkl = dkl_palette_dkl;
p.draw.colors.dklPalette_rgb = dkl_palette_rgb;

mean_lum = mean(p.rig.dklLum);
[r_gray, g_gray, b_gray] = dkl2rgb([mean_lum; 0; 0]);
p.draw.colors.isolumGray = [r_gray, g_gray, b_gray];
fprintf('  ... DKL and RGB color palettes defined.\n');


%% 2. Programmatically define dynamic CLUT indices
% Uses the parameter from the settings file to define the indices.
p.draw.clutIdx.stimStart = p.draw.clutIdx.stimBg + 1;
p.draw.clutIdx.stimEnd   = p.draw.clutIdx.stimStart + p.stim.nStimLevels - 1;

% Add a check to ensure we don't exceed the CLUT's capacity
if p.draw.clutIdx.stimEnd > 255
    error('FATAL: The number of static CLUT entries plus nStimLevels exceeds 256!');
end
fprintf('  ... Dynamic stimulus indices defined: %d to %d.\n', p.draw.clutIdx.stimStart, p.draw.clutIdx.stimEnd);


%% 3. Build and store the STATIC (17-row) CLUTs
idx = p.draw.clutIdx;
static_expCLUT = zeros(17, 3);
static_subCLUT = zeros(17, 3);

% Define named colors for static entries
mutGreen    = [0.5 0.9 0.4];
redISH      = [225 0 76]/255;
orangeISH   = [255 146 0]/255;
blueISH     = [11 97 164]/255;
oldGreen    = [0.45, 0.63, 0.45];
visGreen    = [0.1 0.9 0.1];
memMagenta  = [1 0 1];

% --- Populate the 17-row static Experimenter CLUT ---
static_expCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
static_expCLUT(idx.expGrey25_subBg + 1, :)         = [0.25 0.25 0.25];
static_expCLUT(idx.expBg_subBg + 1, :)             = p.draw.colors.isolumGray; % Default BG
static_expCLUT(idx.expGrey70_subBg + 1, :)         = [0.7 0.7 0.7];
static_expCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
static_expCLUT(idx.expRed_subBg + 1, :)            = redISH;
static_expCLUT(idx.expOrange_subBg + 1, :)         = orangeISH;
static_expCLUT(idx.expBlue_subBg + 1, :)           = blueISH;
static_expCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
static_expCLUT(idx.expGrey90_subBg + 1, :)         = [0.9 0.9 0.9];
static_expCLUT(idx.expMutGreen_subBg + 1, :)       = mutGreen;
static_expCLUT(idx.expGreen_subBg + 1, :)          = [112 229 0]/255;
static_expCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
static_expCLUT(idx.expVisGreen_subBg + 1, :)       = visGreen;
static_expCLUT(idx.expMemMagenta_subBg + 1, :)     = memMagenta;
static_expCLUT(idx.expCyan_subBg + 1, :)           = [0 1 1];

% --- Populate the 17-row static Subject CLUT ---
static_subCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
static_subCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
static_subCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
static_subCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
static_subCLUT(idx.expGrey25_subBg + 1, :)         = p.draw.colors.isolumGray;
static_subCLUT(idx.expBg_subBg + 1, :)             = p.draw.colors.isolumGray;
static_subCLUT(idx.expGrey70_subBg + 1, :)         = p.draw.colors.isolumGray;
static_subCLUT(idx.expRed_subBg + 1, :)            = p.draw.colors.isolumGray;
static_subCLUT(idx.expOrange_subBg + 1, :)         = p.draw.colors.isolumGray;
static_subCLUT(idx.expBlue_subBg + 1, :)           = p.draw.colors.isolumGray;
static_subCLUT(idx.expGrey90_subBg + 1, :)         = p.draw.colors.isolumGray;
static_subCLUT(idx.expMutGreen_subBg + 1, :)       = p.draw.colors.isolumGray;
static_subCLUT(idx.expGreen_subBg + 1, :)          = p.draw.colors.isolumGray;
static_subCLUT(idx.expVisGreen_subBg + 1, :)       = p.draw.colors.isolumGray;
static_subCLUT(idx.expMemMagenta_subBg + 1, :)     = p.draw.colors.isolumGray;
static_subCLUT(idx.expCyan_subBg + 1, :)           = p.draw.colors.isolumGray;

% --- Store the static portions for efficient use in redefClut ---
p.draw.clut.static_expCLUT = static_expCLUT;
p.draw.clut.static_subCLUT = static_subCLUT;
fprintf('  ... Static CLUT portions built.\n');

%% 4. Build a full, default CLUT for opening the PTB window
default_ramp = repmat(p.draw.colors.isolumGray, 256-17, 1);
p.draw.clut.expCLUT = [p.draw.clut.static_expCLUT; default_ramp];
p.draw.clut.subCLUT = [p.draw.clut.static_subCLUT; default_ramp];
fprintf('  ... default CLUTs built.\n\n');

end