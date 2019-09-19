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

extension MapViewController {
    enum Constants {
        static let zoomLevel: CLLocationDistance = 4000
        static let captureButtonWidth: Int = 90
        static let captureButtonHeight = 50
        static let calloutFlagHeight = 32
        static let calloutFlagWidth = 32
        static let overlayAlpha: CGFloat = 0.45
        static let overlayLineWidth: CGFloat = 1
    }
}

class MapViewController: UIViewController {
    
    // Currently keeping map in memory all the time for background state updates (e.g. while quiz view is visible)
    // Set 'mapView.delegate = nil' to be able to deallocate it
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.mapType = .mutedStandard
            mapView.showsUserLocation = true
            mapView.showsCompass = false
        }
    }
    
    private var regionIsCenteredOnUserLocation = false
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(Location.self))
        
        setupAuthListener()
        
        if Auth.auth().currentUser != nil {
            setupAfterUserSignedIn()
        }
        
        // Setup user tracking bar button
        let userTrackingBarButton = MKUserTrackingBarButtonItem(mapView: mapView)
        navigationItem.setRightBarButton(userTrackingBarButton, animated: true)
    }
    
    // MARK: - Setup
    
    private func setupAfterUserSignedIn() {
        // Choose "Map" tab
        tabBarController?.selectedIndex = 1
        
        // Choose "Buildings" location filter
        locationFilter.selectedSegmentIndex = 0

        requestUserLocationAuth()
        
        if currentCity != nil {
            switch locationFilter.selectedSegmentIndex {
            case 0:
                fetchLocations(ofType: .building)
            case 1:
                fetchLocations(ofType: .area)
            default:
                fatalError("Unexpected segment index in locationFilter()")
            }
        }
        
        if authListener == nil {
            setupAuthListener()
        }
        
        setupNotifications()
    }
    
    // Currently listener isn't removed at all (only when singning out) and constantly listening for auth state updates
    // Makes it possible to notice sign-out event in profile view to present auth view
    var authListener: AuthStateDidChangeListenerHandle?
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener() { [weak self] auth, user in
            if user == nil {
                self?.teardownAfterUserSignedOut()
                
                let sb = UIStoryboard(name: "Main", bundle: .main)
                let authVC = sb.instantiateViewController(withIdentifier: "Auth")
                self?.tabBarController?.present(authVC, animated: true)
            }
        }
    }
    
    // MARK: - Teardown
    
    private func teardownAfterUserSignedOut() {
        clearMap()
        
        locationListener?.remove()
        
        if authListener != nil {
            Auth.auth().removeStateDidChangeListener(authListener!)
            authListener = nil
        }
    }
    
    private func clearMap() {
        let annotations = mapView.annotations
        let overlays = mapView.overlays
        mapView.removeAnnotations(annotations)
        mapView.removeOverlays(overlays)
    }
    
    // MARK: - Location Filter (segmented control)
    
    @IBOutlet weak var locationFilter: UISegmentedControl!
    
    @IBAction func locationFilter(_ sender: UISegmentedControl) {
        clearMap()
        
        switch sender.selectedSegmentIndex {
        case 0:
            fetchLocations(ofType: .building)
        case 1:
            fetchLocations(ofType: .area)
        default:
            fatalError("Unexpected segment index in locationFilter()")
        }
    }

    
    // MARK: - Locations
    
    @IBOutlet weak var loadingLocationsView: UIView! {
        didSet {
            loadingLocationsView.layer.cornerRadius = 15
        }
    }
    
    private var allCities = [City]()
    
    private var currentCity: City? {
        didSet {
            guard let currentCity = currentCity else { return }
            
            clearMap()
            
            let region = MKCoordinateRegion(center: currentCity.coordinates, latitudinalMeters: Constants.zoomLevel, longitudinalMeters: Constants.zoomLevel)
            mapView.setRegion(region, animated: true)
            
            switch locationFilter.selectedSegmentIndex {
            case 0:
                fetchLocations(ofType: .building)
            case 1:
                fetchLocations(ofType: .area)
            default:
                fatalError("Unexpected selected segment index in location filter")
            }
            
            currentCityBarButton.title = currentCity.name
            allCities.sort { city, _ in city.name == currentCity.name } // Put the current city first
        }
    }
    
    @IBOutlet weak var currentCityBarButton: UIBarButtonItem! {
        didSet {
            currentCityBarButton.title = nil
        }
    }
    
    private func setNearestCity() {
        loadingLocationsView.isHidden = false
        
        let db = Firestore.firestore()
        db.collectionGroup("cities").getDocuments() { [weak self] querySnapshot, error in
            guard let query = querySnapshot else {
                print("Error getting 'cities' collection group query snapshot: \(String(describing: error))")
                return
            }
            
            let userLocation = self?.mapView.userLocation.location
            var closestDistanceSoFar: CLLocationDistance?
            var nearestCitySoFar: City?
            
            for cityDocument in query.documents {
                guard let cityGeoPoint = cityDocument.data()["coordinates"] as? GeoPoint else { continue }
                let cityLocation = CLLocation(latitude: cityGeoPoint.latitude, longitude: cityGeoPoint.longitude)
                
                guard let distanceFromUser = userLocation?.distance(from: cityLocation) else { return }
                
                // Add to all cities
                let cityCoordinates = CLLocationCoordinate2D(latitude: cityGeoPoint.latitude, longitude: cityGeoPoint.longitude)
                let city = City(name: cityDocument.documentID.capitalized, coordinates: cityCoordinates, reference: cityDocument.reference)
                self?.allCities += [city]
                
                if closestDistanceSoFar == nil || distanceFromUser < closestDistanceSoFar ?? 0 {
                    closestDistanceSoFar = distanceFromUser
                    nearestCitySoFar = city
                }
            }
            
            self?.currentCity = nearestCitySoFar
        }
    }
    
    enum LocationType: String {
        case building
        case area
    }
    
    // Currently not removed at all and constantly listening for updates on locations (even while map is not visible)
    // Makes it possible to keep the map updated in the background while other views are visible
    var locationListener: ListenerRegistration?
    private func fetchLocations(ofType type: LocationType) {
        
        loadingLocationsView.isHidden = false
        
        locationListener?.remove()
        
        locationListener = currentCity?.reference.collection("locations").whereField("type", isEqualTo: type.rawValue).addSnapshotListener { [weak self] querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error fetching locations: \(String(describing: error))")
                return
            }
            guard let username = Auth.auth().currentUser?.displayName else { return }
            
            snapshot.documentChanges.forEach { diff in
                guard let self = self else { return }
                guard let newAnnotation = Location(data: diff.document.data(), username: username) else { return }
                
                if (diff.type == .added) {
                    self.mapView.addAnnotation(newAnnotation)
                    self.addLocationOverlay(newAnnotation)
                }
                
                if (diff.type == .modified) {
                    if let oldAnnotation = self.mapView.annotations.first(where: { $0.title == newAnnotation.name }) as? Location {
                        self.mapView.removeAnnotation(oldAnnotation)
                        self.mapView.removeOverlay(oldAnnotation.overlay)
                        self.mapView.addAnnotation(newAnnotation)
                        self.addLocationOverlay(newAnnotation)
                    }
                }
                
                if (diff.type == .removed) {
                    if let oldAnnotation = self.mapView.annotations.first(where: { $0.title == newAnnotation.name }) as? Location {
                        self.mapView.removeOverlay(oldAnnotation.overlay)
                        self.mapView.removeAnnotation(oldAnnotation)
                    }
                }
            }
            
            self?.loadingLocationsView.isHidden = true
        }
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
        
        annotationView.animatesWhenAdded = true
        annotationView.canShowCallout = true
        annotationView.subtitleVisibility = .hidden
        
        let captureButton = UIButton(type: .system)
        let title = NSLocalizedString("callout-button-capture", comment: "Capture button on location callout view")
        captureButton.setTitle(title, for: .normal)
        captureButton.tintColor = .white
        captureButton.backgroundColor = UIColor.GeoCap.blue
        captureButton.frame = CGRect(x: 0, y: 0, width: Constants.captureButtonWidth, height: Constants.captureButtonHeight)
        
        if annotation.isCapturedByUser {
            annotationView.markerTintColor = UIColor.GeoCap.blue
            
            annotationView.glyphImage = UIImage(named: "marker-check-mark")
            
            let image = UIImage(named: "callout-check-mark")!.withRenderingMode(.alwaysTemplate)
            let imageView = UIImageView(image: image)
            imageView.frame = CGRect(x: 0, y: 0, width: Constants.calloutFlagWidth, height: Constants.calloutFlagHeight)
            imageView.tintColor = UIColor.GeoCap.blue
            annotationView.rightCalloutAccessoryView = imageView
        } else if annotation.owner == nil {
            annotationView.glyphImage = UIImage(named: "marker-circle")
            
            annotationView.markerTintColor = UIColor.GeoCap.gray
            annotationView.rightCalloutAccessoryView = captureButton
        } else {
            annotationView.glyphImage = UIImage(named: "marker-flag")
            
            annotationView.markerTintColor = UIColor.GeoCap.red
            annotationView.rightCalloutAccessoryView = captureButton
        }
        
        return annotationView
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
    
    // MARK: - Notifications

    private func setupNotifications() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        // Setup notification token
        InstanceID.instanceID().instanceID { (result, error) in
            if let error = error {
                print("Error fetching remote instance ID: \(error)")
            } else if let result = result {
                let notificationToken = result.token
                db.collection("users").document(uid).updateData(["notificationToken": notificationToken]) { error in
                    if let error = error {
                        print("Error setting notification token for user: \(error)")
                    }
                }
            }
        }
        
        // Turn off location lost notifications for user if setting is 'denied' or 'not determined'
        UNUserNotificationCenter.current().getNotificationSettings() { settings in
            switch settings.authorizationStatus {
            case .denied, .notDetermined:
                db.collection("users").document(uid).updateData(["locationLostNotificationsEnabled": false]) { error in
                    if let error = error {
                        print("Error setting 'locationLostNotificationsEnabled' in setupNotifications(): ", error)
                    }
                }
            default:
                break
            }
        }
    }
    
    private func presentRequestNotificationAuthAlert() {
        let title = NSLocalizedString("alert-title-request-notification-auth", comment: "Title of alert when requesting notification authorization")
        let message = NSLocalizedString("alert-message-request-notification-auth", comment: "Message of alert when requesting notification authorization")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default) { action in
            guard let user = Auth.auth().currentUser else { return }
            
            let authOptions: UNAuthorizationOptions = [.alert, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, error) in
                if let error = error {
                    print("Error requesting notification auth: ", error)
                    return
                } else if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    
                    let db = Firestore.firestore()
                    db.collection("users").document(user.uid).updateData(["locationLostNotificationsEnabled": true]) { error in
                        if let error = error {
                            print("Error setting 'locationLostNotificationsEnabled' to true: ", error)
                        }
                    }
                }
                UserDefaults.standard.set(true, forKey: "notificationAuthRequestShown")
            }
        }
        alert.addAction(okAction)
        
        // Had to delay the alert a bit to prevent getting "view is not in the window hierarchy" error
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] timer in
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
        let message = NSLocalizedString("alert-message-location-services-off", comment: "Alert message when location services is off")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        let settingsActionTitle = NSLocalizedString("alert-action-title-settings", comment: "Title of alert action for going to 'Settings'")
        let settingsAction = UIAlertAction(title: settingsActionTitle, style: .default, handler: {action in
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
            fatalError("Unexpected overlay in user(location:, isInside:)")
        }
    }
    
    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        
        switch identifier {
        case "Show Quiz":
            if let annotationView = sender as? MKAnnotationView, let annotation = annotationView.annotation as? Location {
                // Annotation title is a double optional 'String??' so it has to be doubly unwrapped
                if let locationTitle = annotationView.annotation?.title, locationTitle != nil {
                    if currentCity != nil {
                        if user(location: mapView.userLocation, isInside: annotation.overlay) {
                            return true
                        } else {
//                            presentNotInsideAreaAlert()
                            return true
//                             return false
                        }
                    } else {
                        print("Couldn't start quiz: 'currentCity' == nil")
                    }
                } else {
                    print("Couldn't start quiz: 'locationTitle' == nil")
                }
            }
        case "Show Choose City Popover":
            if !allCities.isEmpty, currentCity != nil {
                return true
            }
        default:
            break
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
                    if let locationName = locationTitle, let cityReference = currentCity?.reference {
                        quizVC.locationName = locationName
                        quizVC.cityReference = cityReference
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
            break
        }
    }
    
    @IBAction func unwindToMap(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "unwindSegueQuizToMap", let quizVC = unwindSegue.source as? QuizViewController {
            if !quizVC.quizFailed {
                // Request notification auth after first capture
                if !(UserDefaults.standard.bool(forKey: "notificationAuthRequestShown")) {
                    presentRequestNotificationAuthAlert()
                }
            }
        } else if unwindSegue.identifier == "unwindSegueAuthToMap" {
            setupAfterUserSignedIn()
        } else if unwindSegue.identifier == "unwindSegueChooseCityPopoverToMap" {
            if let popoverVC = unwindSegue.source as? ChooseCityPopoverViewController {
                currentCity = popoverVC.currentCity
            }
        }
    }
    
}

