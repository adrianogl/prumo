import Foundation
import Testing
@testable import PRumoKit

@Suite struct WidgetSharedStoreTests {
    @Test func roundTripPreservesUpdatedAtToTheSecond() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_793_800_123)
        let snapshot = WidgetSnapshot(toReview: 2, ciFailing: 1, readyToMerge: 3, updatedAt: updatedAt)
        let data = try WidgetSharedStore.makeEncoder().encode(snapshot)
        let decoded = try WidgetSharedStore.makeDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.updatedAt.timeIntervalSince1970.rounded() == updatedAt.timeIntervalSince1970)
        #expect(decoded == snapshot)
    }
}
