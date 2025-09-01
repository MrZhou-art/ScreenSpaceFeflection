using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

namespace ScreenSpaceReflection.Render
{
    public class HiZRenderFeature : ScriptableRendererFeature
    {
        [Serializable]
        public class HiZSettings
        {
            [SerializeField] internal RenderPassEvent RenderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
            [SerializeField] [Range(2, 6)] internal int HiZMipCount = 6;
        }
        
        [SerializeField] private Shader m_HiZShader;
        [SerializeField] private HiZSettings m_Settings = new(); 
        
        private Material m_HiZMaterial;
        private HiZRenderPass m_HiZRenderPass;
        
        public override void Create()
        {
            m_HiZRenderPass ??= new HiZRenderPass();
            m_HiZRenderPass.renderPassEvent = m_Settings.RenderPassEvent;
            
            if(!m_HiZShader) 
                m_HiZShader = Shader.Find("Hidden/Universal Render Pipeline/Blit");
            m_HiZMaterial = CoreUtils.CreateEngineMaterial(m_HiZShader);
            
            m_HiZRenderPass.Create(m_HiZMaterial);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            bool isGameCamera = renderingData.cameraData.cameraType == CameraType.Game;
            if (!isGameCamera) return;
            
            renderer.EnqueuePass(m_HiZRenderPass);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            bool isGameCamera = renderingData.cameraData.cameraType == CameraType.Game;
            if (!isGameCamera) return;
            
            m_HiZRenderPass.Setup(ref m_Settings);
        }

        protected override void Dispose(bool disposing)
        {
            m_HiZRenderPass?.Dispose();
            m_HiZRenderPass?.ClearUp();
            m_HiZRenderPass = null;
        }
    }

    static class HiZShaderConstants
    {
        public static readonly string HiZTexName = "_HiZTex";
        
        public static readonly int HiZMipLevelSizeID = 
            Shader.PropertyToID("_HiZMipLevelSize");
        
        public static readonly int HiZSourceMipLevelID =
            Shader.PropertyToID("_HiZSourceMipLevel");

        public static readonly int HiZDestinationMipLevelID =
            Shader.PropertyToID("_HiZDestinationMipLevel");

        public static readonly int MaxHiZMipLevelID = 
            Shader.PropertyToID("_MaxHiZMipLevel");

        public static readonly int HiZTexID =
            Shader.PropertyToID(HiZTexName);
        
        public static int[] HiZTexsID;
    }
    
    class HiZRenderPass : ScriptableRenderPass
    {
        private const string m_SsrProfilingTag = "HiZRenderPass";
        private ProfilingSampler m_ProfilingSampler = new(m_SsrProfilingTag + "_Sampler");
        private RenderTextureDescriptor m_Descriptor;
        private RenderTextureDescriptor m_HiZDesc;
        private RenderTextureDescriptor[] m_HiZDescs;
        private RTHandle[] m_HiZRTHandles;
        private RTHandle m_HiZRTHandle; 
        private RTHandle m_CameraDepthTexture;
        
        private Material m_HiZMaterial;
        private HiZRenderFeature.HiZSettings m_Settings;
        private const int m_MaxHiZMipCount = 6;
        
        public void Create(Material material)
        {
            m_HiZMaterial = material;
            
            HiZShaderConstants.HiZTexsID = new int[m_MaxHiZMipCount];
            m_HiZDescs = new RenderTextureDescriptor[m_MaxHiZMipCount];
            m_HiZRTHandles = new RTHandle[m_MaxHiZMipCount];
            
            m_HiZRTHandle = RTHandles.Alloc(HiZShaderConstants.HiZTexID, name: HiZShaderConstants.HiZTexName);
            
            for (int i = 0; i < m_MaxHiZMipCount; i++)
            {
                HiZShaderConstants.HiZTexsID[i] = Shader.PropertyToID(HiZShaderConstants.HiZTexName + i);
                m_HiZRTHandles[i] = RTHandles.Alloc(HiZShaderConstants.HiZTexsID[i], name: HiZShaderConstants.HiZTexName + i);
            }
        }

