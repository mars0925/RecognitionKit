//
//  UIImage+Extesion.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/2/6.
//

import Foundation
import UIKit


extension UIImage {
    
    ///建立PixelBuffer物件
    func createPixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        
        var pixelBuffer: CVPixelBuffer? = nil
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA) // 修改像素格式
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_32BGRA, pixelBufferAttributes as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let unwrappedBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(unwrappedBuffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(unwrappedBuffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(unwrappedBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        
        guard let cgImage = self.cgImage else { return nil }
        let drawingRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(drawingRect)
        context.draw(cgImage, in: drawingRect)
        
        CVPixelBufferUnlockBaseAddress(unwrappedBuffer, [])
        
        return unwrappedBuffer
    }
    
    ///選轉UIImage radians是弧度不是度數
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            context.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return rotatedImage ?? self
        }
        return self
    }

    
}
