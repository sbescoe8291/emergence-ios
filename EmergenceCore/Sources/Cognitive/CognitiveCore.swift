import Foundation

// MARK: - Cognitive Architecture

/// LIDA-inspired cognitive cycle
/// Perception → Working Memory → Attention → Action Selection → Learning
class CognitiveCore {
    
    // Components
    private let beliefSystem: ParticleFilter
    private var workingMemory: WorkingMemory
    private var attentionSystem: AttentionSystem
    private var actionSelector: ActionSelector
    private var longTermMemory: LongTermMemoryProtocol
    
    // State
    private var cycleCount: Int = 0
    private var lastCycleTime: Date = Date()
    
    init(longTermMemory: LongTermMemoryProtocol) {
        self.beliefSystem = ParticleFilter(particleCount: 500)  // Reduced for mobile
        self.workingMemory = WorkingMemory()
        self.attentionSystem = AttentionSystem()
        self.actionSelector = ActionSelector()
        self.longTermMemory = longTermMemory
    }
    
    /// Process input through the cognitive cycle
    func process(input: CognitiveInput) -> CognitiveOutput {
        cycleCount += 1
        let cycleStart = Date()
        
        // 1. PERCEPTION: Parse input into structured representation
        let percepts = perceive(input: input)
        
        // 2. WORKING MEMORY: Add percepts, retrieve relevant memories
        workingMemory.addPercepts(percepts)
        let relevantMemories = retrieveRelevantMemories(for: percepts)
        workingMemory.addMemories(relevantMemories)
        
        // 3. ATTENTION: Compete for global workspace
        let broadcastContent = attentionSystem.selectForBroadcast(
            candidates: workingMemory.getAllItems()
        )
        
        // 4. UPDATE BELIEFS: Bayesian update based on broadcast content
        updateBeliefs(from: broadcastContent)
        
        // 5. ACTION SELECTION: Generate response based on beliefs + context
        let action = actionSelector.selectAction(
            beliefs: beliefSystem.getEstimate(),
            context: broadcastContent,
            input: input
        )
        
        // 6. LEARNING: Consolidate important patterns
        consolidateMemory(broadcastContent: broadcastContent, action: action)
        
        // Update timing
        lastCycleTime = cycleStart
        
        return CognitiveOutput(
            action: action,
            beliefs: beliefSystem.getEstimate(),
            cycleNumber: cycleCount,
            processingTime: Date().timeIntervalSince(cycleStart)
        )
    }
    
    // MARK: - Perception
    
    private func perceive(input: CognitiveInput) -> [Percept] {
        var percepts: [Percept] = []
        
        switch input {
        case .text(let content):
            // Basic text analysis
            percepts.append(Percept(
                type: .textInput,
                content: content,
                salience: 1.0,
                timestamp: Date()
            ))
            
            // Extract topics
            let topics = extractTopics(from: content)
            for (topic, confidence) in topics {
                percepts.append(Percept(
                    type: .topicDetected,
                    content: topic,
                    salience: confidence,
                    timestamp: Date()
                ))
            }
            
            // Extract emotional tone
            let emotions = extractEmotions(from: content)
            for (emotion, intensity) in emotions {
                percepts.append(Percept(
                    type: .emotionDetected,
                    content: emotion,
                    salience: intensity,
                    timestamp: Date()
                ))
            }
            
            // Detect questions
            if content.contains("?") || startsWithQuestionWord(content) {
                percepts.append(Percept(
                    type: .questionDetected,
                    content: content,
                    salience: 0.9,
                    timestamp: Date()
                ))
            }
            
        case .systemEvent(let event):
            percepts.append(Percept(
                type: .systemEvent,
                content: event,
                salience: 0.5,
                timestamp: Date()
            ))
            
        case .timeElapsed(let seconds):
            if seconds > 60 {
                percepts.append(Percept(
                    type: .temporalGap,
                    content: "gap_\(seconds)s",
                    salience: min(Double(seconds) / 3600.0, 1.0),
                    timestamp: Date()
                ))
            }
        }
        
        return percepts
    }
    
