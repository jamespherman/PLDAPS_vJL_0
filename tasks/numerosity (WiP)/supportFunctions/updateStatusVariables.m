function p = updateStatusVariables(p)
%
% p = updateStatusVariables(p)
%

% For visual trials
p.status.visTrials = p.status.visTrials + ...
    (p.trVars.trialType == 1);

p.status.visTrialsOneStimNumHits = p.status.visTrialsOneStimNumHits + ...
    (p.trVars.trialType == 1 && p.trVars.numStim == 1 && p.trData.trialEndState == p.state.correctTarget);
p.status.visTrialsOneStimNumMisses = p.status.visTrialsOneStimNumMisses + ...
    (p.trVars.trialType == 1 && p.trVars.numStim == 1 && p.trData.trialEndState == p.state.wrongTarget);

p.status.visTrialsTwoStimNumHits = p.status.visTrialsTwoStimNumHits + ...
    (p.trVars.trialType == 1 && p.trVars.numStim == 2 && p.trData.trialEndState == p.state.correctTarget);
p.status.visTrialsTwoStimNumMisses = p.status.visTrialsTwoStimNumMisses + ...
    (p.trVars.trialType == 1 && p.trVars.numStim == 2 && p.trData.trialEndState == p.state.wrongTarget);


% For microstim trials

p.status.microstimTrials = p.status.microstimTrials + (p.trVars.trialType == 2);

p.status.microstimTrialsOneStimNumHits = ...
    p.status.microstimTrialsOneStimNumHits + ...
    (p.trVars.trialType == 2 && p.trVars.numStim == 1 && p.trData.trialEndState == p.state.correctTarget);
p.status.microstimTrialsOneStimNumMisses = ...
    p.status.microstimTrialsOneStimNumMisses + ...
    (p.trVars.trialType == 2 && p.trVars.numStim == 1 && p.trData.trialEndState == p.state.wrongTarget);

p.status.microstimTrialsTwoStimNumHits = ...
    p.status.microstimTrialsTwoStimNumHits + ...
    (p.trVars.trialType == 2 && p.trVars.numStim == 2 && p.trData.trialEndState == p.state.correctTarget);
p.status.microstimTrialsTwoStimNumMisses = ...
    p.status.microstimTrialsTwoStimNumMisses + ...
    (p.trVars.trialType == 2 && p.trVars.numStim == 2 && p.trData.trialEndState == p.state.wrongTarget);


% If we want to track based on spacing/ITI and current threshold multiplier
%{
if p.trVars.trialType == 2
    
    p.status.microstimTrials = p.status.microstimTrials + (p.trVars.trialType == 2);
    
    % Spatial
    if p.init.exptType == 'spatial'
        p.status.microstimTrialsOneStimNumHits (p.currentThresholdMultiplier) = ...
            p.status.microstimTrialsOneStimNumHits (p.currentThresholdMultiplier) + ...
            (p.trVars.numStim == 1 && p.trData.trialEndState == p.state.correctTarget);
        p.status.microstimTrialsOneStimNumMisses (p.currentThresholdMultiplier) = ...
            p.status.microstimTrialsOneStimNumMisses (p.currentThresholdMultiplier) + ...
            (p.trVars.numStim == 1 && p.trData.trialEndState == p.state.wrongTarget);
        
        p.status.microstimTrialsTwoStimNumHits (p.trVars.interElectrodeSpacing, p.currentThresholdMultiplier) = ...
            p.status.microstimTrialsTwoStimNumHits (p.trVars.interElectrodeSpacing, p.currentThresholdMultiplier) + ...
            (p.trVars.numStim == 2 && p.trData.trialEndState == p.state.correctTarget);
        p.status.microstimTrialsTwoStimNumMisses (p.trVars.interElectrodeSpacing, p.currentThresholdMultiplier) = ...
            p.status.microstimTrialsTwoStimNumMisses (p.trVars.interElectrodeSpacing, p.currentThresholdMultiplier) + ...
            (p.trVars.numStim == 2 && p.trData.trialEndState == p.state.wrongTarget);
    end
    
    
    % Temporal
    if p.init.exptType == 'temporal'
        
    end

end
%}


