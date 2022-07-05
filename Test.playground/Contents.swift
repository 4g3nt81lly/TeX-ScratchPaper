import Foundation

var string = "#@![display(mode)][render=text][cursor=30]"
let matches = string.matches(of: /\[display(\((mode|style)\))+\]/)
for match in matches {
    print(match.output)
}
