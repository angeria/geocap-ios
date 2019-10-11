//
//  ChooseUsernameViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-09.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import os.log

class ChooseUsernameViewController: UIViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ChooseUsernameViewController.keyboardDidChange), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        usernameTextField.becomeFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    // MARK: - Keyboard
    
    private var bottomToButtonConstraintConstantInStoryboard: CGFloat!
    @IBOutlet weak var bottomToButtonConstraint: NSLayoutConstraint! {
        didSet {
            bottomToButtonConstraintConstantInStoryboard = bottomToButtonConstraint.constant
        }
    }
    @IBOutlet weak var buttonToUsernameTextFieldConstraint: NSLayoutConstraint!
    
    @objc func keyboardDidChange(notification: Notification) {
        let userInfo = notification.userInfo! as [AnyHashable: Any]
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber
        let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as! NSNumber

        bottomToButtonConstraint.constant = endFrame.height - view.safeAreaInsets.bottom + buttonToUsernameTextFieldConstraint.constant

        UIView.setAnimationCurve(UIView.AnimationCurve(rawValue: animationCurve.intValue)!)
        UIView.animate(withDuration: animationDuration.doubleValue) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Other
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var usernameTextField: UITextField! {
        didSet {
            usernameTextField.delegate = self
        }
    }
    
    @IBOutlet weak var letsGoButton: UIButton! {
        didSet {
            letsGoButton.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }
    
    @IBAction func letsGoButtonPressed(_ sender: Any) {
        usernameTextFieldDidEndEditing()
    }
    
    @IBOutlet weak var infoLabel: UILabel!
    
    private func usernameTextFieldDidEndEditing() {
        letsGoButton.isEnabled = false
        
        usernameTextField.text = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let username = usernameTextField.text else { return }
        guard username.count >= 2 && username.count <= 20 else {
            infoLabel.isHidden = false
            infoLabel.text = "Username must be between 2 to 20 characters"
            infoLabel.shake()
            letsGoButton.isEnabled = true
            return
        }
        
        spinner.isHidden = false
        spinner.startAnimating()
        
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username).getDocuments { [weak self] querySnapshot, error in
            if let error = error as NSError? {
                self?.infoLabel.isHidden = false
                self?.infoLabel.text = "Something went wrong, please try another username"
                os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                Crashlytics.sharedInstance().recordError(error)
                self?.letsGoButton.isEnabled = true
                self?.spinner.stopAnimating()
                return
            }
            
            if querySnapshot?.count != 0 {
                self?.infoLabel.isHidden = false
                self?.infoLabel.text = "Username is already taken"
                self?.usernameTextField.shake()
                self?.letsGoButton.isEnabled = true
                self?.spinner.stopAnimating()
                return
            }
            
            self?.infoLabel.isHidden = true
            self?.spinner.stopAnimating()
            self?.usernameTextField.resignFirstResponder()
            UserDefaults.standard.set(username, forKey: "Username")
            let authVC = self?.presentingViewController as! AuthViewController
            authVC.sendSignInLink()
        }
    }
    
}

extension ChooseUsernameViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        usernameTextFieldDidEndEditing()
        return true
    }
    
}
