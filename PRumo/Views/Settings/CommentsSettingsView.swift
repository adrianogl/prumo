import SwiftUI
import PRumoKit

struct CommentsSettingsView: View {
    let store: OrganizationStore

    var body: some View {
        Form {
            Section {
                ForEach(store.settings.ignoredCommentAuthors.indices, id: \.self) { index in
                    authorRow(index)
                }
                Button(CommentsSettingsText.addAuthor) {
                    store.settings.ignoredCommentAuthors.append("")
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CommentsSettingsText.ignoredAuthors)
                    Text(CommentsSettingsText.note)
                        .font(.system(size: CommentsSettingsMetrics.hintSize))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear(perform: dropBlankAuthors)
    }

    private func authorRow(_ index: Int) -> some View {
        HStack {
            TextField(CommentsSettingsText.author, text: author(at: index))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            Button {
                remove(at: index)
            } label: {
                Label(CommentsSettingsText.remove, systemImage: CommentsSettingsSymbol.remove)
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(CommentsSettingsText.remove)
        }
    }

    private func author(at index: Int) -> Binding<String> {
        Binding(
            get: {
                let authors = store.settings.ignoredCommentAuthors
                return authors.indices.contains(index) ? authors[index] : ""
            },
            set: { value in
                guard store.settings.ignoredCommentAuthors.indices.contains(index) else { return }
                store.settings.ignoredCommentAuthors[index] = value
            })
    }

    private func remove(at index: Int) {
        guard store.settings.ignoredCommentAuthors.indices.contains(index) else { return }
        store.settings.ignoredCommentAuthors.remove(at: index)
    }

    private func dropBlankAuthors() {
        let kept = store.settings.ignoredCommentAuthors.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if kept != store.settings.ignoredCommentAuthors { store.settings.ignoredCommentAuthors = kept }
    }
}
