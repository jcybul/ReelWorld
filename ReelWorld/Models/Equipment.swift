//
//  Equipment.swift
//  ReelWorld
//
//  Fishing rods + lures (equipment) and the persistent player economy/state.
//

import Foundation
import SpriteKit

/// Crops icons out of the shared 6×6 "fishing_gear" pixel-art sheet (32px cells,
/// ordered left-to-right, top-to-bottom — same numbering as the asset pack).
enum GearSheet {
    static let columns = 6
    static let rows = 6

    /// Texture for a 1-based gear index (1 = top-left).
    static func icon(_ index1: Int) -> SKTexture {
        let i = index1 - 1
        let col = i % columns
        let row = i / columns
        let w = 1.0 / CGFloat(columns)
        let h = 1.0 / CGFloat(rows)
        // SKTexture rects are normalized with a bottom-left origin, so flip the row.
        let rect = CGRect(x: CGFloat(col) * w, y: 1.0 - CGFloat(row + 1) * h, width: w, height: h)
        let sheet = SKTexture(imageNamed: "fishing_gear")
        sheet.filteringMode = .nearest
        let tex = SKTexture(rect: rect, in: sheet)
        tex.filteringMode = .nearest
        return tex
    }
}

/// Crops icons out of the shared 5×4 "fishing_objects" sheet (32px cells).
/// Cell 1 = green algae, 2 = red algae/coral, 3 = seaweed.
enum ObjectSheet {
    static let columns = 5
    static let rows = 4

    static func icon(_ index1: Int) -> SKTexture {
        let i = index1 - 1
        let col = i % columns
        let row = i / columns
        let w = 1.0 / CGFloat(columns)
        let h = 1.0 / CGFloat(rows)
        let rect = CGRect(x: CGFloat(col) * w, y: 1.0 - CGFloat(row + 1) * h, width: w, height: h)
        let sheet = SKTexture(imageNamed: "fishing_objects")
        sheet.filteringMode = .nearest
        let tex = SKTexture(rect: rect, in: sheet)
        tex.filteringMode = .nearest
        return tex
    }

    static let greenAlgae = 1
    static let redAlgae = 2
    static let seaweed = 3
}

/// A fishing rod. Higher tiers bias catches heavier (`weightBias`) and can land
/// bigger fish (`maxLandable`); a fish heavier than the rod's limit snaps the line.
struct Rod {
    let id: String
    let name: String
    let price: Int
    let power: Double         // 1.0 = starter; drives weightBias
    let maxLandable: Double   // kg the rod can land before the line snaps
    let iconIndex: Int        // cell in the fishing_gear sheet
    let blurb: String

    /// Multiplier applied to a rolled weight — better rods hook heavier fish.
    var weightBias: Double { 1.0 + 0.35 * (power - 1.0) }

    var maxLandableText: String {
        maxLandable >= 900 ? "Any size" : String(format: "%.0f kg", maxLandable)
    }

    var icon: SKTexture { GearSheet.icon(iconIndex) }

    static let all: [Rod] = [
        Rod(id: "twig", name: "Wooden Rod", price: 0, power: 1.0, maxLandable: 2.0,
            iconIndex: 1, blurb: "A simple wooden rod. It'll do."),
        Rod(id: "bamboo", name: "Bamboo Rod", price: 60, power: 1.3, maxLandable: 5.0,
            iconIndex: 2, blurb: "Springy and reliable for bigger pan fish."),
        Rod(id: "fiberglass", name: "Fiberglass Rod", price: 250, power: 1.7, maxLandable: 14.0,
            iconIndex: 4, blurb: "Handles real fighters without snapping."),
        Rod(id: "carbon", name: "Carbon Pro", price: 750, power: 2.3, maxLandable: 45.0,
            iconIndex: 5, blurb: "Tournament-grade. Pulls in trophy fish."),
        Rod(id: "abyssal", name: "Steel Deepsea", price: 2500, power: 3.2, maxLandable: 999.0,
            iconIndex: 3, blurb: "Built to haul up anything that swims."),
    ]

    static let byID: [String: Rod] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let starter = all[0]
}

/// A lure/bait. Lures drive how often fish strike (`attraction`) and nudge the
/// average size you reel in (`sizeBias`). They matter most when trolling.
struct Lure {
    let id: String
    let name: String
    let price: Int
    let attraction: Double   // multiplier on strike/bite chance
    let sizeBias: Double     // multiplier on rolled weight
    let iconIndex: Int
    let blurb: String

