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
        static let zoomLevel: CLLocationDistance = 2500
        static let captureButtonWidth: Int = 90
        static let captureButtonHeight = 50
        static let calloutFlagHeight = 32
        static let calloutFlagWidth = 32
        static let overlayAlpha: CGFloat = 0.45
        static let overlayLineWidth: CGFloat = 1
    }
}

class MapViewController: UIViewController {
    
    @IBOutlet var userTrackingButton: MKUserTrackingButton!
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.mapType = .mutedStandard
            mapView.showsUserLocation = true
            mapView.showsCompass = false
        }
    }
    
    private lazy var db = Firestore.firestore()
    // Currently not removed at all and constantly listening for updates on locations (even while map is not visible)
    // Makes it possible to keep the map updated in the background while the quiz or leaderboard view is visible
    var locationListener: ListenerRegistration?
    // Currently not removed at all and constantly listening for auth state updates
    // Makes it possible to notice sign-out event in profile view and then present auth view
    // Also prepares the map in the background after the user signed in the auth view
    var authListener: AuthStateDidChangeListenerHandle?
    
    private var regionIsCenteredOnUserLocation = false
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(Location.self))
        
        setupAuthListener()
        
        setupUserTrackingButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if Auth.auth().currentUser != nil {
            requestUserLocationAuth()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Auth listener is kept in memory all the time
        // Uncomment this to deallocate it
        // if Auth.auth().currentUser == nil {
        //     present(authUI.authViewController(), animated: true)
        // }
        
        // Currently keeping map in memory all the time for background state updates (e.g. while quiz view is visible)
        // Uncomment this for proper deallocation according to delegate docs
        // mapView.delegate = nil
    }
    
    // MARK: - Setup
    
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener() { [weak self] auth, user in
            if let user = Auth.auth().currentUser {
                // TODO: Remove this when display name has been made mandatory
                guard user.displayName != "", user.displayName != nil else { return }
                self?.setupAfterUserSignedIn()
            } else {
                let sb = UIStoryboard(name: "Main", bundle: .main)
                let authVC = sb.instantiateViewController(withIdentifier: "Auth")
                self?.tabBarController?.present(authVC, animated: true)
            }
        }
    }
    
    private func setupAfterUserSignedIn() {
        tabBarController?.selectedIndex = 1
        fetchLocations(type: .building)
        setupNotificationToken()
    }
    
    // MARK: - Notifications

    private func setupNotificationToken() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        InstanceID.instanceID().instanceID { [weak self] (result, error) in
            if let error = error {
                print("Error fetching remote instance ID: \(error)")
            } else if let result = result {
                let notificationToken = result.token
                guard notificationToken != UserDefaults.standard.string(forKey: "notificationToken") else { return }
                
                self?.db.collection("users").document(uid).updateData(["notificationToken": notificationToken]) { error in
                    if let error = error {
                        print("Error setting notification token for user: \(error)")
                    } else {
                        UserDefaults.standard.set(notificationToken, forKey: "notificationToken")
                    }
                }
            }
        }
    }
    
    private func presentRequestNotificationAuthAlert() {
        let title = NSLocalizedString("alert-title-request-notification-permission", comment: "Title of alert when requesting notification permission")
        let message = NSLocalizedString("alert-message-request-notification-permission", comment: "Message of alert when requesting notification permission")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default) { [weak self] action in
            guard let user = Auth.auth().currentUser else { return }
            
            let authOptions: UNAuthorizationOptions = [.alert, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { (granted, error) in
                if let error = error {
                    print("Error requesting notifications auth: ", error)
                    return
                } else if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    
                    self?.db.collection("users").document(user.uid).updateData(["locationCapturedPushNotificationsEnabled": true]) { error in
                        if let error = error {
                            print("Error in setting location captured push notifications setting to enabled: ", error)
                        }
                    }
                }
                UserDefaults.standard.set(true, forKey: "notificationAuthRequestShown")
            }
        }
        alert.addAction(okAction)
        // Had to delay the alert a bit to prevent getting "view is not in the window hierarchy" error
        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] timer in
            self?.present(alert, animated: true)
        }
    }
    
    // MARK: - User Location Button
    
    func setupUserTrackingButton() {
        let button = MKUserTrackingButton(mapView: mapView)
        button.layer.backgroundColor = UIColor(white: 1, alpha: 0.8).cgColor
        button.layer.cornerRadius = 5
        button.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16)
        ])
    }
    
    // MARK: - Segmented Control (location filter)
    
    @IBOutlet weak var locationFilter: UISegmentedControl!
    
    @IBAction func locationFilter(_ sender: UISegmentedControl) {
        clearMap()
        
        switch sender.selectedSegmentIndex {
        case 0:
            fetchLocations(type: .building)
        case 1:
            fetchLocations(type: .area)
        default:
            fatalError("Unexpected segment index in locationFilter()")
        }
    }
    
    
    // MARK: - Annotations
    
    enum LocationType: String {
        case building
        case area
    }
    
    private func clearMap() {
        let annotations = mapView.annotations
        let overlays = mapView.overlays
        mapView.removeAnnotations(annotations)
        mapView.removeOverlays(overlays)
    }
    
    private func fetchLocations(type: LocationType) {
        
        locationListener = db.collection("cities")
            .document("uppsala")
            .collection("locations")
            .whereField("type", isEqualTo: type.rawValue)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error fetching locations: \(error!)")
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
        
        annotationView.clusteringIdentifier = "location"
        annotationView.displayPriority = .defaultLow
        
        annotationView.glyphImage = UIImage(named: "marker-flag")
        annotationView.glyphTintColor = .white
        
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
            annotationView.markerTintColor = UIColor.GeoCap.purple
            
            let image = UIImage(named: "callout-flag")!.withRenderingMode(.alwaysTemplate)
            let imageView = UIImageView(image: image)
            imageView.frame = CGRect(x: 0, y: 0, width: Constants.calloutFlagWidth, height: Constants.calloutFlagHeight)
            imageView.tintColor = UIColor.GeoCap.purple
            annotationView.rightCalloutAccessoryView = imageView
        } else if annotation.owner == nil {
            annotationView.markerTintColor = UIColor.GeoCap.blue
            annotationView.rightCalloutAccessoryView = captureButton
        } else {
            annotationView.markerTintColor = UIColor.GeoCap.red
            annotationView.rightCalloutAccessoryView = captureButton
        }
        
        return annotationView
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
    
    private func presentNotInsideAreaAlert() {
        let title = NSLocalizedString("alert-title-not-inside-area", comment: "Title of alert when user isn't inside area")
        let message = NSLocalizedString("alert-message-not-inside-area", comment: "Message of alert when user isn't inside area")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okActionTitle = NSLocalizedString("alert-action-title-OK", comment: "Title of alert action OK")
        let okAction = UIAlertAction(title: okActionTitle, style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    // MARK: - User Location Authorization
    
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
    
    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        
        if identifier == "Show Quiz" {
            if let annotationView = sender as? MKAnnotationView, let annotation = annotationView.annotation as? Location {
                if annotationView.annotation?.title != nil {
                    if user(location: mapView.userLocation, isInside: annotation.overlay) {
                        return true
                    } else {
//                        presentNotInsideAreaAlert()
                        return true
                    }
                }
            }
        }
        return false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let quizVC = segue.destination as? QuizViewController, let annotationView = sender as? MKAnnotationView {
            if let locationName = annotationView.annotation?.title {
                quizVC.locationName = locationName
            }
        }
    }
    
    
    @IBAction func unwindToMap(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "unwindSegueToMap", let quizVC = unwindSegue.source as? QuizViewController {
            if quizVC.locationWasCaptured {
                // Request notifications permission after first capture
                if !(UserDefaults.standard.bool(forKey: "notificationAuthRequestShown")) {
                    presentRequestNotificationAuthAlert()
                }

                // Update the location on the map immediately before server response as a workaround of sometimes slow cold started cloud function
                let capturedLocationName = quizVC.locationName
                if let annotation = mapView.annotations.first(where: { $0.title == capturedLocationName }) as? Location {
                    guard let username = Auth.auth().currentUser?.displayName else { return }
                    
                    mapView.removeAnnotation(annotation)
                    mapView.removeOverlay(annotation.overlay)
                    annotation.changeOwner(newOwner: username, username: username)
                    mapView.addAnnotation(annotation)
                    addLocationOverlay(annotation)
                }
            }
        }
    }
    
}

