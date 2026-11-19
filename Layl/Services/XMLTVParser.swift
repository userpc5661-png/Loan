import Foundation

enum XMLTVParser {
    static func parse(_ data: Data, programLimit: Int = 4000) -> [String: [EPGProgram]] {
        let delegate = Delegate(limit: programLimit)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.programs
    }

    static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["yyyyMMddHHmmss Z", "yyyyMMddHHmmssZ", "yyyyMMddHHmmss"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        let limit: Int
        var programs: [String: [EPGProgram]] = [:]
        private var count = 0
        private var element = ""
        private var channel: String?
        private var start: Date?
        private var end: Date?
        private var title = ""
        private var summary = ""
        private var capture: String?

        init(limit: Int) { self.limit = limit }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            element = elementName
            if elementName == "programme" {
                if count >= limit {
                    parser.abortParsing()
                    return
                }
                count += 1
                channel = attributeDict["channel"]
                start = XMLTVParser.parseDate(attributeDict["start"])
                end = XMLTVParser.parseDate(attributeDict["stop"])
                title = ""
                summary = ""
            } else if elementName == "title" || elementName == "desc" {
                capture = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard capture != nil else { return }
            capture?.append(string)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            if elementName == "title" {
                title += capture ?? ""
                capture = nil
            } else if elementName == "desc" {
                summary += capture ?? ""
                capture = nil
            } else if elementName == "programme",
                      let channel, let start, let end {
                let program = EPGProgram(
                    id: "\(channel)-\(Int(start.timeIntervalSince1970))",
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    start: start,
                    end: end,
                    overview: summary.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                programs[channel, default: []].append(program)
            }
        }
    }
}
