//
//  MagicOverlay.metal
//  Rewind
//
//  Created by Aleksei Sherstnev on 16. 9. 2026.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

constant int blobCount = 5;
constant float tau = 6.2831853;
constant float epsilon = 0.0001;

static float3 rainbow(float hue) {
  return 0.5 + 0.5 * cos(tau * (hue + float3(0.0, 0.333, 0.667)));
}

static float farthestCorner(float4 bounds, float2 origin) {
  float2 size = bounds.zw;
  return max(
    max(distance(float2(0.0, 0.0), origin), distance(float2(size.x, 0.0), origin)),
    max(distance(float2(0.0, size.y), origin), distance(size, origin))
  );
}

static float2 gustAt(float2 point, float2 origin, float front, float wind, float edge) {
  float2 away = point - origin;
  float distanceToFront = (length(away) - front) / (edge / 3.0);
  return away / max(length(away), 1.0) * wind * exp(-distanceToFront * distanceToFront);
}

static float3 random3(float2 cell) {
  float3 seeds = float3(
    dot(cell, float2(127.1, 311.7)),
    dot(cell, float2(269.5, 183.3)),
    dot(cell, float2(419.2, 371.9))
  );
  return fract(sin(seeds) * 43758.5453);
}

[[ stitchable ]] half4 magicGlow(
  float2 position,
  half4 color,
  float4 bounds,
  float time,
  float blobSize,
  float blobSpread,
  float blobSpeed,
  float hueSpeed
) {
  float2 size = bounds.zw;
  float radius = min(size.x, size.y) * blobSize;
  float drift = time * blobSpeed;
  float3 rgb = 0;
  float weightSum = 0;
  for (int i = 0; i < blobCount; i++) {
    float index = float(i);
    float2 path = float2(
      sin(drift * (0.7 + 0.13 * index) + index * 1.7),
      cos(drift * (0.5 + 0.11 * index) + index * 2.3)
    );
    float2 center = size * (0.5 + blobSpread * path);
    float normalizedDistance = distance(position, center) / radius;
    float weight = exp(-normalizedDistance * normalizedDistance);
    rgb += weight * rainbow(fract(index / blobCount + time * hueSpeed));
    weightSum += weight;
  }
  float coverage = 1.0 - exp(-weightSum);
  float3 tint = rgb / max(weightSum, epsilon);
  return half4(half3(tint * coverage), half(coverage));
}

[[ stitchable ]] half4 magicDust(
  float2 position,
  half4 color,
  float4 bounds,
  float time,
  float2 origin,
  float reveal,
  float wind,
  float edge,
  float dustAmount,
  float dustGap,
  float dustSize,
  float dustSpeed,
  float dustWander,
  float dustFlow,
  float dustSparkle,
  float sparkle
) {
  float breeze = time * dustSpeed;
  float2 meander = float2(
    sin(0.17 * breeze) + 0.5 * sin(0.41 * breeze),
    cos(0.13 * breeze) + 0.5 * cos(0.37 * breeze)
  ) / 1.5;
  float2 flowDirection = normalize(float2(0.0, bounds.w) - origin);
  float2 flow = dustFlow * (meander.x * flowDirection + meander.y * float2(-flowDirection.y, flowDirection.x));
  float front = reveal * (farthestCorner(bounds, origin) + edge);
  float2 source = position - gustAt(position, origin, front, wind, edge) - flow;
  float2 cell = floor(source / dustGap);
  float brightness = 0;
  for (int dy = -1; dy <= 1; dy++) {
    for (int dx = -1; dx <= 1; dx++) {
      float2 c = cell + float2(dx, dy);
      float3 rnd = random3(c);
      if (fract(rnd.x + rnd.y + rnd.z) > dustAmount) {
        continue;
      }
      float t = time * dustSpeed * (0.5 + rnd.z);
      float2 slowLoop = float2(sin(t + rnd.x * tau), cos(0.8 * t + rnd.y * tau));
      float2 fastLoop = float2(sin(2.3 * t + rnd.y * tau), cos(1.7 * t + rnd.x * tau));
      float2 wander = dustWander * (slowLoop + 0.5 * fastLoop) / 1.5;
      float2 rest = (c + 0.5 + wander) * dustGap + flow;
      float2 particle = rest + gustAt(rest, origin, front, wind, edge);
      float spot = 1.0 - smoothstep(0.0, dustSize, distance(position, particle));
      float twinkle = pow(0.5 + 0.5 * sin(t * 0.7 + rnd.x * tau), dustSparkle);
      brightness += spot * mix(1.0, twinkle, sparkle);
    }
  }
  return half4(half(min(brightness, 1.0)));
}
