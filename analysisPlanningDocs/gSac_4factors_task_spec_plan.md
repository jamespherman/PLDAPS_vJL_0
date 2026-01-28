# Plan: gSac_4factors Task Design Specification Document

## Objective
Create a comprehensive markdown document that describes all details of the gSac_4factors task, focusing on task-relevant information (stimuli, spatial locations, temporal sequencing) rather than implementation details.

## Source Files Analyzed
1. **gSac_4factors_settings.m** - Default parameters, states, timing values, stimulus configuration
2. **gSac_4factors_init.m** - One-time setup (textures, trial structure, hardware)
3. **gSac_4factors_run.m** - State machine, drawing routines, timing logic
4. **gSac_4factors_next.m** - Per-trial parameter setup
5. **gSac_4factors_finish.m** - Post-trial processing, saccade metrics
6. **initTrialStructure.m** - Factorial design and trial array construction
7. **nextParams.m** - Trial type selection, location computation, timing
8. **initTargetLocationList.m** - Target location preset definitions
9. **initImageTextures.m** - Face/non-face image loading
10. **initClut.m** - Color lookup table with DKL color space definitions

## Document Structure

### 1. Task Overview
- Brief description of the memory-guided saccade paradigm
- The four experimental factors being manipulated

### 2. Experimental Factors
- **Stimulus Type/Salience**: Face, Non-Face, Bullseye (High/Low Salience)
- **Reward Magnitude**: High vs. Low reward amounts
- **Target Probability**: High-probability vs. low-probability locations
- **Target Location**: 4 locations derived from base position rotation

### 3. Stimuli
- **Fixation Point**: Black square frame at center
- **Target Stimuli**:
  - Face images (15 monkey faces)
  - Non-face images (120 objects)
  - Bullseye patterns (concentric rectangular rings in DKL color space)
- **Background Colors**: Grey (images) or DKL hues (bullseye)

### 4. Spatial Configuration
- Base target position and 90-degree rotation scheme
- Four target locations
- Hemifield organization (locations 1-2 vs 3-4)
- Window sizes for fixation and target

### 5. Temporal Structure (Trial Timeline)
- Joystick press requirement
- Fixation acquisition phase
- Target flash period (memory)
- Delay period (memory retention)
- Go signal (fixation offset)
- Saccade execution window
- Target hold requirement
- Reward delivery

### 6. Block and Half-Block Structure
- 2 blocks with 2 half-blocks each (4 half-blocks total)
- Probability manipulation by block
- Reward manipulation by half-block and hemifield
- Trial counts per condition

### 7. Trial Types Summary Table
- Complete enumeration of all conditions
- Trial repetitions per condition

### 8. Behavioral Requirements
- Joystick maintained throughout trial
- Eye position within windows
- Saccade latency constraints
- Target hold duration

### 9. Timing Parameters (Default Values)
- All temporal intervals with ranges

## Output
The specification will be saved to:
`tasks/gSac_4factors/gSac_4factors_task_design_specification.md`
