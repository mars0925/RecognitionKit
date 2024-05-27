//
//  DisplayResultViewController.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/2/1.
//

import UIKit
import Combine
import Vision

///用於關閉照相視窗
protocol DisplayResultControllerDelegate: AnyObject {
    func closeCameraView()
}

public class DisplayResultViewController: UIViewController {
    var imageData:UIImage?
    var delegate:DisplayResultControllerDelegate?
    
    @IBOutlet weak var resultTable: UITableView!
    private let vm = DisplayResultViewModel()
    @IBOutlet weak var pictureImageView: UIImageView!
    var cancellabe = Set<AnyCancellable>()
    
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var editButton: UIButton!
    private var currentTextField:UITextField?
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        monitorKeyboardAction()
        addButton.addTarget(self, action: #selector(addItem), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editItem), for: .touchUpInside)
        
        guard let image = imageData  else {
            print("image is nil")
            return
        }
        
        pictureImageView.image = image
        
        vm.processPhotoRotation(image: image)
            .sink { [unowned self] rotateImage in
                vm.startDetect(image: rotateImage)
                    .receive(on: DispatchQueue.main)
                    .sink { [unowned self] result1, result2 in
                        var dectectResult = [DetectImageResult]()
                        
                        if let result1 = result1 {
                            dectectResult.append(contentsOf: result1)
                        }
                        
                        if let result2 = result2 {
                            dectectResult.append(contentsOf: result2)
                        }
                        
                        
                        dectectResult.forEach { data in
                            print("text:\(data.text),score:\(data.score),來源：\(data.source),rect size:\(data.boundingBox.size)")
                        }

                        /*辨識出的數字列表*/
                        let sevenSegmentNumList = dectectResult.filter { detectImageResult in
                            detectImageResult.source == ModelType.NUMBER
                        }
                        //畫框的列表
                        let drawRectList = dectectResult.filter { detectImageResult in
                            detectImageResult.source == ModelType.NUMBER || detectImageResult.source == ModelType.MARK
                        }
                        
                        let noOverlapNumList = vm.removeOverlapBoundingBoxes(boxes: sevenSegmentNumList) // 移除重疊過高的BoundingBoxes
                        
                        // 把led 數字同一列排出來
                        let numberByRow = vm.parseByRow(resultList: noOverlapNumList)
                        
                        vm.checkDevice(resultList: dectectResult, numberByRow: numberByRow)
                        
                        
                        //畫出結果
                        guard let drawImage = drawRectanglesAndTextOnImage(image: rotateImage,detections: drawRectList) else {return}
                        pictureImageView.image = drawImage
                    }
                    .store(in: &cancellabe)
            }
            .store(in: &cancellabe)

        vm.$dataList
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] value in
                resultTable.reloadData()
            }
            .store(in: &cancellabe)
        
    }
    
    @objc func addItem(){
        let controller = UIAlertController(title: "請選擇新增項目", message: nil, preferredStyle: .actionSheet)
        let names = MeterData.allCases
        
        for name in names {
            let action = UIAlertAction(title: name.displayName, style: .default) { [unowned self] action in
                //選擇項目
                vm.addData(at: action.title!)
                resultTable.reloadData()
            }
            
            controller.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        controller.addAction(cancelAction)
        present(controller, animated: true)
    }
    
    @objc func editItem(){
        resultTable.isEditing = !resultTable.isEditing//切換編輯模式
        editButton.setTitle((resultTable.isEditing) ? "Done" : "Edit", for: .normal) //依照編輯模式切換按鍵title
    }
    
    ///鍵盤顯示時
    @objc func keyboardShown(notification: Notification) {
        guard let currentTextField = currentTextField else { return}
        let info: NSDictionary = notification.userInfo! as NSDictionary
        //取得鍵盤尺寸
        let keyboardSize = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        
        //鍵盤頂部 Y軸的位置
        let keyboardY = self.view.frame.height - keyboardSize.height
        //編輯框底部 Y軸的位置
        let editingTextFieldY = currentTextField.convert(currentTextField.bounds, to: self.view).maxY
        //相減得知, 編輯框有無被鍵盤擋住, > 0 有擋住, < 0 沒擋住, 即是擋住多少
        let targetY = editingTextFieldY - keyboardY
        
        //設置想要多移動的高度
        let offsetY: CGFloat = 20
        
        if self.view.frame.minY >= 0 {
            if targetY > 0 {
                UIView.animate(withDuration: 0.25, animations: {
                    self.view.frame = CGRect(x: 0, y:  -targetY - offsetY, width: self.view.bounds.width, height: self.view.bounds.height)
                })
            }
        }
    }
    
    ///鍵盤隱藏時
    @objc func keyboardHidden(notification: Notification) {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        })
    }
    
    ///監聽鍵盤顯示與隱藏
    func monitorKeyboardAction(){
        let center:NotificationCenter = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardShown),
                           name: UIResponder.keyboardWillShowNotification,
                           object: nil)
        center.addObserver(self, selector: #selector(keyboardHidden),
                           name: UIResponder.keyboardWillHideNotification,
                           object: nil)
    }
    
    func drawRectanglesAndTextOnImage(image: UIImage, detections:[DetectImageResult]) -> UIImage? {
        // 开始图形上下文
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        
        // 绘制原始图片
        image.draw(at: .zero)
        
        // 设置矩形和文字的颜色
        let rectColor = UIColor.red
        rectColor.setStroke() // 设置矩形边框颜色
        
        let textColor = UIColor.red
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 30),
            .foregroundColor: textColor
        ]
        
        for detection in detections {
            let rectangle = detection.boundingBox
            let text = detection.text
            // 绘制矩形
            let rectPath = UIBezierPath(rect: rectangle)
            rectPath.lineWidth = 3
            rectPath.stroke()
            
            // 绘制文字
            let textRect = CGRect(x: rectangle.origin.x + 10, y: rectangle.origin.y + 10, width: rectangle.width, height: rectangle.height / 2) // 根据需要调整文字位置
            text.draw(in: textRect, withAttributes: textAttributes)
        }
        
        // 从上下文中获取新的图片
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // 结束图形上下文
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    deinit {
        print("結束")
    }
    
    ///傳送
    @IBAction func sendResult(_ sender: UIButton) {
        ///傳遞信息
        NotificationCenter.default.post(name: NSNotification.Name("ResultFromRecognitionKit"), object: nil, userInfo: ["data": vm.dataList])
        dismiss(animated: true){ [weak self] in
            self?.delegate?.closeCameraView()
        }
    }
    
    ///重新拍照
    @IBAction func retake(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    /**輕擊鍵盤之外的空白區域關閉虛擬鍵盤*/
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
}

