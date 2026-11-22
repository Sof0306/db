set search_path to podoprigora_food, exts;

create or replace procedure insert_test_data(value int) as $$
declare
	v_start date = date_trunc('month', current_date - interval '5 months')::date;

	v_restaurant_statuses restaurant_status[] = enum_range(null::restaurant_status);
	v_product_statuses product_status[] = enum_range(null::product_status);
	v_courier_statuses courier_status[] = enum_range(null::courier_status);
	v_order_statuses order_status[] = enum_range(null::order_status);
	v_payment_types payment_type[] = enum_range(null::payment_type);
	v_entity_types review_entity_type[] = enum_range(null::review_entity_type);

	v_addresses uuid[];
	v_client_addresses uuid[];
	v_categories uuid[];
	v_couriers uuid[];
	v_restaurants uuid[];
	v_clients uuid[] = '{}';
	v_products uuid[] = '{}';
	v_prices numeric[] = '{}';

	v_phone char(12);
	v_client uuid;
	v_product uuid;
	v_price numeric;
	v_restaurant_idx int;
	v_client_idx int;
	v_perm int[];
	v_n int;
	v_idx int;
	v_qty numeric;
	v_first_product uuid;

	v_order_id uuid;
	v_courier uuid;
	v_hire date;
	v_dismissal date;
	v_from timestamp;
	v_to timestamp;
	v_ts timestamp;
	v_delivery timestamp;
	v_status order_status;
	v_sum numeric;
	v_total numeric;
	v_entity_type review_entity_type;
	v_entity_id uuid;
	v_month timestamp;
