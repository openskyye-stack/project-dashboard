import Foundation

enum AchievementCatalog {

    static let all: [Achievement] = [
        Achievement(code: "first.day", title: "Day One Done", detail: "You finished a full day. The hardest one is behind you.", symbolName: "1.circle.fill", coinReward: 15),
        Achievement(code: "week.one", title: "Seven Straight", detail: "A full week without a gap.", symbolName: "7.circle.fill", coinReward: 30),
        Achievement(code: "day.25", title: "Quarter Mark", detail: "Twenty-five days complete.", symbolName: "flag.fill", coinReward: 60),
        Achievement(code: "day.50", title: "Two Thirds", detail: "Fifty days complete. Most people never see this screen.", symbolName: "flag.2.crossed.fill", coinReward: 100),
        Achievement(code: "day.75", title: "Finisher", detail: "Seventy-five days. Done.", symbolName: "flag.checkered", coinReward: 250),

        Achievement(code: "streak.14", title: "Fortnight", detail: "A fourteen-day streak.", symbolName: "flame.fill", coinReward: 45),
        Achievement(code: "streak.30", title: "Thirty Days Lit", detail: "A thirty-day streak.", symbolName: "flame.circle.fill", coinReward: 90),

        Achievement(code: "hydration.perfect.week", title: "Well Watered", detail: "Hit your water target seven days running.", symbolName: "drop.fill", coinReward: 25),
        Achievement(code: "reading.perfect.week", title: "Page Turner", detail: "Seven straight days of reading.", symbolName: "book.fill", coinReward: 25),

        Achievement(code: "deload.hero", title: "Showed Up Anyway", detail: "Completed a day your body had voted against.", symbolName: "heart.fill", coinReward: 30),
        Achievement(code: "deload.veteran", title: "Five Hard Mornings", detail: "Five heavily scaled days finished rather than skipped. This is the badge that actually predicts finishing.", symbolName: "shield.lefthalf.filled", coinReward: 75),

        Achievement(code: "early.bird", title: "Before Nine", detail: "Finished a whole day before 9am.", symbolName: "sunrise.fill", coinReward: 20),
        Achievement(code: "meal.planner", title: "Prepped", detail: "Planned a full week of meals.", symbolName: "calendar", coinReward: 30),
        Achievement(code: "meal.architect", title: "Kitchen Architect", detail: "Thirty planned meals.", symbolName: "fork.knife.circle.fill", coinReward: 60),
        Achievement(code: "reward.claimed", title: "Paid Yourself", detail: "Redeemed your first reward. Claiming them is part of the system, not a weakness.", symbolName: "gift.fill", coinReward: 10),
        Achievement(code: "photo.streak", title: "Ten in Frame", detail: "Ten consecutive progress photos.", symbolName: "camera.fill", coinReward: 30),

        Achievement(code: "comeback", title: "Back Again", detail: "Restarted and got seven days deep. Attempt two beats attempt one every time.", symbolName: "arrow.counterclockwise.circle.fill", coinReward: 50),
        Achievement(code: "balance.builder", title: "Steady", detail: "Twenty days of balance work. This is the one that keeps you on your feet at eighty.", symbolName: "figure.stand", coinReward: 60),
        Achievement(code: "no.freeze", title: "Clean Thirty", detail: "Thirty completed days without spending a single freeze.", symbolName: "snowflake.slash", coinReward: 70),
        Achievement(code: "honest.log", title: "Thirty Check-ins", detail: "Told the truth about how you felt thirty times.", symbolName: "checkmark.message.fill", coinReward: 40),
        Achievement(code: "age.is.a.number", title: "Thirty at Sixty-Five Plus", detail: "Thirty days done, past an age where most people stop starting things.", symbolName: "star.circle.fill", coinReward: 100)
    ]

    static let byCode: [String: Achievement] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })
    }()

    static func achievement(for code: String) -> Achievement? { byCode[code] }
}
