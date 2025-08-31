using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ScreenSpaceReflection.Render
{
    static class SsrShaderConstants
    {
        public static readonly string SsrTexName = "_SsrTex";
        
        public static readonly int SsrTexID = Shader.PropertyToID(SsrTexName);
        // x: step count, y: thickness, z: step size(Stride) , w: ray Z offset
        public static readonly int SsrParameters1ID = Shader.PropertyToID("_SsrParameters1");
        // x: max distance, y: , z: , w:
        public static readonly int SsrParameters2ID = Shader.PropertyToID("_SsrParameters2");
    }
    
    public class SsrRenderPass : ScriptableRenderPass
    {
        private const string m_SsrProfilingTag = "SSRRenderPass";
        private ProfilingSampler m_ProfilingSampler = new(m_SsrProfilingTag + "_Sampler");

        private SsrRenderFeature.SsrSettings m_Settings;
        
        private Material m_SsrMaterial;
        private RTHandle m_SourceRT;
        private RTHandle m_DestinationRT;
        private RTHandle m_SsrRT;
        private RenderTextureDescriptor m_Descriptor;

        public void Create(Material ssrMaterial)
        {
            m_SsrMaterial = ssrMaterial;
        }

        public void Setup(SsrRenderFeature.SsrSettings settings)
        {
            m_Settings = settings;
        }
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_SourceRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
            m_DestinationRT = renderingData.cameraData.renderer.cameraColorTargetHandle;
            
            m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_Descriptor.useMipMap = false;
            m_Descriptor.autoGenerateMips = false;
            
            var tempDesc = GetCompatibleDescriptor(m_Descriptor.width, m_Descriptor.height,
                GraphicsFormat.B10G11R11_UFloatPack32);
            
            string rtName = SsrShaderConstants.SsrTexName;
            RenderingUtils.ReAllocateIfNeeded(ref m_SsrRT, tempDesc, FilterMode.Bilinear,
                TextureWrapMode.Clamp,
                name: rtName);
          
            m_SsrMaterial.SetVector(SsrShaderConstants.SsrParameters1ID,
                new Vector4(m_Settings.StepCount, m_Settings.Thickness / 100, 
                    m_Settings.Stride / 100, m_Settings.RayOffset));
            m_SsrMaterial.SetVector(SsrShaderConstants.SsrParameters2ID,
                new Vector4(m_Settings.MaxDistance, 0, 0, 0));
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(m_SsrProfilingTag + "_CommandBuffer");
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                var tempDesc = GetCompatibleDescriptor(m_Descriptor.width, m_Descriptor.height,
                    GraphicsFormat.B10G11R11_UFloatPack32);
                RenderingUtils.ReAllocateIfNeeded(ref m_SsrRT, tempDesc, FilterMode.Bilinear,
                    TextureWrapMode.Clamp,
                    name: m_SsrRT.name);

                Blitter.BlitCameraTexture(cmd, m_SourceRT, m_SsrRT, RenderBufferLoadAction.DontCare,
                    RenderBufferStoreAction.Store, m_SsrMaterial, 0);
                
                Blitter.BlitCameraTexture(cmd, m_SsrRT, m_DestinationRT);
            }
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            m_SourceRT = null;
            m_DestinationRT = null;
        }

        public void Dispose()
        {
            m_SsrRT?.Release();
            m_SsrRT = null;
        }
        
        public void ClearUp()
        {
            CoreUtils.Destroy(m_SsrMaterial);
        }

        
        RenderTextureDescriptor GetCompatibleDescriptor(int width, int height, GraphicsFormat format,
            DepthBits depthBufferBits = DepthBits.None)
            => GetCompatibleDescriptor(m_Descriptor, width, height, format, depthBufferBits);

        private static RenderTextureDescriptor GetCompatibleDescriptor(RenderTextureDescriptor desc, int width,
            int height, GraphicsFormat format, DepthBits depthBufferBits = DepthBits.None)
        {
            desc.depthBufferBits = (int)depthBufferBits;
            desc.msaaSamples = 1;
            desc.width = width;
            desc.height = height;
            desc.graphicsFormat = format;
            return desc;
        }
    }
}