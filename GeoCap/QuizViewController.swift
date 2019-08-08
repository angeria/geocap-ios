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
    
    private func fetchQuestions() {
        // TODO: Get three random questions instead of all
        db.collection("questions").getDocuments() { [weak self] (querySnapshot, error) in
            if let error = error {
                print("Error getting questions: \(error)")
            } else {
                guard let self = self else { return }
                
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
        }
    }
    
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
