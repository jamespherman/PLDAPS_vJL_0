# Why DKL-axis tri-noise (vs RGB-axis) for `rfMap` chromatic mode

A note for collaborators on the design choice for the chromatic dense-noise
stimulus in `tasks/rfMap/`. Specifically: why we accumulate STA against
**DKL** (cone-opponent) axes rather than against **RGB** framebuffer guns,
which is the more obvious / "default" choice and what the `feng_LGN`
reference code does (`stim_densenoise_color.m`).

The two schemes share the same statistical structure — binary tri-noise,
8 corner states per check per frame, output STA shape `[nY, nX, 3, nLags, nCh]`.
**They differ only in which orthogonal triple the three "axes" are.**

## What we share with Feng's approach

- **Binary tri-noise** on three independent axes per check per frame:
  every check, every frame, draws ±contrast independently on each axis,
  giving 8 corner states.
- **Linear STA estimator**: the binary structure means each axis has
  constant variance across all stimulus realizations, which gives the
  cleanest possible recovery per spike count.
- **Per-axis spatial map**: the `[nY, nX, ..., nLags, nCh]` output has a
  spatial map per axis per lag.

## What we differ on

- **Feng** (`stim_densenoise_color.m`): axes are R, G, B framebuffer guns.
  The 8 corner states are the 8 corners of the RGB cube — `(0,0,0)` through
  `(255,255,255)`. STA is accumulated against the per-frame, per-check
  RGB triple.
- **`rfMap_denseChromatic`**: axes are L−M, S, achromatic — the cardinal
  axes of the DKL color space, which are roughly cone-opponent. The 8
  corner states are mapped through the rig's calibrated `dkl2rgb`
  matrix to RGB framebuffer values before drawing. STA is accumulated
  against the per-check **DKL drive vector**.

## Why this matters for spatial RF mapping (the relevant argument)

The original case for DKL was framed around cone-tuning characterization
("what cone weights does each cell have?"). For a program whose primary
interest is **spatial** receptive-field mapping — for example, electrical-
microstimulation-based visual prosthesis design — that framing isn't the
most direct. The argument that *is* directly relevant to spatial mapping
goes like this.

### Most LGN cells are chromatically tuned

In macaque LGN:
- **Parvocellular (~80%)**: cone-opponent. Each cell's spatial receptive
  field is built from cones with **opposite signs in center vs surround**
  (e.g., L+ center / M− surround for an L/M-opponent P-cell).
- **Koniocellular (~5–10%)**: typically S-cone-driven, also opponent.
- **Magnocellular (~10–15%)**: luminance-driven (sums L and M with the
  same sign), broadly chromatically nonselective.

Magno cells you can map cleanly with achromatic luminance noise.
The other ~90% of LGN you can't, and here's why.

### Luminance-only noise underestimates parvo/konio spatial RFs

Consider an L+/M− P-cell. Its center is driven by L+ minus M−; its
surround is driven by L− plus M+ (opposite signs).

- **Luminance stimulus** (equal positive change on L and M): drives the
  L+ center and the M+ surround **with opposite signs in the cell's
  output** — they roughly cancel. The cell barely responds. STA is small
  and noisy, surround often invisible, center attenuated.
- **L−M-axis stimulus** (positive on L, negative on M, isoluminant):
  drives the L+ center positive, drives the L− part of the surround
  positive, drives the M+ part of the surround negative (so the surround
  net signal is weak), drives the M− part of the center positive — center
  and surround **add constructively in the cell's output**. The STA has
  a clean center–surround spatial profile.

In short, **the spatial RF of a parvo cell is what you measure on its
preferred cone-opponent axis**, not what you measure under luminance-only
modulation. This is documented in:

- **Reid & Shapley (1992), *Nature* 356:716–718.** "Spatial structure
  of cone inputs to receptive fields in primate lateral geniculate
  nucleus." The original demonstration that P-cell receptive-field
  geometry depends on which cone class is driving it.
- **Reid & Shapley (2002), *J. Neurosci.* 22:6158–6175.** Extended
  reverse-correlation analysis showing center and surround geometry
  along cone axes.
- **Solomon & Lennie (2007), *Nature Reviews Neuroscience* 8:276–286.**
  Review that lays out the cone-opponent vs luminance contrast across
  LGN classes.

### Therefore: a chromatic noise mode is required, not optional

If the goal is a clean spatial RF for the **majority** of LGN cells —
which it is for prosthesis-relevant mapping at LGN, since you don't get
to pick which subpopulation your electrode lands near — then luminance-
only noise will systematically miss the spatial RF of ~90% of recorded
cells. A chromatic noise mode is required.

The remaining question is the basis for that chromatic mode.

## Why DKL is the right basis for the chromatic mode

Given that the cell's biology cares about cone-opponent activation, the
question is which 3-axis basis makes the spatial RF estimate cleanest.

1. **DKL axes are roughly cone-orthogonal; RGB axes aren't.** A P-cell's
   preferred drive direction is a single DKL axis (L−M). Driving on
   that axis gives you the cell's spatial RF in one estimator, with
   the full statistical efficiency of the binary stimulus on that axis.
   Driving on R, G, B individually splits the same L−M activation
   across all three RGB-axis estimators (in rig-specific weights), and
   recovering the L−M-axis spatial RF requires recombining the three
   per-gun estimates with the calibration matrix at analysis time.
   Both work; the DKL version is more direct.

2. **Per-axis spatial maps are biologically interpretable.** "The L−M
   spatial map for this cell" is a direct statement about the cell's
   spatial RF on its preferred drive axis. "The green-gun spatial
   map" is the spatial RF for an in-rig-specific mixture of L and M
   cone activation, which is a less useful per-axis quantity even
   though the population sum across guns is fine.

