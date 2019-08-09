//
//  QuizViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-27.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase

class QuizViewController: UIViewController {
    
    // TODO: Fonts
    // TODO: SF Symbols after iOS 13
    
    @IBOutlet weak var questionLabel: UILabel! {
        didSet {
            questionLabel.text = nil
        }
    }
    
    // TODO: Make buttons empty while loading actual answers
    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach() {
                $0.titleLabel?.text = nil
                $0.layer.cornerRadius = 10
            }
        }
    }
    
    private lazy var db = Firestore.firestore()
    
    private var questions = [Question]()
    private var currentQuestion: Question?
    private var correctAnswersCount = 0
    private let numberOfQuestions = 3
    
    // Dependency injections
    var locationName: String?
    var username: String?
    
    @IBOutlet weak var nextQuestionTapRecognizer: UITapGestureRecognizer!
    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        showNextQuestion()
        nextQuestionTapRecognizer.isEnabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchQuestions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @IBAction func answerPressed(_ button: UIButton) {
        answerButtons.forEach() { $0.isEnabled = false }
        
        if button.titleLabel?.text == currentQuestion?.answer {
            button.backgroundColor = UIColor.GeoCap.green
            button.scale()
            correctAnswersCount += 1
        } else {
            button.backgroundColor = UIColor.GeoCap.red
            button.shake()
        }
        
        nextQuestionTapRecognizer.isEnabled = true
    }
    
    // Currently questions are recieved in random specific sets, effective since it's just one request
    // Could be changed to fetch one question at a time which is more random but generates more reads
    //
    // Every question in db has a 'random' object with three randomly generated 64 bit integers
    private func fetchQuestions() {
        let questionsRef = db.collection("questions")
        let shouldFetchGreater = Bool.random()
        let randomIndex = Int.random(in: 0...2)
        let fieldName = "random." + String(randomIndex)
        // 64 bit range
        let randomInt = Int.random(in: 0...9223372036854775807)
        var tries = 0
        
        // flow starts from switch at bottom
        func generateQuestions(_ querySnapshot: QuerySnapshot?, _ error: Error?) {
            if let error = error {
                print("Error fetching questions: \(error)")
            } else {
                let documents = querySnapshot!.documents.shuffled()
                for document in documents {
                    if let question = Question(data: document.data()) {
                        self.questions.append(question)
                    }
                    if self.questions.count == numberOfQuestions {
                        self.showNextQuestion()
                        return
                    }
                }
                
                // less than numberOfQuestions recieved
                // edge case and should be rare
                // if it happens, fetch again once in other direction for remaining questions
                let remaining = numberOfQuestions - questions.count
                tries += 1
                if tries < 2 {
                    fetch(greater: !shouldFetchGreater, amount: remaining)
                } else {
                    print("Warning: missing \(remaining) questions after two passes")
                    presentingViewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
        
        func fetch(greater: Bool, amount: Int) {
            switch greater {
            case true:
                questionsRef.whereField(fieldName, isGreaterThanOrEqualTo: randomInt)
                    .order(by: fieldName)
                    .limit(to: amount)
                    .getDocuments() { querySnapshot, error in
                        generateQuestions(querySnapshot, error)
                }
            case false:
                questionsRef.whereField(fieldName, isLessThan: randomInt)
                    .order(by: fieldName, descending: true)
                    .limit(to: amount)
                    .getDocuments() { querySnapshot, error in
                        generateQuestions(querySnapshot, error)
                }
            }
        }
        
        // starts here because nested functions need to be declared before
        switch shouldFetchGreater {
        case true:
            fetch(greater: true, amount: numberOfQuestions)
        case false:
            fetch(greater: false, amount: numberOfQuestions)
        }
    }

    private func showNextQuestion() {
        if questions.isEmpty {
            if correctAnswersCount == numberOfQuestions {
                updateLocationOwner()
            }
            presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            currentQuestion = questions.removeFirst()
            
            questionLabel.text = currentQuestion!.question
            let alternatives = ([currentQuestion!.answer] + currentQuestion!.alternatives).shuffled()
            for (i, alternative) in alternatives.enumerated() {
                self.answerButtons[i].setTitle(alternative, for: .normal)
            }
            
            resetButtons()
        }
    }
    
    private func resetButtons() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = UIColor.GeoCap.blue
        }
    }

    private func updateLocationOwner() {
        guard let locationName = locationName else {
            print("Error updating location owner: locationName is nil")
            return
        }
        guard let username = username else {
            print("Error updating location owner: username is nil")
            return
        }
        
        // TODO: Make this more general for several cities
        let locationRef = db.collection("cities").document("uppsala").collection("locations").document(locationName)
        locationRef.updateData([
            "owner": username
        ]) { err in
            if let err = err {
                print("Error updating location owner: \(err)")
            } else {
                print("Location owner successfully updated")
            }
        }

    }
    
}
