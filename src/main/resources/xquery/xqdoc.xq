xquery version "3.1";

(:~
 : XQDoc generator module.
 :
 : Parses an XQuery source file using the REx-generated XQueryParser,
 : walks the resulting AST, and produces xqdoc XML in the xqdoc 1.0 format.
 :
 : @author eXist-db project
 : @version 1.0.0
 :)

import module namespace p = "XQueryParser" at "XQueryParser.xquery";

declare namespace xqdoc = "http://www.xqdoc.org/1.0";

(:~ The path to the XQuery source file to document. :)
declare variable $source as xs:string external;

(:~
 : Find the xqdoc comment ((:~ ... :)) that immediately precedes an AST element.
 : REx includes comments as text nodes between elements in the AST.
 : We look at the preceding-sibling text nodes and parent's preceding text.
 :)
declare function local:find-xqdoc-comment($decl as element()) as xs:string? {
  (: Check preceding sibling text nodes, walking backward :)
  let $preceding-text :=
    for $node in $decl/preceding-sibling::node()
    return
      if ($node instance of text()) then string($node)
      else ()
  (: The last preceding text node is the closest :)
  let $closest := $preceding-text[last()]
  return
    if (exists($closest) and contains($closest, "(:~")) then
      let $comment := substring-after($closest, "(:~")
      let $comment := substring-before($comment, ":)")
      return normalize-space($comment)
    else
      ()
};

(:~
 : Parse xqdoc tags from a comment string.
 : Returns a map with keys: description, params (sequence of maps), return,
 : author, version, since, see, deprecated, error.
 :)
declare function local:parse-xqdoc-tags($comment as xs:string?) as map(*) {
  if (empty($comment) or $comment = "") then
    map { "description": "" }
  else
    let $lines := tokenize($comment, "&#10;")
    (: Clean each line: strip leading " : " or " * " prefix :)
    let $clean-lines :=
      for $line in $lines
      (: Strip leading whitespace, optional ":", optional " " :)
      let $trimmed := replace($line, "^\s+", "")
      let $trimmed :=
        if (starts-with($trimmed, ": ")) then substring($trimmed, 3)
        else if ($trimmed = ":") then ""
        else $trimmed
      return $trimmed
    let $text := string-join($clean-lines, "&#10;")

    (: Split into description (before first @tag) and tags :)
    let $parts := tokenize($text, "\s*@")
    let $description := replace(normalize-space($parts[1]), "\s*:\s*$", "")

    (: Parse @tags from remaining parts :)
    let $tags := subsequence($parts, 2)
    let $clean := function($s) { replace(normalize-space($s), "\s*:\s*$", "") }
    let $params :=
      for $tag in $tags
      where starts-with($tag, "param ")
      let $rest := substring-after($tag, "param ")
      let $name := replace($rest, "^(\$?\S+)\s.*$", "$1")
      let $desc := $clean(substring-after($rest, $name))
      return map { "name": $name, "description": $desc }
    let $return :=
      for $tag in $tags
      where starts-with($tag, "return ")
      return $clean(substring-after($tag, "return "))
    let $author :=
      for $tag in $tags
      where starts-with($tag, "author ")
      return $clean(substring-after($tag, "author "))
    let $version :=
      for $tag in $tags
      where starts-with($tag, "version ")
      return $clean(substring-after($tag, "version "))
    let $since :=
      for $tag in $tags
      where starts-with($tag, "since ")
      return $clean(substring-after($tag, "since "))
    let $see :=
      for $tag in $tags
      where starts-with($tag, "see ")
      return $clean(substring-after($tag, "see "))
    let $deprecated :=
      for $tag in $tags
      where starts-with($tag, "deprecated ")
      return $clean(substring-after($tag, "deprecated "))
    let $error :=
      for $tag in $tags
      where starts-with($tag, "error ")
      return $clean(substring-after($tag, "error "))
    return map {
      "description": $description,
      "params": array { $params },
      "return": string-join($return, " "),
      "author": string-join($author, ", "),
      "version": string-join($version, " "),
      "since": string-join($since, " "),
      "see": $see,
      "deprecated": string-join($deprecated, " "),
      "error": $error
    }
};

(:~
 : Build xqdoc:comment element from parsed tags.
 :)
