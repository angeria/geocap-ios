//
//  PendingSignInViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-08.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit

class PendingSignInViewController: UIViewController {

    @IBOutlet weak var textLabel: UILabel! {
        didSet {
            guard let email = UserDefaults.standard.string(forKey: "Email") else { return }
            let format = NSLocalizedString("auth-pending-sign-in-message", comment: "Message telling user to check email")
            textLabel.text = String(format: format, email)
        }
    }

    @IBOutlet weak var openEmailButton: UIButton! {
        didSet {
            openEmailButton.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }
    
    @IBAction func openEmailButtonPressed(_ sender: UIButton) {
        let mailURL = URL(string: "message://")!
        if UIApplication.shared.canOpenURL(mailURL) {
            UIApplication.shared.open(mailURL, options: [:], completionHandler: nil)
         }
    }

}
