<script src="header.js"></script>

<div id="title"> SQL Data Can drive HTML page generation </div>

## Given sql/cursor, generate table/form from column extension configuration

  You can use a sql query to automatically generate a form structure
select a.colname, a.checkbox_value, cursor(select * from dict) from table a where xxxx
PSP.WEB will analyse the sql and find all the names and values and select lists

  You can configure what a column has it's form input name and it's label in form label or table header
We can configure it with serval forms keyed to

* (colname) 
* (table.colname)
* (table.colname.list) or (table.colname.form)
* (table.colname.func) or (table.colname.pack.proc)
* generalized form is ([table|*].colname.[list|form|func|pack.proc])

If a table.colume.func is preferred as 
Its just like css

Every column should have it's extension properties.
A column need to be identifed and a identified column need to have variant set of setting

If table.column has no configuration, use *.column to find a configuration.

parse 'select `a.*, b.*`  from table1 a, table2 b where ...';
p.header_ex will generate

	<col width="..." style="...">
	<thead>
		<th>xxx from column configuration with a(table1).column's list header text</th>
		...
	</thead>

In form

parse 'select `a.*, b.*`  from table1 a, table2 b where ...' to select one row

	<dl>
		<dt> generated from configuration </dt>
		<dd> </dd>
	</dl>
	
### We may use power builder's extension dictionary tables to support our need

<script src="footer.js"></script>
