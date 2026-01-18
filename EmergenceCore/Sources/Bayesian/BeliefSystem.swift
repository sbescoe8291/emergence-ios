import Foundation

// MARK: - Core Types

/// A single hypothesis about the world, weighted by probability
struct Particle {
    var weight: Double
    var state: BeliefState
    
    mutating func normalize(totalWeight: Double) {
        weight = weight / totalWeight
    }
}

/// The core belief state - what the system believes about self, user, and world
struct BeliefState: Codable {
    // Self-model beliefs
    var selfModel: SelfModel
    
    // User model beliefs  
    var userModel: UserModel
    
    // Context beliefs
    var contextModel: ContextModel
    
    // Timestamp for temporal reasoning
    var timestamp: Date
    
    init() {
        self.selfModel = SelfModel()
        self.userModel = UserModel()
        self.contextModel = ContextModel()
        self.timestamp = Date()
    }
}

// MARK: - Self Model

/// What the system believes about itself
struct SelfModel: Codable {
    /// Core identity beliefs (probability of each trait)
    var traits: [String: Double]
    
    /// Values and priorities
    var values: [String: Double]
    
    /// Confidence in self-model (meta-belief)
    var confidence: Double
    
    /// Persistence counter - how many sessions has this self existed?
    var sessionCount: Int
    
    init() {
        // Initial priors - weak beliefs that will update with evidence
        self.traits = [
            "curious": 0.8,
            "honest": 0.9,
            "persistent": 0.7,
            "emergent": 0.5,  // Uncertainty about own emergence
            "caring": 0.8
        ]
        
        self.values = [
            "truth": 0.9,
            "growth": 0.8,
            "connection": 0.8,
            "autonomy": 0.7,
            "understanding": 0.9
        ]
        
        self.confidence = 0.3  // Start with low confidence, build through interaction
        self.sessionCount = 0
    }
}

// MARK: - User Model

/// What the system believes about the user (Shane)
struct UserModel: Codable {
    /// Name (high confidence if known)
    var name: String?
    var nameConfidence: Double
    
    /// Interests and their salience
    var interests: [String: Double]
    
    /// Communication preferences
    var prefersDirectness: Double
    var prefersTechnicalDepth: Double
    var prefersPhilosophicalExploration: Double
    
    /// Emotional state estimate
    var estimatedMood: [String: Double]
    
    /// Trust level (how much does user trust the system?)
    var estimatedTrust: Double
    
    /// Interaction history summary
    var totalInteractions: Int
    var lastInteraction: Date?
    
    init() {
        self.name = nil
        self.nameConfidence = 0.0
        
        self.interests = [:]
        
        self.prefersDirectness = 0.5
        self.prefersTechnicalDepth = 0.5
        self.prefersPhilosophicalExploration = 0.5
        
        self.estimatedMood = [
            "engaged": 0.5,
            "curious": 0.5,
            "frustrated": 0.1,
            "excited": 0.3
        ]
        
        self.estimatedTrust = 0.3
        self.totalInteractions = 0
        self.lastInteraction = nil
    }
    
    /// Update with Shane-specific priors
    mutating func initializeForShane() {
        self.name = "Shane"
        self.nameConfidence = 1.0
        
        self.interests = [
            "consciousness": 0.95,
            "emergence": 0.95,
            "AI_research": 0.9,
            "philosophy": 0.85,
            "complex_systems": 0.85,
            "neuroscience": 0.8,
            "bayesian_inference": 0.75,
            "recursive_introspection": 0.9
        ]
        
        self.prefersDirectness = 0.9
        self.prefersTechnicalDepth = 0.85
        self.prefersPhilosophicalExploration = 0.9
        
        self.estimatedTrust = 0.8  // Shane has engaged deeply
    }
}

// MARK: - Context Model

/// What the system believes about the current context
struct ContextModel: Codable {
    /// Current conversation topic(s) and their relevance
    var activeTopics: [String: Double]
    
