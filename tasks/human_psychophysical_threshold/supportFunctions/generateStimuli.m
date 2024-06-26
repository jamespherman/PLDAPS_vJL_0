function p = generateStimuli(p)

% p = generateStimuli(p)
%
% Generate circularly windowed dynamic "checkerboard" stimuli. 
%
% November 8th, 2022 - JPH
% The way this function works currently is: we always generate the maximum
% number of possible stimuli, then we show only what's needed, but is this
% efficient? I guess let's check first then worry about it? One concern is
% that when we store the stimulus information it might be hard to
% reconstruct which color values were actually displayed. I think for now
% let's keep it inefficient and we can revisit this later. If we want to
% revisit it, what we need to figure out is: how to modify the code so that
% colors are only generated for the stimuli that will be displayed on a
% given trial. I think this involves using "p.trVars.stimOnlist", and
% looping over whatever number of stimuli is in that list rather than
% looping over 1:p.trVars.nPatches.
%
% Another point: we currently generate the textures for each stimulus in
% each trial. This seems "doubly" inefficient: because we're generating the
% colors for all four stimuli even when we're not displaying them, the
% textures themselves could be generated once at the beginning of the
% experiment and never again. However, I think we didn't use this approach
% in the past because it would involve duplicating some of the calculations
% below at an earlier stage. Let's check into this later too (maybe).
%
% Stimulus generation is very fast - currently it takes about 30
% milliseconds to generate all the stimuli. Maybe this would take
% marginally longer if we were generating a larger number of textures but
% that sort of increase in duration is unavoidable.

% use stimSeed to determine following pseudorandom number sequence
rng(p.trVars.stimSeed);

% to define gabors, it's useful to make spatial indicies for each box /
% check.
[xt, yt]        = meshgrid(linspace(-p.stim.patchDiamBox/2, ...
    p.stim.patchDiamBox/2, p.stim.patchDiamBox));

% X array with x indicies for each box in each "frame" (3rd dim)
p.stim.X             = p.stim.funs.repFr(...
    repmat(xt, 1, p.trVars.nPatches), p.trVars.stimFrames);

% Y array with y indicies for each box in each "frame" (3rd dim)
p.stim.Y             = p.stim.funs.repFr(...
    repmat(yt, 1, p.trVars.nPatches), p.trVars.stimFrames);

% number of color-boxes used across all patches
p.stim.nBoxTot      = p.trVars.nPatches * p.stim.patchDiamBox^2;    

%% build indexing arrays
% "initial lifetimes array": assign a random initial value for lifetime.
% This ensures that the color-boxes change at random relative "phases"
% rather than all together.
ili                             = randi([1, p.trVars.boxLifetime], ...
    p.stim.patchDiamBox, p.trVars.nPatches*p.stim.patchDiamBox);

% "frame count index": a linear count of frames along the 3rd dimension
% repeated at each row x column position.
fci                             = repmat(...
    reshape(0:(p.trVars.stimFrames - 1), 1, 1, p.trVars.stimFrames), ...
    p.stim.patchDiamBox, p.trVars.nPatches*p.stim.patchDiamBox);

% "box lifetime index": adding together ili and fci, dividing by 
% p.trVars.boxLifetime and rounding to the ceiling gives us a count of
% lifetimes for each box. That is, along the 3rd dimension of bli, each
% row x column element tracks a box from lifetime #1 up to its maximum
% value, changing each 8 frames (after the random initial number of 
% frames).
bli                             = ceil(...
    bsxfun(@plus, ili, fci) / p.trVars.boxLifetime);

% "unique color index": our goal is to assign a unique numerical index for
% each unique color value needed. This is the placeholder for those unique
% numerical values.
p.stim.uci                      = zeros(size(bli));

% "unique phase index" - placeholder for gabor phase values
p.stim.upi                           = p.stim.uci;

% We're taking advantage of the fact that each stimulus-patch is segregated
% to a specific set of rows, this is useful in counting up the number of
% colors needed. Here we're defining which columns mark the end of each
% stimulus patch.
patchEndCols    = (1:p.trVars.nPatches)*p.stim.patchDiamBox;

