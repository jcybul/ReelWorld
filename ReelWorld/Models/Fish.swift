//
//  Fish.swift
//  ReelWorld
//
//  Created by Joseph Cybul zebede  on 6/5/26.
//

import Foundation
import CoreGraphics

/// Which body of water a fish belongs to.
enum WaterZone: String, Codable, CaseIterable {
    case beach, ocean, lake
}

/// A single caught fish, persisted in the catalog.
struct Fish: Codable {
    let species: String   // stable id, e.g. "trout"
    let name: String      // display name, e.g. "Rainbow Trout"
    let weight: Double    // kilograms
    let length: Double    // centimeters
    let zone: WaterZone
    let date: Date

    /// Pretty weight string (kg, or g for very small fish).
    var weightText: String {
        weight < 1 ? String(format: "%.0f g", weight * 1000)
                   : String(format: "%.2f kg", weight)
    }

    var lengthText: String { String(format: "%.0f cm", length) }

    /// Coin value of this fish, based on its species' price-per-kg and weight.
    var value: Int { FishSpecies.value(species: species, weight: weight) }
}

/// Static description of a species: where it lives, how it looks, and the
/// realistic distributions used to roll a catch's weight and length.
struct FishSpecies {
    let species: String
    let name: String
    let asset: String        // imageset name (a 2-frame horizontal swim strip)
    let frameCount: Int
    let prefersDeep: Bool     // deep water vs shallow
    let zone: WaterZone

    // Weight is drawn from a log-normal distribution (always positive, right-skewed
    // like real fish populations). `weightMedian` is the median in kg.
    let weightMedian: Double
    let weightSigma: Double   // spread in log-space

    // Length range in centimeters.
    let lengthMin: Double
    let lengthMax: Double

    // Sell value per kilogram (coins).
    let pricePerKg: Double

    /// Log-normal weight in kilograms, optionally biased heavier by a better rod.
    func rollWeight(bias: Double = 1.0) -> Double {
        let z = FishSpecies.standardNormal()
        return weightMedian * exp(weightSigma * z) * bias
    }

    /// Length in cm, tilted toward the top of the range as the rod gets stronger.
    func rollLength(power: Double = 1.0) -> Double {
        let tilt = min(0.45, 0.15 * (power - 1.0))
        let t = min(1.0, Double.random(in: 0...1) * (1 - tilt) + tilt)
        return lengthMin + (lengthMax - lengthMin) * t
    }

    /// Builds a catch record, with the equipped rod and lure biasing size/weight.
    func makeCatch(rod: Rod, lure: Lure) -> Fish {
        Fish(species: species, name: name,
             weight: rollWeight(bias: rod.weightBias * lure.sizeBias),
             length: rollLength(power: rod.power),
             zone: zone, date: Date())
    }

    /// Box–Muller standard normal sample.
    static func standardNormal() -> Double {
        let u1 = Double.random(in: 1e-12...1)
        let u2 = Double.random(in: 0...1)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    /// Lookup of every known species by id (across all zones).
    static let byID: [String: FishSpecies] =
        Dictionary(uniqueKeysWithValues: (beach + ocean).map { ($0.species, $0) })

    /// Coin value for a caught fish of the given species/weight.
    static func value(species: String, weight: Double) -> Int {
        let perKg = byID[species]?.pricePerKg ?? 10
        return max(1, Int((weight * perKg).rounded()))
    }
}

extension FishSpecies {
    /// Species available at the Beach. Assets are the "Catch" swim strips.
    static let beach: [FishSpecies] = [
        FishSpecies(species: "sardine", name: "Sardine", asset: "CatchFish_2",
                    frameCount: 2, prefersDeep: false, zone: .beach,
                    weightMedian: 0.05, weightSigma: 0.35, lengthMin: 8, lengthMax: 16,
                    pricePerKg: 40),
        FishSpecies(species: "perch", name: "Sand Perch", asset: "CatchFish_3",
                    frameCount: 2, prefersDeep: false, zone: .beach,
                    weightMedian: 0.30, weightSigma: 0.40, lengthMin: 15, lengthMax: 30,
                    pricePerKg: 30),
        FishSpecies(species: "herring", name: "Herring", asset: "CatchFish_4",
                    frameCount: 2, prefersDeep: false, zone: .beach,
                    weightMedian: 0.18, weightSigma: 0.35, lengthMin: 12, lengthMax: 26,
                    pricePerKg: 35),
        FishSpecies(species: "trout", name: "Sea Trout", asset: "CatchFish_7",
                    frameCount: 2, prefersDeep: true, zone: .beach,
                    weightMedian: 1.20, weightSigma: 0.50, lengthMin: 30, lengthMax: 60,
                    pricePerKg: 25),
        FishSpecies(species: "bass", name: "Striped Bass", asset: "CatchFish_8",
                    frameCount: 2, prefersDeep: true, zone: .beach,
                    weightMedian: 1.60, weightSigma: 0.50, lengthMin: 32, lengthMax: 58,
                    pricePerKg: 28),
        FishSpecies(species: "angler", name: "Anglerfish", asset: "CatchFish_5",
                    frameCount: 2, prefersDeep: true, zone: .beach,
                    weightMedian: 3.00, weightSigma: 0.50, lengthMin: 40, lengthMax: 80,
                    pricePerKg: 45),
        FishSpecies(species: "shark", name: "Reef Shark", asset: "CatchFish_6",
                    frameCount: 2, prefersDeep: true, zone: .beach,
                    weightMedian: 14.0, weightSigma: 0.40, lengthMin: 100, lengthMax: 180,
                    pricePerKg: 55),
    ]

