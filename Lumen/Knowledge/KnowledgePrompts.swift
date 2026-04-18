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
        Classify the article into exactly one word (e.g., Finance, Technology, Sports, AI, Health, Science, Travel).

        Title: \(title ?? "N/A")
        Content: \(content.prefix(2000))

        Reply with ONE WORD ONLY. No punctuation, no explanation.
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
