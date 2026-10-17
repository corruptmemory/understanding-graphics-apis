#version 450

// Four triangles, twelve corners and four colors. gl_VertexIndex / 3 picks the triangle,
// gl_VertexIndex % 3 the corner, so vkCmdDraw(cb, 3, 1, 3 * k, 0) draws triangle k. Every triangle
// covers the center; each also covers one point no other does (see README.md).
const vec2 corners[12] = vec2[12](
    vec2(-0.9, -0.9), vec2( 0.9, -0.9), vec2( 0.0,  0.3),   // 0: red, points down, alone at (0, -0.8)
    vec2( 0.9, -0.9), vec2( 0.9,  0.9), vec2(-0.3,  0.0),   // 1: green, points left, alone at (0.8, 0)
    vec2( 0.9,  0.9), vec2(-0.9,  0.9), vec2( 0.0, -0.3),   // 2: blue, points up, alone at (0, 0.8)
    vec2(-0.9,  0.9), vec2(-0.9, -0.9), vec2( 0.3,  0.0)    // 3: yellow, points right, alone at (-0.8, 0)
);

const vec3 colors[4] = vec3[4](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0),
    vec3(1.0, 1.0, 0.0)
);

layout(location = 0) out vec3 color;

void main() {
    gl_Position = vec4(corners[gl_VertexIndex], 0.0, 1.0);
    color = colors[gl_VertexIndex / 3];
}
