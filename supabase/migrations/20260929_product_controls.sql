-- Existing installations: run in Supabase SQL Editor. Keeps all data.
BEGIN;
create or replace function public.apply_operation(operation jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  member public.profiles;
  existing public.products;
  product jsonb;
  event jsonb;
  pid uuid;
  eid uuid;
  change numeric;
  cost numeric;
  value_change numeric;
  event_kind text;
begin
  select * into member from public.profiles where id = auth.uid() and active for share;
  if not found then raise exception 'Aktif çalışma alanı üyeliği gerekli'; end if;
  if operation->>'actorId' is distinct from auth.uid()::text then raise exception 'İşlem sahibi eşleşmiyor'; end if;
  perform pg_advisory_xact_lock(hashtextextended(member.workspace_id::text, 0));
  eid := (operation->>'id')::uuid;
  event := operation->'event';
  if eid is null or event is null or eid::text is distinct from event->>'id' then raise exception 'Geçersiz işlem'; end if;
  -- Retry of the same UUID is safe, even after a lost HTTP response.
  if exists(select 1 from public.stock_events where workspace_id = member.workspace_id and id = eid and actor_id = member.id) then return; end if;
  pid := (event->>'productId')::uuid;
  if pid is null then raise exception 'Ürün kimliği gerekli'; end if;
  select * into existing from public.products where workspace_id = member.workspace_id and id = pid for update;
  if operation->>'type' = 'product' then
    if member.role <> 'admin' then raise exception 'Yönetici yetkisi gerekli'; end if;
    product := operation->'product';
    if product->>'id' is distinct from pid::text or coalesce(length(trim(product->>'name')),0) = 0
      or coalesce(length(trim(product->>'sku')),0) = 0 or coalesce(length(trim(product->>'unit')),0) = 0 then
      raise exception 'Ürün adı, stok kodu ve birim gerekli';
    end if;
    cost := (product->>'cost')::numeric;
    if cost is null or not (cost >= 0 and cost < 1e12)
      or (product->>'threshold') is null or not ((product->>'threshold')::numeric >= 0 and (product->>'threshold')::numeric < 1e12) then
      raise exception 'Geçersiz maliyet veya eşik';
    end if;
    if existing.id is not null and existing.doc->>'revision' is distinct from operation->>'expectedRevision' then
      raise exception 'Ürün başka cihazda değişti. Bekleyen işlemleri inceleyip sunucu verisini alın.';
    end if;
    if existing.id is null and operation->>'expectedRevision' is not null then raise exception 'Ürün bulunamadı'; end if;
    if existing.id is not null and existing.quantity <> 0 and existing.doc->>'unit' is distinct from product->>'unit' then
      raise exception 'Stok varken birim değiştirilemez';
    end if;
    -- Older clients must preserve an existing freeze/message when editing.
    product := product || jsonb_build_object(
      'isFrozen', coalesce(product->'isFrozen', existing.doc->'isFrozen', 'false'::jsonb),
      'adminMessage', coalesce(product->'adminMessage', existing.doc->'adminMessage', '""'::jsonb));
    if jsonb_typeof(product->'isFrozen') <> 'boolean' or jsonb_typeof(product->'adminMessage') <> 'string' then
      raise exception 'Geçersiz dondurma veya yönetici mesajı';
    end if;
    event_kind := case when existing.id is null then 'create' else 'edit' end;
    change := 0;
    value_change := coalesce(existing.quantity, 0) * (cost - coalesce((existing.doc->>'cost')::numeric, 0));
    product := product || jsonb_build_object('revision', eid::text, 'createdAt', coalesce(existing.doc->>'createdAt', (clock_timestamp() at time zone 'UTC')::text || 'Z'));
    insert into public.products(workspace_id, id, sku, doc) values (member.workspace_id, pid, product->>'sku', product)
      on conflict (workspace_id, id) do update set sku = excluded.sku, doc = excluded.doc;
  elsif operation->>'type' = 'movement' then
    if existing.id is null then raise exception 'Ürün bulunamadı'; end if;
    product := existing.doc;
    if coalesce((product->>'isFrozen')::boolean, false) then
      raise exception 'Bu ürünün stok işlemleri admin tarafından donduruldu';
    end if;
    cost := (product->>'cost')::numeric;
    change := (event->>'delta')::numeric;
    event_kind := event->>'kind';
    if event_kind = 'in' and member.role <> 'admin' then
      raise exception 'Stok girişini yalnızca admin yapabilir';
    end if;
    if change is null or not(abs(change) > 0 and abs(change) < 1e12)
      or event_kind is null or event_kind not in ('in', 'out')
      or (event_kind = 'in' and change < 0) or (event_kind = 'out' and change > 0) then
      raise exception 'Geçersiz stok hareketi';
    end if;
    if existing.quantity + change < 0 then raise exception 'Sunucuda yeterli stok yok; işlem onaylanmadı'; end if;
    update public.products set quantity = quantity + change where workspace_id = member.workspace_id and id = pid;
    value_change := change * cost;
  else
    raise exception 'Bilinmeyen işlem türü';
  end if;
  event := jsonb_build_object('id', eid, 'productId', pid, 'productName', product->>'name',
    'actorId', member.id, 'actorName', member.name, 'kind', event_kind, 'note', coalesce(event->>'note',''),
    'delta', change, 'valueDelta', value_change, 'deviceAt', event->>'at',
    'at', (clock_timestamp() at time zone 'UTC')::text || 'Z');
  insert into public.stock_events(workspace_id, id, actor_id, product_id, doc)
    values (member.workspace_id, eid, member.id, pid, event);
end;
$$;


revoke all on function public.apply_operation(jsonb) from public, anon;
grant execute on function public.apply_operation(jsonb) to authenticated;
COMMIT;
