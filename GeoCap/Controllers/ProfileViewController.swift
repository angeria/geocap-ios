//
//  ProfileViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-16.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import os.log
import Firebase
import SCSDKBitmojiKit
import SCSDKLoginKit

class ProfileViewController: UIViewController {

    @IBOutlet weak var usernameLabel: UILabel!

    // MARK: Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        usernameLabel.text = Auth.auth().currentUser?.displayName
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addBitmojiIcon()
        view.sendSubviewToBack(bitmoji)
    }

    // MARK: - Captured locations

    @IBOutlet weak var capturedLocationsLabel: UILabel!

    func setLocationCount(to count: Int) {
        let format = NSLocalizedString("profile-captured-locations", comment: "Captured locations count label")
        capturedLocationsLabel.text = String(format: format, count)
    }

    // MARK: - Snapchat & Profile Picture

    private var bitmoji = SCSDKBitmojiIconView()

    @IBOutlet weak var profilePictureButton: UIButton! {
        didSet {
            if SCSDKLoginClient.isUserLoggedIn {
                profilePictureButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            }
        }
    }

    @IBAction func profilePictureButtonPressed(_ sender: UIButton) {
        if SCSDKLoginClient.isUserLoggedIn {
            unlinkSnapchat(completion: nil)
        } else {
            linkSnapchat()
        }
    }

    private func linkSnapchat() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        SCSDKLoginClient.login(from: self) { [weak self] _, error in
            if let error = error as NSError? {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                return
            }

            DispatchQueue.main.async {
                self?.profilePictureButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            }

            SCSDKBitmojiClient.fetchAvatarURL { (avatarURL, error) in
                if let error = error as NSError? {
                    os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                    return
                }

                let url = URL(string: avatarURL!)!
                URLSession.shared.dataTask(with: url) { (bitmojiData, _, error) in
                    if let error = error as NSError? {
                        os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                        return
                    }

                    let ref = Storage.storage().reference(withPath: "snapchat_bitmojis/\(uid)/snapchat_bitmoji.png")
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/png"
                    _ = ref.putData(bitmojiData!, metadata: metadata) { (_, error) in
                        if let error = error as NSError? {
                            os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                            return
                        }

                        // Refresh all locations to add user's bitmoji
                        if let navVC = self?.navigationController?.tabBarController?.viewControllers?[1] as? UINavigationController {
                            if let mapVC = navVC.viewControllers[0] as? MapViewController {
                                mapVC.clearMap()
                                mapVC.fetchLocations()
                            }
                        }
                    }
                }.resume()
            }
        }
    }

    func unlinkSnapchat(completion: (() -> Void)?) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        SCSDKLoginClient.unlinkAllSessions { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    self?.profilePictureButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
                }

                let ref = Storage.storage().reference(withPath: "snapchat_bitmojis/\(uid)/snapchat_bitmoji.png")
                ref.delete { error in
                    if let error = error as NSError? {
                        os_log("%{public}@", log: OSLog.Profile, type: .debug, error as NSError)
                        completion?()
                        return
                    }

                    if completion != nil {
                        completion!()
                        return
                    }

                    // Refresh all locations to remove user's bitmoji
                    if let navVC = self?.navigationController?.tabBarController?.viewControllers?[1] as? UINavigationController {
                        if let mapVC = navVC.viewControllers[0] as? MapViewController {
                            mapVC.clearMap()
                            mapVC.fetchLocations()
                        }
                    }
                }
            } else {
                completion?()
            }
        }
    }

    private func addBitmojiIcon() {
        bitmoji.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bitmoji)
        NSLayoutConstraint.activate([
            bitmoji.bottomAnchor.constraint(equalTo: usernameLabel.topAnchor, constant: -16),
            bitmoji.heightAnchor.constraint(equalToConstant: 100),
            bitmoji.widthAnchor.constraint(equalToConstant: 100),
            bitmoji.centerXAnchor.constraint(equalTo: usernameLabel.centerXAnchor)
        ])
    }

}
