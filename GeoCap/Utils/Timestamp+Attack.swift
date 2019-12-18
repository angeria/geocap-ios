//
//  Attacks.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-12-18.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import Firebase

extension Timestamp {

    func attackIsActive() -> Bool {
        let comparison = Calendar.current.dateComponents([.minute], from: dateValue(), to: Date())
        let attackTimeLimit = Int(truncating: RemoteConfig.remoteConfig()[GeoCapConstants.RemoteConfig.Keys.attackTimeLimit].numberValue!)
        return attackTimeLimit - comparison.minute! > 0
    }

    // PRECONDITION: Assumes there's time left
    func minutesLeftOfAttack() -> Int {
        let comparison = Calendar.current.dateComponents([.minute], from: dateValue(), to: Date())
        let attackTimeLimit = Int(truncating: RemoteConfig.remoteConfig()[GeoCapConstants.RemoteConfig.Keys.attackTimeLimit].numberValue!)
        return attackTimeLimit - comparison.minute!
    }

}
