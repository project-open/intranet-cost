ad_page_contract {

    company-profit-loss.tcl
    @author Frank Bergmann (frank.bergmann@project-open.com)
    @date 2012-03-30
}

set current_user_id [auth::require_login]
im_company_permissions $current_user_id $company_id view read write admin
set default_currency [im_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set max_project_name 40

# ------------------------------------------------------
# Company Profit & Loss
# ------------------------------------------------------


set cost_sql "
select	coalesce(sum(round((c.amount * im_exchange_rate(c.effective_date::date, c.currency, :default_currency))::numeric)), 0.0) as amount,
	main_p.project_id,
	substring(main_p.project_name for :max_project_name) as project_name,
	c.cost_type_id
from	im_projects main_p,
	im_projects p,
	im_costs c
where	main_p.parent_id is null and
	main_p.company_id = :company_id and
	p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey) and
	p.project_id = c.project_id
group by
      main_p.project_id, main_p.project_name,
      c.cost_type_id
"

db_foreach cost_info $cost_sql {
    set project_hash($project_id) $project_name
    set key "$project_id-$cost_type_id"
    set costs($key) $amount
}

set lines ""
foreach project_id [array names project_hash] {
    set project_name $project_hash($project_id)
    if {$max_project_name == [string length $project_name]} { set project_name "$project_name..." }
    foreach cost_type_id {3700 3702 3704 3706 3718 3722 3724 3726 3728 3730 3732} {
	set key "$project_id-$cost_type_id"
	if {![info exists costs($key)]} { set costs($key) 0 }
    }
    if {[catch {
	set est_profit [expr {$costs($project_id-3702) - $costs($project_id-3706) - $costs($project_id-3726) - $costs($project_id-3728)}]
    } err_msg]} {
	ns_log Error "$err_msg"
	set est_profit [lang::message::lookup "" intranet-cost.UnableToCalculateEstimatedProfit "Unable to calculate 'Estimated Profit'"]
    }

    if {[catch {
	set profit [expr {$costs($project_id-3700) - $costs($project_id-3704) - $costs($project_id-3718) - $costs($project_id-3722)}]
	set profit_pretty [lc_numeric $profit "%.2f" [lang::user::locale]]
    } err_msg]} {
        ns_log Error "$err_msg"
        set profit_pretty [lang::message::lookup "" intranet-cost.UnableToCalculateProfit "Unable to calculate 'Profit'"]
    }

    if { "" == $costs($project_id-3700) } {set costs($project_id-3700) 0 }
    if { "" == $costs($project_id-3704) } {set costs($project_id-3700) 0 }
    if { "" == $costs($project_id-3718) } {set costs($project_id-3700) 0 }
    if { "" == $costs($project_id-3722) } {set costs($project_id-3700) 0 }

    set line "
 	<tr valign=middle>
	<td><a href=[export_vars -base "/intranet/projects/view" {project_id {view_name finance}}]>$project_name</a></td>
	<td align=right>$est_profit<br>$profit_pretty</td>
	<td align=right>$costs($project_id-3702)<br>[lc_numeric $costs($project_id-3700) "%.2f" [lang::user::locale]]</td> <!-- quote / invoice -->
	<td align=right>$costs($project_id-3706)<br>[lc_numeric $costs($project_id-3704) "%.2f" [lang::user::locale]]</td> <!-- po / bill -->
	<td align=right>$costs($project_id-3726)<br>[lc_numeric $costs($project_id-3718) "%.2f" [lang::user::locale]]</td> <!-- ts budget / ts costs -->
	<td align=right>$costs($project_id-3728)<br>[lc_numeric $costs($project_id-3722) "%.2f" [lang::user::locale]]</td> <!-- expense budget / expenses -->
	</tr>
    "
    append lines $line
}

set html "
<tr valign=middle>
<tr>
	<td class=rowtitle>[lang::message::lookup "" intranet-cost.Project Project]</td>
	<td class=rowtitle>[lang::message::lookup "" intranet-cost.Est_Profit "Est. Profit"]<br>[lang::message::lookup "" intranet-cost.Profit Profit]</td>
	<td class=rowtitle>[lang::message::lookup "" intranet-cost.Quotes Quotes]<br>[lang::message::lookup "" intranet-cost.Invoice Invoices]</td>
	<td class=rowtitle>[lang::message::lookup "" intranet-cost.POs "Prov. POs"]<br>[lang::message::lookup "" intranet-cost.Bill "Prov. Bills"]</td>
	<td class=rowtitle>[lang::message::lookup "" intranet-cost.TS_Budget "TS Budget"]<br>[lang::message::lookup "" intranet-cost.TS_Costs "TS Costs"]</td>
	<td class=rowtitle>[lang::message::lookup "" intranet-cost.Exp_Budget "Exp. Budget"]<br>[lang::message::lookup "" intranet-cost.Exp_Costs "Exp. Costs"]</td>
</tr>
$lines
"

