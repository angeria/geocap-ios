//
//  QuizViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-27.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import AVFoundation

class QuizViewController: UIViewController {
    
    // TODO: Fonts
    
    private lazy var db = Firestore.firestore()
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var questionLabel: UILabel!
    @IBOutlet weak var nextQuestionButton: UIButton! {
        didSet {
            nextQuestionButton.layer.cornerRadius = 15
        }
    }
    @IBOutlet var answerButtons: [UIButton]! {
        didSet {
            answerButtons.forEach() { $0.layer.cornerRadius = 15 }
        }
    }
    
    var quizzes = [Quiz]()
    var currentQuiz: Quiz!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchQuiz()
    }
    
    @IBAction func answerPressed(_ sender: UIButton) {
        answerButtons.forEach() { $0.isEnabled = false }
        nextQuestionButton.isHidden = false
        
        if sender.titleLabel?.text == currentQuiz.answer {
            sender.backgroundColor = UIColor.Custom.systemGreen
            AudioServicesPlaySystemSound(1016)
        } else {
            sender.backgroundColor = UIColor.Custom.systemRed
            AudioServicesPlaySystemSound (1016)
        }
    }
    
    @IBAction func nextQuestionPressed(_ sender: UIButton) {
        showNextQuiz()
        nextQuestionButton.isHidden = true
    }
    
    private func fetchQuiz() {
        // TODO: (DODGE) Probably not fetch all questions
        db.collection("cities").document("uppsala").collection("questions").getDocuments { [weak self] (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
            } else {
                guard let self = self else { return }
                
                let documents = querySnapshot!.documents.shuffled()
                for document in documents {
                    if let quiz = Quiz(data: document.data()) { self.quizzes.append(quiz) }
                    if self.quizzes.count == 3 {
                        self.showNextQuiz()
                        break
                    }
                }
            }
        }
    }
    
    private func resetView() {
        for button in answerButtons {
            button.isEnabled = true
            button.backgroundColor = UIColor.Custom.systemBlue
        }
    }
    
    private func showNextQuiz() {
        resetView()
        
        if quizzes.isEmpty {
            presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            currentQuiz = quizzes.removeFirst()
            self.titleLabel.text = currentQuiz.title
            self.questionLabel.text = currentQuiz.question
            let choices = ([currentQuiz.answer] + currentQuiz.choices).shuffled()
            for (i, choice) in choices.enumerated() {
                self.answerButtons[i].setTitle(choice, for: .normal)
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
