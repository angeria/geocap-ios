//
//  GeoCapTests.swift
//  GeoCapTests
//
//  Created by Benjamin Angeria on 2019-07-19.
//  Copyright © 2019 Benjamin Angeria. All righ wts reserved.
//

import XCTest
@testable import GeoCap
@testable import Firebase

class GeoCapTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCreateLocation() {
        let location = Location(data: [
            "name": "Test location",
            "center": GeoPoint(latitude: 32.4334, longitude: 23.4334)
        ], username: "John")
        
        XCTAssert(location != nil)
        XCTAssertFalse(location!.isCapturedByUser)
    }

//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measure {
//        // Put the code you want to measure the time of here.
//        }
//    }

}
