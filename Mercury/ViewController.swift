//
//  ViewController.swift
//  Mercury
//
//  Created by Nico Ameghino on 10/6/18.
//  Copyright © 2018 Nico Ameghino. All rights reserved.
//

import UIKit
import AudioToolbox.AudioServices

let logDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .none
    df.timeStyle = .long
    return df
}()

extension UITextView {
    func log(_ message: String) {
        DispatchQueue.main.async { [unowned self] in
            let entry = "\(logDateFormatter.string(from: Date())) - \(message)"
            let newText = [self.text, entry].compactMap { $0 }.joined(separator: "\n")
            self.text = newText
        }
    }
}

protocol HomeViewModelProtocol {
    func host()
    func join()
    func sendPing()
    func send(message: String)
}

protocol SessionHandlerProtocol {
    func received(message: MercuryMessage, from peer: String)
    func peer(_ peer: String, stateChangedTo connected: Bool)
}

class ViewController: UIViewController {
    lazy var viewModel: HomeViewModelProtocol = {
        let vm = HomeViewModel(with: self)
        return vm
    }()

    lazy var feedbackGenerator: UIImpactFeedbackGenerator = {
        let fg = UIImpactFeedbackGenerator(style: .heavy)
        fg.prepare()
        return fg
    }()

    lazy var hostButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Host", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .blue
        b.addTarget(self, action: #selector(host(_:)), for: .primaryActionTriggered)
        return b
    }()

    lazy var joinButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Join", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .red
        b.addTarget(self, action: #selector(join(_:)), for: .primaryActionTriggered)
        return b
    }()

    lazy var sendPingButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Send Ping", for: .normal)
        b.setTitleColor(.black, for: .normal)
        b.backgroundColor = .yellow
        b.addTarget(self, action: #selector(sendPing(_:)), for: .primaryActionTriggered)
        return b
    }()

    lazy var composeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Compose", for: .normal)
        b.setTitleColor(.black, for: .normal)
        b.backgroundColor = .green
        b.addTarget(self, action: #selector(compose(_:)), for: .primaryActionTriggered)
        return b
    }()


    lazy var consoleTextField: UITextView = {
        let tf = UITextView()
        tf.isUserInteractionEnabled = false
        tf.isEditable = false
        tf.textColor = .green
        tf.backgroundColor = .black
        return tf
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let gr = UITapGestureRecognizer(target: self, action: #selector(compose(_:)))
        gr.numberOfTapsRequired = 2
        view.addGestureRecognizer(gr)

        let buttonsStackView: UIStackView = {
            let stackView = UIStackView(arrangedSubviews: [hostButton, joinButton, sendPingButton, composeButton])
            stackView.spacing = 10
            stackView.distribution = .fillEqually
            stackView.axis = .horizontal
            stackView.translatesAutoresizingMaskIntoConstraints = false
            return stackView
        }()

        let stackView = UIStackView(arrangedSubviews: [buttonsStackView, consoleTextField])
        stackView.spacing = 4
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 1),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stackView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
        ])
    }

    @objc
    func host(_ sender: UIButton) {
        consoleTextField.log("host tapped")
        viewModel.host()
    }

    @objc
    func join(_ sender: UIButton) {
        consoleTextField.log("join tapped")
        viewModel.join()
    }

    @objc
    func sendPing(_ sender: UIButton) {
        consoleTextField.log("sending ping")
        viewModel.sendPing()
    }

    @objc
    func compose(_ sender: UIButton) {
        let controller = UIAlertController(title: "Compose message", message: nil, preferredStyle: .alert)
        controller.addTextField { textField in
            textField.autocorrectionType = UITextAutocorrectionType.yes
        }

        let sendAction = UIAlertAction(title: "Send", style: .default) { [weak self, weak controller] (_) in
            guard
                let content = controller?.textFields?.first?.text,
                let strongSelf = self
            else { return }
            strongSelf.viewModel.send(message: content)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        [cancelAction, sendAction].forEach { controller.addAction($0) }

        present(controller, animated: true, completion: nil)
    }

    private func handleBuzz(_ m: MercuryMessage, from: String) {
        DispatchQueue.main.async { [unowned self] in
            let hasTapticEngine: Bool
            if let r = UIDevice.current.value(forKey: "_feedbackSupportLevel") as? Int {
                hasTapticEngine = r == 2
            } else {
                hasTapticEngine = false
            }

            if hasTapticEngine {
                self.feedbackGenerator.impactOccurred()
                self.feedbackGenerator.prepare()
            } else {
                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
            }
        }
    }

    private func handleMessage(_ m: MercuryMessage, from: String) {
        consoleTextField.log("\(from): \(m.payload["text"]!)")
    }
}

extension ViewController: SessionHandlerProtocol {
    func received(message: MercuryMessage, from peer: String) {
        switch message.type {
        case .message:
            handleMessage(message, from: peer)
        case .buzz:
            handleBuzz(message, from: peer)
        default:
            break
        }
    }

    func peer(_ peer: String, stateChangedTo connected: Bool) {
        consoleTextField.log("\(peer) is \(connected ? "" : "not ")online")
    }
}
