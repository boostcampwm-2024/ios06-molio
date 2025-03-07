import SwiftUI

final class SearchUserViewController: UIHostingController<SearchUserView> {
    // MARK: - Initializer
    
    init() {
        let viewModel = SearchUserViewModel()
        let view = SearchUserView(viewModel: viewModel)
        super.init(rootView: view)
        
        rootView.didUserInfoCellTapped = { [weak self] selectedUser in
            guard let self else { return }
            self.navigateTofriendViewController(with: selectedUser)
        }
        
        rootView.didTabLoginRequiredButton = {
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                sceneDelegate.switchToLoginViewController()
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - Life Cycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Present Sheet or Navigation
    
    private func navigateTofriendViewController(with user: MolioFollower) {
        let friendProfileViewController = FriendProfileViewController(
            profileType: .friend(
                userID: user.id,
                isFollowing: user.followRelation
            )
        )
        navigationController?.pushViewController(friendProfileViewController, animated: true)
    }
}
