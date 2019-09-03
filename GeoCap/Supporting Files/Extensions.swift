//
//  Extensions.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-01.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {
    struct GeoCap {
        static let green = UIColor(rgb: 0x8CDA98)
        static let blue = UIColor(rgb: 0x71B8EE)
        static let red = UIColor(rgb: 0xF08A82)
        static let gray = UIColor(rgb: 0xB7B6B6)
    }
    
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}

extension UIView {
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        animation.duration = 0.4
        animation.values = [-7.5, 7.5, -5.0, 5.0, -2.5, 2.5, 0.0]
        self.layer.add(animation, forKey: "shake")
    }

    func scale() {
        UIView.animate(withDuration: 0.125, delay: 0, options: [], animations: {
            self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { (completed) in
            UIView.animate(withDuration: 0.125, delay: 0, options: [.curveEaseOut], animations: {
                self.transform = CGAffineTransform.identity
            })
        }
    }
}

