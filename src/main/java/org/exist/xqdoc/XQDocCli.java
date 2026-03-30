package org.exist.xqdoc;

import net.sf.saxon.s9api.*;

import javax.xml.transform.stream.StreamSource;
import java.io.*;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Command-line interface for the xqdoc-rex XQDoc generator.
 *
 * <p>Usage: {@code java -cp ... org.exist.xqdoc.XQDocCli [--format xml|md] source.xqm}</p>
 *
 * <p>Runs the XQuery-based xqdoc generator using Saxon HE, then optionally
 * transforms the output to Markdown via XSLT.</p>
 */
public class XQDocCli {

    private static final String XQDOC_XQ = "/xquery/xqdoc.xq";
    private static final String XQDOC_TO_MD_XSL = "/xslt/xqdoc-to-markdown.xsl";

    public static void main(String[] args) {
        String format = "xml";
        String sourceFile = null;

        // Parse arguments
        for (int i = 0; i < args.length; i++) {
            if ("--format".equals(args[i]) && i + 1 < args.length) {
                format = args[++i];
            } else if ("--help".equals(args[i]) || "-h".equals(args[i])) {
                printUsage();
                System.exit(0);
            } else if (!args[i].startsWith("-")) {
                sourceFile = args[i];
            } else {
                System.err.println("Unknown option: " + args[i]);
                printUsage();
                System.exit(1);
            }
        }

        if (sourceFile == null) {
            System.err.println("Error: No source file specified.");
            printUsage();
            System.exit(1);
        }

        if (!"xml".equals(format) && !"md".equals(format)) {
            System.err.println("Error: Invalid format '" + format + "'. Use 'xml' or 'md'.");
            System.exit(1);
        }

        Path sourcePath = Path.of(sourceFile).toAbsolutePath();
        if (!Files.exists(sourcePath)) {
            System.err.println("Error: Source file not found: " + sourcePath);
            System.exit(1);
        }

        try {
            String xqdocXml = generateXQDoc(sourcePath);

            if ("md".equals(format)) {
                String markdown = transformToMarkdown(xqdocXml);
                System.out.print(markdown);
            } else {
                System.out.println(xqdocXml);
            }
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace(System.err);
            System.exit(2);
        }
    }

    /**
     * Run the xqdoc.xq XQuery module to generate xqdoc XML for the given source file.
     */
    private static String generateXQDoc(Path sourcePath) throws SaxonApiException, IOException, java.net.URISyntaxException {
        Processor processor = new Processor(false);
        XQueryCompiler compiler = processor.newXQueryCompiler();

        // Allow the XQuery to resolve the parser module relative to itself
        URI baseUri = XQDocCli.class.getResource(XQDOC_XQ).toURI();
        compiler.setBaseURI(baseUri);

        // Read the xqdoc.xq source from the classpath
        String xquerySource;
        try (InputStream is = XQDocCli.class.getResourceAsStream(XQDOC_XQ)) {
            if (is == null) {
                throw new IOException("Cannot find " + XQDOC_XQ + " on classpath");
            }
            xquerySource = new String(is.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        }

        XQueryExecutable executable = compiler.compile(xquerySource);
        XQueryEvaluator evaluator = executable.load();

        // Pass the source file path as a URI so unparsed-text() can resolve it
        URI sourceUri = sourcePath.toUri();
        evaluator.setExternalVariable(new QName("source"), new XdmAtomicValue(sourceUri.toString()));

        // Serialize the result
        StringWriter writer = new StringWriter();
        Serializer serializer = processor.newSerializer(writer);
        serializer.setOutputProperty(Serializer.Property.METHOD, "xml");
        serializer.setOutputProperty(Serializer.Property.INDENT, "yes");
        serializer.setOutputProperty(Serializer.Property.OMIT_XML_DECLARATION, "no");

        evaluator.run(serializer);
        return writer.toString();
    }

    /**
     * Transform xqdoc XML to Markdown using the XSLT stylesheet.
     */
    private static String transformToMarkdown(String xqdocXml) throws SaxonApiException, IOException {
        Processor processor = new Processor(false);
        XsltCompiler xsltCompiler = processor.newXsltCompiler();

        // Load the XSLT from classpath
        try (InputStream is = XQDocCli.class.getResourceAsStream(XQDOC_TO_MD_XSL)) {
            if (is == null) {
                throw new IOException("Cannot find " + XQDOC_TO_MD_XSL + " on classpath");
            }

            XsltExecutable xsltExec = xsltCompiler.compile(new StreamSource(is));
            Xslt30Transformer transformer = xsltExec.load30();

            // Transform the xqdoc XML
            StreamSource xmlSource = new StreamSource(new StringReader(xqdocXml));
            StringWriter writer = new StringWriter();
            Serializer serializer = processor.newSerializer(writer);

            transformer.transform(xmlSource, serializer);
            return writer.toString();
        }
    }

    private static void printUsage() {
        System.err.println("Usage: xqdoc [--format xml|md] <source-file.xqm>");
        System.err.println();
        System.err.println("Options:");
        System.err.println("  --format xml    Output xqdoc XML (default)");
        System.err.println("  --format md     Output Markdown documentation");
        System.err.println("  --help, -h      Show this help message");
    }
}
