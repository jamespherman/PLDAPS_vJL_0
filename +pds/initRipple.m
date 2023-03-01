function p = initRipple(p)
%   p = initRipple(p)
%
% Initialize connection to Ripple "NIP", and define recording channels:
%
%

% Initialize xippmex
p.rig.ripple.status = pds.xippmex;
if p.rig.ripple.status ~= 1; warning('Not connected to Ripple');  end

% get recording channels:
p.rig.ripple.recChans = ...
    [pds.xippmex('elec','micro'), ...
    pds.xippmex('elec','nano')];