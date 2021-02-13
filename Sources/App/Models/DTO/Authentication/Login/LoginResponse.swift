import Vapor

struct LoginResponse: Content {
    let user: UserDTO
    let accessToken: AccessTokenResponse
}

struct DataResponse<T: Content>: Content {
    let data: T
}
