function c                      = initClut(c)
% initialize color lookup tables
% CLUTs may be customized as needed
% CLUTS also need to be defined before initializing DataPixx
% also define variables as pointers to certain colors (for ease of
% reference in other places).


% initialize DKL conversion variables
c.init.initMonFile = ['LUT_VPIXX_rig' c.init.pcName(end-1)];
initmon(c.init.initMonFile);

% set Background color to black.
[bgRGB(1), bgRGB(2), bgRGB(3)] = dkl2rgb([-0.8 0 0]');

% define some new DKL colors with equal saturation and luminance:
satRad      = 0.4;
dklLum      = -0.5;
dklThetas   = 0:45:360;

for i = 1:length(dklThetas)
    [r(i), g(i), b(i)] = dkl2rgb(...
        [dklLum satRad *[cosd(dklThetas(i)) sind(dklThetas(i))]]');
end

% fortyfivedegree_pospos = [ 0.6235 0.4863 0.4157];
% fortyfivedegree_posneg = [0.6431 0.4078 0.6392];
% fortyfivedegree_negneg = [ 0.3922 0.5686 0.6235];
% fortyfivedegree_negpos = [0.3647 0.6235 0.3843];
% define muted green (mutGreen):
% mutGreen = [0.3953 0.7459 0.5244];
mutGreen = [0.5 0.9 0.4];
redISH = [225 0 76]/255;
orangeISH = [255 146 0]/255;
blueISH = [11 97 164]/255;
greenISH = [112 229 0]/255;
oldGreen = [0.45, 0.63, 0.45];
visGreen = [0.1 0.9 0.1];
memMagenta = [1 0 1];
% colors for exp's display
% black 0
% grey-1 (grid-lines) 1
% grey-2 (background) 2
% grey-3 (fix-window) 3
% white (fix-point) 4
% red 5
% orange 6
% blue 7
% cue ring 8
% muted green (fixation) 9
c.draw.clut.expColors = ...
    [ 0, 0, 0; % 0
    0.25, 0.25, 0.25; % 1
    bgRGB; % 2
    0.7, 0.7, 0.7; % 3
    1, 1, 1; % 4
    redISH; % 5
    orangeISH; % 6
    blueISH; % 7
    0, 1, 1; % 8
    0.9,0.9,0.9; % 9
    mutGreen; % 10
    greenISH; % 11
    0, 0, 0; % 12
    oldGreen; % 13
    visGreen; % 14
    memMagenta; % 15
    0, 1, 1; % 16
    [r', g', b']]; % 17-24

% colors for subject's display
% black 0
% grey-2 (grid-lines) 2
% grey-2 (background) 2
% grey-2 (fix-window) 3
% white (fix-point) 4
% grey-2 (red) 2
% grey-2 (green) 2
% grey-2 (blue) 2
% cuering 8
% muted green (fixation) 9
c.draw.clut.subColors = ...
    [0, 0, 0; % 0
    bgRGB; % 1
    bgRGB; % 2
    bgRGB; % 3
    1, 1, 1; % 4
    bgRGB; % 5
    bgRGB; % 6
    bgRGB; % 7
    0, 1, 1; % 8
    bgRGB; % 9
    mutGreen; % 10
    bgRGB; % 11
    bgRGB; % 12
    oldGreen; % 13
    bgRGB; % 14
    bgRGB; % 15
    bgRGB; % 16
    [r', g', b']]; % 17-24




assert(size(c.draw.clut.subColors,1)==size(c.draw.clut.expColors,1), 'ERROR-- exp & sub Colors must have equal length')

%%

% fill the remaining LUT slots with background RGB.
nColors         = size(c.draw.clut.subColors,1);
nTotalColors    = 256;
c.draw.clut.expColors(nColors+1:nTotalColors, :) = repmat(bgRGB, nTotalColors-nColors, 1);
c.draw.clut.subColors(nColors+1:nTotalColors, :) = repmat(bgRGB, nTotalColors-nColors, 1);

% populate the rest with 0's
c.draw.clut.ffc      = nColors + 1;
c.draw.clut.expCLUT  = c.draw.clut.expColors;
c.draw.clut.subCLUT  = c.draw.clut.subColors;


end