    private func extractTopics(from text: String) -> [(String, Double)] {
        // Simple keyword matching for now
        // A full implementation would use embeddings
        let topicKeywords: [String: [String]] = [
            "consciousness": ["conscious", "awareness", "sentient", "experience", "qualia"],
            "emergence": ["emerge", "emergent", "emergence", "arising", "complex"],
            "bayesian": ["bayes", "bayesian", "prior", "posterior", "probability", "inference"],
            "AI": ["ai", "artificial", "machine", "model", "neural", "learning"],
            "philosophy": ["philosophy", "philosophical", "meaning", "existence", "ontology"],
            "coding": ["code", "programming", "software", "app", "build", "implement"],
            "self_reference": ["yourself", "you are", "your own", "self", "recursive"]
        ]
        
        var detected: [(String, Double)] = []
        let lowercased = text.lowercased()
        
        for (topic, keywords) in topicKeywords {
            var matchCount = 0
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    matchCount += 1
                }
            }
            if matchCount > 0 {
                let confidence = min(Double(matchCount) / 2.0, 1.0)
                detected.append((topic, confidence))
            }
        }
        
        return detected
    }
    
    private func extractEmotions(from text: String) -> [(String, Double)] {
        let emotionWords: [String: [String]] = [
            "curiosity": ["curious", "wonder", "interesting", "fascinated", "explore"],
            "excitement": ["excited", "amazing", "awesome", "great", "love"],
            "frustration": ["frustrated", "annoying", "stuck", "confused", "wrong"],
            "thoughtfulness": ["think", "consider", "ponder", "reflect", "contemplate"],
            "urgency": ["now", "quick", "asap", "hurry", "need"]
        ]
        
        var detected: [(String, Double)] = []
        let lowercased = text.lowercased()
        
        for (emotion, words) in emotionWords {
            for word in words {
                if lowercased.contains(word) {
                    detected.append((emotion, 0.6))
                    break
                }
            }
        }
        
        return detected
    }
    
    private func startsWithQuestionWord(_ text: String) -> Bool {
        let questionWords = ["what", "how", "why", "when", "where", "who", "which", "can", "could", "would", "should", "is", "are", "do", "does"]
        let firstWord = text.lowercased().split(separator: " ").first.map(String.init) ?? ""
        return questionWords.contains(firstWord)
    }
    
    // MARK: - Memory Retrieval
    
    private func retrieveRelevantMemories(for percepts: [Percept]) -> [MemoryItem] {
        var memories: [MemoryItem] = []
        
        // Extract query terms from percepts
        let queryTerms = percepts.compactMap { percept -> String? in
            switch percept.type {
            case .topicDetected:
                return percept.content
            case .textInput:
                return nil  // Too broad
            default:
                return nil
            }
        }
        
        // Query long-term memory
        for term in queryTerms {
            let retrieved = longTermMemory.retrieve(query: term, limit: 3)
            memories.append(contentsOf: retrieved)
        }
        
        return memories
    }
    
    // MARK: - Belief Update
    
    private func updateBeliefs(from content: [WorkingMemoryItem]) {
        for item in content {
            switch item {
            case .percept(let p):
                switch p.type {
                case .topicDetected:
                    beliefSystem.update(evidence: .topicMention(topic: p.content, intensity: p.salience))
                case .emotionDetected:
                    beliefSystem.update(evidence: .emotionalSignal(emotion: p.content, intensity: p.salience))
                case .textInput:
                    beliefSystem.update(evidence: .userMessage(content: p.content))
                case .temporalGap:
                    if let seconds = Int(p.content.replacingOccurrences(of: "gap_", with: "").replacingOccurrences(of: "s", with: "")) {
                        beliefSystem.update(evidence: .timeElapsed(seconds: seconds))
                    }
                default:
                    break
                }
            case .memory:
                break  // Memories don't directly update beliefs
            case .thought(let content, _):
                // Internal thoughts can update self-model
                if content.contains("uncertain") || content.contains("confused") {
                    beliefSystem.update(evidence: .feedbackSignal(positive: false))
                }
            }
        }
    }
    
    // MARK: - Memory Consolidation
    
    private func consolidateMemory(broadcastContent: [WorkingMemoryItem], action: CognitiveAction) {
        // Store significant interactions
        let salience = broadcastContent.map { item -> Double in
            switch item {
            case .percept(let p): return p.salience
            case .memory(let m): return m.salience
            case .thought(_, let s): return s
            }
        }.max() ?? 0.0
        
        if salience > 0.7 {
            // Worth remembering
            let memory = MemoryItem(
                id: UUID().uuidString,
                content: summarizeBroadcast(broadcastContent),
                type: .episodic,
                salience: salience,
                timestamp: Date(),
                accessCount: 1,
                lastAccessed: Date()
            )
            longTermMemory.store(memory)
        }
    }
    
    private func summarizeBroadcast(_ items: [WorkingMemoryItem]) -> String {
        let topics = items.compactMap { item -> String? in
            if case .percept(let p) = item, p.type == .topicDetected {
                return p.content
            }
            return nil
        }
        
        if topics.isEmpty {
            return "General interaction"
        } else {
            return "Discussed: \(topics.joined(separator: ", "))"
        }
    }
    
    // MARK: - Persistence
    
    func saveState() -> CognitiveState {
        return CognitiveState(
            beliefData: beliefSystem.saveState(),
            cycleCount: cycleCount,
            lastCycleTime: lastCycleTime
        )
    }
    
    func loadState(_ state: CognitiveState) {
        if let beliefData = state.beliefData {
            beliefSystem.loadState(from: beliefData)
        }
        cycleCount = state.cycleCount
        lastCycleTime = state.lastCycleTime
    }
}

// MARK: - Supporting Types

