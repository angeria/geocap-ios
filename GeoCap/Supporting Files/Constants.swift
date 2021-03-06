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
    static let quizTimeoutInterval = 8.0
    static let maxDownloadSize: Int64 =  1 * 1024 * 1024 // 1 MB

    enum UserDefaultsKeys {
        static let soundsAreEnabled = "soundsAreEnabled"
        static let email = "email"
        static let username = "username"
        static let notificationAuthRequestShown = "notificationAuthRequestShown"
        static let lastCity = "lastCity"
        static let tapToContinueNoteDisplayCount = "tapToContinueNoteDisplayCount"
        static let quizWonCount = "quizWonCount"
        static let lastVersionPromptedForReview = "lastVersionPromptedForReview"
    }

    enum RemoteConfig {
        enum Keys { // swiftlint:disable:this nesting
            static let numberOfQuestionsBaseline = "numberOfQuestionsBaseline"
            static let quizTime = "quizTime"
            static let minimumUsernameLength = "minimumUsernameLength"
            static let maximumUsernameLength = "maximumUsernameLength"
        }

        static let Defaults = [
            Keys.numberOfQuestionsBaseline: 3 as NSObject,
            Keys.quizTime: 13 as NSObject,
            Keys.minimumUsernameLength: 3 as NSObject,
            Keys.maximumUsernameLength: 20 as NSObject
        ]
    }
}
