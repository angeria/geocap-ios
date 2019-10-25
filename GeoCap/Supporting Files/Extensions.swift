//
//  Extensions.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-01.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        animation.duration = GeoCapConstants.shakeAnimationDuration
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
