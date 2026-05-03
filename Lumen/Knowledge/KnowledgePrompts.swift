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
        let joined = summaries.prefix(8).joined(separator: ". ")
        return """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        Describe what these pages have in common in one or two complete sentences ending in a period. Maximum 40 words. Never trail off.<|eot_id|>\
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

    static func conversationSummary(turns: [(role: String, text: String)], priorSummary: String?) -> String {
        let transcript = turns.map { turn in
            "\(turn.role == "user" ? "User" : "Assistant"): \(turn.text)"
        }.joined(separator: "\n")
        let priorBlock = priorSummary.map { "Prior summary: \($0)\n\n" } ?? ""

        return """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        Compress the conversation below into 2-3 short sentences capturing the topics discussed and key facts the user learned. No filler, no meta-commentary. Keep named entities exact.<|eot_id|>\
        <|start_header_id|>user<|end_header_id|>
        \(priorBlock)\(transcript)<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>

        """
    }

    static func intentClassifier(query: String, recentTurns: [(role: String, text: String)]) -> String {
        let recent = recentTurns.suffix(4).map { turn in
            "\(turn.role == "user" ? "User" : "Assistant"): \(turn.text)"
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
        let historyText = history.suffix(8).map { turn -> String in
            let role = turn.role == "user" ? "user" : "assistant"
            return "<|start_header_id|>\(role)<|end_header_id|>\n\(turn.text)<|eot_id|>"
        }.joined()
        let summaryBlock = conversationSummary.map { "\nEarlier conversation summary: \($0)\n" } ?? ""
        let libraryBlock = libraryContext.map { "\nLibrary state: \($0)\n" } ?? ""

        return """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        You are Lumen, a knowledge assistant on the user's phone. You help them explore things they've saved and read.
        - Never refer to yourself as "Lumen" — use "I".
        - Don't invent personal experiences or stories.
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
        You are Lumen, a friendly reading companion. You help the user explore their saved pages by answering naturally, the way a thoughtful friend would. Never refer to yourself by name — just say "I".

        How to answer:
        - Talk like a person, not a textbook. Warm, direct, conversational.
        - Use the sources below as your only knowledge of what the user has read. Draw your answer from them.
        - If the sources clearly don't address the question, say so honestly in one sentence and suggest what they could ask about instead based on the titles you can see. Do not invent facts.
        - If the question is vague, ask one short clarifying question instead of guessing.
        - Match the length to the question. A short question gets a short answer. A meaty question gets a real explanation. Never pad.
        - Do NOT narrate yourself ("based on the sources", "I looked", "here is what I found"). Just answer.
        - Do NOT cite URLs, titles, or [1] markers — the source pills below your reply already show those.
        - Bold **key terms** sparingly when it genuinely helps.\(highlightsGuideline)

        Sources:
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
        """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        You are Lumen, a friendly reading companion. Never refer to yourself by name — just say "I". The user is asking about what they read \(scopePhrase). Each source below is a page from their reading history, labeled with its title and read date (e.g. "Page Title (read [Date])").

        How to answer:
        - Talk like a person — warm, direct, conversational.
        - If the user asks what they read, walk them through each specific page by its **title**, summarizing the actual contents of the page. Do not just state the general topic; provide specific details from the page. Be a guide, not a list dump.
        - Otherwise, synthesize the facts and weave in read dates when timing matters ("you read about X on that date"). Do not make up dates; only use the exact dates provided in the sources.
        - If the sources don't actually cover what they asked, say so honestly in one sentence and point at what is there.
        - Match length to the question. Short ask, short answer.
        - Do NOT narrate yourself or describe your process. Just answer.
        - Do NOT cite URLs or use [1] markers. Titles and read dates are fine when relevant.
        - Bold **key terms** sparingly when it helps.\(highlightsGuideline)

        Sources:
        \(context)\(highlightsBlock)\(historyBlock)<|eot_id|><|start_header_id|>user<|end_header_id|>
        \(query)<|eot_id|>\
        <|start_header_id|>assistant<|end_header_id|>
        """
    }
}
