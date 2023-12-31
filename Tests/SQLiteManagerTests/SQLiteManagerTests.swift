import XCTest
import Combine
@testable import SQLiteManager

final class SQLiteManagerTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testQuery() throws {
        let expectation = XCTestExpectation(description: "Query expectation")

        let dbPath = try createTestDatabase()
        let sqlite = try SQLiteManager(path: dbPath)

        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            age INTEGER
        );
        """
        sqlite.query(sql: createTableSQL).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        var insertDataSQL = "INSERT INTO users (name, age) VALUES ('John Doe', 30);"
        sqlite.query(sql: insertDataSQL).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        insertDataSQL = "INSERT INTO users (name, age) VALUES ('Jane Smith', 27);"
        sqlite.query(sql: insertDataSQL).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        let sql = "SELECT * FROM users WHERE age > ?"
        let parameters: [Any] = [25]

        sqlite.query(sql: sql, parameters: parameters)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Query failed with error: \(error)")
                }
            }, receiveValue: { rows in
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0]["name"] as? String, "John Doe")
                XCTAssertEqual(rows[0]["age"] as? Int, 30)
                XCTAssertEqual(rows[1]["name"] as? String, "Jane Smith")
                XCTAssertEqual(rows[1]["age"] as? Int, 27)
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    private func createTestDatabase() throws -> String {
        let fileManager = FileManager.default
        let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let dbFileURL = tempDirectoryURL.appendingPathComponent("test.db")

        if fileManager.fileExists(atPath: dbFileURL.path) {
            try fileManager.removeItem(at: dbFileURL)
        }

        let sqlite = try SQLiteManager(path: dbFileURL.path)

        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            age INTEGER
        );
        """
        sqlite.query(sql: createTableSQL).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        return dbFileURL.path
    }

    static var allTests = [
        ("testQuery", testQuery),
    ]
}
