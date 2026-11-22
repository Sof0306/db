do $$
begin
	if not exists (
		select 1
		from pg_catalog.pg_roles pr
		where pr.rolname = 'inspector'
	) then
		create role inspector with login password 'NetoSQL2025';
	else
		alter role inspector with login password 'NetoSQL2025';
	end if;
end;
$$;

grant all on schema podoprigora_food to inspector;
grant all on all tables in schema podoprigora_food to inspector;
grant usage on schema exts to inspector;
grant usage on schema information_schema to inspector;
grant usage on schema pg_catalog to inspector;
