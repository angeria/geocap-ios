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
    @objc dynamic var coordinate: CLLocationCoordinate2D
    
    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.title = name
        self.coordinate = coordinate
    }
    
    init?(data: [String:Any]) {
        guard
            let name = data["name"] as? String,
            let geoPoint = data["coordinates"] as? GeoPoint
            else { print("Error initializing Location from data"); return nil }
        
        self.name = name
        self.title = name
        self.coordinate = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
        
        if let owner = data["owner"] as? String {
            self.owner = owner
            self.subtitle = "Captured by: \(owner)"
        }
    }
}
