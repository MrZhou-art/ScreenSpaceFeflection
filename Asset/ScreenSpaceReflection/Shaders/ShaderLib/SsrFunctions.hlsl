// 获取 Blit Texture 
half4 GetSource(float2 uv)
{
    return SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, uv, _BlitMipLevel);
}

// 获取 normal
float3 GetNormal(float2 uv)
{
    return SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xyz;
}

// 在延迟渲染管线的 Normal Buffer 中, a 通道输出的是平滑度
// 获取世界空间的法线和平滑度
void GetNormalAndSmoothness(float2 uv, out float3 normal, out float smoothness)
{
    float4 normalAndSmoothness = SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv);
    normal = normalize(normalAndSmoothness.xyz);// 在 normalize 时, 注意不要有 w 分量
    smoothness = normalAndSmoothness.w;
}

// 反投影重建世界坐标
float3 GetWorldSpacePosition(float2 uv, half depth)
{
    return ComputeWorldSpacePosition(uv.xy, depth, UNITY_MATRIX_I_VP);
}

// ---------- temp ---------------
// 从视图空间坐标重构屏幕空间的片元 uv 和深度
void ReconstructUVAndDepth(float3 posWS, out float2 uv, out float depth)
{
    half4 posCS = TransformWViewToHClip(posWS);
    // posCS.w = -posVS.z
    half4 posNDC = posCS / posCS.w;
    depth = posNDC.z;
    uv = float2(posCS.x, posCS.y * _ProjectionParams.x) / posCS.w * 0.5 + 0.5;
}

// 从视图空间坐标重构屏幕空间的片元 uv 和深度
void ReconstructUV(float3 posWS, out float2 uv)
{
    half4 posCS = TransformWViewToHClip(posWS);
    uv = float2(posCS.x, posCS.y * _ProjectionParams.x) / posCS.w * 0.5 + 0.5;
}