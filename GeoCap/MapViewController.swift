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

class FirstViewController: UIViewController, MKMapViewDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // FIXME: Change to actual location
        let uppsala = CLLocationCoordinate2D(latitude: CLLocationDegrees(59.8586), longitude: CLLocationDegrees(17.6389))
        let region = MKCoordinateRegion(center: uppsala, latitudinalMeters: 4000, longitudinalMeters: 4000)
        mapView.setRegion(region, animated: true)
        
        checkLocationAuthorizationStatus()
    }
        
    // MARK: - Map View

    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            mapView.mapType = .mutedStandard
            mapView.showsUserLocation = true
        }
    }

    // MARK: - User Location
    
    let locationManager = CLLocationManager()
    
    // FIXME: Complete
    private func checkLocationAuthorizationStatus() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showLocationAccessFailedAlert()
        case .authorizedWhenInUse, .authorizedAlways:
            print("add case")
        @unknown default:
            fatalError()
        }
    }
    
    // TODO: String localization
    private func showLocationAccessFailedAlert() {
        let title = "Location Access Denied"
        let message = "Access to your location was denied, please enable access in your settings to be able to play."
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel)
        alert.addAction(okAction)
        present(alert, animated: true)
    }

}

