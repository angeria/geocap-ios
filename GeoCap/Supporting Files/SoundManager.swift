//
//  SoundManager.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-10-17.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class SoundManager {
    
    static let shared = SoundManager()
    
    enum Sounds {
        static let quizWon = "quiz-won"
        static let buttonPressed = "button-pressed"
    }
    
    private init() {
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.ambient)
    }
    
    private var audioPlayer: AVAudioPlayer?
    
    func playSound(withName soundName: String) {
        guard !AVAudioSession.sharedInstance().isOtherAudioPlaying else { return }

        let sound = NSDataAsset(name: soundName)!
        audioPlayer = try! AVAudioPlayer(data: sound.data)
        audioPlayer!.play()
    }
    
}
