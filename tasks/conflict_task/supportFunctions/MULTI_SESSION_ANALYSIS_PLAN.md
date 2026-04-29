# Conflict Task Multi-Session Analysis Plan

**Date:** 2026-02-20
**Sessions:** Feb 9, 11, 13, 16, 18 (2026)
**Goal:** Evaluate whether saliency-driven vs. reward-driven behavioral regimes can be dissociated via gap/overlap timing manipulation, and recommend next steps.

---

## 1. Data Preparation

### 1.1 Session Inventory
| Session | File | Trials | Notes |
|---------|------|--------|-------|
| 20260209_t1010 | .mat exists | ~569 | Pre-refactor (phase-level rewards) |
| 20260211_t0929 | .mat exists | ~595 | Pre-refactor |
| 20260213_t1018 | .mat exists | ~594 | Day of per-trial reward refactor |
| 20260216_t0837 | .mat exists | ~629 | Post-refactor |
| 20260218_t0934 | **generate .mat** | ~781 | rewardRatioBig changed to 1.25 |

### 1.2 Parameter Extraction
For each session, extract from p.mat / p.trVarsInit:
- `rewardRatioBig`, `rewardProbHigh`, `rewardDurationMs`
- `deltaTValues`
- `fixHoldDurationMin/Max`, `responseWindow`
- Trial array structure (columns, phase sizes, single-stim presence)
- Any GUI overrides

---

## 2. Core Analyses

### 2.1 Parameter Comparison Table (Figure 1)
- Table of session parameters across all 5 sessions
- Highlight what changed between sessions
- Annotate with design rationale for each change

### 2.2 Observation 1: Rightward Saccade Bias in Phase 1 (Figure 2)
**Question:** Does the monkey show a rightward bias when there is no reward asymmetry?

**Analysis:**
- P(choose right) in Phase 1 dual-stim trials, broken down by:
  - Session (to see if bias is consistent)
  - DeltaT (gap vs overlap)
  - High-salience side (left vs right)
- Compute P(choose right) separately from P(choose high-salience)
  - If rightward bias exists, P(right) > 0.5 regardless of which side is high-salience
  - P(high-sal | high-sal-right) should be > P(high-sal | high-sal-left)

**Metrics:**
- P(right) overall per session in Phase 1
- P(right) by deltaT
- P(high-sal) conditioned on high-sal side
- Binomial CIs for all proportions

### 2.3 Observation 2: Uncertainty-Driven Exploration (Figure 3)
**Question:** Does the 50/50 reward assignment in Phase 1 (with rewardRatioBig > 1) make the monkey explore more symmetrically?

**Analysis:**
- Compare Phase 1 P(right) across sessions with different reward ratios:
  - Feb 9, 11 (rewardRatioBig = 2.0, pre-refactor, no per-trial assignment)
  - Feb 13, 16 (rewardRatioBig = 2.0, with per-trial 50/50 assignment)
  - Feb 18 (rewardRatioBig = 1.25, with per-trial 50/50 assignment)
- Key test: Did the introduction of per-trial 50/50 reward assignment reduce rightward bias?
- Secondary: Did lowering the ratio to 1.25 re-introduce bias?

**Metrics:**
- P(right) by session, Phase 1 only
- Running P(right) within each session (sliding window, 20-trial blocks)
- Statistical comparison (chi-squared test for independence)

### 2.4 Observation 3: Reward Dominates Saliency in Both Gap and Overlap (Figure 4)
**Question:** Does the monkey preferentially choose the high-reward target regardless of gap/overlap timing?

**Analysis:**
- Phases 2-3 only (where reward asymmetry exists)
- P(choose high-reward) by deltaT condition:
  - Gap (deltaT = +150ms): Stimulus appears AFTER go signal
  - Overlap (deltaT = -150ms): Stimulus appears BEFORE go signal
- Also compute P(choose high-salience) by deltaT for comparison
- Break down by conflict vs congruent trials:
  - Congruent: high-sal = high-reward → both factors push same direction
  - Conflict: high-sal ≠ high-reward → factors compete

**Key prediction from gap/overlap hypothesis:**
- Gap (+150): Should show more saliency capture → higher P(high-sal) in conflict
- Overlap (-150): Should show more reward-driven → lower P(high-sal) in conflict
- If NO difference → the delta-T manipulation is not effective

**Metrics:**
- P(high-sal) in conflict trials by deltaT, per session
- P(high-reward) overall by deltaT, per session
- Effect size: P(high-sal, gap) - P(high-sal, overlap) for conflict trials

