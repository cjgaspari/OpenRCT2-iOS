// Shaders.metal - Fullscreen triangle shader for displaying game frame buffer
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen triangle (3 vertices) to cover the screen without gaps.
constant float2 triangleVertices[] = {
    float2(-1.0, -1.0),
    float2( 3.0, -1.0),
    float2(-1.0,  3.0)
};

constant float2 triangleTexCoords[] = {
    float2(0.0, 1.0),
    float2(2.0, 1.0),
    float2(0.0, -1.0)
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    VertexOut out;
    out.position = float4(triangleVertices[vertexID], 0.0, 1.0);
    out.texCoord = triangleTexCoords[vertexID];
    return out;
}

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> frameTexture [[texture(0)]],
    sampler frameSampler [[sampler(0)]]
) {
    return frameTexture.sample(frameSampler, in.texCoord);
}
