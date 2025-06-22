//
//  Logger.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/22/25.
//
import Foundation

enum LogLevel: String {
    case verbose = "📓 VERBOSE"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
}

struct AppLogger {
    
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        print("\(level.rawValue) [\(filename):\(line)] - \(message)")
    }
}
