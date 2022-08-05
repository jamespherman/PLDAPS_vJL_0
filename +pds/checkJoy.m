function out = checkJoy(pass, Joy, Th)
% checkJoy checks if the joystick voltage is above th or below th depending
% on the SIGN of JOY & TH. For example: if JOY & TH are both positive, the
% function checks JOY > TH, but if JOY & TH are both negative, the function
% checks JOY < TH. Meanwhile, the PASS-value controls whether the funciton
% defaults to a true-state. If PASS is true, the funtion always returns
% "true."
%
% out = checkJoy(pass, Joy, Th)
%

out = Joy > Th || pass;

end