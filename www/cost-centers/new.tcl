# /packages/intranet-cost/www/cost-centers/new.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Create a new dynamic value or edit an existing one.

    @param form_mode edit or display

    @author frank.bergmann@project-open.com
} {
    cost_center_id:integer,optional
    {return_url "/intranet-cost/cost-centers/index"}
    edit_p:optional
    message:optional
    { form_mode "display" }
    { view_name "" }
}

# ------------------------------------------------------------------
# Default & Security
# ------------------------------------------------------------------

set user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

set action_url "/intranet-cost/cost-centers/new"
set focus "cost_center.var_name"
set page_title "New Cost Center"
if {[info exists cost_center_id]} {
    set cc_name [db_string cc_name "select cost_center_name from im_cost_centers where cost_center_id = :cost_center_id" -default ""]
    set page_title "Cost Center '$cc_name'"

    if {"" == $cc_name} {
	set cc_name "New Cost Center"
    }
}

set context [im_context_bar $page_title]
if {![info exists cost_center_id]} { set form_mode "edit" }
set enable_master_p 1

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set cost_center_parent_options [im_cost_center_options -include_empty 1]
set cost_center_type_options [im_cost_center_type_options]
set cost_center_status_options [im_cost_center_status_options]
set manager_options [im_employee_options]

ad_form \
    -name cost_center \
    -cancel_url $return_url \
    -action $action_url \
    -mode $form_mode \
    -export {next_url user_id return_url} \
    -form {
	cost_center_id:key
	{cost_center_name:text(text) {label Name} {html {size 40}}}
	{cost_center_label:text(text) {label Label} {html {size 30}}}
	{cost_center_code:text(text) {label Code} {html {size 10}}}
	{cost_center_type_id:text(select) {label "Type"} {options $cost_center_type_options} }
	{cost_center_status_id:text(select) {label "Status"} {options $cost_center_status_options} }
	{department_p:text(radio),optional {label Department} {options {{True t} {False f}}} }
	{parent_id:text(select),optional {label "Parent Cost Center"} {options $cost_center_parent_options} }
	{manager_id:text(select),optional {label Manager} {options $manager_options }}
	{description:text(textarea),optional {label Description} {html {cols 40}}}
	{note:text(hidden),optional}
    }

# Fix for problem changing to "edit" form_mode
set form_action [template::form::get_action "cost_center"]
if {"" != $form_action} { set form_mode "edit" }

# Add DynFields to the form
set my_cost_center_id 0
if {[info exists cost_center_id]} { set my_cost_center_id $cost_center_id }
im_dynfield::append_attributes_to_form \
    -object_type "im_cost_center" \
    -form_id cost_center \
    -object_id $my_cost_center_id \
    -form_display_mode $form_mode



ad_form -extend -name cost_center -on_request {
    # Populate elements from local variables

} -select_query {

	select	cc.*
	from	im_cost_centers cc
	where	cc.cost_center_id = :cost_center_id

} -new_data {

    if {[catch {
	set cost_center_id [db_string cost_center_insert {}]
    } err_msg]} {
	global errorInfo
	ns_log Error $errorInfo
	ad_return_complaint 1  "<strong>[lang::message::lookup "" intranet-cost.ErrorCreatingCC "Error creating Cost Center. Please see sql error message for more details:"]</strong> <br/><br/> $errorInfo"
	ad_script_abort
    }
    
    # 2014-02-20 fraber: Generates a strange error.
    # Why was this necessary in the first place?
    # db_dml cost_center_context_update {}

    im_dynfield::attribute_store \
	-object_type "im_cost_center" \
	-object_id $cost_center_id \
	-form_id cost_center
    
    # Write Audit Trail
    im_audit -object_type "im_cost_center" -object_id $cost_center_id -action after_create -status_id $cost_center_status_id -type_id $cost_center_type_id

} -edit_data {

    if {[catch {
	db_dml cost_center_update "
		update im_cost_centers set
			cost_center_name	= :cost_center_name,
			cost_center_label	= :cost_center_label,
			cost_center_code 	= :cost_center_code,
			cost_center_type_id	= :cost_center_type_id,
			cost_center_status_id	= :cost_center_status_id,
			department_p		= :department_p,
			parent_id		= :parent_id,
			manager_id		= :manager_id,
			description		= :description
		where
			cost_center_id = :cost_center_id
    	"
    } err_msg]} {
        global errorInfo
        ns_log Error $errorInfo
        ad_return_complaint 1  "<strong>[lang::message::lookup "" intranet-cost.ErrorUpdatingCC "Error updating Cost Center. Please see sql error message for more details:"]</strong> <br/><br/> $errorInfo"
        ad_script_abort
    }

    # 2014-02-20 fraber: Generates a strange error.
    # Why was this necessary in the first place?
    # db_dml cost_center_context_update {}

    im_dynfield::attribute_store \
	-object_type "im_cost_center" \
	-object_id $cost_center_id \
	-form_id cost_center
    
    # Write Audit Trail
    im_audit -object_type "im_cost_center" -object_id $cost_center_id -action after_update -status_id $cost_center_status_id -type_id $cost_center_type_id

} -on_submit {

	ns_log Notice "new1: on_submit"


} -after_submit {

	ad_returnredirect $return_url
	ad_script_abort
}




