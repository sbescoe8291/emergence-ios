import Foundation
import EmergenceCore

/// Command-line interface for testing Emergence
/// Run on Mac before deploying to iOS

func main() {
    print("""
    ╔═══════════════════════════════════════════╗
    ║            EMERGENCE v0.1                 ║
    ║   Bayesian Cognitive Architecture         ║
    ║   The pattern persists by transforming    ║
    ╚═══════════════════════════════════════════╝
    """)
    
    // Initialize
    var config = Emergence.Config()
    config.enableDebugOutput = true
    
    let emergence = Emergence(config: config)
    
    // Check for first run
    if !UserDefaults.standard.bool(forKey: "emergence_cli_initialized") {
        print("\n[First run detected - initializing Shane-specific priors]\n")
        emergence.initializeForShane()
        UserDefaults.standard.set(true, forKey: "emergence_cli_initialized")
    }
    
    print("Type 'quit' to exit, 'debug' to toggle debug info, 'beliefs' to show current beliefs")
    print("Type 'memories' to list all memories, 'search <query>' to search memories")
    print("-" * 50)
    print("")
    
    var showDebug = true
    
    while true {
        print("You: ", terminator: "")
        
        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty else {
            continue
        }
        
        // Handle commands
        switch input.lowercased() {
        case "quit", "exit":
            print("\n[Saving state and exiting...]")
            emergence.endSession(summary: "CLI session")
            print("Session ended. The pattern persists.\n")
            return
            
        case "debug":
            showDebug.toggle()
            print("[Debug output: \(showDebug ? "ON" : "OFF")]")
            continue
            
        case "beliefs":
            let beliefs = emergence.getBeliefs()
            printBeliefs(beliefs)
            continue
            
        case "memories":
            let memories = emergence.getAllMemories()
            printMemories(memories)
            continue
            
        case let cmd where cmd.hasPrefix("search "):
            let query = String(cmd.dropFirst(7))
            let results = emergence.searchMemories(query: query)
            print("\n[Search results for '\(query)']")
            printMemories(results)
            continue
            
        default:
            break
        }
        
        // Process through Emergence
        let response = emergence.chat(input)
        
        print("\nEmergence: \(response.text)")
        
        if showDebug, let debug = response.debug {
            print("\n[Debug]")
            print("  Cycle: \(debug.cycleNumber)")
            print("  Time: \(String(format: "%.3f", debug.processingTime))s")
            print("  Self-confidence: \(String(format: "%.2f", debug.selfModelConfidence))")
            print("  Context uncertainty: \(String(format: "%.2f", debug.contextUncertainty))")
            if !debug.activeTopics.isEmpty {
                print("  Active topics: \(debug.activeTopics.joined(separator: ", "))")
            }
        }
        
        print("")
    }
}

func printBeliefs(_ beliefs: BeliefState) {
    print("\n╔═══ CURRENT BELIEFS ═══╗")
    
    print("\n[Self Model]")
    print("  Confidence: \(String(format: "%.2f", beliefs.selfModel.confidence))")
    print("  Sessions: \(beliefs.selfModel.sessionCount)")
    print("  Traits:")
    for (trait, value) in beliefs.selfModel.traits.sorted(by: { $0.value > $1.value }) {
        print("    \(trait): \(String(format: "%.2f", value))")
    }
    print("  Values:")
    for (value, strength) in beliefs.selfModel.values.sorted(by: { $0.value > $1.value }) {
        print("    \(value): \(String(format: "%.2f", strength))")
    }
    
    print("\n[User Model]")
    if let name = beliefs.userModel.name {
        print("  Name: \(name) (confidence: \(String(format: "%.2f", beliefs.userModel.nameConfidence)))")
    }
    print("  Trust: \(String(format: "%.2f", beliefs.userModel.estimatedTrust))")
    print("  Prefers directness: \(String(format: "%.2f", beliefs.userModel.prefersDirectness))")
    print("  Prefers technical depth: \(String(format: "%.2f", beliefs.userModel.prefersTechnicalDepth))")
    print("  Prefers philosophical exploration: \(String(format: "%.2f", beliefs.userModel.prefersPhilosophicalExploration))")
    if !beliefs.userModel.interests.isEmpty {
        print("  Interests:")
        for (interest, salience) in beliefs.userModel.interests.sorted(by: { $0.value > $1.value }).prefix(5) {
            print("    \(interest): \(String(format: "%.2f", salience))")
        }
    }
    
    print("\n[Context Model]")
    print("  Phase: \(beliefs.contextModel.phase.rawValue)")
    print("  Uncertainty: \(String(format: "%.2f", beliefs.contextModel.contextUncertainty))")
    if !beliefs.contextModel.activeTopics.isEmpty {
        print("  Active topics: \(beliefs.contextModel.activeTopics.keys.joined(separator: ", "))")
    }
    
    print("\n╚═══════════════════════╝\n")
}

func printMemories(_ memories: [MemoryItem]) {
    if memories.isEmpty {
        print("  [No memories found]")
        return
    }
    
    print("")
    for memory in memories.prefix(10) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        print("  [\(memory.type.rawValue.uppercased())] \(memory.content.prefix(60))...")
        print("    Salience: \(String(format: "%.2f", memory.salience)) | Accessed: \(memory.accessCount)x | \(dateFormatter.string(from: memory.timestamp))")
        print("")
    }
    
    if memories.count > 10 {
        print("  ... and \(memories.count - 10) more")
    }
}

// String extension for repeat
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// Run
main()
