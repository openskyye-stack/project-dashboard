import Foundation

/// Pulls a recipe off the web without an API key or a scraper that breaks weekly.
///
/// Almost every recipe site publishes schema.org `Recipe` structured data in a
/// `<script type="application/ld+json">` block, because that's what gets them
/// into Google's recipe cards. We read that block. If a site doesn't publish it,
/// we say so plainly rather than guessing from the HTML.
enum RecipeImporter {

    enum ImportError: LocalizedError {
        case badURL
        case network(String)
        case noStructuredData
        case unreadable

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "That doesn't look like a web address."
            case .network(let detail):
                return "Couldn't reach the page. \(detail)"
            case .noStructuredData:
                return "That page doesn't publish machine-readable recipe data. Try a different site, or add the recipe by hand."
            case .unreadable:
                return "Found recipe data on the page but couldn't make sense of it."
            }
        }
    }

    struct Draft {
        var title: String
        var summary: String
        var servings: Int
        var prepMinutes: Int
        var cookMinutes: Int
        var calories: Int
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var fiberG: Double
        var sodiumMg: Double
        var ingredientTexts: [String]
        var steps: [String]
        var sourceURL: String
    }

    // MARK: - Fetch

    static func fetch(from urlString: String) async throws -> Draft {
        var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.lowercased().hasPrefix("http") {
            trimmed = "https://" + trimmed
        }
        guard let url = URL(string: trimmed), url.host != nil else {
            throw ImportError.badURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        // Some sites serve a stripped page to unknown agents; a plain browser
        // agent gets us the same HTML a person would see.
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ImportError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ImportError.network("The site returned \(http.statusCode).")
        }

        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unreadable
        }

        return try parse(html: html, sourceURL: trimmed)
    }

    // MARK: - Parse

    static func parse(html: String, sourceURL: String) throws -> Draft {
        let blocks = jsonLDBlocks(in: html)
        guard !blocks.isEmpty else { throw ImportError.noStructuredData }

        for block in blocks {
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let recipe = findRecipeObject(in: json) {
                return draft(from: recipe, sourceURL: sourceURL)
            }
        }
        throw ImportError.noStructuredData
    }

    /// Extracts the contents of every `<script type="application/ld+json">` tag.
    ///
    /// All searching happens against `html` itself with case-insensitive
    /// matching. Searching a separate `lowercased()` copy and slicing the
    /// original with those indices looks equivalent and is not — a single
    /// non-ASCII character whose lowercase form has a different UTF-8 length
    /// desynchronises the two, and recipe pages are full of accented words.
    static func jsonLDBlocks(in html: String) -> [String] {
        var blocks: [String] = []
        var searchStart = html.startIndex

        while let scriptOpen = html.range(of: "<script", options: .caseInsensitive, range: searchStart..<html.endIndex) {
            guard let tagEnd = html.range(of: ">", range: scriptOpen.upperBound..<html.endIndex) else { break }
            let attributes = html[scriptOpen.upperBound..<tagEnd.lowerBound]

            if attributes.range(of: "application/ld+json", options: .caseInsensitive) != nil,
               let closeTag = html.range(of: "</script", options: .caseInsensitive, range: tagEnd.upperBound..<html.endIndex) {
                let body = String(html[tagEnd.upperBound..<closeTag.lowerBound])
                blocks.append(body.trimmingCharacters(in: .whitespacesAndNewlines))
                searchStart = closeTag.upperBound
                continue
            }
            searchStart = tagEnd.upperBound
        }
        return blocks
    }

    /// JSON-LD arrives in several shapes: a bare object, an array, or an
    /// `@graph`. Walk all of them looking for something typed `Recipe`.
    private static func findRecipeObject(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if isRecipe(dict) { return dict }
            if let graph = dict["@graph"] {
                return findRecipeObject(in: graph)
            }
            for value in dict.values {
                if value is [String: Any] || value is [Any] {
                    if let found = findRecipeObject(in: value) { return found }
                }
            }
        }
        if let array = json as? [Any] {
            for element in array {
                if let found = findRecipeObject(in: element) { return found }
            }
        }
        return nil
    }

    private static func isRecipe(_ dict: [String: Any]) -> Bool {
        guard let type = dict["@type"] else { return false }
        if let string = type as? String { return string.caseInsensitiveCompare("Recipe") == .orderedSame }
        if let array = type as? [String] {
            return array.contains { $0.caseInsensitiveCompare("Recipe") == .orderedSame }
        }
        return false
    }

    private static func draft(from dict: [String: Any], sourceURL: String) -> Draft {
        let nutrition = dict["nutrition"] as? [String: Any] ?? [:]

        return Draft(
            title: string(dict["name"]) ?? "Imported recipe",
            summary: string(dict["description"]) ?? "",
            servings: servings(from: dict["recipeYield"]),
            prepMinutes: minutes(from: dict["prepTime"]),
            cookMinutes: minutes(from: dict["cookTime"]) > 0
                ? minutes(from: dict["cookTime"])
                : max(0, minutes(from: dict["totalTime"]) - minutes(from: dict["prepTime"])),
            calories: Int(number(from: nutrition["calories"])),
            proteinG: number(from: nutrition["proteinContent"]),
            carbsG: number(from: nutrition["carbohydrateContent"]),
            fatG: number(from: nutrition["fatContent"]),
            fiberG: number(from: nutrition["fiberContent"]),
            sodiumMg: number(from: nutrition["sodiumContent"]),
            ingredientTexts: stringList(dict["recipeIngredient"]),
            steps: instructions(from: dict["recipeInstructions"]),
            sourceURL: sourceURL
        )
    }

    // MARK: - Field helpers

    private static func string(_ value: Any?) -> String? {
        if let s = value as? String { return decodeEntities(s).trimmingCharacters(in: .whitespacesAndNewlines) }
        if let dict = value as? [String: Any] { return string(dict["text"] ?? dict["name"]) }
        if let array = value as? [Any] { return string(array.first) }
        return nil
    }

    private static func stringList(_ value: Any?) -> [String] {
        if let array = value as? [Any] {
            return array.compactMap { string($0) }.filter { !$0.isEmpty }
        }
        if let single = string(value), !single.isEmpty { return [single] }
        return []
    }

    private static func instructions(from value: Any?) -> [String] {
        guard let array = value as? [Any] else {
            // Some sites hand over one long paragraph. Split on sentence ends.
            guard let text = string(value), !text.isEmpty else { return [] }
            return text
                .components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        var steps: [String] = []
        for element in array {
            if let dict = element as? [String: Any] {
                // HowToSection nests its own itemListElement.
                if let nested = dict["itemListElement"] {
                    steps.append(contentsOf: instructions(from: nested))
                    continue
                }
                if let text = string(dict["text"]) ?? string(dict["name"]), !text.isEmpty {
                    steps.append(text)
                }
            } else if let text = string(element), !text.isEmpty {
                steps.append(text)
            }
        }
        return steps
    }

    /// ISO 8601 durations like `PT1H25M`.
    static func minutes(from value: Any?) -> Int {
        guard let raw = string(value) else { return 0 }
        if let plain = Int(raw) { return plain }
        guard raw.uppercased().hasPrefix("P") else { return 0 }

        var total = 0
        var digits = ""
        var inTimeSection = false

        for character in raw.uppercased() {
            if character == "T" { inTimeSection = true; digits = ""; continue }
            if character.isNumber { digits.append(character); continue }

            let value = Int(digits) ?? 0
            digits = ""
            switch character {
            case "D": total += value * 1440
            case "H": total += value * 60
            case "M": total += inTimeSection ? value : value * 43_200
            case "S": total += value / 60
            default: break
            }
        }
        return total
    }

    static func servings(from value: Any?) -> Int {
        if let number = value as? Int { return max(1, number) }
        if let array = value as? [Any] { return servings(from: array.first) }
        guard let raw = string(value) else { return 1 }
        let digits = raw.prefix { $0.isNumber }
        return max(1, Int(digits) ?? 1)
    }

    /// Nutrition values arrive as "23 g", "450 calories" or plain numbers.
    static func number(from value: Any?) -> Double {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        guard let raw = string(value) else { return 0 }
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        return Double(filtered) ?? 0
    }

    private static func decodeEntities(_ input: String) -> String {
        var output = input
        let map = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&#x27;": "'",
            "&frac12;": "½", "&frac14;": "¼", "&deg;": "°"
        ]
        for (entity, replacement) in map {
            output = output.replacingOccurrences(of: entity, with: replacement)
        }
        return output
    }

    // MARK: - Ingredient parsing

    /// Turns "2 tbsp olive oil" into a structured line so imported recipes feed
    /// the shopping list like the built-in ones do.
    static func parseIngredient(_ text: String) -> IngredientLine {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var quantity: Double = 1
        var unit = ""
        var name = cleaned

        let tokens = cleaned.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return IngredientLine(cleaned, 1, "", aisle: .other) }

        var index = 0
        if let parsed = fractionValue(tokens[0]) {
            quantity = parsed
            index = 1
            // "1 1/2 cups" — a second fraction token belongs to the same quantity.
            if tokens.count > 1, let second = fractionValue(tokens[1]), tokens[1].contains("/") {
                quantity += second
                index = 2
            }
        }

        let knownUnits: Set<String> = [
            "g", "kg", "ml", "l", "oz", "lb", "lbs", "cup", "cups", "tbsp", "tsp",
            "tablespoon", "tablespoons", "teaspoon", "teaspoons", "clove", "cloves",
            "slice", "slices", "pinch", "can", "cans", "tin", "tins", "stick", "sticks",
            "handful", "sprig", "sprigs", "head", "heads"
        ]
        if index < tokens.count {
            let candidate = tokens[index].lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            if knownUnits.contains(candidate) {
                unit = candidate
                index += 1
            }
        }

        if index < tokens.count {
            name = tokens[index...].joined(separator: " ")
        }

        return IngredientLine(name, quantity, unit, aisle: guessAisle(name))
    }

    private static func fractionValue(_ token: String) -> Double? {
        let unicodeFractions: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]
        if token.count == 1, let character = token.first, let value = unicodeFractions[character] {
            return value
        }
        if token.contains("/") {
            let parts = token.split(separator: "/")
            if parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 {
                return numerator / denominator
            }
            return nil
        }
        return Double(token)
    }

    static func guessAisle(_ name: String) -> GroceryAisle {
        let lower = name.lowercased()
        let table: [(GroceryAisle, [String])] = [
            (.produce, ["onion", "garlic", "tomato", "pepper", "carrot", "celery", "lettuce", "spinach", "potato", "lemon", "lime", "apple", "banana", "berr", "cucumber", "avocado", "broccoli", "courgette", "zucchini", "ginger", "herb", "mushroom", "kale"]),
            (.meatAndFish, ["chicken", "beef", "pork", "lamb", "turkey", "salmon", "cod", "prawn", "shrimp", "tuna", "mince", "bacon", "fish", "steak"]),
            (.dairyAndEggs, ["milk", "yoghurt", "yogurt", "cheese", "butter", "cream", "egg", "tofu", "hummus"]),
            (.grains, ["rice", "pasta", "oat", "quinoa", "noodle", "barley", "bread", "wrap", "tortilla", "couscous"]),
            (.frozen, ["frozen", "peas", "ice"]),
            (.bakery, ["baguette", "roll", "loaf", "pitta", "pita"]),
            (.spices, ["salt", "pepper", "cumin", "paprika", "cinnamon", "oregano", "thyme", "rosemary", "chilli", "chili", "curry powder", "bay lea", "seasoning"]),
            (.pantry, ["oil", "vinegar", "stock", "tinned", "canned", "bean", "lentil", "chickpea", "flour", "sugar", "honey", "soy sauce", "tahini", "olive", "nut", "seed", "coconut milk", "purée", "puree", "mustard"])
        ]
        for (aisle, keywords) in table where keywords.contains(where: { lower.contains($0) }) {
            return aisle
        }
        return .other
    }

    /// Converts a fetched draft into a stored recipe.
    static func makeRecipe(from draft: Draft, slot: MealSlot) -> Recipe {
        Recipe(
            title: draft.title,
            summary: draft.summary,
            servings: draft.servings,
            prepMinutes: draft.prepMinutes,
            cookMinutes: draft.cookMinutes,
            calories: draft.calories,
            proteinG: draft.proteinG,
            carbsG: draft.carbsG,
            fatG: draft.fatG,
            fiberG: draft.fiberG,
            sodiumMg: draft.sodiumMg,
            ingredients: draft.ingredientTexts.map(parseIngredient),
            steps: draft.steps,
            mealSlot: slot,
            // An imported recipe can't be assumed to fit anyone's diet rules, so
            // it starts unclassified and the user tags it.
            tierCompliance: [],
            dietaryTags: [],
            standingMinutes: max(0, draft.prepMinutes),
            sourceURL: draft.sourceURL,
            isUserAdded: true
        )
    }
}
