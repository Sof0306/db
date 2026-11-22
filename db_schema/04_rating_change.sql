set search_path to podoprigora_food, exts;

create or replace function rating_change() returns trigger as $$
begin
	if tg_op = 'UPDATE' or tg_op = 'DELETE' then
		if old.entity_type = 'блюдо' then
			update product
			set rating = (
				select round(avg(r.rating), 2)
				from review r
				where r.entity_type = 'блюдо' and r.entity_id = old.entity_id
			)
			where product_id = old.entity_id;
		elseif old.entity_type = 'ресторан' then
			update restaurant
			set rating = (
				select round(avg(r.rating), 2)
				from review r
				where r.entity_type = 'ресторан' and r.entity_id = old.entity_id
			)
			where restaurant_id = old.entity_id;
		end if;
	end if;

	if tg_op = 'INSERT' or tg_op = 'UPDATE' then
		if new.entity_type = 'блюдо' then
			update product
			set rating = (
				select round(avg(r.rating), 2)
				from review r
				where r.entity_type = 'блюдо' and r.entity_id = new.entity_id
			)
			where product_id = new.entity_id;
		elseif new.entity_type = 'ресторан' then
			update restaurant
			set rating = (
				select round(avg(r.rating), 2)
				from review r
				where r.entity_type = 'ресторан' and r.entity_id = new.entity_id
			)
			where restaurant_id = new.entity_id;
		end if;
	end if;

	return null; 
end;
$$ language plpgsql;

create trigger rating_change_tg
after insert or update or delete on review
for each row execute function rating_change();
