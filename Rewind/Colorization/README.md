# Colorization

> Vibe-coded: this README was written by Claude Opus 5 (`claude-opus-5`) in Claude Code, not by
> hand. Check a claim against the code before relying on it.

On-device colorization of monochrome photos. A colorization model predicts the color. Everything
around it (reading the photo, lightness, contrast, geometry, composing the result) is plain image
processing, written after a reference Python pipeline so every stage can be checked against its
numbers.

## The idea: keep the photo's lightness, predict only the color

The pipeline works in CIE L\*a\*b\*, which splits a pixel into three independent parts:

- **L**: lightness, 0 (black) to 100 (white);
- **a**: green (negative) to red (positive);
- **b**: blue (negative) to yellow (positive).

A monochrome photo already has the right L. Only a and b are missing, and they are all the model
predicts. The result takes L from the photo at full resolution and ab from the model, which works
at a few hundred pixels. The eye resolves detail in brightness far better than in color (the same
reason JPEG stores color at a lower resolution), so low-resolution color on full-resolution
lightness still looks sharp, and the model never touches the photo's brightness.

One stage does change it: **Levels** stretches the lightness to fill the scale before anything else
reads it, so a faded scan gets the contrast of a photograph back. It is the single deliberate
exception, and everything after it — the model, the post-process, compose — still only decides
color.

