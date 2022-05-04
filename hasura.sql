--
-- PostgreSQL database dump
--

-- Dumped from database version 13.6 (Debian 13.6-1.pgdg110+1)
-- Dumped by pg_dump version 13.6

-- Started on 2022-05-04 18:46:01 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 16387)
-- Name: hdb_catalog; Type: SCHEMA; Schema: -; Owner: hasura
--

CREATE SCHEMA hdb_catalog;


ALTER SCHEMA hdb_catalog OWNER TO hasura;

--
-- TOC entry 8 (class 2615 OID 16531)
-- Name: sf; Type: SCHEMA; Schema: -; Owner: hasura
--

CREATE SCHEMA sf;


ALTER SCHEMA sf OWNER TO hasura;

--
-- TOC entry 2 (class 3079 OID 16388)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 3325 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 267 (class 1255 OID 16425)
-- Name: gen_hasura_uuid(); Type: FUNCTION; Schema: hdb_catalog; Owner: hasura
--

CREATE FUNCTION hdb_catalog.gen_hasura_uuid() RETURNS uuid
    LANGUAGE sql
    AS $$select gen_random_uuid()$$;


ALTER FUNCTION hdb_catalog.gen_hasura_uuid() OWNER TO hasura;

--
-- TOC entry 279 (class 1255 OID 16532)
-- Name: insert_event_log(text, text, text, text, json); Type: FUNCTION; Schema: hdb_catalog; Owner: hasura
--

CREATE FUNCTION hdb_catalog.insert_event_log(schema_name text, table_name text, trigger_name text, op text, row_data json) RETURNS text
    LANGUAGE plpgsql
    AS $$
  DECLARE
    id text;
    payload json;
    session_variables json;
    server_version_num int;
    trace_context json;
  BEGIN
    id := gen_random_uuid();
    server_version_num := current_setting('server_version_num');
    IF server_version_num >= 90600 THEN
      session_variables := current_setting('hasura.user', 't');
      trace_context := current_setting('hasura.tracecontext', 't');
    ELSE
      BEGIN
        session_variables := current_setting('hasura.user');
      EXCEPTION WHEN OTHERS THEN
                  session_variables := NULL;
      END;
      BEGIN
        trace_context := current_setting('hasura.tracecontext');
      EXCEPTION WHEN OTHERS THEN
        trace_context := NULL;
      END;
    END IF;
    payload := json_build_object(
      'op', op,
      'data', row_data,
      'session_variables', session_variables,
      'trace_context', trace_context
    );
    INSERT INTO hdb_catalog.event_log
                (id, schema_name, table_name, trigger_name, payload)
    VALUES
    (id, schema_name, table_name, trigger_name, payload);
    RETURN id;
  END;
$$;


