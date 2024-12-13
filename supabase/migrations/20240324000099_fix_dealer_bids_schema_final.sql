```sql
-- Drop existing views and functions
drop view if exists cars_with_brand cascade;
drop view if exists private_listings_with_brand cascade;
drop function if exists get_dealer_bid cascade;
drop function if exists get_listing_bids cascade;
drop function if exists place_dealer_bid cascade;

-- Create cars_with_brand view
create or replace view cars_with_brand as
select 
  c.*,
  b.name as brand_name,
  b.logo_url as brand_logo_url,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'name', cf.name,
          'available', cf.available
        )
        order by cf.name
      )
      filter (where cf.name is not null)
      from car_features cf
      where cf.car_id = c.id
    ),
    '[]'::jsonb
  ) as features
from cars c
join brands b on b.id = c.brand_id;

-- Create private_listings_with_brand view
create or replace view private_listings_with_brand as
select 
  pl.*,
  b.name as brand_name,
  b.logo_url as brand_logo_url,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'name', plf.name,
          'available', plf.available
        )
        order by plf.name
      )
      filter (where plf.name is not null)
      from private_listing_features plf
      where plf.listing_id = pl.id
    ),
    '[]'::jsonb
  ) as features,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', db.id,
          'amount', db.amount,
          'dealer', jsonb_build_object(
            'id', d.id,
            'name', d.name,
            'phone', d.phone,
            'whatsapp', d.whatsapp
          )
        )
        order by db.amount desc
      )
      filter (where db.id is not null)
      from dealer_bids db
      join dealers d on d.id = db.dealer_id
      where db.listing_id = pl.id
    ),
    '[]'::jsonb
  ) as bids
from private_listings pl
join brands b on b.id = pl.brand_id;

-- Create function to get dealer bid
create or replace function get_dealer_bid(
  p_dealer_id uuid,
  p_listing_id uuid
) returns numeric as $$
  select amount
  from dealer_bids
  where dealer_id = p_dealer_id
  and listing_id = p_listing_id;
$$ language sql stable;

-- Create function to get listing bids
create or replace function get_listing_bids(p_listing_id uuid)
returns table (
  dealer_id uuid,
  dealer_name text,
  dealer_phone text,
  dealer_whatsapp text,
  amount numeric
) as $$
  select 
    d.id as dealer_id,
    d.name as dealer_name,
    d.phone as dealer_phone,
    d.whatsapp as dealer_whatsapp,
    db.amount
  from dealer_bids db
  join dealers d on d.id = db.dealer_id
  where db.listing_id = p_listing_id
  order by db.amount desc;
$$ language sql stable;

-- Create function to place or update bid
create or replace function place_dealer_bid(
  p_dealer_id uuid,
  p_listing_id uuid,
  p_amount numeric
) returns void as $$
declare
  v_listing private_listings;
begin
  -- Check if listing exists and is approved
  select * into v_listing
  from private_listings
  where id = p_listing_id
  and status = 'approved'
  for update;

  if not found then
    raise exception 'Listing not found or not available for bidding';
  end if;

  -- Insert or update bid
  insert into dealer_bids (dealer_id, listing_id, amount)
  values (p_dealer_id, p_listing_id, p_amount)
  on conflict (dealer_id, listing_id)
  do update set amount = excluded.amount;
end;
$$ language plpgsql security definer;

-- Create indexes for better performance
create index if not exists idx_cars_brand_id on cars(brand_id);
create index if not exists idx_cars_condition on cars(condition);
create index if not exists idx_cars_is_sold on cars(is_sold);
create index if not exists idx_cars_dealer_id on cars(dealer_id);
create index if not exists idx_car_features_car_id on car_features(car_id);
create index if not exists idx_private_listings_brand_id on private_listings(brand_id);
create index if not exists idx_private_listings_status on private_listings(status);
create index if not exists idx_dealer_bids_dealer_id on dealer_bids(dealer_id);
create index if not exists idx_dealer_bids_listing_id on dealer_bids(listing_id);

-- Grant necessary permissions
grant usage on schema public to authenticated;
grant all privileges on all tables in schema public to authenticated;
grant select on all tables in schema public to anon;

-- Grant access to views and functions
grant select on cars_with_brand to anon, authenticated;
grant select on private_listings_with_brand to anon, authenticated;
grant execute on function get_dealer_bid(uuid, uuid) to authenticated;
grant execute on function get_listing_bids(uuid) to authenticated;
grant execute on function place_dealer_bid(uuid, uuid, numeric) to authenticated;

-- Create RLS policies
create policy "Anyone can view cars"
  on cars for select
  using (true);

create policy "Anyone can view private listings"
  on private_listings for select
  using (true);

create policy "Anyone can view car features"
  on car_features for select
  using (true);

create policy "Anyone can view private listing features"
  on private_listing_features for select
  using (true);

create policy "Anyone can view dealer bids"
  on dealer_bids for select
  using (true);

create policy "Dealers can place bids"
  on dealer_bids for insert
  with check (dealer_id = auth.uid()::uuid);

create policy "Dealers can update their own bids"
  on dealer_bids for update
  using (dealer_id = auth.uid()::uuid);

-- Refresh schema cache
notify pgrst, 'reload schema';
```