//
//  AttackTableViewCell.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-12-17.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit

class AttackTableViewCell: UITableViewCell {

    @IBOutlet weak var locationName: UILabel!
    @IBOutlet weak var attackerName: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var bitmoji: UIImageView!

    var defendButtonCallback: (() -> Void)?

    @IBAction func defendButtonPressed(_ sender: UIButton) {
        defendButtonCallback?()
    }

}
