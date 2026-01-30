# Conflict Task: Target Timing Analysis

This report analyzes the target onset timing relative to the fixation offset (the "go cue") and the timing between the two target onsets in the `conflict_task`.

## 1. Go Signal Timing (Fixation Offset)

The "Go Signal" is defined as the moment the fixation point disappears, signaling the subject to make a saccade.

*   **Logic:** The time of the Go Signal is calculated relative to the time of fixation acquisition (`fixAq`).
*   **Variable:** `p.trVars.timeGoSignal`
*   **Calculation:** The duration is drawn from a uniform distribution between a minimum and maximum hold duration.
    *   `p.trVars.timeGoSignal = unifrnd(p.trVars.fixHoldDurationMin, p.trVars.fixHoldDurationMax);`
*   **Parameters:**
    *   `fixHoldDurationMin = 1.0` seconds (1000 ms)
    *   `fixHoldDurationMax = 1.4` seconds (1400 ms)
*   **Source Code:**
    *   Parameters: `tasks/conflict_task/conflict_task_settings.m`
    *   Calculation: `tasks/conflict_task/supportFunctions/nextParams.m` (in `timingInfo` function)

## 2. Target Onset Timing Relative to Go Signal (Delta-T)

The timing of the target stimuli onset is manipulated relative to the Go Signal using a variable called `deltaT` (Stimulus Onset Asynchrony).

*   **Logic:** The target onset time (`timeStimOnset`) is calculated by adding `deltaT` to the `timeGoSignal`.
    *   `timeStimOnset = timeGoSignal + deltaT`
*   **Variable:** `p.trVars.deltaT` (in ms)
*   **Relationship:**
    *   **Negative Delta-T:** Stimuli appear **before** the Go Signal (Fixation Offset).
    *   **Positive Delta-T:** Stimuli appear **after** the Go Signal (Fixation Offset).
    *   **Zero Delta-T:** Stimuli appear **simultaneously** with the Go Signal.
*   **Specific Values:** The task uses 6 specific `deltaT` values:
    *   **-150 ms**
    *   **-100 ms**
    *   **-50 ms**
    *   **0 ms**
    *   **+50 ms**
    *   **+100 ms**
*   **Source Code:**
    *   Delta-T Values Definition: `tasks/conflict_task/supportFunctions/initTrialStructure.m`
    *   Timing Calculation: `tasks/conflict_task/supportFunctions/nextParams.m` (in `timingInfo` function)

## 3. Timing Between the Two Target Onsets

The task displays two targets: one High Salience and one Low Salience.

*   **Logic:** Both targets are controlled by a single visibility flag: `p.trVars.stimuliVisible`.
*   **Mechanism:**
    *   In the `timingMachine` (in `conflict_task_run.m`), when `timeNow >= timeStimOnset`, the flag `p.trVars.stimuliVisible` is set to `true`.
    *   In the `drawMachine` (in `conflict_task_run.m`), if `p.trVars.stimuliVisible` is true, **both** target bullseyes are drawn in the same frame.
*   **Conclusion:** The two targets always appear **simultaneously**. There is no timing difference (SOA) between the onset of Target A and Target B.
*   **Source Code:**
    *   Execution Logic: `tasks/conflict_task/conflict_task_run.m` (in `timingMachine` and `drawMachine` functions)

## Summary Table

| Parameter | Value / Range | Description |
| :--- | :--- | :--- |
| **Fixation Hold (Go Signal)** | 1000 - 1400 ms | Randomized duration before fixation offset. |
| **Delta-T Values** | -150, -100, -50, 0, 50, 100 ms | Time of Target Onset relative to Go Signal. |
| **Target A vs Target B Timing** | 0 ms | Simultaneous onset. |
