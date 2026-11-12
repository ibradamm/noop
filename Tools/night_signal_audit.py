#!/usr/bin/env python3
"""Read-only WHOOP 5 overnight input inventory. No health scores or BLE writes."""
import argparse
import datetime as dt
import json
import math
from pathlib import Path
import sqlite3

STREAMS = {'heart_rate': ('hrSample', ('bpm',)),
           'motion': ('gravitySample', ('x', 'y', 'z')),
           'respiration_records': ('respSample', ('raw',))}


def utc_seconds(value):
    parsed = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('Times must include a UTC offset, for example +01:00.')
    if parsed.microsecond:
        raise ValueError('Use whole-second window bounds; timestamps are not rounded.')
    return int(parsed.timestamp())


def open_snapshot(path):
    path = Path(path).resolve(strict=True)
    # Immutable connections ignore WAL. Refuse a potentially incomplete copy rather
    # than reporting missing signals that are still held in a sidecar file.
    for suffix in ('-wal', '-journal'):
        sidecar = Path(str(path) + suffix)
        if sidecar.exists() and sidecar.stat().st_size:
            raise ValueError('Use a consistent exported SQLite snapshot without journal/WAL sidecars.')
    db = sqlite3.connect(path.as_uri() + '?mode=ro&immutable=1', uri=True)
    db.row_factory = sqlite3.Row
    return db


def columns(db, table):
    # All table names come from fixed internal constants, never CLI input.
    return {r['name'] for r in db.execute(f'PRAGMA table_info("{table}")')}


