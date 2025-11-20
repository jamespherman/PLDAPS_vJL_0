function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.


% Trial type information:
% vis- or mem-guided saccade
p = trialTypeInfo(p);

% if we're using p.init.trialsArray to determine target locations, do the
% book keeping for that here:
if p.trVars.setTargLocViaTrialArray
    p = chooseRow(p);
end

% set fixation and target locations for next trial:
p = setLocations(p);

% Timing info:
% target onset/offset time
p = timingInfo(p);

end

%
function p = trialTypeInfo(p)

if rand <= p.trVars.propVis
    p.trVars.isVisSac = 1;
else
    p.trVars.isVisSac = 0;
end

end

%
% function p = setTargetLocation(p)
function p = setLocations(p)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set target properties and locations %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Define target location for next trial. First define which column of the
% trials array contains the "numDots" information, then choose a target
% location.
numDotsCol = strcmp(p.init.trialArrayColumnNames, 'numDots');
p.trVars.numDots   = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    numDotsCol);
    
numTargetsCol = strcmp(p.init.trialArrayColumnNames, 'numTargets');  
p.trVars.numTargets = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
    numTargetsCol);  

targsSameColorCol = strcmp(p.init.trialArrayColumnNames, 'targsSameColor');
p.trVars.targsSameColor = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   targsSameColorCol);
 
% Where will the target be displayed? We want the 1-dot target to always
% appear above the fixation and the 2-dot target to always appear below the
% fixation. These will be shown at the same distance based on targDegY

%{
p.trVars.targOneDegX	= p.trVars.targDegX;
p.trVars.targOneDegY	= p.trVars.targDegY;

p.trVars.targTwoDegX	= p.trVars.targDegX;
p.trVars.targTwoDegY	= p.trVars.targDegY * (-1);
%}

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

p.draw.targOnePointPix     =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targOneDegX, p.trVars.targOneDegY], p);
p.draw.targTwoPointPix     =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targTwoDegX, p.trVars.targTwoDegY], p);

% fixation window width and height in pixels.
p.draw.fixWinWidthPix       = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix      = pds.deg2pix(p.trVars.fixWinHeightDeg, p);

% target window width and height in pixels.
p.draw.targWinWidthPix      = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix     = pds.deg2pix(p.trVars.targWinHeightDeg, p);

% what is the separation between the two dots (when there are two dots
% shown) in pixels?
p.draw.twoTargSepPix = pds.deg2pix(p.trVars.twoTargSepDeg, p);

% Convert target X & Y into radius and theta so that we can strobe:
% (can't strobe negative values, so r/th solves that)

[tmpTheta, tmpRadius]   = cart2pol(p.trVars.targDegX, p.trVars.targDegY);

% In order to strobe I need round positive numbers. 
% For theta, I multiply by 10 ('_x10') and round. That gives 1 decimlal 
% point precision, good enough!
p.trVars.targTheta_x10  = round(mod(tmpTheta * 180 / pi, 360) * 10); 

% For radius, I multiply by 100 ('_x100') and round. That gives 2 decimlal
% point precision, goo enough!
p.trVars.targRadius_x100 = round(tmpRadius * 100);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set stim properties and locations %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
stimShapeCol = strcmp(p.init.trialArrayColumnNames, 'stimShape');
p.trVars.stimShape = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   stimShapeCol);

% randomly choose size of stimulus between min and max
p.draw.stimWidth1 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);
p.draw.stimHeight1 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);

% Second set chosen for two-stim trials
p.draw.stimWidth2 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);
p.draw.stimHeight2 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);

% If presenting 1 stimulus, increase width and height by up to sqrt(2) so that the max area = total area of two dots
if p.trVars.numDots == 1
	p.draw.stimWidth1 = p.draw.stimWidth1*(unifrnd(1, sqrt(2)));
	p.draw.stimHeight1 = p.draw.stimHeight1*(unifrnd(1, sqrt(2)));
end

% Note: this method of choosing colour is compatible with FillOval and FillRect, not textures
% randomly choose stim color (note: 2/100 will be white, 98/100 randomly generated when initializing)
%p.trVars.stimColor1 = randi([24, 123]);
%p.trVars.stimColor2 = randi([24, 123]); % For when two stim are presented

% randomly choose x and y coordinates within given radius.
% Should not be used simultaneously with stimRangeX and stimRangeY (below)
%p.trVars.stimDegX  = p.trVars.stimRangeRadius .* cos(2*pi*rand);
%p.trVars.stimDegY  = p.trVars.stimRangeRadius .* sin(2*pi*rand);

% randomly choose x and y coordinates within given ranges (stimRangeX and stimRangeY)
p.trVars.stimDegX = unifrnd(p.trVars.stimRangeXmin, p.trVars.stimRangeXmax);
p.trVars.stimDegY = unifrnd(p.trVars.stimRangeYmin, p.trVars.stimRangeYmax);

p.draw.stimPointPix	=  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.stimDegX, p.trVars.stimDegY], p);

% randomly rotate the individual stims by some amount
p.trVars.stimRotation1 = deg2rad(unifrnd(-p.trVars.oneStimRotationRange/2, p.trVars.oneStimRotationRange/2));
p.trVars.stimRotation2 = deg2rad(unifrnd(-p.trVars.oneStimRotationRange/2, p.trVars.oneStimRotationRange/2));

% For two-stim trials, how separated should they be (edge to edge)?
p.draw.twoStimSepPix = pds.deg2pix(unifrnd(p.trVars.twoStimSepDegMin, p.trVars.twoStimSepDegMax), p);

