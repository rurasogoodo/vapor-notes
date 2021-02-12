import Vapor

struct NoteDTO: Content {
    let id: UUID?
    let title: String
    let description: String
    let isHidden: Bool
    let createdAt: Date
    let user: UserDTO
    
    init(id: UUID? = nil, title: String, description: String, isHidden: Bool, createdAt: Date, user: UserDTO) {
        self.id = id
        self.title = title
        self.description = description
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.user = user
    }
    
    init(from note: Note, user: User) {
        self.init(id: note.id,
                  title: note.title,
                  description: note.description,
                  isHidden: note.isHidden,
                  createdAt: note.createdAt,
                  user: UserDTO(from: user))
    }
}


