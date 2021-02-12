import Vapor

struct CreateNoteResponse: Content {
    var id: UUID?
    var title: String
    var description: String
    var isHidden: Bool
    var userId: UUID
    var createdAt: Date
}

extension CreateNoteResponse {
    init(from note: Note) {
        self.init(id: note.id,
                  title: note.title,
                  description: note.description,
                  isHidden: note.isHidden,
                  userId: note.$user.id,
                  createdAt: note.createdAt)
    }
}
