//
//  AppDelegate.swift
//  Mercury
//
//  Created by Nico Ameghino on 10/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                return false
        }

        if
            let host = components.host, host == "join",
            let items = components.queryItems,
            let room = items.first?.value {
            let controller = ViewController()
            controller.viewModel.join(with: room)
            window?.rootViewController = controller
            return true
        }
        return false
    }
}

