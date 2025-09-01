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
            
            #pragma multi_compile_local_fragment _ _VIEW_SPACE_RAY_MARCHING
            #pragma multi_compile_local_fragment _ _SCREEN_SPACE_RAY_MARCHING
            #pragma multi_compile_local_fragment _ _BINARY_SEARCH_RAY_MARCHING
            #pragma multi_compile_local_fragment _ _HIERARCHICAL_Z_BUFFER_RAY_MARCHING
            
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
            #include "Assets/ScreenSpaceReflection/Shaders/ShaderLib/SsrUniformData.hlsl"

            // ------------ Shader Stage ----------
            half4 SsrFrag(Varyings input) : SV_Target
            {
                // ------ Base Data --------
                float2 uv = input.texcoord;
                
                float rawDepth = SampleSceneDepth(uv);
                float3 normalWS = 0;
                float smoothness = 0;
                GetNormalAndSmoothness(uv, normalWS, smoothness);
                float3 normalVS = TransformWorldToViewDir(normalWS);

                float3 posWS = GetWorldSpacePosition(uv, rawDepth);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - posWS);

                float3 reflDirWS = normalize(-reflect(viewDirWS, normalWS));
                float3 reflDirVS = TransformWorldToViewDir(reflDirWS);
                
                float3 posVS = TransformWorldToView(posWS);

                // --------- Shading ------------
                float2 hitUV = 0;

                // for debug
                // float3 finalColor = 0;
                float3 finalColor = GetSource(uv);


                
                // 视图空间 RayMarching
                #if _VIEW_SPACE_RAY_MARCHING
                finalColor = ViewSpaceRayMarching(uv, reflDirVS, normalVS, posVS, smoothness,
                    THICKNESS,STRIDE,STEP_COUNT,RAY_OFFSET);
                #endif


                
                // 屏幕空间 RayMarching
                #if _SCREEN_SPACE_RAY_MARCHING
                finalColor = ScreenSpaceRayMarching(uv, posVS, reflDirVS, normalVS, smoothness,
                    STEP_COUNT, THICKNESS, STRIDE, RAY_OFFSET, MAX_DISTANCE, ATTENUATION);
                #endif

                
                
                // 二分搜索
                #if _BINARY_SEARCH_RAY_MARCHING
                BinarySearchRayMarchingData rayMarchingData;
                rayMarchingData.reflDirVS = reflDirVS;
                rayMarchingData.posVS = posVS;
                rayMarchingData.normalVS = normalVS;
                rayMarchingData.stepCount = STEP_COUNT;
                rayMarchingData.thickness = THICKNESS;
                rayMarchingData.stride = STRIDE;
                rayMarchingData.rayOffset = RAY_OFFSET;
                rayMarchingData.maxDistance = MAX_DISTANCE;
                rayMarchingData.binaryCount = BINAERY_COUNT;
                
                if (BinarySearchRayMarching(rayMarchingData, hitUV))
                {
                    float2 attUV = abs(hitUV - 0.5) * 1.8;
                    attUV = pow(saturate(attUV), ATTENUATION);
                    float att = length(attUV);
                    float edgeFading = pow(saturate(1 - att * att), 5);
                    
                    finalColor = GetSource(hitUV) * smoothness * edgeFading + finalColor;
                }

                // for debug
                // if (BinarySearchRayMarching(posVS, reflDirVS, normalVS, hitUV, STEP_COUNT,THICKNESS, STRIDE, RAY_OFFSET, MAX_DISTANCE, BINAERY_COUNT))
                // {
                //     finalColor = GetSource(hitUV);
                // }
                #endif



                // Hierarchical Z Buffer Ray Marching
                #if _HIERARCHICAL_Z_BUFFER_RAY_MARCHING
                
                // for debug
                // float4 depth = SAMPLE_TEXTURE2D_X_LOD(_HiZTex, sampler_HiZTex, uv, 5);
                // return float4(depth.xxx, 1);

                // rayMarchingInfo xy: hitUV , w: isHit
                // float4 rayMarchingInfo = HiZRayMarching(posVS, reflDirVS, normalVS, hitUV,
                //     STEP_COUNT, THICKNESS, STRIDE, RAY_OFFSET, MAX_DISTANCE);

                bool isRayMarching = HiZRayMarching(posVS, reflDirVS, normalVS, hitUV,
                    STEP_COUNT, THICKNESS, STRIDE, RAY_OFFSET, MAX_DISTANCE);
                
                if (isRayMarching)
                {
                    float2 attUV = abs(hitUV - 0.5) * 1.8;
                    attUV = pow(saturate(attUV), ATTENUATION);
                    float att = length(attUV);
                    float edgeFading = pow(saturate(1 - att * att), 5);
                    
                    finalColor = GetSource(hitUV) * smoothness * edgeFading + finalColor;
                }
                
                #endif
                
                return half4(finalColor, 1);
            }
            
            ENDHLSL
        }
    }
}
