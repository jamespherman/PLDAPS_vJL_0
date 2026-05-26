function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.

% if we're using p.init.trialsArray to determine target locations, do the
% book keeping for that here:
if p.trVars.setTargLocViaTrialArray
    p = chooseRow(p);
end

% Check if Ripple recording is on, and send error or warning if not
xippmexStatus = pds.xippmex('trial');
if strcmp(xippmexStatus.status, 'stopped') && p.trVars.stopIfNotRecording == true
    error('Ripple recording is not active. Please start recording before proceeding.');
end


trialTypeCol = strcmp(p.init.trialArrayColumnNames, 'trialType');
p.trVars.trialType = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   trialTypeCol);

if p.trVars.trialType == 1 % Visual stimulus
    p = createVisualStimulusTexture(p);
elseif p.trVars.trialType == 2 % Electrode microstimulation
    p = createMicrostimTrain(p);
end

end


function p = createVisualStimulusTexture(p)


% Retrieve info from trial structure
numStimCol = strcmp(p.init.trialArrayColumnNames, 'numStim');
p.trVars.numStim = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   numStimCol);

stimDurCol = strcmp(p.init.trialArrayColumnNames, 'stimDur');
p.trVars.stimDur = (p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   stimDurCol))/1000;

interStimIntervalCol = strcmp(p.init.trialArrayColumnNames, 'interStimInterval');
p.trVars.interStimInterval = (p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   interStimIntervalCol))/1000;


% Locations of fixation and targets and stimuli

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

% fixation window width and height in pixels.
p.draw.fixWinWidthPix       = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix      = pds.deg2pix(p.trVars.fixWinHeightDeg, p);

% Define target location for next trial. First define which column of the
% trials array contains the "visNumStim" information, then choose a target
% location.


p.draw.targOnePointPix     =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targOneDegX, p.trVars.targOneDegY], p);
p.draw.targTwoPointPix     =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targTwoDegX, p.trVars.targTwoDegY], p);

% target window width and height in pixels.
p.draw.targWinWidthPix      = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix     = pds.deg2pix(p.trVars.targWinHeightDeg, p);

p.draw.color.targWin = p.draw.clutIdx.expVisGreen_subBg;

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


% randomly choose x and y coordinates within given ranges (stimRangeX and stimRangeY)
p.trVars.stimDegX = unifrnd(p.trVars.stimRangeXmin, p.trVars.stimRangeXmax);
p.trVars.stimDegY = unifrnd(p.trVars.stimRangeYmin, p.trVars.stimRangeYmax);

p.draw.stimPointPix	=  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.stimDegX, p.trVars.stimDegY], p);


% Convert stim X & Y into radius and theta so that we can strobe:
% (can't strobe negative values, so r/th solves that)

[tmpTheta, tmpRadius]   = cart2pol(p.trVars.stimDegX, p.trVars.stimDegY);

% In order to strobe I need round positive numbers. 
% For theta, I multiply by 10 ('_x10') and round. That gives 1 decimlal 
% point precision, good enough!
p.trVars.stimTheta_x10  = round(mod(tmpTheta * 180 / pi, 360) * 10); 

% For radius, I multiply by 100 ('_x100') and round. That gives 2 decimlal
% point precision, goo enough!
p.trVars.stimRadius_x100 = round(tmpRadius * 100);


% Set stim properties 
%%%%%%%%%%%%%%%%%%%%%
  

p.trVars.stimShape = randsample (["rect", "oval", "both"], 1);

% randomly choose size of stimulus between min and max
p.draw.stimWidth1 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);
p.draw.stimHeight1 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);

% Second set chosen for two-stim trials
p.draw.stimWidth2 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);
p.draw.stimHeight2 = pds.deg2pix (unifrnd(p.trVars.stimSizeMin, p.trVars.stimSizeMax), p);

% If presenting 1 stimulus, increase width and height by up to sqrt(2) so that the max area = total area of two dots
if p.trVars.numStim == 1
	p.draw.stimWidth1 = p.draw.stimWidth1*(unifrnd(1, sqrt(2)));
	p.draw.stimHeight1 = p.draw.stimHeight1*(unifrnd(1, sqrt(2)));
end

