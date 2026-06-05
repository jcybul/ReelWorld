//
//  MenuScene.swift
//  ReelWorld
//
//  Pixel-art styled main menu. Beach is playable; Ocean and Lake are
//  grayed-out "coming soon" placeholders.
//

import SpriteKit

class MenuScene: SKScene {

    private let pixelFont = "Menlo-Bold"
    private let activeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
    private let lockedColor = SKColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1)

    override func didMove(to view: SKView) {
        buildBackground()
        buildTitle()
        buildButtons()
    }

    // MARK: - Background

    private func buildBackground() {
        // Layered sky / sea / sand bands for a simple beach vibe.
        let bands: [(CGFloat, SKColor)] = [
            (0.62, SKColor(red: 0.45, green: 0.72, blue: 0.92, alpha: 1)),   // sky
            (0.30, SKColor(red: 0.10, green: 0.42, blue: 0.66, alpha: 1)),   // sea
            (0.08, SKColor(red: 0.80, green: 0.72, blue: 0.50, alpha: 1)),   // sand
        ]
        var y: CGFloat = size.height
        for (frac, color) in bands {
            let h = size.height * frac
            let band = SKSpriteNode(color: color, size: CGSize(width: size.width, height: h))
            band.anchorPoint = CGPoint(x: 0, y: 1)
            band.position = CGPoint(x: 0, y: y)
            band.zPosition = -10
            addChild(band)
            y -= h
        }

        // A glinting sun.
        let sun = SKShapeNode(circleOfRadius: 34)
        sun.fillColor = SKColor(red: 1.0, green: 0.95, blue: 0.65, alpha: 1)
        sun.strokeColor = .clear
        sun.position = CGPoint(x: size.width * 0.82, y: size.height * 0.82)
        sun.zPosition = -9
        addChild(sun)
    }

    // MARK: - Title

    private func buildTitle() {
        let title = SKLabelNode(fontNamed: pixelFont)
        title.text = "REEL WORLD"
        title.fontSize = 56
        title.fontColor = .white
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.80)
        title.zPosition = 1
        addChild(title)

        // Pixel-style drop shadow behind the title.
        let shadow = SKLabelNode(fontNamed: pixelFont)
        shadow.text = title.text
        shadow.fontSize = title.fontSize
        shadow.fontColor = SKColor(white: 0, alpha: 0.35)
        shadow.horizontalAlignmentMode = .center
        shadow.position = CGPoint(x: title.position.x + 3, y: title.position.y - 3)
        shadow.zPosition = 0
        addChild(shadow)

        let subtitle = SKLabelNode(fontNamed: pixelFont)
        subtitle.text = "Choose your spot"
        subtitle.fontSize = 18
        subtitle.fontColor = SKColor(white: 1, alpha: 0.9)
        subtitle.horizontalAlignmentMode = .center
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.70)
        subtitle.zPosition = 1
        addChild(subtitle)
    }

    // MARK: - Buttons

    private func buildButtons() {
        let buttonSize = CGSize(width: 240, height: 58)
        let spacing: CGFloat = 22
        let totalHeight = buttonSize.height * 3 + spacing * 2
        var y = size.height * 0.52 - buttonSize.height / 2

        let configs: [(name: String, title: String, enabled: Bool)] = [
            ("beach", "Beach", true),
            ("ocean", "Ocean", true),
            ("lake", "Lake", false),
        ]

        for config in configs {
            let button = makeButton(name: config.name, title: config.title,
                                    enabled: config.enabled, size: buttonSize)
            button.position = CGPoint(x: size.width / 2, y: y)
            addChild(button)
            y -= (buttonSize.height + spacing)
        }
        _ = totalHeight
    }

    private func makeButton(name: String, title: String, enabled: Bool, size: CGSize) -> SKNode {
        let container = SKNode()
        container.name = name
        container.zPosition = 5

        let bg = SKShapeNode(rectOf: size, cornerRadius: 10)
        bg.fillColor = enabled ? activeColor : lockedColor
        bg.strokeColor = enabled ? SKColor(white: 1, alpha: 0.9) : SKColor(white: 1, alpha: 0.3)
        bg.lineWidth = 3
        bg.name = name
        container.addChild(bg)

        let label = SKLabelNode(fontNamed: pixelFont)
        label.text = title
        label.fontSize = 28
        label.fontColor = enabled ? SKColor(red: 0.25, green: 0.15, blue: 0.05, alpha: 1)
                                  : SKColor(white: 0.85, alpha: 0.8)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = name
        label.position = enabled ? .zero : CGPoint(x: 0, y: 8)
        container.addChild(label)

        if !enabled {
            let soon = SKLabelNode(fontNamed: pixelFont)
            soon.text = "COMING SOON"
            soon.fontSize = 12
            soon.fontColor = SKColor(white: 1, alpha: 0.7)
            soon.verticalAlignmentMode = .center
            soon.horizontalAlignmentMode = .center
            soon.position = CGPoint(x: 0, y: -14)
            soon.name = name
            container.addChild(soon)
        } else {
            // Gentle pulse to draw the eye to the playable option.
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.6),
                SKAction.scale(to: 1.0, duration: 0.6),
            ])
            container.run(.repeatForever(pulse))
        }

        return container
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location).compactMap { $0.name }

        if tapped.contains("beach") {
            startBeach()
        } else if tapped.contains("ocean") {
            startOcean()
        }
        // Lake is intentionally inert (coming soon).
    }

    private func startBeach() {
        let beach = BeachScene(size: size)
        beach.scaleMode = scaleMode
        view?.presentScene(beach, transition: .doorway(withDuration: 0.6))
    }

    private func startOcean() {
        let ocean = OceanScene(size: size)
        ocean.scaleMode = scaleMode
        view?.presentScene(ocean, transition: .doorway(withDuration: 0.6))
    }
}
