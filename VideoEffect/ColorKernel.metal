//
//  ColorKernel.metal
//  VideoEffect
//
//  Created by TT on 5/22/20.
//  Copyright © 2020 NTP. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void transition(texture2d<float, access::read> inTexture1 [[texture(0)]],
                   texture2d<float, access::read> inTexture2 [[texture(1)]],
                   texture2d<float, access::write> outTexture [[texture(2)]],
                   constant float &firstVidRemainTime [[buffer(0)]],
                   constant bool &firstVidIsNill [[buffer(1)]],
                   constant bool &secondVidIsNill [[buffer(2)]],
                   constant float &overlapDuration [[buffer(3)]],
                   constant bool &shouldBlur [[buffer(4)]],
                   uint2 gid [[thread_position_in_grid]]) {
    float4 inColor1;
    float4 inColor2;

    if (secondVidIsNill) {
        inColor1 = inTexture1.read(gid);
        outTexture.write(inColor1, gid);
    } else if (firstVidIsNill) {
        inColor2 = inTexture2.read(gid);
        outTexture.write(inColor2, gid);
    } else {
        inColor1 = inTexture1.read(gid);
        inColor2 = inTexture2.read(gid);

        float w0 = firstVidRemainTime / overlapDuration;
        if (w0 > 1) {
            w0 = 1;
        }

        float w1 = 1 - w0;
        float4 newColor = w0 * inColor1 + w1 * inColor2;
        outTexture.write(newColor, gid);

    }
}

kernel void mask(texture2d<half, access::read>  inTexture2  [[texture(2)]],
                texture2d<half, access::read>  inTexture1  [[texture(3)]],
                texture2d<half, access::write> outTexture [[texture(4)]],
                const device float& ratio [[ buffer(3) ]],
                uint2                          gid         [[thread_position_in_grid]])
{

    half4 color1  = inTexture1.read(gid);
    half4 color2  = inTexture2.read(gid);
    outTexture.write(half4(color1.rgb, color2.a), gid);
}

kernel void pixellateKernel(texture2d<float, access::read> inTexture [[ texture(2) ]],
                            texture2d<float, access::write> outTexture [[ texture(3) ]],
                            uint2 gid [[ thread_position_in_grid ]]) {

    const float pixelSize = 3.0;
    uint2 position = uint2(floor(gid.x/pixelSize)*pixelSize,
                           floor(gid.y/pixelSize)*pixelSize);
    float4 finalColor = inTexture.read(position);
    outTexture.write(finalColor, gid);
}


kernel void alpha(texture2d<half, access::read>  inTexture2  [[texture(2)]],
    texture2d<half, access::read>  inTexture1  [[texture(3)]],
    texture2d<half, access::write> outTexture [[texture(4)]],
    const device float& tween [[ buffer(3) ]],
    uint2 gid [[thread_position_in_grid]])
{
    half4 color1  = inTexture1.read(gid);
    half4 color2  = inTexture2.read(gid);
    outTexture.write(half4(mix(color1.rgb, color2.rgb, half(tween)), color1.a), gid);
}

kernel void boxBlurKernel(texture2d<float, access::read> inTexture1 [[ texture(2) ]],
                          texture2d<float, access::write> outTexture [[ texture(3) ]],
                          constant bool &shouldBlur [[buffer(4)]],
                          uint2 gid [[ thread_position_in_grid]]) {
    float blurSize = 27;
    if (shouldBlur) {
        int range = floor(blurSize/2.0);

        float4 colors = float4(0);
        for (int x = -range; x <= range; x++) {
            for (int y = -range; y <= range; y++) {
                float4 color = inTexture1.read(uint2(gid.x+x,
                                                    gid.y+y));
                colors += color;
            }
        }
        float4 finalColor = colors/float(blurSize*blurSize);
        outTexture.write(finalColor, gid);
    } else {
        float4 orig = inTexture1.read(gid);
        outTexture.write(orig, gid);
    }

}

