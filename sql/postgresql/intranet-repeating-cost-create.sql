-- /packages/intranet-cost/sql/postgresql/intranet-repeating-cost-create.sql
--
-- ]project-open[ "Costs" Financial Base Module
-- Copyright (C) 2004 - 2009 ]project-open[
--
-- All rights including reserved. To inquire license terms please 
-- refer to http://www.project-open.com/modules/<module-key>
--
-- 040207 frank.bergmann@project-open.com
-- 040917 avila@digiteix.com 


-------------------------------------------------------------
-- Repeating Costs
--
-- These items generate a new cost every month that they
-- are active.
-- This item is used for diverse types of repeating costs
-- such as employees salaries, rent and utilities costs and
-- investment amortization, so it is kind of "aggregated"
-- to those objects.
--
-- Repeating Costs are a subtype of im_costs. However, we 
-- have to add the constraint later because im_costs 
-- depend on im_investment and im_investment depends on 
-- repeating_costs.
--
-- im_costs.cause_object_id contains the reference to the
-- business object that causes the repetitive cost.

SELECT acs_object_type__create_type (
		'im_repeating_cost',		-- object_type
		'Repeating Cost',		-- pretty_name
		'Repeating Cost',		-- pretty_plural
		'im_cost',			-- supertype
		'im_repeating_costs',		-- table_name
		'rep_cost_id',			-- id_column
		'im_repeating_cost',		-- package_name
		'f',				-- abstract_p
		null,				-- type_extension_table
		'im_repeating_cost__name'	-- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_repeating_cost', 'im_repeating_costs', 'rep_cost_id');
insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_repeating_cost', 'im_costs', 'cost_id');


update acs_object_types set
	status_type_table = 'im_costs',
	status_column = 'cost_status_id',
	type_column = 'cost_type_id'
where object_type = 'im_repeating_cost';


create table im_repeating_costs (
	rep_cost_id		integer
				constraint im_rep_costs_id_pk
				primary key
				constraint im_rep_costs_id_fk
				references im_costs,
	start_date		timestamptz 
				constraint im_rep_costs_start_date_nn
				not null,
	end_date		timestamptz default '2099-12-31'
				constraint im_rep_costs_end_date_nn
				not null,
		constraint im_rep_costs_start_end_date
		check(start_date <= end_date)
);


-- Delete a single cost (if we know its ID...)
create or replace function im_repeating_cost__delete (integer)
returns integer as $$
DECLARE
	p_cost_id alias for $1;
begin
	-- Erase the im_repeating_costs entry
	delete from im_repeating_costs
	where rep_cost_id = p_cost_id;

	-- Erase the object
	PERFORM im_cost__delete(p_cost_id);
	return 0;
end;$$ language 'plpgsql';


create or replace function im_repeating_cost__name (integer)
returns varchar as $$
DECLARE
	p_cost_id	alias for $1;	-- cost_id
	v_name		varchar;
begin
	select	cost_name into v_name from im_costs
	where	cost_id = p_cost_id;

	return v_name;
end;$$ language 'plpgsql';

