-- /packages/intranet-cost/sql/postgresql/intranet-cost-create.sql
--
-- ]project-open[ "Costs" Financial Base Module
-- Copyright (C) 2004 - 2009 ]project-open[
--
-- All rights including reserved. To inquire license terms please 
-- refer to http://www.project-open.com/modules/<module-key>
--
-- 040207 frank.bergmann@project-open.com
-- 040917 avila@digiteix.com 


select im_menu__del_module('intranet-cost');
select im_component_plugin__del_module('intranet-cost');

\i intranet-cost-common.sql
\i intranet-cost-backup.sql
\i intranet-cost-menus-create.sql
\i intranet-cost-components-create.sql
\i intranet-cost-center-create.sql
\i intranet-price-list-create.sql



-------------------------------------------------------------
-- Costs
--
-- Costs is the superclass for all financial items such as 
-- Invoices, Quotes, Purchase Orders, Bills (from providers), 
-- Travel Costs, Payroll Costs, Fixed Costs, Amortization Costs,
-- etc. in order to allow for simple SQL queries revealing the
-- financial status of a company.
--
-- Costs are also used for controlling, namely by assigning costs
-- to projects, companies and cost centers in order to allow for 
-- (more or less) accurate profit & loss calculation.
-- This assignment sometimes requires to split a large cost item
-- into several smaller items in order to assign them more 
-- accurately to project, companies or cost centers ("redistribution").
--
-- Costs reference acs_objects for customer and provider in order to
-- allow costs to be created for example between an employee and the
-- company in the case of travel costs.
--

SELECT acs_object_type__create_type (
	'im_cost',		-- object_type
	'Cost',			-- pretty_name
	'Costs',		-- pretty_plural
	'acs_object',		-- supertype
	'im_costs',		-- table_name
	'cost_id',		-- id_column
	'im_costs',		-- package_name
	'f',			-- abstract_p
	null,			-- type_extension_table
	'im_cost__name'		-- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_cost', 'im_costs', 'cost_id');


-- Create URLs for viewing/editing costs
delete from im_biz_object_urls where object_type='im_cost';
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_cost','view','/intranet-cost/costs/new?form_mode=display\&cost_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_cost','edit','/intranet-cost/costs/new?form_mode=edit\&cost_id=');


update acs_object_types set
	status_type_table = 'im_costs',
	status_column = 'cost_status_id',
	type_column = 'cost_type_id'
where object_type = 'im_cost';



-- Creating im_costs
create table im_costs (
	cost_id			integer
				constraint im_costs_pk
				primary key
				constraint im_costs_cost_fk
				references acs_objects,
	-- force a name because we may want to use object.name()
	-- later to list cost
	cost_name		varchar(400)
				constraint im_costs_name_nn
				not null,
	-- Nr is a current number to provide a unique 
	-- identifier of a cost item for backup/restore.
	cost_nr			varchar(400)
				constraint im_costs_nr_nn
				not null,
	project_id		integer
				constraint im_costs_project_fk
				references im_projects,
				-- who pays?
	customer_id		integer
				constraint im_costs_customer_nn
				not null
				constraint im_costs_customer_fk
				references acs_objects,
				-- who gets paid?
	cost_center_id		integer
				constraint im_costs_cost_center_fk
				references im_cost_centers,
	provider_id		integer
				constraint im_costs_provider_nn
				not null
				constraint im_costs_provider_fk
				references acs_objects,
	investment_id		integer
				constraint im_costs_inv_fk
				references acs_objects,
	cost_status_id		integer
				constraint im_costs_status_nn
				not null
				constraint im_costs_status_fk
				references im_categories,
	cost_type_id		integer
				constraint im_costs_type_nn
				not null
				constraint im_costs_type_fk
				references im_categories,
	-- reference to an object that has caused this cost,
	-- in particular used by im_repeating_costs
	cause_object_id		integer
				constraint im_costs_cause_fk
				references acs_objects,
	-- HTML (or other) template
	template_id		integer
				constraint im_cost_template_fk
				references im_categories,
	-- when does the invoice start to be valid?
	-- due_date is effective_date + payment_days.
	effective_date		timestamptz,
	-- start_blocks are the first days every month. This allows
	-- for fast monthly grouping
	start_block		timestamptz
				constraint im_costs_startblck_fk
				references im_start_months,
	payment_days		integer,
	-- amount=null means calculated amount, for example
	-- with an invoice
	amount			numeric(12,3),
	currency		char(3) 
				constraint im_costs_currency_fk
				references currency_codes(iso),
	paid_amount		numeric(12,3),
	paid_currency		char(3) 
				constraint im_costs_paid_currency_fk
				references currency_codes(iso),
	-- vat_type is the base for VAT calculation.
	vat_type_id		integer
				constraint im_cost_vat_type_fk
				references im_categories,
	-- % of total price is VAT
	-- VAT may be calculated based on vat_type_id
	vat			numeric(12,5) default 0,
	-- % of total price is TAX
	tax			numeric(12,5) default 0,
	-- Classification of variable against fixed costs
	variable_cost_p		char(1)
				constraint im_costs_var_ck
				check (variable_cost_p in ('t','f')),
	needs_redistribution_p	char(1)
				constraint im_costs_needs_redist_ck
				check (needs_redistribution_p in ('t','f')),
	-- Points to its parent if the parent was distributed
	parent_id		integer
				constraint im_costs_parent_fk
				references im_costs,
	-- Indicates that this cost has been redistributed to
	-- potentially several other costs, so we don't want to
	-- include this item in sums.
	redistributed_p		char(1)
				constraint im_costs_redist_ck
				check (redistributed_p in ('t','f')),
	planning_p		char(1)
				constraint im_costs_planning_ck
				check (planning_p in ('t','f')),
	planning_type_id	integer
				constraint im_costs_planning_type_fk
				references im_categories,
	read_only_p		char(1) default 'f'
				constraint im_costs_read_only_ck
				check (read_only_p in ('t','f')),
	description		text,
	note			text,
	-- Audit fields
	last_modified		timestamptz,
	last_modifying_user	integer
				constraint im_costs_last_mod_user
				references users,
	last_modifying_ip 	varchar(50)
);
create index im_costs_cause_object_idx on im_costs(cause_object_id);
create index im_costs_start_block_idx on im_costs(start_block);


alter table im_projects add column cost_quotes_cache		numeric(12,2) default 0;
alter table im_projects add column cost_invoices_cache		numeric(12,2) default 0;
alter table im_projects add column cost_timesheet_planned_cache	numeric(12,2) default 0;
alter table im_projects add column cost_purchase_orders_cache	numeric(12,2) default 0;
alter table im_projects add column cost_bills_cache		numeric(12,2) default 0;
alter table im_projects add column cost_timesheet_logged_cache	numeric(12,2) default 0;
alter table im_projects add column cost_delivery_notes_cache	numeric(12,2) default 0;
alter table im_projects add column cost_expense_planned_cache	numeric(12,2) default 0;
alter table im_projects add column cost_expense_logged_cache	numeric(12,2) default 0;
alter table im_projects add column reported_hours_cache		numeric(12,2) default 0;
alter table im_projects add column reported_days_cache		numeric(12,2) default 0;
alter table im_projects add column cost_cache_dirty		timestamptz;



-------------------------------------------------------------
-- Create cost sub-types
--

\i intranet-repeating-cost-create.sql
\i intranet-investment-create.sql



-------------------------------------------------------------
-- Cost Functions

create or replace function im_cost__new (
	integer, varchar, timestamptz, integer,	varchar, integer,
	varchar, integer, integer, integer, integer, integer, integer,
	integer, integer, timestamptz, integer, numeric,
	varchar, numeric, numeric, varchar, varchar, varchar, varchar,
	integer, varchar, varchar
)
returns integer as $$
declare
	p_cost_id		alias for $1;		-- cost_id default null
	p_object_type		alias for $2;		-- object_type default 'im_cost'
	p_creation_date		alias for $3;		-- creation_date default now()
	p_creation_user		alias for $4;		-- creation_user default null
	p_creation_ip		alias for $5;		-- creation_ip default null
	p_context_id		alias for $6;		-- context_id default null

	p_cost_name		alias for $7;		-- cost_name default null
	p_parent_id		alias for $8;		-- parent_id default null
	p_project_id		alias for $9;		-- project_id default null
	p_customer_id		alias for $10;		-- customer_id
	p_provider_id		alias for $11;		-- provider_id
	p_investment_id		alias for $12;		-- investment_id default null

	p_cost_status_id	alias for $13;		-- cost_status_id
	p_cost_type_id		alias for $14;		-- cost_type_id
	p_template_id		alias for $15;		-- template_id default null

	p_effective_date	alias for $16;		-- effective_date default now()
	p_payment_days		alias for $17;		-- payment_days default 30
	p_amount		alias for $18;		-- amount default null
	p_currency		alias for $19;		-- currency default 'EUR'
	p_vat			alias for $20;		-- vat default 0
	p_tax			alias for $21;		-- tax default 0

	p_variable_cost_p	alias for $22;		-- variable_cost_p default 'f'
	p_needs_redistribution_p alias for $23;		-- needs_redistribution_p default 'f'
	p_redistributed_p	alias for $24;		-- redistributed_p default 'f'
	p_planning_p		alias for $25;		-- planning_p default 'f'
	p_planning_type_id	alias for $26;		-- planning_type_id default null

	p_note			alias for $27;		-- note default null
	p_description		alias for $28;		-- description default null
	v_cost_cost_id		integer;
 begin
	v_cost_cost_id := acs_object__new (
		p_cost_id,			-- object_id
		p_object_type,			-- object_type
		p_creation_date,		-- creation_date
		p_creation_user,		-- creation_user
		p_creation_ip,			-- creation_ip
		p_context_id,			-- context_id
		't'				-- security_inherit_p
	);

	insert into im_costs (
		cost_id, cost_name, cost_nr,
		project_id, customer_id, provider_id, 
		cost_status_id, cost_type_id,
		template_id, investment_id,
		effective_date, payment_days,
		amount, currency, vat, tax,
		variable_cost_p, needs_redistribution_p,
		parent_id, redistributed_p, 
		planning_p, planning_type_id, 
		description, note
	) values (
		v_cost_cost_id, p_cost_name, v_cost_cost_id,
		p_project_id, p_customer_id, p_provider_id, 
		p_cost_status_id, p_cost_type_id,
		p_template_id, p_investment_id,
		p_effective_date, p_payment_days,
		p_amount, p_currency, p_vat, p_tax,
		p_variable_cost_p, p_needs_redistribution_p,
		p_parent_id, p_redistributed_p, 
		p_planning_p, p_planning_type_id, 
		p_description, p_note
	);

	return v_cost_cost_id;
end;$$ language 'plpgsql';


-- Delete a single cost (if we know its ID...)
create or replace function im_cost__delete (integer)
returns integer as $$
DECLARE
	p_cost_id alias for $1;
begin
	-- Update im_hours relationship
	update	im_hours
	set	cost_id = null
	where	cost_id = p_cost_id;

	-- Erase payments related to this cost item
	delete from im_payments
	where cost_id = p_cost_id;

	-- Erase the im_cost
	delete from im_costs
	where cost_id = p_cost_id;

	-- Erase the acs_rels entries pointing to this cost item
	delete	from acs_rels
	where	object_id_two = p_cost_id;
	delete	from acs_rels
	where	object_id_one = p_cost_id;

	-- Erase the object
	PERFORM acs_object__delete(p_cost_id);
	return 0;
end;$$ language 'plpgsql';


create or replace function im_cost__name (integer)
returns varchar as $$
DECLARE
	p_cost_id	alias for $1;	-- cost_id
	v_name		varchar;
begin
	select	cost_name into v_name from im_costs
	where	cost_id = p_cost_id;

	return v_name;
end;$$ language 'plpgsql';



-- Creating status and type views
create or replace view im_cost_status as
select	category_id as cost_status_id,
	category as cost_status
from 	im_categories
where	category_type = 'Intranet Cost Status' and
	category_id not in (3812);


create or replace view im_cost_types as
select	category_id as cost_type_id, 
	category as cost_type,
	CASE 
	    WHEN category_id = 3700 THEN 'fi_read_invoices'
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
	    WHEN category_id = 3700 THEN 'fi_write_invoices'
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
	    WHEN category_id = 3700 THEN 'invoice'
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


-------------------------------------------------------------
-- Invalidate the cost cache of related projects
-- (set dirty-flag to current date)
-------------------------------------------------------------

create or replace function im_cost_project_cache_invalidator (integer)
returns integer as $$
declare
	p_project_id	alias for $1;
	v_project_id	integer;
	v_count		integer;
	v_parent_id	integer;
	v_last_dirty	timestamptz;
begin
	v_project_id := p_project_id;
	v_count := 20;
	
	WHILE v_project_id is not null AND v_count > 0 LOOP

		-- Get the projects parent and existing dirty flag to continue...
		select parent_id, cost_cache_dirty into v_parent_id, v_last_dirty from im_projects
		where project_id = v_project_id;

		-- Skip if the update if the project cache is already dirty
		-- Also, we keep a record which was the oldest dirty cache,
		-- so that the cleanup orden stays chronologic with the oldest
		-- dirty cache first.
		IF v_last_dirty is not null THEN return v_count; END IF;

		-- Set the "dirty"-flag. There is a sweeper to cleanup afterwards.
		RAISE NOTICE 'im_cost_project_cache_invalidator: invalidating cost cache of project %', p_project_id;
		update im_projects
		set cost_cache_dirty = now()
		where project_id = v_project_id;

		-- Continue with the parent_id
		v_project_id := v_parent_id;

		-- Decrease the loop-protection counter
		v_count := v_count-1;
	END LOOP;

	return v_count;
end;$$ language 'plpgsql';



-------------------------------------------------------------
-- Trigger for im_cost to invalidate project cost cache on changes
-------------------------------------------------------------


create or replace function im_cost_project_cache_up_tr ()
returns trigger as $$
begin
	RAISE NOTICE 'im_cost_project_cache_up_tr: %', new.cost_id;
	PERFORM im_cost_project_cache_invalidator (old.project_id);
	PERFORM im_cost_project_cache_invalidator (new.project_id);
	return new;
end;$$ language 'plpgsql';

CREATE TRIGGER im_costs_project_cache_up_tr
AFTER UPDATE
ON im_costs
FOR EACH ROW
EXECUTE PROCEDURE im_cost_project_cache_up_tr();



-------------------------------------------------------------
-- Costs Insert Trigger

create or replace function im_cost_project_cache_ins_tr ()
returns trigger as $$
begin
	RAISE NOTICE 'im_cost_project_cache_ins_tr: %', new.cost_id;
	PERFORM im_cost_project_cache_invalidator (new.project_id);
	return new;
end;$$ language 'plpgsql';

CREATE TRIGGER im_costs_project_cache_ins_tr
AFTER INSERT
ON im_costs
FOR EACH ROW
EXECUTE PROCEDURE im_cost_project_cache_ins_tr();


-------------------------------------------------------------
-- Costs Delete Trigger

create or replace function im_cost_project_cache_del_tr ()
returns trigger as $$
begin
	RAISE NOTICE 'im_cost_project_cache_del_tr: %', old.cost_id;
	PERFORM im_cost_project_cache_invalidator (old.project_id);
	return new;
end;$$ language 'plpgsql';

CREATE TRIGGER im_costs_project_cache_del_tr
AFTER DELETE
ON im_costs
FOR EACH ROW
EXECUTE PROCEDURE im_cost_project_cache_del_tr();





-------------------------------------------------------------
-- Trigger for im_projects to invalidate project cost cache on changes:
-- Changing the parent_id of a project or setting the parent_id
-- of a project invalidates the cost caches of its superprojects.


-------------------------------------------------------------
-- Project Update Trigger

create or replace function im_project_project_cache_up_tr ()
returns trigger as $$
begin
	RAISE NOTICE 'im_project_project_cache_up_tr: %', new.project_id;

	IF new.parent_id != old.parent_id THEN
		PERFORM im_cost_project_cache_invalidator (old.parent_id);
		PERFORM im_cost_project_cache_invalidator (new.parent_id);
	END IF;

	IF new.parent_id is null AND old.parent_id is not null THEN
		PERFORM im_cost_project_cache_invalidator (old.parent_id);
	END IF;

	IF new.parent_id is not null AND old.parent_id is null THEN
		PERFORM im_cost_project_cache_invalidator (new.parent_id);
	END IF;
	return new;
end;$$ language 'plpgsql';

CREATE TRIGGER im_projects_project_cache_up_tr
AFTER UPDATE
ON im_projects
FOR EACH ROW
EXECUTE PROCEDURE im_project_project_cache_up_tr();



-------------------------------------------------------------
-- Determine the VAT type of a given cost item.
-- ToDo: Move the vat_type _into_ the im_cost as vat_type_id.
--

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

	IF v_cost_type_id not in (3700,3702,3704,3706,3720,3724,3730,3732) THEN
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

	IF v_cost_type_id in (3700,3702,3730,3732)
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




-------------------------------------------------------------
-- Wrapper Functions for DB-independed execution
--

create or replace function im_cost_del (integer) 
returns integer as $$
declare
	p_cost_id alias for $1;
begin
	PERFORM im_cost__delete(p_cost_id);
	return 0;
end;$$ language 'plpgsql';



-------------------------------------------------------------
-- Permissions and Privileges
--
select acs_privilege__create_privilege('view_costs','View Costs','View Costs');
select acs_privilege__add_child('admin', 'view_costs');

select acs_privilege__create_privilege('add_costs','Add Costs','Add Costs');
select acs_privilege__add_child('admin', 'add_costs');

select acs_privilege__create_privilege('fi_view_internal_rates','FI View internal rates','FI View internal rates');
select acs_privilege__add_child('admin', 'fi_view_internal_rates');

select im_priv_create('view_costs','Accounting');
select im_priv_create('view_costs','Senior Managers');

select im_priv_create('add_costs','Accounting');
select im_priv_create('add_costs','Senior Managers');

select im_priv_create('add_costs','Accounting');
select im_priv_create('fi_view_internal_rates', 'Senior Managers');



-------------------------------------------------------------
-- VAT Type
--
-- 42000-42999  Intranet VAT Type (1000)
--
-- Simple VAT setup for service company.
-- The setup defines three areas (Domestic = transactions within
-- the same country, EU and Internatinal) plus the different types
-- of VAT applicable to each of the areas.
-- These tax types are each associated with a numeric value in the
-- im_categories.aux_int1 field that specifies the applicable tax
-- (0, 7 or 19 in this case).

SELECT im_category_new(42000, 'Domestic 0%', 'Intranet VAT Type');
SELECT im_category_new(42010, 'Domestic 7%', 'Intranet VAT Type');
SELECT im_category_new(42020, 'Domestic 16%', 'Intranet VAT Type');
SELECT im_category_new(42030, 'Europe 0%', 'Intranet VAT Type');
SELECT im_category_new(42040, 'Europe 16%', 'Intranet VAT Type');
SELECT im_category_new(42050, 'Internat. 0%', 'Intranet VAT Type');


update im_categories set aux_int1 = 0 where category_id = 42000;
update im_categories set aux_int1 = 7 where category_id = 42010;
update im_categories set aux_int1 = 16 where category_id = 42020;
update im_categories set aux_int1 = 0 where category_id = 42030;
update im_categories set aux_int1 = 16 where category_id = 42040;
update im_categories set aux_int1 = 0 where category_id = 42050;


create or replace view im_vat_types as
select	category_id as vat_type_id,
	category as vat_type,
	aux_int1 as vat
from	im_categories
where	category_type = 'Intranet VAT Type';





-- ------------------------------------------------
-- Return the final customer name for a cost item
--

create or replace function im_cost_get_final_customer_name(integer)
returns varchar as $$
DECLARE
        v_cost_id       alias for $1;
        v_company_name  varchar;
BEGIN
	select	company_name into v_company_name
	from 	im_companies
	where 	company_id in ( 
	        select  company_id
	        from    im_projects
	        where   project_id in (
        	        select  project_id
                	from    im_costs c
	                where   c.cost_id = v_cost_id
        	        )
		);
        return v_company_name;
END;$$ language 'plpgsql';




create or replace function im_cost_nr_from_id (integer)
returns varchar as $$
DECLARE
	p_id	alias for $1;
	v_name	varchar;
BEGIN
	select cost_nr into v_name from im_costs
	where cost_id = p_id;

	return v_name;
end;$$ language 'plpgsql';




-------------------------------------------------------------
-- Cost Center Permissions for Financial Documents
-------------------------------------------------------------

-- Permissions and Privileges
--

-- All privilege - We cannot directly inherit from "read" or "write",
-- because all registered_users have read access to the "SubSite".
--
select acs_privilege__create_privilege('fi_read_all','Read All','Read All');
select acs_privilege__create_privilege('fi_write_all','Write All','Write All');
select acs_privilege__add_child('admin', 'fi_read_all');
select acs_privilege__add_child('admin', 'fi_write_all');

-- Start defining the cost_type specific privileges
--
select acs_privilege__create_privilege('fi_read_invoices','Read Invoices','Read Invoices');
select acs_privilege__create_privilege('fi_write_invoices','Write Invoices','Write Invoices');
select acs_privilege__add_child('fi_read_all', 'fi_read_invoices');
select acs_privilege__add_child('fi_write_all', 'fi_write_invoices');

select acs_privilege__create_privilege('fi_read_quotes','Read Quotes','Read Quotes');
select acs_privilege__create_privilege('fi_write_quotes','Write Quotes','Write Quotes');
select acs_privilege__add_child('fi_read_all', 'fi_read_quotes');
select acs_privilege__add_child('fi_write_all', 'fi_write_quotes');

select acs_privilege__create_privilege('fi_read_bills','Read Bills','Read Bills');
select acs_privilege__create_privilege('fi_write_bills','Write Bills','Write Bills');
select acs_privilege__add_child('fi_read_all', 'fi_read_bills');
select acs_privilege__add_child('fi_write_all', 'fi_write_bills');

select acs_privilege__create_privilege('fi_read_pos','Read Pos','Read Pos');
select acs_privilege__create_privilege('fi_write_pos','Write Pos','Write Pos');
select acs_privilege__add_child('fi_read_all', 'fi_read_pos');
select acs_privilege__add_child('fi_write_all', 'fi_write_pos');

select acs_privilege__create_privilege('fi_read_timesheets','Read Timesheets','Read Timesheets');
select acs_privilege__create_privilege('fi_write_timesheets','Write Timesheets','Write Timesheets');
select acs_privilege__add_child('fi_read_all', 'fi_read_timesheets');
select acs_privilege__add_child('fi_write_all', 'fi_write_timesheets');

select acs_privilege__create_privilege('fi_read_delivery_notes','Read Delivery Notes','Read Delivery Notes');
select acs_privilege__create_privilege('fi_write_delivery_notes','Write Delivery Notes','Write Delivery Notes');
select acs_privilege__add_child('fi_read_all', 'fi_read_delivery_notes');
select acs_privilege__add_child('fi_write_all', 'fi_write_delivery_notes');

select acs_privilege__create_privilege('fi_read_expense_items','Read Expense Items','Read Expense Items');
select acs_privilege__create_privilege('fi_write_expense_items','Write Expense Items','Write Expense Items');
select acs_privilege__add_child('fi_read_all', 'fi_read_expense_items');
select acs_privilege__add_child('fi_write_all', 'fi_write_expense_items');

select acs_privilege__create_privilege('fi_read_expense_bundles','Read Expense Bundles','Read Expense Bundles');
select acs_privilege__create_privilege('fi_write_expense_bundles','Write Expense Bundles','Write Expense Bundles');
select acs_privilege__add_child('fi_read_all', 'fi_read_expense_bundles');
select acs_privilege__add_child('fi_write_all', 'fi_write_expense_bundles');

select acs_privilege__create_privilege('fi_read_repeatings','Read Repeatings','Read Repeatings');
select acs_privilege__create_privilege('fi_write_repeatings','Write Repeatings','Write Repeatings');
select acs_privilege__add_child('fi_read_all', 'fi_read_repeatings');
select acs_privilege__add_child('fi_write_all', 'fi_write_repeatings');

select acs_privilege__create_privilege('fi_read_interco_invoices','Read Interco Invoices','Read Interco Invoices');
select acs_privilege__create_privilege('fi_write_interco_invoices','Write Interco Invoices','Write Interco Invoices');
select acs_privilege__add_child('fi_read_all', 'fi_read_interco_invoices');
select acs_privilege__add_child('fi_write_all', 'fi_write_interco_invoices');

select acs_privilege__create_privilege('fi_read_interco_quotes','Read Interco Quotes','Read Interco Quotes');
select acs_privilege__create_privilege('fi_write_interco_quotes','Write Interco Quotes','Write Interco Quotes');
select acs_privilege__add_child('fi_read_all', 'fi_read_interco_quotes');
select acs_privilege__add_child('fi_write_all', 'fi_write_interco_quotes');

select im_priv_create('fi_read_all','P/O Admins');
select im_priv_create('fi_read_all','Senior Managers');
select im_priv_create('fi_read_all','Accounting');
select im_priv_create('fi_write_all','P/O Admins');
select im_priv_create('fi_write_all','Senior Managers');
select im_priv_create('fi_write_all','Accounting');

