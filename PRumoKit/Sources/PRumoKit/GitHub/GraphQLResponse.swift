import Foundation

struct GraphQLResponse: Decodable {
    let data: DataNode

    struct DataNode: Decodable {
        let viewer: Viewer
        let search: Search
    }

    struct Viewer: Decodable {
        let login: String
    }

    struct Search: Decodable {
        let nodes: [LossyNode<PullRequestNode>]

        var pullRequests: [PullRequestNode] { nodes.compactMap(\.value) }
    }

    struct Nodes<T: Decodable>: Decodable {
        let nodes: [T]
    }

    struct Author: Decodable {
        let login: String
        let typename: String?

        enum CodingKeys: String, CodingKey {
            case login
            case typename = "__typename"
        }
    }

    struct Repository: Decodable {
        let nameWithOwner: String
    }

    struct PullRequestNode: Decodable {
        let id: String
        let number: Int
        let title: String
        let url: URL
        let isDraft: Bool
        let createdAt: Date
        let updatedAt: Date
        let additions: Int
        let deletions: Int
        let mergeable: String
        let reviewDecision: String?
        let headRefName: String?
        let baseRefName: String?
        let isCrossRepository: Bool?
        let repository: Repository
        let author: Author?
        let commits: Nodes<CommitNode>
        let reviews: Nodes<ReviewNode>
        let comments: CommentConnection
        let reviewRequests: Nodes<LossyNode<ReviewRequestNode>>?
        let timelineItems: Nodes<TimelineEvent>
    }

    struct CommitNode: Decodable {
        let commit: Commit
    }

    struct Commit: Decodable {
        let oid: String
        let statusCheckRollup: Rollup?
    }

    struct Rollup: Decodable {
        let state: String
        let contexts: Contexts
    }

    struct Contexts: Decodable {
        let totalCount: Int
        let nodes: [Context]
    }

    struct Context: Decodable {
        let typename: String
        let name: String?
        let status: String?
        let conclusion: String?
        let detailsUrl: String?
        let context: String?
        let state: String?
        let startedAt: Date?
        let createdAt: Date?
        let checkSuite: CheckSuite?

        enum CodingKeys: String, CodingKey {
            case typename = "__typename"
            case name, status, conclusion, detailsUrl, context, state, startedAt, createdAt, checkSuite
        }
    }

    struct CheckSuite: Decodable {
        let createdAt: Date?
        let workflowRun: WorkflowRun?
    }

    struct WorkflowRun: Decodable {
        let databaseId: Int?
    }

    struct ReviewNode: Decodable {
        let id: String
        let state: String
        let submittedAt: Date?
        let url: URL?
        let body: String?
        let author: Author?
    }

    struct CommentConnection: Decodable {
        let totalCount: Int
        let nodes: [CommentNode]
    }

    struct CommentNode: Decodable {
        let id: String
        let url: URL
        let body: String
        let createdAt: Date
        let author: Author?
    }

    struct TimelineEvent: Decodable {
        let typename: String
        let createdAt: Date?
        let requestedReviewer: Reviewer?

        enum CodingKeys: String, CodingKey {
            case typename = "__typename"
            case createdAt, requestedReviewer
        }
    }

    struct ReviewRequestNode: Decodable {
        let requestedReviewer: Reviewer?
    }

    struct Reviewer: Decodable {
        let typename: String?
        let login: String?
        let name: String?

        enum CodingKeys: String, CodingKey {
            case typename = "__typename"
            case login, name
        }
    }
}