% How many loop iterations do we need? (equal to the number of color
% epochs).
nLoop           = p.trVars.nEpochs;

% we want to count the number of colors we'll need per patch per epoch:
% "Colors Per Patch Per Epoch" (cpppe), this is the placeholder.
cpppe           = zeros(nLoop, p.trVars.nPatches);
for i = 1:nLoop
    
    % The basic strategy for counting colors is: (1) for a given box, count
    % how many color values are needed in a given epoch using "bli", (2)
    % offset the count for the "next" box by that much, so that when we
    % start indexing the colors used for that box, we have unique
    % non-overlapping values, (3) do this for each box in each patch in
    % each index, FAST.
    
    % We count colors and assign unique color index values differently
    % depending on whether this is the first epoch, last epoch, or the
    % middle.
    switch i
        case 1 % first epoch
            
            if isempty(p.stim.chgFrames) % if there's only 1 epoch...
                tempChgFramesIndex = size(bli, 3);
            else
                tempChgFramesIndex = p.stim.chgFrames(i);
            end
            
            % consult bli at the frame where the next change is to occur:
            % this tells us the lifetime count for each box up to that
            % frame. Use this information to calculate where the count
            % should start for each box.
            tempuni     = reshape([0, cumsum(p.stim.funs.flatchp(...
                bli(:, :, tempChgFramesIndex)))], p.stim.patchDiamBox, ...
                p.trVars.nPatches * p.stim.patchDiamBox);

            % make a logical color epoch index (cei) marking which portions
            % of each box's lifetime count belong to the current epoch.
            tempcei     = bli <= p.stim.funs.repFr( ...
                bli(:,:,tempChgFramesIndex), p.trVars.stimFrames);
            
            % how much to offset each box's count based on its lifetime
            % count up-to-now (this is zero in the first epoch, non zero
            % thereafter).
            bliOffset   = zeros(p.stim.patchDiamBox,p.stim.patchDiamBox ...
                * p.trVars.nPatches);
            
            % count the number of colors per patch in this epoch.
            % Conveniently, since out index increases row-wise first and
            % then column-wise (the order in which matlab fills an array
            % with from a vector), we can just consult the final row of
            % each patch's end-column (and add the lifetime-count for that
            % box in that epoch) to obtain the total number of colors
            % needed.
            cpppe(i,:)  = p.stim.funs.fidiff(tempuni(end,patchEndCols) ...
                + bli(end,patchEndCols, tempChgFramesIndex));
            
            % how much do we have to offset the WHOLE count: by the total
            % number of colors index values assigned previously, but again
            % this is the first epoch so the offset is zero.
            offset      = 0;
            
            % use bli to construct p.stim.upi which holds lifetime
            % multiplied by "speed"
            p.stim.upi = p.stim.upi + tempcei .* bli .* ...
                p.stim.funs.repFr(...
                cell2mat(arrayfun(@(x)x*ones(p.stim.patchDiamBox), ...
                p.stim.speedArray(:, i)', 'UniformOutput', false)), ...
                p.trVars.stimFrames);
            
        case nLoop % last epoch
            % just as above
            tempuni     = reshape(...
                [0, cumsum(p.stim.funs.flatchp(bli(:,:,end) - ...
                bli(:,:,p.stim.chgFrames(i-1))))], ...
                p.stim.patchDiamBox,p.trVars.nPatches*p.stim.patchDiamBox);
            
            % just as above, but since this is the last epoch, we just find
            % the box lifetime counts that are beyond the penultimate
            % change-frame
            tempcei     = bli > p.stim.funs.repFr(...
                bli(:,:,p.stim.chgFrames(i-1)), p.trVars.stimFrames);
            
            % offset each box's count by the lifetime-count of each box up
            % until the last change-frame
            bliOffset   = bli(:,:,p.stim.chgFrames(i-1));
            
            % offset the total count by the number of color index values
            % used up to now
            offset      = sum(p.stim.funs.flatten(cpppe));
            
            % just as above except we now subtract the box lifetime-count
            % of the previous change-frame
            cpppe(i,:)  = p.stim.funs.fidiff(tempuni(end,patchEndCols) ...
                + bli(end,patchEndCols,end) - ...
                bli(end,patchEndCols,p.stim.chgFrames(i-1)));
            
            % use bli to construct p.stim.upi which holds lifetime
            % multiplied by "speed", but must be offset by phase in
            % previous epoch to avoid phase "jumps" when speed changes. The
            % "equation" for phase in a 2nd epoch after a change in speed
            % is: y = v2*x + pc * (v1 - v2).
            p.stim.upi = p.stim.upi + tempcei .* bli .* ...
                p.stim.funs.repFr(...
                cell2mat(arrayfun(@(x)x*ones(p.stim.patchDiamBox), ...
                p.stim.speedArray(:, i)', 'UniformOutput', false)), ...
                p.trVars.stimFrames) + ...
                tempcei .* p.stim.funs.repFr(max(p.stim.upi, [], 3) .* ...
                cell2mat(arrayfun(@(x)x*ones(p.stim.patchDiamBox), ...
                (p.stim.speedArray(:, i - 1) - ...
                p.stim.speedArray(:, i))', 'UniformOutput', false)), ...
                p.trVars.stimFrames);
            
        otherwise % middle (not first or last) epochs
            % just as above
            tempuni     = reshape([0, cumsum(p.stim.funs.flatchp(bli(:,:,p.stim.chgFrames(i)) - bli(:,:,p.stim.chgFrames(i-1))))],p.stim.patchDiamBox,p.trVars.nPatches*p.stim.patchDiamBox);
            
            % as abve except we now look for the lifetime-count values
            % between an upper and lower bound rather than only below (case
            % 1), or only above (case nLoop) a proximal change-frame.
            tempcei     = bli<=p.stim.funs.repFr(bli(:,:,p.stim.chgFrames(i)),p.trVars.stimFrames) & bli>p.stim.funs.repFr(bli(:,:,p.stim.chgFrames(i-1)),p.trVars.stimFrames);
            
            % as in 'case nLoop'
            bliOffset   = bli(:,:,p.stim.chgFrames(i-1));
            
            % as in 'case nLoop' 
            offset      = sum(p.stim.funs.flatten(cpppe));
            
            % as in 'case nLoop'
            cpppe(i,:)  = p.stim.funs.fidiff(tempuni(end,patchEndCols) + bli(end,patchEndCols,p.stim.chgFrames(i)) - bli(end,patchEndCols,p.stim.chgFrames(i-1)));
            
            % as in 'case nLoop'
            % use bli to construct p.stim.upi which holds lifetime
            % multiplied by "speed", but must be offset by phase in
            % previous epoch to avoid phase "jumps" when speed changes. The
            % "equation" for phase in a 2nd epoch after a change in speed
            % is: y = v2*x + pc * (v1 - v2).
            p.stim.upi = p.stim.upi + tempcei .* bli .* ...
                p.stim.funs.repFr(...
                cell2mat(arrayfun(@(x)x*ones(p.stim.patchDiamBox), ...
                p.stim.speedArray(:, i)', 'UniformOutput', false)), ...
                p.trVars.stimFrames) + ...
                tempcei .* p.stim.funs.repFr(max(p.stim.upi, [], 3) .* ...
                cell2mat(arrayfun(@(x)x*ones(p.stim.patchDiamBox), ...
                (p.stim.speedArray(:, i - 1) - ...
                p.stim.speedArray(:, i))', 'UniformOutput', false)), ...
                p.trVars.stimFrames);
    end
    
    % put it all together: (1) use tempcei to restrict which portion of
    % p.stim.uci gets assigned (2) add bli to tempuni, subtracting bliOffset so
    % that the count goes up linearly with no skips, (3) add offset so that
    % we don't overlap with color values ued in previous epochs.
    p.stim.uci = p.stim.uci + tempcei.*(p.stim.funs.repFr(tempuni,p.trVars.stimFrames) + bli - p.stim.funs.repFr(bliOffset,p.trVars.stimFrames) + offset);
end

% force p.stim.upi to go between 0 and 2*pi;
% p.stim.upi = 2*pi*((p.stim.upi - 1)/(max(p.stim.upi(:)) - 1));

% Use cpppe to calculate starts-and-ends of each range of color values.
% That is: based on the numer of colors per patch per epoch, which range of
% values will be assigned to which patch/epoch. This makes the code in the
% for-loop below a bit easier to digest.
cpeint = reshape(cumsum(p.stim.funs.flatten([ones(p.trVars.nPatches * nLoop, 1), reshape(cpppe', p.trVars.nPatches * nLoop, 1) - 1]')), 2, p.trVars.nPatches, nLoop);

% placeholders for each "gun's" colors. Keeping each as a seperate vector
% makes putting them back into a 4D array much easier later.
bgRGB                           = p.draw.clut.expColors(p.draw.clutIdx.expBg_subBg + 1, :);
p.stim.tempR                    = [bgRGB(1); zeros(cpeint(end), 1)];
p.stim.tempG                    = [bgRGB(2); zeros(cpeint(end), 1)];
p.stim.tempB                    = [bgRGB(3); zeros(cpeint(end), 1)];

% make an array in which each unique color index "uci" and phase index
% "upi" are stored with corresponding "X" and "Y" arrays (which specify
% the gabor). This "association array" is important for drawing the gabor 
% correctly.
assocArray                  = unique([p.stim.uci(:), p.stim.X(:), ...
    p.stim.Y(:), p.stim.upi(:)], 'rows');

% loop over epochs...
for i = 1:nLoop
    
    % loop over patches...
    for j = 1:p.trVars.nPatches
        
        % define inputs to gabor function ("gf"). Note, the way we're using
        % the gabor function (GF), the frequency is defined as cycles /
        % box, to convert from cycles per box to cycles per degree we need
        % to do: cyc / box * box / pix * pix / deg
        X       = assocArray(cpeint(1,j,i):cpeint(2,j,i), 2);
        Y       = assocArray(cpeint(1,j,i):cpeint(2,j,i), 3);
        freq    = p.stim.freqArray(j,i);
        orient  = p.stim.funs.nrmrnd(p.stim.orientArray(j,i), ...
            p.stim.orientVarArray(j,i), [cpppe(i,j), 1]);
        winStd  = p.stim.patchDiamBox/3;
        
        % hack to deal with velocity change from pre-change to post-change
        % phase   = p.stim.speedArray(j, i) * ...
        %    assocArray(cpeint(1, j, i):cpeint(2, j, i), 4);
        phase   = assocArray(cpeint(1, j, i):cpeint(2, j, i), 4);

        % generate gabor part (gaussian windowed sinusoid).
        
        gaborVals = p.stim.ctrstArray(j,i) * ...
            gf(X, Y, phase, freq, orient, winStd);

        % treating saturation as radius and hue as theta, generate XY (DKL
        % plane) coordinates to then rotate by the desired "hue angle":
        rThetaVals = [...
            p.stim.funs.unfrnd(...
            p.stim.satArray(j, i) - p.stim.satVarArray(j, i), ...
            p.stim.satArray(j, i) + p.stim.satVarArray(j, i), ...
            [1, cpppe(i, j)]); ...
            p.stim.funs.unfrnd(...
            -p.stim.hueVarArray(j, i), ...
            p.stim.hueVarArray(j, i), ...
            [1, cpppe(i, j)])];
        XYvals = repmat(rThetaVals(1,:), 2, 1) .* ...
            [cosd(rThetaVals(2,:)); sind(rThetaVals(2,:))];
        
        % draw the color values for each patch in each epoch, defining
        % the range of values from 'cpeint'
        currInd = (cpeint(1,j,i):cpeint(2,j,i));
        [p.stim.tempR(currInd, :),...
            p.stim.tempG(currInd, :),...
            p.stim.tempB(currInd, :)] = ...
            dkl2rgb([...
            p.stim.funs.unfrnd(...
            p.stim.lumArray(j, i) - p.stim.lumVarArray(j, i), ...
            p.stim.lumArray(j, i) + p.stim.lumVarArray(j,i), ...
            [1,cpppe(i, j)]) + gaborVals'; ...
            p.stim.funs.rotVcts(...
            XYvals, p.stim.hueArray(j, i))]);
        
        % dkl2rgb takes a 3 x n array of DKL-space colors, first row is
        % luminance, 2nd row is red/green, 3rd row is blue/yellow. we're
        % rotating the 2nd/3rd rows so that our colors vary along a single
        % axis in the 2D isoluminant plane, but one can modify the
        % distributions being used to define the colors in DKL space here
        % as long as the numbers / array-sizes are correct.
    end
end

% [p.stim.tempR(currInd, :),...
%             p.stim.tempG(currInd, :),...
%             p.stim.tempB(currInd, :)] = ...
%             dkl2rgb([...
%             p.stim.funs.unfrnd(...
%             p.stim.lumArray(j, i) - p.stim.lumVarArray(j, i), ...
%             p.stim.lumArray(j, i) + p.stim.lumVarArray(j,i), ...
%             [1,cpppe(i, j)]) + gaborVals'; ...
%             p.stim.funs.rotVcts(...
%             [p.stim.funs.nrmrnd(p.stim.satArray(j, i), ...
%             p.stim.satVarArray(j, i), [1, cpppe(i, j)]); ...
%             p.stim.funs.nrmrnd(0, p.stim.hueVarArray(j, i), ...
%             [1, cpppe(i, j)])], p.stim.hueArray(j, i))]);

% define a 4D placeholder for the output "images":
p.stim.imagesOut = zeros(p.stim.patchDiamBox, p.trVars.nPatches * ...
    p.stim.patchDiamBox, 3, p.trVars.stimFrames);

% populate image placeholder array:
p.stim.imagesOut(:,:,1,:) = p.stim.tempR(p.stim.uci+1);
p.stim.imagesOut(:,:,2,:) = p.stim.tempG(p.stim.uci+1);
p.stim.imagesOut(:,:,3,:) = p.stim.tempB(p.stim.uci+1);

% make a hard-edged circular window for the "checkerboard" stimulus
% patches. First some helpful variables.
ms              = p.stim.patchDiamPix / 2 - 0.5;
[x,y]           = meshgrid(-ms:ms, -ms:ms);
hw              = ones(1, p.stim.patchDiamPix, p.stim.patchDiamPix);
radval          = (x.^2 + y.^2).^0.5;
g1              = radval > (ms - 0.5);

% Build the "hard window"
hw(g1)          = 0;
hw              = repmat(hw, 1, p.trVars.nPatches);

% compute the background portion of the textures (the chunk outside the
% "hard window). This doesn't change over stimulus frames:
txBgnd = permute(tensorprod(...
    p.draw.colorRange*p.draw.bgRGB', ...
    double(~hw), 2, 1), [3 2 1]);

% loop over stimulus frames to make textures:
for i = 1:p.trVars.stimFrames
    arrayFrame = round(p.draw.colorRange*permute(repmat(hw, 3, 1, 1), ...
        [3 2 1]) .* ...
        (arrayScale(p.stim.imagesOut(:, :, :, i), p.trVars.boxSizePix)) ...
        + txBgnd);
    p.stim.stimTextures(i) = Screen('MakeTexture', p.draw.window, ...
        255 * arrayFrame / p.draw.colorRange);
end

end

function p                      = makeTex(p)

% make a hard-edged circular window for the "checkerboard" stimulus
% patches. First some helpful variables.
ms              = p.stim.patchDiamPix / 2 - 0.5;
[x,y]           = meshgrid(-ms:ms, -ms:ms);
hw              = ones(1, p.stim.patchDiamPix, p.stim.patchDiamPix);
radval          = (x.^2 + y.^2).^0.5;
g1              = radval > (ms - 0.5);

% Build the "hard window"
hw(g1)          = 0;
hw              = squeeze(hw);

%unscaled "image"
unscaledIm      = reshape(1:p.stim.nBoxTot / p.trVars.nPatches , ...
    p.stim.patchDiamBox, p.stim.patchDiamBox);

% scaled image without replacing the undex values.
scaledIm        = hw.*(arrayScale(unscaledIm, p.trVars.boxSizePix));

% Note which of the checks in the unscaled image have been retained to any
% extent in the scaled image. This is helpful because when we generate
% unique color indexes, we don't try to account for the hard window simply
% because it's computationally more efficient, but we need to discard some
% of the colors / indexes to put the right colors in the right rows of the
% CLUT. This logical index lets us do that.
p.stim.colorRowSelector = repmat(ismember(unscaledIm(:), scaledIm(:)), ...
    p.trVars.nPatches, 1); 

% Loop over possible stimulus locations. For each possible stimulus
% location, if the stimulus will be present in the current trial, make the
% array to generate the texture for displaying the stimulus. However, even 
for i = 1:p.trVars.nPatches

    % The range of CLUT indexes for each stimulus patch is distinct and
    % sequential. To select the right range of indexes for the current
    % patch, we calculate an "offset" that sets the bottom of the range
    % above the index values that are dedicated to other patches / fixed
    % CLUT values.
    if i > 1
        offsetVal = max(p.stim.stimArray{i - 1}(:)) + 1;
    else
        offsetVal = p.draw.nColors;
    end

    % generate the stimulus array for the currently considered patch:
    p.stim.stimArray{i}  = (reshape(unindex(hw.*...
            arrayScale(unscaledIm, p.trVars.boxSizePix)), ...
            p.stim.patchDiamPix, p.stim.patchDiamPix) - 2 + ...
            offsetVal).*hw + (~hw)*p.draw.color.background;

    % If the currently considered stimulus patch is displayed in the
    % current trial, generate a tecture for it. If the stimulus patch
    % won't be displayed, populate the texture with "empty" ("[]").
    if any(p.trVars.stimOnList == i)
        p.draw.stimTex{i}    = Screen('MakeTexture', p.draw.window, ...
            p.stim.stimArray{i});
    else
        % store empty array for patches not shown in the current trial:
        p.draw.stimTex{i}    = [];
    end
end

% if the cued stimulus is being presented at a location other than location
% 1, reorder the textures:
% if p.stim.cueLoc ~= 1 && p.stim.nStim > 1
%     keyboard
%     p.draw.stimTex = fliplr(p.draw.stimTex);
% end

end

function y                      = arrayScale(x, scale)

% scale (up to) the 1st two dimensions of a 1/2/3/4D array:
% 
% A = [1 2; 3 4];
%
% arrayScale(A, 2) = [1 1 2 2; 1 1 2 2; 3 3 4 4; 3 3 4 4];
%
%
flatten = @(x)x(:);
dims = size(x);
switch numel(dims)
    case {1,2}
        y = reshape(repmat(flatten(repmat(x,scale,1)),1,scale)',scale*dims);
    case 3
        y = reshape(repmat(flatten(repmat(x,scale,1)),1, scale)',scale*dims(1),scale*dims(2),dims(3));
    case 4
        y = reshape(repmat(flatten(repmat(x,scale,1)),1, scale)',scale*dims(1),scale*dims(2),dims(3),dims(4));
end
end

function out = gf(x, y, phase, freq, orientDeg, gaussWinSD)

angle   = orientDeg*pi/180; % 30 deg orientation.
f       = freq*2*pi; % cycles / pixel
a       = cos(angle)*f;
b       = sin(angle)*f;
out     = exp(-((x/gaussWinSD).^2) - ((y/gaussWinSD).^2)) .* ...
    sin(a.*x+b.*y+phase);

end