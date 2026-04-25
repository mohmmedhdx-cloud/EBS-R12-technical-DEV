# AR / TCA — Customer creation chain

Verified end-to-end against the live Vision R12.2.12 instance. All six steps below ran successfully in one anonymous block, returning real IDs — then rolled back.

Customers in R12 live in **TCA (Trading Community Architecture)**. A "customer" is actually a graph of objects across `HZ_*` tables. To create a fully usable customer for order entry + billing you need **six** objects:

```
1. Party             (HZ_PARTIES)
   └─ 2. Cust Account    (HZ_CUST_ACCOUNTS)
       └─ (plus)
3. Location          (HZ_LOCATIONS)
   └─ 4. Party Site    (HZ_PARTY_SITES)          -- links party + location
       └─ 5. Cust Acct Site  (HZ_CUST_ACCT_SITES_ALL, org_id)
           └─ 6. Site Use    (HZ_CUST_SITE_USES_ALL, BILL_TO / SHIP_TO / …)
```

Miss step 6 and the customer appears in queries but can't be used on an invoice.

## Context

```sql
fnd_global.apps_initialize(0, 20678, 222);              -- SYSADMIN / RECEIVABLES_MANAGER
mo_global.set_policy_context('S', 204);                 -- Vision Operations OU
```

## Verified end-to-end call (with rollback)

```sql
SET SERVEROUTPUT ON
DECLARE
  -- Step 1: party
  v_org_rec         hz_party_v2pub.organization_rec_type;
  v_party_id        NUMBER;
  v_party_number    VARCHAR2(30);
  v_profile_id      NUMBER;
  v_return_status   VARCHAR2(10);
  v_msg_count       NUMBER;
  v_msg_data        VARCHAR2(4000);

  -- Step 2: cust_account
  v_acct_rec        hz_cust_account_v2pub.cust_account_rec_type;
  v_acct_org_rec    hz_party_v2pub.organization_rec_type;
  v_cp_rec          hz_customer_profile_v2pub.customer_profile_rec_type;
  v_acct_id         NUMBER;
  v_acct_number     VARCHAR2(30);

  -- Step 3: location
  v_loc_rec         hz_location_v2pub.location_rec_type;
  v_location_id     NUMBER;

  -- Step 4: party_site
  v_party_site_rec  hz_party_site_v2pub.party_site_rec_type;
  v_party_site_id   NUMBER;
  v_party_site_num  VARCHAR2(30);

  -- Step 5: cust_acct_site
  v_cas_rec         hz_cust_account_site_v2pub.cust_acct_site_rec_type;
  v_acct_site_id    NUMBER;

  -- Step 6: site_use
  v_su_rec          hz_cust_account_site_v2pub.cust_site_use_rec_type;
  v_site_use_id     NUMBER;
BEGIN
  fnd_global.apps_initialize(0, 20678, 222);
  mo_global.set_policy_context('S', 204);

  -- [1] party
  v_org_rec.organization_name := 'XXC API CUSTOMER INC';
  v_org_rec.created_by_module := 'TCA_V2_API';
  hz_party_v2pub.create_organization(
      p_init_msg_list    => fnd_api.g_true,
      p_organization_rec => v_org_rec,
      x_party_id         => v_party_id,
      x_party_number     => v_party_number,
      x_profile_id       => v_profile_id,
      x_return_status    => v_return_status,
      x_msg_count        => v_msg_count,
      x_msg_data         => v_msg_data);

  -- [2] cust_account
  v_acct_rec.account_name           := 'XXC API CUSTOMER INC';
  v_acct_rec.created_by_module      := 'TCA_V2_API';
  v_acct_org_rec.party_rec.party_id := v_party_id;             -- NOTE: nested record
  hz_cust_account_v2pub.create_cust_account(
      p_init_msg_list         => fnd_api.g_true,
      p_cust_account_rec      => v_acct_rec,
      p_organization_rec      => v_acct_org_rec,
      p_customer_profile_rec  => v_cp_rec,
      p_create_profile_amt    => fnd_api.g_false,
      x_cust_account_id       => v_acct_id,
      x_account_number        => v_acct_number,
      x_party_id              => v_party_id,
      x_party_number          => v_party_number,
      x_profile_id            => v_profile_id,
      x_return_status         => v_return_status,
      x_msg_count             => v_msg_count,
      x_msg_data              => v_msg_data);

  -- [3] location
  v_loc_rec.country           := 'US';
  v_loc_rec.address1          := '1 Ocean Blvd';
  v_loc_rec.city              := 'San Francisco';
  v_loc_rec.state             := 'CA';
  v_loc_rec.postal_code       := '94105';
  v_loc_rec.created_by_module := 'TCA_V2_API';
  hz_location_v2pub.create_location(
      p_init_msg_list => fnd_api.g_true,
      p_location_rec  => v_loc_rec,
      x_location_id   => v_location_id,
      x_return_status => v_return_status,
      x_msg_count     => v_msg_count,
      x_msg_data      => v_msg_data);

  -- [4] party_site
  v_party_site_rec.party_id                 := v_party_id;
  v_party_site_rec.location_id              := v_location_id;
  v_party_site_rec.identifying_address_flag := 'Y';
  v_party_site_rec.created_by_module        := 'TCA_V2_API';
  hz_party_site_v2pub.create_party_site(
      p_init_msg_list     => fnd_api.g_true,
      p_party_site_rec    => v_party_site_rec,
      x_party_site_id     => v_party_site_id,
      x_party_site_number => v_party_site_num,
      x_return_status     => v_return_status,
      x_msg_count         => v_msg_count,
      x_msg_data          => v_msg_data);

  -- [5] cust_acct_site (org-specific)
  v_cas_rec.cust_account_id   := v_acct_id;
  v_cas_rec.party_site_id     := v_party_site_id;
  v_cas_rec.org_id            := 204;
  v_cas_rec.created_by_module := 'TCA_V2_API';
  hz_cust_account_site_v2pub.create_cust_acct_site(
      p_init_msg_list      => fnd_api.g_true,
      p_cust_acct_site_rec => v_cas_rec,
      x_cust_acct_site_id  => v_acct_site_id,
      x_return_status      => v_return_status,
      x_msg_count          => v_msg_count,
      x_msg_data           => v_msg_data);

  -- [6] site_use (BILL_TO — repeat this step for SHIP_TO, STMTS, DUN, … )
  v_su_rec.cust_acct_site_id := v_acct_site_id;
  v_su_rec.site_use_code     := 'BILL_TO';
  v_su_rec.primary_flag      := 'Y';
  v_su_rec.location          := 'XXC-BILL-1';
  v_su_rec.created_by_module := 'TCA_V2_API';
  hz_cust_account_site_v2pub.create_cust_site_use(
      p_init_msg_list        => fnd_api.g_true,
      p_cust_site_use_rec    => v_su_rec,
      p_customer_profile_rec => v_cp_rec,
      p_create_profile       => fnd_api.g_false,
      p_create_profile_amt   => fnd_api.g_false,
      x_site_use_id          => v_site_use_id,
      x_return_status        => v_return_status,
      x_msg_count            => v_msg_count,
      x_msg_data             => v_msg_data);

  dbms_output.put_line('party_id='          ||v_party_id);
  dbms_output.put_line('cust_account_id='   ||v_acct_id||
                       ' account_number='   ||v_acct_number);
  dbms_output.put_line('location_id='       ||v_location_id);
  dbms_output.put_line('party_site_id='     ||v_party_site_id);
  dbms_output.put_line('cust_acct_site_id=' ||v_acct_site_id);
  dbms_output.put_line('site_use_id BILL_TO='||v_site_use_id);

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    FOR i IN 1..NVL(v_msg_count,0) LOOP
      dbms_output.put_line(fnd_msg_pub.get(i,'F'));
    END LOOP;
    RAISE;
END;
/
```

