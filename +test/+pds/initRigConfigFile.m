function p = initRigConfigFile(p)


if isempty(p.init.rigConfigFile)
    error('failed to load a valid rigConfigFile. Perhaps verify that the file is in your path?')
end

[~,tempName] = fileparts(p.init.rigConfigFile);

eval(['p = rigConfigFiles.' tempName '(p);']);
