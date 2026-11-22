set search_path to podoprigora_food, exts;

create or replace view how_much_money as
with recursive months as (
	select date_trunc('month', min(o.order_timestamp)) as m, date_trunc('month', max(o.order_timestamp)) as last_m
	from "order" o
	where o.status = 'доставлен'
	union all
	select mo.m + interval '1 month', mo.last_m
	from months mo
	where mo.m < mo.last_m
),
orders_sum as (
	select date_trunc('month', o.order_timestamp) as m, sum(o.order_amount) as sum_no, sum(o.total_amount) as sum_with
	from "order" o
	where o.status = 'доставлен'
	group by date_trunc('month', o.order_timestamp)
),
pay as (
	select cp.year, cp.month, sum(cp.amount) as amount
	from courier_pay cp
	group by cp.year, cp.month
),
calc as (
	select mo.m,
		left(mo.m::text, 7) as year_month,
		coalesce(os.sum_no, 0) as sum_no_commission,
		coalesce(os.sum_with, 0) as sum_with_commission,
		coalesce(os.sum_with, 0) - coalesce(os.sum_no, 0) as commission,
		coalesce(p.amount, 0) as courier_pay
	from months mo
	left join orders_sum os on os.m = mo.m
	left join pay p on p.year = date_part('year', mo.m) and p.month = date_part('month', mo.m)
),
with_prev as (
	select c.*, lag(c.commission) over (order by c.m) as prev_commission
	from calc c
)
select wp.year_month,
	wp.sum_no_commission,
	wp.sum_with_commission,
	wp.commission,
	wp.prev_commission,
	wp.commission - wp.prev_commission as commission_diff,
	wp.courier_pay,
	wp.commission - wp.courier_pay as net_profit
from with_prev wp
where wp.m is not null 
order by wp.year_month;
