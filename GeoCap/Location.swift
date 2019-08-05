//
//  Location.swift
//  Location
//
//  Created by Benjamin Angeria on 2019-07-22.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import Firebase
import MapKit

class Location: NSObject, MKAnnotation {
    let name: String
    var title: String?
    var subtitle: String? = "Not captured yet"
    var owner: String? {
        didSet {
            subtitle = "Captured by: \(owner!)"
        }
    }
    // Center coordinate (has to be called 'coordinate' to conform to MKAnnotation)
    @objc dynamic var coordinate: CLLocationCoordinate2D
    // Area coordinates enclosing location
    var areaCoordinates: [CLLocationCoordinate2D]?
    
    
    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.title = name
        self.coordinate = coordinate
    }
    
    init?(data: [String:Any]) {
        guard
            let name = data["name"] as? String,
            let center = data["center"] as? GeoPoint
            else { print("Error initializing Location from data"); return nil }
        
        self.name = name
        self.title = name
        self.coordinate = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        
        if let areaCoordinates = data["coordinates"] as? [GeoPoint] {
            self.areaCoordinates = areaCoordinates.map() { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        
        if let owner = data["owner"] as? String {
            self.owner = owner
            self.subtitle = "Captured by: \(owner)"
        }
    }
}
