function p                      = initClut(p)
% initialize color lookup tables
% CLUTs may be customized as needed
% CLUTS also need to be defined before initializing DataPixx
% also define variables as pointers to certain colors (for ease of
% reference in other places).

% initialize DKL conversion variables
p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

% set Background color to dark gray.
[bgRGB(1), bgRGB(2), bgRGB(3)] = dkl2rgb([-0.8 0 0]');

% define colors to be used to define the spatial cue: a gray and 3
% isoluminant equally saturated hues:
cueColors = zeros(4, 3);
[cueColors(:,1), cueColors(:,2), cueColors(:,3)] = ...
    dkl2rgb(...
    [[0 0.8 1]/norm([0, 0.8, 1]); ...           % small reward red
    [0 -0.6 -1 ]/norm([0, -0.6, -1]); ...       % medium reward blue
    [0 -0.95 0.25]/norm([0, -0.95, 0.25]); ...  % large reward green
    0 0 0]');                                % grey filler

% define some useful colors for the experimenter
redISH      = [225 0 76]/255;
orangeISH   = [255 146 0]/255;
blueISH     = [11 97 164]/255;
greenISH    = [112 229 0]/255;
oldGreen    = [0.45, 0.63, 0.45];

% colors for exp's display
% black                     0
% gray-1 (grid-lines)       1
% gray-2 (background)       2
% gray-3 (fix-window)       3
% white  (fix-point)        4
% red                       5
% orange                    6
% blue                      7
% small reward cue color    8
% medium reward cue color   9
% large reward cue color    10
% dark fill cue color       11

p.draw.clut.expColors = ...
    [ 0, 0, 0;          % 0
    0.25, 0.25, 0.25;   % 1
    bgRGB;              % 2
    0.7, 0.7, 0.7;      % 3
    1, 1, 1;            % 4
    redISH;             % 5
    orangeISH;          % 6
    blueISH;            % 7
    cueColors(1,:);     % 8
    cueColors(2,:);     % 9
    cueColors(3,:);     % 10
    cueColors(4,:);     % 11
    0, 0, 0;            % 12
    oldGreen];           % 13

% colors for subject's display
% black                     0
% gray-2 (grid-lines)       1
% gray-2 (background)       2
% gray-2 (fix-window)       3
% white  (fix-point)        4
% gray-2 (red)              5
% gray-2 (green)            6
% gray-2 (blue)             7
% small reward cue color    8
% medium reward cue color   9
% large reward cue color    10
% dark fill cue color       11

p.draw.clut.subColors = ...
    [0, 0, 0;           % 0
    bgRGB;              % 1
    bgRGB;              % 2
    bgRGB;              % 3
    1, 1, 1;            % 4
    bgRGB;              % 5
    bgRGB;              % 6
    bgRGB;              % 7
    cueColors(1,:);     % 8
    cueColors(2,:);     % 9
    cueColors(3,:);     % 10
    cueColors(4,:);     % 11
    bgRGB;              % 12
    oldGreen];           % 13

assert(size(p.draw.clut.subColors,1)==size(p.draw.clut.expColors,1), 'ERROR-- exp & sub Colors must have equal length')

%%

% fill the remaining LUT slots with background RGB.
p.draw.nColors                                          = size(p.draw.clut.subColors,1);
nTotalColors                                            = 256;
p.draw.clut.expColors(p.draw.nColors+1:nTotalColors, :) = [...
    linspace(bgRGB(1), 1, nTotalColors - p.draw.nColors)', ...
    linspace(bgRGB(2), 1, nTotalColors - p.draw.nColors)', ...
    linspace(bgRGB(3), 1, nTotalColors - p.draw.nColors)'];

p.draw.clut.subColors(p.draw.nColors+1:nTotalColors, :) = [...
    linspace(bgRGB(1), 1, nTotalColors - p.draw.nColors)', ...
    linspace(bgRGB(2), 1, nTotalColors - p.draw.nColors)', ...
    linspace(bgRGB(3), 1, nTotalColors - p.draw.nColors)'];

% populate the rest with 0's
p.draw.clut.ffc      = p.draw.nColors + 1;
p.draw.clut.expCLUT  = p.draw.clut.expColors;
p.draw.clut.subCLUT  = p.draw.clut.subColors;


end



