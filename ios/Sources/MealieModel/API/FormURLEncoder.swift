import Foundation

enum FormURLEncoder {
    static func encode(_ fields: [(String, String)]) -> Data {
        Data(fields.map { "\(escape($0.0))=\(escape($0.1))" }.joined(separator: "&").utf8)
    }

    private static func escape(_ value: String) -> String {
        value.utf8.map { byte in
            switch byte {
            case 65...90, 97...122, 48...57, 42, 45, 46, 95:
                return String(UnicodeScalar(byte))
            case 32:
                return "+"
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
    }
}
