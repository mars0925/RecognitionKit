//
//  CustomViewController.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/1/29.
//

import UIKit
import AVFoundation
import Combine
public class CustomCameraViewController: UIViewController{
    @IBOutlet weak var noticeLabel: UILabel!
    @IBOutlet weak var previewLayer: PreviewView! //鏡頭預覽
    @IBOutlet weak var shutterButton: UIButton! //拍照
    @IBOutlet weak var targetRect: UIView!
    private lazy var cameraFeedManager = CameraFeedManager(previewView: previewLayer)
    private let vm = DisplayResultViewModel()

    
    public override func viewDidLoad() {
        super.viewDidLoad()
        cameraFeedManager.delegate = self
    }
    
    //拍照按鈕
    @objc private func didTapTakePhoto(){
        cameraFeedManager.didTapTakePhoto()
        flashOnce(button: shutterButton, duration: 0.1)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraFeedManager.checkCameraConfigurationAndStartSession()
        shutterButton.layer.cornerRadius = shutterButton.frame.size.width / 2
        shutterButton.layer.borderWidth = 3
        shutterButton.layer.borderColor = UIColor.white.cgColor
        
        targetRect.layer.borderWidth = 3
        targetRect.layer.borderColor = UIColor.red.cgColor
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [unowned self] in
            self.shutterButton.isHidden = false
            self.targetRect.isHidden = false
            self.noticeLabel.isHidden = false
        }
        shutterButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraFeedManager.stopSession()
    }
    
    
    /// 拍照按鈕閃爍效果
    func flashOnce(button: UIButton, duration: TimeInterval = 0.5) {
        UIView.animate(withDuration: duration,
                       animations: {
            button.alpha = 0
        }, completion: { _ in
            UIView.animate(withDuration: duration) {
                button.alpha = 1
            }
        })
    }
    
    //關閉拍照視窗
    @IBAction func close(_ sender: UIButton) {
        dismiss(animated: true)
    }
}


// MARK: CameraFeedManagerDelegate Methods
extension CustomCameraViewController: CameraFeedManagerDelegate {
    //接收照片
    func didPhotoOutput(data: Data) {
        
        guard let image = UIImage(data: data) else {return}
        
        let scale = getScale(previewLayer: previewLayer, originalImage: image, rectangleFrame: targetRect.frame)
        guard let cropImage = cropImage(originalImage: image, toRect: scale) else {return}
        
        let frameworkBundle = Bundle(identifier: "com.solidyear.RecognitionKit")
        let storyboard = UIStoryboard(name: RECOGNITION_SB, bundle: frameworkBundle)
        let vc = storyboard.instantiateViewController(identifier: DISPLAY_RESULT_ID) as! DisplayResultViewController
        
        vc.imageData = cropImage
        vc.delegate = self
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        print("didOutput")
        
    }
    
    // MARK: Session Handling Alerts
    func sessionRunTimeErrorOccurred() {
        
    }
    
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        
    }
    
    func sessionInterruptionEnded() {
        
    }
    
    func presentVideoConfigurationErrorAlert() {
        let alertController = UIAlertController(
            title: "Configuration Failed", message: "Configuration of camera has failed.",
            preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func presentCameraPermissionsDeniedAlert() {
        let alertController = UIAlertController(
            title: "Camera Permissions Denied",
            message:
                "Camera permissions have been denied for this app. You can change this by going to Settings",
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
            
            UIApplication.shared.open(
                URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        present(alertController, animated: true, completion: nil)
        
    }
}


extension CustomCameraViewController :DisplayResultControllerDelegate{
    //關閉回調
    func closeCameraView() {
        dismiss(animated: false)
    }

}