extension DisplayResultViewController:UITableViewDataSource,UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return vm.dataList.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ResultItemCell
        //將隱藏的狀態還原
        cell.unit.isHidden = false
        cell.pupUpButton.isHidden = true
        
        
        let title = vm.dataList[indexPath.row].item.displayName
        let unit = vm.dataList[indexPath.row].unit
        
        cell.title.text = title
        cell.value.text = vm.dataList[indexPath.row].value
        cell.value.tag = indexPath.row
        cell.value.delegate = self
        cell.unit.text = unit.displayName
        cell.selectionStyle = .none // 禁用選中效果
        cell.pupUpButton.showsMenuAsPrimaryAction = true
        
        //血糖
        if title == "血糖" {
            cell.unit.isHidden = true
            cell.pupUpButton.isHidden = false
            
            cell.pupUpButton.menu = UIMenu(children: [
                UIAction(title: unit.displayName, handler: { [unowned self] action in
                    vm.updateUnit(at: indexPath.row, unitDisplay: unit.displayName)
                    resultTable.reloadData()
                }),
                
                UIAction(title: UnitType.bloodSugarDisplayUnit(for: unit), handler: { [unowned self] action in
                    vm.updateUnit(at: indexPath.row, unitDisplay: UnitType.bloodSugarDisplayUnit(for: unit))
                    resultTable.reloadData()
                })
            ])
        }
            

        return cell
    }
    
    //可刪除
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            vm.removeData(at: indexPath.item)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
}

extension DisplayResultViewController: UITextFieldDelegate {
    //當文字欄位正在編輯時調用
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        currentTextField = textField //指定現在是哪一個在編輯
    }
    //當文字欄位完成編輯時調用
    public func textFieldDidEndEditing(_ textField: UITextField) {
        vm.updateValue(at: textField.tag, value: textField.text ?? "")
    }
}
