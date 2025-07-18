function c                      = initClut(c)
% initialize color lookup tables
% CLUTs may be customized as needed
% CLUTS also need to be defined before initializing DataPixx
% also define variables as pointers to certain colors (for ease of
% reference in other places).




% set Bg to 0.5 0.5 0.5:
bgRGB       = 0.45*[1 1 1];
% define muted green (mutGreen):
% mutGreen    = [0.3953 0.7459 0.5244];
mutGreen    = [0.5 0.9 0.4];

redISH      = [1 0.9 0];
orangeISH   = [255 146 0]/255;
blueISH     = [0 0 255]/255;
greenISH    = [0.9 1 0];
oldGreen    = [0.45, 0.63, 0.45];
visGreen    = [0.1 0.9 0.1];
memMagenta  = [1 0 1];
yellowISH   = [1 1 0];

randColors = rand (100, 3);

% Alternative way to generate random colors, using LAB colorspace
% randomly generate angle values (thetas)
% choose radius values within a certain range (r)
% convert to ab coordinates for the LAB colorspace (ab)
% choose luminance values within a certain range (L) 
% convert to RGB values using lab2rgb
thetas = randn(100,1)*10 + 90;
r = rand(100,1)*20 + 80;
ab = repmat(r,1,2).*[cosd(thetas), sind(thetas)];
L = rand(100,1)*10 + 60;
rgbVals = lab2rgb([L,ab]);


% Scans the "randColors" array for any row with all three elements between 0.4 and 0.5
% (i.e. too close in color to background grey) and rerolls them, then rechecks that row


for i = 1:100
    if ((randColors (i, 1) > 0.4 & randColors (i, 1) < 0.5) & ...
	(randColors (i, 2) > 0.4 & randColors (i, 1) < 0.5) & ...
	(randColors (i, 3) > 0.4 & randColors (i, 1) < 0.5))
		randColors (i, :) = rand (1, 3);
		i = i - 1;
end

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

c.draw.clut.expColors = ...
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
    oldGreen;           % 13
    visGreen;           % 14
    memMagenta;         % 15
    0, 1, 1;		% 16
    yellowISH;		% 17
    1, 0, 0;		% 18 (Note: 18-23 used for varying color of stim)
    0, 1, 0;		% 19
    0, 0 ,1;		% 20
    0, 1, 1;		% 21
    1, 0, 1;		% 22
    1, 1, 0];         	% 23

% 24-123 (below) randomly generated to create randomly colored stim
c.draw.clut.expColors (25:124, :) = randColors;

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

c.draw.clut.subColors = ...
    [0, 0, 0;     % 0
    bgRGB;        % 1
    bgRGB;        % 2
    bgRGB;        % 3
    1, 1, 1;      % 4
    redISH;        % 5
    bgRGB;        % 6
    bgRGB;        % 7
    0, 1, 1;      % 8
    bgRGB;        % 9
    mutGreen;     % 10
    greenISH;        % 11
    bgRGB;        % 12
    oldGreen;     % 13
    bgRGB;        % 14
    bgRGB;        % 15
    bgRGB;	  % 16
    yellowISH;    % 17
    1, 0, 0;		% 18-23 used for varying color of stim
    0, 1, 0;		% 19
    0, 0 ,1;		% 20
    0, 1, 1;		% 21
    1, 0, 1;		% 22
    1, 1, 0];         	% 23

% 24-123 (below) randomly generated to create randomly colored stim    
c.draw.clut.subColors (25:124, :) = randColors;

    
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