// MARK: - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !regionIsCenteredOnUserLocation {
            setNearestCity()
            
            let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: Constants.zoomLevel, longitudinalMeters: Constants.zoomLevel)
            mapView.setRegion(region, animated: true)
            regionIsCenteredOnUserLocation = true
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
        
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
                renderer.fillColor = UIColor.GeoCap.blue
                renderer.strokeColor = UIColor.GeoCap.blue
            } else if location.owner == nil {
                renderer.fillColor = UIColor.GeoCap.gray
                renderer.strokeColor = UIColor.GeoCap.gray
            } else {
                renderer.fillColor = UIColor.GeoCap.red
                renderer.strokeColor = UIColor.GeoCap.red
            }
            
            return renderer
        case let circle as MKCircle:
            let renderer = MKCircleRenderer(circle: circle)
            renderer.alpha = Constants.overlayAlpha
            renderer.lineWidth = Constants.overlayLineWidth
            
            if location.isCapturedByUser {
                renderer.fillColor = UIColor.GeoCap.blue
                renderer.strokeColor = UIColor.GeoCap.blue
            } else if location.owner == nil {
                renderer.fillColor = UIColor.GeoCap.gray
                renderer.strokeColor = UIColor.GeoCap.gray
            } else {
                renderer.fillColor = UIColor.GeoCap.red
                renderer.strokeColor = UIColor.GeoCap.red
            }
            
            return renderer
        default:
            fatalError("Unexpected overlay in mapView(rendererFor:)")
        }
    }
    
}

// MARK: - UIPopoverPresentationControllerDelegate

extension MapViewController: UIPopoverPresentationControllerDelegate {
    
    // Makes popovers allowed on iPhones instead of converting them to modal presentations
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
}
