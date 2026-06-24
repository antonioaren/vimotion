import Foundation
import os

/// Lightweight logging wrapper. Uses the unified logging system so messages are
/// visible in Console.app under the "vimotion" subsystem.
enum Log {
    private static let logger = os.Logger(subsystem: "com.antonioaren.vimotion", category: "general")

    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        logger.debug("\(message(), privacy: .public)")
        #endif
    }

    static func info(_ message: @autoclosure () -> String) {
        logger.info("\(message(), privacy: .public)")
    }

    static func error(_ message: @autoclosure () -> String) {
        logger.error("\(message(), privacy: .public)")
    }
}
