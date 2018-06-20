//
//  UIAlertController+Prompt.swift
//  Mercury
//
//  Created by Nico Ameghino on 19/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import UIKit

enum UIAlertControllerPromptError: Error {
    case unableToExtractText
}

extension UIViewController {
    func prompt(with title: String, acceptButtonTitle: String = "Submit", callback: @escaping (Result<String, UIAlertControllerPromptError>) -> Void) {
        let p: UIAlertController = UIAlertController.prompt(with: title, acceptButtonTitle: acceptButtonTitle, callback: callback)
        self.present(p, animated: true, completion: nil)
    }

    func alert(with title: String?, message: String?, actionButtonTitle: String? = nil, actionCallback: (() -> Void)? = nil) {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if let buttonTitle = actionButtonTitle,
            let actionCallback = actionCallback {

            let action = UIAlertAction(title: buttonTitle, style: .default) { _ in
                actionCallback()
            }
            controller.addAction(action)
        }


        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        controller.addAction(cancelAction)

        self.present(controller, animated: true, completion: nil)
    }
}

extension UIAlertController {
    static func prompt(with title: String, acceptButtonTitle: String = "Submit", callback: @escaping (Result<String, UIAlertControllerPromptError>) -> Void) -> UIAlertController {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        controller.addTextField { textField in
            textField.autocorrectionType = UITextAutocorrectionType.yes
        }

        let sendAction = UIAlertAction(title: acceptButtonTitle, style: .default) { [weak controller] (_) in
            guard
                let content = controller?.textFields?.first?.text
            else {
                callback(.failure(.unableToExtractText))
                return
            }
            callback(.success(content))
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        [cancelAction, sendAction].forEach { controller.addAction($0) }
        return controller
    }
}
