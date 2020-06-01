//
//  Renderer.swift
//  VideoEffect
//
//  Created by TT on 5/22/20.
//  Copyright © 2020 NTP. All rights reserved.
//

import Foundation
import MetalKit

class Renderer {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    static let sharedInstance = Renderer()
    
    private init() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice(),
            let queue = defaultDevice.makeCommandQueue() else {
            fatalError("GPU is not supported")
        }
        
        self.device = defaultDevice
        self.commandQueue = queue
    }
    
}
