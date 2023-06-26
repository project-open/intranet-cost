SELECT acs_log__debug('/packages/intranet-cost/sql/postgresql/upgrade/upgrade-5.1.0.0.0-5.1.0.0.1.sql','');


-- There was en error in the creation of the im_costs_project_idx.
-- The index was there with the right name, but indexing cost_type_id.
drop index if exists im_costs_project_idx;
create index im_costs_project_idx on im_costs(project_id);
