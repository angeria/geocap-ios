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
        let actionTitle = NSLocalizedString("auth-choose-email-app-action-sheet-title", comment: "Title of choose email app action sheet alert")
        let actionSheet = UIAlertController(title: actionTitle, message: nil, preferredStyle: .actionSheet)
        
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
        
        present(actionSheet, animated: true) { [weak self] in
            // Dismiss email app chooser when tapping outside of it
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self?.dismissEmailAppChooser))
            actionSheet.view.superview?.subviews[0].isUserInteractionEnabled = true
            actionSheet.view.superview?.subviews[0].addGestureRecognizer(tapGesture)
        }
    }
    
    @objc func dismissEmailAppChooser() {
        dismiss(animated: true, completion: nil)
    }

}
