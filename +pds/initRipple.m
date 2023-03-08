function p = initRipple(p)
%   p = initRipple(p)
%
% Initialize connection to Ripple "NIP", and define recording channels:
%
%

% Initialize xippmex
p.rig.ripple.status = pds.xippmex;

% get recording channels (if ripple is connected):
if p.rig.ripple.status
    p.rig.ripple.recChans = ...
        [pds.xippmex('elec','micro'), ...
        pds.xippmex('elec','nano')];
end