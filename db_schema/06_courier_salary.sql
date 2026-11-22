set search_path to podoprigora_food, exts;

create or replace procedure courier_salary() as $$
declare
	v_start timestamp = date_trunc('month', current_date)::timestamp; 
	v_year int = date_part('year', current_date);
	v_month int = date_part('month', current_date);
	r record;
begin
	for r in
		select c.courier_id, c.status, c.coefficient, count(o.order_id) as cnt, coalesce(sum(o.commission), 0) as commission_sum
		from courier c
		left join "order" o on o.courier_id = c.courier_id
			and o.status = 'доставлен'
			and o.order_timestamp >= v_start
			and o.order_timestamp < v_start + interval '1 month'
		group by c.courier_id, c.status, c.coefficient
	loop
		if exists (
			select 1
			from courier_pay cp
			where cp.courier_id = r.courier_id and cp.year = v_year and cp.month = v_month
		) then
			update courier_pay
			set amount = round(coefficient_used * r.commission_sum, 2)
			where courier_id = r.courier_id and year = v_year and month = v_month;
		else
			insert into courier_pay (courier_id, year, month, amount, coefficient_used)
			values (r.courier_id, v_year, v_month, round(r.coefficient * r.commission_sum, 2), r.coefficient);
		end if;

		if r.status != 'уволен' then
			update courier
			set coefficient = case
				when r.cnt > 500 then 0.5
				when r.cnt > 250 then 0.3
				when r.cnt > 150 then 0.2
				else 0.1
			end
			where courier_id = r.courier_id;
		end if;
	end loop;
end;
$$ language plpgsql;
