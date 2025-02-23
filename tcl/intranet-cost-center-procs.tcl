# /packages/intranet-invoices/tcl/intranet-cost-center-procs.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_library {
    Cost Centers

    @author frank.bergann@project-open.com
}

# ---------------------------------------------------------------
# Stati and Types
# ---------------------------------------------------------------

ad_proc -public im_cost_center_type_cost_center {} { return 3001 }
ad_proc -public im_cost_center_type_profit_center {} { return 3002 }
ad_proc -public im_cost_center_type_investment_center {} { return 3003 }
ad_proc -public im_cost_center_type_subdepartment {} { return 3004 }


ad_proc -public im_cost_center_status_active {} { return 3101 }
ad_proc -public im_cost_center_status_inactive {} { return 3102 }


# -----------------------------------------------------------
# 
# -----------------------------------------------------------

ad_proc -public im_cost_center_name { 
    cost_center_id
} {
    Returns the cached name of a cost center
} {
    if {"" == $cost_center_id || ![string is integer $cost_center_id]} { set cost_center_id 0}
    im_security_alert_check_integer -location "im_cost_center_name: cost_center_id" -value $cost_center_id
    return [util_memoize [list db_string ccname "select cost_center_name from im_cost_centers where cost_center_id = $cost_center_id" -default ""]]
}


ad_proc -public im_sub_cost_center_ids {
    cost_center_id
} {
    Returns the list of sub cost centers, order by tree_sortkey.
    Returns 0 if it didn't find the initial cost center
} {
    return [util_memoize [list im_sub_cost_center_ids_helper $cost_center_id]]
}

ad_proc -public im_sub_cost_center_ids_helper {
    cost_center_id
} {
    Returns the list of sub cost centers, order by tree_sortkey.
    Returns 0 if it didn't find the initial cost center
} {
    set cc_code [db_string cc_code "select cost_center_code from im_cost_centers where cost_center_id = :cost_center_id" -default 0]
    if {0 eq $cc_code} { return 0 }

    set sub_cc_sql "
	select cost_center_id
	from   im_cost_centers
	where  substring(cost_center_code for [string length $cc_code]) = :cc_code
	order by cost_center_code
    "
    set result [list]
    db_foreach sub_ccs $sub_cc_sql {
	lappend result $cost_center_id
    }
    return $result
}





# -----------------------------------------------------------
# Permissions
# -----------------------------------------------------------

ad_proc -public im_cost_center_permissions {user_id cost_center_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $cost_center_id.<br>
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
    set cc_admin_id [util_memoize [list db_string cc_admin "select manager_id from im_cost_centers where cost_center_id = $cost_center_id" -default ""]]
    set user_is_cc_admin_p [expr {$user_id == $cc_admin_id}]

    # -----------------------------------------------------
    # Set the permission as the OR-conjunction of provider and customer
    set view 1
    set read 1
    set write [expr {$user_is_admin_p || $user_is_cc_admin_p}]
    set admin $write
}


# -----------------------------------------------------------
# Options & Selects
# -----------------------------------------------------------

