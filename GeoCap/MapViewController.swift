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
    }
}

class MapViewController: UIViewController {

    private lazy var db = Firestore.firestore()
    
    // Currently not removed at all and constantly listening for updates on locations
    var locationUpdateListener: ListenerRegistration?
    
    private var regionIsCenteredOnUserLocation = false
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(Location.self))
        
        fetchLocations()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Has to be set every time the view appears because it's set to nil in viewDidDisappear
        mapView.delegate = self
        
        requestUserLocationAuth()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Has to be set to nil for proper dealloaction according to docs
        mapView.delegate = nil
    }
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.mapType = .mutedStandard
            mapView.showsUserLocation = true
        }
    }
    
    // MARK: - Annotations
    
    private func fetchLocations() {
        locationUpdateListener = db.collection("cities").document("uppsala").collection("locations")
            .addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error fetching locations: \(error!)")
                    return
                }
                snapshot.documentChanges.forEach { [weak self] diff in
                    guard let self = self else { return }
                    guard let location = Location(data: diff.document.data()) else { return }
                    
                    if (diff.type == .added) {
                        print("New location: \(location.name)")
                        self.mapView.addAnnotation(location)
                    }
                    if (diff.type == .modified) {
                        print("Modified location: \(location.name)")
                        if let annotation = self.mapView.annotations.first(where: { $0.title == location.name }) as? Location {
                            annotation.owner = location.owner
                        }
                    }
                    if (diff.type == .removed) {
                        print("Removed location: \(location.name)")
                        self.mapView.removeAnnotation(location)
                    }
                }
        }
    }
    
    private func setupLocationAnnotationView(for annotation: Location, on mapView: MKMapView) -> MKAnnotationView {
        let reuseIdentifier = NSStringFromClass(Location.self)
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier, for: annotation) as! MKMarkerAnnotationView
        
        annotationView.animatesWhenAdded = true
        annotationView.canShowCallout = true
        
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture", for: .normal)
        captureButton.tintColor = .white
        captureButton.backgroundColor = UIColor.Custom.systemBlue
        // TODO: Extract constants and adjust to different text sizes
        captureButton.frame = CGRect(x: 0, y: 0, width: 90, height: 50)
        annotationView.rightCalloutAccessoryView = captureButton
        
        return annotationView
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
    
    // TODO: String localization
    private func presentLocationAccessDeniedAlert() {
        let title = "Location Services Off"
        let message = "Turn on location services in settings to allow GeoCap to determine your current location"
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        let settingsAction = UIAlertAction(title: "Settings", style: .default, handler: {action in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        })
        alert.addAction(settingsAction)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let quizVC = segue.destination as? QuizViewController, let annotationView = sender as? MKAnnotationView {
            if let locationName = annotationView.annotation?.title {
                quizVC.locationName = locationName
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
        
        if let annotation = annotation as? Location {
            let annotationView = setupLocationAnnotationView(for: annotation, on: mapView)
            return annotationView
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        // Callouts stop showing if setting animated to false for some weird reason
        mapView.deselectAnnotation(view.annotation, animated: true)
        performSegue(withIdentifier: "Show Quiz", sender: view)
    }
}
