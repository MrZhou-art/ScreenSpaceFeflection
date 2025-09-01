Shader "Hidden/HizShader"
{
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Pass
        {
            Name "HiZPass"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Fragment
            #pragma multi_compile_fragment _ _LINEAR_TO_SRGB_CONVERSION
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            // Core.hlsl for XR dependencies
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            //  --------- Uniform Variable ---------
            SAMPLER(sampler_BlitTexture);
            
            float _HiZSourceMipLevel;
            float4 _HiZMipLevelSize;
            
            half4 GetSource(half2 uv, float mipLevel = 0.0)
            {
                return SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, uv, mipLevel);
            }

            // --------- Shading Stage ---------
            half4 Fragment(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                half4 nearest = half4(
                    GetSource(uv + float2(-1, -1) * _HiZMipLevelSize.zw, _HiZSourceMipLevel).r,
                    GetSource(uv + float2(-1,  1) * _HiZMipLevelSize.zw, _HiZSourceMipLevel).r,
                    GetSource(uv + float2( 1, -1) * _HiZMipLevelSize.zw, _HiZSourceMipLevel).r,
                    GetSource(uv + float2( 1,  1) * _HiZMipLevelSize.zw, _HiZSourceMipLevel).r);

                // NDC 空间中, 深度从近到远, 由 1 到 0
                return max(max(nearest.r, nearest.g), max(nearest.b, nearest.a));
            }
            ENDHLSL
        }
    }
}
