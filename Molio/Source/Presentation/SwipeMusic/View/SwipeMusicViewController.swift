import Combine
import UIKit

final class SwipeMusicViewController: UIViewController {
    private let viewModel: SwipeMusicViewModel
    private var input: SwipeMusicViewModel.Input
    private var output: SwipeMusicViewModel.Output
    private let musicPlayer: AudioPlayer

    private let musicCardDidChangeSwipePublisher = PassthroughSubject<CGFloat, Never>()
    private let musicCardDidFinishSwipePublisher = PassthroughSubject<CGFloat, Never>()
    private let likeButtonDidTapPublisher = PassthroughSubject<Void, Never>()
    private let dislikeButtonDidTapPublisher = PassthroughSubject<Void, Never>()
    private let filterDidUpdatePublisher = PassthroughSubject<[MusicGenre], Never>()
    private var cancellables = Set<AnyCancellable>()
    
    private var isMusicCardAnimating = false
    private var pendingMusic: (currentMusic: SwipeMusicTrackModel?, nextMusic: SwipeMusicTrackModel?)
    private let basicBackgroundColor = UIColor(resource: .background)
    private var impactFeedBack = UIImpactFeedbackGenerator(style: .medium)
    private var hasProvidedImpactFeedback: Bool = false
    private var currentCardBackgroundColor: RGBAColor?
    private var nextCardBackgroundColor: RGBAColor?
    private var previousRotationAngle: CGFloat?
    private var previousYDirection: CGFloat?
    
