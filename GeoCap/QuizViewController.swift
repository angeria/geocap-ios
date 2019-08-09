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
    
    // TODO: Make more random; currently questions are often in same sets.
    // FIXME: Prevent infinite loop
    // FIXME: Fix edge case of getting < 3 questions
    private func fetchQuestions() {
        let questionsRef = db.collection("questions")
        let randomBool = Bool.random()
        let randomIndex = Int.random(in: 0...2)
        let fieldName = "random." + String(randomIndex)
        let randomInt = Int.random(in: 0...9223372036854775807)
        
        func generateQuestions(_ querySnapshot: QuerySnapshot?) {
            let documents = querySnapshot!.documents.shuffled()
            for document in documents {
                if let question = Question(data: document.data()) {
                    self.questions.append(question)
                }
                if self.questions.count == 3 {
                    self.showNextQuestion()
                    break
                }
            }
        }
        
        func fetchGreater() {
            questionsRef.whereField(fieldName, isGreaterThanOrEqualTo: randomInt)
                .order(by: fieldName)
                .limit(to: 3)
                .getDocuments() { querySnapshot, error in
                if let error = error {
                    print("Error fetching questions: \(error)")
                } else if querySnapshot?.count == 3 {
                    generateQuestions(querySnapshot)
                } else {
                    fetchSmaller()
                }
            }
        }
        
        func fetchSmaller() {
            questionsRef.whereField(fieldName, isLessThanOrEqualTo: randomInt)
                .order(by: fieldName, descending: true)
                .limit(to: 3)
                .getDocuments() { querySnapshot, error in
                if let error = error {
                    print("Error fetching questions: \(error)")
                } else if querySnapshot?.count == 3 {
                    generateQuestions(querySnapshot)
                } else {
                    fetchGreater()
                }
            }
        }
        
        switch randomBool {
        case true:
            fetchGreater()
        case false:
            fetchSmaller()
        }
    }
        
//    db.collection("questions").getDocuments() { [weak self] (querySnapshot, error) in
//        if let error = error {
//            print("Error getting questions: \(error)")
//        } else {
//            guard let self = self else { return }
//
//            let documents = querySnapshot!.documents.shuffled()
//            for document in documents {
//                if let question = Question(data: document.data()) {
//                    self.questions.append(question)
//                }
//                if self.questions.count == 3 {
//                    self.showNextQuestion()
//                    break
//                }
//            }
//        }
//    }

    private func showNextQuestion() {
        if questions.isEmpty {
            if correctAnswersCount == 3 {
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
