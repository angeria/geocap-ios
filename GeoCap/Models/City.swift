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
    let county: String
    let country: String
    let coordinates: CLLocationCoordinate2D
    let reference: DocumentReference // Firestore document reference

    init(name: String, coordinates: CLLocationCoordinate2D, reference: DocumentReference) {
        self.name = name
        self.coordinates = coordinates
        self.reference = reference
        self.county = reference.parent.parent!.documentID
        self.country = reference.parent.parent!.parent.parent!.documentID
    }

    static func == (lhs: City, rhs: City) -> Bool {
        return lhs.coordinates.latitude == rhs.coordinates.latitude
            && lhs.coordinates.longitude == rhs.coordinates.longitude
            && lhs.name == rhs.name
            && lhs.county == rhs.county
            && lhs.country == rhs.country
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
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        let referencePath = try container.decode(String.self, forKey: .referencePath)

        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let reference = Firestore.firestore().document(referencePath)

        self.init(name: name, coordinates: coordinates, reference: reference)
    }
}
