# SQLiteManager

The SQLiteManager is a framework that manage sqlite databases. It works with the Apple Framework Combine to publish the data from the database into the app. For example you create your base sqlite database and put it into the bundle of your swift app. Then you can copy as the sqlite database into a working folder to store data into it or read data. You can also create the sqlite database at runtime and save it to a custom folder.

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Documentation](#documentation)
- [License](#license)

## Features
- Connect to SQLite Database
- Execute sql commands (SELECT, INSERT, UPDATE, DELETE, TRUNCATE)
- Work with the Apple Combine Framework
- Optional logging of the errors from the communication with the database
- Check if a table with a entry is exists in primary key column or custom column

## Requirements
The following table outlines the requirements for this package:

| Platform | Minimum Swift Version | Installation |
| -------- | --------------------- | ------------ |
| iOS 14.0+ / macOS 10.15+ | 5.3 | [Swift Package Manager](#swift-package-manager)|

## Installation
### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Flexible-Universe/SQLiteManager.git", .upToNextMajor(from: "1.0.0"))
]
```

## Examples
Create Table with SQL Command:
```swift
private var cancellables = Set<AnyCancellable>()

/* ... */

let fileManager = FileManager.default
let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
let dbFileURL = tempDirectoryURL.appendingPathComponent("test.db")

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
```
This piece of code create a table with the columns name and age. After this part you can insert some of data:
```swift
private var cancellables = Set<AnyCancellable>()

/* ... */

var insertDataSQL = "INSERT INTO users (name, age) VALUES ('John Doe', 30);"
sqlite.query(sql: insertDataSQL).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    .store(in: &cancellables)
insertDataSQL = "INSERT INTO users (name, age) VALUES ('Jane Smith', 27);"
sqlite.query(sql: insertDataSQL).sink(receiveCompletion: { _ in }, receiveValue: { _ in })
    .store(in: &cancellables)
```
Or take some data from the table with SQL-SELECT Command:
```swift
private var cancellables = Set<AnyCancellable>()

/* ... */

let sql = "SELECT * FROM users WHERE age > ?"
let parameters: [Any] = [25]

sqlite.query(sql: sql, parameters: parameters)
    .sink(receiveCompletion: { completion in
        switch completion {
        case .finished:
            print("The sql command finished successfully...")
        case .failure(let error):
            print("The sql command failed with error: \(error)")
        }
    }, receiveValue: { rows in
        print("The count of rows is: \(rows.count)")
        print("The name is : \(rows[0]["name"] as? String)")
        print("The age is  : \(rows[0]["age"] as? Int)")
    })
    .store(in: &cancellables)
```

## Documentation
The comprehensive documentation is accessible through this [link](https://docs.flexible-universe.com/SQLiteManager/).

## License
SQLiteManager is released under the MIT license. [See LICENSE](https://github.com/Flexible-Universe/SQLiteManager/blob/main/LICENSE) for details.
