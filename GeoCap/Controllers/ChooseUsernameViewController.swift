//
//  ChooseUsernameViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-09.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit

class ChooseUsernameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Close keyboard when tapping outside of it
        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:))))
    }
    
    @IBOutlet weak var usernameTextField: UITextField! {
        didSet {
            usernameTextField.delegate = self
        }
    }
    
    @IBOutlet weak var infoLabel: UILabel!
    
    private func usernameTextFieldDidEndEditing() -> Bool {
        usernameTextField.text = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let username = usernameTextField.text else { return false }
        guard username.count > 1 && username.count < 23 else {
            infoLabel.isHidden = false
            infoLabel.text = "Username must be between 2 to 24 characters"
            return false
        }
        
        infoLabel.isHidden = true
        
        UserDefaults.standard.set(username, forKey: "Username")
        
        usernameTextField.resignFirstResponder()
        performSegue(withIdentifier: "Show Pending Sign In", sender: nil)
        return true
    }
    
}

extension ChooseUsernameViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return usernameTextFieldDidEndEditing()
    }
    
}
