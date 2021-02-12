import Vapor
import Fluent

protocol NoteRepository: Repository {
    func create(_ note: Note) -> EventLoopFuture<Void>
    func find(id: UUID?) -> EventLoopFuture<Note?>
    func find(title: String) -> EventLoopFuture<[Note]>
    func delete(_ note: Note) -> EventLoopFuture<Void>
    func count() -> EventLoopFuture<Int>
    func delete(for userID: UUID) -> EventLoopFuture<Void>
}

struct DatabaseNoteRepository: NoteRepository, DatabaseRepository {
    let database: Database
    
    func create(_ note: Note) -> EventLoopFuture<Void> {
        note.create(on: database)
    }
    
    func find(id: UUID?) -> EventLoopFuture<Note?> {
        Note.find(id, on: database)
    }
    
    func find(title: String) -> EventLoopFuture<[Note]> {
        Note.query(on: database)
            .filter(\.$title == title)
            .all()
    }
    
    func delete(_ note: Note) -> EventLoopFuture<Void> {
        note.delete(on: database)
    }
    
    func count() -> EventLoopFuture<Int> {
        Note.query(on: database)
            .count()
    }
    
    func delete(for userID: UUID) -> EventLoopFuture<Void> {
        Note.query(on: database)
            .filter(\.$user.$id == userID)
            .delete()
    }
}

extension Application.Repositories {
    var notes: NoteRepository {
        guard let factory = storage.makeNoteRepository else {
            fatalError("Note repository not configured, use: app.repositories.use")
        }
        return factory(app)
    }
    
    func use(_ make: @escaping (Application) -> (NoteRepository)) {
        storage.makeNoteRepository = make
    }
}
