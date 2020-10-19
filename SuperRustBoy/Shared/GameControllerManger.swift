//
//  GameControllerManger.swift
//  SuperRustBoy
//
//  Created by Sean Inge Asbjørnsen on 30/06/2020.
//

import Combine
import Foundation
import GameController

internal enum GameControllerButton {
    case left, up, right, down, a, b, x, y, menu, options, leftShoulder, rightShoulder
}

internal protocol GameControllerReceiver: AnyObject {
    func buttonPressed(_ button: GameControllerButton, playerIndex: Int)
    func buttonUnpressed(_ button: GameControllerButton, playerIndex: Int)
}

internal protocol KeyboardReceiver: AnyObject {
    func buttonPressed(_ button: GCKeyCode, playerIndex: Int)
    func buttonUnpressed(_ button: GCKeyCode, playerIndex: Int)
}

internal protocol GameController: AnyObject {
    var id: ObjectIdentifier { get }
    var playerIndex: Int? { get }
    var batteryLevel: Float? { get }
    var kind: GameControllerType { get }
}

internal enum GameControllerType {
    case keyboard, controller
}

internal final class GameControllerManager: ObservableObject {

    internal weak var receiver: (GameControllerReceiver & KeyboardReceiver)? {
        didSet {
            internalControllers.forEach { $0.receiver = receiver }
        }
    }

    internal var controllers: [GameController] { internalControllers }

    private var internalControllers: [Controller] = [] {
        didSet { objectWillChange.send() }
    }

    internal init() {
        NotificationCenter
            .default
            .publisher(for: .GCControllerDidConnect)
            .compactMap { $0.object as? GCController }
            .sink { [weak self] controller in
                guard let self = self else { return }
                self.internalControllers.append(Controller(controller: controller, playerIndex: 1))
            }
            .store(in: &cancellables)

        NotificationCenter
            .default
            .publisher(for: .GCKeyboardDidConnect)
            .compactMap { $0.object as? GCKeyboard }
            .sink { [weak self] keyboard in
                guard let self = self else { return }
                self.internalControllers.append(Controller(keyboard: keyboard, playerIndex: 1))
            }
            .store(in: &cancellables)
    }

    internal func rotateIndex(for controller: GameController) {
        if let controller = controller as? Controller {
            controller.playerIndex = (controller.playerIndex ?? 0) + 1
            objectWillChange.send()
        }
    }

    private var cancellables = Set<AnyCancellable>()
}

fileprivate class Controller: GameController {

    var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    fileprivate var playerIndex: Int?

    var batteryLevel: Float? {
        switch internalController {
        case .controller(let controller):
            return controller.battery?.batteryLevel
        case .keyboard:
            return nil
        }
    }

    var kind: GameControllerType {
        switch internalController {
        case .controller:
            return .controller
        case .keyboard:
            return .keyboard
        }
    }

    weak var receiver: (GameControllerReceiver & KeyboardReceiver)?

    private let internalController: IternalGameControllerType

    internal enum IternalGameControllerType {
        case keyboard(GCKeyboard)
        case controller(GCController)
    }

    init(controller: GCController, playerIndex: Int) {
        self.internalController = .controller(controller)
        self.playerIndex = playerIndex

        controller.extendedGamepad?.dpad.valueChangedHandler = { [self] (dpad, x, y) in
            switch x {
            case 1:
                receiver?.buttonPressed(.right, playerIndex: playerIndex)

            case -1:
                receiver?.buttonPressed(.left, playerIndex: playerIndex)

            default:
                receiver?.buttonUnpressed(.right, playerIndex: playerIndex)
                receiver?.buttonUnpressed(.left, playerIndex: playerIndex)
            }

            switch y {
            case 1:
                receiver?.buttonPressed(.up, playerIndex: playerIndex)

            case -1:
                receiver?.buttonPressed(.down, playerIndex: playerIndex)

            default:
                receiver?.buttonUnpressed(.up, playerIndex: playerIndex)
                receiver?.buttonUnpressed(.down, playerIndex: playerIndex)
            }
        }

        controller.extendedGamepad?.buttonA.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.a, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.a, playerIndex: playerIndex)
        }

        controller.extendedGamepad?.buttonB.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.b, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.b, playerIndex: playerIndex)
        }

        controller.extendedGamepad?.buttonX.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.x, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.x, playerIndex: playerIndex)
        }

        controller.extendedGamepad?.buttonY.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.y, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.y, playerIndex: playerIndex)
        }

        controller.extendedGamepad?.buttonMenu.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.menu, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.menu, playerIndex: playerIndex)
        }

        controller.extendedGamepad?.buttonOptions?.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.options, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.options, playerIndex: playerIndex)
        }

        controller.extendedGamepad?.leftShoulder.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.leftShoulder, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.leftShoulder, playerIndex: playerIndex)
        }

        controller.extendedGamepad?.rightShoulder.valueChangedHandler = { [self] (button, pressure, isPressed) in
            isPressed
                ? receiver?.buttonPressed(.rightShoulder, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(.rightShoulder, playerIndex: playerIndex)
        }
    }

    init(keyboard: GCKeyboard, playerIndex: Int) {
        self.internalController = .keyboard(keyboard)
        self.playerIndex = playerIndex

        keyboard.keyboardInput?.keyChangedHandler = { [self] (input, buttonInput, keyCode, isPressed) in
            isPressed
                ? receiver?.buttonPressed(keyCode, playerIndex: playerIndex)
                : receiver?.buttonUnpressed(keyCode, playerIndex: playerIndex)
        }
    }
}
