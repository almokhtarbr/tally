SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: anomalies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.anomalies (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    event_name character varying NOT NULL,
    anomaly_type character varying NOT NULL,
    expected_value double precision NOT NULL,
    actual_value double precision NOT NULL,
    z_score double precision NOT NULL,
    severity character varying DEFAULT 'info'::character varying NOT NULL,
    detected_at timestamp(6) without time zone NOT NULL,
    resolved_at timestamp(6) without time zone,
    acknowledged boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: anomalies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.anomalies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: anomalies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.anomalies_id_seq OWNED BY public.anomalies.id;


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
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint,
    action character varying NOT NULL,
    summary character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;


--
-- Name: dashboard_widgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboard_widgets (
    id bigint NOT NULL,
    dashboard_id bigint NOT NULL,
    saved_report_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    range_days integer DEFAULT 30 NOT NULL
);


--
-- Name: dashboard_widgets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboard_widgets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboard_widgets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboard_widgets_id_seq OWNED BY public.dashboard_widgets.id;


--
-- Name: dashboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dashboards (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dashboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dashboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dashboards_id_seq OWNED BY public.dashboards.id;


--
-- Name: event_daily_rollups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_daily_rollups (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    event_name character varying NOT NULL,
    date date NOT NULL,
    count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: event_daily_rollups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_daily_rollups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_daily_rollups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_daily_rollups_id_seq OWNED BY public.event_daily_rollups.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    user_profile_id bigint,
    name character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying,
    occurred_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
)
PARTITION BY RANGE (occurred_at);


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: events_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events_default (
    id bigint DEFAULT nextval('public.events_id_seq'::regclass) NOT NULL,
    project_id bigint NOT NULL,
    user_profile_id bigint,
    name character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying,
    occurred_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: events_y2026m02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events_y2026m02 (
    id bigint DEFAULT nextval('public.events_id_seq'::regclass) NOT NULL,
    project_id bigint NOT NULL,
    user_profile_id bigint,
    name character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying,
    occurred_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: events_y2026m03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events_y2026m03 (
    id bigint DEFAULT nextval('public.events_id_seq'::regclass) NOT NULL,
    project_id bigint NOT NULL,
    user_profile_id bigint,
    name character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying,
    occurred_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: events_y2026m04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events_y2026m04 (
    id bigint DEFAULT nextval('public.events_id_seq'::regclass) NOT NULL,
    project_id bigint NOT NULL,
    user_profile_id bigint,
    name character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying,
    occurred_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: events_y2026m05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events_y2026m05 (
    id bigint DEFAULT nextval('public.events_id_seq'::regclass) NOT NULL,
    project_id bigint NOT NULL,
    user_profile_id bigint,
    name character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb NOT NULL,
    idempotency_key character varying,
    occurred_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: identity_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identity_aliases (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    anonymous_id character varying NOT NULL,
    user_profile_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: identity_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identity_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identity_aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identity_aliases_id_seq OWNED BY public.identity_aliases.id;


--
-- Name: project_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_memberships (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    project_id bigint NOT NULL,
    role character varying DEFAULT 'viewer'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    weekly_digest boolean DEFAULT true NOT NULL
);


--
-- Name: project_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_memberships_id_seq OWNED BY public.project_memberships.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    name character varying NOT NULL,
    url character varying,
    api_key character varying NOT NULL,
    api_secret character varying NOT NULL,
    events_count integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    conversion_event character varying DEFAULT 'purchase'::character varying,
    avg_conversion_value numeric(10,2),
    retention_days integer,
    share_token character varying
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: saved_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_reports (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    name character varying NOT NULL,
    report_type character varying NOT NULL,
    configuration jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: saved_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_reports_id_seq OWNED BY public.saved_reports.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: segments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.segments (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    name character varying NOT NULL,
    description text,
    conditions jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: segments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.segments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: segments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.segments_id_seq OWNED BY public.segments.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token character varying NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profiles (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    external_id character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb,
    first_seen_at timestamp(6) without time zone,
    last_seen_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profiles_id_seq OWNED BY public.user_profiles.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    name character varying NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    invitation_accepted_at timestamp(6) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhooks (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    url character varying NOT NULL,
    event_names jsonb DEFAULT '[]'::jsonb NOT NULL,
    secret character varying,
    active boolean DEFAULT true NOT NULL,
    failures integer DEFAULT 0 NOT NULL,
    last_triggered_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: webhooks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.webhooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: webhooks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.webhooks_id_seq OWNED BY public.webhooks.id;


--
-- Name: events_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ATTACH PARTITION public.events_default DEFAULT;


--
-- Name: events_y2026m02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ATTACH PARTITION public.events_y2026m02 FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');


--
-- Name: events_y2026m03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ATTACH PARTITION public.events_y2026m03 FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');


--
-- Name: events_y2026m04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ATTACH PARTITION public.events_y2026m04 FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-05-01 00:00:00');


--
-- Name: events_y2026m05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ATTACH PARTITION public.events_y2026m05 FOR VALUES FROM ('2026-05-01 00:00:00') TO ('2026-06-01 00:00:00');


--
-- Name: anomalies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anomalies ALTER COLUMN id SET DEFAULT nextval('public.anomalies_id_seq'::regclass);


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: dashboard_widgets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_widgets ALTER COLUMN id SET DEFAULT nextval('public.dashboard_widgets_id_seq'::regclass);


--
-- Name: dashboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards ALTER COLUMN id SET DEFAULT nextval('public.dashboards_id_seq'::regclass);


--
-- Name: event_daily_rollups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_daily_rollups ALTER COLUMN id SET DEFAULT nextval('public.event_daily_rollups_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: identity_aliases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_aliases ALTER COLUMN id SET DEFAULT nextval('public.identity_aliases_id_seq'::regclass);


--
-- Name: project_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_memberships ALTER COLUMN id SET DEFAULT nextval('public.project_memberships_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: saved_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_reports ALTER COLUMN id SET DEFAULT nextval('public.saved_reports_id_seq'::regclass);


--
-- Name: segments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.segments ALTER COLUMN id SET DEFAULT nextval('public.segments_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: user_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles ALTER COLUMN id SET DEFAULT nextval('public.user_profiles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: webhooks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks ALTER COLUMN id SET DEFAULT nextval('public.webhooks_id_seq'::regclass);


--
-- Name: anomalies anomalies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anomalies
    ADD CONSTRAINT anomalies_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: dashboard_widgets dashboard_widgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_widgets
    ADD CONSTRAINT dashboard_widgets_pkey PRIMARY KEY (id);


--
-- Name: dashboards dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT dashboards_pkey PRIMARY KEY (id);


--
-- Name: event_daily_rollups event_daily_rollups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_daily_rollups
    ADD CONSTRAINT event_daily_rollups_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id, occurred_at);


--
-- Name: events_default events_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events_default
    ADD CONSTRAINT events_default_pkey PRIMARY KEY (id, occurred_at);


--
-- Name: events_y2026m02 events_y2026m02_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events_y2026m02
    ADD CONSTRAINT events_y2026m02_pkey PRIMARY KEY (id, occurred_at);


--
-- Name: events_y2026m03 events_y2026m03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events_y2026m03
    ADD CONSTRAINT events_y2026m03_pkey PRIMARY KEY (id, occurred_at);


--
-- Name: events_y2026m04 events_y2026m04_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events_y2026m04
    ADD CONSTRAINT events_y2026m04_pkey PRIMARY KEY (id, occurred_at);


--
-- Name: events_y2026m05 events_y2026m05_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events_y2026m05
    ADD CONSTRAINT events_y2026m05_pkey PRIMARY KEY (id, occurred_at);


--
-- Name: identity_aliases identity_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_aliases
    ADD CONSTRAINT identity_aliases_pkey PRIMARY KEY (id);


--
-- Name: project_memberships project_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_memberships
    ADD CONSTRAINT project_memberships_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: saved_reports saved_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_reports
    ADD CONSTRAINT saved_reports_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: segments segments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.segments
    ADD CONSTRAINT segments_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webhooks webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT webhooks_pkey PRIMARY KEY (id);


--
-- Name: idx_events_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_events_idempotency ON ONLY public.events USING btree (project_id, idempotency_key, occurred_at) WHERE (idempotency_key IS NOT NULL);


--
-- Name: events_default_project_id_idempotency_key_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX events_default_project_id_idempotency_key_occurred_at_idx ON public.events_default USING btree (project_id, idempotency_key, occurred_at) WHERE (idempotency_key IS NOT NULL);


--
-- Name: idx_events_project_name_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_project_name_time ON ONLY public.events USING btree (project_id, name, occurred_at);


--
-- Name: events_default_project_id_name_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_default_project_id_name_occurred_at_idx ON public.events_default USING btree (project_id, name, occurred_at);


--
-- Name: idx_events_project_user_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_project_user_time ON ONLY public.events USING btree (project_id, user_profile_id, occurred_at);


--
-- Name: events_default_project_id_user_profile_id_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_default_project_id_user_profile_id_occurred_at_idx ON public.events_default USING btree (project_id, user_profile_id, occurred_at);


--
-- Name: idx_events_properties; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_properties ON ONLY public.events USING gin (properties);


--
-- Name: events_default_properties_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_default_properties_idx ON public.events_default USING gin (properties);


--
-- Name: events_y2026m02_project_id_idempotency_key_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX events_y2026m02_project_id_idempotency_key_occurred_at_idx ON public.events_y2026m02 USING btree (project_id, idempotency_key, occurred_at) WHERE (idempotency_key IS NOT NULL);


--
-- Name: events_y2026m02_project_id_name_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m02_project_id_name_occurred_at_idx ON public.events_y2026m02 USING btree (project_id, name, occurred_at);


--
-- Name: events_y2026m02_project_id_user_profile_id_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m02_project_id_user_profile_id_occurred_at_idx ON public.events_y2026m02 USING btree (project_id, user_profile_id, occurred_at);


--
-- Name: events_y2026m02_properties_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m02_properties_idx ON public.events_y2026m02 USING gin (properties);


--
-- Name: events_y2026m03_project_id_idempotency_key_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX events_y2026m03_project_id_idempotency_key_occurred_at_idx ON public.events_y2026m03 USING btree (project_id, idempotency_key, occurred_at) WHERE (idempotency_key IS NOT NULL);


--
-- Name: events_y2026m03_project_id_name_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m03_project_id_name_occurred_at_idx ON public.events_y2026m03 USING btree (project_id, name, occurred_at);


--
-- Name: events_y2026m03_project_id_user_profile_id_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m03_project_id_user_profile_id_occurred_at_idx ON public.events_y2026m03 USING btree (project_id, user_profile_id, occurred_at);


--
-- Name: events_y2026m03_properties_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m03_properties_idx ON public.events_y2026m03 USING gin (properties);


--
-- Name: events_y2026m04_project_id_idempotency_key_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX events_y2026m04_project_id_idempotency_key_occurred_at_idx ON public.events_y2026m04 USING btree (project_id, idempotency_key, occurred_at) WHERE (idempotency_key IS NOT NULL);


--
-- Name: events_y2026m04_project_id_name_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m04_project_id_name_occurred_at_idx ON public.events_y2026m04 USING btree (project_id, name, occurred_at);


--
-- Name: events_y2026m04_project_id_user_profile_id_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m04_project_id_user_profile_id_occurred_at_idx ON public.events_y2026m04 USING btree (project_id, user_profile_id, occurred_at);


--
-- Name: events_y2026m04_properties_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m04_properties_idx ON public.events_y2026m04 USING gin (properties);


--
-- Name: events_y2026m05_project_id_idempotency_key_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX events_y2026m05_project_id_idempotency_key_occurred_at_idx ON public.events_y2026m05 USING btree (project_id, idempotency_key, occurred_at) WHERE (idempotency_key IS NOT NULL);


--
-- Name: events_y2026m05_project_id_name_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m05_project_id_name_occurred_at_idx ON public.events_y2026m05 USING btree (project_id, name, occurred_at);


--
-- Name: events_y2026m05_project_id_user_profile_id_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m05_project_id_user_profile_id_occurred_at_idx ON public.events_y2026m05 USING btree (project_id, user_profile_id, occurred_at);


--
-- Name: events_y2026m05_properties_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_y2026m05_properties_idx ON public.events_y2026m05 USING gin (properties);


--
-- Name: idx_anomalies_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_anomalies_active ON public.anomalies USING btree (project_id, resolved_at) WHERE (resolved_at IS NULL);


--
-- Name: idx_rollups_project_event_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rollups_project_event_date ON public.event_daily_rollups USING btree (project_id, event_name, date);


--
-- Name: index_anomalies_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_anomalies_on_project_id ON public.anomalies USING btree (project_id);


--
-- Name: index_anomalies_on_project_id_and_event_name_and_detected_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_anomalies_on_project_id_and_event_name_and_detected_at ON public.anomalies USING btree (project_id, event_name, detected_at);


--
-- Name: index_audit_events_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_project_id ON public.audit_events USING btree (project_id);


--
-- Name: index_audit_events_on_project_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_project_id_and_created_at ON public.audit_events USING btree (project_id, created_at);


--
-- Name: index_audit_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_user_id ON public.audit_events USING btree (user_id);


--
-- Name: index_dashboard_widgets_on_dashboard_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboard_widgets_on_dashboard_id ON public.dashboard_widgets USING btree (dashboard_id);


--
-- Name: index_dashboard_widgets_on_dashboard_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboard_widgets_on_dashboard_id_and_position ON public.dashboard_widgets USING btree (dashboard_id, "position");


--
-- Name: index_dashboard_widgets_on_saved_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboard_widgets_on_saved_report_id ON public.dashboard_widgets USING btree (saved_report_id);


--
-- Name: index_dashboards_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dashboards_on_project_id ON public.dashboards USING btree (project_id);


--
-- Name: index_event_daily_rollups_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_daily_rollups_on_project_id ON public.event_daily_rollups USING btree (project_id);


--
-- Name: index_identity_aliases_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_aliases_on_project_id ON public.identity_aliases USING btree (project_id);


--
-- Name: index_identity_aliases_on_project_id_and_anonymous_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identity_aliases_on_project_id_and_anonymous_id ON public.identity_aliases USING btree (project_id, anonymous_id);


--
-- Name: index_identity_aliases_on_user_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identity_aliases_on_user_profile_id ON public.identity_aliases USING btree (user_profile_id);


--
-- Name: index_project_memberships_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_memberships_on_project_id ON public.project_memberships USING btree (project_id);


--
-- Name: index_project_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_memberships_on_user_id ON public.project_memberships USING btree (user_id);


--
-- Name: index_project_memberships_on_user_id_and_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_memberships_on_user_id_and_project_id ON public.project_memberships USING btree (user_id, project_id);


--
-- Name: index_projects_on_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_api_key ON public.projects USING btree (api_key);


--
-- Name: index_projects_on_api_secret; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_api_secret ON public.projects USING btree (api_secret);


--
-- Name: index_projects_on_share_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_share_token ON public.projects USING btree (share_token);


--
-- Name: index_saved_reports_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_reports_on_project_id ON public.saved_reports USING btree (project_id);


--
-- Name: index_saved_reports_on_project_id_and_report_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_reports_on_project_id_and_report_type ON public.saved_reports USING btree (project_id, report_type);


--
-- Name: index_segments_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_segments_on_project_id ON public.segments USING btree (project_id);


--
-- Name: index_segments_on_project_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_segments_on_project_id_and_name ON public.segments USING btree (project_id, name);


--
-- Name: index_sessions_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sessions_on_token ON public.sessions USING btree (token);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_user_profiles_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_profiles_on_project_id ON public.user_profiles USING btree (project_id);


--
-- Name: index_user_profiles_on_project_id_and_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_profiles_on_project_id_and_external_id ON public.user_profiles USING btree (project_id, external_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_webhooks_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_project_id ON public.webhooks USING btree (project_id);


--
-- Name: index_webhooks_on_project_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhooks_on_project_id_and_active ON public.webhooks USING btree (project_id, active);


--
-- Name: events_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_default_pkey;


--
-- Name: events_default_project_id_idempotency_key_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_idempotency ATTACH PARTITION public.events_default_project_id_idempotency_key_occurred_at_idx;


--
-- Name: events_default_project_id_name_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_name_time ATTACH PARTITION public.events_default_project_id_name_occurred_at_idx;


--
-- Name: events_default_project_id_user_profile_id_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_user_time ATTACH PARTITION public.events_default_project_id_user_profile_id_occurred_at_idx;


--
-- Name: events_default_properties_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_properties ATTACH PARTITION public.events_default_properties_idx;


--
-- Name: events_y2026m02_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_y2026m02_pkey;


--
-- Name: events_y2026m02_project_id_idempotency_key_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_idempotency ATTACH PARTITION public.events_y2026m02_project_id_idempotency_key_occurred_at_idx;


--
-- Name: events_y2026m02_project_id_name_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_name_time ATTACH PARTITION public.events_y2026m02_project_id_name_occurred_at_idx;


--
-- Name: events_y2026m02_project_id_user_profile_id_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_user_time ATTACH PARTITION public.events_y2026m02_project_id_user_profile_id_occurred_at_idx;


--
-- Name: events_y2026m02_properties_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_properties ATTACH PARTITION public.events_y2026m02_properties_idx;


--
-- Name: events_y2026m03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_y2026m03_pkey;


--
-- Name: events_y2026m03_project_id_idempotency_key_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_idempotency ATTACH PARTITION public.events_y2026m03_project_id_idempotency_key_occurred_at_idx;


--
-- Name: events_y2026m03_project_id_name_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_name_time ATTACH PARTITION public.events_y2026m03_project_id_name_occurred_at_idx;


--
-- Name: events_y2026m03_project_id_user_profile_id_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_user_time ATTACH PARTITION public.events_y2026m03_project_id_user_profile_id_occurred_at_idx;


--
-- Name: events_y2026m03_properties_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_properties ATTACH PARTITION public.events_y2026m03_properties_idx;


--
-- Name: events_y2026m04_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_y2026m04_pkey;


--
-- Name: events_y2026m04_project_id_idempotency_key_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_idempotency ATTACH PARTITION public.events_y2026m04_project_id_idempotency_key_occurred_at_idx;


--
-- Name: events_y2026m04_project_id_name_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_name_time ATTACH PARTITION public.events_y2026m04_project_id_name_occurred_at_idx;


--
-- Name: events_y2026m04_project_id_user_profile_id_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_user_time ATTACH PARTITION public.events_y2026m04_project_id_user_profile_id_occurred_at_idx;


--
-- Name: events_y2026m04_properties_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_properties ATTACH PARTITION public.events_y2026m04_properties_idx;


--
-- Name: events_y2026m05_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.events_pkey ATTACH PARTITION public.events_y2026m05_pkey;


--
-- Name: events_y2026m05_project_id_idempotency_key_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_idempotency ATTACH PARTITION public.events_y2026m05_project_id_idempotency_key_occurred_at_idx;


--
-- Name: events_y2026m05_project_id_name_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_name_time ATTACH PARTITION public.events_y2026m05_project_id_name_occurred_at_idx;


--
-- Name: events_y2026m05_project_id_user_profile_id_occurred_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_project_user_time ATTACH PARTITION public.events_y2026m05_project_id_user_profile_id_occurred_at_idx;


--
-- Name: events_y2026m05_properties_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_events_properties ATTACH PARTITION public.events_y2026m05_properties_idx;


--
-- Name: events fk_events_project; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.events
    ADD CONSTRAINT fk_events_project FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: project_memberships fk_rails_18b611e244; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_memberships
    ADD CONSTRAINT fk_rails_18b611e244 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: saved_reports fk_rails_255df2535e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_reports
    ADD CONSTRAINT fk_rails_255df2535e FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: segments fk_rails_4172c06e24; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.segments
    ADD CONSTRAINT fk_rails_4172c06e24 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: dashboards fk_rails_5ad01c40ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT fk_rails_5ad01c40ce FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: user_profiles fk_rails_608d5e5b5d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT fk_rails_608d5e5b5d FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: dashboard_widgets fk_rails_834da0b127; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_widgets
    ADD CONSTRAINT fk_rails_834da0b127 FOREIGN KEY (dashboard_id) REFERENCES public.dashboards(id);


--
-- Name: identity_aliases fk_rails_84703a8006; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_aliases
    ADD CONSTRAINT fk_rails_84703a8006 FOREIGN KEY (user_profile_id) REFERENCES public.user_profiles(id);


--
-- Name: project_memberships fk_rails_86b046ec96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_memberships
    ADD CONSTRAINT fk_rails_86b046ec96 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: dashboard_widgets fk_rails_8b9c11cc59; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dashboard_widgets
    ADD CONSTRAINT fk_rails_8b9c11cc59 FOREIGN KEY (saved_report_id) REFERENCES public.saved_reports(id);


--
-- Name: event_daily_rollups fk_rails_9d2bd18d92; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_daily_rollups
    ADD CONSTRAINT fk_rails_9d2bd18d92 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: identity_aliases fk_rails_bc83ef0a56; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identity_aliases
    ADD CONSTRAINT fk_rails_bc83ef0a56 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: audit_events fk_rails_d27dff91d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_d27dff91d1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: webhooks fk_rails_d90278b6a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT fk_rails_d90278b6a9 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: anomalies fk_rails_eb5145e922; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anomalies
    ADD CONSTRAINT fk_rails_eb5145e922 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: audit_events fk_rails_f97ffa6043; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_f97ffa6043 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260906190000'),
('20260906180000'),
('20260906170000'),
('20260906160000'),
('20260906150000'),
('20260906140000'),
('20260906130000'),
('20260906120000'),
('20260316200003'),
('20260316200002'),
('20260316200001'),
('20260316100004'),
('20260316100003'),
('20260316100002'),
('20260316100001'),
('20260315220005'),
('20260315220004'),
('20260315220003'),
('20260315220002'),
('20260315220001');

