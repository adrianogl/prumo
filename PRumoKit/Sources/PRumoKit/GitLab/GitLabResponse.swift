import Foundation

struct GitLabResponse: Decodable {
    let data: DataNode

    struct DataNode: Decodable {
        let currentUser: CurrentUser?
    }

    struct CurrentUser: Decodable {
        let username: String
        let authored: Nodes<LossyNode<MergeRequestNode>>
        let review: Nodes<LossyNode<MergeRequestNode>>
        let merged: Nodes<LossyNode<MergedNode>>?
    }

    struct Nodes<T: Decodable>: Decodable {
        let nodes: [T]
    }

    struct Project: Decodable {
        let id: String
        let fullPath: String
    }

    struct DiffStats: Decodable {
        let additions: Int
        let deletions: Int
    }

    struct Reviewer: Decodable {
        let username: String
        let mergeRequestInteraction: Interaction?
    }

    struct Interaction: Decodable {
        let reviewState: String?
    }

    struct Pipeline: Decodable {
        let id: String
        let status: String
        let jobs: Jobs?
    }

    struct Jobs: Decodable {
        let count: Int?
        let nodes: [Job]
    }

    struct Job: Decodable {
        let id: String
        let name: String?
        let status: String?
        let allowFailure: Bool?
    }

    struct MergeRequestNode: Decodable {
        let iid: String
        let title: String
        let webUrl: URL
        let draft: Bool
        let createdAt: Date
        let updatedAt: Date
        let sourceBranch: String?
        let targetBranch: String?
        let sourceProjectId: Int?
        let targetProjectId: Int?
        let diffHeadSha: String?
        let conflicts: Bool?
        let detailedMergeStatus: String?
        let userNotesCount: Int?
        let diffStatsSummary: DiffStats?
        let project: Project
        let author: GitLabUser?
        let approvedBy: Nodes<GitLabUser>?
        let reviewers: Nodes<Reviewer>?
        let headPipeline: Pipeline?
        let notes: Nodes<LossyNode<GitLabNote>>?
    }

    struct MergedNode: Decodable {
        let iid: String
        let title: String
        let webUrl: URL
        let mergedAt: Date?
        let project: Project
    }
}
