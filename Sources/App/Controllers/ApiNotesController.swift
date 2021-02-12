import Vapor
import Fluent

struct ApiNotesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group("notes") { notes in
            notes.group(UserAuthenticator()) { authenticated in
                authenticated.post("create", use: createNote)
            }
        }
    }
    
    private func createNote(_ req: Request) throws -> EventLoopFuture<NoteDTO> {
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
                        .transform(to: NoteDTO(from: newNote, user: user))
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
    }
}