    /// Open-ocean pelagics — bigger, faster, and worth far more. You troll for
    /// these from the boat, so most need a serious rod to land.
    static let ocean: [FishSpecies] = [
        FishSpecies(species: "mackerel", name: "Atlantic Mackerel", asset: "CatchFish_3",
                    frameCount: 2, prefersDeep: false, zone: .ocean,
                    weightMedian: 0.5, weightSigma: 0.40, lengthMin: 25, lengthMax: 45,
                    pricePerKg: 35),
        FishSpecies(species: "mahi", name: "Mahi-Mahi", asset: "CatchFish_5",
                    frameCount: 2, prefersDeep: false, zone: .ocean,
                    weightMedian: 7.0, weightSigma: 0.45, lengthMin: 70, lengthMax: 120,
                    pricePerKg: 45),
        FishSpecies(species: "wahoo", name: "Wahoo", asset: "CatchFish_8",
                    frameCount: 2, prefersDeep: false, zone: .ocean,
                    weightMedian: 12.0, weightSigma: 0.45, lengthMin: 100, lengthMax: 170,
                    pricePerKg: 50),
        FishSpecies(species: "yellowfin", name: "Yellowfin Tuna", asset: "CatchFish_7",
                    frameCount: 2, prefersDeep: true, zone: .ocean,
                    weightMedian: 25.0, weightSigma: 0.50, lengthMin: 100, lengthMax: 180,
                    pricePerKg: 55),
        FishSpecies(species: "swordfish", name: "Swordfish", asset: "CatchFish_6",
                    frameCount: 2, prefersDeep: true, zone: .ocean,
                    weightMedian: 90.0, weightSigma: 0.50, lengthMin: 200, lengthMax: 350,
                    pricePerKg: 60),
        FishSpecies(species: "bluefin", name: "Bluefin Tuna", asset: "CatchFish_5",
                    frameCount: 2, prefersDeep: true, zone: .ocean,
                    weightMedian: 120.0, weightSigma: 0.50, lengthMin: 150, lengthMax: 300,
                    pricePerKg: 70),
        FishSpecies(species: "mako", name: "Mako Shark", asset: "CatchFish_6",
                    frameCount: 2, prefersDeep: true, zone: .ocean,
                    weightMedian: 90.0, weightSigma: 0.45, lengthMin: 180, lengthMax: 330,
                    pricePerKg: 65),
        FishSpecies(species: "marlin", name: "Blue Marlin", asset: "CatchFish_6",
                    frameCount: 2, prefersDeep: true, zone: .ocean,
                    weightMedian: 180.0, weightSigma: 0.45, lengthMin: 250, lengthMax: 450,
                    pricePerKg: 80),
    ]
}

/// Singleton catalog of caught fish, persisted to `UserDefaults`.
final class CatchLog {
    static let shared = CatchLog()

    private let key = "reelworld.catchlog.v1"
    private(set) var catches: [Fish] = []

    private init() { load() }

    func add(_ fish: Fish) {
        catches.append(fish)
        save()
    }

    func catches(in zone: WaterZone) -> [Fish] {
        catches.filter { $0.zone == zone }
    }

    /// Catches newest-first (for display).
    var recent: [Fish] { catches.reversed() }

    var count: Int { catches.count }

    /// Total coin value of everything currently in the log.
    var totalValue: Int { catches.reduce(0) { $0 + $1.value } }

    /// Sells the fish at `index` within the newest-first ordering; returns its value.
    @discardableResult
    func sell(recentIndex index: Int) -> Int {
        guard index >= 0 && index < catches.count else { return 0 }
        let actual = catches.count - 1 - index   // map newest-first -> storage index
        let value = catches[actual].value
        catches.remove(at: actual)
        save()
        GameState.shared.addCoins(value)
        return value
    }

    /// Sells everything; returns total coins earned.
    @discardableResult
    func sellAll() -> Int {
        let total = totalValue
        catches.removeAll()
        save()
        GameState.shared.addCoins(total)
        return total
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(catches) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Fish].self, from: data) else { return }
        catches = decoded
    }
}
