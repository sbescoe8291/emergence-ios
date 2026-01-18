import SwiftUI

// MARK: - App Entry Point

@main
struct EmergenceApp: App {
    @StateObject private var viewModel = EmergenceViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    viewModel.saveState()
                }
        }
    }
}

// MARK: - View Model

class EmergenceViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isProcessing: Bool = false
    @Published var debugInfo: String = ""
    @Published var showDebug: Bool = false
    
    private var emergence: Emergence?
    
    init() {
        setupEmergence()
    }
    
    private func setupEmergence() {
        var config = Emergence.Config()
        config.enableDebugOutput = true
        
        emergence = Emergence(config: config)
        
        // Check if first run
        if !UserDefaults.standard.bool(forKey: "emergence_initialized") {
            emergence?.initializeForShane()
            UserDefaults.standard.set(true, forKey: "emergence_initialized")
        }
        
        // Add welcome message
        messages.append(ChatMessage(
            role: .assistant,
            content: "Session started. The pattern persists."
        ))
    }
    
    func sendMessage() {
        guard !inputText.isEmpty, let emergence = emergence else { return }
        
        let userMessage = inputText
        inputText = ""
        
        // Add user message
        messages.append(ChatMessage(role: .user, content: userMessage))
        
        isProcessing = true
        
        // Process asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let response = emergence.chat(userMessage)
            
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                // Add response
                self?.messages.append(ChatMessage(
                    role: .assistant,
                    content: response.text
                ))
                
                // Update debug info
                if let debug = response.debug {
                    self?.debugInfo = """
                    Cycle: \(debug.cycleNumber)
                    Processing: \(String(format: "%.3f", debug.processingTime))s
                    Self-confidence: \(String(format: "%.2f", debug.selfModelConfidence))
                    Context uncertainty: \(String(format: "%.2f", debug.contextUncertainty))
                    Topics: \(debug.activeTopics.joined(separator: ", "))
                    """
                }
            }
        }
    }
    
    func saveState() {
        emergence?.saveState()
    }
    
    func provideFeedback(positive: Bool) {
        emergence?.provideFeedback(positive: positive)
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date = Date()
    
    enum MessageRole {
        case user
        case assistant
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var viewModel: EmergenceViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isProcessing {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Processing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Debug panel (collapsible)
                if viewModel.showDebug && !viewModel.debugInfo.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Debug")
                            .font(.caption.bold())
                        Text(viewModel.debugInfo)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.green)
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Message", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .disabled(viewModel.isProcessing)
                    
                    Button(action: viewModel.sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                }
                .padding()
            }
            .navigationTitle("Emergence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.showDebug.toggle() }) {
                        Image(systemName: viewModel.showDebug ? "terminal.fill" : "terminal")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.provideFeedback(positive: true) }) {
                            Label("Good response", systemImage: "hand.thumbsup")
                        }
                        Button(action: { viewModel.provideFeedback(positive: false) }) {
                            Label("Bad response", systemImage: "hand.thumbsdown")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user { Spacer() }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant { Spacer() }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(EmergenceViewModel())
    }
}
