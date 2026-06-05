//
//  FishAI.swift
//  ReelWorld
//
//  A simple wandering fish that drifts gently around its water band.
//

import SpriteKit

final class FishNode: SKSpriteNode {
    var species: FishSpecies!
    var deep = false
    var wanderRect: CGRect = .zero

    /// Next time (scene currentTime) this fish is allowed to test for a bite.
    var nextBiteCheck: TimeInterval = 0

    /// Picks a nearby random point in `wanderRect` and drifts there slowly,
    /// then repeats — producing a calm, organic swim.
    func swim(in rect: CGRect) {
        wanderRect = rect

        // Bias the next target to be reasonably close for gentle motion.
        let dx = CGFloat.random(in: -120...120)
        let dy = CGFloat.random(in: -60...60)
        let tx = min(max(position.x + dx, rect.minX), rect.maxX)
        let ty = min(max(position.y + dy, rect.minY), rect.maxY)
        let target = CGPoint(x: tx, y: ty)

        // Face travel direction (sprites are drawn facing right).
        if abs(target.x - position.x) > 1 {
            xScale = target.x < position.x ? -abs(xScale) : abs(xScale)
        }

        let dist = hypot(target.x - position.x, target.y - position.y)
        let speed: CGFloat = 22  // points / second — slow drift
        let move = SKAction.move(to: target, duration: TimeInterval(max(dist, 1) / speed))
        move.timingMode = .easeInEaseOut
        let pause = SKAction.wait(forDuration: .random(in: 0.4...1.8))
        let again = SKAction.run { [weak self] in
            guard let self else { return }
            self.swim(in: self.wanderRect)
        }
        run(.sequence([move, pause, again]), withKey: "swim")
    }
}
