import Foundation
import SwiftOnig

private struct SearchResult {
    let path: String
    let lineNumber: Int
    let line: String
}

private let reset = "\u{001B}[0m"
private let highlight = "\u{001B}[48;5;220m\u{001B}[38;5;232m"

private func loadDemoCorpus() -> [(path: String, contents: String)] {
    [
        (
            "logs/app.log",
            """
            2026-03-29T10:10:10Z INFO request_id=req-100 route=/checkout latency=18ms
            2026-03-29T10:10:11Z WARN request_id=req-101 route=/checkout latency=241ms
            2026-03-29T10:10:12Z ERROR request_id=req-102 route=/checkout timeout after 1500ms
            """
        ),
        (
            "notes/todo.md",
            """
            - follow up on request_id=req-101
            - investigate timeout after 1500ms
            - celebrate the fast path once tests pass
            """
        ),
        (
            "transcript/chat.txt",
            """
            alice: can you grep timeout and request ids?
            bob: yes, req-102 looks suspicious
            """
        ),
    ]
}

private func loadDirectoryCorpus(root: URL) -> [(path: String, contents: String)] {
    let manager = FileManager.default
    guard let enumerator = manager.enumerator(at: root,
                                              includingPropertiesForKeys: [.isRegularFileKey],
                                              options: [.skipsHiddenFiles]) else {
        return []
    }

    var files = [(path: String, contents: String)]()
    for case let fileURL as URL in enumerator {
        guard
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
            values.isRegularFile == true,
            let data = try? Data(contentsOf: fileURL),
            let contents = String(data: data, encoding: .utf8)
        else {
            continue
        }

        let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
        files.append((path: relativePath, contents: contents))
    }
    return files
}

private func parseArguments() -> (patterns: [String], path: String?) {
    var args = Array(CommandLine.arguments.dropFirst())
    var path: String?
    var patterns = [String]()

    while !args.isEmpty {
        let arg = args.removeFirst()
        if arg == "--path", let next = args.first {
            path = next
            args.removeFirst()
        } else {
            patterns.append(arg)
        }
    }

    if patterns.isEmpty {
        patterns = ["ERROR", #"req-\d+"#, #"timeout after \d+ms"#]
    }

    return (patterns, path)
}

private func highlightLine(_ line: String, with regex: Regex) throws -> String {
    let matches = try line.matches(of: regex)
    guard !matches.isEmpty else {
        return line
    }

    var result = ""
    var cursor = line.startIndex
    for match in matches {
        result += line[cursor..<match.range.lowerBound]
        result += highlight + match.substring + reset
        cursor = match.range.upperBound
    }
    result += line[cursor...]
    return result
}

private func search(files: [(path: String, contents: String)], set: RegexSet) throws -> [SearchResult] {
    var results = [SearchResult]()

    for file in files {
        for (offset, line) in file.contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if try set.firstMatch(in: line) != nil {
                results.append(SearchResult(path: file.path, lineNumber: offset + 1, line: String(line)))
            }
        }
    }

    return results
}

do {
    let arguments = parseArguments()
    let files: [(path: String, contents: String)]

    if let path = arguments.path {
        files = loadDirectoryCorpus(root: URL(fileURLWithPath: path))
    } else {
        files = loadDemoCorpus()
    }

    let set = try RegexSet(patterns: arguments.patterns)
    let highlightRegex = try Regex(pattern: arguments.patterns.joined(separator: "|"))
    let results = try search(files: files, set: set)

    print("== sgrep ==")
    print("Patterns: \(arguments.patterns.joined(separator: ", "))")
    print(arguments.path.map { "Path: \($0)" } ?? "Path: built-in demo corpus")
    print("")

    for result in results {
        print("\(result.path):\(result.lineNumber): \(try highlightLine(result.line, with: highlightRegex))")
    }

    if results.isEmpty {
        print("No matches")
    }
} catch {
    fputs("Error: \(String(describing: error))\n", stderr)
    exit(EXIT_FAILURE)
}
