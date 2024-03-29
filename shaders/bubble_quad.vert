#version 330

layout(location = 0) in vec2 vertpos;

layout(location = 1) in vec2 in_bubble;
layout(location = 2) in float in_radius;
layout(location = 3) in vec4 in_color_a;

out vec2 bubble_pos;
out float rad;
out vec4 color_a;

uniform vec2 resolution;

void main() {
    // radius in [0, 2] scale
    vec2 radius_normalized = in_radius / resolution * 2;
    // bubble position [-1, 1] scale
    vec2 bubblepos_normalized = in_bubble / resolution * 2.0 - 1;
    // pass in a square around the bubble position
    gl_Position = vec4(vertpos * radius_normalized + bubblepos_normalized, 0.0, 1.0);

    bubble_pos = in_bubble;
    rad = in_radius;
    color_a = in_color_a;
}
