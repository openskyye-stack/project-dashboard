import Foundation
import SwiftData

/// One line on an ingredient list. Quantities are numeric so the shopping list
/// can actually add them up instead of listing "chicken" four times.
struct IngredientLine: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantity: Double
    var unit: String
    var aisleRaw: String
    var isOptional: Bool
    var note: String

    init(
        _ name: String,
        _ quantity: Double,
        _ unit: String,
        aisle: GroceryAisle = .other,
        isOptional: Bool = false,
        note: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisleRaw = aisle.rawValue
        self.isOptional = isOptional
        self.note = note
    }

    var aisle: GroceryAisle { GroceryAisle(rawValue: aisleRaw) ?? .other }

    /// Key used to merge identical ingredients across recipes.
    var mergeKey: String { "\(name.lowercased())|\(unit.lowercased())" }

    var displayQuantity: String {
        IngredientLine.formatQuantity(quantity, unit: unit)
    }

    static func formatQuantity(_ quantity: Double, unit: String) -> String {
        let rounded = (quantity * 100).rounded() / 100
        let number: String
        if rounded == rounded.rounded() {
            number = String(Int(rounded))
        } else if abs(rounded - 0.5) < 0.01 {
            number = "½"
        } else if abs(rounded - 0.25) < 0.01 {
            number = "¼"
        } else if abs(rounded - 0.75) < 0.01 {
            number = "¾"
        } else {
            number = String(format: "%.2f", rounded)
        }
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    var display: String {
        let q = displayQuantity
        let base = q.isEmpty ? name : "\(q) \(name)"
        return note.isEmpty ? base : "\(base), \(note)"
    }
}

@Model
final class Recipe {
    var id: UUID = UUID()
    var title: String = ""
    var summary: String = ""
    var servings: Int = 2
    var prepMinutes: Int = 10
    var cookMinutes: Int = 15

    var calories: Int = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var fiberG: Double = 0
    var sodiumMg: Double = 0

    var ingredients: [IngredientLine] = []
    var steps: [String] = []

    var mealSlotRaw: String = MealSlot.dinner.rawValue
    /// Tiers whose diet rules this recipe satisfies.
    var tierComplianceRaw: [String] = []
    var dietaryTagsRaw: [String] = []

    // Accessibility and effort flags — the reason this library exists rather than
    // a generic one. These drive the filters that matter for older or less mobile cooks.
    /// Can be prepped sitting down at a table.
    var seatedPrepFriendly: Bool = false
    /// No task needs two strong hands at once (no heavy pot draining, no wrestling jars).
    var oneHandedFriendly: Bool = false
    /// No hard chewing required.
    var softTexture: Bool = false
    /// Scales cleanly and keeps 4+ days — the backbone of a batch-cook session.
    var batchFriendly: Bool = false
    /// Minutes of continuous standing the recipe actually demands.
    var standingMinutes: Int = 0
    /// No sharp-knife work beyond simple slicing.
    var lowKnifeSkill: Bool = false

    var sourceURL: String?
    var isFavorite: Bool = false
    var isUserAdded: Bool = false
    var createdAt: Date = Date()

    init(
        title: String,
        summary: String,
        servings: Int,
        prepMinutes: Int,
        cookMinutes: Int,
        calories: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        fiberG: Double = 0,
        sodiumMg: Double = 0,
        ingredients: [IngredientLine],
        steps: [String],
        mealSlot: MealSlot,
        tierCompliance: [ChallengeTier],
        dietaryTags: [DietaryPreference] = [],
        seatedPrepFriendly: Bool = false,
        oneHandedFriendly: Bool = false,
        softTexture: Bool = false,
        batchFriendly: Bool = false,
        standingMinutes: Int = 0,
        lowKnifeSkill: Bool = false,
        sourceURL: String? = nil,
        isUserAdded: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sodiumMg = sodiumMg
        self.ingredients = ingredients
        self.steps = steps
        self.mealSlotRaw = mealSlot.rawValue
        self.tierComplianceRaw = tierCompliance.map(\.rawValue)
        self.dietaryTagsRaw = dietaryTags.map(\.rawValue)
        self.seatedPrepFriendly = seatedPrepFriendly
        self.oneHandedFriendly = oneHandedFriendly
        self.softTexture = softTexture
        self.batchFriendly = batchFriendly
        self.standingMinutes = standingMinutes
        self.lowKnifeSkill = lowKnifeSkill
        self.sourceURL = sourceURL
        self.isUserAdded = isUserAdded
    }

