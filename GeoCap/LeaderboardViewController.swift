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

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
