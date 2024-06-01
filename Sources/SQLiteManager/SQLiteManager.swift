import Foundation
import Combine
import SQLite3
import os.log

/// The error types from the SQLiteManager
public enum SQLiteManagerError: Error {
    /// If to open the dabase failed
    case openFailed(String)
    /// If to prepare the dabase failed
    case prepareFailed(String)
    /// If to bind the parameters for the query failed
    case bindFailed(String)
    /// The common error messages
    case commonFailed(String)
}

/// The main class of the SQLite Manager
public final class SQLiteManager {
    
    internal var db: OpaquePointer?
    internal let log = OSLog(subsystem: "com.flexibleuniverse.SQLiteManager", category: "SQLiteManager")
    internal let isLoggingEnabled: Bool

    /// To initialize the SQLite Manager
    ///  - Parameter path: A String with a path to the database
    ///  - Parameter isLoggingEnabled: **TRUE** Logging is enabled with os.log and **FALSE** (Standard) disable the logging
    public init(path: String, isLoggingEnabled: Bool = false) throws {
        self.isLoggingEnabled = isLoggingEnabled
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db)!)
            if isLoggingEnabled {
                os_log("Error opening database: %@", log: log, type: .error, message)
            }
            sqlite3_close(db)
            throw SQLiteManagerError.openFailed(message)
        }
    }
    /// To copy the database to the working folder
    ///  - Parameter sourcFilePath: The path of the sqlite database file with the filename as a URL
    ///  - Parameter targetPath: The working folder for the local sqlite database as a URL
    public func copyDatabaseToTarget(sourceFilePath: URL, targetPath: URL) throws {
        do {
            try FileOperations.createDirectory(targetPath.path)

            let databaseFilename = sourceFilePath.lastPathComponent
            let dbTargetFilePath = targetPath.appendingPathExtension(databaseFilename)

            if !FileManager.default.fileExists(atPath: targetPath.path) {
                try FileManager.default.copyItem(at: sourceFilePath, to: dbTargetFilePath)
            }
        } catch {
            self.logError("Failed to copy database: \(error.localizedDescription)")
            throw SQLiteManagerError.commonFailed(error.localizedDescription)
        }
    }
    
    /// To run the query in the SQLite database with optional parameters
    /// - Parameter sql: The sql command in a string
    /// - Parameter perameters: An Array of integer and String values (optional)
    /// - Returns: A Combine any publisher with the result of the query or the error
    public func query(sql: String, parameters: [Any] = []) -> AnyPublisher<[[String: Any]], Error> {
        Deferred {
            Future<[[String: Any]], Error> { promise in
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                    let message = String(cString: sqlite3_errmsg(self.db)!)
                    self.logError("Error preparing statement: \(message)")
                    promise(.failure(SQLiteManagerError.prepareFailed(message)))
                    return
                }

                for (index, parameter) in parameters.enumerated() {
                    let parameterIndex = Int32(index + 1)

                    switch parameter {
                    case let intValue as Int:
                        guard sqlite3_bind_int64(statement, parameterIndex, Int64(intValue)) == SQLITE_OK else {
                            let message = String(cString: sqlite3_errmsg(self.db)!)
                            self.logError("Error binding integer paramter: \(message)")
                            sqlite3_finalize(statement)
                            promise(.failure(SQLiteManagerError.bindFailed(message)))
                            return
                        }
                    case let stringValue as String:
                        let cString = (stringValue as NSString).utf8String
                        guard sqlite3_bind_text(statement, parameterIndex, cString, -1, nil) == SQLITE_OK else {
                            let message = String(cString: sqlite3_errmsg(self.db)!)
                            self.logError("Error binding text paramter: \(message)")
                            sqlite3_finalize(statement)
                            promise(.failure(SQLiteManagerError.bindFailed(message)))
                            return
                        }
                    default:
                        break
                    }
                }

                var rows: [[String: Any]] = []

                while sqlite3_step(statement) == SQLITE_ROW {
                    let columnCount = sqlite3_column_count(statement)
                    var row: [String: Any] = [:]

                    for i in 0..<columnCount {
                        let columnName = String(cString: sqlite3_column_name(statement, i))
                        let columnType = sqlite3_column_type(statement, i)

                        switch columnType {
                        case SQLITE_INTEGER:
                            let value = sqlite3_column_int64(statement, i)
                            row[columnName] = Int(value)
                        case SQLITE_TEXT:
                            let value = String(cString: sqlite3_column_text(statement, i))
                            row[columnName] = value
                        case SQLITE_FLOAT:
                            let value = sqlite3_column_double(statement, i)
                            row[columnName] = value
                        default:
                            break
                        }
                    }

                    rows.append(row)
                }

                sqlite3_finalize(statement)
                promise(.success(rows))
            }
        }
        .eraseToAnyPublisher()
    }
    /// To write the logging error message with os.log
    /// - Parameter message: The error message as a string
    internal func logError(_ message: String) {
        if isLoggingEnabled {
            os_log("Error: %@", log: log, type: .error, message)
        }
    }
    /// To close the database if the SQLite manager was deinitialize
    deinit {
        sqlite3_close(db)
    }
}
