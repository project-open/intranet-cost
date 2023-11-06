SELECT acs_log__debug('/packages/intranet-cost/sql/postgresql/upgrade/upgrade-5.1.0.0.1-5.1.0.0.2.sql','');


-- Add some more financial document typs

-- SELECT im_category_new (3703,'Order','Intranet Cost Type');
-- SELECT im_category_new (3712,'Provider Travel ???','Intranet Cost Type');
SELECT im_category_new (3752,'Cancellation Invoice','Intranet Cost Type');

-- Cancellation Invoice _is_a_ customer document and an invoice
SELECT im_category_hierarchy_new(3752,3700);
SELECT im_category_hierarchy_new(3752,3708);






update im_component_plugins
set component_tcl = '
im_ad_hoc_query -format html -package_key intranet-cost "
select	''<a href=/intranet-invoices/view?invoice_id='' || c.cost_id || ''>'' || c.cost_name || ''</a>'' as document_nr,
	''<a href=/intranet-cost/cost-centers/new?cost_center_id='' || c.cost_center_id || ''>'' || im_cost_center_code_from_id(c.cost_center_id) || ''</a>'' as cost_center,
	''<a href=/intranet/companies/view?company_id='' || c.customer_id || ''>'' || im_company__name(c.customer_id) || ''</a>'' as customer_name,
	c.effective_date::date + c.payment_days as due_date,
	c.amount::text || '' '' || c.currency as amount,
	c.paid_amount::text || '' '' || c.paid_currency as paid_amount
from	im_costs c
where	c.cost_type_id in (select * from im_sub_categories(3700)) and
	c.cost_status_id not in (3810, 3814, 3816, 3818)
order by coalesce(c.amount,0) DESC
limit 10"'
where plugin_name = 'Top 10 Unpaid Customer Invoices';





create or replace view im_cost_types as
select	category_id as cost_type_id, 
	category as cost_type,
	CASE 
	    WHEN category_id in (3700, 3752) THEN 'fi_read_invoices'
	    WHEN category_id = 3702 THEN 'fi_read_quotes'
	    WHEN category_id = 3704 THEN 'fi_read_bills'
	    WHEN category_id = 3706 THEN 'fi_read_pos'
	    WHEN category_id = 3716 THEN 'fi_read_repeatings'
	    WHEN category_id = 3718 THEN 'fi_read_timesheets'
	    WHEN category_id = 3720 THEN 'fi_read_expense_items'
	    WHEN category_id = 3722 THEN 'fi_read_expense_bundles'
	    WHEN category_id = 3724 THEN 'fi_read_delivery_notes'
	    WHEN category_id = 3730 THEN 'fi_read_interco_invoices'
            WHEN category_id = 3732 THEN 'fi_read_interco_quotes'
	    ELSE 'fi_read_all'
	END as read_privilege,
	CASE 
	    WHEN category_id in (3700, 3752) THEN 'fi_write_invoices'
	    WHEN category_id = 3702 THEN 'fi_write_quotes'
	    WHEN category_id = 3704 THEN 'fi_write_bills'
	    WHEN category_id = 3706 THEN 'fi_write_pos'
	    WHEN category_id = 3716 THEN 'fi_write_repeatings'
	    WHEN category_id = 3718 THEN 'fi_write_timesheets'
	    WHEN category_id = 3720 THEN 'fi_write_expense_items'
	    WHEN category_id = 3722 THEN 'fi_write_expense_bundles'
	    WHEN category_id = 3724 THEN 'fi_write_delivery_notes'
	    WHEN category_id = 3730 THEN 'fi_write_interco_invoices'
	    WHEN category_id = 3732 THEN 'fi_write_interco_quotes'
	    ELSE 'fi_write_all'
	END as write_privilege,
	CASE 
	    WHEN category_id in (3700, 3752) THEN 'invoice'
	    WHEN category_id = 3702 THEN 'quote'
	    WHEN category_id = 3704 THEN 'bill'
	    WHEN category_id = 3706 THEN 'po'
	    WHEN category_id = 3716 THEN 'repcost'
	    WHEN category_id = 3718 THEN 'timesheet'
	    WHEN category_id = 3720 THEN 'expitem'
	    WHEN category_id = 3722 THEN 'expbundle'
	    WHEN category_id = 3724 THEN 'delnote'
	    WHEN category_id = 3730 THEN 'interco_invoices'
	    WHEN category_id = 3732 THEN 'interco_quotes'
	    ELSE 'unknown'
	END as short_name
from 	im_categories
where 	category_type = 'Intranet Cost Type';





create or replace function im_cost_vat_type_from_cost_id (integer)
returns varchar as $$
declare
	p_cost_id			alias for $1;

	v_cost_type_id			integer;
	v_cost_type			varchar;
	v_vat_string			varchar;
	v_vat_type			varchar;
	v_cost_is_invoice_or_quote_p	integer;
	v_internal_country_code		varchar;

	v_customer_country_code		varchar;
	v_customer_spain_p		integer;
	v_customer_eu_p			integer;

	v_provider_country_code		varchar;
	v_provider_spain_p		integer;
	v_provider_eu_p			integer;