    private let loadingIndicatorView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let playlistSelectButton: UIButton = {
        let button = UIButton()
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let blurEffect = UIBlurEffect(style: .systemMaterialDark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.layer.cornerRadius = 10
        blurEffectView.clipsToBounds = true
        blurEffectView.isUserInteractionEnabled = false
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.alpha = 0.5
        
        button.addSubview(blurEffectView)
        NSLayoutConstraint.activate([
            blurEffectView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            blurEffectView.topAnchor.constraint(equalTo: button.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        button.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        return button
    }()
    
    private let selectedPlaylistTitleLabel: UILabel = {
        let label = UILabel()
        label.molioMedium( text: "", size: 16)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let playlistSelectArrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.image = UIImage(systemName: "chevron.down")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let menuStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.alignment = .center
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let currentCardView = MusicCardView()
    
    private let nextCardView: MusicCardView = {
        let nextCardView = MusicCardView()
        nextCardView.isUserInteractionEnabled = false
        return nextCardView
    }()
    
    private let filterButton = CircleMenuButton(
        backgroundColor: .black.withAlphaComponent(0.51),
        highlightColor: .white.withAlphaComponent(0.51),
        buttonSize: 58.0,
        tintColor: .white,
        buttonImage: UIImage(systemName: "slider.horizontal.3"),
        buttonImageSize: CGSize(width: 21.0, height: 19.0)
    )
    
    private let dislikeButton = CircleMenuButton(
        backgroundColor: .black.withAlphaComponent(0.51),
        highlightColor: .white.withAlphaComponent(0.51),
        buttonSize: 66.0,
        tintColor: UIColor(hex: "#FF3D3D"),
        buttonImage: UIImage(systemName: "xmark"),
        buttonImageSize: CGSize(width: 25.0, height: 29.0)
    )

    private let likeButton = CircleMenuButton(
        backgroundColor: .black.withAlphaComponent(0.51),
        highlightColor: .white.withAlphaComponent(0.51),
        buttonSize: 66.0,
        tintColor: UIColor(resource: .main),
        buttonImage: UIImage(systemName: "heart.fill"),
        buttonImageSize: CGSize(width: 30.0, height: 29.0)
    )

    private let myMolioButton = CircleMenuButton(
        backgroundColor: .black.withAlphaComponent(0.51),
        highlightColor: .white.withAlphaComponent(0.51),
        buttonSize: 58.0,
        tintColor: UIColor(hex: "#FFFAFA"),
        buttonImage: UIImage(systemName: "music.note"),
        buttonImageSize: CGSize(width: 18.0, height: 24.0)
    )
    
    init(viewModel: SwipeMusicViewModel, musicPlayer: AudioPlayer = DIContainer.shared.resolve()) {
        self.viewModel = viewModel
        self.input = SwipeMusicViewModel.Input(
            musicCardDidChangeSwipe: musicCardDidChangeSwipePublisher.eraseToAnyPublisher(),
            musicCardDidFinishSwipe: musicCardDidFinishSwipePublisher.eraseToAnyPublisher(),
            likeButtonDidTap: likeButtonDidTapPublisher.eraseToAnyPublisher(),
            dislikeButtonDidTap: dislikeButtonDidTapPublisher.eraseToAnyPublisher(),
            filterDidUpdate: filterDidUpdatePublisher.eraseToAnyPublisher()
        )
        self.output = viewModel.transform(from: input)
        self.musicPlayer = musicPlayer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.viewModel = SwipeMusicViewModel()
        self.input = SwipeMusicViewModel.Input(
            musicCardDidChangeSwipe: musicCardDidChangeSwipePublisher.eraseToAnyPublisher(),
            musicCardDidFinishSwipe: musicCardDidFinishSwipePublisher.eraseToAnyPublisher(),
            likeButtonDidTap: likeButtonDidTapPublisher.eraseToAnyPublisher(),
            dislikeButtonDidTap: dislikeButtonDidTapPublisher.eraseToAnyPublisher(),
            filterDidUpdate: filterDidUpdatePublisher.eraseToAnyPublisher()
        )
        self.output = viewModel.transform(from: input)
        self.musicPlayer = DIContainer.shared.resolve()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true
        view.backgroundColor = basicBackgroundColor
        setupSelectPlaylistView()
        setupMusicTrackView()
        setupMenuButtonView()
        
        setupBindings()
        setupButtonTarget()
        addPanGestureToMusicTrack()
        addTapGestureToMusicTrack()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let previewAssetURL = viewModel.currentMusic?.previewAsset else { return }
        
        // 옵저버가 등록되어 있는 경우에는 삭제한다.
        if let observer = musicPlayer.musicItemDidPlayToEndTimeObserver {
            NotificationCenter.default.removeObserver(observer)
            musicPlayer.musicItemDidPlayToEndTimeObserver = nil
        }
        
        loadAndPlaySongs(url: previewAssetURL)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        musicPlayer.stop()
    }
    
    private func setupBindings() {
        output.selectedPlaylist
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playlist in
                guard let self else { return }
                self.selectedPlaylistTitleLabel.text = playlist.name
            }
            .store(in: &cancellables)
        
        output.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                if isLoading {
                    currentCardView.isUserInteractionEnabled = false
                    loadingIndicatorView.startAnimating()
                } else {
                    currentCardView.isUserInteractionEnabled = true
                    loadingIndicatorView.stopAnimating()
                }
            }
            .store(in: &cancellables)
        
        output.currentMusicTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] music in
                guard let self else { return }
                if isMusicCardAnimating {
                    self.pendingMusic.currentMusic = music
                } else {
                    let currentCardBackgroundColor = music.artworkBackgroundColor
                        .flatMap { UIColor(rgbaColor: $0) } ?? self.basicBackgroundColor
                    UIView.animate(withDuration: 0.3, animations: {
                        self.view.backgroundColor = currentCardBackgroundColor
                    })
                    self.updateCurrentCard(with: music)
                }
                currentCardBackgroundColor = music.artworkBackgroundColor
            }
            .store(in: &cancellables)
        
        output.nextMusicTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] music in
                guard let self else { return }
                if isMusicCardAnimating {
                    self.pendingMusic.nextMusic = music
                } else {
                    nextCardView.configure(music: music)
                }
                nextCardBackgroundColor = music.artworkBackgroundColor
            }
            .store(in: &cancellables)
        