3. **Combining across axes for a 'total' spatial RF works correctly.**
   For a "where is this cell's RF?" estimate that pools across axes,
   you typically want `sum(|STA|^2, axis)`. With DKL axes — which are
   approximately orthogonal in cone space — this sum is unbiased.
   With RGB axes, R and G both activate L and M cones with overlap,
   so the sum slightly double-counts on the L+M-cone component. For
   spatial extent / location estimates this is a small bias, but it
   exists.

4. **(Secondary, multi-rig advantage)** Saved DKL-axis STA tensors are
   directly comparable across rigs and across years without re-applying
   each session's calibration matrix in analysis — the calibration
   enters at *display* time only (DKL → RGB before drawing), not in
   the saved drive vectors that feed STA. For a multi-lab collaboration
   this matters more than for a single-lab program.

## Honest tradeoffs

The DKL choice is not free, and we should be transparent about the costs.

- **Gamut headroom.** The 8 corners of the DKL cube are *interior*
  points of the RGB cube whose position depends on the rig's monitor
  primaries. On our rig (rig1/rig2 LUTs in
  `tasks/rfMap/supportFunctions/LUT_VPIXX_rig*.{xyY,r,g,b}`), the
  largest in-gamut uniform contrast is **0.4738** (computed by
  `gamutMaxContrasts.m`); we use **0.45** (5% safety margin). Feng's
  RGB-noise has no equivalent constraint — its "corners" *are* the
  corners of the RGB cube, full per-channel range. So per-pixel
  framebuffer contrast is ~38% lower for our chromatic stimulus.
- **Per-cone-axis contrast partly offsets the framebuffer-contrast cost.**
  RGB-noise spreads its variance across all three cone classes (most of
  it on luminance, since R+G+B summed is roughly equiluminant on the
  monitor); DKL-noise concentrates contrast on a specific cone-opponent
  axis. So the cone-axis-relevant SNR is closer between the two schemes
  than the framebuffer-contrast comparison suggests. We have not
  computed the exact cone-contrast comparison for this rig; if pressed
  this is worth quantifying.
- **More setup and calibration dependence at display time.** DKL
  requires the rig's monitor primaries and gamma to be measured (not
  the analysis — the *display*). If the calibration is wrong, the
  stimuli aren't actually isolating cone axes, the cell responds to
  the *real* axis structure, and the spatial RF on a "DKL axis" is
  actually the spatial RF on whatever the real cone projection of
  that axis turned out to be. We mitigate this with:
  - Per-rig LUT files (`LUT_VPIXX_rig{N}.{xyY,r,g,b}`) loaded by
    `initmon` based on the PC name.
  - A `dklCalibrationSource` flag (`measured_primaries+measured_gamma`
    vs `vendor_primaries+measured_gamma`) saved with each session so
    analysis can flag uncertainty.
  - A gamut-clip fail-fast in `initClut.m` that errors with the rig's
    max safe contrast if any tri-noise corner clips.

## Bonus argument for visual-prosthesis programs

Even if **spatial RF mapping is the immediate priority**, cone-tuning
information from the same DKL-axis STA is likely useful downstream for
prosthesis design: cortical electrical-stimulation studies (Schmidt et
al., 1996, *Brain* 119:507–522; more recent V1 stimulation work, e.g.,
Bosking, Yoshor and colleagues) consistently report **phosphenes with
apparent color tied to the local population's chromatic tuning**. If
LGN microstimulation produces similarly color-tinged percepts (plausible
given LGN's chromatic organization), then the per-cell cone-tuning
information that DKL-axis STA gives "for free" alongside the spatial RF
is directly relevant for predicting phosphene appearance, not just
location. RGB-axis STA gives the same information in a less directly
useful form (per-gun rather than per-cone-axis).

## Summary, in one paragraph

Most LGN cells are cone-opponent, and their *spatial* receptive fields
are best estimated when the stimulus drives them along their preferred
cone-opponent axis. Luminance-only noise systematically biases the
spatial RF estimate for the parvo/konio majority — the surround often
cancels and the center looks attenuated. A chromatic dense-noise mode
is therefore needed even for purely-spatial mapping. DKL-axis tri-noise
is a more direct basis than RGB-axis tri-noise for this purpose: the
per-axis spatial maps are interpretable on cone-relevant axes, the
combination across axes is unbiased, and the analysis output is
comparable across rigs and years without re-applying each session's
calibration. The cost is ~38% framebuffer-contrast headroom on our
rig and a calibration burden at display time, both of which we
consider acceptable given the spatial-mapping advantage and the
secondary value of cone-tuning information for prosthesis design.

## Appendix: where to find the code

- Generator: `tasks/rfMap/supportFunctions/generateStim_denseChromatic.m`
- Drive-tensor reconstructor: `tasks/rfMap/supportFunctions/recomputeDklDrive.m`
- Per-trial seeding (per-trial drive regeneration): `tasks/rfMap/supportFunctions/initTrialStructure.m`, `nextParams.m`
- DKL ↔ RGB conversion: `tasks/rfMap/supportFunctions/dkl2rgb.m`, `initmon.m`
- Per-rig calibration LUTs: `tasks/rfMap/supportFunctions/LUT_VPIXX_rig{1,2}.{xyY,r,g,b}`
- Gamut helper: `tasks/rfMap/supportFunctions/gamutMaxContrasts.m`
- Settings file: `tasks/rfMap/rfMap_denseChromatic_settings.m`
- Validation harness: `tasks/rfMap/_validation/test_chromatic_generators.m`
- Saved-data conventions: `data_dictionaries/rfMap_data_dictionary.md`
- Locked design decisions: `analysisPlanningDocs/rfMap_unified_merge_plan.md` § "Why DKL for chromatic STA (locked decision)"