    var mealSlot: MealSlot {
        get { MealSlot(rawValue: mealSlotRaw) ?? .dinner }
        set { mealSlotRaw = newValue.rawValue }
    }

    var tierCompliance: [ChallengeTier] {
        tierComplianceRaw.compactMap(ChallengeTier.init(rawValue:))
    }

    var dietaryTags: [DietaryPreference] {
        dietaryTagsRaw.compactMap(DietaryPreference.init(rawValue:))
    }

    var totalMinutes: Int { prepMinutes + cookMinutes }

    var proteinPerServing: Double { servings > 0 ? proteinG / Double(servings) : proteinG }
    var caloriesPerServing: Int { servings > 0 ? calories / servings : calories }

    func satisfies(tier: ChallengeTier) -> Bool {
        tierCompliance.contains(tier)
    }

    /// True when every one of the person's dietary restrictions is honoured.
    func suits(dietary preferences: [DietaryPreference]) -> Bool {
        let required = preferences.filter { $0 != .none }
        guard !required.isEmpty else { return true }
        let tags = Set(dietaryTags)
        return required.allSatisfy { pref in
            switch pref {
            case .vegetarian:
                return tags.contains(.vegetarian) || tags.contains(.vegan)
            case .pescatarian:
                return tags.contains(.pescatarian) || tags.contains(.vegetarian) || tags.contains(.vegan)
            default:
                return tags.contains(pref)
            }
        }
    }
}

/// A recipe placed on a specific day and meal slot.
@Model
final class MealPlanEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var slotRaw: String = MealSlot.dinner.rawValue
    var recipeID: UUID = UUID()
    var recipeTitle: String = ""
    var servings: Int = 1
    var isPrepped: Bool = false
    var isEaten: Bool = false

    init(date: Date, slot: MealSlot, recipe: Recipe, servings: Int) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.slotRaw = slot.rawValue
        self.recipeID = recipe.id
        self.recipeTitle = recipe.title
        self.servings = servings
    }

    var slot: MealSlot {
        get { MealSlot(rawValue: slotRaw) ?? .dinner }
        set { slotRaw = newValue.rawValue }
    }
}

/// One aggregated line on the shopping list. Check-offs persist, so the list
/// survives being put down halfway round the shop.
@Model
final class ShoppingItem {
    var id: UUID = UUID()
    var name: String = ""
    var quantity: Double = 0
    var unit: String = ""
    var aisleRaw: String = GroceryAisle.other.rawValue
    var isChecked: Bool = false
    var isManuallyAdded: Bool = false
    /// Which recipes contributed to this line, for the "why is this here" tap.
    var sourceRecipes: [String] = []
    var weekStart: Date = Date()

    init(
        name: String,
        quantity: Double,
        unit: String,
        aisle: GroceryAisle,
        sourceRecipes: [String],
        weekStart: Date,
        isManuallyAdded: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisleRaw = aisle.rawValue
        self.sourceRecipes = sourceRecipes
        self.weekStart = Calendar.current.startOfDay(for: weekStart)
        self.isManuallyAdded = isManuallyAdded
    }

    var aisle: GroceryAisle { GroceryAisle(rawValue: aisleRaw) ?? .other }

    var display: String {
        let q = IngredientLine.formatQuantity(quantity, unit: unit)
        return q.isEmpty ? name : "\(q) \(name)"
    }
}
