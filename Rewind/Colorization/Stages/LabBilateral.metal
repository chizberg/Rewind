//
//  LabBilateral.metal
//  Rewind
//
//  Created by Aleksei Sherstnev on 19. 9. 2026.
//

#include <metal_stdlib>
using namespace metal;

// Mirrors EdgeAwareBlur.Uniforms.
struct Uniforms {
  int width;
  int height;
  int radius;
  // -0.5 / sigmaColor^2
  float colorCoefficient;
  // -0.5 / sigmaSpace^2
  float spaceCoefficient;
};

// BORDER_REFLECT_101, abcd -> dcb|abcd|cba: the same rule as ColorizationHelpers.mirroredIndex,
// copied because a Metal kernel cannot call Swift.
// https://docs.opencv.org/4.x/d2/de8/group__core__array.html#ga247f571aa6244827d3d798f13892da58
static inline int mirrored(int index, int limit) {
  if (limit <= 1) { return 0; }
  int period = 2 * limit - 2;
  int i = index % period;
  if (i < 0) { i += period; }
  return i < limit ? i : period - i;
}

// cv2.bilateralFilter over the whole Lab triple, as the reference runs it: all three channels
// weigh a tap, only a and b are written back. The range term is the summed absolute difference of
// the three channels, then squared -- what OpenCV does for a three channel float frame, and not
// the euclidean distance one would assume. The radius and the circle come from the dispatch file,
// the summed difference from the SIMD one.
// https://github.com/opencv/opencv/blob/4.x/modules/imgproc/src/bilateral_filter.dispatch.cpp
// https://github.com/opencv/opencv/blob/4.x/modules/imgproc/src/bilateral_filter.simd.hpp
kernel void labBilateral(
    device const float *lightness [[buffer(0)]],
    device const float *inA [[buffer(1)]],
    device const float *inB [[buffer(2)]],
    device float *outA [[buffer(3)]],
    device float *outB [[buffer(4)]],
    constant Uniforms &uniforms [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]) {
  if (int(gid.x) >= uniforms.width || int(gid.y) >= uniforms.height) { return; }

  int index = int(gid.y) * uniforms.width + int(gid.x);
  float centerLightness = lightness[index];
  float centerA = inA[index];
  float centerB = inB[index];

  float weightSum = 0;
  float sumA = 0;
  float sumB = 0;
  float radiusSquared = float(uniforms.radius * uniforms.radius);

  for (int dy = -uniforms.radius; dy <= uniforms.radius; ++dy) {
    int row = mirrored(int(gid.y) + dy, uniforms.height) * uniforms.width;
    for (int dx = -uniforms.radius; dx <= uniforms.radius; ++dx) {
      // OpenCV's support is the circle inscribed in the diameter, not the whole square.
      float distanceSquared = float(dx * dx + dy * dy);
      if (distanceSquared > radiusSquared) { continue; }

      int tap = row + mirrored(int(gid.x) + dx, uniforms.width);
      float a = inA[tap];
      float b = inB[tap];
      float difference = abs(lightness[tap] - centerLightness)
                       + abs(a - centerA)
                       + abs(b - centerB);
      float weight = exp(distanceSquared * uniforms.spaceCoefficient
                       + difference * difference * uniforms.colorCoefficient);
      weightSum += weight;
      sumA += weight * a;
      sumB += weight * b;
    }
  }

  outA[index] = sumA / weightSum;
  outB[index] = sumB / weightSum;
}
