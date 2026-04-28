function dirlist = mydir(string)

% dirlist = mydir(string)

% use dir to get the names
fc = dir(string);

% get rid of all the dot-names
fc = {fc(~strcmp({fc(:).name}','.')).name}';

dirlist = fc(~strcmp(fc,'..'));