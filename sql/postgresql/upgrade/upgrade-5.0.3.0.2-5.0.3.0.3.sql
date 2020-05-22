-- 5.0.3.0.2-5.0.3.0.3.sql
SELECT acs_log__debug('/packages/intranet-cost/sql/postgresql/upgrade/upgrade-5.0.3.0.2-5.0.3.0.3.sql','');


SELECT im_category_new (3740,'Customer Purchase Order','Intranet Cost Type');
SELECT im_category_hierarchy_new(3740,3708); -- Customer Purchase Order is a customer document



-- Setup the "Customer Purchase Order" admin menus for Company Documents
--
create or replace function inline_0 ()
returns integer as $body$
declare
	v_menu			integer;
	v_invoices_new_menu	integer;
	v_finance_menu		integer;
	v_menu_id		integer;
	v_accounting		integer;
	v_senman		integer;
	v_count			integer;
begin
    select group_id into v_senman from groups where group_name = 'Senior Managers';
    select group_id into v_accounting from groups where group_name = 'Accounting';
    select menu_id into v_invoices_new_menu from im_menus where label = 'invoices_customers';
    select menu_id into v_finance_menu from im_menus where label = 'finance';

    select count(*) into v_count from im_menus where label = 'invoices_customers_new_customer_purchase_order';
    IF v_count = 0 THEN
	    v_menu_id := im_menu__new (
		null, 'im_menu', now(), null, null, null,
		'intranet-invoices',			-- package_name
		'invoices_customers_new_customer_purchase_order',	-- label
		'New Customer Purchase Order from scratch',		-- name
		'/intranet-invoices/new?cost_type_id=3740', -- url
		50,					-- sort_order
		v_invoices_new_menu,			-- parent_menu_id
		null					-- visible_tcl
	    );
	
	    PERFORM acs_permission__grant_permission(v_menu_id, v_senman, 'read');
	    PERFORM acs_permission__grant_permission(v_menu_id, v_accounting, 'read');
    END IF;



    select count(*) into v_count from im_menus where label = 'invoices_customers_new_invoice_from_customer_purchase_order';
    IF v_count = 0 THEN
	    v_menu_id := im_menu__new (
		null, 'im_menu', now(), null, null, null,
		'intranet-invoices',			-- package_name
		'invoices_customers_new_invoice_from_customer_purchase_order',	-- label
		'New Customer Invoice from Customer Purchase Order',		-- name
		'/intranet-invoices/new-copy?target_cost_type_id=3700&source_cost_type_id=3740', -- url
		350,					-- sort_order
		v_invoices_new_menu,			-- parent_menu_id
		null					-- visible_tcl
	    );
	
	    PERFORM acs_permission__grant_permission(v_menu_id, v_senman, 'read');
	    PERFORM acs_permission__grant_permission(v_menu_id, v_accounting, 'read');
    END IF;


    select count(*) into v_count from im_menus where label = 'invoices_customers_new_invoice_from_customer_purchase_order';
    IF v_count = 0 THEN
	    v_menu_id := im_menu__new (
		null, 'im_menu', now(), null, null, null,
		'intranet-invoices',			-- package_name
		'invoices_customers_new_invoice_from_customer_purchase_order',	-- label
		'New Customer Invoice from Customer Purchase Order',		-- name
		'/intranet-invoices/new-copy?target_cost_type_id=3700&source_cost_type_id=3740', -- url
		350,					-- sort_order
		v_invoices_new_menu,			-- parent_menu_id
		null					-- visible_tcl
	    );
	
	    PERFORM acs_permission__grant_permission(v_menu_id, v_senman, 'read');
	    PERFORM acs_permission__grant_permission(v_menu_id, v_accounting, 'read');
    END IF;


    select count(*) into v_count from im_menus where label = 'invoices_accounts_receivable';
    IF v_count = 0 THEN
	    v_menu_id := im_menu__new (
		null, 'im_menu', now(), null, null, null,
		'intranet-invoices',			-- package_name
		'invoices_accounts_receivable',		-- label
		'Accounts Receivable',			-- name
		'/intranet-invoices/list?cost_status_id=3802&cost_type_id=3700', -- url
		100,					-- sort_order
		v_finance_menu,				-- parent_menu_id
		null					-- visible_tcl
	    );
	
	    PERFORM acs_permission__grant_permission(v_menu_id, v_senman, 'read');
	    PERFORM acs_permission__grant_permission(v_menu_id, v_accounting, 'read');
    END IF;


    select count(*) into v_count from im_menus where label = 'invoices_accounts_payable';
    IF v_count = 0 THEN
	    v_menu_id := im_menu__new (
		null, 'im_menu', now(), null, null, null,
		'intranet-invoices',			-- package_name
		'invoices_accounts_payable',		-- label
		'Accounts Payable',			-- name
		'/intranet-invoices/list?cost_status_id=3802&cost_type_id=3704', -- url
		110,					-- sort_order
		v_finance_menu,				-- parent_menu_id
		null					-- visible_tcl
	    );
	
	    PERFORM acs_permission__grant_permission(v_menu_id, v_senman, 'read');
	    PERFORM acs_permission__grant_permission(v_menu_id, v_accounting, 'read');
    END IF;



    return 0;
end; $body$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();
