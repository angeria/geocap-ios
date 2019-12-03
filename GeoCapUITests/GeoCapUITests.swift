//
//  GeoCapUITests.swift
//  GeoCapUITests
//
//  Created by Benjamin Angeria on 2019-07-19.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import XCTest

class GeoCapUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()

        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        app = XCUIApplication()

        // UI tests must launch the application that they test
        // Doing this in setup will make sure it happens for each test method
        XCUIApplication().launch()

        // We send a command line argument to our app,
        // to enable it to reset its state
        app.launchArguments.append("--uitesting")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSignIn() {
        app.launch()

        XCTAssertTrue(app.otherElements["welcomeView"].waitForExistence(timeout: 1))

        app.buttons.firstMatch.tap()

        XCTAssert(app.textFields.firstMatch.waitForExistence(timeout: 1))

        app.textFields.firstMatch.typeText("benjamin.angeria@icloud.com")
        app.buttons["Fortsätt"].tap()
        app.alerts.firstMatch.buttons["Ja"].tap()

        XCTAssert(app.otherElements["checkEmailView"].waitForExistence(timeout: 2))
    }

    func testSignUp() {
        app.launch()

        app/*@START_MENU_TOKEN@*/.buttons["Fortsätt med din e-post"]/*[[".otherElements[\"welcomeView\"].buttons[\"Fortsätt med din e-post\"]",".buttons[\"Fortsätt med din e-post\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap() // swiftlint:disable:this line_length
        app.textFields.firstMatch.typeText("xipcake@icloud.com")
        app.buttons["Fortsätt"].tap()
        app.alerts["Bekräfta e-post"].scrollViews.otherElements.buttons["Ja"].tap()

        XCTAssert(app.otherElements["chooseUsernameView"].waitForExistence(timeout: 2))

        app.textFields.firstMatch.typeText("TEST NAME")
        app.buttons["Fortsätt"].tap()

        XCTAssert(app.otherElements["checkEmailView"].waitForExistence(timeout: 2))
    }
}
