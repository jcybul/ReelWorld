import SpriteKit

class GameScene: SKScene {
    override func didMove(to view: SKView) {
        let menu = MenuScene(size: view.bounds.size)
        menu.scaleMode = .aspectFill
        view.presentScene(menu)
    }
}
