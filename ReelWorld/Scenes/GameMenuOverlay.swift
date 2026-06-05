//
//  GameMenuOverlay.swift
//  ReelWorld
//
//  A camera-anchored, tabbed menu: review past catches (and sell them),
//  equip a rod, and buy better rods from the shop.
//

import SpriteKit

final class GameMenuOverlay: SKNode {

    enum Tab { case catches, equipment, shop }

    var onClose: (() -> Void)?
    var onMainMenu: (() -> Void)?

    private let screen: CGSize
    private let uiFont = "Menlo-Bold"
    private var tab: Tab = .catches

    // Interactive hit targets (direct children of self) and their actions.
    private var buttons: [(node: SKNode, action: () -> Void)] = []

    private var panelW: CGFloat { min(screen.width - 40, 680) }
    private var panelH: CGFloat { min(screen.height - 36, 400) }

    init(size: CGSize) {
        self.screen = size
        super.init()
        zPosition = 300
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Tap routing (called by the scene)

    func handleTap(sceneLocation: CGPoint, from scene: SKScene) {
        let p = convert(sceneLocation, from: scene)
        for entry in buttons.reversed() where entry.node.calculateAccumulatedFrame().contains(p) {
            entry.action()
            return
        }
    }

    // MARK: - Build

    private func rebuild() {
        removeAllChildren()
        buttons.removeAll()

        // Dim backdrop.
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6), size: screen)
        addChild(dim)

