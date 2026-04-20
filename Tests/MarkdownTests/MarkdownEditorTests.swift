import XCTest

// MARK: - EditorViewMode Tests

final class EditorViewModeTests: XCTestCase {

    // Test 1: EditorViewMode has three cases: editorOnly, previewOnly, split
    func test_editorViewMode_hasThreeCases() {
        let modes: [EditorViewMode] = [.editorOnly, .previewOnly, .split]
        XCTAssertEqual(modes.count, 3)
    }

    // Test 2: Default mode is split (editor + preview side-by-side)
    func test_editorViewMode_defaultIsSplit() {
        let defaultMode = EditorViewMode.defaultMode
        XCTAssertEqual(defaultMode, .split)
    }

    // Test 3: Each mode has a display name
    func test_editorViewMode_editorOnlyDisplayName() {
        XCTAssertFalse(EditorViewMode.editorOnly.displayName.isEmpty)
    }

    func test_editorViewMode_previewOnlyDisplayName() {
        XCTAssertFalse(EditorViewMode.previewOnly.displayName.isEmpty)
    }

    func test_editorViewMode_splitDisplayName() {
        XCTAssertFalse(EditorViewMode.split.displayName.isEmpty)
    }

    // Test 4: Each mode has a system symbol name for toolbar icon
    func test_editorViewMode_editorOnlySymbol() {
        XCTAssertFalse(EditorViewMode.editorOnly.symbolName.isEmpty)
    }

    func test_editorViewMode_previewOnlySymbol() {
        XCTAssertFalse(EditorViewMode.previewOnly.symbolName.isEmpty)
    }

    func test_editorViewMode_splitSymbol() {
        XCTAssertFalse(EditorViewMode.split.symbolName.isEmpty)
    }

    // Test 5: showsEditor and showsPreview computed properties
    func test_editorOnly_showsEditorTrue_showsPreviewFalse() {
        XCTAssertTrue(EditorViewMode.editorOnly.showsEditor)
        XCTAssertFalse(EditorViewMode.editorOnly.showsPreview)
    }

    func test_previewOnly_showsEditorFalse_showsPreviewTrue() {
        XCTAssertFalse(EditorViewMode.previewOnly.showsEditor)
        XCTAssertTrue(EditorViewMode.previewOnly.showsPreview)
    }

    func test_split_showsBoth() {
        XCTAssertTrue(EditorViewMode.split.showsEditor)
        XCTAssertTrue(EditorViewMode.split.showsPreview)
    }

    // Test 6: Equatable (needed for state comparisons)
    func test_editorViewMode_equatable() {
        XCTAssertEqual(EditorViewMode.split, EditorViewMode.split)
        XCTAssertNotEqual(EditorViewMode.split, EditorViewMode.editorOnly)
    }
}

// MARK: - MarkdownEditorState Tests

final class MarkdownEditorStateTests: XCTestCase {

    // Test 7: MarkdownEditorState initializes with text content
    func test_markdownEditorState_initWithText() {
        let state = MarkdownEditorState(text: "# Hello")
        XCTAssertEqual(state.text, "# Hello")
    }

    // Test 8: Default view mode is split
    func test_markdownEditorState_defaultViewMode() {
        let state = MarkdownEditorState(text: "")
        XCTAssertEqual(state.viewMode, .split)
    }

    // Test 9: Can toggle view mode
    func test_markdownEditorState_cycleViewMode() {
        var state = MarkdownEditorState(text: "")
        XCTAssertEqual(state.viewMode, .split)

        state.cycleViewMode()
        XCTAssertEqual(state.viewMode, .editorOnly)

        state.cycleViewMode()
        XCTAssertEqual(state.viewMode, .previewOnly)

        state.cycleViewMode()
        XCTAssertEqual(state.viewMode, .split)
    }

    // Test 10: Updating text updates the text property
    func test_markdownEditorState_updateText() {
        var state = MarkdownEditorState(text: "# Hello")
        state.text = "# World"
        XCTAssertEqual(state.text, "# World")
    }

    // Test 11: isEdited is false initially
    func test_markdownEditorState_isEditedFalseInitially() {
        let state = MarkdownEditorState(text: "# Hello")
        XCTAssertFalse(state.isEdited)
    }

    // Test 12: isEdited becomes true after text modification
    func test_markdownEditorState_isEditedAfterModification() {
        var state = MarkdownEditorState(text: "# Hello")
        state.markEdited()
        XCTAssertTrue(state.isEdited)
    }
}
