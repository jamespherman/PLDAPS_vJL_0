function p = defineVisuals(p)

% p = defineVisuals(p)
%
% Define fixation location in pixels, define fixation window width / height
% in pixels, make the grid of lines (for experimenter display).

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

% make strings for drawing text objects on screen
p.draw.perfStrings{1, 1} = num2str(p.status.hr1Loc1); % hit rate for single patch at location 1
p.draw.perfStrings{1, 2} = num2str(p.status.cr1Loc1); % correct reject rate for single patch at location 1
p.draw.perfStrings{1, 3} = num2str(p.status.hr2Loc1); % hit rate for two patch at location 1
p.draw.perfStrings{1, 4} = num2str(p.status.hr2Loc1); % correct reject rate for two patch at location 1
p.draw.perfStrings{2, 1} = num2str(p.status.hr1Loc2); % hit rate for single patch at location 2
p.draw.perfStrings{2, 2} = num2str(p.status.cr1Loc2); % correct reject rate for single patch at location 2
p.draw.perfStrings{2, 3} = num2str(p.status.hr2Loc2); % hit rate for two patch at location 2
p.draw.perfStrings{2, 4} = num2str(p.status.hr2Loc2); % correct reject rate for two patch at location 2

% % determine location 1 & 2
% if p.init.trialsArray(p.trVars.currentTrialsArrayRow, 1)
%     locsTemp{1} = p.trVars.cueLocCartPix;
%     locsTemp{2} = p.trVars.foilLocCartPix;
% else
%     locsTemp{1} = p.trVars.cueLocCartPix;
%     locsTemp{2} = p.trVars.foilLocCartPix;
% end
% 
% % figure out which location is on the right and which is on the left
% loc1RightLogical = locsTemp{1}(1) < locsTemp{2}(1);
% 
% % define locations for drawing bits of text
% textOffsets = [-150, -50, 50, 150];
% for i = 1:4
%     for j = 1:2
%         p.draw.perfStringsLoc{j, i} = [locsTemp{j} + 300*((-1)^double(loc1RightLogical + j - 1)), ...
%             locsTemp{j} + textOffsets(i)];
%     end
% end

end