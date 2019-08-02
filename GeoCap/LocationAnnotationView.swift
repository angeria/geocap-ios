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
        // Extract color to constant
        button.backgroundColor = UIColor.Custom.systemBlue
        // TODO: Extract constants
        // TODO: For some reason 50 is the perfect height, more than that and the title is misaligned
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        
        rightCalloutAccessoryView = button
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
