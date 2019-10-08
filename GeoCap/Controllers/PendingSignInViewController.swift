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
            textLabel.text = "To confirm your email, tap the button in the email we sent to \(email)"
        }
    }
    
    @IBAction func openEmailButtonPressed(_ sender: UIButton) {
        let mailURL = URL(string: "message://")!
        if UIApplication.shared.canOpenURL(mailURL) {
            UIApplication.shared.open(mailURL, options: [:], completionHandler: nil)
         }
    }

}
