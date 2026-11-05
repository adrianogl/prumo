import Foundation
import Testing
@testable import PRumoKit

@Suite struct PromptTemplateTests {
    @Test func rendersAllVariables() {
        let pr = PullRequest.fixture(ci: .failure(failedChecks: ["build"], total: 3), failedRunID: 99)
        let values = PromptValues.ci(pr)
        let template = "{numero}|{url}|{repo}|{branch}|{titulo}|{job}|{run}"
        let result = PromptTemplate.render(template, values: values)
        #expect(result == "812|https://github.com/acme/loja/pull/812|acme/loja|feat/carrinho|Corrige cálculo do carrinho|build|99")
    }

    @Test func unknownVariableStaysLiteral() {
        let result = PromptTemplate.render("a {numero} {desconhecida} {", values: ["numero": "5"])
        #expect(result == "a 5 {desconhecida} {")
    }

    @Test func valueContainingPlaceholderIsNotReExpanded() {
        let result = PromptTemplate.render("{titulo} {numero}", values: ["titulo": "usa {numero}", "numero": "7"])
        #expect(result == "usa {numero} 7")
    }

    @Test func reviewValuesOmitJobAndRun() {
        let values = PromptValues.review(.fixture())
        #expect(values["job"] == nil)
        #expect(values["run"] == nil)
        #expect(values["numero"] == "812")
    }

    @Test func defaultsMatchSpec() {
        let defaults = ClaudeSettings.defaults
        #expect(defaults.reviewTemplate == "/code-review {numero}")
        #expect(defaults.ciTemplate == "A CI do PR #{numero} ({repo}) falhou no job {job}. Leia o log com gh run view {run} --log-failed, encontre a causa e corrija.")
        #expect(defaults.conflictTemplate == "O PR #{numero} ({repo}) está em conflito com {base}. Atualize a branch com git fetch origin {base} e git merge origin/{base}, resolva os conflitos mantendo a intenção das duas partes, rode os testes e faça commit do merge.")
        #expect(defaults.commentsTemplate == "O PR #{numero} ({repo}) recebeu comentários de review. Leia os comentários com gh pr view {numero} --comments e gh api repos/{repo}/pulls/{numero}/comments, aplique as alterações pedidas que fizerem sentido, rode os testes e faça commit. Não responda nem resolva as conversas no GitHub; me mostre um resumo do que mudou e do que você não aplicou.")
        #expect(defaults.extraFlags == "")
        #expect(defaults.terminal == .ghostty)
        #expect(defaults.clonesRoot == "~/Code")
        #expect(defaults.worktreesRoot == "~/Code/.prumo-worktrees")
        #expect(defaults.removeWorktreeOnClose)
        #expect(defaults.cloneOverrides.isEmpty)
    }

    @Test func ciValuesUseFirstFailedCheckAndRun() {
        let pr = PullRequest.fixture(ci: .failure(failedChecks: ["lint", "test"], total: 4), failedRunID: 1234)
        let values = PromptValues.ci(pr)
        #expect(values["job"] == "lint")
        #expect(values["run"] == "1234")
        #expect(values["repo"] == "acme/loja")
    }

    @Test func conflictValuesAddBase() {
        let values = PromptValues.conflict(.fixture(baseRefName: "develop"))
        #expect(values["base"] == "develop")
        #expect(values["numero"] == "812")
        #expect(values["branch"] == "feat/carrinho")
        #expect(PromptValues.review(.fixture())["base"] == nil)
    }

    @Test func commentsValuesMatchReviewValues() {
        let pr = PullRequest.fixture()
        #expect(PromptValues.comments(pr) == PromptValues.review(pr))
    }

    @Test func ciValuesAreEmptyWithoutFailure() {
        let values = PromptValues.ci(.fixture(ci: .success(total: 2)))
        #expect(values["job"] == "")
        #expect(values["run"] == "")
    }

    @Test func settingsRoundTripCodable() throws {
        var settings = ClaudeSettings.defaults
        settings.terminal = .custom(template: "open -a X {dir} {cmd}")
        settings.cloneOverrides = ["acme/loja": "/tmp/loja"]
        settings.extraFlags = "--model opus"
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(ClaudeSettings.self, from: data) == settings)
    }

    @Test func terminalKindUsesStableEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let custom = try String(decoding: encoder.encode(TerminalKind.custom(template: "t {dir}")), as: UTF8.self)
        #expect(custom == #"{"kind":"custom","template":"t {dir}"}"#)
        let ghostty = try String(decoding: encoder.encode(TerminalKind.ghostty), as: UTF8.self)
        #expect(ghostty == #"{"kind":"ghostty"}"#)
        for kind in [TerminalKind.ghostty, .terminal, .iterm, .custom(template: "x")] {
            let data = try encoder.encode(kind)
            #expect(try JSONDecoder().decode(TerminalKind.self, from: data) == kind)
        }
    }

    @Test func gitlabCITemplateRendersJobAndPipeline() {
        let pr = PullRequest.fixture(
            repository: "grupo/app", ci: .failure(failedChecks: ["test"], total: 2),
            failedRunID: 987, provider: .gitlab, failedJobID: 555)
        let result = PromptTemplate.render(ClaudeSettings.defaults.gitlabCiTemplate, values: PromptValues.ci(pr))
        #expect(result == "A pipeline 987 do MR !812 (grupo/app) falhou no job test. Leia o log com glab ci trace 555 e o estado da pipeline com glab ci get --pipeline-id 987, encontre a causa e corrija.")
        #expect(PromptValues.ci(.fixture())["jobid"] == "")
    }
}
