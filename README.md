# PLDAPS_vK2: A MATLAB-based Framework for Psychophysics

Written in the great winter of 2018, PLDAPS_vK2 is a flexible framework for conducting neurophysiology and psychophysics experiments written in MATLAB. It is based on the original PLDAPS (Plexon, Datapixx, Psychtoolbox) system (Eastman and Huk, 2012), but has been re-engineered for better organization, modularity, and ease of use.

## Core Concepts

The framework is built around a few key concepts that every user should understand.

### The "Quintet" of Task Files

Every experimental task in PLDAPS_vK2 is defined by a "quintet" of five core M-files. These files control the entire lifecycle of an experiment:

1.  **`_settings.m`**: This file initializes all the parameters for your task. It defines trial conditions, timing, stimulus properties, and any other variables you need.
2.  **`_init.m`**: This script is run once at the beginning of an experiment when you click "Initialize" in the GUI. It's used for setup that only needs to happen once, like initializing hardware, loading stimuli, or setting up online plots.
3.  **`_next.m`**: This script is executed before the start of every single trial. Its job is to set up the specific parameters for the *next* trial (e.g., picking a target location, setting the stimulus condition).
4.  **`_run.m`**: This is the heart of a trial. It contains a `while` loop that implements the trial's state machine. This loop executes frame-by-frame, checking for subject responses (eye movements, joystick), updating stimuli, and transitioning between states (e.g., from "wait for fixation" to "show stimulus").
5.  **`_finish.m`**: This script is executed at the end of every trial. It's used for saving data, updating performance metrics, and cleaning up before the next trial begins.

### The Main Data Structure: `p`

All information in the framework is stored and passed around in a single, large structure named `p`. This structure contains everything from hardware settings to trial data. The most important sub-structures are:

-   `p.trVars`: Holds variables that can change on a trial-by-trial basis. These are the parameters you can control from the GUI.
-   `p.trData`: Stores the data collected during a single trial (e.g., eye position, event times).
-   `p.status`: Contains variables that track the overall status of the experiment (e.g., trial counts, performance).
-   `p.rig`: Stores rig-specific hardware configurations.

## Directory Structure

The repository is organized into several key directories:

-   `+pds/`: A core library of shared functions (a MATLAB "package") used across all tasks. These functions handle common operations like getting eye/joystick data (`pds.getEyeJoy.m`), delivering rewards (`pds.deliverReward.m`), and managing hardware.
-   `tasks/`: This directory contains all the experimental tasks. Each subdirectory within `tasks/` is a separate experiment, containing its own quintet of files and `supportFunctions`.
-   `+rigConfigFiles/`: Contains configuration files for different experimental setups (rigs). These files define hardware-specific parameters like screen dimensions and joystick calibrations.
-   `stimuli/`: A directory for storing stimulus files (images, movies, etc.).
-   `data_dictionaries/`: Contains detailed documentation (data dictionaries) for the data structures saved by various tasks.

## Getting Started: Running an Experiment

1.  **Launch the GUI**: Start MATLAB and run `PLDAPS_vK2_GUI.m`.
2.  **Select a Settings File**: Click the "Browse" button in the "Settings Files" panel. Navigate to a task directory inside `tasks/` and select the `_settings.m` file for the experiment you want to run.
3.  **Initialize**: Click the "Initialize" button. This will load all the parameters from the settings file and run the task's `_init.m` script to prepare the experiment. The "Control Parameters" and "Status Values" panels will populate with the task's variables.
4.  **Run the Experiment**: Click the "Run" toggle button to start the experiment. The GUI will now loop through the `_next.m`, `_run.m`, and `_finish.m` files for each trial. You can pause or stop the experiment by toggling the "Run" button off.

## Creating a New Task

To create a new experiment:

1.  Create a new subdirectory in the `tasks/` directory.
2.  Inside your new task directory, create the five core files: `yourTask_settings.m`, `yourTask_init.m`, `yourTask_next.m`, `yourTask_run.m`, and `yourTask_finish.m`. You can copy and modify these from an existing task.
3.  Create a `supportFunctions/` subdirectory for any helper functions that are specific to your new task.
4.  Implement the logic for your experiment within these five files.

## Rig Configuration

If you are setting up a new experimental rig, you will need to create a new rig configuration file.

1.  Go to the `+rigConfigFiles/` directory.
2.  Copy an existing file (e.g., `rigConfig_rig1.m`) and rename it for your new rig.
3.  Edit the file to match your hardware's specifications. This includes:
    *   Screen viewing distance and dimensions (`p.rig.viewdist`, `p.rig.screenh`).
    *   Joystick voltage ranges (`p.rig.joyVoltageMin`, `p.rig.joyVoltageMax`, etc.).
    *   DataPixx/ViewPixx settings.
4.  In your task's `_settings.m` file, make sure you load the correct rig configuration file.

## Dependencies

This framework requires the following dependencies to be installed and on the MATLAB path:

-   **MATLAB**
-   **Psychtoolbox-3**
-   **DataPixx/ViewPixx Toolbox**: Required for interacting with VPixx hardware.