    var icon: SKTexture { GearSheet.icon(iconIndex) }

    var attractionText: String { String(format: "%.0f%% bites", attraction * 100) }
    var sizeText: String {
        sizeBias == 1 ? "avg size" : String(format: "%+.0f%% size", (sizeBias - 1) * 100)
    }

    static let all: [Lure] = [
        Lure(id: "jig", name: "Jig", price: 0, attraction: 1.0, sizeBias: 1.0,
             iconIndex: 8, blurb: "All-round starter lure. Steady bites."),
        Lure(id: "fly", name: "Fly", price: 40, attraction: 1.35, sizeBias: 0.95,
             iconIndex: 9, blurb: "Irresistible — lots of bites, smaller fish."),
        Lure(id: "crank", name: "Crankbait", price: 180, attraction: 0.95, sizeBias: 1.18,
             iconIndex: 10, blurb: "Dives deep and tempts the bigger ones."),
        Lure(id: "spinner", name: "Spinner", price: 500, attraction: 1.5, sizeBias: 1.12,
             iconIndex: 11, blurb: "Flash and vibration the trophies can't resist."),
    ]

    static let byID: [String: Lure] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let starter = all[0]
}

/// Persistent player state: coins, owned/equipped rods and lures.
final class GameState {
    static let shared = GameState()

    private let coinsKey = "reelworld.coins"
    private let ownedKey = "reelworld.ownedRods"
    private let equippedKey = "reelworld.equippedRod"
    private let ownedLuresKey = "reelworld.ownedLures"
    private let equippedLureKey = "reelworld.equippedLure"

    private(set) var coins: Int
    private(set) var ownedRodIDs: Set<String>
    private(set) var equippedRodID: String
    private(set) var ownedLureIDs: Set<String>
    private(set) var equippedLureID: String

    private init() {
        let defaults = UserDefaults.standard
        coins = defaults.integer(forKey: coinsKey)

        if let arr = defaults.array(forKey: ownedKey) as? [String], !arr.isEmpty {
            ownedRodIDs = Set(arr)
        } else {
            ownedRodIDs = [Rod.starter.id]
        }
        equippedRodID = defaults.string(forKey: equippedKey) ?? Rod.starter.id

        if let arr = defaults.array(forKey: ownedLuresKey) as? [String], !arr.isEmpty {
            ownedLureIDs = Set(arr)
        } else {
            ownedLureIDs = [Lure.starter.id]
        }
        equippedLureID = defaults.string(forKey: equippedLureKey) ?? Lure.starter.id
    }

    // MARK: Coins

    func addCoins(_ amount: Int) {
        coins = max(0, coins + amount)
        UserDefaults.standard.set(coins, forKey: coinsKey)
    }

    // MARK: Rods

    var equippedRod: Rod { Rod.byID[equippedRodID] ?? Rod.starter }
    func owns(_ id: String) -> Bool { ownedRodIDs.contains(id) }

    @discardableResult
    func buy(_ rod: Rod) -> Bool {
        guard !owns(rod.id), coins >= rod.price else { return false }
        addCoins(-rod.price)
        ownedRodIDs.insert(rod.id)
        UserDefaults.standard.set(Array(ownedRodIDs), forKey: ownedKey)
        return true
    }

    func equip(_ id: String) {
        guard owns(id) else { return }
        equippedRodID = id
        UserDefaults.standard.set(id, forKey: equippedKey)
    }

    // MARK: Lures

    var equippedLure: Lure { Lure.byID[equippedLureID] ?? Lure.starter }
    func ownsLure(_ id: String) -> Bool { ownedLureIDs.contains(id) }

    @discardableResult
    func buyLure(_ lure: Lure) -> Bool {
        guard !ownsLure(lure.id), coins >= lure.price else { return false }
        addCoins(-lure.price)
        ownedLureIDs.insert(lure.id)
        UserDefaults.standard.set(Array(ownedLureIDs), forKey: ownedLuresKey)
        return true
    }

    func equipLure(_ id: String) {
        guard ownsLure(id) else { return }
        equippedLureID = id
        UserDefaults.standard.set(id, forKey: equippedLureKey)
    }
}
