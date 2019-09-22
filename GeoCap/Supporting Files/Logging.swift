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
}
