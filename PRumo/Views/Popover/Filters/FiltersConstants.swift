import SwiftUI
import PRumoKit
import enum PRumoKit.CIFilter

enum FiltersMetrics {
    static let barSpacing: CGFloat = 6
    static let barButtonFontSize: CGFloat = 11.5
    static let barButtonCornerRadius: CGFloat = 7
    static let barButtonHorizontalPadding: CGFloat = 9
    static let barButtonVerticalPadding: CGFloat = 3
    static let chevronSize: CGFloat = 8
    static let chipFontSize: CGFloat = 11
    static let chipHorizontalPadding: CGFloat = 9
    static let chipVerticalPadding: CGFloat = 2
    static let chipSpacing: CGFloat = 6
    static let chipLineSpacing: CGFloat = 5
    static let chipRemoveSize: CGFloat = 8
    static let clearFontSize: CGFloat = 11
    static let pickerWidth: CGFloat = 270
    static let orderPickerWidth: CGFloat = 230
    static let pickerPadding: CGFloat = 8
    static let pickerRowFontSize: CGFloat = 12.5
    static let pickerNoteFontSize: CGFloat = 11.5
    static let pickerRowHorizontalPadding: CGFloat = 6
    static let pickerRowVerticalPadding: CGFloat = 4
    static let pickerRowCornerRadius: CGFloat = 5
    static let pickerListMaxHeight: CGFloat = 320
    static let groupTitleFontSize: CGFloat = 10
    static let groupTitleTracking: CGFloat = 0.7
    static let checkboxSize: CGFloat = 13
    static let checkboxCornerRadius: CGFloat = 4
    static let checkboxBorder: CGFloat = 1.5
    static let checkmarkSize: CGFloat = 8
    static let orderCheckSize: CGFloat = 10
    static let checkColumnWidth: CGFloat = 14
    static let starSize: CGFloat = 10
    static let searchFontSize: CGFloat = 12
    static let searchCornerRadius: CGFloat = 6
    static let searchHorizontalPadding: CGFloat = 8
    static let searchVerticalPadding: CGFloat = 4
    static let sectionHeaderFontSize: CGFloat = 12
    static let sectionHeaderSpacing: CGFloat = 8
    static let sectionHeaderHorizontalPadding: CGFloat = 12
    static let sectionHeaderVerticalPadding: CGFloat = 6
    static let sectionHeaderBackgroundOpacity: Double = 0.05
    static let sectionCountFontSize: CGFloat = 10.5
    static let sectionCountHorizontalPadding: CGFloat = 6
    static let sectionCountVerticalPadding: CGFloat = 1
    static let barButtonContentSpacing: CGFloat = 4
    static let barHorizontalPadding: CGFloat = 12
    static let barBottomPadding: CGFloat = 8
    static let chipContentSpacing: CGFloat = 4
    static let searchBottomPadding: CGFloat = 6
    static let searchContentSpacing: CGFloat = 5
    static let footerDividerTopPadding: CGFloat = 8
    static let footerDividerBottomPadding: CGFloat = 4
    static let dividerVerticalPadding: CGFloat = 6
    static let chipFlowHorizontalPadding: CGFloat = 4
    static let groupTitleBottomPadding: CGFloat = 3
    static let rowSpacing: CGFloat = 8
    static let rowSpacerMinLength: CGFloat = 4
    static let saveViewSpacing: CGFloat = 6
    static let viewChipRemoveSize: CGFloat = 11
    static let viewChipRemoveSpacing: CGFloat = 4
    static let viewChipRemoveTrailingPadding: CGFloat = 5
}

enum FiltersSymbol {
    static let chevron = "chevron.down"
    static let order = "arrow.up.arrow.down"
    static let remove = "xmark"
    static let removeView = "xmark.circle.fill"
    static let search = "magnifyingglass"
    static let check = "checkmark"
    static let favorite = "star.fill"
    static let notFavorite = "star"
}

enum FiltersText {
    static let repositories = "Repositórios"
    static let filters = "Filtros"
    static let groupedByRepository = "Agrupado por repo"
    static let searchRepository = "Buscar repositório"
    static let hideEmptyRepositories = "Esconder repositórios sem PR"
    static let saveAsView = "Salvar como visão…"
    static let viewNamePlaceholder = "Nome da visão"
    static let viewNameTaken = "Já existe uma visão com esse nome"
    static let save = "Salvar"
    static let cancel = "Cancelar"
    static let clear = "Limpar"
    static let viewsTitle = "VISÕES"
    static let ciTitle = "CI"
    static let reviewTitle = "REVIEW"
    static let stateTitle = "ESTADO"
    static let requestTitle = "REVISAR"
    static let authorTitle = "AUTOR"
    static let searchPerson = "Buscar pessoa"
    static let groupByRepository = "Agrupar por repositório"
    static let orderNote = "Fixados sempre no topo · silenciados no fim"
    static let favorite = "Favoritar"
    static let unfavorite = "Remover dos favoritos"
    static let removeFilter = "Remover filtro"
    static let deleteView = "Excluir visão"
    static let separator = " · "

    static func deleteView(named name: String) -> String {
        "\(deleteView) \(name)"
    }

    static func removeChip(_ label: String) -> String {
        "\(label), \(removeFilter)"
    }

    static func withCount(_ title: String, count: Int) -> String {
        count > 0 ? "\(title)\(separator)\(count)" : title
    }

    static let sectionOwnerSeparator = " / "

    static func sectionHeader(repository: String, count: Int) -> String {
        "\(repository)\(separator)\(count)"
    }

    static func label(_ value: CIFilter) -> String {
        switch value {
        case .passed: "passou"
        case .running: "rodando"
        case .failing: "falhando"
        }
    }

    static func label(_ value: ReviewFilter) -> String {
        switch value {
        case .approved: "aprovado"
        case .changesRequested: "alterações pedidas"
        case .noReview: "sem review"
        }
    }

    static func label(_ value: StateFilter) -> String {
        switch value {
        case .noDrafts: "sem drafts"
        case .conflicting: "com conflito"
        case .newActivity: "com atividade nova"
        case .pinned: "fixados"
        }
    }

    static func label(_ value: RequestFilter, staleHours: Int) -> String {
        switch value {
        case .forYou: "para você"
        case .forTeam: "para o time"
        case .stale: "parado há +\(staleHours)h"
        }
    }

    static func label(_ value: RowSortOrder) -> String {
        switch value {
        case .recentActivity: "Atividade recente"
        case .needsActionFirst: "Precisa de ação primeiro"
        case .oldestFirst: "Mais antigos primeiro"
        case .newestFirst: "Mais novos primeiro"
        case .repository: "Repositório"
        case .diffSize: "Tamanho do diff"
        }
    }
}
