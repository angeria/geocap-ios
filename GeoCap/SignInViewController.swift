//
//  SignInViewController.swift
//  GeoCap
//
//  Created by Benjamin Angeria on 2019-07-20.
//  Copyright © 2019 Benjamin Angeria. All rights reserved.
//

import UIKit
import FirebaseUI

class SignInViewController: UIViewController, FUIAuthDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let authViewController = authUI.authViewController()
        present(authViewController, animated: false)
    }

    // MARK: - AuthUI
    
    lazy var authUI: FUIAuth = {
        let authUI = FUIAuth.defaultAuthUI()!
        authUI.delegate = self
        authUI.providers = [FUIAnonymousAuth(), FUIEmailAuth()]
        return authUI
    }()
    
    func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        
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