Lab formulas and constants: [OpenCV, RGB ↔ CIE L\*a\*b\*](https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html#color_convert_rgb_lab).

## Status

| Stage | Code | State |
|---|---|---|
| Split the watermark, detect monochrome | `WatermarkedImage.swift`, `MonochromeDetection.swift` | done |
| Download and install models | `ColorizationModelStore.swift` and around | done |
| Prepare: read, lightness, gray frame, CLAHE | `colorize(image:model:)` | done |
| Prepare: levels | `Stages/Levels.swift` | done |
| DDColor: fit, pad, inference, crop | `Models/DDColorLarge.swift` | done |
| DDColor: back to full size | `ABPlanes.bilinearResized(target:)` | done |
| ECCV16: squash, lightness, inference, back to full size | `Models/ECCV16.swift` | done |
| Compose L + ab into the result | `colorize(image:model:)`, `Lab.rgb(lightness:ab:)` | done |
| Stitch the watermark strip back | `WatermarkedImage.stitched()` | done |
| The store hands out the picked model, one loaded at a time | `ColorizationModelStore.localModel(id:)` | done |
| Result on screen: switch between the original and the colorized photo | `ImageDetailsState.displayedImage` | done |
| Stop the run when the user closes the photo | `Colorize.swift`, `ImageDetailsModel`, `Reducer.swift` | done |
| Post-process: edge-aware blur | `Stages/EdgeAwareBlur.swift`, `Stages/LabBilateral.metal` | done |
| Post-process: boldness | `Stages/Boldness.swift` | done |
| Post-process: chroma ceiling | `Stages/ChromaCeiling.swift` | done |

## From the tap to the pipeline

1. The image details screen opens a photo. `splitWatermark` cuts off the archive's watermark
   strip, and `isMonochrome` decides whether the photo has no color. Only then is the colorize
   button offered.
2. On a tap without a chosen model, the picker opens. With one, `ImageDetailsModel` calls
   `colorize(image:model:)` on the photo without the watermark strip, with the model from the store.
   The screen then puts the result in place of the content and stitches the strip back under it
   with `WatermarkedImage.stitched()`. The strip is fitted to the result's width: a photo larger
   than `maxSide` comes back at the size `colorize` read it, with the strip in proportion.
3. The model comes from `ColorizationModelStore.localModel(id:)`, on the main actor. It creates
   `DDColorLarge` or `ECCV16` for the installed
   `Application Support/ColorizationModels/<model ID>.mlmodelc` and keeps that one instance for its
   id, so the graph loads once; a different id replaces it, and deleting the model's file or a
   memory warning drops it.
4. Closing the photo stops the run. The details screen names its colorization effect when it
   builds the reducer, and the reducer cancels that effect in its own `deinit`, which is when the
   dismissed screen is released. `colorize(image:model:)` checks cancellation between the stages,
   so the result of a screen nobody can see is never built. The synchronous Core ML prediction
   cannot be interrupted once started: that one finishes, and its color is dropped.
5. The result replaces the original on screen with a crossfade and a success haptic. The
   colorize button then becomes a switch between the original and the colorized photo; switching
   never runs the model again. Full-screen preview, share, save and comparison take the photo on
   screen, `ImageDetailsState.displayedImage`. Both versions are shown aspect fit, so a result read
   at `maxSide` covers the same area as the larger original.

## The pipeline

`colorize(image:model:)` in `Colorize.swift` takes one photo through the whole diagram, one stage a
line: prepare with the model's `claheClip`, the model's `predict(gray:)`, then compose. Every new
stage lands in it as one more line, so the function always shows the whole order. As a nonisolated
`async` function it runs the pixel work off the main actor the tap came from.

```
UIImage (the photo without the watermark)
  │
  │  PREPARE
  │  RGBPlanes(image:maxSide:)      pixels as floats, long side at most 2048
  │  Lab.lightness(of:)             L of every pixel
  │  Levels.stretch(lightness:)     L stretched to fill the scale ────────────┐
  │  Lab.neutralGray(lightness:)    the same L as a gray sRGB frame           │
  │  CLAHE.apply(to:clip:)          local contrast restored for the model     │
  ▼                                                                           │
gray frame, Plane<UInt8>, full size                                           │ lightness,
  │                                                                           │ Plane<Float>,
  │  MODEL ─ model.predict(gray:), geometry differs per model                 │ full size
  │  DDColor: fit → pad → Core ML → crop → back to full size                  │
  │  ECCV16:  squash → lightness → Core ML → back to full size                │
  ▼                                                                           │
ab, ABPlanes, full size                                                       │
  │                                                                           │
  │  POST-PROCESS                                                             │
  │  EdgeAwareBlur.apply(to:lightness:)  color held inside an outline  ◄──────┤
  │  Boldness.apply(to:lightness:boldness:)  gain where L can hold it  ◄──────┤
  │  ChromaCeiling.apply(to:boldness:)     the whole frame under a limit      │
  │                                                                           │
  │  COMPOSE                                                                  │
  │  Lab.rgb(lightness:ab:)         Lab → sRGB  ◄─────────────────────────────┘
  │  RGBPlanes.makeUIImage()        rounded to bytes
  ▼
UIImage (colorized)
```

### 1. Prepare

The first four lines of `colorize(image:model:)` make the gray frame and the lightness, both at the
size the photo was read at.

1. **Read.** `RGBPlanes(image:maxSide:)` draws the photo into an 8-bit RGB context with its
   orientation applied, scaled down so the long side is at most `maxSide` (2048), and stores each
   channel as floats in 0...1. The cap bounds the memory and time of every full-size stage after it.
2. **Lightness.** `Lab.lightness(of:)` computes L\* of every pixel: sRGB gamma decoded, weighted
   into luminance Y, then `116 f(Y) - 16`. This plane is kept until the end: the result's brightness
   comes from here, not from the model.
3. **Levels.** `Levels.stretch(lightness:)` stretches the band between the 1st and the 99th
   percentile of L onto 0...100. Most archive scans need little of it — over the reference's sample
   of 19 the tonal span was already 56 to 99 of 100 — and the stretch is self-limiting, its gain
   being 100 over the band's width: ×1.02 and ×1.08 on the two full-range parity frames. The class
   it exists for is the photographed reproduction rather than the scan, dark and flat (×1.42 on the
   parity frame of that kind), where every model returns a flat sepia tint instead of a
   colorization and this is the one operator that fixes it. Everything downstream is stretched with
   it: the frame the model reads, the two post-process stages that weigh color by lightness, and
   the composed result, which gets the contrast of a photograph. The band is taken at percentiles
   rather than at the darkest and brightest pixel, so one speck of dust cannot set the range for
   the whole frame. What it costs: the outer percent at each end is crushed flat onto the end of
   the scale; every lightness difference is multiplied by the same gain, so the blur's fixed
   `sigmaColor` covers relatively less of a stretched frame than of the original (the reference has
   the same coupling, and the parity frames are measured through it); and this is the one stage
   that changes the photo's own brightness rather than only steering color. The reference measured
   the stretch as a loss when it is not needed — over those 19 scans mean chroma drops 1.15 while
   the cast ratio improves only 0.035 — and as the only rescue for the dark flat class.
4. **Gray frame.** `Lab.neutralGray(lightness:)` turns each L back into sRGB with a = b = 0. Many
   archive scans are sepia or tinted rather than truly gray; the model must see a neutral frame, and
   the tint must not leak into its color.
5. **CLAHE.** `CLAHE.apply(to:clip:)` is Contrast Limited Adaptive Histogram Equalization on the L
   of 8-bit Lab, 8×8 tiles, written after OpenCV's `clahe.cpp` step by step. Faded scans get their
   local contrast back before the model reads them. The clip limit is a per-model constant measured
   in the reference, `ColorizationModel.claheClip`: DDColor 1.0, ECCV16 1.5. CLAHE only steers the
   color: it changes what the model sees, never the result's brightness, which comes from steps 2
   and 3.

### 2. Model

`ColorizationModel.predict(gray:)` takes the full-size gray frame and returns ab of the same size.
The input geometry lives inside each model, because each model was measured with its own.

Models are actors: a prediction takes seconds, and the `MLModel` never leaves its actor.
`CoreMLLoader` loads the compiled graph on the first prediction rather than when the model is
picked, checks the file is still on disk and that enough memory is available, and keeps the graph
for the next prediction. Errors a user can hit are `HandlingError` sentences, because the alert
shows the error's description.

#### DDColor-large

[DDColor](https://arxiv.org/abs/2212.11613), converted to Core ML at fp16, with a fixed 384×384
input. An 800×698 photo goes through it like this:

| Step | Code | Size |
|---|---|---|
| Gray frame | `colorize(image:model:)` | 800×698 |
| 1. Fit | `Plane<UInt8>.resized(target:)` | 384×335 |
| 2. Pad | `Plane<UInt8>.padded(target:)` | 384×384 |
| 3. Inference | `DDColorLarge.infer` | ab 384×384 |
| 4. Crop | `ABPlanes.cropped(target:)` | ab 384×335 |
| 5. Back to full size | `ABPlanes.bilinearResized(target:)` | ab 800×698 |

1. **Fit.** The long side is scaled to 384, the short side keeps the proportion. Resizing averages
   the source pixels each output pixel covers, the way
   [`cv2.INTER_AREA`](https://docs.opencv.org/4.x/da/d54/group__imgproc__transform.html#ga47a974309e9102f5f08231edc7e7529d)
   does. In the reference, the model's chroma correlates with the fine contrast of its input
   (+0.24), and bilinear or Lanczos resizing changes that contrast; no system resize matches
   `INTER_AREA`.
2. **Pad.** The graph takes only a square. Squashing the frame into it would distort every shape;
   DDColor's own inference did that, and the reference fixed it by keeping the proportions and
   padding instead. The padding goes to the right and bottom and mirrors the frame without
   repeating the edge pixel,
   [`BORDER_REFLECT_101`](https://docs.opencv.org/4.x/d2/de8/group__core__array.html#ga209f2f4869e304c82d07739337eae7c5)
   (`abcd → abcd|cba`), so the margin continues the picture instead of making a hard border.
   The reference pads to a multiple of 32, which a fixed-shape graph cannot take.
3. **Inference.** The gray square becomes an 8-bit RGB image for the graph's `grayRGB` input (the
   graph applies its own normalization) and comes out as `ab` `(1, 2, 384, 384)` float16, already in
   Lab units. Compute units are `.cpuAndGPU`: on the Neural Engine, fp16 arithmetic of this
   ConvNeXt-L breaks down (mean |Δab| 8.56 against the reference). In the Simulator it runs on the
   CPU only, because the Simulator's GPU path returns all-zero ab.
4. **Crop.** The model returned color for the whole square, the mirrored margin included. The crop
   keeps the top-left 384×335 and drops the color of the margin.
5. **Back to full size.** ab is scaled up to the gray frame's size bilinearly, as
   [`F.interpolate(mode="bilinear", align_corners=False)`](https://docs.pytorch.org/docs/stable/generated/torch.nn.functional.interpolate.html):
   each pixel blends the four nearest pixels of the cropped ab, pixel centers sit half a pixel in,
   and past the outermost centers the edge value holds. DDColor's own inference used nearest,
   which leaves 3–5 px color blocks; bilinear reduced color bleeding on all 19 frames the reference
   measured.

**Does padding and then cropping give back the original?** No. Padding adds margins to the gray
frame; cropping removes them from the color the model made. In between, the model turns gray into
color. The crop matters because step 5 stretches the color: without it, the whole square would be
stretched over the photo together with the margin, and every pixel would get the color of a
different place.

#### ECCV16

[Colorful Image Colorization](https://arxiv.org/abs/1603.08511) (Zhang et al., ECCV 2016),
converted to Core ML at fp32, with a fixed 256×256 input. An 800×533 photo goes through it like
this:

| Step | Code | Size |
|---|---|---|
| Gray frame | `colorize(image:model:)` | 800×533 |
| 1. Squash | `Plane<UInt8>.bicubicResized(target:)` | 256×256 |
| 2. Lightness | `Lab.lightness(ofGray:)` | L 256×256 |
| 3. Inference | `ECCV16.infer` | ab 256×256 |
| 4. Back to full size | `ABPlanes.bilinearResized(target:)` | ab 800×533 |

1. **Squash.** The frame is resized to the square with its proportions ignored, the geometry of
   the [upstream code](https://github.com/richzhang/colorization/blob/master/colorizers/util.py)
   that every number for this model was measured on; above 256 the model invents colors. There is
   no padding, so nothing to crop. The resize is Pillow's
   [`BICUBIC`](https://pillow.readthedocs.io/en/stable/handbook/concepts.html#filters), as the
   reference makes this model's input: a cubic kernel widened by the scale when shrinking, a
   horizontal pass and then a vertical one, each rounded to bytes. The model's color follows the
   fine contrast of its input, so the filter has to be the reference's: DDColor's area resize here
   moves the mean a of one parity frame by 5.
2. **Lightness.** The graph takes L, not an image. `Lab.lightness(ofGray:)` puts every byte of the
   squashed frame through the same L formula with R = G = B, after the resize, as the reference's
   [`skimage.color.rgb2lab`](https://scikit-image.org/docs/stable/api/skimage.color.html#skimage.color.rgb2lab)
   does.
3. **Inference.** `lightness` `(1, 1, 256, 256)` in Lab units (the graph normalizes it) and
   `rebalance` `(1)` go in, `ab` `(1, 2, 256, 256)` float32 in Lab units comes out. The model
   predicts a distribution over 313 ab bins; the reference's decode of it (temperature 0.3, the
   violet wedge masked, each bin weighted by its chroma to the power `rebalance` before the mean)
   is converted into the graph, so `rebalance`, 2, is a graph input. Compute units are `.all`: at
   fp32, CPU, GPU and the Neural Engine all agree with torch, while fp16 overflows into NaN on the
   CPU. In the Simulator it runs on the CPU only, as every model does.
4. **Back to full size.** The same bilinear scaling as DDColor's step 5, with a different scale
   on each axis.

### 3. Compose

The last line of `colorize(image:model:)` makes the result from the full-size lightness of prepare
and the ab of the model: `Lab.rgb(lightness:ab:)`, then `RGBPlanes.makeUIImage()`. The formulas and
constants are OpenCV's float `COLOR_Lab2RGB`, like the rest of `Lab.swift`.

1. **Lab → XYZ.** L gives `fy = (L + 16) / 116`, a and b shift it to `fx` and `fz`, and the inverse
   of `f` (a cube, with the straight segment near zero) turns them into X, Y and Z. X and Z are
   scaled by OpenCV's D65 white point, `Xn` 0.950456 and `Zn` 1.088754.
2. **XYZ → sRGB.** OpenCV's
   [XYZ → RGB matrix](https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html#color_convert_rgb_xyz)
   gives linear RGB. Each channel is clamped to 0...1 before the sRGB transfer function, in the
   order of OpenCV's
   [`color_lab.cpp`](https://github.com/opencv/opencv/blob/4.x/modules/imgproc/src/color_lab.cpp):
   a color outside sRGB loses the excess.
3. **Image.** `RGBPlanes.makeUIImage()` rounds every channel to a byte with
   `ColorizationHelpers.byte(sRGB:)` and wraps the bytes in a `CGImage` with
   `ColorizationHelpers.makeCGImage(bytes:size:)`, the same helpers that make the gray frame and
   DDColor's input image.

With a = b = 0 the result is the neutral gray frame within one level. `ColorizeTests` runs
`colorize(image:model:)` on every parity frame with each model's clip limit and a model that predicts
no color, and checks exactly that, together with the result's size and the CLAHE'd frame the model
received.

### 4. Post-process

The reference tunes the color after the model in three stages, inserted before compose in this
fixed order, each of them added only after the one before it had been looked at on real photos on a
phone. All three are in.

1. **Edge-aware blur**: the color is held inside the outlines the lightness shows.
2. **Boldness**: a gain on the color, where the lightness can hold one.
3. **Chroma ceiling**: if the frame's color reaches past a ceiling, all of ab is scaled down under
   it.

#### Edge-aware blur

`EdgeAwareBlur.apply(to:lightness:)` is a
[bilateral filter](https://doi.org/10.1109/ICCV.1998.710815) over the Lab triple: every neighbor
inside a circle contributes to the pixel's new ab, weighted by two things at once — how far away it
is, and how different the three channels are there. A neighbor across an outline differs, so it
counts for almost nothing, and the color is averaged inside an object instead of across its border.
The artifact these models leave is exactly that: a patch of color spilling past the thing it
belongs to.

- **L is read, never written.** Only ab leaves the stage, so the photo's brightness is the same
  after it as before. Lightness is in the weight because that is where the edges are: the model's
  own ab is too soft to find an outline in.
- **The weight** of a neighbor at distance d is
  `exp(-d² / 2σs² - (|ΔL| + |Δa| + |Δb|)² / 2σc²)`, with σc 25 and σs 12: the reference's
  [`cv2.bilateralFilter(d, sigmaColor: 25, sigmaSpace: 12)`](https://docs.opencv.org/4.x/d4/d86/group__imgproc__filter.html#ga9d7064d478c95d60003cf839430737ed)
  on a three-channel float frame. The color term is the summed absolute difference of the three
  channels and then squared, which is what OpenCV computes for three channels — not the euclidean
  distance one would assume.
- **The size.** The window is 15 px wide on a 1600 px long side, scaled with the frame by
  `PlaneSize.scaleFromReference` and forced odd so that it has a center pixel:
  19 px across at `maxSide`, 9 px on the 800 px parity frames. A fixed width would be a different
  filter on a small scan than on a large one, and the misplaced color it has to reach is itself
  proportional to the frame: a model predicts at a few hundred pixels whatever the photo's size,
  so the larger the frame, the more pixels one of its pixels is stretched over. σs is *not*
  scaled: OpenCV lets an explicit diameter win and leaves σs as the falloff inside it, and every
  reference number was measured that way. The support is the circle inscribed in the diameter,
  again OpenCV's.
- **On the GPU.** 19 px across is 253 neighbors a pixel, so a full frame is a billion weights;
  `LabBilateral.metal` does them as a compute kernel, and `EdgeAwareBlur.Shader` keeps the device,
  the queue and the pipeline state it needs for that. There is no bilateral in vImage, MPS or Core
  Image to use instead. The kernel mirrors the frame's edges by the same `BORDER_REFLECT_101` rule
  as the rest of the folder, spelled out a second time because a Metal kernel cannot call Swift.

#### Boldness

`Boldness.apply(to:lightness:boldness:)` multiplies ab by a gain — the one color control this
pipeline offers. The models predict pale color, DDColor especially, and the gain is neither flat
across the frame nor always the one that was asked for.

- **How much to ask for is the model's own constant**, `ColorizationModel.boldness`: DDColor 1.5,
  ECCV16 1. ECCV16 has its lever inside the graph instead — the `rebalance` exponent its `predict`
  passes in — so there is nothing left for a gain to do here. At 1 the stage hands back the frame
  it was given and never builds the weight map below, which is the expensive half of it.
- **Weighted by lightness.** The gain is off at or below L=20, full between L=35 and L=75, and off
  again at or above L=90: deep shadow and blown highlight cannot hold chroma, so a gain there only
  pushes pixels out of sRGB. That map is then blurred by a box of radius 24 px at the reference's
  long side, 63 px across at `maxSide` — unblurred it is a function of L, and multiplying it into
  ab prints the lightness texture onto the color.
- **Withdrawn on a frame that already leans one way.** The cast ratio is `|mean ab| / mean chroma`:
  at 1 every pixel points the same way in color space, which is a tint laid over the photo rather
  than a colorization, and a saturation control on that is a sepia-strength control. Between 0.75
  and 0.95 the requested gain fades to 1. The guard only ever attenuates, so the color can never
  end up further from the model's own prediction than the model asked for.

#### Chroma ceiling

`ChromaCeiling.apply(to:boldness:)` is the last thing that happens to the color before it meets the
lightness again: a frame whose color reaches past a ceiling is scaled down as a whole until it fits
under it. This is what keeps a result from coming out in acid colors — a model that paints one
region far past everything else in the picture, and a gain that has just multiplied it.

- **One factor for the whole frame, and never above 1.** Every pixel is multiplied by the same
  number, so nothing changes hue and no part of the picture loses color relative to another; a
  frame already under the ceiling is handed back untouched. The stage can only take color away.
- **Where the ceiling sits** is 24 chroma units times the gain the model asked for: 36 for DDColor,
  24 for ECCV16. It has to move with the gain, or boldness would raise the color and the ceiling
  would take the same color straight back. It is the model's own constant, not what boldness's cast
  guard was left with: withdrawing the gain on a tinted frame lowers that frame's color without
  also lowering the ceiling it is judged against.
- **Measured at the 99th percentile of chroma**, not at the maximum. The last percent of pixels
  reaches well past the rest of the frame — on the parity frames the maximum is 1.1 to 3.4 times
  the percentile — and fitting the frame under the ceiling by those few would drain the color out
  of everything else.
- **The percentile is read off a histogram**, 8192 bins over the chroma the frame actually has,
  rather than off a sorted copy: sorting three million floats to read one of them costs about forty
  times what binning them does, 380 ms against 9. Inside the bin that holds the rank the values are
  taken to be evenly spread, and on a frame of millions of pixels, where the two sorted values the
  rank falls between land in the same bin, that puts the answer within a bin's width — a hundredth
  or two of a chroma unit — of what `numpy.percentile` returns. Pixels whose chroma is not a finite
  number are left out of both the count and the range: a single one of them cannot be binned at
  all, and must not be allowed to decide the whole frame's color.

## Checking against the reference

- The reference is a Python pipeline on OpenCV and PyTorch. Its per-stage statistics for three
  800 px frames live in `RewindTests/Fixtures/ios-parity/reference.json`, next to the input PNGs.
- `ColorizationParityTests` runs the Swift stages on those frames and compares mean, standard
  deviation, min and max of each stage (`1_to_gray_rgb`, `2_levels_rgb`, `3_clahe_rgb`, `5_L`,
  `7_lum_weight` so far).
- Two of the three frames were recorded with the levels stretch off, and the test runs each frame
  the way it was recorded, from the case's own `levels` flag. The third, 166360, is the one
  recorded with it on — on both consumers, which its `5_L` gives away: the lightness the reference
  composed from is the stretched plane (39.16 mean, 27.33 std) and not the original (37.78 /
  19.37). It is also the only fixture whose source carries a tint, and the two facts together are
  why its input stages are given tolerances of their own: cv2 decodes the sRGB gamma through a
  spline table in its float Lab path, so its L sits 0.084 under the exact formula on this frame,
  and the ×1.42 stretch and CLAHE after it magnify that. Measured, ours against the reference's:
  `1_to_gray_rgb` 91.13 against 90.93, `2_levels_rgb` 96.19 against 95.67, `3_clahe_rgb` 99.33
  against 98.17 at a clip of 1.0 and 101.47 against 99.52 at 1.5. Each tolerance is its own gap
  rounded up — 0.20 to 0.25, 0.52 to 0.75, 1.15 to 1.25, 1.95 to 2.5 — rather than slack picked to
  make the test pass. The last row is the widest because of its extremes rather than its mean: at a
  clip of 1.5 the stretched frame reaches true black where the reference stops at 2, so that one
  case gets 2.5 on min and max as well and every other case keeps the usual 1.0. On the two
  untinted frames the gray round-trip cancels the bias out and they keep the reference's own 0.05.
- The stretch is applied once, to the float lightness plane, where the reference applies it twice —
  to the 8-bit gray the model reads and to the RGB the result is composed from, each through its own
  Lab round-trip. Taking the reference's route does not land closer to it (96.09 against our 96.19,
  for its 95.67): the gap is the spline above, not the quantisation. So the pipeline keeps the
  single stretch, which is also what makes both consumers get it by construction.
- What the stage does regardless of the reference is checked directly: the share of the stretched
  plane sitting exactly at 0 and exactly at 100 is between 0.5% and 1.5% each (0.97% and 1.01%
  here). A stretch taken between the darkest and the brightest pixel would leave both at zero.
- The model stage (`4_model_ab_a`, `4_model_ab_b`, `4_model_chroma`, both models) and the blur
  after it (`6_bilateral_chroma`) compare the mean only, within 1.5 or 25% of the reference mean,
  whichever is larger: DDColor's square padding differs from the reference's and Core ML runs it in
  fp16. ECCV16 lands within 0.07 of every reference mean. Models are not in the repo: each test
  case compiles `~/Junk/models/<package>.mlpackage` from the host, found through
  `SIMULATOR_HOST_HOME`, removes the compiled copy afterwards, and is skipped without the package. The suite is serialized so
  graphs never load side by side.
- A mean that loose cannot tell the blur from doing nothing at all, so the same test also checks
  what the blur unmistakably does on each model: it takes the top off the chroma peaks, on the
  parity frames by 10-13% for DDColor and 0.3-0.8% for ECCV16.
- Boldness splits the same way. `7_lum_weight` comes from the frame alone, so it is checked in
  full next to `5_L`; `7_cast_ratio` and `7_bold_effective` are read off the model's own ab, so
  they are checked within 25% of the reference value, like its means; `7_bold_chroma` compares the
  mean. The gain itself comes from the reference's `7_bold_in`, not from the model's constant — as
  with `claheClip`, that constant is where the two could still drift apart unnoticed.
- The same test also checks what boldness unmistakably does: mean chroma comes out at least 5%
  above the blur's for DDColor, and no lower than it for ECCV16, which asks for no gain at all.
  The reference lifts it by 16% and 33% on the two DDColor frames.
- The ceiling is pinned in three places. `8_cap`, the ceiling itself, is compared exactly rather
  than within a tolerance: it is arithmetic on the reference's own `7_bold_in`, with no model in
  it. `8_cap_chroma` compares the mean like every stage after the model does, and where the ceiling
  really binds that has teeth — the reference takes 37% of the mean chroma off one DDColor frame
  and 63% off one ECCV16 frame. And the stage's own contract is checked directly: the 99th
  percentile of the frame it hands back lands on the ceiling, neither above it nor short of it,
  which is what a stage measuring the maximum instead would fail.
- The percentile itself is the one number of this stage the reference does not record, but it can
  be divided back out of two it does: `8_cap_chroma / 7_bold_chroma` is the factor the stage
  applied, and the ceiling over that factor is the percentile it was measured at. On three of the
  four cases ours lands within 0.3% of that — 36.67 against 36.70, 36.86 against 36.95, 65.68
  against 65.74 — and on the fourth, the DDColor frame whose prediction differs most from the
  reference's to begin with, 61.73 against 57.06.
- With the ceiling in, the chain reaches the composed frame, so `10_final_R`, `10_final_G`,
  `10_final_B` and `10_final_rgb` are compared for the first time. The tolerance is the model's
  own 25%, which on a byte channel proves little by itself; what the comparison shows is that the
  whole chain ends up within 0.1 to 2.1 of the reference's bytes. `LabTests` is what pins compose
  itself, on single pixels against cv2's `COLOR_Lab2RGB`.
- Between the ceiling and that frame the reference has one more stage which is not ported,
  `9_gamut_chroma`: its per-pixel gamut fit degenerated into a flat ×255/256 (its numbers are
  `8_cap_chroma` × 255/256 to four decimals). Composing with that multiplier moves the channel
  means by at most 0.09 of a byte here, against the 0.1 to 2.1 the models' own spread already puts
  between us and the reference — the parity numbers cannot tell the two apart, and a node that
  does nothing is not worth carrying.
- `ChromaCeilingTests` checks the stage on 401-pixel frames whose chroma is known: the 99th
  percentile of a mixed frame lands within a bin of `np.percentile`'s 100.080; a ramp of 0...400 is
  measured at 396 and comes back scaled so that its top pixel is 400 × 24/396 = 24.2424 and its own
  percentile is the ceiling exactly; a ramp that never reaches the ceiling comes back as it went
  in; and a pixel whose chroma is not a number drops out of the count instead of taking the frame's
  percentile with it (396.01 on the 400 that are left). 401 pixels is what puts the rank on a whole
  number, so the ramp separates numpy's convention, `p/100 × (n - 1)`, from the off-by-one one:
  within the histogram that one answers 396.044 instead of 396, which is why the ramp is checked to
  0.01 and its scaled top pixel to 0.001.
- `LevelsTests` checks the stage on 401-pixel ramps: the band between the percentiles fills the
  scale (a ramp of 20...70 comes back with its 200th pixel at 50 and its 5th at `np.percentile`'s
  0.2551, and the pixels outside the band flat at 0 and 100), a ramp with one stray pixel at each
  end is stretched on the percentiles and not on the strays (24.49 where the extremes would have
  given 37.5), and a frame of one flat tone comes back as it went in rather than as solid black.
- `BoldnessTests` checks the stage on 200×16 frames made for it: the weight map lands on numpy and
  [`cv2.blur`](https://docs.opencv.org/4.x/d4/d86/group__imgproc__filter.html#ga8c45db9afe636703801b0b2e440fce37)
  within 0.0005 at the top-left corner, the middle and the bottom-right corner (0.566255, 0.605761,
  0.883951). The last two are what pin the running sums: an index off by one leaves the first
  pixel where it was and moves those two by 0.002 and 0.02-0.08. A replicated border instead of a
  reflected one would miss the two corners by 0.29 and 0.43 and leave the middle untouched, eight
  rows from either edge as it is. Then: half the gain is left in the middle of
  the guard (1.5 at a cast ratio of 0.85 becomes 1.25), a frame painted in one tint comes back
  untouched at a cast ratio of exactly 1, and a frame whose ab averages to zero takes the whole
  gain, ±10 becoming ±15.
- `EdgeAwareBlurTests` checks the filter itself on 1600×16 frames made for it, against
  `cv2.bilateralFilter(d: 15, sigmaColor: 25, sigmaSpace: 12)` on the same frames: a flat color
  comes back unchanged whatever the lightness does, and a step of ±5 in a lands on cv2's value
  within 0.01 both where the lightness is flat (0.7095, smoothed away) and where the lightness has
  an edge under it (4.8411, held). The first of those two also pins the circular support: over a
  square one the same pixel would come out 0.5534.
- Unit tests take their expected numbers from cv2, numpy, Pillow or torch, not from the Swift code.
- Where it matters for the numbers, the code follows OpenCV's arithmetic rather than a textbook
  version: area resize, reflect padding, CLAHE, Lab constants and the 8-bit Lab tables CLAHE runs
  in; ECCV16's input follows Pillow's bicubic resize.
- Rounding is `.rounded()` (halves away from zero) everywhere. cv2 rounds halves to even; the
  difference moves the parity means by at most 0.002.

## Files

| File | What it holds |
|---|---|
| `ColorizationModel.swift` | the model protocol (`claheClip`, `predict(gray:)`, `boldness`) and `ColorizationModelID` |
| `Colorize.swift` | `colorize(image:model:)`, the pipeline stage by stage, and `maxSide` |
| `ColorizationHelpers.swift` | helpers shared by several stages (`mirroredIndex`, `byte(sRGB:)`, `makeCGImage`) |
| `Image/Plane.swift` | `Plane<Value>`: one channel of values with its `PlaneSize`, and the percentile of a float one |
| `Image/RGBPlanes.swift` | a photo as three float channels, read from a `UIImage` and written back to one |
| `Image/ABPlanes.swift` | the model's a and b channels, read from Core ML at fp16 or fp32, cropped, resized, measured as chroma and scaled by it |
| `Image/Lab.swift` | sRGB ↔ Lab: lightness of a photo and of a gray frame, neutral gray, Lab → sRGB for compose, the 8-bit tables CLAHE runs in |
| `Image/Resampling.swift` | area and bicubic resize and reflect padding of the gray frame |
| `Stages/Levels.swift` | the lightness stretched to fill the scale |
| `Stages/CLAHE.swift` | contrast limited adaptive histogram equalization |
| `Stages/EdgeAwareBlur.swift`, `Stages/LabBilateral.metal` | the bilateral filter that holds the model's color inside the outlines the lightness shows, and `PlaneSize.scaleFromReference`, which both filters take their sizes through |
| `Stages/Boldness.swift` | the gain on the model's color, weighted by lightness and withdrawn on a tinted frame |
| `Stages/ChromaCeiling.swift` | the limit on how much color a result may carry |
| `Models/CoreMLLoader.swift` | lazy Core ML loading with the file and memory checks |
| `Models/DDColorLarge.swift` | DDColor-large as a `ColorizationModel`: its clip limit, geometry and inference |
| `Models/ECCV16.swift` | ECCV16 as a `ColorizationModel`: its clip limit, geometry and inference |
| `ColorizationModelStore.swift`, `ColorizationManifest.swift`, `ColorizationFileState.swift`, `DownloadRequest+Colorization.swift` | downloading, installing and deleting models; the store also keeps the one model it hands out |
| `MonochromeDetection.swift` | whether a photo needs colorization |
| `WatermarkedImage.swift` | the archive's watermark strip split off before colorization and stitched back after |

New methods and properties in this folder get a short comment: what they do, why the pipeline
needs them, and the specification they follow, with a link where one exists.
