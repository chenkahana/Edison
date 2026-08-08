# Pasteboard fixture capture

Use the metadata-only inspector to record what a source application places on the current
macOS pasteboard. The JSON contains labels, ordered item/type metadata, byte counts, and SHA-256
hashes, but no raw clipboard bytes. SHA-256 values are stable fingerprints and remain sensitive.
Use only deliberate synthetic samples with no passwords, tokens, or private content.

## Capture

1. In the source application, copy one deliberate sample.
2. From the repository root, inspect the pasteboard on macOS:

   ```sh
   swift scripts/inspect-pasteboard.swift \
     --label textedit-bold-link \
     --source TextEdit
   ```

3. To save a fixture, create its destination directory and pass `--output`. The final file is
   replaced atomically:

   ```sh
   fixture_dir="${TMPDIR%/}/edison-pasteboard-fixtures"
   mkdir -p "$fixture_dir"
   swift scripts/inspect-pasteboard.swift \
     --label textedit-bold-link \
     --source TextEdit \
     --output "$fixture_dir/textedit-bold-link.json"
   ```

4. Copy the same source sample again and recapture it. Compare the ordered type names, byte
   counts, and hashes. Treat a changed `changeCount` as expected metadata; treat a type, size,
   or hash difference as evidence to investigate before creating a regression fixture.

## Safety and failure behavior

- Labels and source names are supplied by the operator; do not put copied content in them.
- The inspector fails if a declared representation cannot be read or if the pasteboard changes
  during capture. It also fails when the pasteboard is empty or has no readable declared
  representations. Copy the sample again and retry.
- Treat generated JSON as sensitive. Only reviewed, sanitized fixture metadata should be
  deliberately moved from the temporary directory into the repository.
- The output parent directory must already exist.
- Run `swift scripts/inspect-pasteboard.swift --help` for the complete CLI reference.
