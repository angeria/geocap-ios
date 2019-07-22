//
//  GeoCap.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-22.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import Firebase

struct Location {
    let name: String
    let coordinates: (Double, Double)
    
    init?(data: [String:Any]) {
        guard
            let name = data["name"] as? String,
            let geoPoint = data["coordinates"] as? GeoPoint
            else { return nil }
        
        self.name = name
        self.coordinates = (geoPoint.latitude, geoPoint.longitude)
    }
}
