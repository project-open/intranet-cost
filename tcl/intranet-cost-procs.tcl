# /packages/intranet-invoicing/tcl/intranet-cost-procs.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    Bring together all "components" (=HTML + SQL code)
    related to Costs

    @author frank.bergann@project-open.com
}

# ---------------------------------------------------------------
# Stati and Types
# ---------------------------------------------------------------

# Frequently used Costs Stati
ad_proc -public im_cost_status_created {} { return 3802 }
ad_proc -public im_cost_status_outstanding {} { return 3804 }
ad_proc -public im_cost_status_past_due {} { return 3806 }
ad_proc -public im_cost_status_partially_paid {} { return 3808 }
ad_proc -public im_cost_status_paid {} { return 3810 }
ad_proc -public im_cost_status_deleted {} { return 3812 }
ad_proc -public im_cost_status_filed {} { return 3814 }


# Frequently used Cost Types
ad_proc -public im_cost_type_invoice {} { return 3700 }
ad_proc -public im_cost_type_quote {} { return 3702 }
ad_proc -public im_cost_type_bill {} { return 3704 }
ad_proc -public im_cost_type_po {} { return 3706 }
ad_proc -public im_cost_type_customer_doc {} { return 3708 }
ad_proc -public im_cost_type_provider_doc {} { return 3710 }


# Payment Methods
ad_proc -public im_payment_method_undefined {} { return 800 }
ad_proc -public im_payment_method_cash {} { return 802 }


ad_proc -public im_package_cost_id { } {
} {
    return [util_memoize "im_package_cost_id_helper"]
}

ad_proc -private im_package_cost_id_helper {} {
    return [db_string im_package_core_id {
        select package_id from apm_packages
        where package_key = 'intranet-cost'
    } -default 0]
}




# ---------------------------------------------------------------
# Options for Form elements
# ---------------------------------------------------------------

