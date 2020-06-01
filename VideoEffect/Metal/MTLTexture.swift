//
//  MTLTexture.swift
//  VideoEffect
//
//  Created by TT on 5/22/20.
//  Copyright © 2020 NTP. All rights reserved.
//

import Metal
import UIKit
import MetalPerformanceShaders

enum SupportedContentMode {
    case scaleAspectFill
    case scaleAspectFit
    case scaleToFill
    
    static func createFromUIViewContentMode(_ contentMode: UIView.ContentMode) -> SupportedContentMode? {
        switch contentMode {
        case .scaleAspectFill: return .scaleAspectFill
        case .scaleAspectFit: return .scaleAspectFit
        case .scaleToFill: return .scaleToFill
        default: return nil
            
        }
    }
}

extension MTLTexture {
    func getScaleTransform(to texture: MTLTexture, contentMode: SupportedContentMode) -> MPSScaleTransform {
        
        var scaleX: Double
        var scaleY: Double
        
        switch contentMode {
        case .scaleToFill:
            scaleX = Double(texture.width) / Double(self.width)
            scaleY = Double(texture.height) / Double(self.height)
        case .scaleAspectFill:
            scaleX = Double(texture.width) / Double(self.width)
            scaleY = Double(texture.height) / Double(self.height)
            
            if scaleX > scaleY {
                scaleY = scaleX
            } else {
                scaleX = scaleY
            }
        case .scaleAspectFit:
            scaleX = Double(texture.width) / Double(self.width)
            scaleY = Double(texture.height) / Double(self.height)
            
            if scaleX > scaleY {
                scaleX = scaleY
            } else {
                scaleY = scaleX
            }
        }
        
        let translateX: Double = (Double(texture.width) - Double(self.width) * scaleX) / 2
        let translateY: Double = (Double(texture.height) - Double(self.height) * scaleY) / 2
        return MPSScaleTransform(scaleX: scaleX, scaleY: scaleY, translateX: translateX, translateY: translateY)
    }
}

