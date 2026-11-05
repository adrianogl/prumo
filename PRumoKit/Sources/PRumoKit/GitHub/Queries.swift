public enum Queries {
    public static let mine = "is:pr is:open author:@me archived:false"
    public static let review = "is:pr is:open user-review-requested:@me archived:false"

    public static let states = "query($ids:[ID!]!){ nodes(ids:$ids){ ... on PullRequest { id state } } }"

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
            headRefName
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
            timelineItems(itemTypes: [REVIEW_REQUESTED_EVENT], last: 10) {
              nodes {
                __typename
                ... on ReviewRequestedEvent {
                  createdAt
                  requestedReviewer { ... on User { login } }
                }
              }
            }
          }
        }
      }
    }
    """
}