ad_proc -public im_project_options { {include_empty 1} } { 
    Cost project options
} {
    set options [db_list_of_lists project_options "
	select project_name, project_id
	from im_projects
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -public im_customer_options { {include_empty 1} } { 
    Cost customer options
} {
    set options [db_list_of_lists customer_options "
	select customer_name, customer_id
	from im_customers
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -public im_provider_options { {include_empty 1} } { 
    Cost provider options
} {
    set options [db_list_of_lists provider_options "
	select customer_name, customer_id
	from im_customers
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -public im_cost_type_options { {include_empty 1} } { 
    Cost type options
} {
   set options [db_list_of_lists cost_type_options "
	select cost_type, cost_type_id
	from im_cost_type
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -public im_cost_status_options { {include_empty 1} } { 
    Cost status options
} {
    set options [db_list_of_lists cost_status_options "
	select cost_status, cost_status_id from im_cost_status
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -public im_cost_template_options { {include_empty 1} } { 
    Cost Template options
} {
    set options [db_list_of_lists template_options "
	select category, category_id
	from im_categories
	where category_type = 'Intranet Cost Template'
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -public im_investment_options { {include_empty 1} } { 
    Cost investment options
} {
    set options [db_list_of_lists investment_options "
	select name, investment_id
	from im_investments
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}

ad_proc -public im_currency_options { {include_empty 1} } { 
    Cost currency options
} {
    set options [db_list_of_lists currency_options "
	select iso, iso
	from currency_codes
	where supported_p = 't'
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}


ad_proc -public im_department_options { {include_empty 0} } {
    Returns a list of all Departments in the company.
} {
    set department_only_p 1
    return [im_cost_center_options $include_empty $department_only_p]
}


ad_proc -public im_cost_center_options { {include_empty 0} { department_only_p 0} } {
    Returns a list of all Cost Centers in the company.
} {
    set start_center_id [db_string start_center_id "select cost_center_id from im_cost_centers where cost_center_label='company'" -default 0]

    set department_only_sql ""
    if {$department_only_p} {
	set department_only_sql "and cc.department_p = 't'"
    }

    set options_sql "
        select
                cc.cost_center_name,
                cc.cost_center_id,
                cc.cost_center_label,
                (level-1) as indent_level
        from
                im_cost_centers cc
	where
		1=1
		$department_only_sql
        start with
                cost_center_id = :start_center_id
        connect by
                parent_id = PRIOR cost_center_id"

    set options [list]
    db_foreach cost_center_options $options_sql {
        set spaces ""
        for {set i 0} {$i < $indent_level} { incr i } {
            append spaces "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
        }
        lappend options [list "$spaces$cost_center_name" $cost_center_id]
    }
    return $options
}




ad_proc -public im_costs_navbar { default_letter base_url next_page_url prev_page_url export_var_list {select_label ""} } {
    Returns rendered HTML code for a horizontal sub-navigation
    bar for /intranet-cost/.
    The lower part of the navbar also includes an Alpha bar.<br>
    Default_letter==none marks a special behavious, printing no alpha-bar.
} {
    # -------- Defaults -----------------------------
    set user_id [ad_get_user_id]
    set url_stub [ns_urldecode [im_url_with_query]]
    ns_log Notice "im_costs_navbar: url_stub=$url_stub"

    set sel "<td class=tabsel>"
    set nosel "<td class=tabnotsel>"
    set a_white "<a class=whitelink"
    set tdsp "<td>&nbsp;</td>"

    # -------- Calculate Alpha Bar with Pass-Through params -------
    set bind_vars [ns_set create]
    foreach var $export_var_list {
        upvar 1 $var value
        if { [info exists value] } {
            ns_set put $bind_vars $var $value
            ns_log Notice "im_costs_navbar: $var <- $value"
        }
    }
    set alpha_bar [im_alpha_bar $base_url $default_letter $bind_vars]
    if {[string equal "none" $default_letter]} { set alpha_bar "&nbsp;" }
    if {![string equal "" $prev_page_url]} {
        set alpha_bar "<A HREF=$prev_page_url>&lt;&lt;</A>\n$alpha_bar"
    }

    if {![string equal "" $next_page_url]} {
        set alpha_bar "$alpha_bar\n<A HREF=$next_page_url>&gt;&gt;</A>\n"
    }

    # Get the Subnavbar
    set parent_menu_sql "select menu_id from im_menus where label='finance'"
    set parent_menu_id [db_string parent_admin_menu $parent_menu_sql -default 0]
    set navbar [im_sub_navbar $parent_menu_id "" $alpha_bar "tabnotsel" $select_label]
    return "<!-- navbar1 -->\n$navbar<!-- end navbar1 -->"
}

ad_proc im_next_cost_nr { } {
    Returns the next free cost number

    Cost_nr's look like: 2003_07_123 with the first 4 digits being
    the current year, the next 2 digits the month and the last 3 digits 
    as the current number  within the month.
    Returns "" if there was an error calculating the number.

    The SQL query works by building the maximum of all numeric (the 8 
    substr comparisons of the last 4 digits) cost numbers
    of the current year/month, adding "+1", and contatenating again with 
    the current year/month.

    This procedure has to deal with the case that
    two user are costs projects concurrently. In this case there may
    be a "raise condition", that two costs are created at the same
    moment. This is possible, because we take the cost numbers from
    im_costs_ACTIVE, which excludes costs in the process of
    generation.
    To deal with this situation, the calling procedure has to double check
    before confirming the cost.
} {
    set sql "
select
	to_char(sysdate, 'YYYY_MM')||'_'||
	trim(to_char(1+max(i.nr),'0000')) as cost_nr
from
	(select substr(cost_nr,9,4) as nr from im_costs
	 where substr(cost_nr, 1,7)=to_char(sysdate, 'YYYY_MM')
	 UNION 
	 select '0000' as nr from dual
	) i
where
        ascii(substr(i.nr,1,1)) > 47 and
        ascii(substr(i.nr,1,1)) < 58 and
        ascii(substr(i.nr,2,1)) > 47 and
        ascii(substr(i.nr,2,1)) < 58 and
        ascii(substr(i.nr,3,1)) > 47 and
        ascii(substr(i.nr,3,1)) < 58 and
        ascii(substr(i.nr,4,1)) > 47 and
        ascii(substr(i.nr,4,1)) < 58
"
    set cost_nr [db_string next_cost_nr $sql -default ""]
    ns_log Notice "im_next_cost_nr: cost_nr=$cost_nr"

    return $cost_nr
}



# ---------------------------------------------------------------
# Components
# ---------------------------------------------------------------

ad_proc im_costs_object_list_component { user_id cost_id return_url } {
    Returns a HTML table containing a list of objects
    associated with a particular financial document.
} {

    set bgcolor(0) "class=roweven"
    set bgcolor(1) "class=rowodd"

    set object_list_sql "
	select distinct
	   	o.object_id,
		acs_object.name(o.object_id) as object_name,
		u.url
	from
	        acs_objects o,
	        acs_rels r,
		im_biz_object_urls u
	where
	        r.object_id_one = o.object_id
	        and r.object_id_two = :cost_id
		and u.object_type = o.object_type
		and u.url_type = 'view'
    "

    set ctr 0
    set object_list_html ""
    db_foreach object_list $object_list_sql {
	append object_list_html "
        <tr $bgcolor([expr $ctr % 2])>
          <td>
            <A href=\"$url$object_id\">$object_name</A>
          </td>
          <td>
            <input type=checkbox name=object_ids.$object_id>
          </td>
        </tr>\n"
	incr ctr
    }

    if {0 == $ctr} {
	append object_list_html "
        <tr $bgcolor([expr $ctr % 2])>
          <td><i>No objects found</i></td>
        </tr>\n"
    }

    return "
      <form action=cost-association-action method=post>
      [export_form_vars cost_id return_url]
      <table border=0 cellspacing=1 cellpadding=1>
        <tr>
          <td align=middle class=rowtitle colspan=2>Related Projects</td>
        </tr>
        $object_list_html
        <tr>
          <td align=right>
            <input type=submit name=add_project_action value='Add a Project'>
            </A>
          </td>
          <td>
            <input type=submit name=del_action value='Del'>
          </td>
        </tr>
      </table>
      </form>
    "
}

ad_proc im_costs_customer_component { user_id customer_id } {
    Returns a HTML table containing a list of costs for a particular
    customer.
} {
    return [im_costs_base_component $user_id $customer_id ""]
}

ad_proc im_costs_project_component { user_id project_id } {
    Returns a HTML table containing a list of costs for a particular
    particular project.
} {
    return [im_costs_base_component $user_id "" $project_id]
}


ad_proc im_costs_base_component { user_id {customer_id ""} {project_id ""} } {
    Returns a HTML table containing a list of costs for a particular
    customer or a particular project.
} {
    if {![im_permission $user_id view_costs]} {
	return ""
    }

    set bgcolor(0) " class=roweven "
    set bgcolor(1) " class=rowodd "
    set max_costs 5
    set colspan 5
    set org_project_id $project_id
    set org_customer_id $customer_id

    # Where to link when clicking on an object linke? "edit" or "view"?
    set view_mode "view"

    # ----------------- Compose SQL Query --------------------------------
  
    set extra_where [list]
    set extra_from [list]
    set extra_select [list]
    set object_name ""
    set new_doc_args ""
    if {"" != $customer_id} { 
	lappend extra_where "ci.customer_id=:customer_id" 
	set object_name [db_string object_name "select customer_name from im_customers where customer_id = :customer_id"]
	set new_doc_args "?customer_id=$customer_id"
    }

    if {"" != $project_id} { 
	# Select the costs explicitely associated with a project.
	lappend extra_where "
	ci.cost_id in (
		select distinct cost_id 
		from im_costs 
		where project_id=:project_id
	    UNION
		select distinct object_id_two as cost_id
		from acs_rels
		where object_id_one = :project_id
	)" 
	set object_name [db_string object_name "select project_name from im_projects where project_id = :project_id"]
	set new_doc_args "?project_id=$project_id"
    }

    if {[db_table_exists im_payments]} {
	lappend extra_select "pa.payment_amount"
	lappend extra_select "pa.payment_currency"
	lappend extra_from "
		(select
			sum(amount) as payment_amount, 
			max(currency) as payment_currency,
			cost_id 
		 from im_payments
		 group by cost_id
		) pa
	"
	lappend extra_where "ci.cost_id=pa.cost_id(+)"
    }

    set extra_where_clause [join $extra_where "\n\tand "]
    if {"" != $extra_where_clause} { set extra_where_clause "\n\tand $extra_where_clause" }
    set extra_from_clause [join $extra_from ",\n\t"]
    if {"" != $extra_from_clause} { set extra_from_clause ",\n\t$extra_from_clause" }
    set extra_select_clause [join $extra_select ",\n\t"]
    if {"" != $extra_select_clause} { set extra_select_clause ",\n\t$extra_select_clause" }

    set costs_sql "
select
	ci.*,
	url.url,
        im_category_from_id(ci.cost_status_id) as cost_status,
        im_category_from_id(ci.cost_type_id) as cost_type,
	ci.effective_date + payment_days as calculated_due_date
	$extra_select_clause
from
	im_costs ci,
	acs_objects o,
        (select * from im_biz_object_urls where url_type=:view_mode) url
	$extra_from_clause
where
	ci.cost_id = o.object_id
	and o.object_type = url.object_type
	$extra_where_clause
order by
	ci.effective_date desc
"

    set cost_html "
<table border=0>
  <tr>
    <td colspan=$colspan class=rowtitle align=center>
      Financial Documents
    </td>
  </tr>
  <tr class=rowtitle>
    <td align=center class=rowtitle>Document</td>
    <td align=center class=rowtitle>Type</td>
    <td align=center class=rowtitle>Due</td>
    <td align=center class=rowtitle>Amount</td>
    <td align=center class=rowtitle>Paid</td>
  </tr>
"
    set ctr 1
    set payment_amount ""
    set payment_currency ""
    db_foreach recent_costs $costs_sql {
	append cost_html "
<tr$bgcolor([expr $ctr % 2])>
  <td><A href=\"$url$cost_id\">[string range $cost_name 0 20]</A></td>
  <td>$cost_type</td>
  <td>$calculated_due_date</td>
  <td>$amount $currency</td>
  <td>$payment_amount $payment_currency</td>
</tr>\n"
	incr ctr
	if {$ctr > $max_costs} { break }
    }

    # Restore the original values after SQL selects
    set project_id $org_project_id
    set customer_id $org_customer_id

    if {$ctr > $max_costs} {
	append cost_html "
<tr$bgcolor([expr $ctr % 2])>
  <td colspan=$colspan>
    <A HREF=/intranet-costs/index?status_id=0&[export_url_vars status_id customer_id project_id]>
      more costs...
    </A>
  </td>
</tr>\n"
    }

    if {$ctr == 1} {
	append cost_html "
<tr$bgcolor([expr $ctr % 2])>
  <td colspan=$colspan align=center>
    <I>No financial documents yet for this project</I>
  </td>
</tr>\n"
	incr ctr
    }

    if {"" != $project_id} {
	append cost_html "
<tr>
  <td colspan=$colspan align=right>
    <A href=\"/intranet-translation/purchase-order/new$new_doc_args\">
      <li>Create a new purchase order
    </A>
  </td>
</tr>\n"
    }

    append cost_html "</table>\n"
    return $cost_html
}


ad_proc -public im_cost_type_select { select_name { default "" } { super_type_id 0 } } {
    Returns an html select box named $select_name and defaulted to
    $default with a list of all the cost_types in the system.
    If super_type_id is specified then return only those types "below" super_type.
} {
    set category_type "Intranet Cost Type"
    set bind_vars [ns_set create]
    ns_set put $bind_vars category_type $category_type

    set sql "
	select	c.category_id,
		c.category
        from	im_categories c
        where	c.category_type = :category_type"

    if {$super_type_id} {
        ns_set put $bind_vars super_type_id $super_type_id
        append sql "\n	and c.category_id in (
		select distinct
			child_id
		from	im_category_hierarchy
		where	parent_id = :super_type_id
        )"
    }
    return [im_selection_to_select_box $bind_vars category_select $sql $select_name $default]
}



ad_proc -public im_cost_status_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to
    $default with a list of all the cost status_types in the system
} {
    set include_empty 0
    set options [util_memoize "im_cost_status_options $include_empty"]

    set result "\n<select name=\"$select_name\">\n"
    if {[string equal $default ""]} {
	append result "<option value=\"\"> -- Please select -- </option>"
    }

    foreach option $options {
	set selected ""
	if { [string equal $default [lindex $option 1]]} {
	    set selected " selected"
	}
	append result "\t<option value=\"[util_quote_double_quotes [lindex $option 1]]\" $selected>"
	append result "[lindex $option 0]</option>\n"

    }

    append result "\n</select>\n"
    return $result
}


ad_proc im_cost_payment_method_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to $default 
    with a list of all the partner statuses in the system
} {
    return [im_category_select "Intranet Cost Payment Method" $select_name $default]
}

ad_proc im_cost_template_select { select_name { default "" } } {
    Returns an html select box named $select_name and defaulted to $default 
    with a list of all the partner statuses in the system
} {
    return [im_category_select "Intranet Cost Template" $select_name $default]
}



ad_proc im_costs_select { select_name { default "" } { status "" } { exclude_status "" } } {
    Returns an html select box named $select_name and defaulted to
    $default with a list of all the costs in the system. If status is
    specified, we limit the select box to costs that match that
    status. If exclude status is provided, we limit to states that do not
    match exclude_status (list of statuses to exclude).

} {
    set bind_vars [ns_set create]

    set sql "
select
	i.cost_id,
	i.cost_name
from
	im_costs i
where
	1=1
"

    if { ![empty_string_p $status] } {
	ns_set put $bind_vars status $status
	append sql " and cost_status_id=(select cost_status_id from im_cost_status where cost_status=:status)"
    }

    if { ![empty_string_p $exclude_status] } {
	set exclude_string [im_append_list_to_ns_set $bind_vars cost_status_type $exclude_status]
	append sql " and cost_status_id in (select cost_status_id 
                                                  from im_cost_status 
                                                 where cost_status not in ($exclude_string)) "
    }
    append sql " order by lower(cost_name)"
    return [im_selection_to_select_box $bind_vars "cost_status_select" $sql $select_name $default]
}




