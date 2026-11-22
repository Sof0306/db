set search_path to podoprigora_food, exts;

create or replace function get_statistic() returns table (
	restaurant_name varchar,
	best_product_name varchar,
	total_amount numeric,
	avg_amount numeric,
	best_user varchar
) as $$
begin
	return query (
		with by_client as (
			select o.restaurant_id, o.client_id, count(*) as cnt, sum(o.total_amount) as amount
			from "order" o
			where o.status = 'доставлен'
			group by o.restaurant_id, o.client_id
		),
		totals as (
			select bc.restaurant_id, sum(bc.amount) as total, sum(bc.amount) / sum(bc.cnt) as average
			from by_client bc
			group by bc.restaurant_id
		),
		best_users as (
			select distinct on (bc.restaurant_id) bc.restaurant_id, c.login
			from by_client bc
			join client c on c.client_id = bc.client_id
			order by bc.restaurant_id, bc.cnt desc, random()
		),
		best_products as (
			select distinct on (o.restaurant_id) o.restaurant_id, p.product_name
			from "order" o
			join order_structure os on os.order_id = o.order_id
			join product p on p.product_id = os.product_id
			where o.status = 'доставлен'
			group by o.restaurant_id, p.product_id, p.product_name
			order by o.restaurant_id, sum(os.quantity) desc, random()
		)
		select r.restaurant_name, bp.product_name, coalesce(t.total, 0), coalesce(round(t.average, 2), 0), bu.login
		from restaurant r
		left join totals t on t.restaurant_id = r.restaurant_id
		left join best_products bp on bp.restaurant_id = r.restaurant_id
		left join best_users bu on bu.restaurant_id = r.restaurant_id
	);
end;
$$ language plpgsql;
