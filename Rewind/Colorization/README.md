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
predicts. The result takes L from the original photo at full resolution and ab from the model,
which works at a few hundred pixels. The eye resolves detail in brightness far better than in color
(the same reason JPEG stores color at a lower resolution), so low-resolution color on
full-resolution lightness still looks sharp, and the model never touches the photo's brightness.

Lab formulas and constants: [OpenCV, RGB ↔ CIE L\*a\*b\*](https://docs.opencv.org/4.x/de/d25/imgproc_color_conversions.html#color_convert_rgb_lab).

## Status

| Stage | Code | State |
|---|---|---|
| Split the watermark, detect monochrome | `WatermarkedImage.swift`, `MonochromeDetection.swift` | done |
| Download and install models | `ColorizationModelStore.swift` and around | done |
| Prepare: read, lightness, gray frame, CLAHE | `colorize(image:model:)` | done |
| DDColor: fit, pad, inference, crop | `Models/DDColorLarge.swift` | done |
| DDColor: back to full size | `ABPlanes.bilinearResized(target:)` | done |
| ECCV16: squash, lightness, inference, back to full size | `Models/ECCV16.swift` | done |
| Compose L + ab into the result | `colorize(image:model:)`, `Lab.rgb(lightness:ab:)` | done |
| Stitch the watermark strip back | `WatermarkedImage.stitched()` | done |
| The store hands out the picked model, one loaded at a time | `ColorizationModelStore.localModel(id:)` | done |
| Result on screen: switch between the original and the colorized photo | `ImageDetailsState.displayedImage` | done |
| Stop the run when the user closes the photo | `Colorize.swift`, `ImageDetailsModel`, `Reducer.swift` | done |
| Post-process: edge-aware blur | `Stages/EdgeAwareBlur.swift`, `Stages/LabBilateral.metal` | done |
| Post-process: boldness, chroma ceiling | | not yet, each after looking at real photos |

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
  │  Lab.lightness(of:)             L of every pixel ─────────────────────────┐
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
  │  (not yet: boldness → chroma ceiling)                                     │
  │                                                                           │
  │  COMPOSE                                                                  │
  │  Lab.rgb(lightness:ab:)         Lab → sRGB  ◄─────────────────────────────┘
  │  RGBPlanes.makeUIImage()        rounded to bytes
  ▼
UIImage (colorized)
```

### 1. Prepare

The first three lines of `colorize(image:model:)` make the gray frame and the lightness, both at the
size the photo was read at.

1. **Read.** `RGBPlanes(image:maxSide:)` draws the photo into an 8-bit RGB context with its
   orientation applied, scaled down so the long side is at most `maxSide` (2048), and stores each
   channel as floats in 0...1. The cap bounds the memory and time of every full-size stage after it.
2. **Lightness.** `Lab.lightness(of:)` computes L\* of every pixel: sRGB gamma decoded, weighted
   into luminance Y, then `116 f(Y) - 16`. This plane is kept until the end: the result's brightness
   comes from here, not from the model.
3. **Gray frame.** `Lab.neutralGray(lightness:)` turns each L back into sRGB with a = b = 0. Many
   archive scans are sepia or tinted rather than truly gray; the model must see a neutral frame, and
   the tint must not leak into its color.
4. **CLAHE.** `CLAHE.apply(to:clip:)` is Contrast Limited Adaptive Histogram Equalization on the L
   of 8-bit Lab, 8×8 tiles, written after OpenCV's `clahe.cpp` step by step. Faded scans get their
   local contrast back before the model reads them. The clip limit is a per-model constant measured
   in the reference, `ColorizationModel.claheClip`: DDColor 1.0, ECCV16 1.5. CLAHE only steers the
   color: it changes what the model sees, never the result's brightness, which still comes from
   step 2.

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
order. The first one is in; the other two are added one at a time, each after looking at real
photos on a phone.

1. **Edge-aware blur**, in, and described below.
2. **Boldness** (not yet). A color gain weighted by lightness, so near-black and near-white areas
   are not boosted, and rolled back on frames the model covered with one global cast.
3. **Chroma ceiling** (not yet). If the 99th percentile of chroma, `hypot(a, b)`, exceeds a
   ceiling, all of ab is scaled down to it.

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
  `PlaneSize.pixelWindowDiameter(atReference:)` and forced odd so that it has a center pixel:
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

## Checking against the reference

- The reference is a Python pipeline on OpenCV and PyTorch. Its per-stage statistics for two
  800 px frames live in `RewindTests/Fixtures/ios-parity/reference.json`, next to the input PNGs.
- `ColorizationParityTests` runs the Swift stages on those frames and compares mean, standard
  deviation, min and max of each stage (`1_to_gray_rgb`, `3_clahe_rgb`, `5_L` so far).
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
- The final frame (`10_final_*`) is not compared yet: the reference recorded it after the
  post-process stages. `LabTests` pins compose to cv2's `COLOR_Lab2RGB` on single pixels instead.
- Rounding is `.rounded()` (halves away from zero) everywhere. cv2 rounds halves to even; the
  difference moves the parity means by at most 0.002.

## Files

| File | What it holds |
|---|---|
| `ColorizationModel.swift` | the model protocol (`claheClip`, `predict(gray:)`) and `ColorizationModelID` |
| `Colorize.swift` | `colorize(image:model:)`, the pipeline stage by stage, and `maxSide` |
| `ColorizationHelpers.swift` | helpers shared by several stages (`mirroredIndex`, `byte(sRGB:)`, `makeCGImage`) |
| `Image/Plane.swift` | `Plane<Value>`: one channel of values with its `PlaneSize` |
| `Image/RGBPlanes.swift` | a photo as three float channels, read from a `UIImage` and written back to one |
| `Image/ABPlanes.swift` | the model's a and b channels, read from Core ML at fp16 or fp32, cropped, resized |
| `Image/Lab.swift` | sRGB ↔ Lab: lightness of a photo and of a gray frame, neutral gray, Lab → sRGB for compose, the 8-bit tables CLAHE runs in |
| `Image/Resampling.swift` | area and bicubic resize and reflect padding of the gray frame |
| `Stages/CLAHE.swift` | contrast limited adaptive histogram equalization |
| `Stages/EdgeAwareBlur.swift`, `Stages/LabBilateral.metal` | the bilateral filter that holds the model's color inside the outlines the lightness shows |
| `Models/CoreMLLoader.swift` | lazy Core ML loading with the file and memory checks |
| `Models/DDColorLarge.swift` | DDColor-large as a `ColorizationModel`: its clip limit, geometry and inference |
| `Models/ECCV16.swift` | ECCV16 as a `ColorizationModel`: its clip limit, geometry and inference |
| `ColorizationModelStore.swift`, `ColorizationManifest.swift`, `ColorizationFileState.swift`, `DownloadRequest+Colorization.swift` | downloading, installing and deleting models; the store also keeps the one model it hands out |
| `MonochromeDetection.swift` | whether a photo needs colorization |
| `WatermarkedImage.swift` | the archive's watermark strip split off before colorization and stitched back after |

New methods and properties in this folder get a short comment: what they do, why the pipeline
needs them, and the specification they follow, with a link where one exists.