% randomly rotate the individual stims by some amount
p.trVars.stimRotation1 = deg2rad(unifrnd(-p.trVars.oneStimRotationRange/2, p.trVars.oneStimRotationRange/2));
p.trVars.stimRotation2 = deg2rad(unifrnd(-p.trVars.oneStimRotationRange/2, p.trVars.oneStimRotationRange/2));

% For two-stim trials, how separated should they be (edge to edge)?
p.trVars.twoStimSepDeg = unifrnd(p.trVars.twoStimSepDegMin, p.trVars.twoStimSepDegMax);
p.draw.twoStimSepPix = pds.deg2pix(p.trVars.twoStimSepDeg, p);

% Now randomly rotate the stimuli relative to each other by between 0 and twoStimRotationRange degrees
p.trVars.twoStimRotation = deg2rad(unifrnd(-p.trVars.twoStimRotationRange/2, p.trVars.twoStimRotationRange/2));


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
if p.trVars.stimShape == "oval" % Both oval %
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
elseif p.trVars.stimShape == "rect" % Both rect % 
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
elseif p.trVars.stimShape == "both" % one oval, one rect %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if rand > 0.5 % Randomly choose whether oval is first or rect is first (note: only really matters for temporal)

% Stim 1 %
%%%%%%%%%%

% Create coordinate grids
[x1, y1] = meshgrid (1:p.draw.textureWindowDimensions, 1:p.draw.textureWindowDimensions);

% Shift coordinates to center the ellipsep.init.trialsArray(p.trVars.currentTrialsArrayRow, ...

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

p.trData.stim1Fuzzy = 1;

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

p.trData.stim1Fuzzy = 0;

stim1_mask_conv = stim1_mask;

end


if rand > 0.5 % in 50% of cases, apply gradient to stim2

p.trData.stim2Fuzzy = 1;

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

p.trData.stim2Fuzzy = 0;

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
p.trVars.translation_unit_vector = R*[1; 0];

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
	test_stim1 = imtranslate (test_stim1_initial, round(translation_scalar*p.trVars.translation_unit_vector));
	test_stim2 = imtranslate (test_stim2_initial, round(-translation_scalar*p.trVars.translation_unit_vector));

% Add these test versions together
	test_combined = test_stim1 + test_stim2;
	
% If the combined test has any values = 2, that means they overlapped at those points
% If there are no such values, they are no longer overlapping and we have out translation_scalar value
	if ~(any(test_combined == 2))
		stimsOverlap = false;
	end

end

% Add twoStimSepPix/2 value to translation_scalar value to find the center-to-center translation
p.trVars.final_translation_scalar = translation_scalar + p.draw.twoStimSepPix/2;

% Translate the stims by the appropriate amount, in opposite directions
stim1_mask_translated = imtranslate (stim1_mask_conv, round(p.trVars.final_translation_scalar*p.trVars.translation_unit_vector));
stim2_mask_translated = imtranslate (stim2_mask_conv, round(-p.trVars.final_translation_scalar*p.trVars.translation_unit_vector));

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

% Save a copy of the final matrices used to make the texture
p.trVars.stimOneTextureMatrix = stim1_color;
p.trVars.stimTwoTextureMatrix = stim2_color;

% Make textures of the individual stims before they're adjusted for combining
p.draw.stimOneTexture = Screen ('MakeTexture', p.draw.window, p.trVars.stimOneTextureMatrix);
p.draw.stimTwoTexture = Screen ('MakeTexture', p.draw.window, p.trVars.stimTwoTextureMatrix);

% for temporal, if interStimInterval is greater than 0, 50% of the time make stimTwo the same as stimOne
if strcmp(p.init.exptType, 'temporal') && p.trVars.interStimInterval > 0 && rand > 0.5
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

% Save a copy of this as well
p.trVars.combinedStimTextureMatrix = combinedStims;

% Make Textures of the stims combined
p.draw.combinedStimTexture = Screen ('MakeTexture', p.draw.window, p.trVars.combinedStimTextureMatrix);


% Timing stuff

% determine total stim duration based on spatial vs temporal and 1 vs 2
if strcmp(p.init.exptType, 'temporal') && p.trVars.numStim == 2
    totalStimDur = p.trVars.stimDur*2 + p.trVars.interStimInterval;
else
    totalStimDur = p.trVars.stimDur;
end

% Check if total fix duration is too small for input parameters
if p.trVars.totalFixDur <= (totalStimDur + ...
                           p.trVars.stimOnsetMin + ...
                           p.trVars.targOnsetMin + ...
                           p.trVars.goTimePostTarg)
    error ('Total fix duration is lower than minimum values for this visual trial');
end

% Randomly allocate "extra" time to either pre-stim or post-stim
remainingTime = p.trVars.totalFixDur - (totalStimDur + ...
                                     	p.trVars.stimOnsetMin + ...
                                     	p.trVars.targOnsetMin + ...
                                     	p.trVars.goTimePostTarg);
randTimeLeft = unifrnd (0, remainingTime);

p.trVars.timeStimOneOnset   = p.trVars.stimOnsetMin + randTimeLeft;
p.trVars.timeStimOneOffset  = p.trVars.timeStimOneOnset + p.trVars.stimDur;



switch p.init.exptType

    case 'spatial'
        % if spatial task, one stim
        if p.trVars.numStim == 1
            
            % stim two does not occur
            p.trVars.timeStimTwoOnset = Inf;
            p.trVars.timeStimTwoOffset = Inf;
        
            p.trVars.timeTargOnset = p.trVars.timeStimOneOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        % if spatial task, two stim
        elseif p.trVars.numStim == 2

            % stim two happens at same time as stim one
            p.trVars.timeStimTwoOnset = p.trVars.timeStimOneOnset;
            p.trVars.timeStimTwoOffset = p.trVars.timeStimOneOffset;
        
            p.trVars.timeTargOnset = p.trVars.timeStimTwoOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        end


    case 'temporal'

        % if temporal task, one stim
        if p.trVars.numStim == 1

            % stim two does not occur
            p.trVars.timeStimTwoOnset = Inf;
            p.trVars.timeStimTwoOffset = Inf;
        
            p.trVars.timeTargOnset = p.trVars.timeStimOneOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        % if temporal task, two stim
        elseif p.trVars.numStim == 2

            % stim two occurs after interstim interval
            p.trVars.timeStimTwoOnset = p.trVars.timeStimOneOnset + p.trVars.interStimInterval;
            p.trVars.timeStimTwoOffset = p.trVars.timeStimTwoOnset + p.trVars.stimDur;
        
            p.trVars.timeTargOnset = p.trVars.timeStimTwoOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        end

end

p.trVars.timeTargOffset     = Inf;

end



function p = createMicrostimTrain(p)


% Retrieve info from trial structure, rename certain parameters as needed 
% to be more straightforward
numStimCol = strcmp(p.init.trialArrayColumnNames, 'numStim');
p.trVars.numStim = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   numStimCol);

