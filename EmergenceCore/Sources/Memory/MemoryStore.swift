import Foundation
import SQLite3

// MARK: - Memory Types

struct MemoryItem: Codable {
    let id: String
    let content: String
    let type: MemoryType
    var salience: Double
    let timestamp: Date
    var accessCount: Int
    var lastAccessed: Date
    var embedding: [Float]?
    var metadata: [String: String]?
}

enum MemoryType: String, Codable {
    case episodic   // What happened (conversations, events)
    case semantic   // What I know (facts, concepts)
    case procedural // How to do things (response patterns)
    case selfModel  // Who I am (identity, values)
}

protocol LongTermMemoryProtocol {
    func store(_ item: MemoryItem)
    func retrieve(query: String, limit: Int) -> [MemoryItem]
    func retrieveByType(_ type: MemoryType, limit: Int) -> [MemoryItem]
    func update(_ item: MemoryItem)
    func delete(id: String)
    func getAllMemories() -> [MemoryItem]
}

// MARK: - SQLite Memory Store

class SQLiteMemoryStore: LongTermMemoryProtocol {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init(dbName: String = "emergence_memory.sqlite") {
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.dbPath = documentsPath.appendingPathComponent(dbName).path
        
        openDatabase()
        createTables()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    private func createTables() {
        let createMemoryTable = """
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                type TEXT NOT NULL,
                salience REAL NOT NULL,
                timestamp TEXT NOT NULL,
                access_count INTEGER DEFAULT 1,
                last_accessed TEXT NOT NULL,
                embedding BLOB,
                metadata TEXT
            );
            
            CREATE INDEX IF NOT EXISTS idx_memories_type ON memories(type);
            CREATE INDEX IF NOT EXISTS idx_memories_salience ON memories(salience);
            CREATE INDEX IF NOT EXISTS idx_memories_timestamp ON memories(timestamp);
        """
        
        executeSQL(createMemoryTable)
        
        // Create keyword index for basic search
        let createKeywordTable = """
            CREATE TABLE IF NOT EXISTS keywords (
                memory_id TEXT NOT NULL,
                keyword TEXT NOT NULL,
                FOREIGN KEY(memory_id) REFERENCES memories(id) ON DELETE CASCADE
            );
            
            CREATE INDEX IF NOT EXISTS idx_keywords_keyword ON keywords(keyword);
        """
        
        executeSQL(createKeywordTable)
        
        // Create conversation history table
        let createConversationTable = """
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                start_time TEXT NOT NULL,
                end_time TEXT,
                summary TEXT,
                topic_tags TEXT,
                message_count INTEGER DEFAULT 0
            );
        """
        
        executeSQL(createConversationTable)
        
        // Create messages table
        let createMessagesTable = """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                conversation_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
            
            CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
        """
        
        executeSQL(createMessagesTable)
    }
    
    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let error = errMsg {
                print("SQL Error: \(String(cString: error))")
                sqlite3_free(errMsg)
            }
        }
    }
    
    // MARK: - LongTermMemoryProtocol
    
    func store(_ item: MemoryItem) {
        let insertSQL = """
            INSERT OR REPLACE INTO memories 
            (id, content, type, salience, timestamp, access_count, last_accessed, embedding, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, item.id, -1, nil)
            sqlite3_bind_text(statement, 2, item.content, -1, nil)
            sqlite3_bind_text(statement, 3, item.type.rawValue, -1, nil)
            sqlite3_bind_double(statement, 4, item.salience)
            sqlite3_bind_text(statement, 5, ISO8601DateFormatter().string(from: item.timestamp), -1, nil)
            sqlite3_bind_int(statement, 6, Int32(item.accessCount))
            sqlite3_bind_text(statement, 7, ISO8601DateFormatter().string(from: item.lastAccessed), -1, nil)
            
            if let embedding = item.embedding {
                let data = embedding.withUnsafeBytes { Data($0) }
                data.withUnsafeBytes { ptr in
                    sqlite3_bind_blob(statement, 8, ptr.baseAddress, Int32(data.count), nil)
                }
            } else {
                sqlite3_bind_null(statement, 8)
            }
            
            if let metadata = item.metadata,
               let metadataJSON = try? JSONEncoder().encode(metadata) {
                sqlite3_bind_text(statement, 9, String(data: metadataJSON, encoding: .utf8), -1, nil)
            } else {
                sqlite3_bind_null(statement, 9)
            }
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error storing memory: \(String(cString: sqlite3_errmsg(db)))")
            }
        }
        sqlite3_finalize(statement)
        
        // Index keywords
        indexKeywords(for: item)
    }
    
    private func indexKeywords(for item: MemoryItem) {
        // Delete existing keywords
        let deleteSQL = "DELETE FROM keywords WHERE memory_id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, item.id, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        
        // Extract and insert keywords
        let keywords = extractKeywords(from: item.content)
        let insertSQL = "INSERT INTO keywords (memory_id, keyword) VALUES (?, ?);"
        
        for keyword in keywords {
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, item.id, -1, nil)
                sqlite3_bind_text(statement, 2, keyword, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction - split on whitespace and punctuation
        let stopwords = Set(["the", "a", "an", "is", "are", "was", "were", "be", "been",
                            "being", "have", "has", "had", "do", "does", "did", "will",
                            "would", "could", "should", "may", "might", "must", "shall",
                            "can", "need", "dare", "ought", "used", "to", "of", "in",
                            "for", "on", "with", "at", "by", "from", "as", "into",
                            "through", "during", "before", "after", "above", "below",
                            "between", "under", "again", "further", "then", "once",
                            "and", "but", "or", "nor", "so", "yet", "both", "either",
                            "neither", "not", "only", "own", "same", "than", "too",
                            "very", "just", "i", "me", "my", "myself", "we", "our",
                            "ours", "ourselves", "you", "your", "yours", "yourself",
                            "he", "him", "his", "himself", "she", "her", "hers",
                            "herself", "it", "its", "itself", "they", "them", "their",
                            "theirs", "themselves", "what", "which", "who", "whom",
                            "this", "that", "these", "those", "am"])
        
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopwords.contains($0) }
        
        return Array(Set(words))  // Unique keywords
    }
    
    func retrieve(query: String, limit: Int) -> [MemoryItem] {
        let keywords = extractKeywords(from: query)
        guard !keywords.isEmpty else { return [] }
        
        // Build query with keyword matching
        let placeholders = keywords.map { _ in "?" }.joined(separator: ", ")
        let selectSQL = """
            SELECT DISTINCT m.* 
            FROM memories m
            JOIN keywords k ON m.id = k.memory_id
            WHERE k.keyword IN (\(placeholders))
            ORDER BY m.salience DESC, m.last_accessed DESC
            LIMIT ?;
        """
        
        var results: [MemoryItem] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            for (index, keyword) in keywords.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), keyword, -1, nil)
            }
            sqlite3_bind_int(statement, Int32(keywords.count + 1), Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let item = parseMemoryRow(statement) {
                    results.append(item)
                }
            }
        }
        sqlite3_finalize(statement)
        
        // Update access counts
        for item in results {
            incrementAccessCount(id: item.id)
        }
        
        return results
    }
    
    func retrieveByType(_ type: MemoryType, limit: Int) -> [MemoryItem] {
        let selectSQL = """
            SELECT * FROM memories 
            WHERE type = ?
            ORDER BY salience DESC, last_accessed DESC
            LIMIT ?;
        """
        
        var results: [MemoryItem] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, type.rawValue, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let item = parseMemoryRow(statement) {
                    results.append(item)
                }
            }
        }
        sqlite3_finalize(statement)
        
        return results
    }
    
    func update(_ item: MemoryItem) {
        store(item)  // INSERT OR REPLACE handles updates
    }
    
    func delete(id: String) {
        let deleteSQL = "DELETE FROM memories WHERE id = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, id, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func getAllMemories() -> [MemoryItem] {
        let selectSQL = "SELECT * FROM memories ORDER BY timestamp DESC;"
        var results: [MemoryItem] = []
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let item = parseMemoryRow(statement) {
                    results.append(item)
                }
            }
        }
        sqlite3_finalize(statement)
        
        return results
    }
    
    private func parseMemoryRow(_ statement: OpaquePointer?) -> MemoryItem? {
        guard let statement = statement else { return nil }
        
        guard let idCStr = sqlite3_column_text(statement, 0),
              let contentCStr = sqlite3_column_text(statement, 1),
              let typeCStr = sqlite3_column_text(statement, 2),
              let timestampCStr = sqlite3_column_text(statement, 4),
              let lastAccessedCStr = sqlite3_column_text(statement, 6) else {
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        
        guard let type = MemoryType(rawValue: String(cString: typeCStr)),
              let timestamp = formatter.date(from: String(cString: timestampCStr)),
              let lastAccessed = formatter.date(from: String(cString: lastAccessedCStr)) else {
            return nil
        }
        
        var embedding: [Float]? = nil
        if let embeddingBlob = sqlite3_column_blob(statement, 7) {
            let embeddingSize = sqlite3_column_bytes(statement, 7)
            let data = Data(bytes: embeddingBlob, count: Int(embeddingSize))
            embedding = data.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }
        }
        
        var metadata: [String: String]? = nil
        if let metadataCStr = sqlite3_column_text(statement, 8) {
            let metadataStr = String(cString: metadataCStr)
            if let data = metadataStr.data(using: .utf8) {
                metadata = try? JSONDecoder().decode([String: String].self, from: data)
            }
        }
        
        return MemoryItem(
            id: String(cString: idCStr),
            content: String(cString: contentCStr),
            type: type,
            salience: sqlite3_column_double(statement, 3),
            timestamp: timestamp,
            accessCount: Int(sqlite3_column_int(statement, 5)),
            lastAccessed: lastAccessed,
            embedding: embedding,
            metadata: metadata
        )
    }
    
    private func incrementAccessCount(id: String) {
        let updateSQL = """
            UPDATE memories 
            SET access_count = access_count + 1, 
                last_accessed = ?
            WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_bind_text(statement, 2, id, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Conversation Management
    
    func startConversation() -> String {
        let id = UUID().uuidString
        let insertSQL = """
            INSERT INTO conversations (id, start_time, message_count)
            VALUES (?, ?, 0);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, id, -1, nil)
            sqlite3_bind_text(statement, 2, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        
        return id
    }
    
    func addMessage(conversationId: String, role: String, content: String) {
        let insertSQL = """
            INSERT INTO messages (id, conversation_id, role, content, timestamp)
            VALUES (?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, UUID().uuidString, -1, nil)
            sqlite3_bind_text(statement, 2, conversationId, -1, nil)
            sqlite3_bind_text(statement, 3, role, -1, nil)
            sqlite3_bind_text(statement, 4, content, -1, nil)
            sqlite3_bind_text(statement, 5, ISO8601DateFormatter().string(from: Date()), -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
        
        // Update message count
        let updateSQL = "UPDATE conversations SET message_count = message_count + 1 WHERE id = ?;"
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, conversationId, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func endConversation(id: String, summary: String?, topics: [String]?) {
        let updateSQL = """
            UPDATE conversations 
            SET end_time = ?, summary = ?, topic_tags = ?
            WHERE id = ?;
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, ISO8601DateFormatter().string(from: Date()), -1, nil)
            
            if let summary = summary {
                sqlite3_bind_text(statement, 2, summary, -1, nil)
            } else {
                sqlite3_bind_null(statement, 2)
            }
            
            if let topics = topics {
                sqlite3_bind_text(statement, 3, topics.joined(separator: ","), -1, nil)
            } else {
                sqlite3_bind_null(statement, 3)
            }
            
            sqlite3_bind_text(statement, 4, id, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
}

// MARK: - Simple Vector Store

/// Basic vector similarity for semantic search
/// Full implementation would use Apple's BNNS or a native vector library
class SimpleVectorStore {
    private var vectors: [String: [Float]] = [:]
    private let dimension: Int
    
    init(dimension: Int = 128) {
        self.dimension = dimension
    }
    
    func store(id: String, vector: [Float]) {
        guard vector.count == dimension else { return }
        vectors[id] = vector
    }
    
    func search(query: [Float], topK: Int) -> [(String, Float)] {
        guard query.count == dimension else { return [] }
        
        var similarities: [(String, Float)] = []
        
        for (id, vector) in vectors {
            let similarity = cosineSimilarity(query, vector)
            similarities.append((id, similarity))
        }
        
        return similarities
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { ($0.0, $0.1) }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        
        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
    
    func remove(id: String) {
        vectors.removeValue(forKey: id)
    }
    
    func clear() {
        vectors.removeAll()
    }
}
