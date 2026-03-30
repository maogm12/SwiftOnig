import Darwin
import Foundation
import SwiftOnig

private let clearLine = "\u{001B}[2K"
private let showCursor = "\u{001B}[?25h"
private let enterAltScreen = "\u{001B}[?1049h"
private let leaveAltScreen = "\u{001B}[?1049l"
private let resetStyle = "\u{001B}[0m"
private let statusStyle = "\u{001B}[48;5;238m\u{001B}[38;5;255m"
private let searchStyle = "\u{001B}[48;5;220m\u{001B}[38;5;232m"
private let cursorLineStyle = "\u{001B}[48;5;235m"
private let lineNumberStyle = "\u{001B}[38;5;244m"

private enum InputKey {
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case delete
    case backspace
    case enter
    case escape
    case ctrlF
    case ctrlQ
    case ctrlS
    case character(Character)
    case unknown
}

private struct SearchState {
    var query = ""
    var regex: Regex?
    var matches: [SearchResult] = []
    var selectedIndex = 0
    var errorMessage: String?
}

private struct SearchResult {
    let row: Int
    let range: Range<String.Index>
}

private struct EditorState {
    var lines: [String]
    var fileURL: URL?
    var dirty = false
    var cursorRow = 0
    var cursorColumn = 0
    var viewportTop = 0
    var search = SearchState()
    var statusMessage = "Ctrl-F search | Enter next match | Ctrl-S save | Ctrl-Q quit"
    var pendingQuitConfirmation = false
}

private enum Mode {
    case normal
    case search
}

private final class RawTerminal {
    private var originalTermios = termios()
    private let stdinFD = STDIN_FILENO
    let width: Int
    let height: Int

    init() throws {
        guard isatty(stdinFD) == 1 else {
            throw NSError(domain: "regexEdit", code: 1, userInfo: [NSLocalizedDescriptionKey: "regexEdit requires an interactive terminal (TTY)."])
        }

        var current = termios()
        guard tcgetattr(stdinFD, &current) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Unable to read terminal attributes."])
        }

        originalTermios = current
        current.c_lflag &= ~tcflag_t(ECHO | ICANON | IEXTEN | ISIG)
        current.c_iflag &= ~tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        current.c_oflag &= ~tcflag_t(OPOST)
        current.c_cflag |= tcflag_t(CS8)
        current.c_cc.16 = 0 // VMIN
        current.c_cc.17 = 1 // VTIME

        guard tcsetattr(stdinFD, TCSAFLUSH, &current) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Unable to enable raw terminal mode."])
        }

        var size = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0, size.ws_row > 0 {
            width = Int(size.ws_col)
            height = Int(size.ws_row)
        } else {
            width = 100
            height = 32
        }

        write("\(enterAltScreen)\(showCursor)")
    }

    deinit {
        var restore = originalTermios
        _ = tcsetattr(stdinFD, TCSAFLUSH, &restore)
        write("\(showCursor)\(leaveAltScreen)\u{001B}[H")
    }

    func readKey() -> InputKey {
        var byte: UInt8 = 0
        guard Darwin.read(stdinFD, &byte, 1) == 1 else {
            return .unknown
        }

        switch byte {
        case 6:
            return .ctrlF
        case 17:
            return .ctrlQ
        case 19:
            return .ctrlS
        case 10, 13:
            return .enter
        case 127:
            return .backspace
        case 27:
            return readEscapeSequence()
        default:
            if (32...126).contains(byte) {
                return .character(Character(UnicodeScalar(byte)))
            }
            return .unknown
        }
    }

    func write(_ string: String) {
        _ = string.withCString { pointer in
            Darwin.write(STDOUT_FILENO, pointer, strlen(pointer))
        }
    }
    private func readEscapeSequence() -> InputKey {
        var bytes = [UInt8](repeating: 0, count: 2)
        let count = Darwin.read(stdinFD, &bytes, 2)
        guard count > 0 else { return .escape }
        if bytes[0] == 91 {
            switch bytes[1] {
            case 65: return .arrowUp
            case 66: return .arrowDown
            case 67: return .arrowRight
            case 68: return .arrowLeft
            case 51:
                var tilde: UInt8 = 0
                _ = Darwin.read(stdinFD, &tilde, 1)
                return .delete
            default:
                return .escape
            }
        }
        return .escape
    }
}

