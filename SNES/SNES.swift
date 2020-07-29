//
//  SNES.swift
//  SuperRustBoy
//
//  Created by Sean Inge Asbjørnsen on 19/07/2020.
//  Copyright © 2020 Sean Inge Asbjørnsen. All rights reserved.
//

#if os(OSX)
import AppKit
#else
import UIKit
import AVFoundation
#endif
import CoreSNES
import CoreVideo

internal final class SNES: Emulator {

    internal enum ButtonType {
        case left, right, up, down, a, b, x, y, start, select, leftShoulder, rightShoulder
    }

    internal var cartridge: Cartridge? {
        didSet {
            coreSNES = nil

            if autoBoot {
                let _ = boot()
            }
        }
    }

    internal override var display: DisplayView? {
        didSet {
            coreSNES?.display = display
        }
    }

    internal func buttonPressed(_ button: ButtonType, controller: UInt32) {
        coreSNES?.buttonPressed(snesButton(button), controller: controller)
    }

    internal func buttonUnpressed(_ button: ButtonType, controller: UInt32) {
        coreSNES?.buttonUnpressed(snesButton(button), controller: controller)
    }

    internal func boot() -> BootStatus {
        guard let cart = cartridge else { return .cartridgeMissing }

        guard let coreSNES = CoreSNES(cartridge: cart) else { return .failedToInitCore }

        self.coreSNES = coreSNES
        self.coreSNES?.display = display

        return .success
    }

    private var coreSNES: CoreSNES?
}


private final class CoreSNES {

    fileprivate weak var display: DisplayView?

    fileprivate init?(cartridge: SNES.Cartridge) {
        guard let coreRef = snesCreate(cartridge.path, cartridge.saveFilePath) else { return nil }
        self.coreRef = coreRef
        timer = Timer.scheduledTimer(withTimeInterval: 1 / Self.framerate, repeats: true) { [weak self] timer in
            self?.render()
        }
    }

    deinit {
        timer?.invalidate()
        snesDelete(coreRef)
    }

    fileprivate func buttonPressed(_ button: snesButton, controller: UInt32) {
        snesButtonClickDown(coreRef, button, controller)
    }

    fileprivate func buttonUnpressed(_ button: snesButton, controller: UInt32) {
        snesButtonClickUp(coreRef, button, controller)
    }

    private let coreRef: UnsafeRawPointer

    private var timer: Timer?
    private var buffer = [UInt8](repeating: 0, count: Int(frameBufferSize))

    private static let framerate: Double = 60
    private static let frameInfo = snesGetFrameInfo()
    private static var frameBufferSize: UInt32 {
        frameInfo.width * frameInfo.height * frameInfo.bytesPerPixel
    }
    private static let bitsPerByte = 8

    private func render() {
        snesFrame(coreRef, &buffer, UInt32(buffer.count))

        guard let display = display else { return }

        let data = Data(bytes: &buffer, count: buffer.count)

        guard let coreImage = Self.createCGImage(from: data) else { return }

#if os(OSX)
        let image = NSImage(cgImage: coreImage, size: NSSize(width: Int(Self.frameInfo.width), height: Int(Self.frameInfo.height)))
#else
        let image = UIImage(cgImage: coreImage)
#endif

        display.image = image
    }

    private static func createCGImage(from data: Data) -> CGImage? {
        guard let dataProvider = CGDataProvider(data: data as CFData) else { return nil }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        return CGImage(
            width:              Int(frameInfo.width),
            height:             Int(frameInfo.height),
            bitsPerComponent:   8,
            bitsPerPixel:       Int(frameInfo.bytesPerPixel) * bitsPerByte,
            bytesPerRow:        Int(frameInfo.width * frameInfo.bytesPerPixel),
            space:              colorSpace,
            bitmapInfo:         [CGBitmapInfo.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)],
            provider:           dataProvider,
            decode:             nil,
            shouldInterpolate:  false,
            intent:             CGColorRenderingIntent.saturation
        )
    }
}

private extension snesButton {
    init(_ buttonType: SNES.ButtonType) {
        switch buttonType {
            case .left:          self = snesButtonLeft
            case .right:         self = snesButtonRight
            case .up:            self = snesButtonUp
            case .down:          self = snesButtonDown
            case .a:             self = snesButtonA
            case .b:             self = snesButtonB
            case .x:             self = snesButtonX
            case .y:             self = snesButtonY
            case .start:         self = snesButtonStart
            case .select:        self = snesButtonSelect
            case .leftShoulder:  self = snesButtonL
            case .rightShoulder: self = snesButtonR
        }
    }
}


