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
            #pragma multi_compile_local_fragment _ _BINARY_SEARCH_RAY_MARCHING
            #pragma multi_compile_local_fragment _ _SCREEN_SPACE_RAY_MARCHING
            
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
            float4 _SsrParameters1;
            // x: max distance, y: attenuation, z: binary count
            float4 _SsrParameters2;

            // _SsrParameters1
            #define STEP_COUNT _SsrParameters1.x
            #define THICKNESS _SsrParameters1.y
            #define STRIDE _SsrParameters1.z
            #define RAY_OFFSET _SsrParameters1.w

            // _SsrParameters2
            #define MAX_DISTANCE _SsrParameters2.x
            #define ATTENUATION _SsrParameters2.y
            #define BINAERY_COUNT _SsrParameters2.z
            

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
                // for debug
                // return half4(posVS, 1);
                
                float2 hitUV = 0;

                // for debug
                // float3 finalColor = 0;
                float3 finalColor = GetSource(uv);

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
                
                return half4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}
