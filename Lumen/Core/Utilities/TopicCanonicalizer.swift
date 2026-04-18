import Foundation

enum TopicCanonicalizer {
    private static let aliases: [String: String] = [
        "ai": "AI",
        "a.i.": "AI",
        "a.i": "AI",
        "artifical": "AI",
        "artificial": "AI",
        "artificialintelligence": "AI",
        "ml": "AI",
        "machinelearning": "AI",
        "llm": "AI",
        "llms": "AI",
        "gpt": "AI",
        "neural": "AI",
        "deeplearning": "AI",

        "tech": "Technology",
        "technology": "Technology",
        "technologies": "Technology",
        "computing": "Technology",
        "software": "Technology",
        "hardware": "Technology",
        "gadget": "Technology",
        "gadgets": "Technology",
        "developer": "Technology",
        "programming": "Programming",
        "coding": "Programming",
        "webdev": "Programming",
        "engineering": "Programming",

        "fin": "Finance",
        "finance": "Finance",
        "financial": "Finance",
        "money": "Finance",
        "investing": "Finance",
        "investment": "Finance",
        "investments": "Finance",
        "markets": "Finance",
        "market": "Finance",
        "stocks": "Finance",
        "stock": "Finance",
        "cryptocurrency": "Finance",
        "bitcoin": "Finance",
        "economy": "Finance",
        "economic": "Finance",
        "economics": "Finance",
        "banking": "Finance",

        "biz": "Business",
        "business": "Business",
        "businesses": "Business",
        "startup": "Business",
        "startups": "Business",
        "entrepreneur": "Business",
        "entrepreneurship": "Business",

        "sport": "Sports",
        "sports": "Sports",
        "football": "Sports",
        "basketball": "Sports",
        "soccer": "Sports",
        "nfl": "Sports",
        "nba": "Sports",

        "health": "Health",
        "medical": "Health",
        "medicine": "Health",
        "fitness": "Health",
        "wellness": "Health",
        "nutrition": "Health",

        "sci": "Science",
        "science": "Science",
        "scientific": "Science",
        "physics": "Science",
        "biology": "Science",
        "chemistry": "Science",
        "astronomy": "Science",

        "travel": "Travel",
        "travels": "Travel",
        "tourism": "Travel",
        "vacation": "Travel",

        "politic": "Politics",
        "politics": "Politics",
        "political": "Politics",
        "government": "Politics",

        "design": "Design",
        "designs": "Design",
        "ui": "Design",
        "ux": "Design",
        "typography": "Design",
        "branding": "Design",

        "game": "Gaming",
        "games": "Gaming",
        "gaming": "Gaming",
        "esports": "Gaming",
        "videogames": "Gaming",

        "music": "Music",
        "album": "Music",
        "albums": "Music",
        "song": "Music",
        "songs": "Music",

        "film": "Film",
        "films": "Film",
        "movie": "Film",
        "movies": "Film",
        "cinema": "Film",
        "tv": "Film",
        "television": "Film",
        "streaming": "Film",

        "food": "Food",
        "foods": "Food",
        "cooking": "Food",
        "recipe": "Food",
        "recipes": "Food",
        "cuisine": "Food",
        "restaurant": "Food",
        "restaurants": "Food",

        "edu": "Education",
        "education": "Education",
        "educational": "Education",
        "learning": "Education",
        "school": "Education",
        "university": "Education",
        "college": "Education",
        "academic": "Education",

        "law": "Law",
        "legal": "Law",
        "legislation": "Law",
        "court": "Law",

        "history": "History",
        "historical": "History",

        "art": "Art",
        "arts": "Art",
        "gallery": "Art",
        "painting": "Art",
        "sculpture": "Art",

        "photo": "Photography",
        "photos": "Photography",
        "photography": "Photography",
        "photographer": "Photography",

        "book": "Books",
        "books": "Books",
        "literature": "Books",

        "fashion": "Fashion",
        "clothing": "Fashion",

        "auto": "Automotive",
        "automotive": "Automotive",
        "car": "Automotive",
        "cars": "Automotive",
        "vehicle": "Automotive",

        "climate": "Climate",
        "environment": "Climate",
        "environmental": "Climate",
        "sustainability": "Climate",

        "productivity": "Productivity",
        "workflow": "Productivity",

        "psychology": "Psychology",
        "mental": "Psychology",
        "philosophy": "Philosophy",
        "culture": "Culture",
        "religion": "Religion",
        "parenting": "Parenting",
        "family": "Family",
        "relationships": "Relationships"
    ]

    static func canonical(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let key = trimmed
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()

        if let hit = aliases[key] {
            return hit
        }

        return prettify(trimmed)
    }

    static func normalizedKey(for raw: String) -> String {
        canonical(for: raw).lowercased()
    }

    private static func prettify(_ s: String) -> String {
        let cleaned = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        if cleaned.count <= 4, cleaned == cleaned.uppercased() { return cleaned }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst().lowercased()
    }
}
