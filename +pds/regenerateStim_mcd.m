function stim = regenerateStim_mcd(p)

% This functions is used to regenrate a stimulus, given a random seed, in
% the mcd task.
% It works by setting the random seed to the number set in
% p.trVArs.randSeedStim. Then it uses the stock functions (e.g. genDots) to
% generate the stimulus. 
% It tests that the stimulus was indeed generated accurately by comparing
% the last frame of the regenerated stimulus to the last frame of the
% stimulus that is saved in p.trVats.stimLastFrame. This is a CRITICAL
% step. If the two don't match, then we can't trust the regenerated
% stimulus....
%
% 20190217 - lnk wrote it
% 20190411 - lnk added comments


%%

% initialize the random number stream:
% (this should be identical to whatever is in the init function. There is no
% reason why this should ever be changed.
RandStream.setGlobalStream(RandStream('mt19937ar','Seed', 0));

nTrials = numel(p.trVars);

%%
for iTr = 1:nTrials
    
    % hack- genDots needs p with a single (i.e. 1 trial-worth) of trVars.
    % So I'm making 'pTr' ot look like 'p' but with 1 trVars field that is
    % for the current trial:
    pTr = p;
    pTr.trVars = p.trVars(iTr);
    
    %% Set the random seed:
    rng(pTr.trVars.randSeedStim);
    
    
    %% generate the stimulus:
    if pTr.stim.shittyDots
        % generate cue dots
        [cueDotsX, cueDotsY, cueDotsColors, cueDotsWidths] = ...
            genDots(pTr, 'cue');
        
        % generate foil dots
        [foilDotsX, foilDotsY, foilDotsColors, foilDotsWidths] = ...
            genDots(pTr, 'foil');
    else
        % generate cue dots
        [cueDotsX, cueDotsY, cueDotsColors, cueDotsWidths] = ...
            genDotsBigSquare_noCells(pTr, 'cue');
        
        % generate foil dots
        [foilDotsX, foilDotsY, foilDotsColors, foilDotsWidths] = ...
            genDotsBigSquare_noCells(pTr, 'foil');
        
    end
    
    
    %% verify that stim was generated accurately:
        
    % defining function that returns non-nan elements:
    nonan = @(x) x(~isnan(x));
    
    % verifying for the non-nan elements otherwise the assertion will
    % return a 0. Damn this is some butt ugly code. 
    if  all(nonan(pTr.trVars.stimLastFrame.cueDotsX) == nonan(cueDotsX(:,end))) && ...
        all(nonan(pTr.trVars.stimLastFrame.cueDotsY) == nonan(cueDotsY(:,end))) && ...
        all(nonan(pTr.trVars.stimLastFrame.foilDotsX) == nonan(foilDotsX(:,end))) && ...
        all(nonan(pTr.trVars.stimLastFrame.foilDotsY) == nonan(foilDotsY(:,end)))
        
        fprintf('Trial %d: Seeds matched. Boom shakalaka!\n', iTr)
        
        % pack up and go:
        stim(iTr).cueDotsX         = cueDotsX;
        stim(iTr).cueDotsY         = cueDotsY;
        stim(iTr).cueDotsColors    = cueDotsColors;
        stim(iTr).cueDotsWidths    = cueDotsWidths;
        stim(iTr).foilDotsX        = foilDotsX;
        stim(iTr).foilDotsY        = foilDotsY;
        stim(iTr).foilDotsColors   = foilDotsColors;
        stim(iTr).foilDotsWidths   = foilDotsWidths;
        
        
    else
        disp('YOUR SEEDS FAILED TO REGENRATE THE STIMULUS ACCURATELY')
        dips('THIS IS BIG NO NO')
        disp('RETURNING AN EMPTY stim STRUCT')
        disp('GET YOUR SHIT TOGETHER')
        
        % empty stim:
        stim = [];
    end
    
end




