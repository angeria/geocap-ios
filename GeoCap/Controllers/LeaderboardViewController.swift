//
//  LeaderboardViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-09.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase

class LeaderboardViewController: UITableViewController {

    // MARK: - Life Cycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupLeaderboard()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        userListener?.remove()
    }
    
    // MARK: - Leaderboard
    
    struct userCellData {
        var isOpened: Bool
        let username: String
        let locations: [String]
        let locationCount: Int
    }
    
    private var tableViewData = [userCellData]()
    private var userListener: ListenerRegistration?
    
    private func setupLeaderboard() {
        let db = Firestore.firestore()
        userListener = db.collection("users").order(by: "capturedLocationsCount", descending: true).addSnapshotListener { [weak self] querySnapshot, error in
            guard let snapshot = querySnapshot else {
                Crashlytics.sharedInstance().recordError(error!)
                print("Error fetching 'users' query snappshot: \(String(describing: error))")
                return
            }
            guard let self = self else { return }
            
            self.tableViewData.removeAll()
            
            snapshot.documents.forEach() { documentSnapshot in
                let data = documentSnapshot.data()
                guard let username = data["username"] as? String else {print( "Couldn't get 'username'"); return }
                guard var locations = data["capturedLocations"] as? [String] else { print("Couldn't get 'capturedLocations'"); return }
                guard let locationCount = data["capturedLocationsCount"] as? Int else { print("Couldn't get 'capturedLocationsCount'"); return }

                // Sort locations in alphabetical order
                locations.sort(by: { $0 < $1 })
                
                self.tableViewData += [userCellData(isOpened: false, username: username, locations: locations, locationCount: locationCount)]
            }
            self.tableView.reloadData()
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
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
            let username = tableViewData[indexPath.section].username
            let locationCount = tableViewData[indexPath.section].locationCount
            cell.textLabel?.text = "\(indexPath.section + 1). \(username)"
            cell.detailTextLabel?.text = String(locationCount)
            if username == Auth.auth().currentUser?.displayName {
                cell.backgroundColor = UIColor.GeoCap.blue.withAlphaComponent(0.15)
            } else {
                cell.backgroundColor = UIColor.groupTableViewBackground.withAlphaComponent(0.35)
            }
            return cell
        } else {
            let dataIndex = indexPath.row - 1
            let cell = tableView.dequeueReusableCell(withIdentifier: "locationCell", for: indexPath)
            cell.textLabel?.text = tableViewData[indexPath.section].locations[dataIndex]
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
