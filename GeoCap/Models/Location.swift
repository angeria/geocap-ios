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

extension Location {
    enum Constants {
        static let circleOverlayRadius: CLLocationDistance = 50
    }
}

class Location: NSObject, MKAnnotation {
    let reference: DocumentReference
    let name: String
    var title: String?
    var subtitle: String? = NSLocalizedString("callout-subtitle-not-captured-yet",
                                              comment: "Callout subtitle when a location isn't captured yet")
    var owner: String?
    var isCapturedByUser = false
    var isUnderAttack = false // Not available to capture if currently attacked
    var attackerName: String?
    // Center coordinate (has to be called 'coordinate' to conform to MKAnnotation)
    @objc dynamic var coordinate: CLLocationCoordinate2D
    // Coordinates enclosing location
    var areaCoordinates: [CLLocationCoordinate2D]?
    var overlay: MKOverlay

    init?(data: [String: Any], reference: DocumentReference, username: String) {
        guard
            let name = data["name"] as? String,
            let center = data["center"] as? GeoPoint else { return nil }

        self.reference = reference
        self.name = name
        self.title = name
        self.coordinate = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)

        if let areaCoordinates = data["coordinates"] as? [GeoPoint] {
            self.areaCoordinates = areaCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude,
                                                                                longitude: $0.longitude) }
        }

        if let coordinates = areaCoordinates {
            overlay = MKPolygon(coordinates: coordinates, count: coordinates.count)
        } else {
            overlay = MKCircle(center: coordinate, radius: Constants.circleOverlayRadius)
        }

        super.init()

        if let owner = data["owner"] as? String {
            changeOwner(newOwner: owner, username: username)
        }

        if let isUnderAttack = data["isUnderAttack"] as? Bool {
            self.isUnderAttack = isUnderAttack

            if let attackerName = data["attackerName"] as? String {
                let messageFormat = NSLocalizedString("callout-subtitle-attacked",
                                                      comment: "Callout subtitle when location is attacked")
                subtitle = String(format: messageFormat, attackerName)
            }
        }
    }

    func changeOwner(newOwner: String, username: String) {
        owner = newOwner
        if newOwner == username {
            isCapturedByUser = true
            subtitle = NSLocalizedString("callout-subtitle-captured-by-user",
                                         comment: "Callout subtitle when location is owned by user")
        } else {
            isCapturedByUser = false
            let format = NSLocalizedString("callout-subtitle-captured-by-other-user",
                                           comment: "Callout subtitle with name of owner: Captured by ‰@{username}")
            subtitle = String.localizedStringWithFormat(format, newOwner)
        }
    }
}
