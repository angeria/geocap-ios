//
//  AuthPickerViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-03.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit

class AuthPickerViewController: UIViewController {
    
    @IBOutlet weak var appIcon: UIImageView!
    
    @IBOutlet weak var signInWithEmailButton: UIButton! {
        didSet {
            signInWithEmailButton.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }
    
    private var animationNotShown = true
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if animationNotShown {
            animate()
        }
    }
    
    private func animate() {
        UIView.animate(withDuration: 0.5, delay: 0.15, options: .curveEaseInOut, animations: {
            self.appIcon.frame = self.appIcon.frame.offsetBy(dx: 0, dy: -self.view.frame.maxY / 6)
        }, completion: { finished in
            self.signInWithEmailButton.isHidden = false
            self.animationNotShown = false
        })
    }
    
}
