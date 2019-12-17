//
//  MapViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-19.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import os.log
import AVFoundation
import SwiftEntryKit

extension MapViewController {
    enum Constants {
        static let zoomLevel: CLLocationDistance = 4000
        static let calloutImageHeight = 32
        static let calloutImageWidth = 32
        static let overlayAlpha: CGFloat = 0.45
        static let markerAlpha: CGFloat = 0.75
        static let overlayLineWidth: CGFloat = 1
    }
}

class MapViewController: UIViewController {

    // Couldn't figure out a way to get the callout size dynamically so had to hard code values that looked good
    private var captureButtonWidth: Int {
        switch traitCollection.preferredContentSizeCategory {
        case .extraSmall:
            return 75
        case .small:
            return 80
        case .medium:
            return 85
        case .large, .unspecified:
            return 90
        case .extraLarge:
            return 100
        case .extraExtraLarge:
            return 100
        case .extraExtraExtraLarge:
            return 105
        case .accessibilityMedium:
            return 110
        case .accessibilityLarge:
            return 130
        case .accessibilityExtraLarge:
            return 150
        case .accessibilityExtraExtraLarge:
            return 170
        case .accessibilityExtraExtraExtraLarge:
            return 190
        default:
            return 90
        }
    }

    private var captureButtonHeight: Int {
        switch traitCollection.preferredContentSizeCategory {
        case .extraSmall:
            return 43
        case .small:
            return 45
        case .medium:
            return 46
        case .large, .unspecified:
            return 50
        case .extraLarge:
            return 54
        case .extraExtraLarge:
            return 59
        case .extraExtraExtraLarge:
            return 65
        case .accessibilityMedium:
            return 78
        case .accessibilityLarge:
            return 90
        case .accessibilityExtraLarge:
            return 109
        case .accessibilityExtraExtraLarge:
            return 127
        case .accessibilityExtraExtraExtraLarge:
            return 141
        default:
            return 50
        }
    }

    var currentCityIsNotSet = true

