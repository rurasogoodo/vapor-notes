import Vapor

struct UpdateNoteRequest: Content {
    var title: String
    var description: String
    var isHidden: Bool
}

extension UpdateNoteRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("title", as: String.self, is: .count(3...))
        validations.add("description", as: String.self, is: .count(10...))
    }
}
