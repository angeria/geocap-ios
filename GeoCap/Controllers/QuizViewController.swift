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
import AVFoundation
import FirebaseRemoteConfig

extension QuizViewController {
    enum Constants {
        static let maxNumberOfRetries = 3
    }
}

class QuizViewController: UIViewController {

    private let dispatchGroup = DispatchGroup()

    private let numberOfQuestions = Int(truncating:
        RemoteConfig.remoteConfig()[GeoCapConstants.RemoteConfig.Keys.numberOfQuestions].numberValue!)

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(QuizViewController.willResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        dispatchGroup.enter()
        fetchTotalDatabaseQuestionCount()

        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.dispatchGroup.enter()
            self?.fetchQuestions()
        }
    }

    // Dismiss quiz immediately if view resigns active to prevent cheating
    @objc private func willResignActive() {
        quizLost = true
        countdownBarTimer?.invalidate()
        performSegue(withIdentifier: "unwindSegueQuizToMap", sender: self)
    }

    // MARK: - Fetching

    private var totalDatabaseQuestionCount: Int!

    private func fetchTotalDatabaseQuestionCount() {
        let db = Firestore.firestore()
        db.collection("quiz").document("data").getDocument { [weak self] documentSnapshot, error in
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
        guard amount > 0 else {
            self.dispatchGroup.leave()
            return
        }

        let db = Firestore.firestore()
        let randomIndex = getRandomIndex(within: totalDatabaseQuestionCount)

        db.collection("quiz").document("data").collection("questions")
            .whereField("index", isEqualTo: randomIndex)
            .getDocuments { [weak self] querySnapshot, error in
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
                    let error = NSError(domain: geoCapErrorDomain,
                                        code: GeoCapErrorCode.quizLoadFailed.rawValue,
                                        userInfo: [
                        NSLocalizedDescriptionKey: "Couldn't load quiz",
                        NSDebugDescriptionErrorKey: "Couldn't get questions after several retries with different indices", // swiftlint:disable:this line_length
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

    private var currentQuestionNumber = 0 {
        didSet {
            questionCountLabel.text = "\(currentQuestionNumber)/\(numberOfQuestions)"
        }
    }

    @IBOutlet weak var questionCountLabel: UILabel!

    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach {
                $0.layer.cornerRadius = GeoCapConstants.defaultCornerRadius
                if traitCollection.userInterfaceStyle == .dark {
                    $0.alpha = 1
                }
            }
        }
    }

    private var currentQuestion: Question?

    // PRECONDITION: questions.count > 0
    private func showNextQuestion() {
        currentQuestion = questions.removeFirst()
        currentQuestionNumber += 1

        questionLabel.text = currentQuestion!.question
        let alternatives = ([currentQuestion!.answer] + currentQuestion!.alternatives).shuffled()
        for (i, alternative) in alternatives.enumerated() {
            self.answerButtons[i].setTitle(alternative, for: .normal)
        }

        resetButtons()
        startTimer()
    }

    // Checked in the map vc after the quiz is dismissed
    var quizWon = false

    private var quizLost = false
    private var correctAnswers = 0

    @IBOutlet weak var nextQuestionTapRecognizer: UITapGestureRecognizer!

    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        sender.isEnabled = false

        if quizLost || quizWon {
            performSegue(withIdentifier: "unwindSegueQuizToMap", sender: self)
        } else {
            // Dispatch group prevents trying to show next question before it has loaded
            dispatchGroup.notify(queue: .main) { [weak self] in
                self?.showNextQuestion()
            }
        }
    }

    let feedbackGenerator = UINotificationFeedbackGenerator()

    @IBAction func answerPressed(_ button: UIButton) {
        answerButtons.forEach { $0.isEnabled = false }

        if button.titleLabel?.text == currentQuestion?.answer {
            button.backgroundColor = .systemGreen
            button.scale()
            feedbackGenerator.notificationOccurred(.success)

            correctAnswers += 1
            if correctAnswers == numberOfQuestions {
                quizWon = true
            // Prefetch question only if there's more than one left
            } else if correctAnswers < numberOfQuestions - 1 {
                dispatchGroup.enter()
                fetchQuestions(amount: 1)
            }
        } else {
            button.backgroundColor = .systemRed
            button.shake()

            let correctAnswerButton = answerButtons.first { $0.titleLabel?.text == currentQuestion?.answer }
            correctAnswerButton?.backgroundColor = .systemGreen

            quizLost = true
        }

        countdownBarTimer?.invalidate()
        nextQuestionTapRecognizer.isEnabled = true
    }

    private func resetButtons() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = .systemBlue
        }
    }

    // MARK: - Timer

    @IBOutlet weak var countdownBarHeightConstraint: NSLayoutConstraint! {
        didSet {
            countdownBar.layer.cornerRadius = countdownBarHeightConstraint.constant / 2
            countdownBar.clipsToBounds = true
            countdownBar.layer.sublayers?[1].cornerRadius = countdownBarHeightConstraint.constant / 2
            countdownBar.subviews[1].clipsToBounds = true
            if traitCollection.userInterfaceStyle == .dark {
                countdownBar.alpha = 1
            }
        }
    }

    @IBOutlet weak var countdownBar: UIProgressView!

    private var shortnessOfTimeModeNotActivated = true
    private var countdownBarTimer: Timer?
    private func startTimer() {
        countdownBar.progress = 1
        countdownBar.progressTintColor = .systemGreen

        countdownBarTimer = Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            switch self.countdownBar.progress {
            case ...0:
                self.countdownBar.shake()
                self.answerButtons.forEach { $0.isEnabled = false }
                self.countdownBarTimer?.invalidate()
                Timer.scheduledTimer(withTimeInterval: GeoCapConstants.shakeAnimationDuration + 0.1, repeats: false) { _ in // swiftlint:disable:this line_length
                    self.quizLost = true
                    self.performSegue(withIdentifier: "unwindSegueQuizToMap", sender: self)
                }
            case 0.29...0.30:
                if self.shortnessOfTimeModeNotActivated {
                    self.shortnessOfTimeModeNotActivated = false
                    SoundManager.shared.playSound(withName: SoundManager.Sounds.quizTimerAlert)
                    self.countdownBar.progressTintColor = .systemRed
                }
                fallthrough
            default:
                self.countdownBar.setProgress(self.countdownBar.progress - 0.001, animated: false)
            }
        }
    }

}
