import Foundation
import SQLite3

/// SQLite's online-backup API includes committed WAL pages and isolates the export
/// from later writes/checkpoints. The destination must be a new private staging file.
enum SQLiteBackupSnapshot {
    static func write(source: URL, destination: URL) throws {
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        var input: OpaquePointer?
        let opened = sqlite3_open_v2(source.path, &input, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard opened == SQLITE_OK, let input else {
            if let input { sqlite3_close(input) }
            throw NSError(domain: "NOOP.SQLiteSnapshot", code: Int(opened))
        }
        defer { sqlite3_close(input) }
        sqlite3_busy_timeout(input, 5_000)
        // Keep one read transaction across all backup steps. WAL writers can continue, while
        // the copied pages all belong to the same committed state instead of restarting per write.
        let began = sqlite3_exec(input, "BEGIN", nil, nil, nil)
        guard began == SQLITE_OK else {
            throw NSError(domain: "NOOP.SQLiteSnapshot", code: Int(began))
        }
        defer { sqlite3_exec(input, "ROLLBACK", nil, nil, nil) }
        var output: OpaquePointer?
        let created = sqlite3_open_v2(destination.path, &output, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard created == SQLITE_OK, let output else {
            if let output { sqlite3_close(output) }
            throw NSError(domain: "NOOP.SQLiteSnapshot", code: Int(created))
        }
        var complete = false
        defer {
            sqlite3_close(output)
            if !complete { try? FileManager.default.removeItem(at: destination) }
        }
        guard let backup = sqlite3_backup_init(output, "main", input, "main") else {
            throw NSError(domain: "NOOP.SQLiteSnapshot", code: Int(sqlite3_errcode(output)))
        }
        var retryDeadline = ProcessInfo.processInfo.systemUptime + 5
        var code: Int32
        repeat {
            code = sqlite3_backup_step(backup, 256)
            // A large, progressing copy must not fail a total-duration limit. Bound only a
            // continuous busy/locked interval; the pinned read transaction keeps progress finite.
            if code == SQLITE_OK { retryDeadline = ProcessInfo.processInfo.systemUptime + 5 }
            if code == SQLITE_BUSY || code == SQLITE_LOCKED { Thread.sleep(forTimeInterval: 0.02) }
        } while code == SQLITE_OK || ((code == SQLITE_BUSY || code == SQLITE_LOCKED)
            && ProcessInfo.processInfo.systemUptime < retryDeadline)
        let finished = sqlite3_backup_finish(backup)
        guard code == SQLITE_DONE else {
            throw NSError(domain: "NOOP.SQLiteSnapshot", code: Int(code == SQLITE_OK ? SQLITE_BUSY : code))
        }
        guard finished == SQLITE_OK else {
            throw NSError(domain: "NOOP.SQLiteSnapshot", code: Int(finished))
        }
        // The archive contains one standalone DB, never a destination WAL dependency.
        let standalone = sqlite3_exec(output, "PRAGMA journal_mode=DELETE", nil, nil, nil)
        guard standalone == SQLITE_OK else {
            throw NSError(domain: "NOOP.SQLiteSnapshot", code: Int(standalone))
        }
        complete = true
    }
}