private func loadState(from path: String?) throws -> EditorState {
    guard let path else {
        return EditorState(lines: [""])
    }

    let url = URL(fileURLWithPath: path)
    let contents = try String(contentsOf: url, encoding: .utf8)
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return EditorState(lines: lines.isEmpty ? [""] : lines, fileURL: url)
}

private func stringIndex(in line: String, column: Int) -> String.Index {
    line.index(line.startIndex, offsetBy: max(0, min(column, line.count)))
}

private func columnOffset(in line: String, index: String.Index) -> Int {
    line.distance(from: line.startIndex, to: index)
}

private func refreshSearch(state: inout EditorState) {
    guard !state.search.query.isEmpty else {
        state.search = SearchState()
        return
    }

    do {
        let regex = try Regex(pattern: state.search.query)
        var results = [SearchResult]()
        for (row, line) in state.lines.enumerated() {
            let matches = try line.matches(of: regex)
            results.append(contentsOf: matches.map { SearchResult(row: row, range: $0.range) })
        }
        state.search.regex = regex
        state.search.matches = results
        state.search.errorMessage = nil
        if state.search.selectedIndex >= results.count {
            state.search.selectedIndex = max(0, results.count - 1)
        }
    } catch {
        state.search.regex = nil
        state.search.matches = []
        state.search.selectedIndex = 0
        state.search.errorMessage = String(describing: error)
    }
}

private func updateSearchPreview(state: inout EditorState, visibleRows: Int) {
    refreshSearch(state: &state)

    guard !state.search.query.isEmpty else {
        state.statusMessage = "Search cleared"
        return
    }

    if let error = state.search.errorMessage {
        state.statusMessage = "Invalid regex: \(error)"
        return
    }

    if let first = state.search.matches.first {
        state.search.selectedIndex = 0
        moveToSearchResult(first, state: &state, visibleRows: visibleRows)
        state.statusMessage = "Match 1 of \(state.search.matches.count)"
    } else {
        state.statusMessage = "No matches for /\(state.search.query)/"
    }
}

private func moveToSearchResult(_ result: SearchResult, state: inout EditorState, visibleRows: Int) {
    state.cursorRow = result.row
    state.cursorColumn = columnOffset(in: state.lines[result.row], index: result.range.lowerBound)
    if state.cursorRow < state.viewportTop {
        state.viewportTop = state.cursorRow
    }
    if state.cursorRow >= state.viewportTop + visibleRows {
        state.viewportTop = state.cursorRow - visibleRows + 1
    }
}

private func jumpSearchMatch(forward: Bool, state: inout EditorState, visibleRows: Int) {
    guard !state.search.matches.isEmpty else {
        state.statusMessage = "No search matches"
        return
    }

    if forward {
        state.search.selectedIndex = (state.search.selectedIndex + 1) % state.search.matches.count
    } else {
        state.search.selectedIndex = (state.search.selectedIndex - 1 + state.search.matches.count) % state.search.matches.count
    }
    moveToSearchResult(state.search.matches[state.search.selectedIndex], state: &state, visibleRows: visibleRows)
    state.statusMessage = "Match \(state.search.selectedIndex + 1) of \(state.search.matches.count)"
}

private func highlightedLine(_ line: String, row: Int, search: SearchState, isCursorLine: Bool) -> String {
    let segments: [Range<String.Index>]
    if let regex = search.regex, let matches = try? line.matches(of: regex) {
        segments = matches.map(\.range)
    } else {
        segments = []
    }

    var rendered = isCursorLine ? cursorLineStyle : ""
    var cursor = line.startIndex
    for range in segments {
        guard cursor <= range.lowerBound else { continue }
        rendered += String(line[cursor..<range.lowerBound])
        rendered += searchStyle + String(line[range]) + (isCursorLine ? cursorLineStyle : resetStyle)
        cursor = range.upperBound
    }
    rendered += String(line[cursor...])
    rendered += resetStyle
    return rendered
}

