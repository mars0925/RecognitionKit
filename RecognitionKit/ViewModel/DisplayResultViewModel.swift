//
//  CustomCameraViewModel.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/2/1.
//

import Foundation
import UIKit
import Combine
import Vision

class DisplayResultViewModel:NSObject {
    private var objectDetectionHelper: ObjectDetectionHelper?
    private var cancellabe = Set<AnyCancellable>()
    private var deviceType:DeviceType = .undefined //裝置的類型
    @Published var errorMessage:String? ///errorMessage值
    @Published private (set) var dataList:[DetectResultItem] = [DetectResultItem]()
    
    
    override init() {
        super.init()
        
        objectDetectionHelper = ObjectDetectionHelper(
            modelFileInfo: FileInfo(tfliteName, "tflite"),
            threadCount: threadCount,
            scoreThreshold: scoreThreshold,
            maxResults: maxResults
        )
        
        guard objectDetectionHelper != nil else {
            print("Failed to create the ObjectDetectionHelper. See the console for the error.")
            return
        }
    }
    
    func startDetect(image: UIImage)-> AnyPublisher<([DetectImageResult]?,[DetectImageResult]?),Never>{
        guard let buffer = image.createPixelBuffer() else {
            return Just((nil, nil)).eraseToAnyPublisher()
        }
        
        //同時執行並等待兩個異步任務
        return Publishers.CombineLatest(detect(buffer: buffer), recognizeTextByIos(image: image))
            .eraseToAnyPublisher()
    }
    
    ///以自己訓練的模式辨識出七段線
    func detect(buffer:CVPixelBuffer) -> AnyPublisher<[DetectImageResult]?,Never> {
        return Future { promise in
            DispatchQueue.global().async { [weak self] in
                
                guard let result =  self?.objectDetectionHelper?.detect(frame: buffer) else {
                    promise(.success(nil))
                    return
                }
                
                var dataArray = [DetectImageResult]()
                result.detections.forEach { detection in
                    let index = detection.categories.first?.index ?? 0
                    let text = classList[index]
                    let confidence = detection.categories.first?.score ?? 0
                    let boundingBox = detection.boundingBox
                    var data:DetectImageResult
                    ///index > 9 為  "mgdl", "mmol","°C" 等標籤 非數字
                    if index > 9{
                        data = DetectImageResult(boundingBox: boundingBox, text: text, score: String(confidence), source: .MARK)
                    }else {
                        data = DetectImageResult(boundingBox: boundingBox, text: text, score: String(confidence), source: .NUMBER)
                    }

                    dataArray.append(data)
                }
                
                promise(.success(dataArray))
            }
            
        }.eraseToAnyPublisher()
    }
    ///以ios的文字辨識模型辨識文字
    func recognizeTextByIos(image: UIImage)->AnyPublisher<[DetectImageResult]?, Never> {
        return Future { promise in
            
            guard let cgImage = image.cgImage else {
                promise(.success(nil))
                return
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNRecognizeTextRequest { [unowned self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    promise(.success(nil))
                    return
                }
                var dataArray = [DetectImageResult]()
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    // 獲取文字內容
                    let text = topCandidate.string
                    
                    // 獲取信心水準
                    let confidence = topCandidate.confidence
                    
                    // 轉換矩形框位置至 UIKit 座標系統
                    let boundingBox = observation.boundingBox
                    let convertBoundingBox = convertBoundingBoxToUIKitCoordinates(boundingBox: boundingBox, imageSize: image.size)
                    
                    // 打印文字內容、信心水準以及矩形框位置
                    let data = DetectImageResult(boundingBox: convertBoundingBox, text: text, score: String(confidence), source: .TEXT)
                    dataArray.append(data)
                    
                }
                promise(.success(dataArray))
            }
            
            // 默认情况下不会识别中文，需要手动指定 recognitionLanguages
            // zh-Hans 是简体中文
            // zh-Hant 是繁体中文
            request.recognitionLanguages = ["zh-Hans", "zh-Hant"]
            request.usesLanguageCorrection = true
            request.customWords = customWords
            do {
                try handler.perform([request])
            } catch {
                print(error)
                promise(.success(nil))
            }
        }.eraseToAnyPublisher()
    }
    
