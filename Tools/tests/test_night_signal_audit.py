import hashlib
import importlib.util
from pathlib import Path
import sqlite3
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('night_signal_audit', Path(__file__).parents[1] / 'night_signal_audit.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class NightAuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'night with spaces & %.sqlite'
        db = sqlite3.connect(self.path)
        db.executescript('''CREATE TABLE hrSample(deviceId TEXT, ts INTEGER, bpm INTEGER);
        CREATE TABLE gravitySample(deviceId TEXT, ts INTEGER, x REAL, y REAL, z REAL);
        CREATE TABLE respSample(deviceId TEXT, ts INTEGER, raw INTEGER);
        CREATE TABLE rrInterval(deviceId TEXT, ts INTEGER, rrMs INTEGER, srcChannel INTEGER, tsSuspect INTEGER);''')
        db.executemany('INSERT INTO hrSample VALUES (?,?,?)', [('band', 1000, 60), ('band', 1299, 61), ('band', 1300, 60), ('other', 1100, 70)])
        db.executemany('INSERT INTO rrInterval VALUES (?,?,?,?,?)', [
            ('band', 1000, 1000, 5, None), ('band', 1000, 1010, 5, None),
            ('band', 1001, 500, 5, 1), ('band', 1100, 500, 7, None),
            ('band', 1200, 1000, 6, None), ('band', 1201, 1000, None, None)])
        db.commit()
        db.close()

    def report(self, device='band', start=1000, end=1300):
        db = m.open_snapshot(self.path)
        try:
            return m.audit(db, device, start, end)
        finally:
            db.close()

    def test_read_only_and_no_mutation(self):
        before = hashlib.sha256(self.path.read_bytes()).digest()
        self.report()
        self.assertEqual(before, hashlib.sha256(self.path.read_bytes()).digest())
        db = m.open_snapshot(self.path)
        with self.assertRaises(sqlite3.OperationalError):
            db.execute('DELETE FROM hrSample')
        db.close()

    def test_half_open_window_and_device_filter(self):
        r = self.report()['streams']['heart_rate']
        self.assertEqual(r['rows'], 2)
        self.assertEqual(r['distinct_seconds'], 2)

    def test_channels_stay_separate_and_flags_respected(self):
        channels = {r['channel']: r for r in self.report()['rr_by_channel']}
        self.assertEqual(channels[5]['rows'], 3)
        self.assertEqual(channels[5]['non_suspect_rows'], 2)
        self.assertEqual(channels[5]['distinct_seconds'], 1)
        self.assertTrue(channels[7]['recognized_whoop5_scoring_transport'])
        self.assertFalse(channels[6]['recognized_whoop5_scoring_transport'])
        self.assertFalse(channels[None]['recognized_whoop5_scoring_transport'])
        self.assertEqual(channels[7]['non_suspect_rows'], 1)  # 500 ms alone is not a rejection rule.

    def test_sparse_bins_do_not_claim_continuity(self):
        r = m.timeline([1000, 1300], 1000, 1601)
        self.assertEqual(r['five_minute_bins_with_any_sample'], 2)
        self.assertEqual(r['five_minute_bins_total'], 3)
        self.assertEqual(r['largest_timestamp_gap_seconds'], 301)
        self.assertLess(r['observed_seconds_fraction'], 0.01)

    def test_empty_and_unknown_device(self):
        r = self.report(device="unknown' OR 1=1 --")
        self.assertFalse(r['device_seen_in_available_streams'])
        self.assertEqual(r['streams']['heart_rate']['rows'], 0)
        self.assertEqual(r['streams']['heart_rate']['largest_timestamp_gap_seconds'], 300)

    def test_old_schema_reports_missing_provenance(self):
        db = sqlite3.connect(self.path)
        db.executescript('ALTER TABLE rrInterval RENAME TO oldRR; CREATE TABLE rrInterval(deviceId TEXT, ts INTEGER, rrMs INTEGER); INSERT INTO rrInterval VALUES (\'band\',1000,1000); DROP TABLE gravitySample;')
        db.commit(); db.close()
        r = self.report()
        self.assertFalse(r['rr_provenance_column_present'])
        self.assertFalse(r['rr_quarantine_column_present'])
        self.assertEqual(r['streams']['motion']['status'], 'table_or_columns_missing')
        self.assertFalse(r['rr_by_channel'][0]['recognized_whoop5_scoring_transport'])

    def test_offset_required_and_equivalent_instants(self):
        with self.assertRaises(ValueError): m.utc_seconds('2026-11-07T23:00:00')
        self.assertEqual(m.utc_seconds('2026-11-07T23:00:00+01:00'), m.utc_seconds('2026-11-07T22:00:00Z'))

    def test_invalid_windows(self):
        for start, end in [(1000, 1000), (1001, 1000), (0, 49*3600)]:
            with self.assertRaises(ValueError): self.report(start=start, end=end)

    def test_rejects_wal_and_missing_file(self):
        wal = Path(str(self.path) + '-wal'); wal.write_bytes(b'pending')
        with self.assertRaises(ValueError): m.open_snapshot(self.path)
        with self.assertRaises(FileNotFoundError): m.open_snapshot(self.path.parent / 'missing.sqlite')

    def test_report_does_not_expose_identifiers_or_health_values(self):
        import json
        result = json.dumps(self.report())
        self.assertNotIn('"band"', result)
        self.assertNotIn('"bpm"', result)
        self.assertNotIn(str(self.path), result)


if __name__ == '__main__':
    unittest.main()
