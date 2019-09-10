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
        static let largest64BitNumber = 9223372036854775807
        static let maximalNumberOfQuestionFetchTries = 1
        static let locationRandomArrayCount = 3
        static let numberOfQuestions = 3
    }
}

class QuizViewController: UIViewController {
    
    @IBOutlet weak var questionLabel: UILabel! {
        didSet {
            questionLabel.text = nil
        }
    }
    
    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach() {
                $0.layer.cornerRadius = 10
            }
        }
    }
    
    private var questions = [Question]()
    private var currentQuestion: Question?
    private var correctAnswersCount = 0
    private let numberOfQuestions = Constants.numberOfQuestions
    private var quizFailed = false
    // Checked in the map view via the unwind segue
    var locationWasCaptured = false
    
    // Dependency injection
    var locationName: String!
    
    @IBOutlet weak var nextQuestionTapRecognizer: UITapGestureRecognizer!
    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        if quizFailed || questions.isEmpty {
            performSegue(withIdentifier: "unwindSegueQuizToMap", sender: self)
        } else {
            showNextQuestion()
            nextQuestionTapRecognizer.isEnabled = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchQuestions()
    }
    
    @IBAction func answerPressed(_ button: UIButton) {
        answerButtons.forEach() { $0.isEnabled = false }
        
        if button.titleLabel?.text == currentQuestion?.answer {
            button.backgroundColor = UIColor.GeoCap.green
            button.scale()
            correctAnswersCount += 1
            if correctAnswersCount == numberOfQuestions {
                locationWasCaptured = true
                captureLocation()
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
    
    // Currently questions are recieved in random specific sets, effective since it's just one request
    // Could be changed to fetch one question at a time which is more random but generates more reads
    //
    // Every question in db has a 'random' object with randomly generated 64 bit integers
    private func fetchQuestions() {
        let db = Firestore.firestore()
        let questionsRef = db.collection("questions")
        let shouldFetchGreater = Bool.random()
        let randomIndex = Int.random(in: 0..<Constants.locationRandomArrayCount)
        let fieldName = "random." + String(randomIndex)
        let randomInt = Int.random(in: 0...Constants.largest64BitNumber)
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
                if tries <= Constants.maximalNumberOfQuestionFetchTries {
                    fetch(greater: !shouldFetchGreater, amount: remaining)
                } else {
                    print("Warning: missing \(remaining) questions after \(Constants.maximalNumberOfQuestionFetchTries) passes")
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
        currentQuestion = questions.removeFirst()
        
        questionLabel.text = currentQuestion!.question
        let alternatives = ([currentQuestion!.answer] + currentQuestion!.alternatives).shuffled()
        for (i, alternative) in alternatives.enumerated() {
            self.answerButtons[i].setTitle(alternative, for: .normal)
        }
        
        resetButtons()
        startTimer()
    }
    
    private func resetButtons() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = UIColor.GeoCap.blue
        }
    }

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
                print("Error writing batch \(err)")
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
