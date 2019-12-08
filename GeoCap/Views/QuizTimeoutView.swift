//
//  QuizTimeoutView.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-12-07.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit

class QuizTimeoutView: UIView {

    let circle = CAShapeLayer()

    func stopTimer() {
        circle.removeAllAnimations()
        circle.removeFromSuperlayer()
        isHidden = true
    }

    func startTimer() {
        isHidden = false

        let path = UIBezierPath(arcCenter: CGPoint(x: bounds.maxX / 2, y: bounds.maxY / 2), radius: bounds.maxX * 0.4, startAngle: -CGFloat.pi / 2, endAngle: 3 * CGFloat.pi / 2, clockwise: true)

        circle.path = path.cgPath
        circle.strokeColor = UIColor.systemRed.cgColor
        circle.fillColor = UIColor.clear.cgColor
        circle.lineWidth = 6
        circle.lineCap = .round
        circle.strokeEnd = 0
        layer.addSublayer(circle)

        let strokeAnimation = CABasicAnimation(keyPath: "strokeEnd")
        strokeAnimation.toValue = 1
        strokeAnimation.duration = GeoCapConstants.quizTimeoutInterval
        strokeAnimation.fillMode = .forwards
        strokeAnimation.isRemovedOnCompletion = false
        circle.add(strokeAnimation, forKey: nil)

        let colorAnimation = CABasicAnimation(keyPath: "strokeColor")
        colorAnimation.toValue = UIColor.systemGreen.cgColor
        colorAnimation.duration = GeoCapConstants.quizTimeoutInterval
        colorAnimation.fillMode = .forwards
        colorAnimation.isRemovedOnCompletion = false
        circle.add(colorAnimation, forKey: nil)
    }

//    override func draw(_ rect: CGRect) {
//        layer.cornerRadius = GeoCapConstants.defaultCornerRadius
//        layer.masksToBounds = true
//    }
}
