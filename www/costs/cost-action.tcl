# /packages/intranet-costs/www/costs/cost-action.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Purpose: Takes commands from the /intranet-cost/index
    page and deletes costs where marked

    @param return_url the url to return to
    @param group_id group id
    @author frank.bergmann@project-open.com
} {
    { return_url "/intranet-costs/list" }
    del_cost:multiple,optional
    cost_status:array,optional
    object_type:array,optional
    submit
}

set user_id [ad_maybe_redirect_for_registration]
if {![im_permission $user_id add_costs]} {
    ad_return_complaint 1 "<li>You have insufficient privileges to see this page"
    return
}

ns_log Notice "cost-action: submit=$submit"
switch $submit {

    "Save" {
	# Save the stati for the costs on this list
	foreach cost_id [array names cost_status] {
	    set cost_status_id $cost_status($cost_id)
	    ns_log Notice "set cost_status($cost_id) = $cost_status_id"

	    db_dml update_cost_status "update im_costs set cost_status_id=:cost_status_id where cost_id=:cost_id"
	}

	ad_returnredirect $return_url
	return
    }

    "Del" {
	# Maybe the list of costs was empty...
	if {![info exists del_cost]} { 
	    ad_returnredirect $return_url
	    return
	}

	foreach cost_id $del_cost {
	    set otype $object_type($cost_id)
	    # ToDo: Security
#	    db_0or1row delete_cost_item "select ${otype}.del(:cost_id) from dual"

	    im_exec_dml del_cost_item "${otype}_del(:cost_id)"

	    lappend in_clause_list $cost_id
	}
	set cost_where_list "([join $in_clause_list ","])"

	ad_returnredirect $return_url
	return
    }

    default {
	set error "Unknown submit command: '$submit'"
	ad_returnredirect "/error?error=$error"
    }
}

