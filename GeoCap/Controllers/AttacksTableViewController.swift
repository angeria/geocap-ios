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
        let attackerUid: String
        let locationName: String
        let locationRef: DocumentReference
        let cityRef: DocumentReference
        let attackRef: DocumentReference
        let minutesLeft: Int
        var bitmoji: UIImage?
    }

    private var tableData = [AttackCellData]()

    private let reuseIdentifierAttackCell = "AttackCell"
    private let reuseIdentifierRelaxCell = "RelaxCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()

        // Refresh to remove attacks that timed out
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.setup()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        timer?.invalidate()
    }

    private var timer: Timer?

    private func setup() {
        defer {
            tableView.reloadData()
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }

        tableData.removeAll()

        let db = Firestore.firestore()
        db.collection("attacks").whereField("defenderUid", isEqualTo: uid).getDocuments { [weak self] (querySnapshot, error) in
            guard let snapshot = querySnapshot else {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }

            snapshot.documents.forEach { docSnap in
                guard let timestamp = docSnap.data()["timestamp"] as? Timestamp else { return }
                guard timestamp.attackIsActive() else { return }
                let minutesLeft = timestamp.minutesLeftOfAttack()

                guard let attackerName = docSnap.data()["attackerName"] as? String else { return }
                guard let attackerUid = docSnap.data()["attackerUid"] as? String else { return }

                guard let locationName = docSnap.data()["locationName"] as? String else { return }
                guard let locationRef = docSnap.data()["locationRef"] as? DocumentReference else { return }
                guard let cityRef = docSnap.data()["cityRef"] as? DocumentReference else { return }

                let attackCellData = AttackCellData(attackerName: attackerName, attackerUid: attackerUid, locationName: locationName, locationRef: locationRef, cityRef: cityRef, attackRef: docSnap.reference, minutesLeft: minutesLeft, bitmoji: nil)
                self?.tableData += [attackCellData]
                self?.tableView.reloadData()

                // Fetch bitmoji async
                self?.fetchAndSetBitmoji(for: attackCellData)
            }
        }
    }

    private func fetchAndSetBitmoji(for attackCellData: AttackCellData) {
        var cellData = attackCellData
        let ref = Storage.storage().reference(withPath: "snapchat_bitmojis/\(attackCellData.attackerUid)/snapchat_bitmoji.png")
        ref.getData(maxSize: GeoCapConstants.maxDownloadSize) { [weak self] data, error in
            if let error = error as NSError? {
                let storageError = StorageErrorCode(rawValue: error.code)!
                if storageError == .objectNotFound { return }
                os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                return
            }

            cellData.bitmoji = UIImage(data: data!)
            if let existingCellIndex = self?.tableData.firstIndex(where: { $0.attackerUid == cellData.attackerUid }) {
                self?.tableData[existingCellIndex] = cellData
            } else {
                self?.tableData += [cellData]
            }
            self?.tableView.reloadData()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        tableData.isEmpty ? 1 : tableData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableData.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: reuseIdentifierRelaxCell)!
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifierAttackCell, for: indexPath) as! AttackTableViewCell

        if let bitmoji = tableData[indexPath.section].bitmoji {
            cell.bitmoji.image = bitmoji
        }

        cell.attackerName.text = tableData[indexPath.section].attackerName

        let locationName = tableData[indexPath.section].locationName
        cell.locationName.text = locationName

        let minutesLeft = tableData[indexPath.section].minutesLeft
        cell.timeLabel.text = "\(minutesLeft) minutes left"

        let locationRef = tableData[indexPath.section].locationRef
        let cityRef = tableData[indexPath.section].cityRef
        let attackRef = tableData[indexPath.section].attackRef
        cell.defendButtonCallback = {
            SwiftEntryKit.dismiss {
                if let navVC = UIApplication.shared.windows[0].rootViewController as? UINavigationController {
                    if let tabBarVC = navVC.visibleViewController as? UITabBarController {
                        if let mapNavVC = tabBarVC.viewControllers?[1] as? UINavigationController {
                            if let mapVC = mapNavVC.visibleViewController as? MapViewController {
                                attackRef.delete { _ in
                                    mapVC.defendLocation(locationName: locationName, locationRef: locationRef, cityRef: cityRef)
                                }
                            }
                        }
                    }
                }
            }
        }

        return cell
    }

}
