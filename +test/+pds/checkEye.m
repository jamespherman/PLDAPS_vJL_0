function out = checkEye(pass, Eye, WinDim)
% Check if eye position is within square window (around zero).
%
% out = checkEye(pass, Eye, WinDim)

out = all(abs(Eye)<WinDim) || pass;

end