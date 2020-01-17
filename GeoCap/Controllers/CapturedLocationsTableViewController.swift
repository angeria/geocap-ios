//
//  CapturedLocationsTableViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2020-01-16.
//  Copyright © 2020 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import os.log

class CapturedLocationsTableViewController: UITableViewController {

    // MARK: Life Cycle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        setup()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)

        listener?.remove()
    }

    // MARK: Data Structures

    private var tableViewData = [City]() {
        didSet {
            tableViewData.sort(by: { $0.name < $1.name })
        }
    }

    private struct City {
        let name: String
        var locations = [LocationCellData]()
    }

    private struct LocationCellData {
        var isOpened: Bool
        let name: String
        let ref: DocumentReference

        init?(data: [String: Any]) {
            guard let name = data["name"] as? String,
                let ref = data["ref"] as? DocumentReference
                else { return nil }

            self.isOpened = false
            self.name = name
            self.ref = ref
        }
    }

    // MARK: - Table View

    private var listener: ListenerRegistration?

    private func setup() {
        listener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.document("users/\(uid)").addSnapshotListener { [weak self] (documentSnapshot, error) in
            guard let userDoc = documentSnapshot else {
                os_log("%{public}@", log: OSLog.Profile, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }

            if let locationCount = userDoc.get("capturedLocationsCount") as? Int {
                self?.updateLocationCount(to: locationCount)
            }

            guard let capturedLocations = userDoc.get("capturedLocationsPerCity") as? [String: [String: [String: [String: AnyObject]]]] else { return }
            self?.setupData(capturedLocations)
        }
    }

    private func updateLocationCount(to count: Int) {
        if let profileVC = parent as? ProfileViewController {
            profileVC.setLocationCount(to: count)
        }
    }

    private func setupData(_ capturedLocations: [String: [String: [String: [String: AnyObject]]]]) {
        tableViewData.removeAll()

        for country in capturedLocations.values {
            for (cityName, county) in country {
                for city in county.values {
                    if let locations = city["locations"] as? [String: AnyObject] {
                        var cityLocations = [LocationCellData]()
                        for location in locations.values {
                            if let location = location as? [String: Any] {
                                if let locationCell = LocationCellData(data: location) {
                                    cityLocations += [locationCell]
                                }
                            }
                        }
                        cityLocations.sort(by: { $0.name < $1.name })
                        tableViewData += [City(name: cityName.capitalized, locations: cityLocations)]
                    }
                }
            }
        }
        tableView.reloadData()
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        tableViewData[section].name
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        40
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let ref = tableViewData[indexPath.section].locations[indexPath.row].ref
        tabBarController?.selectedIndex = 1
        mapVC.focusRegionOnLocation(withRef: ref)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        tableViewData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableViewData[section].locations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "locationCell", for: indexPath)

        let locationCellData = tableViewData[indexPath.section].locations[indexPath.row]
        cell.textLabel?.text = locationCellData.name

        return cell
    }
}

extension CapturedLocationsTableViewController {

    var mapVC: MapViewController {
        let navVC = tabBarController!.viewControllers![1] as! UINavigationController
        return navVC.viewControllers[0] as! MapViewController
    }

}
