//
//  VideoPeriod.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import Foundation

/// A calendar month or year that videos are grouped by
struct VideoPeriod: Hashable, Identifiable {
    enum Kind: Hashable {
        case month
        case year
    }

    let kind: Kind
    /// The first moment of the period
    let start: Date

    var id: Self { self }

    init(_ kind: Kind, containing date: Date, calendar: Calendar = .current) {
        self.kind = kind
        let components: Set<Calendar.Component> = kind == .month ? [.year, .month] : [.year]
        start = calendar.date(from: calendar.dateComponents(components, from: date)) ?? calendar.startOfDay(for: date)
    }

    /// "March 2025" or "2025"
    var title: String {
        switch kind {
        case .month: return start.formatted(.dateTime.month(.wide).year())
        case .year: return start.formatted(.dateTime.year())
        }
    }

    /// "March"
    var monthName: String {
        start.formatted(.dateTime.month(.wide))
    }

    /// Newest period first, and oldest item first within each period
    static func group<Item>(_ items: [Item], by kind: Kind, date: (Item) -> Date) -> [(period: VideoPeriod, items: [Item])] {
        Dictionary(grouping: items) { VideoPeriod(kind, containing: date($0)) }
            .map { (period: $0.key, items: $0.value.sorted { date($0) < date($1) }) }
            .sorted { $0.period.start > $1.period.start }
    }
}
