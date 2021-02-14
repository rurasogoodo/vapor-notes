import Vapor
import Fluent

struct ApiNotesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group("notes") { notes in
            notes.group(UserAuthenticator()) { authenticated in
                authenticated.post("create", use: createNote)
                authenticated.get("allNotes", use: fetchAllNotes)
                authenticated.delete(":noteId", use: deleteNote)
                authenticated.put(":noteId", use: updateNote)
                authenticated.get(":noteId", use: fetchNote)
            }
        }
    }
    
    private func createNote(_ req: Request) throws -> EventLoopFuture<DataResponse<NoteDTO>> {
        try CreateNoteRequest.validate(content: req)
        let payload = try req.auth.require(Payload.self)
        let createRequest = try req.content.decode(CreateNoteRequest.self)
        
        return req.users.find(id: payload.userID)
            .unwrap(or: AuthenticationError.userNotFound)
            .flatMap { user in
                do {
                    let newNote = try Note(title: createRequest.title,
                                           description: createRequest.description,
                                           isHidden: createRequest.isHidden,
                                           createdAt: Date(),
                                           userID: user.requireID())
                    return user.$notes.create(newNote, on: req.db)
                        .transform(to: DataResponse<NoteDTO>(data: NoteDTO(from: newNote, user: user)))
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
    }
    
    private func fetchAllNotes(_ req: Request) throws -> EventLoopFuture<DataResponse<[NoteDTO]>> {
        let payload = try req.auth.require(Payload.self)
        return req.users.find(id: payload.userID)
            .unwrap(or: Abort(.notFound))
            .flatMap { user in
                req.notes.fetchAll(for: user.id)
                    .mapEach { NoteDTO(from: $0, user: user) }
                    .map { DataResponse<[NoteDTO]>(data: $0) }
            }
    }
    
    private func deleteNote(_ req: Request) throws -> EventLoopFuture<HTTPStatus> {
        Note.find(req.parameters.get("noteId"), on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db) }
            .transform(to: .noContent)
    }
    
    private func updateNote(_ req: Request) throws -> EventLoopFuture<DataResponse<NoteDTO>> {
        let payload = try req.auth.require(Payload.self)
        let updatedData = try req.content.decode(UpdateNoteRequest.self)
        
        let noteQuery = req.notes.find(id: req.parameters.get("noteId")).unwrap(or: Abort(.notFound))
        let userQuery = req.users.find(id: payload.userID).unwrap(or: Abort(.notFound))
        
        return userQuery.and(noteQuery)
            .flatMap { user, note in
                note.title = updatedData.title
                note.description = updatedData.description
                note.isHidden = updatedData.isHidden
                return note.update(on: req.db)
                    .map { DataResponse<NoteDTO>(data: NoteDTO(from: note, user: user)) }
            }
    }
    
    private func fetchNote(_ req: Request) throws -> EventLoopFuture<DataResponse<NoteDTO>> {
        let payload = try req.auth.require(Payload.self)
        let noteQuery = req.notes.find(id: req.parameters.get("noteId")).unwrap(or: Abort(.notFound))
        let userQuery = req.users.find(id: payload.userID).unwrap(or: Abort(.notFound))
        
        return userQuery.and(noteQuery)
            .flatMap { user, note in
                req.eventLoop.future(DataResponse<NoteDTO>(data: NoteDTO(from: note, user: user)))
            }
    }
}
