//
//  Extensions.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-01.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit 

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension UIColor {
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.init(red: r/255, green: g/255, blue: b/255, alpha: 1)
    }
}

// TODO: Change to original system fonts when iOS 13 is released
extension UIColor {
    struct Custom {
        static let systemBlue = UIColor(r: 0, g: 122, b: 255)
        static let systemRed = UIColor(r: 255, g: 59, b: 48)
        static let systemGreen = UIColor(r: 52, g: 199, b: 89)
    }
}
