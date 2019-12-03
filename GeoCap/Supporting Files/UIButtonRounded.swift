//
//  UIButtonRounded.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-26.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit

@IBDesignable class UIButtonRounded: UIButton {

    override func layoutSubviews() {
        super.layoutSubviews()

        updateCornerRadius()
    }

    @IBInspectable var rounded: Bool = false {
        didSet {
            updateCornerRadius()
        }
    }

    func updateCornerRadius() {
        layer.cornerRadius = rounded ? frame.size.height / 2 : 0
    }
}
