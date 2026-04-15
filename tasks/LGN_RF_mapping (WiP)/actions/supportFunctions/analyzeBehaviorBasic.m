function bb = analyzeBehaviorBasic(p)
%   bb = analyzeBehaviorBasic(p)
%

%% init basic behavior struct ('bb'):
bb = struct;
bb.sessionId        = p.init.sessionId;
bb.sessionFolder    = p.init.sessionFolder;

%% get indices for all trial types of interest:
bb.ix = getIndices(p);

%% analyze basic behavior:
% n = count
% p = proportion
% rt = reaction time

for iN = 1:2
    % cue:
    bb.n(iN).cue.n        = sum(bb.ix.n(iN).cue);
    % cue - hit:
    bb.n(iN).cue.nHit     = sum(bb.ix.n(iN).cueHit);
    [bb.n(iN).cue.pHit, bb.n(iN).cue.ciHit]     = binofit(bb.n(iN).cue.nHit, bb.n(iN).cue.n);
    % cue - miss:
    bb.n(iN).cue.nMiss     = bb.n(iN).cue.n - bb.n(iN).cue.nHit;
    [bb.n(iN).cue.pMiss, bb.n(iN).cue.ciMiss]   = binofit(bb.n(iN).cue.nMiss, bb.n(iN).cue.n);
    
    % foil:
    bb.n(iN).foil.n        = sum(bb.ix.n(iN).foil);
    % foil - false alarm:
    bb.n(iN).foil.nFa     = sum(bb.ix.n(iN).foilFa);
    [bb.n(iN).foil.pFa, bb.n(iN).foil.ciFa]     = binofit(bb.n(iN).foil.nFa, bb.n(iN).foil.n);
    % foil - correct reject:
    bb.n(iN).foil.nCr     = bb.n(iN).foil.n - bb.n(iN).foil.nFa;
    [bb.n(iN).foil.pCr, bb.n(iN).foil.ciCr]     = binofit(bb.n(iN).foil.nCr, bb.n(iN).foil.n);
    
    
    for iL = 1:2
         % cue:
        bb.n(iN).cue.loc(iL).n        = sum(bb.ix.n(iN).cueLoc(:,iL));
        % cue - hit:
        bb.n(iN).cue.loc(iL).nHit     = sum(bb.ix.n(iN).cueHitLoc(:,iL));
        [bb.n(iN).cue.loc(iL).pHit, bb.n(iN).cue.loc(iL).ciHit]     = binofit(bb.n(iN).cue.loc(iL).nHit, bb.n(iN).cue.loc(iL).n);
        % cue - miss:
        bb.n(iN).cue.loc(iL).nMiss     = bb.n(iN).cue.loc(iL).n - bb.n(iN).cue.loc(iL).nHit;
        [bb.n(iN).cue.loc(iL).pMiss, bb.n(iN).cue.loc(iL).ciMiss]   = binofit(bb.n(iN).cue.loc(iL).nMiss, bb.n(iN).cue.loc(iL).n);

        % foil:
        bb.n(iN).foil.loc(iL).n        = sum(bb.ix.n(iN).foilLoc(:,iL));
        % foil - false alarm:
        bb.n(iN).foil.loc(iL).nFa     = sum(bb.ix.n(iN).foilFaLoc(:,iL));
        [bb.n(iN).foil.loc(iL).pFa, bb.n(iN).foil.loc(iL).ciFa]     = binofit(bb.n(iN).foil.loc(iL).nFa, bb.n(iN).foil.loc(iL).n);
        % foil - correct reject:
        bb.n(iN).foil.loc(iL).nCr     = bb.n(iN).foil.loc(iL).n - bb.n(iN).foil.loc(iL).nFa;
        [bb.n(iN).foil.loc(iL).pCr, bb.n(iN).foil.loc(iL).ciCr]     = binofit(bb.n(iN).foil.loc(iL).nCr, bb.n(iN).foil.loc(iL).n);
    
    end
end