//
//  Extensions.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-01.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit

// TODO: Change to original system fonts when iOS 13 is released
extension UIColor {
    
    struct GeoCap {
        static let green = UIColor(rgb: 0x8cda98)
        static let blue = UIColor(rgb: 0x65b7f6)
        static let red = UIColor(rgb: 0xfc7066)
        static let pink = UIColor(rgb: 0xfdfd96)
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

extension UIViewController {
    var contents: UIViewController {
        if let navVC = self as? UINavigationController {
            return navVC.visibleViewController ?? navVC
        } else if let tabVC = self as? UITabBarController {
            return tabVC.viewControllers?.first ?? tabVC
        } else {
            return self
        }
    }
}
