import Foundation

public enum Queries {
    public static let viewer = "query { viewer { login } }"
    public static let mine = "is:pr is:open author:@me archived:false"
    public static let review = "is:pr is:open review-requested:@me archived:false"

    public static func merged(since now: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let midnight = calendar.startOfDay(for: now)
        let parts = calendar.dateComponents([.year, .month, .day], from: midnight)
        let offset = timeZone.secondsFromGMT(for: midnight)
        let sign = offset < 0 ? "-" : "+"
        let absolute = abs(offset)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let zone = String(format: "%@%02d:%02d", sign, absolute / 3600, absolute % 3600 / 60)
        return "is:pr author:@me is:merged merged:>=\(day)T00:00:00\(zone) archived:false"
    }

    public static let states = "query($ids:[ID!]!){ nodes(ids:$ids){ ... on PullRequest { id state } } }"

    public static let mergedSearchQuery = """
    query($q: String!) {
      search(query: $q, type: ISSUE, first: 50) {
        nodes {
          ... on PullRequest {
            id
            number
            title
            url
            mergedAt
            repository { nameWithOwner }
          }
        }
      }
    }
    """

    public static let searchQuery = """
    query($q: String!) {
      viewer { login }
      search(query: $q, type: ISSUE, first: 50) {
        nodes {
          ... on PullRequest {
            id
            number
            title
            url
            isDraft
            createdAt
            updatedAt
            additions
            deletions
            mergeable
            reviewDecision
            headRefName
            baseRefName
            isCrossRepository
            repository { nameWithOwner }
            author { __typename login }
            commits(last: 1) {
              nodes {
                commit {
                  oid
                  statusCheckRollup {
                    state
                    contexts(first: 100) {
                      totalCount
                      nodes {
                        __typename
                        ... on CheckRun { name status conclusion detailsUrl }
                        ... on StatusContext { context state }
                      }
                    }
                  }
                }
              }
            }
            reviews(last: 30) {
              nodes { id state submittedAt url body author { __typename login } }
            }
            comments(last: 20) {
              totalCount
              nodes { id url body createdAt author { __typename login } }
            }
            reviewRequests(first: 20) {
              nodes {
                requestedReviewer {
                  __typename
                  ... on User { login }
                  ... on Team { name }
                }
              }
            }
            timelineItems(itemTypes: [REVIEW_REQUESTED_EVENT], last: 10) {
              nodes {
                __typename
                ... on ReviewRequestedEvent {
                  createdAt
                  requestedReviewer { ... on User { login } ... on Team { name } }
                }
              }
            }
          }
        }
      }
    }
    """
}
