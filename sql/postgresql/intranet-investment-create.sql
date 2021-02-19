-- /packages/intranet-cost/sql/postgresql/intranet-cost-create.sql
--
-- ]project-open[ "Costs" Financial Base Module
-- Copyright (C) 2004 - 2009 ]project-open[
--
-- All rights including reserved. To inquire license terms please 
-- refer to https://www.project-open.com/modules/<module-key>



-------------------------------------------------------------
-- "Investments"
--
-- Investments are purchases of larger "investment items"
-- that are not treated as a cost item immediately.
-- Instead, investments are "amortized" over time
-- (monthly, quarterly or yearly) until their non-amortized
-- valeu is zero. A new cost item cost items is generated for 
-- every amortization interval.
--
-- The amortized amount of costs is calculated by summing up
-- all im_costs with the specific investment_id
--

create table im_investments (
	investment_id		integer
				constraint im_investments_pk
				primary key
				constraint im_investments_fk
				references im_repeating_costs,
	name			text,
	investment_status_id	integer
				constraint im_investments_status_fk
				references im_categories,
	investment_type_id	integer
				constraint im_investments_type_fk
				references im_categories
);

SELECT acs_object_type__create_type (
		'im_investment',	-- object_type
		'Investment',		-- pretty_name
		'Investments',	-- pretty_plural
		'im_repeating_cost',	-- supertype	
		'im_investments',	-- table_name
		'investment_id',	-- id_column
		'im_investment',	-- package_name
		'f',			-- abstract_p
		null,			-- type_extension_table
		'im_investment__name' -- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_investment', 'im_investments', 'investment_id');
insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_investment', 'im_repeating_costs', 'rep_cost_id');
insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_investment', 'im_costs', 'cost_id');


-- Creating URLs for viewing/editing investments
delete from im_biz_object_urls where object_type='im_investment';
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_investment','view','/intranet-cost/investments/new?form_mode=display\&investment_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_investment','edit','/intranet-cost/investments/new?form_mode=edit\&investment_id=');

update acs_object_types set
	status_type_table = 'im_costs',
	status_column = 'cost_status_id',
	type_column = 'cost_type_id'
where object_type = 'im_investment';




create or replace function im_investment_name_from_id (integer)
returns varchar as $$
DECLARE
	p_id	alias for $1;
	v_name	varchar;
BEGIN
	select i.name
	into v_name
	from im_investments
	where investment_id = p_id;

	return v_name;
end;$$ language 'plpgsql';

