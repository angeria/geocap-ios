//
//  Quiz.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-01.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation

struct Question {
    let title: String
    let question: String
    let answer: String
    let choices: [String]
    
    init(title: String, question: String, answer: String, choices: [String]) {
        self.title = title
        self.question = question
        self.answer = answer
        self.choices = choices
    }
    
    init?(data: [String:Any]) {
        guard
            let title = data["title"] as? String,
            let question = data["question"] as? String,
            let answer = data["answer"] as? String,
            let choices = data["choices"] as? [String]
            else { return nil }
        
        self.init(title: title, question: question, answer: answer, choices: choices)
    }
    
}
