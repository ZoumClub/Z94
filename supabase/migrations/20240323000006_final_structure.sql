-- Drop existing tables in the correct order
drop table if exists cars cascade;
drop table if exists brands cascade;
drop table if exists profiles cascade;

-- Create profiles table
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique,
  role text check (role in ('admin', 'user')) default 'user',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create brands table
create table brands (
  id uuid default gen_random_uuid() primary key,
  name text not null unique,
  logo_url text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create cars table with brand relationship
create table cars (
  id uuid default gen_random_uuid() primary key,
  brand_id uuid not null references brands(id) on delete restrict,
  make text not null,
  model text not null,
  year integer not null check (year >= 1900),
  price numeric not null check (price > 0),
  image text not null,
  savings numeric not null check (savings >= 0),
  condition text check (condition in ('new', 'used')) not null default 'new',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create indexes for better query performance
create index idx_cars_brand_id on cars(brand_id);
create index idx_cars_condition on cars(condition);
create index idx_cars_price on cars(price);
create index idx_cars_year on cars(year);
create index idx_brands_name on brands(name);

-- Enable RLS
alter table profiles enable row level security;
alter table brands enable row level security;
alter table cars enable row level security;

-- Create policies
create policy "Public profiles are viewable by everyone"
  on profiles for select using (true);

create policy "Users can update their own profile"
  on profiles for update using (auth.uid() = id);

create policy "Brands are viewable by everyone"
  on brands for select using (true);

create policy "Cars are viewable by everyone"
  on cars for select using (true);

-- Create function to automatically update updated_at timestamp
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

-- Create trigger for updating updated_at
create trigger update_cars_updated_at
  before update on cars
  for each row
  execute function update_updated_at_column();

-- Insert sample brands
insert into brands (id, name, logo_url) values
  ('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'BMW', 'https://images.unsplash.com/photo-1617886903355-9354bb57751f'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d480', 'Mercedes-Benz', 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Audi', 'https://images.unsplash.com/photo-1610768764270-790fbec18178'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d482', 'Toyota', 'https://images.unsplash.com/photo-1629897048514-3dd7414fe72a'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'Honda', 'https://images.unsplash.com/photo-1618843479619-f3d0d81e4d10'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'Ford', 'https://images.unsplash.com/photo-1612825173281-9a193378527e'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d485', 'Volkswagen', 'https://images.unsplash.com/photo-1622353219448-46a009f0d44f');

-- Insert sample cars
insert into cars (brand_id, make, model, year, price, image, savings, condition) values
  ('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'BMW', '3 Series', 2024, 45990, 'https://images.unsplash.com/photo-1555215695-3004980ad54e', 3500, 'new'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d480', 'Mercedes-Benz', 'C-Class', 2024, 47990, 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8', 4200, 'new'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Audi', 'A4', 2024, 46590, 'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6', 3800, 'new'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'BMW', '5 Series', 2022, 35990, 'https://images.unsplash.com/photo-1523983388277-336a66bf9bcd', 5500, 'used'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d480', 'Mercedes-Benz', 'E-Class', 2021, 38990, 'https://images.unsplash.com/photo-1606220838315-056192d5e927', 6200, 'used'),
  ('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Audi', 'A6', 2022, 37590, 'https://images.unsplash.com/photo-1606220838315-056192d5e927', 4800, 'used');