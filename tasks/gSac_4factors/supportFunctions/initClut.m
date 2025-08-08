function p = initClut(p)
% initClut
%
% Builds the single, static CLUT for the gSac_4factors experiment.

fprintf('--- Building static CLUT ---\n');

%% 1. Initialize DKL conversion and define color palette
p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

dkl_hues_to_calc = [0, 45, 180, 225];
p.draw.colors.bullseye_hues = zeros(length(dkl_hues_to_calc), 3);
mean_lum = -0.495;
satRad = 0.4;
for i = 1:length(dkl_hues_to_calc)
    theta = dkl_hues_to_calc(i);
    dkl_color = [mean_lum; satRad * cosd(theta); satRad * sind(theta)];
    [r, g, b] = dkl2rgb(dkl_color);
    p.draw.colors.bullseye_hues(i, :) = [r, g, b];
end
[r_gray, g_gray, b_gray] = dkl2rgb([mean_lum; 0; 0]);
p.draw.colors.isolumGray = [r_gray, g_gray, b_gray];
fprintf('  ... DKL colors defined.\n');


%% 2. Assemble the Experimenter's CLUT (expCLUT)
expCLUT = zeros(256, 3);
idx = p.draw.clutIdx;

% --- Fill in all entries explicitly for the experimenter display ---
expCLUT(idx.expBlack_subBlack + 1, :)      = [0 0 0];
expCLUT(idx.expGrey25_subBg + 1, :)         = [0.25 0.25 0.25];
expCLUT(idx.expGrey_subBg + 1, :)           = p.draw.colors.isolumGray;
expCLUT(idx.expGrey70_subBg + 1, :)         = [0.7 0.7 0.7];
expCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
expCLUT(idx.expBlue_subBg + 1, :)           = [11 97 164]/255;
expCLUT(idx.expGreen_subBg + 1, :)          = [0 1 0];
expCLUT(idx.expDkGreen_subBg + 1, :)        = [0 0.5 0];
expCLUT(idx.expDkl0_subDkl0 + 1, :)         = p.draw.colors.bullseye_hues(1,:);
expCLUT(idx.expDkl45_subDkl45 + 1, :)       = p.draw.colors.bullseye_hues(2,:);
expCLUT(idx.expDkl180_subDkl180 + 1, :)     = p.draw.colors.bullseye_hues(3,:);
expCLUT(idx.expDkl225_subDkl225 + 1, :)     = p.draw.colors.bullseye_hues(4,:);

% Generate and insert the Grayscale Ramp
n_ramp_levels = idx.grayscale_ramp_end - idx.grayscale_ramp_start + 1;
gray_ramp = linspace(0, 1, n_ramp_levels)';
gray_ramp = [gray_ramp, gray_ramp, gray_ramp];
ramp_indices = (idx.grayscale_ramp_start:idx.grayscale_ramp_end) + 1;
expCLUT(ramp_indices, :) = gray_ramp;


%% 3. Programmatically create the Subject's CLUT (subCLUT)
% Start with a copy of the experimenter's CLUT
subCLUT = expCLUT;

% Find all clutIdx fields that should be invisible to the subject (_subBg)
subBg_rows = [];
idx_fields = fieldnames(p.draw.clutIdx);
for i = 1:length(idx_fields)
    field_name = idx_fields{i};
    if contains(field_name, '_subBg')
        index_to_update = p.draw.clutIdx.(field_name);
        subBg_rows(end+1) = index_to_update + 1; % Store the 1-based index
    end
end
subBg_rows = unique(subBg_rows);

% Set these rows in the subject's CLUT to the default background color
subCLUT(subBg_rows, :) = repmat(p.draw.colors.isolumGray, length(subBg_rows), 1);
fprintf('  ... Subject CLUT created with %d invisible elements.\n', length(subBg_rows));


%% 4. Store the final CLUTs
p.draw.clut.expCLUT = expCLUT;
p.draw.clut.subCLUT = subCLUT;
fprintf('  ... Static CLUT built successfully.\n\n');

end