extension MapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !regionIsCenteredOnUserLocation {
            let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: Constants.zoomLevel, longitudinalMeters: Constants.zoomLevel)
            mapView.setRegion(region, animated: true)
            regionIsCenteredOnUserLocation = true
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
        
        if let locationAnnotation = annotation as? Location {
            return setupLocationAnnotationView(for: locationAnnotation, on: mapView)
        } else if let clusterAnnotation = annotation as? MKClusterAnnotation {
            let clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: clusterAnnotation) as! MKMarkerAnnotationView
            clusterView.markerTintColor = UIColor.GeoCap.blue
            return clusterView
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
        
        // Duplicate code but I can't figure out how to extract it
        switch overlay {
        case let polygon as MKPolygon:
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.alpha = Constants.overlayAlpha
            renderer.lineWidth = Constants.overlayLineWidth
            
            if location.isCapturedByUser {
                renderer.fillColor = UIColor.GeoCap.purple
                renderer.strokeColor = UIColor.GeoCap.purple
            } else if location.owner == nil {
                renderer.fillColor = UIColor.GeoCap.blue
                renderer.strokeColor = UIColor.GeoCap.blue
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
                renderer.fillColor = UIColor.GeoCap.purple
                renderer.strokeColor = UIColor.GeoCap.purple
            } else if location.owner == nil {
                renderer.fillColor = UIColor.GeoCap.blue
                renderer.strokeColor = UIColor.GeoCap.blue
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
