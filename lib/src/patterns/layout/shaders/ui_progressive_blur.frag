#version 460 core
#include <flutter/runtime_effect.glsl>

#define MAX_KERNEL_SIZE 255

// Continuous strength-map and separable Gaussian technique adapted from the
// MIT-licensed progressive_blur package: github.com/kekland/progressive_blur.

uniform sampler2D child_texture;
uniform vec2 child_size;
uniform float blur_sigma;
uniform float blur_direction;
uniform float blur_extent;
uniform float fade_hold;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / child_size;

  // Match progressive_blur's continuous strength-map technique without a
  // generated texture: the top-edge gradient is computed analytically here.
  float edge_progress = clamp(
    FlutterFragCoord().y / max(blur_extent, 1.0),
    0.0,
    1.0
  );
  // The tint begins fading at edge_progress == 1.0 and reaches full strength
  // at 0.12. Use those same boundaries, with a sub-linear exponent so blur
  // becomes perceptible quickly as content enters the fade.
  float fade_value = clamp(
    (1.0 - edge_progress) / max(1.0 - fade_hold, 0.001),
    0.0,
    1.0
  );
  float blur_value = pow(fade_value, 0.55);

  float sigma = blur_sigma * blur_value;
  if (sigma < 1e-5) {
    frag_color = texture(child_texture, uv);
    return;
  }

  int kernel_radius = int(ceil(3.0 * sigma));
  int kernel_size = 2 * kernel_radius + 1;
  if (kernel_size > MAX_KERNEL_SIZE) {
    kernel_radius = MAX_KERNEL_SIZE / 2;
    kernel_size = MAX_KERNEL_SIZE;
  }

  vec2 direction = blur_direction == 0.0
    ? vec2(1.0, 0.0)
    : vec2(0.0, 1.0);
  float total_weight = 0.0;
  vec4 color = vec4(0.0);

  for (int index = 0; index < MAX_KERNEL_SIZE; index++) {
    if (index >= kernel_size) break;

    int offset_index = index - kernel_radius;
    float offset_value = float(offset_index);
    float weight = exp(
      -(offset_value * offset_value) / (2.0 * sigma * sigma)
    );
    vec2 offset = direction * offset_value / child_size;
    color += texture(child_texture, uv + offset) * weight;
    total_weight += weight;
  }

  frag_color = color / total_weight;
}