stimNumPulsesCol = strcmp(p.init.trialArrayColumnNames, 'stimDur');
p.trVars.stimNumPulses = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   stimNumPulsesCol);

interTrainIntervalCol = strcmp(p.init.trialArrayColumnNames, 'interStimInterval');
p.trVars.interTrainInterval = (p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   interTrainIntervalCol))/1000;

stimPeriodCol = strcmp(p.init.trialArrayColumnNames, 'stimPeriod');
p.trVars.stimPeriod = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   stimPeriodCol);

currentThresholdMultiplierCol = strcmp(p.init.trialArrayColumnNames, 'currentThresholdMultiplier');
p.trVars.currentThresholdMultiplier = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   currentThresholdMultiplierCol);

interElectrodeSpacingCol = strcmp(p.init.trialArrayColumnNames, 'interElectrodeSpacing');
p.trVars.interElectrodeSpacing = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
   interElectrodeSpacingCol);


% Locations of fixation and targets

% fixation location in pixels relative to the center of the screen!
% (Y is flipped because positive is down in psychophysics toolbox).
p.draw.fixPointPix      =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

% fixation window width and height in pixels.
p.draw.fixWinWidthPix       = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix      = pds.deg2pix(p.trVars.fixWinHeightDeg, p);


% Choose target locations:
p.draw.targOnePointPix     =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targOneDegX, p.trVars.targOneDegY], p);
p.draw.targTwoPointPix     =  p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targTwoDegX, p.trVars.targTwoDegY], p);

% target window width and height in pixels.
p.draw.targWinWidthPix      = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix     = pds.deg2pix(p.trVars.targWinHeightDeg, p);

p.draw.color.targWin = p.draw.clutIdx.expMemMagenta_subBg;

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