ad_proc -public im_cost_center_status_options { {include_empty 1} } { 
    Cost Center status options
} {
    set options [db_list_of_lists cost_center_status_options "
	select	category, category_id 
	from	im_categories
	where	category_type = 'Intranet Cost Center Status' and
		(enabled_p is null OR enabled_p = 't')
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}


ad_proc -public im_cost_center_type_options { {include_empty 1} } { 
    Cost Center type options
} {
    set options [db_list_of_lists cost_center_type_options "
	select	category, category_id 
	from	im_categories
	where	category_type = 'Intranet Cost Center Type' and
		(enabled_p is null OR enabled_p = 't')
    "]
    if {$include_empty} { set options [linsert $options 0 { "" "" }] }
    return $options
}


ad_proc -public im_department_options { {include_empty 0} } {
    Returns a list of all Departments in the company.
} {
    set department_only_p 1
    return [im_cost_center_options -include_empty $include_empty -department_only_p $department_only_p]
}

ad_proc -public im_cost_center_select { 
    { -include_empty 0 } 
    { -include_empty_name "" }
    { -department_only_p 0 } 
    { -show_inactive_cc_p 0 }
    select_name 
    { default "" } 
    { cost_type_id "" } 
} {
    Returns a select box with all Cost Centers in the company.
} {
    set options [im_cost_center_options -include_empty $include_empty -include_empty_name $include_empty_name -department_only_p $department_only_p -cost_type_id $cost_type_id -show_inactive_cc_p $show_inactive_cc_p]

    # Only one option, so 
    # write out string instead of select component
    if {[llength $options] == 1} {
	set cc_entry [lindex $options 0]
	set cc_id [lindex $cc_entry 1]
	set cc_name [string trim [lindex $cc_entry 0]]
	# Replace &nbsp; by " "
	regsub -all {\&nbsp\;} $cc_name " " cc_name
	return "$cc_name <input type=hidden name=\"$select_name\" value=\"$cc_id\">\n"
    }

    return [im_options_to_select_box $select_name $options $default]
}


ad_proc -public im_cost_center_options { 
    { -include_empty 0 } 
    { -include_empty_name "" }
    { -department_only_p 0 } 
    { -cost_type_id ""} 
    { -show_inactive_cc_p 0 } 
} {
    Returns a list of all Cost Centers in the company.
    Takes into account the permission of the user to 
    charge FinDocs to CostCenters
} {
    set user_id [ad_conn user_id]
    set start_center_id [im_cost_center_company]
    set cost_type "Invalid"
    if {"" != $cost_type_id} { set cost_type [db_string ct "select im_category_from_id(:cost_type_id)"] }

    set cost_type_sql ""
    set short_name [im_cost_type_short_name $cost_type_id]

    # Profit-Center-Module (perms on CCs) installed?
    set pcenter_p [util_memoize [list db_string pcent "select count(*) from apm_packages where package_key = 'intranet-cost-center'"]]

    if {$pcenter_p && "" != $cost_type_id} { 
	set cost_type_sql "and im_object_permission_p(cost_center_id, :user_id, 'fi_write_${short_name}s') = 't'\n"
    }

    set department_only_sql ""
    if {$department_only_p} {
	set department_only_sql "and cc.department_p = 't'"
    }

    if { $show_inactive_cc_p } {
	set status_sql "1=1"
    } else {
        set status_sql "cost_center_status_id in (select * from im_sub_categories([im_cost_center_status_active]))"
    }

    set options_sql "
        select	cc.cost_center_name,
                cc.cost_center_id,
                cc.cost_center_label,
    		(length(cc.cost_center_code) / 2) - 1 as indent_level,
		cost_center_status_id
        from	im_cost_centers cc
	where	
		$status_sql
		$department_only_sql
		$cost_type_sql
	order by
		cc.cost_center_code
    "

    set options [list]
    if {$include_empty} { lappend options [list $include_empty_name ""] }

    db_foreach cost_center_options $options_sql {
        set spaces ""
        for {set i 0} {$i < $indent_level} { incr i } {
            append spaces "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
        }
	if { $cost_center_status_id == [im_cost_center_status_inactive] } {
	    # this would not work, investigate when time: lappend options [list "$spaces<span class='select_option_inactive'>$cost_center_name</span>" $cost_center_id]
	    lappend options [list "$spaces$cost_center_name&nbsp;([lang::message::lookup "" intranet-core.Inactive "Inactive"])" $cost_center_id]
	} else {
	    lappend options [list "$spaces$cost_center_name" $cost_center_id]
	}
    }

    if {$include_empty && [llength $options] == 0} {
	set invalid_cc [lang::message::lookup "" intranet-cost.No_CC_permissions_for_cost_type "No CC permissions for \"%cost_type%\""]
	lappend options [list $invalid_cc ""]
    }

    return $options

}


ad_proc -public template::widget::im_cost_center_tree { 
    element_reference 
    tag_attributes 
} {
    ad_form tree widget for cost centers and departments.
    <tt>Usage: {custom {department_only_p 1} {start_cc_id 1234} {include_empty_p 0}}</tt>

    @param start_cc_id
	Set to a cc_id in order to display only a subtree

    @param department_only_p 
	Set to 1 in order to show only departments (subset of CCs)

    @param include_empty_p
	Set to 1 in order to include an empty line at the top

    @param translate_p
	Set to 1 in order to use L10n

    The widget displays a department tree, starting at the top (or start_cc_id).
} {
    # Defaults
    set include_empty_p 1
    set start_cc_id ""
    set department_only_p 1
    set tranlate_p 0
   
    # Get references to parameters (magic...)
    upvar $element_reference element
    array set attributes $tag_attributes
    set field_name $element(name)
    set default_value_list $element(values)

    # Determine parameters
    if { [info exists element(custom)] } {
	set params $element(custom)

	set include_empty_pos [lsearch $params include_empty_p]
	if { $include_empty_pos >= 0 } {
	    set include_empty_p [lindex $params $include_empty_pos+1]
	}
	set department_only_p_pos [lsearch $params department_only_p]
	if { $department_only_p_pos >= 0 } {
	    set department_only_p [lindex $params $department_only_p_pos+1]
	}
	set translate_p_pos [lsearch $params translate_p]
	if { $translate_p_pos >= 0 } {
	    set translate_p [lindex $params $translate_p_pos+1]
	}
    }

    # Determine the default value for the widget
    set default_value ""
    if {[info exists element(value)]} {
	set default_value $element(values)
    }

    # Debug
    if {0} {
	set debug ""
	foreach key [array names element] {
	    set value $element($key)
	    append debug "$key = $value\n"
	}
	ad_return_complaint 1 "<pre>$element(name)\n$debug\n</pre>"
	return
    }

    # Render the widget, depending on the display_mode (edit/display):
    if { "edit" == $element(mode)} {

	return [im_cost_center_select \
		    -include_empty $include_empty_p \
		    -department_only_p $department_only_p \
		    $field_name \
		    $default_value \
	]

    } else {

	if {"" != $default_value && "\{\}" != $default_value} {
	    return [db_string cat "select acs_object__name($default_value)"]

	    # This is an object, not a category...
	    # return [db_string cat "select im_category_from_id($default_value)"]
	}
	return ""
    }
}


ad_proc -public im_costs_default_cost_center_for_user { 
    user_id
} {
    Returns a reasonable default cost center for a given user.
} {
    # For an employee return the department_id:
    set cost_center_id [db_string employee_cost_center "
	select	department_id
	from	im_employees
	where	employee_id = :user_id
    " -default 0]

    if {"" == $cost_center_id || 0 == $cost_center_id} {
	set cost_center_id [im_cost_center_company]
    }

    return $cost_center_id
}


ad_proc -public im_cost_center_company {
} {
    Returns the ID of the "Company - Co" Cost Center
} {
    set cc [util_memoize [list db_string cost_center_company "
	select	cost_center_id
	from	im_cost_centers
	where	cost_center_label = 'company'
    " -default 0]]

    if {0 == $cc} { 
	set cc [util_memoize [list db_string cost_center_company "
		select	cost_center_id
		from	im_cost_centers
		order by length(cost_center_code)
		LIMIT 1
	" -default 0]]
    }

    if {0 == $cc} { ad_return_complaint 1 "Unable to find Cost Center 'company'" }
    return $cc
}


ad_proc -public -deprecated im_cost_center_read_p {
    cost_center_id
    cost_type_id
    user_id
} {
    Returns "1" if the user can read the CC, "0" otherwise.
    This TCL-level query makes sense, because it is cached
    and thus quite cheap to execute, while executing the
    acs_permission__permission_p() query could be quite
    expensive with a considerable number of financial docs.
} {
    if {"" == $cost_center_id} { return 1 }
    return [string equal "t" [util_memoize [list im_cost_center_read_p_helper $cost_center_id $cost_type_id $user_id] 60]]
}

ad_proc -private -deprecated im_cost_center_read_p_helper {
    cost_center_id
    cost_type_id
    user_id
} {
    Returns "t" if the user can read the CC, "f" otherwise.
} {
    # User can read all CCs if no Profit Center Controlling is installed
    set pcenter_p [util_memoize [list db_string pcent "select count(*) from apm_packages where package_key = 'intranet-cost-center'"]]
    if {!$pcenter_p} { return "t" }

    return [db_string cc_perms "
	select	im_object_permission_p(:cost_center_id, :user_id, ct.read_privilege)
	from	im_cost_types ct
	where	ct.cost_type_id = :cost_type_id
    " -default "f"]
}


ad_proc -public im_cc_read_p {
    {-user_id 0}
    {-cost_center_id 0}
    {-cost_type_id 0}
    {-privilege ""}
} {
    Returns "1" if the user can read the CC
} {
    # User can read all CCs if no Profit Center Controlling is installed
    set pcenter_p [util_memoize [list db_string pcent "select count(*) from apm_packages where package_key = 'intranet-cost-center'"]]
    if {!$pcenter_p} { return 1 }
    im_security_alert_check_integer -location "im_cc_read_p: user_id" -value $user_id
    im_security_alert_check_integer -location "im_cc_read_p: cost_type_id" -value $cost_type_id
    im_security_alert_check_integer -location "im_cc_read_p: cost_center_id" -value $cost_center_id
    im_security_alert_check_alphanum -location "im_cc_read_p: privilege" -value $privilege

    # Deal with exceptions
    if {0 == $user_id} { set user_id [ad_conn user_id] }
    if {0 == $cost_center_id} { set cost_center_id [im_cost_center_company] }
    if {0 != $cost_type_id} {
	set privilege [util_memoize [list db_string priv "select read_privilege from im_cost_types where cost_type_id = $cost_type_id" -default ""]]
    }
    if {"" == $privilege} { set privilege "fi_read_all" }

    set true_false [util_memoize [list db_string company_cc_read "select im_object_permission_p($cost_center_id, $user_id, '$privilege')" -default f] 60]
    return [string equal "t" $true_false]
}




ad_proc -public im_cc_write_p {
    {-user_id 0}
    {-cost_center_id 0}
    {-cost_type_id 0}
    {-privilege ""}
} {
    Returns "1" if the user can write the CC
} {
    # User can read all CCs if no Profit Center Controlling is installed
    set pcenter_p [util_memoize [list db_string pcent "select count(*) from apm_packages where package_key = 'intranet-cost-center'"]]
    if {"" == $cost_center_id} { return 1 }
    if {!$pcenter_p} { return 1 }
    im_security_alert_check_integer -location "im_cc_read_p: user_id" -value $user_id
    im_security_alert_check_integer -location "im_cc_read_p: cost_type_id" -value $cost_type_id
    im_security_alert_check_integer -location "im_cc_read_p: cost_center_id" -value $cost_center_id
    im_security_alert_check_alphanum -location "im_cc_read_p: privilege" -value $privilege

    # Deal with exceptions
    if {0 == $user_id} { set user_id [ad_conn user_id] }
    if {0 == $cost_center_id} { set cost_center_id [im_cost_center_company] }
    if {0 != $cost_type_id} {
	set privilege [util_memoize [list db_string priv "select write_privilege from im_cost_types where cost_type_id = $cost_type_id" -default ""]]
    }
    if {"" == $privilege} { set privilege "fi_write_all" }

    set true_false [util_memoize [list db_string company_cc_read "select im_object_permission_p($cost_center_id, $user_id, '$privilege')" -default f] 60]
    if {"t" eq $true_false} { return 1 }

    set true_false [util_memoize [list im_cost_center_write_p_helper $cost_center_id $cost_type_id $user_id] 60]
    return [string equal "t" $true_false]
}


ad_proc -public im_cost_center_write_p {
    cost_center_id
    cost_type_id
    user_id
} {
    Returns "1" if the user can write to the CC, "0" otherwise.
    This TCL-level query makes sense, because it is cached
    and thus quite cheap to execute, while executing the
    acs_permission__permission_p() query could be quite
    expensive with a considerable number of financial docs.
} {
    if {"" == $cost_center_id} { return 1 }
    return [string equal "t" [util_memoize [list im_cost_center_write_p_helper $cost_center_id $cost_type_id $user_id] 60]]
}

ad_proc -public im_cost_center_write_p_helper {
    cost_center_id
    cost_type_id
    user_id
} {
    Returns "t" if the user can write to the CC, "f" otherwise.
} {
    # User can write all CCs if no Profit Center Controlling is installed
    set pcenter_p [util_memoize [list db_string pcent "select count(*) from apm_packages where package_key = 'intranet-cost-center'"]]
    if {!$pcenter_p} { return "t" }

    return [db_string cc_perms "
	select	im_object_permission_p(:cost_center_id, :user_id, ct.write_privilege)
	from	im_cost_types ct
	where	ct.cost_type_id = :cost_type_id
    " -default "f"]
}


ad_proc -public im_user_cost_centers { user_id } {
    Returns the list of all cost-centes of the user
    including sub cost-centers
} {
    # We use util_memoize, user_id may be "" when faking users somehow
    if {"" eq $user_id} { set user_id [ad_conn user_id] }
    if {"" eq $user_id} { set user_id 0 }
    im_security_alert_check_integer -location "im_user_cost_centers: user_id" -value $user_id
    return [util_memoize [list db_list user_ccs "select * from im_user_cost_centers($user_id)"]]
}
