//
//  Quiz.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-01.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import Crashlytics
import os.log

struct Question {
    let question: String
    let answer: String
    let alternatives: [String]

    init(question: String, answer: String, alternatives: [String]) {
        self.question = question
        self.answer = answer
        self.alternatives = alternatives
    }

    init?(data: [String: Any]) {
        guard
            let question = data["question"] as? String,
            let answer = data["answer"] as? String,
            let alternatives = data["alternatives"] as? [String]
        else {
            let error = NSError(domain: geoCapErrorDomain, code: GeoCapErrorCode.initFailed.rawValue, userInfo: [
                    NSDebugDescriptionErrorKey: "Failed to initialize question",
                    "question": data["question"] as? String ?? "",
                    "answer": data["answer"] as? String ?? "",
                    "alternatives": String(describing: data["alternatives"] as? [String]),
                    "index": data["index"] as? Int ?? -1
                ])
            os_log("Failed to initialize question", log: OSLog.Quiz, type: .debug, error)
            Crashlytics.sharedInstance().recordError(error)
            return nil
        }

        self.init(question: question, answer: answer, alternatives: alternatives)
    }

}
