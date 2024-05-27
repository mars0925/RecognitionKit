//
//  Configuration.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/1/29.
//

import Foundation

let threadCount:Int = 1
let scoreThreshold:Float = 0.3
let maxResults:Int = 15
let tfliteName:String = "model0523"

/**
 * ViewController的storyboard ID
 */
let DISPLAY_RESULT_ID:String = "display_result"

/*storyboard name*/
let RECOGNITION_SB:String = "Recognition"

/// 血壓計面板上的文字。
/// 包含用於識別血壓計的關鍵字，例如 "mmHg", "DIA", "SYS" 等。
let bmText: [String] = [
    "mmHg", "DIA", "SYS", "血壓", "脈拍", "BPM", "收縮", "舒張", "舒张",
    "最高血压", "血压", "脉博", "WatchBP", "/min", "最低", "最高"
]

/// 血糖面板上的文字。
/// 包含用於識別血糖機的關鍵字，例如 "mmo", "/L", "mimo", "mg", "mmol"。
let bsText: [String] = ["mmo", "/L", "mimo", "mg", "mmol"]

/// 體重面板上的文字。
/// 包含用於識別體重計的關鍵字，例如 "kg", "bmi"。
let wmText: [String] = ["kg", "bmi"]
let celsiusText: [String] = ["°C"]


let sysLabelList = ["SYS", "SY", "最高", "最高血", "高压", "高", "收", "縮", "收缩压"] //SYS 標籤
let diaLabelList = ["DIA", "DI", "最低", "最低血", "低压", "低", "舒", "張", "张"] //DIA 標籤
let mapLabelList = ["MAP", "Ma"] //MAP 標籤
let pulseLabelList = ["Pulse", "脈拍", "BPM", "BRM", "PUL", "脈", "拍", "心率", "搏", "脉", "/分", "/min"] //MAP 標籤
let classList = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "mgdl", "mmol","°C"] //辨識模型中的類別

let customWords = [ "mmHg", "DIA", "SYS", "血壓", "脈拍", "BPM", "收縮", "舒張", "舒张",
                    "最高血压","最低血压", "血压", "脉博", "/min", "最低", "最高","Pulse","mg/dL","mmol/L"]