        public void Setup(ref HiZRenderFeature.HiZSettings settings)
        {
            m_Settings = settings;
        }
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_CameraDepthTexture = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            
            m_Descriptor = renderingData.cameraData.cameraTargetDescriptor;
            m_Descriptor.useMipMap = false;
            m_Descriptor.autoGenerateMips = false;
            
            var width = Math.Max((int)Math.Ceiling(Mathf.Log(m_Descriptor.width, 2) - 1.0f), 1);
            var height = Math.Max((int)Math.Ceiling(Mathf.Log(m_Descriptor.height, 2) - 1.0f), 1);
            width = 1 << width;
            height = 1 << height;
            
            m_HiZDesc = GetCompatibleDescriptor(width, height, GraphicsFormat.R32_SFloat);
            m_HiZDesc.useMipMap = true;
            m_HiZDesc.sRGB = false; // linear
            m_HiZDesc.mipCount = m_Settings.HiZMipCount;
            
            RenderingUtils.ReAllocateIfNeeded(ref m_HiZRTHandle, m_HiZDesc, FilterMode.Bilinear,
                TextureWrapMode.Clamp, name: HiZShaderConstants.HiZTexName);

            for (int i = 0; i < m_Settings.HiZMipCount; i++)
            {
                m_HiZDescs[i] = GetCompatibleDescriptor(width, height, GraphicsFormat.R32_SFloat);
                // m_HiZDescs[i] = new RenderTextureDescriptor(width, height, RenderTextureFormat.RFloat, 0, 1);
                // m_HiZDescs[i].msaaSamples = 1;
                m_HiZDescs[i].useMipMap = false;
                m_HiZDescs[i].sRGB = false; // linear
                
                RenderingUtils.ReAllocateIfNeeded(ref m_HiZRTHandles[i], m_HiZDescs[i],
                    FilterMode.Bilinear, TextureWrapMode.Clamp, name: HiZShaderConstants.HiZTexName);
                
                // generate mipmap
                width = Math.Max(width / 2, 1);
                height = Math.Max(height / 2, 1);
            }

            ConfigureTarget(renderingData.cameraData.renderer.cameraColorTargetHandle);
            ConfigureClear(ClearFlag.None, Color.white);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(m_SsrProfilingTag + "_CommandBuffer");
            
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // mip 0
                Blitter.BlitCameraTexture(cmd, m_CameraDepthTexture, m_HiZRTHandles[0]);
                cmd.CopyTexture(m_HiZRTHandles[0], 0, 0, m_HiZRTHandle, 0, 0);
                
                // mip 1~max
                for (int i = 1; i < m_Settings.HiZMipCount; i++)
                {
                    cmd.SetGlobalFloat(HiZShaderConstants.HiZSourceMipLevelID, i - 1);
                    cmd.SetGlobalFloat(HiZShaderConstants.HiZDestinationMipLevelID, i);
                    cmd.SetGlobalVector(HiZShaderConstants.HiZMipLevelSizeID,
                        new Vector4(m_HiZDescs[i - 1].width, m_HiZDescs[i - 1].height,
                            1.0f / m_HiZDescs[i - 1].width, 1.0f / m_HiZDescs[i - 1].height));
                    Blitter.BlitCameraTexture(cmd, m_HiZRTHandles[i - 1], m_HiZRTHandles[i], m_HiZMaterial, 0);

                    cmd.CopyTexture(m_HiZRTHandles[i], 0, 0, m_HiZRTHandle, 0, i);
                }

                cmd.SetGlobalFloat(HiZShaderConstants.MaxHiZMipLevelID, m_Settings.HiZMipCount - 1);
                cmd.SetGlobalTexture(HiZShaderConstants.HiZTexName, m_HiZRTHandle);
            }
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }

        public void Dispose()
        {
            foreach (var handle in m_HiZRTHandles)
                handle?.Release();
            m_HiZRTHandle?.Release();
        }

        public void ClearUp()
        {
            CoreUtils.Destroy(m_HiZMaterial);
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