    // Keeping map in memory all the time for background state updates (e.g. while quiz view is visible)
    // Set 'mapView.delegate = nil' somewhere to be able to deallocate it
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.showsUserLocation = true
            mapView.mapType = .mutedStandard
            mapView.showsCompass = false
            mapView.isPitchEnabled = false
        }
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(Location.self))

        if let lastCity = UserDefaults.standard.data(forKey: GeoCapConstants.UserDefaultsKeys.lastCity),
            let lastCityDecoded = try? JSONDecoder().decode(City.self, from: lastCity) {
            currentCity = lastCityDecoded
        }

        requestUserLocationAuth()

        setupNotifications()

        let userTrackingBarButton = MKUserTrackingBarButtonItem(mapView: mapView)
        navigationItem.setRightBarButton(userTrackingBarButton, animated: true)
    }

    func teardown() {
        locationListener?.remove()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if let selectedAnnotation = mapView.selectedAnnotations.first {
            mapView.deselectAnnotation(selectedAnnotation, animated: true)
        }
        clearMap()
        fetchLocations()
    }

    // MARK: - Location Filter (segmented control)

    @IBOutlet weak var locationFilter: UISegmentedControl!

    private let feedbackGenerator = UISelectionFeedbackGenerator()

    @IBAction func locationFilterWasPressed(_ sender: UISegmentedControl) {
        feedbackGenerator.selectionChanged()
        clearMap()
        fetchLocations()
    }

    // MARK: - Locations

    @IBOutlet weak var loadingLocationsView: UIVisualEffectView! {
        didSet {
            loadingLocationsView.clipsToBounds = true
            loadingLocationsView.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
        }
    }

    private var allCities = [City]()

    private var currentCity: City? {
        didSet {
            clearMap()
            fetchLocations()

            if !isDefendingLocation {
                let region = MKCoordinateRegion(center: currentCity!.coordinates,
                                                latitudinalMeters: Constants.zoomLevel,
                                                longitudinalMeters: Constants.zoomLevel)
                mapView.setRegion(region, animated: true)
            }

            currentCityBarButton.title = currentCity!.name
            allCities.sort { city, _ in city.name == self.currentCity?.name } // Put the current city first
        }
    }

    @IBOutlet weak var currentCityBarButton: UIBarButtonItem! {
        didSet {
            currentCityBarButton.title = nil
        }
    }

    private func setNearestCity() {
        if UserDefaults.standard.object(forKey: GeoCapConstants.UserDefaultsKeys.lastCity) == nil {
            loadingLocationsView.isHidden = false
        }

        let db = Firestore.firestore()
        db.collectionGroup("cities").getDocuments { [weak self] querySnapshot, error in
            guard let query = querySnapshot else {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }
            guard let self = self else { return }

            let userLocation = self.mapView.userLocation.location!
            var closestDistanceSoFar: CLLocationDistance?
            var nearestCitySoFar: City?

            for cityDocument in query.documents {
                guard let cityGeoPoint = cityDocument.data()["coordinates"] as? GeoPoint else {
                    os_log("Field 'coordinates' doesn't exist for city with id %{public}@", log: OSLog.Map, type: .debug,
                           cityDocument.documentID)
                    continue
                }
                let cityLocation = CLLocation(latitude: cityGeoPoint.latitude, longitude: cityGeoPoint.longitude)
                let distanceFromUser = userLocation.distance(from: cityLocation)

                // Add to all cities
                let cityCoordinates = CLLocationCoordinate2D(latitude: cityGeoPoint.latitude, longitude: cityGeoPoint.longitude)
                let city = City(name: cityDocument.documentID.capitalized, coordinates: cityCoordinates, reference: cityDocument.reference)
                self.allCities += [city]

                // Set to nearest city if closer
                if closestDistanceSoFar == nil || distanceFromUser < closestDistanceSoFar! {
                    closestDistanceSoFar = distanceFromUser
                    nearestCitySoFar = city
                }
            }
            self.allCities.sort { city, _ in city.name == self.currentCity?.name } // Put the current city first

            // Update only if the nearest city is not the same as the last cached city
            if let lastCity = UserDefaults.standard.data(forKey: GeoCapConstants.UserDefaultsKeys.lastCity) {
                do {
                    let lastCityDecoded = try JSONDecoder().decode(City.self, from: lastCity)
                    if nearestCitySoFar != lastCityDecoded {
                        self.currentCity = nearestCitySoFar
                        do {
                            let nearestCityEncoded = try JSONEncoder().encode(nearestCitySoFar)
                            UserDefaults.standard.set(nearestCityEncoded, forKey: GeoCapConstants.UserDefaultsKeys.lastCity)
                        } catch {
                            os_log("%{public}@", log: OSLog.Map, type: .debug, error as NSError)
                        }
                    }
                } catch {
                    os_log("%{public}@", log: OSLog.Map, type: .debug, error as NSError)
                }
            } else {
                self.currentCity = nearestCitySoFar
            }
        }
    }

    private enum LocationType: String {
        case building
        case area
    }

    // Listener not removed at all (only when signing out)
    // and constantly listening for updates on locations even while map is not visible
    // Makes it possible to keep the map updated in the background while other views are visible
    private var locationListener: ListenerRegistration?

    // swiftlint:disable:next cyclomatic_complexity
    func fetchLocations() {
        guard let username = Auth.auth().currentUser?.displayName else { return }

        loadingLocationsView.isHidden = false

        locationListener?.remove()

        var locationType: String
        switch locationFilter.selectedSegmentIndex {
        case 0:
            locationType = LocationType.building.rawValue
        case 1:
            locationType = LocationType.area.rawValue
        default:
            fatalError("Unexpected selected segment index in location filter")
        }

        locationListener = currentCity?.reference.collection("locations")
            .whereField("type", isEqualTo: locationType)
            .addSnapshotListener { [weak self] querySnapshot, error in
            guard let snapshot = querySnapshot else {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }

            snapshot.documentChanges.forEach { diff in
                guard let self = self else { return }
                guard let newAnnotation = Location(data: diff.document.data(), username: username) else {
                    os_log("Couldn't initialize location with id %{public}@", log: OSLog.Map, type: .debug, diff.document.documentID)
                    return
                }

                if diff.type == .added {
                    self.mapView.addAnnotation(newAnnotation)
                    self.addLocationOverlay(newAnnotation)
                }

                if diff.type == .modified {
                    if let oldAnnotation = self.mapView.annotations
                        .first(where: { $0.title == newAnnotation.name }) as? Location {
                        self.mapView.removeAnnotation(oldAnnotation)
                        self.mapView.removeOverlay(oldAnnotation.overlay)
                        self.mapView.addAnnotation(newAnnotation)
                        self.addLocationOverlay(newAnnotation)
                    }
                }

                if diff.type == .removed {
                    if let oldAnnotation = self.mapView.annotations
                        .first(where: { $0.title == newAnnotation.name }) as? Location {
                        self.mapView.removeOverlay(oldAnnotation.overlay)
                        self.mapView.removeAnnotation(oldAnnotation)
                    }
                }
            }

            self?.loadingLocationsView.isHidden = true
        }
    }

    func clearMap() {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
    }

    // Awkward solution but used for making the affected location available to the delegate function which renders overlays
    private var locationToOverlay: Location?
    private func addLocationOverlay(_ location: Location) {
        locationToOverlay = location
        mapView.addOverlay(location.overlay)
        locationToOverlay = nil
    }

    // Should optimally be subclassed but I couldn't get it to work properly
    // I wasn't able to cast the annotation to Location in the subclass init()
    private func setupLocationAnnotationView(for annotation: Location, on mapView: MKMapView) -> MKMarkerAnnotationView {
        let reuseIdentifier = NSStringFromClass(Location.self)
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier, for: annotation) as! MKMarkerAnnotationView

        annotationView.displayPriority = .required
        annotationView.animatesWhenAdded = true
        annotationView.canShowCallout = true
        annotationView.subtitleVisibility = .hidden

        let captureButton = UIButton(type: .system)
        let title = NSLocalizedString("callout-button-capture", comment: "Capture button on location callout view")
        captureButton.setTitle(title, for: .normal)
        captureButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
        captureButton.tintColor = .white
        captureButton.backgroundColor = .systemBlue
        captureButton.frame = CGRect(x: 0, y: 0, width: captureButtonWidth, height: captureButtonHeight)

        if annotation.isCapturedByUser {
            annotationView.markerTintColor = UIColor.systemBlue.withAlphaComponent(Constants.markerAlpha)
            annotationView.glyphImage = UIImage(systemName: "checkmark")

            let image = UIImage(systemName: "checkmark.circle")
            let imageView = UIImageView(image: image)
            imageView.frame = CGRect(x: 0, y: 0, width: Constants.calloutImageWidth, height: Constants.calloutImageHeight)
            imageView.tintColor = .systemBlue
            annotationView.rightCalloutAccessoryView = imageView
            fetchAndSetBitmoji(forUser: annotation.owner!, in: annotationView)
        } else if annotation.owner == nil {
            annotationView.glyphImage = UIImage(systemName: "circle")
            annotationView.markerTintColor = UIColor.systemGray.withAlphaComponent(Constants.markerAlpha)
            annotationView.rightCalloutAccessoryView = captureButton
            annotationView.leftCalloutAccessoryView = nil
        } else {
            annotationView.glyphImage = UIImage(systemName: "flag.fill")
            annotationView.markerTintColor = UIColor.systemRed.withAlphaComponent(Constants.markerAlpha)
            annotationView.rightCalloutAccessoryView = captureButton
            fetchAndSetBitmoji(forUser: annotation.owner!, in: annotationView)
        }

        return annotationView
    }

    private func fetchAndSetBitmoji(forUser username: String, in annotationView: MKAnnotationView) {
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username).getDocuments { [weak self] (snapshot, error) in
            if let error = error as NSError? {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                return
            }

            if let user = snapshot?.documents.first {
                let ref = Storage.storage().reference(withPath: "snapchat_bitmojis/\(user.documentID)/snapchat_bitmoji.png")
                ref.getData(maxSize: 1 * 1024 * 1024) { data, error in
                    if let error = error as NSError? {
                        let storageError = StorageErrorCode(rawValue: error.code)!
                        if storageError == .objectNotFound { return }
                        os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                        return
                    }

                    let bitmoji = UIImage(data: data!)
                    let imageView = UIImageView(frame: CGRect(x: 0,
                                                              y: 0,
                                                              width: (self?.captureButtonHeight ?? 0) - 12,
                                                              height: (self?.captureButtonHeight ?? 0) - 12))
                    imageView.image = bitmoji
                    annotationView.leftCalloutAccessoryView = imageView
                    return
                }
            }

            annotationView.leftCalloutAccessoryView = nil
        }
    }

    private func presentNotInsideAreaAlert() {
        let title = NSLocalizedString("alert-title-not-inside-area", comment: "Title of alert when user isn't inside area")
        let message = NSLocalizedString("alert-message-not-inside-area", comment: "Message of alert when user isn't inside area")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    // MARK: - Quiz

    private func handleQuizDismissal(quizVC: QuizViewController) {
        if isDefendingLocation {
            print("Defended")
            isDefendingLocation = false
            defendingLocationInfo = [String: Any]()
            return
        }

        if quizVC.quizWon {
            SoundManager.shared.playSound(withName: SoundManager.Sounds.quizWon)
            captureLocation()

            // Request notification auth after first capture
            if !(UserDefaults.standard.bool(forKey: GeoCapConstants.UserDefaultsKeys.notificationAuthRequestShown)) {
                presentRequestNotificationAuthAlert()
            }
        } else {
            // TODO: REMOVE THIS
            captureLocation()
            quizTimeoutIsActive = true
        }
    }

    private var quizTimeoutIsActive = false {
        willSet {
            if newValue == true {
                startQuizTimeout()
            }
        }
    }

    @IBOutlet weak var quizTimeoutView: QuizTimeoutView!

    private func startQuizTimeout() {
        quizTimeoutView.startTimer()

        Timer.scheduledTimer(withTimeInterval: GeoCapConstants.quizTimeoutInterval, repeats: false) { [weak self] _ in
            self?.quizTimeoutIsActive = false
            self?.quizTimeoutView.stopTimer()
        }
    }

    private func presentQuizTimeoutAlert() {
        let title = NSLocalizedString("quiz-timeout-alert-title", comment: "Title of quiz timeout alert")
        let messageFormat = NSLocalizedString("quiz-timeout-alert-message", comment: "Message of quiz timeout alert")
        let message = String(format: messageFormat, Int(GeoCapConstants.quizTimeoutInterval))
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    private var attemptedCaptureLocation: String?

    private func captureLocation() {
        guard let user = Auth.auth().currentUser, let username = user.displayName else { return }
        guard let locationName = attemptedCaptureLocation else { return }

        let db = Firestore.firestore()
        let batch = db.batch()

        currentCity?.reference.collection("locations")
            .whereField("name", isEqualTo: locationName)
            .getDocuments { querySnapshot, error in
            guard let query = querySnapshot else {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }

            if let document = query.documents.first {
                let locationReference = document.reference
                batch.updateData([
                    "owner": username,
                    "ownerId": user.uid,
                    "captureTimestamp": FieldValue.serverTimestamp()
                ], forDocument: locationReference)

                let userReference = db.collection("users").document(user.uid)
                batch.updateData(["capturedLocations": FieldValue.arrayUnion([locationName]),
                                  "capturedLocationsCount": FieldValue.increment(Int64(1))], forDocument: userReference)

                batch.commit { error in
                    if let error = error as NSError? {
                        os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            }
        }
    }

    private var isDefendingLocation = false
    private var defendingLocationInfo = [String: Any]()

    // swiftlint:disable:next function_parameter_count
    func defendLocation(locationName: String, locationId: String, coordinates: CLLocationCoordinate2D, country: String,
                        county: String, city: String, type: String) {

        defendingLocationInfo = [
            "locationName": locationName,
            "locationId": locationId,
            "coordinates": coordinates,
            "country": country,
            "county:": county,
            "city": city
        ]
        isDefendingLocation = true

        tabBarController?.selectedIndex = 1

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: 500, longitudinalMeters: 500)
            self?.mapView.setRegion(region, animated: true)
        }

        Timer.scheduledTimer(withTimeInterval: 1.75, repeats: false) { [weak self] _ in
            switch type {
            case "building":
                self?.locationFilter.selectedSegmentIndex = 0
            case "area":
                self?.locationFilter.selectedSegmentIndex = 1
            default:
                fatalError("Unexpected location type")
            }

            let ref = Firestore.firestore().document("countries/\(country)/counties/\(county)/cities/\(city)")
            self?.currentCity = City(name: city.capitalized, coordinates: coordinates, reference: ref)
        }

        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            if let quizVC = self?.storyboard?.instantiateViewController(identifier: "Quiz") as? QuizViewController {
                self?.tabBarController?.view.isUserInteractionEnabled = true
                quizVC.presentationController?.delegate = self
                self?.present(quizVC, animated: true)
            }
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid).collection("private").document("data")

        // Setup notification token
        InstanceID.instanceID().instanceID { (result, error) in
            if let error = error {
                os_log("%{public}@", log: OSLog.Map, type: .debug, error as NSError)
                Crashlytics.sharedInstance().recordError(error)
            } else if let result = result {
                let notificationToken = result.token
                ref.updateData(["notificationToken": notificationToken]) { error in
                    if let error = error {
                        os_log("%{public}@", log: OSLog.Map, type: .debug, error as NSError)
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            }
        }

        // Turn off location lost notifications for user if setting is 'denied' or 'not determined'
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .denied, .notDetermined:
                ref.updateData(["locationLostNotificationsEnabled": false]) { error in
                    if let error = error {
                        os_log("%{public}@", log: OSLog.Map, type: .debug, error as NSError)
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            default:
                break
            }
        }
    }

    private func presentRequestNotificationAuthAlert() {
        let title = NSLocalizedString("alert-title-request-notification-auth",
                                      comment: "Title of alert when requesting notification authorization")
        let message = NSLocalizedString("alert-message-request-notification-auth",
                                        comment: "Message of alert when requesting notification authorization")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let dontAllowActionTitle = NSLocalizedString("alert-action-title-dont-allow",
                                                     comment: "Title of alert action 'Don't Allow'")
        let dontAllowAction = UIAlertAction(title: dontAllowActionTitle, style: .default) { _ in
            UserDefaults.standard.set(true, forKey: GeoCapConstants.UserDefaultsKeys.notificationAuthRequestShown)
        }
        alert.addAction(dontAllowAction)

        let allowActionTitle = NSLocalizedString("alert-action-title-allow", comment: "Title of alert action 'Allow'")
        let allowAction = UIAlertAction(title: allowActionTitle, style: .default) { _ in
            guard let user = Auth.auth().currentUser else { return }

            let authOptions: UNAuthorizationOptions = [.alert, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, error) in
                if let error = error {
                    os_log("%{public}@", log: OSLog.Map, type: .debug, error as NSError)
                    Crashlytics.sharedInstance().recordError(error)
                    return
                } else if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }

                    let db = Firestore.firestore()
                    let ref = db.collection("users").document(user.uid).collection("private").document("data")
                    ref.updateData(["locationLostNotificationsEnabled": true]) { error in
                        if let error = error as NSError? {
                            os_log("%{public}@", log: OSLog.Map, type: .debug, error)
                            Crashlytics.sharedInstance().recordError(error)
                        }
                    }
                }
                UserDefaults.standard.set(true, forKey: GeoCapConstants.UserDefaultsKeys.notificationAuthRequestShown)
            }
        }
        alert.addAction(allowAction)

        // Had to delay the alert a bit to prevent getting "view is not in the window hierarchy" error
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.present(alert, animated: true)
        }
    }

    // MARK: - User Location

    private let locationManager = CLLocationManager()

    private func requestUserLocationAuth() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            presentLocationAccessDeniedAlert()
        @unknown default:
            break
        }
    }

    private func presentLocationAccessDeniedAlert() {
        let title = NSLocalizedString("alert-title-location-services-off", comment: "Alert title when location services is off")
        let message = NSLocalizedString("alert-message-location-services-off",
                                        comment: "Alert message when location services is off")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        let settingsActionTitle = NSLocalizedString("alert-action-title-settings",
                                                    comment: "Title of alert action for going to 'Settings'")
        let settingsAction = UIAlertAction(title: settingsActionTitle, style: .default, handler: { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        })
        alert.addAction(settingsAction)
        alert.addAction(okAction)
        present(alert, animated: true)
    }

    func user(location: MKUserLocation, isInside overlay: MKOverlay) -> Bool {
        let coordinates = location.coordinate

        switch overlay {
        case let polygon as MKPolygon:
            let polygonRenderer = MKPolygonRenderer(polygon: polygon)
            let mapPoint = MKMapPoint(coordinates)
            let polygonPoint = polygonRenderer.point(for: mapPoint)
            return polygonRenderer.path.contains(polygonPoint)
        case let circle as MKCircle:
            let circleRenderer = MKCircleRenderer(circle: circle)
            let mapPoint = MKMapPoint(coordinates)
            let circlePoint = circleRenderer.point(for: mapPoint)
            return circleRenderer.path.contains(circlePoint)
        default:
            fatalError("Unexpected overlay")
        }
    }

    // MARK: - Navigation

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        super.shouldPerformSegue(withIdentifier: identifier, sender: sender)

        switch identifier {
        case "Show Quiz":
            if quizTimeoutIsActive {
//                presentQuizTimeoutAlert()
//                return false
            }

            if let annotationView = sender as? MKAnnotationView, let annotation = annotationView.annotation as? Location {
                // Annotation title is a double optional 'String??' so it has to be doubly unwrapped
                if let locationTitle = annotationView.annotation?.title, locationTitle != nil {
                    if currentCity != nil {
                        if user(location: mapView.userLocation, isInside: annotation.overlay) {
                            return true
                        } else {
//                            presentNotInsideAreaAlert()
//                            return false
                            return true
                        }
                    }
                }
            }
        case "Show Choose City Popover":
            if !allCities.isEmpty, currentCity != nil {
                return true
            }
        default:
            return true
            // fatalError("Unexpected segue identifier")
        }

        return false
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        switch segue.identifier {
        case "Show Quiz":
            if let quizVC = segue.destination as? QuizViewController, let annotationView = sender as? MKAnnotationView {
                // Annotation title is a double optional 'String??' so it has to be doubly unwrapped
                if let locationTitle = annotationView.annotation?.title {
                    if let locationName = locationTitle {
                        quizVC.presentationController?.delegate = self
                        attemptedCaptureLocation = locationName
                    }
                }
            }
        case "Show Choose City Popover":
            if let popoverVC = segue.destination as? ChooseCityPopoverViewController {
                popoverVC.popoverPresentationController?.delegate = self
                popoverVC.allCities = allCities
                popoverVC.currentCity = currentCity
            }
        default:
            return
//            fatalError("Unexpected segue identifier")
        }
    }

    @IBAction func unwindToMap(unwindSegue: UIStoryboardSegue) {
        switch unwindSegue.identifier {
        case "unwindSegueQuizToMap":
            if let quizVC = unwindSegue.source as? QuizViewController {
                handleQuizDismissal(quizVC: quizVC)
            }
        case "unwindSegueChooseCityPopoverToMap":
            if let popoverVC = unwindSegue.source as? ChooseCityPopoverViewController {
                currentCity = popoverVC.currentCity
            }
        default:
            fatalError("Unexpected unwind segue identifier")
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if let quizVC = presentationController.presentedViewController as? QuizViewController {
            SwiftEntryKit.dismiss() // Dismiss "Tap anywhere to continue"-note, if visible
            handleQuizDismissal(quizVC: quizVC)
        }
    }

}