    ///轉換VNRecognizedTextObservation 矩形框至符合 UIKit座標系統，可以直接畫在uiImage
    func convertBoundingBoxToUIKitCoordinates(boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        // 将 Vision 框架的归一化坐标转换为实际像素坐标
        let x = boundingBox.origin.x * imageSize.width
        let y = (1 - boundingBox.origin.y - boundingBox.height) * imageSize.height
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /**將偵測的數字從左到右分列排列
     @return LinkedHashMap<Int, List<DetectObject>> key 代表第幾列 ,List 存放此列的數字
     */
    func parseByRow(resultList: [DetectImageResult]) -> [Int: [DetectImageResult]] {
        // 平均高度
        let averageHeight = resultList.filter {
            $0.boundingBox.height >= 10
        }.map {
            $0.boundingBox.height
        }.reduce(0, +) / Double(resultList.count)
        
        var rowMap = [Int: [DetectImageResult]]()
        var numberList = [(Int, DetectImageResult)]() // (行號, 檢測結果)
        let sorted = resultList.sorted(by: {
//            $0.boundingBox.midY < $1.boundingBox.midY
            $0.boundingBox.maxY < $1.boundingBox.maxY
        })
        
        var i = 0 // 初始化行號變數
        var firstItemY: CGFloat = 0.0 // 用來記錄每一行的第一個元素的 Y 軸位置
        var firstItemHeight = sorted[0].boundingBox.height
        let h = averageHeight / 2 // 平均高度的一半，用於行距的閾值
        
        for each in sorted {
            let d = abs(firstItemY - each.boundingBox.midY) // 計算 firstItemY 和當前元素 boundingBox.midY 之間的差異 d
//            let diffHeight = abs(firstItemHeight - each.boundingBox.height) // 計算 firstItemHeight 和當前元素高度之間的差異
            
            let max = max(firstItemHeight, each.boundingBox.height)
            let min = min(firstItemHeight, each.boundingBox.height)
            let diffHeight = max * 0.5 > min // 相差超過一半

            
            // 如果差異 d 大於 h 或者高度差異超過 40，則表示進入新的一行，將 i 自增並更新 firstItemY
            if d > h || diffHeight {
                i += 1
                firstItemY = each.boundingBox.midY
                firstItemHeight = each.boundingBox.height
            }
            
            numberList.append((i, each))
        }
        
        // 使用 Set 獲取所有行號並對其進行遍歷
        let rowSet = Set(numberList.map { $0.0 })
        
        // 對於每一行號，使用 filter 從 numberList 中取出該行的結果，並按 boundingBox.midX 進行排序
        // 將排序後的結果存儲到 rowMap
        for row in rowSet {
            let datas = numberList.filter { $0.0 == row }.map { $0.1 }
            
            if !datas.isEmpty {
                let sort = datas.sorted(by: {
                    $0.boundingBox.midX < $1.boundingBox.midX
                })
                
                rowMap[row] = sort
            }
        }
        
        // 調試或驗證結果
        rowMap.forEach { (i, list) in
            var result = ""
            list.forEach {
                result += $0.text
            }
            print("Row \(i): \(result)")
        }
        
        return rowMap
    }

    
    /// 判斷什麼裝置
    func checkDevice(resultList: [DetectImageResult], numberByRow: [Int: [DetectImageResult]]) {
        let mapList = resultList.map { $0.text }
        
    outerLoop: for each in mapList {
        // 檢查是否為血壓計
        for i in bmText {
            let isContainsElement = ["SYS", "DIA", "BPM"].contains(i)
            
            if isContainsElement {
                let regex = try! NSRegularExpression(pattern: "^\(i)", options: .caseInsensitive)
                let matches = regex.matches(in: each, options: [], range: NSRange(location: 0, length: each.utf16.count))
                if !matches.isEmpty {
                    deviceType = .bpm
                    break outerLoop
                }
            } else if each.localizedCaseInsensitiveContains(i) {
                deviceType = .bpm
                break outerLoop
            }
        }
        
        // 檢查是否為血糖機
        for i in bsText {
            if i == "mg" {
                let regex = try! NSRegularExpression(pattern: "^\(i)", options: .caseInsensitive)
                let matches = regex.matches(in: each, options: [], range: NSRange(location: 0, length: each.utf16.count))
                if !matches.isEmpty {
                    deviceType = .bloodSugarMeter
                    break outerLoop
                }
            } else if each.localizedCaseInsensitiveContains(i) {
                deviceType = .bloodSugarMeter
                print("辨識成血糖機")
                break outerLoop
            }
        }
        
        // 檢查是否為體重計
        for i in wmText {
            if each.localizedCaseInsensitiveContains(i) {
                deviceType = .scale
                break outerLoop
            }
        }
        
        //檢查是否為溫度計
        for i in celsiusText {
            if each.localizedCaseInsensitiveContains(i) {
                deviceType = .thermometer
                break outerLoop
            }
        }
    }
        
        // 三排字以上，則判斷為血壓計
        if numberByRow.keys.count >= 3 && deviceType == .undefined {
            deviceType = .bpm
        }
        
        //前面都沒有符合的話 設定為溫度計
        if deviceType == .undefined {
            deviceType = .thermometer
        }
        
        // 使用 deviceType 做後續處理
        // 例如更新 UI 或進行其他邏輯操作
        print("裝置是：\(deviceType)")
        makeResult(resultList: resultList, numberByRow: numberByRow)
    }
    
    func makeResult(resultList: [DetectImageResult],numberByRow: [Int: [DetectImageResult]]){
        switch deviceType {
        case .bpm:
            let labelRect = locationLabel(resultList: resultList) //設備標籤的位置
            var numberAreaList = parseByColumn(map: numberByRow)
            
            numberAreaList.forEach { areaResult in
                print("血壓計：\(areaResult.text) size:\(areaResult.boundingBox.size) maxY:\(areaResult.boundingBox.maxY)")
            }
            
            //設定收縮壓
            if let sys = labelRect.sys {
                let ans:String = checkValue(rect: sys, data: &numberAreaList)
                dataList.append(DetectResultItem(item: .systolic, value: ans, unit: .mmHg))
                
            }
            //如果沒有辨識出收縮壓標籤位置
            else {
                let ans = setSysNumber(numberAreaList: numberAreaList)
                dataList.append(DetectResultItem(item: .systolic, value: ans, unit: .mmHg))
                
            }
            
            //設定舒張壓
            if let dia = labelRect.dia {
                let ans:String = checkValue(rect: dia, data: &numberAreaList)
                dataList.append(DetectResultItem(item: .diastolic, value: ans, unit: .mmHg))
            }else {
                dataList.append(DetectResultItem(item: .diastolic, value: setDiaNumber(numberAreaList: numberAreaList), unit: .mmHg))
            }
            
            //設定脈搏
            if let pulse = labelRect.pulse {
                let ans:String = checkValue(rect: pulse, data: &numberAreaList)
                dataList.append(DetectResultItem(item: .pulse, value: ans, unit: .pulse_unit))
            }else {
                dataList.append(DetectResultItem(item: .pulse, value: setPulse(numberAreaList: numberAreaList), unit: .pulse_unit))
                
            }
            
            break
        case .thermometer:
            let values = numberByRow.values
            
            let filterList = values.filter { resultList in
                resultList.count > 1
            }
            
            guard filterList.isNotEmpty else {return}
            
            
            let maxNumList = filterList.max { previousList, nextList in
                guard let previous = previousList.first , let next = nextList.first else {return false}
                
                return previous.boundingBox.height <  next.boundingBox.height
            }
            
            var result = ""
            
            // 检查 maxNumList 是否为 nil
            if let maxNumList = maxNumList {
                var numText = ""
                
                // 将 maxNumList 中的各元素的文本内容连接成一个字符串
                for each in maxNumList {
                    numText += each.text
                }
                
                // 根据 numText 的长度进行不同的处理
                switch numText.count {
                    // 如果长度为 3
                case 3:
                    // 提取子序列和最后一个字符，并按特定格式组合成结果字符串
                    let subSequence = String(numText.prefix(numText.count - 1))
                    let lastWord = String(numText.suffix(1))
                    result = "\(subSequence).\(lastWord)"
                    // 如果长度为 4
                case 4:
                    // 提取两个不同的子序列，并按特定格式组合成结果字符串
                    let subSequence = String(numText.prefix(numText.count - 2))
                    let lastWord = String(numText.suffix(2))
                    result = "\(subSequence).\(lastWord)"
                    // 如果长度小于或等于 2
                default:
                    // 将 numText 直接赋值给 result
                    result = numText
                }
            }
            
            dataList.append(DetectResultItem(item: .temp, value: result, unit: .temperature_scale_C))
            
            break
        case .bloodSugarMeter:
            
            let values = numberByRow.values
            let filterList = values.filter { resultList in
                resultList.count > 1
            }
            guard filterList.isNotEmpty else {return}
            
            //高度最大的
            let maxNumList = filterList.max { previousList, nextList in
                guard let previous = previousList.first , let next = nextList.first else {return false}
                
                return previous.boundingBox.height <  next.boundingBox.height
            }
            
            let labelList = resultList.map { $0.text }
            
            var unitType: BloodSugarUnit = .undefined
            
            labelList.forEach { label in
                if label.contains("mg"){
                    unitType = .mgDL
                    return
                }else if label.contains("mmo"){
                    unitType = .mmolL
                    return
                }
            }
            
            var result = ""
            switch unitType {
            case .mgDL:
                maxNumList?.forEach { each in
                    result += each.text
                }
                dataList.append(DetectResultItem(item: .bloodSugar, value: result, unit: .mg_dl))
            case .mmolL:
                var numText = ""
                maxNumList?.forEach { each in
                    numText += each.text
                }
                let subSequence = String(numText.dropLast())
                let lastWord = numText.last!
                result = "\(subSequence).\(lastWord)"
                dataList.append(DetectResultItem(item: .bloodSugar, value: result, unit: .mmolL))
            case .undefined:
                var numText = ""
                maxNumList?.forEach { each in
                    numText += each.text
                }
                if numText.count == 2 {
                    let firstWord = numText.first! // 猜它是mmol/L
                    if Int(String(firstWord))! <= 6 {
                        let subSequence = String(numText.dropLast())
                        let lastWord = numText.last!
                        result = "\(subSequence).\(lastWord)"
                        dataList.append(DetectResultItem(item: .bloodSugar, value: result, unit: .mmolL))
                    }
                } else if numText.count == 3 {
                    let firstTwoWord = String(numText.prefix(2)) // 猜它是mg/dL
                    if Int(firstTwoWord)! > 12 {
                        result = numText
                        dataList.append(DetectResultItem(item: .bloodSugar, value: result, unit: .mg_dl))
                    }
                }
                
            }
            
            break
        case .scale:
            break
        case .undefined:
            errorMessage = "無法變置裝置種類"
            break
        }
    }
    
    /**設備標籤的位置*/
    private func locationLabel(resultList: [DetectImageResult]) -> BPMInterface {
        var bpmInterface = BPMInterface()
        if deviceType == .bpm {
            /*忠孝院區 找SYS,DIA ,BMP的label位置*/
            for each in resultList { // Recognized text
                //辨識出的文字
                if each.source == .TEXT { // Matching systolic pressure label
                    //比對收縮壓標籤
                    if bpmInterface.sys == nil {
                        for sys in sysLabelList {
                            if each.text.lowercased().contains(sys.lowercased()) {
                                bpmInterface.sys = each.boundingBox
                                //忠孝院區血壓計 解決辨識出SYSO的時候 SYS標籤過長的問題
                                if each.text.count >= 4 && each.text.lowercased().contains("sy") {
                                    let newWidth = bpmInterface.sys!.width / 3
                                    let newBoundingBox = CGRect(x: bpmInterface.sys!.origin.x, y: bpmInterface.sys!.origin.y, width: newWidth, height: bpmInterface.sys!.height)
                                    bpmInterface.sys = newBoundingBox
                                }
                                
                                break
                            }
                        }
                    }
                    
                    //比對舒張壓標籤
                    if bpmInterface.dia == nil {
                        for dia in diaLabelList {
                            if each.text.lowercased().contains(dia.lowercased()) {
                                bpmInterface.dia = each.boundingBox
                                break
                            }
                        }
                    }
                    
                    //比對map標籤
                    for map in mapLabelList {
                        if each.text.count <= 4 {
                            if each.text.lowercased().contains(map.lowercased()) {
                                bpmInterface.map = each.boundingBox
                                break
                            }
                        }
                    }
                    
                    //比對脈搏標籤
                    if bpmInterface.pulse == nil {
                        for pulse in pulseLabelList {
                            if each.text.lowercased().contains(pulse.lowercased()) {
                                bpmInterface.pulse = each.boundingBox
                                break
                            }
                        }
                    }
                    
                    //比對mmHg單位
                    if each.text.lowercased().contains("mm") {
                        bpmInterface.mmHgList.append(each.boundingBox)
                    }
                }
            }
        }
        
        /*如果收縮壓的標籤沒有辨識出來*/
        if bpmInterface.sys == nil {
            if bpmInterface.mmHgList.count == 2 {
                /*兩個mmHg是上下排列*/
                if bpmInterface.mmHgList[0].centerX >= bpmInterface.mmHgList[1].minX && bpmInterface.mmHgList[0].centerX <= bpmInterface.mmHgList[1].maxX { // Position of higher mmHg
                    bpmInterface.sys = bpmInterface.mmHgList.min(by: { $0.top < $1.top })
                }
                /*兩個mmHg是左右排列*/
                if bpmInterface.mmHgList[0].centerY >= bpmInterface.mmHgList[1].top && bpmInterface.mmHgList[0].centerY <= bpmInterface.mmHgList[1].bottom {
                    bpmInterface.sys = bpmInterface.mmHgList.min(by: { $0.centerX < $1.centerX })
                }
            }
        }
        
        /*如果舒張壓的標籤沒有辨識出來*/
        if bpmInterface.dia == nil {
            if bpmInterface.mmHgList.count == 2 {
                /*兩個mmHg是上下排列*/
                if bpmInterface.mmHgList[0].centerX >= bpmInterface.mmHgList[1].left && bpmInterface.mmHgList[0].centerX <= bpmInterface.mmHgList[1].right { // Position of lower mmHg
                    bpmInterface.dia = bpmInterface.mmHgList.max(by: { $0.centerY < $1.centerY })
                }
                
                /*兩個mmHg是左右排列*/
                if bpmInterface.mmHgList[0].centerY >= bpmInterface.mmHgList[1].top && bpmInterface.mmHgList[0].centerY <= bpmInterface.mmHgList[1].bottom { // Lower mmHg position
                    bpmInterface.dia = bpmInterface.mmHgList.max(by: { $0.centerX < $1.centerX })
                }
            }
        }
        
        return bpmInterface
    }
    
    
    /**
     * 根據行的位置，剖析是否始於同一區域的數字
     *@return ArrayList<NumBerArea> 數字區域的集合
     */
    private func parseByColumn(map: [Int: [DetectImageResult]]) -> [NumBerArea] {
        var rowMap = [Int: [DetectImageResult]]() // key: 第幾個區域, value: list 表示相同區域的數字集合
        var areaList = [NumBerArea]() // 數字區域的集合
        var i = 0 // 不同區塊
        var numberList = [(Int, DetectImageResult)]()
        let keys = map.keys
        
        for key in keys {
            guard let list = map[key] else { continue }
            
            // 相鄰元素centerX距離
            // 根據每個矩形框的中心x坐標進行排序
            let sortedRects = list.sorted(by: { $0.boundingBox.midX < $1.boundingBox.midX })
            // 計算相鄰矩形框中心x的距離
            var centerXList: [CGFloat] = []
            
            for i in 0..<sortedRects.count - 1 {
                let currentRect = sortedRects[i]
                let nextRect = sortedRects[i + 1]
                let distance = nextRect.boundingBox.midX - currentRect.boundingBox.midX
                centerXList.append(abs(distance))
            }
            
            
            let diffCenterX = centerXList.average() * 1.3
            
            var lastItem: DetectImageResult?
            for (index, item) in list.enumerated() {
                
                let currentCenterX =  lastItem?.boundingBox.centerX ?? 0
                let nowItem = item
                // 每一列一開始
                if index == 0 {
                    i += 1
                }
                // 或者相鄰兩個數字距離大於diffCenterX且沒有交集
                else if abs(currentCenterX - nowItem.boundingBox.centerX) > diffCenterX {
                    if getIou(nowItem.boundingBox, lastItem!.boundingBox) <= 0.0 {
                        i += 1
                    }
                }
                
                numberList.append((i, nowItem))
                lastItem = nowItem
            }
        }
        
        let areaSet = Set(numberList.map { $0.0 })
        
        for row in areaSet {
            let datas = numberList.filter { $0.0 == row }.map { $0.1 }
            
            if !datas.isEmpty {
                let sortedDatas = datas.sorted { $0.boundingBox.centerX < $1.boundingBox.centerX }
                
                rowMap[row] = sortedDatas
            }
        }
        
        // 將辨識出的數字結合成一個 NumBerArea
        for (_, value) in rowMap {
            if !value.isEmpty {
                var left = value[0].boundingBox.minX
                var top = value[0].boundingBox.minY
                var right = value[0].boundingBox.maxX
                var bottom = value[0].boundingBox.maxY
                var text = ""
                
                for obj in value {
                    if left > obj.boundingBox.minX { left = obj.boundingBox.minX }
                    if top > obj.boundingBox.minY { top = obj.boundingBox.minY }
                    if right < obj.boundingBox.maxX { right = obj.boundingBox.maxX }
                    if bottom < obj.boundingBox.maxY { bottom = obj.boundingBox.maxY }
                    text += obj.text
                }
                
                areaList.append(NumBerArea(boundingBox: CGRect(x: left, y: top, width: right - left, height: bottom - top), text: text))
            }
        }
        
        return areaList
    }
    
    /// 移除重疊過高的BoundingBoxes
    /// - Parameters:
    ///   - boxes: BoundingBox列表
    ///   - limit: 最高個數
    ///   - threshold: 重疊面積不得超過的比例
    /// - Returns: 篩選後的BoundingBox列表
    func removeOverlapBoundingBoxes(boxes: [DetectImageResult], limit: Int = 20, threshold: Double = 0.50) -> [DetectImageResult] {
        // 按信心分數從高到低排序
        let sortedList = boxes.sorted { $0.score > $1.score }
        
        var selected = [DetectImageResult]()
        var active = Array(repeating: true, count: boxes.count) //[true,..] 都是true的陣列
        var numActive = active.count
        
        var done = false
        var i = 0
        while i < sortedList.count && !done {
            if active[i] {
                let boxA = sortedList[i]
                selected.append(boxA)
                if selected.count >= limit { break }
                
                for j in (i + 1)..<boxes.count {
                    if active[j] {
                        let boxB = sortedList[j]
                        if getIou(boxA.boundingBox, boxB.boundingBox) > threshold  {
                            active[j] = false
                            numActive -= 1
                            if numActive <= 0 {
                                done = true
                                break
                            }
                        }
                    }
                }
            }
            i += 1
        }
        return selected
    }
    
    /**計算兩個矩形框重疊比例*/
    private func getIou(_ rectA: CGRect, _ rectB: CGRect) -> CGFloat {
        let areaA = rectA.width * rectA.height
        if areaA <= 0 { return 0.0 }
        let areaB = rectB.width * rectB.height
        if areaB <= 0 { return 0.0 }
        
        let intersectionMinX = max(rectA.minX, rectB.minX)
        let intersectionMinY = max(rectA.minY, rectB.minY)
        let intersectionMaxX = min(rectA.maxX, rectB.maxX)
        let intersectionMaxY = min(rectA.maxY, rectB.maxY)
        let intersectionWidth = max(0, intersectionMaxX - intersectionMinX)
        let intersectionHeight = max(0, intersectionMaxY - intersectionMinY)
        let intersectionArea = intersectionWidth * intersectionHeight
        
        return intersectionArea / (areaA + areaB - intersectionArea)
    }
    
    
    /// 根據標籤和數字的位置，判斷數字屬於哪一個標籤
    /// - Parameters:
    ///   - rect: 標籤的位置（矩形框）
    ///   - data: 包含數字及其位置的列表
    /// - Returns: 與標籤相關的數字的值
    func checkValue(rect: CGRect, data: inout [NumBerArea]) -> String {
        var result: String = "" // 最終結果
        
        // 篩選出位於標籤左右兩側的數字，並滿足特定條件
        let leftAndRightList = data.filter { numberArea in
            numberArea.text.count >= 2 && numberArea.text.count <= 3 &&
            Int(numberArea.text)! >= 39 && Int(numberArea.text)! <= 270 &&
            (rect.midY >= numberArea.boundingBox.minY && rect.midY <= numberArea.boundingBox.maxY)
        }
        
        // 篩選出位於標籤上下兩側的數字，並滿足特定條件
        let upAndDownList = data.filter { numberArea in
            numberArea.text.count >= 2 && numberArea.text.count <= 3 &&
            Int(numberArea.text)! >= 39 && Int(numberArea.text)! <= 270 &&
            (rect.midX >= numberArea.boundingBox.minX && rect.midX <= numberArea.boundingBox.maxX)
        }
        
        // 決定哪個數字最接近標籤
        if !leftAndRightList.isEmpty || !upAndDownList.isEmpty {
            var closestNumberArea: NumBerArea? // 最接近的數字區域
            
            // 在水平或垂直方向上尋找最接近的數字
            if let closestInHorizontal = leftAndRightList.min(by: { abs(rect.midX - $0.boundingBox.midX) < abs(rect.midX - $1.boundingBox.midX) }),
               let closestInVertical = upAndDownList.min(by: { abs(rect.midY - $0.boundingBox.midY) < abs(rect.midY - $1.boundingBox.midY) }) {
                
                let distanceHorizontal = hypot(rect.midX - closestInHorizontal.boundingBox.midX, rect.midY - closestInHorizontal.boundingBox.midY)
                let distanceVertical = hypot(rect.midX - closestInVertical.boundingBox.midX, rect.midY - closestInVertical.boundingBox.midY)
                
                // 根據距離選擇最接近的數字
                closestNumberArea = distanceHorizontal < distanceVertical ? closestInHorizontal : closestInVertical
            } else if let closestInHorizontal = leftAndRightList.min(by: { abs(rect.midX - $0.boundingBox.midX) < abs(rect.midX - $1.boundingBox.midX) }) {
                closestNumberArea = closestInHorizontal
            } else if let closestInVertical = upAndDownList.min(by: { abs(rect.midY - $0.boundingBox.midY) < abs(rect.midY - $1.boundingBox.midY) }) {
                closestNumberArea = closestInVertical
            }
            
            // 更新結果並從數據列表中移除已選擇的數字
            if let selectedNumber = closestNumberArea {
                result = selectedNumber.text
                data.removeAll { $0.text == selectedNumber.text && $0.boundingBox == selectedNumber.boundingBox }
            }
        }
        
        return result
    }
    
    /// 設定收縮壓數字
    /// 數字必須在39到270之間，這是血壓值的常見範圍。
    //如果有多個數字符合上述條件，則選擇最大的一個數字作為收縮壓的值。
    //如果沒有任何數字符合條件，則將收縮壓的值設為空字符串。
    /// - Parameter numberAreaList: 包含數字及其對應區域的列表
    func setSysNumber(numberAreaList: [NumBerArea]) ->String {
        if numberAreaList.isEmpty { return ""}
        
        let resultAns = numberAreaList.filter { numBerArea in
            let text = Int(numBerArea.text) ?? 0
            return text >= 39 && text <= 270
        }.max { previous,next in
                let previousNum = Int(previous.text) ?? 0
                let nextNum = Int(next.text) ?? 0
                return previousNum < nextNum
        }
        
        print(resultAns)
        
        return resultAns?.text ?? ""
        
    }
    
    /**找不到Dia標籤時 設定dia 數字*/
    private func setDiaNumber(numberAreaList: [NumBerArea]) -> String {
        guard numberAreaList.isNotEmpty else { return ""}
        
        let sortList = numberAreaList.sorted { previous, next in
            let previousNum = Int(previous.text) ?? 0
            let nextNum = Int(next.text) ?? 0
            return previousNum > nextNum
        }
        
        // 找到最大的数字
        guard let maxNum = sortList.first else { return ""}
        
        // 过滤出符合范围且不是最大值的数字
        let filter = sortList.filter { numBerArea in
            guard let text = Int(numBerArea.text), (39...270).contains(text) else { return false }
            return numBerArea.text != maxNum.text
        }
        
        // 如果过滤后的列表不为空，则计算距离最大值最近的数字作为 "dia" 数字
        if let result = filter.min(by: { hypot(Double(maxNum.boundingBox.midX - $0.boundingBox.midX), Double(maxNum.boundingBox.midY - $0.boundingBox.midY)) < hypot(Double(maxNum.boundingBox.midX - $1.boundingBox.midX), Double(maxNum.boundingBox.midY - $1.boundingBox.midY)) })?.text {
            return result
        }
        
        return ""
    }
    
    /**找不到pulse標籤時 設定pulse 數字*/
    private func setPulse(numberAreaList: [NumBerArea]) -> String{
        // 确保输入的数组不为空
        guard numberAreaList.isNotEmpty else { return ""}
        
        // 过滤出符合范围的元素
        let filter = numberAreaList.filter { numBerArea in
            // 将文本转换为整数，然后检查是否在指定范围内
            guard let text = Int(numBerArea.text) else { return false }
            return (39...270).contains(text)
        }
        
        // 如果过滤后的数组不为空，则找到位置最下方的元素
        if filter.isNotEmpty {
            // 使用元素的中心 Y 坐标进行比较，找到位置最下方的元素
            if let result = filter.max(by: { $0.boundingBox.midY < $1.boundingBox.midY })?.text {
                return result
            }
        }
        
        return ""
    }
    
    
    ///移除項目
    func removeData(at index: Int){
        dataList.remove(at: index)
    }
    
    
    ///新增項目
    func addData(at item:String){
        guard let data = MeterData.from(displayName: item) else {
            return
        }
        print("新增項目:\(data)")
        
        let result = DetectResultItem(item: data, value: "0", unit: data.unit)
        
        dataList.append(result)
        
        for index in dataList.indices{
            let item = dataList[index]
            print("\(index),\(item.item.displayName),\(item.value),\(item.unit.displayName)")
            
        }
        
    }
    
    
    //更新單位
    func updateUnit(at index: Int,unitDisplay:String){
        let data = dataList[index]
        
        let update = DetectResultItem(item: data.item, value: data.value, unit: UnitType.from(displayName: unitDisplay)!)
        
        dataList[index] = update
        
    }
    //更新數值
    func updateValue(at index:Int, value:String){
        let data = dataList[index]
        let update = DetectResultItem(item: data.item, value: value, unit: data.unit)
        dataList[index] = update
    }
    
    ///處理照片角度問題，有傾斜的話轉正
    func processPhotoRotation(image:UIImage)->Future<UIImage, Never>{
        return Future { [unowned self] promise in
            guard let buffer = image.createPixelBuffer() else {
                return
            }
            
            detect(buffer: buffer)
                .sink { [unowned self] resultList in
                    guard let dataList = resultList else {return}
                    
                    let angle = getAngle(image: image, dataList: dataList)
                    
                    if abs(angle) > 0.15 {
                        promise(.success(image.rotate(radians: angle)))
                    }else{
                        promise(.success(image))
                    }
                }
                .store(in: &cancellabe)
        }
    }
    
    ///取得圖片偏斜角度
    func getAngle(image:UIImage,dataList:[DetectImageResult])->CGFloat{
        guard dataList.isNotEmpty else {return 0}
        
        let NUMBERList = dataList.filter {$0.source == .NUMBER}
        
        //以y排序
        var newList = NUMBERList.sorted {
            $0.boundingBox.origin.y < $1.boundingBox.origin.y
        }
        
        let topBox = newList[0]
        newList.remove(at: 0)
        //找尋跟topBox相同大小的字
        let filterList = newList.filter {
            abs($0.boundingBox.height - topBox.boundingBox.height) < 40
        }
        
        //距離最近的
        let secondaryBox = filterList.min {
            // 取得兩個矩形的原點
            let origin0 = $0.boundingBox.origin
            let origin1 = $1.boundingBox.origin
            
            let distance0 = getDistance(origin1: origin0, origin2: topBox.boundingBox.origin)
            let distance1 = getDistance(origin1: origin1, origin2: topBox.boundingBox.origin)
            
            return distance0 < distance1
        }
        
        guard let secondaryBox = secondaryBox else {return 0 }
        
        if topBox.boundingBox.origin.x >  secondaryBox.boundingBox.origin.x {
            let radious = atan2(-(topBox.boundingBox.origin.y - secondaryBox.boundingBox.origin.y), topBox.boundingBox.origin.x - secondaryBox.boundingBox.origin.x)
            return radious
        }else {
            let radious = atan2(-(secondaryBox.boundingBox.origin.y - topBox.boundingBox.origin.y), secondaryBox.boundingBox.origin.x - topBox.boundingBox.origin.x)
            return radious
        }
    }
    
    ///計算兩點距離
    func getDistance(origin1: CGPoint, origin2: CGPoint) -> CGFloat {
        // 計算兩點之間的x和y差值
        let deltaX = origin2.x - origin1.x
        let deltaY = origin2.y - origin1.y
        
        // 使用畢氏定理計算距離
        let distance = sqrt(pow(deltaX, 2) + pow(deltaY, 2))
        return distance
    }
    
    
}
