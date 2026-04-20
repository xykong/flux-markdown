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

// MARK: - MarkdownEditorTextModel Tests

final class MarkdownEditorTextModelTests: XCTestCase {

    func test_textModel_initWithText() {
        let model = MarkdownEditorTextModel(text: "# Hello\nWorld")
        XCTAssertEqual(model.text, "# Hello\nWorld")
    }

    func test_textModel_lineCount_emptyString() {
        let model = MarkdownEditorTextModel(text: "")
        XCTAssertEqual(model.lineCount, 1)
    }

    func test_textModel_lineCount_singleLine() {
        let model = MarkdownEditorTextModel(text: "hello")
        XCTAssertEqual(model.lineCount, 1)
    }

    func test_textModel_lineCount_multipleLines() {
        let model = MarkdownEditorTextModel(text: "line1\nline2\nline3")
        XCTAssertEqual(model.lineCount, 3)
    }

    func test_textModel_wordCount_empty() {
        let model = MarkdownEditorTextModel(text: "")
        XCTAssertEqual(model.wordCount, 0)
    }

    func test_textModel_wordCount_singleWord() {
        let model = MarkdownEditorTextModel(text: "hello")
        XCTAssertEqual(model.wordCount, 1)
    }

    func test_textModel_wordCount_multipleWords() {
        let model = MarkdownEditorTextModel(text: "Hello World Foo")
        XCTAssertEqual(model.wordCount, 3)
    }

    func test_textModel_wordCount_ignoresMarkdownSyntax() {
        let model = MarkdownEditorTextModel(text: "# Hello **World**")
        XCTAssertEqual(model.wordCount, 2)
    }

    func test_textModel_charCount() {
        let model = MarkdownEditorTextModel(text: "abc")
        XCTAssertEqual(model.charCount, 3)
    }

    func test_textModel_charCount_empty() {
        let model = MarkdownEditorTextModel(text: "")
        XCTAssertEqual(model.charCount, 0)
    }

    func test_textModel_statusText_showsLineWordChar() {
        let model = MarkdownEditorTextModel(text: "# Hello\nWorld foo")
        let status = model.statusText
        XCTAssertTrue(status.contains("2"))
        XCTAssertTrue(status.contains("3"))
    }
}

// MARK: - EditorLayoutConfig Tests

final class EditorLayoutConfigTests: XCTestCase {

    func test_layoutConfig_splitHasBothPanes() {
        let config = EditorLayoutConfig(viewMode: .split)
        XCTAssertTrue(config.showsEditorPane)
        XCTAssertTrue(config.showsPreviewPane)
    }

    func test_layoutConfig_editorOnlyHasOnlyEditorPane() {
        let config = EditorLayoutConfig(viewMode: .editorOnly)
        XCTAssertTrue(config.showsEditorPane)
        XCTAssertFalse(config.showsPreviewPane)
    }

    func test_layoutConfig_previewOnlyHasOnlyPreviewPane() {
        let config = EditorLayoutConfig(viewMode: .previewOnly)
        XCTAssertFalse(config.showsEditorPane)
        XCTAssertTrue(config.showsPreviewPane)
    }

    func test_layoutConfig_split_dividerPosition_isHalf() {
        let config = EditorLayoutConfig(viewMode: .split)
        XCTAssertEqual(config.editorWidthFraction, 0.5, accuracy: 0.01)
    }

    func test_layoutConfig_editorOnly_widthFraction_isOne() {
        let config = EditorLayoutConfig(viewMode: .editorOnly)
        XCTAssertEqual(config.editorWidthFraction, 1.0, accuracy: 0.01)
    }

    func test_layoutConfig_previewOnly_widthFraction_isZero() {
        let config = EditorLayoutConfig(viewMode: .previewOnly)
        XCTAssertEqual(config.editorWidthFraction, 0.0, accuracy: 0.01)
    }

