import XCTest
@testable import EmergenceCore

final class EmergenceTests: XCTestCase {
    
    func testBeliefStateInitialization() {
        let state = BeliefState()
        
        XCTAssertGreaterThan(state.selfModel.traits.count, 0)
        XCTAssertGreaterThan(state.selfModel.values.count, 0)
        XCTAssertLessThanOrEqual(state.selfModel.confidence, 1.0)
        XCTAssertGreaterThanOrEqual(state.selfModel.confidence, 0.0)
    }
    
    func testParticleFilterInitialization() {
        let filter = ParticleFilter(particleCount: 100)
        let estimate = filter.getEstimate()
        
        XCTAssertNotNil(estimate)
        XCTAssertGreaterThan(estimate.selfModel.traits.count, 0)
    }
    
    func testParticleFilterUpdate() {
        let filter = ParticleFilter(particleCount: 100)
        
        // Initial estimate
        let before = filter.getEstimate()
        
        // Update with evidence
        filter.update(evidence: .userMessage(content: "I'm interested in consciousness and emergence"))
        filter.update(evidence: .topicMention(topic: "consciousness", intensity: 0.9))
        
        let after = filter.getEstimate()
        
        // Beliefs should have changed
        // (In a full implementation, we'd check specific belief changes)
        XCTAssertNotNil(after)
    }
    
    func testUserModelShaneInitialization() {
        var userModel = UserModel()
        userModel.initializeForShane()
        
        XCTAssertEqual(userModel.name, "Shane")
        XCTAssertEqual(userModel.nameConfidence, 1.0)
        XCTAssertGreaterThan(userModel.interests["consciousness"] ?? 0, 0.9)
        XCTAssertGreaterThan(userModel.prefersDirectness, 0.8)
    }
    
    func testMemoryStoreBasicOperations() {
        let store = SQLiteMemoryStore(dbName: "test_memory.sqlite")
        
        // Store a memory
        let memory = MemoryItem(
            id: "test_1",
            content: "This is a test memory about consciousness",
            type: .semantic,
            salience: 0.8,
            timestamp: Date(),
            accessCount: 1,
            lastAccessed: Date()
        )
        
        store.store(memory)
        
        // Retrieve by query
        let results = store.retrieve(query: "consciousness", limit: 5)
        
        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.contains(where: { $0.id == "test_1" }))
        
        // Clean up
        store.delete(id: "test_1")
    }
    
    func testCognitiveInputProcessing() {
        let store = SQLiteMemoryStore(dbName: "test_cognitive.sqlite")
        let core = CognitiveCore(longTermMemory: store)
        
        let output = core.process(input: .text("What do you think about emergence?"))
        
        XCTAssertGreaterThan(output.cycleNumber, 0)
        XCTAssertNotNil(output.beliefs)
        
        // Should detect the topic
        switch output.action {
        case .respond(let text):
            XCTAssertFalse(text.isEmpty)
        default:
            XCTFail("Expected respond action")
        }
    }
    
    func testEmergenceEndToEnd() {
        var config = Emergence.Config()
        config.enableDebugOutput = false
        
        let emergence = Emergence(config: config)
        
        // First message
        let response1 = emergence.chat("Hello, I'm interested in consciousness research")
        XCTAssertFalse(response1.text.isEmpty)
        
        // Second message - should show context awareness
        let response2 = emergence.chat("What do you think about emergence?")
        XCTAssertFalse(response2.text.isEmpty)
        
        // Save and end
        emergence.endSession(summary: "Test session")
    }
    
    func testStatePersistence() {
        // Create and use emergence
        var config = Emergence.Config()
        config.enableDebugOutput = false
        
        let emergence1 = Emergence(config: config)
        _ = emergence1.chat("Remember this: the test value is 42")
        emergence1.saveState()
        
        // Create new instance - should load state
        let emergence2 = Emergence(config: config)
        let beliefs = emergence2.getBeliefs()
        
        // Session count should have persisted
        XCTAssertGreaterThan(beliefs.selfModel.sessionCount, 0)
    }
}
