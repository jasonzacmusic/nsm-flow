use crate::settings::RecordingRetentionPeriod;
use rusqlite::{params, Connection};

/// Saved entries are exempt from automatic transcript expiry.
pub fn expired_transcripts(
    conn: &Connection,
    period: RecordingRetentionPeriod,
    limit: usize,
    now: i64,
) -> rusqlite::Result<Vec<(i64, String)>> {
    use RecordingRetentionPeriod::*;
    if period == Never {
        return Ok(Vec::new());
    }
    let (sql, parameter) = match period {
        PreserveLimit => ("SELECT id, file_name FROM transcription_history WHERE saved = 0 ORDER BY id DESC LIMIT -1 OFFSET ?1", limit.min(i64::MAX as usize) as i64),
        DeleteImmediately => ("SELECT id, file_name FROM transcription_history WHERE saved = 0 AND timestamp <= ?1", now),
        Days3 => ("SELECT id, file_name FROM transcription_history WHERE saved = 0 AND timestamp < ?1", now - 3 * 86400),
        Weeks2 => ("SELECT id, file_name FROM transcription_history WHERE saved = 0 AND timestamp < ?1", now - 14 * 86400),
        Months3 => ("SELECT id, file_name FROM transcription_history WHERE saved = 0 AND timestamp < ?1", now - 90 * 86400),
        Never => unreachable!(),
    };
    let mut stmt = conn.prepare(sql)?;
    let entries = stmt
        .query_map(params![parameter], |row| Ok((row.get(0)?, row.get(1)?)))?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    Ok(entries)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expiry_preserves_saved_and_fresh_transcripts_and_never_keeps_everything() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch("CREATE TABLE transcription_history (id INTEGER PRIMARY KEY, file_name TEXT, saved INTEGER, timestamp INTEGER); INSERT INTO transcription_history VALUES (1, 'old.wav', 0, 0), (2, 'saved.wav', 1, 0), (3, 'fresh.wav', 0, 1000000);").unwrap();
        assert!(
            expired_transcripts(&conn, RecordingRetentionPeriod::Never, 0, 1000000)
                .unwrap()
                .is_empty()
        );
        assert_eq!(
            expired_transcripts(&conn, RecordingRetentionPeriod::Days3, 0, 1000000).unwrap(),
            vec![(1, "old.wav".into())]
        );
        assert_eq!(
            expired_transcripts(&conn, RecordingRetentionPeriod::PreserveLimit, 1, 1000000)
                .unwrap(),
            vec![(1, "old.wav".into())]
        );
        assert_eq!(
            expired_transcripts(
                &conn,
                RecordingRetentionPeriod::DeleteImmediately,
                0,
                1000000
            )
            .unwrap()
            .len(),
            2
        );
    }
}