### 2.5 Observation 4: Low Reward Ratio Reduces Exploration (Figure 5)
**Question:** When rewardRatioBig is lowered to 1.25, does the monkey revert to rightward bias?

**Analysis:**
- Direct comparison of Feb 18 (ratio=1.25) vs Feb 13/16 (ratio=2.0)
- Phase 1: P(right) comparison
- Phases 2-3: P(high-reward) comparison - is the monkey less motivated to track reward?

---

## 3. Extended Analyses

### 3.1 Saccadic Reaction Time Distributions (Figure 6)
- Full RT distributions (histograms or kernel density estimates), not just medians
- Separate by:
  - Phase (1 vs 2-3)
  - DeltaT (gap vs overlap)
  - Choice (high-sal vs low-sal)
  - Conflict status (conflict vs congruent)
- Look for bimodality (short-latency express saccades vs longer deliberative saccades)
- Express saccade range: 80-130ms → these would be saliency-driven

### 3.2 RT-Choice Relationship (Figure 7)
- Conditional accuracy function: P(high-sal) as a function of RT bin
- If saliency captures fast saccades, P(high-sal) should be higher for short-latency RTs
- Plot separately for gap vs overlap conditions
- This is the classic "tachometric function" approach

### 3.3 Within-Session Learning & Adaptation (Figure 8)
- Running P(choose high-reward) over trial number within Phases 2-3
- How quickly does the monkey learn the reward mapping?
- Does performance plateau or continue improving?
- Separate traces for conflict vs congruent

### 3.4 Sequential Effects / Win-Stay-Lose-Shift (Figure 9)
- P(same choice as previous trial) conditioned on:
  - Previous trial rewarded (same side) vs not
  - Previous trial was high-reward side vs not
- Tests whether monkey uses local reward history to guide choices

### 3.5 Error Analysis (Figure 10)
- Error rates by condition (fixBreak, noResponse, inaccurate)
- Breakdown by phase, deltaT, session
- High error rates in specific conditions may indicate task difficulty or disengagement

### 3.6 Saccade Endpoint Analysis (Figure 11)
- 2D scatter of saccade endpoints (postSacXY)
- Separate panels for different conditions
- Check for systematic endpoint biases that might reveal motor planning strategies
- Verify target locations are correctly implemented across sessions

### 3.7 P(Choose Right) vs P(Choose High-Sal) Decomposition (Figure 12)
- Disentangle spatial bias from salience effect
- 2x2 analysis: high-sal-left × high-sal-right × chose-left × chose-right
- Compute additive spatial bias + multiplicative salience effect
- Signal detection theory: d' for salience detection with criterion shift for spatial bias

---

## 4. Cross-Session Summary (Figure 13)
- All key metrics plotted across sessions on a single figure
- x-axis: session date, annotated with parameter changes
- y-axis panels: P(right), P(high-sal gap), P(high-sal overlap), median RT, error rate
- Allows visual identification of which parameter changes had behavioral effects

---

## 5. Design Recommendations Analysis

### 5.1 Gap/Overlap Effectiveness Assessment
- Quantify the delta-T effect size across all sessions
- Is there ANY evidence of differential saliency capture between gap and overlap?
- If not, consider: are the delta-T values large enough? (Currently ±150ms)

### 5.2 Salience Manipulation Effectiveness
- Are the DKL hue contrasts perceptually distinct enough?
- P(high-sal) in Phase 1 should be > 0.5 if salience is working
- If P(high-sal) ≈ 0.5 in Phase 1, the salience manipulation is too weak

### 5.3 Reward Ratio Sweet Spot
- Plot P(high-reward) as a function of rewardRatioBig across sessions
- Identify whether there's a ratio that balances reward sensitivity with exploration

### 5.4 Potential Modifications to Consider
- Larger delta-T values (e.g., ±300ms)
- Stimulus onset asynchrony BETWEEN targets (not just relative to fixation offset)
- Luminance contrast instead of/in addition to hue contrast
- Varying target eccentricity
- Shorter response windows to force faster (more reflexive) saccades
- Step-gap paradigm (fixation offset → blank gap → target onset)

---

## 6. Output Specification

### Figures
- All figures saved as PDFs in `output/analysis/`
- Publication-quality: vector graphics where possible, 300 DPI raster
- Consistent color scheme across all figures
- Error bars: 95% binomial CIs for proportions, bootstrap CIs for medians

### Report
- Console output summarizing all key findings
- Statistical test results (chi-squared, binomial tests)
- Clear statement of whether each user observation is supported

### Script
- Single MATLAB script: `tasks/conflict_task/supportFunctions/analyzeConflictSessions.m`
- Modular functions for each analysis
- Well-commented with section headers matching this plan
