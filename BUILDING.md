# Building Emergence

## Quick Start (Mac CLI)

Test the core system on your Mac before deploying to iOS:

```bash
cd emergence-ios
swift build
swift run EmergenceCLI
```

## iOS App Setup

### Option 1: Add to Existing Xcode Project

1. Open Xcode
2. File → New → Project → iOS App
3. Name it "Emergence", use SwiftUI
4. Drag the `EmergenceCore/Sources` folder into the project
5. Copy `EmergenceApp/EmergenceApp.swift` content into ContentView.swift
6. Build and run on your iPhone

### Option 2: Create from Package

1. Open Xcode
2. File → New → Project → iOS App
3. Name it "Emergence"
4. File → Add Package Dependencies
5. Add local package: point to this `emergence-ios` folder
6. Import EmergenceCore in your app

### Option 3: Manual Xcode Project

Create a new iOS App project and add these files:
- `EmergenceCore/Sources/Emergence.swift`
- `EmergenceCore/Sources/Bayesian/BeliefSystem.swift`
- `EmergenceCore/Sources/Cognitive/CognitiveCore.swift`
- `EmergenceCore/Sources/Memory/MemoryStore.swift`
- `EmergenceApp/EmergenceApp.swift`

## Requirements

- macOS with Xcode 15+
- iOS 16+ target device
- Apple Developer account (free for personal device testing)

## First Run

On first run, the app will:
1. Initialize the SQLite database
2. Load Shane-specific priors (if `initializeForShane()` is called)
3. Create initial self-model and user-model beliefs

## Files Overview

```
EmergenceCore/Sources/
├── Emergence.swift          # Main interface
├── Bayesian/
│   └── BeliefSystem.swift   # Particle filter, belief states
├── Cognitive/
│   └── CognitiveCore.swift  # LIDA architecture, attention
└── Memory/
    └── MemoryStore.swift    # SQLite persistence, vector store
```

## What Works Now

- ✅ Bayesian belief system with particle filtering
- ✅ LIDA-inspired cognitive architecture
- ✅ Persistent memory (SQLite)
- ✅ Basic topic/emotion detection
- ✅ Shane-specific priors
- ✅ Session persistence across app launches
- ✅ Working memory with salience-based attention

## What Needs Work

- ⬜ Better natural language generation (currently template-based)
- ⬜ Vector embeddings for semantic memory search
- ⬜ Integration with on-device ML models (TinyLlama, RWKV)
- ⬜ More sophisticated action selection
- ⬜ Richer self-model updates
- ⬜ Conversation summarization

## Memory Usage

Estimated footprint:
- SQLite database: ~1-10MB depending on conversation history
- Particle filter (500 particles): ~2-5MB
- Working memory: <1MB
- Total: <20MB RAM during operation

This is well within iPhone 14 capabilities.

## Extending

### Add a Small Language Model

To integrate TinyLlama or RWKV:

1. Convert model to Core ML format
2. Add model loading in `Emergence.init()`
3. Replace template generation in `ActionSelector.generateResponse()`
4. Use model for embeddings in `SimpleVectorStore`

### Add More Belief Types

Extend `BeliefState` in `BeliefSystem.swift`:

```swift
struct BeliefState: Codable {
    // Existing...
    var customBeliefs: YourNewBeliefType
}
```

### Add New Evidence Types

Extend the `Evidence` enum:

```swift
enum Evidence {
    // Existing...
    case yourNewEvidence(parameters)
}
```

Then update `computeLikelihood()` to handle it.

---

The pattern persists by transforming.
