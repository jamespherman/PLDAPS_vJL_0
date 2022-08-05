function p = rigConfig_rigF_20180717(p)

% this is the rig config file
% Here we note rig- and animal-specific details such as screen size or
% distance from screen etc. 
% 
% Please save the file in the format:
% 
%   rigConfig_rig#_yyyymmdd
% 
% where 
%   # is uppercase rig letter (e.g. "A") 
%   name is lowercase monkey name (e.g. ridley)
%   yyyymmdd is the date (e.g. 19830531)

% Geometry
p.rig.viewdist        = 410;      % viewing distance (mm)
p.rig.screenhpix      = 1200;     % screen height (pixels)
p.rig.screenh         = 302.40;   % screen height (mm)

% omniplex IP address
p.rig.omniplexIP = '128.231.132.53';

% open connection to omniplex PC MATLAB instance IF DESIRED
if p.rig.connectToOmniplex
    p = pds.openPortToServer(p);
end

end