declare function local:build-comment($tags as map(*)) as element(xqdoc:comment) {
  <xqdoc:comment>
    <xqdoc:description>{$tags("description")}</xqdoc:description>
    {for $p in $tags("params")?*
     return <xqdoc:param>{$p("name")} - {$p("description")}</xqdoc:param>}
    {if ($tags("return") != "") then <xqdoc:return>{$tags("return")}</xqdoc:return> else ()}
    {if ($tags("author") != "") then <xqdoc:author>{$tags("author")}</xqdoc:author> else ()}
    {if ($tags("version") != "") then <xqdoc:version>{$tags("version")}</xqdoc:version> else ()}
    {if ($tags("since") != "") then <xqdoc:since>{$tags("since")}</xqdoc:since> else ()}
    {for $s in $tags("see") return <xqdoc:see>{$s}</xqdoc:see>}
    {if ($tags("deprecated") != "") then <xqdoc:deprecated>{$tags("deprecated")}</xqdoc:deprecated> else ()}
    {for $e in $tags("error") return <xqdoc:error>{$e}</xqdoc:error>}
  </xqdoc:comment>
};

(:~
 : Strip surrounding quotes from a string literal token.
 : The REx parser preserves the quote characters in the AST text.
 :)
declare function local:unquote($s as xs:string) as xs:string {
  let $trimmed := normalize-space($s)
  return
    if ((starts-with($trimmed, '"') and ends-with($trimmed, '"')) or
        (starts-with($trimmed, "'") and ends-with($trimmed, "'"))) then
      substring($trimmed, 2, string-length($trimmed) - 2)
    else
      $trimmed
};

(:~
 : Serialize a SequenceType AST subtree back to its XQuery string form.
 : Walks child elements recursively and concatenates their text content
 : with appropriate spacing.
 :)
declare function local:serialize-type($node as element()) as xs:string {
  normalize-space(string-join(local:serialize-node($node), ""))
};

(:~
 : Recursive helper to serialize an AST node back to source text.
 : For leaf text nodes, returns the text; for elements, recurses.
 :)
declare function local:serialize-node($node as node()) as xs:string* {
  typeswitch ($node)
    case text() return
      let $t := normalize-space($node)
      return if ($t != "") then $t else ()
    case element() return
      for $child in $node/node()
      return local:serialize-node($child)
    default return ()
};

(:~
 : Extract the function name from an UnreservedFunctionEQName element.
 : This handles both prefixed (QName) and URIQualified names.
 :)
declare function local:function-name($func-decl as element()) as xs:string {
  let $eqname := $func-decl/UnreservedFunctionEQName
  return
    if ($eqname) then
      normalize-space(string-join(local:serialize-node($eqname), ""))
    else
      "(anonymous)"
};

(:~
 : Extract parameters from a ParamListWithDefaults element.
 : Each ParamWithDefault contains a VarNameAndType with $name and optional TypeDeclaration.
 :)
declare function local:extract-params($param-list as element()?) as element(xqdoc:parameter)* {
  if (empty($param-list)) then ()
  else
    for $param in $param-list/ParamWithDefault
    let $vnt := $param/VarNameAndType
    let $var-name := "$" || normalize-space(string-join(local:serialize-node($vnt/EQName), ""))
    let $type-decl := $vnt/TypeDeclaration
    let $type :=
      if ($type-decl) then
        (: TypeDeclaration starts with "as", skip it and serialize the SequenceType :)
        let $seq-type := $type-decl/SequenceType
        return
          if ($seq-type) then local:serialize-type($seq-type)
          else local:serialize-type($type-decl)
      else
        ()
    return
      <xqdoc:parameter>
        <xqdoc:name>{$var-name}</xqdoc:name>
        {if ($type) then <xqdoc:type>{$type}</xqdoc:type> else ()}
      </xqdoc:parameter>
};

(:~
 : Build the function signature string from the AST.
 :)
declare function local:build-signature(
  $name as xs:string,
  $params as element(xqdoc:parameter)*,
  $return-type as xs:string?,
  $annotations as xs:string*
) as xs:string {
  let $ann-str :=
    if (exists($annotations)) then
      string-join(for $a in $annotations return "%" || $a, " ") || " "
    else ""
  let $param-str := string-join(
    for $p in $params
    return
      if ($p/xqdoc:type) then
        string($p/xqdoc:name) || " as " || string($p/xqdoc:type)
      else
        string($p/xqdoc:name),
    ", "
  )
  let $ret-str :=
    if ($return-type) then " as " || $return-type
    else ""
  return
    "declare " || $ann-str || "function " || $name || "(" || $param-str || ")" || $ret-str
};

