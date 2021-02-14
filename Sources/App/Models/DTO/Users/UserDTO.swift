import Vapor

struct UserDTO: Content {
    let id: UUID?
    let username: String
    let email: String
    
    init(id: UUID? = nil, username: String, email: String, isAdmin: Bool) {
        self.id = id
        self.username = username
        self.email = email
    }
    
    init(from user: User) {
        self.init(id: user.id, username: user.username, email: user.email, isAdmin: user.isAdmin)
    }
}


