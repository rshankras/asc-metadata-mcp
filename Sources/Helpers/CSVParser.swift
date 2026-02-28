import Foundation

enum CSVParser {
    struct ParsedData: Sendable {
        let headers: [String]
        let rows: [[String]]
    }

    /// Parse tab-separated (or comma-separated) text into headers and rows.
    /// Apple's analytics CSVs use TSV format.
    static func parse(_ text: String, delimiter: Character = "\t") -> ParsedData {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else {
            return ParsedData(headers: [], rows: [])
        }

        let headers = parseLine(headerLine, delimiter: delimiter)
        var rows: [[String]] = []
        for line in lines.dropFirst() {
            let fields = parseLine(line, delimiter: delimiter)
            rows.append(fields)
        }

        return ParsedData(headers: headers, rows: rows)
    }

    private static func parseLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if inQuotes {
                if char == "\"" {
                    inQuotes = false
                } else {
                    current.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == delimiter {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            }
        }
        fields.append(current)
        return fields
    }
}
