//
//  LeaderboardViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-09.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import os.log

class LeaderboardViewController: UITableViewController {
    
    // MARK: - Life Cycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
            
        setupLeaderboard()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        leaderboardListener?.remove()
    }
    
    // MARK: - Leaderboard
    
    struct userCellData {
        var isOpened = false
        let username: String
        let locations: [String]
        let locationCount: Int
        var bitmoji: UIImage?
        
        init?(data: [String: Any]) {
            guard
                let username = data["username"] as? String,
                let locations = data["capturedLocations"] as? [String],
                let locationCount = data["capturedLocationsCount"] as? Int
            else {
                return nil
            }
            
            self.username = username
            self.locations = locations.sorted()
            self.locationCount = locationCount
        }
    }
    
    private var tableViewData = [userCellData]() {
        didSet {
            tableViewData.sort(by: { $0.locationCount > $1.locationCount })
        }
    }
    
    private var leaderboardListener: ListenerRegistration?
    
    private func setupLeaderboard() {
        leaderboardListener?.remove()
        
        let db = Firestore.firestore()
        leaderboardListener = db.collection("users").order(by: "capturedLocationsCount", descending: true).addSnapshotListener { [weak self] querySnapshot, error in
            guard let snapshot = querySnapshot else {
                os_log("%{public}@", log: OSLog.Leaderboard, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }
            guard let self = self else { return }
            
            self.tableViewData.removeAll()
            
            snapshot.documents.forEach() { documentSnapshot in
                guard let userCellData = userCellData(data: documentSnapshot.data()) else {
                    os_log("Couldn't initialize 'userCellData' from user with id '%{public}@'", log: OSLog.Leaderboard, type: .debug, documentSnapshot.documentID)
                    return
                }
                
                self.fetchAndSetBitmoji(for: userCellData)
            }
        }
    }
    
    private func fetchAndSetBitmoji(for userCellData: userCellData) {
        var cellData = userCellData
        
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: cellData.username).getDocuments { [weak self] (snapshot, error) in
            if let error = error as NSError? {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                return
            }
            
            if let user = snapshot?.documents.first {
                let ref = Storage.storage().reference(withPath: "snapchat_bitmojis/\(user.documentID)/snapchat_bitmoji.png")
                ref.getData(maxSize: 1 * 1024 * 1024) { data, error in
                    if let error = error as NSError? {
                        self?.tableViewData += [cellData]
                        self?.tableView.reloadData()
                        
                        let storageError = StorageErrorCode(rawValue: error.code)!
                        if storageError == .objectNotFound { return }
                        os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                        return
                    }

                    cellData.bitmoji = UIImage(data: data!)
                    self?.tableViewData += [cellData]
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewData.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableViewData[section].isOpened {
            return tableViewData[section].locations.count + 1
        } else {
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
            let username = tableViewData[indexPath.section].username
            let locationCount = tableViewData[indexPath.section].locationCount
            cell.textLabel?.text = "\(indexPath.section + 1). \(username)"
            cell.detailTextLabel?.text = String(locationCount)
            if let bitmoji = tableViewData[indexPath.section].bitmoji {
                cell.imageView?.image = bitmoji.addImagePadding(x: 0, y: 50)
                print(bitmoji.size)
            } else {
                let icon = UIImage(systemName: "person.crop.circle")?.resized(to: CGSize(width: 144, height: 144)).addImagePadding(x: 0, y: 50)
                cell.imageView?.image = icon
            }
            
            if username == Auth.auth().currentUser?.displayName {
                cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.50)
            } else {
                cell.backgroundColor = .secondarySystemBackground
            }
            return cell
        } else {
            let dataIndex = indexPath.row - 1
            let cell = tableView.dequeueReusableCell(withIdentifier: "locationCell", for: indexPath)
            cell.textLabel?.text = tableViewData[indexPath.section].locations[dataIndex]
            return cell
        }
    }
    
    let feedbackGenerator = UISelectionFeedbackGenerator()
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        feedbackGenerator.selectionChanged()
        
        guard tableViewData[indexPath.section].locationCount > 0 else { return }
        
        var sectionsToReload = IndexSet()
        if let openSectionIndex = tableViewData.firstIndex(where: { $0.isOpened }), openSectionIndex != indexPath.section {
            tableViewData[openSectionIndex].isOpened = false
            sectionsToReload.insert(openSectionIndex)
        }
        
        tableViewData[indexPath.section].isOpened = !tableViewData[indexPath.section].isOpened
        sectionsToReload.insert(indexPath.section)
        tableView.reloadSections(sectionsToReload, with: .automatic)
    }

}

extension UIImage {

    func addImagePadding(x: CGFloat, y: CGFloat) -> UIImage? {
        let width: CGFloat = size.width + x
        let height: CGFloat = size.height + y
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
        let origin: CGPoint = CGPoint(x: (width - size.width) / 2, y: (height - size.height) / 2)
        draw(at: origin)
        let imageWithPadding = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return imageWithPadding
    }
    
    func resized(to size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
}
