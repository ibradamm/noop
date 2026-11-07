#!/usr/bin/env python3
"""Read-only WHOOP 5 overnight input inventory. No health scores or BLE writes."""
import argparse
import datetime as dt
import json
import math
from pathlib import Path
import sqlite3

STREAMS = {'heart_rate': ('hrSample', 'bpm'), 'motion': ('gravitySample', 'x'),
           'respiration_records': ('respSample', 'raw')}


def utc_seconds(value):
    parsed = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('Times must include a UTC offset, for example +01:00.')
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
    unique = sorted({int(t) for t in timestamps if start <= t < end})
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


def audit(db, device, start, end):
    if end <= start:
        raise ValueError('End must be later than start.')
    if end - start > 48 * 3600:
        raise ValueError('Choose one overnight window of no more than 48 hours.')
    result = {'window_seconds': end - start, 'streams': {}, 'rr_by_channel': [],
              'notes': ['An occupied five-minute bin can contain just one sample; this is not continuous coverage.',
                        'Stored respiration records do not establish a validated respiratory waveform.',
                        'This report measures stored inputs, not sleep accuracy or recovery readiness.']}
    device_seen = False
    for key, (table, value) in STREAMS.items():
        names = columns(db, table)
        if not {'deviceId', 'ts', value}.issubset(names):
            result['streams'][key] = {'status': 'table_or_columns_missing'}
            continue
        device_seen |= bool(db.execute(f'SELECT 1 FROM {table} WHERE deviceId=? LIMIT 1', (device,)).fetchone())
        times = [r['ts'] for r in db.execute(
            f'SELECT ts FROM {table} WHERE deviceId=? AND ts>=? AND ts<? ORDER BY ts',
            (device, start, end))]
        result['streams'][key] = {'status': 'observed' if times else 'no_rows_in_window',
                                  'rows': len(times), **timeline(times, start, end)}
    names = columns(db, 'rrInterval')
    if not {'deviceId', 'ts', 'rrMs'}.issubset(names):
        result['rr_status'] = 'table_or_columns_missing'
    else:
        device_seen |= bool(db.execute('SELECT 1 FROM rrInterval WHERE deviceId=? LIMIT 1', (device,)).fetchone())
        channel = 'srcChannel' if 'srcChannel' in names else 'NULL AS srcChannel'
        suspect = 'tsSuspect' if 'tsSuspect' in names else 'NULL AS tsSuspect'
        rows = list(db.execute(f'SELECT ts, rrMs, {channel}, {suspect} FROM rrInterval '
                               'WHERE deviceId=? AND ts>=? AND ts<? ORDER BY ts', (device, start, end)))
        result['rr_status'] = 'observed' if rows else 'no_rows_in_window'
        result['rr_provenance_column_present'] = 'srcChannel' in names
        result['rr_quarantine_column_present'] = 'tsSuspect' in names
        labels = sorted({r['srcChannel'] for r in rows}, key=lambda v: (v is None, v or 0))
        for label in labels:
            group = [r for r in rows if r['srcChannel'] == label]
            non_suspect = [r for r in group if r['tsSuspect'] != 1]
            result['rr_by_channel'].append({
                'channel': label, 'rows': len(group),
                'flagged_suspect_rows': len(group) - len(non_suspect),
                'non_suspect_rows': len(non_suspect),
                'non_positive_interval_rows': sum(r['rrMs'] <= 0 for r in group),
                'exact_500_ms_rows': sum(r['rrMs'] == 500 for r in group),
                'recognized_whoop5_scoring_transport': label in (5, 7),
                **timeline([r['ts'] for r in non_suspect], start, end)})
        result['notes'].append('RR channels are reported separately, never merged or converted. Channel 6 and unlabelled rows are not scoring transports in the inspected WHOOP 5 policy.')
        result['notes'].append('Exact 500 ms intervals are counted, not automatically discarded; inspect the stored suspect flags and same-second HR before attributing them to filler.')
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
        parser.exit(2, f'Cannot audit snapshot: {exc}\n')
    # No device identifiers, absolute timestamps or raw health values in output.
    print(json.dumps(report, indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