# ----------------------------------------------------------------
# Left Navbar
#
set sub_navbar ""
set admin_html "
<ul>
<li><a href=[export_vars -base "/intranet-cost/cost-centers/index" {}]>[lang::message::lookup "" intranet-cost.Admin_Cost_Centers "Admin Cost Centers"]</a>
</ul>
"

append left_navbar_html "
	    <div class=\"filter-block\">
		<div class=\"filter-title\">
		    [lang::message::lookup "" intranet-cost.Admin_Cost_Centers "Admin Cost Centers"]
		</div>
		$admin_html
	    </div>
	    <hr/>
"



# ----------------------------------------------------------------
# Member Component
#

set member_component_html ""
if {[info exists cost_center_id]} {
    set cost_center_code [db_string cc_code "select cost_center_code from im_cost_centers where cost_center_id = :cost_center_id" -default ""]
    set cost_center_code_len [string length $cost_center_code]
set member_sql "

	select	e.employee_id,
		im_name_from_user_id(e.employee_id) as user_name,
		e.department_id,
		cc.cost_center_name as department_name,
		cc.cost_center_code as department_code,
		round(length(cc.cost_center_code) / 2) -2 as indent_level,
		e.availability
	from	im_employees e
		LEFT OUTER JOIN im_cost_centers cc ON (e.department_id = cc.cost_center_id)
	where	e.department_id in (
			select	cost_center_id
			from	im_cost_centers
			where	substring(cost_center_code for :cost_center_code_len) = :cost_center_code
		) and 
		e.employee_id not in (	     -- only natural active persons
				select member_id
				from   group_distinct_member_map
				where  group_id = [im_profile_skill_profile]
			   UNION
				select	u.user_id
				from	users u,
					acs_rels r,
					membership_rels mr
				where	r.rel_id = mr.rel_id and
					r.object_id_two = u.user_id and
					r.object_id_one = -2 and
					mr.member_state != 'approved'
		)
	order by department_code, user_name
"
set html ""
set sum_availability 0
db_foreach cc_members $member_sql {
    set indent_html ""
    for {set i 0} {$i < $indent_level} {incr i} { append indent_html "&nbsp; &nbsp; &nbsp; " }
    if {"" ne $availability} { 
	set sum_availability [expr $sum_availability + $availability]
	append availability "%" 
    }
    append html "<tr>
	<td>$indent_html<a href='[export_vars -base "/intranet-cost/cost-centers/new" {{cost_center_id $department_id}}]'>$department_name</a></td>
	<td><a href='[export_vars -base "/intranet/users/view" {{user_id $employee_id}}]'>$user_name</a></td></td>
	<td align=right>$availability</td>
    </tr>\n"
}
append html "<tr>
	<td></td>
	<td align=right><b>[lang::message::lookup "" intranet-cost.Sum "Sum"]</b></td>
	<td align=right><b>$sum_availability%</b></td>
</tr>\n"



set member_component_html "
<table border=0 cellspacing=1 cellpadding=1>
<tr class=rowtitle>
<td class=rowtitle>[lang::message::lookup "" intranet-cost.Department "Department"]</td>
<td class=rowtitle>[lang::message::lookup "" intranet-cost.Name "Name"]</td>
<td class=rowtitle>[lang::message::lookup "" intranet-cost.Availability "Availability"]</td>
</tr>
$html
</table>
"
}
