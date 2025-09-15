--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2 (Debian 16.2-1.pgdg120+2)
-- Dumped by pg_dump version 16.2 (Debian 16.2-1.pgdg120+2)

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
-- Name: prevent_concurrent_pending_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_concurrent_pending_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        -- If trying to set pending_update_since when it's already set
        IF NEW.pending_update_since IS NOT NULL AND 
           OLD.pending_update_since IS NOT NULL AND
           NEW.pending_update_since != OLD.pending_update_since THEN
          RAISE EXCEPTION 'Concurrent pending update not allowed for record %', NEW.id
            USING ERRCODE = 'unique_violation';
        END IF;
        
        -- Allow clearing pending_update_since (setting to NULL)
        -- Allow initial setting when OLD value is NULL
        RETURN NEW;
      END;
      $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: shared_profile_read_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shared_profile_read_models (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    first_name character varying,
    last_name character varying,
    email character varying,
    birth_date character varying,
    phone_number character varying,
    address character varying,
    city character varying,
    country character varying,
    postal_code character varying,
    test_personal_info_revision integer DEFAULT '-1'::integer NOT NULL,
    test_contact_info_revision integer DEFAULT '-1'::integer NOT NULL,
    locale character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pending_update_since timestamp(6) without time zone
);


--
-- Name: test_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_locations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    revision integer DEFAULT '-1'::integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: test_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.test_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying,
    name character varying,
    age integer,
    active boolean,
    document_ids character varying,
    another character varying,
    test_field character varying,
    location_id uuid,
    shortcut_description character varying,
    shortcuts_used integer,
    shortcut_usage_enabled boolean,
    shortcut_toggle boolean,
    published boolean,
    locale_test character varying,
    revision integer DEFAULT '-1'::integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    pending_update_since timestamp(6) without time zone
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: shared_profile_read_models shared_profile_read_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_profile_read_models
    ADD CONSTRAINT shared_profile_read_models_pkey PRIMARY KEY (id);


--
-- Name: test_locations test_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_locations
    ADD CONSTRAINT test_locations_pkey PRIMARY KEY (id);


--
-- Name: test_users test_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.test_users
    ADD CONSTRAINT test_users_pkey PRIMARY KEY (id);


--
-- Name: idx_shared_profiles_pending_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shared_profiles_pending_recovery ON public.shared_profile_read_models USING btree (pending_update_since) WHERE (pending_update_since IS NOT NULL);


--
-- Name: idx_test_users_pending_recovery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_test_users_pending_recovery ON public.test_users USING btree (pending_update_since) WHERE (pending_update_since IS NOT NULL);


--
-- Name: index_shared_profile_read_models_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shared_profile_read_models_on_email ON public.shared_profile_read_models USING btree (email);


--
-- Name: shared_profile_read_models trg_shared_profiles_prevent_concurrent_pending; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_shared_profiles_prevent_concurrent_pending BEFORE UPDATE ON public.shared_profile_read_models FOR EACH ROW EXECUTE FUNCTION public.prevent_concurrent_pending_update();


--
-- Name: test_users trg_test_users_prevent_concurrent_pending; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_test_users_prevent_concurrent_pending BEFORE UPDATE ON public.test_users FOR EACH ROW EXECUTE FUNCTION public.prevent_concurrent_pending_update();


--
-- PostgreSQL database dump complete
--

