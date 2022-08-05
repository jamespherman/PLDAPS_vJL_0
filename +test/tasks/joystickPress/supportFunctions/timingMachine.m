function p = timingMachine(p)
%
% c = timingMachine(c)
%

% time is relative to trial Start
Datapixx('RegWrRd');
timeNow = Datapixx('GetTime') - p.trData.timing.trialStart;

% Also calculate a time in "frames" relative to trial-start
p.trData.timing.frameNow    = fix(timeNow * p.rig.refreshRate);

% SET COLORS AS A FUNCTION OF ELAPSED TIME

% function of time (and may span multiple states)
if p.trData.timing.fixAq > 0
    
    % time elapsed from fixation acquisition:
    timeFromFixAq = timeNow - p.trData.timing.fixAq;
    
    % Determine if cue should be on:
    if timeFromFixAq >= p.trVars.fix2CueIntvl && ...
            timeFromFixAq < (p.trVars.fix2CueIntvl + p.trVars.cueDur);
        p.trVars.cueIsOn       = true;
        p.init.strb.addValueOnce(p.init.codes.cueOn);
    else
        p.trVars.cueIsOn       = false;
        p.init.strb.addValueOnce(p.init.codes.cueOff);
    end

    % Determine if cue and or foil stimulus should be on:
    if timeFromFixAq >= p.trVars.fix2StimOnIntvl && ...
            timeFromFixAq < p.trVars.fix2StimOffIntvl  
        p.trVars.cueStimIsOn  = p.trVars.cueOn;
        p.trVars.foilStimIsOn  = p.trVars.foilOn;
        p.init.strb.addValueOnce(p.init.codes.stimOn);
        
    elseif timeFromFixAq >= p.trVars.fix2StimOffIntvl
        p.trVars.cueStimIsOn  = false;
        p.trVars.foilStimIsOn  = false;
        p.init.strb.addValueOnce(p.init.codes.stimOff);
    end
    
end