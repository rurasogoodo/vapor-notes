import Vapor

struct DataResponse<T: Content>: Content {
    let data: T
}

extension DataResponse where T: Collection { }
