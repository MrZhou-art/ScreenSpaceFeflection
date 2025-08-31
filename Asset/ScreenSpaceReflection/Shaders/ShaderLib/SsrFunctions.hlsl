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

// 屏幕空间 ---> 世界空间 (默认是点)
float3 GetWorldSpacePosition(float2 uv, half depth)
{
    return ComputeWorldSpacePosition(uv.xy, depth, UNITY_MATRIX_I_VP);
}

// 视图空间 ---> 屏幕空间 (默认是点)
float2 TransformViewToScreen(float3 posVS, float2 screenSize,out float InvW)
{
    float4 posCS = TransformWViewToHClip(posVS);
    InvW = 1 / posCS.w;
    float2 uv = float2(posCS.x, posCS.y * _ProjectionParams.x) / posCS.w * 0.5 + 0.5;
    return uv * screenSize;
}

// ---------- temp ---------------

// 从视图空间坐标重构屏幕空间的片元 uv 和深度
void ReconstructUVAndDepth(float3 posVS, out float2 uv, out float depth)
{
    half4 posCS = TransformWViewToHClip(posVS);
    // posCS.w = -posVS.z
    half4 posNDC = posCS / posCS.w;
    depth = posNDC.z;
    uv = float2(posCS.x, posCS.y * _ProjectionParams.x) / posCS.w * 0.5 + 0.5;
}

// 从视图空间坐标重构屏幕空间的片元 uv 和深度
void ReconstructUV(float3 posVS, out float2 uv)
{
    half4 posCS = TransformWViewToHClip(posVS);
    uv = float2(posCS.x, posCS.y * _ProjectionParams.x) / posCS.w * 0.5 + 0.5;
}

// ---------- Ray Marching ------------

// 视图空间 RayMarching
float3 ViewSpaceRayMarching(float2 uv, float3 reflDirVS, float3 rayVS, float smoothness,
                            float thickness, float stride, float stepCount)
{
    // 视图空间 RayMarching
    UNITY_LOOP
    for (int i = 0; i < stepCount; i ++)
    {
        rayVS += reflDirVS * stride * i;
        float2 currRayUV;
        ReconstructUV(rayVS, currRayUV);
        float currSampleDepth = SampleSceneDepth(currRayUV).x;
        // 重构出相机空间的 Z 坐标(绝对值)进行比较, 方便调参
        float currSampleZ = LinearEyeDepth(currSampleDepth, _ZBufferParams);
        float currRayZ = - rayVS.z;

        float deltaZ = currRayZ - currSampleZ;

        if (deltaZ >= 0 && deltaZ < thickness)
        {
            // for debug : 直接获取到反射的信息
            // return GetSource(currRayUV);
            return GetSource(currRayUV) * smoothness + GetSource(uv);
        }
    }

    // for debug : 未击中的区域为黑色
    // return half4(0.0, 0.0, 0.0, 1.0);
    return GetSource(uv);
}

// 屏幕空间 RayMarching
float3 ScreenSpaceRayMarching(float2 uv, float3 posVS, float3 reflDirVS, float3 normalVS, float smoothness,
                              float stepCount, float thickness, float stride, float rayOffset, float maxDistance)
{
    // 视图空间中射线起始位置和结束位置
    float3 startVS = posVS;
    float3 endVS = posVS + reflDirVS * maxDistance;
    
    if (endVS.z > -_ProjectionParams.y)
        maxDistance = (-_ProjectionParams.y - startVS.z) / reflDirVS.z;
    endVS = startVS + reflDirVS * maxDistance;

    // inverse w
    // w = -Vz , 为了后面方便在屏幕空间插值深度
    float startInvW = 0;
    float endInvW = 0;

    // 屏幕空间中射线起始位置和结束位置  
    // 其实 startSS = uv * _ScreenSize.xy ([0, 1]^2 -> [0, w-1],[0, h-1])
    // 但是为了拿到裁剪空间的 w 分量, 我们必须使用自定义的 TransformViewToScreen 函数
    float2 startSS = TransformViewToScreen(startVS, _ScreenSize.xy, startInvW);
    float2 endSS = TransformViewToScreen(endVS, _ScreenSize.xy, endInvW);

    // DDA 算法
    float2 deltaSS = endSS - startSS; // 注意方向性!
    bool isVertical = false;
    // 我们默认的是以横轴为主导向, 如果纵轴为主导向, 则进行反转, 并在之后进行复原
    if (abs(deltaSS.x) < abs(deltaSS.y))
    {
        isVertical = true;

        deltaSS = deltaSS.yx;
        startSS = startSS.yx;
        endSS = endSS.yx;
    }

    // 计算屏幕坐标、inverse-w的线性增量
    float dir = sign(deltaSS.x); // 屏幕空间增量方向
    float invdx = dir / deltaSS.x; // 1 / 屏幕空间增量 (绝对值)
    float2 dPosSS = float2(dir, invdx * deltaSS.y);
    float dInvW = (endInvW - startInvW) * invdx;

    // 步长的调整
    dPosSS *= stride;
    dInvW *= stride;

    // 存在自反射, 需要加一定的偏移
    float3 rayVS = posVS + normalVS * rayOffset;
    float preZ = rayVS.z;// 作为初始 Z 分量和缓存的作用

    // 起始数据
    float2 currPosSS = startSS;
    float currInvW = startInvW;

    // RayMarching
    UNITY_LOOP
    for (int i = 0; i < stepCount && currPosSS.x * dir <= endSS.x * dir; i++)
    {
        // 缓存前后两步视图空间的 Z 分量 (防止跨像素太大, 判断不出相交)
        float rayNearZ = preZ;
        float rayFarZ = -1 / (dInvW * 0.5 + currInvW);// 初始做一次半步长迈进
        preZ = rayFarZ;

        // 视图空间中相机朝向 -Z 方向
        if (rayNearZ < rayFarZ) 
            Swap(rayNearZ, rayFarZ);

        // 步近
        currPosSS += dPosSS;
        currInvW += dInvW;

        // 得到交点uv  
        float2 hitUV = isVertical ? currPosSS.yx : currPosSS; // 复原
        hitUV *= _ScreenSize.zw;

        if (any(hitUV < 0.0) || any(hitUV > 1.0))
            break;

        // 相交判断
        float surfaceZ = -LinearEyeDepth(SampleSceneDepth(hitUV), _ZBufferParams);
        bool intersecting = (rayFarZ <= surfaceZ) && (rayNearZ >= surfaceZ - thickness);

        if (intersecting)
            // return GetSource(hitUV);
            return GetSource(hitUV) * smoothness + GetSource(uv);
    }

    // return half4(0, 0, 0, 1);
    return GetSource(uv);
}
