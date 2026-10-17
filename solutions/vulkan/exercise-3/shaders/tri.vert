#version 450

// Three corners in clip space. Vulkan's y points down in framebuffer coordinates, and the
// specification's signed area a = -1/2 * sum(x_i * y_{i+1} - x_{i+1} * y_i) is positive for this
// order, so the triangle is front-facing under VK_FRONT_FACE_COUNTER_CLOCKWISE.
const vec2 corners[3] = vec2[3](
    vec2(-0.8,  0.8),   // bottom left
    vec2( 0.8,  0.8),   // bottom right
    vec2( 0.0, -0.8)    // top
);

void main() {
    gl_Position = vec4(corners[gl_VertexIndex], 0.0, 1.0);
}
