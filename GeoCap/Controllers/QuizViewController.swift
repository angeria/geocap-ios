//
//  QuizViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-27.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import os.log

extension QuizViewController {
    enum Constants {
        static let numberOfQuestions = 3
        static let maxNumberOfRetries = 3
    }
}

class QuizViewController: UIViewController {

    private let dispatchGroup = DispatchGroup()
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(QuizViewController.willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
        dispatchGroup.enter()
        fetchTotalDatabaseQuestionCount()
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.dispatchGroup.enter()
            self?.fetchQuestions()
        }
    }
    
    @objc private func willResignActive() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Fetching

    private var totalDatabaseQuestionCount: Int?
    
    private func fetchTotalDatabaseQuestionCount() {
        let db = Firestore.firestore()
        db.collection("quiz").document("data").getDocument() { [weak self] documentSnapshot, error in
            guard let document = documentSnapshot else {
                os_log("%{public}@", log: OSLog.Quiz, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                self?.presentingViewController?.dismiss(animated: true)
                return
            }
            
            if let questionsCount = document.get("questionsCount") as? Int {
                self?.totalDatabaseQuestionCount = questionsCount
                self?.dispatchGroup.leave()
            } else {
                os_log("Couldn't get 'questionsCount'", log: OSLog.Quiz, type: .debug)
                self?.presentingViewController?.dismiss(animated: true)
            }
        }
    }
    
    private var questions = [Question]()
    
    private func fetchQuestions(amount: Int = 2, retryCount: Int = 0) {
        guard let totalDatabaseQuestionCount = totalDatabaseQuestionCount else { return }
        
        guard amount > 0 else {
            self.dispatchGroup.leave()
            return
        }
        
        let db = Firestore.firestore()
        let randomIndex = getRandomIndex(within: totalDatabaseQuestionCount)
        
        db.collection("quiz").document("data").collection("questions").whereField("index", isEqualTo: randomIndex).getDocuments() { [weak self] querySnapshot, error in
            guard let query = querySnapshot else {
                os_log("%{public}@", log: OSLog.Quiz, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                self?.presentingViewController?.dismiss(animated: true)
                return
            }
            
            guard let self = self else { return }
            
            Crashlytics.sharedInstance().setIntValue(Int32(randomIndex), forKey: "randomQuestionIndex")
            if let document = query.documents.first, let question = Question(data: document.data()) {
                self.questions += [question]
                if self.currentQuestion == nil {
                    self.showNextQuestion()
                }
                self.fetchQuestions(amount: amount - 1, retryCount: retryCount)
            } else {
                os_log("Couldn't find a question with index '%d'", log: OSLog.Quiz, type: .default, randomIndex)
                if retryCount < Constants.maxNumberOfRetries {
                    os_log("Retrying with another index...", log: OSLog.Quiz, type: .default)
                    self.fetchQuestions(amount: amount, retryCount: retryCount + 1)
                } else {
                    os_log("Retries exhausted: exiting back to map", log: OSLog.Quiz, type: .default)
                    let error = NSError(domain: GeoCapErrorDomain, code: GeoCapErrorCode.quizLoadFailed.rawValue, userInfo: [
                        NSLocalizedDescriptionKey: "Couldn't load quiz",
                        NSDebugDescriptionErrorKey: "Couldn't get questions after several retries with different indices",
                        "triedIndices": String(describing: self.usedIndices),
                        "numberOfRetries": String(Constants.maxNumberOfRetries)
                    ])
                    os_log("%{public}@", log: OSLog.Quiz, type: .debug, error)
                    Crashlytics.sharedInstance().recordError(error)
                    self.presentingViewController?.dismiss(animated: true)
                }
            }
        }
    }
    
    private var usedIndices = [Int]()
    
    private func getRandomIndex(within limit: Int) -> Int {
        var randomIndex: Int
        repeat {
            randomIndex = Int.random(in: 0..<limit)
        } while usedIndices.contains(randomIndex)
        usedIndices += [randomIndex]
        return randomIndex
    }
    
    // MARK: - Interaction
    
    @IBOutlet weak var questionLabel: UILabel! {
        didSet {
            questionLabel.text = nil
        }
    }
    
    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach() {
                $0.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
            }
        }
    }

    private var currentQuestion: Question?
    
    // PRECONDITION: questions.count > 0
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
    
    // Checked in the map view via the unwind segue
    var quizFailed = false
    private var correctAnswers = 0
    
    @IBOutlet weak var nextQuestionTapRecognizer: UITapGestureRecognizer!
    
    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        sender.isEnabled = false
        
        if quizFailed || correctAnswers == Constants.numberOfQuestions {
            performSegue(withIdentifier: "unwindSegueQuizToMap", sender: self)
        } else {
            // Dispatch group prevents trying to show next question before it has loaded
            dispatchGroup.notify(queue: .main) { [weak self] in
                self?.showNextQuestion()
            }
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
            // Prefetch question only if there's more than one left
            } else if correctAnswers < Constants.numberOfQuestions - 1 {
                dispatchGroup.enter()
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
    var cityReference: DocumentReference!
    
    private func captureLocation() {
        guard let user = Auth.auth().currentUser, let username = user.displayName else { return }
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        cityReference.collection("locations").whereField("name", isEqualTo: locationName!).getDocuments() { [weak self] querySnapshot, error in
            guard let query = querySnapshot else {
                os_log("%{public}@", log: OSLog.Quiz, type: .debug, error! as NSError)
                Crashlytics.sharedInstance().recordError(error!)
                return
            }
            guard let self = self else { return }
            
            if let document = query.documents.first {
                let locationReference = document.reference
                batch.updateData(["owner": username, "ownerId": user.uid], forDocument: locationReference)
                
                let userReference = db.collection("users").document(user.uid)
                batch.updateData(["capturedLocations": FieldValue.arrayUnion([self.locationName!]), "capturedLocationsCount": FieldValue.increment(Int64(1))], forDocument: userReference)
                
                batch.commit() { err in
                    if let error = error {
                        os_log("%{public}@", log: OSLog.Quiz, type: .debug, error as NSError)
                        Crashlytics.sharedInstance().recordError(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Timer
    
    @IBOutlet weak var countdownBar: UIProgressView! {
        didSet {
            countdownBar.layer.cornerRadius = 5
            countdownBar.clipsToBounds = true
            // Uncomment to make the inner bar rounded too
            // countdownBar.layer.sublayers?[1].cornerRadius = 5
            // countdownBar.subviews[1].clipsToBounds = true
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
                Timer.scheduledTimer(withTimeInterval: GeoCapConstants.shakeAnimationDuration + 0.1, repeats: false) { _ in
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