% For radius, I multiply by 100 ('_x100') and round. That gives 2 decimal
% point precision, goo enough!
p.trVars.targRadius_x100 = round(tmpRadius * 100);


% Determine which electrodes to stimulate on:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

spacingChNum = p.trVars.interElectrodeSpacing/75;


% If using the "random suitable choice" method:

% Create matrix of differences between channel numbers of "good electrodes"
allDiffsGoodElectrodes = abs(p.init.electrodeInfo.goodElectrodes - p.init.electrodeInfo.goodElectrodes');

% find the paired indices where differences == desired spacing
[rows, cols] = find (allDiffsGoodElectrodes == spacingChNum);

if isempty (rows) || isempty (cols)
    error ('There are no pairs of good electrodes with the desired spacing');
end


% Randomly pick one pair from rows/cols
randCol = randi(length(cols));

% Set that pair as the two stimulation electrodes for this trial
p.trVars.stimElectrode1 = p.init.electrodeInfo.goodElectrodes (rows(randCol));
p.trVars.stimElectrode2 = p.init.electrodeInfo.goodElectrodes (cols(randCol));

% Use the channel-mapping to select the appropriate Ripple channel
p.trVars.rippleStimElectrode1 = p.init.electrodeInfo.rippleChannel (p.trVars.stimElectrode1);
p.trVars.rippleStimElectrode2 = p.init.electrodeInfo.rippleChannel (p.trVars.stimElectrode2);

% Check if the chosen ripple channel is a valid stim channel, based on info
% pulled using xippmex in initRipple
if ~ismember (p.trVars.rippleStimElectrode1, p.rig.ripple.stimChans)
    errorMessage = append('Ripple channel ', num2str(p.trVars.rippleStimElectrode1), ' is not a valid stim channel');
    error (errorMessage);
end

if ~ismember (p.trVars.rippleStimElectrode2, p.rig.ripple.stimChans)
    errorMessage = append('Ripple channel ', num2str(p.trVars.rippleStimElectrode2), ' is not a valid stim channel');
    error (errorMessage);
end

% If using the "refStimElectrode" method:
%{

% Check that refStimElectrode is set correctly
if p.trVars.refStimElectrode == -1
    error ('Need to set reference stimulation electrode');
elseif ~any(p.trVars.refStimElectrode == p.init.electrodeInfo.goodElectrodes)
    error ('Chosen reference stimulation electrode is not on good electrodes list')
end

% If electrodes + or - spacing are both not on good electrode list, send error
if      ~any (p.trVars.refStimElectrode + spacingChNum == p.init.electrodeInfo.goodElectrodes) && ...
        ~any (p.trVars.refStimElectrode - spacingChNum == p.init.electrodeInfo.goodElectrodes)
    errorStr = append ('No electrodes on good electrode list that are ', num2Str(p.trVars.interElectrodeSpacing), ' um from the chosen refStimElectrode');
    error (errorStr);

% If only electrode + spacing is on good electrode list, use that
elseif  any (p.trVars.refStimElectrode + spacingChNum == p.init.electrodeInfo.goodElectrodes) && ...
        ~any (p.trVars.refStimElectrode - spacingChNum == p.init.electrodeInfo.goodElectrodes)
    p.trVars.otherStimElectrode = p.trVars.refStimElectrode + spacingChNum;

% If only electrode - spacing is on good electrode list, use that
elseif  ~any (p.trVars.refStimElectrode + spacingChNum == p.init.electrodeInfo.goodElectrodes) && ...
        any (p.trVars.refStimElectrode - spacingChNum == p.init.electrodeInfo.goodElectrodes)
    p.trVars.otherStimElectrode = p.trVars.refStimElectrode - spacingChNum;

% If both electrodes + or - spacing are on good electrode list, randomly choose one
else
    p.trVars.otherStimElectrode = p.trVars.refStimElectrode + (randsample ([1 -1], 1)*spacingChNum);
end

p.trVars.stimElectrode1 = p.trVars.refStimElectrode;
p.trVars.stimElectrode2 = p.trVars.otherStimElectrode;

% Use the channel-mapping to select the appropriate Ripple channel
p.trVars.rippleStimElectrode1 = p.init.electrodeInfo.rippleChannel (p.trVars.stimElectrode1);
p.trVars.rippleStimElectrode2 = p.init.electrodeInfo.rippleChannel (p.trVars.stimElectrode2);

% Check if the chosen ripple channel is a valid stim channel, based on info
% pulled using xippmex in initRipple
if ~ismember (p.trVars.rippleStimElectrode1, p.rig.ripple.stimChans)
    errorMessage = append('Ripple channel ', p.trVars.rippleStimElectrode1, ' is not a valid stim channel');
    error (errorMessage);
end

if ~ismember (p.trVars.rippleStimElectrode2, p.rig.ripple.stimChans)
    errorMessage = append('Ripple channel ', p.trVars.rippleStimElectrode2, ' is not a valid stim channel');
    error (errorMessage);
end


%}



% Determine amount of current to use:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set step size to 2 for both electrodes
% **Note: For this task, we are simply always using a step size of 2

pds.xippmex ('stim', 'enable', 0);

pds.xippmex('stim', 'res', p.trVars.rippleStimElectrode1, 2);
pds.xippmex('stim', 'res', p.trVars.rippleStimElectrode2, 2);

% Calculate desired current amplitude based on C50 of that electrode and
% the multiplier in the trial structure
p.trVars.stimAmplitude1 = p.init.electrodeInfo.C50(p.trVars.stimElectrode1)*p.trVars.currentThresholdMultiplier;
p.trVars.stimAmplitude2 = p.init.electrodeInfo.C50(p.trVars.stimElectrode2)*p.trVars.currentThresholdMultiplier;


% If stimulation amplitude is >200, set it =200 and send a message saying
% we have done this (we are artificially limiting the current to 200 uA)
if p.trVars.stimAmplitude1 > 200
    dispStr = append('Calculated stimulation amplitude for electrode 1 is ', ...
        num2str(p.trVars.stimAmplitude1), '. Limiting to 200 uA instead');
    disp (dispStr);
    p.trVars.stimAmplitude1 = 200;
    
end
    
if p.trVars.stimAmplitude2 > 200
    dispStr = append('Calculated stimulation amplitude for electrode 1 is ', ...
        num2str(p.trVars.stimAmplitude2), '. Limiting to 200 uA instead');
    disp (dispStr);
    p.trVars.stimAmplitude2 = 200;
end


% Convert to steps and overwrite amplitude value with actual amount of
% current we will be stimulating with for bookkeeping purposes
p.trVars.stimCurrentSteps1 = round(p.trVars.stimAmplitude1/2);
p.trVars.stimCurrentSteps2 = round(p.trVars.stimAmplitude2/2);

p.trVars.stimAmplitude1 = p.trVars.stimCurrentSteps1*2;
p.trVars.stimAmplitude2 = p.trVars.stimCurrentSteps2*2;


% Checks if number of steps is >100, as Ripple can't handle that. Note that
% this error should never actually be seen with how the code is written,
% but is here as a check just in case something weird happens
if p.trVars.stimCurrentSteps1 > 100 || p.trVars.stimCurrentSteps2 > 100

	currentSteps1 = p.trVars.stimCurrentSteps1
	currentSteps2 = p.trVars.stimCurrentSteps2
	
    error ('Stimulation current steps is >100');
end



% Make stimulation commands:
%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Which electrodes, period between pulses, how many pulses
p.trVars.cmd1 = struct ('elec', p.trVars.rippleStimElectrode1, ...
    'period', p.trVars.stimPeriod, 'repeats', p.trVars.stimNumPulses);
p.trVars.cmd2 = struct ('elec', p.trVars.rippleStimElectrode2, ...
    'period', p.trVars.stimPeriod, 'repeats', p.trVars.stimNumPulses);


% cmd.seq(1) describes first phase of the biphasic pulse
p.trVars.cmd1.seq(1) = struct('length', p.trVars.cmdSeqLength, 'ampl', p.trVars.stimCurrentSteps1, ...
    'pol', 0, 'fs', 1, 'enable', 1, 'delay', 0, 'ampSelect', 1);
p.trVars.cmd2.seq(1) = struct('length', p.trVars.cmdSeqLength, 'ampl', p.trVars.stimCurrentSteps2, ...
    'pol', 0, 'fs', 1, 'enable', 1, 'delay', 0, 'ampSelect', 1);

% cmd.seq(2) describes interphase interval of the biphasic pulse
p.trVars.cmd1.seq(2) = struct('length', p.trVars.cmdSeqIPI, 'ampl', 0, ...
    'pol', 0, 'fs', 1, 'enable', 0, 'delay', 0, 'ampSelect', 1);
p.trVars.cmd2.seq(2) = struct('length', p.trVars.cmdSeqIPI, 'ampl', 0, ...
    'pol', 0, 'fs', 1, 'enable', 0, 'delay', 0, 'ampSelect', 1);

% cmd.seq(3) describes second phase of the biphasic pulse
p.trVars.cmd1.seq(3) = struct('length', p.trVars.cmdSeqLength, 'ampl', p.trVars.stimCurrentSteps1, ...
    'pol', 1, 'fs', 1, 'enable', 1, 'delay', 0, 'ampSelect', 1);
p.trVars.cmd2.seq(3) = struct('length', p.trVars.cmdSeqLength, 'ampl', p.trVars.stimCurrentSteps2, ...
    'pol', 1, 'fs', 1, 'enable', 1, 'delay', 0, 'ampSelect', 1);



% Timing Info:
%%%%%%%%%%%%%%


% Note: for microstim trials, stimDur is an estimate based on input 
% parameters; it is not used to actually control how long the train lasts,
% that is done by the Ripple system through xippmex
p.trVars.stimDur             = (p.trVars.stimPeriod*p.trVars.stimNumPulses*(100/3))/1000000;


% determine total stim duration based on spatial vs temporal and 1 vs 2
if strcmp(p.init.exptType, 'temporal') && p.trVars.numStim == 2
    totalStimDur = p.trVars.stimDur*2 + p.trVars.interTrainInterval;
else
    totalStimDur = p.trVars.stimDur;
end

% Check if total fix duration is too small for input parameters
if p.trVars.totalFixDur < (totalStimDur + ...
                           p.trVars.stimOnsetMin + ...
                           p.trVars.targOnsetMin + ...
                           p.trVars.goTimePostTarg)
    error ('Total fix duration is lower than minimum values for this microstim trial');
end

% Randomly allocate "extra" time to either pre-stim or post-stim
remainingTime = p.trVars.totalFixDur - totalStimDur ...
                                     - p.trVars.stimOnsetMin ...
                                     - p.trVars.targOnsetMin ...
                                     - p.trVars.goTimePostTarg;
randTimeLeft = unifrnd (0, remainingTime);

p.trVars.timeStimOneOnset   = p.trVars.stimOnsetMin + randTimeLeft;
p.trVars.timeStimOneOffset  = p.trVars.timeStimOneOnset + p.trVars.stimDur;



switch p.init.exptType

    case 'spatial'
        % if spatial task, one stim
        if p.trVars.numStim == 1
            
            % stim two does not occur
            p.trVars.timeStimTwoOnset = Inf;
            p.trVars.timeStimTwoOffset = Inf;
        
            p.trVars.timeTargOnset = p.trVars.timeStimOneOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        % if spatial task, two stim
        elseif p.trVars.numStim == 2

            % stim two happens at same time as stim one
            p.trVars.timeStimTwoOnset = p.trVars.timeStimOneOnset;
            p.trVars.timeStimTwoOffset = p.trVars.timeStimOneOffset;
        
            p.trVars.timeTargOnset = p.trVars.timeStimTwoOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        end


    case 'temporal'

        % if temporal task, one stim
        if p.trVars.numStim == 1

            % stim two does not occur
            p.trVars.timeStimTwoOnset = Inf;
            p.trVars.timeStimTwoOffset = Inf;
        
            p.trVars.timeTargOnset = p.trVars.timeStimOneOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        % if temporal task, two stim
        elseif p.trVars.numStim == 2

            % stim two occurs after interstim interval
            p.trVars.timeStimTwoOnset = p.trVars.timeStimOneOnset + p.trVars.interTrainInterval;
            p.trVars.timeStimTwoOffset = p.trVars.timeStimTwoOnset + p.trVars.stimDur;
        
            p.trVars.timeTargOnset = p.trVars.timeStimTwoOffset + (remainingTime-randTimeLeft);
            p.trVars.timeFixOffset = p.trVars.timeTargOnset + p.trVars.goTimePostTarg;

        end

end

p.trVars.timeTargOffset     = Inf;

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
