import Combine
import Foundation

final class DefaultManageMyPlaylistUseCase:
    ManageMyPlaylistUseCase {
    private let currentUserIdUseCase: CurrentUserIdUseCase
    private let playlistRepository: PlaylistRepository
    private let currentPlaylistRepository: CurrentPlaylistRepository

    init(
        currentUserIdUseCase: CurrentUserIdUseCase = DIContainer.shared.resolve(),
        playlistRepository: PlaylistRepository = DIContainer.shared.resolve(),
        currentPlaylistRepository: CurrentPlaylistRepository = DIContainer.shared.resolve()
    ) {
        self.currentUserIdUseCase = currentUserIdUseCase
        self.playlistRepository = playlistRepository
        self.currentPlaylistRepository = currentPlaylistRepository
    }
    
    func currentPlaylistPublisher() -> AnyPublisher<MolioPlaylist?, Never> {
        currentPlaylistRepository.currentPlaylistPublisher
            .flatMap { playlistUUID in
                return Future { promise in
                    Task { [weak self] in
                        guard let self,
                              let playlistUUID else {
                            promise(.success(nil))
                            return
                            }
                        let userID = try currentUserIdUseCase.execute()
                        let playlist = try await self.playlistRepository.fetchPlaylist(userID: userID, for: playlistUUID)
                        promise(.success(playlist))
                    }
                    
                    return
                }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func changeCurrentPlaylist(playlistID: UUID) {
        do {
            try currentPlaylistRepository.setCurrentPlaylist(playlistID)
        } catch {
            print("Failed to set current playlist: \(error)") // TODO: 현재 플레이리스트를 변경할 수 없다는 알림창 추가
        }
    }
    
    func createPlaylist(playlistName: String) async throws {
        let userID = try currentUserIdUseCase.execute()
        
        let newPlaylistID = UUID()
        try await playlistRepository.createNewPlaylist(userID: userID, playlistID: newPlaylistID, playlistName)
        changeCurrentPlaylist(playlistID: newPlaylistID)
    }
    
    func updatePlaylistName(playlistID: UUID, name: String) async throws {
        try await updatePlaylist(playlistID: playlistID, name: name )
    }

    func updatePlaylistFilter(playlistID: UUID, filter: [MusicGenre]) async throws {
        try await updatePlaylist(playlistID: playlistID, filter: filter)
    }
    
    func deletePlaylist(playlistID: UUID) async throws {
        let userID = try currentUserIdUseCase.execute()

        try await playlistRepository.deletePlaylist(userID: userID, playlistID)
    }
    
    func addMusic(musicISRC: String, to playlistID: UUID) async throws {
        let userID = try currentUserIdUseCase.execute() 
        guard let playlist = try await playlistRepository.fetchPlaylist(userID: userID, for: playlistID) else {
            return
        }
        
        guard !playlist.musicISRCs.contains(musicISRC) else { return }
        
        let newMusicISRCs = playlist.musicISRCs + [musicISRC]
        let newPlaylist = playlist.copy(musicISRCs: newMusicISRCs)
        try await playlistRepository.updatePlaylist(userID: userID, newPlaylist: newPlaylist)
    }
    
    func deleteMusic(musicISRC: String, from playlistID: UUID) async throws {
        let userID = try currentUserIdUseCase.execute()

        guard let playlist = try await playlistRepository.fetchPlaylist(userID: userID, for: playlistID) else { return }
        
        let newMusicISRCs = playlist.musicISRCs.filter { $0 != musicISRC }
        let newPlaylist = playlist.copy(musicISRCs: newMusicISRCs)
        try await playlistRepository.updatePlaylist(userID: userID, newPlaylist: newPlaylist)
    }
    
    func moveMusic(musicISRC: String, in playlistID: UUID, fromIndex: Int, toIndex: Int) async throws {
        if fromIndex == toIndex { return }
        let userID = try currentUserIdUseCase.execute()

        guard let playlist = try await playlistRepository.fetchPlaylist(userID: userID, for: playlistID) else {
            return
        }
        
        guard fromIndex < playlist.musicISRCs.count, toIndex < playlist.musicISRCs.count else {
            throw PlaylistMusicISRCsError.invalidIndex
        }
        
        var updatedMusicISRCs = playlist.musicISRCs
        let movedMusic = updatedMusicISRCs.remove(at: fromIndex)
        
        if fromIndex > toIndex {
            updatedMusicISRCs.insert(movedMusic, at: toIndex)

        } else {
            updatedMusicISRCs.insert(movedMusic, at: toIndex-1)
        }
        
        let updatedPlaylist = playlist.copy(musicISRCs: updatedMusicISRCs)
        
        try await playlistRepository.updatePlaylist(userID: userID, newPlaylist: updatedPlaylist)
    }
    
    // MARK: - Private Method
    
    private func updatePlaylist(playlistID: UUID, name: String? = nil, musicISRCs: [String]? = nil, filter: [MusicGenre]? = nil, like: [String]? = nil) async throws {
        let userID = try currentUserIdUseCase.execute()

        guard let playlist = try await playlistRepository.fetchPlaylist(userID: userID, for: playlistID) else { return }
        
        let newPlaylist = playlist.copy(name: name, musicISRCs: musicISRCs, filter: filter, like: like)
        try await playlistRepository.updatePlaylist(userID: userID, newPlaylist: newPlaylist)
    }
}

enum PlaylistMusicISRCsError: Error {
    case invalidIndex
}
