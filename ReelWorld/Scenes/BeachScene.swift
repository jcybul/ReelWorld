//
//  BeachScene.swift
//  ReelWorld
//
//  Created by Joseph Cybul zebede  on 6/5/26.
//

import SpriteKit

class BeachScene: SKScene {

    let tileSize: CGFloat = 32
    let beachWidthTiles = 60
    let sandRowCount = 6
    let shallowRowCount = 4
    let deepRowCount = 8

    var player: SKSpriteNode!
    var cameraNode: SKCameraNode!

    // Fisherman animation frames (sliced from the pixel-art sheets).
    var idleFrames: [SKTexture] = []
    var walkFrames: [SKTexture] = []
    var fishFrames: [SKTexture] = []
    var hookFrames: [SKTexture] = []

    // Fishing state machine.
    enum FishingState { case idle, waiting, biting }
    var fishingState: FishingState = .idle

    var bobber: SKSpriteNode?
    var fishNodes: [FishNode] = []
    var bitingFish: FishNode?
    var pendingCatch: Fish?

    // Rocky reef structures in the water, where reef fish congregate.
    var reefZones: [CGRect] = []
    static let reefSpecies: Set<String> = ["perch", "bass", "angler"]

    // HUD (camera-anchored).
    var actionButton: SKNode!
    var actionBG: SKShapeNode!
    var actionLabel: SKLabelNode!
    var menuButton: SKNode!
    var coinsLabel: SKLabelNode!

    // Catch popup.
    var catchPopup: SKNode?
    var registerButton: SKNode?

    // Catalog / shop / gear menu.
    var menuOverlay: GameMenuOverlay?

    private let uiFont = "Menlo-Bold"

    // MARK: - Derived layout