% Now randomly rotate the stimuli relative to each other by between 0 and twoStimRotationRange degrees
p.trVars.twoStimRotation = deg2rad(unifrnd(-p.trVars.twoStimRotationRange/2, p.trVars.twoStimRotationRange/2));


% Texture stuff old %%%%%%%%%%%%%%%%%%%%%%%
%{
%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set colors for texture %
%%%%%%%%%%%%%%%%%%%%%%%%%%

p.trVars.stimColor1 = rand (1, 3);
p.trVars.stimColor2 = rand (1, 3);

% Check if either color is too close to background grey (i.e. all 3 RGB values are between 0.4 and 0.5)
isGrey = 1;
while isGrey
    isGrey = 0;
    if ((p.trVars.stimColor1 (1) > 0.4 & p.trVars.stimColor1 (1) < 0.5) & ...
	(p.trVars.stimColor1 (2) > 0.4 & p.trVars.stimColor1 (1) < 0.5) & ...
	(p.trVars.stimColor1 (3) > 0.4 & p.trVars.stimColor1 (1) < 0.5))
		p.trVars.stimColor1 = rand (1, 3);
		isGrey = 1;
    elseif ((p.trVars.stimColor2 (1) > 0.4 & p.trVars.stimColor2 (1) < 0.5) & ...
	(p.trVars.stimColor2 (2) > 0.4 & p.trVars.stimColor2 (1) < 0.5) & ...
	(p.trVars.stimColor2 (3) > 0.4 & p.trVars.stimColor2 (1) < 0.5))
		p.trVars.stimColor2 = rand (1, 3);
		isGrey = 1;
    end
end

% On 2% of trials, make stim color white instead
if rand > 0.98
    p.trVars.stimColor1 = [1, 1, 1];
end

% On 50% of trials, make color of second stim same as first, and on 2% of trials, make white
if rand > 0.5
    p.trVars.stimColor2 = p.trVars.stimColor1;
elseif rand > 0.98
    p.trVars.stimColor2 = [1, 1, 1];
end

% Create color gradients between the stim color and background grey across 100 values.
% linspace is done over Lab colorspace instead of RGB as it produces a smoother gradient

labGrey = rgb2lab([0.45 0.45 0.45]);
labStimColor1 = rgb2lab(p.trVars.stimColor1);
labStimColor2 = rgb2lab(p.trVars.stimColor2);

for i = 1:3
	labClut1 (:, i) = linspace (labGrey(i), labStimColor1(i));
	labClut2 (:, i) = linspace (labGrey(i), labStimColor2(i));
end

stimClut1 = lab2rgb (labClut1);
stimClut2 = lab2rgb (labClut2);

stimClut1(stimClut1 > 1) = 1;
stimClut2(stimClut2 > 1) = 1;
stimClut1(stimClut1 < 0) = 0;
stimClut2(stimClut2 < 0) = 0;



% Alternatively, perform linspace over RGB space:
%{
stimClut1 = zeros (100, 3);
stimClut2 = zeros (100, 3);

for i = 1:3
	stimClut1 (:, i) = linspace (0.45, p.trVars.stimColor1(i));
	stimClut2 (:, i) = linspace (0.45, p.trVars.stimColor2(i));
end
%}


% Put the color gradients into the CLUTS to be pushed to ViewPIXX
p.draw.clut.expCLUT (51:150, :) = stimClut1;
p.draw.clut.subCLUT (51:150, :) = stimClut1;

p.draw.clut.expCLUT (151:250, :) = stimClut2;
p.draw.clut.subCLUT (151:250, :) = stimClut2;

% Push new CLUT to ViewPIXX
Datapixx('SetVideoClut', [p.draw.clut.subCLUT; p.draw.clut.expCLUT]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define texture window and center locations for stims %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Texture window should be large enough to accomadate two max-size stim with max size separation/rotation,
% plus some extra empty space to allow blurring with convolution. Forced to be even as odd values
% caused weird issues
p.draw.textureWindowDimensions = 2*round(pds.deg2pix (p.trVars.twoStimSepDegMax + p.trVars.stimSizeMax*sqrt(2)*2.5, p)/2);

% define center of texture window to shift things into appropriate frame
textureWindowCenter = [p.draw.textureWindowDimensions/2; p.draw.textureWindowDimensions/2];

% Calculate "pseudodiameter"; i.e. diameter of largest circle representative of the shape
if p.trVars.stimShape == 1 % If oval, use major axis
	pseudoDiameter1 = max (p.draw.stimWidth1, p.draw.stimHeight1);
	pseudoDiameter2 = max (p.draw.stimWidth2, p.draw.stimHeight2);
elseif p.trVars.stimShape == 2 % If rect, use diagonal
	pseudoDiameter1 = sqrt(p.draw.stimWidth1^2 + p.draw.stimHeight1^2);
	pseudoDiameter2 = sqrt(p.draw.stimWidth2^2 + p.draw.stimHeight2^2);
elseif p.trVars.stimShape == 3 % If both, stim1 is oval and stim2 is rect
	pseudoDiameter1 = max (p.draw.stimWidth1, p.draw.stimHeight1);
	pseudoDiameter2 = sqrt(p.draw.stimWidth2^2 + p.draw.stimHeight2^2);
end

% Define relative positions of stim1 and stim2 centers in texture window 
% based on pseudeoDiameter, twoStimSepPix, and twoStimRotation
center1_unrotated = -(pseudoDiameter1 + p.draw.twoStimSepPix)/2;
center2_unrotated = (pseudoDiameter2 + p.draw.twoStimSepPix)/2;

rotationMatrix = [cos(p.trVars.twoStimRotation), -sin(p.trVars.twoStimRotation);
		  sin(p.trVars.twoStimRotation), cos(p.trVars.twoStimRotation)];
		  
% Calculate center positions (X, Y) of stim1 and stim2
center1 = rotationMatrix * [center1_unrotated; 0];
center2 = rotationMatrix * [center2_unrotated; 0];

% Redefines center1 and center2 in terms of the texture window
% (previously defined based on [0, 0] being at center of texture window,
% now defined based on [0, 0] being top left corner)
center1 = center1 + textureWindowCenter;
center2 = center2 + textureWindowCenter;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create shapes within the texture window %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if p.trVars.stimShape == 1 % Both oval %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Stim 1 %
%%%%%%%%%%

% Create coordinate grids
[x1, y1] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Translate coordinates to be centered on the appropriate location in the texture 360window
x1_shifted = x1 - center1(1);
y1_shifted = y1 - center1(2);

% Rotate coordinates
x1_rotated = x1_shifted*cos(p.trVars.stimRotation1) + y1_shifted*sin(p.trVars.stimRotation1);
y1_rotated = -x1_shifted*sin(p.trVars.stimRotation1) + y1_shifted*cos(p.trVars.stimRotation1);

% Apply ellipse equation
stim1_mask = (x1_rotated.^2 / (p.draw.stimWidth1/2)^2) + (y1_rotated.^2 / (p.draw.stimHeight1/2)^2) <= 1;



% Stim 2 %
%%%%%%%%%%

% Create coordinate grids
[x2, y2] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Translate coordinates to be centered on the appropriate location in the texture window
x2_shifted = x2 - center2(1);
y2_shifted = y2 - center2(2);

% Rotate coordinates
x2_rotated = x2_shifted*cos(p.trVars.stimRotation2) + y2_shifted*sin(p.trVars.stimRotation2);
y2_rotated = -x2_shifted*sin(p.trVars.stimRotation2) + y2_shifted*cos(p.trVars.stimRotation2);

% Apply ellipse equation
stim2_mask = (x2_rotated.^2 / (p.draw.stimWidth2/2)^2) + (y2_rotated.^2 / (p.draw.stimHeight2/2)^2) <= 1;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
elseif p.trVars.stimShape == 2 % Both rect % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Stim 1 %
%%%%%%%%%%

% Define positions of rectangle corners (before rotation)
cornersUnrotated = [-p.draw.stimWidth1/2, -p.draw.stimHeight1/2;
		   p.draw.stimWidth1/2, -p.draw.stimHeight1/2;
		   p.draw.stimWidth1/2, p.draw.stimHeight1/2;
		   -p.draw.stimWidth1/2, p.draw.stimHeight1/2];

% Rotation matrix
R = [cos(p.trVars.stimRotation1), -sin(p.trVars.stimRotation1);
     sin(p.trVars.stimRotation1), cos(p.trVars.stimRotation1)];

% Rotate
cornersRotated = (R*cornersUnrotated')';

% Translate and separate into X's and Y's to be passed into poly2mask0.1
cornersX = cornersRotated(:, 1) + center1(1);
cornersY = cornersRotated(:, 2) + center1(2);

stim1_mask = poly2mask(cornersX, cornersY, p.draw.textureWindowDimensions, p.draw.textureWindowDimensions);


% Stim 2 %
%%%%%%%%%%

% Define positions of rectangle corners (before rotation)
cornerPositions = [-p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, p.draw.stimHeight2/2;
		   -p.draw.stimWidth2/2, p.draw.stimHeight2/2];

% Rotation matrix
R = [cos(p.trVars.stimRotation2), -sin(p.trVars.stimRotation2);
     sin(p.trVars.stimRotation2), cos(p.trVars.stimRotation2)];

% Rotate
cornersRotated = (R*cornerPositions')';

% Translate and separate into X's and Y's to be passed into poly2mask
cornersX = cornersRotated(:, 1) + center2(1);
cornersY = cornersRotated(:, 2) + center2(2);

stim2_mask = poly2mask(cornersX, cornersY, p.draw.textureWindowDimensions, p.draw.textureWindowDimensions);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
elseif p.trVars.stimShape == 3 % stim1 is oval, stim2 is rect %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Stim 1 %
%%%%%%%%%%

% From James
%{

% do we want our texture window to be an odd number of pixels or an even
% number of pixels?150
evenPixFlag = round(p.draw.textureWindowDimensions/2) == ...
    (p.draw.textureWindowDimensions/2);

% depending on the state of 'evenPixFlag', define our pixel coordinates:
if evenPixFlag
    pixVector = -(p.draw.textureWindowDimensions/2 - ...
        0.5):(p.draw.textureWindowDimensions/2 - 0.5);
else
    pixVector = -(p.draw.textureWindowDimensions - ...
        1)/2:(p.draw.textureWindowDimensions - 1)/2;
end

% Create coordinate grids
[x, y] = meshgrid (pixVector, pixVector);

%}

% Create coordinate grids
[x1, y1] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Translate coordinates to be centered on the appropriate location in the texture window
x1_shifted = x1 - center1(1);
y1_shifted = y1 - center1(2);

% Rotate coordinates
x1_rotated = x1_shifted*cos(p.trVars.stimRotation1) + y1_shifted*sin(p.trVars.stimRotation1);
y1_rotated = -x1_shifted*sin(p.trVars.stimRotation1) + y1_shifted*cos(p.trVars.stimRotation1);

% Apply ellipse equation
stim1_mask = (x1_rotated.^2 / (p.draw.stimWidth1/2)^2) + (y1_rotated.^2 / (p.draw.stimHeight1/2)^2) <= 1;


% Stim 2 %
%%%%%%%%%%

% Define positions of rectangle corners (before rotation)
cornerPositions = [-p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, p.draw.stimHeight2/2;
		   -p.draw.stimWidth2/2, p.draw.stimHeight2/2];

% Rotation matrix
R = [cos(p.trVars.stimRotation2), -sin(p.trVars.stimRotation2);
     sin(p.trVars.stimRotation2), cos(p.trVars.stimRotation2)];

% Rotate
cornersRotated = (R*cornerPositions')';

% Translate and separate into X's and Y's to be passed into poly2mask
cornersX = cornersRotated(:, 1) + center2(1);
cornersY = cornersRotated(:, 2) + center2(2);

stim2_mask = poly2mask(cornersX, cornersY, p.draw.textureWindowDimensions, p.draw.textureWindowDimensions);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Apply gradient and color to the stims %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if rand > 0.5 % in 50% of cases, apply gradient to stim1

% Decide on gaussian parameters dependent on size of stim (can adjust these if it doesn't look right)
kernelSize = 0.15*(p.draw.stimWidth1 + p.draw.stimHeight1);
sigma = 5;

% Round kernelSize to nearest odd number, as this value must be odd
kernelSize = 2*floor(kernelSize/2)+1;

gaussianKernel = fspecial('gaussian', kernelSize, sigma);

stim1_mask_conv = conv2(stim1_mask, gaussianKernel, 'same');

% set anything that is imperceptable to 0 to avoid issues with "invisible overlap"
stim1_mask_conv (stim1_mask_conv < 0.1) = 0;

else

stim1_mask_conv = stim1_mask;

end


if rand > 0.5 % in 50% of cases, apply gradient to stim2

% Decide on gaussian parameters dependent on size of stim (can adjust these if it doesn't look right)
kernelSize = 0.15*(p.draw.stimWidth2 + p.draw.stimHeight2);
sigma = 5;

% Round kernelSize to nearest odd number, as this value must be odd
kernelSize = 2*floor(kernelSize/2)+1;

gaussianKernel = fspecial('gaussian', kernelSize, sigma);

stim2_mask_conv = conv2(stim2_mask, gaussianKernel, 'same');

% set anything that is imperceptable to 0 to avoid issues with "invisible overlap"
stim2_mask_conv (stim2_mask_conv < 0.1) = 0;

else

stim2_mask_conv = stim2_mask;

end

% Apply color by setting values to the appropriate indices
stim1_color = round (stim1_mask_conv*99 + 50); % 51-150 in CLUT are the color gradient for stim 1
stim2_color = round (stim2_mask_conv*99 + 150); % 151-250 in CLUT are the color gradient for stim 2

% Anything out of bounds for the color gradient gets set to either grey or
% fully saturated color, as appropriate
stim1_color(stim1_color <= 50) = 50;
stim1_color(stim1_color >= 149) = 149;

stim2_color (stim2_color <= 150) = 150;
stim2_color (stim2_color >= 249) = 249;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Combine stims into one texture %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% If we are only presenting one stim, erase second stim
if p.trVars.numDots == 1
	stim2_color (:) = 0;
end

% Set anything that is currently at background grey to 0 so we
% don't add 50 or 150 to values inappropriately
stim1_color (stim1_color == 50) = 0;
stim2_color (stim2_color == 150) = 0;


%{
try
combinedStims = stim1_color + stim2_color;
catch me
    keyboard
end
%}

% Add stim1 and stim2 to make full texture
combinedStims = stim1_color + stim2_color;

% Reapply grey background to texture
combinedStims (combinedStims == 0) = 50;

% Test %%%%%%%%%%%%%%%%%%%
%{
stim1_mask_preconv
stim2_mask_preconv
stim1_mask
stim2_mask
stim1_color
stim2_color
combinedStims

stim1_color_fig = stim1_color / max(max(stim1_color));
stim2_color_fig = stim2_color / max(max(stim2_color));
combinedStims_fig = combinedStims / max(max(combinedStims));

figure;

subplot (2, 3, 1);
imshow(stim1_mask_preconv);
title('stim1_mask');

subplot (2, 3, 2);
imshow(stim2_mask_preconv);
title('stim2_mask');

subplot (2, 3, 3);
imshow(stim1_color_fig);
title('stim1_color');

subplot (2, 3, 4);
imshow(stim2_color_fig);
title('stim2_color');

subplot (2, 3, 5);
imshow(combinedStims_fig);
title('combinedStims');

%w = waitforbuttonpress;
%}

% Make Texture
p.draw.stimTexture = Screen('MakeTexture', p.draw.window, combinedStims);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% End Texture Stuff %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%}







%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Texture stuff%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define texture window and create shapes in center %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Texture window should be large enough to accomadate two max-size stim with max size separation/rotation,
% plus some extra empty space to allow blurring with convolution. Forced to be even as odd values
% caused weird issues
p.draw.textureWindowDimensions = 2*round(pds.deg2pix (p.trVars.twoStimSepDegMax + p.trVars.stimSizeMax*sqrt(2)*2.5, p)/2);

% define center of texture window to shift things into appropriate frame
textureWindowCenter = [p.draw.textureWindowDimensions/2; p.draw.textureWindowDimensions/2];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if p.trVars.stimShape == 1 % Both oval %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Stim 1 %
%%%%%%%%%%

% Create coordinate grids
[x1, y1] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Shift coordinates to center the ellipse
x1_shifted = x1 - textureWindowCenter(1);
y1_shifted = y1 - textureWindowCenter(2);

% Rotate coordinates
x1_rotated = x1_shifted*cos(p.trVars.stimRotation1) + y1_shifted*sin(p.trVars.stimRotation1);
y1_rotated = -x1_shifted*sin(p.trVars.stimRotation1) + y1_shifted*cos(p.trVars.stimRotation1);

% Apply ellipse equation
stim1_mask = (x1_rotated.^2 / (p.draw.stimWidth1/2)^2) + (y1_rotated.^2 / (p.draw.stimHeight1/2)^2) <= 1;



% Stim 2 %
%%%%%%%%%%

% Create coordinate grids
[x2, y2] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Shift coordinates to center the ellipse
x2_shifted = x2 - textureWindowCenter(1);
y2_shifted = y2 - textureWindowCenter(2);

% Rotate coordinates
x2_rotated = x2_shifted*cos(p.trVars.stimRotation2) + y2_shifted*sin(p.trVars.stimRotation2);
y2_rotated = -x2_shifted*sin(p.trVars.stimRotation2) + y2_shifted*cos(p.trVars.stimRotation2);

% Apply ellipse equation
stim2_mask = (x2_rotated.^2 / (p.draw.stimWidth2/2)^2) + (y2_rotated.^2 / (p.draw.stimHeight2/2)^2) <= 1;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
elseif p.trVars.stimShape == 2 % Both rect % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Stim 1 %
%%%%%%%%%%

% Define positions of rectangle corners (before rotation)
cornersUnrotated = [-p.draw.stimWidth1/2, -p.draw.stimHeight1/2;
		   p.draw.stimWidth1/2, -p.draw.stimHeight1/2;
		   p.draw.stimWidth1/2, p.draw.stimHeight1/2;
		   -p.draw.stimWidth1/2, p.draw.stimHeight1/2];

% Rotation matrix
R = [cos(p.trVars.stimRotation1), -sin(p.trVars.stimRotation1);
     sin(p.trVars.stimRotation1), cos(p.trVars.stimRotation1)];

% Rotate
cornersRotated = (R*cornersUnrotated')';

% Separate into X's and Y's to be passed into poly2mask, and shift to center
cornersX = cornersRotated(:, 1) + textureWindowCenter(1);
cornersY = cornersRotated(:, 2) + textureWindowCenter(2);

stim1_mask = poly2mask(cornersX, cornersY, p.draw.textureWindowDimensions, p.draw.textureWindowDimensions);


% Stim 2 %
%%%%%%%%%%

% Define positions of rectangle corners (before rotation)
cornerPositions = [-p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, p.draw.stimHeight2/2;
		   -p.draw.stimWidth2/2, p.draw.stimHeight2/2];

% Rotation matrix
R = [cos(p.trVars.stimRotation2), -sin(p.trVars.stimRotation2);
     sin(p.trVars.stimRotation2), cos(p.trVars.stimRotation2)];

% Rotate
cornersRotated = (R*cornerPositions')';

% Separate into X's and Y's to be passed into poly2mask, and shift to center
cornersX = cornersRotated(:, 1) + textureWindowCenter(1);
cornersY = cornersRotated(:, 2) + textureWindowCenter(2);

stim2_mask = poly2mask(cornersX, cornersY, p.draw.textureWindowDimensions, p.draw.textureWindowDimensions);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
elseif p.trVars.stimShape == 3 % one oval, one rect %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if rand > 0.5 % Randomly choose whether oval is first or rect is first (note: only really matters for temporal)

% Stim 1 %
%%%%%%%%%%

% Create coordinate grids
[x1, y1] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Shift coordinates to center the ellipse
x1_shifted = x1 - textureWindowCenter(1);
y1_shifted = y1 - textureWindowCenter(2);

% Rotate coordinates
x1_rotated = x1_shifted*cos(p.trVars.stimRotation1) + y1_shifted*sin(p.trVars.stimRotation1);
y1_rotated = -x1_shifted*sin(p.trVars.stimRotation1) + y1_shifted*cos(p.trVars.stimRotation1);

% Apply ellipse equation
stim1_mask = (x1_rotated.^2 / (p.draw.stimWidth1/2)^2) + (y1_rotated.^2 / (p.draw.stimHeight1/2)^2) <= 1;


% Stim 2 %
%%%%%%%%%%

% Define positions of rectangle corners (before rotation)
cornerPositions = [-p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, -p.draw.stimHeight2/2;
		   p.draw.stimWidth2/2, p.draw.stimHeight2/2;
		   -p.draw.stimWidth2/2, p.draw.stimHeight2/2];

% Rotation matrix
R = [cos(p.trVars.stimRotation2), -sin(p.trVars.stimRotation2);
     sin(p.trVars.stimRotation2), cos(p.trVars.stimRotation2)];

% Rotate
cornersRotated = (R*cornerPositions')';

% Separate into X's and Y's to be passed into poly2mask, and shift to center
cornersX = cornersRotated(:, 1) + textureWindowCenter(1);
cornersY = cornersRotated(:, 2) + textureWindowCenter(2);

stim2_mask = poly2mask(cornersX, cornersY, p.draw.textureWindowDimensions, p.draw.textureWindowDimensions);

else

% Stim 1 %
%%%%%%%%%%

% Define positions of rectangle corners (before rotation)
cornersUnrotated = [-p.draw.stimWidth1/2, -p.draw.stimHeight1/2;
		   p.draw.stimWidth1/2, -p.draw.stimHeight1/2;
		   p.draw.stimWidth1/2, p.draw.stimHeight1/2;
		   -p.draw.stimWidth1/2, p.draw.stimHeight1/2];

% Rotation matrix
R = [cos(p.trVars.stimRotation1), -sin(p.trVars.stimRotation1);
     sin(p.trVars.stimRotation1), cos(p.trVars.stimRotation1)];

% Rotate
cornersRotated = (R*cornersUnrotated')';

% Separate into X's and Y's to be passed into poly2mask, and shift to center
cornersX = cornersRotated(:, 1) + textureWindowCenter(1);
cornersY = cornersRotated(:, 2) + textureWindowCenter(2);

stim1_mask = poly2mask(cornersX, cornersY, p.draw.textureWindowDimensions, p.draw.textureWindowDimensions);


% Stim 2 %
%%%%%%%%%%

% Create coordinate grids
[x2, y2] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Shift coordinates to center the ellipse
x2_shifted = x2 - textureWindowCenter(1);
y2_shifted = y2 - textureWindowCenter(2);

% Rotate coordinates
x2_rotated = x2_shifted*cos(p.trVars.stimRotation2) + y2_shifted*sin(p.trVars.stimRotation2);
y2_rotated = -x2_shifted*sin(p.trVars.stimRotation2) + y2_shifted*cos(p.trVars.stimRotation2);

% Apply ellipse equation
stim2_mask = (x2_rotated.^2 / (p.draw.stimWidth2/2)^2) + (y2_rotated.^2 / (p.draw.stimHeight2/2)^2) <= 1;

end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Apply blur effect to the stims %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if rand > 0.5 % in 50% of cases, apply gradient to stim1

% Decide on gaussian parameters dependent on size of stim (can adjust these if it doesn't look right)
kernelSize = 0.15*(p.draw.stimWidth1 + p.draw.stimHeight1);
sigma = 5;

% Round kernelSize to nearest odd number, as this value must be odd
kernelSize = 2*floor(kernelSize/2)+1;

gaussianKernel = fspecial('gaussian', kernelSize, sigma);

stim1_mask_conv = conv2(stim1_mask, gaussianKernel, 'same');

% set anything that is imperceptable to 0 to get a better boundary for the edge of the shape
stim1_mask_conv (stim1_mask_conv < 0.1) = 0;

else

stim1_mask_conv = stim1_mask;

end


if rand > 0.5 % in 50% of cases, apply gradient to stim2

% Decide on gaussian parameters dependent on size of stim (can adjust these if it doesn't look right)
kernelSize = 0.15*(p.draw.stimWidth2 + p.draw.stimHeight2);
sigma = 5;

% Round kernelSize to nearest odd number, as this value must be odd
kernelSize = 2*floor(kernelSize/2)+1;

gaussianKernel = fspecial('gaussian', kernelSize, sigma);

stim2_mask_conv = conv2(stim2_mask, gaussianKernel, 'same');

% set anything that is imperceptable to get a better boundary for the edge of the shape
stim2_mask_conv (stim2_mask_conv < 0.1) = 0;

else

stim2_mask_conv = stim2_mask;

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Translate stim to appropriate locations %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Using a "step and check" method where we shift the stims away from each other in steps until
% they no longer overlap, then additionally add the edge-to-edge separation

% Rotation vector for relative position from center
% (stim1 will move in positive direction, stim2 in negative direction)
R = [cos(p.trVars.twoStimRotation), -sin(p.trVars.twoStimRotation);
     sin(p.trVars.twoStimRotation), cos(p.trVars.twoStimRotation)];
    
% Define the unit vector for direction of translation 
translation_unit_vector = R*[1; 0];

% Initialize the scalar value we will multiply the unit vector by
translation_scalar = 0;

% Initialize whether the two stim overlap or not
stimsOverlap = true;

% Initial positions for test versions of the stimuli where anything >0 is now =1,
% so we know where the edge of the gradient is.
test_stim1_initial = zeros (size(stim1_mask_conv));
test_stim1_initial (stim1_mask_conv > 0) = 1;

test_stim2_initial = zeros (size(stim2_mask_conv));
test_stim2_initial (stim2_mask_conv > 0) = 1;


% Loop that shifts the stim stepwise in the direction (or opposite direction) of the unit vector,
% until the two stim no longer overlap, leaving them with their closest edges next to each other
while stimsOverlap

% Step the scalar value by 1 pixel
	translation_scalar = translation_scalar + 1;

% Create "test versions" of the stims that are shifted by some amount determined by the scalar/unit vector
	test_stim1 = imtranslate (test_stim1_initial, round(translation_scalar*translation_unit_vector));
	test_stim2 = imtranslate (test_stim2_initial, round(-translation_scalar*translation_unit_vector));

% Add these test versions together
	test_combined = test_stim1 + test_stim2;
	
% If the combined test has any values = 2, that means they overlapped at those points
% If there are no such values, they are no longer overlapping and we have out translation_scalar value
	if ~(any(test_combined == 2))
		stimsOverlap = false;
	end

end

% Add twoStimSepPix/2 value to translation_scalar value to find the center-to-center translation
final_translation_scalar = translation_scalar + p.draw.twoStimSepPix/2;

% Translate the stims by the appropriate amount, in opposite directions
stim1_mask_translated = imtranslate (stim1_mask_conv, round(final_translation_scalar*translation_unit_vector));
stim2_mask_translated = imtranslate (stim2_mask_conv, round(-final_translation_scalar*translation_unit_vector));


%%%%%%%%%%%%%%%%%%%%%%%%%%
% Add color to the stims %
%%%%%%%%%%%%%%%%%%%%%%%%%%

p.trVars.stimColor1 = rand (1, 3);
p.trVars.stimColor2 = rand (1, 3);

% On 2% of trials, make stim color white instead
if rand > 0.98
    p.trVars.stimColor1 = [1, 1, 1];
end

if rand > 0.98
    p.trVars.stimColor2 = [1, 1, 1];
end

% Check if either color is too close to background grey (i.e. all 3 RGB values are between 0.4 and 0.5)
isGrey = 1;
while isGrey
    isGrey = 0;
    if ((p.trVars.stimColor1 (1) > 0.4 & p.trVars.stimColor1 (1) < 0.5) & ...
	(p.trVars.stimColor1 (2) > 0.4 & p.trVars.stimColor1 (1) < 0.5) & ...
	(p.trVars.stimColor1 (3) > 0.4 & p.trVars.stimColor1 (1) < 0.5))
		p.trVars.stimColor1 = rand (1, 3);
		isGrey = 1;
    elseif ((p.trVars.stimColor2 (1) > 0.4 & p.trVars.stimColor2 (1) < 0.5) & ...
	(p.trVars.stimColor2 (2) > 0.4 & p.trVars.stimColor2 (1) < 0.5) & ...
	(p.trVars.stimColor2 (3) > 0.4 & p.trVars.stimColor2 (1) < 0.5))
		p.trVars.stimColor2 = rand (1, 3);
		isGrey = 1;
    end
end

% On 50% of trials, make color of second stim same as first
if rand > 0.5
    p.trVars.stimColor2 = p.trVars.stimColor1;
end

% Create color gradients between the stim color and background grey across 100 values.
% linspace is done over Lab colorspace instead of RGB as it produces a smoother gradient

labGrey = rgb2lab([0.45 0.45 0.45]);
labStimColor1 = rgb2lab(p.trVars.stimColor1);
labStimColor2 = rgb2lab(p.trVars.stimColor2);

for i = 1:3
	labClut1 (:, i) = linspace (labGrey(i), labStimColor1(i));
	labClut2 (:, i) = linspace (labGrey(i), labStimColor2(i));
end

stimClut1 = lab2rgb (labClut1);
stimClut2 = lab2rgb (labClut2);

stimClut1(stimClut1 > 1) = 1;
stimClut2(stimClut2 > 1) = 1;
stimClut1(stimClut1 < 0) = 0;
stimClut2(stimClut2 < 0) = 0;


% Alternatively, perform linspace over RGB space:
%{
stimClut1 = zeros (100, 3);
stimClut2 = zeros (100, 3);

for i = 1:3
	stimClut1 (:, i) = linspace (0.45, p.trVars.stimColor1(i));
	stimClut2 (:, i) = linspace (0.45, p.trVars.stimColor2(i));
end
%}


% Put the color gradients into the CLUTS to be pushed to ViewPIXX
p.draw.clut.expCLUT (51:150, :) = stimClut1;
p.draw.clut.subCLUT (51:150, :) = stimClut1;

p.draw.clut.expCLUT (151:250, :) = stimClut2;
p.draw.clut.subCLUT (151:250, :) = stimClut2;

% Push new CLUTs to ViewPIXX
Datapixx('SetVideoClut', [p.draw.clut.subCLUT; p.draw.clut.expCLUT]);

% Apply color by setting values to the appropriate indices
stim1_color = round (stim1_mask_translated*99 + 50); % 50-149 in CLUT are the color gradient for stim 1
stim2_color = round (stim2_mask_translated*99 + 150); % 150-249 in CLUT are the color gradient for stim 2

% Anything out of bounds for the color gradient gets set to either grey or
% fully saturated color, as appropriate (for weird edge cases or rounding errors)
stim1_color(stim1_color <= 50) = 50;
stim1_color(stim1_color >= 149) = 149;

stim2_color (stim2_color <= 150) = 150;
stim2_color (stim2_color >= 249) = 249;




%%%%%%%%%%%%%%%%%%%
% Create textures %
%%%%%%%%%%%%%%%%%%%


if p.trVars.numDots == 1 % If we are only presenting one stim, only use stim1 for everything
	%stim2_color (:) = 0;
    stim2_color = stim1_color;
    combinedStims = stim1_color;

    % Make textures of the individual stims and combined
    p.draw.stimOneTexture = Screen ('MakeTexture', p.draw.window, stim1_color);
    p.draw.stimTwoTexture = Screen ('MakeTexture', p.draw.window, stim2_color);
    p.draw.combinedStimTexture = Screen ('MakeTexture', p.draw.window, combinedStims);
else % If we are presenting both...

    % Make textures of the individual stims before they're adjusted for combining
    p.draw.stimOneTexture = Screen ('MakeTexture', p.draw.window, stim1_color);
    p.draw.stimTwoTexture = Screen ('MakeTexture', p.draw.window, stim2_color);

% If interStimInterval is greater than 0, 50% of the time make stimTwo the same as stimOne
	if p.trVars.temporalOverlap == 0 && p.trVars.interStimIntervalMin > 0 && rand > 0.5
   	    p.draw.stimTwoTexture = p.draw.stimOneTexture;
	end


    % Set anything that is currently at background grey to 0 so we
    % don't add 50 or 150 to values inappropriately
    stim1_color (stim1_color == 50) = 0;
    stim2_color (stim2_color == 150) = 0;

    % Add stim1 and stim2 to make combined texture
    combinedStims = stim1_color + stim2_color;

    % Reapply grey background to texture
    combinedStims (combinedStims == 0) = 50;

    % Make Textures of the stims combined
    p.draw.combinedStimTexture = Screen ('MakeTexture', p.draw.window, combinedStims);

end




%{
try
combinedStims = stim1_color + stim2_color;
catch me
    keyboard
end
%}



% Test %%%%%%%%%%%%%%%%%%%
%{
stim1_mask_preconv
stim2_mask_preconv
stim1_mask
stim2_mask
stim1_color
stim2_color
combinedStims

stim1_color_fig = stim1_color / max(max(stim1_color));
stim2_color_fig = stim2_color / max(max(stim2_color));
combinedStims_fig = combinedStims / max(max(combinedStims));

figure;

subplot (2, 3, 1);
imshow(stim1_mask_preconv);
title('stim1_mask');

subplot (2, 3, 2);
imshow(stim2_mask_preconv);
title('stim2_mask');

subplot (2, 3, 3);
imshow(stim1_color_fig);
title('stim1_color');

subplot (2, 3, 4);
imshow(stim2_color_fig);
title('stim2_color');

subplot (2, 3, 5);
imshow(combinedStims_fig);
title('combinedStims');

%w = waitforbuttonpress;
%}



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% End Texture Stuff %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end



%
function p = timingInfo(p)

% time of stim one onset and offset wrt fixAcq:
p.trVars.timeStimOneOnset		= unifrnd (p.trVars.stimOnsetMin, p.trVars.stimOnsetMax);
p.trVars.stimOneDur             = unifrnd (p.trVars.stimDurMin, p.trVars.stimDurMax);
p.trVars.timeStimOneOffset		= p.trVars.timeStimOneOnset + p.trVars.stimOneDur;

% If we're doing full version of temporal task, add interstim interval
% if we're doing spatial task, stim1 and stim2 happen at the same time
% If we're in transition, use temporal overlap to determine stim2 timing
if p.trVars.temporalOverlap == 0    
    if p.trVars.numDots == 1
        % If presenting 1 stimulus, total duration should be between total
        % duration of the two stimuli and that plus inter-stim-interval
        p.trVars.interStimInterval  = unifrnd (0, p.trVars.interStimIntervalMax);
        p.trVars.timeStimOneOffset  = p.trVars.timeStimOneOffset + p.trVars.interStimInterval;
        p.trVars.timeStimTwoOnset   = p.trVars.timeStimOneOffset;
        p.trVars.stimTwoDur         = unifrnd (p.trVars.stimDurMin, p.trVars.stimDurMax);
        p.trVars.timeStimTwoOffset  = p.trVars.timeStimTwoOnset + p.trVars.stimTwoDur;
    else
        p.trVars.interStimInterval  = unifrnd (p.trVars.interStimIntervalMin, p.trVars.interStimIntervalMax);
        p.trVars.timeStimTwoOnset   = p.trVars.timeStimOneOffset + p.trVars.interStimInterval;
        p.trVars.stimTwoDur         = unifrnd (p.trVars.stimDurMin, p.trVars.stimDurMax);
        p.trVars.timeStimTwoOffset  = p.trVars.timeStimTwoOnset + p.trVars.stimTwoDur;
    end

elseif p.trVars.temporalOverlap > 0 && p.trVars.temporalOverlap < 1
    p.trVars.timeStimTwoOnset   = p.trVars.timeStimOneOnset + ...
                                  (p.trVars.stimOneDur*(1-p.trVars.temporalOverlap));
    p.trVars.stimTwoDur         = unifrnd (p.trVars.stimDurMin, p.trVars.stimDurMax);
    p.trVars.timeStimTwoOffset  = p.trVars.timeStimTwoOnset + p.trVars.stimTwoDur;

elseif p.trVars.temporalOverlap >= 1
    p.trVars.timeStimTwoOnset  = p.trVars.timeStimOneOnset;
    p.trVars.stimTwoDur        = p.trVars.stimOneDur;
    p.trVars.timeStimTwoOffset = p.trVars.timeStimOneOffset;
end

% time of target onset wrt fixAcq:
p.trVars.timeTargOnset          = p.trVars.timeStimTwoOffset + unifrnd(p.trVars.targOnsetMin, p.trVars.targOnsetMax);

% time of target offset wrt fixAcq:
if p.trVars.isVisSac
    % infinity for vis"
    p.trVars.timeTargOffset     = Inf;
else
    % flash for mem:
    p.trVars.timeTargOffset     = p.trVars.timeTargOnset + p.trVars.targetFlashDuration;
end

% time of fix offset wrt fix acquired:
p.trVars.timeFixOffset          = p.trVars.timeTargOnset + unifrnd(p.trVars.goTimePostTargMin, p.trVars.goTimePostTargMax);

%         p.trVars.postFlashFixDur       = unifrnd(p.trVars.postFlashFixMin, p.trVars.postFlashFixMax);
p.trVars.targHoldDuration         = unifrnd(p.trVars.targHoldDurationMin, p.trVars.targHoldDurationMax);


end

function p = chooseRow(p)

% if p.status.trialsArrayRowsPossible is empty, we're at the beginning of
% the experiment and we need to define it.
if ~isfield(p.status, 'trialsArrayRowsPossible') || ...
        isempty(p.status.trialsArrayRowsPossible)
    p.status.trialsArrayRowsPossible =  true(p.init.blockLength, 1);
end

% otherwise, choose an available row with no constraints: all stimulus
% locations are intermixed.
g = p.status.trialsArrayRowsPossible;

% shuffle the list of possible rows of trialsArray
tempList = shuff(find(g));

% choose the first row number in the shuffled list.
p.trVars.currentTrialsArrayRow = tempList(1);

end

%
function y = shuff(x)
    y = x(randperm(length(x)));
end
