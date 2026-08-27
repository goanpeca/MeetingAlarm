# generated/

Docs whose **completeness/consistency is machine-enforced**, so they can't silently drift from
the code — even where the one-line summaries are human-curated (auto-extracting them from
doc-comments was tried and produced worse, truncated text).

| File | What | Gate |
| --- | --- | --- |
| [repo-map.md](repo-map.md) | Every source file, one curated line each | `check-docs` — a new file must have a row, a deleted one must lose it |
