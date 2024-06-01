//
//  SQLiteOperations.swift
//
//
//  Created by Rolf Warnecke on 31.05.24.
//

import Foundation
import Combine
import SQLite3
import os.log

extension SQLiteManager {
    /// To check if the entry exists in the table
    /// - Parameter table: The name of the database table as a string
    /// - Parameter column: The column name for check the entry
    /// - Parameter entry: The content of the row as a string
    /// - Returns: A Combine any publisher returns **TRUE** if the entry exists in the table, otherwise **FALSE**.
    public func checkEntryExistsInColumn(inTable table: String, inColumn column: String, entry: String) -> AnyPublisher<Bool, Error> {
            let sql = "SELECT EXISTS(SELECT 1 FROM \(table) WHERE \(column) = ? LIMIT 1)"
            return Deferred {
                Future<Bool, Error> { promise in
                    var statement: OpaquePointer?
                    guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                        let message = String(cString: sqlite3_errmsg(self.db)!)
                        self.logError(message)
                        promise(.failure(SQLiteManagerError.prepareFailed(message)))
                        return
                    }

                    guard sqlite3_bind_text(statement, 1, entry, -1, nil) == SQLITE_OK else {
                        let message = String(cString: sqlite3_errmsg(self.db)!)
                        self.logError(message)
                        sqlite3_finalize(statement)
                        promise(.failure(SQLiteManagerError.bindFailed(message)))
                        return
                    }

                    var exists = false
                    if sqlite3_step(statement) == SQLITE_ROW {
                        exists = sqlite3_column_int(statement, 0) != 0
                    }

                    sqlite3_finalize(statement)
                    promise(.success(exists))
                }
            }
            .eraseToAnyPublisher()
    }
    /// To check if the entry exists in the primary key column
    /// - Parameters
    public func checkEntryExists(inTable table: String, primaryKeyValue: Any) -> AnyPublisher<Bool, Error> {
        // First, get the primary key column name
        let pragmaSQL = "PRAGMA table_info(\(table));"
        return Deferred {
            Future<Bool, Error> { promise in
                var statement: OpaquePointer?
                guard sqlite3_prepare_v2(self.db, pragmaSQL, -1, &statement, nil) == SQLITE_OK else {
                    let message = String(cString: sqlite3_errmsg(self.db)!)
                    self.logError(message)
                    promise(.failure(SQLiteManagerError.prepareFailed(message)))
                    return
                }

                var primaryKeyColumn: String?
                while sqlite3_step(statement) == SQLITE_ROW {
                    let columnName = String(cString: sqlite3_column_text(statement, 1))
                    let isPrimaryKey = sqlite3_column_int(statement, 5)
                    if isPrimaryKey == 1 {
                        primaryKeyColumn = columnName
                        break
                    }
                }

                sqlite3_finalize(statement)

                guard let primaryKeyColumn = primaryKeyColumn else {
                    let message = "Primary key not found for table \(table)"
                    self.logError(message)
                    promise(.failure(SQLiteManagerError.prepareFailed(message)))
                    return
                }

                // Check if the entry exists
                let sql = "SELECT EXISTS(SELECT 1 FROM \(table) WHERE \(primaryKeyColumn) = ? LIMIT 1)"
                guard sqlite3_prepare_v2(self.db, sql, -1, &statement, nil) == SQLITE_OK else {
                    let message = String(cString: sqlite3_errmsg(self.db)!)
                    self.logError(message)
                    promise(.failure(SQLiteManagerError.prepareFailed(message)))
                    return
                }

                switch primaryKeyValue {
                case let intValue as Int:
                    guard sqlite3_bind_int64(statement, 1, Int64(intValue)) == SQLITE_OK else {
                        let message = String(cString: sqlite3_errmsg(self.db)!)
                        self.logError(message)
                        sqlite3_finalize(statement)
                        promise(.failure(SQLiteManagerError.bindFailed(message)))
                        return
                    }
                case let stringValue as String:
                    let cString = (stringValue as NSString).utf8String
                    guard sqlite3_bind_text(statement, 1, cString, -1, nil) == SQLITE_OK else {
                        let message = String(cString: sqlite3_errmsg(self.db)!)
                        self.logError(message)
                        sqlite3_finalize(statement)
                        promise(.failure(SQLiteManagerError.bindFailed(message)))
                        return
                    }
                default:
                    let message = "Unsupported primary key type"
                    self.logError(message)
                    sqlite3_finalize(statement)
                    promise(.failure(SQLiteManagerError.bindFailed(message)))
                    return
                }

                var exists = false
                if sqlite3_step(statement) == SQLITE_ROW {
                    exists = sqlite3_column_int(statement, 0) != 0
                }

                sqlite3_finalize(statement)
                promise(.success(exists))
            }
        }
        .eraseToAnyPublisher()
    }
}
