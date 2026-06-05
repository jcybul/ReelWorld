//
//  OceanScene.swift
//  ReelWorld
//
//  Top-down trolling: you pilot a boat across open water by tapping to set a
//  course of waypoints. The boat trails two lures; trolling past pelagic fish
//  hooks them, then you reel them in. Ocean fish are big and valuable, so a
//  weak rod will usually snap the line.
//

import SpriteKit

final class OceanScene: SKScene {

    // MARK: - Map

    private let waterTile: CGFloat = 96
    private let mapColsTiles = 26
    private let mapRowsTiles = 20
    private var mapWidth: CGFloat { CGFloat(mapColsTiles) * waterTile }
    private var mapHeight: CGFloat { CGFloat(mapRowsTiles) * waterTile }

    // MARK: - Nodes

    private var cameraNode: SKCameraNode!
    private var boat: SKSpriteNode!
    private var lureLeft: SKSpriteNode!
    private var lureRight: SKSpriteNode!
    private var lineLeftShape: SKShapeNode!
    private var lineRightShape: SKShapeNode!
    private var routeLine: SKShapeNode!
    private var fishNodes: [FishNode] = []

    /// Seaweed beds: structure that creates current and concentrates fish.
    private var weedBeds: [CGPoint] = []
    private var currentAngle: CGFloat = 0

    /// Whether the trolling lines are deployed. No lines → no strikes.
    private var linesOut = false

    // MARK: - Navigation

    private var waypoints: [CGPoint] = []
    private var markers: [SKNode] = []
    private let boatSpeed: CGFloat = 95      // points / second while trolling
    private let arriveRadius: CGFloat = 18
    private var heading: CGFloat = .pi / 2     // radians; boat art points "up"
    private var lastUpdate: TimeInterval = 0

    // MARK: - State

    private enum OceanState { case idle, trolling, fishOn }
    private var state: OceanState = .idle
    private var hookedFish: FishNode?
    private var pendingCatch: Fish?

    private let strikeRadius: CGFloat = 64

    // MARK: - HUD

    private var actionButton: SKNode!
    private var actionBG: SKShapeNode!
    private var actionLabel: SKLabelNode!
    private var clearButton: SKNode!
    private var linesButton: SKNode!
    private var linesBG: SKShapeNode!
    private var linesLabel: SKLabelNode!
    private var coinsLabel: SKLabelNode!
    private var menuButton: SKNode!

    private var catchPopup: SKNode?
    private var registerButton: SKNode?
    private var menuOverlay: GameMenuOverlay?

