import Vapor
import Fluent

final class Note: Model {
    static let schema = "notes"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "description")
    var description: String
    
    @Field(key: "is_note_hidden")
    var isHidden: Bool
    
    @Field(key: "createdAt")
    var createdAt: Date
    
    @Parent(key: "userID")
    var user: User
    
    init() {}
    
    init(id: UUID? = nil,
         title: String,
         description: String,
         isHidden: Bool = false,
         createdAt: Date,
         userID: User.IDValue) {
        self.id = id
        self.title = title
        self.description = description
        self.isHidden = isHidden
        self.createdAt = createdAt
        self.$user.id = userID
    }
}