// MARK: - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        for view in views where view.annotation is MKUserLocation {
            view.canShowCallout = false
        }
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if currentCityIsNotSet {
            currentCityIsNotSet = false
            setNearestCity()
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let locationAnnotation = annotation as? Location {
            return setupLocationAnnotationView(for: locationAnnotation, on: mapView)
        }
        return nil
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        mapView.deselectAnnotation(view.annotation, animated: true)
        if shouldPerformSegue(withIdentifier: "Show Quiz", sender: view) {
            performSegue(withIdentifier: "Show Quiz", sender: view)
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let location = locationToOverlay else { return MKOverlayRenderer(overlay: overlay) }

        // Duplicate code but I can't figure out how to extract it since they are different classes
        switch overlay {
        case let polygon as MKPolygon:
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.alpha = Constants.overlayAlpha
            renderer.lineWidth = Constants.overlayLineWidth

            if location.isCapturedByUser {
                renderer.fillColor = .systemBlue
                renderer.strokeColor = .systemBlue
            } else if location.owner == nil {
                renderer.fillColor = .systemGray
                renderer.strokeColor = .systemGray
            } else {
                renderer.fillColor = .systemRed
                renderer.strokeColor = .systemRed
            }

            return renderer
        case let circle as MKCircle:
            let renderer = MKCircleRenderer(circle: circle)
            renderer.alpha = Constants.overlayAlpha
            renderer.lineWidth = Constants.overlayLineWidth

            if location.isCapturedByUser {
                renderer.fillColor = .systemBlue
                renderer.strokeColor = .systemBlue
            } else if location.owner == nil {
                renderer.fillColor = .systemGray
                renderer.strokeColor = .systemGray
            } else {
                renderer.fillColor = .systemRed
                renderer.strokeColor = .systemRed
            }

            return renderer
        default:
            fatalError("Unexpected overlay")
        }
    }

}

// MARK: - UIPopoverPresentationControllerDelegate

extension MapViewController: UIPopoverPresentationControllerDelegate {

    // Allow popovers on iPhones instead of converting them to modal presentations
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }

}
