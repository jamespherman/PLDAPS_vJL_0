function p = timingMachine(p)
%TIMINGMACHINE Update time-dependent cue and stimulus visibility.

Datapixx('RegWrRd');
timeNow = Datapixx('GetTime') - p.trData.timing.trialStart;
p.trData.timing.frameNow = fix(timeNow * p.rig.refreshRate);

if p.trData.timing.fixAq > 0
    timeFromFixAq = timeNow - p.trData.timing.fixAq;
    cueEndTime = p.trVars.fix2CueIntvl + p.trVars.cueDur;

    if (timeFromFixAq >= p.trVars.fix2CueIntvl) && ...
            (timeFromFixAq < cueEndTime)
        p.trVars.cueIsOn = true;
        p.init.strb.addValueOnce(p.init.codes.cueOn);
    else
        p.trVars.cueIsOn = false;
        p.init.strb.addValueOnce(p.init.codes.cueOff);
    end

    if (timeFromFixAq >= p.trVars.fix2StimOnIntvl) && ...
            (timeFromFixAq < p.trVars.fix2StimOffIntvl)
        p.trVars.cueStimIsOn = p.trVars.cueOn;
        p.trVars.foilStimIsOn = p.trVars.foilOn;
        p.init.strb.addValueOnce(p.init.codes.stimOn);
    elseif timeFromFixAq >= p.trVars.fix2StimOffIntvl
        p.trVars.cueStimIsOn = false;
        p.trVars.foilStimIsOn = false;
        p.init.strb.addValueOnce(p.init.codes.stimOff);
    end
end
end