p.status.trialsLeftInBlock  = nnz(p.status.trialsArrayRowsPossible);


% 
% % was the last trial a "two patch" trial?
% twoPatch    = p.trVars.cueOn & p.trVars.foilOn;
% 
% % was the last trial location 1?
% loc1 = p.init.trialsArray(p.trVars.currentTrialsArrayRow,1) == 1;
% 
% % compute hit / correct reject counts and rates for each location
% % separately for single patch and two patch.
% p.status.cue1CtLoc1                 = p.status.cue1CtLoc1 + double(~twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of single patch cue change trials at location 1
% p.status.foil1CtLoc1                = p.status.foil1CtLoc1 + double(~twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of single patch foil change trials at location 1
% p.status.cue1CtLoc2                 = p.status.cue1CtLoc2 + double(~twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of single patch cue change trials at location 2
% p.status.foil1CtLoc2                = p.status.foil1CtLoc2 + double(~twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of single patch foil change trials at location 2
% p.status.cue2CtLoc1                 = p.status.cue2CtLoc1 + double(twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of two patch cue change trials at location 1
% p.status.foil2CtLoc1                = p.status.foil2CtLoc1 + double(twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of two patch foil change trials at location 1
% p.status.cue2CtLoc2                 = p.status.cue2CtLoc2 + double(twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of two patch cue change trials at location 2
% p.status.foil2CtLoc2                = p.status.foil2CtLoc2 + double(twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of two patch foil change trials at location 2
% 
% p.status.hc1Loc1                    = p.status.hc1Loc1 + double(~twoPatch & loc1 & p.trData.trialEndState == p.state.hit); % hit count for single patch at location 1
% p.status.crc1Loc1                   = p.status.crc1Loc1 + double(~twoPatch & loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for single patch at location 1
% p.status.hc1Loc2                    = p.status.hc1Loc2 + double(~twoPatch & ~loc1 & p.trData.trialEndState == p.state.hit); % hit count for single patch at location 2
% p.status.crc1Loc2                   = p.status.crc1Loc2 + double(~twoPatch & ~loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for single patch at location 2
% p.status.hc2Loc1                    = p.status.hc2Loc1 + double(twoPatch & loc1 & p.trData.trialEndState == p.state.hit); % hit count for two patch at location 1
% p.status.crc2Loc1                   = p.status.crc2Loc1 + double(twoPatch & loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for two patch at location 1
% p.status.hc2Loc2                    = p.status.hc2Loc2 + double(twoPatch & ~loc1 & p.trData.trialEndState == p.state.hit); % hit count for two patch at location 2
% p.status.crc2Loc2                   = p.status.crc2Loc2 + double(twoPatch & ~loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for two patch at location 2
% 
% p.status.hr1Loc1                    = p.status.hc1Loc1 / p.status.cue1CtLoc1; % hit rate for single patch at location 1
% p.status.cr1Loc1                    = p.status.crc1Loc1 / p.status.foil1CtLoc1; % correct reject rate for single patch at location 1
% p.status.hr1Loc2                    = p.status.hc1Loc2 / p.status.cue1CtLoc2; % hit rate for single patch at location 2
% p.status.cr1Loc2                    = p.status.crc1Loc2 / p.status.foil1CtLoc2; % correct reject rate for single patch at location 2
% p.status.hr2Loc1                    = p.status.hc2Loc1 / p.status.cue2CtLoc1; % hit rate for two patch at location 1
% p.status.cr2Loc1                    = p.status.crc2Loc1 / p.status.foil2CtLoc1; % correct reject rate for two patch at location 1
% p.status.hr2Loc2                    = p.status.hc2Loc2 / p.status.cue2CtLoc2; % hit rate for two patch at location 2
% p.status.cr2Loc2                    = p.status.crc2Loc2 / p.status.foil2CtLoc2; % correct reject rate for two patch at location 2
% 
% % calculate how many trials are left in the block
% p.status.trialsLeftInBlock          = nnz(p.status.trialsArrayRowsPossible);

end
