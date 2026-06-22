function [xyWrap, needWrap] = circleWrap(thetaDeg, xy1, r)

% the way the "shittyDots" function works, the dots never have negative X/Y
% values. We need to compensate for this.
xy1 = xy1 - repmat(r*[1, 1], size(xy1, 1), 1);

% To do the main calculations (points of intersection between a line and a
% circle), we need two points along the line. First, we calculate "m" and
% "b" for each dot based on it's position and motion direction angle.
m = tand(thetaDeg);
b = xy1(:,2) - m.*xy1(:,1);

% Now we find another point along the same "path" (again for the purposes
% of the main calculations below).
xy2(:,1) = xy1(:,1) + 1;
xy2(:,2) = xy2(:,1).*m + b;

% We use the pair of points "xy1" and "xy2" to calculate "dx", "dy", "dr",
% and "D" which are used in the main calculation of the intersection
% points.
dx = xy2(:,1) - xy1(:,1);
dy = xy2(:,2) - xy1(:,2);
dr = (dx.^2 + dy.^2).^0.5;
D = xy1(:,1).*xy2(:,2) - xy2(:,1).*xy1(:,2);

% Calculate intersection points (between circle and each line of angle
% "thetaDeg" going through "xy1").
X(:,1) = (D.*dy - sign(dy).*dx.*(r^2*dr.^2 - D.^2).^0.5)./dr.^2;
X(:,2) = (D.*dy + sign(dy).*dx.*(r^2*dr.^2 - D.^2).^0.5)./dr.^2;
Y(:,1) = (-D.*dx - abs(dy).*(r^2*dr.^2 - D.^2).^0.5)./dr.^2;
Y(:,2) = (-D.*dx + abs(dy).*(r^2*dr.^2 - D.^2).^0.5)./dr.^2;

% We use the intersection points to find the length of the "secant" (line
% segment connecting the intersection points), and then use the secant
% length to move any dots that "needWrap" (have gone outside the circle).
% We calculate the components of each secant separatrely for X and Y ("dX"
% and "dY").
needWrap = (xy1(:,1).^2 + xy1(:,2).^2).^0.5 > r;
dX = abs(X(:,2) - X(:,1)).*needWrap.*sign(cosd(thetaDeg-180));
dY = abs(Y(:,2) - Y(:,1)).*needWrap.*sign(sind(thetaDeg-180));

% wrap (re/un-compensating for NO NEGATIVE X/Y values).
xyWrap = xy1 + [dX, dY] + repmat(r*[1, 1], size(xy1, 1), 1);

end