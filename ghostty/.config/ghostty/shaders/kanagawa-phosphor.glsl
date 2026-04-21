// Calm retro shader with a cursor-smear style trail.
// Keeps the retro-terminal palette, but limits animation to cursor movement.

float rectSdf(in vec2 p, in vec2 center, in vec2 halfSize)
{
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float segDist(in vec2 p, in vec2 a, in vec2 b, inout float s, float d)
{
    vec2 e = b - a;
    vec2 w = p - a;
    float denom = max(dot(e, e), 1e-6);
    vec2 proj = a + e * clamp(dot(w, e) / denom, 0.0, 1.0);
    float segd = dot(p - proj, p - proj);
    d = min(d, segd);

    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float flip = mix(1.0, -1.0, step(0.5, c0 * c1 * c2 + (1.0 - c0) * (1.0 - c1) * (1.0 - c2)));
    s *= flip;
    return d;
}

float parallelogramSdf(in vec2 p, in vec2 v0, in vec2 v1, in vec2 v2, in vec2 v3)
{
    float s = 1.0;
    float d = dot(p - v0, p - v0);

    d = segDist(p, v0, v3, s, d);
    d = segDist(p, v1, v0, s, d);
    d = segDist(p, v2, v1, s, d);
    d = segDist(p, v3, v2, s, d);

    return s * sqrt(d);
}

vec2 normCoord(vec2 value, float isPosition)
{
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float aa(float distanceField)
{
    return 1.0 - smoothstep(0.0, normCoord(vec2(2.0), 0.0).x, distanceField);
}

float startVertexFactor(vec2 a, vec2 b)
{
    float condition1 = step(b.x, a.x) * step(a.y, b.y);
    float condition2 = step(a.x, b.x) * step(b.y, a.y);
    return 1.0 - max(condition1, condition2);
}

vec2 rectCenter(vec4 rectangle)
{
    return vec2(rectangle.x + rectangle.z * 0.5, rectangle.y - rectangle.w * 0.5);
}

float easeOut(float x)
{
    return pow(1.0 - x, 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec3 base = texture(iChannel0, uv).rgb;

    float scanline = abs(sin(fragCoord.y * 1.05)) * 0.14;
    vec3 phosphorTint = vec3(0.00, 0.80, 0.60);
    vec3 retro = mix(base * phosphorTint, vec3(0.0), scanline * 0.65);

    vec2 centered = uv * 2.0 - 1.0;
    float vignette = 1.0 - dot(centered * vec2(0.88, 1.02), centered * vec2(0.88, 1.02)) * 0.06;
    retro *= clamp(vignette, 0.92, 1.0);

    vec2 scenePos = normCoord(fragCoord, 1.0);
    vec2 offsetFactor = vec2(-0.5, 0.5);
    vec4 currentCursor = vec4(normCoord(iCurrentCursor.xy, 1.0), normCoord(iCurrentCursor.zw, 0.0));
    vec4 previousCursor = vec4(normCoord(iPreviousCursor.xy, 1.0), normCoord(iPreviousCursor.zw, 0.0));

    float vertexFactor = startVertexFactor(currentCursor.xy, previousCursor.xy);
    float invertedVertexFactor = 1.0 - vertexFactor;

    vec2 v0 = vec2(currentCursor.x + currentCursor.z * vertexFactor, currentCursor.y - currentCursor.w);
    vec2 v1 = vec2(currentCursor.x + currentCursor.z * invertedVertexFactor, currentCursor.y);
    vec2 v2 = vec2(previousCursor.x + currentCursor.z * invertedVertexFactor, previousCursor.y);
    vec2 v3 = vec2(previousCursor.x + currentCursor.z * vertexFactor, previousCursor.y - previousCursor.w);

    float cursorSdf = rectSdf(scenePos, currentCursor.xy - (currentCursor.zw * offsetFactor), currentCursor.zw * 0.5);
    float trailSdf = parallelogramSdf(scenePos, v0, v1, v2, v3);

    float progress = clamp((iTime - iTimeCursorChange) / 0.12, 0.0, 1.0);
    float easedProgress = easeOut(progress);
    float lineLength = distance(rectCenter(currentCursor), rectCenter(previousCursor));

    float trailMask = aa(trailSdf) * step(cursorSdf, easedProgress * lineLength);
    float cursorMask = aa(cursorSdf);

    vec3 trailColor = vec3(0.18, 0.46, 0.56);
    vec3 cursorColor = vec3(0.28, 0.70, 0.62);

    vec3 finalColor = retro;
    finalColor = mix(finalColor, trailColor, trailMask * 0.22);
    finalColor = mix(finalColor, cursorColor, cursorMask * 0.30);
    finalColor = mix(finalColor, retro, step(cursorSdf, 0.0));

    fragColor = vec4(clamp(finalColor, 0.0, 1.0), 1.0);
}
