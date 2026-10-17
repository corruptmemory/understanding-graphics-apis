#version 450

// TODO: a table of shapes. With no vertex buffers bound, the only input is gl_VertexIndex, which
// starts at the firstVertex you pass to vkCmdDraw. Index a const array of corners with it, as
// vulkan/exercise-4/shaders/table.vert does; a quad is two triangles, six corners. Give each shape
// a color and pass it to the fragment shader through an output at location 0.

void main() {
    gl_Position = vec4(0.0);
}
