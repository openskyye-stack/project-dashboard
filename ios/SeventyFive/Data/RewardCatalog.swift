import Foundation

/// Starter rewards. These are suggestions the user edits or deletes — the
/// onboarding explicitly asks them to name their own, because a reward someone
/// else chose has no pull.
enum RewardCatalog {

    static func starterRewards() -> [Reward] {
        [
            Reward(title: "A proper lie-in", detail: "No alarm. The plan waits until you're up.", cost: 60, category: .rest, symbolName: "bed.double.fill"),
            Reward(title: "Long bath or sauna", detail: "Thirty uninterrupted minutes.", cost: 40, category: .rest, symbolName: "drop.circle.fill"),
            Reward(title: "Massage", detail: "Book it. Actually book it.", cost: 200, category: .rest, symbolName: "hands.and.sparkles.fill"),
            Reward(title: "Film night, your pick", detail: "Nobody else gets a vote.", cost: 50, category: .treat, symbolName: "film.fill"),
            Reward(title: "The good coffee", detail: "The one you normally talk yourself out of.", cost: 25, category: .treat, symbolName: "cup.and.saucer.fill"),
            Reward(title: "New book", detail: "You're going through them at ten pages a day now.", cost: 80, category: .gear, symbolName: "books.vertical.fill"),
            Reward(title: "New trainers", detail: "Earned, not bought on a whim.", cost: 400, category: .gear, symbolName: "shoe.fill"),
            Reward(title: "Lunch with someone you miss", detail: "You pay.", cost: 120, category: .social, symbolName: "person.2.fill"),
            Reward(title: "A day trip", detail: "Somewhere you keep meaning to go.", cost: 300, category: .experience, symbolName: "map.fill"),
            Reward(title: "Concert or match ticket", detail: "Front half of the venue.", cost: 500, category: .experience, symbolName: "ticket.fill")
        ]
    }

    /// Milestone rewards are unlocked by reaching a day, not by spending coins.
    static func milestoneRewards() -> [Reward] {
        [
            Reward(title: "Week One Badge", detail: "Seven days in. Tell one person.", cost: 0, category: .milestone, symbolName: "7.circle.fill", unlocksAtDay: 7),
            Reward(title: "Quarter Mark Treat", detail: "Day 25. Something small and real, today.", cost: 0, category: .milestone, symbolName: "flag.fill", unlocksAtDay: 25),
            Reward(title: "Halfway Reset", detail: "Day 38. A full rest day that costs you nothing.", cost: 0, category: .milestone, symbolName: "arrow.triangle.2.circlepath", unlocksAtDay: 38),
            Reward(title: "Fifty Day Splurge", detail: "Day 50. The one you've been eyeing.", cost: 0, category: .milestone, symbolName: "flag.2.crossed.fill", unlocksAtDay: 50),
            Reward(title: "Finisher's Prize", detail: "Day 75. Decide what this is on day one and write it below.", cost: 0, category: .milestone, symbolName: "flag.checkered", unlocksAtDay: 75)
        ]
    }

    /// Prompts used in onboarding to get the user to name rewards that mean something.
    static let promptQuestions: [String] = [
        "What's something small you'd enjoy this week but usually don't let yourself have?",
        "What's worth a month of work?",
        "What would you want waiting for you on day 75?"
    ]
}