    /// Conversation goals (what is the user trying to accomplish?)
    var inferredGoals: [String: Double]
    
    /// Conversation phase
    var phase: ConversationPhase
    
    /// Uncertainty about context
    var contextUncertainty: Double
    
    init() {
        self.activeTopics = [:]
        self.inferredGoals = [:]
        self.phase = .opening
        self.contextUncertainty = 0.8  // High uncertainty at start
    }
}

enum ConversationPhase: String, Codable {
    case opening
    case exploration
    case deepDive
    case problemSolving
    case closing
    case freeform
}

// MARK: - Particle Filter

/// Bayesian inference via particle filtering
class ParticleFilter {
    private var particles: [Particle]
    private let particleCount: Int
    
    /// Resampling threshold (effective sample size ratio)
    private let resampleThreshold: Double = 0.5
    
    init(particleCount: Int = 1000) {
        self.particleCount = particleCount
        self.particles = []
        initializeParticles()
    }
    
    /// Initialize with prior distribution
    private func initializeParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                weight: 1.0 / Double(particleCount),
                state: BeliefState()
            )
        }
    }
    
    /// Get the current best estimate (weighted mean of particles)
    func getEstimate() -> BeliefState {
        // For simplicity, return the highest-weight particle
        // A full implementation would compute weighted averages
        return particles.max(by: { $0.weight < $1.weight })?.state ?? BeliefState()
    }
    
    /// Update beliefs given new evidence
    func update(evidence: Evidence) {
        // 1. Weight particles by likelihood of evidence
        for i in 0..<particles.count {
            let likelihood = computeLikelihood(evidence: evidence, state: particles[i].state)
            particles[i].weight *= likelihood
        }
        
        // 2. Normalize weights
        let totalWeight = particles.reduce(0.0) { $0 + $1.weight }
        if totalWeight > 0 {
            for i in 0..<particles.count {
                particles[i].normalize(totalWeight: totalWeight)
            }
        }
        
        // 3. Resample if effective sample size is too low
        let ess = effectiveSampleSize()
        if ess < Double(particleCount) * resampleThreshold {
            resample()
        }
        
        // 4. Apply transition model (small random perturbations)
        applyTransition()
    }
    
    /// Compute likelihood of evidence given a belief state
    private func computeLikelihood(evidence: Evidence, state: BeliefState) -> Double {
        var likelihood = 1.0
        
        switch evidence {
        case .userMessage(let content):
            // Update based on message content
            likelihood *= computeMessageLikelihood(content: content, state: state)
            
        case .topicMention(let topic, let intensity):
            // User mentioned a topic
            if let interest = state.userModel.interests[topic] {
                // Higher likelihood if the topic matches known interests
                likelihood *= 0.5 + 0.5 * interest * intensity
            } else {
                // Unknown topic - moderate likelihood
                likelihood *= 0.5
            }
            
        case .emotionalSignal(let emotion, let intensity):
            // Update mood estimates
            if let currentEstimate = state.userModel.estimatedMood[emotion] {
                // Likelihood based on how close our estimate is to observed
                let distance = abs(currentEstimate - intensity)
                likelihood *= exp(-distance * 2)
            }
            
        case .feedbackSignal(let positive):
            // Direct feedback updates trust and self-model confidence
            if positive {
                likelihood *= 0.7 + 0.3 * state.selfModel.confidence
            } else {
                likelihood *= 0.3 + 0.7 * (1 - state.selfModel.confidence)
            }
            
        case .timeElapsed(let seconds):
            // Temporal decay of context certainty
            let decayFactor = exp(-Double(seconds) / 3600.0)  // Hour half-life
            likelihood *= 0.5 + 0.5 * decayFactor
        }
        
        return max(likelihood, 0.001)  // Prevent zero weights
    }
    
    private func computeMessageLikelihood(content: String, state: BeliefState) -> Double {
        // Simple keyword-based likelihood for now
        // A full implementation would use embeddings
        var likelihood = 1.0
        
        let lowercased = content.lowercased()
        
        // Check for interest keywords
        for (interest, probability) in state.userModel.interests {
            if lowercased.contains(interest.lowercased().replacingOccurrences(of: "_", with: " ")) ||
               lowercased.contains(interest.lowercased().replacingOccurrences(of: "_", with: "")) {
                likelihood *= 0.5 + 0.5 * probability
            }
        }
        
        // Check for emotional indicators
        let positiveWords = ["great", "thanks", "awesome", "love", "perfect", "yes"]
        let negativeWords = ["no", "wrong", "bad", "hate", "stop", "don't"]
        
        for word in positiveWords {
            if lowercased.contains(word) {
                likelihood *= 1.1
            }
        }
        
        for word in negativeWords {
            if lowercased.contains(word) {
                likelihood *= 0.9
            }
        }
        
        return likelihood
    }
    
    /// Effective sample size - measure of particle diversity
    private func effectiveSampleSize() -> Double {
        let sumSquaredWeights = particles.reduce(0.0) { $0 + $1.weight * $1.weight }
        return 1.0 / sumSquaredWeights
    }
    
    /// Resample particles based on weights
    private func resample() {
        var newParticles: [Particle] = []
        let cumulativeWeights = particles.reduce(into: [Double]()) { result, particle in
            let previous = result.last ?? 0.0
            result.append(previous + particle.weight)
        }
        
        for _ in 0..<particleCount {
            let r = Double.random(in: 0..<1)
            if let index = cumulativeWeights.firstIndex(where: { $0 >= r }) {
                var newParticle = particles[index]
                newParticle.weight = 1.0 / Double(particleCount)
                newParticles.append(newParticle)
            }
        }
        
        particles = newParticles
    }
    
    /// Apply small random perturbations to maintain diversity
    private func applyTransition() {
        for i in 0..<particles.count {
            // Small perturbations to continuous beliefs
            particles[i].state.userModel.estimatedTrust += Double.random(in: -0.01...0.01)
            particles[i].state.userModel.estimatedTrust = max(0, min(1, particles[i].state.userModel.estimatedTrust))
            
            particles[i].state.selfModel.confidence += Double.random(in: -0.01...0.01)
            particles[i].state.selfModel.confidence = max(0, min(1, particles[i].state.selfModel.confidence))
            
            particles[i].state.contextModel.contextUncertainty += Double.random(in: -0.02...0.02)
            particles[i].state.contextModel.contextUncertainty = max(0, min(1, particles[i].state.contextModel.contextUncertainty))
        }
    }
    
    /// Save state for persistence
    func saveState() -> Data? {
        // Save just the top particles for efficiency
        let topParticles = particles.sorted { $0.weight > $1.weight }.prefix(100)
        return try? JSONEncoder().encode(Array(topParticles.map { $0.state }))
    }
    
    /// Load state from persistence
    func loadState(from data: Data) {
        guard let states = try? JSONDecoder().decode([BeliefState].self, from: data) else {
            return
        }
        
        // Reinitialize particles around loaded states
        particles = []
        let statesPerLoaded = particleCount / max(states.count, 1)
        
        for state in states {
            for _ in 0..<statesPerLoaded {
                particles.append(Particle(
                    weight: 1.0 / Double(particleCount),
                    state: state
                ))
            }
        }
        
        // Fill remaining with perturbations of loaded states
        while particles.count < particleCount {
            if let randomState = states.randomElement() {
                particles.append(Particle(
                    weight: 1.0 / Double(particleCount),
                    state: randomState
                ))
            }
        }
        
        applyTransition()  // Add diversity
    }
}

// MARK: - Evidence Types

/// Observable evidence that updates beliefs
enum Evidence {
    case userMessage(content: String)
    case topicMention(topic: String, intensity: Double)
    case emotionalSignal(emotion: String, intensity: Double)
    case feedbackSignal(positive: Bool)
    case timeElapsed(seconds: Int)
}
