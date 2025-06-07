//
//  TimeFormatter.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/29/25.
//
import Foundation

extension Date {
    var videoFormattedDisplay: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(self) {
            return "Today"
        }

        let isThisYear = calendar.component(.year, from: self) == calendar.component(.year, from: Date())
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = isThisYear ? "MMMM d" : "MMMM d, yyyy"

        return formatter.string(from: self)
        
    }
}
