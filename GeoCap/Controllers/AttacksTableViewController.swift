//
//  AttacksTableViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-12-17.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import os.log

class AttacksTableViewController: UITableViewController {

    private struct AttackCellData {
        let attackerName: String
        let locationName: String
        let minutesLeft: Int
    }
    private var tableData = [AttackCellData]()
    private let reuseIdentifier = "AttackCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    private func setup() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let defenderRef = db.document("users/\(uid)")
        db.collection("attacks").whereField("defender", isEqualTo: defenderRef).getDocuments { [weak self] (querySnapshot, error) in
            guard let snapshot = querySnapshot else {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }
            guard let self = self else { return }

            print(snapshot.documents.count)
            snapshot.documents.forEach { docSnap in
                guard let attackerName = docSnap.data()["attacker"] as? String else { return }
                guard let locationName = docSnap.data()["location"] as? String else { return }
                guard let timestamp = docSnap.data()["timestamp"] as? Timestamp else { return }

                print("here")

                let comparison = Calendar.current.dateComponents([.minute], from: timestamp.dateValue(), to: Date())
                guard let minutesSinceCapture = comparison.minute else { return }
                // TODO: Extract time cap to remote config constant
                let minutesLeft = 10 - minutesSinceCapture
                guard minutesLeft > 0 else { return }

                let attackCellData = AttackCellData(attackerName: attackerName, locationName: locationName, minutesLeft: minutesLeft)
                self.tableData += [attackCellData]
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        tableData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! AttackTableViewCell

        let attackerName = tableData[indexPath.section].attackerName
        let locationName = tableData[indexPath.section].locationName
        let minutesLeft = tableData[indexPath.section].minutesLeft

        cell.attackerName.text = attackerName
        cell.locationName.text = locationName
        cell.timeLabel.text = "\(minutesLeft) minutes left"

        return cell
    }

}