def timeline(timestamps, start, end):
    unique = sorted({t for t in timestamps if type(t) is int and start <= t < end})
    span = end - start
    bins = math.ceil(span / 300)
    occupied = {int((t - start) // 300) for t in unique}
    if unique:
        gaps = [unique[0] - start, end - unique[-1]]
        gaps.extend(b - a for a, b in zip(unique, unique[1:]))
        longest = max(gaps)
    else:
        longest = span
    return {'distinct_seconds': len(unique), 'five_minute_bins_with_any_sample': len(occupied),
            'five_minute_bins_total': bins,
            'observed_seconds_fraction': round(len(unique) / span, 6),
            'largest_timestamp_gap_seconds': longest}


def finite_number(value):
    return type(value) in (int, float) and math.isfinite(value)


def window_rows(db, table, fields, device, start, end):
    # SQLite is dynamically typed even when a column declares INTEGER. Do not
    # coerce text, fractional seconds, NaN/NULL or milliseconds into valid input.
    rows = list(db.execute(f'SELECT ts, {", ".join(fields)} FROM {table} '
                           'WHERE deviceId=? AND ts>=? AND ts<? ORDER BY ts',
                           (device, start, end)))
    invalid_ts = db.execute(f'SELECT COUNT(*) FROM {table} WHERE deviceId=? '
                            "AND (typeof(ts)<>'integer')", (device,)).fetchone()[0]
    return rows, invalid_ts


def audit(db, device, start, end):
    if end <= start:
        raise ValueError('End must be later than start.')
    if end - start > 48 * 3600:
        raise ValueError('Choose one overnight window of no more than 48 hours.')
    result = {'report_version': 2, 'window_seconds': end - start, 'streams': {}, 'rr_by_channel': [],
              'notes': ['An occupied five-minute bin can contain just one sample; this is not continuous coverage.',
                        'Stored respiration records do not establish a validated respiratory waveform.',
                        'This report measures stored inputs, not sleep accuracy or readiness.',
                        'Value checks establish structural usability only, not sensor accuracy.',
                        'Invalid timestamp counts cover the selected device across the snapshot: malformed times cannot be assigned to this window.']}
    device_seen = False
    for key, (table, fields) in STREAMS.items():
        names = columns(db, table)
        if not {'deviceId', 'ts', *fields}.issubset(names):
            result['streams'][key] = {'status': 'table_or_columns_missing'}
            continue
        device_seen |= bool(db.execute(f'SELECT 1 FROM {table} WHERE deviceId=? LIMIT 1', (device,)).fetchone())
        rows, invalid_ts = window_rows(db, table, fields, device, start, end)
        valid = [r for r in rows if type(r['ts']) is int
                 and all(finite_number(r[f]) for f in fields)
                 and (key != 'heart_rate' or r['bpm'] > 0)]
        by_second = {}
        for row in valid:
            by_second.setdefault(row['ts'], []).append(tuple(row[f] for f in fields))
        result['streams'][key] = {
            'status': ('no_rows_in_window' if not rows else
                       'observed' if valid else 'no_structurally_usable_rows'),
            'rows': len(rows), 'structurally_usable_rows': len(valid),
            'invalid_value_or_timestamp_rows_in_window': len(rows) - len(valid),
            'invalid_timestamp_rows_for_device': invalid_ts,
            'extra_rows_same_second': sum(len(v) - 1 for v in by_second.values()),
            'seconds_with_conflicting_values': sum(len(set(v)) > 1 for v in by_second.values()),
            **timeline([r['ts'] for r in valid], start, end)}
    names = columns(db, 'rrInterval')
    if not {'deviceId', 'ts', 'rrMs'}.issubset(names):
        result['rr_status'] = 'table_or_columns_missing'
    else:
        device_seen |= bool(db.execute('SELECT 1 FROM rrInterval WHERE deviceId=? LIMIT 1', (device,)).fetchone())
        channel = 'srcChannel' if 'srcChannel' in names else 'NULL AS srcChannel'
        suspect = 'tsSuspect' if 'tsSuspect' in names else 'NULL AS tsSuspect'
        rows, invalid_ts = window_rows(db, 'rrInterval', ('rrMs', channel, suspect), device, start, end)
        result['rr_invalid_timestamp_rows_for_device'] = invalid_ts
        result['rr_status'] = 'observed' if rows else 'no_rows_in_window'
        result['rr_provenance_column_present'] = 'srcChannel' in names
        result['rr_quarantine_column_present'] = 'tsSuspect' in names
        labels = sorted({r['srcChannel'] for r in rows}, key=lambda v: (v is None, type(v).__name__, str(v)))
        for label in labels:
            group = [r for r in rows if r['srcChannel'] == label]
            non_suspect = [r for r in group if r['tsSuspect'] != 1]
            usable = [r for r in non_suspect if type(r['ts']) is int
                      and finite_number(r['rrMs']) and r['rrMs'] > 0]
            result['rr_by_channel'].append({
                'channel': label if label is None or type(label) is int else 'invalid',
                'invalid_channel_type': label is not None and type(label) is not int,
                'rows': len(group),
                'flagged_suspect_rows': len(group) - len(non_suspect),
                'non_suspect_rows': len(non_suspect),
                'non_positive_interval_rows': sum(finite_number(r['rrMs']) and r['rrMs'] <= 0 for r in group),
                'invalid_interval_rows': sum(not finite_number(r['rrMs']) or r['rrMs'] <= 0 for r in group),
                'unknown_suspect_flag_rows': sum(r['tsSuspect'] not in (None, 0, 1) for r in group),
                'structurally_usable_non_suspect_rows': len(usable),
                'exact_500_ms_rows': sum(r['rrMs'] == 500 for r in group),
                'recognized_whoop5_scoring_transport': type(label) is int and label in (5, 7),
                **timeline([r['ts'] for r in usable], start, end)})
        result['notes'].append('RR channels are reported separately, never merged or converted. Channel 6 and unlabelled rows are not scoring transports in the inspected WHOOP 5 policy.')
        result['notes'].append('Exact 500 ms intervals are counted, not automatically discarded; inspect the stored suspect flags and same-second HR before attributing them to filler.')
        result['notes'].append('Multiple RR intervals in one second can be distinct beats. They are not deduplicated by timestamp, and structural usability is not HRV eligibility.')
        if not result['rr_quarantine_column_present']:
            result['notes'].append('This schema has no suspect flag; non_suspect_rows only means no stored flag was available, not physiological validity.')
    result['device_seen_in_available_streams'] = device_seen
    if not device_seen:
        result['notes'].append('Device ID not found in available input tables. Check the selected device before interpreting an empty report.')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', required=True, help='Consistent exported SQLite snapshot, not a .noopbak ZIP')
    parser.add_argument('--device', required=True, help='Exact deviceId used by the exported database')
    parser.add_argument('--start', required=True, help='ISO time with UTC offset')
    parser.add_argument('--end', required=True, help='ISO time with UTC offset; exclusive')
    args = parser.parse_args()
    try:
        start, end = utc_seconds(args.start), utc_seconds(args.end)
        db = open_snapshot(args.db)
        try:
            report = audit(db, args.device, start, end)
        finally:
            db.close()
    except (OSError, sqlite3.Error, ValueError) as exc:
        # OS/SQLite exception text can include the private path or a stored value.
        # Give a stable error category without copying that content into logs.
        parser.exit(2, f'Cannot audit snapshot ({type(exc).__name__}). Check the local snapshot, schema and offset-qualified window.\n')
    # No device identifiers, absolute timestamps or raw health values in output.
    print(json.dumps(report, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
