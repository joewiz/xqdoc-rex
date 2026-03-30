<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xqdoc="http://www.xqdoc.org/1.0"
    exclude-result-prefixes="xqdoc">

  <xsl:output method="text" encoding="UTF-8"/>

  <xsl:template match="/">
    <xsl:apply-templates select="xqdoc:xqdoc"/>
  </xsl:template>

  <xsl:template match="xqdoc:xqdoc">
    <!-- Module header -->
    <xsl:apply-templates select="xqdoc:module"/>

    <!-- Namespaces -->
    <xsl:if test="xqdoc:namespaces/xqdoc:namespace">
      <xsl:text>## Namespaces&#10;&#10;</xsl:text>
      <xsl:text>| Prefix | URI |&#10;</xsl:text>
      <xsl:text>|--------|-----|&#10;</xsl:text>
      <xsl:for-each select="xqdoc:namespaces/xqdoc:namespace">
        <xsl:text>| `</xsl:text>
        <xsl:value-of select="@prefix"/>
        <xsl:text>` | `</xsl:text>
        <xsl:value-of select="@uri"/>
        <xsl:text>` |&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>

    <!-- Imports -->
    <xsl:if test="xqdoc:imports/xqdoc:import">
      <xsl:text>## Imports&#10;&#10;</xsl:text>
      <xsl:for-each select="xqdoc:imports/xqdoc:import">
        <xsl:text>- **</xsl:text>
        <xsl:value-of select="@type"/>
        <xsl:text>**: `</xsl:text>
        <xsl:value-of select="xqdoc:uri"/>
        <xsl:text>`</xsl:text>
        <xsl:if test="xqdoc:prefix">
          <xsl:text> (prefix: `</xsl:text>
          <xsl:value-of select="xqdoc:prefix"/>
          <xsl:text>`)</xsl:text>
        </xsl:if>
        <xsl:text>&#10;</xsl:text>
      </xsl:for-each>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>

    <!-- Variables -->
    <xsl:if test="xqdoc:variables/xqdoc:variable">
      <xsl:text>## Variables&#10;&#10;</xsl:text>
      <xsl:for-each select="xqdoc:variables/xqdoc:variable">
        <xsl:text>### </xsl:text>
        <xsl:value-of select="xqdoc:name"/>
        <xsl:text>&#10;&#10;</xsl:text>
        <xsl:if test="xqdoc:type[normalize-space(.) != '']">
          <xsl:text>**Type**: `</xsl:text>
          <xsl:value-of select="xqdoc:type"/>
          <xsl:text>`&#10;&#10;</xsl:text>
        </xsl:if>
        <xsl:if test="xqdoc:annotations/xqdoc:annotation">
          <xsl:text>**Annotations**: </xsl:text>
          <xsl:for-each select="xqdoc:annotations/xqdoc:annotation">
            <xsl:text>`%</xsl:text>
            <xsl:value-of select="@name"/>
            <xsl:text>`</xsl:text>
            <xsl:if test="position() != last()">
              <xsl:text>, </xsl:text>
            </xsl:if>
          </xsl:for-each>
          <xsl:text>&#10;&#10;</xsl:text>
        </xsl:if>
        <xsl:if test="xqdoc:comment/xqdoc:description[normalize-space(.) != '']">
          <xsl:value-of select="xqdoc:comment/xqdoc:description"/>
          <xsl:text>&#10;&#10;</xsl:text>
        </xsl:if>
      </xsl:for-each>
    </xsl:if>

    <!-- Functions -->
    <xsl:if test="xqdoc:functions/xqdoc:function">
      <xsl:text>## Functions&#10;&#10;</xsl:text>
      <xsl:for-each select="xqdoc:functions/xqdoc:function">
        <xsl:text>### </xsl:text>
        <xsl:value-of select="xqdoc:name"/>
        <xsl:text>#</xsl:text>
        <xsl:value-of select="@arity"/>
        <xsl:text>&#10;&#10;</xsl:text>

        <!-- Signature -->
        <xsl:text>```xquery&#10;</xsl:text>
        <xsl:value-of select="xqdoc:signature"/>
        <xsl:text>&#10;```&#10;&#10;</xsl:text>

        <!-- Description -->
        <xsl:if test="xqdoc:comment/xqdoc:description[normalize-space(.) != '']">
          <xsl:value-of select="xqdoc:comment/xqdoc:description"/>
          <xsl:text>&#10;&#10;</xsl:text>
        </xsl:if>

        <!-- Annotations -->
        <xsl:if test="xqdoc:annotations/xqdoc:annotation">
          <xsl:text>**Annotations**: </xsl:text>
          <xsl:for-each select="xqdoc:annotations/xqdoc:annotation">
            <xsl:text>`%</xsl:text>
            <xsl:value-of select="@name"/>
            <xsl:text>`</xsl:text>
            <xsl:if test="position() != last()">
              <xsl:text>, </xsl:text>
            </xsl:if>
          </xsl:for-each>
          <xsl:text>&#10;&#10;</xsl:text>
        </xsl:if>

        <!-- Parameters -->
        <xsl:if test="xqdoc:parameters/xqdoc:parameter">
          <xsl:text>**Parameters**:&#10;&#10;</xsl:text>
          <xsl:for-each select="xqdoc:parameters/xqdoc:parameter">
            <xsl:text>- `</xsl:text>
            <xsl:value-of select="xqdoc:name"/>
            <xsl:text>`</xsl:text>
            <xsl:if test="xqdoc:type">
              <xsl:text> as `</xsl:text>
              <xsl:value-of select="xqdoc:type"/>
              <xsl:text>`</xsl:text>
            </xsl:if>
            <xsl:text>&#10;</xsl:text>
          </xsl:for-each>
          <xsl:text>&#10;</xsl:text>
        </xsl:if>

        <!-- Return type -->
        <xsl:if test="xqdoc:return/xqdoc:type[normalize-space(.) != '']">
          <xsl:text>**Returns**: `</xsl:text>
          <xsl:value-of select="xqdoc:return/xqdoc:type"/>
          <xsl:text>`&#10;&#10;</xsl:text>
        </xsl:if>

        <xsl:text>---&#10;&#10;</xsl:text>
      </xsl:for-each>
    </xsl:if>
  </xsl:template>

  <xsl:template match="xqdoc:module">
    <xsl:text># </xsl:text>
    <xsl:choose>
      <xsl:when test="xqdoc:name[normalize-space(.) != '']">
        <xsl:value-of select="xqdoc:name"/>
        <xsl:text> module</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>Main module</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>&#10;&#10;</xsl:text>

    <xsl:if test="xqdoc:uri[normalize-space(.) != '']">
      <xsl:text>**Namespace**: `</xsl:text>
      <xsl:value-of select="xqdoc:uri"/>
      <xsl:text>`&#10;&#10;</xsl:text>
    </xsl:if>

    <xsl:text>**Type**: </xsl:text>
    <xsl:value-of select="@type"/>
    <xsl:text>&#10;&#10;</xsl:text>

    <xsl:if test="xqdoc:comment/xqdoc:description[normalize-space(.) != '']">
      <xsl:value-of select="xqdoc:comment/xqdoc:description"/>
      <xsl:text>&#10;&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
