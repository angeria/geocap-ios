//
//  Quiz.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-01.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation

struct Question {
    let question: String
    let answer: String
    let alternatives: [String]
    
    init(question: String, answer: String, alternatives: [String]) {
        self.question = question
        self.answer = answer
        self.alternatives = alternatives
    }
    
    init?(data: [String:Any]) {
        guard
            let question = data["question"] as? String,
            let answer = data["answer"] as? String,
            let alternatives = data["alternatives"] as? [String]
            else { print("Error in initializing Question"); return nil }
        
        self.init(question: question, answer: answer, alternatives: alternatives)
    }
    
}
