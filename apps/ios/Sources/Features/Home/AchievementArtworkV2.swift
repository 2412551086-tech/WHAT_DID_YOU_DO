import SwiftUI

enum V2ArtworkCatalog {
    static let rows: [[String]] = [
        ["FIRST_RECORD", "ACTIVE_DAYS_3", "ACTIVE_DAYS_5", "ACTIVE_DAYS_7", "STREAK_7", "STREAK_14", "HABIT_30", "MASTERY_DISHES"],
        ["MASTERY_COOKING", "MASTERY_TRASH", "MASTERY_PET", "MASTERY_CHILDCARE", "MASTERY_FLOOR", "MASTERY_LAUNDRY", "MASTERY_ROMANCE", "MASTERY_ORGANIZE"],
        ["MASTERY_ALL_ROUNDER", "REACTION_FIRST", "REACTION_GIVEN_20", "REACTION_RECEIVED_10", "FAMILY_FORMED", "FAMILY_ALL_IN", "FAMILY_RELAY", "FAMILY_VISIBLE_4W"],
        ["FAMILY_FULL_SERVICE", "FAMILY_CATEGORY_COVERAGE", "PAIR_COOK_AND_CLEAN", "FAMILY_ACTIVE_DAYS", "FAMILY_RECORD_COUNT", "FAMILY_ANNIVERSARY", "HIDDEN_DISHES_3", "HIDDEN_SHINY_FLOOR"],
        ["HIDDEN_GUESTS", "HIDDEN_NIGHT_SHIFT", "HIDDEN_ENDURANCE", "SCENE_PET_CARE", "SCENE_PET_TEAM", "SCENE_CHILDCARE_STORY", "SCENE_CHILDCARE_TEAM", "SCENE_LOVE_MOMENT"],
        ["SCENE_LOVE_TEAM", "HIDDEN_FRESH_START", "HIDDEN_WARM_WELCOME", "MYSTERY", "avatar_v2_recycler", "avatar_v2_chef", "avatar_v2_trainer", "avatar_v2_dad"]
    ]

    static func location(for key: String) -> (atlas: String, cell: Int)? {
        for (index, row) in rows.enumerated() {
            if let cell = row.firstIndex(of: key) {
                return ("achv2_atlas_\(index + 1)", cell)
            }
        }
        return nil
    }

    static func hasAchievement(key: String) -> Bool {
        guard !key.hasPrefix("avatar_") else { return false }
        return location(for: key) != nil
    }
}

struct V2AchievementArt: View {
    let key: String

    var body: some View {
        V2AtlasTile(key: key)
            .accessibilityHidden(true)
    }
}

struct V2CharacterArt: View {
    let avatarKey: String

    var body: some View {
        V2AtlasTile(key: avatarKey)
            .accessibilityHidden(true)
    }
}

private struct V2AtlasTile: View {
    let key: String

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, proxy.size.height * 0.75)
            let height = width / 0.75
            if let location = V2ArtworkCatalog.location(for: key) {
                // Clip a single fixed cell; retain the original atlas without destructive crops.
                Image(location.atlas)
                    .resizable()
                    .frame(width: width * 4, height: height * 2)
                    .offset(x: -CGFloat(location.cell % 4) * width, y: -CGFloat(location.cell / 4) * height)
                    .frame(width: width, height: height, alignment: .topLeading)
                    .clipped()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                Image(systemName: key.hasPrefix("avatar_") ? "person.crop.circle.fill" : "sparkles")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }
}
