import Cocoa

class TokenPattern {
    
    struct Match {
        let ranges: [NSRange]
        let groupRanges: [NSRange]
        let userInfo: Any?
        
        var range: NSRange {
            return ranges.first!
        }
        
        func groupRange(at index: Int) -> NSRange {
            if (index == 0) {
                return range
            }
            return groupRanges[index - 1]
        }
    }
    
    let ranges: (_ textStorage: NSTextStorage, _ range: NSRange, _ userInfo: Any?) -> [Match]
    
    init(handler: @escaping (NSTextStorage, NSRange, Any?) -> [Match]) {
        ranges = handler
    }
    
    convenience init(regex: RegEx) {
        self.init { textStorage, range, _ in
            regex.matches(in: textStorage.string, range: range).map { result in
                let ranges = [result.range]
                let captureGroupRanges = (1..<result.numberOfRanges).map { index in
                    result.range(at: index)
                }
                return Match(ranges: ranges, groupRanges: captureGroupRanges, userInfo: nil)
            }
        }
    }
    
}
