function p = initRipple(p)
%   p = initRipple(p)
%
% Initialize connection to Ripple "NIP", and define recording channels:
%
%

% Initialize connection to ripple NIP.
p.rig.ripple.status = pds.xippmex;

% Check to see if NIP is turned on (if p.rig.ripple.status is TRUE):
if p.rig.ripple.status
    p.rig.ripple.status = pds.xippmex('led', 'f1');
end

% if we DON'T WANT TO USE RIPPLE...
% p.rig.ripple.status = p.trVarsInit.connectRipple;

% get recording channels (if ripple is connected, and we want to use it):
if p.rig.ripple.status && p.trVarsInit.connectRipple
    p.rig.ripple.recChans = ...
        [pds.xippmex('elec','micro'), ...
        pds.xippmex('elec','nano')];
end