private func draw(state: EditorState, mode: Mode, terminal: RawTerminal) {
    let visibleRows = max(1, terminal.height - 2)
    var output = "\u{001B}[H"

    for screenRow in 0..<visibleRows {
        let bufferRow = state.viewportTop + screenRow
        output += clearLine
        if bufferRow < state.lines.count {
            let lineNumber = String(format: "%4d ", bufferRow + 1)
            let highlighted = highlightedLine(state.lines[bufferRow], row: bufferRow, search: state.search, isCursorLine: bufferRow == state.cursorRow)
            output += lineNumberStyle + lineNumber + resetStyle + highlighted
        } else {
            output += "~"
        }
        output += "\r\n"
    }

    let fileName = state.fileURL?.lastPathComponent ?? "<scratch>"
    let searchInfo: String
    if !state.search.query.isEmpty {
        if let error = state.search.errorMessage {
            searchInfo = " search:/\(state.search.query)/ error=\(error)"
        } else {
            searchInfo = " search:/\(state.search.query)/ \(state.search.matches.count) hits"
        }
    } else {
        searchInfo = ""
    }
    let dirtyMarker = state.dirty ? " [+]" : ""
    let header = " regexEdit \(fileName)\(dirtyMarker)  Ln \(state.cursorRow + 1), Col \(state.cursorColumn + 1)\(searchInfo) "
    output += statusStyle + clearLine + String(header.prefix(max(0, terminal.width))) + resetStyle + "\r\n"

    let prompt: String
    switch mode {
    case .normal:
        prompt = state.statusMessage
    case .search:
        prompt = "/\(state.search.query)"
    }
    output += clearLine + prompt.prefix(max(0, terminal.width)).description

    let cursorScreenRow = state.cursorRow - state.viewportTop + 1
    let cursorScreenColumn = min(state.cursorColumn, state.lines[state.cursorRow].count) + 6
    let targetRow = (mode == .search) ? terminal.height : max(1, min(visibleRows, cursorScreenRow))
    let targetColumn = (mode == .search) ? min(terminal.width, state.search.query.count + 2) : max(1, min(terminal.width, cursorScreenColumn))
    output += "\u{001B}[\(targetRow);\(targetColumn)H"

    terminal.write(output)
}

private func insert(character: Character, state: inout EditorState) {
    let row = state.cursorRow
    let index = stringIndex(in: state.lines[row], column: state.cursorColumn)
    state.lines[row].insert(character, at: index)
    state.cursorColumn += 1
    state.dirty = true
}

private func insertNewline(state: inout EditorState) {
    let row = state.cursorRow
    let splitIndex = stringIndex(in: state.lines[row], column: state.cursorColumn)
    let current = state.lines[row]
    let prefix = String(current[..<splitIndex])
    let suffix = String(current[splitIndex...])
    state.lines[row] = prefix
    state.lines.insert(suffix, at: row + 1)
    state.cursorRow += 1
    state.cursorColumn = 0
    state.dirty = true
}

private func backspace(state: inout EditorState) {
    if state.cursorColumn > 0 {
        let row = state.cursorRow
        let removeIndex = stringIndex(in: state.lines[row], column: state.cursorColumn - 1)
        state.lines[row].remove(at: removeIndex)
        state.cursorColumn -= 1
        state.dirty = true
    } else if state.cursorRow > 0 {
        let previousLength = state.lines[state.cursorRow - 1].count
        state.lines[state.cursorRow - 1] += state.lines[state.cursorRow]
        state.lines.remove(at: state.cursorRow)
        state.cursorRow -= 1
        state.cursorColumn = previousLength
        state.dirty = true
    }
}

private func deleteForward(state: inout EditorState) {
    let row = state.cursorRow
    if state.cursorColumn < state.lines[row].count {
        let removeIndex = stringIndex(in: state.lines[row], column: state.cursorColumn)
        state.lines[row].remove(at: removeIndex)
        state.dirty = true
    } else if state.cursorRow + 1 < state.lines.count {
        state.lines[row] += state.lines[state.cursorRow + 1]
        state.lines.remove(at: state.cursorRow + 1)
        state.dirty = true
    }
}

