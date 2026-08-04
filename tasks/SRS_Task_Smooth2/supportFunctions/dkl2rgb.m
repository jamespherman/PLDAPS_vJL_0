function [r,g,b] = dkl2rgb(x,varargin)

% rgb = dkl2rgb(x,bgRGB)

if(nargin>1)
    bgRGB = round(varargin{1}*255);
else
    bgRGB = round([0.5 0.5 0.5]*255);
end

% Load the rotation matrix
global M_dkl2rgb

% Load the gamma correction LUTs
global Rg Gg Bg

% Convert from DKL to RGB
rgb = round((0.5 + M_dkl2rgb*x/2)*255);

% Find "bad" values (out of RGB range).
bad = sum(rgb>255 |rgb<0)>0;

% Replace "bad" values with the background color.
rgb(:,bad) = bgRGB(ones(nnz(bad),1),:)';

% Gamma correct
r = Rg(rgb(1,:)+1);
g = Gg(rgb(2,:)+1);
b = Bg(rgb(3,:)+1);
end

function M_dkl2rgb = getdkl(monxyY)
%------------------------------------------------------------------------------
% compute dkl2rgb conversion matrix from moncie coordinates
% (compare function "getdkl" in color.c)

x = monxyY(:,1); y = monxyY(:,2); Y = monxyY(:,3);
if prod(y) == 0, error('y column contains zero value.'), end
xyz = [x y 1-x-y];
white = Y/2;

% Smith & Pokorny cone fundamentals
% V. C. Smith & J. Pokorny (1975), Vision Res. 15, 161-172.
M = [ 0.15514  0.54312  -0.03286
    -0.15514  0.45684   0.03286
    0.0      0.0       0.01608];

RGB = xyz*M'; % R, G  and B cones (i.e, long, middle and short wavelength)

RG_sum = RGB(:,1) + RGB(:,2); % R G sum
R = RGB(:,1)./RG_sum;%similar to MacLeod-Boynton?
B = RGB(:,3)./RG_sum;
G = 1 - R;

% alternative implementation of last 4 lines
%RGB = RGB./repmat(RGB(:,1) + RGB(:,2), 1, 3);
%R = RGB(:,1); G = RGB(:,2); B = RGB(:, 3);

% constant blue axis
a = white(1)*B(1);
b = white(1)*(R(1)+G(1));
c = B(2);
d = B(3);
e = R(2)+G(2);
f = R(3)+G(3);
dGcb = (a*f/d - b)/(c*f/d - e); % solve x
dBcb = (a*e/c - b)/(d*e/c - f); % solve y

% tritanopic confusion axis
a = white(3)*R(3);
b = white(3)*G(3);
c = R(1);
d = R(2);
e = G(1);
f = G(2);
dRtc = (a*f/d - b)/(c*f/d - e); % solve x
dGtc = (a*e/c - b)/(d*e/c - f); % solve y

IMAX = 1;
M_dkl2rgb = IMAX * [1        1         dRtc/white(1)
    1  -dGcb/white(2)  dGtc/white(2)
    1  -dBcb/white(3)     -1];
end
