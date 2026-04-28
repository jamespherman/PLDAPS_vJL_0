function hA = plot_hitP_foilFaP_perLoc(cue, foil)



if ~exist('verbose')
    verbose = true;
end


hA = gca;
h   = nan(1,2);
clr = flipud(lines(2));

iN      = 2; % analyzing data for stimulus n=2.
for iL = 1:2
    x       = [1, 2];
    xShift  = x + sign(iL-1.5)*0.1; % shifting the x position by 0.1 either leftward (for iL=1) or rightward (for iL=2).
    y       = [cue.loc(iL).pHit, foil.loc(iL).pFa];
    ciNeg   = [cue.loc(iL).pHit - cue.loc(iL).ciHit(1); foil.loc(iL).pFa - foil.loc(iL).ciFa(1)];
    ciPos   = [cue.loc(iL).pHit - cue.loc(iL).ciHit(2); foil.loc(iL).pFa - foil.loc(iL).ciFa(2)];
    h(iL)   = errorbar(xShift, y, ciNeg, ciPos, '.', 'MarkerSize', 15, 'LineWidth', 1, 'Color', clr(iL,:), 'MarkerFaceColor', clr(iL,:));
end
legend(h, {'loc1', 'loc2'}, 'Location', 'NorthEast')
xlim([.5 2.5])
ylim([-0.2 1]);
set(gca, 'XTick', x, 'XTickLabel', {'hit', 'foilFa'})
ylabel('proportion')
grid on

if verbose
    for iL = 1:2
        text(.8, -0.1 + (sign(iL-1.5)*0.04), ['nTr = ' num2str(cue.loc(iL).n)], 'Color', clr(iL,:), 'fontSize', 6);
        text(1.8, -0.1 + (sign(iL-1.5)*0.04), ['nTr = ' num2str(foil.loc(iL).n)], 'Color', clr(iL,:), 'fontSize', 6);
    end
end
