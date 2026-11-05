import Foundation
import Testing
@testable import PRumoKit

@Suite struct ClaudeSettingsTests {
    @Test func decodesPartialJSONWithDefaults() throws {
        let json = #"{"extraFlags":"--model opus","removeWorktreeOnClose":false}"#
        let settings = try JSONDecoder().decode(ClaudeSettings.self, from: Data(json.utf8))
        #expect(settings.extraFlags == "--model opus")
        #expect(settings.removeWorktreeOnClose == false)
        #expect(settings.reviewTemplate == ClaudeDefaults.reviewTemplate)
        #expect(settings.ciTemplate == ClaudeDefaults.ciTemplate)
        #expect(settings.conflictTemplate == ClaudeDefaults.conflictTemplate)
        #expect(settings.commentsTemplate == ClaudeDefaults.commentsTemplate)
        #expect(settings.terminal == ClaudeDefaults.terminal)
        #expect(settings.clonesRoot == ClaudeDefaults.clonesRoot)
        #expect(settings.worktreesRoot == ClaudeDefaults.worktreesRoot)
        #expect(settings.cloneOverrides.isEmpty)
    }

    @Test func decodesEmptyObjectAsDefaults() throws {
        let settings = try JSONDecoder().decode(ClaudeSettings.self, from: Data("{}".utf8))
        #expect(settings == ClaudeSettings.defaults)
    }

    @Test func roundTrips() throws {
        let original = ClaudeSettings(terminal: .custom(template: "x {dir} {cmd}"), cloneOverrides: ["a/b": "~/x"])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(ClaudeSettings.self, from: data) == original)
    }

    @Test func commandDefaultsToClaude() {
        #expect(ClaudeSettings.defaults.command == "claude")
        #expect(ClaudeDefaults.command == "claude")
    }

    @Test func oldSettingsWithoutCommandDecode() throws {
        let json = #"{"extraFlags":"--model opus"}"#
        let settings = try JSONDecoder().decode(ClaudeSettings.self, from: Data(json.utf8))
        #expect(settings.command == "claude")
    }

    @Test func resolvedCommandTrimsAndFallsBack() {
        #expect(ClaudeSettings(command: " claude-ems ").resolvedCommand == "claude-ems")
        #expect(ClaudeSettings(command: "").resolvedCommand == "claude")
        #expect(ClaudeSettings(command: "a b").resolvedCommand == "claude")
    }

    @Test(arguments: ["claude", "claude-ems", "~/bin/claude", "/opt/homebrew/bin/claude"])
    func validCommandNames(name: String) {
        #expect(ClaudeCommandName.isValid(name))
    }

    @Test(arguments: ["claude --x", "-x", "a;b", "$(x)", "a b", "", ".", "..", "/", "//", "./", "eval", "source", "exec", "builtin", "command", "noglob"])
    func invalidCommandNames(name: String) {
        #expect(!ClaudeCommandName.isValid(name))
    }

    @Test func oldClaudeSettingsJSONGetsGitLabDefaults() throws {
        let json = #"{"reviewTemplate":"x","extraFlags":"--model opus"}"#
        let settings = try JSONDecoder().decode(ClaudeSettings.self, from: Data(json.utf8))
        #expect(settings.gitlabReviewTemplate == ClaudeDefaults.gitlabReviewTemplate)
        #expect(settings.gitlabCiTemplate == ClaudeDefaults.gitlabCiTemplate)
        #expect(settings.gitlabConflictTemplate == ClaudeDefaults.gitlabConflictTemplate)
        #expect(settings.gitlabCommentsTemplate == ClaudeDefaults.gitlabCommentsTemplate)
        #expect(settings.templates(for: .github).review == "x")
        #expect(settings.templates(for: .gitlab).review == ClaudeDefaults.gitlabReviewTemplate)
    }

    @Test func gitlabReviewDefaultUsesGlabMrDiff() {
        let review = ClaudeSettings.defaults.templates(for: .gitlab).review
        #expect(review.contains("glab mr diff {numero}"))
        #expect(review.contains("glab mr view {numero}"))
        #expect(ClaudeSettings.defaults.templates(for: .github).review == "/code-review {numero}")
    }

    @Test func gitlabDefaultsMatchSpec() {
        let templates = ClaudeSettings.defaults.templates(for: .gitlab)
        #expect(templates.review == "Revise o MR !{numero} ({repo}). Leia a descrição com glab mr view {numero} e o diff com glab mr diff {numero}, e aponte problemas de correção, segurança e contrato. Não comente no GitLab; mostre o resultado aqui.")
        #expect(templates.ci == "A pipeline {run} do MR !{numero} ({repo}) falhou no job {job}. Leia o log com glab ci trace {jobid} e o estado da pipeline com glab ci get --pipeline-id {run}, encontre a causa e corrija.")
        #expect(templates.conflict == "O MR !{numero} ({repo}) está em conflito com {base}. Atualize a branch com git fetch origin {base} e git merge origin/{base}, resolva os conflitos mantendo a intenção das duas partes, rode os testes e faça commit do merge.")
        #expect(templates.comments == "O MR !{numero} ({repo}) recebeu comentários de review. Leia os comentários com glab mr view {numero} --comments, aplique as alterações pedidas que fizerem sentido, rode os testes e faça commit. Não responda nem resolva as discussões no GitLab; me mostre um resumo do que mudou e do que você não aplicou.")
    }
}
