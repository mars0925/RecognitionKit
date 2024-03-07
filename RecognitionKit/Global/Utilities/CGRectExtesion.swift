//
//  CGRect.swift
//  RecognitionApp
//
//  Created by 張宮豪 on 2024/2/19.
//

import Foundation

extension CGRect {
    var left: CGFloat {
        return self.origin.x
    }
    
    var top: CGFloat {
        return self.origin.y
    }
    
    var right: CGFloat {
        return self.origin.x + self.width
    }
    
    var bottom: CGFloat {
        return self.origin.y + self.height
    }
    
    var centerX: CGFloat {
        return self.origin.x + (self.width / 2)
    }
    
    var centerY: CGFloat {
        return self.origin.y + (self.height / 2)
    }
    
    ///面積
    var area:CGFloat {
        return self.width * self.height
    }

    
    init(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {
        let width = right - left
        let height = bottom - top
        self.init(x: left, y: top, width: width, height: height)
    }
}
