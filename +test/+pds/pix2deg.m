function deg = pix2deg(pix, p)

% deg = pix2deg(pix, p)
%
% convert screen pixels (pix) into visual angle in degrees (deg)

deg = atand(pix * p.rig.screenh/(p.rig.viewdist * p.rig.screenhpix));