# Tokens Task: Data Analysis Plan

This document outlines the key components of the 'tokens' task in the PLDAPS codebase, designed to facilitate data analysis. It covers the task's goal, trial structure, experimental variables, and critical timing parameters for both the 'tokens_main' and 'tokens_AV' variants.

## 1. Task Goal

The primary objective for the subject is to learn the association between different visual cues and the statistical distributions of rewards they predict. On each trial, the subject is presented with a visual cue, and if they successfully hold fixation, they are awarded a variable number of "tokens." These tokens are then "cashed in" one by one for juice reward. The task is designed to probe how subjects learn and represent reward uncertainty, with some cues predicting a normally distributed number of tokens and others predicting a uniformly distributed number. The 'tokens_AV' variant adds an audiovisual component to explore multisensory integration in this process.

## 2. Trial Structure & State Machine

The chronological flow of each trial is governed by a state machine defined in `tasks/tokens/tokens_run.m`. The key states and events are as follows:

- **p.state.trialBegun (State 1):** The trial officially starts. The end time for the Inter-Trial Interval (ITI) is calculated.
- **p.state.waitForITI (State 2):** A pause between trials. The screen is blank. The trial proceeds to the next state only after the calculated ITI duration has elapsed.
- **p.state.showCue (State 3):** The visual cue (an image file) is displayed on the screen, indicating the upcoming reward conditions.
- **p.state.waitForFix (State 4):** The system waits for the subject's gaze to enter the predefined fixation window around the cue. A timeout (`p.trVars.fixAqDur`) aborts the trial to a `nonStart` state if fixation is not achieved.
- **p.state.holdFix (State 5):** The subject must maintain fixation within the window for a specified duration (`p.trVars.fixDur`). If the subject's gaze leaves the window, the trial is aborted to a `fixBreak` state.
- **p.state.showOutcome (State 6):** Once fixation is successfully held, the visual cue is replaced by a display of the tokens awarded for that trial. In 'tokens_AV' trials, a flickering visual and a sweeping auditory tone are presented.
- **p.state.cashInTokens (State 7):** After a brief delay (`p.trVars.outcomeDelay`), the tokens are "cashed in." For each token awarded, a pulse of juice is delivered, separated by a short pause (`p.trVars.juicePause`).
- **p.state.success (State 21):** The trial is successfully completed after all tokens are cashed in.
- **p.state.fixBreak (State 11):** An aborted trial state, reached if the subject breaks fixation during the `holdFix` state.
- **p.state.nonStart (State 12):** An aborted trial state, reached if the subject fails to acquire fixation during the `waitForFix` state.

## 3. Independent Variables (Experimental Factors)

These variables are manipulated across trials to form the different experimental conditions. They are defined in `tasks/tokens/supportFunctions/initTrialStructure.m` and selected for each trial in `tasks/tokens/supportFunctions/nextParams.m`.

### For `tokens_main`:
- **`dist`**: The underlying reward distribution associated with the cue.
  - `1`: Normal distribution (mean = 5).
  - `2`: Uniform distribution (range = 1-9).
  - `0`: Fixed reward (value = 5), typically used for uncued trials.
- **`cueFile`**: A string specifying the `.jpg` image file used as the visual cue (e.g., `'famNorm_01.jpg'`). Cues are categorized by familiarity (`fam` vs. `nov`) and the distribution they predict (`Norm` vs. `Uni`).
- **`isFixationRequired`**: A boolean indicating whether the subject must perform the fixation task (`true`) or if it's a "free reward" trial (`false`).
- **`isToken`**: A boolean determining if tokens are displayed during the outcome (`true`) or if the reward is delivered without a visual token representation (`false`).

### For `tokens_AV`:
Includes all variables from `tokens_main`, plus:
- **`avProbability`**: The probability that the outcome will be accompanied by an audiovisual stimulus (flickering tokens and a sweeping sound).
  - `0`: Visual only.
  - `0.5`: 50% chance of being an AV trial.
  - `1`: Always an AV trial.
- **`isAVTrial`**: A boolean (`true`/`false`) determined on each trial based on `avProbability`, indicating whether the trial presented audiovisual stimuli.

## 4. Key Dependent Variables (Performance Measures)

These are the primary outcomes recorded on each trial to assess performance. They are defined in the `p.init.trDataInitList` within the settings files and their values are recorded in the `p.trData` structure.

- **`trialEndState`**: An integer code representing the final outcome of the trial (e.g., `p.state.success`, `p.state.fixBreak`, `p.state.nonStart`). This is the most critical measure of trial success.
- **`rewardAmt`**: The number of tokens (and thus juice pulses) delivered on the current trial, drawn from the distribution indicated by the cue.
- **`timing.fixAq`**: The timestamp (in seconds from trial start) when fixation was first acquired. Can be used to calculate reaction time to the cue.
- **`timing.fixBreak`**: The timestamp when a fixation break occurred, if applicable.
- **`timing.cueOn`**: The timestamp when the cue appeared on the screen.
- **`timing.outcomeOn`**: The timestamp when the token outcome was displayed.
- **Eye-tracking Data**:
  - `eyeX`, `eyeY`: Raw X and Y coordinates of eye position.
  - `eyeP`: Pupil diameter.
  - `eyeT`: Timestamp for each eye sample.

## 5. Critical Timing Parameters

These are user-configurable variables (defined in `p.trVarsInit` in the settings files) that control the pacing and difficulty of the trial.

- **`fixDur`**: The required duration (in seconds) for which the subject must maintain fixation on the cue.
- **`fixAqDur`**: The maximum time (in seconds) allowed for the subject to acquire fixation after the cue appears.
- **`itiMean`**, **`itiMin`**, **`itiMax`**: Parameters defining the truncated exponential distribution from which the Inter-Trial Interval (ITI) is drawn for each trial.
- **`outcomeDelay`**: The duration (in seconds) of the pause after the tokens are shown but before they begin to be cashed in for reward.
- **`juicePause`**: The duration (in seconds) of the pause between each individual juice pulse when cashing in multiple tokens.
- **`flickerFramesPerColor`** (`tokens_AV` only): An integer that controls the speed of the token flicker in AV trials. It defines how many screen frames each color in the flicker cycle is displayed for.
