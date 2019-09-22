//
//  Logging.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-09-21.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation.NSBundle
import os.log

extension OSLog {
    private static let subsystem = Bundle.main.bundleIdentifier!

    static let auth = OSLog(subsystem: subsystem, category: "auth")
    static let map = OSLog(subsystem: subsystem, category: "map")
    static let leaderboard = OSLog(subsystem: subsystem, category: "leaderboard")
    static let profile = OSLog(subsystem: subsystem, category: "profile")
    static let quiz = OSLog(subsystem: subsystem, category: "quiz")
}
