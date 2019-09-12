//
//  QuizViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-27.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase

extension QuizViewController {
    enum Constants {
        static let numberOfQuestions = 3
        static let maxNumberOfRetries = 3
    }
}

class QuizViewController: UIViewController {
    
    @IBOutlet weak var questionLabel: UILabel!
    
    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach() {
                $0.layer.cornerRadius = 10
            }
        }
    }
    
    private var correctAnswers = 0
    private var currentQuestion: Question?
    private var nextQuestion: Question?
    private var questions = [Question]()
    private var usedIndices = [Int]()
    
    // Checked in the map view via the unwind segue
    var quizFailed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchQuestions()
    }
    
    // MARK: - Fetching
    
    private func fetchQuestions(amount: Int = 2, retryCount: Int = 0) {
        guard amount > 0 else { return }
        
        let db = Firestore.firestore()
        db.collection("quiz").document("data").getDocument() { [weak self] documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching 'quiz/data' document: \(String(describing: error))")
                return
            }
            guard let self = self else { return }
            
            if let questionsCount = document.get("questionsCount") as? Int {
                let randomIndex = self.getRandomIndex(within: questionsCount)
                db.collection("quiz").document("data").collection("questions").whereField("index", isEqualTo: randomIndex).getDocuments() { querySnapshot, error in
                    guard let query = querySnapshot else {
                        print("Error fetching question: \(String(describing: error))")
                        self.presentingViewController?.dismiss(animated: true)
                        return
                    }
                    
                    if let document = query.documents.first, let question = Question(data: document.data()) {
                        self.questions += [question]
                        if self.currentQuestion == nil {
                            self.showNextQuestion()
                        }
                        self.fetchQuestions(amount: amount - 1, retryCount: retryCount)
                    } else {
                        print("Couldn't find a question with index '\(randomIndex)'")
                        if retryCount < Constants.maxNumberOfRetries {
                            print("Retrying with another index...")
                            self.fetchQuestions(amount: amount, retryCount: retryCount + 1)
                        } else {
                            print("Retries exhausted: exiting back to map")
                            self.presentingViewController?.dismiss(animated: true)
                        }
                        return
                    }
                }
            }
        }
    }
    
    private func getRandomIndex(within limit: Int) -> Int {
        var randomIndex: Int
        repeat {
            randomIndex = Int.random(in: 0..<limit)
        } while usedIndices.contains(randomIndex)
        usedIndices += [randomIndex]
        return randomIndex
    }
    
    // MARK: - Interaction
    
    private func showNextQuestion() {
        guard questions.count > 0 else { return }
        currentQuestion = questions.removeFirst()
        
        questionLabel.text = currentQuestion!.question
        let alternatives = ([currentQuestion!.answer] + currentQuestion!.alternatives).shuffled()
        for (i, alternative) in alternatives.enumerated() {
            self.answerButtons[i].setTitle(alternative, for: .normal)
        }
        
        resetButtons()
        startTimer()
    }
    
    @IBOutlet weak var nextQuestionTapRecognizer: UITapGestureRecognizer!
    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        if quizFailed || correctAnswers == Constants.numberOfQuestions {
            performSegue(withIdentifier: "unwindSegueQuizToMap", sender: self)
        } else {
            nextQuestionTapRecognizer.isEnabled = false
            showNextQuestion()
        }
    }
    
    @IBAction func answerPressed(_ button: UIButton) {
        answerButtons.forEach() { $0.isEnabled = false }
        
        if button.titleLabel?.text == currentQuestion?.answer {
            button.backgroundColor = UIColor.GeoCap.green
            button.scale()
            correctAnswers += 1
            if correctAnswers == Constants.numberOfQuestions {
                captureLocation()
            } else {
                // Prefetching next question while user is on current question
                fetchQuestions(amount: 1)
            }
        } else {
            button.backgroundColor = UIColor.GeoCap.red
            button.shake()
            
            let correctAnswerButton = answerButtons.first() { $0.titleLabel?.text == currentQuestion?.answer }
            correctAnswerButton?.backgroundColor = UIColor.GeoCap.green
            
            quizFailed = true
        }
        
        countdownBarTimer?.invalidate()
        nextQuestionTapRecognizer.isEnabled = true
    }
    
    private func resetButtons() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = UIColor.GeoCap.blue
        }
    }

    // MARK: - Capturing
    
    // Dependency injection
    var locationName: String!
    
    private func captureLocation() {
        guard let user = Auth.auth().currentUser, let username = user.displayName else { return }
        guard let locationName = locationName else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        let locationReference = db.collection("cities").document("uppsala").collection("locations").document(locationName)
        batch.updateData(["owner": username, "ownerId": user.uid], forDocument: locationReference)
        
        let userReference = db.collection("users").document(user.uid)
        batch.updateData(["capturedLocations": FieldValue.arrayUnion([locationName]), "capturedLocationsCount": FieldValue.increment(Int64(1))], forDocument: userReference)
        
        batch.commit() { err in
            if let err = err {
                print("Error writing batch: \(err)")
            }
        }
    }
    
    // MARK: - Timer
    
    @IBOutlet weak var countdownBar: UIProgressView! {
        didSet {
            countdownBar.layer.cornerRadius = 5
            countdownBar.clipsToBounds = true
            countdownBar.layer.sublayers![1].cornerRadius = 5
            countdownBar.subviews[1].clipsToBounds = true
        }
    }
    
    private var countdownBarTimer: Timer?
    private func startTimer() {
        countdownBar.progress = 1
        countdownBar.progressTintColor = UIColor.GeoCap.green
        
        countdownBarTimer = Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            switch self.countdownBar.progress {
            case ...0:
                self.countdownBar.shake()
                self.answerButtons.forEach() { $0.isEnabled = false }
                self.countdownBarTimer?.invalidate()
                Timer.scheduledTimer(withTimeInterval: GeoCap.Constants.shakeAnimationDuration + 0.1, repeats: false) { _ in
                    self.presentingViewController?.dismiss(animated: true, completion: nil)
                }
            case 0.29...0.30:
                self.countdownBar.progressTintColor = UIColor.GeoCap.red
                fallthrough
            default:
                self.countdownBar.setProgress(self.countdownBar.progress - 0.001, animated: false)
            }
        }
    }
    
}
