import Vapor
import Fluent

struct ApiAuthenticationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group("auth") { auth in
            auth.post("register", use: register)
            auth.post("login", use: login)
            
            auth.group("email-verification") { emailVerificationRoutes in
                emailVerificationRoutes.post("", use: sendEmailVerification)
                emailVerificationRoutes.get("", use: verifyEmail)
            }
            
            auth.group("reset-password") { resetPasswordRoutes in
                resetPasswordRoutes.post("", use: resetPassword)
                resetPasswordRoutes.get("verify", use: verifyResetPasswordToken)
            }
            auth.post("recover", use: recoverAccount)
            
            auth.post("accessToken", use: refreshAccessToken)
            
            // Authentication required
            auth.group(UserAuthenticator()) { authenticated in
                authenticated.get("me", use: getCurrentUser)
                authenticated.delete("logout", use: logout)
            }
        }
    }
    
    private func register(_ req: Request) throws -> EventLoopFuture<DataResponse<LoginResponse>> {
        try RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        guard registerRequest.password == registerRequest.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        
        return req.password
            .async
            .hash(registerRequest.password)
            .flatMapThrowing { try User(from: registerRequest, hash: $0) }
            .flatMap { user in
                req.users
                    .create(user)
                    .flatMapErrorThrowing {
                        if let dbError = $0 as? DatabaseError, dbError.isConstraintFailure {
                            throw AuthenticationError.emailAlreadyExists
                        }
                        throw $0
                    }
                    .flatMapThrowing {
                        try createLoginResponse(with: user, req: req).wait()
                    }
            }
    }
    
    private func login(_ req: Request) throws -> EventLoopFuture<DataResponse<LoginResponse>> {
        try LoginRequest.validate(content: req)
        let loginRequest = try req.content.decode(LoginRequest.self)
        
        return req.users
            .find(email: loginRequest.email)
            .unwrap(or: AuthenticationError.invalidEmailOrPassword)
            .guard({ $0.isEmailVerified }, else: AuthenticationError.emailIsNotVerified)
            .flatMap { user -> EventLoopFuture<User> in
                return req.password
                    .async
                    .verify(loginRequest.password, created: user.passwordHash)
                    .guard({ $0 == true }, else: AuthenticationError.invalidEmailOrPassword)
                    .transform(to: user)
            }
            .flatMap { user -> EventLoopFuture<User> in
                do {
                    return try req.refreshTokens.delete(for: user.requireID()).transform(to: user)
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
            .flatMap { user in
                do {
                    let refreshTokenString = req.random.generate(bits: 256)
                    let refreshToken = try RefreshToken(token: SHA256.hash(refreshTokenString), userID: user.requireID())
                    
                    return req.refreshTokens
                        .create(refreshToken)
                        .flatMapThrowing {
                            let payload = try Payload(with: user)
                            let accessTokenString = try req.jwt.sign(payload)
                            let accessTokenResponse = AccessTokenResponse(refreshToken: refreshTokenString,
                                                                          accessToken: accessTokenString,
                                                                          expiresAt: payload.exp.value)
                            return DataResponse<LoginResponse>(data: LoginResponse(user: UserDTO(from: user), accessToken: accessTokenResponse))
                        }
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
    }
    
    private func logout(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let payload = try req.auth.require(Payload.self)
        req.auth.logout(Payload.self)
        return RefreshToken.query(on: req.db)
            .filter(\.$user.$id == payload.userID)
            .first()
            .unwrap(or: AuthenticationError.refreshTokenOrUserNotFound)
            .flatMap { req.refreshTokens.delete($0) }
            .transform(to: HTTPStatus.noContent)
    }
    
    private func refreshAccessToken(_ req: Request) throws -> EventLoopFuture<DataResponse<AccessTokenResponse>> {
        let accessTokenRequest = try req.content.decode(AccessTokenRequest.self)
        let hashedRefreshToken = SHA256.hash(accessTokenRequest.refreshToken)
        
        return req.refreshTokens
            .find(token: hashedRefreshToken)
            .unwrap(or: AuthenticationError.refreshTokenOrUserNotFound)
            .flatMap { req.refreshTokens.delete($0).transform(to: $0) }
            .guard({ $0.expiresAt > Date() }, else: AuthenticationError.refreshTokenHasExpired)
            .flatMap { req.users.find(id: $0.$user.id) }
            .unwrap(or: AuthenticationError.refreshTokenOrUserNotFound)
            .flatMap { user in
                do {
                    let token = req.random.generate(bits: 256)
                    let refreshToken = try RefreshToken(token: SHA256.hash(token), userID: user.requireID())
                    
                    let payload = try Payload(with: user)
                    let accessToken = try req.jwt.sign(payload)
                    
                    return req.refreshTokens
                        .create(refreshToken)
                        .transform(to: (token, accessToken, payload.exp.value))
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
            .map { DataResponse<AccessTokenResponse>(data: AccessTokenResponse(refreshToken: $0,
                                                                               accessToken: $1,
                                                                               expiresAt: $2)) }
    }
    
    private func getCurrentUser(_ req: Request) throws -> EventLoopFuture<DataResponse<UserDTO>> {
        let payload = try req.auth.require(Payload.self)
        
        return req.users
            .find(id: payload.userID)
            .unwrap(or: AuthenticationError.userNotFound)
            .map { DataResponse<UserDTO>(data: UserDTO(from: $0)) }
    }
    
    private func verifyEmail(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let token = try req.query.get(String.self, at: "token")
        
        let hashedToken = SHA256.hash(token)
        
        return req.emailTokens
            .find(token: hashedToken)
            .unwrap(or: AuthenticationError.emailTokenNotFound)
            .flatMap { req.emailTokens.delete($0).transform(to: $0) }
            .guard({ $0.expiresAt > Date() },
                   else: AuthenticationError.emailTokenHasExpired)
            .flatMap {
                req.users.set(\.$isEmailVerified, to: true, for: $0.$user.id)
            }
            .transform(to: .ok)
    }
    
    private func resetPassword(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let resetPasswordRequest = try req.content.decode(ResetPasswordRequest.self)
        
        return req.users
            .find(email: resetPasswordRequest.email)
            .flatMap {
                if let user = $0 {
                    return req.passwordResetter
                        .reset(for: user)
                        .transform(to: .noContent)
                } else {
                    return req.eventLoop.makeSucceededFuture(.noContent)
                }
            }
    }
    
    private func verifyResetPasswordToken(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let token = try req.query.get(String.self, at: "token")
        
        let hashedToken = SHA256.hash(token)
        
        return req.passwordTokens
            .find(token: hashedToken)
            .unwrap(or: AuthenticationError.invalidPasswordToken)
            .flatMap { passwordToken in
                guard passwordToken.expiresAt > Date() else {
                    return req.passwordTokens
                        .delete(passwordToken)
                        .transform(to: req.eventLoop
                                    .makeFailedFuture(AuthenticationError.passwordTokenHasExpired)
                        )
                }
                
                return req.eventLoop.makeSucceededFuture(.noContent)
            }
    }
    
    private func recoverAccount(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        try RecoverAccountRequest.validate(content: req)
        let content = try req.content.decode(RecoverAccountRequest.self)
        
        guard content.password == content.confirmPassword else {
            throw AuthenticationError.passwordsDontMatch
        }
        
        let hashedToken = SHA256.hash(content.token)
        
        return req.passwordTokens
            .find(token: hashedToken)
            .unwrap(or: AuthenticationError.invalidPasswordToken)
            .flatMap { passwordToken -> EventLoopFuture<Void> in
                guard passwordToken.expiresAt > Date() else {
                    return req.passwordTokens
                        .delete(passwordToken)
                        .transform(to: req.eventLoop
                                    .makeFailedFuture(AuthenticationError.passwordTokenHasExpired)
                        )
                }
                
                return req.password
                    .async
                    .hash(content.password)
                    .flatMap { digest in
                        req.users.set(\.$passwordHash, to: digest, for: passwordToken.$user.id)
                    }
                    .flatMap { req.passwordTokens.delete(for: passwordToken.$user.id) }
            }
            .transform(to: .noContent)
    }
    
    private func sendEmailVerification(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let content = try req.content.decode(SendEmailVerificationRequest.self)
        
        return req.users
            .find(email: content.email)
            .flatMap {
                guard let user = $0, !user.isEmailVerified else {
                    return req.eventLoop.makeSucceededFuture(.noContent)
                }
                
                return req.emailVerifier
                    .verify(for: user)
                    .transform(to: .noContent)
            }
    }
    
    private func createLoginResponse(with user: User, req: Request) throws -> EventLoopFuture<DataResponse<LoginResponse>> {
        do {
            let refreshTokenString = req.random.generate(bits: 256)
            let refreshToken = try RefreshToken(token: SHA256.hash(refreshTokenString), userID: user.requireID())
            
            return req.refreshTokens
                .create(refreshToken)
                .flatMapThrowing {
                    let payload = try Payload(with: user)
                    let accessTokenString = try req.jwt.sign(payload)
                    let accessTokenResponse = AccessTokenResponse(refreshToken: refreshTokenString,
                                                                  accessToken: accessTokenString,
                                                                  expiresAt: payload.exp.value)
                    let response = DataResponse<LoginResponse>(data: LoginResponse(user: UserDTO(from: user),
                                                                                   accessToken: accessTokenResponse))
                    return response
                }
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
}
