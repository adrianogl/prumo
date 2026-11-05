import Foundation

enum GitLabQueries {
    static let currentUser = "query { currentUser { username } }"

    static func pipelineRetry(runID: Int) -> String {
        "mutation { pipelineRetry(input: {id: \"gid://gitlab/Ci::Pipeline/\(runID)\"}) { errors } }"
    }

    static func snapshot(_ capabilities: GitLabCapabilities) -> String {
        let mergeStatus = capabilities.hasDetailedMergeStatus ? " detailedMergeStatus" : ""
        let reviewer = capabilities.hasReviewState ? "username mergeRequestInteraction { reviewState }" : "username"
        return """
        query($mergedAfter: Time!) {
          currentUser {
            username
            authored: authoredMergeRequests(state: opened, first: 50, sort: UPDATED_DESC) { nodes { ...mr } }
            review: reviewRequestedMergeRequests(state: opened, first: 50, sort: UPDATED_DESC) { nodes { ...mr } }
            merged: authoredMergeRequests(state: merged, mergedAfter: $mergedAfter, first: 50) {
              nodes { iid title webUrl mergedAt project { id fullPath } }
            }
          }
        }
        fragment mr on MergeRequest {
          iid title webUrl draft createdAt updatedAt
          sourceBranch targetBranch sourceProjectId targetProjectId diffHeadSha
          conflicts\(mergeStatus) userNotesCount
          diffStatsSummary { additions deletions }
          project { id fullPath }
          author { username }
          approvedBy { nodes { username } }
          reviewers { nodes { \(reviewer) } }
          headPipeline { id status jobs(first: 100) { count nodes { id name status allowFailure } } }
          notes(last: 50) { nodes { id body system createdAt url author { username bot } } }
        }
        """
    }

    static func mergedAfter(since now: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return formatter.string(from: calendar.startOfDay(for: now))
    }
}