    private var mapWidth: CGFloat { CGFloat(beachWidthTiles) * tileSize }
    private var sandTopY: CGFloat { CGFloat(sandRowCount) * tileSize }
    private var shallowTopY: CGFloat { CGFloat(sandRowCount + shallowRowCount) * tileSize }
    private var mapTopY: CGFloat { CGFloat(sandRowCount + shallowRowCount + deepRowCount) * tileSize }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1)
        buildTilemap()
        decorateBeach()
        addPlayer()
        setupCamera()
        setupUI()
        addBoundaryMarkers()
        buildReefs()
        spawnFish()
    }

    func buildTilemap() {
        let totalRows = sandRowCount + shallowRowCount + deepRowCount

        for row in 0..<totalRows {
            for col in 0..<beachWidthTiles {
                let tile = SKSpriteNode(color: colorForRow(row), size: CGSize(width: tileSize, height: tileSize))
                tile.position = CGPoint(
                    x: CGFloat(col) * tileSize + tileSize / 2,
                    y: CGFloat(row) * tileSize + tileSize / 2
                )
                tile.zPosition = 0
                tile.name = row < sandRowCount ? "sand" : (row < sandRowCount + shallowRowCount ? "shallow" : "deep")
                addChild(tile)
            }
        }
    }

    func colorForRow(_ row: Int) -> SKColor {
        if row < sandRowCount {
            return SKColor(red: 0.76, green: 0.70, blue: 0.50, alpha: 1)
        } else if row < sandRowCount + shallowRowCount {
            return SKColor(red: 0.20, green: 0.55, blue: 0.75, alpha: 1)
        } else {
            return SKColor(red: 0.05, green: 0.25, blue: 0.55, alpha: 1)
        }
    }

    // MARK: - Decoration (grass lining the water's edge)

    /// Lines the bottom edge of the sand zone with grass reeds, spaced randomly
    /// (not grid-aligned). Re-rolls a fresh layout each load.
    func decorateBeach() {
        let minX = tileSize * 5.5   // clear of the rock jetties
        let maxX = mapWidth - tileSize * 5.5

        var x = minX
        while x < maxX {
            let n = Int.random(in: 1...4)
            let tex = SKTexture(imageNamed: "Grass\(n)")
            tex.filteringMode = .nearest
            let grass = SKSpriteNode(texture: tex)

            let px = tex.size()
            let s = CGFloat.random(in: 1.0...1.5)
            grass.size = CGSize(width: px.width * s, height: px.height * s)
            grass.anchorPoint = CGPoint(x: 0.5, y: 0.0)  // grows up from its base
            grass.position = CGPoint(x: x + CGFloat.random(in: -tileSize * 0.3...tileSize * 0.3),
                                     y: CGFloat.random(in: tileSize * 0.1...tileSize * 0.7))
            if Bool.random() { grass.xScale = -1 }
            grass.zPosition = 2
            addChild(grass)

            x += CGFloat.random(in: 0.8...1.8) * tileSize
        }
    }

    // MARK: - Player

    /// Slices a horizontal pixel-art strip into `frameCount` frames (crisp).
    func animationFrames(sheet name: String, frameCount: Int) -> [SKTexture] {
        let sheet = SKTexture(imageNamed: name)
        sheet.filteringMode = .nearest
        let w = 1.0 / CGFloat(frameCount)
        return (0..<frameCount).map { i in
            let tex = SKTexture(rect: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: 1), in: sheet)
            tex.filteringMode = .nearest
            return tex
        }
    }

    func addPlayer() {
        idleFrames = animationFrames(sheet: "Fisherman_idle", frameCount: 4)
        walkFrames = animationFrames(sheet: "Fisherman_walk", frameCount: 6)
        fishFrames = animationFrames(sheet: "Fisherman_fish", frameCount: 4)
        hookFrames = animationFrames(sheet: "Fisherman_hook", frameCount: 6)

        player = SKSpriteNode(texture: idleFrames.first)
        player.size = CGSize(width: tileSize * 1.5, height: tileSize * 1.5)
        player.position = CGPoint(
            x: CGFloat(beachWidthTiles / 2) * tileSize,
            y: CGFloat(sandRowCount / 2) * tileSize
        )
        player.zPosition = 10
        player.name = "player"
        addChild(player)
        startIdle()
    }

    func startIdle() {
        let anim = SKAction.repeatForever(SKAction.animate(with: idleFrames, timePerFrame: 0.18))
        player.run(anim, withKey: "anim")
    }

    func startWalk() {
        let anim = SKAction.repeatForever(SKAction.animate(with: walkFrames, timePerFrame: 0.1))
        player.run(anim, withKey: "anim")
    }

    func movePlayer(to position: CGPoint) {
        let margin: CGFloat = tileSize * 5.5  // keep player clear of rock clusters
        let minX = margin
        let maxX = mapWidth - margin
        let minY = tileSize * 0.75
        let maxY = sandTopY - tileSize * 0.5

        let targetX = max(minX, min(position.x, maxX))
        let targetY = max(minY, min(position.y, maxY))
        let target = CGPoint(x: targetX, y: targetY)

        let dx = targetX - player.position.x
        let dy = targetY - player.position.y
        let distance = hypot(dx, dy)
        guard distance > 1 else { return }

        if abs(dx) > 1 { player.xScale = dx < 0 ? -1 : 1 }

        startWalk()
        let duration = TimeInterval(distance / 200)
        let move = SKAction.move(to: target, duration: duration)
        let returnToIdle = SKAction.run { [weak self] in self?.startIdle() }
        player.run(SKAction.sequence([move, returnToIdle]), withKey: "walk")
    }

    // MARK: - Camera

    func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = player.position
        addChild(cameraNode)
        camera = cameraNode
    }

    override func update(_ currentTime: TimeInterval) {
        // Camera follows the player (X clamped to the map; Y gently clamped too).
        let halfW = size.width / 2
        let halfH = size.height / 2
        let camX = max(halfW, min(player.position.x, mapWidth - halfW))
        let camY = max(halfH, min(player.position.y, mapTopY - halfH))
        cameraNode.position = CGPoint(x: camX, y: camY)

        // Bite checks: only while a bobber is soaking and no fish is biting yet.
        guard menuOverlay == nil, fishingState == .waiting, let bob = bobber else { return }
        for fish in fishNodes {
            if currentTime < fish.nextBiteCheck { continue }
            fish.nextBiteCheck = currentTime + Double.random(in: 2...3)
            let d = hypot(fish.position.x - bob.position.x, fish.position.y - bob.position.y)
            let chance = 0.5 * GameState.shared.equippedLure.attraction
            if d <= 80 && Double.random(in: 0...1) < chance {
                triggerBite(fish)
                break
            }
        }
    }

    // MARK: - Fish AI

    func spawnFish() {
        let inset = tileSize
        let shallowRect = CGRect(x: inset, y: sandTopY + 10,
                                 width: mapWidth - inset * 2,
                                 height: (shallowTopY - sandTopY) - 20)
        let deepRect = CGRect(x: inset, y: shallowTopY + 10,
                              width: mapWidth - inset * 2,
                              height: (mapTopY - shallowTopY) - 20)

        let reefPool = FishSpecies.beach.filter { BeachScene.reefSpecies.contains($0.species) }
        let openPool = FishSpecies.beach.filter { !BeachScene.reefSpecies.contains($0.species) }

        // Reef fish hang around the rocky structures.
        for zone in reefZones {
            for _ in 0..<Int.random(in: 3...4) {
                addFish(in: zone, pool: reefPool, alpha: 0.8)
            }
        }

        // Open-water fish roam the rest of the beach.
        for _ in 0..<6 { addFish(in: shallowRect, pool: openPool, alpha: 0.55) }
        for _ in 0..<5 { addFish(in: deepRect, pool: openPool, alpha: 0.45) }
    }

    func addFish(in rect: CGRect, pool: [FishSpecies], alpha: CGFloat) {
        guard !rect.isNull, let species = pool.randomElement() else { return }

        let frames = animationFrames(sheet: species.asset, frameCount: species.frameCount)
        let fish = FishNode(texture: frames.first)
        fish.species = species
        fish.deep = species.prefersDeep
        fish.name = "fish"

        let scale: CGFloat = 1.7
        let px = frames.first?.size() ?? CGSize(width: 16, height: 12)
        fish.size = CGSize(width: px.width * scale, height: px.height * scale)
        fish.position = CGPoint(x: .random(in: rect.minX...rect.maxX),
                                y: .random(in: rect.minY...rect.maxY))
        fish.zPosition = 3
        fish.alpha = 0

        if frames.count > 1 {
            fish.run(.repeatForever(.animate(with: frames, timePerFrame: 0.3)), withKey: "anim")
        }
        addChild(fish)
        fish.swim(in: rect)
        fishNodes.append(fish)
    }

    // MARK: - Rocky reef structures

    /// Drops a few submerged rock piles in the water, away from the side jetties.
    /// Each one defines a reef zone that reef fish gather around.
    func buildReefs() {
        let leftEdge = tileSize * 7
        let rightEdge = mapWidth - tileSize * 7
        let fracs: [CGFloat] = [0.28, 0.52, 0.78]
        for f in fracs {
            let cx = leftEdge + (rightEdge - leftEdge) * f + CGFloat.random(in: -tileSize...tileSize)
            // Sit the reef across the shallow/deep boundary.
            let cy = CGFloat.random(in: (sandTopY + tileSize * 1.5)...(shallowTopY + tileSize * 1.5))
            addReefCluster(at: CGPoint(x: cx, y: cy))
            reefZones.append(CGRect(x: cx - tileSize * 2.2, y: cy - tileSize * 1.8,
                                    width: tileSize * 4.4, height: tileSize * 3.6))
        }
    }

    private func addReefCluster(at center: CGPoint) {
        let rocks = Int.random(in: 5...8)
        for _ in 0..<rocks {
            let big = Bool.random()
            let tex = randomRockTexture(big: big)
            let rock = SKSpriteNode(texture: tex)
            let px = tex.size()
            let s = CGFloat.random(in: 0.8...1.2)
            rock.size = CGSize(width: px.width * s, height: px.height * s)
            if Bool.random() { rock.xScale = -1 }
            rock.position = CGPoint(x: center.x + .random(in: -tileSize * 1.6...tileSize * 1.6),
                                    y: center.y + .random(in: -tileSize * 1.2...tileSize * 1.2))
            rock.zRotation = .random(in: -0.1...0.1)
            rock.zPosition = 2
            rock.blendMode = .alpha
            addChild(rock)
        }

        // A little coral / algae for reef character.
        for _ in 0..<Int.random(in: 2...4) {
            let kind = Bool.random() ? ObjectSheet.redAlgae : ObjectSheet.greenAlgae
            let coral = SKSpriteNode(texture: ObjectSheet.icon(kind))
            let s = CGFloat.random(in: 1.0...1.6)
            coral.size = CGSize(width: 32 * s, height: 32 * s)
            coral.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            coral.position = CGPoint(x: center.x + .random(in: -tileSize * 1.4...tileSize * 1.4),
                                     y: center.y + .random(in: -tileSize...tileSize * 0.5))
            coral.zPosition = 2.2
            addChild(coral)
        }
    }

    // MARK: - Casting & bobber

    func startCast(at location: CGPoint) {
        guard fishingState == .idle else { return }

        // Place the bobber in the water at (a clamped) tap location.
        let bx = min(max(location.x, tileSize), mapWidth - tileSize)
        let by = min(max(location.y, sandTopY + tileSize * 0.5), mapTopY - tileSize * 0.5)
        placeBobber(at: CGPoint(x: bx, y: by))

        fishingState = .waiting

        // Cast animation, then a slow "waiting for a bite" hold.
        player.removeAction(forKey: "walk")
        player.removeAction(forKey: "anim")
        let cast = SKAction.animate(with: fishFrames, timePerFrame: 0.15)
        let waiting = SKAction.repeatForever(
            SKAction.animate(with: Array(fishFrames.suffix(2)), timePerFrame: 0.4))
        player.run(.sequence([cast, waiting]), withKey: "anim")

        setActionButton(title: "Reel In", highlighted: false, hidden: false)
    }

    func placeBobber(at point: CGPoint) {
        removeBobber()  // only one bobber at a time
        let tex = SKTexture(imageNamed: "Bobber")
        tex.filteringMode = .nearest
        let bob = SKSpriteNode(texture: tex)
        bob.size = CGSize(width: 16, height: 28)
        bob.position = point
        bob.zPosition = 9
        bob.name = "bobber"
        addChild(bob)
        bobber = bob
        startBobberBob()
    }

    func startBobberBob() {
        guard let bob = bobber else { return }
        bob.removeAction(forKey: "tug")
        let up = SKAction.moveBy(x: 0, y: 4, duration: 0.6)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        bob.run(.repeatForever(.sequence([up, down])), withKey: "bob")
    }

    func removeBobber() {
        bobber?.removeFromParent()
        bobber = nil
    }

    /// Player chose to reel the line in without a catch.
    func cancelFishing() {
        guard fishingState != .idle else { return }
        removeAction(forKey: "biteTimeout")

        // A biting fish escapes back to its wandering.
        if let fish = bitingFish {
            fish.swim(in: fish.wanderRect)
            bitingFish = nil
        }
        removeBobber()
        fishingState = .idle
        setActionButton(title: "Reel In", highlighted: false, hidden: true)

        player.removeAction(forKey: "anim")
        let reel = SKAction.animate(with: hookFrames, timePerFrame: 0.1)
        player.run(reel) { [weak self] in self?.startIdle() }
    }

    // MARK: - Bite

    func triggerBite(_ fish: FishNode) {
        fishingState = .biting
        bitingFish = fish
        fish.removeAction(forKey: "swim")  // hold near the bobber

        // Tug the bobber.
        bobber?.removeAction(forKey: "bob")
        let tug = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -7, duration: 0.08),
            SKAction.moveBy(x: 0, y: 7, duration: 0.14),
        ])
        bobber?.run(.repeatForever(tug), withKey: "tug")

        setActionButton(title: "Catch!", highlighted: true, hidden: false)

        // If ignored, the fish gets away after a few seconds.
        let escape = SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in self?.escapeBite() },
        ])
        run(escape, withKey: "biteTimeout")
    }

    func escapeBite() {
        guard fishingState == .biting, let fish = bitingFish else { return }
        fishingState = .waiting
        bitingFish = nil
        fish.swim(in: fish.wanderRect)
        startBobberBob()
        setActionButton(title: "Reel In", highlighted: false, hidden: false)
    }

    /// Hooked! Roll a catch with the equipped rod; a fish that's too big snaps the line.
    func catchFish() {
        guard fishingState == .biting, let fish = bitingFish else { return }
        removeAction(forKey: "biteTimeout")
        bobber?.removeAction(forKey: "tug")

        let rod = GameState.shared.equippedRod
        let candidate = fish.species.makeCatch(rod: rod, lure: GameState.shared.equippedLure)

        if candidate.weight > rod.maxLandable {
            lineSnapped(rod: rod, fish: fish)
            return
        }

        pendingCatch = candidate
        showCatchPopup(for: fish.species, catch: candidate)
    }

    /// The hooked fish was too heavy for the rod — it breaks free.
    private func lineSnapped(rod: Rod, fish: FishNode) {
        fishingState = .idle
        bitingFish = nil
        fish.swim(in: fish.wanderRect)
        removeBobber()
        setActionButton(title: "Reel In", highlighted: false, hidden: true)
        showToast("The line snapped! Too big for your \(rod.name).")
    }

    /// Brief camera-anchored message that fades away.
    func showToast(_ text: String) {
        let toast = SKNode()
        toast.zPosition = 250
        let label = SKLabelNode(fontNamed: uiFont)
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        let bg = SKShapeNode(rectOf: CGSize(width: label.frame.width + 40, height: 44), cornerRadius: 10)
        bg.fillColor = SKColor(red: 0.1, green: 0.12, blue: 0.18, alpha: 0.92)
        bg.strokeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        bg.lineWidth = 2
        toast.addChild(bg)
        toast.addChild(label)
        toast.position = CGPoint(x: 0, y: size.height / 2 - 90)
        cameraNode.addChild(toast)
        toast.run(.sequence([
            .wait(forDuration: 2.2),
            .fadeOut(withDuration: 0.4),
            .removeFromParent(),
        ]))
    }

    // MARK: - HUD

    func setupUI() {
        let button = SKNode()
        button.zPosition = 100
        button.isHidden = true

        let bg = SKShapeNode(rectOf: CGSize(width: 150, height: 56), cornerRadius: 12)
        bg.fillColor = SKColor(red: 0.12, green: 0.55, blue: 0.85, alpha: 0.95)
        bg.strokeColor = .white
        bg.lineWidth = 3
        button.addChild(bg)
        actionBG = bg

        let label = SKLabelNode(fontNamed: uiFont)
        label.text = "Reel In"
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        button.addChild(label)
        actionLabel = label

        // Bottom-right of the screen, clear of the centered player sprite.
        button.position = CGPoint(x: size.width / 2 - 95, y: -size.height / 2 + 55)
        cameraNode.addChild(button)
        actionButton = button

        setupTopHUD()
    }

    /// Top HUD: coins counter (left) and a Menu button (right).
    private func setupTopHUD() {
        let topY = size.height / 2 - 34

        // Coins.
        let coinHUD = SKNode()
        coinHUD.zPosition = 100
        let coin = SKShapeNode(circleOfRadius: 11)
        coin.fillColor = SKColor(red: 1.0, green: 0.83, blue: 0.30, alpha: 1)
        coin.strokeColor = SKColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1)
        coin.lineWidth = 2
        coin.position = CGPoint(x: -size.width / 2 + 26, y: topY)
        coinHUD.addChild(coin)

        let coins = SKLabelNode(fontNamed: uiFont)
        coins.fontSize = 20
        coins.fontColor = SKColor(red: 1.0, green: 0.92, blue: 0.6, alpha: 1)
        coins.verticalAlignmentMode = .center
        coins.horizontalAlignmentMode = .left
        coins.position = CGPoint(x: -size.width / 2 + 44, y: topY)
        coinHUD.addChild(coins)
        coinsLabel = coins
        cameraNode.addChild(coinHUD)
        updateCoinsHUD()

        // Menu button.
        let menu = SKNode()
        menu.zPosition = 100
        let bg = SKShapeNode(rectOf: CGSize(width: 96, height: 40), cornerRadius: 10)
        bg.fillColor = SKColor(red: 0.18, green: 0.22, blue: 0.30, alpha: 0.95)
        bg.strokeColor = .white
        bg.lineWidth = 2
        menu.addChild(bg)
        let label = SKLabelNode(fontNamed: uiFont)
        label.text = "Menu"
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        menu.addChild(label)
        menu.position = CGPoint(x: size.width / 2 - 60, y: topY)
        cameraNode.addChild(menu)
        menuButton = menu
    }

    func updateCoinsHUD() {
        coinsLabel?.text = "\(GameState.shared.coins)"
    }

    // MARK: - Menu overlay

    func openMenu() {
        guard menuOverlay == nil else { return }
        let overlay = GameMenuOverlay(size: size)
        overlay.onClose = { [weak self] in self?.closeMenu() }
        overlay.onMainMenu = { [weak self] in self?.goToMainMenu() }
        cameraNode.addChild(overlay)
        menuOverlay = overlay
    }

    func goToMainMenu() {
        let menu = MenuScene(size: size)
        menu.scaleMode = scaleMode
        view?.presentScene(menu, transition: .doorway(withDuration: 0.6))
    }

    func closeMenu() {
        menuOverlay?.removeFromParent()
        menuOverlay = nil
        updateCoinsHUD()
    }

    func setActionButton(title: String, highlighted: Bool, hidden: Bool) {
        actionLabel.text = title
        actionBG.fillColor = highlighted
            ? SKColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 0.98)
            : SKColor(red: 0.12, green: 0.55, blue: 0.85, alpha: 0.95)
        actionButton.isHidden = hidden
        actionButton.removeAction(forKey: "pulse")
        if highlighted && !hidden {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.3),
            ])
            actionButton.run(.repeatForever(pulse), withKey: "pulse")
        } else {
            actionButton.setScale(1.0)
        }
    }

    func handleActionButton() {
        switch fishingState {
        case .waiting: cancelFishing()
        case .biting:  catchFish()
        case .idle:    break
        }
    }

    // MARK: - Catch popup

    func showCatchPopup(for species: FishSpecies, catch fish: Fish) {
        let container = SKNode()
        container.zPosition = 200
        container.position = .zero  // camera center

        // Dim backdrop.
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55),
                               size: CGSize(width: size.width, height: size.height))
        dim.zPosition = 0
        container.addChild(dim)

        // Panel.
        let panelSize = CGSize(width: 340, height: 230)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.16, green: 0.20, blue: 0.28, alpha: 1)
        panel.strokeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        panel.lineWidth = 4
        panel.zPosition = 1
        container.addChild(panel)

        // Title.
        let title = SKLabelNode(fontNamed: uiFont)
        title.text = "Nice Catch!"
        title.fontSize = 24
        title.fontColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: panelSize.height / 2 - 34)
        title.zPosition = 2
        container.addChild(title)

        // Fish sprite (first frame of the species swim strip).
        let frames = animationFrames(sheet: species.asset, frameCount: species.frameCount)
        let fishSprite = SKSpriteNode(texture: frames.first)
        let px = frames.first?.size() ?? CGSize(width: 24, height: 12)
        let fishScale = min(120 / px.width, 70 / px.height, 4)
        fishSprite.size = CGSize(width: px.width * fishScale, height: px.height * fishScale)
        fishSprite.position = CGPoint(x: -panelSize.width / 2 + 90, y: 6)
        fishSprite.zPosition = 2
        container.addChild(fishSprite)

        // Stats.
        let stats = SKNode()
        stats.zPosition = 2
        container.addChild(stats)
        let lines = [fish.name, "Weight: \(fish.weightText)", "Length: \(fish.lengthText)",
                     "Value: \(fish.value)g"]
        var ly: CGFloat = 42
        for (i, text) in lines.enumerated() {
            let l = SKLabelNode(fontNamed: uiFont)
            l.text = text
            l.fontSize = i == 0 ? 20 : 16
            l.fontColor = .white
            l.horizontalAlignmentMode = .left
            l.position = CGPoint(x: 10, y: ly)
            stats.addChild(l)
            ly -= (i == 0 ? 34 : 26)
        }

        // Register Catch button.
        let reg = SKNode()
        reg.name = "registerButton"
        reg.zPosition = 2
        let regBG = SKShapeNode(rectOf: CGSize(width: 220, height: 48), cornerRadius: 10)
        regBG.fillColor = SKColor(red: 0.20, green: 0.70, blue: 0.40, alpha: 1)
        regBG.strokeColor = .white
        regBG.lineWidth = 2
        reg.addChild(regBG)
        let regLabel = SKLabelNode(fontNamed: uiFont)
        regLabel.text = "Register Catch"
        regLabel.fontSize = 20
        regLabel.fontColor = .white
        regLabel.verticalAlignmentMode = .center
        regLabel.horizontalAlignmentMode = .center
        reg.addChild(regLabel)
        reg.position = CGPoint(x: 0, y: -panelSize.height / 2 + 38)
        container.addChild(reg)
        registerButton = reg

        cameraNode.addChild(container)
        catchPopup = container

        // Pop-in animation.
        container.setScale(0.8)
        container.alpha = 0
        container.run(.group([.fadeIn(withDuration: 0.15),
                              .scale(to: 1.0, duration: 0.15)]))
    }

    func registerCatch() {
        if let c = pendingCatch { CatchLog.shared.add(c) }
        pendingCatch = nil

        catchPopup?.removeFromParent()
        catchPopup = nil
        registerButton = nil

        // Remove the caught fish and the bobber.
        if let fish = bitingFish {
            fishNodes.removeAll { $0 === fish }
            fish.removeFromParent()
        }
        bitingFish = nil
        removeBobber()

        fishingState = .idle
        setActionButton(title: "Reel In", highlighted: false, hidden: true)

        player.removeAction(forKey: "anim")
        let reel = SKAction.animate(with: hookFrames, timePerFrame: 0.1)
        player.run(reel) { [weak self] in self?.startIdle() }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // 0) Menu overlay is modal: route taps to it.
        if let overlay = menuOverlay {
            overlay.handleTap(sceneLocation: touch.location(in: self), from: self)
            return
        }

        // Menu button (camera space).
        if let menu = menuButton,
           menu.calculateAccumulatedFrame().contains(touch.location(in: cameraNode)) {
            openMenu()
            return
        }

        // 1) Modal catch popup: only the Register Catch button responds.
        if let popup = catchPopup {
            if let reg = registerButton,
               reg.calculateAccumulatedFrame().contains(touch.location(in: popup)) {
                registerCatch()
            }
            return
        }

        // 2) HUD action button (camera space).
        if let button = actionButton, !button.isHidden,
           button.calculateAccumulatedFrame().contains(touch.location(in: cameraNode)) {
            handleActionButton()
            return
        }

        let location = touch.location(in: self)

        // 3) Tapping the bobber while a fish is biting catches it.
        if fishingState == .biting, let bob = bobber,
           bob.calculateAccumulatedFrame().insetBy(dx: -24, dy: -24).contains(location) {
            catchFish()
            return
        }

        // 4) Idle: tap water to cast, tap sand to walk.
        if fishingState == .idle {
            if location.y > sandTopY {
                startCast(at: location)
            } else {
                movePlayer(to: location)
            }
        }
        // While waiting/biting, taps elsewhere are ignored — the player stays put.
    }

    // MARK: - Boundary rocks

    // Rock Pile pack: 6 color variants, 15 piles each, in BIG and small sizes.
    static let rockColors = ["AZURE", "BEIGE", "MOSSY", "ORANGE", "SILVER", "WHITE"]
    static let rockPileCount = 15

    /// Loads a random rock-pile sprite (random color each call).
    func randomRockTexture(big: Bool) -> SKTexture {
        let color = BeachScene.rockColors.randomElement()!
        let n = Int.random(in: 1...BeachScene.rockPileCount)
        let size = big ? "BIG" : "small"
        let tex = SKTexture(imageNamed: "RockPile_\(color)_\(n)_\(size)")
        tex.filteringMode = .nearest
        return tex
    }

    func addBoundaryMarkers() {
        addRockCluster(centerX: tileSize * 1.5)
        addRockCluster(centerX: mapWidth - tileSize * 1.5)
    }

    /// Builds an organic, jetty-style rock cluster centered on `centerX`.
    func addRockCluster(centerX: CGFloat) {
        let bottomY: CGFloat = -tileSize * 0.5
        let topY = CGFloat(sandRowCount + 2) * tileSize
        let span = topY - bottomY
        let baseScale: CGFloat = 1.4
        let layerCount = 8

        for i in 0..<layerCount {
            let t = CGFloat(i) / CGFloat(layerCount - 1)
            let layerY = bottomY + t * span
            let big = t > 0.33

            for j in 0..<2 {
                let tex = randomRockTexture(big: big)
                let rock = SKSpriteNode(texture: tex)

                let pixels = tex.size()
                let s = baseScale * CGFloat.random(in: 0.9...1.1)
                rock.size = CGSize(width: pixels.width * s, height: pixels.height * s)

                if Bool.random() { rock.xScale = -1 }

                let spread = (CGFloat(j) - 0.5) * tileSize * 1.1
                let xOffset = spread + CGFloat.random(in: -tileSize * 0.4...tileSize * 0.4)
                let yOffset = CGFloat.random(in: -tileSize * 0.35...tileSize * 0.35)
                rock.position = CGPoint(x: centerX + xOffset, y: layerY + yOffset)

                rock.zRotation = CGFloat.random(in: -0.08...0.08)
                rock.zPosition = 4 + (1 - t) * 4 + CGFloat.random(in: 0...0.3)
                rock.blendMode = .alpha
                addChild(rock)
            }
        }
    }
}