        output.buttonHighlight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] buttonHighlight in
                guard let self else { return }
                
                self.likeButton.isHighlighted = buttonHighlight.isLikeHighlighted
                animateButtonScale(button: self.likeButton, isHighlighted: buttonHighlight.isLikeHighlighted)
                
                self.dislikeButton.isHighlighted = buttonHighlight.isDislikeHighlighted
                animateButtonScale(button: self.dislikeButton, isHighlighted: buttonHighlight.isDislikeHighlighted)
            }
            .store(in: &cancellables)
        
        output.musicCardSwipeAnimation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] swipeDirection in
                guard let self else { return }
                self.animateMusicCard(direction: swipeDirection)
                
            }
            .store(in: &cancellables)
    }
    
    private func loadAndPlaySongs(url: URL) {
        musicPlayer.stop()
        musicPlayer.loadSong(with: url)
        musicPlayer.play()
    }
    
    /// Swipe 동작이 끝나고 MusicCard가 animation되는 메서드
    private func animateMusicCard(direction: SwipeMusicViewModel.SwipeDirection) {
        let currentCenter = currentCardView.center
        let frameWidth = view.frame.width
        
        switch direction {
        case .left, .right:
            self.isMusicCardAnimating = true
            let movedCenterX = currentCenter.x + direction.rawValue * frameWidth
            let movedCenterY = currentCenter.y + (previousYDirection ?? 0) * frameWidth
            UIView.animate(
                withDuration: 0.3,
                animations: { [weak self] in
                    guard let self else { return }
                    // 카드 이동
                    self.currentCardView.center = CGPoint(x: movedCenterX, y: movedCenterY)
                    // 카드 회전
                    self.currentCardView.transform = CGAffineTransform(rotationAngle: previousRotationAngle ?? 0)
                    // 배경색 변경
                    let nextCardBackgroundColor = nextCardBackgroundColor
                        .flatMap { UIColor(rgbaColor: $0) } ?? self.basicBackgroundColor
                    self.view.backgroundColor = nextCardBackgroundColor
                },
                completion: { [weak self] _ in
                    guard let self else { return }
                    if let currentMusic = self.pendingMusic.currentMusic {
                        self.updateCurrentCard(with: currentMusic)
                        self.pendingMusic.currentMusic = nil
                    }
                    
                    if let nextMusic = self.pendingMusic.nextMusic {
                        self.nextCardView.configure(music: nextMusic)
                        self.pendingMusic.nextMusic = nil
                    }
                    
                    self.currentCardView.transform = .identity
                    self.isMusicCardAnimating = false
                })
        case .none:
            UIView.animate(withDuration: 0.3) { [weak self] in
                guard let self else { return }
                self.currentCardView.center = self.nextCardView.center
                self.currentCardView.transform = .identity
                let currentCardBackgroundColor = currentCardBackgroundColor
                    .flatMap { UIColor(rgbaColor: $0) } ?? self.basicBackgroundColor
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.view.backgroundColor = currentCardBackgroundColor
                })
            }
        }
    }
    
    /// 현재 노래 카드 정보 변경 및 현재 노래 재생하는 메서드
    private func updateCurrentCard(with music: SwipeMusicTrackModel) {
        currentCardView.configure(music: music)
        self.loadAndPlaySongs(url: music.previewAsset)
    }
    
    private func addPanGestureToMusicTrack() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        currentCardView.addGestureRecognizer(panGesture)
    }
    
    private func addTapGestureToMusicTrack() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        currentCardView.addGestureRecognizer(tapGesture)
    }

    private func setupButtonTarget() {
        likeButton.addTarget(self, action: #selector(didTapLikeButton), for: .touchUpInside)
        dislikeButton.addTarget(self, action: #selector(didTapDislikeButton), for: .touchUpInside)
        playlistSelectButton.addTarget(self, action: #selector(didTapPlaylistSelectButton), for: .touchUpInside)
        filterButton.addTarget(self, action: #selector(didTapFilterButton), for: .touchUpInside)
        myMolioButton.addTarget(self, action: #selector(didTapMyMolioButton), for: .touchUpInside)
    }
    
    /// 사용자에게 진동 feedback을 주는 메서드
    private func providedImpactFeedback(translationX: CGFloat) {
        if abs(translationX) > viewModel.swipeThreshold && !hasProvidedImpactFeedback {
            impactFeedBack.impactOccurred()
            hasProvidedImpactFeedback = true
        } else if abs(translationX) <= viewModel.swipeThreshold {
            hasProvidedImpactFeedback = false
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let card = gesture.view else { return }
        
        let translation = gesture.translation(in: view)
        
        card.center = CGPoint(
            x: nextCardView.center.x + translation.x,
            y: nextCardView.center.y + translation.y
        )
        
        let rotationAngle = calculateRotationAngle(movedPoint: translation)
        card.transform = CGAffineTransform(rotationAngle: rotationAngle)
        
        if gesture.state == .changed {
            musicCardDidChangeSwipePublisher.send(translation.x)
            providedImpactFeedback(translationX: translation.x)
            interpolateBackgroundColor(
                from: currentCardBackgroundColor,
                to: nextCardBackgroundColor,
                movedX: translation.x
            )
        } else if gesture.state == .ended {
            previousRotationAngle = rotationAngle
            previousYDirection = translation.y >= 0 ? 1 : -1
            musicCardDidFinishSwipePublisher.send(translation.x)
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard gesture.view == currentCardView else { return }
        if musicPlayer.isPlaying {
            musicPlayer.pause()
            currentCardView.showPlayPauseIcon(isPlaying: true)
        } else {
            musicPlayer.play()
            currentCardView.showPlayPauseIcon(isPlaying: false)
        }
    }
    
    @objc private func didTapLikeButton() {
        setRandomRotationAngle(isLike: true)
        likeButtonDidTapPublisher.send()
    }
    
    @objc private func didTapDislikeButton() {
        setRandomRotationAngle(isLike: false)
        dislikeButtonDidTapPublisher.send()
    }
    
    @objc func didTapPlaylistSelectButton() {
        let viewModel = ManagePlaylistViewModel()
        let selectPlaylistVC = SelectPlaylistViewController(viewModel: viewModel)
        selectPlaylistVC.delegate = self
        self.presentCustomSheet(selectPlaylistVC)
    }
    
    @objc private func didTapMyMolioButton() {
        musicPlayer.stop()
        let viewModel = PlaylistDetailViewModel()
        let playlistDetailVC = PlaylistDetailViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(playlistDetailVC, animated: true)
    }
    
    @objc private func didTapFilterButton() {
        musicPlayer.stop()
        let viewModel = MusicFilterViewModel()
        let musicFilterVC = MusicFilterViewController(viewModel: viewModel) { [weak self] updatedFilter in
            if let updatedFilter = updatedFilter {
                self?.filterDidUpdatePublisher.send(updatedFilter)
            } else {
                self?.musicPlayer.play() // 필터를 설정하지 않고 dismiss한 경우 이어서 재생
            }
        }
        self.present(musicFilterVC, animated: true)
    }
    
    /// 버튼 클릭시, (상, 중, 하)에 따라 달라지는 카드 애니메이션 값 적용하는 메서드
    private func setRandomRotationAngle(isLike: Bool) {
        let randomDirection = [-1, 0, 1].randomElement() ?? 0
        let rotationDirection: CGFloat = isLike ? 1 : -1
        switch randomDirection {
        case -1:
            previousYDirection = -1
            previousRotationAngle = .pi / 6 * rotationDirection
        case 1:
            previousYDirection = 1
            previousRotationAngle = .pi / 6 * rotationDirection * -1
        default:
            previousYDirection = 0
            previousRotationAngle = 0
        }
    }
    
    /// 이동하는 값에 따라 두 색깔 사이의 값으로 배경색이 변하는 메서드
    private func interpolateBackgroundColor(from: RGBAColor?, to: RGBAColor?, movedX: CGFloat) {
        let from = from ?? RGBAColor.background
        let to = to ?? RGBAColor.background
        let progress: CGFloat = min((abs(movedX) / viewModel.swipeThreshold), 1.0)
        let red = from.red + (to.red - from.red) * progress
        let green = from.green + (to.green - from.green) * progress
        let blue = from.blue + (to.blue - from.blue) * progress
        let alpha = from.alpha + (to.alpha - from.alpha) * progress
        view.backgroundColor = UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// 카드 이동에 따른 회전 각도 계산하는 메서드
    private func calculateRotationAngle(movedPoint: CGPoint) -> CGFloat {
        let maxRotationAngle: CGFloat = .pi / 6
        let diagonalFactor = calculateRotationFactor(point: movedPoint)
        let rotationSign = getRotationSign(point: movedPoint)
        return maxRotationAngle * diagonalFactor * rotationSign
    }
    
    /// 회전 비율을 결정하는 메서드
    private func calculateRotationFactor(point: CGPoint) -> CGFloat {
        let absX = abs(point.x)
        let absY = abs(point.y)
        
        return min(absX, absY) / (view.bounds.width / 2)
    }
    
    /// 회전 방향을 구하는 메서드
    private func getRotationSign(point: CGPoint) -> CGFloat {
        return point.x * point.y >= 0 ? -1.0 : 1.0
    }
    
    private func animateButtonScale(button: UIButton, isHighlighted: Bool) {
        UIView.animate(withDuration: 0.1) {
            button.transform = isHighlighted ? CGAffineTransform(scaleX: 1.2, y: 1.2) : .identity
        }
    }
    
    private func setupSelectPlaylistView() {
        view.addSubview(playlistSelectButton)
        view.addSubview(selectedPlaylistTitleLabel)
        view.addSubview(playlistSelectArrowImageView)
        
        NSLayoutConstraint.activate([
            playlistSelectButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            playlistSelectButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playlistSelectButton.heightAnchor.constraint(equalToConstant: 39)
        ])
        
        NSLayoutConstraint.activate([
            selectedPlaylistTitleLabel.leadingAnchor.constraint(equalTo: playlistSelectButton.leadingAnchor, constant: 15),
            selectedPlaylistTitleLabel.centerYAnchor.constraint(equalTo: playlistSelectButton.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            playlistSelectArrowImageView.leadingAnchor.constraint(equalTo: selectedPlaylistTitleLabel.trailingAnchor, constant: 10),
            playlistSelectArrowImageView.trailingAnchor.constraint(equalTo: playlistSelectButton.trailingAnchor, constant: -15),
            playlistSelectArrowImageView.centerYAnchor.constraint(equalTo: playlistSelectButton.centerYAnchor),
            playlistSelectArrowImageView.widthAnchor.constraint(equalToConstant: 18),
            playlistSelectArrowImageView.heightAnchor.constraint(equalToConstant: 19)
        ])
    }
    
    private func setupMusicTrackView() {
        // MARK: 다음 노래 카드
        view.insertSubview(nextCardView, belowSubview: playlistSelectButton)
        NSLayoutConstraint.activate([
            nextCardView.topAnchor.constraint(equalTo: playlistSelectButton.bottomAnchor, constant: 12),
            nextCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            nextCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            nextCardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -107)
        ])
        
        // MARK: 현재 노래 카드
        view.insertSubview(currentCardView, belowSubview: playlistSelectButton)
        NSLayoutConstraint.activate([
            currentCardView.topAnchor.constraint(equalTo: playlistSelectButton.bottomAnchor, constant: 12),
            currentCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            currentCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            currentCardView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -107)
        ])
        
        view.addSubview(loadingIndicatorView)
        NSLayoutConstraint.activate([
            loadingIndicatorView.centerXAnchor.constraint(equalTo: nextCardView.centerXAnchor),
            loadingIndicatorView.centerYAnchor.constraint(equalTo: nextCardView.centerYAnchor)
        ])
    }
    
    private func setupMenuButtonView() {
        view.addSubview(menuStackView)
        menuStackView.addArrangedSubview(filterButton)
        menuStackView.addArrangedSubview(dislikeButton)
        menuStackView.addArrangedSubview(likeButton)
        menuStackView.addArrangedSubview(myMolioButton)
        
        NSLayoutConstraint.activate([
            menuStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22)
        ])
    }
}

extension SwipeMusicViewController: SelectPlaylistViewControllerDelegate {
    func didTapCreateButton() {
        let createPlaylistVC = CreatePlaylistViewController(viewModel: ManagePlaylistViewModel())
        self.presentCustomSheet(createPlaylistVC)
    }
}

// MARK: - Preview

// SwiftUI에서 SwipeViewController 미리보기
import SwiftUI
struct SwipeViewControllerPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeMusicViewController {
        let swipeMusicViewModel = SwipeMusicViewModel()
        return SwipeMusicViewController(viewModel: swipeMusicViewModel)
    }
    
    func updateUIViewController(_ uiViewController: SwipeMusicViewController, context: Context) {
        
    }
}

struct SwipeViewController_Previews: PreviewProvider {
    static var previews: some View {
        SwipeViewControllerPreview()
            .edgesIgnoringSafeArea(.all)
    }
}
