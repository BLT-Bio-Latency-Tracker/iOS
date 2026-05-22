import Foundation

struct HomeTimelineSegment: Identifiable {
    let id = UUID()
    let startHour: Double
    let endHour: Double
    let kind: HomeTimelineSegmentKind
}

enum HomeTimelineSegmentKind {
    case rest
    case deepWork
    case collaboration
    case caution
    case recovery
}

