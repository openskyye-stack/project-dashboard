import Foundation

/// The recipes that ship with the app, so the meal planner works offline on day
/// one. Everything here is chosen for three things at once: it fits the diet
/// rules of at least one tier, it hits protein hard enough to matter for an
/// older body, and it can be made without long periods of standing.
///
/// `standingMinutes` is the number that makes this library different from a
/// generic one — it's the honest answer to "how long will I be on my feet?".
enum RecipeLibrary {

    static func seedRecipes() -> [Recipe] {
        breakfasts + lunches + dinners + snacks
    }

    // MARK: - Breakfast

    private static var breakfasts: [Recipe] {
        [
            Recipe(
                title: "Overnight Protein Oats",
                summary: "Assembled in three minutes the night before, eaten cold. Nothing to stand at.",
                servings: 1, prepMinutes: 3, cookMinutes: 0,
                calories: 430, proteinG: 32, carbsG: 48, fatG: 12, fiberG: 8, sodiumMg: 180,
                ingredients: [
                    IngredientLine("rolled oats", 60, "g", aisle: .grains),
                    IngredientLine("Greek yoghurt", 150, "g", aisle: .dairyAndEggs),
                    IngredientLine("milk", 100, "ml", aisle: .dairyAndEggs),
                    IngredientLine("whey or plant protein powder", 1, "scoop", aisle: .pantry),
                    IngredientLine("chia seeds", 1, "tbsp", aisle: .pantry),
                    IngredientLine("blueberries", 80, "g", aisle: .produce),
                    IngredientLine("cinnamon", 1, "pinch", aisle: .spices)
                ],
                steps: [
                    "Put everything except the blueberries in a jar.",
                    "Stir until there are no dry pockets. Lid on.",
                    "Fridge overnight, minimum four hours.",
                    "Top with blueberries in the morning."
                ],
                mealSlot: .breakfast,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .glutenFree, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: true, softTexture: true,
                batchFriendly: true, standingMinutes: 0, lowKnifeSkill: true
            ),
            Recipe(
                title: "Sheet-Pan Egg Squares",
                summary: "Twelve portions from one tray. Reheats in ninety seconds all week.",
                servings: 6, prepMinutes: 10, cookMinutes: 25,
                calories: 1560, proteinG: 132, carbsG: 36, fatG: 96, fiberG: 9, sodiumMg: 1400,
                ingredients: [
                    IngredientLine("eggs", 12, "", aisle: .dairyAndEggs),
                    IngredientLine("cottage cheese", 200, "g", aisle: .dairyAndEggs),
                    IngredientLine("frozen spinach", 200, "g", aisle: .frozen, note: "thawed and squeezed"),
                    IngredientLine("cherry tomatoes", 150, "g", aisle: .produce, note: "halved"),
                    IngredientLine("feta", 100, "g", aisle: .dairyAndEggs),
                    IngredientLine("black pepper", 1, "tsp", aisle: .spices),
                    IngredientLine("olive oil", 1, "tbsp", aisle: .pantry)
                ],
                steps: [
                    "Heat the oven to 180°C / 350°F. Oil a lined baking tray.",
                    "Whisk eggs and cottage cheese in a large bowl — do this sitting down.",
                    "Stir in the spinach, tomatoes, crumbled feta and pepper.",
                    "Pour into the tray, bake 22–25 minutes until just set in the middle.",
                    "Cool, cut into 12 squares, keep 4 days in the fridge."
                ],
                mealSlot: .breakfast,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .glutenFree, .lowCarb, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: true,
                batchFriendly: true, standingMinutes: 6, lowKnifeSkill: true
            ),
            Recipe(
                title: "Smoked Salmon on Rye",
                summary: "No cooking at all. Two minutes, thirty grams of protein.",
                servings: 1, prepMinutes: 4, cookMinutes: 0,
                calories: 390, proteinG: 30, carbsG: 32, fatG: 15, fiberG: 6, sodiumMg: 900,
                ingredients: [
                    IngredientLine("rye bread", 2, "slices", aisle: .bakery),
                    IngredientLine("smoked salmon", 100, "g", aisle: .meatAndFish),
                    IngredientLine("cream cheese", 40, "g", aisle: .dairyAndEggs),
                    IngredientLine("cucumber", 0.25, "", aisle: .produce, note: "sliced"),
                    IngredientLine("lemon", 0.25, "", aisle: .produce),
                    IngredientLine("dill", 1, "tsp", aisle: .spices, isOptional: true)
                ],
                steps: [
                    "Spread the cream cheese on the rye.",
                    "Layer salmon and cucumber.",
                    "Squeeze the lemon over, add dill if you have it."
                ],
                mealSlot: .breakfast,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.pescatarian, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: true,
                batchFriendly: false, standingMinutes: 0, lowKnifeSkill: true
            ),
            Recipe(
                title: "Banana Almond Smoothie",
                summary: "For mornings when chewing is the problem. Blender does everything.",
                servings: 1, prepMinutes: 3, cookMinutes: 0,
                calories: 420, proteinG: 34, carbsG: 44, fatG: 12, fiberG: 7, sodiumMg: 200,
                ingredients: [
                    IngredientLine("banana", 1, "", aisle: .produce),
                    IngredientLine("Greek yoghurt", 150, "g", aisle: .dairyAndEggs),
                    IngredientLine("milk", 200, "ml", aisle: .dairyAndEggs),
                    IngredientLine("almond butter", 1, "tbsp", aisle: .pantry),
                    IngredientLine("protein powder", 1, "scoop", aisle: .pantry),
                    IngredientLine("ground flaxseed", 1, "tbsp", aisle: .pantry)
                ],
                steps: [
                    "Everything in the blender.",
                    "Blend 45 seconds.",
                    "Drink within the hour or it separates."
                ],
                mealSlot: .breakfast,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .glutenFree, .softTexture],
                seatedPrepFriendly: true, oneHandedFriendly: true, softTexture: true,
                batchFriendly: false, standingMinutes: 0, lowKnifeSkill: true
            ),
            Recipe(
                title: "Savoury Cottage Cheese Bowl",
                summary: "Thirty-five grams of protein and no heat source involved.",
                servings: 1, prepMinutes: 5, cookMinutes: 0,
                calories: 340, proteinG: 35, carbsG: 18, fatG: 14, fiberG: 5, sodiumMg: 620,
                ingredients: [
                    IngredientLine("cottage cheese", 250, "g", aisle: .dairyAndEggs),
                    IngredientLine("cherry tomatoes", 100, "g", aisle: .produce),
                    IngredientLine("cucumber", 0.5, "", aisle: .produce),
                    IngredientLine("olive oil", 1, "tsp", aisle: .pantry),
                    IngredientLine("everything bagel seasoning", 1, "tsp", aisle: .spices),
                    IngredientLine("avocado", 0.5, "", aisle: .produce, isOptional: true)
                ],
                steps: [
                    "Spoon the cottage cheese into a bowl.",
                    "Halve the tomatoes and slice the cucumber — sitting down, blunt knife is fine.",
                    "Scatter over, oil, seasoning."
                ],
                mealSlot: .breakfast,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .glutenFree, .lowCarb, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: true,
                batchFriendly: false, standingMinutes: 0, lowKnifeSkill: true
            ),
            Recipe(
                title: "Slow Cooker Steel-Cut Oats",
                summary: "Set it before bed, six portions ready at dawn. Zero morning effort.",
                servings: 6, prepMinutes: 5, cookMinutes: 420,
                calories: 1980, proteinG: 66, carbsG: 300, fatG: 48, fiberG: 42, sodiumMg: 300,
                ingredients: [
                    IngredientLine("steel-cut oats", 320, "g", aisle: .grains),
                    IngredientLine("water", 1200, "ml", aisle: .other),
                    IngredientLine("milk", 400, "ml", aisle: .dairyAndEggs),
                    IngredientLine("apple", 2, "", aisle: .produce, note: "diced"),
                    IngredientLine("cinnamon", 2, "tsp", aisle: .spices),
                    IngredientLine("walnuts", 60, "g", aisle: .pantry, isOptional: true)
                ],
                steps: [
                    "Everything except the walnuts into the slow cooker.",
                    "Low for 7 hours.",
                    "Stir well in the morning, portion into six containers.",
                    "Walnuts go on at serving so they stay crunchy."
                ],
                mealSlot: .breakfast,
                tierCompliance: [.soft, .medium],
                dietaryTags: [.vegetarian],
                seatedPrepFriendly: true, oneHandedFriendly: true, softTexture: true,
                batchFriendly: true, standingMinutes: 3, lowKnifeSkill: false
            )
        ]
    }

    // MARK: - Lunch

    private static var lunches: [Recipe] {
        [
            Recipe(
                title: "Chicken & Quinoa Mason Jars",
                summary: "Five lunches built in one seated session. Shake and eat.",
                servings: 5, prepMinutes: 25, cookMinutes: 20,
                calories: 2600, proteinG: 215, carbsG: 220, fatG: 85, fiberG: 35, sodiumMg: 1900,
                ingredients: [
                    IngredientLine("chicken breast", 750, "g", aisle: .meatAndFish),
                    IngredientLine("quinoa", 300, "g", aisle: .grains, note: "dry"),
                    IngredientLine("chickpeas", 400, "g", aisle: .pantry, note: "drained tin"),
                    IngredientLine("cherry tomatoes", 300, "g", aisle: .produce),
                    IngredientLine("cucumber", 1, "", aisle: .produce),
                    IngredientLine("red onion", 0.5, "", aisle: .produce),
                    IngredientLine("feta", 150, "g", aisle: .dairyAndEggs),
                    IngredientLine("olive oil", 4, "tbsp", aisle: .pantry),
                    IngredientLine("lemon", 2, "", aisle: .produce),
                    IngredientLine("dried oregano", 2, "tsp", aisle: .spices)
                ],
                steps: [
                    "Cook the quinoa, cool it fully.",
                    "Poach or bake the chicken, shred it. A rotisserie chicken is a legitimate shortcut.",
                    "Chop the vegetables sitting at a table.",
                    "Layer each jar: dressing at the bottom, then quinoa, chickpeas, chicken, vegetables, feta on top.",
                    "Lids on. Four days in the fridge. Shake before eating."
                ],
                mealSlot: .lunch,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.glutenFree, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: false,
                batchFriendly: true, standingMinutes: 12, lowKnifeSkill: false
            ),
            Recipe(
                title: "Tinned Salmon Salad",
                summary: "Store cupboard to plate in five minutes. No heat, no standing.",
                servings: 1, prepMinutes: 5, cookMinutes: 0,
                calories: 410, proteinG: 38, carbsG: 12, fatG: 24, fiberG: 5, sodiumMg: 700,
                ingredients: [
                    IngredientLine("tinned salmon", 150, "g", aisle: .pantry),
                    IngredientLine("Greek yoghurt", 2, "tbsp", aisle: .dairyAndEggs),
                    IngredientLine("dijon mustard", 1, "tsp", aisle: .pantry),
                    IngredientLine("celery", 1, "stick", aisle: .produce),
                    IngredientLine("mixed leaves", 60, "g", aisle: .produce),
                    IngredientLine("lemon", 0.5, "", aisle: .produce),
                    IngredientLine("capers", 1, "tbsp", aisle: .pantry, isOptional: true)
                ],
                steps: [
                    "Drain the salmon, tip into a bowl, break it up with a fork.",
                    "Stir in yoghurt, mustard, lemon.",
                    "Slice the celery, fold through.",
                    "Spoon over the leaves."
                ],
                mealSlot: .lunch,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.pescatarian, .glutenFree, .lowCarb, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: true, softTexture: true,
                batchFriendly: false, standingMinutes: 0, lowKnifeSkill: true
            ),
            Recipe(
                title: "Lentil & Vegetable Soup",
                summary: "One pot, freezes in portions, spoon-only eating.",
                servings: 6, prepMinutes: 15, cookMinutes: 35,
                calories: 1680, proteinG: 96, carbsG: 240, fatG: 30, fiberG: 60, sodiumMg: 1500,
                ingredients: [
                    IngredientLine("red lentils", 400, "g", aisle: .pantry),
                    IngredientLine("carrots", 3, "", aisle: .produce),
                    IngredientLine("celery", 3, "sticks", aisle: .produce),
                    IngredientLine("onion", 1, "", aisle: .produce),
                    IngredientLine("garlic", 3, "cloves", aisle: .produce),
                    IngredientLine("chopped tomatoes", 400, "g", aisle: .pantry, note: "tin"),
                    IngredientLine("vegetable stock", 1500, "ml", aisle: .pantry),
                    IngredientLine("cumin", 2, "tsp", aisle: .spices),
                    IngredientLine("smoked paprika", 1, "tsp", aisle: .spices),
                    IngredientLine("olive oil", 2, "tbsp", aisle: .pantry)
                ],
                steps: [
                    "Buy the vegetables pre-chopped if chopping is the barrier — it makes no difference to the result.",
                    "Soften onion, carrot and celery in the oil, 8 minutes.",
                    "Garlic and spices, 1 minute.",
                    "Lentils, tomatoes and stock in. Simmer 30 minutes.",
                    "Blend half of it if you want it smooth. Portion and freeze."
                ],
                mealSlot: .lunch,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegan, .vegetarian, .glutenFree, .dairyFree, .nutFree, .softTexture],
                seatedPrepFriendly: false, oneHandedFriendly: false, softTexture: true,
                batchFriendly: true, standingMinutes: 15, lowKnifeSkill: false
            ),
            Recipe(
                title: "Turkey & Hummus Wrap",
                summary: "Assembly only. Made standing at a counter for ninety seconds.",
                servings: 1, prepMinutes: 4, cookMinutes: 0,
                calories: 450, proteinG: 36, carbsG: 42, fatG: 15, fiberG: 8, sodiumMg: 950,
                ingredients: [
                    IngredientLine("wholemeal wrap", 1, "", aisle: .bakery),
                    IngredientLine("turkey slices", 120, "g", aisle: .meatAndFish),
                    IngredientLine("hummus", 3, "tbsp", aisle: .dairyAndEggs),
                    IngredientLine("spinach", 30, "g", aisle: .produce),
                    IngredientLine("roasted red pepper", 60, "g", aisle: .pantry),
                    IngredientLine("black pepper", 1, "pinch", aisle: .spices)
                ],
                steps: [
                    "Hummus across the wrap.",
                    "Turkey, spinach, pepper strips down the middle.",
                    "Roll tightly, cut in half."
                ],
                mealSlot: .lunch,
                tierCompliance: [.soft, .medium],
                dietaryTags: [.nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: false,
                batchFriendly: false, standingMinutes: 2, lowKnifeSkill: true
            ),
            Recipe(
                title: "Tofu Rainbow Bowl",
                summary: "Roast a tray of vegetables once, eat it four ways.",
                servings: 4, prepMinutes: 15, cookMinutes: 30,
                calories: 1720, proteinG: 88, carbsG: 180, fatG: 68, fiberG: 32, sodiumMg: 1200,
                ingredients: [
                    IngredientLine("firm tofu", 500, "g", aisle: .dairyAndEggs),
                    IngredientLine("sweet potato", 2, "", aisle: .produce),
                    IngredientLine("broccoli", 1, "head", aisle: .produce),
                    IngredientLine("red pepper", 2, "", aisle: .produce),
                    IngredientLine("brown rice", 250, "g", aisle: .grains),
                    IngredientLine("soy sauce", 3, "tbsp", aisle: .pantry),
                    IngredientLine("sesame oil", 1, "tbsp", aisle: .pantry),
                    IngredientLine("tahini", 3, "tbsp", aisle: .pantry),
                    IngredientLine("lemon", 1, "", aisle: .produce)
                ],
                steps: [
                    "Oven to 200°C / 400°F.",
                    "Cube tofu and vegetables onto one tray, soy and sesame oil over, toss.",
                    "Roast 30 minutes, turning once.",
                    "Cook the rice while it roasts.",
                    "Thin the tahini with lemon and water for the dressing. Portion into four."
                ],
                mealSlot: .lunch,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegan, .vegetarian, .dairyFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: false,
                batchFriendly: true, standingMinutes: 10, lowKnifeSkill: false
            ),
            Recipe(
                title: "Egg & Avocado Rice Bowl",
                summary: "Uses leftover rice. One pan, five minutes.",
                servings: 1, prepMinutes: 3, cookMinutes: 5,
                calories: 480, proteinG: 24, carbsG: 45, fatG: 24, fiberG: 9, sodiumMg: 480,
                ingredients: [
                    IngredientLine("cooked rice", 150, "g", aisle: .grains),
                    IngredientLine("eggs", 2, "", aisle: .dairyAndEggs),
                    IngredientLine("avocado", 0.5, "", aisle: .produce),
                    IngredientLine("soy sauce", 1, "tsp", aisle: .pantry),
                    IngredientLine("chilli flakes", 1, "pinch", aisle: .spices, isOptional: true),
                    IngredientLine("spring onion", 1, "", aisle: .produce, isOptional: true)
                ],
                steps: [
                    "Warm the rice through.",
                    "Fry the eggs to your liking.",
                    "Rice in a bowl, eggs on top, avocado alongside, soy over."
                ],
                mealSlot: .lunch,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .dairyFree, .nutFree],
                seatedPrepFriendly: false, oneHandedFriendly: false, softTexture: true,
                batchFriendly: false, standingMinutes: 5, lowKnifeSkill: true
            )
        ]
    }

    // MARK: - Dinner

    private static var dinners: [Recipe] {
        [
            Recipe(
                title: "One-Tray Chicken & Root Veg",
                summary: "Everything on one tray. Eight minutes of standing, the oven does the rest.",
                servings: 4, prepMinutes: 12, cookMinutes: 40,
                calories: 2200, proteinG: 180, carbsG: 160, fatG: 80, fiberG: 28, sodiumMg: 1600,
                ingredients: [
                    IngredientLine("chicken thighs", 8, "", aisle: .meatAndFish, note: "bone in, skin on"),
                    IngredientLine("new potatoes", 700, "g", aisle: .produce),
                    IngredientLine("carrots", 4, "", aisle: .produce),
                    IngredientLine("red onion", 2, "", aisle: .produce),
                    IngredientLine("olive oil", 3, "tbsp", aisle: .pantry),
                    IngredientLine("dried rosemary", 2, "tsp", aisle: .spices),
                    IngredientLine("garlic", 4, "cloves", aisle: .produce),
                    IngredientLine("lemon", 1, "", aisle: .produce)
                ],
                steps: [
                    "Oven to 200°C / 400°F.",
                    "Halve the potatoes, chunk the carrots and onion — do it sitting at the table with the tray in front of you.",
                    "Everything onto the tray, oil and rosemary over, toss with your hands.",
                    "Chicken on top, skin up.",
                    "40 minutes. Lemon squeezed over at the end."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.glutenFree, .dairyFree, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: false,
                batchFriendly: true, standingMinutes: 8, lowKnifeSkill: false
            ),
            Recipe(
                title: "Slow Cooker Beef & Barley Stew",
                summary: "Ten minutes in the morning, dinner for five ready when you are.",
                servings: 5, prepMinutes: 15, cookMinutes: 480,
                calories: 2450, proteinG: 190, carbsG: 210, fatG: 85, fiberG: 30, sodiumMg: 2100,
                ingredients: [
                    IngredientLine("stewing beef", 800, "g", aisle: .meatAndFish),
                    IngredientLine("pearl barley", 200, "g", aisle: .grains),
                    IngredientLine("carrots", 4, "", aisle: .produce),
                    IngredientLine("celery", 3, "sticks", aisle: .produce),
                    IngredientLine("onion", 2, "", aisle: .produce),
                    IngredientLine("beef stock", 1200, "ml", aisle: .pantry),
                    IngredientLine("tomato purée", 2, "tbsp", aisle: .pantry),
                    IngredientLine("bay leaves", 2, "", aisle: .spices),
                    IngredientLine("thyme", 1, "tsp", aisle: .spices)
                ],
                steps: [
                    "Everything into the slow cooker. No browning needed — it costs you twenty minutes of standing and buys very little.",
                    "Low, 8 hours.",
                    "Fish out the bay leaves. Portion into five."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.dairyFree, .nutFree, .softTexture],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: true,
                batchFriendly: true, standingMinutes: 5, lowKnifeSkill: false
            ),
            Recipe(
                title: "Baked Cod with Tomatoes & Olives",
                summary: "Twenty-two minutes start to finish, one dish.",
                servings: 2, prepMinutes: 7, cookMinutes: 18,
                calories: 720, proteinG: 78, carbsG: 24, fatG: 32, fiberG: 7, sodiumMg: 1100,
                ingredients: [
                    IngredientLine("cod fillets", 2, "", aisle: .meatAndFish),
                    IngredientLine("cherry tomatoes", 300, "g", aisle: .produce),
                    IngredientLine("black olives", 60, "g", aisle: .pantry),
                    IngredientLine("garlic", 2, "cloves", aisle: .produce),
                    IngredientLine("olive oil", 2, "tbsp", aisle: .pantry),
                    IngredientLine("dried oregano", 1, "tsp", aisle: .spices),
                    IngredientLine("lemon", 1, "", aisle: .produce)
                ],
                steps: [
                    "Oven to 200°C / 400°F.",
                    "Tomatoes, olives, sliced garlic and oil in a baking dish. 8 minutes.",
                    "Cod on top, oregano over, back in for 12 minutes.",
                    "Lemon at the table."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.pescatarian, .glutenFree, .dairyFree, .lowCarb, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: true,
                batchFriendly: false, standingMinutes: 5, lowKnifeSkill: true
            ),
            Recipe(
                title: "Turkey Chilli",
                summary: "One pot, six portions, better on day three.",
                servings: 6, prepMinutes: 12, cookMinutes: 40,
                calories: 2340, proteinG: 200, carbsG: 190, fatG: 72, fiberG: 48, sodiumMg: 2200,
                ingredients: [
                    IngredientLine("turkey mince", 900, "g", aisle: .meatAndFish),
                    IngredientLine("kidney beans", 800, "g", aisle: .pantry, note: "two tins, drained"),
                    IngredientLine("chopped tomatoes", 800, "g", aisle: .pantry, note: "two tins"),
                    IngredientLine("onion", 2, "", aisle: .produce),
                    IngredientLine("red pepper", 2, "", aisle: .produce),
                    IngredientLine("chilli powder", 2, "tsp", aisle: .spices),
                    IngredientLine("cumin", 2, "tsp", aisle: .spices),
                    IngredientLine("smoked paprika", 2, "tsp", aisle: .spices),
                    IngredientLine("olive oil", 2, "tbsp", aisle: .pantry)
                ],
                steps: [
                    "Soften the onion and pepper, 6 minutes.",
                    "Turkey in, break it up, brown it.",
                    "Spices, 1 minute.",
                    "Tomatoes and beans, simmer 30 minutes with the lid off.",
                    "Portion into six. Freezes for three months."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.glutenFree, .dairyFree, .nutFree],
                seatedPrepFriendly: false, oneHandedFriendly: false, softTexture: true,
                batchFriendly: true, standingMinutes: 18, lowKnifeSkill: false
            ),
            Recipe(
                title: "Chickpea & Spinach Curry",
                summary: "Store cupboard dinner, twenty-five minutes, no meat to handle.",
                servings: 4, prepMinutes: 8, cookMinutes: 22,
                calories: 1640, proteinG: 68, carbsG: 200, fatG: 60, fiberG: 44, sodiumMg: 1300,
                ingredients: [
                    IngredientLine("chickpeas", 800, "g", aisle: .pantry, note: "two tins, drained"),
                    IngredientLine("coconut milk", 400, "ml", aisle: .pantry),
                    IngredientLine("chopped tomatoes", 400, "g", aisle: .pantry),
                    IngredientLine("frozen spinach", 250, "g", aisle: .frozen),
                    IngredientLine("onion", 1, "", aisle: .produce),
                    IngredientLine("garlic", 3, "cloves", aisle: .produce),
                    IngredientLine("curry powder", 2, "tbsp", aisle: .spices),
                    IngredientLine("ginger", 1, "tbsp", aisle: .produce, note: "grated"),
                    IngredientLine("basmati rice", 300, "g", aisle: .grains)
                ],
                steps: [
                    "Soften onion, add garlic, ginger and curry powder.",
                    "Tomatoes and coconut milk in, simmer 10 minutes.",
                    "Chickpeas and frozen spinach, another 10.",
                    "Rice alongside. Portion into four."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegan, .vegetarian, .glutenFree, .dairyFree, .nutFree, .softTexture],
                seatedPrepFriendly: false, oneHandedFriendly: false, softTexture: true,
                batchFriendly: true, standingMinutes: 14, lowKnifeSkill: false
            ),
            Recipe(
                title: "Salmon Traybake with Greens",
                summary: "Omega-3s and two portions of veg with one tray to wash.",
                servings: 2, prepMinutes: 6, cookMinutes: 20,
                calories: 900, proteinG: 72, carbsG: 40, fatG: 50, fiberG: 12, sodiumMg: 800,
                ingredients: [
                    IngredientLine("salmon fillets", 2, "", aisle: .meatAndFish),
                    IngredientLine("tenderstem broccoli", 200, "g", aisle: .produce),
                    IngredientLine("baby potatoes", 300, "g", aisle: .produce),
                    IngredientLine("olive oil", 2, "tbsp", aisle: .pantry),
                    IngredientLine("lemon", 1, "", aisle: .produce),
                    IngredientLine("garlic", 2, "cloves", aisle: .produce)
                ],
                steps: [
                    "Oven to 200°C / 400°F. Potatoes on the tray with oil, 20 minutes head start.",
                    "Add broccoli and salmon, another 12–14 minutes.",
                    "Lemon and garlic over at the end."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.pescatarian, .glutenFree, .dairyFree, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: true,
                batchFriendly: false, standingMinutes: 6, lowKnifeSkill: true
            ),
            Recipe(
                title: "Shepherd's Pie with Lentils",
                summary: "Soft throughout, freezes in portions, comfort food that still hits protein.",
                servings: 5, prepMinutes: 20, cookMinutes: 45,
                calories: 2300, proteinG: 130, carbsG: 260, fatG: 78, fiberG: 45, sodiumMg: 1900,
                ingredients: [
                    IngredientLine("lamb or beef mince", 500, "g", aisle: .meatAndFish),
                    IngredientLine("green lentils", 250, "g", aisle: .pantry, note: "cooked or tinned"),
                    IngredientLine("potatoes", 1000, "g", aisle: .produce),
                    IngredientLine("carrots", 3, "", aisle: .produce),
                    IngredientLine("onion", 1, "", aisle: .produce),
                    IngredientLine("beef stock", 400, "ml", aisle: .pantry),
                    IngredientLine("tomato purée", 2, "tbsp", aisle: .pantry),
                    IngredientLine("butter", 40, "g", aisle: .dairyAndEggs),
                    IngredientLine("milk", 100, "ml", aisle: .dairyAndEggs),
                    IngredientLine("worcestershire sauce", 1, "tbsp", aisle: .pantry)
                ],
                steps: [
                    "Boil the potatoes for mash.",
                    "Brown the mince with onion and carrot.",
                    "Lentils, stock, purée and worcestershire in. Simmer 15 minutes.",
                    "Mash the potatoes with butter and milk.",
                    "Mince into a dish, mash on top, 25 minutes at 200°C / 400°F."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium],
                dietaryTags: [.nutFree, .softTexture],
                seatedPrepFriendly: false, oneHandedFriendly: false, softTexture: true,
                batchFriendly: true, standingMinutes: 25, lowKnifeSkill: false
            ),
            Recipe(
                title: "Prawn & Courgette Stir Fry",
                summary: "Fifteen minutes, high protein, low effort.",
                servings: 2, prepMinutes: 8, cookMinutes: 8,
                calories: 640, proteinG: 62, carbsG: 48, fatG: 22, fiberG: 8, sodiumMg: 1400,
                ingredients: [
                    IngredientLine("raw prawns", 400, "g", aisle: .frozen),
                    IngredientLine("courgette", 2, "", aisle: .produce),
                    IngredientLine("red pepper", 1, "", aisle: .produce),
                    IngredientLine("soy sauce", 3, "tbsp", aisle: .pantry),
                    IngredientLine("garlic", 2, "cloves", aisle: .produce),
                    IngredientLine("ginger", 1, "tbsp", aisle: .produce),
                    IngredientLine("sesame oil", 1, "tbsp", aisle: .pantry),
                    IngredientLine("rice noodles", 150, "g", aisle: .grains)
                ],
                steps: [
                    "Noodles soaking in boiled water.",
                    "Hot pan, sesame oil, garlic and ginger 30 seconds.",
                    "Vegetables 4 minutes, prawns 3 minutes until pink.",
                    "Drained noodles and soy in, toss, serve."
                ],
                mealSlot: .dinner,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.pescatarian, .dairyFree, .nutFree],
                seatedPrepFriendly: false, oneHandedFriendly: false, softTexture: false,
                batchFriendly: false, standingMinutes: 12, lowKnifeSkill: false
            )
        ]
    }

    // MARK: - Snacks

    private static var snacks: [Recipe] {
        [
            Recipe(
                title: "Greek Yoghurt & Berries",
                summary: "Twenty grams of protein, no preparation worth the name.",
                servings: 1, prepMinutes: 2, cookMinutes: 0,
                calories: 220, proteinG: 22, carbsG: 22, fatG: 4, fiberG: 4, sodiumMg: 90,
                ingredients: [
                    IngredientLine("Greek yoghurt", 200, "g", aisle: .dairyAndEggs),
                    IngredientLine("mixed berries", 100, "g", aisle: .frozen),
                    IngredientLine("honey", 1, "tsp", aisle: .pantry, isOptional: true)
                ],
                steps: ["Yoghurt in a bowl.", "Berries on top. Frozen ones thaw in ten minutes."],
                mealSlot: .snack,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .glutenFree, .nutFree, .softTexture],
                seatedPrepFriendly: true, oneHandedFriendly: true, softTexture: true,
                batchFriendly: false, standingMinutes: 0, lowKnifeSkill: true
            ),
            Recipe(
                title: "Hard-Boiled Eggs, Batch of Twelve",
                summary: "Ten minutes on Sunday, protein on hand all week.",
                servings: 6, prepMinutes: 2, cookMinutes: 10,
                calories: 840, proteinG: 72, carbsG: 6, fatG: 60, fiberG: 0, sodiumMg: 420,
                ingredients: [
                    IngredientLine("eggs", 12, "", aisle: .dairyAndEggs),
                    IngredientLine("salt", 1, "pinch", aisle: .spices)
                ],
                steps: [
                    "Eggs into already-boiling water.",
                    "9 minutes for firm yolks.",
                    "Straight into cold water — they peel far more easily.",
                    "Keep unpeeled in the fridge for a week."
                ],
                mealSlot: .snack,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .glutenFree, .dairyFree, .lowCarb, .nutFree],
                seatedPrepFriendly: false, oneHandedFriendly: true, softTexture: true,
                batchFriendly: true, standingMinutes: 4, lowKnifeSkill: true
            ),
            Recipe(
                title: "Hummus & Crudités Box",
                summary: "Prep five boxes at once, sitting down.",
                servings: 5, prepMinutes: 15, cookMinutes: 0,
                calories: 950, proteinG: 35, carbsG: 90, fatG: 50, fiberG: 30, sodiumMg: 1300,
                ingredients: [
                    IngredientLine("hummus", 400, "g", aisle: .dairyAndEggs),
                    IngredientLine("carrots", 4, "", aisle: .produce),
                    IngredientLine("cucumber", 1, "", aisle: .produce),
                    IngredientLine("red pepper", 2, "", aisle: .produce),
                    IngredientLine("cherry tomatoes", 200, "g", aisle: .produce)
                ],
                steps: [
                    "Cut everything into sticks at the table. Pre-cut vegetable packs are a fine substitute.",
                    "Portion hummus into five small pots.",
                    "Box them up. Four days in the fridge."
                ],
                mealSlot: .snack,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegan, .vegetarian, .dairyFree, .nutFree],
                seatedPrepFriendly: true, oneHandedFriendly: false, softTexture: false,
                batchFriendly: true, standingMinutes: 0, lowKnifeSkill: false
            ),
            Recipe(
                title: "Cottage Cheese & Pineapple",
                summary: "Soft, cold, twenty-eight grams of protein. Good when nothing appeals.",
                servings: 1, prepMinutes: 2, cookMinutes: 0,
                calories: 260, proteinG: 28, carbsG: 26, fatG: 5, fiberG: 2, sodiumMg: 560,
                ingredients: [
                    IngredientLine("cottage cheese", 250, "g", aisle: .dairyAndEggs),
                    IngredientLine("pineapple", 120, "g", aisle: .produce, note: "tinned in juice is fine")
                ],
                steps: ["Combine. That's the recipe."],
                mealSlot: .snack,
                tierCompliance: [.soft, .medium, .hard],
                dietaryTags: [.vegetarian, .glutenFree, .nutFree, .softTexture],
                seatedPrepFriendly: true, oneHandedFriendly: true, softTexture: true,
                batchFriendly: false, standingMinutes: 0, lowKnifeSkill: true
            )
        ]
    }
}
