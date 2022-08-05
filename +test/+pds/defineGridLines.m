function p = defineGridLines(p)

% p = defineGridLines(p)
%
% Define fixation location in pixels, define fixation window width / height
% in pixels, make the grid of lines (for experimenter display).

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
            [gridX(1), gridX(end); gridY(i), gridY(i)]]; ... % horizontal lines
end

end