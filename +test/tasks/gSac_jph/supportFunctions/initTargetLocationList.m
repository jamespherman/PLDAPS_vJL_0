function [p] = initTargetLocationList(p)

switch p.stim.targLocationPreset
    case 'grid'
        
        % Defines a grid where each x/y intersection will be a target location.
        % stroes all X and Y positions in a list, and into the p.stim substruct.
        
        
        % x's:
        minX = p.stim.gridMinX;
        maxX = p.stim.gridMaxX;
        binX = p.stim.gridBinSizeX;
        % y's:
        minY = p.stim.gridMinY;
        maxY = p.stim.gridMaxY;
        binY = p.stim.gridBinSizeY;
        
        % meshgrid dat shiznitz:
        [xx, yy] = meshgrid(minX:binX:maxX, minY:binY:maxY);
        xx = xx(:);
        yy = yy(:);
        
        % make sure that a taget does not appear at the fixation point by removing
        % the fixation point from the list of target locations:
        ptrToFp     = find(xx==p.trVarsInit.fixDegX & yy==p.trVarsInit.fixDegY);
        xx(ptrToFp) = [];
        yy(ptrToFp) = [];
    
    case {'ring', 'nRing'}
        
        % Defines a ring at given radius whereupon a number of targets will
        % appear at an equal distance from one another. The phase is
        % determined by the base angle.
        
        iT = 1;
        xx = nan(sum(p.stim.ringTargNumber),1);
        yy = nan(sum(p.stim.ringTargNumber),1);
        nRings = numel(p.stim.ringRadius);
        
        for iR = 1:nRings
            ita = 360 / p.stim.ringTargNumber(iR);

            for ii = 1:(p.stim.ringTargNumber(iR))
                xx(iT) = p.stim.ringRadius(iR) * cosd(p.stim.ringBaseAngle(iR) + (ii-1) * ita);
                yy(iT) = p.stim.ringRadius(iR) * sind(p.stim.ringBaseAngle(iR) + (ii-1) * ita);
                iT = iT + 1;
            end
        end
        


        
end


% length of target location list:
p.stim.nTargetLocations = length(xx);

% get randomly permutation indices
idxRand = randperm(p.stim.nTargetLocations);

% and store the list in p:
p.stim.targetLocationListX = xx(idxRand);
p.stim.targetLocationListY = yy(idxRand);

% also get the eccentricity of each stimulus location:
p.stim.stimulusLocationListEcc = sqrt(...
    (p.trVarsInit.fixDegX - p.stim.targetLocationListX).^2 + ...
    (p.trVarsInit.fixDegX - p.stim.targetLocationListY).^2);

        
end