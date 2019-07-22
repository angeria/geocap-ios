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

class FirstViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requestUserLocationAuth()
    }
        
    // MARK: - Map View

    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.mapType = .mutedStandard
            mapView.showsUserLocation = true
        }
    }

    private var initialRegionIsSet = false
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !initialRegionIsSet {
            let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 4000, longitudinalMeters: 4000)
            mapView.setRegion(region, animated: true)
            initialRegionIsSet = true
        }
    }
    
    // MARK: - User Location Authorization
    
    private let locationManager = CLLocationManager()
    
    private func requestUserLocationAuth() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            presentLocationAccessDeniedAlert()
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    // TODO: String localization
    private func presentLocationAccessDeniedAlert() {
        let title = "Location Access Denied"
        let message = "Access to your location was denied, please enable location services to be able to play."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
    }
    
}
