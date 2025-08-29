Shader "Hidden/SsrShader"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Pass
        {
            Name "SsrPass"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment SsrFrag
            #pragma multi_compile_fragment _ _LINEAR_TO_SRGB_CONVERSION
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            // Core.hlsl for XR dependencies
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"  
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"  
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/DebuggingFullscreen.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            // ------------ Fucntions -----------
            #include "Assets/ScreenSpaceReflection/Shaders/ShaderLib/SsrFunctions.hlsl"
            // ------------ Uniform Variable -----------
            SAMPLER(sampler_BlitTexture);

            // x: step count, y: thickness, z: step size w: ray offset
            float4 _SsrParameters;

            #define RAY_OFFSET _SsrParameters.w
            #define STEP_COUNT _SsrParameters.x
            #define THICKNESS _SsrParameters.y
            #define STEP_SIZE _SsrParameters.z

            // ------------ Shader Stage ----------
            half4 SsrFrag(Varyings input) : SV_Target
            {
                // ------ Base Data --------
                float2 uv = input.texcoord;
                
                half4 source = GetSource(uv);
                // rawDepth 记录 NDC 空间的 Z 信息 [0, 1]
                float rawDepth = SampleSceneDepth(uv);
                // linearDepth 为视线空间的 Z 坐标绝对值
                // float linear01Depth = Linear01Depth(rawDepth, _ZBufferParams);
                float3 normalWS = 0;
                float smoothness = 0;
                GetNormalAndSmoothness(uv, normalWS, smoothness);
                float3 normalVS = TransformWorldToViewDir(normalWS);

                float3 posWS = GetWorldSpacePosition(uv, rawDepth);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - posWS);
                float3 viewDirVS = TransformWorldToViewDir(viewDirWS);

                float3 reflDirWS = normalize(-reflect(viewDirWS, normalWS));
                float3 reflDirVS = TransformWorldToViewDir(reflDirWS);
                
                float3 posVS = TransformWorldToView(posWS);

                // 存在自反射, 需要加一定的偏移
                float3 rayVS = posVS + normalVS * RAY_OFFSET;

                // ------ Shading ----------

                // for debug
                // return half4(reflDirVS, 1);

                // 视图空间 RayMarching
                UNITY_LOOP
                for (int i = 0; i < STEP_COUNT; i++)
                {
                    rayVS += reflDirVS * STEP_SIZE * i;
                    float2 currRayUV;
                    ReconstructUV(rayVS, currRayUV);
                    
                    if (any(currRayUV < 0.0) || any(currRayUV > 1.0))
                            // for debug
                            return half4(0.0, 0.0, 0.0, 1.0);
                            // return GetSource(uv);
                    
                    float currSampleDepth = SampleSceneDepth(currRayUV).x;
                    // 重构出相机空间的 Z 坐标(绝对值)进行比较, 方便调参
                    float currSampleZ = LinearEyeDepth(currSampleDepth, _ZBufferParams);
                    float currRayZ = -rayVS.z;

                    float deltaZ = currRayZ - currSampleZ;
                    
                    if (deltaZ >= 0 && deltaZ < THICKNESS)
                    {
                        return GetSource(currRayUV);
                        return GetSource(currRayUV) * smoothness + GetSource(uv);
                    }
                }
                
                // 未击中的区域为黑色
                return half4(0.0, 0.0, 0.0, 1.0);
                return GetSource(uv);
                
            }
            ENDHLSL
        }
    }
}
