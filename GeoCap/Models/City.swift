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

struct City {
    let name: String
    let coordinates: CLLocationCoordinate2D
    let reference: DocumentReference // Firestore document reference
}
