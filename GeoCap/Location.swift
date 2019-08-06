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
    var owner: String?
    var isCapturedByUser = false
    // Center coordinate (has to be called 'coordinate' to conform to MKAnnotation)
    @objc dynamic var coordinate: CLLocationCoordinate2D
    // Area coordinates enclosing location
    var areaCoordinates: [CLLocationCoordinate2D]?
    var overlay: MKOverlay
    
    init?(data: [String:Any], username: String) {
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
        
        if let coordinates = areaCoordinates {
            overlay = MKPolygon(coordinates: coordinates, count: coordinates.count)
        } else {
            overlay = MKCircle(center: coordinate, radius: 75)
        }
        
        super.init()
        
        if let owner = data["owner"] as? String {
            changeOwner(newOwner: owner, username: username)
        }
    }
    
    func changeOwner(newOwner: String, username: String) {
        owner = newOwner
        if newOwner == username {
            isCapturedByUser = true
            subtitle = "Captured by you"
        } else {
            isCapturedByUser = false
            subtitle = "Captured by \(newOwner)"
        }
    }
}
