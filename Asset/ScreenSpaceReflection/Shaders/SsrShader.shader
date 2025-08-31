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
            float4 _SsrParameters1;
            // x: max distance
            float4 _SsrParameters2;

            // _SsrParameters1
            #define STEP_COUNT _SsrParameters1.x
            #define THICKNESS _SsrParameters1.y
            #define STRIDE _SsrParameters1.z
            #define RAY_OFFSET _SsrParameters1.w

            // _SsrParameters2
            #define MAX_DISTANCE _SsrParameters2.x

            // ------------ Shader Stage ----------
            half4 SsrFrag(Varyings input) : SV_Target
            {
                // ------ Base Data --------
                float2 uv = input.texcoord;
                
                half4 source = GetSource(uv);
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
                float3 finalColor = ScreenSpaceRayMarching(uv, posVS, reflDirVS, normalVS, smoothness,
                    STEP_COUNT, THICKNESS, STRIDE, RAY_OFFSET, MAX_DISTANCE);
                
                return half4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}