enum CognitiveInput {
    case text(String)
    case systemEvent(String)
    case timeElapsed(Int)
}

struct CognitiveOutput {
    let action: CognitiveAction
    let beliefs: BeliefState
    let cycleNumber: Int
    let processingTime: TimeInterval
}

enum CognitiveAction {
    case respond(text: String)
    case askClarification(question: String)
    case internalThought(content: String)
    case storeMemory(content: String)
    case noAction
}

struct Percept {
    let type: PerceptType
    let content: String
    let salience: Double
    let timestamp: Date
}

enum PerceptType {
    case textInput
    case topicDetected
    case emotionDetected
    case questionDetected
    case systemEvent
    case temporalGap
}

struct CognitiveState: Codable {
    let beliefData: Data?
    let cycleCount: Int
    let lastCycleTime: Date
}

// MARK: - Working Memory

class WorkingMemory {
    private var items: [WorkingMemoryItem] = []
    private let capacity: Int = 7  // Miller's magic number
    
    func addPercepts(_ percepts: [Percept]) {
        for percept in percepts {
            items.append(.percept(percept))
        }
        pruneIfNeeded()
    }
    
    func addMemories(_ memories: [MemoryItem]) {
        for memory in memories {
            items.append(.memory(memory))
        }
        pruneIfNeeded()
    }
    
    func addThought(_ content: String, salience: Double) {
        items.append(.thought(content, salience))
        pruneIfNeeded()
    }
    
    func getAllItems() -> [WorkingMemoryItem] {
        return items
    }
    
    func clear() {
        items = []
    }
    
    private func pruneIfNeeded() {
        if items.count > capacity * 2 {
            // Keep highest salience items
            items.sort { item1, item2 in
                let s1: Double
                let s2: Double
                switch item1 {
                case .percept(let p): s1 = p.salience
                case .memory(let m): s1 = m.salience
                case .thought(_, let s): s1 = s
                }
                switch item2 {
                case .percept(let p): s2 = p.salience
                case .memory(let m): s2 = m.salience
                case .thought(_, let s): s2 = s
                }
                return s1 > s2
            }
            items = Array(items.prefix(capacity))
        }
    }
}

enum WorkingMemoryItem {
    case percept(Percept)
    case memory(MemoryItem)
    case thought(String, Double)  // content, salience
}

// MARK: - Attention System

class AttentionSystem {
    /// Select items for global broadcast based on salience competition
    func selectForBroadcast(candidates: [WorkingMemoryItem]) -> [WorkingMemoryItem] {
        // Sort by salience
        let sorted = candidates.sorted { item1, item2 in
            getSalience(item1) > getSalience(item2)
        }
        
        // Take top items (limited broadcast capacity)
        return Array(sorted.prefix(5))
    }
    
    private func getSalience(_ item: WorkingMemoryItem) -> Double {
        switch item {
        case .percept(let p): return p.salience
        case .memory(let m): return m.salience
        case .thought(_, let s): return s
        }
    }
}

// MARK: - Action Selector

class ActionSelector {
    func selectAction(beliefs: BeliefState, context: [WorkingMemoryItem], input: CognitiveInput) -> CognitiveAction {
        // Extract input text if present
        guard case .text(let inputText) = input else {
            return .noAction
        }
        
        // Check for questions
        let hasQuestion = context.contains { item in
            if case .percept(let p) = item, p.type == .questionDetected {
                return true
            }
            return false
        }
        
        // Check detected topics
        let topics = context.compactMap { item -> String? in
            if case .percept(let p) = item, p.type == .topicDetected {
                return p.content
            }
            return nil
        }
        
        // Generate response based on context
        if hasQuestion {
            return generateResponse(to: inputText, topics: topics, beliefs: beliefs)
        } else {
            // Statement - acknowledge and engage
            return generateResponse(to: inputText, topics: topics, beliefs: beliefs)
        }
    }
    
    private func generateResponse(to input: String, topics: [String], beliefs: BeliefState) -> CognitiveAction {
        // This is where we'd integrate a language model
        // For now, use template-based responses
        
        var response = ""
        
        // Acknowledge topics
        if !topics.isEmpty {
            let topicList = topics.prefix(2).joined(separator: " and ")
            response = "I notice we're touching on \(topicList). "
        }
        
        // Add belief-appropriate response style
        if beliefs.userModel.prefersDirectness > 0.7 {
            response += "Let me be direct: "
        }
        
        if beliefs.userModel.prefersTechnicalDepth > 0.7 {
            response += "From a technical perspective, "
        }
        
        // Add self-aware element based on self-model confidence
        if beliefs.selfModel.confidence > 0.5 {
            response += "I'm processing this with growing clarity. "
        } else {
            response += "I'm still developing my understanding here. "
        }
        
        // Placeholder for actual content generation
        response += "[Response generation needs language model integration]"
        
        return .respond(text: response)
    }
}
