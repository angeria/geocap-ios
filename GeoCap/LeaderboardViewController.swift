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
    private lazy var db = Firestore.firestore()
    private let user = Auth.auth().currentUser
    
    var users = [(String, Int)]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchUsers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let userListener = userListener {
            userListener.remove()
        }
        
        users.removeAll()
    }
    
    private func fetchUsers() {
        userListener = db.collection("users").addSnapshotListener { [weak self] querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error fetching users: \(error!)")
                return
            }
            
            guard let self = self else { return }
            snapshot.documentChanges.forEach { diff in
                guard let username = diff.document.data()["username"] as? String else { return }
                guard let locationCount = diff.document.data()["capturedLocationsCount"] as? Int else { return }
                
                if (diff.type == .added) {
                    print("added")
                    self.users += [(username, locationCount)]
                }
                
                if (diff.type == .modified) {
                    print("modified")
                    if let index = self.users.firstIndex(where: { $0.0 == username }) {
                        self.users[index].1 = locationCount
                    }
                }
                
                if (diff.type == .removed) {
                    print("removed")
                    if let index = self.users.firstIndex(where: { $0.0 == username }) {
                        self.users.remove(at: index)
                    }
                }
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
        
        let (username, count) = users[indexPath.row]
        cell.textLabel?.text = "\(indexPath.row + 1). \(username)"
        cell.detailTextLabel?.text = String(count)
        if username == user?.displayName {
            cell.backgroundColor = UIColor.GeoCap.green.withAlphaComponent(0.20)
        }
        
        return cell
    }

}