begin
	with ins as (
		insert into address (street, house_number, apartment_office)
		select 'ул. ' || substring(md5(random()::text), 1, 20),
			(1 + floor(random() * 200))::int::text,
			case when random() < 0.5 then null else (1 + floor(random() * 300))::int::text end
		from generate_series(1, value * 5)
		returning address_id
	)
	select array_agg(address_id) into v_addresses
	from ins;

	v_client_addresses = v_addresses[value + 1 : value * 5];

	with ins as (
		insert into product_category (product_category_name)
		select 'Категория ' || substring(md5(random()::text), 1, 20)
		from generate_series(1, value)
		returning product_category_id
	)
	select array_agg(product_category_id) into v_categories
	from ins;

	with base as (
		select g,
			v_start + floor(random() * 11)::int as hire_date,
			case
				when g = 1 then 'свободен'::courier_status
				else v_courier_statuses[1 + floor(random() * array_length(v_courier_statuses, 1))::int]
			end as status
		from generate_series(1, value) g
	),
	ins as (
		insert into courier (fio, phone_number, status, hire_date, dismissal_date)
		select 'Курьер ' || substring(md5(random()::text), 1, 20),
			'+7' || (9000000000 + floor(random() * 1000000000))::bigint::text,
			b.status,
			b.hire_date,
			case
				when b.status = 'уволен'
				then b.hire_date + 10 + floor(random() * (current_date - b.hire_date - 10))::int
			end
		from base b
		returning courier_id
	)
	select array_agg(courier_id) into v_couriers
	from ins;

	with base as (
		select g,
			6 + floor(random() * 6)::int as start_hour, 
			8 + floor(random() * 5)::int as work_hours 
		from generate_series(1, value) g
	),
	ins as (
		insert into restaurant (restaurant_name, address_id, description, work_start, work_end, company_details, status)
		select 'Ресторан ' || substring(md5(random()::text), 1, 20),
			v_addresses[b.g],
			'Описание ' || substring(md5(random()::text), 1, 20),
			'00:00'::time + b.start_hour * interval '1 hour',
			'00:00'::time + (b.start_hour + b.work_hours) * interval '1 hour',
			'Реквизиты ' || substring(md5(random()::text), 1, 20),
			case
				when random() < 0.8 then 'активен'::restaurant_status
				else v_restaurant_statuses[1 + floor(random() * array_length(v_restaurant_statuses, 1))::int]
			end
		from base b
		returning restaurant_id
	)
	select array_agg(restaurant_id) into v_restaurants
	from ins;

	for i in 1..value
	loop
		loop
			v_phone = '+7' || (9000000000 + floor(random() * 1000000000))::bigint::text;
			exit when not exists (
				select 1
				from client c
				where c.phone_number = v_phone
			);
		end loop;

		v_client = exts.uuid_generate_v4();

		insert into client (client_id, login, password, phone_number)
		values (v_client, 'user_' || replace(v_client::text, '-', ''), md5(random()::text), v_phone);

		v_clients = v_clients || v_client;
	end loop;

	insert into client_address (client_id, address_id)
	select v_clients[((g - 1) % value) + 1], v_client_addresses[g]
	from generate_series(1, value * 4) g;

	for i in 1..value * 5
	loop
		v_product = exts.uuid_generate_v4();
		v_price = round((500 + random() * 2500)::numeric, 2);

		insert into product (product_id, product_name, product_category_id, price, restaurant_id, photo_url, status, description)
		values (v_product,
			'Блюдо ' || substring(md5(random()::text), 1, 20),
			v_categories[1 + floor(random() * value)::int],
			v_price,
			v_restaurants[((i - 1) % value) + 1],
			case when random() < 0.5 then null else 'https://example.com/' || md5(random()::text) end,
			case
				when random() < 0.8 then 'доступно'::product_status
				else v_product_statuses[1 + floor(random() * array_length(v_product_statuses, 1))::int]
			end,
			'Описание ' || substring(md5(random()::text), 1, 20));

		v_products = v_products || v_product;
		v_prices = v_prices || v_price;
	end loop;

	for i in 1..value * 5
	loop
		v_client_idx = 1 + floor(random() * value)::int;
		v_idx = v_client_idx + value * floor(random() * 4)::int;
		v_restaurant_idx = 1 + floor(random() * value)::int;

		v_courier = v_couriers[1 + floor(random() * value)::int];

		select hire_date, dismissal_date into v_hire, v_dismissal
		from courier
		where courier_id = v_courier;

		v_from = (v_hire + 1)::timestamp;
		v_to = case
			when v_dismissal is null then current_timestamp::timestamp - interval '3 hours'
			else v_dismissal::timestamp
		end;
		v_ts = v_from + (v_to - v_from) * random();

		v_status = v_order_statuses[1 + floor(random() * array_length(v_order_statuses, 1))::int];
		if random() < 0.7 then
			v_status = 'доставлен';
		end if;

		v_delivery = case
			when v_status = 'доставлен' then v_ts + (20 + random() * 70) * interval '1 minute'
		end;

		v_order_id = exts.uuid_generate_v4();

		insert into "order" (order_id, courier_id, client_id, address_id, restaurant_id, order_timestamp, delivery_timestamp, order_amount, status, pay_status)
		values (v_order_id, v_courier, v_clients[v_client_idx], v_client_addresses[v_idx], v_restaurants[v_restaurant_idx],
			v_ts, v_delivery, 1000, v_status, 'оплачен');

		select array_agg(k order by random()) into v_perm
		from generate_series(0, 4) k;

		v_n = 1 + floor(random() * 5)::int;
		v_sum = 0;

		for j in 1..v_n
		loop
			v_idx = v_restaurant_idx + value * v_perm[j];
			v_price = v_prices[v_idx];
			v_qty = 1 + floor(random() * 3);

			if j = 1 then
				if ceil(910 / v_price) > v_qty then
					v_qty = ceil(910 / v_price);
				end if;
				v_first_product = v_products[v_idx];
			end if;

			insert into order_structure (order_id, product_id, restaurant_id, quantity)
			values (v_order_id, v_products[v_idx], v_restaurants[v_restaurant_idx], v_qty);

			v_sum = v_sum + v_price * v_qty;
		end loop;

		update "order"
		set order_amount = round(v_sum, 2)
		where order_id = v_order_id;

		select total_amount into v_total
		from "order"
		where order_id = v_order_id;

		insert into payment (order_id, payment_type, amount, transaction_id, transaction_timestamp, status)
		values (v_order_id,
			v_payment_types[1 + floor(random() * array_length(v_payment_types, 1))::int],
			v_total,
			replace(exts.uuid_generate_v4()::text, '-', ''),
			v_ts + (1 + random() * 10) * interval '1 minute',
			'успех');

		v_entity_type = v_entity_types[1 + floor(random() * array_length(v_entity_types, 1))::int];
		v_entity_id = case v_entity_type
			when 'заказ' then v_order_id
			when 'ресторан' then v_restaurants[v_restaurant_idx]
			else v_first_product
		end;

		insert into review (client_id, review_timestamp, entity_id, entity_type, order_id, description, photo_url, rating)
		values (v_clients[v_client_idx],
			coalesce(v_delivery, v_ts) + (5 + random() * 25) * interval '1 minute',
			v_entity_id,
			v_entity_type,
			v_order_id,
			'Отзыв ' || substring(md5(random()::text), 1, 20),
			case when random() < 0.5 then null else 'https://example.com/' || md5(random()::text) end,
			1 + floor(random() * 5));
	end loop;

	update product p
	set rating = s.avg_rating
	from (
		select r.entity_id, round(avg(r.rating), 2) as avg_rating
		from review r
		where r.entity_type = 'блюдо' and r.entity_id = any(v_products)
		group by r.entity_id
	) s
	where p.product_id = s.entity_id;

	update restaurant rs
	set rating = s.avg_rating
	from (
		select r.entity_id, round(avg(r.rating), 2) as avg_rating
		from review r
		where r.entity_type = 'ресторан' and r.entity_id = any(v_restaurants)
		group by r.entity_id
	) s
	where rs.restaurant_id = s.entity_id;

	for v_month in
		select x
		from generate_series(date_trunc('month', v_start::timestamp), date_trunc('month', current_date)::timestamp, interval '1 month') x
	loop
		insert into courier_pay (courier_id, year, month, amount, coefficient_used)
		select c.courier_id,
			date_part('year', v_month),
			date_part('month', v_month),
			round(c.coefficient * coalesce(sum(o.commission), 0), 2),
			c.coefficient
		from courier c
		left join "order" o on o.courier_id = c.courier_id
			and o.status = 'доставлен'
			and date_trunc('month', o.order_timestamp) = v_month
		where c.courier_id = any(v_couriers)
		group by c.courier_id, c.coefficient;

		update courier c
		set coefficient = case
			when s.cnt > 500 then 0.5
			when s.cnt > 250 then 0.3
			when s.cnt > 150 then 0.2
			else 0.1
		end
		from (
			select c2.courier_id, count(o.order_id) as cnt
			from courier c2
			left join "order" o on o.courier_id = c2.courier_id
				and o.status = 'доставлен'
				and date_trunc('month', o.order_timestamp) = v_month
			where c2.courier_id = any(v_couriers)
			group by c2.courier_id
		) s
		where c.courier_id = s.courier_id
			and (c.status != 'уволен' or date_trunc('month', c.dismissal_date::timestamp) > v_month);
	end loop;
end;
$$ language plpgsql;


create or replace procedure erase_test_data() as $$
begin
	truncate review, payment, order_structure, "order", courier_pay, product, restaurant, client_address, client, address, courier, product_category;
end;
$$ language plpgsql;
