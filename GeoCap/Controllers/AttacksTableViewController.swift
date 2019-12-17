//
//  AttacksTableViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-12-17.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import SwiftEntryKit
import os.log

class AttacksTableViewController: UITableViewController {

    private struct AttackCellData {
        let attackerName: String
        let locationName: String
        let minutesLeft: Int
    }
    private var tableData = [AttackCellData]()
    private let reuseIdentifierAttackCell = "AttackCell"
    private let reuseIdentifierRelaxCell = "RelaxCell"

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

            snapshot.documents.forEach { docSnap in
                guard let attackerName = docSnap.data()["attacker"] as? String else { return }
                guard let locationName = docSnap.data()["location"] as? String else { return }
                guard let timestamp = docSnap.data()["timestamp"] as? Timestamp else { return }

                let comparison = Calendar.current.dateComponents([.minute], from: timestamp.dateValue(), to: Date())
                guard let minutesSinceCapture = comparison.minute else { return }
                let minutesLeft = 60 - minutesSinceCapture // TODO: Extract time cap to remote config constant
                guard minutesLeft > 0 else { return }

                let attackCellData = AttackCellData(attackerName: attackerName, locationName: locationName, minutesLeft: minutesLeft)
                self?.tableData += [attackCellData]
                self?.tableView.reloadData()
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if tableData.count > 1 {
            return tableData.count
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableData.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: reuseIdentifierRelaxCell)!
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifierAttackCell, for: indexPath) as! AttackTableViewCell

        cell.attackerName.text = tableData[indexPath.section].attackerName

        let locationName = tableData[indexPath.section].locationName
        cell.locationName.text = locationName

        let minutesLeft = tableData[indexPath.section].minutesLeft
        cell.timeLabel.text = "\(minutesLeft) minutes left"

        cell.defendButtonCallback = {
            SwiftEntryKit.dismiss {
                if let navVC = UIApplication.shared.windows[0].rootViewController as? UINavigationController {
                    if let tabBarVC = navVC.visibleViewController as? UITabBarController {
                        if let mapNavVC = tabBarVC.viewControllers?[1] as? UINavigationController {
                            if let mapVC = mapNavVC.visibleViewController as? MapViewController {
                                mapVC.defendLocation(locationRef: nil)
                            }
                        }
                    }
                }
            }
        }

        return cell
    }

}
