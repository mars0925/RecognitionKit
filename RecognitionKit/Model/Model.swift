//
//  Model.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/2/6.
//

import Foundation


/**辨識結果類別
 * @param boundingBox 辨識區域
 * @param text 辨識結果
 * @param score 信心指數
 * @param source 來自的模型 text, number
 * */
struct DetectImageResult{
    let boundingBox:CGRect
    let text:String
    let score:String
    let source:ModelType
}

import UIKit

/**血壓計介面
 * @property sys 收縮壓
 * @property dia 舒張壓
 * @property pulse 脈搏
 * @property map 平均動脈壓
 * @property mmHgList mmHg的位置
 * */
struct BPMInterface {
    var sys: CGRect?
    var dia: CGRect?
    var pulse: CGRect?
    var map: CGRect?
    var mmHgList: [CGRect] = []
}

struct NumBerArea{
    let boundingBox: CGRect
    let text: String
}


/**辨識模型類別
 TEXT:ios文字辨識的結果
 NUMBER：自以訓練的模型辨識出的七斷線數字
 MARK：自以訓練的模型辨識出的單位，如："mgdl", "mmol","°C"
 */
enum ModelType {
    case TEXT,NUMBER,MARK
}


/// 辨識裝置類型的列舉。
///
/// - Note: 提供了五種不同的裝置類型，用於識別各種健康監測裝置。
enum DeviceType {
    /// 血壓計: 用於測量血壓的裝置。
    case bpm
    
    /// 溫度計: 用於測量體溫的裝置。
    case thermometer
    
    /// 血糖機: 用於測量血糖的裝置。
    case bloodSugarMeter
    
    /// 體重計: 用於測量體重的裝置。
    case scale
    
    /// 未定: 尚未定義的裝置類型。
    case undefined
}


/// 代表測量血糖水平的單位。
enum BloodSugarUnit {
    case mgDL // 毫克/分升
    case mmolL // 毫摩爾/升
    case undefined // 未定義

    /// 返回每個血糖單位的顯示名稱。
    var displayName: String {
        switch self {
        case .mgDL:
            return "mg/dL" // 表示毫克/分升
        case .mmolL:
            return "mmol/L" // 表示毫摩爾/升
        case .undefined:
            return "未定" // 表示未定義的單位
        }
    }
}

///辨識結果
public struct DetectResultItem {
    //數據種類
    public let item:MeterData
    //值
    public let value:String
    //單位
    public let unit:UnitType
}


public enum UnitType:CaseIterable {
    case temperature_scale_C,kg,mmHg,mg_dl,mmolL,time_min,pulse_unit,undefined
    
    /// 單位的顯示名稱。
    public var displayName:String {
        switch self {
        case .temperature_scale_C:
            "°C"
        case .kg:
            "KG"
        case .mmHg:
            "mmHg"
        case .mg_dl:
            "mg/dL"
        case .mmolL:
            "mmol/L"
        case .time_min:
            "次/分"
        case .pulse_unit:
            "下/次"
        case .undefined:
            "不明"
        }
    }
    
    /// 顯示血糖單位選項
    static func bloodSugarDisplayUnit(for input: UnitType) -> String {
        switch input {
        case .mg_dl:
            return UnitType.mmolL.displayName
        case .mmolL:
            return UnitType.mg_dl.displayName
        default:
            return ""
        }
    }
    
    ///伺服器的編碼
    public var code:Int {
        switch self {
        case .temperature_scale_C:
            1
        case .kg:
            1
        case .mmHg:
            1
        case .mg_dl:
            2
        case .mmolL:
            1
        case .time_min:
            1
        case .pulse_unit:
            1
        case .undefined:
            1
        }
    }
    
    /// 给定的displayName找到UnitType
    static func from(displayName: String) -> UnitType? {
        for caseItem in UnitType.allCases {
            if caseItem.displayName == displayName {
                return caseItem
            }
        }
        return nil
    }
}

/// Enum for representing different types of health metrics.
/// 代表不同健康指標類型的枚舉。
public enum MeterData :CaseIterable{
    // Cases for each health metric
    // 每個健康指標的案例
    case systolic, diastolic, pulse, weight, temp, breath, bloodSugar
    
    /// Computed property to return the display name of each health metric in Chinese.
    /// 計算屬性，以中文返回每個健康指標的顯示名稱。
    public var displayName: String {
        switch self {
        case .systolic:
            return "收縮壓" // Systolic Blood Pressure
        case .diastolic:
            return "舒張壓" // Diastolic Blood Pressure
        case .pulse:
            return "脈搏"   // Pulse
        case .weight:
            return "體重"   // Weight
        case .temp:
            return "體溫"   // Temperature
        case .breath:
            return "呼吸"   // Breath
        case .bloodSugar:
            return "血糖"   // Blood Sugar
        }
    }
    
    ///單位
    public var unit:UnitType {
        switch self {
        case .systolic:
            UnitType.mmHg
        case .diastolic:
            UnitType.mmHg
        case .pulse:
            UnitType.pulse_unit
        case .weight:
            UnitType.kg
        case .temp:
            UnitType.time_min
        case .breath:
            UnitType.time_min
        case .bloodSugar:
            UnitType.mg_dl
        }
    }
    
    ///對應app local data 資料庫
    public var typeCode:Int {
        switch self {
        case .systolic:
            3
        case .diastolic:
            4
        case .pulse:
            1
        case .weight:
            6
        case .temp:
            7
        case .breath:
            2
        case .bloodSugar:
            8
        }
    }
    
    /// 根据给定的displayName找到对应的MeterData枚举值
    static func from(displayName: String) -> MeterData? {
        for caseItem in MeterData.allCases {
            if caseItem.displayName == displayName {
                return caseItem
            }
        }
        return nil
    }
}