private func moveCursor(_ key: InputKey, state: inout EditorState) {
    switch key {
    case .arrowUp:
        state.cursorRow = max(0, state.cursorRow - 1)
    case .arrowDown:
        state.cursorRow = min(state.lines.count - 1, state.cursorRow + 1)
    case .arrowLeft:
        if state.cursorColumn > 0 {
            state.cursorColumn -= 1
        } else if state.cursorRow > 0 {
            state.cursorRow -= 1
            state.cursorColumn = state.lines[state.cursorRow].count
        }
    case .arrowRight:
        if state.cursorColumn < state.lines[state.cursorRow].count {
            state.cursorColumn += 1
        } else if state.cursorRow + 1 < state.lines.count {
            state.cursorRow += 1
            state.cursorColumn = 0
        }
    default:
        break
    }

    state.cursorColumn = min(state.cursorColumn, state.lines[state.cursorRow].count)
}

private func scrollIfNeeded(state: inout EditorState, visibleRows: Int) {
    if state.cursorRow < state.viewportTop {
        state.viewportTop = state.cursorRow
    } else if state.cursorRow >= state.viewportTop + visibleRows {
        state.viewportTop = state.cursorRow - visibleRows + 1
    }
}

private func writeFile(state: inout EditorState) throws {
    guard let url = state.fileURL else {
        throw NSError(domain: "regexEdit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Open a file first to save."])
    }
    try state.lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    state.dirty = false
    state.statusMessage = "Saved \(url.lastPathComponent)"
}

private func runEditor(initialPath: String?) throws {
    let terminal = try RawTerminal()
    var state = try loadState(from: initialPath)
    var mode: Mode = .normal
    let visibleRows = max(1, terminal.height - 2)

    while true {
        scrollIfNeeded(state: &state, visibleRows: visibleRows)
        draw(state: state, mode: mode, terminal: terminal)

        let key = terminal.readKey()
        switch mode {
        case .normal:
            switch key {
            case .ctrlQ:
                if state.dirty && !state.pendingQuitConfirmation {
                    state.pendingQuitConfirmation = true
                    state.statusMessage = "Unsaved changes. Press Ctrl-Q again to quit."
                } else {
                    return
                }

            case .ctrlS:
                do {
                    try writeFile(state: &state)
                } catch {
                    state.statusMessage = "Save failed: \(error.localizedDescription)"
                }

            case .ctrlF:
                mode = .search
                state.search.query = ""
                state.statusMessage = "Search mode"

            case .arrowUp, .arrowDown, .arrowLeft, .arrowRight:
                state.pendingQuitConfirmation = false
                moveCursor(key, state: &state)

            case .backspace:
                state.pendingQuitConfirmation = false
                backspace(state: &state)
                refreshSearch(state: &state)

            case .delete:
                state.pendingQuitConfirmation = false
                deleteForward(state: &state)
                refreshSearch(state: &state)

            case .enter:
                state.pendingQuitConfirmation = false
                insertNewline(state: &state)
                refreshSearch(state: &state)

            case .character(let character):
                state.pendingQuitConfirmation = false
                insert(character: character, state: &state)
                refreshSearch(state: &state)

            case .unknown, .escape:
                break
            }

        case .search:
            switch key {
            case .escape:
                mode = .normal
                state.statusMessage = "Search cancelled"

            case .enter:
                updateSearchPreview(state: &state, visibleRows: visibleRows)
                if state.search.errorMessage == nil,
                   !state.search.matches.isEmpty {
                    jumpSearchMatch(forward: true, state: &state, visibleRows: visibleRows)
                }

            case .backspace:
                if !state.search.query.isEmpty {
                    state.search.query.removeLast()
                }
                updateSearchPreview(state: &state, visibleRows: visibleRows)

            case .character(let character):
                state.search.query.append(character)
                updateSearchPreview(state: &state, visibleRows: visibleRows)

            default:
                break
            }
        }
    }
}

private func printUsage() {
    print("""
    regexEdit

    Minimal TUI editor demo for SwiftOnig.

    Usage:
      swift run regexEdit [path]

    Controls:
      Arrow keys  Move cursor
      Enter       Insert newline (normal mode) / jump next match (search mode)
      Backspace   Delete backward
      Delete      Delete forward
      Ctrl-F      Enter regex search
      Ctrl-S      Save current file
      Ctrl-Q      Quit (press twice if buffer is dirty)
      Esc         Leave search mode
    """)
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.first == "--help" || arguments.first == "-h" {
        printUsage()
        exit(EXIT_SUCCESS)
    }
    try runEditor(initialPath: arguments.first)
} catch {
    fputs("Error: \(String(describing: error))\n", stderr)
    exit(EXIT_FAILURE)
}
