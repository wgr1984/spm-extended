import Foundation

/// Represents a single pin from Package.resolved
struct ResolvedPin: Sendable {
    let identity: String
    let location: String
    let kind: String?
    let currentVersion: String?

    var isRegistry: Bool {
        if kind?.lowercased() == "registry" { return true }
        guard kind == nil else { return false }
        guard identity.contains("."),
              let url = URL(string: location),
              url.scheme != nil,
              !location.lowercased().contains("github.com"),
              !location.lowercased().contains("gitlab"),
              !location.hasSuffix(".git") else { return false }
        return true
    }
}

/// Parses Package.resolved (format version 2 and 3) into a list of pins.
enum ResolvedParser {
    static func parse(data: Data) throws -> [ResolvedPin] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json else { throw ResolvedParserError.invalidJSON }

        let pinsArray: [[String: Any]]
        if let object = json["object"] as? [String: Any], let pins = object["pins"] as? [[String: Any]] {
            pinsArray = pins
        } else if let pins = json["pins"] as? [[String: Any]] {
            pinsArray = pins
        } else {
            throw ResolvedParserError.missingPins
        }

        return try pinsArray.map { pin -> ResolvedPin in
            guard let identity = pin["identity"] as? String else { throw ResolvedParserError.missingIdentity }
            let location = pin["location"] as? String ?? ""
            let kind = pin["kind"] as? String
            let state = pin["state"] as? [String: Any]
            let version = state?["version"] as? String
            return ResolvedPin(identity: identity, location: location, kind: kind, currentVersion: version)
        }
    }

    static func parse(filePath: String) throws -> [ResolvedPin] {
        let url = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }
}

enum ResolvedParserError: Error, CustomStringConvertible {
    case invalidJSON
    case missingPins
    case missingIdentity

    var description: String {
        switch self {
        case .invalidJSON: return "Package.resolved is not valid JSON."
        case .missingPins: return "Package.resolved does not contain a 'pins' array."
        case .missingIdentity: return "A pin is missing an 'identity' field."
        }
    }
}
