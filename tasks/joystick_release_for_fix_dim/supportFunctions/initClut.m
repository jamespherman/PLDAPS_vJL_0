function p                      = initClut(p)
% initialize color lookup tables
% CLUTs may be customized as needed
% CLUTS also need to be defined before initializing DataPixx
% also define variables as pointers to certain colors (for ease of
% reference in other places).


% initialize DKL conversion variables`
initmon('LUTvpixx');

% set Background color to black.
[bgRGB(1), bgRGB(2), bgRGB(3)] = dkl2rgb([-0.8 0 0]');

% define muted green (mutGreen):
% mutGreen    = [0.3953 0.7459 0.5244];
mutGreen    = [0.5 0.9 0.4];

% define some other useful colors
redISH      = [225 0 76]/255;
orangeISH   = [255 146 0]/255;
blueISH     = [11 97 164]/255;
greenISH    = [112 229 0]/255;
oldGreen    = [0.45, 0.63, 0.45];

% colors for exp's display
% black                     0
% grey-1 (grid-lines)       1
% grey-2 (background)       2
% grey-3 (fix-window)       3
% white  (fix-point)        4
% red                       5
% orange                    6
% blue                      7
% cue ring                  8
% muted green (fixation)    9

p.draw.clut.expColors = ...
    [ 0, 0, 0;          % 0
    0.25, 0.25, 0.25;   % 1
    bgRGB;              % 2
    0.7, 0.7, 0.7;      % 3
    1, 1, 1;            % 4
    redISH;             % 5
    orangeISH;          % 6
    blueISH;            % 7
    0, 1, 1;            % 8
    0.9,0.9,0.9;        % 9
    mutGreen;           % 10
    greenISH;           % 11
    0, 0, 0;            % 12
    oldGreen];           % 13

% colors for subject's display
% black                     0
% grey-2 (grid-lines)       2
% grey-2 (background)       2
% grey-2 (fix-window)       3
% white  (fix-point)        4
% grey-2 (red)              2
% grey-2 (green)            2
% grey-2 (blue)             2
% cuering                   8
% muted green (fixation)    9

p.draw.clut.subColors = ...
    [0, 0, 0;           % 0
    bgRGB;              % 1
    bgRGB;              % 2
    bgRGB;              % 3
    1, 1, 1;            % 4
    bgRGB;              % 5
    bgRGB;              % 6
    bgRGB;              % 7
    0, 1, 1;            % 8
    bgRGB;              % 9
    mutGreen;           % 10
    bgRGB;              % 11
    bgRGB;              % 12
    oldGreen];           % 13

% Throw error if the exp / sub colors are unequal lengths:
assert(size(p.draw.clut.subColors,1)==size(p.draw.clut.expColors,1), ...
    'ERROR-- exp & sub Colors must have equal length')

%%

% fill the remaining CLUT slots with background RGB.
p.draw.nColors                                  = ...
    size(p.draw.clut.subColors,1);
nTotalColors                                    = 256;
p.draw.clut.ffc                                 = p.draw.nColors + 1;
p.draw.clut.expCLUT                             = p.draw.clut.expColors;
p.draw.clut.subCLUT                             = p.draw.clut.subColors;
p.draw.clut.expCLUT(p.draw.clut.ffc:nTotalColors, :) = ...
    repmat(bgRGB, nTotalColors - p.draw.nColors, 1);
p.draw.clut.subCLUT(p.draw.clut.ffc:nTotalColors, :) = ...
    repmat(bgRGB, nTotalColors - p.draw.nColors, 1);

end



