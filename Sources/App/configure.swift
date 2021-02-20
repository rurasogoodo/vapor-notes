import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import Mailgun
import QueuesRedisDriver

public func configure(_ app: Application) throws {
    // MARK: JWT
//    if app.environment != .testing {
//        let jwksFilePath = app.directory.workingDirectory + (Environment.get("JWKS_KEYPAIR_FILE") ?? "keypair.jwks")
//         guard
//             let jwks = FileManager.default.contents(atPath: jwksFilePath),
//             let jwksString = String(data: jwks, encoding: .utf8)
//             else {
//                 fatalError("Failed to load JWKS Keypair file at: \(jwksFilePath)")
//         }
//         try app.jwt.signers.use(jwksJSON: jwksString)
//    }
    app.jwt.signers.use(.hs256(key: "secret"))
    
    // MARK: Database
    // Configure PostgreSQL database
    app.databases.use(
        .postgres(
            hostname: Environment.get("DB_HOST") ?? "db",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DB_USER") ?? "vapor",
            password: Environment.get("DB_PASS") ?? "password",
            database: Environment.get("DB_NAME") ?? "vapor"
        ), as: .psql)
        
    // MARK: Middleware
    app.middleware = .init()
    app.middleware.use(ErrorMiddleware.custom(environment: app.environment))
    
    // MARK: Model Middleware
    
    // MARK: Mailgun
//    app.mailgun.configuration = .environment
    app.mailgun.configuration = .init(apiKey: "<api key>")
    app.mailgun.defaultDomain = .sandbox
    
    // MARK: App Config
    app.config = .environment
    
    try routes(app)
    try migrations(app)
    try queues(app)
    try services(app)
    
    
    try app.autoMigrate().wait()
    if app.environment == .development {
        try app.autoMigrate().wait()
        try app.queues.startInProcessJobs()
    }
}
