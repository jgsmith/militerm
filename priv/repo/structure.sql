--
-- PostgreSQL database dump
--

-- Dumped from database version 11.2
-- Dumped by pg_dump version 11.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: core_areas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.core_areas (
    id bigint NOT NULL,
    name character varying(255),
    plug character varying(255),
    description text,
    domain_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: core_areas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.core_areas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_areas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_areas_id_seq OWNED BY public.core_areas.id;


--
-- Name: core_domains; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.core_domains (
    id bigint NOT NULL,
    name character varying(255),
    plug character varying(255),
    description text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: core_domains_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.core_domains_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_domains_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_domains_id_seq OWNED BY public.core_domains.id;


--
-- Name: core_scenes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.core_scenes (
    id bigint NOT NULL,
    archetype character varying(255) NOT NULL,
    description text,
    plug character varying(255) NOT NULL,
    area_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: core_scenes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.core_scenes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: core_scenes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.core_scenes_id_seq OWNED BY public.core_scenes.id;


--
-- Name: details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.details (
    id bigint NOT NULL,
    entity_id character varying(255),
    detail character varying(255),
    data jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: details_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.details_id_seq OWNED BY public.details.id;


--
-- Name: entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entities (
    id bigint NOT NULL,
    entity_id character varying(255),
    data jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.entities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.entities_id_seq OWNED BY public.entities.id;


--
-- Name: flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flags (
    id bigint NOT NULL,
    entity_id character varying(255),
    flags character varying(255)[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: flags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flags_id_seq OWNED BY public.flags.id;


--
-- Name: identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identities (
    id bigint NOT NULL,
    entity_id character varying(255),
    data jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identities_id_seq OWNED BY public.identities.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id bigint NOT NULL,
    entity_id character varying(255),
    target_id character varying(255),
    t integer,
    detail character varying(255),
    relationship character varying(255),
    "position" character varying(255),
    point integer[],
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: traits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traits (
    id bigint NOT NULL,
    entity_id character varying(255),
    data jsonb,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: traits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traits_id_seq OWNED BY public.traits.id;


--
-- Name: core_areas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_areas ALTER COLUMN id SET DEFAULT nextval('public.core_areas_id_seq'::regclass);


--
-- Name: core_domains id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_domains ALTER COLUMN id SET DEFAULT nextval('public.core_domains_id_seq'::regclass);


--
-- Name: core_scenes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_scenes ALTER COLUMN id SET DEFAULT nextval('public.core_scenes_id_seq'::regclass);


--
-- Name: details id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.details ALTER COLUMN id SET DEFAULT nextval('public.details_id_seq'::regclass);


--
-- Name: entities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities ALTER COLUMN id SET DEFAULT nextval('public.entities_id_seq'::regclass);


--
-- Name: flags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags ALTER COLUMN id SET DEFAULT nextval('public.flags_id_seq'::regclass);


--
-- Name: identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identities ALTER COLUMN id SET DEFAULT nextval('public.identities_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- Name: traits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits ALTER COLUMN id SET DEFAULT nextval('public.traits_id_seq'::regclass);


--
-- Name: core_areas core_areas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_areas
    ADD CONSTRAINT core_areas_pkey PRIMARY KEY (id);


--
-- Name: core_domains core_domains_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_domains
    ADD CONSTRAINT core_domains_pkey PRIMARY KEY (id);


--
-- Name: core_scenes core_scenes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_scenes
    ADD CONSTRAINT core_scenes_pkey PRIMARY KEY (id);


--
-- Name: details details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.details
    ADD CONSTRAINT details_pkey PRIMARY KEY (id);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: flags flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags
    ADD CONSTRAINT flags_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: traits traits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits
    ADD CONSTRAINT traits_pkey PRIMARY KEY (id);


--
-- Name: core_areas_domain_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX core_areas_domain_id_index ON public.core_areas USING btree (domain_id);


--
-- Name: core_areas_domain_id_plug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX core_areas_domain_id_plug_index ON public.core_areas USING btree (domain_id, plug);


--
-- Name: core_domains_plug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX core_domains_plug_index ON public.core_domains USING btree (plug);


--
-- Name: core_scenes_area_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX core_scenes_area_id_index ON public.core_scenes USING btree (area_id);


--
-- Name: core_scenes_area_id_plug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX core_scenes_area_id_plug_index ON public.core_scenes USING btree (area_id, plug);


--
-- Name: details_entity_id_detail_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX details_entity_id_detail_index ON public.details USING btree (entity_id, detail);


--
-- Name: entities_entity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX entities_entity_id_index ON public.entities USING btree (entity_id);


--
-- Name: flags_entity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX flags_entity_id_index ON public.flags USING btree (entity_id);


--
-- Name: identities_entity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX identities_entity_id_index ON public.identities USING btree (entity_id);


--
-- Name: locations_entity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX locations_entity_id_index ON public.locations USING btree (entity_id);


--
-- Name: locations_target_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_target_id_index ON public.locations USING btree (target_id);


--
-- Name: traits_entity_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX traits_entity_id_index ON public.traits USING btree (entity_id);


--
-- Name: core_areas core_areas_domain_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_areas
    ADD CONSTRAINT core_areas_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES public.core_domains(id);


--
-- Name: core_scenes core_scenes_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.core_scenes
    ADD CONSTRAINT core_scenes_area_id_fkey FOREIGN KEY (area_id) REFERENCES public.core_areas(id);


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20200106003951), (20200106133028), (20200107005156), (20200115125732), (20200115125928), (20200119003816), (20200204173613), (20200209201958), (20200209203051);

