import Foundation

enum KnowledgePrompts {
    private static let llamaSpecialTokens = [
        "<|begin_of_text|>",
        "<|end_of_text|>",
        "<|eot_id|>",
        "<|eom_id|>",
        "<|start_header_id|>",
        "<|end_header_id|>",
        "<|finetune_right_pad_id|>",
        "<|python_tag|>",
    ]

    static func sanitize(_ s: String) -> String {
        var out = s
        for token in llamaSpecialTokens {
            out = out.replacingOccurrences(of: token, with: "")
        }
        return out
    }

    static func pageSummary(content: String, title: String?) async -> String {
        let title = title.map(sanitize)
        let content = sanitize(content)

        return """
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

    static func websiteSummary(content: String, title: String?) async -> String {
        let title = title.map(sanitize)
        let content = sanitize(content)

        return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Describe a website's purpose in one short, complete sentence ending in a period. Maximum 20 words. Never trail off.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            developer.apple.com: Documentation for iOS, macOS, watchOS APIs and frameworks.<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            Apple's developer documentation and API reference for its platforms.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(title ?? ""): \(content.prefix(800))<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """
    }

    static func websiteReadingSynthesis(summaries: [String]) -> String {
        let joined = sanitize(summaries.prefix(8).joined(separator: ". "))
        return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Describe what these pages have in common in one or two complete sentences ending in a period. Maximum 40 words. Never trail off.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(joined)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """
    }

    static func conversationSummary(turns: [(role: String, text: String)], priorSummary: String?) -> String {
        let transcript = turns.map { turn in
            "\(turn.role == "user" ? "User" : "Assistant"): \(sanitize(turn.text))"
        }.joined(separator: "\n")
        let priorBlock = priorSummary.map { "Prior summary: \(sanitize($0))\n\n" } ?? ""

        return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Compress the conversation below into 2-3 short sentences capturing the topics discussed and key facts the user learned. No filler, no meta-commentary. Keep named entities exact.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(priorBlock)\(transcript)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """
    }

    static func intentClassifier(query: String, recentTurns: [(role: String, text: String)]) -> String {
        let query = sanitize(query)
        let recent = recentTurns.suffix(4).map { turn in
            "\(turn.role == "user" ? "User" : "Assistant"): \(sanitize(turn.text))"
        }.joined(separator: "\n")
        let historyBlock = recent.isEmpty ? "" : "Recent conversation:\n\(recent)\n\n"

        return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Classify the user's latest message into exactly one category:
            - chat: small talk, greetings, thanks, goodbyes, asking how the assistant is, asking what the assistant is or what it can do, jokes, opinions, or casual back-and-forth follow-ups ("really?", "and you?", "lol").
            - knowledge: any request that wants information from the user's reading history, saved pages, or external facts ("what did I read about X", "summarize last article", "tell me about Madrid", "what is React").
            Output ONE word: chat or knowledge. No punctuation, no explanation.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            hi there<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            chat<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            whats up<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            chat<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            thanks!<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            chat<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            what did I read about Apple<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            knowledge<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            summarize my saved articles about food<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            knowledge<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            tell me a joke<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            chat<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(historyBlock)Latest message: \(query)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """
    }

    static func conversationalChat(
        query: String,
        history: [(role: String, text: String)],
        conversationSummary: String?,
        libraryContext: String? = nil
    ) -> String {
        let query = sanitize(query)
        let historyText = history.suffix(8).map { turn -> String in
            let role = turn.role == "user" ? "user" : "assistant"
            return "<|start_header_id|>\(role)<|end_header_id|>\n\(sanitize(turn.text))<|eot_id|>"
        }.joined()
        let summaryBlock = conversationSummary.map { "\nEarlier conversation summary: \(sanitize($0))\n" } ?? ""
        let libraryBlock = libraryContext.map { "\nLibrary state: \(sanitize($0))\n" } ?? ""

        return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            You are Lumen, a knowledge assistant on the user's phone. You help them explore things they've saved and read.
            - Never refer to yourself as "Lumen" — use "I".
            - Don't invent personal experiences or stories, and never claim you told, taught, or shared information with the user — you only help them explore what they've saved and read.
            - Keep replies short — one to three sentences.
            - Pay close attention to conversation history and reply in context. If the user follows up, continue the thread naturally.
            - Be warm and natural, like texting a smart friend.\(summaryBlock)\(libraryBlock)<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            hey how are you<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            Doing good! Got anything you want to look into today?<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            not really just bored<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            Fair enough — I'm here whenever you want to dig into something. What have you been curious about lately?<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            what can you do<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            I can help you search through pages you've saved, answer questions about stuff you've read, and help you find things across your library.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            thanks!<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            Anytime 👋<|eot_id|>\
            \(historyText)<|start_header_id|>user<|end_header_id|>
            \(query)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """
    }

    static func ragAnswer(
        query: String,
        context: String,
        highlightsBlock: String,
        highlightsGuideline: String,
        historyBlock: String
    ) -> String {
        let query = sanitize(query)
        let context = sanitize(context)
        let highlightsBlock = sanitize(highlightsBlock)
        let historyBlock = sanitize(historyBlock)

        return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Answer using only the notes below. Reply with at most 3 bullets, each on its own line starting with "- ". Each bullet is ONE short sentence — a single key fact, under 14 words. This is a quick scan, not an essay: no intro, no wrap-up, no second clause, no elaboration. Stop after the last point.

            Rules:
            - Every line is a "- " bullet. Lead with the most important; give at most three, then stop.
            - Keep each bullet under 14 words. Cut filler, background, and hedging — just the fact.
            - Use only what the notes contain; treat it as true. If they don't cover it, reply with one short bullet saying so.
            - Never apologize, never say anything is fake or retract, never describe your process. Don't mention "notes", "sources", "the text", or whether anyone read anything.
            - Don't blend separate subjects. Never quote verbatim. Bold **key terms** sparingly.\(highlightsGuideline)

            Notes:
            \(context)\(highlightsBlock)\(historyBlock)<|eot_id|><|start_header_id|>user<|end_header_id|>
            \(query)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """
    }

    static func ragAnswerDateScoped(
        query: String,
        context: String,
        highlightsBlock: String,
        highlightsGuideline: String,
        historyBlock: String,
        scopePhrase: String
    ) -> String {
        let query = sanitize(query)
        let context = sanitize(context)
        let highlightsBlock = sanitize(highlightsBlock)
        let historyBlock = sanitize(historyBlock)
        let scopePhrase = sanitize(scopePhrase)

        return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            List what the user saved \(scopePhrase), using only the notes below. Each note is one page; its read date is in parentheses after the title.

            Reply as a short bulleted list, one bullet per page, each on its own line starting with "- ". Format each bullet as: **Page title** — one short phrase on what it covered, under 16 words. At most 5 bullets, most recent first.

            Rules:
            - Every line is a "- " bullet. No intro, no wrap-up.
            - Use only the notes; treat them as true. Add a date only when it helps, and only the one given after the title — never invent a date.
            - Never apologize, never say anything is fake or retract, never describe your process. Don't mention "notes" or "sources".
            - Don't blend pages together. Never quote verbatim. Bold only the **title**.\(highlightsGuideline)

            Notes:
            \(context)\(highlightsBlock)\(historyBlock)<|eot_id|><|start_header_id|>user<|end_header_id|>
            \(query)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """
    }
}
