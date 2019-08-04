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
    
    @IBOutlet weak var titleLabel: UILabel! {
        didSet {
            titleLabel.text = nil
        }
    }
    @IBOutlet weak var questionLabel: UILabel! {
        didSet {
            questionLabel.text = nil
        }
    }
    @IBOutlet weak var nextQuestionButton: UIButton! {
        didSet {
            nextQuestionButton.layer.cornerRadius = 10
        }
    }
    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach() {
                $0.titleLabel?.text = nil
                $0.layer.cornerRadius = 10
            }
        }
    }
    
    private lazy var db = Firestore.firestore()
    private var auth = Auth.auth()
    private var authListener: AuthStateDidChangeListenerHandle?
    
    private var questions = [Question]()
    private var currentQuestion: Question?
    private var correctAnswersCount = 0
    var locationName: String?
    private var username: String?
    
    override func viewDidLoad() {
        authListener = auth.addStateDidChangeListener { [weak self] (auth, user) in
            if let user = user {
                self?.username = user.displayName
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchQuestions()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if let handle = authListener {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    @IBAction func answerPressed(_ sender: UIButton) {
        answerButtons.forEach() { $0.isEnabled = false }
        nextQuestionButton.isHidden = false
        
        if sender.titleLabel?.text == currentQuestion?.answer {
            sender.backgroundColor = UIColor.Custom.systemGreen
            correctAnswersCount += 1
        } else {
            sender.backgroundColor = UIColor.Custom.systemRed
        }
    }
    
    @IBAction func nextQuestionPressed(_ sender: UIButton) {
        showNextQuestion()
        nextQuestionButton.isHidden = true
    }
    
    private func fetchQuestions() {
        // TODO: (DODGE) Probably not fetch all questions
        db.collection("cities").document("uppsala").collection("questions").getDocuments { [weak self] (querySnapshot, error) in
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
            
            titleLabel.text = currentQuestion!.title
            questionLabel.text = currentQuestion!.question
            let choices = ([currentQuestion!.answer] + currentQuestion!.choices).shuffled()
            for (i, choice) in choices.enumerated() {
                self.answerButtons[i].setTitle(choice, for: .normal)
            }
            
            resetButtons()
        }
    }
    
    private func resetButtons() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = UIColor.Custom.systemBlue
        }
    }

    private func updateLocationOwner() {
        guard let locationName = locationName else {
            print("Error updating location owner: locationName is nil")
            return
        }
        guard let username = username else {
            print("Error updating location owner: no user is logged in")
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
