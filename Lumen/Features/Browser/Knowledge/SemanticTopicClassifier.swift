import Foundation
import NaturalLanguage
import os

nonisolated struct TopicClassification: Sendable {
    let best: String?
    let candidates: [String]

    static let none = TopicClassification(best: nil, candidates: [])
}

actor SemanticTopicClassifier {
    static let shared = SemanticTopicClassifier()

    private struct TopicPrototype {
        let name: String
        let seedVectors: [[Double]]
    }

    private var prototypes: [TopicPrototype]?

    nonisolated private static let minConfidence: Double = 0.20

    private static let topicSeeds: [(String, [String])] = [
        ("AI", [
            "An article about artificial intelligence, machine learning, and neural networks.",
            "Coverage of large language models, chatbots, and AI companies like OpenAI and Anthropic.",
            "A piece on AI safety, model training, alignment, and frontier model capabilities."
        ]),
        ("Programming", [
            "An article about writing software, programming languages, and developer tools.",
            "A tutorial covering code, APIs, frameworks, debugging, and software engineering practice.",
            "A post about version control, code review, build systems, and open source libraries."
        ]),
        ("Technology", [
            "A review of consumer electronics like smartphones, laptops, and wearable devices.",
            "News about the tech industry, product launches, chips, and operating system updates.",
            "Coverage of Silicon Valley companies, gadgets, and hardware specifications."
        ]),
        ("Finance", [
            "An article about the stock market, bonds, interest rates, and inflation.",
            "Coverage of investing, portfolios, retirement savings, and personal finance.",
            "News about cryptocurrency, central banks, earnings reports, and monetary policy."
        ]),
        ("Business", [
            "An article about startups, founders, venture capital, and fundraising.",
            "A piece on business strategy, management, leadership, and company culture.",
            "Coverage of sales, marketing, growth, and customer acquisition."
        ]),
        ("Sports", [
            "Coverage of a football, basketball, baseball, or soccer game and its score.",
            "News about athletes, teams, coaches, playoffs, and championships.",
            "An article about the Olympics, tournaments, league standings, and records."
        ]),
        ("Health", [
            "An article about medical research, disease treatment, and clinical trials.",
            "A piece on nutrition, diet, exercise, fitness, and sleep.",
            "Coverage of mental health, therapy, wellness, and medicine."
        ]),
        ("Science", [
            "An article about physics, chemistry, biology, or astronomy research.",
            "Coverage of a scientific study, peer-reviewed paper, or new discovery.",
            "A piece about space exploration, genetics, mathematics, or the cosmos."
        ]),
        ("Travel", [
            "A guide to visiting a city or country, with sights and attractions.",
            "An article about flights, hotels, booking trips, and vacation planning.",
            "A piece about tourism, destinations, and travel itineraries."
        ]),
        ("Politics", [
            "News about elections, campaigns, candidates, and voting.",
            "Coverage of government, legislation, congress, and public policy.",
            "An article about foreign policy, diplomacy, and political parties."
        ]),
        ("Design", [
            "An article about user interface and user experience design.",
            "A piece on typography, visual hierarchy, branding, and design systems.",
            "Coverage of product design, wireframes, prototypes, and design tools like Figma."
        ]),
        ("Gaming", [
            "News about video games, consoles, and game releases.",
            "A game review discussing gameplay, story, and graphics.",
            "Coverage of esports, streamers, and game development studios."
        ]),
        ("Music", [
            "An article about a song, album, artist, or band.",
            "Coverage of concerts, festivals, tours, and live performances.",
            "A piece about music streaming, charts, producers, and songwriting."
        ]),
        ("Film", [
            "A review of a movie or television series.",
            "News about directors, actors, studios, and the box office.",
            "An article about a show's plot, characters, and storyline."
        ]),
        ("Anime", [
            "An article about anime series, manga, and Japanese animation.",
            "Coverage of anime adaptations, studios, and new season releases.",
            "A piece about manga chapters, characters, and anime fandom."
        ]),
        ("Food", [
            "A recipe with ingredients and cooking instructions.",
            "A restaurant review covering cuisine, chefs, and dining.",
            "An article about baking, coffee, wine, and cooking techniques."
        ]),
        ("Education", [
            "An article about universities, colleges, students, and degrees.",
            "A piece on teaching, curriculum, learning, and online courses.",
            "Coverage of admissions, tuition, scholarships, and academia."
        ]),
        ("Law", [
            "Coverage of a court case, lawsuit, ruling, or verdict.",
            "An article about lawyers, litigation, and legal regulation.",
            "A piece on contracts, intellectual property, and constitutional law."
        ]),
        ("History", [
            "An article about a historical event, war, or empire.",
            "A piece about ancient civilizations, archaeology, and artifacts.",
            "A biography of a historical figure and their era."
        ]),
        ("Art", [
            "An article about painting, sculpture, and gallery exhibitions.",
            "Coverage of artists, museums, and art movements.",
            "A piece about art auctions, collections, and curators."
        ]),
        ("Photography", [
            "An article about cameras, lenses, and photography technique.",
            "A piece on portrait, landscape, and street photography.",
            "Coverage of photo editing, exposure, and composition."
        ]),
        ("Books", [
            "A review of a novel or nonfiction book.",
            "An article about authors, publishers, and bestsellers.",
            "A piece about reading lists, libraries, and literature."
        ]),
        ("Fashion", [
            "An article about clothing designers, brands, and collections.",
            "Coverage of fashion week, runway shows, and trends.",
            "A piece about luxury retail, streetwear, and accessories."
        ]),
        ("Automotive", [
            "A review of a car, truck, or SUV and its driving performance.",
            "An article about electric vehicles, batteries, and charging range.",
            "Coverage of engines, motorcycles, and motor racing."
        ]),
        ("Climate", [
            "An article about climate change, global warming, and emissions.",
            "Coverage of renewable energy, solar power, and sustainability.",
            "A piece about extreme weather, conservation, and ecosystems."
        ]),
        ("Productivity", [
            "An article about task management, note-taking, and workflows.",
            "A piece on focus, deep work, habits, and time management.",
            "Coverage of productivity apps and systems like Notion and Obsidian."
        ]),
        ("Psychology", [
            "An article about human behavior, cognition, and emotion.",
            "A piece on neuroscience, memory, attention, and the brain.",
            "Coverage of therapy, motivation, personality, and habit formation."
        ]),
        ("Philosophy", [
            "An essay about ethics, metaphysics, and the meaning of existence.",
            "A piece discussing philosophers, arguments, and moral reasoning.",
            "An article about consciousness, logic, and schools of thought like Stoicism."
        ]),
        ("Culture", [
            "An article about society, social trends, and internet culture.",
            "A piece about traditions, festivals, and community identity.",
            "Coverage of media discourse and generational change."
        ])
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
            built.append(TopicPrototype(name: entry.0, seedVectors: vecs))
        }

        prototypes = built
        return built
    }

    func classify(title: String?, content: String) async -> TopicClassification {
        let probe = Self.buildProbe(title: title, content: content)
        guard !probe.isEmpty else { return .none }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(probe)
        if let lang = recognizer.dominantLanguage, lang != .english { return .none }

        let prototypes = await loadedPrototypes()
        guard !prototypes.isEmpty else { return .none }
        guard let vector = await EmbeddingService.shared.generateEmbedding(for: probe) else {
            return .none
        }

        let scored = prototypes.map { prototype in
            (
                name: prototype.name,
                score: prototype.seedVectors
                    .map { VectorMath.cosineSimilarity(vector, $0) }
                    .max() ?? 0
            )
        }
        return Self.rank(scored)
    }

    nonisolated static func rank(_ scored: [(name: String, score: Double)]) -> TopicClassification {
        let ranked = scored.sorted { $0.score > $1.score }
        guard let best = ranked.first, best.score >= minConfidence else { return .none }
        let candidates = ranked.prefix(3).filter { $0.score >= minConfidence }.map { $0.name }
        return TopicClassification(best: best.name, candidates: candidates)
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
}
