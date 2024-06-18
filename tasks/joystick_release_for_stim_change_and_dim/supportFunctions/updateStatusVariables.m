function p = updateStatusVariables(p)
%
% p = updateStatusVariables(p)
%

% keep a running log of trial end states, reaction times, and dimVals. If
% only the peripheral stimulus dimmed on this trial, define this as a
% "negative" dimVal for the purposes of plotting, if this was a no-change
% trial, instead define the dimVal as 0.
p.status.trialEndStates(p.status.iTrial)    = p.trData.trialEndState;
p.status.reactionTimes(p.status.iTrial)     = p.trData.timing.reactionTime;
p.status.dimVals(p.status.iTrial)           = p.trData.dimVal * ...
    ((-1)^p.trVars.isStimChgNoDim) * p.trVars.isStimChangeTrial;
p.status.nStim(p.status.iTrial)             = p.stim.nStim;

p.status.chgLoc(p.status.iTrial) = p.stim.stimChgIdx;

% iterate "good trial" count
p.status.iGoodTrial = p.status.iGoodTrial + ...
    double(~p.trData.trialRepeatFlag);


% update count of trials with 1 / 2 / 3 / 4 stimuli:
switch p.stim.nStim
    case 1
        if p.trVars.isStimChangeTrial
            p.status.tc1stim = p.status.tc1stim + 1;
            p.status.hc1stim = p.status.hc1stim + ...
                (p.trData.trialEndState == p.state.hit);
            p.status.hr1stim = p.status.hc1stim / p.status.tc1stim;
        end
    case 2
        if p.trVars.isStimChangeTrial
            p.status.tc1stim = p.status.tc2stim + 1;
            p.status.hc1stim = p.status.hc2stim + ...
                (p.trData.trialEndState == p.state.hit);
            p.status.hr1stim = p.status.hc2stim / p.status.tc2stim;
        end
    case 3
        if p.trVars.isStimChangeTrial
            p.status.tc3stim = p.status.tc3stim + 1;
            p.status.hc3stim = p.status.hc3stim + ...
                (p.trData.trialEndState == p.state.hit);
            p.status.hr3stim = p.status.hc3stim / p.status.tc3stim;
        end
    case 4
        if p.trVars.isStimChangeTrial
            p.status.tc4stim = p.status.tc4stim + 1;
            p.status.hc4stim = p.status.hc4stim + ...
                (p.trData.trialEndState == p.state.hit);
            p.status.hr4stim = p.status.hc4stim / p.status.tc4stim;
        end
end

switch p.trData.trialEndState
    case p.state.hit
        p.status.totalHits = p.status.totalHits + 1;
    case p.state.miss
        p.status.totalMisses = p.status.totalMisses + 1;
    case p.state.fa
        if p.trVars.isStimChangeTrial
            p.status.totalChangeFalseAlarms = p.status.totalChangeFalseAlarms + 1;
        else
            p.status.totalNoChangeFalseAlarms = p.status.totalNoChangeFalseAlarms + 1;
        end
    case p.state.cr
        p.status.totalCorrectRejects = p.status.totalCorrectRejects + 1;
end

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
p.status.trialsLeftInBlock      = nnz(p.status.trialsArrayRowsPossible);


% if we're using QUEST, update the threshold estimate
if p.trVars.useQuest
    p.status.questThreshEst = 10^QuestMean(p.init.questObj);
end

end
