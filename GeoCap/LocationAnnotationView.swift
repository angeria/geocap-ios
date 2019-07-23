//
//  LocationAnnotationView.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-23.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import MapKit

class LocationAnnotationView: MKMarkerAnnotationView {

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        canShowCallout = true
        
        let button = UIButton(type: .system)
        button.setTitle("Capture", for: .normal)
        button.tintColor = .white
        button.backgroundColor = .init(r: 45, g: 209, b: 135)
        // TODO: Extract constants
        // TODO: For some reason 50 is the perfect height, more than that and the title is misaligned
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        
        rightCalloutAccessoryView = button
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension UIColor {
    convenience init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.init(red: r/255, green: g/255, blue: b/255, alpha: 1)
    }
}
