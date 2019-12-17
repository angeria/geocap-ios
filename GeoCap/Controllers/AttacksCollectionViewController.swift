//
//  AttacksCollectionViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-12-16.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import os.log

private let reuseIdentifierHeader = "Header"
private let reuseIdentifierCell = "Cell"

fileprivate struct AttackCellData {
    let attacker: String
    let location: String
    let minutesLeft: Int
}

class AttacksCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    private var collectionData = [AttackCellData]()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupListener()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)

        listener?.remove()
    }

    private var listener: ListenerRegistration?

    private func setupListener() {
        listener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let defenderRef = db.document("users/\(uid)")
        listener = db.collection("attacks").whereField("defender", isEqualTo: defenderRef).addSnapshotListener({ [weak self] (querySnapshot, error) in
            guard let snapshot = querySnapshot else {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }
            guard let self = self else { return }
            self.collectionData.removeAll()

            snapshot.documents.forEach { (docSnap) in
                guard let attackerRef = docSnap.data()["attacker"] as? DocumentReference, let locationRef = docSnap.data()["location"] as? DocumentReference else {print("1"); return }

                attackerRef.getDocument { (attackerDoc, error) in
                    guard let attackerName = attackerDoc?.data()?["username"] as? String else {print("2"); return }

                    locationRef.getDocument { (locationDoc, error) in
                        guard let locationName = locationDoc?.data()?["name"] as? String else {print("3"); return }
                        guard let timestamp = docSnap.data()["timestamp"] as? Timestamp else {print("4"); return }

                        let comparison = Calendar.current.dateComponents([.minute], from: timestamp.dateValue(), to: Date())
                        guard let minutesSinceCapture = comparison.minute else { return }
                        // TODO: Extract time cap to remote config constant
                        let minutesLeft = 10 - minutesSinceCapture
                        guard minutesLeft > 0 else { return }

                        let attackCellData = AttackCellData(attacker: attackerName, location: locationName, minutesLeft: minutesLeft)
                        self.collectionData += [attackCellData]
                        self.collectionView.reloadData()
                    }
                }
            }
        })
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        collectionData.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let view = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierCell, for: indexPath) as! AttackCollectionViewCell

        let attacker = collectionData[indexPath.row].attacker
        let location = collectionData[indexPath.row].location
        let minutesLeft = collectionData[indexPath.row].minutesLeft

        view.attacker.text = attacker
        view.location.text = location
        view.timeLabel.text = "\(minutesLeft) minutes left"
        view.timeLabel.text = "\(minutesLeft) minutes left"

        print("\(attacker), \(location), \(minutesLeft)")
        return view
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            return collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: reuseIdentifierHeader, for: indexPath)
        }

        return UICollectionReusableView()
    }

    // MARK: UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 370, height: 150)
    }

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
