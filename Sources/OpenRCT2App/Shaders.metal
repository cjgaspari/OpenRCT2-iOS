// Shaders.metal - Simple fullscreen quad shader for displaying game frame buffer
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen quad vertices (2 triangles)
constant float2 quadVertices[] = {
    float2(-1, -1),  // bottom-left
    float2( 1, -1),  // bottom-right
    float2(-1,  1),  // top-left
    float2( 1, -1),  // bottom-right
    float2( 1,  1),  // top-right
    float2(-1,  1),  // top-left
};

constant float2 quadTexCoords[] = {
    float2(0, 1),  // bottom-left (flipped Y for Metal)
    float2(1, 1),  // bottom-right
    float2(0, 0),  // top-left
    float2(1, 1),  // bottom-right
    float2(1, 0),  // top-right
    float2(0, 0),  // top-left
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    out.position = float4(quadVertices[vertexID], 0, 1);
    out.texCoord = quadTexCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                texture2d<float> gameTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::nearest, min_filter::nearest);
    return gameTexture.sample(textureSampler, in.texCoord);
}
