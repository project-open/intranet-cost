<if @enable_master_p@><master></if>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context;literal@</property>
<property name="main_navbar_label">finance</property>
<property name="left_navbar">@left_navbar_html;literal@</property>
<property name="sub_navbar">@sub_navbar;literal@</property>
<property name="focus">@focus;literal@</property>

<h2>@page_title@</h2>

<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>


<if @view_name@ eq "component">
    <%= [im_component_page -plugin_id $plugin_id -return_url [export_vars -base "/intranet-cost/cost-centers/new" {cost_center_id}] %>
</if>
<else>
    <%= [im_component_bay top] %>
    <table width="100%">
	<tr valign="top">
	<td width="50%">
		<%= [im_box_header [lang::message::lookup "" intranet-helpdesk.Cost_Center_Details "Cost Center Details"]] %>
		<formtemplate id="cost_center"></formtemplate>
		<%= [im_box_footer] %>
		<%= [im_component_bay left] %>
	</td>
	<td width="50%">
		<%= [im_box_header [lang::message::lookup "" intranet-helpdesk.Members_of_Cost_Center_and_Sub_Cost_Centers "Members of this Cost Center and below"]] %>
		@member_component_html;noquote@
		<%= [im_box_footer] %>
		<%= [im_component_bay right] %>
	</td>
	</tr>
    </table>
    <%= [im_component_bay bottom] %>
</else>
