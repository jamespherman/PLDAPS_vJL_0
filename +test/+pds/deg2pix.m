function pix = deg2pix(deg, p)
% deg2pix convert degrees of visual angle into pixels
%
% pix = deg2pix(deg, p)

pix = round(tand(deg) * p.rig.viewdist * p.rig.screenhpix / p.rig.screenh);

end