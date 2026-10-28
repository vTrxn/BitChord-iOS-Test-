import Foundation

/// Represents a single synchronized lyrics line with an exact time offset.
struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    
    /// Offset in seconds from track start when this line begins.
    let timestamp: TimeInterval
    
    /// Lyric text content.
    let text: String
}

/// Container for processed lyrics, providing both synchronized timestamps and plain text fallbacks.
struct ParsedLyrics: Equatable {
    /// True when time-synchronized LRC data is present.
    let isSynced: Bool
    
    /// Array of ordered lines with millisecond precision timestamps.
    let lines: [LyricLine]
    
    /// Complete plain-text lyrics without timestamp tags.
    let plainText: String
    
    static let empty = ParsedLyrics(isSynced: false, lines: [], plainText: "")
    
    /// Parses standard LRC strings (e.g. `[01:23.45] Lyric text`) into sorted timestamped lines.
    /// Supports both 2-digit and 3-digit millisecond fractions.
    static func parseLRC(_ lrcString: String) -> [LyricLine] {
        var parsed: [LyricLine] = []
        let rawLines = lrcString.components(separatedBy: .newlines)
        
        let pattern = #"\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex.firstMatch(in: trimmed, range: range) {
                guard let minRange = Range(match.range(at: 1), in: trimmed),
                      let secRange = Range(match.range(at: 2), in: trimmed),
                      let min = Double(trimmed[minRange]),
                      let sec = Double(trimmed[secRange]) else {
                    continue
                }
                
                var millis: Double = 0
                if match.numberOfRanges > 3, let msRange = Range(match.range(at: 3), in: trimmed) {
                    let msStr = String(trimmed[msRange])
                    if msStr.count == 2, let parsedMs = Double(msStr) {
                        millis = parsedMs / 100.0
                    } else if msStr.count == 3, let parsedMs = Double(msStr) {
                        millis = parsedMs / 1000.0
                    }
                }
                
                let timestamp = (min * 60.0) + sec + millis
                
                var lyricText = ""
                if match.numberOfRanges > 4, let textRange = Range(match.range(at: 4), in: trimmed) {
                    lyricText = trimmed[textRange].trimmingCharacters(in: .whitespaces)
                }
                
                parsed.append(LyricLine(timestamp: timestamp, text: lyricText))
            }
        }
        
        return parsed.sorted { $0.timestamp < $1.timestamp }
    }
}
