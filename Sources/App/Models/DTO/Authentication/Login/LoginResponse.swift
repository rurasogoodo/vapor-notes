import Vapor

struct LoginResponse: Content {
    let user: UserDTO
    let accessToken: AccessTokenResponse
}
