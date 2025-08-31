// jitter dither map
static half dither[16] = {
    0.0, 0.5, 0.125, 0.625,
    0.75, 0.25, 0.875, 0.375,
    0.187, 0.687, 0.0625, 0.562,
    0.937, 0.437, 0.812, 0.312
};

struct BinarySearchRayMarchingData
{
    // base data
    float3 posVS;
    float3 reflDirVS;
    float3 normalVS;
    float stepCount;
    float thickness;
    float stride;
    float rayOffset;
    float maxDistance;
    float binaryCount;
};

struct ScreenSpaceRayMarchingData
{
    // inout data
    float2 currPosSS;
    float currInvW;
    
    // out data
    float deltaZ;

    // base data
    float dPosSS;
    float dInvW;
    float rayZ;
    bool isVertical;
    float2 endSS;
    float dir;
    float stepCount;
};