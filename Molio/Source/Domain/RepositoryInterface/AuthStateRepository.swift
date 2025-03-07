protocol AuthStateRepository {
    var authMode: AuthMode { get }
    var authSelection: AuthSelection { get }
    func setAuthMode(_ mode: AuthMode)
    func setAuthSelection(_ selection: AuthSelection)
    func signInApple(info: AppleAuthInfo) async throws -> (uid: String, isNewUser: Bool)
    func logout() throws
    func reauthenticateApple(idToken: String, nonce: String) async throws
    func deleteAuth(authorizationCode: String) async throws
}
