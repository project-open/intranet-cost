<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">#intranet-cost.finance#</property>

<br>
@filter_html;noquote@
<%= [im_costs_navbar $letter "/intranet-cost/list" $next_page_url $previous_page_url [list cost_status_id cost_type_id company_id start_idx order_by how_many view_name letter] "<#_ costs#>"] %>

<form action=/intranet-cost/costs/cost-action method=POST>
<%= [export_form_vars company_id cost_id return_url]%>
  <table width=100% cellpadding=2 cellspacing=2 border=0>
    @table_header_html;noquote@
    @table_body_html;noquote@
    @table_continuation_html;noquote@
    @button_html;noquote@
  </table>
</form>


