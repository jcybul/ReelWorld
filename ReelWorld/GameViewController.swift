import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private var didPresentScene = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if let view = self.view as? SKView {
            view.ignoresSiblingOrder = true
            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

    // Present once the view has its final (landscape) bounds. Doing this in
    // viewDidLoad can size the scene from not-yet-laid-out / portrait bounds,
    // which makes .aspectFill zoom in. Waiting for layout avoids that.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !didPresentScene,
              let view = self.view as? SKView,
              view.bounds.width > 0, view.bounds.height > 0 else { return }
        didPresentScene = true

        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
