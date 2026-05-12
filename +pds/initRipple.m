function p = initRipple(p)
%   p = initRipple(p)
%
% Initialize connection to Ripple "NIP", and define recording channels:
%
%

% Initialize connection to ripple NIP.
p.rig.ripple.status = pds.xippmex;

% Query time from NIP multiple times. If NIP is powered on, times will be
% different:
nVals = 2;
tempTimeVals = zeros(nVals, 1);
for i = 1:nVals
    tempTimeVals(i) = pds.xippmex('time');
    WaitSecs(0.05);
end

% re-define "status" based on time values:
p.rig.ripple.status = diff(tempTimeVals) > 0;

% get recording channels (if ripple is connected, and we want to use it):
if p.rig.ripple.status && p.trVarsInit.connectRipple
    p.rig.ripple.recChans = ...
        [pds.xippmex('elec','micro'), ...
        pds.xippmex('elec','nano')];

    % if recChans is empty we have a problem - warn the user:
    if isempty (p.rig.ripple.recChans)
        warning(['Ripple is connected but there are no recording ...' ...
            'channels found!']);
    end

    % get stimulation channels
    p.rig.ripple.stimChans = pds.xippmex('elec', 'stim');

    if isempty (p.rig.ripple.stimChans)
        warning(['Ripple is connected but there are no stimulation ...' ...
            'channels found!']);
    end
end
