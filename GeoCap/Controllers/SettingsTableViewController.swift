//
//  SettingsTableViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-12-08.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import os.log
import Firebase
import ThirdPartyMailer

class SettingsTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupLocationLostNotificationsSwitch()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        settingsListener?.remove()
    }

    // MARK: - Sign Out

    @IBAction func signOutPressed(_ sender: UIButton) {
        unregisterNotifications(completion: teardownBeforeSignOut)
    }

    private func teardownBeforeSignOut() {
        // Removing listeners here also to not get "Missing or insufficient permissions" error after signing out
        let navVC = tabBarController!.viewControllers![1] as! UINavigationController
        let mapVC = navVC.viewControllers[0] as! MapViewController
        mapVC.teardown()

        settingsListener?.remove()

        if let profileVC = navigationController?.viewControllers[0] as? ProfileViewController {
            profileVC.unlinkSnapchat(completion: signOut)
        }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let error as NSError {
            os_log("%{public}@", log: OSLog.Profile, type: .debug, error)
            Crashlytics.sharedInstance().recordError(error)
        }
    }

    // MARK: - Notifications

    @IBOutlet weak var locationLostNotificationsSwitch: UISwitch!

    // Using a listener to use offline caching which gives a more responsive feeling compared to normal requests
    // I'm uncertain if this causes undue performance and/or network impact; keeping it for now
    private var settingsListener: ListenerRegistration?
    private func setupLocationLostNotificationsSwitch() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("private").document("data")
        settingsListener = ref.addSnapshotListener { [weak self] documentSnapshot, error in
                guard let document = documentSnapshot else {
                    os_log("%{public}@", log: OSLog.Profile, type: .debug, error! as NSError)
                    Crashlytics.sharedInstance().recordError(error!)
                    return
                }

                DispatchQueue.main.async {
                    self?.locationLostNotificationsSwitch.isOn = document.get("locationLostNotificationsEnabled") as? Bool == true ? true : false
                }
        }
    }

    private func unregisterNotifications(completion: (() -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("private").document("data")
        ref.updateData(["notificationToken": FieldValue.delete()]) { error in
            if let error = error {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                Crashlytics.sharedInstance().recordError(error)
            }
            completion?()
        }
    }

    @IBAction func notificationsSwitchPressed(_ sender: UISwitch) {
        switch sender.isOn {
        case true:
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self?.setLocationLostNotificationsSetting(to: true)
                case .denied:
                    DispatchQueue.main.async {
                        self?.locationLostNotificationsSwitch.isOn = false
                        self?.presentNotificationAuthDisabledAlert()
                    }
                case .notDetermined:
                    self?.presentNotificationAuthRequest()
                @unknown default:
                    fatalError("Unexpected notification authorization status")
                }
            }
        case false:
            setLocationLostNotificationsSetting(to: false)
        }
    }

    private func setLocationLostNotificationsSetting(to isEnabled: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("private").document("data")
        ref.updateData(["locationLostNotificationsEnabled": isEnabled]) { error in
            if let error = error {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                Crashlytics.sharedInstance().recordError(error)
            }
        }
    }

    private func presentNotificationAuthRequest() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let authOptions: UNAuthorizationOptions = [.alert, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { [weak self] (granted, error) in
            if let error = error {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                Crashlytics.sharedInstance().recordError(error)
                DispatchQueue.main.async {
                    self?.locationLostNotificationsSwitch.isOn = false
                }
                return
            } else if granted {
                self?.setLocationLostNotificationsSetting(to: true)

                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }

                let db = Firestore.firestore()
                let ref = db.collection("users").document(uid).collection("private").document("data")
                ref.updateData(["locationLostNotificationsEnabled": true]) { error in
                    if let error = error {
                        os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.locationLostNotificationsSwitch.isOn = false
                }
            }
            UserDefaults.standard.set(true, forKey: GeoCapConstants.UserDefaultsKeys.notificationAuthRequestShown)
        }
    }

    private func presentNotificationAuthDisabledAlert() {
        let title = NSLocalizedString("alert-title-notification-auth-off", comment: "Alert title when notification auth is off")
        let message = NSLocalizedString("alert-message-notification-auth-off", comment: "Alert message when notification auth is off")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        let settingsActionTitle = NSLocalizedString("alert-action-title-settings", comment: "Title of alert action for going to 'Settings'")
        let settingsAction = UIAlertAction(title: settingsActionTitle, style: .default, handler: { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        })
        alert.addAction(settingsAction)
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    // MARK: - Sound Setting

    @IBOutlet weak var soundSettingSwitch: UISwitch! {
        didSet {
            soundSettingSwitch.isOn = UserDefaults.standard.bool(forKey: GeoCapConstants.UserDefaultsKeys.soundsAreEnabled)
        }
    }

    @IBAction func soundSettingSwitchPressed(_ sender: UISwitch) {
        switch sender.isOn {
        case true:
            UserDefaults.standard.set(true, forKey: GeoCapConstants.UserDefaultsKeys.soundsAreEnabled)
        case false:
            UserDefaults.standard.set(false, forKey: GeoCapConstants.UserDefaultsKeys.soundsAreEnabled)
        }
    }

    // MARK: - Delete Account

    private func deleteAccount() {
        let functions = Functions.functions(region: "europe-west1")
        functions.httpsCallable("deleteAccount").call { [weak self] (result, error) in
            if let error = error as NSError? {
              os_log("%{public}@", log: OSLog.Profile, type: .debug, error)
              Crashlytics.sharedInstance().recordError(error)
            }

            if let success = (result?.data as? [String: Any])?["result"] as? Bool {
                if success {
                    self?.teardownBeforeSignOut()
                }
            }
        }
    }

    @IBAction func deleteAccountButtonPressed(_ sender: UIButton) {
        presentConfirmAccountDeletionAlert()
    }

    private func presentConfirmAccountDeletionAlert() {
        let title = NSLocalizedString("alert-title-confirm-account-deletion", comment: "Alert title when asking the user to confirm account deletion")
        let message = NSLocalizedString("alert-message-confirm-account-deletion", comment: "Alert message when asking the user to confirm account deletion")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let yesActionTitle = NSLocalizedString("alert-action-title-yes", comment: "Title of alert action 'Yes'")
        let yesAction = UIAlertAction(title: yesActionTitle, style: .destructive) { [weak self] (_) in
            self?.deleteAccount()
        }

        let noActionTitle = NSLocalizedString("alert-action-title-no", comment: "Title of alert action 'No'")
        let noAction = UIAlertAction(title: noActionTitle, style: .cancel)

        alert.addAction(yesAction)
        alert.addAction(noAction)
        present(alert, animated: true)
    }

    // MARK: - Contact

    @IBAction func openEmailButtonPressed(_ sender: UIButton) {
        let actionTitle = NSLocalizedString("auth-choose-email-app-action-sheet-title",
                                            comment: "Title of choose email app action sheet alert")
        let actionSheet = UIAlertController(title: actionTitle, message: nil, preferredStyle: .actionSheet)

        // Native mail app
        let mailURL = URL(string: "mailto:hello@geocap.app")!
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
                    _ = ThirdPartyMailer.application(UIApplication.shared,
                                                     openMailClient: client,
                                                     recipient: "hello@geocap.app",
                                                     subject: nil,
                                                     body: nil
                    )
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

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let usernameVC = segue.destination as? ChooseUsernameViewController {
            usernameVC.isUsernameChange = true
        }
    }

}