begin
	-- Get the relevant information about the cost item
	SELECT
		c.cost_type_id,
		im_category_from_id(c.cost_type_id),
		trim(to_char(coalesce(c.vat,0), '999.9'), '0. '),
		(select o.address_country_code from im_offices o where o.office_id = cust.main_office_id),
		(select o.address_country_code from im_offices o where o.office_id = prov.main_office_id)
	INTO
		v_cost_type_id,
		v_cost_type,
		v_vat_string,
		v_customer_country_code,
		v_provider_country_code
	FROM
		im_companies cust,
		im_companies prov,
		im_costs c
	WHERE
		c.cost_id = p_cost_id and
		c.customer_id = cust.company_id and
		c.provider_id = prov.company_id;

	-- Make sure we get a reasonable number after the trim() operation...
	IF '' = v_vat_string THEN v_vat_string = '0'; END IF;

	-- Determine the country_code of the internal company.
	SELECT	(select address_country_code from im_offices where office_id = c.main_office_id)
	INTO	v_internal_country_code
	from	im_companies c
	where	c.company_path = 'internal';

	IF v_cost_type_id not in (3700,3702,3704,3706,3720,3724,3730,3732,3752) THEN
		return 'invalid cost type: ' || v_cost_type;
	END IF;

	-- check customer characteristics
	IF v_customer_country_code = v_internal_country_code
		THEN v_customer_spain_p := 1;
		ELSE v_customer_spain_p := 0;
	END IF;
	RAISE NOTICE 'im_cost_vat_type_from_cost_id: v_customer_spain_p=%', v_customer_spain_p;
	IF v_customer_country_code in (
			'ad', 'at', 'be', 'bg', 'cy', 'cz', 'de', 'dk', 
			'ee', 'es', 'fi', 'fr', 'gr', 'hr', 'hu', 'ie', 
			'it', 'li', 'lu', 'mt', 'nl', 'no', 'pl', 'pt', 
			'ro', 'se', 'si', 'sk', 'uk') 
		THEN v_customer_eu_p := 1;
		ELSE v_customer_eu_p := 0;
	END IF;
	RAISE NOTICE 'im_cost_vat_type_from_cost_id: v_customer_eu_p=%', v_customer_eu_p;


	-- check provider characteristics
	IF v_provider_country_code = v_internal_country_code
		THEN v_provider_spain_p := 1;
		ELSE v_provider_spain_p := 0;
	END IF;
	RAISE NOTICE 'im_cost_vat_type_from_cost_id: v_provider_spain_p=%', v_provider_spain_p;
	IF v_provider_country_code in (
			'ad', 'at', 'be', 'bg', 'cy', 'cz', 'de', 'dk', 
			'ee', 'es', 'fi', 'fr', 'gr', 'hr', 'hu', 'ie', 
			'it', 'li', 'lu', 'mt', 'nl', 'no', 'pl', 'pt', 
			'ro', 'se', 'si', 'sk', 'uk') 
		THEN v_provider_eu_p := 1;
		ELSE v_provider_eu_p := 0;
	END IF;
	RAISE NOTICE 'im_cost_vat_type_from_cost_id: v_provider_eu_p=%', v_provider_eu_p;

	IF v_cost_type_id in (3700,3702,3730,3732,3752)
		THEN v_cost_is_invoice_or_quote_p := 1;
		ELSE v_cost_is_invoice_or_quote_p := 0;
	END IF;
	RAISE NOTICE 'im_cost_vat_type_from_cost_id: v_cost_is_invoice_or_quote_p=%', v_cost_is_invoice_or_quote_p;
	
	IF v_cost_is_invoice_or_quote_p > 0 THEN
		v_vat_type := 'Intl';
		IF v_customer_eu_p THEN v_vat_type = 'EU'; END IF;
		IF v_customer_spain_p THEN v_vat_type = 'Domestic'; END IF;
		v_vat_type := v_vat_type || ' ' || v_vat_string || '%';
	ELSE
		v_vat_type := 'Intl';
		IF v_provider_eu_p THEN v_vat_type = 'EU'; END IF;
		IF v_provider_spain_p THEN v_vat_type = 'Domestic'; END IF;
		v_vat_type := v_vat_type || ' ' || v_vat_string || '%';
	END IF;

        return v_vat_type;
end;$$ language 'plpgsql';


update im_reports
set report_sql = 'select coalesce(round(sum(amount)), 0) from im_costs where cost_type_id in (select * from im_sub_categories(3700)) and effective_date between now()::date-60 and now()::date-30'
where report_name = 'Revenues';



-- ([join [im_sub_categories [list 3700 3702 3704 3706 3718 3720]] ","])
-- (select * from im_sub_categories(3700))


update im_reports
set report_sql = 'select
        round((invoices - bills - timesheet - expenses) / (invoices+0.000001) * 100, 1) as net_margin
from
        (select
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3700)) and effective_date between now()::date-60 and now()::date-30) as invoices,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3702)) and effective_date between now()::date-60 and now()::date-30) as quotes,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3704)) and effective_date between now()::date-60 and now()::date-30) as bills,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3706)) and effective_date between now()::date-60 and now()::date-30) as pos,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3718)) and effective_date between now()::date-60 and now()::date-30) as timesheet,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3720)) and effective_date between now()::date-60 and now()::date-30) as expenses
        ) base;'
where report_name = 'Net Margin Two Months Ago';

update im_reports
set report_sql = 'select
        round((quotes - pos) / (quotes+0.000001) * 100,1) as prelim_brut_margin
from
        (select
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3700)) and effective_date between now()::date-60 and now()::date-30) as invoices,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3702)) and effective_date between now()::date-60 and now()::date-30) as quotes,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3704)) and effective_date between now()::date-60 and now()::date-30) as bills,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3706)) and effective_date between now()::date-60 and now()::date-30) as pos,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3718)) and effective_date between now()::date-60 and now()::date-30) as timesheet,
        (select sum(amount) from im_costs where cost_type_id in (select * from im_sub_categories(3720)) and effective_date between now()::date-60 and now()::date-30) as expenses
        ) base;'
where report_name = 'Preliminary Bruto Margin Two Months Ago';


