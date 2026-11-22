create schema podoprigora_food;

set search_path to podoprigora_food, exts;

create type restaurant_status as enum (
	'активен', 'неактивен'
); 
create type product_status as enum (
	'доступно', 'нет_в_наличии', 'архив'
);

create type courier_status as enum (
	'свободен', 'занят', 'на_доставке', 'уволен'
);

create type order_status as enum (
	'создан', 'готовится', 'в_доставке', 'доставлен', 'отменён'
); 
create type order_pay_status as enum (
	'ожидает', 'оплачен', 'ошибка'
); 

create type payment_status as enum (
	'успех', 'ошибка', 'в_обработке'
); 

create type payment_type as enum (
	'карта', 'наличные', 'безнал'
); 

create type review_entity_type as enum (
	'блюдо', 'ресторан', 'заказ'
); 

create table address (
	address_id uuid primary key default exts.uuid_generate_v4(),
	street varchar(100) not null,
	house_number varchar(10) not null,
	apartment_office varchar(10) 
);

create table client (
	client_id uuid primary key default exts.uuid_generate_v4(),
	login varchar(50) not null unique, 
	password char(32) not null check(char_length(password) = 32), 
	phone_number char(12) not null unique -- формат: +7 и 10 цифр, в (11) не влезло бы
);

create table product_category (
	product_category_id uuid primary key default exts.uuid_generate_v4(),
	product_category_name varchar(100) not null
);

create table courier (
	courier_id uuid primary key default exts.uuid_generate_v4(),
	fio varchar(150) not null,
	phone_number char(12) not null,
	status courier_status not null,
	hire_date date not null,
	dismissal_date date, 
	coefficient numeric(3, 2) not null default 0.1 check(coefficient between 0.1 and 0.5), 
	check(status != 'уволен' or dismissal_date is not null),
	check(dismissal_date >= hire_date) 
);

create table client_address (
	client_id uuid not null references client(client_id),
	address_id uuid not null references address(address_id),
	primary key (client_id, address_id) 
);

create table restaurant (
	restaurant_id uuid primary key default exts.uuid_generate_v4(),
	restaurant_name varchar(100) not null,
	address_id uuid not null unique references address(address_id), 
	description text not null,
	work_start time not null,
	work_end time not null,
	company_details text not null,
	rating numeric(3, 2) check(rating between 0 and 5), 
	status restaurant_status not null,
	check(work_end > work_start) 
);

create table product (
	product_id uuid primary key default exts.uuid_generate_v4(),
	product_name varchar(100) not null,
	product_category_id uuid not null references product_category(product_category_id),
	price numeric(10, 2) not null check(price >= 0), 
	restaurant_id uuid not null references restaurant(restaurant_id),
	photo_url text, 
	rating numeric(3, 2) check(rating between 0 and 5), 
	status product_status not null,
	description text not null,
	unique (product_id, restaurant_id) 
);

create table "order" ( 
	order_id uuid primary key default exts.uuid_generate_v4(),
	courier_id uuid not null references courier(courier_id), 
	client_id uuid not null references client(client_id), 
	address_id uuid not null references address(address_id), 
	restaurant_id uuid not null references restaurant(restaurant_id), 
	order_timestamp timestamp not null,
	delivery_timestamp timestamp,
	order_amount numeric(12, 2) not null,
	commission numeric(12, 2) generated always as (round(order_amount * 0.1, 2)) stored, 
	total_amount numeric(12, 2) generated always as (order_amount + round(order_amount * 0.1, 2)) stored, 
	status order_status not null,
	pay_status order_pay_status not null,
	description text,
	check(total_amount >= 1000),
	check(delivery_timestamp >= order_timestamp), 
	check(status != 'доставлен' or delivery_timestamp is not null), 
	foreign key (client_id, address_id) references client_address(client_id, address_id), 
	unique (order_id, restaurant_id), 
	unique (order_id, client_id), 
	unique (order_id, total_amount) 
);

create table order_structure (
	order_id uuid not null,
	product_id uuid not null,
	restaurant_id uuid not null, 
	quantity numeric(8, 2) not null check(quantity > 0), 
	primary key (order_id, product_id), 
	foreign key (order_id, restaurant_id) references "order"(order_id, restaurant_id),
	foreign key (product_id, restaurant_id) references product(product_id, restaurant_id)
);

create table payment (
	payment_id uuid primary key default exts.uuid_generate_v4(),
	order_id uuid not null,
	payment_type payment_type not null, 
	amount numeric(12, 2) not null,
	transaction_id varchar(100) not null unique, 
	transaction_timestamp timestamp not null,
	status payment_status not null,
	foreign key (order_id, amount) references "order"(order_id, total_amount) 
);

create unique index payment_one_success_idx on payment (order_id) where status = 'успех'; 

create table review (
	review_id uuid primary key default exts.uuid_generate_v4(),
	client_id uuid not null references client(client_id),
	review_timestamp timestamp not null,
	entity_id uuid not null,
	entity_type review_entity_type not null,
	order_id uuid not null references "order"(order_id), 
	description text not null, 
	photo_url text, 
	rating numeric(2, 1) not null check(rating between 1 and 5), 
	foreign key (order_id, client_id) references "order"(order_id, client_id),
	unique (order_id, entity_type, entity_id) 
);

create table courier_pay (
	courier_id uuid not null references courier(courier_id),
	year int not null,
	month int not null,
	amount numeric(12, 2) not null check(amount >= 0), 
	coefficient_used numeric(3, 2) not null, 
	primary key (courier_id, year, month) 
);


create or replace function review_check_entity() returns trigger as $$
begin
	if new.entity_type = 'заказ' then
		if new.entity_id != new.order_id then
			raise exception 'для отзыва на заказ entity_id должен совпадать с order_id';
		end if;
	elseif new.entity_type = 'ресторан' then
		if not exists (
			select 1
			from "order" o
			where o.order_id = new.order_id and o.restaurant_id = new.entity_id
		) then
			raise exception 'ресторан % не относится к заказу %', new.entity_id, new.order_id;
		end if;
	elseif new.entity_type = 'блюдо' then
		if not exists (
			select 1
			from order_structure os
			where os.order_id = new.order_id and os.product_id = new.entity_id
		) then
			raise exception 'блюдо % не входит в заказ %', new.entity_id, new.order_id;
		end if;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger review_check_entity_tg
before insert or update on review
for each row execute function review_check_entity();