(:~
 : Extract annotations from the AST. Annotations appear as Annotation elements
 : directly inside FunctionDecl or VarDecl, before the 'function'/'variable' keyword.
 :)
declare function local:extract-annotations($decl as element()) as element(xqdoc:annotation)* {
  for $ann in $decl/Annotation
  let $name := normalize-space(string-join(local:serialize-node($ann/EQName), ""))
  let $literals :=
    for $const in $ann/Constant
    return normalize-space(string-join(local:serialize-node($const), ""))
  return
    <xqdoc:annotation name="{$name}">
      {for $lit in $literals return <xqdoc:literal>{$lit}</xqdoc:literal>}
    </xqdoc:annotation>
};

(:~
 : Extract the return type from a FunctionDecl.
 : The TypeDeclaration that is a direct child of FunctionDecl (not inside
 : ParamListWithDefaults) is the return type.
 :)
declare function local:extract-return-type($func-decl as element()) as xs:string? {
  let $type-decl := $func-decl/TypeDeclaration
  return
    if ($type-decl) then
      let $seq-type := $type-decl/SequenceType
      return
        if ($seq-type) then local:serialize-type($seq-type)
        else local:serialize-type($type-decl)
    else
      ()
};

(:~
 : Process a single FunctionDecl element from the AST.
 :)
declare function local:process-function($func-decl as element()) as element(xqdoc:function) {
  let $name := local:function-name($func-decl)
  let $param-list := $func-decl/ParamListWithDefaults
  let $params := local:extract-params($param-list)
  let $arity := count($params)
  let $return-type := local:extract-return-type($func-decl)
  let $annotations := local:extract-annotations($func-decl)
  let $ann-names :=
    for $ann in $annotations
    return string($ann/@name)
  let $signature := local:build-signature($name, $params, $return-type, $ann-names)
  let $comment-text := local:find-xqdoc-comment($func-decl)
  let $tags := local:parse-xqdoc-tags($comment-text)
  return
    <xqdoc:function arity="{$arity}">
      {local:build-comment($tags)}
      <xqdoc:name>{$name}</xqdoc:name>
      {if (exists($annotations)) then
        <xqdoc:annotations>{$annotations}</xqdoc:annotations>
      else ()}
      <xqdoc:signature>{$signature}</xqdoc:signature>
      {if (exists($params)) then
        <xqdoc:parameters>{$params}</xqdoc:parameters>
      else ()}
      {if ($return-type) then
        <xqdoc:return>
          <xqdoc:type>{$return-type}</xqdoc:type>
        </xqdoc:return>
      else ()}
    </xqdoc:function>
};

(:~
 : Process a VarDecl element from the AST.
 :)
declare function local:process-variable($var-decl as element()) as element(xqdoc:variable) {
  let $vnt := $var-decl/VarNameAndType
  let $var-name := "$" || normalize-space(string-join(local:serialize-node($vnt/EQName), ""))
  let $type-decl := $vnt/TypeDeclaration
  let $type :=
    if ($type-decl) then
      let $seq-type := $type-decl/SequenceType
      return
        if ($seq-type) then local:serialize-type($seq-type)
        else local:serialize-type($type-decl)
    else
      ()
  let $annotations := local:extract-annotations($var-decl)
  let $comment-text := local:find-xqdoc-comment($var-decl)
  let $tags := local:parse-xqdoc-tags($comment-text)
  return
    <xqdoc:variable>
      {local:build-comment($tags)}
      <xqdoc:name>{$var-name}</xqdoc:name>
      {if (exists($annotations)) then
        <xqdoc:annotations>{$annotations}</xqdoc:annotations>
      else ()}
      {if ($type) then
        <xqdoc:type>{$type}</xqdoc:type>
      else ()}
    </xqdoc:variable>
};

(:~
 : Process NamespaceDecl elements from the AST.
 : NamespaceDecl contains: 'declare' 'namespace' NCName '=' URILiteral
 :)
declare function local:process-namespace-decl($ns-decl as element()) as element(xqdoc:namespace) {
  let $prefix := normalize-space(string($ns-decl/NCName))
  let $uri := local:unquote(normalize-space(string($ns-decl/URILiteral)))
  return
    <xqdoc:namespace prefix="{$prefix}" uri="{$uri}"/>
};

(:~
 : Process ModuleImport elements from the AST.
 : ModuleImport: 'import' 'module' ('namespace' NCName '=')? URILiteral ...
 :)
