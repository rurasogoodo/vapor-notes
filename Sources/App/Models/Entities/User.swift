import Vapor
import Fluent

final class User: Model, Authenticatable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "full_name")
    var username: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Field(key: "is_admin")
    var isAdmin: Bool
    
    @Field(key: "is_email_verified")
    var isEmailVerified: Bool
    
    @Children(for: \.$user)
    var notes: [Note]
    
    init() {}
    
    init(id: UUID? = nil,
         fullName: String,
         email: String,
         passwordHash: String,
         isAdmin: Bool = false,
         isEmailVerified: Bool = true) {
        self.id = id
        self.username = fullName
        self.email = email
        self.passwordHash = passwordHash
        self.isAdmin = isAdmin
        self.isEmailVerified = isEmailVerified
    }
}
