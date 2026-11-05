import Testing
@testable import PRumoKit

@Suite struct KeyboardSelectionTests {
    let ids = ["A", "B", "C"]

    @Test func downFromNoneSelectsFirst() {
        #expect(KeyboardSelection.move(from: nil, in: ids, direction: .down) == "A")
    }

    @Test func upFromNoneSelectsLast() {
        #expect(KeyboardSelection.move(from: nil, in: ids, direction: .up) == "C")
    }

    @Test func movesBetweenRows() {
        #expect(KeyboardSelection.move(from: "B", in: ids, direction: .down) == "C")
        #expect(KeyboardSelection.move(from: "B", in: ids, direction: .up) == "A")
    }

    @Test func clampsAtEnds() {
        #expect(KeyboardSelection.move(from: "C", in: ids, direction: .down) == "C")
        #expect(KeyboardSelection.move(from: "A", in: ids, direction: .up) == "A")
    }

    @Test func emptyListGivesNil() {
        #expect(KeyboardSelection.move(from: nil, in: [], direction: .down) == nil)
        #expect(KeyboardSelection.move(from: "A", in: [], direction: .up) == nil)
        #expect(KeyboardSelection.validated("A", in: []) == nil)
    }

    @Test func unknownCurrentBehavesAsNone() {
        #expect(KeyboardSelection.move(from: "X", in: ids, direction: .down) == "A")
    }

    @Test func selectionKeptWhileRowExists() {
        #expect(KeyboardSelection.validated("B", in: ids) == "B")
        #expect(KeyboardSelection.validated(nil, in: ids) == nil)
    }

    @Test func selectionDroppedWhenRowDisappears() {
        #expect(KeyboardSelection.validated("B", in: ["A", "C"]) == nil)
    }
}
