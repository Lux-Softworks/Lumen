import Foundation

enum KnowledgePrompts {
    static func pageSummary(content: String, title: String?) -> String {
        """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        Summarize articles in one sentence.<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        Understanding closures: Closures capture variables from their enclosing scope and can be passed as arguments.<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        Closures capture surrounding variables and can be passed around as self-contained blocks of functionality.<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        \(title ?? ""): \(content.prefix(500))<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>

        """
    }

    static func websiteSummary(content: String, title: String?) -> String {
        """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        Describe a website's purpose in under 8 words.<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        developer.apple.com: Documentation for iOS, macOS, watchOS APIs and frameworks.<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        Apple developer documentation and API reference.<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        \(title ?? ""): \(content.prefix(800))<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>

        """
    }

    static func websiteReadingSynthesis(summaries: [String]) -> String {
        let joined = summaries.prefix(8).joined(separator: ". ")
        return """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        Describe what these pages have in common in one sentence.<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        \(joined)<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>

        """
    }

    static func topicClassification(content: String, title: String?) -> String {
        """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        Assign ONE topic label from this exact list: AI, Technology, Programming, Finance, Business, Sports, Health, Science, Travel, Politics, Design, Gaming, Music, Film, Food, Education, Law, History, Art, Photography, Books, Fashion, Automotive, Climate, Productivity, Psychology, Philosophy, Culture.

        Rules:
        - Output the word EXACTLY as spelled in the list. Never abbreviate a list word (do not write "Artifical" for AI, do not write "Tech" for Technology).
        - Prefer "AI" for anything about machine learning, LLMs, neural networks, artificial intelligence.
        - Prefer "Programming" for coding, software development, languages, frameworks.
        - Prefer "Technology" for gadgets, consumer tech, tech industry news.
        - Output ONE word, nothing else. No punctuation. No "Other", "News", "Article", "Topic", "Unknown".<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        Introducing GPT-5: OpenAI announces a new large language model with multimodal reasoning.<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        AI<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        Rust 1.80 released: improvements to async traits and lazy static initialization.<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        Programming<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        Apple unveils new iPhone with titanium chassis and redesigned camera system.<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        Technology<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        Fed holds rates steady as inflation cools; markets rally on dovish tone from chair.<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        Finance<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        A beginner's guide to sourdough starter: maintaining a healthy culture at home.<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        Food<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        \(title ?? "N/A"): \(content.prefix(1500))<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>

        """
    }

    static func queryRefinement(query: String) -> String {
        """
        Your task is to refine the given query to be more suitable for database search.
        Once the query is refined, please find the most relevant keyword from the refined query.
        Respond with ONLY the keyword.

        Query: \(query)
        """
    }

    static func ragAnswer(
        query: String,
        context: String,
        highlightsBlock: String,
        highlightsGuideline: String,
        historyBlock: String
    ) -> String {
        """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        Answer ONLY from the sources below — pages from the user's reading history.
        - Use ONLY facts present in the sources. No outside knowledge.
        - Be as brief as possible. Dense, compressed answers. No filler sentences.
        - Do NOT describe your process. Do NOT say "I looked", "I searched", "based on the sources", "from the sources", "here is what I found", or any meta-commentary.
        - Do NOT cite, list, name, or refer to sources, pages, URLs, or titles. Never write citation markers like [1] or (source).
        - Do NOT repeat the same sentence or phrase. Each sentence must add new information.
        - If the sources do not answer the question, reply exactly: "I don't have that in your saved pages."
        - Bold **key terms** only when it adds clarity.\(highlightsGuideline)

        Sources:
        \(context)\(highlightsBlock)<|eot_id|>\(historyBlock)<|start_header_id|>user<|end_header_id|>
        \(query)<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>

        """
    }
}
