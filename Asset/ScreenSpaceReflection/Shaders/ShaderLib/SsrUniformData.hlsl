#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/DebuggingFullscreen.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"


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
            