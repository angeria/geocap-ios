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
    
    // TODO: Make buttons empty while loading actual answers
    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach() {
                $0.titleLabel?.text = nil
                $0.layer.cornerRadius = 10
            }
        }
    }
    
    @IBOutlet weak var timer: UIProgressView! {
        didSet {
            timer.layer.cornerRadius = 5
            timer.clipsToBounds = true
            timer.layer.sublayers![1].cornerRadius = 5
            timer.subviews[1].clipsToBounds = true
        }
    }
    
    private lazy var db = Firestore.firestore()
    private lazy var functions = Functions.functions(region:"europe-west1")
    
    private var questions = [Question]()
    private var currentQuestion: Question?
    private var correctAnswersCount = 0
    private let numberOfQuestions = Constants.numberOfQuestions
    private var timerBarTimer: Timer?
    
    // Dependency injection
    var locationName: String!
    
    @IBOutlet weak var nextQuestionTapRecognizer: UITapGestureRecognizer!
    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        showNextQuestion()
        nextQuestionTapRecognizer.isEnabled = false
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
                updateLocationOwner()
            }
        } else {
            button.backgroundColor = UIColor.GeoCap.red
            button.shake()
            
            let correctAnswerButton = answerButtons.first() { $0.titleLabel?.text == currentQuestion?.answer }
            correctAnswerButton?.backgroundColor = UIColor.GeoCap.green
        }
        
        timerBarTimer?.invalidate()
        nextQuestionTapRecognizer.isEnabled = true
    }
    
    // Currently questions are recieved in random specific sets, effective since it's just one request
    // Could be changed to fetch one question at a time which is more random but generates more reads
    //
    // Every question in db has a 'random' object with randomly generated 64 bit integers
    private func fetchQuestions() {
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
        if questions.isEmpty {
            presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            currentQuestion = questions.removeFirst()
            
            questionLabel.text = currentQuestion!.question
            let alternatives = ([currentQuestion!.answer] + currentQuestion!.alternatives).shuffled()
            for (i, alternative) in alternatives.enumerated() {
                self.answerButtons[i].setTitle(alternative, for: .normal)
            }
            
            resetButtons()
            startTimer()
        }
    }
    
    private func startTimer() {
        timer.progress = 1
        timer.progressTintColor = UIColor.GeoCap.green
        
        timerBarTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            switch self.timer.progress {
            case ..<0:
                self.timerBarTimer?.invalidate()
            case ..<0.35:
                self.timer.progressTintColor = UIColor.GeoCap.red
                fallthrough
            default:
                self.timer.setProgress(self.timer.progress - 0.0005, animated: true)
            }
        }
    }
    
    private func resetButtons() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = UIColor.GeoCap.blue
        }
    }

    private func updateLocationOwner(isRetry: Bool = false) {
        functions.httpsCallable("locationCaptured").call(["location": locationName]) { (result, error) in
            if let error = error as NSError? {
                print("Error from called https function locationCaptured() in updateLocationOwner()")
                if error.domain == FunctionsErrorDomain {
                    let code = FunctionsErrorCode(rawValue: error.code)
                    if let code = code {
                        switch code {
                        case .internal:
                            if !isRetry {
                                self.updateLocationOwner(isRetry: true)
                            }
                        case .invalidArgument:
                            break
                        case .failedPrecondition:
                            break
                        default:
                            break
                        }
                    }
                    let message = error.localizedDescription
                    print("Message: \(message)")
                    if let details = error.userInfo[FunctionsErrorDetailsKey] {
                        print("Details: \(details)")
                    }
                }
                // ...
            }
        }
    }
    
}
