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
    }
}

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.mapType = .mutedStandard
            mapView.showsUserLocation = true
        }
    }
    
    private lazy var db = Firestore.firestore()
    // Currently not removed at all and constantly listening for updates on locations, even while map is not visible
    var locationUpdateListener: ListenerRegistration?
    private var regionIsCenteredOnUserLocation = false
    
    // Dependency injection
    var user: User!
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(Location.self))
        
        fetchLocations()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requestUserLocationAuth()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Currently keeping map in memory all the time because it's the main view
        // Uncomment this for proper deallocation according to delegate docs
        // mapView.delegate = nil
    }

    
    // MARK: - Annotations
    
    private func fetchLocations() {
        locationUpdateListener = db.collection("cities").document("uppsala").collection("locations").addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error fetching locations: \(error!)")
                return
            }
            snapshot.documentChanges.forEach { [weak self] diff in
                guard let self = self else { return }
                guard let username = self.user.displayName else {
                    print("Error in fetching locations: displayName is nil");
                    return
                }
                guard let newAnnotation = Location(data: diff.document.data(), username: username) else { return }
                
                if (diff.type == .added) {
                    self.mapView.addAnnotation(newAnnotation)
                    self.addLocationOverlay(newAnnotation)
                }
                if (diff.type == .modified) {
                    print("Modified location: \(newAnnotation.name)")
                    if let oldAnnotation = self.mapView.annotations.first(where: { $0.title == newAnnotation.name }) as? Location {
                        self.mapView.removeAnnotation(oldAnnotation)
                        self.mapView.removeOverlay(oldAnnotation.overlay)
                        self.mapView.addAnnotation(newAnnotation)
                        self.addLocationOverlay(newAnnotation)
                    }
                }
                if (diff.type == .removed) {
                    print("Removed location: \(newAnnotation.name)")
                    if let oldAnnotation = self.mapView.annotations.first(where: { $0.title == newAnnotation.name }) as? Location {
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
    // I wasn't able to cast the annotation to Location in the init()
    private func setupLocationAnnotationView(for annotation: Location, on mapView: MKMapView) -> MKMarkerAnnotationView {
        let reuseIdentifier = NSStringFromClass(Location.self)
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier, for: annotation) as! MKMarkerAnnotationView
        
        annotationView.animatesWhenAdded = true
        annotationView.canShowCallout = true
        annotationView.subtitleVisibility = .hidden
        
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture", for: .normal)
        captureButton.tintColor = .white
        captureButton.backgroundColor = UIColor.Custom.systemBlue
        // TODO: Extract constants and adjust to different text sizes
        captureButton.frame = CGRect(x: 0, y: 0, width: 90, height: 50)
        
        if annotation.isCapturedByUser {
            annotationView.markerTintColor = UIColor.Custom.systemGreen
            let image = UIImage(named: "green-flag")
            let imageView = UIImageView(image: image!)
            imageView.frame = CGRect(x: 0, y: 0, width: 27, height: 32)
            annotationView.rightCalloutAccessoryView = imageView
        } else if annotation.owner == nil {
            annotationView.markerTintColor = .lightGray
            annotationView.rightCalloutAccessoryView = captureButton
        } else {
            annotationView.markerTintColor = UIColor.Custom.systemRed
            annotationView.rightCalloutAccessoryView = captureButton
        }
        
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
                quizVC.username = user.displayName
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
            return setupLocationAnnotationView(for: annotation, on: mapView)
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        mapView.deselectAnnotation(view.annotation, animated: false)
        performSegue(withIdentifier: "Show Quiz", sender: view)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let location = locationToOverlay else { return MKOverlayRenderer(overlay: overlay) }
        
        // Duplicate code but I can't figure out how to extract it
        switch overlay {
        case let polygon as MKPolygon:
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.alpha = 0.45
            renderer.lineWidth = 1
            
            if location.isCapturedByUser {
                renderer.fillColor = UIColor.Custom.systemGreen
                renderer.strokeColor = UIColor.Custom.systemGreen
            } else if location.owner == nil {
                renderer.fillColor = .lightGray
                renderer.strokeColor = .lightGray
            } else {
                renderer.fillColor = UIColor.Custom.systemRed
                renderer.strokeColor = UIColor.Custom.systemRed
            }
            
            return renderer
        case let circle as MKCircle:
            let renderer = MKCircleRenderer(circle: circle)
            renderer.alpha = 0.45
            renderer.lineWidth = 1
            
            if location.isCapturedByUser {
                renderer.fillColor = UIColor.Custom.systemGreen
                renderer.strokeColor = UIColor.Custom.systemGreen
            } else if location.owner == nil {
                renderer.fillColor = .lightGray
                renderer.strokeColor = .lightGray
            } else {
                renderer.fillColor = UIColor.Custom.systemRed
                renderer.strokeColor = UIColor.Custom.systemRed
            }
            
            return renderer
        default:
            break
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
    
}
