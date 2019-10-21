//
//  City.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-09-15.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import CoreLocation
import Firebase

struct City: Equatable, Codable {
    
    let name: String
    let coordinates: CLLocationCoordinate2D
    let reference: DocumentReference // Firestore document reference
    
    init(name: String, coordinates: CLLocationCoordinate2D, reference: DocumentReference) {
      self.name = name
      self.coordinates = coordinates
      self.reference = reference
    }
    
    init(name: String, latitude: CLLocationDegrees, longitude: CLLocationDegrees, referencePath: String) { // default struct initializer
       self.name = name
       self.coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
       self.reference = Firestore.firestore().document(referencePath)
     }
    
    static func == (lhs: City, rhs: City) -> Bool {
        return lhs.coordinates.latitude == rhs.coordinates.latitude
            && lhs.coordinates.longitude == rhs.coordinates.longitude
            && lhs.name == rhs.name
            && lhs.reference == rhs.reference
    }

    enum CodingKeys: String, CodingKey {
        case name
        case latitude
        case longitude
        case referencePath
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(coordinates.latitude, forKey: .latitude)
        try container.encode(coordinates.longitude, forKey: .longitude)
        try container.encode(reference.path, forKey: .referencePath)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self) // defining our (keyed) container
        let name: String = try container.decode(String.self, forKey: .name) // extracting the data
        let latitude: CLLocationDegrees = try container.decode(CLLocationDegrees.self, forKey: .latitude) // extracting the data
        let longitude: CLLocationDegrees = try container.decode(CLLocationDegrees.self, forKey: .longitude) // extracting the data
        let referencePath: String = try container.decode(String.self, forKey: .referencePath) // extracting the data
        
        self.init(name: name, latitude: latitude, longitude: longitude, referencePath: referencePath)
    }
}
