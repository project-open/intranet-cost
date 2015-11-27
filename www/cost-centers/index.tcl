# /packages/intranet-cost/www/cost-centers/index.tcl
#
# Copyright (C) 2003 - now Project Open Business Solutions S.L.
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Show the permissions for all cost_centers in the system

    @author frank.bergmann@project-open.com
} {
    { return_url "" }
}

# ------------------------------------------------------
# Defaults & Security
# ------------------------------------------------------

set user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]

if {!$user_is_admin_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set page_title "Cost Centers"
set context_bar [im_context_bar $page_title]
set context ""

set cost_center_url "/intranet-cost/cost-centers/new"
set group_url "/admin/groups/one"

set bgcolor(0) " class=rowodd"
set bgcolor(1) " class=roweven"

if {"" == $return_url} { set return_url [ad_conn url] }


set help_str "<ul><li>To show CC in right order please set 'Cost Center Code' accordingly. For additional help please see 'Context Help' that is provided for this page</li>" 
append help_str "<li><span>Please note:</span><br>Deleting Cost Centers from a productive system should be the exception. Whenever possible, set them to 'inactive'."
append help_str "If a Cost Center is removed from the system, all related costs will be transfered to the default Cost Center 'The Company'.</li></ul>"
set help_txt [lang::message::lookup "" intranet-cost.Cost_Center_help $help_str]


set table_header "
<tr>
  <td class=rowtitle>[im_gif -translate_p 1 del "Delete Cost Center"]</td>
  <td class=rowtitle>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.CostCenter "Cost Center Code"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.Type "Type"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.DepartmentP "Dpt.?"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.CostCenterStatus "Status"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.InheritFrom "Inherit Permsissons From"]</td>
  <td class=rowtitle align=center>[lang::message::lookup "" intranet-cost.Manager "Manager"]</td>
</tr>
"

# ------------------------------------------------------
# Determine employee-cost_center membership
# and store in hash array
# ------------------------------------------------------

set employee_cc_map_sql "
	select	m.cost_center_id,
		e.employee_id as employee_id,
		im_name_from_user_id(e.employee_id) as employee_name
	from	im_cost_centers m,
		im_employees e
	where	e.department_id = m.cost_center_id and
		e.employee_id not in (
			-- Exclude deleted or disabled users
			select  m.member_id
			from    group_member_map m,
				membership_rels mr
			where   m.group_id = acs__magic_object_id('registered_users') and
				m.rel_id = mr.rel_id and
				m.container_id = m.group_id and
				mr.member_state != 'approved'
		)
	order by employee_name, m.cost_center_id
"
db_foreach cost_centers $employee_cc_map_sql {
    set employee_list []
    if {[info exists employee_hash($cost_center_id)]} {
	set employee_list $employee_hash($cost_center_id)
    }
    lappend employee_list "<nobr><a href=[export_vars -base "/intranet/users/view" -override {{user_id $employee_id}}]>$employee_name</a></nobr>"
    set employee_hash($cost_center_id) $employee_list
}


# ------------------------------------------------------
# List Cost Centers
# ------------------------------------------------------

set main_sql "
	select	m.*,
		im_name_from_id(m.cost_center_type_id) as cost_center_type,
		im_name_from_id(m.cost_center_status_id) as cost_center_status,
		length(cost_center_code) / 2 as indent_level,
		im_name_from_user_id(m.manager_id) as manager_name,
		acs_object__name(o.context_id) as context
	from	acs_objects o,
		im_cost_centers m
	where	o.object_id = m.cost_center_id
	order by cost_center_code
"

set table ""
set ctr 0
set old_package_name ""
set space "&nbsp; &nbsp; &nbsp; "
db_foreach cost_centers $main_sql {
    incr ctr
    set object_id $cost_center_id
    set sub_indent ""
    for {set i 1} {$i < $indent_level} {incr i} { append sub_indent $space }

    set employee_list []
    if {[info exists employee_hash($cost_center_id)]} {
	set employee_list $employee_hash($cost_center_id)
    }

    append table "
		<tr$bgcolor([expr {$ctr % 2}])>
		<td><input type=checkbox name=cost_center_id.$cost_center_id></td>
		<td><nobr>$sub_indent <a href=$cost_center_url?cost_center_id=$cost_center_id&return_url=$return_url>$cost_center_name</a></nobr></td>
		<td>$cost_center_code</td>
		<td>$cost_center_type</td>
		<td>$department_p</td>
		<td>$cost_center_status</td>
		<td>$context</td>
		<td><a href=[export_vars -base "/intranet/users/view" -override {{user_id $manager_id}}]>$manager_name</a></td>
		</tr>
    "
    if {{} != $employee_list} {
	append table "
		<tr$bgcolor([expr {$ctr % 2}])><td colspan=2 align=right>&nbsp;</td><td colspan=6>
		[join $employee_list ", "]
		</td></tr>
        "
    }
}

append table "
	<tr>
	  <td colspan='8'><input type='submit' value='Del'></td>
	</tr>
"

append left_navbar_html "
	<div class='filter-block'>
		<div class='filter-title'>#intranet-cost.AdminCostCenter#</div>
		<ul>
		    <li><a href=[export_vars -base new { return_url}]>[lang::message::lookup "" intranet-cost.CreateNewCostCenter "Create new Cost Center"]</a</li>
		</ul>
	</div>
"
