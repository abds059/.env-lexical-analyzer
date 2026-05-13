# .env Formal Lexical Analyzer — CT-367

## Build & Run

### Prerequisites
- Linux / macOS / WSL on Windows
- `flex` installed  →  `sudo apt install flex`  (Ubuntu/WSL)
- `gcc` installed   →  `sudo apt install gcc`

### Build
```bash
flex envlexer.l
gcc lex.yy.c -o envlexer 
```
### Run on the sample file
```bash
./envlexer sample.env
```

### Run on your own file
```bash
./envlexer yourfile.env
```

---

## Token Types

| Token         | Pattern                  | Description                          |
|---------------|--------------------------|--------------------------------------|
| KEY           | `[A-Z_][A-Z0-9_]*`       | Environment variable name            |
| EQUALS        | `=`                      | Assignment operator                  |
| COMMENT       | `#[^\n]*`                | Full-line comment                    |
| INLINE_CMT    | `[ \t]*#[^\n]*`          | Comment after a value                |
| EXPORT_KW     | `export`                 | Optional export prefix               |
| UNQUOTED_VAL  | `[^\n#"'$\t ]+`          | Bare unquoted value                  |
| SINGLE_QUOTED | `'[^'\n]*'`              | Single-quoted literal (no escapes)   |
| DOUBLE_QUOTED | `"(\\. or [^"\\\n])*"`   | Double-quoted with escape sequences  |
| MULTILINE_VAL | `"(\\.  or [^"\\])*"`    | Double-quoted spanning lines         |
| VAR_EXPANSION | `\${[A-Z_][A-Z0-9_]*}`   | Risk — expanded by Docker/Bash       |
| VAR_SHORT     | `\$[A-Z_][A-Z0-9_]*`     | Risk — boundary ambiguous in shell   |
| INVALID       | `.` (catch-all)          | Risk — unparseable token             |
| NEWLINE       | `\n`                     | Line boundary, resets lexer state    |

---

## Risk Flags

A `RISK Category` in the output means that token will be interpreted differently
by at least one major platform:

| Flag                        | Meaning                                              |
|-----------------------------|------------------------------------------------------|
| `platform-dependent`        | Node/Python treat as literal; Docker/Bash expand it  |
| `boundary ambiguous`        | Shell cannot reliably tell where variable name ends  |
| `unparseable token`         | No platform has consistent behavior for this token   |
| `unclosed string`           | Quote opened but never closed on this line           |

---

## Assumptions (Canonical Grammar Rules)

1. Keys must be UPPERCASE letters, digits, and underscores only.
2. Keys must start with a letter or underscore — not a digit.
3. Single-quoted values: fully literal — no escape sequences whatsoever.
4. Double-quoted values: support `\n`, `\t`, `\\`, `\"` escape sequences.
5. No whitespace is allowed between KEY and EQUALS sign.
6. Whitespace after EQUALS but before the value is silently consumed.
7. Blank lines are valid and produce only a NEWLINE token.
8. The `export` keyword is optional and must immediately precede the KEY.
9. Inline comments are valid when preceded by at least one space after the value.
10. Any unrecognized token produces INVALID — flagged as a cross-platform risk.

---

## License

This project is released under the MIT License. Feel free to fork, modify, and use it for academic or personal projects.

---

## Author

Abdur Rehman Siddiqui

---