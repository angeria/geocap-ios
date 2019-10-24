//
//  Constants.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-09-10.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import UIKit

enum GeoCapConstants {
    static let shakeAnimationDuration = 0.4
    static let scaleAnimationDuration = 0.125
    static let defaultCornerRadius: CGFloat = 10
    static let minimumUsernameLength = 3
    static let maximumUsernameLength = 20
    
    enum UserDefaultsKeys {
        static let soundsAreEnabled = "soundsAreEnabled"
        static let email = "email"
        static let username = "username"
        static let notificationAuthRequestShown = "notificationAuthRequestShown"
        static let lastCity = "lastCity"
    }
}
