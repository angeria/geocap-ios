//
//  AuthPickerViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-03.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class AuthPickerViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if Auth.auth().currentUser != nil {
            let sb = UIStoryboard.init(name: "Main", bundle: .main)
            let mapVC = sb.instantiateViewController(withIdentifier: "Map")
            mapVC.modalPresentationStyle = .fullScreen
            present(mapVC, animated: true)
        } else if animationNotShown {
            animate()
        }
    }
    
    @IBOutlet weak var signInWithEmailButton: UIButton! {
        didSet {
            signInWithEmailButton.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }
    
    @IBOutlet weak var appIcon: UIImageView!
    
    private var animationNotShown = true
    
    private func animate() {
        UIView.animate(withDuration: 0.5, delay: 0.15, options: .curveEaseInOut, animations: {
            self.appIcon.frame = self.appIcon.frame.offsetBy(dx: 0, dy: -self.view.frame.maxY / 6)
        }, completion: { finished in
            self.signInWithEmailButton.isHidden = false
            self.animationNotShown = false
        })
    }
    
}
