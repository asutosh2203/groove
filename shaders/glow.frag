#version 440
// Cursor glow (D-41): neutral white, Gaussian falloff alpha(d) = intensity * exp(-falloff * (d / radius)^2), clipped to the
// surface silhouette by sampling its alpha (the shape layer) in normalised coordinates. Output is premultiplied.
// Static per-pixel noise of +-0.5/255 dithers the 8-bit result so 5% white over a dark surface does not band.
// Build: scripts/build-shaders.sh (Qt 6 qsb). Do not edit the .qsb by hand.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 center;      // pointer, in item pixels
    vec2 size;        // item size in pixels
    float radius;
    float intensity;
    float falloff;
    float strength;   // fade 0..1
} ubuf;

layout(binding = 1) uniform sampler2D mask;

// Interleaved gradient noise: static, depends only on the pixel.
float noise(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
    vec2 p = qt_TexCoord0 * ubuf.size;
    float d = length(p - ubuf.center) / ubuf.radius;
    float glow = ubuf.intensity * exp(-ubuf.falloff * d * d) * ubuf.strength;
    float inside = texture(mask, qt_TexCoord0).a;
    float a = max(glow + (noise(floor(p)) - 0.5) / 255.0, 0.0) * inside * ubuf.qt_Opacity;
    fragColor = vec4(vec3(a), a);
}
