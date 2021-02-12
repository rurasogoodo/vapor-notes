import Vapor

struct CreateNoteRequest: Content {
    var title: String
    var description: String
    var isHidden: Bool
}

extension CreateNoteRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: .count(3...))
        validations.add("description", as: String.self, is: .count(10...))
    }
}
