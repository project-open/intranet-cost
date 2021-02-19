-- /packages/intranet-cost/sql/postgresql/intranet-cost-menus-create.sql
--
-- ]project-open[ "Costs" Financial Base Module
-- Copyright (C) 2004 - 2009 ]project-open[
--
-- All rights including reserved. To inquire license terms please 
-- refer to https://www.project-open.com/modules/<module-key>


-------------------------------------------------------------
-- Finance Menu System
--

SELECT im_menu__new (
	null,'im_menu',now(),null,null,null,
	'intranet-cost',		-- package_name
	'finance',			-- label
	'Finance',			-- name
	'/intranet-cost/list',		-- url
	800,				-- sort_order
	(select menu_id from im_menus where label = 'main'),	-- parent_menu_id
	null				-- visible_tcl
);
SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'finance'),
	(select group_id from groups where group_name = 'Accounting'),
	'read'
);

SELECT im_menu__new (
	null,'im_menu',now(),null,null,null,
	'intranet-cost',		-- package_name
	'costs_home',			-- label
	'Finance Home',			-- name
	'/intranet-cost/index',		-- url
	10,				-- sort_order
	(select menu_id from im_menus where label = 'finance'),
	null				-- visible_tcl
);
SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'costs_home'),
	(select group_id from groups where group_name = 'Accounting'),
	'read'
);

SELECT im_menu__new (
	null,'im_menu',now(),null,null,	null,
	'intranet-cost',		-- package_name
	'costs',			-- label
	'All Costs',			-- name
	'/intranet-cost/list',		-- url
	80,				-- sort_order
	(select menu_id from im_menus where label = 'finance'),
	null				-- visible_tcl
);
SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'costs'),
	(select group_id from groups where group_name = 'Accounting'),
	'read'
);


SELECT im_menu__new (
	null,'im_menu',now(),null,null,null,
	'intranet-cost',		-- package_name
	'finance_cost_centers',		-- label
	'Cost Centers',			-- name
	'/intranet-cost/cost-centers/index',		-- url
	90,				-- sort_order
	(select menu_id from im_menus where label = 'finance'),
	null				-- visible_tcl
);
SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'finance_cost_centers'),
	(select group_id from groups where group_name = 'Accounting'),
	'read'
);


SELECT im_menu__new (
	null,'im_menu',now(),null,null,null,
	'intranet-cost',		-- package_name
	'cost_new',			-- label
	'New Cost',			-- name
	'/intranet-cost/costs/new',	-- url
	10,				-- sort_order
	(select menu_id from im_menus where label = 'finance'),
	null				-- visible_tcl
);
SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'cost_new'),
	(select group_id from groups where group_name = 'Accounting'),
	'read'
);


SELECT im_menu__new (
	null,'im_menu',now(),null,null,null,
	'intranet-core',	-- package_name
	'project_finance',	-- label
	'Finance',		-- name
	'/intranet/projects/view?view_name=finance',	-- url
	20,			-- sort_order
	(select menu_id from im_menus where label = 'project'),
	null			-- p_visible_tcl
);
SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'project_finance'),
	(select group_id from groups where group_name = 'Accounting'),
	'read'
);

