import SpriteKit

class GameScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .black
        scaleMode = .aspectFill
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // input handling goes here
    }

    override func update(_ currentTime: TimeInterval) {
        // game loop goes here
    }
}
