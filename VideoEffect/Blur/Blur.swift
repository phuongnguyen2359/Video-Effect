//
//  Blur.swift
//  VideoEffect
//
//  Created by TT on 5/22/20.
//  Copyright © 2020 NTP. All rights reserved.
//

import Foundation

struct BlurWeight: Codable {
    let radius: Float
    let weights: [Float]
    let size: Int
}

extension MainViewController {
    func setupBlurWeights() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("weights")
        
        let generateBlock = { [weak self] in
            guard let self = self else { return }
            
            // Number of frame to apply blur
            // let say max duration is 10s
            let numberOfFrames = 10 * 60
            let maxRadius: Float = 14.0
            
            var blurWeights = [BlurWeight]()
            for i in 0..<numberOfFrames {
                let radius = Float(i) / Float(numberOfFrames - 1) * maxRadius
                print(radius)
                let (weights, size) = self.generateBlurWeightTexture(radius: radius)
                let blurWeight = BlurWeight(radius: radius, weights: weights, size: size)
                blurWeights.append(blurWeight)
            }
            
            self.blurWeights = blurWeights
            
            let data = try? JSONEncoder().encode(blurWeights)
            try? data?.write(to: url)
        }
        
        do {
            if let data = try? Data(contentsOf: url) {
                let jsonDecoder = JSONDecoder()
                blurWeights = try jsonDecoder.decode([BlurWeight].self, from: data)
                
            } else {
                generateBlock()
            }
        } catch {
            generateBlock()
        }
    }
    
    func generateBlurWeightTexture(radius: Float) -> ([Float], Int) {
        
        assert(radius >= 0, "Blur radius must be non-negative")
        
        let sigma = radius / 2.0
        let size: Int = Int(round(radius) * 2) + 1
        
        var delta: Float = 0
        var expScale: Float = 0
        if radius > 0.0 {
            delta = (radius * 2) / Float(size - 1)
            expScale = -1 / (2 * sigma * sigma);
        }
        
        var weights = [Float].init(repeating: 0, count: MemoryLayout<Float>.size * size * size)
        
        var weightSum: Float = 0
        var y = -radius
        
        for j in 0..<size {
            
            
            var x = -radius;

            for i in 0..<size {
                
                
                let weight = expf((x * x + y * y) * expScale)
                weights[j * size + i] = weight
                weightSum += weight
                
                x += delta
            }
            
            y += delta
        }
        

        let weightScale = 1 / weightSum
        for j in 0..<size {
            for i in 0..<size {
                weights[j * size + i] *= weightScale;
            }
        }
        
        return (weights, size)
    }

}
