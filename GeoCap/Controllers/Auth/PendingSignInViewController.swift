//
//  PendingSignInViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-08.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import ThirdPartyMailer

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
        let actionSheet = UIAlertController(title: "Choose email app", message: nil, preferredStyle: .actionSheet)
        
        // Native mail app
        let mailURL = URL(string: "message://")!
        if UIApplication.shared.canOpenURL(mailURL) {
            let openNativeMailAppAction = UIAlertAction(title: "Mail", style: .default) { _ in
                UIApplication.shared.open(mailURL, options: [:], completionHandler: nil)
            }
            actionSheet.addAction(openNativeMailAppAction)
        }
        
        // Third party mail apps
        let emailClients = ThirdPartyMailClient.clients()
        for client in emailClients {
            if ThirdPartyMailer.application(UIApplication.shared, isMailClientAvailable: client) {
                let openOtherMailAppAction = UIAlertAction(title: client.name, style: .default) { _ in
                    let _ = ThirdPartyMailer.application(UIApplication.shared, openMailClient: client)
                }
                actionSheet.addAction(openOtherMailAppAction)
            }
        }
        
        present(actionSheet, animated: true)
    }

}
