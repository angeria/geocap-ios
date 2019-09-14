//
//  chooseCityPopover.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-09-14.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation

class ChooseCityPopoverViewController: UIViewController {
    
    @IBOutlet weak var cityPicker: UIPickerView! {
        didSet {
            cityPicker.dataSource = self
            cityPicker.delegate = self
        }
    }
    
    // Dependency injection
    var allCities = [(name: String, reference: DocumentReference, coordinates: CLLocationCoordinate2D)]()
    var currentCity: (name: String, reference: DocumentReference, coordinates: CLLocationCoordinate2D)!

}

extension ChooseCityPopoverViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return allCities.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return allCities[row].name
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if allCities[row].name != currentCity.name {
            currentCity = allCities.first { $0.name ==  allCities[row].name }
            performSegue(withIdentifier: "unwindSegueChooseCityPopoverToMap", sender: self)
        }
    }
}
