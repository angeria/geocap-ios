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
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if isUsernameChange {
            titleLabel.text = "Choose a new name"
            subtitleLabel.text = "Choose carefully, you won't be able to change it again before seven days"
            continueButton.setTitle("Confirm", for: .normal)
            usernameTextField.returnKeyType = .done
        }
        
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
    
    @IBOutlet weak var continueButton: UIButton! {
        didSet {
            continueButton.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }
    
    @IBAction func continueButtonPressed(_ sender: Any) {
        if usernameWasChanged {
            navigationController?.popViewController(animated: true)
        }
        
        usernameTextFieldDidEndEditing()
    }
    
    @IBOutlet weak var infoLabel: UILabel!
    
    private func usernameTextFieldDidEndEditing() {
        continueButton.isEnabled = false
        
        usernameTextField.text = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let username = usernameTextField.text,
                username != "",
                username.count >= GeoCapConstants.minimumUsernameLength,
                username.count <= GeoCapConstants.maximumUsernameLength
        else {
            infoLabel.isHidden = false
            let format = NSLocalizedString("auth-choose-username-invalid-length", comment: "Error message for choose username text field when inputed username is invalid length")
            infoLabel.text = String(format: format, GeoCapConstants.minimumUsernameLength, GeoCapConstants.maximumUsernameLength)
            usernameTextField.shake()
            continueButton.isEnabled = true
            return
        }
        
        spinner.isHidden = false
        spinner.startAnimating()

        chooseUsername(username)
    }
    
    private func chooseUsername(_ username: String) {
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username).getDocuments { [weak self] querySnapshot, error in
            if let error = error as NSError? {
                self?.infoLabel.isHidden = false
                self?.infoLabel.text = NSLocalizedString("auth-choose-username-error", comment: "Error message for choose username text field")
                os_log("%{public}@", log: OSLog.Auth, type: .debug, error)
                Crashlytics.sharedInstance().recordError(error)
                self?.continueButton.isEnabled = true
                self?.spinner.stopAnimating()
                return
            }
            
            if querySnapshot?.count != 0 {
                self?.infoLabel.isHidden = false
                self?.infoLabel.text = NSLocalizedString("auth-choose-username-already-taken", comment: "Error message when username is already taken")
                self?.usernameTextField.shake()
                self?.continueButton.isEnabled = true
                self?.spinner.stopAnimating()
                return
            }
            
            self?.infoLabel.isHidden = true
            self?.usernameTextField.resignFirstResponder()
            UserDefaults.standard.set(username, forKey: "Username")
            
            if self?.isUsernameChange == true {
                self?.changeUsername(to: username)
                return
            }
            
            let authVC = self?.navigationController?.viewControllers[0] as! AuthViewController
            authVC.sendSignInLink() { [weak self] errorMessage in
                self?.spinner.stopAnimating()
                self?.continueButton.isEnabled = true
                if let errorMessage = errorMessage {
                    self?.infoLabel.text = errorMessage
                    self?.infoLabel.isHidden = false
                    return
                }
                self?.performSegue(withIdentifier: "Show Pending Sign In", sender: nil)
            }
        }
    }
    
    var isUsernameChange = false
    private var usernameWasChanged = false
    lazy private var functions = Functions.functions(region:"europe-west1")
    @IBOutlet weak var subtitleToTitleTopConstraint: NSLayoutConstraint!
    
    private func changeUsername(to newUsername: String) {
        functions.httpsCallable("modifyUsername").call(["newName": newUsername]) { [weak self] (result, error) in
            if let error = error as NSError? {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error)
                Crashlytics.sharedInstance().recordError(error)
                return
            }
            
            if let usernameChangedSuccessfully = (result?.data as? [String: Any])?["result"] as? Bool {
                if usernameChangedSuccessfully {
                    Auth.auth().currentUser?.reload(completion: { [weak self] (error) in
                        if let error = error as NSError? {
                            os_log("%{public}@", log: OSLog.Profile, type: .debug, error)
                            Crashlytics.sharedInstance().recordError(error)
                            return
                        }

                        // Refresh all locations to update pins to new username
                        if let navVC = self?.navigationController?.tabBarController?.viewControllers?[1] as? UINavigationController {
                            if let mapVC = navVC.viewControllers[0] as? MapViewController {
                                mapVC.clearMap()
                                mapVC.fetchLocations()
                            }
                        }
                        
                        let newConstraint = self?.titleLabel.bottomAnchor.constraint(equalTo: self!.usernameTextField!.topAnchor, constant: -20.0)
                        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
                            self?.usernameWasChanged = true
                            self?.usernameTextField.isEnabled = false
                            self?.continueButton.setTitle("Done", for: .normal)
                            self?.titleLabel.text = "Successfully changed name 😎"
                            self?.subtitleLabel.alpha = 0
                            
                            self?.subtitleToTitleTopConstraint.isActive = false
                            newConstraint?.isActive = true
                            self?.view.layoutIfNeeded()
                        })
                        
                        self?.spinner.stopAnimating()
                        self?.continueButton.isEnabled = true
                    })
                } else {
                    self?.infoLabel.text = "Not enough time since last change"
                    self?.infoLabel.isHidden = false
                }
            }
        }
    }
    
}

extension ChooseUsernameViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        usernameTextFieldDidEndEditing()
        return true
    }
    
}
