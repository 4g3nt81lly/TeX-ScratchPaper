import Foundation

fileprivate class EmphasisDelimiter {
    
    enum SymbolType {
        case asterisk, underscore
        
        init(string: String) {
            self = (string.first! == "*") ? .asterisk : .underscore
        }
    }
    
    var range: NSRange
    let length: Int
    let type: SymbolType
    var canOpen: Bool
    var canClose: Bool
    
    var usableLength: Int {
        return range.length
    }
    
    convenience init(range: NSRange, string: String, canOpen: Bool, canClose: Bool) {
        self.init(range: range, type: SymbolType(string: string),
                  canOpen: canOpen, canClose: canClose)
    }
    
    init(range: NSRange, type: SymbolType, canOpen: Bool, canClose: Bool) {
        self.range = range
        self.length = range.length
        self.type = type
        self.canOpen = canOpen
        self.canClose = canClose
    }
    
    func crossOut() {
        canOpen = false
        canClose = false
    }
    
}

final class MDEmphasisParser {
    
    private let string: NSString
    private let baseLocation: Int
    
    init(string: String, at baseLocation: Int = 0) {
        self.string = string as NSString
        self.baseLocation = baseLocation
    }
    
    private static func firstPotentialCloserIndex(
        in stack: [EmphasisDelimiter], from currentPosition: inout Int
    ) -> Int? {
        while (currentPosition < stack.count && !stack[currentPosition].canClose) {
            currentPosition += 1
        }
        return (currentPosition < stack.count) ? currentPosition : nil
    }
    
