-- /packages/intranet-cost/sql/postgresql/intranet-cost-components-create.sql
--
-- ]project-open[ "Costs" Financial Base Module
-- Copyright (C) 2004 - 2009 ]project-open[
--
-- All rights including reserved. To inquire license terms please 
-- refer to http://www.project-open.com/modules/<module-key>



-------------------------------------------------------------
-- Cost Components
--

-- Show the finance component in a projects "Finance" page
select	im_component_plugin__new (
	null,'im_component_plugin',now(),null,null,null,
	'Project Finance Component',	-- plugin_name
	'intranet-cost',		-- package_name
	'finance',			-- location
	'/intranet/projects/view',	-- page_url
	null,				-- view_name
	50,				-- sort_order
	'im_costs_project_finance_component $user_id $project_id'	-- component_tcl
);


-- Show the finance component (summary view) in a projects "Summary" page
select	im_component_plugin__new (
	null,'im_component_plugin',now(),null,null,null,
	'Project Finance Summary Component',	-- plugin_name
	'intranet-cost',		-- package_name
	'left',				-- location
	'/intranet/projects/view',	-- page_url
	null,				-- view_name
	80,				-- sort_order
	'im_costs_project_finance_component -show_details_p 0 $user_id $project_id'	-- component_tcl
);



-- Show the cost component in companies page
select im_component_plugin__new (
	null,'im_component_plugin',now(),null,null,null,
	'Company Cost Component',	-- plugin_name
	'intranet-cost',		-- package_name
	'left',				-- location
	'/intranet/companies/view',	-- page_url
	null,				-- view_name
	90,				-- sort_order
	'im_costs_company_component $user_id $company_id'	-- component_tcl
);


-- Show profit and loss in companies page
select im_component_plugin__new (
	null,'im_component_plugin',now(),null,null,null,
	'Company Profit Component',	-- plugin_name
	'intranet-cost',		-- package_name
	'left',				-- location
	'/intranet/companies/view',	-- page_url
	null,				-- view_name
	85,				-- sort_order
	'im_costs_company_profit_loss_component -company_id $company_id'	-- component_tcl
);


SELECT im_component_plugin__new (
	null,'im_component_plugin',now(),null,null,null,
	'Top 10 Unpaid Customer Invoices',	-- plugin_name - shown in menu
	'intranet-cost',			-- package_name
	'left',					-- location
	'/intranet-cost/index',			-- page_url
	null,					-- view_name
	10,					-- sort_order
	'
im_ad_hoc_query -format html -package_key intranet-cost "
select	''<a href=/intranet-invoices/view?invoice_id='' || c.cost_id || ''>'' || c.cost_name || ''</a>'' as document_nr,
	''<a href=/intranet-cost/cost-centers/new?cost_center_id='' || c.cost_center_id || ''>'' || im_cost_center_code_from_id(c.cost_center_id) || ''</a>'' as cost_center,
	''<a href=/intranet/companies/view?company_id='' || c.customer_id || ''>'' || im_company__name(c.customer_id) || ''</a>'' as customer_name,
	c.effective_date::date + c.payment_days as due_date,
	c.amount::text || '' '' || c.currency as amount,
	c.paid_amount::text || '' '' || c.paid_currency as paid_amount
from	im_costs c
where	c.cost_type_id = 3700 and
	c.cost_status_id not in (3810, 3814, 3816, 3818)
order by coalesce(c.amount,0) DESC
limit 10
"',
	'lang::message::lookup "" intranet-cost.Top_10_Unpaid_Customer_Invoices "Top 10 Unpaid Customer Invoices"'
);



SELECT im_component_plugin__new (
	null,'im_component_plugin',now(),null,null,null,
	'Top 10 Unpaid Provider Bills',		-- plugin_name - shown in menu
	'intranet-cost',			-- package_name
	'left',					-- location
	'/intranet-cost/index',			-- page_url
	null,					-- view_name
	20,					-- sort_order
	'im_ad_hoc_query -format html -package_key intranet-cost "
select
	''<a href=/intranet-invoices/view?invoice_id='' || c.cost_id || ''>'' || c.cost_name || ''</a>'' as document_nr
	im_cost_center_code_from_id(c.cost_center_id) as cost_center,
	''<a href=/intranet/companies/view?company_id='' || c.provider_id || ''>'' || im_company__name(c.provider_id) || ''</a>'' as provider_name,
	c.effective_date::date + c.payment_days as due_date,
	c.amount::text || '' '' || c.currency as amount,
	c.paid_amount::text || '' '' || c.paid_currency as paid_amount
from	im_costs c
where	c.cost_type_id = 3704 and
	c.cost_status_id not in (3810, 3814, 3816, 3818)
order by coalesce(c.amount,0) DESC
limit 10
"',
	'lang::message::lookup "" intranet-cost.Top_10_Unpaid_Provider_Bills "Top 10 Unpaid Provider Bills"'
);


-- Help Blurb Portlet
SELECT im_component_plugin__new (
        null,'im_component_plugin',now(),null,null,null,
        'Finance Home Page Help',               -- plugin_name
        'intranet-cost',                        -- package_name
        'top',                                  -- location
        '/intranet-cost/index',                 -- page_url
        null,                                   -- view_name
        10,                                     -- sort_order
        'set a [lang::message::lookup "" intranet-core.Finance_Home_Page_Help "
		This page shows a section of possible reports and indicators that might help you
		to obtain a quick overview over your company finance.<br>
		The examples included below can be easily modified and extended to suit your needs. <br>
		Please login as System Administrator and click on the wrench ([im_gif wrench])
		symbols to the right of each portlet.
	"]',
        'lang::message::lookup "" intranet-cost.Help_Blurb "Finance Home Page Help"'
);
