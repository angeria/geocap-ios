//
//  QuizViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-27.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
//import FirebaseAuth
import os.log
import AVFoundation
//import FirebaseRemoteConfig
import SwiftEntryKit

extension QuizViewController {
    enum Constants {
        static let maxNumberOfRetries = 3
        static let timerBarHeight: CGFloat = 15
    }
}

class QuizViewController: UIViewController {

    private let dispatchGroup = DispatchGroup()

    private let numberOfQuestions = Int(truncating: RemoteConfig.remoteConfig()[GeoCapConstants.RemoteConfig.Keys.numberOfQuestions].numberValue!)
    private let quizTime = Double(truncating: RemoteConfig.remoteConfig()[GeoCapConstants.RemoteConfig.Keys.quizTime].numberValue!)

    // MARK: - Life Cycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        drawTimerBar()
    }

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
        SwiftEntryKit.dismiss() // Dismiss "Tap anywhere to continue"-note, if visible
        quizLost = true
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
        startTimerBar()
    }

    // Checked in the map vc after the quiz is dismissed
    var quizWon = false

    private var quizLost = false
    private var correctAnswers = 0

    @IBOutlet weak var nextQuestionTapRecognizer: UITapGestureRecognizer!

    @IBAction func tap(_ sender: UITapGestureRecognizer) {
        SwiftEntryKit.dismiss() // Dismiss "Tap anywhere to continue"-note, if visible

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

        stopCountdownBar()
        timer?.invalidate()
        soundTimer?.invalidate()
        nextQuestionTapRecognizer.isEnabled = true

        let noteDisplayCount = UserDefaults.standard.integer(forKey: GeoCapConstants.UserDefaultsKeys.tapToContinueNoteDisplayCount)
        if noteDisplayCount < 3 {
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.presentTapToContinueNote()
                UserDefaults.standard.set(noteDisplayCount + 1, forKey: GeoCapConstants.UserDefaultsKeys.tapToContinueNoteDisplayCount)
            }
        }
    }

    private func presentTapToContinueNote() {
        var attributes = EKAttributes.topNote
        attributes.displayMode = EKAttributes.DisplayMode.inferred
        attributes.entryBackground = .color(color: EKColor(.systemBlue))
        attributes.shadow = .active(
            with: .init(
                color: .black,
                opacity: 0.3,
                radius: 10,
                offset: .zero
            )
        )
        attributes.displayDuration = .infinity

        let text = NSLocalizedString("quiz-tap-to-continue-note",
                                     comment: "Text on 'Tap to continue'-note in quiz")
        let style = EKProperty.LabelStyle(
            font: .preferredFont(forTextStyle: .subheadline),
            color: .white,
            alignment: .center
        )
        let labelContent = EKProperty.LabelContent(
            text: text,
            style: style
        )
        let contentView = EKNoteMessageView(with: labelContent)
        SwiftEntryKit.display(entry: contentView, using: attributes)
    }

    private func resetButtons() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = .systemBlue
        }
    }

    // MARK: - Timer

    private var timer: Timer?
    private var soundTimer: Timer?
    private var timerBar = CAShapeLayer()
    private let timerBarBackground = CAShapeLayer()
    private var strokeAnimation: CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = 0
        animation.duration = quizTime
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }
    private var colorAnimation: CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "strokeColor")
        animation.toValue = UIColor.systemRed.cgColor
        animation.duration = quizTime
        return animation
    }

    private func drawTimerBar() {
        guard let path = getTimerBarPath() else { return }

        timerBar.removeFromSuperlayer()
        timerBarBackground.removeFromSuperlayer()

        timerBarBackground.path = path.cgPath
        timerBarBackground.strokeColor = UIColor.systemGray5.cgColor
        timerBarBackground.lineWidth = Constants.timerBarHeight
        // Timer bar doesn't disappear completely when using round cap
        // timerBarBackground.lineCap = .round
        timerBarBackground.strokeEnd = 1
        view.layer.addSublayer(timerBarBackground)

        timerBar = CAShapeLayer()
        timerBar.path = path.cgPath
        timerBar.strokeColor = UIColor.systemGreen.cgColor
        timerBar.lineWidth = Constants.timerBarHeight
        // timerBar.lineCap = .round
        timerBar.strokeEnd = 1
        view.layer.addSublayer(timerBar)
    }

    private func startTimerBar() {
        timerBar.removeAllAnimations()

        drawTimerBar()

        timerBar.add(strokeAnimation, forKey: nil)
        timerBar.add(colorAnimation, forKey: nil)

        timer = Timer.scheduledTimer(withTimeInterval: quizTime, repeats: false) { [weak self] _ in
            self?.timeDidRunOut()
        }

        soundTimer = Timer.scheduledTimer(withTimeInterval: quizTime * 0.70, repeats: false) { [weak self] _ in
            guard self?.isViewLoaded == true else { return }
            SoundManager.shared.playSound(withName: SoundManager.Sounds.quizTimerAlert)
        }
    }

    private func timeDidRunOut() {
        answerButtons.forEach { $0.isEnabled = false }
        quizLost = true
        performSegue(withIdentifier: "unwindSegueQuizToMap", sender: self)
    }

    private func getTimerBarPath() -> UIBezierPath? {
        guard let answerButtonsBottom = answerButtons.first?.superview?.frame.maxY else { return nil }
        let y = ((view.frame.maxY - answerButtonsBottom) / 2) + Constants.timerBarHeight / 2
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 35, y: view.frame.maxY - y))
        path.addLine(to: CGPoint(x: view.frame.maxX - 35, y: view.frame.maxY - y))
        return path
    }

    private func stopCountdownBar() {
        if let countdownBar = view.layer.sublayers?.first(where: { $0 === timerBar }) {
            let pausedTime = countdownBar.convertTime(CACurrentMediaTime(), from: nil)
            countdownBar.speed = 0.0
            countdownBar.timeOffset = pausedTime
        }
    }

}
