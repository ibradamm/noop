import XCTest
import SQLite3
import WhoopStore
import ZIPFoundation
@testable import Strand

final class SQLiteBackupSnapshotTests: XCTestCase {
    func testIncludesCommittedWalAndDoesNotChangeWithLaterWrites() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("source.sqlite")
        let snapshot = folder.appendingPathComponent("snapshot.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(source.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0; CREATE TABLE sample(id INTEGER); INSERT INTO sample VALUES(1);", nil, nil, nil), SQLITE_OK)
        let wal = URL(fileURLWithPath: source.path + "-wal")
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: wal.path)[.size] as? NSNumber)?.intValue ?? 0, 0)
        try SQLiteBackupSnapshot.write(source: source, destination: snapshot)
        XCTAssertEqual(sqlite3_exec(db, "INSERT INTO sample VALUES(2)", nil, nil, nil), SQLITE_OK)
        var copied: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(snapshot.path, &copied, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(copied) }
        var query: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(copied, "SELECT COUNT(*) FROM sample", -1, &query, nil), SQLITE_OK)
        defer { sqlite3_finalize(query) }
        XCTAssertEqual(sqlite3_step(query), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(query, 0), 1)
        XCTAssertNil(DatabaseIntegrity.quickCheckFailure(atPath: snapshot.path))
    }

    func testMissingSourceIsRefusedWithoutInventingAnEmptyDatabase() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("missing.sqlite")
        let snapshot = folder.appendingPathComponent("snapshot.sqlite")
        XCTAssertThrowsError(try SQLiteBackupSnapshot.write(source: source, destination: snapshot))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshot.path))
    }

    func testExistingDestinationIsNeverOverwritten() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let destination = folder.appendingPathComponent("existing.sqlite")
        let original = Data("existing private file".utf8)
        try original.write(to: destination)
        XCTAssertThrowsError(try SQLiteBackupSnapshot.write(source: folder.appendingPathComponent("missing.sqlite"), destination: destination))
        XCTAssertEqual(try Data(contentsOf: destination), original)
    }

    func testCorruptSourceLeavesNoPartialSnapshot() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("corrupt.sqlite")
        let snapshot = folder.appendingPathComponent("snapshot.sqlite")
        let original = Data("not a SQLite database".utf8)
        try original.write(to: source)
        XCTAssertThrowsError(try SQLiteBackupSnapshot.write(source: source, destination: snapshot))
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshot.path))
    }

    func testProductionArchiveIncludesCommitsAfterCheckpoint() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("source.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(source.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0; CREATE TABLE sample(id INTEGER); INSERT INTO sample VALUES(1); PRAGMA wal_checkpoint(TRUNCATE); INSERT INTO sample VALUES(2);", nil, nil, nil), SQLITE_OK)
        let wal = URL(fileURLWithPath: source.path + "-wal")
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: wal.path)[.size] as? NSNumber)?.intValue ?? 0, 0)
        let destination = folder.appendingPathComponent("synthetic.noopbak")
        try DataBackup.writeVerifiedBackupZip(dbURL: source, to: destination, settingsJSON: nil)
        XCTAssertTrue(DataBackup.writtenBackupIsIntact(at: destination))
        let archive = try Archive(url: destination, accessMode: .read)
        let entry = try XCTUnwrap(archive["noop-backup.sqlite"])
        let extracted = folder.appendingPathComponent("restored.sqlite")
        _ = try archive.extract(entry, to: extracted)
        XCTAssertEqual(try integers("SELECT COUNT(*) FROM sample", at: extracted), [2])
        XCTAssertNil(DatabaseIntegrity.quickCheckFailure(atPath: extracted.path))
    }

    func testConcurrentWalTransactionsCannotTearTheSnapshot() throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("source.sqlite")
        let snapshot = folder.appendingPathComponent("snapshot.sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(source.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        // A multi-step copy, with a two-row invariant changed atomically by another connection.
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0; CREATE TABLE pair(id INTEGER PRIMARY KEY, revision INTEGER); INSERT INTO pair VALUES(1,0),(2,0); CREATE TABLE padding(body BLOB); WITH RECURSIVE n(i) AS (VALUES(1) UNION ALL SELECT i+1 FROM n WHERE i<512) INSERT INTO padding SELECT zeroblob(131072) FROM n;", nil, nil, nil), SQLITE_OK)
        let ready = DispatchSemaphore(value: 0)
        let start = DispatchSemaphore(value: 0)
        let finished = DispatchGroup()
        finished.enter()
        let evidence = WriterEvidence()
        DispatchQueue.global(qos: .userInitiated).async {
            var writer: OpaquePointer?
            let opened = sqlite3_open(source.path, &writer)
            evidence.record(error: opened)
            defer { sqlite3_close(writer); finished.leave() }
            sqlite3_busy_timeout(writer, 5_000)
            ready.signal()
            start.wait()
            guard opened == SQLITE_OK else { return }
            for revision in 1...40 {
                let code = sqlite3_exec(writer, "BEGIN IMMEDIATE; UPDATE pair SET revision=\(revision); COMMIT;", nil, nil, nil)
                evidence.record(error: code)
                guard code == SQLITE_OK else { return }
                evidence.recordCommit()
                if revision.isMultiple(of: 4) {
                    evidence.record(error: sqlite3_exec(writer, "PRAGMA wal_checkpoint(PASSIVE)", nil, nil, nil))
                }
                Thread.sleep(forTimeInterval: 0.001)
            }
        }
        XCTAssertEqual(ready.wait(timeout: .now() + 5), .success)
        let began = ProcessInfo.processInfo.systemUptime
        start.signal()
        defer { _ = finished.wait(timeout: .now() + 5) }
        try SQLiteBackupSnapshot.write(source: source, destination: snapshot)
        let ended = ProcessInfo.processInfo.systemUptime
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
        // This assertion proves writes actually overlapped the copy; merely launching a task is insufficient.
        XCTAssertTrue(evidence.commits.contains { $0 >= began && $0 <= ended })
        XCTAssertEqual(evidence.errors, [])
        XCTAssertEqual(evidence.commits.count, 40)
        let pair = try integers("SELECT revision FROM pair ORDER BY id", at: snapshot)
        XCTAssertEqual(pair.count, 2)
        XCTAssertEqual(pair.first, pair.last)
        XCTAssertTrue((0...40).contains(try XCTUnwrap(pair.first)))
        XCTAssertEqual(try integers("SELECT revision FROM pair ORDER BY id", at: source), [40, 40])
        XCTAssertEqual(try integers("SELECT COUNT(*) FROM padding", at: snapshot), [512])
        XCTAssertNil(DatabaseIntegrity.quickCheckFailure(atPath: snapshot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshot.path + "-wal"))
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        return folder
    }

    private func integers(_ sql: String, at url: URL) throws -> [Int] {
        var db: OpaquePointer?
        let opened = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil)
        defer { sqlite3_close(db) }
        guard opened == SQLITE_OK else { throw NSError(domain: "SyntheticSQLiteTest", code: Int(opened)) }
        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        guard prepared == SQLITE_OK else { throw NSError(domain: "SyntheticSQLiteTest", code: Int(prepared)) }
        var values: [Int] = []
        var code = sqlite3_step(statement)
        while code == SQLITE_ROW {
            values.append(Int(sqlite3_column_int(statement, 0)))
            code = sqlite3_step(statement)
        }
        XCTAssertEqual(code, SQLITE_DONE)
        return values
    }

    private final class WriterEvidence: @unchecked Sendable {
        private let lock = NSLock()
        private var times: [TimeInterval] = []
        private var failures: [Int32] = []
        var commits: [TimeInterval] { lock.lock(); defer { lock.unlock() }; return times }
        var errors: [Int32] { lock.lock(); defer { lock.unlock() }; return failures }
        func recordCommit() { lock.lock(); defer { lock.unlock() }; times.append(ProcessInfo.processInfo.systemUptime) }
        func record(error: Int32) { lock.lock(); defer { lock.unlock() }; if error != SQLITE_OK { failures.append(error) } }
    }
}
