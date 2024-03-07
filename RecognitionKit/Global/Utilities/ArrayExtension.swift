//
//  ArrayExtension.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/2/19.
//

import Foundation

extension Array where Element == CGFloat {
    func average() -> CGFloat {
        return self.reduce(0, +) / CGFloat(self.count)
    }
}
