<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:template match="/users">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
    <meta http-equiv="Content-Type" content="text/html; charset=gb2312"/>
    <title>Untitled Document</title>
    </head>
    <body>
     <h3> server side xslt transform has bug </h3>
     <table id="t" border="1" style="border-collapse:collapse;">
      <xsl:for-each select="user">
        <tr>
          <td><xsl:value-of select="USER_NAME"/></td>
          <td><xsl:value-of select="USER_ID"/></td>
          <td><xsl:value-of select="PASSWORD"/></td>
        </tr>
      </xsl:for-each>
    </table>
    <script>
    <![CDATA[t.onclick = function() { alert('clicked table'); }]]> 
	</script>
    </body>
    </html>
  </xsl:template>
  
</xsl:stylesheet>