**Verified output on Vision:**
```
party_id=476204
cust_account_id=126871  account_number=6084
location_id=27517
party_site_id=254884
cust_acct_site_id=11839
site_use_id BILL_TO=14827
```

## Gotchas

- **`p_organization_rec.party_rec.party_id`** — to link a cust_account to an *existing* party you set `party_rec.party_id` (nested record), not `party_id` directly on the org rec.
- **`create_cust_account` overload 2** — takes `p_organization_rec`; overload 1 takes `p_person_rec`. PL/SQL picks by the record type you pass.
- **No `p_create_profile`** for `create_cust_account` — only `p_create_profile_amt`. `create_cust_site_use` *does* have both.
- **`created_by_module`** is mandatory on every record — the API rejects the row silently (via `fnd_msg_pub`) if you omit it.
- **Site use types** are keyed by `site_use_code`: `BILL_TO`, `SHIP_TO`, `STMTS` (statements), `DUN` (dunning), `LEGAL`, `END_USER`. Order Management needs SHIP_TO; AR invoicing needs BILL_TO.
- **`identifying_address_flag = 'Y'`** on the party_site makes it the default address shown in HZ queries — set it on the primary site only.
- **`org_id`** lives on `cust_acct_site` only — the party and party_site are **global**, but the cust_acct_site + site_use are OU-specific.

## Verification queries

```sql
-- the whole graph for one customer account
SELECT ca.cust_account_id, ca.account_number, p.party_name,
       l.address1, l.city, l.state, l.country,
       cas.org_id, cas.status AS acct_site_status,
       csu.site_use_code, csu.primary_flag, csu.status AS site_use_status
FROM   hz_cust_accounts          ca
JOIN   hz_parties                p    ON p.party_id             = ca.party_id
JOIN   hz_cust_acct_sites_all    cas  ON cas.cust_account_id    = ca.cust_account_id
JOIN   hz_party_sites            ps   ON ps.party_site_id       = cas.party_site_id
JOIN   hz_locations              l    ON l.location_id          = ps.location_id
JOIN   hz_cust_site_uses_all     csu  ON csu.cust_acct_site_id  = cas.cust_acct_site_id
WHERE  ca.cust_account_id = :p_cust_account_id
AND    cas.org_id         = 204
ORDER  BY csu.site_use_code;
```

## Related

- **Person customer** (not organization): `hz_party_v2pub.create_person` — returns a party whose `party_type='PERSON'`. Then same cust_account / site / site_use chain.
- **Contact**: `hz_party_contact_v2pub.create_org_contact` links a person as a contact of an organization party.
- **Accounts with multiple buckets**: call `create_cust_site_use` once per `site_use_code` against the same `cust_acct_site_id`.

## Next

Back to [./](./).
