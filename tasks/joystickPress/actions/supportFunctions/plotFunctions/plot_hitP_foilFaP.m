function hA = plot_hitP_foilFaP(cue, foil, verbose)


if ~exist('verbose')
    verbose = true;
end


hA      = gca;
x       = [1, 2];
y       = [cue.pHit, foil.pFa];
ciNeg   = [cue.pHit - cue.ciHit(1); foil.pFa - foil.ciFa(1)];
ciPos   = [cue.pHit - cue.ciHit(2); foil.pFa - foil.ciFa(2)];
h       = errorbar(x, y, ciNeg, ciPos, '.k', 'MarkerSize', 15, 'LineWidth', 1);
legend(h, 'either loc', 'Location', 'NorthEast');
xlim([.5 2.5])
ylim([-0.2 1]);
set(gca, 'XTick', x, 'XTickLabel', {'hit', 'foilFa'})
ylabel('proportion')
grid on

if verbose
   text(.8, -0.1, ['nTr = ' num2str(cue.n)], 'fontSize', 6)
   text(1.8, -0.1, ['nTr = ' num2str(foil.n)], 'fontSize', 6)
end

