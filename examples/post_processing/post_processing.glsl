#[compute]
#version 450

#define PI 3.141592653589793
#define SMOOTHSTEP(x) (x*x*(3.0-2.0*x))
//
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(push_constant) uniform PushConstants {
    float time;
};

//set 0
layout(set = 0, binding = 0) uniform sampler2D input_image;
layout(set = 0, binding = 1, rgba8) writeonly uniform image2D output_image;

//** COMPUTE SHADER SEPARATOR - 分隔符 **//

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    vec4 color = texelFetch(input_image, pixel, 0);
    imageStore(output_image, pixel, vec4(sin(time), color.gb, color.a));
}
