public enum ReviewInclusion {
    public static func visible(_ prs: [PullRequest], ignoreDrafts: Bool, includeTeam: Bool) -> [PullRequest] {
        prs.filter { pr in
            (includeTeam || pr.reviewTarget == .you) && !(ignoreDrafts && pr.isDraft)
        }
    }
}
