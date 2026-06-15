import Foundation
import SwiftUI

struct FamilyMember: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let points: Int
    let badge: String
    let color: Color
}

struct ChoreItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: String
    let minutes: Int
    let points: Int
    let icon: String
    let color: Color
}

struct ChoreLog: Identifiable, Hashable {
    let id = UUID()
    let memberName: String
    let choreName: String
    let points: Int
    let note: String
}