    private let uiFont = "Menlo-Bold"

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.04, green: 0.18, blue: 0.34, alpha: 1)
        buildWater()
        buildWeedBeds()
        addBoat()
        setupCamera()
        setupUI()
        spawnFish()
        showHint("Tap the water to set a course.\nThen tap \"Lines Out\" and troll past fish to hook them!\nFish gather around the seaweed beds.")
    }

    // MARK: - Water

    private func buildWater() {
        let tex = SKTexture(imageNamed: "Water")
        tex.filteringMode = .nearest
        for row in 0..<mapRowsTiles {
            for col in 0..<mapColsTiles {
                let t = SKSpriteNode(texture: tex)
                t.size = CGSize(width: waterTile, height: waterTile)
                t.position = CGPoint(x: CGFloat(col) * waterTile + waterTile / 2,
                                     y: CGFloat(row) * waterTile + waterTile / 2)
                t.zPosition = 0
                addChild(t)
            }
        }

        // Route line, drawn under the boat.
        routeLine = SKShapeNode()
        routeLine.strokeColor = SKColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 0.5)
        routeLine.lineWidth = 2
        routeLine.lineCap = .round
        routeLine.zPosition = 2
        addChild(routeLine)
    }

    // MARK: - Seaweed beds & current

    private func buildWeedBeds() {
        currentAngle = CGFloat.random(in: 0..<(2 * .pi))
        addCurrentStreaks()

        let inset = waterTile * 2
        let beds = 6
        for _ in 0..<beds {
            let center = CGPoint(x: .random(in: inset...(mapWidth - inset)),
                                 y: .random(in: inset...(mapHeight - inset)))
            weedBeds.append(center)
            addWeedBed(at: center)
        }
    }

    /// Faint specks drifting with the current so you can read its direction.
    private func addCurrentStreaks() {
        let dir = CGVector(dx: cos(currentAngle), dy: sin(currentAngle))
        for _ in 0..<22 {
            let streak = SKShapeNode(rectOf: CGSize(width: 18, height: 2), cornerRadius: 1)
            streak.fillColor = SKColor(white: 1, alpha: 0.10)
            streak.strokeColor = .clear
            streak.zRotation = currentAngle
            streak.zPosition = 1.2
            streak.position = CGPoint(x: .random(in: 0...mapWidth), y: .random(in: 0...mapHeight))
            addChild(streak)
            driftStreak(streak, dir: dir)
        }
    }

    private func driftStreak(_ streak: SKShapeNode, dir: CGVector) {
        let dist: CGFloat = .random(in: 220...360)
        let dur = TimeInterval(dist / 26)
        let move = SKAction.moveBy(x: dir.dx * dist, y: dir.dy * dist, duration: dur)
        let reset = SKAction.run { [weak self] in
            guard let self else { return }
            streak.position = CGPoint(x: .random(in: 0...self.mapWidth),
                                      y: .random(in: 0...self.mapHeight))
        }
        streak.run(.repeatForever(.sequence([move, reset])))
    }

    private func addWeedBed(at center: CGPoint) {
        // Darker "structure" shadow under the bed.
        let shadow = SKShapeNode(circleOfRadius: .random(in: 52...78))
        shadow.fillColor = SKColor(red: 0.02, green: 0.12, blue: 0.20, alpha: 0.30)
        shadow.strokeColor = .clear
        shadow.position = center
        shadow.zPosition = 1
        addChild(shadow)

        // Sway leans with the current's horizontal component.
        let lean = max(-0.32, min(0.32, cos(currentAngle) * 0.4))
        let blades = Int.random(in: 7...11)
        for _ in 0..<blades {
            let kind = Bool.random() ? ObjectSheet.seaweed : ObjectSheet.greenAlgae
            let tex = ObjectSheet.icon(kind)
            let blade = SKSpriteNode(texture: tex)
            let s = CGFloat.random(in: 1.5...2.5)
            blade.size = CGSize(width: 32 * s, height: 32 * s)
            blade.anchorPoint = CGPoint(x: 0.5, y: 0.0)   // bends from its base
            blade.position = CGPoint(x: center.x + .random(in: -46...46),
                                     y: center.y + .random(in: -40...40))
            blade.zPosition = 1.5
            blade.zRotation = lean
            addChild(blade)

            let amp: CGFloat = .random(in: 0.10...0.18)
            let t = TimeInterval.random(in: 1.1...1.8)
            let sway = SKAction.sequence([
                .rotate(byAngle: amp, duration: t),
                .rotate(byAngle: -amp, duration: t),
            ])
            sway.timingMode = .easeInEaseOut
            blade.run(.repeatForever(sway))
        }
    }

    /// A small wander rect around a bed (clamped to the playable water).
    private func bedRect(_ center: CGPoint) -> CGRect {
        let inset = waterTile
        let full = CGRect(x: inset, y: inset, width: mapWidth - inset * 2, height: mapHeight - inset * 2)
        return CGRect(x: center.x - 95, y: center.y - 95, width: 190, height: 190).intersection(full)
    }

    // MARK: - Boat & lures

    private func addBoat() {
        let tex = SKTexture(imageNamed: "Boat2")
        tex.filteringMode = .nearest
        boat = SKSpriteNode(texture: tex)
        let px = tex.size()
        let scale: CGFloat = 1.1
        boat.size = CGSize(width: px.width * scale, height: px.height * scale)
        boat.position = CGPoint(x: mapWidth / 2, y: mapHeight / 2)
        boat.zPosition = 6
        boat.zRotation = heading - .pi / 2
        addChild(boat)

        lineLeftShape = makeLineShape()
        lineRightShape = makeLineShape()
        addChild(lineLeftShape)
        addChild(lineRightShape)

        lureLeft = makeLure()
        lureRight = makeLure()
        addChild(lureLeft)
        addChild(lureRight)

        refreshLureTextures()
        setLinesVisible(false)
        positionLures()
    }

    private func makeLure() -> SKSpriteNode {
        let lure = SKSpriteNode()
        lure.size = CGSize(width: 20, height: 20)
        lure.zPosition = 5
        return lure
    }

    private func makeLineShape() -> SKShapeNode {
        let line = SKShapeNode()
        line.strokeColor = SKColor(white: 1, alpha: 0.45)
        line.lineWidth = 1.5
        line.zPosition = 4.5
        return line
    }

    /// Updates the trailing lure sprites to show the currently equipped lure.
    private func refreshLureTextures() {
        let tex = GameState.shared.equippedLure.icon
        lureLeft.texture = tex
        lureRight.texture = tex
    }

    private func setLinesVisible(_ visible: Bool) {
        lureLeft.isHidden = !visible
        lureRight.isHidden = !visible
        lineLeftShape.isHidden = !visible
        lineRightShape.isHidden = !visible
    }

    /// Places the two trailing lures behind the boat's stern and draws the lines.
    private func positionLures() {
        let back = heading + .pi
        let sternDist: CGFloat = boat.size.height * 0.45
        let lineLen: CGFloat = linesOut ? 46 : 0
        let spread: CGFloat = 16
        let perp = heading + .pi / 2
        let stern = CGPoint(x: boat.position.x + cos(back) * sternDist,
                            y: boat.position.y + sin(back) * sternDist)
        let lureBack = CGPoint(x: stern.x + cos(back) * lineLen,
                               y: stern.y + sin(back) * lineLen)

        let lp = CGPoint(x: lureBack.x + cos(perp) * spread, y: lureBack.y + sin(perp) * spread)
        let rp = CGPoint(x: lureBack.x - cos(perp) * spread, y: lureBack.y - sin(perp) * spread)
        lureLeft.position = lp
        lureRight.position = rp

        if linesOut {
            let lpath = CGMutablePath(); lpath.move(to: stern); lpath.addLine(to: lp)
            lineLeftShape.path = lpath
            let rpath = CGMutablePath(); rpath.move(to: stern); rpath.addLine(to: rp)
            lineRightShape.path = rpath
        }
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = boat.position
        addChild(cameraNode)
        camera = cameraNode
    }

    private func clampedCamera(to p: CGPoint) -> CGPoint {
        let halfW = size.width / 2, halfH = size.height / 2
        let x = max(halfW, min(p.x, mapWidth - halfW))
        let y = max(halfH, min(p.y, mapHeight - halfH))
        return CGPoint(x: x, y: y)
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 20.0)
        lastUpdate = currentTime

        if state == .trolling { advanceBoat(dt: CGFloat(dt)) }
        positionLures()
        drawRoute()
        cameraNode.position = clampedCamera(to: boat.position)

        // Strikes only happen with the lines deployed and no fish already on.
        guard menuOverlay == nil, catchPopup == nil, linesOut, state != .fishOn else { return }
        checkStrikes(currentTime: currentTime)
    }

    private func advanceBoat(dt: CGFloat) {
        guard let target = waypoints.first else { state = .idle; return }
        let dx = target.x - boat.position.x
        let dy = target.y - boat.position.y
        let dist = hypot(dx, dy)

        if dist <= arriveRadius {
            waypoints.removeFirst()
            if !markers.isEmpty { markers.removeFirst().removeFromParent() }
            renumberMarkers()
            if waypoints.isEmpty { state = .idle; updateActionButton() }
            return
        }

        // Smoothly rotate toward the target heading.
        let desired = atan2(dy, dx)
        heading = lerpAngle(heading, desired, t: min(1, 6 * dt))
        boat.zRotation = heading - .pi / 2

        let step = min(boatSpeed * dt, dist)
        boat.position = CGPoint(x: boat.position.x + cos(heading) * step,
                                y: boat.position.y + sin(heading) * step)
    }

    private func checkStrikes(currentTime: TimeInterval) {
        for fish in fishNodes {
            if currentTime < fish.nextBiteCheck { continue }
            fish.nextBiteCheck = currentTime + Double.random(in: 1.0...2.0)
            let dl = hypot(fish.position.x - lureLeft.position.x, fish.position.y - lureLeft.position.y)
            let dr = hypot(fish.position.x - lureRight.position.x, fish.position.y - lureRight.position.y)
            let chance = 0.4 * GameState.shared.equippedLure.attraction
            if min(dl, dr) <= strikeRadius && Double.random(in: 0...1) < chance {
                strike(fish)
                break
            }
        }
    }

    // MARK: - Fish

    private func spawnFish() {
        let inset = waterTile
        let full = CGRect(x: inset, y: inset,
                          width: mapWidth - inset * 2, height: mapHeight - inset * 2)

        // Most fish gather on the seaweed beds; a few roam the open water.
        for bed in weedBeds {
            let rect = bedRect(bed)
            for _ in 0..<Int.random(in: 2...3) { addFish(in: rect.isEmpty ? full : rect) }
        }
        for _ in 0..<3 { addFish(in: full) }
    }

    /// A wander rect to respawn into — favors a random bed to keep them stocked.
    private func restockRect() -> CGRect {
        let inset = waterTile
        let full = CGRect(x: inset, y: inset, width: mapWidth - inset * 2, height: mapHeight - inset * 2)
        if let bed = weedBeds.randomElement() {
            let r = bedRect(bed)
            return r.isEmpty ? full : r
        }
        return full
    }

    private func addFish(in rect: CGRect) {
        guard let species = FishSpecies.ocean.randomElement() else { return }
        let frames = animationFrames(sheet: species.asset, frameCount: species.frameCount)
        let fish = FishNode(texture: frames.first)
        fish.species = species
        fish.name = "fish"

        // Scale pelagics up so the trophies read as genuinely bigger.
        let scale: CGFloat = species.weightMedian > 50 ? 2.6 : (species.weightMedian > 8 ? 2.1 : 1.7)
        let px = frames.first?.size() ?? CGSize(width: 24, height: 12)
        fish.size = CGSize(width: px.width * scale, height: px.height * scale)
        fish.position = CGPoint(x: .random(in: rect.minX...rect.maxX),
                                y: .random(in: rect.minY...rect.maxY))
        fish.zPosition = 4
        fish.alpha = 0
        if frames.count > 1 {
            fish.run(.repeatForever(.animate(with: frames, timePerFrame: 0.28)), withKey: "anim")
        }
        addChild(fish)
        fish.swim(in: rect)
        fishNodes.append(fish)
    }

    private func animationFrames(sheet name: String, frameCount: Int) -> [SKTexture] {
        let sheet = SKTexture(imageNamed: name)
        sheet.filteringMode = .nearest
        let w = 1.0 / CGFloat(frameCount)
        return (0..<frameCount).map { i in
            let tex = SKTexture(rect: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: 1), in: sheet)
            tex.filteringMode = .nearest
            return tex
        }
    }

    // MARK: - Strike / reel

    private func strike(_ fish: FishNode) {
        state = .fishOn
        hookedFish = fish
        fish.removeAction(forKey: "swim")

        // Drag the fish to the nearer lure and make it thrash.
        let dl = hypot(fish.position.x - lureLeft.position.x, fish.position.y - lureLeft.position.y)
        let dr = hypot(fish.position.x - lureRight.position.x, fish.position.y - lureRight.position.y)
        let lure = dl <= dr ? lureLeft! : lureRight!
        fish.run(.move(to: lure.position, duration: 0.3))
        let thrash = SKAction.sequence([.rotate(byAngle: 0.25, duration: 0.1),
                                        .rotate(byAngle: -0.25, duration: 0.1)])
        fish.run(.repeatForever(thrash), withKey: "thrash")

        updateActionButton()
        showToast("Fish on! Reel it in!")

        let escape = SKAction.sequence([.wait(forDuration: 4.5),
                                        .run { [weak self] in self?.fishEscaped() }])
        run(escape, withKey: "fishOnTimeout")
    }

    private func fishEscaped() {
        guard state == .fishOn, let fish = hookedFish else { return }
        fish.removeAction(forKey: "thrash")
        fish.zRotation = 0
        fish.swim(in: fish.wanderRect)
        hookedFish = nil
        resumeTrolling()
        showToast("It got away…")
    }

    private func reelIn() {
        guard state == .fishOn, let fish = hookedFish else { return }
        removeAction(forKey: "fishOnTimeout")

        let rod = GameState.shared.equippedRod
        let candidate = fish.species.makeCatch(rod: rod, lure: GameState.shared.equippedLure)

        if candidate.weight > rod.maxLandable {
            fish.removeAction(forKey: "thrash")
            fish.zRotation = 0
            fish.swim(in: fish.wanderRect)
            hookedFish = nil
            resumeTrolling()
            showToast("Line snapped! \(fish.species.name) was too strong for your \(rod.name).")
            return
        }

        pendingCatch = candidate
        showCatchPopup(for: fish.species, catch: candidate)
    }

    /// Returns the boat to trolling if a route remains, otherwise idles it.
    private func resumeTrolling() {
        state = waypoints.isEmpty ? .idle : .trolling
        lastUpdate = 0   // avoid a dt spike after the pause
        updateActionButton()
    }

    // MARK: - Route drawing

    private func drawRoute() {
        guard !waypoints.isEmpty else { routeLine.path = nil; return }
        let path = CGMutablePath()
        path.move(to: boat.position)
        for wp in waypoints { path.addLine(to: wp) }
        routeLine.path = path
    }

    private func addWaypoint(_ p: CGPoint) {
        let clamped = CGPoint(x: min(max(p.x, 20), mapWidth - 20),
                              y: min(max(p.y, 20), mapHeight - 20))
        waypoints.append(clamped)

        let marker = SKNode()
        marker.position = clamped
        marker.zPosition = 3
        let ring = SKShapeNode(circleOfRadius: 13)
        ring.fillColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 0.9)
        ring.strokeColor = .white
        ring.lineWidth = 2
        marker.addChild(ring)
        let num = SKLabelNode(fontNamed: uiFont)
        num.fontSize = 15
        num.fontColor = SKColor(red: 0.2, green: 0.13, blue: 0.04, alpha: 1)
        num.verticalAlignmentMode = .center
        num.horizontalAlignmentMode = .center
        marker.addChild(num)
        addChild(marker)
        markers.append(marker)
        renumberMarkers()

        if state == .idle { state = .trolling }
        lastUpdate = 0
        updateActionButton()
    }

    private func renumberMarkers() {
        for (i, marker) in markers.enumerated() {
            if let label = marker.children.compactMap({ $0 as? SKLabelNode }).first {
                label.text = "\(i + 1)"
            }
        }
    }

    private func clearRoute() {
        waypoints.removeAll()
        markers.forEach { $0.removeFromParent() }
        markers.removeAll()
        routeLine.path = nil
        if state == .trolling { state = .idle }
        updateActionButton()
    }

    // MARK: - HUD

    private func setupUI() {
        // Reel-in action button (bottom-right), hidden until a fish is on.
        let button = SKNode()
        button.zPosition = 100
        button.isHidden = true
        let bg = SKShapeNode(rectOf: CGSize(width: 160, height: 56), cornerRadius: 12)
        bg.strokeColor = .white
        bg.lineWidth = 3
        button.addChild(bg)
        actionBG = bg
        let label = SKLabelNode(fontNamed: uiFont)
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        button.addChild(label)
        actionLabel = label
        button.position = CGPoint(x: size.width / 2 - 100, y: -size.height / 2 + 55)
        cameraNode.addChild(button)
        actionButton = button

        // Clear-route button (bottom-left), hidden until a route exists.
        let clear = SKNode()
        clear.zPosition = 100
        clear.isHidden = true
        let cbg = SKShapeNode(rectOf: CGSize(width: 130, height: 44), cornerRadius: 10)
        cbg.fillColor = SKColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 0.95)
        cbg.strokeColor = .white
        cbg.lineWidth = 2
        clear.addChild(cbg)
        let clabel = SKLabelNode(fontNamed: uiFont)
        clabel.text = "Clear Route"
        clabel.fontSize = 16
        clabel.fontColor = .white
        clabel.verticalAlignmentMode = .center
        clabel.horizontalAlignmentMode = .center
        clear.addChild(clabel)
        clear.position = CGPoint(x: -size.width / 2 + 85, y: -size.height / 2 + 45)
        cameraNode.addChild(clear)
        clearButton = clear

        // Lines Out / In toggle (bottom-center).
        let lines = SKNode()
        lines.zPosition = 100
        let lbg = SKShapeNode(rectOf: CGSize(width: 150, height: 50), cornerRadius: 12)
        lbg.strokeColor = .white
        lbg.lineWidth = 3
        lines.addChild(lbg)
        linesBG = lbg
        let llabel = SKLabelNode(fontNamed: uiFont)
        llabel.fontSize = 20
        llabel.fontColor = .white
        llabel.verticalAlignmentMode = .center
        llabel.horizontalAlignmentMode = .center
        lines.addChild(llabel)
        linesLabel = llabel
        lines.position = CGPoint(x: 0, y: -size.height / 2 + 50)
        cameraNode.addChild(lines)
        linesButton = lines

        setupTopHUD()
        updateActionButton()
        updateLinesButton()
    }

    private func updateLinesButton() {
        linesLabel.text = linesOut ? "Lines In" : "Lines Out"
        linesBG.fillColor = linesOut
            ? SKColor(red: 0.85, green: 0.55, blue: 0.20, alpha: 0.97)
            : SKColor(red: 0.15, green: 0.55, blue: 0.45, alpha: 0.97)
        // Hidden while reeling a fish — you can't pull the lines until it's resolved.
        linesButton.isHidden = (state == .fishOn)
    }

    private func toggleLines() {
        linesOut.toggle()
        setLinesVisible(linesOut)
        positionLures()
        updateLinesButton()
        showToast(linesOut ? "Lines out — troll past fish to hook them!" : "Lines in.")
    }

    private func setupTopHUD() {
        let topY = size.height / 2 - 34

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

    private func updateCoinsHUD() { coinsLabel?.text = "\(GameState.shared.coins)" }

    private func updateActionButton() {
        if state == .fishOn {
            actionButton.isHidden = false
            actionLabel.text = "Reel In!"
            actionBG.fillColor = SKColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 0.98)
            actionButton.removeAction(forKey: "pulse")
            let pulse = SKAction.sequence([.scale(to: 1.1, duration: 0.3),
                                           .scale(to: 1.0, duration: 0.3)])
            actionButton.run(.repeatForever(pulse), withKey: "pulse")
        } else {
            actionButton.isHidden = true
            actionButton.removeAction(forKey: "pulse")
            actionButton.setScale(1.0)
        }
        clearButton.isHidden = waypoints.isEmpty
        updateLinesButton()
    }

    // MARK: - Menu overlay

    private func openMenu() {
        guard menuOverlay == nil else { return }
        let overlay = GameMenuOverlay(size: size)
        overlay.onClose = { [weak self] in self?.closeMenu() }
        overlay.onMainMenu = { [weak self] in self?.goToMainMenu() }
        cameraNode.addChild(overlay)
        menuOverlay = overlay
    }

    private func goToMainMenu() {
        let menu = MenuScene(size: size)
        menu.scaleMode = scaleMode
        view?.presentScene(menu, transition: .doorway(withDuration: 0.6))
    }

    private func closeMenu() {
        menuOverlay?.removeFromParent()
        menuOverlay = nil
        updateCoinsHUD()
        refreshLureTextures()   // the player may have switched lures in the menu
    }

    // MARK: - Catch popup

    private func showCatchPopup(for species: FishSpecies, catch fish: Fish) {
        let container = SKNode()
        container.zPosition = 200

        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55), size: size)
        container.addChild(dim)

        let panelSize = CGSize(width: 360, height: 240)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.10, green: 0.20, blue: 0.30, alpha: 1)
        panel.strokeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        panel.lineWidth = 4
        container.addChild(panel)

        let title = SKLabelNode(fontNamed: uiFont)
        title.text = "Trophy Catch!"
        title.fontSize = 24
        title.fontColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: panelSize.height / 2 - 34)
        container.addChild(title)

        let frames = animationFrames(sheet: species.asset, frameCount: species.frameCount)
        let sprite = SKSpriteNode(texture: frames.first)
        let px = frames.first?.size() ?? CGSize(width: 24, height: 12)
        let fishScale = min(150 / px.width, 80 / px.height, 5)
        sprite.size = CGSize(width: px.width * fishScale, height: px.height * fishScale)
        sprite.position = CGPoint(x: -panelSize.width / 2 + 95, y: 6)
        container.addChild(sprite)

        let lines = [fish.name, "Weight: \(fish.weightText)", "Length: \(fish.lengthText)",
                     "Value: \(fish.value)g"]
        var ly: CGFloat = 44
        for (i, text) in lines.enumerated() {
            let l = SKLabelNode(fontNamed: uiFont)
            l.text = text
            l.fontSize = i == 0 ? 20 : 16
            l.fontColor = .white
            l.horizontalAlignmentMode = .left
            l.position = CGPoint(x: 6, y: ly)
            container.addChild(l)
            ly -= (i == 0 ? 34 : 26)
        }

        let reg = SKNode()
        reg.name = "registerButton"
        let regBG = SKShapeNode(rectOf: CGSize(width: 230, height: 48), cornerRadius: 10)
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
        container.setScale(0.8)
        container.alpha = 0
        container.run(.group([.fadeIn(withDuration: 0.15), .scale(to: 1.0, duration: 0.15)]))
    }

    private func registerCatch() {
        if let c = pendingCatch { CatchLog.shared.add(c) }
        pendingCatch = nil
        catchPopup?.removeFromParent()
        catchPopup = nil
        registerButton = nil

        if let fish = hookedFish {
            fishNodes.removeAll { $0 === fish }
            fish.removeFromParent()
        }
        hookedFish = nil

        // Re-stock so the ocean never empties out (favor the weed beds).
        addFish(in: restockRect())

        resumeTrolling()
        updateCoinsHUD()
    }

    // MARK: - Feedback

    private func showToast(_ text: String) {
        let toast = SKNode()
        toast.zPosition = 250
        let label = SKLabelNode(fontNamed: uiFont)
        label.text = text
        label.fontSize = 17
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        let bg = SKShapeNode(rectOf: CGSize(width: label.frame.width + 40, height: 42), cornerRadius: 10)
        bg.fillColor = SKColor(red: 0.06, green: 0.12, blue: 0.20, alpha: 0.92)
        bg.strokeColor = SKColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
        bg.lineWidth = 2
        toast.addChild(bg)
        toast.addChild(label)
        toast.position = CGPoint(x: 0, y: size.height / 2 - 90)
        cameraNode.addChild(toast)
        toast.run(.sequence([.wait(forDuration: 2.2), .fadeOut(withDuration: 0.4), .removeFromParent()]))
    }

    private func showHint(_ text: String) {
        let hint = SKLabelNode(fontNamed: uiFont)
        hint.numberOfLines = 0
        hint.preferredMaxLayoutWidth = size.width - 80
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode = .center
        hint.fontSize = 17
        hint.fontColor = SKColor(white: 1, alpha: 0.95)
        hint.text = text
        hint.zPosition = 90
        hint.position = CGPoint(x: 0, y: -size.height / 2 + 130)
        cameraNode.addChild(hint)
        hint.run(.sequence([.wait(forDuration: 4.0), .fadeOut(withDuration: 0.8), .removeFromParent()]))
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if let overlay = menuOverlay {
            overlay.handleTap(sceneLocation: touch.location(in: self), from: self)
            return
        }

        let camLoc = touch.location(in: cameraNode)

        if menuButton.calculateAccumulatedFrame().contains(camLoc) { openMenu(); return }

        if let popup = catchPopup {
            if let reg = registerButton,
               reg.calculateAccumulatedFrame().contains(touch.location(in: popup)) {
                registerCatch()
            }
            return
        }

        if state == .fishOn {
            // Reel-in button, or just tap the thrashing fish.
            if actionButton.calculateAccumulatedFrame().contains(camLoc) { reelIn(); return }
            let loc = touch.location(in: self)
            if let fish = hookedFish,
               fish.calculateAccumulatedFrame().insetBy(dx: -30, dy: -30).contains(loc) {
                reelIn()
            }
            return
        }

        if !clearButton.isHidden, clearButton.calculateAccumulatedFrame().contains(camLoc) {
            clearRoute(); return
        }

        if !linesButton.isHidden, linesButton.calculateAccumulatedFrame().contains(camLoc) {
            toggleLines(); return
        }

        // Otherwise: tap the water to add a waypoint.
        addWaypoint(touch.location(in: self))
    }

    // MARK: - Math

    /// Interpolates between two angles along the shortest arc.
    private func lerpAngle(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        var diff = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if diff > .pi { diff -= 2 * .pi }
        if diff < -.pi { diff += 2 * .pi }
        return a + diff * t
    }
}
