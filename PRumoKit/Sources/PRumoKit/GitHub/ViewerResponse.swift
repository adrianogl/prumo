struct ViewerResponse: Decodable {
    let data: DataNode

    struct DataNode: Decodable {
        let viewer: Viewer
    }

    struct Viewer: Decodable {
        let login: String
    }
}
