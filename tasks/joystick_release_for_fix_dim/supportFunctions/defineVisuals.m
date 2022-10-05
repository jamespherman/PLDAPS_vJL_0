function p = defineVisuals(p)

% p = defineVisuals(p)
%
% Define fixation location in pixels, define fixation window width / height
% in pixels, make the grid of lines (for experimenter display). Also define
% the color of the fixation window depending on the trial type. If it's a
% "release on fixation offset" trial, make the fixation window one color,
% if it's not, make it another color

% fixation window width and height in pixels.
p.draw.fixWinWidthPix       = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix      = pds.deg2pix(p.trVars.fixWinHeightDeg, p);

% make grid with "gridSpace" degree spacing
gridX           = pds.deg2pix(-30:p.draw.gridSpacing:30, p) + p.draw.middleXY(1);
gridY           = pds.deg2pix(-20:p.draw.gridSpacing:20, p) + p.draw.middleXY(2);

p.draw.gridXY   = [];
for i = 1:length(gridX)
    p.draw.gridXY = [p.draw.gridXY, ...
        [gridX(i), gridX(i); gridY(1), gridY(end)]]; ... % vertical lines
end
for i = 1:length(gridY)
    p.draw.gridXY = [p.draw.gridXY, ...
        [gridX(1), gridX(end); gridY(i), gridY(i)]]; ... % vertical lines
end

% define fixation window color depending on trial type:
if p.trVars.isRelOnFixOffTrial
    p.draw.color.fixWin = p.draw.clutIdx.expBlue_subBg;
else
    p.draw.color.fixWin = p.draw.clutIdx.expGrey25_subBg;
end

end