function k = barsweepRampFilterEnum(filterStr)
% k = pds.barsweepRampFilterEnum(filterStr)
%
% Map an iradon ramp-filter name to its integer strobe code.
%   1 = 'Ram-Lak'
%   2 = 'Hann'
%   3 = 'Shepp-Logan'
%   4 = 'Cosine'
%
% Used by the barsweep online RF mapping strobeList to encode
% p.trVars.rfRampFilter as a positive integer.

switch filterStr
    case 'Ram-Lak',     k = 1;
    case 'Hann',        k = 2;
    case 'Shepp-Logan', k = 3;
    case 'Cosine',      k = 4;
    otherwise
        error('pds:barsweepRampFilterEnum:unknownFilter', ...
            'Unknown iradon filter name "%s". Expected Ram-Lak, Hann, Shepp-Logan, or Cosine.', ...
            filterStr);
end

end
