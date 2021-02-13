import Vapor

struct UserDTO: Content {
    let id: UUID?
    let username: String
    let email: String
    
    init(id: UUID? = nil, fullName: String, email: String, isAdmin: Bool) {
        self.id = id
        self.username = fullName
        self.email = email
    }
    
    init(from user: User) {
        self.init(id: user.id, fullName: user.username, email: user.email, isAdmin: user.isAdmin)
    }
}