    func test_layoutConfig_minWindowWidth_split() {
        let config = EditorLayoutConfig(viewMode: .split)
        XCTAssertGreaterThanOrEqual(config.minWindowWidth, 640)
    }

    func test_layoutConfig_minWindowWidth_single() {
        let configEditor = EditorLayoutConfig(viewMode: .editorOnly)
        let configPreview = EditorLayoutConfig(viewMode: .previewOnly)
        XCTAssertGreaterThanOrEqual(configEditor.minWindowWidth, 320)
        XCTAssertGreaterThanOrEqual(configPreview.minWindowWidth, 320)
    }
}

// MARK: - EditorToolbarState Tests

final class EditorToolbarStateTests: XCTestCase {

    func test_toolbarState_initialViewModeIsSplit() {
        let state = EditorToolbarState()
        XCTAssertEqual(state.viewMode, .split)
    }

    func test_toolbarState_cycleChangesMode() {
        var state = EditorToolbarState()
        state.cycleViewMode()
        XCTAssertEqual(state.viewMode, .editorOnly)
    }

    func test_toolbarState_toggleButtonSymbol_split() {
        let state = EditorToolbarState(viewMode: .split)
        XCTAssertEqual(state.toggleButtonSymbol, EditorViewMode.split.symbolName)
    }

    func test_toolbarState_toggleButtonSymbol_editorOnly() {
        let state = EditorToolbarState(viewMode: .editorOnly)
        XCTAssertEqual(state.toggleButtonSymbol, EditorViewMode.editorOnly.symbolName)
    }

    func test_toolbarState_toggleButtonLabel_split() {
        let state = EditorToolbarState(viewMode: .split)
        XCTAssertEqual(state.toggleButtonLabel, EditorViewMode.split.displayName)
    }

    func test_toolbarState_isEditing_trueWhenEditorVisible() {
        let stateSplit = EditorToolbarState(viewMode: .split)
        let stateEditor = EditorToolbarState(viewMode: .editorOnly)
        let statePreview = EditorToolbarState(viewMode: .previewOnly)
        XCTAssertTrue(stateSplit.isEditing)
        XCTAssertTrue(stateEditor.isEditing)
        XCTAssertFalse(statePreview.isEditing)
    }
}

// MARK: - LivePreviewCoordinator Tests

final class LivePreviewCoordinatorTests: XCTestCase {

    func test_coordinator_initialPreviewContentMatchesText() {
        let coord = LivePreviewCoordinator(initialText: "# Hello")
        XCTAssertEqual(coord.previewContent, "# Hello")
    }

    func test_coordinator_updateText_updatesPreviewContent() {
        var coord = LivePreviewCoordinator(initialText: "")
        coord.updateText("# New Content")
        XCTAssertEqual(coord.previewContent, "# New Content")
    }

    func test_coordinator_updateText_marksNeedsRender() {
        var coord = LivePreviewCoordinator(initialText: "initial")
        XCTAssertFalse(coord.needsRender)
        coord.updateText("changed")
        XCTAssertTrue(coord.needsRender)
    }

    func test_coordinator_acknowledgeRender_clearsNeedsRender() {
        var coord = LivePreviewCoordinator(initialText: "")
        coord.updateText("something")
        XCTAssertTrue(coord.needsRender)
        coord.acknowledgeRender()
        XCTAssertFalse(coord.needsRender)
    }

    func test_coordinator_sameText_doesNotMarkNeedsRender() {
        var coord = LivePreviewCoordinator(initialText: "# Same")
        coord.acknowledgeRender()
        coord.updateText("# Same")
        XCTAssertFalse(coord.needsRender)
    }

    func test_coordinator_emptyUpdate_doesNotMarkNeedsRender() {
        var coord = LivePreviewCoordinator(initialText: "")
        coord.acknowledgeRender()
        coord.updateText("")
        XCTAssertFalse(coord.needsRender)
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
