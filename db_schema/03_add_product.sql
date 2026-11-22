set search_path to podoprigora_food, exts;

create or replace procedure add_product(
	p_restaurant_id uuid,
	p_product_category_id uuid,
	p_name varchar,
	p_price numeric,
	p_status product_status,
	p_description text,
	p_rating numeric default null, 
	p_photo_url text default null 
) as $$
begin

	if not exists (
		select 1
		from restaurant r
		where r.restaurant_id = p_restaurant_id
	) then
		raise exception 'Ресторан с идентификатором % не найден', p_restaurant_id;
	end if;

	if not exists (
		select 1
		from product_category pc
		where pc.product_category_id = p_product_category_id
	) then
		raise exception 'Категория блюда с идентификатором % не найдена', p_product_category_id;
	end if;

	if p_price < 0 then
		raise exception 'Цена блюда не может быть отрицательной (BR-5.3), передано %', p_price;
	end if;

	if p_rating not between 0 and 5 then
		raise exception 'Рейтинг блюда должен быть от 0 до 5 (BR-5.4), передано %', p_rating;
	end if;

	insert into product (product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description)
	values (p_name, p_product_category_id, p_price, p_restaurant_id, p_photo_url, p_rating, p_status, p_description);
end;
$$ language plpgsql;