        // Panel.
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 18)
        panel.fillColor = SKColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 1)
        panel.strokeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        panel.lineWidth = 4
        addChild(panel)

        let top = panelH / 2

        // Coins (top-left).
        let coin = SKShapeNode(circleOfRadius: 9)
        coin.fillColor = SKColor(red: 1.0, green: 0.83, blue: 0.30, alpha: 1)
        coin.strokeColor = SKColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1)
        coin.lineWidth = 2
        coin.position = CGPoint(x: -panelW / 2 + 24, y: top - 26)
        addChild(coin)
        addLabel("\(GameState.shared.coins)", x: -panelW / 2 + 40, y: top - 26,
                 size: 18, color: SKColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1), halign: .left)

        // Close (top-right).
        addButton(x: panelW / 2 - 26, y: top - 26, w: 34, h: 34, title: "X",
                  fill: SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1)) { [weak self] in
            self?.onClose?()
        }

        // Back to main menu (top-center).
        addButton(x: 0, y: top - 26, w: 150, h: 32, title: "Main Menu",
                  fill: SKColor(red: 0.28, green: 0.32, blue: 0.40, alpha: 1), fontSize: 15) { [weak self] in
            self?.onMainMenu?()
        }

        // Tabs.
        let tabY = top - 66
        let tabW = (panelW - 48) / 3
        let titles: [(Tab, String)] = [(.catches, "Catches"), (.equipment, "Gear"), (.shop, "Shop")]
        for (i, item) in titles.enumerated() {
            let x = -panelW / 2 + 24 + tabW / 2 + CGFloat(i) * tabW
            let active = item.0 == tab
            addButton(x: x, y: tabY, w: tabW - 8, h: 34, title: item.1,
                      fill: active ? SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
                                   : SKColor(red: 0.28, green: 0.32, blue: 0.40, alpha: 1),
                      textColor: active ? SKColor(red: 0.2, green: 0.13, blue: 0.04, alpha: 1) : .white) { [weak self] in
                self?.tab = item.0
                self?.rebuild()
            }
        }

        switch tab {
        case .catches:   buildCatches(topY: tabY - 36)
        case .equipment: buildEquipment(topY: tabY - 36)
        case .shop:      buildShop(topY: tabY - 36)
        }
    }

    // MARK: - Catches tab

    private func buildCatches(topY: CGFloat) {
        let log = CatchLog.shared
        if log.count == 0 {
            addLabel("No catches yet — go reel something in!", x: 0, y: 0, size: 16,
                     color: SKColor(white: 0.8, alpha: 1), halign: .center)
            return
        }

        addLabel("Total: \(log.count) fish  •  worth \(log.totalValue)g",
                 x: -panelW / 2 + 24, y: topY, size: 14,
                 color: SKColor(white: 0.85, alpha: 1), halign: .left)
        addButton(x: panelW / 2 - 70, y: topY + 2, w: 110, h: 30, title: "Sell All",
                  fill: SKColor(red: 0.20, green: 0.70, blue: 0.40, alpha: 1), fontSize: 15) { [weak self] in
            CatchLog.shared.sellAll()
            self?.rebuild()
        }

        let rowH: CGFloat = 36
        let startY = topY - 28
        let maxRows = max(1, Int((startY - (-panelH / 2 + 24)) / rowH))
        let shown = Array(log.recent.prefix(maxRows))

        for (i, fish) in shown.enumerated() {
            let y = startY - CGFloat(i) * rowH
            addRowBG(y: y, h: rowH - 6)
            addLabel(fish.name, x: -panelW / 2 + 24, y: y, size: 15, color: .white, halign: .left)
            addLabel("\(fish.weightText)  \(fish.lengthText)", x: -panelW / 2 + 200, y: y,
                     size: 13, color: SKColor(white: 0.8, alpha: 1), halign: .left)
            addButton(x: panelW / 2 - 60, y: y, w: 92, h: 28, title: "Sell \(fish.value)g",
                      fill: SKColor(red: 0.22, green: 0.55, blue: 0.42, alpha: 1), fontSize: 13) { [weak self] in
                CatchLog.shared.sell(recentIndex: i)
                self?.rebuild()
            }
        }

        if log.count > shown.count {
            addLabel("+\(log.count - shown.count) more (use Sell All)", x: 0, y: -panelH / 2 + 16,
                     size: 12, color: SKColor(white: 0.7, alpha: 1), halign: .center)
        }
    }

    // Two-column layout helpers (left = Rods, right = Lures).
    private var colMargin: CGFloat { 24 }
    private var colGap: CGFloat { 12 }
    private var colWidth: CGFloat { (panelW - colMargin * 2 - colGap) / 2 }
    private var leftCX: CGFloat { -panelW / 2 + colMargin + colWidth / 2 }
    private var rightCX: CGFloat { leftCX + colWidth + colGap }

    // MARK: - Equipment ("Gear") tab — rods on the left, lures on the right

    private func buildEquipment(topY: CGFloat) {
        addLabel("Rods", x: leftCX, y: topY, size: 16,
                 color: SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1), halign: .center)
        addLabel("Lures", x: rightCX, y: topY, size: 16,
                 color: SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1), halign: .center)

        let cardH: CGFloat = 50
        var y = topY - 30
        for rod in Rod.all where GameState.shared.owns(rod.id) {
            addRodCard(rod: rod, cx: leftCX, y: y, shop: false)
            y -= cardH
        }
        y = topY - 30
        for lure in Lure.all where GameState.shared.ownsLure(lure.id) {
            addLureCard(lure: lure, cx: rightCX, y: y, shop: false)
            y -= cardH
        }
    }

    // MARK: - Shop tab — buy rods (left) and lures (right)

    private func buildShop(topY: CGFloat) {
        addLabel("Rods", x: leftCX, y: topY, size: 16,
                 color: SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1), halign: .center)
        addLabel("Lures", x: rightCX, y: topY, size: 16,
                 color: SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1), halign: .center)

        let cardH: CGFloat = 50
        var y = topY - 30
        for rod in Rod.all {
            addRodCard(rod: rod, cx: leftCX, y: y, shop: true)
            y -= cardH
        }
        y = topY - 30
        for lure in Lure.all {
            addLureCard(lure: lure, cx: rightCX, y: y, shop: true)
            y -= cardH
        }
    }

    private func addRodCard(rod: Rod, cx: CGFloat, y: CGFloat, shop: Bool) {
        let action = makeCardAction(
            shop: shop,
            owned: GameState.shared.owns(rod.id),
            equipped: GameState.shared.equippedRodID == rod.id,
            price: rod.price,
            buy: { GameState.shared.buy(rod) },
            equip: { GameState.shared.equip(rod.id) })
        addGearCard(cx: cx, y: y, icon: rod.icon, title: rod.name,
                    subtitle: "Pw \(String(format: "%.1f", rod.power)) • \(rod.maxLandableText)",
                    button: action)
    }

    private func addLureCard(lure: Lure, cx: CGFloat, y: CGFloat, shop: Bool) {
        let action = makeCardAction(
            shop: shop,
            owned: GameState.shared.ownsLure(lure.id),
            equipped: GameState.shared.equippedLureID == lure.id,
            price: lure.price,
            buy: { GameState.shared.buyLure(lure) },
            equip: { GameState.shared.equipLure(lure.id) })
        addGearCard(cx: cx, y: y, icon: lure.icon, title: lure.name,
                    subtitle: "\(lure.attractionText) • \(lure.sizeText)",
                    button: action)
    }

    /// Describes a card's action button given ownership/shop context.
    private struct CardButton {
        var title: String
        var fill: SKColor
        var enabled: Bool
        var run: () -> Void
    }

    private func makeCardAction(shop: Bool, owned: Bool, equipped: Bool, price: Int,
                                buy: @escaping () -> Bool, equip: @escaping () -> Void) -> CardButton {
        if shop {
            if owned {
                return CardButton(title: "Owned",
                                  fill: SKColor(red: 0.4, green: 0.45, blue: 0.42, alpha: 1),
                                  enabled: false, run: {})
            }
            let canAfford = GameState.shared.coins >= price
            return CardButton(title: "Buy \(price)g",
                              fill: canAfford ? SKColor(red: 0.20, green: 0.70, blue: 0.40, alpha: 1)
                                              : SKColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1),
                              enabled: canAfford,
                              run: { [weak self] in if buy() { self?.rebuild() } })
        } else {
            return CardButton(title: equipped ? "Equipped" : "Equip",
                              fill: equipped ? SKColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1)
                                             : SKColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1),
                              enabled: !equipped,
                              run: { [weak self] in equip(); self?.rebuild() })
        }
    }

    private func addGearCard(cx: CGFloat, y: CGFloat, icon: SKTexture, title: String,
                             subtitle: String, button: CardButton) {
        addCardBG(cx: cx, y: y, w: colWidth, h: 44)

        let iconNode = SKSpriteNode(texture: icon)
        iconNode.size = CGSize(width: 30, height: 30)
        iconNode.position = CGPoint(x: cx - colWidth / 2 + 22, y: y)
        addChild(iconNode)

        let textX = cx - colWidth / 2 + 42
        addLabel(title, x: textX, y: y + 10, size: 13, color: .white, halign: .left)
        addLabel(subtitle, x: textX, y: y - 8, size: 10,
                 color: SKColor(white: 0.78, alpha: 1), halign: .left)

        addButton(x: cx + colWidth / 2 - 44, y: y, w: 78, h: 28, title: button.title,
                  fill: button.fill, fontSize: 12, enabled: button.enabled, action: button.run)
    }

    private func addCardBG(cx: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 8)
        bg.fillColor = SKColor(white: 1, alpha: 0.06)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: cx, y: y)
        addChild(bg)
    }

    // MARK: - Small builders

    @discardableResult
    private func addLabel(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat,
                          color: SKColor, halign: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: uiFont)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = halign
        label.position = CGPoint(x: x, y: y)
        addChild(label)
        return label
    }

    private func addRowBG(y: CGFloat, h: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: panelW - 36, height: h), cornerRadius: 8)
        bg.fillColor = SKColor(white: 1, alpha: 0.06)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: 0, y: y)
        addChild(bg)
    }

    private func addButton(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, title: String,
                           fill: SKColor, textColor: SKColor = .white, fontSize: CGFloat = 16,
                           enabled: Bool = true, action: @escaping () -> Void) {
        let container = SKNode()
        container.position = CGPoint(x: x, y: y)

        let bg = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 8)
        bg.fillColor = enabled ? fill : fill.withAlphaComponent(0.5)
        bg.strokeColor = SKColor(white: 1, alpha: enabled ? 0.7 : 0.2)
        bg.lineWidth = 2
        container.addChild(bg)

        let label = SKLabelNode(fontNamed: uiFont)
        label.text = title
        label.fontSize = fontSize
        label.fontColor = enabled ? textColor : textColor.withAlphaComponent(0.6)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        addChild(container)
        if enabled { buttons.append((container, action)) }
    }
}
