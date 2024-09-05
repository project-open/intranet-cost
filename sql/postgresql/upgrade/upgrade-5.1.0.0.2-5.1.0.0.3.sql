SELECT acs_log__debug('/packages/intranet-cost/sql/postgresql/upgrade/upgrade-5.1.0.0.2-5.1.0.0.3.sql','');


-- Add missing columns
--
create or replace function inline_0 ()
returns integer as $body$
DECLARE
        v_count                 integer;
BEGIN
        -- Check if colum exists in the database
        select count(*) into v_count from user_tab_columns where lower(table_name) = 'im_costs' and lower(column_name) = 'sort_order';
        IF v_count = 0 THEN alter table im_costs add column sort_order integer; END IF;

        return 0;
END;$body$ language 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();
