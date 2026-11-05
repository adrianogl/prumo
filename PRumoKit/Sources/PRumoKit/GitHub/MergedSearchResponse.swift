import Foundation

struct MergedSearchResponse: Decodable {
    let data: DataNode

    struct DataNode: Decodable {
        let search: Search
    }

    struct Search: Decodable {
        let nodes: [LossyNode<Node>]

        var pullRequests: [Node] { nodes.compactMap(\.value) }
    }

    struct Node: Decodable {
        let id: String
        let number: Int
        let title: String
        let url: URL
        let mergedAt: Date
        let repository: GraphQLResponse.Repository
    }
}
