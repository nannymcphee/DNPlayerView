//
//  AppDelegate.swift
//  SampleApp
//
//  Created by Duy Nguyen on 01/05/2022.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var navigationController: UINavigationController?
    var rootViewController: UIViewController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupRootVC()
        return true
    }

    private func setupRootVC() {
        rootViewController = VideoListVC()
        navigationController = UINavigationController(rootViewController: rootViewController!)
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
}

