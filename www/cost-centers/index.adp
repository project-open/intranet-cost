<master src="/packages/intranet-core/www/admin/master">
<property name="page_title">@page_title;literal@</property>
<property name="main_navbar_label">admin</property>
<property name="admin_navbar_label">admin_cost_centers</property>
<property name="left_navbar">@left_navbar_html;literal@</property>

<h1>@page_title@</h1>
@help_txt;noquote@

<if @inconsistent_count@ gt 0>
<table border=0 bgcolor="#FF8080"><tr><td>
<h3>Inconsistent Cost Centers</h3>
<p><font color=black>The following cost centers have inconsistencies in their parent hierarchy.<br>
Please make sure that the cost center code (for example "CoOpMa" for Company - Operations - Maintencance) <br>
corresponds to the list of it's parents. Each level of CCs should be uniquely marked by a two letter
code.</font></p>
<listtemplate name="inconsistent_parents"></listtemplate>
</td></tr></table>
<br>&nbsp;<br>
</if>


<form action=cost-center-action method=post>
      <%= [export_vars -form {return_url}] %>
      <table width="100%">
      @table_header;noquote@
      @table;noquote@
      </table>
</form>


