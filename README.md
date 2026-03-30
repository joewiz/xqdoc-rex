# xqdoc-rex

XQDoc generator for XQuery 4.0 using a [REx](https://www.bottlecaps.de/rex/)-generated parser and [Saxon HE](https://www.saxonica.com/html/products/products.html).

## Architecture

```
XQuery source → REx parser (XQuery on Saxon) → AST XML → xqdoc.xq walker → xqdoc XML → XSLT → Markdown
```

1. **REx-generated parser** (`XQueryParser.xquery`, 58K lines) — parses XQuery 4.0 + Update 3.0 + Full Text 1.0 + eXist legacy update syntax into an XML AST
2. **xqdoc.xq** — XQuery module that walks the AST and extracts module declarations, functions, variables, namespaces, imports into xqdoc 1.0 XML
3. **xqdoc-to-markdown.xsl** — XSLT 3.0 transform producing Markdown documentation

## Requirements

- Java 21+
- Maven 3.9+

## Build

```bash
mvn package
```

## Usage

```bash
# XML output (default)
./xqdoc module.xqm

# Markdown output
./xqdoc --format md module.xqm

# Direct JAR invocation
java -Xss16m -jar target/xqdoc-rex-1.0.0-SNAPSHOT-jar-with-dependencies.jar --format md module.xqm
```

## Output formats

- **xml** — xqdoc 1.0 XML (namespace `http://www.xqdoc.org/1.0`)
- **md** — Markdown with function signatures, parameters, return types, annotations

## Performance

Tested on semver.xqm (820 lines, 43 functions):

| Metric | Value |
|--------|-------|
| Parse + generate (avg 10 runs) | ~1.35s |
| First run (JVM cold start) | ~2.3s |
| Fat JAR size | 8.6 MB |
| Dependencies | Saxon HE 12.5 only |

## Grammar

The parser is generated from `XQuery-40-Family-XQUFEL.ebnf` using:

```bash
java -cp tools REx grammars/XQuery-40-Family-XQUFEL.ebnf -ll 3 -backtrack -tree -xquery -name XQueryParser
```

This is the same combined grammar used by [eXide](https://github.com/eXist-db/eXide), covering XQuery 4.0, W3C XQuery Update Facility 3.0, XQuery Full Text 1.0, and eXist-db legacy update syntax.

## Comparison with xqdoc-rd

This project is one half of a head-to-head comparison. The other half is [xqdoc-rd](https://github.com/joewiz/xqdoc-rd), which uses eXist-db's hand-written recursive descent parser.

| Criterion | xqdoc-rex | xqdoc-rd |
|-----------|-----------|----------|
| Parser | REx-generated (XQuery) | Hand-written rd (Java) |
| Runtime | Saxon HE (8.6 MB) | Zero dependencies (39 KB) |
| Language | XQuery + XSLT | Java |
| XQ4 coverage | Full (from W3C grammar) | Full (hand-written) |

## License

LGPL 2.1 (matching eXist-db)