    func enumerateEmphasis(with block: (_ range: NSRange, _ strong: Bool) -> Void) {
        var delimiterStack: [EmphasisDelimiter] = []
        
        // create the stack of left-/right-flanking delimiter runs
        Patterns.markdownEmphasisDelimiter
            .enumerateMatches(in: string.string, range: string.range) { result, _, _ in
                guard let range = result?.range else { return }
                let substring = string.substring(with: range)
                
                var canOpen = false
                var canClose = false
                
                // check if the delimiter run is a potential opener (left-flanking delimiter)
                if (range.upperBound < string.length) {
                    // not the last sequence in the string
                    let nextCharacter = string.substring(with: NSMakeRange(range.upperBound, 1))
                    let followedByWhitespace = nextCharacter.matches(pattern: Patterns.unicodeWhitespace)
                    let followedByPunctuation = nextCharacter.matches(pattern: Patterns.unicodePunctuation)
                    
                    if (!followedByWhitespace) {
                        if (followedByPunctuation) {
                            if (range.location > 0) {
                                // must be preceded by whitespace or punctuation
                                let previousCharacter = string.substring(with: NSMakeRange(range.location - 1, 1))
                                let precededByWhitespace = previousCharacter.matches(pattern: Patterns.unicodeWhitespace)
                                let precededByPunctuation = previousCharacter.matches(pattern: Patterns.unicodePunctuation)
                                canOpen = precededByWhitespace || precededByPunctuation
                            } else {
                                // at the beginning of line
                                canOpen = true
                            }
                        } else {
                            // not followed by whitespace nor punctuation
                            canOpen = true
                        }
                    }
                }
                
                // check if the delimiter run is a potential closer (right-flanking delimiter)
                if (range.location > 0) {
                    let previousCharacter = string.substring(with: NSMakeRange(range.location - 1, 1))
                    let precededByWhitespace = previousCharacter.matches(pattern: Patterns.unicodeWhitespace)
                    let precededByPunctuation = previousCharacter.matches(pattern: Patterns.unicodePunctuation)
                    
                    if (!precededByWhitespace) {
                        if (precededByPunctuation) {
                            if (range.upperBound < string.length) {
                                // must be followed by whitespace or punctuation
                                let nextCharacter = string.substring(with: NSMakeRange(range.upperBound, 1))
                                let followedByWhitespace = nextCharacter.matches(pattern: Patterns.unicodeWhitespace)
                                let followedByPunctuation = nextCharacter.matches(pattern: Patterns.unicodePunctuation)
                                canClose = followedByWhitespace || followedByPunctuation
                            } else {
                                // at the end of line
                                canClose = true
                            }
                        } else {
                            // not preceded by whitespace nor punctuation
                            canClose = true
                        }
                    }
                }
                
                guard (canOpen || canClose) else { return }
                let delimiter = EmphasisDelimiter(range: range, string: substring,
                                                  canOpen: canOpen, canClose: canClose)
                delimiterStack.append(delimiter)
            }
        
        let delimiterStackBottom = -1
        var currentPosition = 0
        var openersBottom: [EmphasisDelimiter.SymbolType : Int] = [.asterisk : -1, .underscore : -1]
        
        while let potentialCloserIndex = MDEmphasisParser
            .firstPotentialCloserIndex(in: delimiterStack, from: &currentPosition) {
            // NOTE: current position IS the index of the potential closer
            let potentialCloser = delimiterStack[potentialCloserIndex]
            
            // find the closest potential opener by looking back, while staying above delimiter stack bottom
            //   and the corresponding openers bottom
            let earliestIndex = max(delimiterStackBottom, openersBottom[potentialCloser.type]!) + 1
            var potentialOpenerIndex = potentialCloserIndex - 1
            var potentialOpener: EmphasisDelimiter {
                return delimiterStack[potentialOpenerIndex]
            }
            // ASSUMPTION: the potential opener cannot be a closer
            // IF the potential closer is also an opener AND its length is not a multiple of 3,
            //   THEN the sum cannot be a multiple of 3
            // (potential closer is not an opener) OR (potential closer has a multiple of 3 length)
            //   OR (the sum of lengths is not a multiple of 3)
            while (potentialOpenerIndex >= earliestIndex &&
                   !(potentialOpener.canOpen &&
                     potentialOpener.type == potentialCloser.type &&
                     (!potentialCloser.canOpen || potentialCloser.length % 3 == 0 ||
                      (potentialOpener.length + potentialCloser.length) % 3 != 0))) {
                potentialOpenerIndex -= 1
            }
            if (potentialOpenerIndex >= earliestIndex) {
                // a potential opener is found
                let potentialOpener = delimiterStack[potentialOpenerIndex]
                let delimiterLength: Int
                if (potentialOpener.usableLength >= 2 && potentialCloser.usableLength >= 2) {
                    // strong emphasis
                    delimiterLength = 2
                } else {
                    // regular emphasis
                    delimiterLength = 1
                }
                
                // "tombstone" (instead of removing) all delimiter runs between opener and closer
                //   this is preferred to removal to preserve proper indexing
                for index in (potentialOpenerIndex + 1)..<potentialCloserIndex {
                    delimiterStack[index].crossOut()
                }
                
                // shrink opener by the delimiter length to the left
                potentialOpener.range.length -= delimiterLength
                // shrink closer by the delimiter length to the right
                potentialCloser.range.location += delimiterLength
                potentialCloser.range.length -= delimiterLength
                
                // "tombstone" the delimiters if no usable length left
                if (potentialOpener.usableLength == 0) {
                    potentialOpener.crossOut()
                }
                if (potentialCloser.usableLength == 0) {
                    potentialCloser.crossOut()
                    // update current position to the next index after the closer
                    currentPosition += 1
                }
                
                // create range describing the portion of the text to be emphasized
                let emphasisLocation = potentialOpener.range.upperBound
                let emphasisLength = potentialCloser.range.location - emphasisLocation
                // convert to global range via offesetting by the base location, if any
                let emphasisRange = NSMakeRange(baseLocation + emphasisLocation, emphasisLength)
                block(emphasisRange, delimiterLength == 2)
            } else {
                // no potential opener found
                // no openers for this kind up to and including current position - 1
                openersBottom[potentialCloser.type] = currentPosition - 1
                
                // the delimiter cannot be a closer since there's no matching opener
                potentialCloser.canClose = false
                
                // advance current position to the next element in stack
                currentPosition += 1
            }
        }
    }
    
    func emphasisRanges() -> [NSRange : (emphasize: Bool, strong: Bool)] {
        var ranges: [NSRange : (emphasize: Bool, strong: Bool)] = [:]
        enumerateEmphasis { range, strong in
            var info = ranges[range] ?? (false, false)
            if (strong) {
                info.strong = true
            } else {
                info.emphasize = true
            }
            ranges[range] = info
        }
        return ranges
    }
    
}
