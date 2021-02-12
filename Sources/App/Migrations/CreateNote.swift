import Fluent

struct CreateNote: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("notes")
            .id()
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("is_note_hidden", .bool, .required, .custom("DEFAULT FALSE"))
            .field("createdAt", .datetime, .required)
            .field("userID", .uuid, .required, .references("users", "id"))
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("notes").delete()
    }
}
