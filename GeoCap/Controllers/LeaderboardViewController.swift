//
//  LeaderboardViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-09.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import os.log

class LeaderboardViewController: UITableViewController {

    struct Constants {
        static let imageHeightPadding: CGFloat = 50
        static let approxBitmojiSize: CGFloat = 150
        static let userCellOpacity: CGFloat = 0.50
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if cityPicker.numberOfRows(inComponent: 0) > 1 {
            cityPicker.selectRow(1, inComponent: 0, animated: false)
        } else {
            cityPicker.selectRow(0, inComponent: 0, animated: false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupLeaderboard()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        leaderboardListener?.remove()
    }

    // MARK: - Leaderboard

    private struct UserCellData {
        var isOpened = false
        let username: String
        let locations: [String]
        let locationCount: Int
        var bitmoji: UIImage?

        init?(data: [String: Any], country: String?, county: String?, city: String?) {
            guard let username = data["username"] as? String else { return nil }
            self.username = username

            var locations: [String]?
            var locationCount: Int?
            // If a specific city is selected in the leaderboard
            if let country = country, let county = county, let city = city {
                if let capturedLocationsPerCity = data["capturedLocationsPerCity"] as? [String: [String: [String: [String: Any]]]] {
                    if let city = capturedLocationsPerCity[country]?[county]?[city] {
                        locations = city["locations"] as? [String]
                        locationCount = city["locationCount"] as? Int
                    }
                }
            } else {
                // If 'global' is selected
                locations = data["capturedLocations"] as? [String]
                locationCount = data["capturedLocationsCount"] as? Int
            }
            guard locations != nil, locationCount != nil else { return nil }

            self.locations = locations!.sorted()
            self.locationCount = locationCount!
        }
    }

    private var tableViewData = [UserCellData]() {
        didSet {
            tableViewData.sort(by: { $0.locationCount > $1.locationCount })
        }
    }

    private var leaderboardListener: ListenerRegistration?

    private struct LeaderboardQuery {
        let query: String
        let type: String
    }

    private func setupLeaderboard() {
        leaderboardListener?.remove()
        guard let allCities = mapVC?.allCities else { return }

        var queryField: String
        var country: String?
        var county: String?
        var cityName: String?
        if allCities.count == 0 || cityPicker.selectedRow(inComponent: 0) == 0 {
            queryField = "capturedLocationsCount" // Global
        } else {
            let city = allCities[cityPicker.selectedRow(inComponent: 0) - 1]
            cityName = city.name.lowercased()
            county = city.reference.parent.parent!.documentID
            country = city.reference.parent.parent!.parent.parent!.documentID
            queryField = "capturedLocationsPerCity.\(country!).\(county!).\(cityName!).locationCount"
        }

        let userLimit = limitControl.selectedSegmentIndex == 0 ? 10 : 50

        let db = Firestore.firestore()
        leaderboardListener = db.collection("users")
            .order(by: queryField, descending: true)
            .limit(to: userLimit)
            .addSnapshotListener { [weak self] querySnapshot, error in

                guard let snapshot = querySnapshot else {
                    os_log("%{public}@", log: OSLog.Leaderboard, type: .debug, error! as NSError)
                    Crashlytics.sharedInstance().recordError(error!)
                    return
                }
                guard let self = self else { return }

                self.tableViewData.removeAll()

                snapshot.documents.forEach { documentSnapshot in
                    guard let userCellData = UserCellData(data: documentSnapshot.data(), country: country, county: county, city: cityName) else {
                        os_log("Couldn't initialize 'userCellData' from user with id '%{public}@'",
                               log: OSLog.Leaderboard,
                               type: .debug, documentSnapshot.documentID)
                        return
                    }

                    self.tableViewData += [userCellData]
                    self.tableView.reloadData()

                    // Fetch bitmoji async
                    self.fetchAndSetBitmoji(for: userCellData)
                }
                self.tableView.reloadData()
        }
    }

    private func fetchAndSetBitmoji(for userCellData: UserCellData) {
        var cellData = userCellData

        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: cellData.username).getDocuments { [weak self] (snapshot, error) in
            if let error = error as NSError? {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                return
            }

            if let user = snapshot?.documents.first {
                let ref = Storage.storage().reference(withPath: "snapchat_bitmojis/\(user.documentID)/snapchat_bitmoji.png")
                ref.getData(maxSize: GeoCapConstants.maxDownloadSize) { data, error in
                    if let error = error as NSError? {
                        let storageError = StorageErrorCode(rawValue: error.code)!
                        if storageError == .objectNotFound { return }
                        os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                        return
                    }

                    cellData.bitmoji = UIImage(data: data!)
                    if let existingCellIndex = self?.tableViewData.firstIndex(where: { $0.username == cellData.username }) {
                        self?.tableViewData[existingCellIndex] = cellData
                    } else {
                        self?.tableViewData += [cellData]
                    }
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
        return 60
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
            let username = tableViewData[indexPath.section].username
            let locationCount = tableViewData[indexPath.section].locationCount
            cell.textLabel?.text = "\(indexPath.section + 1). \(username)"
            cell.detailTextLabel?.text = String(locationCount)
            if let bitmoji = tableViewData[indexPath.section].bitmoji {
                cell.imageView?.image = bitmoji.addImagePadding(x: 0, y: Constants.imageHeightPadding)
            } else {
                cell.imageView?.image = UIImage(systemName: "person.crop.circle")?
                    .withTintColor(.systemGray)
                    .resized(to: CGSize(width: Constants.approxBitmojiSize,
                                        height: Constants.approxBitmojiSize))
                    .addImagePadding(x: 0, y: Constants.imageHeightPadding)
            }

            if username == Auth.auth().currentUser?.displayName {
                cell.backgroundColor = UIColor.systemBlue.withAlphaComponent(Constants.userCellOpacity)
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

    // MARK: - Leaderboard Limit

    @IBOutlet weak var limitControl: UISegmentedControl!

    @IBAction func limitControlWasPressed(_ sender: UISegmentedControl) {
        feedbackGenerator.selectionChanged()
        setupLeaderboard()
    }

    // MARK: - City Picker

    @IBOutlet weak var cityPicker: UIPickerView! {
        didSet {
            cityPicker.dataSource = self
            cityPicker.delegate = self
        }
    }

}

extension LeaderboardViewController: UIPickerViewDataSource, UIPickerViewDelegate {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        35

    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if let count = mapVC?.allCities.count {
            return count + 1
        } else {
            return 1
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch row {
        case 0:
            return NSLocalizedString("leaderboard-global", comment: "Global location filter in leaderboard")
        default:
            return mapVC?.allCities[row - 1].name
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        setupLeaderboard()
    }

}

extension LeaderboardViewController {

    var mapVC: MapViewController? {
        if let navVC = tabBarController?.viewControllers?[1] as? UINavigationController {
            if let mapVC = navVC.viewControllers[0] as? MapViewController {
                return mapVC
            }
        }
        return nil
    }

}
