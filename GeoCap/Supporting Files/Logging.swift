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

    static let Auth = OSLog(subsystem: subsystem, category: "Auth")
    static let Map = OSLog(subsystem: subsystem, category: "Map")
    static let Leaderboard = OSLog(subsystem: subsystem, category: "Leaderboard")
    static let Profile = OSLog(subsystem: subsystem, category: "Profile")
    static let Quiz = OSLog(subsystem: subsystem, category: "Quiz")
}