declare function local:process-module-import($import as element()) as element(xqdoc:import) {
  let $prefix := normalize-space(string($import/NCName))
  let $uris := $import/URILiteral
  let $uri := if (exists($uris)) then local:unquote(normalize-space(string($uris[1]))) else ""
  return
    <xqdoc:import type="library">
      <xqdoc:uri>{$uri}</xqdoc:uri>
      {if ($prefix != "") then
        <xqdoc:prefix>{$prefix}</xqdoc:prefix>
      else ()}
    </xqdoc:import>
};

(:~
 : Process SchemaImport elements from the AST.
 :)
declare function local:process-schema-import($import as element()) as element(xqdoc:import) {
  let $prefix-elem := $import/SchemaPrefix
  let $prefix :=
    if ($prefix-elem/NCName) then normalize-space(string($prefix-elem/NCName))
    else ""
  let $uris := $import/URILiteral
  let $uri := if (exists($uris)) then local:unquote(normalize-space(string($uris[1]))) else ""
  return
    <xqdoc:import type="schema">
      <xqdoc:uri>{$uri}</xqdoc:uri>
      {if ($prefix != "") then
        <xqdoc:prefix>{$prefix}</xqdoc:prefix>
      else ()}
    </xqdoc:import>
};

(: ========== Main ========== :)

let $source-text := unparsed-text($source)
let $ast := p:parse-XQuery($source-text)
return
  if ($ast instance of element(ERROR)) then
    <xqdoc:xqdoc xmlns:xqdoc="http://www.xqdoc.org/1.0">
      <xqdoc:control>
        <xqdoc:date>{current-dateTime()}</xqdoc:date>
        <xqdoc:version>1.0</xqdoc:version>
      </xqdoc:control>
      <xqdoc:error>{string($ast)}</xqdoc:error>
    </xqdoc:xqdoc>
  else

let $module := $ast/self::XQuery

(: Determine module type :)
let $lib-module := $module//LibraryModule
let $main-module := $module//MainModule
let $is-library := exists($lib-module)
let $module-type := if ($is-library) then "library" else "main"

(: Extract module declaration (library modules only) :)
let $module-decl := $module//ModuleDecl
let $module-prefix :=
  if ($module-decl) then normalize-space(string($module-decl/NCName))
  else ""
let $module-uri :=
  if ($module-decl) then local:unquote(normalize-space(string($module-decl/URILiteral)))
  else ""

(: Extract the module-level xqdoc comment :)
let $module-element := if ($is-library) then $lib-module else $main-module
let $module-comment-text := local:find-xqdoc-comment($module-element)
let $module-tags := local:parse-xqdoc-tags($module-comment-text)

(: Find all function declarations :)
let $func-decls := $module//FunctionDecl

(: Find all variable declarations :)
let $var-decls := $module//VarDecl

(: Find all namespace declarations :)
let $ns-decls := $module//NamespaceDecl

(: Find all imports :)
let $imports := $module//Import

return
  <xqdoc:xqdoc xmlns:xqdoc="http://www.xqdoc.org/1.0">
    <xqdoc:control>
      <xqdoc:date>{current-dateTime()}</xqdoc:date>
      <xqdoc:version>1.0</xqdoc:version>
    </xqdoc:control>

    <xqdoc:module type="{$module-type}">
      <xqdoc:uri>{$module-uri}</xqdoc:uri>
      {if ($module-prefix != "") then
        <xqdoc:name>{$module-prefix}</xqdoc:name>
      else ()}
      {local:build-comment($module-tags)}
    </xqdoc:module>

    {if (exists($imports)) then
      <xqdoc:imports>
        {for $imp in $imports
         return
           if ($imp/ModuleImport) then
             local:process-module-import($imp/ModuleImport)
           else if ($imp/SchemaImport) then
             local:process-schema-import($imp/SchemaImport)
           else ()
        }
      </xqdoc:imports>
    else ()}

    {if (exists($ns-decls)) then
      <xqdoc:namespaces>
        {for $ns in $ns-decls
         return local:process-namespace-decl($ns)
        }
      </xqdoc:namespaces>
    else ()}

    {if (exists($var-decls)) then
      <xqdoc:variables>
        {for $v in $var-decls
         return local:process-variable($v)
        }
      </xqdoc:variables>
    else ()}

    {if (exists($func-decls)) then
      <xqdoc:functions>
        {for $f in $func-decls
         return local:process-function($f)
        }
      </xqdoc:functions>
    else ()}
  </xqdoc:xqdoc>
