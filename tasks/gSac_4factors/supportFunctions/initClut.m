function p = initClut(p)
% initClut
%
% Builds the single, static CLUT for the redesigned gSac_4factors experiment.
% This function is called only once during initialization.

fprintf('--- Building static CLUT ---\n');

%% 1. Initialize DKL conversion and define color palette
p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

% We only need to calculate the 4 specific hues for the bullseye trials
% and the isoluminant gray.
dkl_hues_to_calc = [0, 45, 180, 225];
p.draw.colors.bullseye_hues = zeros(length(dkl_hues_to_calc), 3);

% Use the mean luminance from your empirical measurements
mean_lum = -0.495; % Approx. mean of your dklLum vector
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

%% 2. Generate the Grayscale Ramp
% This ramp will occupy indices 18-255. It's a linear ramp from
% black to white in gun values (0 to 1).
n_ramp_levels = p.draw.clutIdx.grayscale_ramp_end - p.draw.clutIdx.grayscale_ramp_start + 1;
gray_ramp = linspace(0, 1, n_ramp_levels)';
gray_ramp = [gray_ramp, gray_ramp, gray_ramp]; % Create Nx3 matrix

%% 3. Assemble the Final 256x3 CLUT
clut = zeros(256, 3);
idx = p.draw.clutIdx; % Get the indices from the settings file

% --- Fill in all entries explicitly ---
% Core Task Colors (0-7)
clut(idx.black + 1, :)      = [0 0 0];
clut(idx.gridLines + 1, :)  = [0.25 0.25 0.25];
clut(idx.bg_image + 1, :)   = p.draw.colors.isolumGray;
clut(idx.fixWin + 1, :)     = [0.7 0.7 0.7];
clut(idx.white + 1, :)      = [1 1 1];
clut(idx.eyePos + 1, :)     = [0.04 0.38 0.64]; % "blueISH"
clut(idx.rwd_high + 1, :)   = [0 1 0]; % Bright Green
clut(idx.rwd_low + 1, :)    = [0 0.5 0]; % Dim Green

% Bullseye Hues (8-11)
clut(idx.dkl_0 + 1, :)      = p.draw.colors.bullseye_hues(1,:);
clut(idx.dkl_45 + 1, :)     = p.draw.colors.bullseye_hues(2,:);
clut(idx.dkl_180 + 1, :)    = p.draw.colors.bullseye_hues(3,:);
clut(idx.dkl_225 + 1, :)    = p.draw.colors.bullseye_hues(4,:);

% Grayscale Ramp (18-255)
ramp_indices = (idx.grayscale_ramp_start:idx.grayscale_ramp_end) + 1;
clut(ramp_indices, :) = gray_ramp;

%% 4. Store the final CLUT
% In a static CLUT design, the experimenter and subject CLUTs are identical
p.draw.clut.expCLUT = clut;
p.draw.clut.subCLUT = clut;
fprintf('  ... Static CLUT built successfully.\n\n');

end