ALTER FUNCTION hdb_catalog.insert_event_log(schema_name text, table_name text, trigger_name text, op text, row_data json) OWNER TO hasura;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 211 (class 1259 OID 16533)
-- Name: event_invocation_logs; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.event_invocation_logs (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    event_id text,
    status integer,
    request json,
    response json,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE hdb_catalog.event_invocation_logs OWNER TO hasura;

--
-- TOC entry 212 (class 1259 OID 16541)
-- Name: event_log; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.event_log (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    trigger_name text NOT NULL,
    payload jsonb NOT NULL,
    delivered boolean DEFAULT false NOT NULL,
    error boolean DEFAULT false NOT NULL,
    tries integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    locked timestamp with time zone,
    next_retry_at timestamp without time zone,
    archived boolean DEFAULT false NOT NULL
);


ALTER TABLE hdb_catalog.event_log OWNER TO hasura;

--
-- TOC entry 205 (class 1259 OID 16449)
-- Name: hdb_action_log; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_action_log (
    id uuid DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    action_name text,
    input_payload jsonb NOT NULL,
    request_headers jsonb NOT NULL,
    session_variables jsonb NOT NULL,
    response_payload jsonb,
    errors jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    response_received_at timestamp with time zone,
    status text NOT NULL,
    CONSTRAINT hdb_action_log_status_check CHECK ((status = ANY (ARRAY['created'::text, 'processing'::text, 'completed'::text, 'error'::text])))
);


ALTER TABLE hdb_catalog.hdb_action_log OWNER TO hasura;

--
-- TOC entry 207 (class 1259 OID 16475)
-- Name: hdb_cron_event_invocation_logs; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_cron_event_invocation_logs (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    event_id text,
    status integer,
    request json,
    response json,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE hdb_catalog.hdb_cron_event_invocation_logs OWNER TO hasura;

--
-- TOC entry 206 (class 1259 OID 16460)
-- Name: hdb_cron_events; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_cron_events (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    trigger_name text NOT NULL,
    scheduled_time timestamp with time zone NOT NULL,
    status text DEFAULT 'scheduled'::text NOT NULL,
    tries integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    next_retry_at timestamp with time zone,
    CONSTRAINT valid_status CHECK ((status = ANY (ARRAY['scheduled'::text, 'locked'::text, 'delivered'::text, 'error'::text, 'dead'::text])))
);


ALTER TABLE hdb_catalog.hdb_cron_events OWNER TO hasura;

--
-- TOC entry 204 (class 1259 OID 16438)
-- Name: hdb_metadata; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_metadata (
    id integer NOT NULL,
    metadata json NOT NULL,
    resource_version integer DEFAULT 1 NOT NULL
);


ALTER TABLE hdb_catalog.hdb_metadata OWNER TO hasura;

--
-- TOC entry 209 (class 1259 OID 16505)
-- Name: hdb_scheduled_event_invocation_logs; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_scheduled_event_invocation_logs (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    event_id text,
    status integer,
    request json,
    response json,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE hdb_catalog.hdb_scheduled_event_invocation_logs OWNER TO hasura;

--
-- TOC entry 208 (class 1259 OID 16491)
-- Name: hdb_scheduled_events; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_scheduled_events (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    webhook_conf json NOT NULL,
    scheduled_time timestamp with time zone NOT NULL,
    retry_conf json,
    payload json,
    header_conf json,
    status text DEFAULT 'scheduled'::text NOT NULL,
    tries integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    next_retry_at timestamp with time zone,
    comment text,
    CONSTRAINT valid_status CHECK ((status = ANY (ARRAY['scheduled'::text, 'locked'::text, 'delivered'::text, 'error'::text, 'dead'::text])))
);


ALTER TABLE hdb_catalog.hdb_scheduled_events OWNER TO hasura;

--
-- TOC entry 210 (class 1259 OID 16520)
-- Name: hdb_schema_notifications; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_schema_notifications (
    id integer NOT NULL,
    notification json NOT NULL,
    resource_version integer DEFAULT 1 NOT NULL,
    instance_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT hdb_schema_notifications_id_check CHECK ((id = 1))
);


ALTER TABLE hdb_catalog.hdb_schema_notifications OWNER TO hasura;

--
-- TOC entry 213 (class 1259 OID 16553)
-- Name: hdb_source_catalog_version; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_source_catalog_version (
    version text NOT NULL,
    upgraded_on timestamp with time zone NOT NULL
);


ALTER TABLE hdb_catalog.hdb_source_catalog_version OWNER TO hasura;

--
-- TOC entry 203 (class 1259 OID 16426)
-- Name: hdb_version; Type: TABLE; Schema: hdb_catalog; Owner: hasura
--

CREATE TABLE hdb_catalog.hdb_version (
    hasura_uuid uuid DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    version text NOT NULL,
    upgraded_on timestamp with time zone NOT NULL,
    cli_state jsonb DEFAULT '{}'::jsonb NOT NULL,
    console_state jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE hdb_catalog.hdb_version OWNER TO hasura;

--
-- TOC entry 214 (class 1259 OID 16559)
-- Name: account; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.account (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL
);


ALTER TABLE sf.account OWNER TO hasura;

--
-- TOC entry 215 (class 1259 OID 16563)
-- Name: account_asset; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.account_asset (
    account_id uuid NOT NULL,
    asset_id uuid NOT NULL
);


ALTER TABLE sf.account_asset OWNER TO hasura;

--
-- TOC entry 216 (class 1259 OID 16566)
-- Name: account_auth; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.account_auth (
    account_id uuid NOT NULL,
    password text NOT NULL,
    seed text NOT NULL
);


ALTER TABLE sf.account_auth OWNER TO hasura;

--
-- TOC entry 217 (class 1259 OID 16572)
-- Name: account_profile; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.account_profile (
    account_id uuid NOT NULL,
    chain_id text NOT NULL,
    name text NOT NULL
);


ALTER TABLE sf.account_profile OWNER TO hasura;

--
-- TOC entry 218 (class 1259 OID 16578)
-- Name: asset; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.asset (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL
);


ALTER TABLE sf.asset OWNER TO hasura;

--
-- TOC entry 229 (class 1259 OID 17322)
-- Name: asset_class; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.asset_class (
    asset_id uuid NOT NULL,
    class_id uuid NOT NULL
);


ALTER TABLE sf.asset_class OWNER TO hasura;

--
-- TOC entry 219 (class 1259 OID 16585)
-- Name: asset_metadata; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.asset_metadata (
    asset_id uuid NOT NULL,
    chain_meta jsonb,
    chain_id integer NOT NULL
);


ALTER TABLE sf.asset_metadata OWNER TO hasura;

--
-- TOC entry 220 (class 1259 OID 16591)
-- Name: asset_nft; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.asset_nft (
    asset_id uuid NOT NULL,
    name text NOT NULL
);


ALTER TABLE sf.asset_nft OWNER TO hasura;

--
-- TOC entry 225 (class 1259 OID 17215)
-- Name: bundle; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.bundle (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metadata jsonb NOT NULL,
    chain_bundle_id text NOT NULL,
    chain_class_id integer NOT NULL,
    chain_asset_id integer NOT NULL
);


ALTER TABLE sf.bundle OWNER TO hasura;

--
-- TOC entry 226 (class 1259 OID 17277)
-- Name: class; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.class (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chain_id integer NOT NULL
);


ALTER TABLE sf.class OWNER TO hasura;

--
-- TOC entry 227 (class 1259 OID 17285)
-- Name: class_metadata; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.class_metadata (
    class_id uuid NOT NULL,
    chain_meta jsonb NOT NULL
);


ALTER TABLE sf.class_metadata OWNER TO hasura;

--
-- TOC entry 228 (class 1259 OID 17293)
-- Name: class_profile; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.class_profile (
    class_id uuid NOT NULL,
    creator_id uuid NOT NULL,
    name text NOT NULL,
    description text NOT NULL
);


ALTER TABLE sf.class_profile OWNER TO hasura;

--
-- TOC entry 230 (class 1259 OID 17470)
-- Name: currency; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.currency (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    symbol text NOT NULL,
    total_supply integer NOT NULL,
    chain_class_id integer NOT NULL,
    chain_asset_id integer NOT NULL,
    current_supply integer DEFAULT 0 NOT NULL
);


ALTER TABLE sf.currency OWNER TO hasura;

--
-- TOC entry 223 (class 1259 OID 17161)
-- Name: escrow; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.escrow (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    class_id integer NOT NULL,
    metadata jsonb NOT NULL,
    asset_id integer,
    chain_id text
);


ALTER TABLE sf.escrow OWNER TO hasura;

--
-- TOC entry 224 (class 1259 OID 17175)
-- Name: escrow_share; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.escrow_share (
    escrow_id uuid NOT NULL,
    owner uuid NOT NULL,
    share integer NOT NULL
);


ALTER TABLE sf.escrow_share OWNER TO hasura;

--
-- TOC entry 221 (class 1259 OID 17088)
-- Name: market; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.market (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    chain_id integer NOT NULL
);


ALTER TABLE sf.market OWNER TO hasura;

--
-- TOC entry 222 (class 1259 OID 17094)
-- Name: market_rate; Type: TABLE; Schema: sf; Owner: hasura
--

CREATE TABLE sf.market_rate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    market_id uuid NOT NULL,
    chain_id integer NOT NULL
);


ALTER TABLE sf.market_rate OWNER TO hasura;

--
-- TOC entry 3300 (class 0 OID 16533)
-- Dependencies: 211
-- Data for Name: event_invocation_logs; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.event_invocation_logs (id, event_id, status, request, response, created_at) FROM stdin;
\.


--
-- TOC entry 3301 (class 0 OID 16541)
-- Dependencies: 212
-- Data for Name: event_log; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.event_log (id, schema_name, table_name, trigger_name, payload, delivered, error, tries, created_at, locked, next_retry_at, archived) FROM stdin;
\.


--
-- TOC entry 3294 (class 0 OID 16449)
-- Dependencies: 205
-- Data for Name: hdb_action_log; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_action_log (id, action_name, input_payload, request_headers, session_variables, response_payload, errors, created_at, response_received_at, status) FROM stdin;
\.


--
-- TOC entry 3296 (class 0 OID 16475)
-- Dependencies: 207
-- Data for Name: hdb_cron_event_invocation_logs; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_cron_event_invocation_logs (id, event_id, status, request, response, created_at) FROM stdin;
\.


--
-- TOC entry 3295 (class 0 OID 16460)
-- Dependencies: 206
-- Data for Name: hdb_cron_events; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_cron_events (id, trigger_name, scheduled_time, status, tries, created_at, next_retry_at) FROM stdin;
\.


--
-- TOC entry 3293 (class 0 OID 16438)
-- Dependencies: 204
-- Data for Name: hdb_metadata; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_metadata (id, metadata, resource_version) FROM stdin;
1	{"rest_endpoints":[{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Accounts"}},"url":"accounts","methods":["GET"],"name":"Accounts","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Account Create"}},"url":"accounts","methods":["POST"],"name":"Account Create","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Account assets"}},"url":"accounts/assets","methods":["GET"],"name":"Account assets","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Asset Create"}},"url":"assets","methods":["POST"],"name":"Asset Create","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Asset Get"}},"url":"assets","methods":["GET"],"name":"Asset Get","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Asset by Chain"}},"url":"assets/chain","methods":["GET"],"name":"Asset by Chain","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Asset by ID"}},"url":"assets/id","methods":["GET"],"name":"Asset by ID","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Bundle Get"}},"url":"bundles","methods":["GET"],"name":"Bundle Get","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Bundle Register"}},"url":"bundles","methods":["POST"],"name":"Bundle Register","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Bundle by Chain"}},"url":"bundles/chain","methods":["GET"],"name":"Bundle by Chain","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Bundle by ID"}},"url":"bundles/id","methods":["GET"],"name":"Bundle by ID","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Class Create"}},"url":"classes","methods":["POST"],"name":"Class Create","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Classes"}},"url":"classes","methods":["GET"],"name":"Classes","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Class Assets"}},"url":"classes/assets","methods":["GET"],"name":"Class Assets","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Currency Create"}},"url":"currencies","methods":["POST"],"name":"Currency Create","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Currency Get"}},"url":"currencies","methods":["GET"],"name":"Currency Get","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Currency Update"}},"url":"currencies/id","methods":["PATCH"],"name":"Currency Update","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Escrow Create"}},"url":"escrows","methods":["POST"],"name":"Escrow Create","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Escrow Get"}},"url":"escrows","methods":["GET"],"name":"Escrow Get","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Escrow Owners"}},"url":"escrows/owners","methods":["POST"],"name":"Escrow Owners","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Escrow Register"}},"url":"escrows/register","methods":["POST"],"name":"Escrow Register","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Market Get"}},"url":"markets","methods":["GET"],"name":"Market Get","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Market Create"}},"url":"markets","methods":["POST"],"name":"Market Create","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Market by Chain"}},"url":"markets/chain","methods":["GET"],"name":"Market by Chain","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Market by ID"}},"url":"markets/id","methods":["GET"],"name":"Market by ID","comment":null},{"definition":{"query":{"collection_name":"allowed-queries","query_name":"Market Rate by ID"}},"url":"markets/rates/id","methods":["GET"],"name":"Market Rate by ID","comment":null}],"allowlist":[{"collection":"allowed-queries","scope":{"global":true}}],"sources":[{"kind":"postgres","name":"default","tables":[{"object_relationships":[{"using":{"foreign_key_constraint_on":{"column":"account_id","table":{"schema":"sf","name":"account_auth"}}},"name":"account_auth"},{"using":{"foreign_key_constraint_on":{"column":"account_id","table":{"schema":"sf","name":"account_profile"}}},"name":"account_profile"}],"table":{"schema":"sf","name":"account"},"array_relationships":[{"using":{"foreign_key_constraint_on":{"column":"account_id","table":{"schema":"sf","name":"account_asset"}}},"name":"account_assets"},{"using":{"foreign_key_constraint_on":{"column":"creator_id","table":{"schema":"sf","name":"class_profile"}}},"name":"class_profiles"},{"using":{"foreign_key_constraint_on":{"column":"owner","table":{"schema":"sf","name":"escrow_share"}}},"name":"escrow_shares"}]},{"object_relationships":[{"using":{"foreign_key_constraint_on":"account_id"},"name":"account"},{"using":{"foreign_key_constraint_on":"asset_id"},"name":"asset"}],"table":{"schema":"sf","name":"account_asset"}},{"object_relationships":[{"using":{"foreign_key_constraint_on":"account_id"},"name":"account"}],"table":{"schema":"sf","name":"account_auth"}},{"object_relationships":[{"using":{"foreign_key_constraint_on":"account_id"},"name":"account"}],"table":{"schema":"sf","name":"account_profile"}},{"object_relationships":[{"using":{"foreign_key_constraint_on":{"column":"asset_id","table":{"schema":"sf","name":"asset_metadata"}}},"name":"asset_metadata"},{"using":{"foreign_key_constraint_on":{"column":"asset_id","table":{"schema":"sf","name":"asset_nft"}}},"name":"asset_nft"}],"table":{"schema":"sf","name":"asset"},"array_relationships":[{"using":{"foreign_key_constraint_on":{"column":"asset_id","table":{"schema":"sf","name":"account_asset"}}},"name":"account_assets"},{"using":{"foreign_key_constraint_on":{"column":"asset_id","table":{"schema":"sf","name":"asset_class"}}},"name":"asset_classes"}]},{"object_relationships":[{"using":{"foreign_key_constraint_on":"asset_id"},"name":"asset"},{"using":{"foreign_key_constraint_on":"class_id"},"name":"class"}],"table":{"schema":"sf","name":"asset_class"}},{"object_relationships":[{"using":{"foreign_key_constraint_on":"asset_id"},"name":"asset"}],"table":{"schema":"sf","name":"asset_metadata"}},{"object_relationships":[{"using":{"foreign_key_constraint_on":"asset_id"},"name":"asset"}],"table":{"schema":"sf","name":"asset_nft"}},{"table":{"schema":"sf","name":"bundle"}},{"object_relationships":[{"using":{"foreign_key_constraint_on":{"column":"class_id","table":{"schema":"sf","name":"class_metadata"}}},"name":"class_metadata"},{"using":{"foreign_key_constraint_on":{"column":"class_id","table":{"schema":"sf","name":"class_profile"}}},"name":"class_profile"}],"table":{"schema":"sf","name":"class"},"array_relationships":[{"using":{"foreign_key_constraint_on":{"column":"class_id","table":{"schema":"sf","name":"asset_class"}}},"name":"asset_classes"}]},{"object_relationships":[{"using":{"foreign_key_constraint_on":"class_id"},"name":"class"}],"table":{"schema":"sf","name":"class_metadata"}},{"object_relationships":[{"using":{"foreign_key_constraint_on":"creator_id"},"name":"account"},{"using":{"foreign_key_constraint_on":"class_id"},"name":"class"}],"table":{"schema":"sf","name":"class_profile"}},{"table":{"schema":"sf","name":"currency"}},{"table":{"schema":"sf","name":"escrow"},"array_relationships":[{"using":{"foreign_key_constraint_on":{"column":"escrow_id","table":{"schema":"sf","name":"escrow_share"}}},"name":"escrow_shares"}]},{"object_relationships":[{"using":{"foreign_key_constraint_on":"owner"},"name":"account"},{"using":{"foreign_key_constraint_on":"escrow_id"},"name":"escrow"}],"table":{"schema":"sf","name":"escrow_share"}},{"table":{"schema":"sf","name":"market"},"array_relationships":[{"using":{"foreign_key_constraint_on":{"column":"market_id","table":{"schema":"sf","name":"market_rate"}}},"name":"market_rates"}]},{"object_relationships":[{"using":{"foreign_key_constraint_on":"market_id"},"name":"market"}],"table":{"schema":"sf","name":"market_rate"}}],"configuration":{"connection_info":{"use_prepared_statements":true,"database_url":{"from_env":"HASURA_GRAPHQL_DATABASE_URL"},"isolation_level":"read-committed","pool_settings":{"connection_lifetime":600,"retries":1,"idle_timeout":180,"max_connections":50}}}}],"version":3,"query_collections":[{"definition":{"queries":[{"name":"Accounts","query":"query get_all_accounts {\\n  sf_account {\\n    id\\n    account_profile {\\n      name\\n      chain_id\\n    }\\n    account_auth {\\n      seed\\n    }\\n  }\\n}"},{"name":"Account Create","query":"mutation create_account($account: String!, $seed: String!, $name: String!, $password: String!) {\\n  insert_sf_account_one(object: {account_auth: {data: {password: $password, seed: $seed}}, account_profile: {data: {chain_id: $account, name: $name}}}) {\\n    id\\n  }\\n}"},{"name":"Asset Create","query":"mutation asset_nft($class_id: uuid!, $account_id: uuid!, $chain_id: Int!, $chain_meta: jsonb!, $name: String!) {\\n  insert_sf_asset_one(object: {asset_metadata: {data: {chain_id: $chain_id, chain_meta: $chain_meta}}, asset_nft: {data: {name: $name}}, account_assets: {data: {account_id: $account_id}}, asset_classes: {data: {class_id: $class_id}}}) {\\n    id\\n  }\\n}"},{"name":"Bundle Get","query":"query get_bundle {\\n  sf_bundle {\\n    chain_asset_id\\n    chain_bundle_id\\n    chain_class_id\\n    id\\n    metadata\\n  }\\n}"},{"name":"Bundle by Chain","query":"query get_bundle_by_chain($chain_class_id: Int!, $chain_asset_id: Int!) {\\n  sf_bundle(where: {chain_class_id: {_eq: $chain_class_id}, chain_asset_id: {_eq: $chain_asset_id}}) {\\n    chain_asset_id\\n    chain_bundle_id\\n    chain_class_id\\n    id\\n    metadata\\n  }\\n}"},{"name":"Bundle by ID","query":"query get_bundle_by_id($id: uuid!) {\\n  sf_bundle(where: {id: {_eq: $id}}) {\\n    chain_asset_id\\n    chain_bundle_id\\n    chain_class_id\\n    id\\n    metadata\\n  }\\n}"},{"name":"Bundle Register","query":"mutation insert_bundle($chain_asset_id: Int!, $chain_class_id: Int!, $metadata: jsonb!, $chain_bundle_id: String!) {\\n  insert_sf_bundle_one(object: {metadata: $metadata, chain_asset_id: $chain_asset_id, chain_class_id: $chain_class_id, chain_bundle_id: $chain_bundle_id}) {\\n    chain_asset_id\\n    id\\n    metadata\\n    chain_bundle_id\\n    chain_class_id\\n  }\\n}"},{"name":"Class Create","query":"mutation create_class($chain_id: Int!, $collection_name: String!, $account_id: uuid!, $collection_description: String!, $chain_metadata: jsonb!) {\\n  insert_sf_class_one(object: {class_profile: {data: {creator_id: $account_id, description: $collection_description, name: $collection_name}}, class_metadata: {data: {chain_meta: $chain_metadata}}, chain_id: $chain_id}) {\\n    chain_id\\n    id\\n  }\\n}"},{"name":"Asset by Chain","query":"query get_asset_by_chain($asset_chain_id: Int!, $class_chain_id: Int!) {\\n  sf_asset(where: {asset_metadata: {chain_id: {_eq: $asset_chain_id}}, asset_classes: {class: {chain_id: {_eq: $class_chain_id}}}}) {\\n    id\\n    account_assets {\\n      account_id\\n    }\\n    asset_classes {\\n      class_id\\n      class {\\n        chain_id\\n      }\\n    }\\n    asset_nft {\\n      name\\n    }\\n    asset_metadata {\\n      chain_id\\n      chain_meta\\n    }\\n  }\\n}"},{"name":"Asset by ID","query":"query get_asset_by_id($id: uuid!) {\\n  sf_asset(where: {id: {_eq: $id}}) {\\n    id\\n    account_assets {\\n      account_id\\n    }\\n    asset_classes {\\n      class_id\\n      class {\\n        chain_id\\n      }\\n    }\\n    asset_metadata {\\n      chain_id\\n      chain_meta\\n    }\\n    asset_nft {\\n      name\\n    }\\n  }\\n}"},{"name":"Account assets","query":"query get_asset_by_account($account_id: uuid!) {\\n  sf_asset {\\n    id\\n    account_assets(where: {account_id: {_eq: $account_id}}) {\\n      account_id\\n    }\\n    asset_classes {\\n      class_id\\n      class {\\n        chain_id\\n      }\\n    }\\n    asset_metadata {\\n      chain_id\\n      chain_meta\\n    }\\n    asset_nft {\\n      name\\n    }\\n  }\\n}"},{"name":"Class Assets","query":"query get_asset_by_class($class_id: uuid!) {\\n  sf_asset {\\n    id\\n    account_assets {\\n      account_id\\n    }\\n    asset_classes(where: {class_id: {_eq: $class_id}}) {\\n      class_id\\n      class {\\n        chain_id\\n      }\\n    }\\n    asset_metadata {\\n      chain_id\\n      chain_meta\\n    }\\n    asset_nft {\\n      name\\n    }\\n  }\\n}"},{"name":"Classes","query":"query get_all_accounts {\\n  sf_class {\\n    chain_id\\n    id\\n    class_profile {\\n      name\\n    }\\n    asset_classes {\\n      asset {\\n        asset_metadata {\\n          asset_id\\n          chain_id\\n        }\\n        asset_nft {\\n          name\\n        }\\n      }\\n    }\\n  }\\n}"},{"name":"Market Get","query":"query get_market {\\n  sf_market {\\n    chain_id\\n    id\\n    market_rates {\\n      id\\n      chain_id\\n    }\\n  }\\n}"},{"name":"Currency Create","query":"mutation create_currency($name: String!, $symbol: String!, $chain_asset_id: Int!, $chain_class_id: Int!, $total_supply: Int!) {\\n  insert_sf_currency_one(object: {name: $name, symbol: $symbol, chain_asset_id: $chain_asset_id, chain_class_id: $chain_class_id, total_supply: $total_supply}) {\\n    id\\n    name\\n   \\tsymbol\\t\\n    chain_asset_id\\n    chain_class_id\\n    total_supply\\n    current_supply   \\n  }\\n}"},{"name":"Currency Get","query":"query get_currencies {\\n  sf_currency {\\n    id\\n    name\\n    symbol\\n    total_supply\\n    current_supply\\n    chain_class_id\\n    chain_asset_id\\n  }\\n}"},{"name":"Currency Update","query":"mutation update_currency($id: uuid!, $current_supply: Int!) {\\n  update_sf_currency(where: {id: {_eq: $id}}, _set: {current_supply: $current_supply}) {\\n    returning {\\n      id\\n      name\\n      symbol\\n      total_supply\\n      current_supply\\n      chain_asset_id\\n      chain_class_id\\n    }\\n  }\\n}"},{"name":"Asset Get","query":"query get_asset {\\n  sf_asset {\\n    id\\n    account_assets {\\n      account_id\\n    }\\n    asset_classes {\\n      class_id\\n      class {\\n        chain_id\\n      }\\n    }\\n    asset_metadata {\\n      chain_id\\n      chain_meta\\n    }\\n    asset_nft {\\n      name\\n    }\\n  }\\n}"},{"name":"Market Create","query":"mutation insert_market($market_rate_chain_id: Int!, $market_chain_id: Int!) {\\n  insert_sf_market_one(object: {market_rates: {data: {chain_id: $market_rate_chain_id}}, chain_id: $market_chain_id}) {\\n    id\\n  }\\n}"},{"name":"Escrow Create","query":"mutation create_escrow($id: uuid!, $asset_id: Int!, $chain_id: String!) {\\n  update_sf_escrow(where: {id: {_eq: $id}}, _set: {asset_id: $asset_id, chain_id: $chain_id}) {\\n    returning {\\n      class_id\\n      asset_id\\n      id\\n      metadata\\n      chain_id\\n    }\\n  }\\n}"},{"name":"Escrow Get","query":"query get_escrow {\\n  sf_escrow {\\n    id\\n    chain_id\\n    class_id\\n    metadata\\n    escrow_shares {\\n      owner\\n      share\\n    }\\n  }\\n}"},{"name":"Escrow Register","query":"mutation register_escrow($metadata: jsonb!, $class_id: Int!) {\\n  insert_sf_escrow_one(object: {metadata: $metadata, class_id: $class_id}) {\\n    id\\n    metadata\\n  }\\n}"},{"name":"Escrow Owners","query":"mutation escrow_owners($owners: [sf_escrow_share_insert_input!]!) {\\n  insert_sf_escrow_share(objects: $owners) {\\n    returning {\\n      escrow_id\\n      owner\\n      share\\n    }\\n  }\\n}"},{"name":"Market by Chain","query":"query get_market_by_chain($market_chain_id: Int!, $market_rate_chain_id: Int!) {\\n  sf_market(where: {chain_id: {_eq: $market_chain_id}, market_rates: {chain_id: {_eq: $market_rate_chain_id}}}) {\\n    chain_id\\n    id\\n    market_rates {\\n      id\\n      chain_id\\n    }\\n  }\\n}"},{"name":"Market by ID","query":"query get_market_by_id($id: uuid!) {\\n  sf_market(where: {id: {_eq: $id}}) {\\n    chain_id\\n    id\\n    market_rates {\\n      id\\n      chain_id\\n    }\\n  }\\n}"},{"name":"Market Rate by ID","query":"query get_market_rate_by_id($id: uuid!) {\\n  sf_market {\\n    chain_id\\n    id\\n    market_rates(where: {id: {_eq: $id}}) {\\n      id\\n      chain_id\\n    }\\n  }\\n}"}]},"name":"allowed-queries"}]}	257
\.


--
-- TOC entry 3298 (class 0 OID 16505)
-- Dependencies: 209
-- Data for Name: hdb_scheduled_event_invocation_logs; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_scheduled_event_invocation_logs (id, event_id, status, request, response, created_at) FROM stdin;
\.


--
-- TOC entry 3297 (class 0 OID 16491)
-- Dependencies: 208
-- Data for Name: hdb_scheduled_events; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_scheduled_events (id, webhook_conf, scheduled_time, retry_conf, payload, header_conf, status, tries, created_at, next_retry_at, comment) FROM stdin;
\.


--
-- TOC entry 3299 (class 0 OID 16520)
-- Dependencies: 210
-- Data for Name: hdb_schema_notifications; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_schema_notifications (id, notification, resource_version, instance_id, updated_at) FROM stdin;
1	{"metadata":true,"remote_schemas":[],"sources":[]}	257	6f56c900-592d-49d0-965f-bdf3f777f3c3	2021-05-20 21:59:06.468494+00
\.


--
-- TOC entry 3302 (class 0 OID 16553)
-- Dependencies: 213
-- Data for Name: hdb_source_catalog_version; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_source_catalog_version (version, upgraded_on) FROM stdin;
1	2021-05-14 18:18:46.14169+00
\.


--
-- TOC entry 3292 (class 0 OID 16426)
-- Dependencies: 203
-- Data for Name: hdb_version; Type: TABLE DATA; Schema: hdb_catalog; Owner: hasura
--

COPY hdb_catalog.hdb_version (hasura_uuid, version, upgraded_on, cli_state, console_state) FROM stdin;
6341c351-4ed3-460e-8b19-486dd9ac2b0f	47	2022-03-11 21:46:42.163527+00	{"settings": {"migration_mode": "true"}, "migrations": {"default": {"1648066704964": false, "1651616028986": false, "1651620713337": false, "1651620759145": false, "1651687194030": false}}, "isStateCopyCompleted": true}	{"onboardingShown": true, "console_notifications": {"admin": {"date": null, "read": [], "showBadge": true}}, "telemetryNotificationShown": true}
\.


--
-- TOC entry 3303 (class 0 OID 16559)
-- Dependencies: 214
-- Data for Name: account; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.account (id) FROM stdin;
a0893d5b-7d6b-41f7-b7b7-5f2a91a73ce4
8dca283e-9654-41c0-a758-31063fb24742
8e29794a-41c6-4a4e-8878-51fe8f1c45b7
\.


--
-- TOC entry 3304 (class 0 OID 16563)
-- Dependencies: 215
-- Data for Name: account_asset; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.account_asset (account_id, asset_id) FROM stdin;
a0893d5b-7d6b-41f7-b7b7-5f2a91a73ce4	6ec34605-da76-48d3-9d3b-06cae526dba9
\.


--
-- TOC entry 3305 (class 0 OID 16566)
-- Dependencies: 216
-- Data for Name: account_auth; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.account_auth (account_id, password, seed) FROM stdin;
a0893d5b-7d6b-41f7-b7b7-5f2a91a73ce4	Alice	//Alice
8dca283e-9654-41c0-a758-31063fb24742	bob123	//Bob
8e29794a-41c6-4a4e-8878-51fe8f1c45b7	123lol	//6d631f9cdea8615b69bbd8cb82e438dda4b39015d4ad017912bb585ae42c43d3
\.


--
-- TOC entry 3306 (class 0 OID 16572)
-- Dependencies: 217
-- Data for Name: account_profile; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.account_profile (account_id, chain_id, name) FROM stdin;
a0893d5b-7d6b-41f7-b7b7-5f2a91a73ce4	5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY	Alice
8dca283e-9654-41c0-a758-31063fb24742	5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty	Bob
8e29794a-41c6-4a4e-8878-51fe8f1c45b7	5GdcETweYRQrDLSCwRERXR74zUayn323VhpH3k12ssv1Ypsq	Niv
\.


--
-- TOC entry 3307 (class 0 OID 16578)
-- Dependencies: 218
-- Data for Name: asset; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.asset (id) FROM stdin;
6ec34605-da76-48d3-9d3b-06cae526dba9
\.


--
-- TOC entry 3318 (class 0 OID 17322)
-- Dependencies: 229
-- Data for Name: asset_class; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.asset_class (asset_id, class_id) FROM stdin;
6ec34605-da76-48d3-9d3b-06cae526dba9	8089fc1f-8b30-4628-8784-976aeb95afec
\.


--
-- TOC entry 3308 (class 0 OID 16585)
-- Dependencies: 219
-- Data for Name: asset_metadata; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.asset_metadata (asset_id, chain_meta, chain_id) FROM stdin;
6ec34605-da76-48d3-9d3b-06cae526dba9	{"data": "somedata"}	1
\.


--
-- TOC entry 3309 (class 0 OID 16591)
-- Dependencies: 220
-- Data for Name: asset_nft; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.asset_nft (asset_id, name) FROM stdin;
6ec34605-da76-48d3-9d3b-06cae526dba9	Asset Name
\.


--
-- TOC entry 3314 (class 0 OID 17215)
-- Dependencies: 225
-- Data for Name: bundle; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.bundle (id, metadata, chain_bundle_id, chain_class_id, chain_asset_id) FROM stdin;
6462b3ee-f690-40a7-9c7e-aa27dfc723c5	{"data": "somedata"}	8a804cccd49626baff500f1ad93b154045d218642e219fd0f23770a8054cf766	1000	1
\.


--
-- TOC entry 3315 (class 0 OID 17277)
-- Dependencies: 226
-- Data for Name: class; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.class (id, chain_id) FROM stdin;
8089fc1f-8b30-4628-8784-976aeb95afec	1
\.


--
-- TOC entry 3316 (class 0 OID 17285)
-- Dependencies: 227
-- Data for Name: class_metadata; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.class_metadata (class_id, chain_meta) FROM stdin;
8089fc1f-8b30-4628-8784-976aeb95afec	{"userdata": "some data"}
\.


--
-- TOC entry 3317 (class 0 OID 17293)
-- Dependencies: 228
-- Data for Name: class_profile; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.class_profile (class_id, creator_id, name, description) FROM stdin;
8089fc1f-8b30-4628-8784-976aeb95afec	a0893d5b-7d6b-41f7-b7b7-5f2a91a73ce4	Class Name	Class Description
\.


--
-- TOC entry 3319 (class 0 OID 17470)
-- Dependencies: 230
-- Data for Name: currency; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.currency (id, name, symbol, total_supply, chain_class_id, chain_asset_id, current_supply) FROM stdin;
c06eb3ca-2bf6-456e-b3ba-ea5447baa1e1	Name	Symbol	1000000	9000	0	0
\.


--
-- TOC entry 3312 (class 0 OID 17161)
-- Dependencies: 223
-- Data for Name: escrow; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.escrow (id, class_id, metadata, asset_id, chain_id) FROM stdin;
2774b651-068d-4e8b-b3a1-04ba5036ec02	1002	{"data": "somedata"}	1	5EYCAe5jLQkbmk7kHzj6Fto7aCdKjARmxedYH4VhqQctZrQx
1de1f60a-29e5-4371-9dae-660b6f483c07	1003	{"data": "somedata"}	0	5EYCAe5jLQkbmk7kHzixa6QQcgcG3vC6FDvQUsny8nDwXLU8
635bb527-1547-4dba-a2cf-34c5fdfd1430	1005	{"data": "somedata"}	0	5EYCAe5jLQkbmk7kHzizAqWXeTxWEYcE4EwhV4XZoR9V1aN2
\.


--
-- TOC entry 3313 (class 0 OID 17175)
-- Dependencies: 224
-- Data for Name: escrow_share; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.escrow_share (escrow_id, owner, share) FROM stdin;
635bb527-1547-4dba-a2cf-34c5fdfd1430	a0893d5b-7d6b-41f7-b7b7-5f2a91a73ce4	1
635bb527-1547-4dba-a2cf-34c5fdfd1430	8dca283e-9654-41c0-a758-31063fb24742	2
635bb527-1547-4dba-a2cf-34c5fdfd1430	8e29794a-41c6-4a4e-8878-51fe8f1c45b7	3
\.


--
-- TOC entry 3310 (class 0 OID 17088)
-- Dependencies: 221
-- Data for Name: market; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.market (id, chain_id) FROM stdin;
ea0947c9-fcea-443c-bcb2-dcc021c5d2a7	1
1b7689cc-fc30-40dd-be5f-41cf2bfae3a5	2
\.


--
-- TOC entry 3311 (class 0 OID 17094)
-- Dependencies: 222
-- Data for Name: market_rate; Type: TABLE DATA; Schema: sf; Owner: hasura
--

COPY sf.market_rate (id, market_id, chain_id) FROM stdin;
c3df776a-92d8-4284-9def-c49253d846b7	ea0947c9-fcea-443c-bcb2-dcc021c5d2a7	1
d7263656-89b9-426c-b581-1a49fba34a6b	1b7689cc-fc30-40dd-be5f-41cf2bfae3a5	2
\.


--
-- TOC entry 3087 (class 2606 OID 16622)
-- Name: event_invocation_logs event_invocation_logs_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.event_invocation_logs
    ADD CONSTRAINT event_invocation_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 3092 (class 2606 OID 16624)
-- Name: event_log event_log_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.event_log
    ADD CONSTRAINT event_log_pkey PRIMARY KEY (id);


--
-- TOC entry 3070 (class 2606 OID 16459)
-- Name: hdb_action_log hdb_action_log_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_action_log
    ADD CONSTRAINT hdb_action_log_pkey PRIMARY KEY (id);


--
-- TOC entry 3077 (class 2606 OID 16484)
-- Name: hdb_cron_event_invocation_logs hdb_cron_event_invocation_logs_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_event_invocation_logs
    ADD CONSTRAINT hdb_cron_event_invocation_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 3073 (class 2606 OID 16472)
-- Name: hdb_cron_events hdb_cron_events_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_events
    ADD CONSTRAINT hdb_cron_events_pkey PRIMARY KEY (id);


--
-- TOC entry 3066 (class 2606 OID 16446)
-- Name: hdb_metadata hdb_metadata_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_metadata
    ADD CONSTRAINT hdb_metadata_pkey PRIMARY KEY (id);


--
-- TOC entry 3068 (class 2606 OID 16448)
-- Name: hdb_metadata hdb_metadata_resource_version_key; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_metadata
    ADD CONSTRAINT hdb_metadata_resource_version_key UNIQUE (resource_version);


--
-- TOC entry 3082 (class 2606 OID 16514)
-- Name: hdb_scheduled_event_invocation_logs hdb_scheduled_event_invocation_logs_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_event_invocation_logs
    ADD CONSTRAINT hdb_scheduled_event_invocation_logs_pkey PRIMARY KEY (id);


--
-- TOC entry 3080 (class 2606 OID 16503)
-- Name: hdb_scheduled_events hdb_scheduled_events_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_events
    ADD CONSTRAINT hdb_scheduled_events_pkey PRIMARY KEY (id);


--
-- TOC entry 3084 (class 2606 OID 16530)
-- Name: hdb_schema_notifications hdb_schema_notifications_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_schema_notifications
    ADD CONSTRAINT hdb_schema_notifications_pkey PRIMARY KEY (id);


--
-- TOC entry 3064 (class 2606 OID 16436)
-- Name: hdb_version hdb_version_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_version
    ADD CONSTRAINT hdb_version_pkey PRIMARY KEY (hasura_uuid);


--
-- TOC entry 3098 (class 2606 OID 16626)
-- Name: account_asset account_asset_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_asset
    ADD CONSTRAINT account_asset_pkey PRIMARY KEY (account_id, asset_id);


--
-- TOC entry 3100 (class 2606 OID 16628)
-- Name: account_auth account_auth_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_auth
    ADD CONSTRAINT account_auth_pkey PRIMARY KEY (account_id);


--
-- TOC entry 3102 (class 2606 OID 16630)
-- Name: account_auth account_auth_seed_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_auth
    ADD CONSTRAINT account_auth_seed_key UNIQUE (seed);


--
-- TOC entry 3096 (class 2606 OID 16632)
-- Name: account account_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- TOC entry 3104 (class 2606 OID 16634)
-- Name: account_profile account_profile_chain_id_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_profile
    ADD CONSTRAINT account_profile_chain_id_key UNIQUE (chain_id);


--
-- TOC entry 3106 (class 2606 OID 16636)
-- Name: account_profile account_profile_name_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_profile
    ADD CONSTRAINT account_profile_name_key UNIQUE (name);


--
-- TOC entry 3108 (class 2606 OID 16638)
-- Name: account_profile account_profile_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_profile
    ADD CONSTRAINT account_profile_pkey PRIMARY KEY (account_id);


--
-- TOC entry 3136 (class 2606 OID 17326)
-- Name: asset_class asset_class_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset_class
    ADD CONSTRAINT asset_class_pkey PRIMARY KEY (asset_id, class_id);


--
-- TOC entry 3112 (class 2606 OID 16644)
-- Name: asset_metadata asset_metadata_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset_metadata
    ADD CONSTRAINT asset_metadata_pkey PRIMARY KEY (asset_id);


--
-- TOC entry 3114 (class 2606 OID 16646)
-- Name: asset_nft asset_nft_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset_nft
    ADD CONSTRAINT asset_nft_pkey PRIMARY KEY (asset_id);


--
-- TOC entry 3110 (class 2606 OID 16648)
-- Name: asset asset_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset
    ADD CONSTRAINT asset_pkey PRIMARY KEY (id);


--
-- TOC entry 3124 (class 2606 OID 17274)
-- Name: bundle bundle_bundle_id_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.bundle
    ADD CONSTRAINT bundle_bundle_id_key UNIQUE (chain_bundle_id);


--
-- TOC entry 3126 (class 2606 OID 17222)
-- Name: bundle bundle_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.bundle
    ADD CONSTRAINT bundle_pkey PRIMARY KEY (id);


--
-- TOC entry 3128 (class 2606 OID 17284)
-- Name: class class_chain_id_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.class
    ADD CONSTRAINT class_chain_id_key UNIQUE (chain_id);


--
-- TOC entry 3132 (class 2606 OID 17292)
-- Name: class_metadata class_metadata_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.class_metadata
    ADD CONSTRAINT class_metadata_pkey PRIMARY KEY (class_id);


--
-- TOC entry 3130 (class 2606 OID 17282)
-- Name: class class_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);


--
-- TOC entry 3134 (class 2606 OID 17300)
-- Name: class_profile class_profile_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.class_profile
    ADD CONSTRAINT class_profile_pkey PRIMARY KEY (class_id);


--
-- TOC entry 3138 (class 2606 OID 17480)
-- Name: currency currency_chain_class_id_chain_asset_id_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.currency
    ADD CONSTRAINT currency_chain_class_id_chain_asset_id_key UNIQUE (chain_class_id, chain_asset_id);


--
-- TOC entry 3140 (class 2606 OID 17490)
-- Name: currency currency_name_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.currency
    ADD CONSTRAINT currency_name_key UNIQUE (name);


--
-- TOC entry 3142 (class 2606 OID 17478)
-- Name: currency currency_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (id);


--
-- TOC entry 3144 (class 2606 OID 17493)
-- Name: currency currency_symbol_key; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.currency
    ADD CONSTRAINT currency_symbol_key UNIQUE (symbol);


--
-- TOC entry 3120 (class 2606 OID 17169)
-- Name: escrow escrow_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.escrow
    ADD CONSTRAINT escrow_pkey PRIMARY KEY (id);


--
-- TOC entry 3122 (class 2606 OID 17179)
-- Name: escrow_share escrow_shares_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.escrow_share
    ADD CONSTRAINT escrow_shares_pkey PRIMARY KEY (escrow_id, owner);


--
-- TOC entry 3116 (class 2606 OID 17093)
-- Name: market market_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.market
    ADD CONSTRAINT market_pkey PRIMARY KEY (id);


--
-- TOC entry 3118 (class 2606 OID 17099)
-- Name: market_rate market_rate_pkey; Type: CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.market_rate
    ADD CONSTRAINT market_rate_pkey PRIMARY KEY (id);


--
-- TOC entry 3085 (class 1259 OID 16663)
-- Name: event_invocation_logs_event_id_idx; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX event_invocation_logs_event_id_idx ON hdb_catalog.event_invocation_logs USING btree (event_id);


--
-- TOC entry 3088 (class 1259 OID 16664)
-- Name: event_log_created_at_idx; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX event_log_created_at_idx ON hdb_catalog.event_log USING btree (created_at);


--
-- TOC entry 3089 (class 1259 OID 16665)
-- Name: event_log_delivered_idx; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX event_log_delivered_idx ON hdb_catalog.event_log USING btree (delivered);


--
-- TOC entry 3090 (class 1259 OID 16666)
-- Name: event_log_locked_idx; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX event_log_locked_idx ON hdb_catalog.event_log USING btree (locked);


--
-- TOC entry 3093 (class 1259 OID 16667)
-- Name: event_log_trigger_name_idx; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX event_log_trigger_name_idx ON hdb_catalog.event_log USING btree (trigger_name);


--
-- TOC entry 3075 (class 1259 OID 16490)
-- Name: hdb_cron_event_invocation_event_id; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX hdb_cron_event_invocation_event_id ON hdb_catalog.hdb_cron_event_invocation_logs USING btree (event_id);


--
-- TOC entry 3071 (class 1259 OID 16473)
-- Name: hdb_cron_event_status; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX hdb_cron_event_status ON hdb_catalog.hdb_cron_events USING btree (status);


--
-- TOC entry 3074 (class 1259 OID 16474)
-- Name: hdb_cron_events_unique_scheduled; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE UNIQUE INDEX hdb_cron_events_unique_scheduled ON hdb_catalog.hdb_cron_events USING btree (trigger_name, scheduled_time) WHERE (status = 'scheduled'::text);


--
-- TOC entry 3078 (class 1259 OID 16504)
-- Name: hdb_scheduled_event_status; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE INDEX hdb_scheduled_event_status ON hdb_catalog.hdb_scheduled_events USING btree (status);


--
-- TOC entry 3094 (class 1259 OID 16668)
-- Name: hdb_source_catalog_version_one_row; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE UNIQUE INDEX hdb_source_catalog_version_one_row ON hdb_catalog.hdb_source_catalog_version USING btree (((version IS NOT NULL)));


--
-- TOC entry 3062 (class 1259 OID 16437)
-- Name: hdb_version_one_row; Type: INDEX; Schema: hdb_catalog; Owner: hasura
--

CREATE UNIQUE INDEX hdb_version_one_row ON hdb_catalog.hdb_version USING btree (((version IS NOT NULL)));


--
-- TOC entry 3147 (class 2606 OID 16669)
-- Name: event_invocation_logs event_invocation_logs_event_id_fkey; Type: FK CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.event_invocation_logs
    ADD CONSTRAINT event_invocation_logs_event_id_fkey FOREIGN KEY (event_id) REFERENCES hdb_catalog.event_log(id);


--
-- TOC entry 3145 (class 2606 OID 16485)
-- Name: hdb_cron_event_invocation_logs hdb_cron_event_invocation_logs_event_id_fkey; Type: FK CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_event_invocation_logs
    ADD CONSTRAINT hdb_cron_event_invocation_logs_event_id_fkey FOREIGN KEY (event_id) REFERENCES hdb_catalog.hdb_cron_events(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3146 (class 2606 OID 16515)
-- Name: hdb_scheduled_event_invocation_logs hdb_scheduled_event_invocation_logs_event_id_fkey; Type: FK CONSTRAINT; Schema: hdb_catalog; Owner: hasura
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_event_invocation_logs
    ADD CONSTRAINT hdb_scheduled_event_invocation_logs_event_id_fkey FOREIGN KEY (event_id) REFERENCES hdb_catalog.hdb_scheduled_events(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3148 (class 2606 OID 16674)
-- Name: account_asset account_asset_account_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_asset
    ADD CONSTRAINT account_asset_account_id_fkey FOREIGN KEY (account_id) REFERENCES sf.account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3149 (class 2606 OID 16679)
-- Name: account_asset account_asset_asset_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_asset
    ADD CONSTRAINT account_asset_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES sf.asset(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3150 (class 2606 OID 16684)
-- Name: account_auth account_auth_account_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_auth
    ADD CONSTRAINT account_auth_account_id_fkey FOREIGN KEY (account_id) REFERENCES sf.account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3151 (class 2606 OID 16689)
-- Name: account_profile account_profile_account_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.account_profile
    ADD CONSTRAINT account_profile_account_id_fkey FOREIGN KEY (account_id) REFERENCES sf.account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3160 (class 2606 OID 17327)
-- Name: asset_class asset_class_asset_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset_class
    ADD CONSTRAINT asset_class_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES sf.asset(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3161 (class 2606 OID 17332)
-- Name: asset_class asset_class_class_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset_class
    ADD CONSTRAINT asset_class_class_id_fkey FOREIGN KEY (class_id) REFERENCES sf.class(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3152 (class 2606 OID 16704)
-- Name: asset_metadata asset_metadata_asset_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset_metadata
    ADD CONSTRAINT asset_metadata_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES sf.asset(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3153 (class 2606 OID 16709)
-- Name: asset_nft asset_nft_asset_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.asset_nft
    ADD CONSTRAINT asset_nft_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES sf.asset(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3157 (class 2606 OID 17311)
-- Name: class_metadata class_metadata_class_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.class_metadata
    ADD CONSTRAINT class_metadata_class_id_fkey FOREIGN KEY (class_id) REFERENCES sf.class(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3159 (class 2606 OID 17306)
-- Name: class_profile class_profile_class_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.class_profile
    ADD CONSTRAINT class_profile_class_id_fkey FOREIGN KEY (class_id) REFERENCES sf.class(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3158 (class 2606 OID 17301)
-- Name: class_profile class_profile_creator_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.class_profile
    ADD CONSTRAINT class_profile_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES sf.account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3155 (class 2606 OID 17546)
-- Name: escrow_share escrow_share_escrow_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.escrow_share
    ADD CONSTRAINT escrow_share_escrow_id_fkey FOREIGN KEY (escrow_id) REFERENCES sf.escrow(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3156 (class 2606 OID 17552)
-- Name: escrow_share escrow_share_owner_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.escrow_share
    ADD CONSTRAINT escrow_share_owner_fkey FOREIGN KEY (owner) REFERENCES sf.account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3154 (class 2606 OID 17100)
-- Name: market_rate market_rate_market_id_fkey; Type: FK CONSTRAINT; Schema: sf; Owner: hasura
--

ALTER TABLE ONLY sf.market_rate
    ADD CONSTRAINT market_rate_market_id_fkey FOREIGN KEY (market_id) REFERENCES sf.market(id) ON UPDATE CASCADE ON DELETE CASCADE;


-- Completed on 2022-05-04 18:46:01 UTC

--
-- PostgreSQL database dump complete
--

