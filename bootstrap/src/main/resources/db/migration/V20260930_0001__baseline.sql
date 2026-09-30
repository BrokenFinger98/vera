-- Vera baseline. Timestamp versions avoid collisions between parallel worktrees (spec §9).
-- Merged migrations are immutable: never edit this file, add a new V<timestamp>__*.sql instead.

comment on schema vera is 'Vera platform schema: sys_* system catalog tables, u_* customer tables';
