//
//  GlobalFunction.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/2/1.
//

import Foundation
import UIKit



/// 計算照相預覽鏡頭中矩形在照片的位置
/// - Parameters:
///   - previewLayer: 照相預覽畫面
///   - originalImage: 照片
///   - rectangleFrame: 照相預覽畫面中矩形的位置和尺寸
/// - Returns: 照相預覽畫面中矩形映射到實際照片的位置以及尺寸
func getScale(previewLayer:UIView,originalImage: UIImage,rectangleFrame:CGRect)->CGRect{
    let previewLayerSize = previewLayer.frame.size // AVCaptureVideoPreviewLayer的尺寸
    let actualPhotoSize = originalImage.size // 实际照片的尺寸

    // 计算缩放比例
    let scaleX = actualPhotoSize.width / previewLayerSize.width
    let scaleY = actualPhotoSize.height / previewLayerSize.height

    // 应用缩放比例（和必要的偏移量）以计算矩形框在照片中的位置
    let actualRectangleX = rectangleFrame.origin.x * scaleX
    let actualRectangleY = (rectangleFrame.origin.y) * scaleY //加上40是加上導航欄的高度
    let actualRectangleWidth = rectangleFrame.size.width * scaleX
    let actualRectangleHeight = rectangleFrame.size.height * scaleY

    let actualRectangleFrame = CGRect(x: actualRectangleX, y: actualRectangleY, width: actualRectangleWidth, height: actualRectangleHeight)
    return actualRectangleFrame
}


/// 裁切圖片
/// - Parameters:
///   - originalImage: 原始圖片
///   - rect: 裁缺的矩形
/// - Returns: 裁切的照片
func cropImage(originalImage: UIImage, toRect rect: CGRect) -> UIImage? {
    // 定義裁切區域的尺寸，這裡以圖像中心的一半大小為例
    let cropSize = CGSize(width: rect.width, height: rect.height)
    // 創建一個UIGraphicsImageRenderer來繪製新的圖像
    let renderer = UIGraphicsImageRenderer(size: cropSize)
    
    // 計算裁切區域的原點，使得裁切的圖像部分居中
    let x = (originalImage.size.width - cropSize.width) / 2
    let y = (originalImage.size.height - cropSize.height) / 2

    let image = renderer.image { _ in
        // 計算要繪製的原圖像的區域和位置
        originalImage.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
    }
    
    return image
}

/**叫用Storyboard頁面*/
func viewControllerWithID(vcID : String,sbID : String) -> UIViewController!{
    let storyboard : UIStoryboard = UIStoryboard(name: sbID, bundle: Bundle.main)
    return storyboard.instantiateViewController(withIdentifier: vcID)
}
