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

    private var userListener: ListenerRegistration?
    
    var users = [(String, Int)]()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchUsers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if userListener != nil {
            userListener?.remove()
            userListener = nil
        }
    }
    
    private func fetchUsers() {
        let db = Firestore.firestore()
        userListener = db.collection("users").addSnapshotListener { [weak self] querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error fetching users: \(error!)")
                return
            }
            
            guard let self = self else { return }
            
            self.users.removeAll()
            
            snapshot.documents.forEach() { documentSnapshot in
                guard let username = documentSnapshot.data()["username"] as? String else { return }
                guard let locationCount = documentSnapshot.data()["capturedLocationsCount"] as? Int else { return }
                
                self.users += [(username, locationCount)]
            }
            
            self.users.sort() { $0.1 > $1.1 }
            
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
        
        cell.backgroundColor = .white
        let (username, count) = users[indexPath.row]
        cell.textLabel?.text = "\(indexPath.row + 1). \(username)"
        cell.detailTextLabel?.text = String(count)
        cell.backgroundColor = (username == Auth.auth().currentUser?.displayName) ? UIColor.groupTableViewBackground.withAlphaComponent(0.50) : .white
        
        return cell
    }

}
