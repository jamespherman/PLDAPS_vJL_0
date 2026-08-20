# i1Pro MEX

`I1.mexa64` is the directly callable X-Rite i1Pro MEX used by the `i1*` actions
(`I1('IsConnected')`, `I1('Calibrate')`, `I1('TriggerMeasurement')`, ...).

It lives here, in a plain folder rather than in `+pds/`, because MATLAB exposes
files inside a package directory only as `pds.I1(...)`. The actions call the
bare name `I1(...)`, so the MEX has to sit on the path outside a package.

Resolve this folder with `pds.i1MexFolder` rather than hardcoding a path. The
actions previously pointed at `/home/herman_lab/OneDrive/Code/i1`, which made
calibration depend on a cloud mount and on one machine's home directory.

**Keep this folder to the MEX alone.** The actions `addpath(..., '-begin')` it,
so anything else added here shadows the rest of the repo. The OneDrive folder
also held a June-2024 `initClut.m`, which silently shadowed the current
`tasks/SRS_Task_Smooth/supportFunctions/initClut.m` for the remainder of any
MATLAB session in which an i1 action had run.
