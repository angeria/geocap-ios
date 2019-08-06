//
//  LocationAnnotationView.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-08-06.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import MapKit

class LocationAnnotationView: MKMarkerAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
        
        animatesWhenAdded = true
        canShowCallout = true
        
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture", for: .normal)
        captureButton.tintColor = .white
        captureButton.backgroundColor = UIColor.Custom.systemBlue
        // TODO: Extract constants and adjust to different text sizes
        captureButton.frame = CGRect(x: 0, y: 0, width: 90, height: 50)
        rightCalloutAccessoryView = captureButton
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
