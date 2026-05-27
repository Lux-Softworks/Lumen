import Foundation
import NaturalLanguage
import os

actor SemanticTopicClassifier {
    static let shared = SemanticTopicClassifier()

    private struct TopicPrototype {
        let name: String
        let vector: [Double]
    }

    private var prototypes: [TopicPrototype]?

    private static let minConfidence: Double = 0.20
    private static let relativeMargin: Double = 0.03

    private static let topicSeeds: [(String, [String])] = [
        (
            "AI",
            [
                "artificial intelligence machine learning neural networks deep learning",
                "large language models LLM GPT Claude transformer attention",
                "AI agents chatbots reinforcement learning training inference",
                "AI safety alignment interpretability reasoning frontier models",
                "openai anthropic google deepmind model capabilities benchmark",
                "computer vision speech recognition generative image video model",
            ]
        ),
        (
            "Programming",
            [
                "programming language syntax compiler runtime debugger",
                "software engineering code review pull request refactor",
                "javascript typescript python rust go swift kotlin",
                "frontend backend api rest graphql database orm",
                "git repository version control branch merge commit",
                "framework library package dependency build system",
            ]
        ),
        (
            "Technology",
            [
                "smartphone laptop tablet headphones wearable device",
                "consumer electronics hardware specs review launch",
                "iphone android mac windows operating system update",
                "tech industry company acquisition IPO earnings",
                "chip processor semiconductor fabrication",
                "silicon valley startup unicorn valuation",
            ]
        ),
        (
            "Finance",
            [
                "stock market equities bonds treasury yield inflation",
                "federal reserve interest rate monetary policy",
                "investing portfolio diversification asset allocation",
                "quarterly earnings revenue profit margin guidance",
                "cryptocurrency bitcoin ethereum blockchain defi",
                "personal finance savings retirement tax budget",
            ]
        ),
        (
            "Business",
            [
                "startup founder venture capital fundraising seed series",
                "business strategy market positioning competitive advantage",
                "entrepreneurship launch product pivot scale",
                "management leadership organization culture team",
                "sales marketing growth customer acquisition retention",
            ]
        ),
        (
            "Sports",
            [
                "football basketball baseball soccer tennis golf",
                "nba nfl mlb premier league champions",
                "athlete team coach playoff championship tournament",
                "score match game season league standings",
                "olympics world cup medal record athlete",
            ]
        ),
        (
            "Health",
            [
                "medical research clinical trial disease treatment",
                "nutrition diet exercise fitness workout",
                "mental health anxiety depression therapy wellness",
                "doctor hospital patient diagnosis symptom",
                "medicine drug pharmaceutical dosage prescription",
                "sleep stress recovery longevity supplement",
            ]
        ),
        (
            "Science",
            [
                "physics quantum mechanics relativity particle",
                "biology cell genome evolution organism",
                "chemistry molecule reaction compound",
                "astronomy planet galaxy telescope cosmos space exploration",
                "scientific research paper peer reviewed journal",
                "mathematics theorem proof equation",
            ]
        ),
        (
            "Travel",
            [
                "flight hotel booking itinerary destination",
                "tourism sightseeing attraction landmark",
                "vacation trip holiday travel guide",
                "airline airport boarding pass ticket",
                "city country visit tour local",
            ]
        ),
        (
            "Politics",
            [
                "election campaign vote candidate president",
                "congress senate legislation bill policy",
                "government administration white house",
                "foreign policy diplomacy treaty sanctions",
                "democracy republican democrat political party",
            ]
        ),
        (
            "Design",
            [
                "user interface ux design visual hierarchy typography",
                "design system component library pattern",
                "branding logo identity color palette",
                "product design wireframe prototype figma",
                "aesthetics craft detail minimalism",
            ]
        ),
        (
            "Gaming",
            [
                "video game console playstation xbox nintendo",
                "game review release trailer gameplay",
                "esports tournament competitive player stream",
                "rpg fps mmo indie aaa title",
                "steam epic game developer studio",
            ]
        ),
        (
            "Music",
            [
                "song album artist band release tour",
                "genre rock pop hip hop jazz classical electronic",
                "streaming spotify apple music chart billboard",
                "producer songwriter lyrics composition",
                "concert festival live performance venue",
            ]
        ),
        (
            "Film",
            [
                "movie film cinema director screenplay actor",
                "tv series show episode season streaming netflix hbo",
                "plot character protagonist storyline narrative arc",
                "science fiction fantasy thriller drama franchise sequel",
                "box office premiere trailer review studio cast",
            ]
        ),
        (
            "Anime",
            [
                "anime manga japanese animation studio",
                "mecha shonen shojo seinen isekai slice of life",
                "anime series episode character arc adaptation",
                "otaku light novel cosplay franchise subtitled dubbed",
                "naruto one piece evangelion gundam studio ghibli",
            ]
        ),
        (
            "Food",
            [
                "recipe cooking ingredient dish meal",
                "restaurant cuisine chef menu dining",
                "baking bread pastry dessert",
                "coffee tea wine cocktail",
                "flavor taste technique kitchen",
            ]
        ),
        (
            "Education",
            [
                "university college student degree course",
                "curriculum learning teaching pedagogy",
                "admissions tuition scholarship financial aid",
                "research academic scholar professor",
                "online course tutorial lesson",
            ]
        ),
        (
            "Law",
            [
                "court judge lawsuit ruling verdict",
                "attorney lawyer legal case litigation",
                "regulation compliance statute constitutional",
                "supreme court appellate circuit",
                "contract intellectual property patent trademark",
            ]
        ),
        (
            "History",
            [
                "ancient medieval renaissance modern era",
                "historical event war revolution empire",
                "civilization culture archaeology artifact",
                "biography historical figure era century",
            ]
        ),
        (
            "Art",
            [
                "painting sculpture gallery exhibition museum",
                "artist medium canvas brush palette",
                "contemporary modern classical art movement",
                "curator critic auction collection",
            ]
        ),
        (
            "Photography",
            [
                "camera lens aperture shutter iso photograph",
                "photographer portrait landscape street documentary",
                "photo editing lightroom raw exposure composition",
                "film analog digital mirrorless dslr",
            ]
        ),
        (
            "Books",
            [
                "novel fiction nonfiction author bestseller chapter",
                "bookstore library reading list book club",
                "literary publisher memoir biography",
                "poetry essay short story anthology",
            ]
        ),
        (
            "Fashion",
            [
                "clothing designer brand collection runway",
                "fashion week trend accessory shoes bag",
                "retail boutique luxury streetwear",
                "textile fabric material garment",
            ]
        ),
        (
            "Automotive",
            [
                "car vehicle sedan suv truck",
                "engine horsepower torque transmission",
                "electric vehicle ev tesla battery range",
                "driving review test drive model year",
                "motorcycle bike racing formula",
            ]
        ),
        (
            "Climate",
            [
                "climate change global warming emissions",
                "renewable energy solar wind battery storage",
                "sustainability carbon footprint offset",
                "environment ecosystem biodiversity conservation",
                "weather extreme drought flood wildfire",
            ]
        ),
        (
            "Productivity",
            [
                "workflow task management notes note-taking second brain",
                "focus deep work time blocking calendar",
                "tools apps obsidian notion readwise",
                "habit routine gtd system method",
            ]
        ),
        (
            "Psychology",
            [
                "cognitive behavior emotion mental",
                "therapy counseling cbt mindfulness",
                "personality trait motivation habit formation",
                "neuroscience brain cognition memory attention",
            ]
        ),
        (
            "Philosophy",
            [
                "ethics metaphysics epistemology ontology",
                "philosopher argument logic reasoning",
                "existence meaning consciousness moral",
                "stoicism utilitarianism kant aristotle plato",
            ]
        ),
        (
            "Culture",
            [
                "society social trend community",
                "identity generation internet online culture",
                "tradition custom ritual festival",
                "media influence discourse conversation",
            ]
        ),
    ]

    private init() {}

    private func loadedPrototypes() async -> [TopicPrototype] {
        if let prototypes { return prototypes }

        var flatSeeds: [String] = []
        var owners: [Int] = []
        for (index, entry) in Self.topicSeeds.enumerated() {
            for seed in entry.1 {
                flatSeeds.append(seed)
                owners.append(index)
            }
        }

        let vectors = await EmbeddingService.shared.generateEmbeddings(for: flatSeeds)
        var byTopic: [Int: [[Double]]] = [:]
        for (slot, vector) in vectors.enumerated() {
            guard let vector else { continue }
            byTopic[owners[slot], default: []].append(vector)
        }

        var built: [TopicPrototype] = []
        for (index, entry) in Self.topicSeeds.enumerated() {
            guard let vecs = byTopic[index], !vecs.isEmpty else { continue }
            built.append(TopicPrototype(name: entry.0, vector: Self.average(vecs)))
        }

        prototypes = built
        return built
    }

    func classify(title: String?, content: String) async -> String {
        let probe = Self.buildProbe(title: title, content: content)
        guard !probe.isEmpty else { return "" }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(probe)
        if let lang = recognizer.dominantLanguage, lang != .english { return "" }

        let prototypes = await loadedPrototypes()
        guard !prototypes.isEmpty else { return "" }
        guard let vector = await EmbeddingService.shared.generateEmbedding(for: probe) else { return "" }

        let ranked =
            prototypes
            .map { (name: $0.name, score: VectorMath.cosineSimilarity(vector, $0.vector)) }
            .sorted { $0.score > $1.score }

        guard let best = ranked.first, best.score >= Self.minConfidence else { return "" }

        if ranked.count >= 2 {
            let gap = best.score - ranked[1].score
            if gap < best.score * Self.relativeMargin { return "" }
        }

        return best.name
    }

    private static func buildProbe(title: String?, content: String) -> String {
        var parts: [String] = []
        if let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedTitle.isEmpty {
            parts.append(trimmedTitle)
        }

        let snippet = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyLimit = 1200
        if snippet.count > bodyLimit {
            parts.append(String(snippet.prefix(bodyLimit)))
        } else {
            parts.append(snippet)
        }

        return parts.joined(separator: ". ")
    }

    private static func average(_ vectors: [[Double]]) -> [Double] {
        guard let first = vectors.first else { return [] }

        var result = [Double](repeating: 0, count: first.count)
        for vector in vectors {
            for i in 0..<min(result.count, vector.count) {
                result[i] += vector[i]
            }
        }

        let count = Double(vectors.count)
        for i in 0..<result.count {
            result[i] /= count
        }

        return result
    }
}
