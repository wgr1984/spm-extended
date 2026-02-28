import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum Banner {
    /// Split column: left = SPM (orange), right = EXTENDED (cyan). Kept at 24 so the E’s top bar is fully cyan.
    private static let leftWidth = 24

    private static let lines = [
        "   _____                 ______      _                 _          _ ",
        "  / ____|               |  ____|    | |               | |        | |",
        " | (___  _ __  _ __ ___ | |__  __  _| |_ ___ _ __   __| | ___  __| |",
        "  \\___ \\| '_ \\| '_ ` _ \\|  __| \\ \\/ / __/ _ \\ '_ \\ / _` |/ _ \\/ _` |",
        "  ____) | |_) | | | | | | |____ >  <| ||  __/ | | | (_| |  __/ (_| |",
        " |_____/| .__/|_| |_| |_|______/_/\\_\\\\__\\___|_| |_|\\__,_|\\___|\\__,_|",
        "        | |                                                         ",
        "        |_|                                                         ",
    ]

    /// ANSI 256-color: Swift orange
    private static let colorSPM = "\u{001B}[38;5;208m"
    /// ANSI 256-color: cyan
    private static let colorExtended = "\u{001B}[38;5;87m"
    /// Dim for tagline
    private static let colorDim = "\u{001B}[38;5;245m"
    private static let reset = "\u{001B}[0m"

    static var supportsColor: Bool {
        guard let term = ProcessInfo.processInfo.environment["TERM"], !term.isEmpty else { return false }
        if term.lowercased() == "dumb" { return false }
        #if canImport(Darwin)
        return isatty(STDOUT_FILENO) != 0
        #elseif canImport(Glibc)
        return isatty(STDOUT_FILENO) != 0
        #else
        return false
        #endif
    }

    private static func pad(_ s: String, to width: Int) -> String {
        guard s.count <= width else { return String(s.prefix(width)) }
        return s + String(repeating: " ", count: width - s.count)
    }

    /// Print the multicolor ASCII logo (or plain when not a TTY).
    static func printLogo() {
        if supportsColor {
            for line in lines {
                let left = pad(String(line.prefix(leftWidth)), to: leftWidth)
                let right = line.count > leftWidth ? String(line.dropFirst(leftWidth)) : ""
                print("\(colorSPM)\(left)\(reset)\(colorExtended)\(right)\(reset)")
            }
            print("\(colorDim)  Registry & dependency tools for Swift Package Manager\(reset)")
        } else {
            for line in lines {
                print(line)
            }
            print("  Registry & dependency tools for Swift Package Manager")
        }
        print()
    }
}
