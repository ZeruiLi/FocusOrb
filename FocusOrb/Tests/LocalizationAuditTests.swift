import XCTest

final class LocalizationAuditTests: XCTestCase {
    func testLocalizableStringsContainAllL10nLiteralKeys() throws {
        let root = try packageRootURL()
        let sourcesURL = root.appendingPathComponent("Sources", isDirectory: true)
        let enStringsURL = sourcesURL.appendingPathComponent("Resources/en.lproj/Localizable.strings")
        let zhStringsURL = sourcesURL.appendingPathComponent("Resources/zh-Hans.lproj/Localizable.strings")

        let (keysInCode, locations) = try extractL10nLiteralKeys(in: sourcesURL)
        let enKeys = try parseStringsKeys(at: enStringsURL)
        let zhKeys = try parseStringsKeys(at: zhStringsURL)

        let missingInEn = keysInCode.subtracting(enKeys).sorted()
        let missingInZh = keysInCode.subtracting(zhKeys).sorted()

        if !missingInEn.isEmpty || !missingInZh.isEmpty {
            func render(_ keys: [String]) -> String {
                keys.prefix(40).map { key in
                    if let loc = locations[key] {
                        return "- \"\(key)\"  (\(loc))"
                    }
                    return "- \"\(key)\""
                }.joined(separator: "\n")
            }

            XCTFail(
                """
                Localizable.strings is missing keys referenced by L10n.string("...").

                Missing in en (\(missingInEn.count)):
                \(render(missingInEn))

                Missing in zh-Hans (\(missingInZh.count)):
                \(render(missingInZh))
                """
            )
        }
    }

    func testNoRawUserVisibleStringLiteralsInUI() throws {
        let root = try packageRootURL()
        let sourcesURL = root.appendingPathComponent("Sources", isDirectory: true)

        let swiftFiles = try listSwiftFiles(in: sourcesURL)
        let patterns: [(label: String, regex: NSRegularExpression)] = [
            (label: "Text(\"…\")", regex: try NSRegularExpression(pattern: #"\bText\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: "Button(\"…\")", regex: try NSRegularExpression(pattern: #"\bButton\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: "Label(\"…\")", regex: try NSRegularExpression(pattern: #"\bLabel\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: "Toggle(\"…\")", regex: try NSRegularExpression(pattern: #"\bToggle\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: "Picker(\"…\")", regex: try NSRegularExpression(pattern: #"\bPicker\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: "Section(\"…\")", regex: try NSRegularExpression(pattern: #"\bSection\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: ".help(\"…\")", regex: try NSRegularExpression(pattern: #"\.help\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: ".alert(\"…\")", regex: try NSRegularExpression(pattern: #"\.alert\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: ".confirmationDialog(\"…\")", regex: try NSRegularExpression(pattern: #"\.confirmationDialog\(\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: "NSMenuItem(title: \"…\")", regex: try NSRegularExpression(pattern: #"NSMenuItem\(\s*title:\s*"((?:\\.|[^"\\])*)""#, options: [])),
            (label: "nameFieldStringValue = \"…\"", regex: try NSRegularExpression(pattern: #"nameFieldStringValue\s*=\s*"((?:\\.|[^"\\])*)""#, options: []))
        ]

        var violations: [String] = []

        for fileURL in swiftFiles {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let nsText = text as NSString
            let filePath = fileURL.path

            for (label, regex) in patterns {
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    guard match.numberOfRanges >= 2 else { continue }
                    let raw = nsText.substring(with: match.range(at: 1))
                    guard shouldFlagUserVisibleLiteral(raw) else { continue }
                    let line = lineNumber(in: text, utf16Location: match.range.location)
                    violations.append("- \(label): \"\(raw)\"  (\(filePath):\(line))")
                }
            }
        }

        if !violations.isEmpty {
            XCTFail(
                """
                Found raw user-visible string literals in UI APIs. Route them through L10n.string(...) and add both en/zh translations.

                \(violations.prefix(80).joined(separator: "\n"))
                """
            )
        }
    }
}

private struct CodeLocation: CustomStringConvertible {
    let filePath: String
    let line: Int

    var description: String {
        "\(filePath):\(line)"
    }
}

private func packageRootURL() throws -> URL {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let fm = FileManager.default
    while url.path != "/" {
        if fm.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return url
        }
        url.deleteLastPathComponent()
    }
    throw NSError(domain: "LocalizationAuditTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to locate Package.swift from test file path."])
}

private func listSwiftFiles(in directory: URL) throws -> [URL] {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        return []
    }
    var files: [URL] = []
    for case let url as URL in enumerator {
        if url.pathExtension == "swift" {
            files.append(url)
        }
    }
    return files.sorted(by: { $0.path < $1.path })
}

private func extractL10nLiteralKeys(in sourcesURL: URL) throws -> (Set<String>, [String: CodeLocation]) {
    let swiftFiles = try listSwiftFiles(in: sourcesURL)
    let regex = try NSRegularExpression(
        pattern: #"\bL10n\.string\(\s*"((?:\\.|[^"\\])*)""#,
        options: []
    )

    var keys = Set<String>()
    var locations: [String: CodeLocation] = [:]

    for fileURL in swiftFiles {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let key = nsText.substring(with: match.range(at: 1))
            keys.insert(key)
            if locations[key] == nil {
                let line = lineNumber(in: text, utf16Location: match.range.location)
                locations[key] = CodeLocation(filePath: fileURL.path, line: line)
            }
        }
    }

    return (keys, locations)
}

private func parseStringsKeys(at url: URL) throws -> Set<String> {
    let text = try String(contentsOf: url, encoding: .utf8)
    let nsText = text as NSString
    let regex = try NSRegularExpression(
        pattern: #"(?m)^\s*"((?:\\.|[^"\\])*)"\s*="#,
        options: []
    )

    var keys = Set<String>()
    let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
    for match in matches {
        guard match.numberOfRanges >= 2 else { continue }
        keys.insert(nsText.substring(with: match.range(at: 1)))
    }
    return keys
}

private func lineNumber(in text: String, utf16Location: Int) -> Int {
    // NSRegularExpression ranges are in UTF-16 code units.
    let ns = text as NSString
    let prefix = ns.substring(with: NSRange(location: 0, length: min(utf16Location, ns.length)))
    return prefix.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
}

private func shouldFlagUserVisibleLiteral(_ raw: String) -> Bool {
    // Allowed: empty labels for hidden controls.
    if raw.isEmpty { return false }

    let staticPart = stripInterpolations(from: raw)
    if staticPart.isEmpty { return false }

    // Flag anything that contains letters (any locale) or Han characters in the static part.
    for scalar in staticPart.unicodeScalars {
        if CharacterSet.letters.contains(scalar) { return true }
        if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF { return true }
    }
    return false
}

private func stripInterpolations(from raw: String) -> String {
    // Source-level string literals may contain Swift interpolations like `\\(expr)`.
    // We only care about the static text that will actually appear in the UI.
    var out = ""
    var index = raw.startIndex

    while index < raw.endIndex {
        if raw[index] == "\\" {
            let next = raw.index(after: index)
            if next < raw.endIndex, raw[next] == "(" {
                // Skip `\( ... )`, handling nested parentheses.
                var depth = 1
                index = raw.index(after: next)
                while index < raw.endIndex, depth > 0 {
                    let ch = raw[index]
                    if ch == "(" {
                        depth += 1
                    } else if ch == ")" {
                        depth -= 1
                    }
                    index = raw.index(after: index)
                }
                continue
            }
        }

        out.append(raw[index])
        index = raw.index(after: index)
    }

    return out
}
