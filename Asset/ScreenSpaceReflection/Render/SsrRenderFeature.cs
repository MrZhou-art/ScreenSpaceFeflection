using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

namespace ScreenSpaceReflection.Render
{
    public class SsrRenderFeature : ScriptableRendererFeature
    {
        [Serializable]
        public class SsrSettings
        {
            [SerializeField] internal int StepCount = 200;
            [SerializeField] internal float Thickness = 0.3f;
            [SerializeField] internal float Stride = 0.1f;
            [SerializeField] internal float RayOffset = 0.1f;
            [SerializeField] internal float MaxDistance = 10;
        }
    
        [SerializeField] private Shader m_SsrShader;
        [SerializeField] private RenderPassEvent m_RenderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        [SerializeField] private SsrSettings m_Settings = new();
        
        private Material m_SsrMaterial;
        private SsrRenderPass m_SsrRenderPass;

        public override void Create()
        {
            m_SsrRenderPass ??= new SsrRenderPass();
            m_SsrRenderPass.renderPassEvent = m_RenderPassEvent;
            
            if(!m_SsrShader) 
                m_SsrShader = Shader.Find("Hidden/Universal Render Pipeline/Blit");
            m_SsrMaterial = CoreUtils.CreateEngineMaterial(m_SsrShader);
            
            m_SsrRenderPass.Create(m_SsrMaterial);
        }
        
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(m_SsrRenderPass);
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            m_SsrRenderPass.Setup(m_Settings);
        }
        
        protected override void Dispose(bool disposing)
        {
            m_SsrRenderPass?.Dispose();
            m_SsrRenderPass?.ClearUp();
            m_SsrRenderPass = null;
        }
    }
}


