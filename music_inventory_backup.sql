--
-- PostgreSQL database dump
--

-- Dumped from database version 15.6 (Postgres.app)
-- Dumped by pg_dump version 16.0

-- Started on 2024-03-13 09:58:07 EAT

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
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--
DROP SCHEMA IF EXISTS public;

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 3972 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 308 (class 1255 OID 22925)
-- Name: check_teacher_role(); Type: FUNCTION; Schema: public; Owner: postgres
--


CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;

CREATE FUNCTION public.check_teacher_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (SELECT role FROM users WHERE id = NEW.teacher_id) <> 'TEACHER' THEN
    RAISE EXCEPTION 'Teacher_id must correspond to a user with the role "TEACHER".';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_teacher_role() OWNER TO postgres;

--
-- TOC entry 328 (class 1255 OID 27833)
-- Name: create_roles(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_roles() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    user_record RECORD;
    username VARCHAR(100);
    default_password VARCHAR(100);
    user_id INT;
    role_to_grant VARCHAR(100);
BEGIN
    FOR user_record IN SELECT * FROM users WHERE role IN ('STUDENT', 'MUSIC TEACHER', 'MUSIC TA') 
                                            AND email IS NOT NULL
    LOOP
        username := user_record.username;
        default_password := CONCAT(username, '@music');
        user_id := user_record.id;
        role_to_grant := user_record.role;
        
        -- Check if role already exists
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = username) THEN
            -- Create role
            EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', username, default_password);
                
            -- Associate user ID with the role using a comment
            EXECUTE format('COMMENT ON ROLE %I IS %L', username, 'User ID: ' || user_id);
            
            -- Grant privileges based on role
            IF role_to_grant = 'STUDENT' THEN
                EXECUTE format('GRANT student TO %I', username);
            ELSIF role_to_grant = 'MUSIC TEACHER' THEN
                EXECUTE format('GRANT music_teacher TO %I', username);
            ELSIF role_to_grant = 'MUSIC TA' THEN
                EXECUTE format('GRANT music_ta TO %I', username);
            END IF;
        END IF;
    END LOOP;
END;
$$;


ALTER FUNCTION public.create_roles() OWNER TO postgres;

--
-- TOC entry 327 (class 1255 OID 24774)
-- Name: dispatch(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dispatch() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
    instrument_user_name TEXT;
BEGIN
    -- Check if the family is valid
    IF (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD') THEN
        RAISE EXCEPTION 'Item cannot be rented out';
    END IF;

    -- Check if the instrument is already checked out
    SELECT INTO instrument_user_name first_name || ' ' || last_name
    FROM users
    WHERE "id" = (SELECT user_id FROM instruments WHERE "id" = NEW.item_id)::integer;


    IF instrument_user_name IS NOT NULL THEN
        RAISE EXCEPTION 'Instrument already checked out to %', instrument_user_name;
    END IF;

    -- Update the instruments table
    UPDATE instruments
    SET "user_id" = NEW.user_id,
        location = NULL
    WHERE id = NEW.item_id;
	NEW.created_by = CURRENT_USER;

    RETURN NEW;
END;$$;


ALTER FUNCTION public.dispatch() OWNER TO postgres;

--
-- TOC entry 316 (class 1255 OID 24759)
-- Name: get_division(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_division(grade_level character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
BEGIN
  grade_level := UPPER(grade_level);
  
  IF grade_level IN ('PK', 'K', '1', '2', '3', '4', '5') THEN
    RETURN 'ES';
  ELSIF grade_level IN ('6', '7', '8') THEN
    RETURN 'MS';
  ELSIF grade_level IN ('9', '10', '11', '12') THEN
    RETURN 'HS';
  ELSE
    RETURN NULL;
  END IF;
END;
$$;


ALTER FUNCTION public.get_division(grade_level character varying) OWNER TO postgres;

--
-- TOC entry 323 (class 1255 OID 25099)
-- Name: get_instruments_by_name(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_instruments_by_name(p_name character varying) RETURNS TABLE(description public.citext, make public.citext, number integer, username character varying)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE '
    SELECT description, make, number, user_name
    FROM all_instruments_view
    WHERE user_name ILIKE $1'
    USING '%' || p_name || '%';
END;
$_$;


ALTER FUNCTION public.get_instruments_by_name(p_name character varying) OWNER TO postgres;

--
-- TOC entry 319 (class 1255 OID 25009)
-- Name: get_item_id_by_code(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_item_id_by_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE code = p_code
    AND number = p_number;
END;
$$;


ALTER FUNCTION public.get_item_id_by_code(p_code character varying, p_number integer, OUT item_id integer) OWNER TO postgres;

--
-- TOC entry 317 (class 1255 OID 25007)
-- Name: get_item_id_by_description(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_item_id_by_description(p_description character varying, p_number integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_item_id INT;
BEGIN
    SELECT id INTO v_item_id
    FROM all_instruments_view
    WHERE description = p_description
    AND number = p_number;

    RETURN v_item_id;
END;
$$;


ALTER FUNCTION public.get_item_id_by_description(p_description character varying, p_number integer) OWNER TO postgres;

--
-- TOC entry 318 (class 1255 OID 25008)
-- Name: get_item_id_by_old_code(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_item_id_by_old_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE legacy_code = p_code
    AND number = p_number;
END;
$$;


ALTER FUNCTION public.get_item_id_by_old_code(p_code character varying, p_number integer, OUT item_id integer) OWNER TO postgres;

--
-- TOC entry 320 (class 1255 OID 25010)
-- Name: get_item_id_by_serial(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE "serial" = p_serial;
END;
$$;


ALTER FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer) OWNER TO postgres;

--
-- TOC entry 321 (class 1255 OID 25033)
-- Name: get_user_id_by_number(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM all_users_view
    WHERE "number" = p_number;
END;
$$;


ALTER FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer) OWNER TO postgres;

--
-- TOC entry 325 (class 1255 OID 27714)
-- Name: get_user_id_by_role(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM users
    WHERE "username" = p_role;
END;
$$;


ALTER FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer) OWNER TO postgres;

--
-- TOC entry 303 (class 1255 OID 22927)
-- Name: insert_type(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_type(p_code character varying, p_description character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO types (code, description) VALUES (UPPER(p_code), UPPER(p_description));
END;
$$;


ALTER FUNCTION public.insert_type(p_code character varying, p_description character varying) OWNER TO postgres;

--
-- TOC entry 329 (class 1255 OID 24770)
-- Name: log_transaction(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_transaction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
    IF TG_TABLE_NAME = 'instruments' THEN
        -- Insert or update on the instruments table
        IF TG_OP = 'INSERT' THEN
            -- Instrument created
            INSERT INTO instrument_history (transaction_type, created_by, item_id)
            VALUES ('Instrument Created', CURRENT_USER, NEW.id);
        ELSIF TG_OP = 'UPDATE' THEN
            -- Check if state or number columns have been updated
            IF NEW.state <> OLD.state OR NEW.number <> OLD.number THEN
                -- Instrument updated
                INSERT INTO instrument_history (transaction_type, created_by, item_id)
                VALUES ('Details Updated', CURRENT_USER, NEW.id);
            END IF;
        END IF;
    ELSIF TG_TABLE_NAME = 'dispatches' THEN
        -- Insert on the dispatches table
        IF TG_OP = 'INSERT' THEN
            -- Instrument dispatched
            INSERT INTO instrument_history (transaction_type, created_by, item_id, assigned_to)
            VALUES ('Instrument Out',CURRENT_USER, NEW.item_id, NEW.user_id);
        END IF;
   
	ELSIF TG_TABLE_NAME = 'returns' THEN
        -- Insert on the returns table
        IF TG_OP = 'INSERT' THEN
            -- Instrument returned
            INSERT INTO instrument_history (transaction_type, item_id, created_by)
            VALUES ('Instrument Returned', NEW.item_id,CURRENT_USER);
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_transaction() OWNER TO postgres;

--
-- TOC entry 326 (class 1255 OID 24846)
-- Name: new_instr_function(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.new_instr_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    n_code VARCHAR;
    legacy_code VARCHAR;
    last_number INT;
    nstate VARCHAR;
BEGIN
    -- Work out correct code
    SELECT equipment.code INTO n_code FROM equipment WHERE equipment.description = NEW.description;
    SELECT equipment.legacy_code INTO legacy_code FROM equipment WHERE equipment.description = UPPER(NEW.description);
   
    -- If "number" is explicitly provided, use that value
    IF NEW.number IS NOT NULL THEN
        last_number := NEW.number - 1; -- Subtract 1 to avoid conflicts with auto-increment
    ELSE
        -- Work out the last number for the given code
        SELECT COALESCE(MAX(number), 0) INTO last_number FROM instruments WHERE "code" = n_code;
    END IF;

    -- Populate the columns and insert into instruments
    INSERT INTO instruments (
        "code",
        "legacy_code",
        "description",
        "serial",
        "number",
        "make",
        "model",
        "state", 
        "location"
    ) VALUES (
        n_code,
        legacy_code,
        NEW.description,
        COALESCE(NEW.serial, NULL),
        COALESCE(NEW.number, last_number + 1),
        COALESCE(NEW.make, NULL),
        COALESCE(NEW.model, NULL),
        COALESCE(NEW.state, 'New'),
        COALESCE(NEW.location, 'INSTRUMENT STORE')
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.new_instr_function() OWNER TO postgres;

--
-- TOC entry 324 (class 1255 OID 27834)
-- Name: return(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.return() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE p_user_id integer;
BEGIN
	SELECT id INTO p_user_id FROM users WHERE username = CURRENT_USER;
    -- Check if the current user has a room assigned
    IF (SELECT room FROM users WHERE id = p_user_id) IS NOT NULL THEN
        -- Instrument returned
        UPDATE instruments
        SET user_id = NULL,
            location = (SELECT room FROM users WHERE users.id = p_user_id),
            user_name = NULL
        WHERE id = NEW.item_id;

        NEW.created_by = CURRENT_USER;
    ELSE
        -- Do not allow instrument return if the current user has no room assigned
        RAISE EXCEPTION 'User cannot return instrument. No room assigned.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.return() OWNER TO postgres;

--
-- TOC entry 322 (class 1255 OID 25048)
-- Name: search_user_by_name(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_user_by_name(p_name character varying, OUT user_id integer, OUT full_name text, OUT grade_level character varying) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT all_users_view.id, all_users_view.full_name, all_users_view.grade_level
    FROM all_users_view
    WHERE all_users_view.full_name ILIKE '%' || p_name || '%';
END;
$$;


ALTER FUNCTION public.search_user_by_name(p_name character varying, OUT user_id integer, OUT full_name text, OUT grade_level character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 240 (class 1259 OID 24634)
-- Name: equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);


ALTER TABLE public.equipment OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 24633)
-- Name: all_instruments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.all_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 218 (class 1259 OID 24202)
-- Name: instruments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instruments (
    id integer NOT NULL,
    legacy_number integer,
    code public.citext,
    description public.citext,
    serial public.citext,
    state character varying,
    location public.citext DEFAULT 'INSTRUMENT STORE'::character varying,
    make public.citext,
    model public.citext,
    legacy_code public.citext,
    number integer,
    user_name public.citext,
    user_id integer,
    CONSTRAINT instruments_state_check CHECK (((state)::text = ANY ((ARRAY['New'::character varying, 'Good'::character varying, 'Worn'::character varying, 'Damaged'::character varying, 'Write-off'::character varying])::text[])))
);


ALTER TABLE public.instruments OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 24250)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying,
    email character varying,
    role character varying NOT NULL,
    number public.citext,
    grade_level character varying,
    division character varying,
    room public.citext,
    username character varying
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 24998)
-- Name: all_instruments_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.all_instruments_view AS
 SELECT instruments.id,
    instruments.description,
    instruments.make,
    instruments.model,
    instruments.serial,
    instruments.legacy_code,
    instruments.code,
    instruments.number,
    instruments.location,
    (COALESCE((((users.first_name)::text || ' '::text) || (users.last_name)::text), NULL::text))::character varying AS user_name
   FROM (public.instruments
     LEFT JOIN public.users ON ((instruments.user_id = users.id)))
  ORDER BY instruments.description, instruments.number;


ALTER VIEW public.all_instruments_view OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 24383)
-- Name: students; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.students (
    id integer NOT NULL,
    student_number integer NOT NULL,
    last_name character varying NOT NULL,
    first_name character varying NOT NULL,
    full_name character varying GENERATED ALWAYS AS ((((first_name)::text || ' '::text) || (last_name)::text)) STORED,
    grade_level character varying NOT NULL,
    parent1_email character varying,
    parent2_email character varying,
    division public.citext,
    class public.citext,
    email character varying
);


ALTER TABLE public.students OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 27844)
-- Name: all_users_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.all_users_view AS
 SELECT users.id,
    users.role,
    users.division,
    users.grade_level,
    users.first_name,
    users.last_name,
    COALESCE((((users.first_name)::text || ' '::text) || (users.last_name)::text), (users.first_name)::text, (users.last_name)::text) AS full_name,
    users.number,
    users.email,
    students.class
   FROM (public.users
     LEFT JOIN public.students ON (((students.student_number)::text = (users.number)::text)))
  ORDER BY users.role, users.first_name;


ALTER VIEW public.all_users_view OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 24265)
-- Name: class; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.class (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    class_name character varying
);


ALTER TABLE public.class OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 24264)
-- Name: class_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.class ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 255 (class 1259 OID 27836)
-- Name: dispatched_instruments_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.dispatched_instruments_view AS
 SELECT all_instruments_view.id,
    all_instruments_view.description,
    all_instruments_view.number,
    all_instruments_view.make,
    all_instruments_view.serial,
    all_instruments_view.user_name
   FROM public.all_instruments_view
  WHERE (all_instruments_view.user_name IS NOT NULL);


ALTER VIEW public.dispatched_instruments_view OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 24280)
-- Name: dispatches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dispatches (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    user_id integer,
    item_id integer,
    created_by character varying
);


ALTER TABLE public.dispatches OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 24279)
-- Name: dispatches_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.dispatches ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dispatches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 244 (class 1259 OID 24657)
-- Name: duplicate_instruments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.duplicate_instruments (
    id integer NOT NULL,
    number integer NOT NULL,
    legacy_number integer,
    family character varying DEFAULT 'MISCELLANEOUS'::character varying NOT NULL,
    equipment character varying NOT NULL,
    make character varying,
    model character varying,
    serial character varying,
    class character varying,
    year character varying,
    name character varying,
    school_storage character varying DEFAULT 'Instrument Storage'::character varying,
    return_2023 character varying
);


ALTER TABLE public.duplicate_instruments OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 24656)
-- Name: duplicate_instruments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.duplicate_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.duplicate_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 246 (class 1259 OID 24681)
-- Name: hardware_and_equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hardware_and_equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);


ALTER TABLE public.hardware_and_equipment OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 24680)
-- Name: hardware_and_equipment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.hardware_and_equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.hardware_and_equipment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 236 (class 1259 OID 24362)
-- Name: instrument_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instrument_history (
    id integer NOT NULL,
    transaction_type character varying NOT NULL,
    transaction_timestamp date DEFAULT CURRENT_DATE,
    item_id integer NOT NULL,
    notes text,
    assigned_to character varying,
    created_by character varying
);


ALTER TABLE public.instrument_history OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 27864)
-- Name: history_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.history_view AS
 SELECT instrument_history.id,
    instrument_history.transaction_type,
    instrument_history.transaction_timestamp,
    instrument_history.item_id AS instrument_id,
    initcap((instruments.description)::text) AS description,
    instruments.number,
    instrument_history.assigned_to AS user_id,
    initcap(COALESCE((((users.first_name)::text || ' '::text) || (users.last_name)::text), (users.first_name)::text, (users.last_name)::text)) AS full_name,
    users.email,
    initcap((instrument_history.created_by)::text) AS created_by
   FROM ((public.instrument_history
     LEFT JOIN public.users ON ((users.id = (instrument_history.assigned_to)::integer)))
     LEFT JOIN public.instruments ON ((instruments.id = instrument_history.item_id)))
  ORDER BY instrument_history.id;


ALTER VIEW public.history_view OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 24951)
-- Name: instrument_distribution_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.instrument_distribution_view AS
 SELECT subquery.description,
    subquery.legacy_code,
    subquery.code,
    subquery.total,
    subquery.available,
    subquery.dispatched,
    subquery.ms_music,
    subquery.hs_music,
    subquery.upper_es_music,
    subquery.lower_es_music,
    ((((((subquery.total - COALESCE(subquery.available, (0)::bigint)) - COALESCE(subquery.ms_music, (0)::bigint)) - COALESCE(subquery.hs_music, (0)::bigint)) - COALESCE(subquery.upper_es_music, (0)::bigint)) - COALESCE(subquery.lower_es_music, (0)::bigint)) - COALESCE(subquery.dispatched, (0)::bigint)) AS unknown_count
   FROM ( SELECT instruments.description,
            instruments.legacy_code,
            instruments.code,
            count(instruments.description) AS total,
            count(
                CASE
                    WHEN (instruments.location OPERATOR(public.=) 'INSTRUMENT STORE'::public.citext) THEN 1
                    ELSE NULL::integer
                END) AS available,
            count(
                CASE
                    WHEN ((instruments.user_id IS NOT NULL) OR (instruments.user_name IS NOT NULL)) THEN 1
                    ELSE NULL::integer
                END) AS dispatched,
            count(
                CASE
                    WHEN (instruments.location OPERATOR(public.=) 'MS MUSIC'::public.citext) THEN 1
                    ELSE NULL::integer
                END) AS ms_music,
            count(
                CASE
                    WHEN (instruments.location OPERATOR(public.=) 'HS MUSIC'::public.citext) THEN 1
                    ELSE NULL::integer
                END) AS hs_music,
            count(
                CASE
                    WHEN (instruments.location OPERATOR(public.=) 'UPPER ES MUSIC'::public.citext) THEN 1
                    ELSE NULL::integer
                END) AS upper_es_music,
            count(
                CASE
                    WHEN (instruments.location OPERATOR(public.=) 'LOWER ES MUSIC'::public.citext) THEN 1
                    ELSE NULL::integer
                END) AS lower_es_music
           FROM public.instruments
          GROUP BY instruments.description, instruments.legacy_code, instruments.code) subquery
  ORDER BY subquery.total DESC;


ALTER VIEW public.instrument_distribution_view OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 24361)
-- Name: instrument_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.instrument_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 217 (class 1259 OID 24201)
-- Name: instruments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 216 (class 1259 OID 23612)
-- Name: legacy_database; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.legacy_database (
    id integer NOT NULL,
    number integer NOT NULL,
    legacy_number integer,
    family character varying DEFAULT 'MISCELLANEOUS'::character varying NOT NULL,
    equipment character varying NOT NULL,
    make character varying,
    model character varying,
    serial character varying,
    class character varying,
    year character varying,
    full_name character varying,
    school_storage character varying DEFAULT 'Instrument Storage'::character varying,
    return_2023 character varying,
    student_number integer,
    code public.citext
);


ALTER TABLE public.legacy_database OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 23611)
-- Name: legacy_database_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.legacy_database ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.legacy_database_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 247 (class 1259 OID 24727)
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.locations (
    room public.citext NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 24743)
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.locations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 242 (class 1259 OID 24646)
-- Name: music_instruments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.music_instruments (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext NOT NULL,
    notes character varying,
    CONSTRAINT music_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text])))
);


ALTER TABLE public.music_instruments OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 24645)
-- Name: music_instruments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.music_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.music_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 250 (class 1259 OID 24850)
-- Name: new_instrument; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.new_instrument (
    id integer NOT NULL,
    legacy_number integer,
    code public.citext,
    description public.citext,
    serial public.citext,
    state character varying,
    location public.citext DEFAULT 'INSTRUMENT STORE'::character varying,
    make public.citext,
    model public.citext,
    legacy_code public.citext,
    number integer,
    user_name public.citext,
    user_id integer,
    CONSTRAINT instruments_state_check CHECK (((state)::text = ANY ((ARRAY['New'::character varying, 'Good'::character varying, 'Worn'::character varying, 'Damaged'::character varying, 'Write-off'::character varying])::text[])))
);


ALTER TABLE public.new_instrument OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 24849)
-- Name: new_instrument_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.new_instrument ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.new_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 254 (class 1259 OID 25128)
-- Name: receive_instrument; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.receive_instrument (
    id integer NOT NULL,
    created_by_id integer,
    instrument_id integer,
    room public.citext
);


ALTER TABLE public.receive_instrument OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 25127)
-- Name: receive_instrument_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.receive_instrument ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.receive_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 24313)
-- Name: repair_request; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.repair_request (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    complaint text NOT NULL
);


ALTER TABLE public.repair_request OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 24312)
-- Name: repairs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.repair_request ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.repairs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 234 (class 1259 OID 24341)
-- Name: requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.requests (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    teacher_id integer,
    instrument public.citext NOT NULL,
    quantity integer NOT NULL
);


ALTER TABLE public.requests OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 24340)
-- Name: requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 232 (class 1259 OID 24327)
-- Name: resolve; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resolve (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    "case" integer,
    notes text
);


ALTER TABLE public.resolve OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 24326)
-- Name: resolve_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.resolve ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.resolve_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 24301)
-- Name: returns; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.returns (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    created_by character varying
);


ALTER TABLE public.returns OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 24300)
-- Name: returns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.returns ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.returns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 24238)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    role_name character varying DEFAULT 'STUDENT'::character varying
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 24237)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.roles ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 237 (class 1259 OID 24382)
-- Name: students_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.students ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.students_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 221 (class 1259 OID 24249)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 3938 (class 0 OID 24265)
-- Dependencies: 224
-- Data for Name: class; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.class (id, teacher_id, class_name) FROM stdin;
\.


--
-- TOC entry 3940 (class 0 OID 24280)
-- Dependencies: 226
-- Data for Name: dispatches; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dispatches (id, created_at, user_id, item_id, created_by) FROM stdin;
19	2024-01-31	1072	2129	postgres
23	2024-01-31	1072	2129	postgres
24	2024-02-01	1072	4166	postgres
25	2024-02-01	1072	4166	postgres
26	2024-02-01	1072	4166	\N
32	2024-02-01	1072	4166	\N
35	2024-02-01	1072	4166	postgres
45	2024-02-23	1074	2129	nochomo
47	2024-02-23	1074	4166	nochomo
48	2024-02-23	1074	4166	nochomo
50	2024-02-23	1074	4166	nochomo
52	2024-02-23	1074	4166	nochomo
53	2024-02-23	1074	4166	nochomo
54	2024-02-23	1074	4166	nochomo
55	2024-02-23	1074	4166	nochomo
56	2024-02-23	1074	4166	nochomo
58	2024-02-23	1074	4166	nochomo
59	2024-02-23	1074	4166	nochomo
60	2024-02-23	1074	4166	nochomo
64	2024-02-23	1074	4166	nochomo
65	2024-03-01	1074	4166	nochomo
66	2024-03-01	1074	4166	nochomo
67	2024-03-01	1074	4166	nochomo
68	2024-03-01	1074	4166	nochomo
69	2024-03-02	1074	4166	nochomo
82	2024-03-03	1074	4166	nochomo
83	2024-03-03	1074	4166	nochomo
87	2024-03-03	1072	4166	nochomo
88	2024-03-03	1074	4165	nochomo
90	2024-03-03	1074	4164	nochomo
91	2024-03-03	1074	2129	nochomo
93	2024-03-03	1072	4166	nochomo
95	2024-03-03	1072	4165	nochomo
96	2024-03-04	1072	4164	nochomo
97	2024-03-04	1074	4164	nochomo
98	2024-03-04	1074	4163	nochomo
99	2024-03-04	1074	4164	nochomo
100	2024-03-04	1074	4163	nochomo
101	2024-03-04	1072	4166	nochomo
102	2024-03-04	1072	2129	nochomo
103	2024-03-04	1074	4163	nochomo
104	2024-03-04	1074	4165	nochomo
105	2024-03-04	1074	4166	nochomo
106	2024-03-05	1072	4166	nochomo
107	2024-03-05	1074	4165	nochomo
108	2024-03-06	1074	2129	nochomo
111	2024-03-06	1074	4166	nochomo
112	2024-03-06	1074	4166	nochomo
120	2024-03-07	1074	4166	postgres
124	2024-03-07	1074	4165	nochomo
125	2024-03-07	1074	4166	nochomo
126	2024-03-07	1074	4164	nochomo
127	2024-03-07	1072	4166	nochomo
\.


--
-- TOC entry 3958 (class 0 OID 24657)
-- Dependencies: 244
-- Data for Name: duplicate_instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.duplicate_instruments (id, number, legacy_number, family, equipment, make, model, serial, class, year, name, school_storage, return_2023) FROM stdin;
1	37	121	BRASS	TRUMPET, B FLAT	HOLTON	\N	619468	\N	\N	\N	\N	\N
2	37	121	BRASS	TRUMPET, B FLAT	HOLTON	\N	619468	\N	\N	\N	\N	\N
3	11	498	WOODWIND	FLUTE	GEMEINHARDT	2SP	K96124	\N	\N	\N	INSTRUMENT STORE	\N
4	11	498	WOODWIND	FLUTE	GEMEINHARDT	2SP	K96124	\N	\N	\N	INSTRUMENT STORE	\N
5	11	498	WOODWIND	FLUTE	GEMEINHARDT	2SP	K96124	\N	\N	\N	INSTRUMENT STORE	\N
6	35	117	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	619276	\N	\N	\N	INSTRUMENT STORE	\N
7	35	117	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	619276	\N	\N	\N	INSTRUMENT STORE	\N
8	35	117	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	619276	\N	\N	\N	INSTRUMENT STORE	\N
9	35	117	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	619276	\N	\N	\N	INSTRUMENT STORE	\N
10	6	414	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65670	\N	\N	\N	\N	\N
11	6	414	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65670	\N	\N	\N	\N	\N
12	6	414	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65670	\N	\N	\N	\N	\N
13	6	414	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65670	\N	\N	\N	\N	\N
14	6	414	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65670	\N	\N	\N	\N	\N
15	40	127	BRASS	TRUMPET, B FLAT	BLESSING	\N	H32043	\N	\N	\N	\N	\N
16	40	127	BRASS	TRUMPET, B FLAT	BLESSING	\N	H32043	\N	\N	\N	\N	\N
17	31	599	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	354121A	\N	\N	\N	\N	\N
18	31	599	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	354121A	\N	\N	\N	\N	\N
19	31	599	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	354121A	\N	\N	\N	\N	\N
20	31	599	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	354121A	\N	\N	\N	\N	\N
21	31	599	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	354121A	\N	\N	\N	\N	\N
22	31	599	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	354121A	\N	\N	\N	\N	\N
23	3	408	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65679	\N	\N	\N	\N	\N
24	3	408	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65679	\N	\N	\N	\N	\N
25	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
26	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
27	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
28	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
29	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
30	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
31	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
32	15	507	WOODWIND	FLUTE	YAMAHA	\N	566919A	\N	\N	\N	\N	\N
33	32	601	WOODWIND	SAXOPHONE, ALTO	BARRINGTON	\N	AS1003852	\N	\N	\N	\N	\N
34	32	601	WOODWIND	SAXOPHONE, ALTO	BARRINGTON	\N	AS1003852	\N	\N	\N	\N	\N
35	42	131	BRASS	TRUMPET, B FLAT	KOHLERT	\N	A6570	\N	\N	\N	\N	\N
36	42	131	BRASS	TRUMPET, B FLAT	KOHLERT	\N	A6570	\N	\N	\N	\N	\N
37	9	495	WOODWIND	FLUTE	HUANG	\N	R-28	\N	\N	\N	\N	\N
38	9	495	WOODWIND	FLUTE	HUANG	\N	R-28	\N	\N	\N	\N	\N
39	41	129	BRASS	TRUMPET, B FLAT	BACH	Stradivarius	488350	\N	\N	\N	\N	\N
40	41	129	BRASS	TRUMPET, B FLAT	BACH	Stradivarius	488350	\N	\N	\N	\N	\N
41	16	509	WOODWIND	FLUTE	YAMAHA	\N	737508	\N	\N	\N	\N	\N
42	16	509	WOODWIND	FLUTE	YAMAHA	\N	737508	\N	\N	\N	\N	\N
43	16	509	WOODWIND	FLUTE	YAMAHA	\N	737508	\N	\N	\N	\N	\N
44	36	119	BRASS	TRUMPET, B FLAT	HOLTON	\N	259/970406	\N	\N	\N	\N	\N
45	36	119	BRASS	TRUMPET, B FLAT	HOLTON	\N	259/970406	\N	\N	\N	\N	\N
46	36	119	BRASS	TRUMPET, B FLAT	HOLTON	\N	259/970406	\N	\N	\N	\N	\N
47	36	119	BRASS	TRUMPET, B FLAT	HOLTON	\N	259/970406	\N	\N	\N	\N	\N
48	36	119	BRASS	TRUMPET, B FLAT	HOLTON	\N	259/970406	\N	\N	\N	\N	\N
49	36	119	BRASS	TRUMPET, B FLAT	HOLTON	\N	259/970406	\N	\N	\N	\N	\N
50	36	119	BRASS	TRUMPET, B FLAT	HOLTON	\N	259/970406	\N	\N	\N	\N	\N
51	13	503	WOODWIND	FLUTE	YAMAHA	\N	916386	\N	\N	\N	\N	\N
52	13	503	WOODWIND	FLUTE	YAMAHA	\N	916386	\N	\N	\N	\N	\N
53	39	125	BRASS	TRUMPET, B FLAT	BLESSING	\N	H31434	\N	\N	\N	\N	\N
54	39	125	BRASS	TRUMPET, B FLAT	BLESSING	\N	H31434	\N	\N	\N	\N	\N
55	18	513	WOODWIND	FLUTE	PRELUDE	\N	28411024	\N	\N	\N	\N	\N
56	18	513	WOODWIND	FLUTE	PRELUDE	\N	28411024	\N	\N	\N	\N	\N
57	18	513	WOODWIND	FLUTE	PRELUDE	\N	28411024	\N	\N	\N	\N	\N
58	18	513	WOODWIND	FLUTE	PRELUDE	\N	28411024	\N	\N	\N	\N	\N
59	5	412	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65449	\N	\N	\N	\N	\N
60	5	412	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65449	\N	\N	\N	\N	\N
61	5	412	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65449	\N	\N	\N	\N	\N
62	2	406	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	405227	\N	\N	\N	\N	\N
63	2	406	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	405227	\N	\N	\N	\N	\N
64	2	406	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	405227	\N	\N	\N	\N	\N
65	2	406	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	405227	\N	\N	\N	\N	\N
66	30	597	WOODWIND	SAXOPHONE, ALTO	GIARDINELLI	\N	200494	\N	\N	\N	\N	\N
67	30	597	WOODWIND	SAXOPHONE, ALTO	GIARDINELLI	\N	200494	\N	\N	\N	\N	\N
68	7	491	WOODWIND	FLUTE	YAMAHA	\N	608552	\N	\N	\N	\N	\N
69	7	491	WOODWIND	FLUTE	YAMAHA	\N	608552	\N	\N	\N	\N	\N
70	29	595	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11120089	\N	\N	\N	\N	\N
71	29	595	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11120089	\N	\N	\N	\N	\N
72	4	410	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65480	\N	\N	\N	\N	\N
73	4	410	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65480	\N	\N	\N	\N	\N
74	38	123	BRASS	TRUMPET, B FLAT	HOLTON	\N	619528	\N	\N	\N	\N	\N
75	38	123	BRASS	TRUMPET, B FLAT	HOLTON	\N	619528	\N	\N	\N	\N	\N
76	12	501	WOODWIND	FLUTE	YAMAHA	\N	740478	\N	\N	\N	\N	\N
77	12	501	WOODWIND	FLUTE	YAMAHA	\N	740478	\N	\N	\N	\N	\N
78	10	497	WOODWIND	FLUTE	ARTLEU	\N	3827353	\N	\N	\N	\N	\N
79	10	497	WOODWIND	FLUTE	ARTLEU	\N	3827353	\N	\N	\N	\N	\N
80	17	511	WOODWIND	FLUTE	HUANG	\N	Y-60	\N	\N	\N	\N	\N
81	17	511	WOODWIND	FLUTE	HUANG	\N	Y-60	\N	\N	\N	\N	\N
82	17	511	WOODWIND	FLUTE	HUANG	\N	Y-60	\N	\N	\N	\N	\N
83	17	511	WOODWIND	FLUTE	HUANG	\N	Y-60	\N	\N	\N	\N	\N
84	17	511	WOODWIND	FLUTE	HUANG	\N	Y-60	\N	\N	\N	\N	\N
85	34	115	BRASS	TRUMPET, B FLAT	YAMAHA	\N	458367	\N	\N	\N	\N	\N
86	34	115	BRASS	TRUMPET, B FLAT	YAMAHA	\N	458367	\N	\N	\N	\N	\N
87	34	115	BRASS	TRUMPET, B FLAT	YAMAHA	\N	458367	\N	\N	\N	\N	\N
88	34	115	BRASS	TRUMPET, B FLAT	YAMAHA	\N	458367	\N	\N	\N	\N	\N
89	34	115	BRASS	TRUMPET, B FLAT	YAMAHA	\N	458367	\N	\N	\N	\N	\N
90	1	404	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	443895	\N	\N	\N	\N	\N
91	1	404	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	443895	\N	\N	\N	\N	\N
92	14	505	WOODWIND	FLUTE	YAMAHA	\N	917448	\N	\N	\N	\N	\N
93	14	505	WOODWIND	FLUTE	YAMAHA	\N	917448	\N	\N	\N	\N	\N
94	13	370	STRING	GUITAR, CLASSICAL	PARADISE	14	\N	\N	under repair	\N	MS MUSIC	\N
95	13	370	STRING	GUITAR, CLASSICAL	PARADISE	14	\N	\N	under repair	\N	MS MUSIC	\N
96	8	493	WOODWIND	FLUTE	YAMAHA	\N	848024	\N	\N	\N	PIANO ROOM	\N
\.


--
-- TOC entry 3954 (class 0 OID 24634)
-- Dependencies: 240
-- Data for Name: equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.equipment (id, family, description, legacy_code, code, notes) FROM stdin;
3	BRASS	BUGLE	\N	BG	\N
4	BRASS	BUGLE , KEYED	\N	BGK	\N
5	BRASS	CIMBASSO	\N	CS	\N
6	BRASS	CIMBASSO, B FLAT	\N	CSB	\N
7	BRASS	CIMBASSO, C	\N	CSC	\N
8	BRASS	CIMBASSO, E FLAT	\N	CSE	\N
9	BRASS	CIMBASSO, F	\N	CSF	\N
10	BRASS	CORNET	\N	CT	\N
11	BRASS	CORNET , POCKET	\N	CTP	\N
12	BRASS	CORNET, A	\N	CTA	\N
13	BRASS	CORNET, C	\N	CTC	\N
14	BRASS	CORNET, E♭  FLAT	\N	CTE	\N
15	BRASS	DIDGERIDOO	\N	DGD	\N
16	BRASS	EUPHONIUM	\N	EP	\N
17	BRASS	EUPHONIUM , DOUBLE BELL	\N	EPD	\N
18	BRASS	FLUGELHORN	\N	FGH	\N
19	BRASS	FRENCH HORN	\N	FH	\N
20	BRASS	HORN, ALTO	\N	HNE	\N
21	BRASS	HORN, F	\N	HNF	\N
23	BRASS	METALLOPHONE	\N	MTL	\N
24	BRASS	SAXHORN	\N	SXH	\N
25	BRASS	SAXOTROMBA	\N	STB	\N
26	BRASS	SAXTUBA	\N	STU	\N
30	BRASS	TROMBONE, BASS	\N	TNB	\N
31	BRASS	TROMBONE, PICCOLO	\N	TNP	\N
32	BRASS	TROMBONE, SOPRANO	\N	TNS	\N
33	BRASS	TROMBONE, TENOR	\N	TN	\N
35	BRASS	TROMBONE, VALVE	\N	TNV	\N
36	BRASS	TRUMPET , PICCOLO	\N	TPC	\N
37	BRASS	TRUMPET ,TUBE	\N	TPX	\N
39	BRASS	TRUMPET, BAROQUE	\N	TPQ	\N
40	BRASS	TRUMPET, BASS	\N	TPB	\N
42	BRASS	TRUMPET, ROTARY	\N	TPR	\N
43	BRASS	TRUMPET, SLIDE	\N	TPSL	\N
44	BRASS	TRUMPET,SOPRANO	\N	TPS	\N
46	BRASS	TUBA, BASS	\N	TBB	\N
47	BRASS	TUBA, WAGNER	\N	TBW	\N
48	BRASS	VUVUZELA	\N	VV	\N
49	ELECTRIC	AMPLIFIER	\N	AM	\N
50	ELECTRIC	AMPLIFIER, BASS	\N	AMB	\N
51	ELECTRIC	AMPLIFIER, GUITAR	\N	AMG	\N
52	ELECTRIC	AMPLIFIER, KEYBOARD	\N	AMK	\N
56	KEYBOARD	KEYBOARD	\N	KB	\N
57	KEYBOARD	PIANO, GRAND	\N	PG	\N
58	KEYBOARD	PIANO, UPRIGHT	\N	PU	\N
59	KEYBOARD	PIANO (PIANOFORTE)	\N	P	\N
60	KEYBOARD	PIANO, ELECTRIC	\N	PE	\N
61	MISCELLANEOUS	HARNESS	\N	\N	\N
62	MISCELLANEOUS	PEDAL, SUSTAIN	\N	\N	\N
63	MISCELLANEOUS	STAND, GUITAR	\N	\N	\N
64	MISCELLANEOUS	STAND, MUSIC	\N	\N	\N
65	PERCUSSION	ASHIKO	\N	ASK	\N
66	PERCUSSION	BARREL DRUM	\N	BRD	\N
67	PERCUSSION	BASS DRUM	\N	BD	\N
68	PERCUSSION	BONGO DRUMS	\N	BNG	\N
69	PERCUSSION	CABASA	\N	CBS	\N
70	PERCUSSION	CARILLON	\N	CRL	\N
71	PERCUSSION	CASTANETS	\N	CST	\N
72	PERCUSSION	CLAPSTICK	\N	CLP	\N
73	PERCUSSION	CLAVES	\N	CLV	\N
74	PERCUSSION	CONGA	\N	CG	\N
75	PERCUSSION	COWBELL	\N	CWB	\N
76	PERCUSSION	CYMBAL	\N	CM	\N
77	PERCUSSION	DJEMBE	\N	DJ	\N
78	PERCUSSION	FLEXATONE	\N	FXT	\N
79	PERCUSSION	GLOCKENSPIEL	\N	GLK	\N
80	PERCUSSION	GOBLET DRUM	\N	GBL	\N
81	PERCUSSION	GONG	\N	GNG	\N
82	PERCUSSION	HANDBELLS	\N	HB	\N
83	PERCUSSION	HANDPAN	\N	HPN	\N
84	PERCUSSION	ILIMBA DRUM	\N	ILD	\N
85	PERCUSSION	KALIMBA	\N	KLM	\N
86	PERCUSSION	KANJIRA	\N	KNJ	\N
87	PERCUSSION	KAYAMBA	\N	KYM	\N
88	PERCUSSION	KEBERO	\N	KBR	\N
89	PERCUSSION	KEMANAK	\N	KMK	\N
90	PERCUSSION	MARIMBA	\N	MRM	\N
91	PERCUSSION	MBIRA	\N	MB	\N
92	PERCUSSION	MRIDANGAM	\N	MRG	\N
93	PERCUSSION	NAGARA (DRUM)	\N	NGR	\N
94	PERCUSSION	OCTA-VIBRAPHONE	\N	OV	\N
95	PERCUSSION	PATE	\N	PT	\N
96	PERCUSSION	SANDPAPER BLOCKS	\N	SPB	\N
97	PERCUSSION	SHEKERE	\N	SKR	\N
98	PERCUSSION	SLIT DRUM	\N	SLD	\N
99	PERCUSSION	SNARE	\N	SR	\N
100	PERCUSSION	STEELPAN	\N	SP	\N
101	PERCUSSION	TABLA	\N	TBL	\N
102	PERCUSSION	TALKING DRUM	\N	TDR	\N
103	PERCUSSION	TAMBOURINE	\N	TR	\N
104	PERCUSSION	TIMBALES (PAILAS)	\N	TMP	\N
105	PERCUSSION	TOM-TOM DRUM	\N	TT	\N
106	PERCUSSION	TRIANGLE	\N	TGL	\N
107	PERCUSSION	VIBRAPHONE	\N	VBR	\N
108	PERCUSSION	VIBRASLAP	\N	VS	\N
109	PERCUSSION	WOOD BLOCK	\N	WB	\N
110	PERCUSSION	XYLOPHONE	\N	X	\N
111	PERCUSSION	AGOGO BELL	\N	AGG	\N
112	PERCUSSION	BELL SET	\N	BL	\N
113	PERCUSSION	BELL TREE	\N	BLR	\N
114	PERCUSSION	BELLS, CONCERT	\N	BLC	\N
115	PERCUSSION	BELLS, SLEIGH	\N	BLS	\N
116	PERCUSSION	BELLS, TUBULAR	\N	BLT	\N
118	PERCUSSION	CYMBAL, SUSPENDED 18 INCH	\N	CMS	\N
119	PERCUSSION	CYMBALS, HANDHELD 16 INCH	\N	CMY	\N
120	PERCUSSION	CYMBALS, HANDHELD 18 INCH	\N	CMZ	\N
121	PERCUSSION	DRUMSET	\N	DK	\N
122	PERCUSSION	DRUMSET, ELECTRIC	\N	DKE	\N
123	PERCUSSION	EGG SHAKERS	\N	EGS	\N
124	PERCUSSION	GUIRO	\N	GUR	\N
125	PERCUSSION	MARACAS	\N	MRC	\N
127	PERCUSSION	PRACTICE KIT	\N	PK	\N
128	PERCUSSION	PRACTICE PAD	\N	PD	\N
129	PERCUSSION	QUAD, MARCHING	\N	Q	\N
130	PERCUSSION	RAINSTICK	\N	RK	\N
132	PERCUSSION	SNARE, CONCERT	\N	SRC	\N
133	PERCUSSION	SNARE, MARCHING	\N	SRM	\N
131	MISCELLANEOUS	SHIELD	\N	\N	\N
126	MISCELLANEOUS	MOUNTING BRACKET, BELL TREE	\N	\N	\N
54	SOUND	MIXER	\N	MX	\N
55	SOUND	PA SYSTEM, ALL-IN-ONE	\N	\N	\N
53	SOUND	MICROPHONE	\N	\N	\N
135	PERCUSSION	TAMBOURINE, 10 INCH	\N	TRT	\N
136	PERCUSSION	TAMBOURINE, 6 INCH	\N	TRS	\N
137	PERCUSSION	TAMBOURINE, 8 INCH	\N	TRE	\N
138	PERCUSSION	TIMBALI	\N	TML	\N
139	PERCUSSION	TIMPANI, 23 INCH	\N	TPT	\N
140	PERCUSSION	TIMPANI, 26 INCH	\N	TPD	\N
141	PERCUSSION	TIMPANI, 29 INCH	\N	TPN	\N
142	PERCUSSION	TIMPANI, 32 INCH	\N	TPW	\N
143	PERCUSSION	TOM, MARCHING	\N	TTM	\N
144	PERCUSSION	TUBANOS	\N	TBN	\N
145	PERCUSSION	WIND CHIMES	\N	WC	\N
146	STRING	ADUNGU	\N	ADG	\N
147	STRING	AEOLIAN HARP	\N	AHP	\N
148	STRING	AUTOHARP	\N	HPA	\N
149	STRING	BALALAIKA	\N	BLK	\N
150	STRING	BANJO	\N	BJ	\N
151	STRING	BANJO CELLO	\N	BJC	\N
152	STRING	BANJO, 4-STRING	\N	BJX	\N
153	STRING	BANJO, 5-STRING	\N	BJY	\N
154	STRING	BANJO, 6-STRING	\N	BJW	\N
155	STRING	BANJO, BASS	\N	BJB	\N
156	STRING	BANJO, BLUEGRASS	\N	BJG	\N
157	STRING	BANJO, PLECTRUM	\N	BJP	\N
158	STRING	BANJO, TENOR	\N	BJT	\N
159	STRING	BANJO, ZITHER	\N	BJZ	\N
160	STRING	CARIMBA	\N	CRM	\N
161	STRING	CELLO, (VIOLONCELLO)	\N	VCL	\N
162	STRING	CELLO, ELECTRIC	\N	VCE	\N
163	STRING	CHAPMAN STICK	\N	CPS	\N
164	STRING	CLAVICHORD	\N	CVC	\N
165	STRING	CLAVINET	\N	CVN	\N
166	STRING	CONTRAGUITAR	\N	GTC	\N
167	STRING	CRWTH, (CROWD)	\N	CRW	\N
168	STRING	DIDDLEY BOW	\N	DDB	\N
169	STRING	DOUBLE BASS	\N	DB	\N
170	STRING	DOUBLE BASS, 5-STRING	\N	DBF	\N
171	STRING	DOUBLE BASS, ELECTRIC	\N	DBE	\N
172	STRING	DULCIMER	\N	DCM	\N
173	STRING	ELECTRIC CYMBALUM	\N	CYE	\N
174	STRING	FIDDLE	\N	FDD	\N
175	STRING	GUITAR SYNTHESIZER	\N	GR	\N
176	STRING	GUITAR, 10-STRING	\N	GRK	\N
177	STRING	GUITAR, 12-STRING	\N	GRL	\N
178	STRING	GUITAR, 7-STRING	\N	GRM	\N
179	STRING	GUITAR, 8-STRING	\N	GRN	\N
180	STRING	GUITAR, 9-STRING	\N	GRP	\N
181	STRING	GUITAR, ACOUSTIC	\N	GRA	\N
182	STRING	GUITAR, ACOUSTIC-ELECTRIC	\N	GRJ	\N
183	STRING	GUITAR, ARCHTOP	\N	GRH	\N
184	STRING	GUITAR, BARITONE	\N	GRR	\N
185	STRING	GUITAR, BAROQUE	\N	GRQ	\N
186	STRING	GUITAR, BASS	\N	GRB	\N
187	STRING	GUITAR, BASS ACOUSTIC	\N	GRG	\N
188	STRING	GUITAR, BRAHMS	\N	GRZ	\N
189	STRING	GUITAR, CLASSICAL	\N	GRC	\N
190	STRING	GUITAR, CUTAWAY	\N	GRW	\N
191	STRING	GUITAR, DOUBLE-NECK	\N	GRD	\N
192	STRING	GUITAR, ELECTRIC	\N	GRE	\N
193	STRING	GUITAR, FLAMENCO	\N	GRF	\N
194	STRING	GUITAR, FRETLESS	\N	GRY	\N
195	STRING	GUITAR, HALF	\N	GRT	\N
196	STRING	GUITAR, OCTAVE	\N	GRO	\N
197	STRING	GUITAR, SEMI-ACOUSTIC	\N	GRX	\N
198	STRING	GUITAR, STEEL	\N	GRS	\N
199	STRING	HARDANGER FIDDLE	\N	FDH	\N
200	STRING	HARMONICO	\N	HMR	\N
201	STRING	HARP	\N	HP	\N
202	STRING	HARP GUITAR	\N	HPG	\N
203	STRING	HARP, ELECTRIC	\N	HPE	\N
204	STRING	HARPSICHORD	\N	HRC	\N
205	STRING	HURDY-GURDY	\N	HG	\N
206	STRING	KORA	\N	KR	\N
207	STRING	KOTO	\N	KT	\N
208	STRING	LOKANGA	\N	LK	\N
209	STRING	LUTE	\N	LT	\N
210	STRING	LUTE GUITAR	\N	LTG	\N
211	STRING	LYRA (BYZANTINE)	\N	LYB	\N
212	STRING	LYRA (CRETAN)	\N	LYC	\N
213	STRING	LYRE	\N	LY	\N
214	STRING	MANDOBASS	\N	MDB	\N
215	STRING	MANDOCELLO	\N	MDC	\N
216	STRING	MANDOLA	\N	MDL	\N
217	STRING	MANDOLIN	\N	MD	\N
218	STRING	MANDOLIN , BUEGRASS	\N	MDX	\N
219	STRING	MANDOLIN , ELECTRIC	\N	MDE	\N
220	STRING	MANDOLIN-BANJO	\N	MDJ	\N
221	STRING	MANDOLIN, OCTAVE	\N	MDO	\N
222	STRING	MANDOLUTE	\N	MDT	\N
223	STRING	MUSICAL BOW	\N	MSB	\N
224	STRING	OCTOBASS	\N	OCB	\N
225	STRING	OUD	\N	OUD	\N
226	STRING	PSALTERY	\N	PS	\N
227	STRING	SITAR	\N	STR	\N
228	STRING	THEORBO	\N	TRB	\N
229	STRING	U-BASS	\N	UB	\N
230	STRING	UKULELE, 5-STRING TENOR	\N	UKF	\N
231	STRING	UKULELE, 6-STRING TENOR	\N	UKX	\N
232	STRING	UKULELE, 8-STRING TENOR	\N	UKW	\N
233	STRING	UKULELE, BARITONE	\N	UKR	\N
234	STRING	UKULELE, BASS	\N	UKB	\N
235	STRING	UKULELE, CONCERT	\N	UKC	\N
236	STRING	UKULELE, CONTRABASS	\N	UKZ	\N
237	STRING	UKULELE, ELECTRIC	\N	UKE	\N
238	STRING	UKULELE, HARP	\N	UKH	\N
239	STRING	UKULELE, LAP STEEL	\N	UKL	\N
240	STRING	UKULELE, POCKET	\N	UKP	\N
241	STRING	UKULELE, SOPRANO	\N	UKS	\N
242	STRING	UKULELE, TENOR	\N	UKT	\N
243	STRING	VIOLA 13 INCH	\N	VLT	\N
244	STRING	VIOLA 16 INCH (FULL)	\N	VL	\N
245	STRING	VIOLA, ELECTRIC	\N	VLE	\N
246	STRING	VIOLIN	\N	VN	\N
247	STRING	VIOLIN, 1/2	\N	VNH	\N
248	STRING	VIOLIN, 1/4	\N	VNQ	\N
249	STRING	VIOLIN, 3/4	\N	VNT	\N
250	STRING	VIOLIN, ELECTRIC	\N	VNE	\N
251	STRING	ZITHER	\N	Z	\N
252	STRING	ZITHER, ALPINE (HARP ZITHER)	\N	ZA	\N
253	STRING	ZITHER, CONCERT	\N	ZC	\N
254	WOODWIND	ALPHORN	\N	ALH	\N
255	WOODWIND	BAGPIPE	\N	BGP	\N
256	WOODWIND	BASSOON	\N	BS	\N
257	WOODWIND	CHALUMEAU	\N	CHM	\N
258	WOODWIND	CLARINET, ALTO IN E FLAT	\N	CLE	\N
261	WOODWIND	CLARINET, BASSET IN A	\N	CLA	\N
262	WOODWIND	CLARINET, CONTRA-ALTO	\N	CLT	\N
263	WOODWIND	CLARINET, CONTRABASS	\N	CLU	\N
264	WOODWIND	CLARINET, PICCOLO IN A FLAT (OR G)	\N	CLC	\N
265	WOODWIND	CLARINET, SOPRANINO IN E FLAT (OR D)	\N	CLS	\N
266	WOODWIND	CONCERTINA	\N	CNT	\N
267	WOODWIND	CONTRABASSOON/DOUBLE BASSOON	\N	BSD	\N
268	WOODWIND	DULCIAN	\N	DLC	\N
269	WOODWIND	DULCIAN, ALTO	\N	DLCA	\N
270	WOODWIND	DULCIAN, BASS	\N	DLCB	\N
271	WOODWIND	DULCIAN, SOPRANO	\N	DLCS	\N
272	WOODWIND	DULCIAN, TENOR	\N	DLCT	\N
273	WOODWIND	DZUMARI	\N	DZ	\N
274	WOODWIND	ENGLISH HORN	\N	CA	\N
275	WOODWIND	FIFE	\N	FF	\N
276	WOODWIND	FLAGEOLET	\N	FGL	\N
278	WOODWIND	FLUTE , NOSE	\N	FLN	\N
279	WOODWIND	FLUTE, ALTO	\N	FLA	\N
280	WOODWIND	FLUTE, BASS	\N	FLB	\N
281	WOODWIND	FLUTE, CONTRA-ALTO	\N	FLX	\N
282	WOODWIND	FLUTE, CONTRABASS	\N	FLC	\N
283	WOODWIND	FLUTE, IRISH	\N	FLI	\N
284	WOODWIND	HARMONICA	\N	HM	\N
285	WOODWIND	HARMONICA, CHROMATIC	\N	HMC	\N
286	WOODWIND	HARMONICA, DIATONIC	\N	HMD	\N
287	WOODWIND	HARMONICA, ORCHESTRAL	\N	HMO	\N
288	WOODWIND	HARMONICA, TREMOLO	\N	HMT	\N
289	WOODWIND	KAZOO	\N	KZO	\N
290	WOODWIND	MELODEON	\N	MLD	\N
291	WOODWIND	MELODICA	\N	ML	\N
292	WOODWIND	MUSETTE DE COUR	\N	MSC	\N
294	WOODWIND	OCARINA	\N	OCR	\N
295	WOODWIND	PAN FLUTE	\N	PF	\N
297	WOODWIND	PIPE ORGAN	\N	PO	\N
298	WOODWIND	PITCH PIPE	\N	PP	\N
299	WOODWIND	RECORDER	\N	R	\N
300	WOODWIND	RECORDER, BASS	\N	RB	\N
301	WOODWIND	RECORDER, CONTRA BASS	\N	RC	\N
302	WOODWIND	RECORDER, DESCANT	\N	RD	\N
303	WOODWIND	RECORDER, GREAT BASS	\N	RG	\N
304	WOODWIND	RECORDER, SOPRANINO	\N	RS	\N
305	WOODWIND	RECORDER, SUBCONTRA BASS	\N	RX	\N
306	WOODWIND	RECORDER, TENOR	\N	RT	\N
307	WOODWIND	RECORDER, TREBLE OR ALTO	\N	RA	\N
308	WOODWIND	ROTHPHONE	\N	RP	\N
309	WOODWIND	ROTHPHONE , ALTO	\N	RPA	\N
310	WOODWIND	ROTHPHONE , BARITONE	\N	RPX	\N
311	WOODWIND	ROTHPHONE , BASS	\N	RPB	\N
312	WOODWIND	ROTHPHONE , SOPRANO	\N	RPS	\N
313	WOODWIND	ROTHPHONE , TENOR	\N	RPT	\N
314	WOODWIND	SARRUSOPHONE	\N	SRP	\N
315	WOODWIND	SAXOPHONE	\N	SX	\N
318	WOODWIND	SAXOPHONE, BASS	\N	SXY	\N
319	WOODWIND	SAXOPHONE, C MELODY (TENOR IN C)	\N	SXM	\N
320	WOODWIND	SAXOPHONE, C SOPRANO	\N	SXC	\N
321	WOODWIND	SAXOPHONE, CONTRABASS	\N	SXZ	\N
322	WOODWIND	SAXOPHONE, MEZZO-SOPRANO (ALTO IN F)	\N	SXF	\N
323	WOODWIND	SAXOPHONE, PICCOLO (SOPRILLO)	\N	SXP	\N
324	WOODWIND	SAXOPHONE, SOPRANINO	\N	SXX	\N
325	WOODWIND	SAXOPHONE, SOPRANO	\N	SXS	\N
327	WOODWIND	SEMICONTRABASSOON	\N	BSS	\N
328	WOODWIND	WHISTLE, TIN	\N	WT	\N
117	MISCELLANEOUS	CRADLE, CONCERT CYMBAL	\N	\N	\N
134	MISCELLANEOUS	STAND, CYMBAL	\N	\N	\N
329	PERCUSSION	BELL KIT	\N	BK	\N
330	BRASS	BARITONE/EUPHONIUM	BH	BH	\N
331	BRASS	BARITONE/TENOR HORN	BH	BT	\N
332	BRASS	MELLOPHONE	M	M	\N
333	BRASS	SOUSAPHONE	T	SSP	\N
334	BRASS	TROMBONE, ALTO	PTB	TNA	\N
335	BRASS	TROMBONE, ALTO - PLASTIC	PTB	TNAP	\N
336	BRASS	TROMBONE, TENOR - PLASTIC	PTB	TNTP	\N
337	BRASS	TRUMPET, B FLAT	TP	TP	\N
338	BRASS	TRUMPET, POCKET	TPP	TPP	\N
339	BRASS	TUBA	T	TB	\N
340	WOODWIND	CLARINET, B FLAT	CL	CL	\N
341	WOODWIND	CLARINET, BASS	BCL	CLB	\N
342	WOODWIND	FLUTE	FL	FL	\N
343	WOODWIND	OBOE	OB	OB	\N
344	WOODWIND	PICCOLO	PC	PC	\N
345	WOODWIND	SAXOPHONE, ALTO	AX	SXA	\N
346	WOODWIND	SAXOPHONE, BARITONE	BX	SXB	\N
347	WOODWIND	SAXOPHONE, TENOR	TX	SXT	\N
348	STRING	DUMMY 1	\N	DMMO	\N
\.


--
-- TOC entry 3960 (class 0 OID 24681)
-- Dependencies: 246
-- Data for Name: hardware_and_equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hardware_and_equipment (id, family, description, legacy_code, code, notes) FROM stdin;
10	SOUND	MIXER	\N	MX	\N
11	SOUND	PA SYSTEM, ALL-IN-ONE	\N	\N	\N
12	SOUND	MICROPHONE	\N	\N	\N
13	MISCELLANEOUS	HARNESS	\N	\N	\N
14	MISCELLANEOUS	PEDAL, SUSTAIN	\N	\N	\N
15	MISCELLANEOUS	STAND, GUITAR	\N	\N	\N
16	MISCELLANEOUS	STAND, MUSIC	\N	\N	\N
17	MISCELLANEOUS	SHIELD	\N	\N	\N
18	MISCELLANEOUS	MOUNTING BRACKET, BELL TREE	\N	\N	\N
19	MISCELLANEOUS	CRADLE, CONCERT CYMBAL	\N	\N	\N
20	MISCELLANEOUS	STAND, CYMBAL	\N	\N	\N
\.


--
-- TOC entry 3950 (class 0 OID 24362)
-- Dependencies: 236
-- Data for Name: instrument_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instrument_history (id, transaction_type, transaction_timestamp, item_id, notes, assigned_to, created_by) FROM stdin;
11	Instrument Created	2024-02-01	4163	\N	\N	postgres
12	Instrument Created	2024-02-01	4164	\N	\N	postgres
13	Instrument Created	2024-02-01	4165	\N	\N	postgres
14	Instrument Created	2024-02-01	4166	\N	\N	postgres
2987	Details Updated	2024-02-23	2129	\N	\N	nochomo
16	Instrument Out	2024-02-01	4166	\N	1072	postgres
2988	Instrument Out	2024-02-23	2129	\N	1074	nochomo
18	Instrument Out	2024-02-01	4166	\N	1072	postgres
3055	Instrument Returned	2024-03-01	4166	\N	\N	nochomo
20	Instrument Out	2024-02-01	4166	\N	1072	postgres
3103	Instrument Out	2024-03-04	4163	\N	1074	nochomo
3142	Instrument Returned	2024-03-07	4166	\N	\N	nochomo
23	Instrument Out	2024-02-01	4166	\N	1072	postgres
26	Instrument Out	2024-02-01	4166	\N	1072	postgres
27	Instrument Returned	2024-02-01	2129	\N	\N	postgres
30	Instrument Returned	2024-02-01	2129	\N	\N	postgres
2989	Details Updated	2024-02-23	4166	\N	\N	nochomo
2990	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3056	Instrument Out	2024-03-01	4166	\N	1074	nochomo
3104	Instrument Returned	2024-03-04	4166	\N	\N	nochomo
3105	Instrument Returned	2024-03-04	4165	\N	\N	nochomo
3106	Instrument Returned	2024-03-04	4164	\N	\N	nochomo
3143	Instrument Returned	2024-03-07	4165	\N	\N	nochomo
2991	Details Updated	2024-02-23	4166	\N	\N	postgres
2992	Instrument Returned	2024-02-23	4166	\N	\N	postgres
2993	Details Updated	2024-02-23	2129	\N	\N	postgres
2994	Instrument Returned	2024-02-23	2129	\N	\N	postgres
2997	Details Updated	2024-02-23	2129	\N	\N	postgres
2998	Instrument Returned	2024-02-23	2129	\N	\N	postgres
2999	Details Updated	2024-02-23	4166	\N	\N	postgres
3000	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3003	Details Updated	2024-02-23	4166	\N	\N	postgres
3004	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3007	Details Updated	2024-02-23	4166	\N	\N	postgres
3008	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3011	Details Updated	2024-02-23	4166	\N	\N	postgres
3012	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3015	Details Updated	2024-02-23	4166	\N	\N	postgres
3016	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3019	Details Updated	2024-02-23	4166	\N	\N	postgres
3020	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3023	Details Updated	2024-02-23	4166	\N	\N	postgres
3024	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3028	Details Updated	2024-02-23	4166	\N	\N	postgres
3029	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3032	Details Updated	2024-02-23	4166	\N	\N	postgres
3033	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3036	Details Updated	2024-02-23	4166	\N	\N	postgres
3037	Instrument Returned	2024-02-23	4166	\N	\N	postgres
3057	Instrument Returned	2024-03-01	4166	\N	\N	nochomo
3107	Instrument Out	2024-03-04	4166	\N	1072	nochomo
3144	Instrument Out	2024-03-07	4166	\N	1072	nochomo
2995	Details Updated	2024-02-23	4166	\N	\N	nochomo
2996	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3058	Instrument Out	2024-03-01	4166	\N	1074	nochomo
3108	Instrument Out	2024-03-04	2129	\N	1072	nochomo
3001	Details Updated	2024-02-23	4166	\N	\N	nochomo
3002	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3059	Instrument Returned	2024-03-01	4166	\N	\N	nochomo
3109	Instrument Returned	2024-03-04	4166	\N	\N	nochomo
3110	Instrument Returned	2024-03-04	4163	\N	\N	nochomo
3005	Details Updated	2024-02-23	4166	\N	\N	nochomo
3006	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3060	Instrument Out	2024-03-01	4166	\N	1074	nochomo
3061	Instrument Returned	2024-03-01	4166	\N	\N	nochomo
3062	Instrument Returned	2024-03-01	4166	\N	\N	nochomo
3111	Instrument Out	2024-03-04	4163	\N	1074	nochomo
3009	Details Updated	2024-02-23	4166	\N	\N	nochomo
3010	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3063	Instrument Out	2024-03-02	4166	\N	1074	nochomo
3112	Instrument Out	2024-03-04	4165	\N	1074	nochomo
3013	Details Updated	2024-02-23	4166	\N	\N	nochomo
3014	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3064	Instrument Returned	2024-03-02	4166	\N	\N	nochomo
3113	Instrument Returned	2024-03-04	4165	\N	\N	nochomo
3017	Details Updated	2024-02-23	4166	\N	\N	nochomo
3018	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3076	Instrument Out	2024-03-03	4166	\N	1074	nochomo
3114	Instrument Out	2024-03-04	4166	\N	1074	nochomo
3021	Details Updated	2024-02-23	4166	\N	\N	nochomo
3022	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3077	Instrument Returned	2024-03-03	4166	\N	\N	nochomo
3115	Instrument Returned	2024-03-04	4166	\N	\N	nochomo
3026	Details Updated	2024-02-23	4166	\N	\N	nochomo
3027	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3078	Instrument Out	2024-03-03	4166	\N	1074	nochomo
3116	Instrument Returned	2024-03-04	4163	\N	\N	nochomo
3030	Details Updated	2024-02-23	4166	\N	\N	nochomo
3031	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3082	Instrument Returned	2024-03-03	4166	\N	\N	nochomo
3117	Instrument Returned	2024-03-04	2129	\N	\N	nochomo
3034	Details Updated	2024-02-23	4166	\N	\N	nochomo
3035	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3083	Instrument Out	2024-03-03	4166	\N	1072	nochomo
3118	Instrument Out	2024-03-05	4166	\N	1072	nochomo
3038	Details Updated	2024-02-23	4166	\N	\N	nochomo
3039	Instrument Out	2024-02-23	4166	\N	1074	nochomo
3084	Instrument Out	2024-03-03	4165	\N	1074	nochomo
3119	Instrument Out	2024-03-05	4165	\N	1074	nochomo
3040	Details Updated	2024-02-23	4166	\N	\N	nochomo
3041	Instrument Returned	2024-02-23	4166	\N	\N	nochomo
3085	Instrument Out	2024-03-03	4164	\N	1074	nochomo
3120	Instrument Out	2024-03-06	2129	\N	1074	nochomo
3042	Instrument Returned	2024-02-23	4166	\N	\N	nochomo
3043	Instrument Returned	2024-02-23	4166	\N	\N	nochomo
3044	Instrument Returned	2024-02-23	4166	\N	\N	nochomo
3086	Instrument Out	2024-03-03	2129	\N	1074	nochomo
3121	Instrument Returned	2024-03-06	4166	\N	\N	nochomo
3045	Instrument Returned	2024-02-25	4166	\N	\N	nochomo
3087	Instrument Returned	2024-03-03	2129	\N	\N	nochomo
3088	Instrument Returned	2024-03-03	4164	\N	\N	nochomo
3089	Instrument Returned	2024-03-03	4165	\N	\N	nochomo
3090	Instrument Returned	2024-03-03	4166	\N	\N	nochomo
3122	Instrument Out	2024-03-06	4166	\N	1074	nochomo
3046	Instrument Returned	2024-02-25	4166	\N	\N	nochomo
3091	Instrument Out	2024-03-03	4166	\N	1072	nochomo
3123	Instrument Returned	2024-03-06	4166	\N	\N	nochomo
3047	Instrument Returned	2024-02-25	4166	\N	\N	nochomo
3048	Instrument Returned	2024-02-25	4166	\N	\N	nochomo
3092	Instrument Out	2024-03-03	4165	\N	1072	nochomo
3124	Instrument Out	2024-03-06	4166	\N	1074	nochomo
2264	Instrument Returned	2024-02-01	1731	\N	\N	postgres
2266	Instrument Returned	2024-02-01	1768	\N	\N	postgres
2268	Instrument Returned	2024-02-01	2072	\N	\N	postgres
2270	Instrument Returned	2024-02-01	1595	\N	\N	postgres
2272	Instrument Returned	2024-02-01	1618	\N	\N	postgres
2274	Instrument Returned	2024-02-01	2072	\N	\N	postgres
2276	Instrument Returned	2024-02-01	2072	\N	\N	postgres
2278	Instrument Returned	2024-02-01	1768	\N	\N	postgres
2280	Instrument Returned	2024-02-01	1618	\N	\N	postgres
2282	Instrument Returned	2024-02-01	1731	\N	\N	postgres
2284	Instrument Returned	2024-02-01	1595	\N	\N	postgres
3049	Instrument Returned	2024-02-25	4166	\N	\N	nochomo
3093	Instrument Returned	2024-03-03	1757	\N	\N	nochomo
3125	Instrument Returned	2024-03-06	4166	\N	\N	nochomo
3050	Instrument Returned	2024-02-25	4166	\N	\N	nochomo
3094	Instrument Returned	2024-03-03	1566	\N	\N	nochomo
3126	Instrument Returned	2024-03-07	4165	\N	\N	nochomo
3051	Instrument Returned	2024-02-28	4166	\N	\N	nochomo
3095	Instrument Returned	2024-03-03	2098	\N	\N	nochomo
3134	Instrument Out	2024-03-07	4166	\N	1074	postgres
3052	Instrument Returned	2024-02-28	4166	\N	\N	nochomo
3096	Instrument Out	2024-03-04	4164	\N	1072	nochomo
3097	Instrument Returned	2024-03-04	4164	\N	\N	nochomo
3098	Instrument Out	2024-03-04	4164	\N	1074	nochomo
3138	Instrument Out	2024-03-07	4165	\N	1074	nochomo
3053	Instrument Returned	2024-02-28	4166	\N	\N	nochomo
3099	Instrument Out	2024-03-04	4163	\N	1074	nochomo
3139	Instrument Returned	2024-03-07	4166	\N	\N	nochomo
3140	Instrument Out	2024-03-07	4166	\N	1074	nochomo
3054	Instrument Out	2024-03-01	4166	\N	1074	nochomo
3100	Instrument Returned	2024-03-04	4163	\N	\N	nochomo
3101	Instrument Returned	2024-03-04	4164	\N	\N	nochomo
3102	Instrument Out	2024-03-04	4164	\N	1074	nochomo
3141	Instrument Out	2024-03-07	4164	\N	1074	nochomo
2977	Instrument Returned	2024-02-15	4166	\N	\N	nochomo
\.


--
-- TOC entry 3932 (class 0 OID 24202)
-- Dependencies: 218
-- Data for Name: instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.instruments (id, legacy_number, code, description, serial, state, location, make, model, legacy_code, number, user_name, user_id) FROM stdin;
1734	216	\N	STAND, GUITAR	\N	Good	HS MUSIC	UNKNOWN	\N	\N	1	\N	\N
1774	589	SXA	SAXOPHONE, ALTO	11110739	Good	INSTRUMENT STORE	ETUDE	\N	AX	24	\N	\N
1773	519	FL	FLUTE	28411028	Good	INSTRUMENT STORE	PRELUDE	\N	FL	24	\N	\N
1791	302	TBN	TUBANOS	\N	Good	MS MUSIC	REMO	14 inch	\N	4	\N	\N
1798	401	BS	BASSOON	33CVC02	Good	INSTRUMENT STORE	UNKNOWN	\N	\N	1	\N	\N
1804	566	SXA	SAXOPHONE, ALTO	11120071	Good	INSTRUMENT STORE	ETUDE	\N	AX	1	\N	\N
1809	622	SXA	SAXOPHONE, ALTO	YF57624	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	53	\N	\N
1811	287	SR	SNARE	\N	Good	MS MUSIC	PEARL	\N	\N	3	\N	\N
1813	207	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	7	\N	\N
1821	631	SXA	SAXOPHONE, ALTO	BF54273	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	62	\N	\N
1829	626	SXA	SAXOPHONE, ALTO	AF53354	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	57	\N	\N
1818	243	CG	CONGA	\N	Good	MS MUSIC	MEINL	HEADLINER RANGE	\N	2	\N	\N
1832	627	SXA	SAXOPHONE, ALTO	AF53345	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	58	\N	\N
1835	630	SXA	SAXOPHONE, ALTO	BF54625	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	61	\N	\N
1837	637	SXA	SAXOPHONE, ALTO	CF57292	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	68	\N	\N
1838	638	SXA	SAXOPHONE, ALTO	CF57202	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	69	\N	\N
1839	639	SXA	SAXOPHONE, ALTO	CF56658	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	70	\N	\N
1782	78	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	46	\N	\N
1784	79	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	47	\N	\N
1789	80	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	48	\N	\N
1792	56	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	KAIZER	\N	PTB	24	\N	\N
1793	36	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	4	\N	\N
1799	37	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	5	\N	\N
1801	33	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	1	\N	\N
1807	653	SXT	SAXOPHONE, TENOR	N495304	Good	INSTRUMENT STORE	SELMER	\N	TX	9	\N	\N
1840	238	CLV	CLAVES	\N	Good	MS MUSIC	LP	GRENADILLA	\N	2	\N	\N
1841	251	CWB	COWBELL	\N	Good	MS MUSIC	LP	Black Beauty	\N	2	\N	\N
1808	657	SXT	SAXOPHONE, TENOR	TS10050022	Good	INSTRUMENT STORE	BUNDY	\N	TX	13	\N	\N
1781	525	FL	FLUTE	D1206510	Good	INSTRUMENT STORE	ETUDE	\N	FL	30	\N	\N
1815	647	SXT	SAXOPHONE, TENOR	31840	Good	INSTRUMENT STORE	YAMAHA	\N	TX	3	\N	\N
1775	25	TN	TROMBONE, TENOR	452363	Good	INSTRUMENT STORE	BLESSING	\N	TB	11	\N	\N
1776	27	TN	TROMBONE, TENOR	9120158	Good	INSTRUMENT STORE	ETUDE	\N	TB	13	\N	\N
1777	28	TN	TROMBONE, TENOR	9120243	Good	INSTRUMENT STORE	ETUDE	\N	TB	14	\N	\N
1783	159	TP	TRUMPET, B FLAT	CAS15598	Good	INSTRUMENT STORE	JUPITER	JTR 700	TP	70	\N	\N
1794	490	FL	FLUTE	2922376	Good	INSTRUMENT STORE	WT.AMSTRONG	104	FL	7	\N	\N
1796	13	M	MELLOPHONE	L02630	Good	INSTRUMENT STORE	JUPITER	\N	M	1	\N	\N
1802	562	OB	OBOE	B33327	Good	INSTRUMENT STORE	BUNDY	\N	OB	1	\N	\N
1803	564	PC	PICCOLO	11010007	Good	INSTRUMENT STORE	BUNDY	\N	PC	1	\N	\N
1778	29	TN	TROMBONE, TENOR	9120157	Good	INSTRUMENT STORE	ETUDE	\N	TB	15	\N	\N
1779	30	TN	TROMBONE, TENOR	1107197	Good	INSTRUMENT STORE	ALLORA	\N	TB	16	\N	\N
1780	31	TN	TROMBONE, TENOR	1107273	Good	INSTRUMENT STORE	ALLORA	\N	TB	17	\N	\N
1735	226	BLT	BELLS, TUBULAR	\N	Good	HS MUSIC	ROSS	\N	\N	1	\N	\N
1909	582	SXA	SAXOPHONE, ALTO	388666A	Good	INSTRUMENT STORE	YAMAHA	\N	AX	17	\N	\N
1910	583	SXA	SAXOPHONE, ALTO	T14584	Good	INSTRUMENT STORE	YAMAHA	YAS 23	AX	18	\N	\N
1845	293	TR	TAMBOURINE	\N	Good	MS MUSIC	REMO	Fiberskyn 3 black	\N	2	\N	\N
1846	199	PU	PIANO, UPRIGHT	\N	Good	PRACTICE ROOM 2	EAVESTAFF	\N	\N	2	\N	\N
1847	200	PU	PIANO, UPRIGHT	\N	Good	PRACTICE ROOM 3	SPENCER	\N	\N	3	\N	\N
1849	272	Q	QUAD, MARCHING	202902	Good	MS MUSIC	PEARL	Black	\N	1	\N	\N
1850	385	GRT	GUITAR, HALF	11	Good	\N	KAY	\N	\N	1	\N	\N
1851	387	GRT	GUITAR, HALF	9	Good	PRACTICE ROOM 3	KAY	\N	\N	3	\N	\N
1852	267	EGS	EGG SHAKERS	\N	Good	MS MUSIC	LP	Black 2 pr	\N	2	\N	\N
1853	271	MRC	MARACAS	\N	Good	MS MUSIC	LP	Pro Yellow Light Handle	\N	2	\N	\N
1854	210	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	10	\N	\N
1855	211	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	11	\N	\N
2029	574	SXA	SAXOPHONE, ALTO	348075	Good	\N	YAMAHA	\N	AX	9	Mwende Mittelstadt	192
1927	579	SXA	SAXOPHONE, ALTO	290365	Good	INSTRUMENT STORE	YAMAHA	\N	AX	14	\N	\N
1858	306	WB	WOOD BLOCK	\N	Good	HS MUSIC	BLACK SWAMP	BLA-MWB1	\N	1	\N	\N
1812	206	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	6	\N	\N
1859	166	AM	AMPLIFIER	72168	Good	MS MUSIC	GALLEN-K	\N	\N	2	\N	\N
1860	317	CMS	CYMBAL, SUSPENDED 18 INCH	AD 69101 046	Good	HS MUSIC	ZILDJIAN	Orchestral Selection ZIL-A0419	\N	1	\N	\N
1862	348	GRB	GUITAR, BASS	CGF1307326	Good	DRUM ROOM 1	FENDER	\N	\N	5	\N	\N
1863	388	GRT	GUITAR, HALF	4	Good	PRACTICE ROOM 3	KAY	\N	\N	4	\N	\N
1864	168	AMB	AMPLIFIER, BASS	M 1053205	Good	DRUM ROOM 1	FENDER	BASSMAN	\N	4	\N	\N
1866	393	GRT	GUITAR, HALF	8	Good	\N	KAY	\N	\N	9	\N	\N
1873	242	CG	CONGA	\N	Good	MS MUSIC	YAMAHA	Red 14 inch	\N	1	\N	\N
1867	247	CG	CONGA	ISK 3120157238	Good	MS MUSIC	LATIN PERCUSSION	12 inch	\N	4	\N	\N
1868	248	CG	CONGA	ISK 23 JAN 02	Good	MS MUSIC	LATIN PERCUSSION	14 Inch	\N	5	\N	\N
1869	244	CG	CONGA	ISK 3120138881	Good	MS MUSIC	LATIN PERCUSSION	10 Inch	\N	3	\N	\N
1870	249	CG	CONGA	ISK 312138881	Good	MS MUSIC	LATIN PERCUSSION	10 Inch	\N	6	\N	\N
1871	250	CG	CONGA	ISK 312120138881	Good	MS MUSIC	LATIN PERCUSSION	10 Inch	\N	7	\N	\N
1865	46	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	MS MUSIC	TROMBA	Pro	PTB	14	\N	\N
1875	183	KB	KEYBOARD	AH24202	Good	\N	ROLAND	813	\N	1	\N	\N
1883	264	DK	DRUMSET	\N	Good	MS MUSIC	PEARL	Vision	\N	3	\N	\N
1884	325	SR	SNARE	\N	Good	UPPER ES MUSIC	PEARL	\N	\N	4	\N	\N
1887	205	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	5	\N	\N
1888	274	SRM	SNARE, MARCHING	1P-3095	Good	MS MUSIC	YAMAHA	MS 9014	\N	1	\N	\N
1993	665	SXT	SAXOPHONE, TENOR	CF07553	Good	\N	JUPITER	JTS700	TX	21	Naomi Yohannes	361
1890	22	TN	TROMBONE, TENOR	320963	Good	MS MUSIC	YAMAHA	\N	TB	8	\N	\N
1881	39	TNAP	TROMBONE, ALTO - PLASTIC	BM17120413	Good	INSTRUMENT STORE	PBONE	Mini	PTB	7	\N	\N
1882	41	TNAP	TROMBONE, ALTO - PLASTIC	BM17120388	Good	INSTRUMENT STORE	PBONE	Mini	PTB	9	\N	\N
1889	164	SSP	SOUSAPHONE	910530	Good	MS MUSIC	YAMAHA	\N	T	1	\N	\N
1912	241	SRC	SNARE, CONCERT	\N	Good	HS MUSIC	BLACK SWAMP	BLA-CM514BL	\N	1	\N	\N
1913	297	TPT	TIMPANI, 23 INCH	52479	Good	HS MUSIC	LUDWIG	LKS423FG	\N	6	\N	\N
1914	282	\N	SHIELD	\N	Good	HS MUSIC	GIBRALTAR	GIB-GDS-5	\N	1	\N	\N
1917	280	PK	PRACTICE KIT	\N	Good	UPPER ES MUSIC	PEARL	\N	\N	1	\N	\N
1919	261	DJ	DJEMBE	\N	Good	MS MUSIC	CUSTOM	\N	\N	6	\N	\N
1920	259	DJ	DJEMBE	\N	Good	MS MUSIC	CUSTOM	\N	\N	4	\N	\N
1921	224	RK	RAINSTICK	\N	Good	UPPER ES MUSIC	CUSTOM	\N	\N	3	\N	\N
1805	417	CL	CLARINET, B FLAT	989832	Good	INSTRUMENT STORE	BUNDY	\N	CL	9	\N	\N
1810	107	TP	TRUMPET, B FLAT	H34971	Good	INSTRUMENT STORE	BLESSING	\N	TP	27	\N	\N
1816	413	CL	CLARINET, B FLAT	7943	Good	INSTRUMENT STORE	YAMAHA	\N	CL	6	\N	\N
1817	432	CL	CLARINET, B FLAT	444451	Good	INSTRUMENT STORE	YAMAHA	\N	CL	24	\N	\N
1820	556	FL	FLUTE	BD62736	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	62	\N	\N
1822	471	CL	CLARINET, B FLAT	YE67775	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	63	\N	\N
1823	472	CL	CLARINET, B FLAT	YE67468	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	64	\N	\N
1824	476	CL	CLARINET, B FLAT	BE63558	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	68	\N	\N
1825	462	CL	CLARINET, B FLAT	XE50000	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	54	\N	\N
1826	549	FL	FLUTE	YD66218	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	55	\N	\N
1827	550	FL	FLUTE	YD66291	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	56	\N	\N
1828	465	CL	CLARINET, B FLAT	XE54699	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	57	\N	\N
1830	466	CL	CLARINET, B FLAT	XE54697	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	58	\N	\N
1831	552	FL	FLUTE	BD62678	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	58	\N	\N
1833	553	FL	FLUTE	BD63526	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	59	\N	\N
1922	331	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	3	\N	\N
1928	227	VS	VIBRASLAP	\N	Good	HS MUSIC	WEISS	SW-VIBRA	\N	1	\N	\N
1834	554	FL	FLUTE	BD63433	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	60	\N	\N
1737	576	SXA	SAXOPHONE, ALTO	3468	Good	INSTRUMENT STORE	BLESSING	\N	AX	11	\N	\N
2098	62	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	30	\N	\N
1925	235	CST	CASTANETS	\N	Good	HS MUSIC	DANMAR	DAN-17A	\N	1	\N	\N
1733	611	SXA	SAXOPHONE, ALTO	XF53790	Good	\N	JUPITER	JAS 710	AX	42	Olivia Freiin Von Handel	933
1530	315	BL	BELL SET	\N	Good	INSTRUMENT STORE	UNKNOWN	\N	\N	4	\N	\N
1926	169	AMB	AMPLIFIER, BASS	AX78271	Good	MS MUSIC	ROLAND	CUBE-100	\N	5	\N	\N
1886	204	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	4	\N	\N
1929	223	RK	RAINSTICK	\N	Good	UPPER ES MUSIC	CUSTOM	\N	\N	2	\N	\N
1930	330	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	2	\N	\N
1491	273	Q	QUAD, MARCHING	203143	Good	MS MUSIC	PEARL	Black	\N	2	\N	\N
1492	276	SRM	SNARE, MARCHING	\N	Good	MS MUSIC	VERVE	White	\N	3	\N	\N
1493	277	SRM	SNARE, MARCHING	\N	Good	MS MUSIC	VERVE	White	\N	4	\N	\N
1495	75	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	43	\N	\N
1497	76	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	44	\N	\N
1504	77	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	45	\N	\N
1506	48	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	16	\N	\N
1507	51	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	19	\N	\N
1980	52	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	HS MUSIC	KAIZER	\N	PTB	20	\N	\N
1981	53	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	HS MUSIC	KAIZER	\N	PTB	21	\N	\N
1932	333	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	5	\N	\N
1933	334	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	6	\N	\N
1934	335	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	7	\N	\N
1935	167	AMB	AMPLIFIER, BASS	ICTB15016929	Good	HS MUSIC	FENDER	Rumble 25	\N	3	\N	\N
1936	399	VN	VIOLIN	V2024618	Good	HS MUSIC	ANDREAS EASTMAN	\N	\N	4	\N	\N
1937	298	TPD	TIMPANI, 26 INCH	51734	Good	HS MUSIC	LUDWIG	SUD-LKS426FG	\N	2	\N	\N
1938	400	VN	VIOLIN	V2025159	Good	HS MUSIC	ANDREAS EASTMAN	\N	\N	5	\N	\N
1939	326	TPN	TIMPANI, 29 INCH	36346	Good	HS MUSIC	LUDWIG	\N	\N	5	\N	\N
1940	172	AMG	AMPLIFIER, GUITAR	ICTB1500267	Good	HS MUSIC	FENDER	Frontman 15G	\N	7	\N	\N
1941	232	\N	MOUNTING BRACKET, BELL TREE	\N	Good	HS MUSIC	TREEWORKS	TW-TRE52	\N	1	\N	\N
1942	327	TPW	TIMPANI, 32 INCH	36301	Good	HS MUSIC	LUDWIG	\N	\N	4	\N	\N
1943	294	TRT	TAMBOURINE, 10 INCH	\N	Good	HS MUSIC	PEARL	Symphonic Double Row PEA-PETM1017	\N	1	\N	\N
1944	222	RK	RAINSTICK	\N	Good	UPPER ES MUSIC	CUSTOM	\N	\N	1	\N	\N
1945	329	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	1	\N	\N
1947	165	AM	AMPLIFIER	M 1134340	Good	HS MUSIC	FENDER	\N	\N	1	\N	\N
1948	229	BD	BASS DRUM	3442181	Good	HS MUSIC	LUDWIG	\N	\N	1	\N	\N
1949	311	X	XYLOPHONE	\N	Good	HS MUSIC	DII	Decator	\N	18	\N	\N
1950	174	AMK	AMPLIFIER, KEYBOARD	ODB#1230169	Good	HS MUSIC	PEAVEY	\N	\N	9	\N	\N
1960	20	TN	TROMBONE, TENOR	071009A	Good	INSTRUMENT STORE	YAMAHA	\N	TB	6	\N	\N
1953	328	X	XYLOPHONE	660845710719	Good	HS MUSIC	UNKNOWN	\N	\N	19	\N	\N
1954	179	\N	MICROPHONE	\N	Good	HS MUSIC	SHURE	SM58	\N	1	\N	\N
1955	233	CBS	CABASA	\N	Good	HS MUSIC	LP	LP234A	\N	1	\N	\N
1956	268	GUR	GUIRO	\N	Good	HS MUSIC	LP	Super LP243	\N	1	\N	\N
1957	231	BLR	BELL TREE	\N	Good	HS MUSIC	TREEWORKS	TW-TRE35	\N	1	\N	\N
1958	270	MRC	MARACAS	\N	Good	HS MUSIC	WEISS	\N	\N	1	\N	\N
1961	300	TGL	TRIANGLE	\N	Good	HS MUSIC	ALAN ABEL	6" Inch Symphonic	\N	1	\N	\N
1962	236	CLV	CLAVES	\N	Good	HS MUSIC	LP	GRENADILLA	\N	3	\N	\N
1963	368	GRC	GUITAR, CLASSICAL	HKPO64008	Good	MS MUSIC	YAMAHA	40	\N	12	\N	\N
1964	369	GRC	GUITAR, CLASSICAL	HKP054554	Good	MS MUSIC	YAMAHA	40	\N	13	\N	\N
1971	220	CWB	COWBELL	\N	Good	HS MUSIC	LP	Black Beauty	\N	1	\N	\N
1972	337	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	9	\N	\N
1973	338	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	10	\N	\N
1974	339	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	11	\N	\N
1975	340	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	12	\N	\N
1976	341	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	13	\N	\N
1977	342	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	14	\N	\N
1978	171	AMB	AMPLIFIER, BASS	OJBHE2300098	Good	HS MUSIC	PEAVEY	TKO-230EU	\N	11	\N	\N
1979	343	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	15	\N	\N
1836	470	CL	CLARINET, B FLAT	YE67470	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	62	\N	\N
1843	146	TP	TRUMPET, B FLAT	XA04125	Good	INSTRUMENT STORE	JUPITER	\N	TP	57	\N	\N
1785	557	FL	FLUTE	DD58225	Good	\N	JUPITER	JFL 700	FL	63	Malan Chopra	927
2073	446	CL	CLARINET, B FLAT	J65493	Good	\N	YAMAHA	\N	CL	38	Vashnie Joymungul	1032
4163	\N	DMMO	DUMMY 1	DUMMM1	Good	INSTRUMENT STORE	DUMMY MAKER	DUMDUM	\N	2	\N	\N
1946	336	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	8	\N	\N
1984	307	WB	WOOD BLOCK	\N	Good	MS MUSIC	LP	PLASTIC RED	\N	2	\N	\N
1985	380	GRE	GUITAR, ELECTRIC	115085004	Good	HS MUSIC	FENDER	CD-60CE Mahogany	\N	26	\N	\N
1986	308	WB	WOOD BLOCK	\N	Good	MS MUSIC	LP	PLASTIC BLUE	\N	3	\N	\N
1987	269	GUR	GUIRO	\N	Good	MS MUSIC	LP	Plastic	\N	2	\N	\N
1988	310	X	XYLOPHONE	587	Good	MS MUSIC	ROSS	410	\N	17	\N	\N
1992	373	GRC	GUITAR, CLASSICAL	\N	Good	MS MUSIC	PARADISE	19	\N	19	\N	\N
1998	390	GRT	GUITAR, HALF	3	Good	PRACTICE ROOM 3	KAY	\N	\N	6	\N	\N
2000	382	GRE	GUITAR, ELECTRIC	115085034	Good	\N	FENDER	CD-60CE Mahogany	\N	25	\N	\N
2001	266	DKE	DRUMSET, ELECTRIC	694318011177	Good	DRUM ROOM 2	ALESIS	DM8	\N	5	\N	\N
2026	578	SXA	SAXOPHONE, ALTO	352128A	Good	INSTRUMENT STORE	YAMAHA	\N	AX	13	\N	\N
2003	197	PG	PIANO, GRAND	302697	Good	PIANO ROOM	GEBR. PERZINO	GBT 175	\N	1	\N	\N
2004	198	PU	PIANO, UPRIGHT	\N	Good	PRACTICE ROOM 1	ELSENBERG	\N	\N	1	\N	\N
2005	391	GRT	GUITAR, HALF	1	Good	PRACTICE ROOM 3	KAY	\N	\N	7	\N	\N
2007	392	GRT	GUITAR, HALF	12	Good	PRACTICE ROOM 3	KAY	\N	\N	8	\N	\N
2008	395	GRT	GUITAR, HALF	6	Good	PRACTICE ROOM 3	KAY	\N	\N	11	\N	\N
2009	228	AGG	AGOGO BELL	\N	Good	MS MUSIC	LP	577 Dry	\N	1	\N	\N
2010	292	TR	TAMBOURINE	\N	Good	MS MUSIC	MEINL	Open face	\N	1	\N	\N
2011	323	BK	BELL KIT	\N	Good	MS MUSIC	PEARL	PK900C	\N	6	\N	\N
2012	318	BK	BELL KIT	\N	Good	MS MUSIC	PEARL	PK900C	\N	1	\N	\N
2013	284	BLS	BELLS, SLEIGH	\N	Good	MS MUSIC	LUDWIG	Red Handle	\N	2	\N	\N
2014	279	TTM	TOM, MARCHING	6 PAIRS	Good	HS MUSIC	PEARL	\N	\N	1	\N	\N
2015	218	\N	STAND, MUSIC	\N	Good	MS MUSIC	GMS	\N	\N	2	\N	\N
2016	305	WC	WIND CHIMES	\N	Good	MS MUSIC	LP	LP236D	\N	1	\N	\N
2017	301	TGL	TRIANGLE	\N	Good	MS MUSIC	ALAN ABEL	6 inch	\N	2	\N	\N
2018	234	CBS	CABASA	\N	Good	MS MUSIC	LP	Small	\N	2	\N	\N
2019	202	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	2	\N	\N
2020	237	CLV	CLAVES	\N	Good	MS MUSIC	KING	\N	\N	1	\N	\N
2021	376	GRC	GUITAR, CLASSICAL	265931HRJ	Good	INSTRUMENT STORE	YAMAHA	40	\N	28	\N	\N
1982	58	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	HS MUSIC	KAIZER	\N	PTB	26	\N	\N
2023	362	GRC	GUITAR, CLASSICAL	HKPO065675	Good	MS MUSIC	YAMAHA	40	\N	6	\N	\N
2055	49	TNTP	TROMBONE, TENOR - PLASTIC	PR18100094	Good	\N	TROMBA	Pro	PTB	17	Lilyrose Trottier	357
2002	15	TN	TROMBONE, TENOR	970406	Good	MS MUSIC	HOLTON	TR259	TB	1	\N	\N
2030	191	PE	PIANO, ELECTRIC	YCQM01249	Good	MS MUSIC	YAMAHA	CAP 320	\N	4	\N	\N
2027	19	TN	TROMBONE, TENOR	334792	Good	INSTRUMENT STORE	YAMAHA	\N	TB	5	\N	\N
2033	481	CLB	CLARINET, BASS	43084	Good	INSTRUMENT STORE	YAMAHA	\N	BCL	3	\N	\N
2034	189	PE	PIANO, ELECTRIC	GBRCKK 01006	Good	MUSIC OFFICE	YAMAHA	CVP303x	\N	2	\N	\N
2035	190	PE	PIANO, ELECTRIC	7163	Good	MUSIC OFFICE	YAMAHA	CVP 87A	\N	3	\N	\N
2036	366	GRC	GUITAR, CLASSICAL	HKP064183	Good	MS MUSIC	YAMAHA	40	\N	10	\N	\N
2037	357	GRC	GUITAR, CLASSICAL	HKZ107832	Good	\N	YAMAHA	40	\N	1	\N	\N
2038	358	GRC	GUITAR, CLASSICAL	HKZ034412	Good	MS MUSIC	YAMAHA	40	\N	2	\N	\N
2039	359	GRC	GUITAR, CLASSICAL	HKP065151	Good	MS MUSIC	YAMAHA	40	\N	3	\N	\N
2120	409	CL	CLARINET, B FLAT	7988	Good	\N	YAMAHA	\N	CL	4	Zecarun Caminha	538
1856	87	TP	TRUMPET, B FLAT	638871	Good	INSTRUMENT STORE	YAMAHA	YTR 2335	TP	7	\N	\N
1857	81	TP	TRUMPET, B FLAT	808845	Good	INSTRUMENT STORE	YAMAHA	\N	TP	1	\N	\N
1874	415	CL	CLARINET, B FLAT	B 859866/7112-STORE	Good	\N	VITO	\N	CL	7	\N	\N
1891	486	FL	FLUTE	600365	Good	INSTRUMENT STORE	YAMAHA	\N	FL	3	\N	\N
1893	488	FL	FLUTE	452046A	Good	MS MUSIC	YAMAHA	\N	FL	5	\N	\N
1896	89	TP	TRUMPET, B FLAT	556519	Good	INSTRUMENT STORE	YAMAHA	\N	TP	9	\N	\N
1897	532	FL	FLUTE	AP28041129	Good	\N	PRELUDE	\N	FL	37	\N	\N
1903	95	TP	TRUMPET, B FLAT	634070	Good	INSTRUMENT STORE	YAMAHA	YTR 2335	TP	15	\N	\N
1904	110	TP	TRUMPET, B FLAT	501720	Good	INSTRUMENT STORE	YAMAHA	YTR 2335	TP	30	\N	\N
1911	428	CL	CLARINET, B FLAT	J65540	Good	INSTRUMENT STORE	YAMAHA	\N	CL	20	\N	\N
1916	112	TP	TRUMPET, B FLAT	638850	Good	MS MUSIC	YAMAHA	YTR 2335	TP	32	\N	\N
1755	441	CL	CLARINET, B FLAT	J65382	Good	\N	YAMAHA	\N	CL	33	Moussa Sangare	929
2040	421	CL	CLARINET, B FLAT	27303	Good	\N	YAMAHA	\N	CL	13	Naia Friedhoff Jaeschke	602
1736	416	CL	CLARINET, B FLAT	504869	Good	INSTRUMENT STORE	AMATI KRASLICE	\N	CL	8	\N	\N
1496	94	TP	TRUMPET, B FLAT	L306677	Good	INSTRUMENT STORE	BACH	Stradivarius 37L	TP	14	\N	\N
1498	97	TP	TRUMPET, B FLAT	S-756323	Good	INSTRUMENT STORE	CONN	\N	TP	17	\N	\N
1499	98	TP	TRUMPET, B FLAT	H35537	Good	INSTRUMENT STORE	BLESSING	BTR 1270	TP	18	\N	\N
1500	102	TP	TRUMPET, B FLAT	H34929	Good	INSTRUMENT STORE	BLESSING	BIR 1270	TP	22	\N	\N
1501	104	TP	TRUMPET, B FLAT	H32053	Good	INSTRUMENT STORE	BLESSING	BIR 1270	TP	24	\N	\N
1502	105	TP	TRUMPET, B FLAT	H31491	Good	INSTRUMENT STORE	BLESSING	BIR 1270	TP	25	\N	\N
1503	108	TP	TRUMPET, B FLAT	F24304	Good	INSTRUMENT STORE	BLESSING	\N	TP	28	\N	\N
1505	133	TP	TRUMPET, B FLAT	XA07789	Good	INSTRUMENT STORE	JUPITER	\N	TP	44	\N	\N
1951	429	CL	CLARINET, B FLAT	J65851	Good	INSTRUMENT STORE	YAMAHA	\N	CL	21	\N	\N
1952	442	CL	CLARINET, B FLAT	J65593	Good	INSTRUMENT STORE	YAMAHA	\N	CL	34	\N	\N
1959	443	CL	CLARINET, B FLAT	J65299	Good	INSTRUMENT STORE	YAMAHA	\N	CL	35	\N	\N
1965	499	FL	FLUTE	617224	Good	INSTRUMENT STORE	YAMAHA	\N	FL	11	\N	\N
2096	580	SXA	SAXOPHONE, ALTO	362547A	Good	\N	YAMAHA	\N	AX	15	Caitlin Wood	160
1764	575	SXA	SAXOPHONE, ALTO	387824A	Good	INSTRUMENT STORE	YAMAHA	\N	AX	10	\N	\N
1766	636	SXA	SAXOPHONE, ALTO	CF57086	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	67	\N	\N
1966	420	CL	CLARINET, B FLAT	7980	Good	INSTRUMENT STORE	YAMAHA	\N	CL	12	\N	\N
1967	434	CL	CLARINET, B FLAT	B88822	Good	INSTRUMENT STORE	YAMAHA	\N	CL	26	\N	\N
1968	405	CL	CLARINET, B FLAT	206603A	Good	INSTRUMENT STORE	YAMAHA	\N	CL	2	\N	\N
1969	485	FL	FLUTE	826706	Good	INSTRUMENT STORE	YAMAHA	222	FL	2	\N	\N
2022	6	BH	BARITONE/EUPHONIUM	534386	Good	INSTRUMENT STORE	YAMAHA	\N	BH	7	\N	\N
2024	403	CL	CLARINET, B FLAT	206681A	Good	INSTRUMENT STORE	YAMAHA	\N	CL	1	\N	\N
2025	484	FL	FLUTE	609368	Good	INSTRUMENT STORE	YAMAHA	\N	FL	1	\N	\N
1494	506	FL	FLUTE	K96338	Good	INSTRUMENT STORE	GEMEINHARDT	2SP	FL	15	\N	\N
2032	407	CL	CLARINET, B FLAT	7291	Good	INSTRUMENT STORE	YAMAHA	\N	CL	3	\N	\N
1739	431	CL	CLARINET, B FLAT	193026A	Good	\N	YAMAHA	\N	CL	23	Fatuma Tall	301
1756	444	CL	CLARINET, B FLAT	J65434	Good	\N	YAMAHA	\N	CL	36	Anastasia Mulema	979
1768	489	FL	FLUTE	42684	Good	INSTRUMENT STORE	EMERSON	EF1	FL	6	\N	\N
1787	134	TP	TRUMPET, B FLAT	XA08653	Good	\N	JUPITER	\N	TP	45	Connor Fort	299
1742	422	CL	CLARINET, B FLAT	206167	Good	INSTRUMENT STORE	AMATI KRASLICE	\N	CL	14	\N	\N
1763	492	FL	FLUTE	650122	Good	INSTRUMENT STORE	YAMAHA	\N	FL	8	\N	\N
1765	475	CL	CLARINET, B FLAT	BE63660	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	67	\N	\N
1767	502	FL	FLUTE	K96367	Good	INSTRUMENT STORE	GEMEINHARDT	2SP	FL	13	\N	\N
1770	518	FL	FLUTE	33111112	Good	INSTRUMENT STORE	PRELUDE	\N	FL	23	\N	\N
1746	468	CL	CLARINET, B FLAT	XE54704	Good	\N	JUPITER	JCL710	CL	60	Lorian Inglis	358
1786	122	TP	TRUMPET, B FLAT	124911	Good	\N	ETUDE	\N	TP	38	Mark Anding	1076
1745	254	\N	STAND, CYMBAL	\N	Good	HS MUSIC	GIBRALTAR	GIB-5710	\N	1	\N	\N
1747	296	TPT	TIMPANI, 23 INCH	36264	Good	MS MUSIC	LUDWIG	LKS423FG	\N	1	\N	\N
1748	309	X	XYLOPHONE	25	Good	MS MUSIC	MAJESTIC	x55 352	\N	16	\N	\N
1749	182	\N	PA SYSTEM, ALL-IN-ONE	S1402186AA8	Good	HS MUSIC	BEHRINGER	EPS500MP3	\N	1	\N	\N
1570	96	TP	TRUMPET, B FLAT	33911	Good	\N	SCHILKE	B1L	TP	16	Mark Anding	1076
1753	209	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	9	\N	\N
1758	215	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	15	\N	\N
1759	203	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	3	\N	\N
1760	253	CMZ	CYMBALS, HANDHELD 18 INCH	ZIL-A0447	Good	HS MUSIC	ZILDJIAN	18 Inch Symphonic Viennese Tone	\N	1	\N	\N
1761	378	GRW	GUITAR, CUTAWAY	\N	Good	MS MUSIC	UNKNOWN	\N	\N	15	\N	\N
1762	379	GRW	GUITAR, CUTAWAY	\N	Good	MS MUSIC	UNKNOWN	\N	\N	16	\N	\N
1769	304	TBN	TUBANOS	1-7	Good	MS MUSIC	REMO	12 inch	\N	7	\N	\N
2064	263	DK	DRUMSET	\N	Good	DRUM ROOM 1	YAMAHA	\N	\N	2	\N	\N
2061	361	GRC	GUITAR, CLASSICAL	HKZ114314	Good	MS MUSIC	YAMAHA	40	\N	5	\N	\N
2065	324	DK	DRUMSET	\N	Good	DRUM ROOM 2	YAMAHA	\N	\N	6	\N	\N
2066	411	CL	CLARINET, B FLAT	27251	Good	\N	YAMAHA	\N	CL	5	Mark Anding	1076
1885	398	VN	VIOLIN	D 0933 1998	Good	\N	WILLIAM LEWIS & SON	\N	\N	3	Gakenia Mucharie	1075
4164	\N	DMMO	DUMMY 1	DUMMM2	Good	\N	DUMMY MAKER	DUMDUM	\N	3	\N	1074
1771	588	SXA	SAXOPHONE, ALTO	11110695	Good	INSTRUMENT STORE	ETUDE	\N	AX	23	\N	\N
1790	613	SXA	SAXOPHONE, ALTO	XF56401	Good	\N	JUPITER	JAS 710	AX	44	Emiel Ghelani-Decorte	662
1877	614	SXA	SAXOPHONE, ALTO	XF57089	Good	\N	JUPITER	JAS 710	AX	45	Fatuma Tall	301
2059	402	CLE	CLARINET, ALTO IN E FLAT	1260	Good	\N	YAMAHA	\N	\N	1	Mark Anding	1076
1879	634	SXA	SAXOPHONE, ALTO	BF54604	Good	\N	JUPITER	JAS 710	AX	65	Ethan Sengendo	393
2060	610	SXA	SAXOPHONE, ALTO	XF54140	Good	\N	JUPITER	JAS 710	AX	41	Lucile Bamlango	176
1878	615	SXA	SAXOPHONE, ALTO	XF57192	Good	\N	JUPITER	JAS 710	AX	46	Max Stock	956
2056	120	TP	TRUMPET, B FLAT	124816	Good	\N	ETUDE	\N	TP	37	Masoud Ibrahim	787
1743	126	TP	TRUMPET, B FLAT	H35214	Good	\N	BLESSING	\N	TP	40	Masoud Ibrahim	787
1588	478	CL	CLARINET, B FLAT	BE63657	Good	\N	JUPITER	JCL710	CL	70	Gakenia Mucharie	1075
1514	140	TP	TRUMPET, B FLAT	XA06017	Good	INSTRUMENT STORE	JUPITER	\N	TP	51	\N	\N
1772	667	SXT	SAXOPHONE, TENOR	CF08026	Good	INSTRUMENT STORE	JUPITER	JTS700	TX	23	\N	\N
1741	32	TN	TROMBONE, TENOR	646721	Good	\N	YAMAHA	\N	TB	18	Andrew Wachira	268
1892	24	TN	TROMBONE, TENOR	316975	Good	\N	YAMAHA	\N	TB	10	Margaret Oganda	1078
1861	12	HNF	HORN, F	BC00278	Good	\N	JUPITER	JHR1100	HN	5	Kai O'Bra	480
1527	573	SXA	SAXOPHONE, ALTO	200547	Good	INSTRUMENT STORE	GIARDINELLI	\N	AX	8	\N	\N
1511	137	TP	TRUMPET, B FLAT	XA08294	Good	INSTRUMENT STORE	JUPITER	\N	TP	48	\N	\N
1582	180	\N	MICROPHONE	\N	Good	HS MUSIC	SHURE	SM58	\N	2	\N	\N
1723	312	BL	BELL SET	\N	Good	INSTRUMENT STORE	UNKNOWN	\N	\N	1	\N	\N
1534	569	SXA	SAXOPHONE, ALTO	11120109	Good	INSTRUMENT STORE	ETUDE	\N	AX	4	\N	\N
1512	138	TP	TRUMPET, B FLAT	XA08319	Good	INSTRUMENT STORE	JUPITER	\N	TP	49	\N	\N
1725	397	VN	VIOLIN	3923725	Good	INSTRUMENT STORE	AUBERT	\N	\N	2	\N	\N
1548	571	SXA	SAXOPHONE, ALTO	12080618	Good	INSTRUMENT STORE	ETUDE	\N	AX	6	\N	\N
1555	612	SXA	SAXOPHONE, ALTO	XF56514	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	43	\N	\N
1578	584	SXA	SAXOPHONE, ALTO	AS1001039	Good	INSTRUMENT STORE	BARRINGTON	\N	AX	19	\N	\N
1580	568	SXA	SAXOPHONE, ALTO	11120090	Good	INSTRUMENT STORE	ETUDE	\N	AX	3	\N	\N
1602	585	SXA	SAXOPHONE, ALTO	AS1003847	Good	INSTRUMENT STORE	BARRINGTON	\N	AX	20	\N	\N
1726	45	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	13	\N	\N
1728	34	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	2	\N	\N
1549	35	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	3	\N	\N
1931	332	X	XYLOPHONE	\N	Good	UPPER ES MUSIC	ORFF	\N	\N	4	\N	\N
1579	50	TNTP	TROMBONE, TENOR - PLASTIC	PB17070322	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	18	\N	\N
1526	645	SXT	SAXOPHONE, TENOR	403557	Good	INSTRUMENT STORE	VITO	\N	TX	1	\N	\N
1528	652	SXT	SAXOPHONE, TENOR	N4200829	Good	INSTRUMENT STORE	SELMER	\N	TX	8	\N	\N
1532	650	SXT	SAXOPHONE, TENOR	310278	Good	INSTRUMENT STORE	AMATI KRASLICE	\N	TX	6	\N	\N
1536	659	SXT	SAXOPHONE, TENOR	13120021	Good	INSTRUMENT STORE	ALLORA	\N	TX	15	\N	\N
1724	9	HNF	HORN, F	619468	Good	INSTRUMENT STORE	HOLTON	H281	HN	2	\N	\N
1727	480	CLB	CLARINET, BASS	Y3717	Good	INSTRUMENT STORE	VITO	\N	BCL	2	\N	\N
1518	640	SXB	SAXOPHONE, BARITONE	1360873	Good	INSTRUMENT STORE	SELMER	\N	BX	1	\N	\N
1540	644	SXB	SAXOPHONE, BARITONE	CF05160	Good	INSTRUMENT STORE	JUPITER	JBS 1000	BX	5	\N	\N
1517	163	TB	TUBA	\N	Good	INSTRUMENT STORE	BOOSEY & HAWKES	Imperial  EEb	T	3	\N	\N
1544	303	TBN	TUBANOS	\N	Good	MS MUSIC	REMO	10 Inch	\N	5	\N	\N
1551	170	AMB	AMPLIFIER, BASS	Z9G3740	Good	MS MUSIC	ROLAND	Cube-120 XL	\N	6	\N	\N
1552	173	AMG	AMPLIFIER, GUITAR	M 1005297	Good	MS MUSIC	FENDER	STAGE 160	\N	8	\N	\N
4165	\N	DMMO	DUMMY 1	DUMMM3	New	INSTRUMENT STORE	DUMMY MAKER	DUMDUM	\N	4	\N	\N
4166	\N	DMMO	DUMMY 1	DUMMM4	New	\N	DUMMY MAKER	\N	\N	5	\N	1072
1559	252	CMY	CYMBALS, HANDHELD 16 INCH	\N	Good	HS MUSIC	SABIAN	SAB SR 16BOL	\N	1	\N	\N
1581	175	AMK	AMPLIFIER, KEYBOARD	OBD#1230164	Good	MS MUSIC	PEAVEY	KB4	\N	10	\N	\N
1583	184	KB	KEYBOARD	TCK 611	Good	HS MUSIC	CASIO	\N	\N	2	\N	\N
1584	256	DJ	DJEMBE	\N	Good	MS MUSIC	CUSTOM	\N	\N	2	\N	\N
1585	258	DJ	DJEMBE	\N	Good	MS MUSIC	CUSTOM	\N	\N	3	\N	\N
1586	260	DJ	DJEMBE	\N	Good	MS MUSIC	CUSTOM	\N	\N	5	\N	\N
1587	255	DJ	DJEMBE	\N	Good	MS MUSIC	CUSTOM	\N	\N	1	\N	\N
1589	14	MTL	METALLOPHONE	\N	Good	\N	ORFF	\N	\N	1	\N	\N
1590	187	KB	KEYBOARD	\N	Good	\N	CASIO	TC-360	\N	23	\N	\N
1591	217	\N	STAND, MUSIC	50052	Good	\N	WENGER	\N	\N	1	\N	\N
1597	176	AMG	AMPLIFIER, GUITAR	S190700059B4P	Good	\N	BUGERA	\N	\N	12	\N	\N
1599	320	BK	BELL KIT	\N	Good	MS MUSIC	PEARL	PK900C	\N	3	\N	\N
1600	177	AMG	AMPLIFIER, GUITAR	B-749002	Good	\N	FENDER	Blue Junior	\N	13	\N	\N
1601	351	GRA	GUITAR, ACOUSTIC	\N	Good	\N	UNKNOWN	\N	\N	32	\N	\N
1604	322	BK	BELL KIT	\N	Good	MS MUSIC	PEARL	PK900C	\N	5	\N	\N
1513	139	TP	TRUMPET, B FLAT	XA08322	Good	INSTRUMENT STORE	JUPITER	\N	TP	50	\N	\N
1515	141	TP	TRUMPET, B FLAT	XA05452	Good	INSTRUMENT STORE	JUPITER	\N	TP	52	\N	\N
1605	319	BK	BELL KIT	\N	Good	MS MUSIC	PEARL	PK900C	\N	2	\N	\N
1607	291	SRM	SNARE, MARCHING	1P-3086	Good	MS MUSIC	YAMAHA	MS 9014	\N	6	\N	\N
1609	620	SXA	SAXOPHONE, ALTO	XF56962	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	51	\N	\N
1612	633	SXA	SAXOPHONE, ALTO	BF54617	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	64	\N	\N
1638	586	SXA	SAXOPHONE, ALTO	AS 1010089	Good	INSTRUMENT STORE	BARRINGTON	\N	AX	21	\N	\N
1655	607	SXA	SAXOPHONE, ALTO	XF54539	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	38	\N	\N
1658	609	SXA	SAXOPHONE, ALTO	XF54577	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	40	\N	\N
1615	225	TDR	TALKING DRUM	\N	Good	MS MUSIC	REMO	Small	\N	1	\N	\N
1616	212	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	12	\N	\N
1617	178	AMG	AMPLIFIER, GUITAR	LCB500-A126704	Good	\N	FISHMAN	494-000-582	\N	14	\N	\N
1619	286	SR	SNARE	\N	Good	UPPER ES MUSIC	PEARL	\N	\N	2	\N	\N
1620	181	MX	MIXER	BGXL01101	Good	MS MUSIC	YAMAHA	MG12XU	\N	15	\N	\N
1622	347	GRB	GUITAR, BASS	15020198	Good	HS MUSIC	SQUIER	Modified Jaguar	\N	4	\N	\N
1623	240	\N	CRADLE, CONCERT CYMBAL	\N	Good	HS MUSIC	GIBRALTAR	GIB-7614	\N	1	\N	\N
1631	381	GRE	GUITAR, ELECTRIC	15029891	Good	HS MUSIC	SQUIER	StratPkHSSCAR	\N	1	\N	\N
1686	577	SXA	SAXOPHONE, ALTO	11120110	Good	INSTRUMENT STORE	ETUDE	\N	AX	12	\N	\N
1688	590	SXA	SAXOPHONE, ALTO	11110696	Good	INSTRUMENT STORE	ETUDE	\N	AX	25	\N	\N
1693	591	SXA	SAXOPHONE, ALTO	91145	Good	INSTRUMENT STORE	CONSERVETE	\N	AX	26	\N	\N
1624	54	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	KAIZER	\N	PTB	22	\N	\N
1625	55	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	KAIZER	\N	PTB	23	\N	\N
1626	63	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	31	\N	\N
1627	65	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	33	\N	\N
1628	67	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	35	\N	\N
1664	314	BL	BELL SET	\N	Good	INSTRUMENT STORE	UNKNOWN	\N	\N	3	\N	\N
1629	69	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	37	\N	\N
1675	352	GRA	GUITAR, ACOUSTIC	00Y224811	Good	\N	YAMAHA	F 325	\N	19	\N	\N
1676	353	GRA	GUITAR, ACOUSTIC	00Y224884	Good	\N	YAMAHA	F 325	\N	20	\N	\N
1630	70	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	38	\N	\N
1634	71	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	39	\N	\N
1635	72	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	40	\N	\N
1637	73	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	41	\N	\N
1682	59	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	KAIZER	\N	PTB	27	\N	\N
1683	354	GRA	GUITAR, ACOUSTIC	00Y145219	Good	\N	YAMAHA	F 325	\N	22	\N	\N
1690	245	CG	CONGA	\N	Good	HS MUSIC	YAMAHA	\N	\N	24	\N	\N
1691	246	CG	CONGA	\N	Good	HS MUSIC	YAMAHA	\N	\N	25	\N	\N
1666	201	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	1	\N	\N
1685	60	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	KAIZER	\N	PTB	28	\N	\N
1689	61	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	29	\N	\N
1695	44	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	TROMBA	Pro	PTB	12	\N	\N
1697	221	PD	PRACTICE PAD	ISK NO.26	Good	UPPER ES MUSIC	YAMAHA	4 INCH	\N	1	\N	\N
1707	355	GRA	GUITAR, ACOUSTIC	00Y224899	Good	HS MUSIC	YAMAHA	F 325	\N	23	\N	\N
1708	356	GRA	GUITAR, ACOUSTIC	00Y224741	Good	HS MUSIC	YAMAHA	F 325	\N	24	\N	\N
1709	194	PE	PIANO, ELECTRIC	BCAZ01088	Good	LOWER ES MUSIC	YAMAHA	CLP 7358	\N	9	\N	\N
1711	281	PD	PRACTICE PAD	\N	Good	UPPER ES MUSIC	YAMAHA	4 INCH	\N	2	\N	\N
1717	375	GRC	GUITAR, CLASSICAL	\N	Good	MS MUSIC	YAMAHA	40	\N	27	\N	\N
1684	655	SXT	SAXOPHONE, TENOR	420486	Good	INSTRUMENT STORE	VITO	\N	TX	11	\N	\N
1516	142	TP	TRUMPET, B FLAT	XA06111	Good	INSTRUMENT STORE	JUPITER	\N	TP	53	\N	\N
2129	\N	DMMO	DUMMY 1	\N	Good	\N	DUMMY MAKER	DUMMY MODEL	\N	1	\N	1074
1994	602	SXA	SAXOPHONE, ALTO	XF54322	Good	\N	JUPITER	JAS 710	AX	33	Noah Ochomo	1071
2058	593	SXA	SAXOPHONE, ALTO	XF54181	Good	\N	JUPITER	JAS 710	AX	28	Romilly Haysmith	937
1906	651	SXT	SAXOPHONE, TENOR	10355	Good	\N	YAMAHA	\N	TX	7	Noah Ochomo	1071
1744	658	SXT	SAXOPHONE, TENOR	13120005	Good	\N	ALLORA	\N	TX	14	Ochieng Simbiri	300
2054	661	SXT	SAXOPHONE, TENOR	XF03739	Good	\N	JUPITER	\N	TX	17	Rohan Giri	454
2087	162	TB	TUBA	533558	Good	MS MUSIC	YAMAHA	\N	T	2	\N	\N
1752	208	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	8	\N	\N
1732	372	GRC	GUITAR, CLASSICAL	\N	Good	MS MUSIC	PARADISE	18	\N	18	\N	\N
2090	195	PE	PIANO, ELECTRIC	BCZZ01016	Good	UPPER ES MUSIC	YAMAHA	CLP-645B	\N	7	\N	\N
2091	188	PE	PIANO, ELECTRIC	GBRCKK 01021	Good	THEATRE/FOYER	YAMAHA	CVP 303	\N	1	\N	\N
2079	192	PE	PIANO, ELECTRIC	YCQN01006	Good	HS MUSIC	YAMAHA	CAP 329	\N	5	\N	\N
2081	193	PE	PIANO, ELECTRIC	EBQN02222	Good	HS MUSIC	YAMAHA	P-95	\N	6	\N	\N
2082	262	DK	DRUMSET	\N	Good	HS MUSIC	YAMAHA	\N	\N	1	\N	\N
2083	239	BLC	BELLS, CONCERT	112158	Good	HS MUSIC	YAMAHA	YG-250D Standard	\N	1	\N	\N
2085	289	SR	SNARE	\N	Good	HS MUSIC	YAMAHA	\N	\N	27	\N	\N
2086	290	SR	SNARE	\N	Good	HS MUSIC	YAMAHA	\N	\N	28	\N	\N
1667	213	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	13	\N	\N
1519	151	TP	TRUMPET, B FLAT	BA09236	Good	INSTRUMENT STORE	JUPITER	\N	TP	62	\N	\N
1520	152	TP	TRUMPET, B FLAT	BA08359	Good	INSTRUMENT STORE	JUPITER	\N	TP	63	\N	\N
1521	154	TP	TRUMPET, B FLAT	BA09193	Good	INSTRUMENT STORE	JUPITER	\N	TP	65	\N	\N
1522	155	TP	TRUMPET, B FLAT	CA15052	Good	INSTRUMENT STORE	JUPITER	JTR 700	TP	66	\N	\N
1523	156	TP	TRUMPET, B FLAT	CA16033	Good	INSTRUMENT STORE	JUPITER	JTR 700	TP	67	\N	\N
1524	157	TP	TRUMPET, B FLAT	CAS15546	Good	INSTRUMENT STORE	JUPITER	JTR 700	TP	68	\N	\N
1525	158	TP	TRUMPET, B FLAT	CAS16006	Good	INSTRUMENT STORE	JUPITER	JTR 700	TP	69	\N	\N
1529	500	FL	FLUTE	K96337	Good	INSTRUMENT STORE	GEMEINHARDT	2SP	FL	12	\N	\N
1535	423	CL	CLARINET, B FLAT	282570	Good	INSTRUMENT STORE	VITO	\N	CL	15	\N	\N
1537	424	CL	CLARINET, B FLAT	206244	Good	INSTRUMENT STORE	AMATI KRASLICE	\N	CL	16	\N	\N
1538	508	FL	FLUTE	2SP-K96103	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	16	\N	\N
1539	4	BH	BARITONE/EUPHONIUM	987998	Good	INSTRUMENT STORE	KING	\N	BH	5	\N	\N
1541	541	FL	FLUTE	XD59821	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	46	\N	\N
1542	542	FL	FLUTE	XD59741	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	47	\N	\N
1543	561	FL	FLUTE	DD58003	Good	INSTRUMENT STORE	JUPITER	JFL 700	FL	67	\N	\N
1545	84	TP	TRUMPET, B FLAT	H31816	Good	INSTRUMENT STORE	BLESSING	\N	TP	4	\N	\N
1546	147	TP	TRUMPET, B FLAT	XA14523	Good	INSTRUMENT STORE	JUPITER	\N	TP	58	\N	\N
1547	85	TP	TRUMPET, B FLAT	831664	Good	INSTRUMENT STORE	JUPITER	\N	TP	5	\N	\N
1553	537	FL	FLUTE	WD62143	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	42	\N	\N
1554	451	CL	CLARINET, B FLAT	1312128	Good	INSTRUMENT STORE	ALLORA	\N	CL	43	\N	\N
1556	452	CL	CLARINET, B FLAT	1312139	Good	INSTRUMENT STORE	ALLORA	\N	CL	44	\N	\N
1557	539	FL	FLUTE	XD59192	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	44	\N	\N
1558	453	CL	CLARINET, B FLAT	KE54780	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	45	\N	\N
1608	526	FL	FLUTE	D1206521	Good	INSTRUMENT STORE	ETUDE	\N	FL	31	\N	\N
1610	460	CL	CLARINET, B FLAT	XE54946	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	52	\N	\N
1611	558	FL	FLUTE	DD57954	Good	INSTRUMENT STORE	JUPITER	JFL 700	FL	64	\N	\N
1613	559	FL	FLUTE	DD58158	Good	INSTRUMENT STORE	JUPITER	JFL 700	FL	65	\N	\N
1614	474	CL	CLARINET, B FLAT	BE63671	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	66	\N	\N
1633	504	FL	FLUTE	2SP-K90658	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	14	\N	\N
1636	520	FL	FLUTE	28411029	Good	INSTRUMENT STORE	PRELUDE	711	FL	25	\N	\N
1657	448	CL	CLARINET, B FLAT	1209179	Good	INSTRUMENT STORE	ETUDE	\N	CL	40	\N	\N
1659	449	CL	CLARINET, B FLAT	1209180	Good	INSTRUMENT STORE	ETUDE	\N	CL	41	\N	\N
1660	450	CL	CLARINET, B FLAT	1209177	Good	INSTRUMENT STORE	ETUDE	\N	CL	42	\N	\N
1661	544	FL	FLUTE	XD59774	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	49	\N	\N
1662	545	FL	FLUTE	XD59164	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	50	\N	\N
1663	459	CL	CLARINET, B FLAT	KE54774	Good	INSTRUMENT STORE	JUPITER	JCL710	CL	51	\N	\N
1665	487	FL	FLUTE	T479	Good	INSTRUMENT STORE	HEIMAR	\N	FL	4	\N	\N
1677	148	TP	TRUMPET, B FLAT	XA14343	Good	INSTRUMENT STORE	JUPITER	\N	TP	59	\N	\N
1678	149	TP	TRUMPET, B FLAT	XA033335	Good	INSTRUMENT STORE	JUPITER	\N	TP	60	\N	\N
1679	150	TP	TRUMPET, B FLAT	BA09439	Good	INSTRUMENT STORE	JUPITER	\N	TP	61	\N	\N
1680	418	CL	CLARINET, B FLAT	30614E	Good	INSTRUMENT STORE	SIGNET	\N	CL	10	\N	\N
1681	419	CL	CLARINET, B FLAT	B59862	Good	INSTRUMENT STORE	VITO	\N	CL	11	\N	\N
1692	521	FL	FLUTE	K98973	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	26	\N	\N
1694	522	FL	FLUTE	P11876	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	27	\N	\N
1696	436	CL	CLARINET, B FLAT	11299279	Good	INSTRUMENT STORE	ETUDE	\N	CL	28	\N	\N
1719	523	FL	FLUTE	K98879	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	28	\N	\N
1720	437	CL	CLARINET, B FLAT	11299280	Good	INSTRUMENT STORE	ETUDE	\N	CL	29	\N	\N
1721	524	FL	FLUTE	K99078	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	29	\N	\N
1618	374	GRC	GUITAR, CLASSICAL	\N	Good	INSTRUMENT STORE	PARADISE	20	\N	20	\N	\N
1712	598	SXA	SAXOPHONE, ALTO	XF54370	Good	\N	JUPITER	JAS 710	AX	31	Emilie Wittmann	659
1722	438	CL	CLARINET, B FLAT	11299277	Good	INSTRUMENT STORE	ETUDE	\N	CL	30	\N	\N
1729	563	OB	OBOE	B33402	Good	INSTRUMENT STORE	BUNDY	\N	OB	2	\N	\N
1730	565	PC	PICCOLO	12111016	Good	INSTRUMENT STORE	BUNDY	\N	PC	2	\N	\N
1508	118	TP	TRUMPET, B FLAT	H35268	Good	INSTRUMENT STORE	BLESSING	\N	TP	36	\N	\N
1509	135	TP	TRUMPET, B FLAT	XA08649	Good	INSTRUMENT STORE	JUPITER	\N	TP	46	\N	\N
1510	136	TP	TRUMPET, B FLAT	XA08643	Good	INSTRUMENT STORE	JUPITER	\N	TP	47	\N	\N
2084	515	FL	FLUTE	917792	Good	MS MUSIC	YAMAHA	\N	FL	20	\N	\N
2063	93	TP	TRUMPET, B FLAT	553853	Good	\N	YAMAHA	YTR 2335	TP	13	Natéa Firzé Al Ghaoui	541
1989	109	TP	TRUMPET, B FLAT	G27536	Good	\N	BLESSING	\N	TP	29	Noah Ochomo	1071
1999	454	CL	CLARINET, B FLAT	KE56526	Good	\N	JUPITER	JCL710	CL	46	Noah Ochomo	1071
1880	555	FL	FLUTE	BD62784	Good	\N	JUPITER	JEL 710	FL	61	Nora Saleem	931
1848	455	CL	CLARINET, B FLAT	KE56579	Good	\N	JUPITER	JCL710	CL	47	Owen Harris	115
1595	516	FL	FLUTE	J94358	Good	INSTRUMENT STORE	GEMEINHARDT	2SP	FL	21	\N	\N
1700	130	TP	TRUMPET, B FLAT	35272	Good	\N	BLESSING	\N	TP	42	Ainsley Hire	959
1699	128	TP	TRUMPET, B FLAT	34928	Good	\N	BLESSING	\N	TP	41	Ansh Mehta	482
1718	426	CL	CLARINET, B FLAT	25247	Good	\N	YAMAHA	\N	CL	18	Balazs Meyers	976
1704	547	FL	FLUTE	YD66330	Good	\N	JUPITER	JEL 710	FL	53	Eliana Hodge	945
1702	145	TP	TRUMPET, B FLAT	XA04094	Good	\N	JUPITER	\N	TP	56	Etienne Carlevato	980
1716	82	TP	TRUMPET, B FLAT	G29437	Good	\N	BLESSING	\N	TP	2	Fatima Zucca	539
1594	494	FL	FLUTE	G15104	Good	\N	GEMEINHARDT	2SP	FL	9	Margaret Oganda	1078
1674	68	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	\N	PBONE	\N	PTB	36	Arhum Bid	240
1687	656	SXT	SAXOPHONE, TENOR	TS10050027	Good	INSTRUMENT STORE	BUNDY	\N	TX	12	\N	\N
1566	11	HNF	HORN, F	XC07411	Good	INSTRUMENT STORE	JUPITER	JHR700	HN	4	\N	\N
1705	648	SXT	SAXOPHONE, TENOR	26286	Good	\N	YAMAHA	\N	TX	4	\N	\N
1701	663	SXT	SAXOPHONE, TENOR	AF04276	Good	\N	JUPITER	\N	TX	19	Ean Kimuli	962
1872	10	HNF	HORN, F	602	Good	\N	HOLTON	\N	HN	3	Jamison Line	172
1800	479	CLB	CLARINET, BASS	18250	Good	INSTRUMENT STORE	VITO	\N	BCL	1	\N	\N
1806	483	CLB	CLARINET, BASS	CE69047	Good	\N	JUPITER	JBC 1000	BCL	5	Mikael Eshetu	935
1606	321	BK	BELL KIT	\N	Good	\N	PEARL	PK900C	\N	4	Mahori	\N
1596	496	FL	FLUTE	2SP-L89133	Good	\N	GEMEINHARDT	\N	FL	10	Zoe Mcdowell	\N
1842	642	SXB	SAXOPHONE, BARITONE	XF05936	Good	PIANO ROOM	JUPITER	JBS 1000	BX	3	\N	\N
1788	641	SXB	SAXOPHONE, BARITONE	B15217	Good	\N	VIENNA	\N	BX	2	Fatuma Tall	301
1814	38	TNAP	TROMBONE, ALTO - PLASTIC	BM18030151	Good	INSTRUMENT STORE	PBONE	Mini	PTB	6	\N	\N
1750	40	TNAP	TROMBONE, ALTO - PLASTIC	BM17120387	Good	INSTRUMENT STORE	PBONE	Mini	PTB	8	\N	\N
1565	350	VCL	CELLO, (VIOLONCELLO)	\N	Good	\N	WENZER KOHLER	\N	C	2	Mark Anding	1076
1795	7	BT	BARITONE/TENOR HORN	575586	Good	INSTRUMENT STORE	BESSON	\N	BH	1	\N	\N
1797	160	TPP	TRUMPET, POCKET	PT1309020	Good	INSTRUMENT STORE	ALLORA	\N	TPP	1	\N	\N
1598	90	TP	TRUMPET, B FLAT	F24090	Good	\N	BLESSING	\N	TP	10	Gakenia Mucharie	1075
1714	463	CL	CLARINET, B FLAT	XE54729	Good	\N	JUPITER	JCL710	CL	55	Lauren Mucci	981
1698	477	CL	CLARINET, B FLAT	BE63692	Good	\N	JUPITER	JCL710	CL	69	Olivia Patel	601
1592	572	SXA	SAXOPHONE, ALTO	200585	Good	\N	GIARDINELLI	\N	AX	7	Gwendolyn Anding	1077
1710	619	SXA	SAXOPHONE, ALTO	XF56406	Good	\N	JUPITER	JAS 710	AX	50	Luke O'Hara	481
2046	625	SXA	SAXOPHONE, ALTO	AF53425	Good	\N	JUPITER	JAS 710	AX	56	Milan Jayaram	967
1713	632	SXA	SAXOPHONE, ALTO	BF54335	Good	\N	JUPITER	JAS 710	AX	63	Tawheed Hussain	177
1703	604	SXA	SAXOPHONE, ALTO	XF54451	Good	\N	JUPITER	JAS 710	AX	35	Uzima Otieno	911
1706	47	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	\N	TROMBA	Pro	PTB	15	Kianu Ruiz Stannah	276
1593	8	HNF	HORN, F	619528	Good	\N	HOLTON	H281	HN	1	Gwendolyn Anding	1077
1603	349	VCL	CELLO, (VIOLONCELLO)	100725	Good	\N	CREMONA	\N	C	1	Gwendolyn Anding	1077
1621	383	GRE	GUITAR, ELECTRIC	116108513	Good	\N	FENDER	CD-60CE Mahogany	\N	30	Gakenia Mucharie	1075
1715	346	GRB	GUITAR, BASS	ICS10191321	Good	\N	FENDER	Squire	\N	3	Isla Willis	925
2057	606	SXA	SAXOPHONE, ALTO	XF54452	Good	\N	JUPITER	JAS 710	AX	37	Tanay Cherickel	974
1905	111	TP	TRUMPET, B FLAT	645447	Good	INSTRUMENT STORE	YAMAHA	YTR 2335	TP	31	\N	\N
1754	5	BH	BARITONE/EUPHONIUM	533835	Good	\N	YAMAHA	\N	BH	6	Saqer Alnaqbi	942
2044	543	FL	FLUTE	XD59816	Good	\N	JUPITER	JEL 710	FL	48	Teagan Wood	159
2050	535	FL	FLUTE	WD62108	Good	\N	JUPITER	JEL 710	FL	40	Yoonseo Choi	953
1740	427	CL	CLARINET, B FLAT	J65020	Good	\N	YAMAHA	\N	CL	19	Zayn Khalid	975
1844	605	SXA	SAXOPHONE, ALTO	XF53797	Good	\N	JUPITER	JAS 710	AX	36	Thomas Higgins	342
1819	608	SXA	SAXOPHONE, ALTO	XF54476	Good	\N	JUPITER	JAS 710	AX	39	Tobias Godfrey	179
2097	43	TNTP	TROMBONE, TENOR - PLASTIC	PB17070488	Good	\N	TROMBA	Pro	PTB	11	Titu Tulga	788
1990	666	SXT	SAXOPHONE, TENOR	CF07965	Good	\N	JUPITER	JTS700	TX	22	Tawheed Hussain	177
2043	23	TN	TROMBONE, TENOR	303168	Good	\N	YAMAHA	\N	TB	9	Zameer Nanji	257
1757	433	CL	CLARINET, B FLAT	405117	Good	INSTRUMENT STORE	YAMAHA	\N	CL	25	\N	\N
1876	313	BL	BELL SET	\N	Good	\N	UNKNOWN	\N	\N	2	Selma Mensah	958
1908	363	GRC	GUITAR, CLASSICAL	HKZ104831	Good	MS MUSIC	YAMAHA	40	\N	7	\N	\N
1738	467	CL	CLARINET, B FLAT	XE54680	Good	\N	JUPITER	JCL710	CL	59	Aisha Awori	960
1902	456	CL	CLARINET, B FLAT	KE56608	Good	\N	JUPITER	JCL710	CL	48	Ariel Mutombo	948
1901	1	BH	BARITONE/EUPHONIUM	601249	Good	\N	BOOSEY & HAWKES	Soveriegn	BH	2	Kasra Feizzadeh	135
2101	101	TP	TRUMPET, B FLAT	H35502	Good	\N	BLESSING	\N	TP	21	Kiara Materne	934
1900	464	CL	CLARINET, B FLAT	XE54692	Good	\N	JUPITER	JCL710	CL	56	Lilla Vestergaard	928
2102	103	TP	TRUMPET, B FLAT	H35099	Good	\N	BLESSING	\N	TP	23	Mikael Eshetu	935
1533	546	FL	FLUTE	XD60579	Good	\N	JUPITER	JEL 710	FL	51	Nellie Odera	1081
1918	458	CL	CLARINET, B FLAT	KE54751	Good	\N	JUPITER	JCL710	CL	50	Seung Hyun Nam	973
2099	457	CL	CLARINET, B FLAT	KE54676	Good	\N	JUPITER	JCL710	CL	49	Theodore Wright	1070
1894	596	SXA	SAXOPHONE, ALTO	XF54480	Good	\N	JUPITER	JAS 710	AX	30	Margaret Oganda	1078
1899	628	SXA	SAXOPHONE, ALTO	AF53348	Good	\N	JUPITER	JAS 710	AX	59	Reuben Szuchman	848
1915	621	SXA	SAXOPHONE, ALTO	YF57348	Good	\N	JUPITER	JAS 710	AX	52	Mark Anding	1076
1923	617	SXA	SAXOPHONE, ALTO	XF56283	Good	\N	JUPITER	JAS 710	AX	48	Vanaaya Patel	304
1924	616	SXA	SAXOPHONE, ALTO	XF57296	Good	\N	JUPITER	JAS 710	AX	47	Yonatan Wondim Belachew Andersen	952
2100	594	SXA	SAXOPHONE, ALTO	XF54576	Good	\N	JUPITER	JAS 710	AX	29	Stefanie Landolt	239
1531	623	SXA	SAXOPHONE, ALTO	YF57320	Good	\N	JUPITER	JAS 710	AX	54	Nirvi Joymungul	984
1550	624	SXA	SAXOPHONE, ALTO	XF54149	Good	\N	JUPITER	JAS 710	AX	55	Gakenia Mucharie	1075
1895	384	GRE	GUITAR, ELECTRIC	116108578	Good	\N	FENDER	CD-60CE Mahogany	\N	31	Angel Gray	\N
1561	567	SXA	SAXOPHONE, ALTO	11120072	Good	INSTRUMENT STORE	ETUDE	\N	AX	2	\N	\N
1562	646	SXT	SAXOPHONE, TENOR	227671	Good	INSTRUMENT STORE	BUSCHER	\N	TX	2	\N	\N
1564	389	GRT	GUITAR, HALF	10	Good	\N	KAY	\N	\N	5	\N	\N
1567	285	SR	SNARE	6276793	Good	MS MUSIC	LUDWIG	\N	\N	1	\N	\N
1568	295	TML	TIMBALI	3112778	Good	MS MUSIC	LUDWIG	\N	\N	1	\N	\N
1569	257	DJ	DJEMBE	\N	Good	MS MUSIC	CUSTOM	\N	\N	7	\N	\N
1571	275	SRM	SNARE, MARCHING	1P-3099	Good	MS MUSIC	YAMAHA	MS 9014	\N	2	\N	\N
1572	278	SRM	SNARE, MARCHING	1P-3076	Good	MS MUSIC	YAMAHA	MS 9014	\N	5	\N	\N
1574	288	SR	SNARE	NIL	Good	INSTRUMENT STORE	YAMAHA	\N	\N	26	\N	\N
1560	143	TP	TRUMPET, B FLAT	XA02614	Good	INSTRUMENT STORE	JUPITER	\N	TP	54	\N	\N
1563	153	TP	TRUMPET, B FLAT	BA09444	Good	INSTRUMENT STORE	JUPITER	\N	TP	64	\N	\N
1573	3	BH	BARITONE/EUPHONIUM	839431	Good	\N	AMATI KRASLICE	\N	BH	4	\N	\N
1575	510	FL	FLUTE	K98713	Good	INSTRUMENT STORE	GEMEINHARDT	2SP	FL	17	\N	\N
1576	512	FL	FLUTE	2SP-K99109	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	18	\N	\N
1577	514	FL	FLUTE	P11203	Good	INSTRUMENT STORE	GEMEINHARDT	2SP	FL	19	\N	\N
1640	587	SXA	SAXOPHONE, ALTO	11110740	Good	INSTRUMENT STORE	ETUDE	\N	AX	22	\N	\N
1641	386	GRT	GUITAR, HALF	7	Good	\N	KAY	\N	\N	2	\N	\N
1644	600	SXA	SAXOPHONE, ALTO	XF54574	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	32	\N	\N
1648	603	SXA	SAXOPHONE, ALTO	XF54336	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	34	\N	\N
1650	581	SXA	SAXOPHONE, ALTO	362477A	Good	INSTRUMENT STORE	YAMAHA	\N	AX	16	\N	\N
1646	74	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	INSTRUMENT STORE	PBONE	\N	PTB	42	\N	\N
1649	42	TNTP	TROMBONE, TENOR - PLASTIC	PB17070395	Good	\N	TROMBA	Pro	PTB	10	\N	\N
1639	517	FL	FLUTE	28411021	Good	INSTRUMENT STORE	PRELUDE	\N	FL	22	\N	\N
1642	439	CL	CLARINET, B FLAT	11299276	Good	INSTRUMENT STORE	ETUDE	\N	CL	31	\N	\N
1643	527	FL	FLUTE	D1206485	Good	INSTRUMENT STORE	ETUDE	\N	FL	32	\N	\N
1645	528	FL	FLUTE	D1206556	Good	INSTRUMENT STORE	ETUDE	\N	FL	33	\N	\N
1647	529	FL	FLUTE	206295	Good	INSTRUMENT STORE	ETUDE	\N	FL	34	\N	\N
1651	116	TP	TRUMPET, B FLAT	756323	Good	INSTRUMENT STORE	YAMAHA	\N	TP	35	\N	\N
1652	530	FL	FLUTE	206261	Good	INSTRUMENT STORE	ETUDE	\N	FL	35	\N	\N
1653	531	FL	FLUTE	K96124	Good	INSTRUMENT STORE	GEMEINHARDT	\N	FL	36	\N	\N
1654	533	FL	FLUTE	WD57818	Good	INSTRUMENT STORE	JUPITER	JEL 710	FL	38	\N	\N
1656	447	CL	CLARINET, B FLAT	1209178	Good	INSTRUMENT STORE	ETUDE	\N	CL	39	\N	\N
2053	114	TP	TRUMPET, B FLAT	511564	Good	\N	YAMAHA	\N	TP	34	Aiden D'Souza	944
2047	132	TP	TRUMPET, B FLAT	WA26516	Good	\N	JUPITER	\N	TP	43	Anaiya Khubchandani	947
2045	473	CL	CLARINET, B FLAT	YE67756	Good	\N	JUPITER	JCL710	CL	65	Gaia Bonde-Nielsen	940
1970	92	TP	TRUMPET, B FLAT	678970	Good	\N	YAMAHA	YTR 2335	TP	12	Ignacio Biafore	936
2051	536	FL	FLUTE	WD62303	Good	\N	JUPITER	JEL 710	FL	41	Julian Dibling	939
2006	144	TP	TRUMPET, B FLAT	488350	Good	\N	BACH	\N	TP	55	Kaisei Stephens	932
1996	113	TP	TRUMPET, B FLAT	F19277	Good	\N	BLESSING	\N	TP	33	Kush Tanna	941
2049	534	FL	FLUTE	WD62211	Good	\N	JUPITER	JEL 710	FL	39	Leo Cutler	267
1995	100	TP	TRUMPET, B FLAT	H31438	Good	\N	BLESSING	\N	TP	20	Maria Agenorwot	847
1997	538	FL	FLUTE	WD62183	Good	\N	JUPITER	JEL 710	FL	43	Mark Anding	1076
1983	57	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	\N	KAIZER	\N	PTB	25	Mark Anding	1076
1991	664	SXT	SAXOPHONE, TENOR	CF07952	Good	\N	JUPITER	JTS700	TX	20	Mark Anding	1076
2042	654	SXT	SAXOPHONE, TENOR	063739A	Good	\N	YAMAHA	\N	TX	10	Finlay Haswell	951
2048	662	SXT	SAXOPHONE, TENOR	YF06601	Good	\N	JUPITER	JTS710	TX	18	Gunnar Purdy	27
2052	660	SXT	SAXOPHONE, TENOR	3847	Good	\N	JUPITER	\N	TX	16	Adam Kone	755
2031	26	TN	TROMBONE, TENOR	406896	Good	\N	YAMAHA	\N	TB	12	Marco De Vries Aguirre	502
2041	18	TN	TROMBONE, TENOR	406948	Good	\N	YAMAHA	\N	TB	4	Arhum Bid	240
2028	482	CLB	CLARINET, BASS	YE 69248	Good	\N	YAMAHA	Hex 1000	BCL	4	Gwendolyn Anding	1077
1632	396	VN	VIOLIN	J052107087	Good	HS MUSIC	HOFNER	\N	\N	1	\N	\N
2072	445	CL	CLARINET, B FLAT	J65342	Good	INSTRUMENT STORE	YAMAHA	\N	CL	37	\N	\N
2067	88	TP	TRUMPET, B FLAT	806725	Good	\N	YAMAHA	YTR 2335	TP	8	Arjan Arora	360
2093	83	TP	TRUMPET, B FLAT	533719	Good	\N	YAMAHA	\N	TP	3	Evan Daines	954
2088	230	BD	BASS DRUM	PO-1575	Good	MS MUSIC	YAMAHA	CB628	\N	2	\N	\N
2095	86	TP	TRUMPET, B FLAT	556107	Good	\N	YAMAHA	YTR 2335	TP	6	Holly Mcmurtry	955
2094	440	CL	CLARINET, B FLAT	J65438	Good	\N	YAMAHA	\N	CL	32	Io Verstraete	792
2092	435	CL	CLARINET, B FLAT	074011A	Good	\N	YAMAHA	\N	CL	27	Leo Prawitz	511
2113	618	SXA	SAXOPHONE, ALTO	XF56319	Good	\N	JUPITER	JAS 710	AX	49	Barney Carver Wildig	612
2114	461	CL	CLARINET, B FLAT	XE54957	Good	\N	JUPITER	JCL710	CL	53	Mahdiyah Muneeb	977
1731	371	GRC	GUITAR, CLASSICAL	\N	Good	INSTRUMENT STORE	PARADISE	17	\N	17	\N	\N
1751	283	BLS	BELLS, SLEIGH	\N	Good	HS MUSIC	WEISS	\N	\N	1	\N	\N
2071	430	CL	CLARINET, B FLAT	J07292	Good	\N	YAMAHA	\N	CL	22	Kevin Keene	\N
2117	540	FL	FLUTE	XD58187	Good	\N	JUPITER	JEL 710	FL	45	Saptha Girish Bommadevara	332
2116	2	BH	BARITONE/EUPHONIUM	770765	Good	\N	BESSON	Soveriegn 968	BH	3	Saqer Alnaqbi	942
2115	548	FL	FLUTE	YD66080	Good	\N	JUPITER	JEL 710	FL	54	Seya Chandaria	926
2118	570	SXA	SAXOPHONE, ALTO	11110173	Good	\N	ETUDE	\N	AX	5	Lukas Norman	419
2121	649	SXT	SAXOPHONE, TENOR	31870	Good	\N	YAMAHA	\N	TX	5	Spencer Schenck	924
2122	21	TN	TROMBONE, TENOR	325472	Good	\N	YAMAHA	\N	TB	7	Maartje Stott	114
2074	16	TN	TROMBONE, TENOR	406538	Good	\N	YAMAHA	\N	TB	2	Anne Bamlango	359
2119	643	SXB	SAXOPHONE, BARITONE	AF03351	Good	\N	JUPITER	JBS 1000	BX	4	Lukas Norman	419
2068	196	PE	PIANO, ELECTRIC	\N	Good	DANCE STUDIO	YAMAHA	\N	\N	8	\N	\N
2069	185	KB	KEYBOARD	913094	Good	\N	YAMAHA	PSR 220	\N	21	\N	\N
2070	186	KB	KEYBOARD	13143	Good	\N	YAMAHA	PSR 83	\N	22	\N	\N
2077	345	GRB	GUITAR, BASS	\N	Good	MS MUSIC	YAMAHA	BB1000	\N	2	\N	\N
2078	219	\N	PEDAL, SUSTAIN	\N	Good	HS MUSIC	YAMAHA	FC4	\N	7	\N	\N
2080	316	BL	BELL SET	\N	Good	HS MUSIC	YAMAHA	\N	\N	5	\N	\N
2089	377	GRC	GUITAR, CLASSICAL	\N	Good	\N	YAMAHA	40	\N	29	Keeara Walji	\N
2075	365	GRC	GUITAR, CLASSICAL	HKP064005	Good	\N	YAMAHA	40	\N	9	Finola Doherty	\N
2076	367	GRC	GUITAR, CLASSICAL	HKP054553	Good	\N	YAMAHA	40	\N	11	Marwa Baker	\N
1898	91	TP	TRUMPET, B FLAT	554189	Good	INSTRUMENT STORE	YAMAHA	YTR 2335	TP	11	\N	\N
1907	161	TB	TUBA	106508	Good	MS MUSIC	YAMAHA	\N	T	1	\N	\N
2062	265	DK	DRUMSET	SBB2217	Good	HS MUSIC	YAMAHA	\N	\N	4	\N	\N
1668	214	\N	HARNESS	\N	Good	MS MUSIC	PEARL	\N	\N	14	\N	\N
1669	425	CL	CLARINET, B FLAT	443788	Good	INSTRUMENT STORE	YAMAHA	\N	CL	17	\N	\N
1672	360	GRC	GUITAR, CLASSICAL	HKP064875	Good	\N	YAMAHA	40	\N	4	Jihong Joo	525
1670	635	SXA	SAXOPHONE, ALTO	CF57209	Good	INSTRUMENT STORE	JUPITER	JAS 710	AX	66	\N	\N
1673	17	TN	TROMBONE, TENOR	336151	Good	INSTRUMENT STORE	YAMAHA	\N	TB	3	\N	\N
1671	364	GRC	GUITAR, CLASSICAL	HKP064163	Good	MS MUSIC	YAMAHA	40	\N	8	\N	\N
2110	551	FL	FLUTE	YD65954	Good	\N	JUPITER	JEL 710	FL	57	Anaiya Shah	356
2111	99	TP	TRUMPET, B FLAT	H35203	Good	\N	BLESSING	BTR 1270	TP	19	Cahir Patel	117
2112	124	TP	TRUMPET, B FLAT	1107571	Good	\N	LIBRETTO	\N	TP	39	Caleb Ross	961
2103	106	TP	TRUMPET, B FLAT	H31450	Good	\N	BLESSING	BIR 1270	TP	26	Saqer Alnaqbi	942
2107	469	CL	CLARINET, B FLAT	YE67254	Good	\N	JUPITER	JCL710	CL	61	Vilma Doret Rosen	59
2106	629	SXA	SAXOPHONE, ALTO	AF53502	Good	\N	JUPITER	JAS 710	AX	60	Noga Hercberg	661
2108	592	SXA	SAXOPHONE, ALTO	XF54339	Good	\N	JUPITER	JAS 710	AX	27	Alexander Roe	36
2104	64	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	\N	PBONE	\N	PTB	32	Seth Lundell	982
2105	66	TNTP	TROMBONE, TENOR - PLASTIC	\N	Good	\N	PBONE	\N	PTB	34	Sadie Szuchman	846
2109	344	GRB	GUITAR, BASS	\N	Good	\N	ARCHER	\N	\N	1	Jana Landolt	302
\.


--
-- TOC entry 3930 (class 0 OID 23612)
-- Dependencies: 216
-- Data for Name: legacy_database; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.legacy_database (id, number, legacy_number, family, equipment, make, model, serial, class, year, full_name, school_storage, return_2023, student_number, code) FROM stdin;
23	2	273	PERCUSSION	QUAD, MARCHING	PEARL	Black	203143	\N	\N	\N	MS MUSIC	\N	\N	Q
60	3	276	PERCUSSION	SNARE, MARCHING	VERVE	White	\N	\N	\N	\N	MS MUSIC	\N	\N	SRM
89	4	277	PERCUSSION	SNARE, MARCHING	VERVE	White	\N	\N	\N	\N	MS MUSIC	\N	\N	SRM
359	15	506	WOODWIND	FLUTE	GEMEINHARDT	2SP	K96338	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
551	43	75	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
342	14	94	BRASS	TRUMPET, B FLAT	BACH	Stradivarius 37L	L306677	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
556	44	76	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
374	17	97	BRASS	TRUMPET, B FLAT	CONN	\N	S-756323	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
383	18	98	BRASS	TRUMPET, B FLAT	BLESSING	BTR 1270	H35537	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
414	22	102	BRASS	TRUMPET, B FLAT	BLESSING	BIR 1270	H34929	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
430	24	104	BRASS	TRUMPET, B FLAT	BLESSING	BIR 1270	H32053	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
437	25	105	BRASS	TRUMPET, B FLAT	BLESSING	BIR 1270	H31491	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
458	28	108	BRASS	TRUMPET, B FLAT	BLESSING	\N	F24304	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
561	45	77	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
557	44	133	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA07789	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
364	16	48	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
390	19	51	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
510	36	118	BRASS	TRUMPET, B FLAT	BLESSING	\N	H35268	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
567	46	135	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA08649	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
572	47	136	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA08643	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
577	48	137	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA08294	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
581	49	138	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA08319	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
585	50	139	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA08322	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
589	51	140	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA06017	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
593	52	141	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA05452	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
596	53	142	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA06111	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
51	3	163	BRASS	TUBA	BOOSEY & HAWKES	Imperial  EEb	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TB
260	1	640	WOODWIND	SAXOPHONE, BARITONE	SELMER	\N	1360873	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXB
632	62	151	BRASS	TRUMPET, B FLAT	JUPITER	\N	BA09236	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
636	63	152	BRASS	TRUMPET, B FLAT	JUPITER	\N	BA08359	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
644	65	154	BRASS	TRUMPET, B FLAT	JUPITER	\N	BA09193	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
648	66	155	BRASS	TRUMPET, B FLAT	JUPITER	JTR 700	CA15052	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
652	67	156	BRASS	TRUMPET, B FLAT	JUPITER	JTR 700	CA16033	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
656	68	157	BRASS	TRUMPET, B FLAT	JUPITER	JTR 700	CAS15546	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
659	69	158	BRASS	TRUMPET, B FLAT	JUPITER	JTR 700	CAS16006	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
261	1	645	WOODWIND	SAXOPHONE, TENOR	VITO	\N	403557	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
274	8	573	WOODWIND	SAXOPHONE, ALTO	GIARDINELLI	\N	200547	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
275	8	652	WOODWIND	SAXOPHONE, TENOR	SELMER	\N	N4200829	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
323	12	500	WOODWIND	FLUTE	GEMEINHARDT	2SP	K96337	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
91	4	315	PERCUSSION	BELL SET	UNKNOWN	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	BL
603	54	623	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	YF57320	\N	2023/24	Nirvi Joymungul	\N	\N	12997	SXA
156	6	650	WOODWIND	SAXOPHONE, TENOR	AMATI KRASLICE	\N	310278	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
591	51	546	WOODWIND	FLUTE	JUPITER	JEL 710	XD60579	\N	2023	Nellie Odera	\N	\N	\N	FL
105	4	569	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11120109	\N	xx	\N	INSTRUMENT STORE	\N	\N	SXA
358	15	423	WOODWIND	CLARINET, B FLAT	VITO	\N	282570	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
362	15	659	WOODWIND	SAXOPHONE, TENOR	ALLORA	\N	13120021	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
367	16	424	WOODWIND	CLARINET, B FLAT	AMATI KRASLICE	\N	206244	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
368	16	508	WOODWIND	FLUTE	GEMEINHARDT	\N	2SP-K96103	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
108	5	4	BRASS	BARITONE/EUPHONIUM	KING	\N	987998	\N	x	\N	INSTRUMENT STORE	\N	\N	BH
134	5	644	WOODWIND	SAXOPHONE, BARITONE	JUPITER	JBS 1000	CF05160	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXB
569	46	541	WOODWIND	FLUTE	JUPITER	JEL 710	XD59821	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
574	47	542	WOODWIND	FLUTE	JUPITER	JEL 710	XD59741	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
654	67	561	WOODWIND	FLUTE	JUPITER	JFL 700	DD58003	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
120	5	303	PERCUSSION	TUBANOS	REMO	10 Inch	\N	\N	\N	\N	MS MUSIC	\N	\N	TBN
82	4	84	BRASS	TRUMPET, B FLAT	BLESSING	\N	H31816	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
616	58	147	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA14523	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
112	5	85	BRASS	TRUMPET, B FLAT	JUPITER	\N	831664	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
155	6	571	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	12080618	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
49	3	35	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
607	55	624	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54149	HS MUSIC	2023/24	Gakenia Mucharie	\N	\N	\N	SXA
140	6	170	ELECTRIC	AMPLIFIER, BASS	ROLAND	Cube-120 XL	Z9G3740	\N	\N	\N	MS MUSIC	\N	\N	AMB
265	8	173	ELECTRIC	AMPLIFIER, GUITAR	FENDER	STAGE 160	M 1005297	\N	\N	\N	MS MUSIC	\N	\N	AMG
549	42	537	WOODWIND	FLUTE	JUPITER	JEL 710	WD62143	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
553	43	451	WOODWIND	CLARINET, B FLAT	ALLORA	\N	1312128	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
555	43	612	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF56514	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
558	44	452	WOODWIND	CLARINET, B FLAT	ALLORA	\N	1312139	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
559	44	539	WOODWIND	FLUTE	JUPITER	JEL 710	XD59192	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
563	45	453	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	KE54780	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
215	1	252	PERCUSSION	CYMBALS, HANDHELD 16 INCH	SABIAN	SAB SR 16BOL	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CMY
600	54	143	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA02614	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
43	2	567	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11120072	\N	xx	\N	INSTRUMENT STORE	\N	\N	SXA
45	2	646	WOODWIND	SAXOPHONE, TENOR	BUSCHER	\N	227671	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
640	64	153	BRASS	TRUMPET, B FLAT	JUPITER	\N	BA09444	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
127	5	389	STRING	GUITAR, HALF	KAY	\N	10	\N	\N	\N	\N	\N	\N	GRT
33	2	350	STRING	CELLO, (VIOLONCELLO)	WENZER KOHLER	\N	\N	\N	2023/24	Mark Anding	\N	7/6/23	\N	VCL
79	4	11	BRASS	HORN, F	JUPITER	JHR700	XC07411	\N	2023/24	Mark Anding	MS MUSIC	\N	\N	HNF
228	1	285	PERCUSSION	SNARE	LUDWIG	\N	6276793	\N	\N	\N	MS MUSIC	\N	\N	SR
232	1	295	PERCUSSION	TIMBALI	LUDWIG	\N	3112778	\N	\N	\N	MS MUSIC	\N	\N	TML
19	7	257	PERCUSSION	DJEMBE	CUSTOM	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	DJ
365	16	96	BRASS	TRUMPET, B FLAT	SCHILKE	B1L	33911	\N	2023/24	Mark Anding	MS MUSIC	\N	\N	TP
24	2	275	PERCUSSION	SNARE, MARCHING	YAMAHA	MS 9014	1P-3099	\N	\N	\N	MS MUSIC	\N	\N	SRM
119	5	278	PERCUSSION	SNARE, MARCHING	YAMAHA	MS 9014	1P-3076	\N	\N	\N	MS MUSIC	\N	\N	SRM
78	4	3	BRASS	BARITONE/EUPHONIUM	AMATI KRASLICE	\N	839431	\N	x	\N	\N	\N	\N	BH
445	26	288	PERCUSSION	SNARE	YAMAHA	\N	NIL	\N	\N	\N	INSTRUMENT STORE	\N	\N	SR
377	17	510	WOODWIND	FLUTE	GEMEINHARDT	2SP	K98713	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
386	18	512	WOODWIND	FLUTE	GEMEINHARDT	\N	2SP-K99109	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
395	19	514	WOODWIND	FLUTE	GEMEINHARDT	2SP	P11203	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
396	19	584	WOODWIND	SAXOPHONE, ALTO	BARRINGTON	\N	AS1001039	\N	xx	\N	INSTRUMENT STORE	\N	\N	SXA
382	18	50	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	PB17070322	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
75	3	568	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11120090	\N	xx	\N	INSTRUMENT STORE	\N	\N	SXA
292	10	175	ELECTRIC	AMPLIFIER, KEYBOARD	PEAVEY	KB4	OBD#1230164	\N	\N	\N	MS MUSIC	\N	\N	AMK
8	2	180	SOUND	MICROPHONE	SHURE	SM58	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
9	2	184	KEYBOARD	KEYBOARD	CASIO	\N	TCK 611	HS MUSIC	\N	\N	HS MUSIC	\N	\N	KB
18	2	256	PERCUSSION	DJEMBE	CUSTOM	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	DJ
58	3	258	PERCUSSION	DJEMBE	CUSTOM	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	DJ
117	5	260	PERCUSSION	DJEMBE	CUSTOM	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	DJ
218	1	255	PERCUSSION	DJEMBE	CUSTOM	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	DJ
663	70	478	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	BE63657	HS MUSIC	2023/24	Gakenia Mucharie	\N	\N	\N	CL
178	1	14	BRASS	METALLOPHONE	ORFF	\N	\N	\N	\N	\N	\N	\N	\N	MTL
423	23	187	KEYBOARD	KEYBOARD	CASIO	TC-360	\N	\N	\N	\N	\N	\N	\N	KB
194	1	217	MISCELLANEOUS	STAND, MUSIC	WENGER	\N	50052	HS MUSIC	2022/23	\N	\N	\N	\N	\N
173	7	572	WOODWIND	SAXOPHONE, ALTO	GIARDINELLI	\N	200585	HS MUSIC	2021/22	Gwendolyn Anding	\N	\N	\N	SXA
176	1	8	BRASS	HORN, F	HOLTON	H281	619528	HS MUSIC	2023/24	Gwendolyn Anding	\N	\N	\N	HNF
285	9	494	WOODWIND	FLUTE	GEMEINHARDT	2SP	G15104	ES MUSIC	2021/22	Magaret Oganda	\N	\N	\N	FL
410	21	516	WOODWIND	FLUTE	GEMEINHARDT	2SP	J94358	MS Band 8	2022/23	Vera Ballan	\N	7/6/2023	\N	FL
298	10	496	WOODWIND	FLUTE	GEMEINHARDT	\N	2SP-L89133	ms concert band	2021/22	Zoe Mcdowell	\N	\N	\N	FL
318	12	176	ELECTRIC	AMPLIFIER, GUITAR	BUGERA	\N	S190700059B4P	\N	\N	\N	\N	\N	\N	AMG
291	10	90	BRASS	TRUMPET, B FLAT	BLESSING	\N	F24090	HS MUSIC	2023/24	Gakenia Mucharie	\N	\N	\N	TP
65	3	320	PERCUSSION	BELL KIT	PEARL	PK900C	\N	\N	\N	\N	MS MUSIC	\N	\N	BK
330	13	177	ELECTRIC	AMPLIFIER, GUITAR	FENDER	Blue Junior	B-749002	\N	\N	\N	\N	\N	\N	AMG
487	32	351	STRING	GUITAR, ACOUSTIC	UNKNOWN	\N	\N	\N	under repair	\N	\N	\N	\N	GRA
404	20	585	WOODWIND	SAXOPHONE, ALTO	BARRINGTON	\N	AS1003847	\N	xx	\N	INSTRUMENT STORE	\N	\N	SXA
246	1	349	STRING	CELLO, (VIOLONCELLO)	CREMONA	\N	100725	HS MUSIC	2021/22	Gwendolyn Anding	\N	\N	\N	VCL
122	5	322	PERCUSSION	BELL KIT	PEARL	PK900C	\N	\N	\N	\N	MS MUSIC	\N	\N	BK
30	2	319	PERCUSSION	BELL KIT	PEARL	PK900C	\N	\N	\N	\N	MS MUSIC	\N	\N	BK
92	4	321	PERCUSSION	BELL KIT	PEARL	PK900C	\N	\N	2022/23	Mahori	\N	\N	\N	BK
229	6	291	PERCUSSION	SNARE, MARCHING	YAMAHA	MS 9014	1P-3086	\N	\N	\N	MS MUSIC	\N	\N	SRM
482	31	526	WOODWIND	FLUTE	ETUDE	\N	D1206521	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
592	51	620	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF56962	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
594	52	460	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54946	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
642	64	558	WOODWIND	FLUTE	JUPITER	JFL 700	DD57954	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
643	64	633	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	BF54617	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
646	65	559	WOODWIND	FLUTE	JUPITER	JFL 700	DD58158	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
649	66	474	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	BE63671	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
199	1	225	PERCUSSION	TALKING DRUM	REMO	Small	\N	\N	\N	\N	MS MUSIC	\N	\N	TDR
319	12	212	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
343	14	178	ELECTRIC	AMPLIFIER, GUITAR	FISHMAN	494-000-582	LCB500-A126704	\N	\N	\N	\N	\N	\N	AMG
401	20	374	STRING	GUITAR, CLASSICAL	PARADISE	20	\N	\N	yes, no case	Amin Hussein	\N	\N	\N	GRC
25	2	286	PERCUSSION	SNARE	PEARL	\N	\N	\N	\N	\N	UPPER ES MUSIC	\N	\N	SR
354	15	181	SOUND	MIXER	YAMAHA	MG12XU	BGXL01101	\N	\N	\N	MS MUSIC	\N	\N	MX
473	30	383	STRING	GUITAR, ELECTRIC	FENDER	CD-60CE Mahogany	116108513	HS MUSIC	2023/24	Gakenia Mucharie	\N	\N	\N	GRE
97	4	347	STRING	GUITAR, BASS	SQUIER	Modified Jaguar	15020198	HS MUSIC	\N	\N	HS MUSIC	\N	\N	GRB
212	1	240	PERCUSSION	CRADLE, CONCERT CYMBAL	GIBRALTAR	GIB-7614	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
413	22	54	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
421	23	55	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
478	31	63	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
492	33	65	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
503	35	67	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
515	37	69	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
521	38	70	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
248	1	381	STRING	GUITAR, ELECTRIC	SQUIER	StratPkHSSCAR	15029891	HS MUSIC	\N	\N	HS MUSIC	\N	\N	GRE
250	1	396	STRING	VIOLIN	HOFNER	\N	J052107087	HS MUSIC	2023/24	\N	HS MUSIC	\N	\N	VN
347	14	504	WOODWIND	FLUTE	GEMEINHARDT	\N	2SP-K90658	\N	Flute damaged, but still works	\N	INSTRUMENT STORE	\N	\N	FL
527	39	71	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
533	40	72	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
441	25	520	WOODWIND	FLUTE	PRELUDE	711	28411029	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
539	41	73	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
411	21	586	WOODWIND	SAXOPHONE, ALTO	BARRINGTON	\N	AS 1010089	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
418	22	517	WOODWIND	FLUTE	PRELUDE	\N	28411021	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
419	22	587	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11110740	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
35	2	386	STRING	GUITAR, HALF	KAY	\N	7	\N	\N	\N	\N	\N	\N	GRT
481	31	439	WOODWIND	CLARINET, B FLAT	ETUDE	\N	11299276	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
489	32	527	WOODWIND	FLUTE	ETUDE	\N	D1206485	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
490	32	600	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54574	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
495	33	528	WOODWIND	FLUTE	ETUDE	\N	D1206556	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
545	42	74	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
501	34	529	WOODWIND	FLUTE	ETUDE	\N	206295	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
502	34	603	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54336	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
290	10	42	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	PB17070395	\N	2022/23	\N	\N	\N	\N	TNTP
370	16	581	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	362477A	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
504	35	116	BRASS	TRUMPET, B FLAT	YAMAHA	\N	756323	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
507	35	530	WOODWIND	FLUTE	ETUDE	\N	206261	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
513	36	531	WOODWIND	FLUTE	GEMEINHARDT	\N	K96124	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
525	38	533	WOODWIND	FLUTE	JUPITER	JEL 710	WD57818	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
526	38	607	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54539	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
530	39	447	WOODWIND	CLARINET, B FLAT	ETUDE	\N	1209178	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
536	40	448	WOODWIND	CLARINET, B FLAT	ETUDE	\N	1209179	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
538	40	609	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54577	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
542	41	449	WOODWIND	CLARINET, B FLAT	ETUDE	\N	1209180	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
548	42	450	WOODWIND	CLARINET, B FLAT	ETUDE	\N	1209177	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
583	49	544	WOODWIND	FLUTE	JUPITER	JEL 710	XD59774	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
587	50	545	WOODWIND	FLUTE	JUPITER	JEL 710	XD59164	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
590	51	459	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	KE54774	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
64	3	314	PERCUSSION	BELL SET	UNKNOWN	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	BL
104	4	487	WOODWIND	FLUTE	HEIMAR	\N	T479	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
192	1	201	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
331	13	213	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
344	14	214	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
376	17	425	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	443788	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
651	66	635	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	CF57209	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
269	8	364	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKP064163	\N	yes	\N	MS MUSIC	\N	\N	GRC
98	4	360	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKP064875	\N	2021/22	Jihong Joo	MS MUSIC	\N	11686	GRC
48	3	17	BRASS	TROMBONE, TENOR	YAMAHA	\N	336151	\N	\N	\N	INSTRUMENT STORE	\N	\N	TN
509	36	68	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	Arhum Bid	\N	\N	11706	TNTP
392	19	352	STRING	GUITAR, ACOUSTIC	YAMAHA	F 325	00Y224811	\N	\N	\N	\N	\N	\N	GRA
400	20	353	STRING	GUITAR, ACOUSTIC	YAMAHA	F 325	00Y224884	\N	\N	\N	\N	\N	\N	GRA
620	59	148	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA14343	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
624	60	149	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA033335	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
628	61	150	BRASS	TRUMPET, B FLAT	JUPITER	\N	BA09439	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
297	10	418	WOODWIND	CLARINET, B FLAT	SIGNET	\N	30614E	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
310	11	419	WOODWIND	CLARINET, B FLAT	VITO	\N	B59862	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
450	27	59	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
416	22	354	STRING	GUITAR, ACOUSTIC	YAMAHA	F 325	00Y145219	HS MUSIC	\N	\N	\N	\N	\N	GRA
314	11	655	WOODWIND	SAXOPHONE, TENOR	VITO	\N	420486	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
457	28	60	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
325	12	577	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11120110	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
326	12	656	WOODWIND	SAXOPHONE, TENOR	BUNDY	\N	TS10050027	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
442	25	590	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11110696	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
464	29	61	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
431	24	245	PERCUSSION	CONGA	YAMAHA	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CG
438	25	246	PERCUSSION	CONGA	YAMAHA	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CG
448	26	521	WOODWIND	FLUTE	GEMEINHARDT	\N	K98973	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
449	26	591	WOODWIND	SAXOPHONE, ALTO	CONSERVETE	\N	91145	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
455	27	522	WOODWIND	FLUTE	GEMEINHARDT	\N	P11876	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
316	12	44	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
461	28	436	WOODWIND	CLARINET, B FLAT	ETUDE	\N	11299279	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
197	1	221	PERCUSSION	PRACTICE PAD	YAMAHA	4 INCH	ISK NO.26	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	PD
660	69	477	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	BE63692	BB1	2023/24	Olivia Patel	\N	\N	10561	CL
540	41	128	BRASS	TRUMPET, B FLAT	BLESSING	\N	34928	\N	2023/24	Ansh Mehta	\N	\N	10657	TP
546	42	130	BRASS	TRUMPET, B FLAT	BLESSING	\N	35272	\N	2023/24	Ainsley Hire	\N	\N	10621	TP
397	19	663	WOODWIND	SAXOPHONE, TENOR	JUPITER	\N	AF04276	\N	2023/24	Ean Kimuli	\N	\N	11703	SXT
608	56	145	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA04094	BB1	2023/24	Etienne Carlevato	\N	\N	12924	TP
508	35	604	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54451	\N	2023/24	Uzima Otieno	\N	\N	13056	SXA
598	53	547	WOODWIND	FLUTE	JUPITER	JEL 710	YD66330	\N	2023/24	Eliana Hodge	\N	\N	12193	FL
107	4	648	WOODWIND	SAXOPHONE, TENOR	YAMAHA	\N	26286	HS MUSIC	2022/23	\N	\N	\N	\N	SXT
352	15	47	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	MS Band 8	2022/23	Kianu Ruiz Stannah	\N	\N	10247	TNTP
424	23	355	STRING	GUITAR, ACOUSTIC	YAMAHA	F 325	00Y224899	HS MUSIC	yes, no case	\N	HS MUSIC	\N	\N	GRA
432	24	356	STRING	GUITAR, ACOUSTIC	YAMAHA	F 325	00Y224741	HS MUSIC	yes, no case	\N	HS MUSIC	\N	\N	GRA
142	9	194	KEYBOARD	PIANO, ELECTRIC	YAMAHA	CLP 7358	BCAZ01088	\N	\N	\N	LOWER ES MUSIC	\N	\N	PE
588	50	619	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF56406	BB7	2023/24	Luke O'Hara	\N	\N	12063	SXA
667	2	281	PERCUSSION	PRACTICE PAD	YAMAHA	4 INCH	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	PD
483	31	598	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54370	BB1	2023/24	Emilie Wittmann	\N	\N	12428	SXA
639	63	632	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	BF54335	ES MUSIC	84 7/24	Tawheed Hussain	\N	\N	11469	SXA
605	55	463	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54729	BB7	2023/24	Lauren Mucci	\N	\N	12694	CL
67	3	346	STRING	GUITAR, BASS	FENDER	Squire	ICS10191321	BB8	2023/24	Isla Willis	\N	\N	12969	GRB
5	2	82	BRASS	TRUMPET, B FLAT	BLESSING	\N	G29437	BB8	2023/24	Fatima Zucca	\N	\N	10566	TP
453	27	375	STRING	GUITAR, CLASSICAL	YAMAHA	40	\N	\N	yes	\N	MS MUSIC	\N	\N	GRC
385	18	426	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	25247	BB1	2023/24	Balazs Meyers	\N	\N	12621	CL
462	28	523	WOODWIND	FLUTE	GEMEINHARDT	\N	K98879	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
467	29	437	WOODWIND	CLARINET, B FLAT	ETUDE	\N	11299280	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
468	29	524	WOODWIND	FLUTE	GEMEINHARDT	\N	K99078	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
474	30	438	WOODWIND	CLARINET, B FLAT	ETUDE	\N	11299277	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
241	1	312	PERCUSSION	BELL SET	UNKNOWN	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	BL
2	2	9	BRASS	HORN, F	HOLTON	H281	619468	\N	\N	\N	INSTRUMENT STORE	\N	\N	HNF
36	2	397	STRING	VIOLIN	AUBERT	\N	3923725	\N	\N	\N	INSTRUMENT STORE	\N	\N	VN
328	13	45	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
39	2	480	WOODWIND	CLARINET, BASS	VITO	\N	Y3717	\N	\N	\N	INSTRUMENT STORE	\N	\N	CLB
4	2	34	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
41	2	563	WOODWIND	OBOE	BUNDY	\N	B33402	\N	yes	\N	INSTRUMENT STORE	\N	\N	OB
42	2	565	WOODWIND	PICCOLO	BUNDY	\N	12111016	\N	\N	\N	INSTRUMENT STORE	\N	\N	PC
375	17	371	STRING	GUITAR, CLASSICAL	PARADISE	17	\N	\N	yes, no case	Amin Hussein	MS MUSIC	\N	\N	GRC
384	18	372	STRING	GUITAR, CLASSICAL	PARADISE	18	\N	\N	\N	\N	MS MUSIC	\N	\N	GRC
550	42	611	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF53790	BB8	2023/24	Olivia Freiin von Handel	\N	\N	12096	SXA
193	1	216	MISCELLANEOUS	STAND, GUITAR	UNKNOWN	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
200	1	226	PERCUSSION	BELLS, TUBULAR	ROSS	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	BLT
271	8	416	WOODWIND	CLARINET, B FLAT	AMATI KRASLICE	\N	504869	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
313	11	576	WOODWIND	SAXOPHONE, ALTO	BLESSING	\N	3468	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
621	59	467	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54680	\N	2023/24	Aisha Awori	\N	\N	10474	CL
425	23	431	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	193026A	HS MUSIC	2023/24	Fatuma Tall	\N	\N	11515	CL
394	19	427	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65020	BB1	2023/24	Zayn Khalid	\N	\N	12616	CL
381	18	32	BRASS	TROMBONE, TENOR	YAMAHA	\N	646721	HS MUSIC	2023/24	Andrew Wachira	\N	\N	20866	TN
346	14	422	WOODWIND	CLARINET, B FLAT	AMATI KRASLICE	\N	206167	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
534	40	126	BRASS	TRUMPET, B FLAT	BLESSING	\N	H35214	BB1	2023/24	Masoud Ibrahim	\N	\N	13076	TP
350	14	658	WOODWIND	SAXOPHONE, TENOR	ALLORA	\N	13120005	BB1	2023/24	Ochieng Simbiri	\N	\N	11265	SXT
217	1	254	PERCUSSION	STAND, CYMBAL	GIBRALTAR	GIB-5710	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
625	60	468	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54704	BB7	2023/24	Lorian Inglis	\N	\N	12133	CL
233	1	296	PERCUSSION	TIMPANI, 23 INCH	LUDWIG	LKS423FG	36264	\N	\N	\N	MS MUSIC	\N	\N	TPT
240	16	309	PERCUSSION	XYLOPHONE	MAJESTIC	x55 352	25	\N	\N	\N	MS MUSIC	\N	\N	X
187	1	182	SOUND	PA SYSTEM, ALL-IN-ONE	BEHRINGER	EPS500MP3	S1402186AA8	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
263	8	40	BRASS	TROMBONE, ALTO - PLASTIC	PBONE	Mini	BM17120387	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNAP
226	1	283	PERCUSSION	BELLS, SLEIGH	WEISS	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	BLS
267	8	208	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
280	9	209	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
136	6	5	BRASS	BARITONE/EUPHONIUM	YAMAHA	\N	533835	BB8	2023/24	Saqer Alnaqbi	\N	\N	12909	BH
494	33	441	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65382	BB8	2023/24	Moussa Sangare	\N	\N	12427	CL
512	36	444	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65434	BB1	2023/24	Anastasia Mulema	\N	\N	11622	CL
440	25	433	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	405117	MS Band 8	2022/23	Tangaaza Mujuni	\N	\N	10788	CL
355	15	215	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
55	3	203	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
216	1	253	PERCUSSION	CYMBALS, HANDHELD 18 INCH	ZILDJIAN	18 Inch Symphonic Viennese Tone	ZIL-A0447	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CMZ
357	15	378	STRING	GUITAR, CUTAWAY	UNKNOWN	\N	\N	\N	yes	\N	MS MUSIC	\N	\N	GRW
366	16	379	STRING	GUITAR, CUTAWAY	UNKNOWN	\N	\N	\N	yes	\N	MS MUSIC	\N	\N	GRW
272	8	492	WOODWIND	FLUTE	YAMAHA	\N	650122	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
300	10	575	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	387824A	\N	present x	\N	INSTRUMENT STORE	\N	\N	SXA
653	67	475	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	BE63660	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
655	67	636	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	CF57086	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
336	13	502	WOODWIND	FLUTE	GEMEINHARDT	2SP	K96367	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
154	6	489	WOODWIND	FLUTE	EMERSON	EF1	42684	\N	2023/24	Ji-June	\N	\N	\N	FL
166	7	304	PERCUSSION	TUBANOS	REMO	12 inch	1-7	\N	\N	\N	MS MUSIC	\N	\N	TBN
426	23	518	WOODWIND	FLUTE	PRELUDE	\N	33111112	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
427	23	588	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11110695	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
428	23	667	WOODWIND	SAXOPHONE, TENOR	JUPITER	JTS700	CF08026	\N	2023/24	\N	INSTRUMENT STORE	\N	\N	SXT
434	24	519	WOODWIND	FLUTE	PRELUDE	\N	28411028	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
435	24	589	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11110739	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
302	11	25	BRASS	TROMBONE, TENOR	BLESSING	\N	452363	\N	x	\N	INSTRUMENT STORE	\N	\N	TN
327	13	27	BRASS	TROMBONE, TENOR	ETUDE	\N	9120158	\N	x	\N	INSTRUMENT STORE	\N	\N	TN
340	14	28	BRASS	TROMBONE, TENOR	ETUDE	\N	9120243	\N	\N	\N	INSTRUMENT STORE	\N	\N	TN
351	15	29	BRASS	TROMBONE, TENOR	ETUDE	\N	9120157	\N	\N	\N	INSTRUMENT STORE	\N	\N	TN
363	16	30	BRASS	TROMBONE, TENOR	ALLORA	\N	1107197	\N	\N	\N	INSTRUMENT STORE	\N	\N	TN
372	17	31	BRASS	TROMBONE, TENOR	ALLORA	\N	1107273	\N	\N	\N	INSTRUMENT STORE	7/6/2023	\N	TN
475	30	525	WOODWIND	FLUTE	ETUDE	\N	D1206510	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
566	46	78	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
662	70	159	BRASS	TRUMPET, B FLAT	JUPITER	JTR 700	CAS15598	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
571	47	79	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
638	63	557	WOODWIND	FLUTE	JUPITER	JFL 700	DD58225	BB8	2023/24	Malan Chopra	\N	\N	10508	FL
522	38	122	BRASS	TRUMPET, B FLAT	ETUDE	\N	124911	\N	2022/23	Mark Anding	\N	\N	\N	TP
562	45	134	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA08653	BB7	2023/24	Connor Fort	\N	\N	11650	TP
44	2	641	WOODWIND	SAXOPHONE, BARITONE	VIENNA	\N	B15217	\N	2023/24	Fatuma Tall	\N	\N	11515	SXB
576	48	80	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
560	44	613	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF56401	\N	2023/24	Emiel Ghelani-Decorte	\N	\N	12674	SXA
90	4	302	PERCUSSION	TUBANOS	REMO	14 inch	\N	\N	\N	\N	MS MUSIC	\N	\N	TBN
429	24	56	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
81	4	36	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
171	7	490	WOODWIND	FLUTE	WT.AMSTRONG	104	2922376	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
175	1	7	BRASS	BARITONE/TENOR HORN	BESSON	\N	575586	\N	x	\N	INSTRUMENT STORE	\N	\N	BT
177	1	13	BRASS	MELLOPHONE	JUPITER	\N	L02630	\N	\N	\N	INSTRUMENT STORE	\N	\N	M
182	1	160	BRASS	TRUMPET, POCKET	ALLORA	\N	PT1309020	\N	\N	\N	INSTRUMENT STORE	\N	\N	TPP
251	1	401	WOODWIND	BASSOON	UNKNOWN	\N	33CVC02	\N	\N	\N	INSTRUMENT STORE	\N	\N	BS
111	5	37	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
255	1	479	WOODWIND	CLARINET, BASS	VITO	\N	18250	\N	\N	\N	INSTRUMENT STORE	\N	\N	CLB
180	1	33	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNTP
257	1	562	WOODWIND	OBOE	BUNDY	\N	B33327	\N	yes needs repair	\N	INSTRUMENT STORE	\N	\N	OB
258	1	564	WOODWIND	PICCOLO	BUNDY	\N	11010007	\N	\N	\N	INSTRUMENT STORE	\N	\N	PC
259	1	566	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11120071	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
284	9	417	WOODWIND	CLARINET, B FLAT	BUNDY	\N	989832	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
131	5	483	WOODWIND	CLARINET, BASS	JUPITER	JBC 1000	CE69047	BB8	2023/24	Mikael Eshetu	\N	\N	12689	CLB
288	9	653	WOODWIND	SAXOPHONE, TENOR	SELMER	\N	N495304	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
339	13	657	WOODWIND	SAXOPHONE, TENOR	BUNDY	\N	TS10050022	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
599	53	622	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	YF57624	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
451	27	107	BRASS	TRUMPET, B FLAT	BLESSING	\N	H34971	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
61	3	287	PERCUSSION	SNARE	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	SR
143	6	206	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
163	7	207	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
138	6	38	BRASS	TROMBONE, ALTO - PLASTIC	PBONE	Mini	BM18030151	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNAP
77	3	647	WOODWIND	SAXOPHONE, TENOR	YAMAHA	\N	31840	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXT
152	6	413	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	7943	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
433	24	432	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	444451	\N	2021/22	\N	INSTRUMENT STORE	\N	\N	CL
16	2	243	PERCUSSION	CONGA	MEINL	HEADLINER RANGE	\N	\N	\N	\N	MS MUSIC	\N	\N	CG
532	39	608	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54476	\N	2023/24	Tobias Godfrey	\N	\N	11227	SXA
634	62	556	WOODWIND	FLUTE	JUPITER	JEL 710	BD62736	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
635	62	631	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	BF54273	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
637	63	471	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	YE67775	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
641	64	472	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	YE67468	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
657	68	476	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	BE63558	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
601	54	462	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE50000	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
606	55	549	WOODWIND	FLUTE	JUPITER	JEL 710	YD66218	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
610	56	550	WOODWIND	FLUTE	JUPITER	JEL 710	YD66291	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
613	57	465	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54699	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
615	57	626	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	AF53354	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
617	58	466	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54697	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
618	58	552	WOODWIND	FLUTE	JUPITER	JEL 710	BD62678	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
619	58	627	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	AF53345	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
622	59	553	WOODWIND	FLUTE	JUPITER	JEL 710	BD63526	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
626	60	554	WOODWIND	FLUTE	JUPITER	JEL 710	BD63433	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
631	61	630	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	BF54625	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
633	62	470	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	YE67470	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
658	68	637	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	CF57292	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
661	69	638	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	CF57202	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
664	70	639	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	CF56658	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
15	2	238	PERCUSSION	CLAVES	LP	GRENADILLA	\N	\N	\N	\N	MS MUSIC	\N	\N	CLV
17	2	251	PERCUSSION	COWBELL	LP	Black Beauty	\N	\N	\N	\N	MS MUSIC	\N	\N	CWB
76	3	642	WOODWIND	SAXOPHONE, BARITONE	JUPITER	JBS 1000	XF05936	\N	\N	\N	PIANO ROOM	\N	\N	SXB
612	57	146	BRASS	TRUMPET, B FLAT	JUPITER	\N	XA04125	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
514	36	605	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF53797	HS MUSIC	2023/24	Thomas Higgins	\N	\N	11744	SXA
26	2	293	PERCUSSION	TAMBOURINE	REMO	Fiberskyn 3 black	\N	\N	\N	\N	MS MUSIC	\N	\N	TR
11	2	199	KEYBOARD	PIANO, UPRIGHT	EAVESTAFF	\N	\N	\N	\N	\N	PRACTICE ROOM 2	\N	\N	PU
54	3	200	KEYBOARD	PIANO, UPRIGHT	SPENCER	\N	\N	\N	\N	\N	PRACTICE ROOM 3	\N	\N	PU
573	47	455	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	KE56579	BB1	2023/24	Owen Harris	\N	\N	12609	CL
223	1	272	PERCUSSION	QUAD, MARCHING	PEARL	Black	202902	\N	\N	\N	MS MUSIC	\N	\N	Q
249	1	385	STRING	GUITAR, HALF	KAY	\N	11	\N	\N	\N	\N	\N	\N	GRT
69	3	387	STRING	GUITAR, HALF	KAY	\N	9	\N	under repair	\N	PRACTICE ROOM 3	\N	\N	GRT
21	2	267	PERCUSSION	EGG SHAKERS	LP	Black 2 pr	\N	\N	\N	\N	MS MUSIC	\N	\N	EGS
22	2	271	PERCUSSION	MARACAS	LP	Pro Yellow Light Handle	\N	\N	\N	\N	MS MUSIC	\N	\N	MRC
293	10	210	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
306	11	211	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
160	7	87	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	638871	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
181	1	81	BRASS	TRUMPET, B FLAT	YAMAHA	\N	808845	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
237	1	306	PERCUSSION	WOOD BLOCK	BLACK SWAMP	BLA-MWB1	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	WB
7	2	166	ELECTRIC	AMPLIFIER	GALLEN-K	\N	72168	MS Band 7	2022/23	\N	MS MUSIC	\N	\N	AM
242	1	317	PERCUSSION	CYMBAL, SUSPENDED 18 INCH	ZILDJIAN	Orchestral Selection ZIL-A0419	AD 69101 046	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CMS
109	5	12	BRASS	HORN, F	JUPITER	JHR1100	BC00278	BB8	2023/24	Kai O'Bra	\N	\N	12342	HNF
125	5	348	STRING	GUITAR, BASS	FENDER	\N	CGF1307326	\N	2023/24	\N	DRUM ROOM 1	\N	\N	GRB
99	4	388	STRING	GUITAR, HALF	KAY	\N	4	\N	\N	\N	PRACTICE ROOM 3	\N	\N	GRT
83	4	168	ELECTRIC	AMPLIFIER, BASS	FENDER	BASSMAN	M 1053205	\N	\N	\N	DRUM ROOM 1	\N	\N	AMB
341	14	46	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	\N	\N	\N	\N	MS MUSIC	\N	\N	TNTP
283	9	393	STRING	GUITAR, HALF	KAY	\N	8	\N	\N	\N	\N	\N	\N	GRT
86	4	247	PERCUSSION	CONGA	LATIN PERCUSSION	12 inch	ISK 3120157238	\N	\N	\N	MS MUSIC	\N	\N	CG
116	5	248	PERCUSSION	CONGA	LATIN PERCUSSION	14 Inch	ISK 23 JAN 02	\N	\N	\N	MS MUSIC	\N	\N	CG
57	3	244	PERCUSSION	CONGA	LATIN PERCUSSION	10 Inch	ISK 3120138881	\N	\N	\N	MS MUSIC	\N	\N	CG
144	6	249	PERCUSSION	CONGA	LATIN PERCUSSION	10 Inch	ISK 312138881	\N	\N	\N	MS MUSIC	\N	\N	CG
165	7	250	PERCUSSION	CONGA	LATIN PERCUSSION	10 Inch	ISK 312120138881	\N	\N	\N	MS MUSIC	\N	\N	CG
47	3	10	BRASS	HORN, F	HOLTON	\N	602	HS MUSIC	2023/24	Jamison Line	\N	\N	11625	HNF
214	1	242	PERCUSSION	CONGA	YAMAHA	Red 14 inch	\N	\N	\N	\N	MS MUSIC	\N	\N	CG
170	7	415	WOODWIND	CLARINET, B FLAT	VITO	\N	B 859866/7112-STORE	\N	\N	\N	\N	\N	\N	CL
188	1	183	KEYBOARD	KEYBOARD	ROLAND	813	AH24202	\N	\N	\N	\N	\N	\N	KB
29	2	313	PERCUSSION	BELL SET	UNKNOWN	\N	\N	BB8	2023/24	Selma Mensah	\N	\N	12392	BL
565	45	614	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF57089	MS Band 5	2022/23	Fatuma Tall	\N	\N	11515	SXA
570	46	615	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF57192	BB1	2023/24	Max Stock	\N	\N	12915	SXA
647	65	634	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	BF54604	HS MUSIC	2023/24	Ethan Sengendo	\N	\N	11702	SXA
630	61	555	WOODWIND	FLUTE	JUPITER	JEL 710	BD62784	BB1	2023/24	Nora Saleem	\N	\N	12619	FL
159	7	39	BRASS	TROMBONE, ALTO - PLASTIC	PBONE	Mini	BM17120413	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNAP
277	9	41	BRASS	TROMBONE, ALTO - PLASTIC	PBONE	Mini	BM17120388	\N	\N	\N	INSTRUMENT STORE	\N	\N	TNAP
59	3	264	PERCUSSION	DRUMSET	PEARL	Vision	\N	\N	\N	\N	MS MUSIC	\N	\N	DK
93	4	325	PERCUSSION	SNARE	PEARL	\N	\N	\N	\N	\N	UPPER ES MUSIC	\N	\N	SR
70	3	398	STRING	VIOLIN	WILLIAM LEWIS & SON	\N	D 0933 1998	\N	2023/24	Gakenia Mucharie	\N	\N	\N	VN
85	4	204	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
115	5	205	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
224	1	274	PERCUSSION	SNARE, MARCHING	YAMAHA	MS 9014	1P-3095	\N	\N	\N	MS MUSIC	\N	\N	SRM
184	1	164	BRASS	SOUSAPHONE	YAMAHA	\N	910530	\N	\N	\N	MS MUSIC	7/6/2023	\N	SSP
262	8	22	BRASS	TROMBONE, TENOR	YAMAHA	\N	320963	\N	\N	\N	MS MUSIC	\N	\N	TN
74	3	486	WOODWIND	FLUTE	YAMAHA	\N	600365	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
289	10	24	BRASS	TROMBONE, TENOR	YAMAHA	\N	316975	\N	2022/23	Margaret Oganda	\N	\N	\N	TN
132	5	488	WOODWIND	FLUTE	YAMAHA	\N	452046A	\N	\N	\N	MS MUSIC	MS	\N	FL
476	30	596	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54480	ES MUSIC	2021/22	Magaret Oganda	\N	\N	\N	SXA
480	31	384	STRING	GUITAR, ELECTRIC	FENDER	CD-60CE Mahogany	116108578	\N	yes	Angel Gray	\N	\N	\N	GRE
278	9	89	BRASS	TRUMPET, B FLAT	YAMAHA	\N	556519	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
519	37	532	WOODWIND	FLUTE	PRELUDE	\N	AP28041129	\N	PRESENT	\N	\N	\N	\N	FL
304	11	91	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	554189	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
623	59	628	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	AF53348	\N	2023/24	Reuben Szuchman	\N	\N	12667	SXA
609	56	464	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54692	BB8	2023/24	Lilla Vestergaard	\N	\N	11266	CL
1	2	1	BRASS	BARITONE/EUPHONIUM	BOOSEY & HAWKES	Soveriegn	601249	HS MUSIC	2023/24	Kasra Feizzadeh	PIANO ROOM	\N	12871	BH
578	48	456	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	KE56608	BB7	2023/24	Ariel Mutombo	\N	\N	12549	CL
353	15	95	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	634070	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
472	30	110	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	501720	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
479	31	111	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	645447	\N	\N	\N	INSTRUMENT STORE	\N	\N	TP
174	7	651	WOODWIND	SAXOPHONE, TENOR	YAMAHA	\N	10355	\N	2022	Noah Ochomo	\N	\N	\N	SXT
183	1	161	BRASS	TUBA	YAMAHA	\N	106508	\N	Mark Class	\N	MS MUSIC	7/6/2023	\N	TB
168	7	363	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKZ104831	\N	yes, no case	\N	MS MUSIC	\N	\N	GRC
379	17	582	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	388666A	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
388	18	583	WOODWIND	SAXOPHONE, ALTO	YAMAHA	YAS 23	T14584	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
402	20	428	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65540	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
213	1	241	PERCUSSION	SNARE, CONCERT	BLACK SWAMP	BLA-CM514BL	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	SRC
146	6	297	PERCUSSION	TIMPANI, 23 INCH	LUDWIG	LKS423FG	52479	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TPT
225	1	282	PERCUSSION	SHIELD	GIBRALTAR	GIB-GDS-5	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
595	52	621	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	YF57348	\N	2022/23	Mark Anding	\N	7/6/2023	\N	SXA
486	32	112	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	638850	\N	\N	\N	MS MUSIC	\N	\N	TP
666	1	280	PERCUSSION	PRACTICE KIT	PEARL	\N	\N	\N	\N	\N	UPPER ES MUSIC	\N	\N	PK
586	50	458	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	KE54751	BB7	2023/24	Seung Hyun Nam	\N	\N	13080	CL
145	6	261	PERCUSSION	DJEMBE	CUSTOM	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	DJ
87	4	259	PERCUSSION	DJEMBE	CUSTOM	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	DJ
56	3	224	PERCUSSION	RAINSTICK	CUSTOM	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	RK
66	3	331	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
580	48	617	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF56283	ES ROOM	\N	Vanaaya Patel	\N	\N	20839	SXA
575	47	616	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF57296	BB7	2023/24	Yonatan Wondim Belachew Andersen	\N	\N	12967	SXA
208	1	235	PERCUSSION	CASTANETS	DANMAR	DAN-17A	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CST
113	5	169	ELECTRIC	AMPLIFIER, BASS	ROLAND	CUBE-100	AX78271	\N	\N	\N	MS MUSIC	\N	\N	AMB
349	14	579	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	290365	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
201	1	227	PERCUSSION	VIBRASLAP	WEISS	SW-VIBRA	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	VS
13	2	223	PERCUSSION	RAINSTICK	CUSTOM	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	RK
31	2	330	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
96	4	332	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
124	5	333	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
149	6	334	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
167	7	335	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
52	3	167	ELECTRIC	AMPLIFIER, BASS	FENDER	Rumble 25	ICTB15016929	HS MUSIC	\N	\N	HS MUSIC	\N	\N	AMB
100	4	399	STRING	VIOLIN	ANDREAS EASTMAN	\N	V2024618	HS MUSIC	2023/24	\N	HS MUSIC	\N	\N	VN
27	2	298	PERCUSSION	TIMPANI, 26 INCH	LUDWIG	SUD-LKS426FG	51734	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TPD
128	5	400	STRING	VIOLIN	ANDREAS EASTMAN	\N	V2025159	HS MUSIC	2023/24	\N	HS MUSIC	\N	\N	VN
123	5	326	PERCUSSION	TIMPANI, 29 INCH	LUDWIG	\N	36346	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TPN
161	7	172	ELECTRIC	AMPLIFIER, GUITAR	FENDER	Frontman 15G	ICTB1500267	HS MUSIC	\N	\N	HS MUSIC	\N	\N	AMG
205	1	232	PERCUSSION	MOUNTING BRACKET, BELL TREE	TREEWORKS	TW-TRE52	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
94	4	327	PERCUSSION	TIMPANI, 32 INCH	LUDWIG	\N	36301	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TPW
231	1	294	PERCUSSION	TAMBOURINE, 10 INCH	PEARL	Symphonic Double Row PEA-PETM1017	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TRT
198	1	222	PERCUSSION	RAINSTICK	CUSTOM	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	RK
244	1	329	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
268	8	336	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
185	1	165	ELECTRIC	AMPLIFIER	FENDER	\N	M 1134340	HS MUSIC	\N	\N	HS MUSIC	\N	\N	AM
203	1	229	PERCUSSION	BASS DRUM	LUDWIG	\N	3442181	HS MUSIC	\N	\N	HS MUSIC	\N	\N	BD
63	18	311	PERCUSSION	XYLOPHONE	DII	Decator	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	X
279	9	174	ELECTRIC	AMPLIFIER, KEYBOARD	PEAVEY	\N	ODB#1230169	HS MUSIC	\N	\N	HS MUSIC	\N	\N	AMK
409	21	429	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65851	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
500	34	442	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65593	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
95	19	328	PERCUSSION	XYLOPHONE	UNKNOWN	\N	660845710719	HS MUSIC	\N	\N	HS MUSIC	\N	\N	X
186	1	179	SOUND	MICROPHONE	SHURE	SM58	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
206	1	233	PERCUSSION	CABASA	LP	LP234A	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CBS
220	1	268	PERCUSSION	GUIRO	LP	Super LP243	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	GUR
204	1	231	PERCUSSION	BELL TREE	TREEWORKS	TW-TRE35	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	BLR
222	1	270	PERCUSSION	MARACAS	WEISS	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	MRC
506	35	443	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65299	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
137	6	20	BRASS	TROMBONE, TENOR	YAMAHA	\N	071009A	\N	x	\N	INSTRUMENT STORE	\N	\N	TN
234	1	300	PERCUSSION	TRIANGLE	ALAN ABEL	6" Inch Symphonic	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TGL
209	3	236	PERCUSSION	CLAVES	LP	GRENADILLA	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CLV
321	12	368	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKPO64008	\N	yes, no case	\N	MS MUSIC	\N	\N	GRC
333	13	369	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKP054554	\N	yes	\N	MS MUSIC	\N	\N	GRC
312	11	499	WOODWIND	FLUTE	YAMAHA	\N	617224	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
322	12	420	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	7980	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
447	26	434	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	B88822	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
37	2	405	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	206603A	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
40	2	485	WOODWIND	FLUTE	YAMAHA	222	826706	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
317	12	92	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	678970	BB8	2023/24	Ignacio Biafore	\N	\N	12170	TP
196	1	220	PERCUSSION	COWBELL	LP	Black Beauty	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	CWB
281	9	337	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
294	10	338	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
307	11	339	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
320	12	340	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
332	13	341	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
345	14	342	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
305	11	171	ELECTRIC	AMPLIFIER, BASS	PEAVEY	TKO-230EU	OJBHE2300098	HS MUSIC	\N	\N	HS MUSIC	\N	\N	AMB
356	15	343	PERCUSSION	XYLOPHONE	ORFF	\N	\N	ES MUSIC	\N	\N	UPPER ES MUSIC	\N	\N	X
398	20	52	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TNTP
406	21	53	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TNTP
443	26	58	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TNTP
436	25	57	BRASS	TROMBONE, TENOR - PLASTIC	KAIZER	\N	\N	\N	2022/23	Mark Anding	MS MUSIC	\N	\N	TNTP
238	2	307	PERCUSSION	WOOD BLOCK	LP	PLASTIC RED	\N	\N	\N	\N	MS MUSIC	\N	\N	WB
446	26	380	STRING	GUITAR, ELECTRIC	FENDER	CD-60CE Mahogany	115085004	HS MUSIC	Yes,with case	\N	HS MUSIC	\N	\N	GRE
239	3	308	PERCUSSION	WOOD BLOCK	LP	PLASTIC BLUE	\N	\N	\N	\N	MS MUSIC	\N	\N	WB
221	2	269	PERCUSSION	GUIRO	LP	Plastic	\N	\N	\N	\N	MS MUSIC	\N	\N	GUR
28	17	310	PERCUSSION	XYLOPHONE	ROSS	410	587	\N	\N	\N	MS MUSIC	\N	\N	X
465	29	109	BRASS	TRUMPET, B FLAT	BLESSING	\N	G27536	\N	2023/24	Noah Ochomo	\N	\N	\N	TP
420	22	666	WOODWIND	SAXOPHONE, TENOR	JUPITER	JTS700	CF07965	\N	2023/24	Tawheed Hussain	MS MUSIC	\N	11469	SXT
405	20	664	WOODWIND	SAXOPHONE, TENOR	JUPITER	JTS700	CF07952	\N	2023/24	Mark Anding	MS MUSIC	\N	\N	SXT
393	19	373	STRING	GUITAR, CLASSICAL	PARADISE	19	\N	\N	\N	\N	MS MUSIC	\N	\N	GRC
412	21	665	WOODWIND	SAXOPHONE, TENOR	JUPITER	JTS700	CF07553	\N	2023/24	Naomi Yohannes	\N	\N	10787	SXT
496	33	602	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54322	\N	2022/23	Noah Ochomo	\N	\N	\N	SXA
399	20	100	BRASS	TRUMPET, B FLAT	BLESSING	\N	H31438	\N	2023/24	Maria Agenorwot	\N	\N	13018	TP
493	33	113	BRASS	TRUMPET, B FLAT	BLESSING	\N	F19277	BB8	2023/24	Kush Tanna	\N	\N	11096	TP
554	43	538	WOODWIND	FLUTE	JUPITER	JEL 710	WD62183	\N	2022/23	Mark Anding	\N	\N	\N	FL
151	6	390	STRING	GUITAR, HALF	KAY	\N	3	\N	yes	\N	PRACTICE ROOM 3	\N	\N	GRT
568	46	454	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	KE56526	\N	2023/24	Noah Ochomo	\N	\N	\N	CL
439	25	382	STRING	GUITAR, ELECTRIC	FENDER	CD-60CE Mahogany	115085034	\N	yes, no case	\N	\N	\N	\N	GRE
118	5	266	PERCUSSION	DRUMSET, ELECTRIC	ALESIS	DM8	694318011177	\N	\N	\N	DRUM ROOM 2	\N	\N	DKE
179	1	15	BRASS	TROMBONE, TENOR	HOLTON	TR259	970406	\N	x	\N	MS MUSIC	\N	\N	TN
190	1	197	KEYBOARD	PIANO, GRAND	GEBR. PERZINO	GBT 175	302697	\N	\N	\N	PIANO ROOM	\N	\N	PG
191	1	198	KEYBOARD	PIANO, UPRIGHT	ELSENBERG	\N	\N	\N	\N	\N	PRACTICE ROOM 1	\N	\N	PU
169	7	391	STRING	GUITAR, HALF	KAY	\N	1	\N	yes	\N	PRACTICE ROOM 3	\N	\N	GRT
604	55	144	BRASS	TRUMPET, B FLAT	BACH	\N	488350	BB8	2023/24	Kaisei Stephens	\N	\N	11804	TP
270	8	392	STRING	GUITAR, HALF	KAY	\N	12	\N	yes	\N	PRACTICE ROOM 3	\N	\N	GRT
309	11	395	STRING	GUITAR, HALF	KAY	\N	6	\N	yes	\N	PRACTICE ROOM 3	\N	\N	GRT
202	1	228	PERCUSSION	AGOGO BELL	LP	577 Dry	\N	\N	\N	\N	MS MUSIC	\N	\N	AGG
230	1	292	PERCUSSION	TAMBOURINE	MEINL	Open face	\N	\N	\N	\N	MS MUSIC	\N	\N	TR
147	6	323	PERCUSSION	BELL KIT	PEARL	PK900C	\N	\N	\N	\N	MS MUSIC	\N	\N	BK
243	1	318	PERCUSSION	BELL KIT	PEARL	PK900C	\N	\N	\N	\N	MS MUSIC	\N	\N	BK
227	2	284	PERCUSSION	BELLS, SLEIGH	LUDWIG	Red Handle	\N	\N	\N	\N	MS MUSIC	\N	\N	BLS
665	1	279	PERCUSSION	TOM, MARCHING	PEARL	\N	6 PAIRS	HS MUSIC	\N	\N	HS MUSIC	\N	\N	TTM
195	2	218	MISCELLANEOUS	STAND, MUSIC	GMS	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
236	1	305	PERCUSSION	WIND CHIMES	LP	LP236D	\N	\N	\N	\N	MS MUSIC	\N	\N	WC
235	2	301	PERCUSSION	TRIANGLE	ALAN ABEL	6 inch	\N	\N	\N	\N	MS MUSIC	\N	\N	TGL
207	2	234	PERCUSSION	CABASA	LP	Small	\N	\N	\N	\N	MS MUSIC	\N	\N	CBS
12	2	202	MISCELLANEOUS	HARNESS	PEARL	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	\N
210	1	237	PERCUSSION	CLAVES	KING	\N	\N	\N	\N	\N	MS MUSIC	\N	\N	CLV
460	28	376	STRING	GUITAR, CLASSICAL	YAMAHA	40	265931HRJ	\N	yes, no case	\N	INSTRUMENT STORE	\N	\N	GRC
157	7	6	BRASS	BARITONE/EUPHONIUM	YAMAHA	\N	534386	\N	\N	\N	INSTRUMENT STORE	\N	\N	BH
150	6	362	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKPO065675	\N	yes, no case	\N	MS MUSIC	\N	\N	GRC
253	1	403	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	206681A	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
256	1	484	WOODWIND	FLUTE	YAMAHA	\N	609368	\N	\N	\N	INSTRUMENT STORE	\N	\N	FL
338	13	578	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	352128A	\N	\N	\N	INSTRUMENT STORE	\N	\N	SXA
110	5	19	BRASS	TROMBONE, TENOR	YAMAHA	\N	334792	\N	x	\N	INSTRUMENT STORE	\N	\N	TN
103	4	482	WOODWIND	CLARINET, BASS	YAMAHA	Hex 1000	YE 69248	\N	2023/24	Gwendolyn Anding	\N	\N	\N	CLB
287	9	574	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	348075	MS band 8	\N	Mwende Mittelstadt	\N	\N	11098	SXA
84	4	191	KEYBOARD	PIANO, ELECTRIC	YAMAHA	CAP 320	YCQM01249	\N	\N	\N	MS MUSIC	\N	\N	PE
315	12	26	BRASS	TROMBONE, TENOR	YAMAHA	\N	406896	HS MUSIC	2023/24	Marco De Vries Aguirre	\N	\N	11551	TN
71	3	407	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	7291	\N	\N	\N	INSTRUMENT STORE	\N	\N	CL
73	3	481	WOODWIND	CLARINET, BASS	YAMAHA	\N	43084	\N	\N	\N	INSTRUMENT STORE	\N	\N	CLB
10	2	189	KEYBOARD	PIANO, ELECTRIC	YAMAHA	CVP303x	GBRCKK 01006	\N	\N	\N	MUSIC OFFICE	\N	\N	PE
53	3	190	KEYBOARD	PIANO, ELECTRIC	YAMAHA	CVP 87A	7163	\N	\N	\N	MUSIC OFFICE	\N	\N	PE
295	10	366	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKP064183	\N	yes	\N	MS MUSIC	\N	\N	GRC
247	1	357	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKZ107832	\N	?	\N	\N	\N	\N	GRC
34	2	358	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKZ034412	\N	yes	\N	MS MUSIC	\N	\N	GRC
68	3	359	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKP065151	\N	yes	\N	MS MUSIC	\N	\N	GRC
335	13	421	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	27303	\N	2023/24	Naia Friedhoff Jaeschke	\N	\N	11822	CL
80	4	18	BRASS	TROMBONE, TENOR	YAMAHA	\N	406948	BB1	2023/24	Arhum Bid	\N	\N	11706	TN
301	10	654	WOODWIND	SAXOPHONE, TENOR	YAMAHA	\N	063739A	BB7	2023/24	Finlay Haswell	\N	\N	10562	SXT
276	9	23	BRASS	TROMBONE, TENOR	YAMAHA	\N	303168	\N	xx	Zameer Nanji	MS MUSIC	\N	10416	TN
579	48	543	WOODWIND	FLUTE	JUPITER	JEL 710	XD59816	HS MUSIC	2023/24	Teagan Wood	\N	\N	10972	FL
645	65	473	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	YE67756	BB8	2023/24	Gaia Bonde-Nielsen	\N	\N	12537	CL
611	56	625	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	AF53425	\N	2023/24	Milan Jayaram	\N	\N	10493	SXA
552	43	132	BRASS	TRUMPET, B FLAT	JUPITER	\N	WA26516	BB7	2023/24	Anaiya Khubchandani	\N	\N	11262	TP
389	18	662	WOODWIND	SAXOPHONE, TENOR	JUPITER	JTS710	YF06601	\N	2023/24	Gunnar Purdy	\N	\N	12349	SXT
531	39	534	WOODWIND	FLUTE	JUPITER	JEL 710	WD62211	HS MUSIC	2023/24	Leo Cutler	\N	\N	10673	FL
537	40	535	WOODWIND	FLUTE	JUPITER	JEL 710	WD62108	BB7	2023/24	Yoonseo Choi	\N	\N	10708	FL
543	41	536	WOODWIND	FLUTE	JUPITER	JEL 710	WD62303	BB8	2023/24	Julian Dibling	\N	\N	12883	FL
371	16	660	WOODWIND	SAXOPHONE, TENOR	JUPITER	\N	3847	HS MUSIC	2023/24	Adam Kone	\N	\N	11368	SXT
498	34	114	BRASS	TRUMPET, B FLAT	YAMAHA	\N	511564	BB8	2023/24	Aiden D'Souza	PIANO ROOM	\N	12500	TP
380	17	661	WOODWIND	SAXOPHONE, TENOR	JUPITER	\N	XF03739	HS MUSIC	2023/24	Rohan Giri	\N	\N	12410	SXT
373	17	49	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	PR18100094	BB7	2023/24	Lilyrose Trottier	\N	\N	11944	TNTP
516	37	120	BRASS	TRUMPET, B FLAT	ETUDE	\N	124816	BB1	2023/24	Masoud Ibrahim	\N	\N	13076	TP
520	37	606	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54452	BB7	2023/24	Tanay Cherickel	\N	7/6/2023	13007	SXA
463	28	593	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54181	BB8	2023/24	Romilly Haysmith	\N	\N	12976	SXA
252	1	402	WOODWIND	CLARINET, ALTO IN E FLAT	YAMAHA	\N	1260	\N	2024/25	Mark Anding	\N	\N	\N	CLE
544	41	610	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54140	BB1	2023/24	Lucile Bamlango	\N	\N	10977	SXA
126	5	361	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKZ114314	\N	yes	\N	MS MUSIC	\N	\N	GRC
88	4	265	PERCUSSION	DRUMSET	YAMAHA	\N	SBB2217	HS MUSIC	\N	\N	HS MUSIC	\N	\N	DK
329	13	93	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	553853	\N	2023/24	Natéa Firzé Al Ghaoui	\N	\N	12190	TP
20	2	263	PERCUSSION	DRUMSET	YAMAHA	\N	\N	\N	\N	\N	DRUM ROOM 1	\N	\N	DK
148	6	324	PERCUSSION	DRUMSET	YAMAHA	\N	\N	\N	\N	\N	DRUM ROOM 2	\N	\N	DK
129	5	411	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	27251	\N	2022/23	Mark Anding	\N	\N	\N	CL
264	8	88	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	806725	\N	2023/24	Arjan Arora	\N	\N	12130	TP
266	8	196	KEYBOARD	PIANO, ELECTRIC	YAMAHA	\N	\N	\N	\N	\N	DANCE STUDIO	\N	\N	PE
408	21	185	KEYBOARD	KEYBOARD	YAMAHA	PSR 220	913094	\N	\N	\N	\N	\N	\N	KB
415	22	186	KEYBOARD	KEYBOARD	YAMAHA	PSR 83	13143	\N	\N	\N	\N	\N	\N	KB
417	22	430	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J07292	\N	2022/23	Kevin Keene	HS MUSIC	\N	\N	CL
518	37	445	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65342	HS MUSIC	2023/24	Lo	\N	\N	\N	CL
524	38	446	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65493	HS MUSIC	2023/24	Vashnie Joymungul	\N	\N	12996	CL
3	2	16	BRASS	TROMBONE, TENOR	YAMAHA	\N	406538	\N	2023/24	Anne Bamlango	\N	\N	10978	TN
282	9	365	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKP064005	\N	just the case	Finola Doherty	MS MUSIC	\N	\N	GRC
308	11	367	STRING	GUITAR, CLASSICAL	YAMAHA	40	HKP054553	\N	Checked out	Marwa Baker	MS MUSIC	\N	\N	GRC
32	2	345	STRING	GUITAR, BASS	YAMAHA	BB1000	\N	\N	\N	\N	MS MUSIC	\N	\N	GRB
164	7	219	MISCELLANEOUS	PEDAL, SUSTAIN	YAMAHA	FC4	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	\N
114	5	192	KEYBOARD	PIANO, ELECTRIC	YAMAHA	CAP 329	YCQN01006	HS MUSIC	\N	\N	HS MUSIC	\N	\N	PE
121	5	316	PERCUSSION	BELL SET	YAMAHA	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	BL
141	6	193	KEYBOARD	PIANO, ELECTRIC	YAMAHA	P-95	EBQN02222	HS MUSIC	\N	\N	HS MUSIC	\N	\N	PE
219	1	262	PERCUSSION	DRUMSET	YAMAHA	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	DK
211	1	239	PERCUSSION	BELLS, CONCERT	YAMAHA	YG-250D Standard	112158	HS MUSIC	\N	\N	HS MUSIC	\N	\N	BLC
403	20	515	WOODWIND	FLUTE	YAMAHA	\N	917792	MS band 8	2022/23	\N	MS MUSIC	7/6/2023	\N	FL
452	27	289	PERCUSSION	SNARE	YAMAHA	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	SR
459	28	290	PERCUSSION	SNARE	YAMAHA	\N	\N	HS MUSIC	\N	\N	HS MUSIC	\N	\N	SR
6	2	162	BRASS	TUBA	YAMAHA	\N	533558	\N	\N	\N	MS MUSIC	7/6/2023	\N	TB
14	2	230	PERCUSSION	BASS DRUM	YAMAHA	CB628	PO-1575	\N	\N	\N	MS MUSIC	\N	\N	BD
466	29	377	STRING	GUITAR, CLASSICAL	YAMAHA	40	\N	\N	yes	Keeara Walji	MS MUSIC	\N	\N	GRC
162	7	195	KEYBOARD	PIANO, ELECTRIC	YAMAHA	CLP-645B	BCZZ01016	\N	\N	\N	UPPER ES MUSIC	\N	\N	PE
189	1	188	KEYBOARD	PIANO, ELECTRIC	YAMAHA	CVP 303	GBRCKK 01021	\N	\N	\N	THEATRE/FOYER	\N	\N	PE
454	27	435	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	074011A	BB1	2023/24	Leo Prawitz	\N	\N	12297	CL
50	3	83	BRASS	TRUMPET, B FLAT	YAMAHA	\N	533719	\N	\N	Evan Daines	\N	\N	13073	TP
488	32	440	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	J65438	HS MUSIC	2023/24	Io Verstraete	\N	\N	12998	CL
139	6	86	BRASS	TRUMPET, B FLAT	YAMAHA	YTR 2335	556107	BB1	2023/24	Holly Mcmurtry	\N	\N	10817	TP
361	15	580	WOODWIND	SAXOPHONE, ALTO	YAMAHA	\N	362547A	HS MUSIC	2023/24	Caitlin Wood	\N	\N	10934	SXA
303	11	43	BRASS	TROMBONE, TENOR - PLASTIC	TROMBA	Pro	PB17070488	BB7	2023/24	Titu Tulga	\N	\N	12756	TNTP
471	30	62	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	BB8	2023/24	Alexander Wietecha	\N	\N	12725	TNTP
582	49	457	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	KE54676	\N	2023/24	Theodore Wright	\N	xx	12566	CL
469	29	594	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54576	BB8	2023/24	Stefanie Landolt	\N	\N	12286	SXA
407	21	101	BRASS	TRUMPET, B FLAT	BLESSING	\N	H35502	BB8	2023/24	Kiara Materne	\N	\N	12152	TP
422	23	103	BRASS	TRUMPET, B FLAT	BLESSING	\N	H35099	BB8	2023/24	Mikael Eshetu	\N	\N	12689	TP
444	26	106	BRASS	TRUMPET, B FLAT	BLESSING	BIR 1270	H31450	BB8	2023/24	Saqer Alnaqbi	\N	\N	12909	TP
485	32	64	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	BB7	2023/24	Seth Lundell	\N	\N	12691	TNTP
497	34	66	BRASS	TROMBONE, TENOR - PLASTIC	PBONE	\N	\N	BB7	2023/24	Sadie Szuchman	\N	\N	12668	TNTP
627	60	629	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	AF53502	BB7	2023/24	Noga Hercberg	\N	\N	12681	SXA
629	61	469	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	YE67254	BB7	2023/24	Vilma Doret Rosen	\N	\N	11763	CL
456	27	592	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF54339	MS Band 8	2022/23	Alexander Roe	\N	5/6/2023	12188	SXA
245	1	344	STRING	GUITAR, BASS	ARCHER	\N	\N	\N	2023/24	Jana Landolt	\N	\N	12285	GRB
614	57	551	WOODWIND	FLUTE	JUPITER	JEL 710	YD65954	BB7	2023/24	Anaiya Shah	\N	\N	11264	FL
391	19	99	BRASS	TRUMPET, B FLAT	BLESSING	BTR 1270	H35203	\N	2023/24	Cahir Patel	\N	\N	10772	TP
528	39	124	BRASS	TRUMPET, B FLAT	LIBRETTO	\N	1107571	\N	2023/24	Caleb Ross	\N	\N	11677	TP
584	49	618	WOODWIND	SAXOPHONE, ALTO	JUPITER	JAS 710	XF56319	MS Band 8	2022/23	Barney Carver Wildig	\N	\N	12601	SXA
597	53	461	WOODWIND	CLARINET, B FLAT	JUPITER	JCL710	XE54957	BB8	2023/24	Mahdiyah Muneeb	\N	\N	12761	CL
602	54	548	WOODWIND	FLUTE	JUPITER	JEL 710	YD66080	BB8	2023/24	Seya Chandaria	\N	\N	10775	FL
46	3	2	BRASS	BARITONE/EUPHONIUM	BESSON	Soveriegn 968	770765	HS MUSIC	2023/24	Saqer Alnaqbi	\N	\N	12909	BH
564	45	540	WOODWIND	FLUTE	JUPITER	JEL 710	XD58187	HS MUSIC	2023/24	Saptha Girish Bommadevara	\N	\N	10504	FL
133	5	570	WOODWIND	SAXOPHONE, ALTO	ETUDE	\N	11110173	ms concert band	2021/22	Lukas Norman	\N	\N	11534	SXA
106	4	643	WOODWIND	SAXOPHONE, BARITONE	JUPITER	JBS 1000	AF03351	HS MUSIC	2023/24	Lukas Norman	\N	\N	11534	SXB
101	4	409	WOODWIND	CLARINET, B FLAT	YAMAHA	\N	7988	BB1	2023/24	Zecarun Caminha	\N	\N	12081	CL
135	5	649	WOODWIND	SAXOPHONE, TENOR	YAMAHA	\N	31870	BB1	2023/24	Spencer Schenck	\N	\N	11457	SXT
158	7	21	BRASS	TROMBONE, TENOR	YAMAHA	\N	325472	BB1	2023/24	Maartje Stott	\N	\N	12519	TN
\.


--
-- TOC entry 3961 (class 0 OID 24727)
-- Dependencies: 247
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.locations (room, id) FROM stdin;
PIANO ROOM	3
INSTRUMENT STORE	4
PRACTICE ROOM 3	5
PRACTICE ROOM 2	6
DRUM ROOM 2	7
LOWER ES MUSIC	8
MUSIC OFFICE	9
HS MUSIC	10
UPPER ES MUSIC	11
THEATRE/FOYER	12
MS MUSIC	13
DANCE STUDIO	14
PRACTICE ROOM 1	15
DRUM ROOM 1	16
\.


--
-- TOC entry 3956 (class 0 OID 24646)
-- Dependencies: 242
-- Data for Name: music_instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.music_instruments (id, family, description, legacy_code, code, notes) FROM stdin;
221	BRASS	BARITONE/EUPHONIUM	BH	BH	\N
222	BRASS	BARITONE/TENOR HORN	BH	BT	\N
223	BRASS	BUGLE	\N	BG	\N
224	BRASS	BUGLE , KEYED	\N	BGK	\N
225	BRASS	CIMBASSO	\N	CS	\N
226	BRASS	CIMBASSO, B FLAT	\N	CSB	\N
227	BRASS	CIMBASSO, C	\N	CSC	\N
228	BRASS	CIMBASSO, E FLAT	\N	CSE	\N
229	BRASS	CIMBASSO, F	\N	CSF	\N
230	BRASS	CORNET	\N	CT	\N
231	BRASS	CORNET , POCKET	\N	CTP	\N
232	BRASS	CORNET, A	\N	CTA	\N
233	BRASS	CORNET, C	\N	CTC	\N
234	BRASS	CORNET, E♭  FLAT	\N	CTE	\N
235	BRASS	DIDGERIDOO	\N	DGD	\N
236	BRASS	EUPHONIUM	\N	EP	\N
237	BRASS	EUPHONIUM , DOUBLE BELL	\N	EPD	\N
238	BRASS	FLUGELHORN	\N	FGH	\N
239	BRASS	FRENCH HORN	\N	FH	\N
240	BRASS	HORN, ALTO	\N	HNE	\N
241	BRASS	HORN, F	\N	HNF	\N
242	BRASS	MELLOPHONE	M	M	\N
243	BRASS	METALLOPHONE	\N	MTL	\N
244	BRASS	SAXHORN	\N	SXH	\N
245	BRASS	SAXOTROMBA	\N	STB	\N
246	BRASS	SAXTUBA	\N	STU	\N
247	BRASS	SOUSAPHONE	T	SSP	\N
248	BRASS	TROMBONE, ALTO	PTB	TNA	\N
249	BRASS	TROMBONE, ALTO - PLASTIC	PTB	TNAP	\N
250	BRASS	TROMBONE, BASS	\N	TNB	\N
251	BRASS	TROMBONE, PICCOLO	\N	TNP	\N
252	BRASS	TROMBONE, SOPRANO	\N	TNS	\N
253	BRASS	TROMBONE, TENOR	\N	TN	\N
254	BRASS	TROMBONE, TENOR - PLASTIC	PTB	TNTP	\N
255	BRASS	TROMBONE, VALVE	\N	TNV	\N
256	BRASS	TRUMPET , PICCOLO	\N	TPC	\N
257	BRASS	TRUMPET ,TUBE	\N	TPX	\N
258	BRASS	TRUMPET, B FLAT	TP	TP	\N
259	BRASS	TRUMPET, BAROQUE	\N	TPQ	\N
260	BRASS	TRUMPET, BASS	\N	TPB	\N
261	BRASS	TRUMPET, POCKET	TPP	TPP	\N
262	BRASS	TRUMPET, ROTARY	\N	TPR	\N
263	BRASS	TRUMPET, SLIDE	\N	TPSL	\N
264	BRASS	TRUMPET,SOPRANO	\N	TPS	\N
265	BRASS	TUBA	T	TB	\N
266	BRASS	TUBA, BASS	\N	TBB	\N
267	BRASS	TUBA, WAGNER	\N	TBW	\N
268	BRASS	VUVUZELA	\N	VV	\N
269	KEYBOARD	KEYBOARD	\N	KB	\N
270	KEYBOARD	PIANO, GRAND	\N	PG	\N
271	KEYBOARD	PIANO, UPRIGHT	\N	PU	\N
272	KEYBOARD	PIANO (PIANOFORTE)	\N	P	\N
273	KEYBOARD	PIANO, ELECTRIC	\N	PE	\N
274	PERCUSSION	ASHIKO	\N	ASK	\N
275	PERCUSSION	BARREL DRUM	\N	BRD	\N
276	PERCUSSION	BASS DRUM	\N	BD	\N
277	PERCUSSION	BONGO DRUMS	\N	BNG	\N
278	PERCUSSION	CABASA	\N	CBS	\N
279	PERCUSSION	CARILLON	\N	CRL	\N
280	PERCUSSION	CASTANETS	\N	CST	\N
281	PERCUSSION	CLAPSTICK	\N	CLP	\N
282	PERCUSSION	CLAVES	\N	CLV	\N
283	PERCUSSION	CONGA	\N	CG	\N
284	PERCUSSION	COWBELL	\N	CWB	\N
285	PERCUSSION	CYMBAL	\N	CM	\N
286	PERCUSSION	DJEMBE	\N	DJ	\N
287	PERCUSSION	FLEXATONE	\N	FXT	\N
288	PERCUSSION	GLOCKENSPIEL	\N	GLK	\N
289	PERCUSSION	GOBLET DRUM	\N	GBL	\N
290	PERCUSSION	GONG	\N	GNG	\N
291	PERCUSSION	HANDBELLS	\N	HB	\N
292	PERCUSSION	HANDPAN	\N	HPN	\N
293	PERCUSSION	ILIMBA DRUM	\N	ILD	\N
294	PERCUSSION	KALIMBA	\N	KLM	\N
295	PERCUSSION	KANJIRA	\N	KNJ	\N
296	PERCUSSION	KAYAMBA	\N	KYM	\N
297	PERCUSSION	KEBERO	\N	KBR	\N
298	PERCUSSION	KEMANAK	\N	KMK	\N
299	PERCUSSION	MARIMBA	\N	MRM	\N
300	PERCUSSION	MBIRA	\N	MB	\N
301	PERCUSSION	MRIDANGAM	\N	MRG	\N
302	PERCUSSION	NAGARA (DRUM)	\N	NGR	\N
303	PERCUSSION	OCTA-VIBRAPHONE	\N	OV	\N
304	PERCUSSION	PATE	\N	PT	\N
305	PERCUSSION	SANDPAPER BLOCKS	\N	SPB	\N
306	PERCUSSION	SHEKERE	\N	SKR	\N
307	PERCUSSION	SLIT DRUM	\N	SLD	\N
308	PERCUSSION	SNARE	\N	SR	\N
309	PERCUSSION	STEELPAN	\N	SP	\N
310	PERCUSSION	TABLA	\N	TBL	\N
311	PERCUSSION	TALKING DRUM	\N	TDR	\N
312	PERCUSSION	TAMBOURINE	\N	TR	\N
313	PERCUSSION	TIMBALES (PAILAS)	\N	TMP	\N
314	PERCUSSION	TOM-TOM DRUM	\N	TT	\N
315	PERCUSSION	TRIANGLE	\N	TGL	\N
316	PERCUSSION	VIBRAPHONE	\N	VBR	\N
317	PERCUSSION	VIBRASLAP	\N	VS	\N
318	PERCUSSION	WOOD BLOCK	\N	WB	\N
319	PERCUSSION	XYLOPHONE	\N	X	\N
320	PERCUSSION	AGOGO BELL	\N	AGG	\N
321	PERCUSSION	BELL SET	\N	BL	\N
322	PERCUSSION	BELL TREE	\N	BLR	\N
323	PERCUSSION	BELLS, CONCERT	\N	BLC	\N
324	PERCUSSION	BELLS, SLEIGH	\N	BLS	\N
325	PERCUSSION	BELLS, TUBULAR	\N	BLT	\N
326	PERCUSSION	CYMBAL, SUSPENDED 18 INCH	\N	CMS	\N
327	PERCUSSION	CYMBALS, HANDHELD 16 INCH	\N	CMY	\N
328	PERCUSSION	CYMBALS, HANDHELD 18 INCH	\N	CMZ	\N
329	PERCUSSION	DRUMSET	\N	DK	\N
330	PERCUSSION	DRUMSET, ELECTRIC	\N	DKE	\N
331	PERCUSSION	EGG SHAKERS	\N	EGS	\N
332	PERCUSSION	GUIRO	\N	GUR	\N
333	PERCUSSION	MARACAS	\N	MRC	\N
334	PERCUSSION	PRACTICE KIT	\N	PK	\N
335	PERCUSSION	PRACTICE PAD	\N	PD	\N
336	PERCUSSION	QUAD, MARCHING	\N	Q	\N
337	PERCUSSION	RAINSTICK	\N	RK	\N
338	PERCUSSION	SNARE, CONCERT	\N	SRC	\N
339	PERCUSSION	SNARE, MARCHING	\N	SRM	\N
340	PERCUSSION	TAMBOURINE, 10 INCH	\N	TRT	\N
341	PERCUSSION	TAMBOURINE, 6 INCH	\N	TRS	\N
342	PERCUSSION	TAMBOURINE, 8 INCH	\N	TRE	\N
343	PERCUSSION	TIMBALI	\N	TML	\N
344	PERCUSSION	TIMPANI, 23 INCH	\N	TPT	\N
345	PERCUSSION	TIMPANI, 26 INCH	\N	TPD	\N
346	PERCUSSION	TIMPANI, 29 INCH	\N	TPN	\N
347	PERCUSSION	TIMPANI, 32 INCH	\N	TPW	\N
348	PERCUSSION	TOM, MARCHING	\N	TTM	\N
349	PERCUSSION	TUBANOS	\N	TBN	\N
350	PERCUSSION	WIND CHIMES	\N	WC	\N
351	STRING	ADUNGU	\N	ADG	\N
352	STRING	AEOLIAN HARP	\N	AHP	\N
353	STRING	AUTOHARP	\N	HPA	\N
354	STRING	BALALAIKA	\N	BLK	\N
355	STRING	BANJO	\N	BJ	\N
356	STRING	BANJO CELLO	\N	BJC	\N
357	STRING	BANJO, 4-STRING	\N	BJX	\N
358	STRING	BANJO, 5-STRING	\N	BJY	\N
359	STRING	BANJO, 6-STRING	\N	BJW	\N
360	STRING	BANJO, BASS	\N	BJB	\N
361	STRING	BANJO, BLUEGRASS	\N	BJG	\N
362	STRING	BANJO, PLECTRUM	\N	BJP	\N
363	STRING	BANJO, TENOR	\N	BJT	\N
364	STRING	BANJO, ZITHER	\N	BJZ	\N
365	STRING	CARIMBA	\N	CRM	\N
366	STRING	CELLO, (VIOLONCELLO)	\N	VCL	\N
367	STRING	CELLO, ELECTRIC	\N	VCE	\N
368	STRING	CHAPMAN STICK	\N	CPS	\N
369	STRING	CLAVICHORD	\N	CVC	\N
370	STRING	CLAVINET	\N	CVN	\N
371	STRING	CONTRAGUITAR	\N	GTC	\N
372	STRING	CRWTH, (CROWD)	\N	CRW	\N
373	STRING	DIDDLEY BOW	\N	DDB	\N
374	STRING	DOUBLE BASS	\N	DB	\N
375	STRING	DOUBLE BASS, 5-STRING	\N	DBF	\N
376	STRING	DOUBLE BASS, ELECTRIC	\N	DBE	\N
377	STRING	DULCIMER	\N	DCM	\N
378	STRING	ELECTRIC CYMBALUM	\N	CYE	\N
379	STRING	FIDDLE	\N	FDD	\N
380	STRING	GUITAR SYNTHESIZER	\N	GR	\N
381	STRING	GUITAR, 10-STRING	\N	GRK	\N
382	STRING	GUITAR, 12-STRING	\N	GRL	\N
383	STRING	GUITAR, 7-STRING	\N	GRM	\N
384	STRING	GUITAR, 8-STRING	\N	GRN	\N
385	STRING	GUITAR, 9-STRING	\N	GRP	\N
386	STRING	GUITAR, ACOUSTIC	\N	GRA	\N
387	STRING	GUITAR, ACOUSTIC-ELECTRIC	\N	GRJ	\N
388	STRING	GUITAR, ARCHTOP	\N	GRH	\N
389	STRING	GUITAR, BARITONE	\N	GRR	\N
390	STRING	GUITAR, BAROQUE	\N	GRQ	\N
391	STRING	GUITAR, BASS	\N	GRB	\N
392	STRING	GUITAR, BASS ACOUSTIC	\N	GRG	\N
393	STRING	GUITAR, BRAHMS	\N	GRZ	\N
394	STRING	GUITAR, CLASSICAL	\N	GRC	\N
395	STRING	GUITAR, CUTAWAY	\N	GRW	\N
396	STRING	GUITAR, DOUBLE-NECK	\N	GRD	\N
397	STRING	GUITAR, ELECTRIC	\N	GRE	\N
398	STRING	GUITAR, FLAMENCO	\N	GRF	\N
399	STRING	GUITAR, FRETLESS	\N	GRY	\N
400	STRING	GUITAR, HALF	\N	GRT	\N
401	STRING	GUITAR, OCTAVE	\N	GRO	\N
402	STRING	GUITAR, SEMI-ACOUSTIC	\N	GRX	\N
403	STRING	GUITAR, STEEL	\N	GRS	\N
404	STRING	HARDANGER FIDDLE	\N	FDH	\N
405	STRING	HARMONICO	\N	HMR	\N
406	STRING	HARP	\N	HP	\N
407	STRING	HARP GUITAR	\N	HPG	\N
408	STRING	HARP, ELECTRIC	\N	HPE	\N
409	STRING	HARPSICHORD	\N	HRC	\N
410	STRING	HURDY-GURDY	\N	HG	\N
411	STRING	KORA	\N	KR	\N
412	STRING	KOTO	\N	KT	\N
413	STRING	LOKANGA	\N	LK	\N
414	STRING	LUTE	\N	LT	\N
415	STRING	LUTE GUITAR	\N	LTG	\N
416	STRING	LYRA (BYZANTINE)	\N	LYB	\N
417	STRING	LYRA (CRETAN)	\N	LYC	\N
418	STRING	LYRE	\N	LY	\N
419	STRING	MANDOBASS	\N	MDB	\N
420	STRING	MANDOCELLO	\N	MDC	\N
421	STRING	MANDOLA	\N	MDL	\N
422	STRING	MANDOLIN	\N	MD	\N
423	STRING	MANDOLIN , BUEGRASS	\N	MDX	\N
424	STRING	MANDOLIN , ELECTRIC	\N	MDE	\N
425	STRING	MANDOLIN-BANJO	\N	MDJ	\N
426	STRING	MANDOLIN, OCTAVE	\N	MDO	\N
427	STRING	MANDOLUTE	\N	MDT	\N
428	STRING	MUSICAL BOW	\N	MSB	\N
429	STRING	OCTOBASS	\N	OCB	\N
430	STRING	OUD	\N	OUD	\N
431	STRING	PSALTERY	\N	PS	\N
432	STRING	SITAR	\N	STR	\N
433	STRING	THEORBO	\N	TRB	\N
434	STRING	U-BASS	\N	UB	\N
435	STRING	UKULELE, 5-STRING TENOR	\N	UKF	\N
436	STRING	UKULELE, 6-STRING TENOR	\N	UKX	\N
437	STRING	UKULELE, 8-STRING TENOR	\N	UKW	\N
438	STRING	UKULELE, BARITONE	\N	UKR	\N
439	STRING	UKULELE, BASS	\N	UKB	\N
440	STRING	UKULELE, CONCERT	\N	UKC	\N
441	STRING	UKULELE, CONTRABASS	\N	UKZ	\N
442	STRING	UKULELE, ELECTRIC	\N	UKE	\N
443	STRING	UKULELE, HARP	\N	UKH	\N
444	STRING	UKULELE, LAP STEEL	\N	UKL	\N
445	STRING	UKULELE, POCKET	\N	UKP	\N
446	STRING	UKULELE, SOPRANO	\N	UKS	\N
447	STRING	UKULELE, TENOR	\N	UKT	\N
448	STRING	VIOLA 13 INCH	\N	VLT	\N
449	STRING	VIOLA 16 INCH (FULL)	\N	VL	\N
450	STRING	VIOLA, ELECTRIC	\N	VLE	\N
451	STRING	VIOLIN	\N	VN	\N
452	STRING	VIOLIN, 1/2	\N	VNH	\N
453	STRING	VIOLIN, 1/4	\N	VNQ	\N
454	STRING	VIOLIN, 3/4	\N	VNT	\N
455	STRING	VIOLIN, ELECTRIC	\N	VNE	\N
456	STRING	ZITHER	\N	Z	\N
457	STRING	ZITHER, ALPINE (HARP ZITHER)	\N	ZA	\N
458	STRING	ZITHER, CONCERT	\N	ZC	\N
459	WOODWIND	ALPHORN	\N	ALH	\N
460	WOODWIND	BAGPIPE	\N	BGP	\N
461	WOODWIND	BASSOON	\N	BS	\N
462	WOODWIND	CHALUMEAU	\N	CHM	\N
463	WOODWIND	CLARINET, ALTO IN E FLAT	\N	CLE	\N
464	WOODWIND	CLARINET, B FLAT	CL	CL	\N
465	WOODWIND	CLARINET, BASS	BCL	CLB	\N
466	WOODWIND	CLARINET, BASSET IN A	\N	CLA	\N
467	WOODWIND	CLARINET, CONTRA-ALTO	\N	CLT	\N
468	WOODWIND	CLARINET, CONTRABASS	\N	CLU	\N
469	WOODWIND	CLARINET, PICCOLO IN A FLAT (OR G)	\N	CLC	\N
470	WOODWIND	CLARINET, SOPRANINO IN E FLAT (OR D)	\N	CLS	\N
471	WOODWIND	CONCERTINA	\N	CNT	\N
472	WOODWIND	CONTRABASSOON/DOUBLE BASSOON	\N	BSD	\N
473	WOODWIND	DULCIAN	\N	DLC	\N
474	WOODWIND	DULCIAN, ALTO	\N	DLCA	\N
475	WOODWIND	DULCIAN, BASS	\N	DLCB	\N
476	WOODWIND	DULCIAN, SOPRANO	\N	DLCS	\N
477	WOODWIND	DULCIAN, TENOR	\N	DLCT	\N
478	WOODWIND	DZUMARI	\N	DZ	\N
479	WOODWIND	ENGLISH HORN	\N	CA	\N
480	WOODWIND	FIFE	\N	FF	\N
481	WOODWIND	FLAGEOLET	\N	FGL	\N
482	WOODWIND	FLUTE	FL	FL	\N
483	WOODWIND	FLUTE , NOSE	\N	FLN	\N
484	WOODWIND	FLUTE, ALTO	\N	FLA	\N
485	WOODWIND	FLUTE, BASS	\N	FLB	\N
486	WOODWIND	FLUTE, CONTRA-ALTO	\N	FLX	\N
487	WOODWIND	FLUTE, CONTRABASS	\N	FLC	\N
488	WOODWIND	FLUTE, IRISH	\N	FLI	\N
489	WOODWIND	HARMONICA	\N	HM	\N
490	WOODWIND	HARMONICA, CHROMATIC	\N	HMC	\N
491	WOODWIND	HARMONICA, DIATONIC	\N	HMD	\N
492	WOODWIND	HARMONICA, ORCHESTRAL	\N	HMO	\N
493	WOODWIND	HARMONICA, TREMOLO	\N	HMT	\N
494	WOODWIND	KAZOO	\N	KZO	\N
495	WOODWIND	MELODEON	\N	MLD	\N
496	WOODWIND	MELODICA	\N	ML	\N
497	WOODWIND	MUSETTE DE COUR	\N	MSC	\N
498	WOODWIND	OBOE	OB	OB	\N
499	WOODWIND	OCARINA	\N	OCR	\N
500	WOODWIND	PAN FLUTE	\N	PF	\N
501	WOODWIND	PICCOLO	PC	PC	\N
502	WOODWIND	PIPE ORGAN	\N	PO	\N
503	WOODWIND	PITCH PIPE	\N	PP	\N
504	WOODWIND	RECORDER	\N	R	\N
505	WOODWIND	RECORDER, BASS	\N	RB	\N
506	WOODWIND	RECORDER, CONTRA BASS	\N	RC	\N
507	WOODWIND	RECORDER, DESCANT	\N	RD	\N
508	WOODWIND	RECORDER, GREAT BASS	\N	RG	\N
509	WOODWIND	RECORDER, SOPRANINO	\N	RS	\N
510	WOODWIND	RECORDER, SUBCONTRA BASS	\N	RX	\N
511	WOODWIND	RECORDER, TENOR	\N	RT	\N
512	WOODWIND	RECORDER, TREBLE OR ALTO	\N	RA	\N
513	WOODWIND	ROTHPHONE	\N	RP	\N
514	WOODWIND	ROTHPHONE , ALTO	\N	RPA	\N
515	WOODWIND	ROTHPHONE , BARITONE	\N	RPX	\N
516	WOODWIND	ROTHPHONE , BASS	\N	RPB	\N
517	WOODWIND	ROTHPHONE , SOPRANO	\N	RPS	\N
518	WOODWIND	ROTHPHONE , TENOR	\N	RPT	\N
519	WOODWIND	SARRUSOPHONE	\N	SRP	\N
520	WOODWIND	SAXOPHONE	\N	SX	\N
521	WOODWIND	SAXOPHONE, ALTO	AX	SXA	\N
522	WOODWIND	SAXOPHONE, BARITONE	BX	SXB	\N
523	WOODWIND	SAXOPHONE, BASS	\N	SXY	\N
524	WOODWIND	SAXOPHONE, C MELODY (TENOR IN C)	\N	SXM	\N
525	WOODWIND	SAXOPHONE, C SOPRANO	\N	SXC	\N
526	WOODWIND	SAXOPHONE, CONTRABASS	\N	SXZ	\N
527	WOODWIND	SAXOPHONE, MEZZO-SOPRANO (ALTO IN F)	\N	SXF	\N
528	WOODWIND	SAXOPHONE, PICCOLO (SOPRILLO)	\N	SXP	\N
529	WOODWIND	SAXOPHONE, SOPRANINO	\N	SXX	\N
530	WOODWIND	SAXOPHONE, SOPRANO	\N	SXS	\N
531	WOODWIND	SAXOPHONE, TENOR	TX	SXT	\N
532	WOODWIND	SEMICONTRABASSOON	\N	BSS	\N
533	WOODWIND	WHISTLE, TIN	\N	WT	\N
534	PERCUSSION	BELL KIT	\N	BK	\N
541	ELECTRIC	AMPLIFIER	\N	AM	\N
542	ELECTRIC	AMPLIFIER, BASS	\N	AMB	\N
543	ELECTRIC	AMPLIFIER, GUITAR	\N	AMG	\N
544	ELECTRIC	AMPLIFIER, KEYBOARD	\N	AMK	\N
\.


--
-- TOC entry 3964 (class 0 OID 24850)
-- Dependencies: 250
-- Data for Name: new_instrument; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.new_instrument (id, legacy_number, code, description, serial, state, location, make, model, legacy_code, number, user_name, user_id) FROM stdin;
3	\N	\N	DUMMY 1	DUMMM1	Good	INSTRUMENT STORE	DUMMY MAKER	DUMDUM	\N	\N	\N	\N
8	\N	\N	DUMMY 1	DUMMM1	Good	INSTRUMENT STORE	DUMMY MAKER	DUMDUM	\N	\N	\N	\N
9	\N	\N	DUMMY 1	DUMMM2	Good	INSTRUMENT STORE	DUMMY MAKER	DUMDUM	\N	\N	\N	\N
10	\N	\N	DUMMY 1	DUMMM3	\N	INSTRUMENT STORE	DUMMY MAKER	DUMDUM	\N	\N	\N	\N
11	\N	\N	DUMMY 1	DUMMM4	\N	INSTRUMENT STORE	DUMMY MAKER	\N	\N	\N	\N	\N
\.


--
-- TOC entry 3966 (class 0 OID 25128)
-- Dependencies: 254
-- Data for Name: receive_instrument; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.receive_instrument (id, created_by_id, instrument_id, room) FROM stdin;
\.


--
-- TOC entry 3944 (class 0 OID 24313)
-- Dependencies: 230
-- Data for Name: repair_request; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.repair_request (id, created_at, item_id, complaint) FROM stdin;
\.


--
-- TOC entry 3948 (class 0 OID 24341)
-- Dependencies: 234
-- Data for Name: requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requests (id, created_at, teacher_id, instrument, quantity) FROM stdin;
\.


--
-- TOC entry 3946 (class 0 OID 24327)
-- Dependencies: 232
-- Data for Name: resolve; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.resolve (id, created_at, "case", notes) FROM stdin;
\.


--
-- TOC entry 3942 (class 0 OID 24301)
-- Dependencies: 228
-- Data for Name: returns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.returns (id, created_at, item_id, created_by) FROM stdin;
6	2024-01-31	2129	\N
8	2024-01-31	2129	\N
9	2024-01-31	2129	\N
11	2024-01-31	2129	\N
12	2024-01-31	1494	\N
13	2024-01-31	1494	\N
14	2024-02-01	2129	\N
15	2024-02-01	2129	postgres
16	2024-02-01	1731	postgres
17	2024-02-01	1768	postgres
18	2024-02-01	2072	postgres
19	2024-02-01	1595	postgres
20	2024-02-01	1618	postgres
21	2024-02-01	2072	postgres
22	2024-02-01	2072	postgres
23	2024-02-01	1768	postgres
24	2024-02-01	1618	postgres
25	2024-02-01	1731	postgres
26	2024-02-01	1595	postgres
27	2024-02-15	4166	nochomo
29	2024-02-23	4166	postgres
30	2024-02-23	2129	postgres
31	2024-02-23	2129	postgres
32	2024-02-23	4166	postgres
33	2024-02-23	4166	postgres
34	2024-02-23	4166	postgres
35	2024-02-23	4166	postgres
36	2024-02-23	4166	postgres
37	2024-02-23	4166	postgres
38	2024-02-23	4166	postgres
39	2024-02-23	4166	postgres
40	2024-02-23	4166	postgres
41	2024-02-23	4166	postgres
42	2024-02-23	4166	nochomo
43	2024-02-23	4166	nochomo
44	2024-02-23	4166	nochomo
45	2024-02-23	4166	nochomo
46	2024-02-25	4166	nochomo
47	2024-02-25	4166	nochomo
48	2024-02-25	4166	nochomo
49	2024-02-25	4166	nochomo
50	2024-02-25	4166	nochomo
51	2024-02-25	4166	nochomo
61	2024-02-28	4166	nochomo
62	2024-02-28	4166	nochomo
63	2024-02-28	4166	nochomo
64	2024-03-01	4166	nochomo
65	2024-03-01	4166	nochomo
66	2024-03-01	4166	nochomo
67	2024-03-01	4166	nochomo
68	2024-03-01	4166	nochomo
69	2024-03-02	4166	nochomo
70	2024-03-03	4166	nochomo
71	2024-03-03	4166	nochomo
72	2024-03-03	2129	nochomo
73	2024-03-03	4164	nochomo
74	2024-03-03	4165	nochomo
75	2024-03-03	4166	nochomo
76	2024-03-03	1757	nochomo
77	2024-03-03	1566	nochomo
78	2024-03-03	2098	nochomo
79	2024-03-04	4164	nochomo
80	2024-03-04	4163	nochomo
81	2024-03-04	4164	nochomo
82	2024-03-04	4166	nochomo
83	2024-03-04	4165	nochomo
84	2024-03-04	4164	nochomo
85	2024-03-04	4166	nochomo
86	2024-03-04	4163	nochomo
87	2024-03-04	4165	nochomo
88	2024-03-04	4166	nochomo
89	2024-03-04	4163	nochomo
90	2024-03-04	2129	nochomo
91	2024-03-06	4166	nochomo
92	2024-03-06	4166	nochomo
93	2024-03-06	4166	nochomo
95	2024-03-07	4165	nochomo
96	2024-03-07	4166	nochomo
97	2024-03-07	4166	nochomo
98	2024-03-07	4165	nochomo
\.


--
-- TOC entry 3934 (class 0 OID 24238)
-- Dependencies: 220
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.roles (id, role_name) FROM stdin;
4	STUDENT
5	MUSIC TEACHER
6	INVENTORY MANAGER
7	COMMUNITY
8	ADMIN
10	MUSIC TA
11	SUBSTITUTE
\.


--
-- TOC entry 3952 (class 0 OID 24383)
-- Dependencies: 238
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.students (id, student_number, last_name, first_name, grade_level, parent1_email, parent2_email, division, class, email) FROM stdin;
14	11764	Rosen	Rosa Marie	3	Lollerosen@gmail.com	mikaeldissing@gmail.com	ES	\N	\N
16	11845	Rosen	August	9	Lollerosen@gmail.com	mikaeldissing@gmail.com	HS	\N	\N
17	13077	Abdissa	Dawit	8	addisalemt96@gmail.com	tesemaa@un.org	MS	\N	\N
18	13078	Abdissa	Meron	8	addisalemt96@gmail.com	tesemaa@un.org	MS	\N	\N
19	12966	Andersen	Yohanna Wondim Belachew	1	louian@um.dk	wondim_b@yahoo.com	ES	\N	\N
21	12968	Andersen	Yonas Wondim Belachew	10	louian@um.dk	wondim_b@yahoo.com	HS	\N	\N
23	11881	Camisa	Cassandre	9	katerinelafreniere@hotmail.com	laurentcamisa@hotmail.com	HS	\N	\N
24	12277	Armstrong	Cole	7	stacia.armstrong@ymail.com	patrick.k.armstrong@gmail.com	MS	\N	\N
25	12276	Armstrong	Kennedy	11	stacia.armstrong@ymail.com	patrick.k.armstrong@gmail.com	HS	\N	\N
26	11856	De Backer	Lily	10	camilletanza@yahoo.fr	pierredeb1@gmail.com	HS	\N	\N
27	11801	Kuehnle	Emma	5	jk.payan@gmail.com	jkuehnle@usaid.gov	ES	\N	\N
28	11833	Kuehnle	John (Trey)	7	jk.payan@gmail.com	jkuehnle@usaid.gov	MS	\N	\N
29	12465	Abraha	Rahsi	4	senait.zwerasi@gmail.com	yosiefa@gmail.com	ES	\N	\N
30	12464	Abraha	Siyam	8	senait.zwerasi@gmail.com	yosiefa@gmail.com	MS	\N	\N
31	12463	Abraha	Risty	9	senait.zwerasi@gmail.com	yosiefa@gmail.com	HS	\N	\N
32	12462	Abraha	Seret	12	senait.zwerasi@gmail.com	yosiefa@gmail.com	HS	\N	\N
33	11902	Ashton	Hugo	6	1charlotteashton@gmail.com	todd.ashton@ericsson.com	MS	\N	\N
34	11893	Ashton	Theodore	9	1charlotteashton@gmail.com	todd.ashton@ericsson.com	HS	\N	\N
35	11896	Ashton	Vera	11	1charlotteashton@gmail.com	todd.ashton@ericsson.com	HS	\N	\N
36	11932	Massawe	Nathan	4	kikii.brown78@gmail.com	nmassawe@hotmail.com	ES	\N	\N
37	11933	Massawe	Noah	8	kikii.brown78@gmail.com	nmassawe@hotmail.com	MS	\N	\N
38	12746	Bedein	Ziv	K	bebedein@gmail.com	gilbeinken@gmail.com	ES	\N	\N
39	12615	Bedein	Itai	4	bebedein@gmail.com	gilbeinken@gmail.com	ES	\N	\N
41	12345	Purdy	Annika	2	Mangoshy@yahoo.com	jess_a_purdy@yahoo.com	ES	\N	\N
42	12348	Purdy	Christiaan	5	Mangoshy@yahoo.com	jess_a_purdy@yahoo.com	ES	\N	\N
43	12349	Purdy	Gunnar	8	Mangoshy@yahoo.com	jess_a_purdy@yahoo.com	MS	\N	\N
44	12780	Abou Hamda	Lana	5	hiba_hassan1983@hotmail.com	designcenter2011@live.com	ES	\N	\N
45	12779	Abou Hamda	Samer	8	hiba_hassan1983@hotmail.com	designcenter2011@live.com	MS	\N	\N
46	12778	Abou Hamda	Youssef	11	hiba_hassan1983@hotmail.com	designcenter2011@live.com	HS	\N	\N
47	12075	Andersen	Ida-Marie	12	hanneseverin@hotmail.com	martin.andersen@eeas.europa.eu	HS	\N	\N
48	12497	Cole	Cheryl	12	colevira@gmail.com	acole@unicef.org	HS	\N	\N
49	12247	Bunbury	Oria	K	tammybunbury@gmail.com	robertbunbury@gmail.com	ES	\N	\N
50	12733	Eom	Dawon	10	yinjing7890@gmail.com	ikhyuneom@hotmail.com	HS	\N	\N
51	11925	Mohan	Arnav	12	divyamohan2000@gmail.com	rakmohan1@yahoo.com	HS	\N	\N
52	12188	Roe	Alexander	7	christinarece@gmail.com	aron.roe@international.gc.ca	MS	\N	\N
53	12186	Roe	Elizabeth	9	christinarece@gmail.com	aron.roe@international.gc.ca	HS	\N	\N
54	12535	Lindvig	Freja	5	elisa@lindvig.com	jglindvig@gmail.com	ES	\N	\N
1065	12559	Linck	Hana	12	anitapetitpierre@gmail.com	\N	HS	\N	\N
55	12502	Lindvig	Sif	8	elisa@lindvig.com	jglindvig@gmail.com	MS	\N	\N
56	12503	Lindvig	Mimer	10	elisa@lindvig.com	jglindvig@gmail.com	HS	\N	\N
57	12440	Weurlander	Frida	4	pia.weurlander@gmail.com	matts.weurlander@gmail.com	ES	\N	\N
58	11505	Singh	Zahra	9	ypande@gmail.com	kabirsingh75@gmail.com	HS	\N	\N
59	12206	Zhang	Dylan	1	bonjourchelsea.zz@gmail.com	zhangwei@bucg.cc	ES	\N	\N
60	11838	Aubrey	Carys	8	joaubrey829@gmail.com	dyfed.aubrey@un.org	MS	\N	\N
61	10950	Aubrey	Evie	12	joaubrey829@gmail.com	dyfed.aubrey@un.org	HS	\N	\N
62	11910	Mahmud	Raeed	12	eshajasmine@gmail.com	kmahmud@gmail.com	HS	\N	\N
63	11185	Mekonnen	Kaleb	5	helenabebaw35@gmail.com	m.loulseged@afdb.org	ES	\N	\N
64	11015	Mekonnen	Yonathan	7	helenabebaw35@gmail.com	m.loulseged@afdb.org	MS	\N	\N
65	11793	Mathers	Aya	4	eri77s@gmail.com	nickmathers@gmail.com	ES	\N	\N
66	11110	Mathers	Yui	8	eri77s@gmail.com	nickmathers@gmail.com	MS	\N	\N
67	11468	Gardner	Madeleine	5	michelle.barrett@wfp.org	calum.gardner@wfp.org	ES	\N	\N
69	11362	Russo	Sofia	4	samiaabdul@yahoo.com	andrearux@yahoo.it	ES	\N	\N
70	11361	Russo	Leandro	8	samiaabdul@yahoo.com	andrearux@yahoo.it	MS	\N	\N
73	11724	Murathi	Gerald	4	ngugir@hotmail.com	ammuturi@yahoo.com	ES	\N	\N
74	11735	Murathi	Megan	7	ngugir@hotmail.com	ammuturi@yahoo.com	MS	\N	\N
75	11736	Murathi	Eunice	11	ngugir@hotmail.com	ammuturi@yahoo.com	HS	\N	\N
76	11479	Manzano	Abby Angelica	7	mira_manzano@yahoo.com	jose.manzano@undp.org	MS	\N	\N
15	11763	Rosen	Vilma Doret	6	Lollerosen@gmail.com	mikaeldissing@gmail.com	MS	Beginning Band 7 2023	vrosen30@isk.ac.ke
68	11467	Gardner	Elizabeth	7	michelle.barrett@wfp.org	calum.gardner@wfp.org	MS	Concert Band 2023	egardner29@isk.ac.ke
40	12614	Bedein	Shai	7	bebedein@gmail.com	gilbeinken@gmail.com	MS	Concert Band 2023	sbedein29@isk.ac.ke
89	13005	Alemu	Or	K	esti20022@gmail.com	alemus20022@gmail.com	ES	\N	\N
77	11942	Bellamy	Lillia	3	ahuggins@mercycorps.org	bellamy.paul@gmail.com	ES	\N	\N
78	10319	Ouma	Destiny	8	aouso05@gmail.com	oumajao05@gmail.com	MS	\N	\N
79	12197	Ronzio	Louis	3	janinecocker@gmail.com	jronzio@gmail.com	ES	\N	\N
80	12199	Ronzio	George	7	janinecocker@gmail.com	jronzio@gmail.com	MS	\N	\N
82	24068	Awori	Andre	12	jeawori@gmail.com	jeremyawori@gmail.com	HS	\N	\N
83	12121	Shah	Krishi	10	komal.kevs@gmail.com	keval.shah@cloudhop.it	HS	\N	\N
84	11416	Fisher	Isabella	9	nataliafisheranne@gmail.com	ben.fisher@fcdo.gov.uk	HS	\N	\N
85	11415	Fisher	Charles	11	nataliafisheranne@gmail.com	ben.fisher@fcdo.gov.uk	HS	\N	\N
86	10557	Mwangi	Joy	12	winrose@flexi-personnel.com	wawerujamesmwangi@gmail.com	HS	\N	\N
88	11985	Akuete	Hassan	10	kaycwed@gmail.com	pkakuete@gmail.com	HS	\N	\N
90	13004	Alemu	Leul	5	esti20022@gmail.com	alemus20022@gmail.com	ES	\N	\N
91	12336	Otterstedt	Lisa	12	annika.otterstedt@icloud.com	isak.isaksson@naturskyddsforeningen.se	HS	\N	\N
93	12520	Stott	Helena	9	arineachterstraat@me.com	stottbrian@me.com	HS	\N	\N
94	12521	Stott	Patrick	10	arineachterstraat@me.com	stottbrian@me.com	HS	\N	\N
95	12397	Kimani	Isla	K	rjones@isk.ac.ke	anthonykimani001@gmail.com	ES	\N	\N
96	11788	Van De Velden	Christodoulos	3	smafro@gmail.com	jaapvandevelden@gmail.com	ES	\N	\N
97	10704	Van De Velden	Evangelia	7	smafro@gmail.com	jaapvandevelden@gmail.com	MS	\N	\N
98	11731	Todd	Sofia	2	carli@vovohappilyorganic.com	rich.toddy77@gmail.com	ES	\N	\N
99	11481	Mogilnicki	Dominik	5	aurelia_micko@yahoo.com	milosz.mogilnicki@gmail.com	ES	\N	\N
102	12723	Echalar	Kieran	1	shortjas@gmail.com	ricardo.echalar@gmail.com	ES	\N	\N
103	11882	Echalar	Liam	4	shortjas@gmail.com	ricardo.echalar@gmail.com	ES	\N	\N
104	12750	Wilkes	Nova	PK	aninepier@gmail.com	joshuawilkes@hotmail.co.uk	ES	\N	\N
106	12095	Freiherr Von Handel	Maximilian	11	igiribaldi@hotmail.com	thomas.von.handel@gmail.com	HS	\N	\N
107	11759	Lopez Abella	Lucas	3	monica.lopezconlon@gmail.com	iniakiag@gmail.com	ES	\N	\N
108	11819	Lopez Abella	Mara	5	monica.lopezconlon@gmail.com	iniakiag@gmail.com	ES	\N	\N
109	27007	Miller	Cassius	9	emiller@isk.ac.ke	Angus.miller@fcdo.gov.uk	HS	\N	\N
110	25051	Miller	Albert	11	emiller@isk.ac.ke	Angus.miller@fcdo.gov.uk	HS	\N	\N
111	12753	Rose	Axel	PK	tiarae@rocketmail.com	rosetimothy@gmail.com	ES	\N	\N
112	10843	James	Evelyn	5	tiarae@rocketmail.com	rosetimothy@gmail.com	ES	\N	\N
113	11941	Sudra	Ellis	1	maryleakeysudra@gmail.com	msudra@isk.ac.ke	ES	\N	\N
114	10784	Shah	Arav	7	alpadodhia@gmail.com	whiteicepharmaceuticals@gmail.com	MS	\N	\N
115	12993	Thornton	Lucia	5	emilypt1980@outlook.com	thorntoncr1@state.gov	ES	\N	\N
116	12992	Thornton	Robert	7	emilypt1980@outlook.com	thorntoncr1@state.gov	MS	\N	\N
117	12492	Yun	Jeongu	2	juhee907000@gmail.com	tony.yun80@gmail.com	ES	\N	\N
118	12487	Yun	Geonu	3	juhee907000@gmail.com	tony.yun80@gmail.com	ES	\N	\N
119	11937	Carter	David	8	ksvensson@worldbank.org	miguelcarter.4@gmail.com	MS	\N	\N
120	12970	Willis	Gabrielle	5	tjpeta.willis@gmail.com	pt.willis@bigpond.com	ES	\N	\N
122	11803	Schmidlin Guerrero	Julian	5	ag.guerreroserdan@gmail.com	gaby.juerg@gmail.com	ES	\N	\N
125	10476	Awori	Malaika	8	Annmarieawori@gmail.com	Michael.awori@gmail.com	MS	\N	\N
126	12248	Sagar	Aarav	1	preeti74472@yahoo.com	sagaramit1@gmail.com	ES	\N	\N
127	11592	Sheridan	Indira	10	noush007@hotmail.com	alan.sheridan@wfp.org	HS	\N	\N
128	11591	Sheridan	Erika	12	noush007@hotmail.com	alan.sheridan@wfp.org	HS	\N	\N
129	12798	Andries-Munshi	Téa	K	sarah.andries@gmail.com	neilmunshi@gmail.com	ES	\N	\N
130	12788	Andries-Munshi	Zaha	3	sarah.andries@gmail.com	neilmunshi@gmail.com	ES	\N	\N
131	10841	Wallbridge	Samir	5	awallbridge@isk.ac.ke	tcwallbridge@gmail.com	ES	\N	\N
132	20867	Wallbridge	Lylah	8	awallbridge@isk.ac.ke	tcwallbridge@gmail.com	MS	\N	\N
133	12134	Ansell	Oscar	9	emily.ansell@gmail.com	damon.ansell@gmail.com	HS	\N	\N
134	11852	Ansell	Louise	10	emily.ansell@gmail.com	damon.ansell@gmail.com	HS	\N	\N
136	12625	Harris Ii	Omar	11	tnicoleharris@sbcglobal.net	omarharris@sbcglobal.net	HS	\N	\N
137	11003	Hissink	Boele	5	saskia@dobequity.nl	lodewijkh@gmail.com	ES	\N	\N
138	10683	Hissink	Pomeline	7	saskia@dobequity.nl	lodewijkh@gmail.com	MS	\N	\N
92	12519	Stott	Maartje	6	arineachterstraat@me.com	stottbrian@me.com	MS	Beginning Band 1 2023	mstott30@isk.ac.ke
135	12609	Harris	Owen	6	tnicoleharris@sbcglobal.net	omarharris@sbcglobal.net	MS	Beginning Band 1 2023	oharris30@isk.ac.ke
100	11480	Mogilnicki	Alexander	7	aurelia_micko@yahoo.com	milosz.mogilnicki@gmail.com	MS	Concert Band 2023	amogilnicki29@isk.ac.ke
81	10772	Patel	Cahir	7	nads_k@hotmail.com	samir@aura-capital.com	MS	Concert Band 2023	cpatel29@isk.ac.ke
87	12156	Akuete	Ehsan	8	kaycwed@gmail.com	pkakuete@gmail.com	MS	Concert Band 2023	eakuete28@isk.ac.ke
151	11647	Liban	Ismail	7	shukrih77@gmail.com	aliban@cdc.gov	MS	\N	\N
140	10703	Tanna	Shreya	8	vptanna@gmail.com	priyentanna@gmail.com	MS	\N	\N
141	13049	Clark	Samuel	4	jwang7@ifc.org	davidjclark000@gmail.com	ES	\N	\N
142	12167	Yarkoni	Ohad	3	dvorayarkoni4@gmail.com	yarkan1@yahoo.com	ES	\N	\N
143	12168	Yarkoni	Matan	5	dvorayarkoni4@gmail.com	yarkan1@yahoo.com	ES	\N	\N
144	12169	Yarkoni	Itay	8	dvorayarkoni4@gmail.com	yarkan1@yahoo.com	MS	\N	\N
145	11672	Nguyen	Yen	7	nnguyen@parallelconsultants.com	luu@un.org	MS	\N	\N
146	11671	Nguyen	Binh	9	nnguyen@parallelconsultants.com	luu@un.org	HS	\N	\N
147	11496	Hussain	Shams	3	sajdakhalil@gmail.com	aminmnhussain@gmail.com	ES	\N	\N
148	11495	Hussain	Salam	4	sajdakhalil@gmail.com	aminmnhussain@gmail.com	ES	\N	\N
150	10275	Pozzi	Basile	12	brucama@gmail.com	brucama@gmail.com	HS	\N	\N
152	11666	Ibrahim	Ibrahim	12	shukrih77@gmail.com	aliban@cdc.gov	HS	\N	\N
153	12752	Lopez Salazar	Mateo	K	alopez@isk.ac.ke	\N	ES	\N	\N
154	11242	Godfrey	Benjamin	5	amakagodfrey@gmail.com	drsamgodfrey@yahoo.co.uk	ES	\N	\N
156	11525	Sana	Jamal	11	hadizamounkaila4@gmail.com	moussa.sana@wfp.org	HS	\N	\N
157	12872	Feizzadeh	Saba	4	mahshidtaj88@gmail.com	feizzadeha@unaids.org	ES	\N	\N
158	12871	Feizzadeh	Kasra	9	mahshidtaj88@gmail.com	feizzadeha@unaids.org	HS	\N	\N
159	12201	Fazal	Kayla	6	aleeda@gmail.com	rizwanfazal2013@gmail.com	MS	\N	\N
160	11878	Fazal	Alyssia	8	aleeda@gmail.com	rizwanfazal2013@gmail.com	MS	\N	\N
161	11530	Foster	Chloe	11	Ttruong@isk.ac.ke	Bfoster@isk.ac.ke	HS	\N	\N
162	11582	Miyanue	Joyous	10	knbajia8@gmail.com	tpngwa@gmail.com	HS	\N	\N
163	11583	Nkahnue	Marvelous Peace	12	knbajia8@gmail.com	tpngwa@gmail.com	HS	\N	\N
164	10707	Patella Ross	Rafaelle	7	sarahpatella@icloud.com	bross@unicef.org	MS	\N	\N
165	10617	Patella Ross	Juna	10	sarahpatella@icloud.com	bross@unicef.org	HS	\N	\N
166	12879	Good	Tyler	4	jenniferaharwood@yahoo.com	travistcg@gmail.com	ES	\N	\N
167	12878	Good	Julia	8	jenniferaharwood@yahoo.com	travistcg@gmail.com	MS	\N	\N
168	11723	Biesiada	Maria-Antonina (Jay)	10	magda.biesiada@gmail.com	\N	HS	\N	\N
169	10980	Nannes	Ben	9	pamela@terrasolkenya.com	sjaak@terrasolkenya.com	HS	\N	\N
170	11520	Hajee	Kaiam	5	jhajee@isk.ac.ke	khalil.hajee@gmail.com	ES	\N	\N
171	11542	Hajee	Kadin	7	jhajee@isk.ac.ke	khalil.hajee@gmail.com	MS	\N	\N
172	11541	Hajee	Kahara	8	jhajee@isk.ac.ke	khalil.hajee@gmail.com	MS	\N	\N
173	10688	Gebremedhin	Maria	6	donicamerhazion@gmail.com	mgebremedhin@gmail.com	MS	\N	\N
174	12003	Copeland	Rainey	12	susancopeland@gmail.com	charlescopeland@gmail.com	HS	\N	\N
177	11936	Ndinguri	Zawadi	5	muriithifiona@gmail.com	joramgatei@gmail.com	ES	\N	\N
178	24001	De Jong	Max	11	anouk.paauwe@gmail.com	rob.jong@un.org	HS	\N	\N
179	12372	Davis - Arana	Maximiliano	1	majo.arana@gmail.com	nick.diallo@gmail.com	ES	\N	\N
180	12797	Nicolau Meganck	Emilia	K	nicolau.joana@gmail.com	joana.olivier2016@gmail.com	ES	\N	\N
182	10968	Anding	Zane	11	ganding@isk.ac.ke	manding@isk.ac.ke	HS	\N	\N
183	11940	Rogers	Otis	1	laoisosullivan@yahoo.com.au	mrogers@isk.ac.ke	ES	\N	\N
184	12744	Rogers	Liam	PK	laoisosullivan@yahoo.com.au	mrogers@isk.ac.ke	ES	\N	\N
185	10972	Wood	Teagan	9	carriewoodtz@gmail.com	cwood.ken@gmail.com	HS	\N	\N
186	10934	Wood	Caitlin	11	carriewoodtz@gmail.com	cwood.ken@gmail.com	HS	\N	\N
187	10632	Masrani	Anusha	8	shrutimasrani@gmail.com	rupinmasrani@gmail.com	MS	\N	\N
188	10641	Handa	Jin	10	jinln-2009@163.com	jinzhe322406@gmail.com	HS	\N	\N
189	10279	Fest	Lina	11	marilou_de_wit@hotmail.com	michel.fest@gmail.com	HS	\N	\N
190	10278	Fest	Marie	11	marilou_de_wit@hotmail.com	michel.fest@gmail.com	HS	\N	\N
191	11830	Ramrakha	Divyaan	7	leenagehlot@gmail.com	rishiramrakha@gmail.com	MS	\N	\N
192	11379	Ramrakha	Niyam	10	leenagehlot@gmail.com	rishiramrakha@gmail.com	HS	\N	\N
193	11404	Jayaram	Akeyo	3	sonali.murthy@gmail.com	kartik_j@yahoo.com	ES	\N	\N
195	10320	Sapta	Gendhis	8	vanda.andromeda@yahoo.com	sapta.hendra@yahoo.com	MS	\N	\N
196	12706	Venkataya	Kianna	4	e.venkataya@gmail.com	\N	ES	\N	\N
197	11627	Line	Taegan	7	emeraldcardinal7@gmail.com	kris.line@ice.dhs.gov	MS	\N	\N
198	11626	Line	Bronwyn	9	emeraldcardinal7@gmail.com	kris.line@ice.dhs.gov	HS	\N	\N
199	11625	Line	Jamison	11	emeraldcardinal7@gmail.com	kris.line@ice.dhs.gov	HS	\N	\N
200	10788	Mujuni	Tangaaza	7	barbara.bamanya@gmail.com	benardmujuni@gmail.com	MS	\N	\N
201	20828	Mujuni	Rugaba	10	barbara.bamanya@gmail.com	benardmujuni@gmail.com	HS	\N	\N
202	20805	Guyard Suengas	Laia	11	tetxusu@gmail.com	\N	HS	\N	\N
331	10977	Bamlango	Lucile	6	leabamlango@gmail.com	bamlango@gmail.com	MS	Beginning Band 8 - 2023	lbamlango30@isk.ac.ke
149	11469	Hussain	Tawheed	6	sajdakhalil@gmail.com	aminmnhussain@gmail.com	MS	Beginning Band 1 2023	thussain30@isk.ac.ke
181	10967	Anding	Florencia	8	ganding@isk.ac.ke	manding@isk.ac.ke	MS	Concert Band 2023	fanding28@isk.ac.ke
155	11227	Godfrey	Tobias	7	amakagodfrey@gmail.com	drsamgodfrey@yahoo.co.uk	MS	Concert Band 2023	tgodfrey29@isk.ac.ke
211	11570	Ahmed	Zeeon	12	nahreen.farjana@gmail.com	ahmedzu@gmail.com	HS	\N	\N
204	27066	Haswell	Emily	8	ahaswell@isk.ac.ke	danhaswell@hotmail.co.uk	MS	\N	\N
205	12444	Dalla Vedova Sanjuan	Yago	12	felasanjuan13@gmail.com	giovanni.dalla-vedova@ericsson.com	HS	\N	\N
206	10973	Choda	Ariana	10	gabriele@sunworldsafaris.com	dchoda22@gmail.com	HS	\N	\N
207	10974	Schmid	Isabella	11	aschmid@isk.ac.ke	sschmid@isk.ac.ke	HS	\N	\N
208	10975	Schmid	Sophia	11	aschmid@isk.ac.ke	sschmid@isk.ac.ke	HS	\N	\N
209	13043	Ernst	Kai	K	andreaernst@gmail.com	ebaimu@gmail.com	ES	\N	\N
210	11628	Ernst	Aika	3	andreaernst@gmail.com	ebaimu@gmail.com	ES	\N	\N
213	11705	Varga	Amira	5	hugi.ev@gmail.com	\N	ES	\N	\N
214	12835	Veverka	Jonah	K	cveverka@usaid.gov	jveverka@usaid.gov	ES	\N	\N
215	12838	Veverka	Theocles	2	cveverka@usaid.gov	jveverka@usaid.gov	ES	\N	\N
216	12441	Sankoh	Adam-Angelo	3	ckoroma@unicef.org	baimankay.sankoh@wfp.org	ES	\N	\N
217	11098	Mittelstadt	Mwende	10	mmaingi84@gmail.com	joel@meridian.co.ke	HS	\N	\N
218	20780	Charette	Miles	9	mdimitracopoulos@isk.ac.ke	acharette@isk.ac.ke	HS	\N	\N
219	20781	Charette	Tea	12	mdimitracopoulos@isk.ac.ke	acharette@isk.ac.ke	HS	\N	\N
220	12963	Giblin	Drew (Tilly)	2	kloehr@gmail.com	drewgiblin@gmail.com	ES	\N	\N
221	12964	Giblin	Auberlin (Addie)	7	kloehr@gmail.com	drewgiblin@gmail.com	MS	\N	\N
222	11199	Burns	Ryan	12	sburns@isk.ac.ke	Johnburnskenya@gmail.com	HS	\N	\N
223	12457	Jama	Bella	1	katie.elles@gmail.com	jama.artan@gmail.com	ES	\N	\N
224	12452	Jama	Ari	3	katie.elles@gmail.com	jama.artan@gmail.com	ES	\N	\N
225	11572	Marriott	Isaiah	12	sibilawsonmarriott@gmail.com	rkmarriott@gmail.com	HS	\N	\N
226	11751	Byrne-Ilako	Sianna	11	ailish.byrne@crs.org	james10s@aol.com	HS	\N	\N
227	12360	Teel	Camden	4	destiny1908@hotmail.com	bernard1906@hotmail.com	ES	\N	\N
228	12361	Teel	Jaidyn	6	destiny1908@hotmail.com	bernard1906@hotmail.com	MS	\N	\N
230	12793	Eshetu	Lukas	9	olga.petryniak@gmail.com	kassahun.wossene@gmail.com	HS	\N	\N
231	11511	Okanda	Dylan	9	indiakk@yahoo.com	mbauro@gmail.com	HS	\N	\N
232	11599	Blaschke	Sasha	4	cmcmorrison@gmail.com	sean.blaschke@gmail.com	ES	\N	\N
233	11052	Blaschke	Kaitlyn	6	cmcmorrison@gmail.com	sean.blaschke@gmail.com	MS	\N	\N
234	12789	Marin Fonseca Choucair Ramos	Georges	3	jmarin@ifc.org	ychoucair@hotmail.com	ES	\N	\N
235	11575	Kobayashi	Maaya	5	kobayashiyoko8@gmail.com	jdasilva66@gmail.com	ES	\N	\N
236	11943	Hansen Meiro	Isabel	5	mmeirolorenzo@gmail.com	keithehansen@gmail.com	ES	\N	\N
237	11568	Eckert-Crosse	Finley	4	ekarleckert@gmail.com	billycrosse@gmail.com	ES	\N	\N
238	10941	Bajwa	Mohammad Haroon	8	akbarfarzana12@gmail.com	mabajwa@unicef.org	MS	\N	\N
239	10511	Suther	Erik	7	ansuther@hotmail.com	dansuther@hotmail.com	MS	\N	\N
240	11792	Chandaria	Aarav	4	preenas@gmail.com	vijaychandaria@gmail.com	ES	\N	\N
241	10338	Chandaria	Aarini Vijay	9	preenas@gmail.com	vijaychandaria@gmail.com	HS	\N	\N
242	11526	Korvenoja	Leo	11	tita.korvenoja@gmail.com	korvean@gmail.com	HS	\N	\N
243	10881	Mathew	Mandisa	12	bhattacharjee.parinita@gmail.com	aniljmathew@gmail.com	HS	\N	\N
244	12158	Ahmed	Hafsa	8	zahraaden@gmail.com	yassinoahmed@gmail.com	MS	\N	\N
245	12159	Ahmed	Mariam	8	zahraaden@gmail.com	yassinoahmed@gmail.com	MS	\N	\N
246	11745	Ahmed	Osman	12	zahraaden@gmail.com	yassinoahmed@gmail.com	HS	\N	\N
247	12116	Steel	Tessa	10	dianna.kopansky@un.org	derek@ramco.co.ke	HS	\N	\N
248	11442	Steel	Ethan	12	dianna.kopansky@un.org	derek@ramco.co.ke	HS	\N	\N
249	11271	Otieno	Brianna	8	maureenagengo@gmail.com	jotieno@isk.ac.ke	MS	\N	\N
250	13042	Bid	Sohum	K	snehalbid@gmail.com	rahulbid23@gmail.com	ES	\N	\N
252	12173	Janmohamed	Yara	4	nabila.wissanji@gmail.com	gj@jansons.co.za	ES	\N	\N
253	12174	Janmohamed	Aila	8	nabila.wissanji@gmail.com	gj@jansons.co.za	MS	\N	\N
254	12208	Rogers	Rwenzori	4	sorogers@usaid.gov	drogers@usaid.gov	ES	\N	\N
255	12209	Rogers	Junin	5	sorogers@usaid.gov	drogers@usaid.gov	ES	\N	\N
256	11879	Schoneveld	Jasmine	3	nicoliendelange@hotmail.com	georgeschoneveld@gmail.com	ES	\N	\N
257	11444	Kefela	Hiyabel	12	mehari.kefela@palmoil.co.ke	akberethabtay2@gmail.com	HS	\N	\N
258	12416	Manji	Arra	4	tnathoo@gmail.com	allymanji@gmail.com	ES	\N	\N
259	12108	Shah	Deesha	10	hemapiyu@yahoo.com	priyesh@eazy-group.com	HS	\N	\N
260	10770	Rughani	Sidh	9	priticrughani@gmail.com	cirughani@gmail.com	HS	\N	\N
261	12124	Chandaria	Sohil	10	avni@stjohnslodge.com	hc@kincap.com	HS	\N	\N
262	12275	Patel	Imara	11	bindyaracing@hotmail.com	patelsatyan@hotmail.com	HS	\N	\N
263	11437	Wissanji	Riyaan	10	rwissanji@gmail.com	shaheed.wissanji@sopalodges.com	HS	\N	\N
264	11440	Wissanji	Mikayla	12	rwissanji@gmail.com	shaheed.wissanji@sopalodges.com	HS	\N	\N
265	12270	Bwonya	Leti	12	faith.bwonya@gmail.com	\N	HS	\N	\N
304	12286	Landolt	Stefanie	6	nadia.landolt@yahoo.com	jclandolt@icrc.org	MS	Beginning Band 8 - 2023	slandolt30@isk.ac.ke
251	11706	Bid	Arhum	6	snehalbid@gmail.com	rahulbid23@gmail.com	MS	Beginning Band 1 2023	abid30@isk.ac.ke
212	10696	Okwany	Hawi	7	bijaflowers@yahoo.com	stonekidi@yahoo.com	MS	Concert Band 2023	hokwany29@isk.ac.ke
266	11491	Kurauchi	Mairi	3	yuko.kurauchi@gmail.com	kunal.chandaria@gmail.com	ES	\N	\N
267	10932	Chandaria	Meiya	5	yuko.kurauchi@gmail.com	kunal.chandaria@gmail.com	ES	\N	\N
269	12531	Inwani	Aiden	11	cirablue@gmail.com	\N	HS	\N	\N
270	10774	Shah	Nirvaan	12	bsshah1@gmail.com	bhartesh1@gmail.com	HS	\N	\N
272	11401	Butt	Ziya	9	flalani-butt@isk.ac.ke	sameer.butt@outlook.com	HS	\N	\N
273	11839	Shamji	Sofia	8	farah@aaagrowers.co.ke	ariff@aaagrowers.co.ke	MS	\N	\N
274	11472	Tall	Oumi	5	jgacheke@isk.ac.ke	pmtall@gmail.com	ES	\N	\N
276	10487	Price-Abdi	Yasmin	12	Suzyyprice@yahoo.com	yusufhas@gmail.com	HS	\N	\N
277	11704	Fort	Kaitlyn	3	kellymaura@gmail.com	brycelfort@gmail.com	ES	\N	\N
279	10637	Raja	Keiya	8	nlpwithshilpa@gmail.com	neeraj@raja.org.uk	MS	\N	\N
280	10955	Shah	Ryka	12	bshah63@gmail.com	pk64shah@gmail.com	HS	\N	\N
281	12278	Muoki	Ruby	11	angelawokabi11@gmail.com	jmuoki@outlook.com	HS	\N	\N
282	25072	Chandaria	Siana	11	rupalbid@gmail.com	bchandaria@gmail.com	HS	\N	\N
283	11877	Wangari	Tatyana	12	yndungu@gmail.com	\N	HS	\N	\N
284	11190	Shah	Sohan	12	diyasohan@gmail.com	bhavan@cpshoes.com	HS	\N	\N
285	10416	Nanji	Zameer	9	Narmeen_r@yahoo.com	zahid@abc-place.com	HS	\N	\N
286	11326	Paul	Esther	8	Megpaul47@icloud.Com	\N	MS	\N	\N
287	10430	Sanders	Liam	10	angelaferrsan@gmail.com	jpsanders32@gmail.com	HS	\N	\N
288	10431	Sanders	Teresa	12	angelaferrsan@gmail.com	jpsanders32@gmail.com	HS	\N	\N
289	12132	Melson	Sarah	9	metmel@um.dk	clausmelson@gmail.com	HS	\N	\N
290	12229	Kurji	Kaysan Karim	3	shabz.karmali1908@gmail.com	shaukatali@primecuts.co.ke	ES	\N	\N
291	11768	Doshi	Ashi	4	adoshi@wave.co.ke	vdoshi@wave.co.ke	ES	\N	\N
292	10636	Doshi	Anay	8	adoshi@wave.co.ke	vdoshi@wave.co.ke	MS	\N	\N
293	12731	Bini	Bianca	2	boschettiraffaella@gmail.com	boschettiraffaella@gmail.com	ES	\N	\N
294	11535	Cutler	Otis	4	megseyjackson@gmail.com	adrianhcutler@gmail.com	ES	\N	\N
296	10673	Cutler	Leo	9	megseyjackson@gmail.com	adrianhcutler@gmail.com	HS	\N	\N
297	20866	Wachira	Andrew	10	suzielawrence@yahoo.co.uk	lawrence.githinji@ke.atlascopco.com	HS	\N	\N
298	11884	Nzioka	Jordan	2	bmusyoka@isk.ac.ke	nziokarobert.rn@gmail.com	ES	\N	\N
299	11313	Nzioka	Zuriel	4	bmusyoka@isk.ac.ke	nziokarobert.rn@gmail.com	ES	\N	\N
300	10865	Otieno	Radek Tidi	5	alividza@isk.ac.ke	eotieno@isk.ac.ke	ES	\N	\N
301	10943	Otieno	Ranam Telu	5	alividza@isk.ac.ke	eotieno@isk.ac.ke	ES	\N	\N
302	10866	Otieno	Riani Tunu	5	alividza@isk.ac.ke	eotieno@isk.ac.ke	ES	\N	\N
303	10715	Weaver	Sachin	11	rebeccajaneweaver@gmail.com	\N	HS	\N	\N
306	12284	Landolt	Mark	8	nadia.landolt@yahoo.com	jclandolt@icrc.org	MS	\N	\N
307	10247	Ruiz Stannah	Kianu	7	ruizstannah@gmail.com	stephen.stannah@un.org	MS	\N	\N
308	25032	Ruiz Stannah	Tamia	11	ruizstannah@gmail.com	stephen.stannah@un.org	HS	\N	\N
309	11611	Noordin	Ahmad Eissa	4	iman@thenoordins.com	nadeem.noordin@copycatgroup.com	ES	\N	\N
310	12194	Herman-Roloff	Lily	3	amykateherman@hotmail.com	khermanroloff@gmail.com	ES	\N	\N
311	12195	Herman-Roloff	Shela	5	amykateherman@hotmail.com	khermanroloff@gmail.com	ES	\N	\N
313	10800	Baheta	Bruke	8	Thadera@hotmail.com	dbaheta@unicef.org	MS	\N	\N
314	20766	Baheta	Helina	11	Thadera@hotmail.com	dbaheta@unicef.org	HS	\N	\N
315	11040	Bjornholm	Jonathan	11	sbjornholm@me.com	ulf.bjornholm@un.org	HS	\N	\N
316	11574	Vellenga	Rose	4	kristenmaddock@hotmail.co.uk	Rvellenga@unicef.org	ES	\N	\N
317	11573	Vellenga	Solomon	5	kristenmaddock@hotmail.co.uk	Rvellenga@unicef.org	ES	\N	\N
318	11255	Patel	Ishaan	4	priya@ramco.co.ke	amit@ramco.co.ke	ES	\N	\N
319	11843	Clements	Ciaran	8	jill.a.clements@gmail.com	shanedanielricketts@gmail.com	MS	\N	\N
320	12332	Nair	Ahana	1	pinkilika@gmail.com	gautamn@techno-associates.co.ke	ES	\N	\N
321	11729	Pattni	Aryaan	4	azmina@vicbank.com	yogesh@vicbank.com	ES	\N	\N
322	11200	Boxer	Hana	11	mboxer@isk.ac.ke	bendboxer@hotmail.com	HS	\N	\N
323	10993	Shah	Parth	10	KAUSHISHAH@HOTMAIL.COM	KBS.KIFARU@GMAIL.COM	HS	\N	\N
325	11263	Khubchandani	Layla	9	ramji.farzana@gmail.com	rishi.khubchandani@gmail.com	HS	\N	\N
326	12494	Patel	Nikhil	1	shruti.bahety@gmail.com	akithpatel@gmail.com	ES	\N	\N
327	10830	Shah	Janak	11	nishshah@hotmail.co.uk	nipshah@dunhillconsulting.com	HS	\N	\N
328	10645	Tunbridge	Saba	12	louise.tunbridge@gmail.com	\N	HS	\N	\N
329	11777	Manek	Shriya	11	devika@maneknet.com	jay@maneknet.com	HS	\N	\N
330	12371	Bamlango	Diane	K	leabamlango@gmail.com	bamlango@gmail.com	ES	\N	\N
271	11402	Butt	Ayana	6	flalani-butt@isk.ac.ke	sameer.butt@outlook.com	MS	Beginning Band 1 2023	abutt30@isk.ac.ke
278	11650	Fort	Connor	6	kellymaura@gmail.com	brycelfort@gmail.com	MS	Beginning Band 7 2023	cfort30@isk.ac.ke
268	11265	Simbiri	Ochieng	6	sandra.simbiri@gmail.com	davidsimbiri@gmail.com	MS	Beginning Band 1 2023	osimbiri30@isk.ac.ke
275	11515	Tall	Fatuma	8	jgacheke@isk.ac.ke	pmtall@gmail.com	MS	Concert Band 2023	ftall28@isk.ac.ke
305	12285	Landolt	Jana	8	nadia.landolt@yahoo.com	jclandolt@icrc.org	MS	Concert Band 2023	jlandolt28@isk.ac.ke
333	10979	Bamlango	Cecile	11	leabamlango@gmail.com	bamlango@gmail.com	HS	\N	\N
334	20839	Patel	Vanaaya	9	sunira29@gmail.com	umang@vegpro-group.com	HS	\N	\N
335	20840	Patel	Veer	9	sunira29@gmail.com	umang@vegpro-group.com	HS	\N	\N
336	11502	Shah	Laina	4	skhamar77@gmail.com	sonaars@gmail.com	ES	\N	\N
337	10965	Shah	Savir	7	skhamar77@gmail.com	sonaars@gmail.com	MS	\N	\N
338	11789	Vestergaard	Nikolaj	3	psarasas@gmail.com	o.vestergaard@gmail.com	ES	\N	\N
340	11445	Allport	Kian	12	shelina@safari-mania.com	rallport75@gmail.com	HS	\N	\N
341	12094	Hagelberg	Reid	9	Lisa@virginbushsafaris.com	niklas.hagelberg@un.org	HS	\N	\N
342	12077	Hagelberg	Zoe Rose	11	Lisa@virginbushsafaris.com	niklas.hagelberg@un.org	HS	\N	\N
343	12354	Kimmelman-May	Juju	4	shannon.k.may@gmail.com	jay.kimmelman@gmail.com	ES	\N	\N
344	12353	Kimmelman-May	Chloe	8	shannon.k.may@gmail.com	jay.kimmelman@gmail.com	MS	\N	\N
345	11452	Uberoi	Tara	11	alpaub@hotmail.com	moby@sivoko.com	HS	\N	\N
346	24018	Mwenya	Chansa	12	mwansachishimba10@yahoo.co.uk	kasonde.mwenya@un.org	HS	\N	\N
347	11486	Patel	Liam	4	rajul@ramco.co.ke	hasit@ramco.co.ke	ES	\N	\N
348	10138	Patel	Shane	8	rajul@ramco.co.ke	hasit@ramco.co.ke	MS	\N	\N
349	26025	Patel	Rhiyana	10	rajul@ramco.co.ke	hasit@ramco.co.ke	HS	\N	\N
350	10334	Pattni	Yash	7	poonampatt@gmail.com	pulin@anmoljewellers.biz	MS	\N	\N
351	11179	Samani	Gaurav	5	pooja@amsproperties.com	rupen@amsgroup.co.ke	ES	\N	\N
352	11180	Samani	Siddharth	5	pooja@amsproperties.com	rupen@amsgroup.co.ke	ES	\N	\N
353	10791	Bhandari	Kiara	9	srbhandari406@gmail.com	avnish@intercool.co.ke	HS	\N	\N
354	12224	Monadjem	Safa	3	shekufehk@yahoo.com	bmonadjem@gmail.com	ES	\N	\N
355	25076	Monadjem	Malaika	11	shekufehk@yahoo.com	bmonadjem@gmail.com	HS	\N	\N
356	11858	Khagram	Sam	10	karen@khagram.org	vishal@riftcot.com	HS	\N	\N
357	10786	Shah	Radha	7	reena23sarit@gmail.com	sarit.shah@saritcentre.com	MS	\N	\N
358	10796	Shah	Vishnu	10	reena23sarit@gmail.com	sarit.shah@saritcentre.com	HS	\N	\N
360	12013	Khan	Cuyuni	10	sheila.aggarwalkhan@gmail.com	seanadriankhan@gmail.com	HS	\N	\N
362	12131	Inglis	Lengai	9	lieslkareninglis@gmail.com	\N	HS	\N	\N
364	20875	Yohannes	Mathias	10	sewit.a@gmail.com	biniam.yohannes@gmail.com	HS	\N	\N
366	12129	Arora	Avish	9	kulpreet.vikram@gmail.com	aroravikramsingh@gmail.com	HS	\N	\N
367	10504	Bommadevara	Saptha Girish	10	malini.hemamalini@gmail.com	bvramana@hotmail.com	HS	\N	\N
368	10505	Bommadevara	Sharmila Devi	12	malini.hemamalini@gmail.com	bvramana@hotmail.com	HS	\N	\N
370	12309	Sangare	Adama	11	taissata@yahoo.fr	sangnouh@yahoo.fr	HS	\N	\N
372	11945	Trottier	Gabrielle	9	gabydou123@hotmail.com	ftrotier@hotmail.com	HS	\N	\N
373	11485	Suri	Mannat	4	shipra.unhabitat@gmail.com	suri.raj@gmail.com	ES	\N	\N
374	11076	Suri	Armaan	7	shipra.unhabitat@gmail.com	suri.raj@gmail.com	MS	\N	\N
375	11101	Furness	Zoe	12	terrifurness@gmail.com	tim@amanzi.ke	HS	\N	\N
377	12442	Tshomo	Tandin	7	sangdema@gmail.com	kpenjor@unicef.org	MS	\N	\N
378	12394	Zangmo	Thuji	8	sangdema@gmail.com	kpenjor@unicef.org	MS	\N	\N
379	10878	Berezhny	Maxym	9	lubashara078@gmail.com	oles@berezhny.net	HS	\N	\N
380	11744	Higgins	Thomas	10	katehiggins77@yahoo.com	kevanphiggins@gmail.com	HS	\N	\N
381	11743	Higgins	Louisa	12	katehiggins77@yahoo.com	kevanphiggins@gmail.com	HS	\N	\N
382	12244	Startup	Indhira	2	s.mai.rattanavong@gmail.com	joshstartup@gmail.com	ES	\N	\N
383	11389	Lindgren	Anyamarie	8	annewendy13@gmail.com	jalsweden@gmail.com	MS	\N	\N
385	12854	Plunkett	Takumi	8	makiplunkett@live.jp	jplun585@gmail.com	MS	\N	\N
386	11556	Gagnidze	Catherina	12	laramief@yahoo.com	LEVGAG@YAHOO.COM	HS	\N	\N
387	11676	Jama	Adam	2	lucky74f@gmail.com	hargeisa1000@gmail.com	ES	\N	\N
388	11675	Jama	Amina	4	lucky74f@gmail.com	hargeisa1000@gmail.com	ES	\N	\N
389	12757	Jama	Guled	6	lucky74f@gmail.com	hargeisa1000@gmail.com	MS	\N	\N
390	12211	Salituri	Noha	1	bakermelissamarie@gmail.com	jpsalituri@hotmail.com	ES	\N	\N
391	12212	Salituri	Amaia	4	bakermelissamarie@gmail.com	jpsalituri@hotmail.com	ES	\N	\N
392	12213	Salituri	Leone	4	bakermelissamarie@gmail.com	jpsalituri@hotmail.com	ES	\N	\N
393	12214	Thongmod	Sorawit (Nico)	5	bakermelissamarie@gmail.com	jpsalituri@hotmail.com	ES	\N	\N
394	11860	Makimei	Henk	12	MariaTwerda@redcross.org.uk	ig.makimei2014@gmail.com	HS	\N	\N
359	11264	Shah	Anaiya	6	heena1joshi25@yahoo.co.uk	jilan21@hotmail.com	MS	Beginning Band 7 2023	ashah30@isk.ac.ke
371	11944	Trottier	Lilyrose	6	gabydou123@hotmail.com	ftrotier@hotmail.com	MS	Beginning Band 7 2023	ltrottier30@isk.ac.ke
361	12133	Inglis	Lorian	6	lieslkareninglis@gmail.com	\N	MS	Beginning Band 7 2023	linglis30@isk.ac.ke
332	10978	Bamlango	Anne	8	leabamlango@gmail.com	bamlango@gmail.com	MS	Concert Band 2023	abamlango28@isk.ac.ke
365	12130	Arora	Arjan	8	kulpreet.vikram@gmail.com	aroravikramsingh@gmail.com	MS	Concert Band 2023	aarora28@isk.ac.ke>
363	10787	Yohannes	Naomi	7	sewit.a@gmail.com	biniam.yohannes@gmail.com	MS	Concert Band 2023	nyohannes29@isk.ac.ke
395	11175	Maldonado	Mira	10	smaldonado@isk.ac.ke	mam27553@yahoo.com	HS	\N	\N
396	11170	Maldonado	Che	12	smaldonado@isk.ac.ke	mam27553@yahoo.com	HS	\N	\N
397	11261	Nguyen	Phuong An	4	vietha.sbvhn@gmail.com	hnguyen@isk.ac.ke	ES	\N	\N
399	12705	Smith	Charlotte	4	asarahday@gmail.com	randysmith@usaid.gov	ES	\N	\N
400	12719	Von Strauss	Olivia	1	malin.vonstrauss@gmail.com	adam.ojdahl@gmail.com	ES	\N	\N
401	11009	Petrangeli	Gabriel	12	ivanikolicinkampala@yahoo.com	junior.antonio@sobetrainternational.com	HS	\N	\N
402	11951	Hwang	Jihwan	5	choijungh83@gmail.com	cs5085.hwang@samsung.com	ES	\N	\N
403	12377	Hornor	Anneka	10	schlesingermaria@gmail.com	chris@powerhive.com	HS	\N	\N
404	12008	Veveiros	Florencia	5	julie.veveiros5@gmail.com	aveveiros@yahoo.com	ES	\N	\N
405	12009	Veveiros	Xavier	10	julie.veveiros5@gmail.com	aveveiros@yahoo.com	HS	\N	\N
406	11786	Clark	Laras	3	agniparamita@gmail.com	samueltclark@gmail.com	ES	\N	\N
407	11787	Clark	Galuh	7	agniparamita@gmail.com	samueltclark@gmail.com	MS	\N	\N
408	12267	Schwabel	Miriam	12	kschwabel@gmail.com	jasones99@gmail.com	HS	\N	\N
410	12113	Gremley	Ben	10	emmagremley@gmail.com	andrewgremley@gmail.com	HS	\N	\N
411	12115	Gremley	Calvin	10	emmagremley@gmail.com	andrewgremley@gmail.com	HS	\N	\N
412	12546	Baig-Giannotti	Danial	1	giannotti76@yahoo.it	khbaig@yahoo.com	ES	\N	\N
413	11593	Baig-Giannotti	Daria	4	giannotti76@yahoo.it	khbaig@yahoo.com	ES	\N	\N
414	12071	Jackson	Ciara	11	laurajfrost@gmail.com	stephenwjackson@gmail.com	HS	\N	\N
415	12806	Nelson	Ansley	1	kmctamney@gmail.com	nelsonex1080@gmail.com	ES	\N	\N
416	12803	Nelson	Caroline	4	kmctamney@gmail.com	nelsonex1080@gmail.com	ES	\N	\N
417	12658	Wanyoike	Tamara	11	lois.wanyoike@gmail.com	joe.wanyoike@gmail.com	HS	\N	\N
418	12437	Cowan	Marcella	8	cowseal@aol.com	cowanjc@state.gov	MS	\N	\N
419	11717	Sommerlund	Alisia	7	sommerlundsurat@yahoo.com	sommerlu@unhcr.org	MS	\N	\N
420	12507	Castel-Wang	Lea	10	weiyangwang88@gmail.com	\N	HS	\N	\N
421	12707	Som Chaudhuri	Anisha	4	deyshr@gmail.com	dchaudhuri@ifc.org	ES	\N	\N
422	12067	Jacques	Gloria	11	deuwba@hotmail.com	pageja1@hotmail.com	HS	\N	\N
423	11938	Nurshaikhova	Dana	9	alma.nurshaikhova@gmail.com	\N	HS	\N	\N
424	12161	Shah	Raheel	8	bhavisha@eazy-group.com	neel@eazy-group.com	MS	\N	\N
425	20850	Shah	Rohan	10	bhavisha@eazy-group.com	neel@eazy-group.com	HS	\N	\N
426	11395	Burmester	Malou	5	Margs.Burmester@hotmail.com	mads.burmester@hotmail.com	ES	\N	\N
427	11394	Burmester	Nicholas	8	Margs.Burmester@hotmail.com	mads.burmester@hotmail.com	MS	\N	\N
429	11702	Sengendo	Ethan	10	jusmug@yahoo.com	e.sennoga@afdb.org	HS	\N	\N
430	12443	Osman	Omer	1	rwan.adil13@gmail.com	hishammsalih@gmail.com	ES	\N	\N
431	12238	Jensen	Felix	2	arietajensen@gmail.com	dannje@um.dk	ES	\N	\N
432	12237	Jensen	Fiona	3	arietajensen@gmail.com	dannje@um.dk	ES	\N	\N
433	11462	Gerba	Andrew	7	erin.gerba@gmail.com	mogerba2@gmail.com	MS	\N	\N
434	11507	Gerba	Madigan	9	erin.gerba@gmail.com	mogerba2@gmail.com	HS	\N	\N
435	11449	Gerba	Porter	11	erin.gerba@gmail.com	mogerba2@gmail.com	HS	\N	\N
436	11800	Atamuradov	Aaron	5	businka2101@gmail.com	atamoura@unhcr.org	ES	\N	\N
437	11752	Atamuradova	Arina	11	businka2101@gmail.com	atamoura@unhcr.org	HS	\N	\N
438	12792	Yoon	Seojun	7	japark1981@naver.com	yoonzie@gmail.com	MS	\N	\N
439	12791	Yoon	Seohyeon	9	japark1981@naver.com	yoonzie@gmail.com	HS	\N	\N
440	11387	Allard Ruiz	Sasha	12	katiadesouza@sobetrainternational.com	\N	HS	\N	\N
441	12910	Alnaqbi	Ali	2	emaraty_a99@hotmail.com	emaraty353@hotmail.com	ES	\N	\N
443	12908	Alnaqbi	Almayasa	7	emaraty_a99@hotmail.com	emaraty353@hotmail.com	MS	\N	\N
444	12907	Alnaqbi	Fatima	9	emaraty_a99@hotmail.com	emaraty353@hotmail.com	HS	\N	\N
445	12906	Alnaqbi	Ibrahim	10	emaraty_a99@hotmail.com	emaraty353@hotmail.com	HS	\N	\N
446	12396	Jabbour	Rasmus	1	anna.kontorov@gmail.com	jason.jabbour@gmail.com	ES	\N	\N
447	12395	Jabbour	Olivia	4	anna.kontorov@gmail.com	jason.jabbour@gmail.com	ES	\N	\N
448	12308	Allen	Tobin	9	beth1421@hotmail.com	jeff_allen_1@yahoo.com	HS	\N	\N
449	12307	Allen	Corinne	12	beth1421@hotmail.com	jeff_allen_1@yahoo.com	HS	\N	\N
450	12643	Ben Anat	Maya	PK	benanatim@gmail.com	benanatim25@gmail.com	ES	\N	\N
451	11475	Ben Anat	Ella	5	benanatim@gmail.com	benanatim25@gmail.com	ES	\N	\N
452	11518	Ben Anat	Shira	8	benanatim@gmail.com	benanatim25@gmail.com	MS	\N	\N
453	12489	Mishra	Amishi	12	sumananjali@gmail.com	prafulla2001@gmail.com	HS	\N	\N
454	12488	Mishra	Arushi	12	sumananjali@gmail.com	prafulla2001@gmail.com	HS	\N	\N
455	11488	O'neill Calver	Riley	4	laraoneill@gmail.com	timcalver@gmail.com	ES	\N	\N
457	11534	Norman	Lukas	10	hambrouc@unhcr.org	johannorman62@gmail.com	HS	\N	\N
458	11533	Norman	Lise	12	hambrouc@unhcr.org	johannorman62@gmail.com	HS	\N	\N
398	11260	Nguyen	Phuc Anh	6	vietha.sbvhn@gmail.com	hnguyen@isk.ac.ke	MS	Beginning Band 1 2023	pnguyen30@isk.ac.ke
409	12393	Gremley	Aiden	7	emmagremley@gmail.com	andrewgremley@gmail.com	MS	Concert Band 2023	agremley29@isk.ac.ke
508	24043	Sims	Ella	12	kwest@mac.com	oscar.sims@mac.com	HS	\N	\N
459	11446	Wikenczy Thomsen	Sebastian	11	swikenczy@yahoo.com	anders_thomsen@yahoo.com	HS	\N	\N
460	11758	Foley	Logan Lilly	3	koech.maureen@gmail.com	MPFoley@icloud.com	ES	\N	\N
461	12376	Mills	James	11	staceyinvienna@gmail.com	pmills27@yahoo.com	HS	\N	\N
462	11820	Goold	Amira	5	lizagoold@hotmail.co.uk	alistairgoold@hotmail.com	ES	\N	\N
464	11527	Shenge	Micaella	6	uangelique@gmail.com	kaganzielly@gmail.com	MS	\N	\N
465	12338	Huber	Siri	5	griet.kenis@gmail.com	thorsten.huber@giz.de	ES	\N	\N
466	12339	Huber	Lisa	9	griet.kenis@gmail.com	thorsten.huber@giz.de	HS	\N	\N
467	12340	Huber	Jara	10	griet.kenis@gmail.com	thorsten.huber@giz.de	HS	\N	\N
468	12764	O'hearn	Case	7	ohearnek7@gmail.com	ohearn4@msn.com	MS	\N	\N
469	12763	O'hearn	Maeve	10	ohearnek7@gmail.com	ohearn4@msn.com	HS	\N	\N
470	11375	Chigudu	Komborero	5	memoshiri@yahoo.co.uk	vchigudu@yahoo.co.uk	ES	\N	\N
471	11376	Chigudu	Munashe	8	memoshiri@yahoo.co.uk	vchigudu@yahoo.co.uk	MS	\N	\N
472	11373	Chigudu	Nyasha	11	memoshiri@yahoo.co.uk	vchigudu@yahoo.co.uk	HS	\N	\N
473	12271	Sakaedani Petrovic	Kodjiro	11	asakaedani@unicef.org	opetrovic@unicef.org	HS	\N	\N
474	12522	Essoungou	Ines Clelia	10	maymuchka@yahoo.com	essoungou@gmail.com	HS	\N	\N
475	12562	Mcsharry	Caspian	5	emmeline@mcsharry.net	patrick@mcsharry.net	ES	\N	\N
476	12563	Mcsharry	Theodore	9	emmeline@mcsharry.net	patrick@mcsharry.net	HS	\N	\N
477	12073	Exel	Joshua	10	kexel@usaid.gov	jexel@worldbank.org	HS	\N	\N
478	12074	Exel	Hannah	12	kexel@usaid.gov	jexel@worldbank.org	HS	\N	\N
479	11569	Vutukuru	Sumedh Vedya	12	schodavarapu@ifc.org	vvutukuru@worldbank.org	HS	\N	\N
480	11657	Mabaso	Nyasha	5	loicemabaso@icloud.com	tmabaso@icao.int	ES	\N	\N
481	12323	Young	Jack	8	dyoung1462@gmail.com	dianeandjody@yahoo.com	MS	\N	\N
482	12378	Young	Annie	11	dyoung1462@gmail.com	dianeandjody@yahoo.com	HS	\N	\N
483	11892	Peck	Sofia	12	andrea.m.peck@gmail.com	robert.b.peck@gmail.com	HS	\N	\N
485	12062	O'hara	Elia	11	siemerm@hotmail.com	corykohara@gmail.com	HS	\N	\N
486	12200	Friedman	Becca	5	jennysansfer@yahoo.com	\N	ES	\N	\N
487	11700	Murape	Nandipha	11	tmurape@unicef.org	lloydmurape@gmail.com	HS	\N	\N
488	11630	Van Der Vliet	Sarah	7	lauretavdva@gmail.com	janisvliet@gmail.com	MS	\N	\N
489	11629	Van Der Vliet	Grecy	12	lauretavdva@gmail.com	janisvliet@gmail.com	HS	\N	\N
490	12421	Giri	Maila	3	lisebendiksen@gmail.com	rgiri@unicef.org	ES	\N	\N
491	12410	Giri	Rohan	10	lisebendiksen@gmail.com	rgiri@unicef.org	HS	\N	\N
492	13041	Kasahara	Ao	K	miho.a.yonekura@gmail.com	aito.kasahara@sumitomocorp.com	ES	\N	\N
493	12250	Laurits	Leonard	1	emily.laurits@gmail.com	eric.laurits@gmail.com	ES	\N	\N
494	12249	Laurits	Charlotte	3	emily.laurits@gmail.com	eric.laurits@gmail.com	ES	\N	\N
495	11761	Jansson	Kai	3	sawanakagawa@gmail.com	torjansson@gmail.com	ES	\N	\N
497	12363	Hansen	Ines Elise	2	metteojensen@gmail.com	thomasnikolaj@hotmail.com	ES	\N	\N
498	12365	Hansen	Marius	6	metteojensen@gmail.com	thomasnikolaj@hotmail.com	MS	\N	\N
499	11145	Choi	Minseo	4	shy_cool@naver.com	flymax2002@hotmail.com	ES	\N	\N
501	12637	Tassew	Abigail	3	faithmekuria24@gmail.com	tassew@gmail.com	ES	\N	\N
502	12636	Tassew	Nathan	10	faithmekuria24@gmail.com	tassew@gmail.com	HS	\N	\N
503	12867	Johnson	Catherine	1	bobbiejohnsonbjj@gmail.com	donovanshanej@gmail.com	ES	\N	\N
504	12866	Johnson	Brycelyn	6	bobbiejohnsonbjj@gmail.com	donovanshanej@gmail.com	MS	\N	\N
505	12865	Johnson	Azzalina	10	bobbiejohnsonbjj@gmail.com	donovanshanej@gmail.com	HS	\N	\N
506	12103	Raja	Aaditya	10	darshanaraja@aol.com	praja42794@aol.com	HS	\N	\N
509	20843	Priestley	Leila	11	samela.priestley@gmail.com	mark.priestley@trademarkea.com	HS	\N	\N
510	25038	Piper	Saron	11	piperlilly@gmail.com	piperben@gmail.com	HS	\N	\N
511	12574	Mazibuko	Maxwell	10	mazibukos@yahoo.com	\N	HS	\N	\N
512	12573	Mazibuko	Naledi	10	mazibukos@yahoo.com	\N	HS	\N	\N
513	12575	Mazibuko	Sechaba	10	mazibukos@yahoo.com	\N	HS	\N	\N
514	12257	Raval	Ananya	1	prakrutidevang@icloud.com	devang.raval1990@gmail.com	ES	\N	\N
515	10333	Donohue	Christopher Ross	7	adriennedonohue@gmail.com	crdonohue@gmail.com	MS	\N	\N
516	12111	Cooney	Luna	3	mireillefc@gmail.com	danielcooney@gmail.com	ES	\N	\N
517	12110	Cooney	Maïa	10	mireillefc@gmail.com	danielcooney@gmail.com	HS	\N	\N
519	12154	Materne	Danaé	9	nat.dekeyser@gmail.com	fredmaterne@hotmail.com	HS	\N	\N
520	10495	Dale	Ameya	11	gdale@isk.ac.ke	jdale@isk.ac.ke	HS	\N	\N
521	11232	Hire	Arthur	4	jhire@isk.ac.ke	bhire@isk.ac.ke	ES	\N	\N
618	12342	O'bra	Kai	6	hbobra@gmail.com	bcobra@gmail.com	MS	Beginning Band 8 - 2023	kobra30@isk.ac.ke
484	12063	O'hara	Luke	6	siemerm@hotmail.com	corykohara@gmail.com	MS	Beginning Band 7 2023	lohara30@isk.ac.ke
507	10657	Mehta	Ansh	7	mehtakrishnay@gmail.com	ymehta@cevaltd.com	MS	Concert Band 2023	amehta29@isk.ac.ke
463	11836	Goold	Isla	8	lizagoold@hotmail.co.uk	alistairgoold@hotmail.com	MS	Concert Band 2023	igoold28@isk.ac.ke
523	10676	Sekar	Akshith	10	rsekar1999@yahoo.com	rekhasekar@yahoo.co.in	HS	\N	\N
524	11464	Lloyd	Elsa	7	apaolo@isk.ac.ke	bobcoulibaly@yahoo.com	MS	\N	\N
525	12191	Firzé Al Ghaoui	Laé	5	agnaima@gmail.com	olivierfirze@gmail.com	ES	\N	\N
527	11461	Quacquarella	Alessia	5	lisa_limahken@yahoo.com	q_gioik@hotmail.com	ES	\N	\N
528	12268	Ledgard	Hamish	12	marta_ledgard@mzv.cz	eternaut@icloud.com	HS	\N	\N
529	12742	Shahbal	Sophia	K	kaitlin.hillis@gmail.com	saud.shahbal@gmail.com	ES	\N	\N
530	12712	Shahbal	Saif	2	kaitlin.hillis@gmail.com	saud.shahbal@gmail.com	ES	\N	\N
531	11854	Rwehumbiza	Jonathan	10	abakilana@worldbank.org	abakilana@worldbank.org	HS	\N	\N
532	11897	Eidex	Simone	11	waterlily6970@gmail.com	\N	HS	\N	\N
533	11484	Schenck	Alston	4	prillakrone@gmail.com	schenck.mills@bcg.com	ES	\N	\N
535	12306	Hopps	Troy	3	rharrison90@gmail.com	jasonhopps@gmail.com	ES	\N	\N
536	10477	Hughes	Noah	11	ahughes@isk.ac.ke	ethiopiashaun@gmail.com	HS	\N	\N
537	12303	Njenga	Maximus	2	stephanienjenga@gmail.com	njengaj@state.gov	ES	\N	\N
538	12279	Njenga	Sadie	5	stephanienjenga@gmail.com	njengaj@state.gov	ES	\N	\N
540	12281	Njenga	Justin	10	stephanienjenga@gmail.com	njengaj@state.gov	HS	\N	\N
544	11898	Jensen	Daniel	10	amag32@gmail.com	jonathon.jensen@gmail.com	HS	\N	\N
545	12357	Thibodeau	Maya	8	gerry@grayemail.com	ace@thibodeau.com	MS	\N	\N
546	11552	De Vries Aguirre	Lorenzo	9	pangolinaty@yahoo.com	mmgoez1989@gmail.com	HS	\N	\N
547	11551	De Vries Aguirre	Marco	12	pangolinaty@yahoo.com	mmgoez1989@gmail.com	HS	\N	\N
548	12620	Saleem	Adam	2	anna.saleem.hogberg@gov.se	saleembaha@gmail.com	ES	\N	\N
550	11605	Abdellahi	Emir	11	knwazota@ifc.org	\N	HS	\N	\N
551	11912	O'neal	Maliah	8	onealp1@yahoo.com	onealap@state.gov	MS	\N	\N
552	11906	Kraemer	Caio	9	leticiarc73@gmail.com	eduardovk03@gmail.com	HS	\N	\N
553	11907	Kraemer	Isabela	12	leticiarc73@gmail.com	eduardovk03@gmail.com	HS	\N	\N
554	11780	Bannikau	Eva	4	lenusia@hotmail.com	elena.sahlin@gov.se	ES	\N	\N
555	12291	Prawitz	Alba	2	camillaprawitz@gmail.com	peter.nilsson@scb.se	ES	\N	\N
556	12298	Prawitz	Max	5	camillaprawitz@gmail.com	peter.nilsson@scb.se	ES	\N	\N
557	12297	Prawitz	Leo	6	camillaprawitz@gmail.com	peter.nilsson@scb.se	MS	\N	\N
558	12060	Holder	Abigail	5	nickandstephholder@gmail.com	stephiemiddleton@hotmail.com	ES	\N	\N
559	12059	Holder	Charles	11	nickandstephholder@gmail.com	stephiemiddleton@hotmail.com	HS	\N	\N
560	12056	Holder	Isabel	12	nickandstephholder@gmail.com	stephiemiddleton@hotmail.com	HS	\N	\N
561	12656	Ansorg	Sebastian	7	katy.agg@gmail.com	tansorg@gmail.com	MS	\N	\N
562	12655	Ansorg	Leon	11	katy.agg@gmail.com	tansorg@gmail.com	HS	\N	\N
563	12217	Bosch	Pilar	K	jasmin.gohl@gmail.com	luis.bosch@outlook.com	ES	\N	\N
564	12218	Bosch	Moira	2	jasmin.gohl@gmail.com	luis.bosch@outlook.com	ES	\N	\N
565	12219	Bosch	Blanca	4	jasmin.gohl@gmail.com	luis.bosch@outlook.com	ES	\N	\N
566	11678	Ross	Aven	7	skeddington@yahoo.com	sross78665@gmail.com	MS	\N	\N
568	12231	Herbst	Kai	2	magdaa002@hotmail.com	torstenherbst@hotmail.com	ES	\N	\N
569	12230	Herbst	Sofia	4	magdaa002@hotmail.com	torstenherbst@hotmail.com	ES	\N	\N
570	12179	Bierly	Michael	8	abierly02@gmail.com	BierlyJE@state.gov	MS	\N	\N
571	11802	Stephens	Miya	5	mwatanabe1@worldbank.org	mstephens@worldbank.org	ES	\N	\N
573	11686	Joo	Jihong	10	ruvigirl@icloud.com	jeongje.joo@gmail.com	HS	\N	\N
574	11685	Joo	Hyojin	12	ruvigirl@icloud.com	jeongje.joo@gmail.com	HS	\N	\N
575	12358	Sottsas	Bruno	4	sinxayvoravong@hotmail.com	ssottsas@worldbank.org	ES	\N	\N
576	12359	Sottsas	Natasha	7	sinxayvoravong@hotmail.com	ssottsas@worldbank.org	MS	\N	\N
577	12525	Gandhi	Krishna	10	gayatri.gandhi0212@gmail.com	gandhi.harish@gmail.com	HS	\N	\N
578	12524	Gandhi	Hrushikesh	12	gayatri.gandhi0212@gmail.com	gandhi.harish@gmail.com	HS	\N	\N
579	12490	Leon	Max	12	andrealeon@gmx.de	m.d.lance007@gmail.com	HS	\N	\N
580	12775	Korngold	Myra	5	yenyen321@gmail.com	korngold.caleb@gmail.com	ES	\N	\N
581	12773	Korngold	Mila Ruth	7	yenyen321@gmail.com	korngold.caleb@gmail.com	MS	\N	\N
582	12223	Tarquini	Alexander	4	caroline.bird@wfp.org	drmarcellotarquini@gmail.com	ES	\N	\N
583	10602	Abukari	Marian	7	moprissy@gmail.com	m.abukari@ME.com	MS	\N	\N
584	10672	Abukari	Manuela	9	moprissy@gmail.com	m.abukari@ME.com	HS	\N	\N
585	12470	Mansourian	Soren	1	braedenr@gmail.com	hani.mansourian@gmail.com	ES	\N	\N
586	12081	Caminha	Zecarun	6	sunita1214@gmail.com	zesopolcaminha@gmail.com	MS	Beginning Band 1 2023	zcaminha30@isk.ac.ke
541	10566	Zucca	Fatima	6	mariacristina.zucca@gmail.com	\N	MS	Beginning Band 8 - 2023	fazucca30@isk.ac.ke
539	12280	Njenga	Grace	7	stephanienjenga@gmail.com	njengaj@state.gov	MS	Concert Band 2023	gnjenga29@isk.ac.ke
526	12190	Firzé Al Ghaoui	Natéa	7	agnaima@gmail.com	olivierfirze@gmail.com	MS	Concert Band 2023	nfirzealghaoui29@isk.ac.ke
587	12079	Caminha	Manali	9	sunita1214@gmail.com	zesopolcaminha@gmail.com	HS	\N	\N
589	12894	Leca Turner	Nomi	PK	lecalaurianne@yahoo.co.uk	ejamturner@yahoo.com	ES	\N	\N
590	12893	Leca Turner	Enzo	1	lecalaurianne@yahoo.co.uk	ejamturner@yahoo.com	ES	\N	\N
591	12162	Karuga	Kelsie	6	irene.karuga2@gmail.com	karugafamily@gmail.com	MS	\N	\N
592	12163	Karuga	Kayla	8	irene.karuga2@gmail.com	karugafamily@gmail.com	MS	\N	\N
593	12897	Jones-Avni	Tamar	K	erinjonesavni@gmail.com	danielgavni@gmail.com	ES	\N	\N
594	12784	Jones-Avni	Dov	2	erinjonesavni@gmail.com	danielgavni@gmail.com	ES	\N	\N
595	12783	Jones-Avni	Nahal	4	erinjonesavni@gmail.com	danielgavni@gmail.com	ES	\N	\N
596	12504	Godden	Noa	5	martinettegodden@gmail.com	kieranrgodden@gmail.com	ES	\N	\N
597	12479	Godden	Emma	9	martinettegodden@gmail.com	kieranrgodden@gmail.com	HS	\N	\N
598	12478	Godden	Lisa	10	martinettegodden@gmail.com	kieranrgodden@gmail.com	HS	\N	\N
599	12882	Acharya	Ella	1	isk@kuttaemail.com	thaipeppers2020@gmail.com	ES	\N	\N
600	12881	Acharya	Anshi	7	isk@kuttaemail.com	thaipeppers2020@gmail.com	MS	\N	\N
601	12722	Hardy	Clara	1	rlbeckster@yahoo.com	jamesphardy211@gmail.com	ES	\N	\N
602	11958	Dara	Safari	4	yndege@gmail.com	dara_andrew@yahoo.com	ES	\N	\N
603	12305	Koucheravy	Moira	4	grace.koucheravy@gmail.com	patrick.e.koucheravy@gmail.com	ES	\N	\N
604	12304	Koucheravy	Carys	8	grace.koucheravy@gmail.com	patrick.e.koucheravy@gmail.com	MS	\N	\N
605	12258	Germain	Edouard	11	mel_laroche1@hotmail.com	alexgermain69@hotmail.com	HS	\N	\N
606	12259	Germain	Jacob	11	mel_laroche1@hotmail.com	alexgermain69@hotmail.com	HS	\N	\N
607	12293	Aung	Lynn Htet	5	lwint@unhcr.org	lwinkyawkyaw@gmail.com	ES	\N	\N
608	12302	Thu	Phyo Nyein Nyein	7	lwint@unhcr.org	lwinkyawkyaw@gmail.com	MS	\N	\N
610	10119	Patel	Ronan	8	vbeiner@isk.ac.ke	nilesh140@hotmail.com	MS	\N	\N
611	10746	Asamoah	Annabel	11	msuya.eunice1@gmail.com	Samuelasamoah4321@gmail.com	HS	\N	\N
612	12085	Duwyn	Teo	5	angeladuwyn@gmail.com	dduwyn@gmail.com	ES	\N	\N
613	12086	Duwyn	Mia	9	angeladuwyn@gmail.com	dduwyn@gmail.com	HS	\N	\N
614	12028	Van Bommel	Cato	11	jorismarij@hotmail.com	joris-van.bommel@minbuza.nl	HS	\N	\N
615	12698	Raehalme	Henrik	1	johanna.raehalme@gmail.com	raehalme@gmail.com	ES	\N	\N
616	12697	Raehalme	Emilia	5	johanna.raehalme@gmail.com	raehalme@gmail.com	ES	\N	\N
619	12341	O'bra	Asara	9	hbobra@gmail.com	bcobra@gmail.com	HS	\N	\N
620	12449	Lee	Seonu	3	eduinun@gmail.com	stuff0521@gmail.com	ES	\N	\N
621	10953	Davis	Maya	12	jdavis@isk.ac.ke	matt.davis@crs.org	HS	\N	\N
623	12050	Bruhwiler	Anika	12	bruehome@gmail.com	mbruhwiler@ifc.org	HS	\N	\N
624	12678	Jovanovic	Mila	5	jjovanovic@unicef.org	milansgml@gmail.com	ES	\N	\N
625	12677	Jovanovic	Dunja	8	jjovanovic@unicef.org	milansgml@gmail.com	MS	\N	\N
626	12740	Walji	Elise	2	marlouswergerwalji@gmail.com	shafranw@gmail.com	ES	\N	\N
627	12739	Walji	Felyne	3	marlouswergerwalji@gmail.com	shafranw@gmail.com	ES	\N	\N
628	12765	Jacob	Dechen	7	namgya@gmail.com	vinodkjacobpminy@gmail.com	MS	\N	\N
629	12766	Jacob	Tenzin	11	namgya@gmail.com	vinodkjacobpminy@gmail.com	HS	\N	\N
630	12324	Touré	Fatoumata	4	adja_samb@yahoo.fr	cheikhtoure@hotmail.com	ES	\N	\N
631	12325	Touré	Ousmane	5	adja_samb@yahoo.fr	cheikhtoure@hotmail.com	ES	\N	\N
632	12642	Khayat De Andrade	Helena	PK	nathaliakhayat@gmail.com	orestejunior@gmail.com	ES	\N	\N
633	12650	Khayat De Andrade	Sophia	1	nathaliakhayat@gmail.com	orestejunior@gmail.com	ES	\N	\N
634	12762	Nitcheu	Maelle	PK	lilimakole@yahoo.fr	georges.nitcheu@gmail.com	ES	\N	\N
635	12415	Nitcheu	Margot	2	lilimakole@yahoo.fr	georges.nitcheu@gmail.com	ES	\N	\N
636	12417	Nitcheu	Marion	3	lilimakole@yahoo.fr	georges.nitcheu@gmail.com	ES	\N	\N
637	11939	Fernstrom	Eva	5	anushika00@hotmail.com	erik_fernstrom@yahoo.se	ES	\N	\N
638	12831	Barragan Sofrony	Sienna	K	angelica.sofrony@gmail.com	barraganc@un.org	ES	\N	\N
639	12711	Barragan Sofrony	Gael	3	angelica.sofrony@gmail.com	barraganc@un.org	ES	\N	\N
641	11837	Jansen	William	8	sjansen@usaid.gov	tmjjansen@hotmail.com	MS	\N	\N
642	11855	Jansen	Matias	10	sjansen@usaid.gov	tmjjansen@hotmail.com	HS	\N	\N
643	12827	Maagaard	Siri	4	pil_larsen@hotmail.com	chmaagaard@live.dk	ES	\N	\N
644	12826	Maagaard	Laerke	9	pil_larsen@hotmail.com	chmaagaard@live.dk	HS	\N	\N
645	12647	Jin	Chae Hyun	PK	h.lee2@afdb.org	jinseungsoo@gmail.com	ES	\N	\N
646	12246	Jin	A-Hyun	2	h.lee2@afdb.org	jinseungsoo@gmail.com	ES	\N	\N
647	11329	Fundaro	Pietro	10	bethroca9@gmail.com	funroc@gmail.com	HS	\N	\N
648	11847	Onderi	Jade	9	ligamic@gmail.com	nathan.mabeya@gmail.com	HS	\N	\N
649	11810	Kimatrai	Nikhil	9	aditikimatrai@gmail.com	ranjeevkimatrai@gmail.com	HS	\N	\N
650	11809	Kimatrai	Rhea	9	aditikimatrai@gmail.com	ranjeevkimatrai@gmail.com	HS	\N	\N
651	10313	Ireri	Kennedy	9	mwebi@unhcr.org	\N	HS	\N	\N
609	10561	Patel	Olivia	6	vbeiner@isk.ac.ke	nilesh140@hotmail.com	MS	Beginning Band 1 2023	opatel30@isk.ac.ke
617	11822	Friedhoff Jaeschke	Naia	7	heike_friedhoff@hotmail.com	thomas.jaeschke.e@outlook.com	MS	Concert Band 2023	nfriedhoffjaeschke29@isk.ac.ke
745	12830	Abshir	Kaynan	K	nada.abshir@gmail.com	\N	ES	\N	\N
652	11335	Taneem	Farzin	7	mahfuhai@gmail.com	taneem.a@gmail.com	MS	\N	\N
653	11336	Taneem	Umaiza	8	mahfuhai@gmail.com	taneem.a@gmail.com	MS	\N	\N
654	12808	Mothobi	Oagile	1	shielamothobi@gmail.com	imothobi@gmail.com	ES	\N	\N
655	12807	Mothobi	Resegofetse	4	shielamothobi@gmail.com	imothobi@gmail.com	ES	\N	\N
657	12429	Wittmann	Soline	10	benedicte.wittmann@yahoo.fr	christophewittmann@yahoo.fr	HS	\N	\N
658	12704	Muziramakenga	Mateo	1	kristina.leuchowius@gmail.com	lionel.muzira@gmail.com	ES	\N	\N
659	12703	Muziramakenga	Aiden	4	kristina.leuchowius@gmail.com	lionel.muzira@gmail.com	ES	\N	\N
660	12602	Carver Wildig	Charlie	5	zoe.wildig@gmail.com	freddie.carver@gmail.com	ES	\N	\N
661	12601	Carver Wildig	Barney	7	zoe.wildig@gmail.com	freddie.carver@gmail.com	MS	\N	\N
662	12787	Park	Jijoon	2	hypakuo@gmail.com	joonwoo.park@undp.org	ES	\N	\N
663	12786	Park	Jooan	4	hypakuo@gmail.com	joonwoo.park@undp.org	ES	\N	\N
664	12745	Hercberg	Zohar	PK	avigili3012@gmail.com	avigili3012@gmail.com	ES	\N	\N
665	12680	Hercberg	Amitai	3	avigili3012@gmail.com	avigili3012@gmail.com	ES	\N	\N
667	12682	Hercberg	Uriya	7	avigili3012@gmail.com	avigili3012@gmail.com	MS	\N	\N
668	12776	Carter	Rafael	8	ksvensson@worldbank.org	miguelcarter.4@gmail.com	MS	\N	\N
670	12242	Arora	Vihaan	2	miss.sikka@gmail.com	yash2201@gmail.com	ES	\N	\N
671	12990	Crandall	Sofia	12	mariama1@mac.com	mail@billcrandall.com	HS	\N	\N
672	13061	Ihsan	Almaira	5	tyuwono@worldbank.org	aihsan@gmail.com	ES	\N	\N
673	13060	Ihsan	Rayyan	7	tyuwono@worldbank.org	aihsan@gmail.com	MS	\N	\N
674	13063	Ihsan	Zakhrafi	11	tyuwono@worldbank.org	aihsan@gmail.com	HS	\N	\N
675	12579	Thomas	Alexander	11	claire@go-two-one.net	sunfish62@gmail.com	HS	\N	\N
677	12921	Dove	Ruth	9	meganlpdove@gmail.com	stephencarterdove@gmail.com	HS	\N	\N
678	12920	Dove	Samuel	11	meganlpdove@gmail.com	stephencarterdove@gmail.com	HS	\N	\N
679	12588	Ngumi	Alvin	11	rsituma@yahoo.com	\N	HS	\N	\N
680	13100	Handler	Julia	6	lholley@gmail.com	nhandler@gmail.com	MS	\N	\N
681	12592	Maguire	Josephine	8	carybmaguire@gmail.com	spencer.maguire@gmail.com	MS	\N	\N
682	12593	Maguire	Theodore	10	carybmaguire@gmail.com	spencer.maguire@gmail.com	HS	\N	\N
683	13027	Kasymbekova Tauras	Deniza	5	aisuluukasymbekova@yahoo.com	ttauras@gmail.com	ES	\N	\N
684	12669	Assefa	Amman	8	selamh27@yahoo.com	Assefaft@Gmail.com	MS	\N	\N
685	12822	Maasdorp Mogollon	Lucas	1	inamogollon@gmail.com	maasdorp@gmail.com	ES	\N	\N
686	12821	Maasdorp Mogollon	Gabriela	4	inamogollon@gmail.com	maasdorp@gmail.com	ES	\N	\N
687	13064	Daines	Dallin	2	foreverdaines143@gmail.com	dainesy@gmail.com	ES	\N	\N
688	13084	Daines	Caleb	4	foreverdaines143@gmail.com	dainesy@gmail.com	ES	\N	\N
690	12833	Mccown	Gabriel	K	nickigreenlee@gmail.com	andrew.mccown@gmail.com	ES	\N	\N
691	12837	Mccown	Clea	2	nickigreenlee@gmail.com	andrew.mccown@gmail.com	ES	\N	\N
692	12916	Stock	Beckham	2	rydebstock@hotmail.com	stockr2@state.gov	ES	\N	\N
694	12914	Stock	Payton	11	rydebstock@hotmail.com	stockr2@state.gov	HS	\N	\N
696	13021	Reza	Ruhan	7	ruintoo@gmail.com	areza@usaid.gov	MS	\N	\N
697	12802	Sankar	Nandita	3	sankarpr@state.gov	\N	ES	\N	\N
698	13059	Kavaleuski	Ian	10	kavaleuskaya@gmail.com	m.kavaleuskaya@gmail.com	HS	\N	\N
700	12673	Ghelani-Decorte	Kian	8	rghelani14@gmail.com	decorte@un.org	MS	\N	\N
701	12690	Abdurazakov	Elrad	6	abdurazakova@un.org	akmal.abdurazakov@gmail.com	MS	\N	\N
702	12724	Kamara	Malik	1	rdagash@gmail.com	kamara1ster@gmail.com	ES	\N	\N
703	12863	Diehl	Ethan	PK	mlegg85@gmail.com	adiehl1@gmail.com	ES	\N	\N
704	12864	Diehl	Malcolm	1	mlegg85@gmail.com	adiehl1@gmail.com	ES	\N	\N
705	12710	Mosher	Elena	1	anabgonzalez@gmail.com	james.mosher@gmail.com	ES	\N	\N
706	12709	Mosher	Emma	3	anabgonzalez@gmail.com	james.mosher@gmail.com	ES	\N	\N
707	13092	Magassouba	Abibatou	2	mnoel.fall@gmail.com	mmagass9@gmail.com	ES	\N	\N
708	12989	Bomba	Sada	11	williams.kristi@gmail.com	khalid.bomba@gmail.com	HS	\N	\N
709	13054	Ishikawa	Tamaki	3	n2project@cobi.jp	ishikawan@un.org	ES	\N	\N
710	12475	Walls	Colin	3	sabinalily@yahoo.com	mattmw29@gmail.com	ES	\N	\N
711	12474	Walls	Ethan	5	sabinalily@yahoo.com	mattmw29@gmail.com	ES	\N	\N
712	12811	Patterson	Emilin	3	refinceyaa@gmail.com	markpatterson74@gmail.com	ES	\N	\N
713	12810	Patterson	Kaitlin	7	refinceyaa@gmail.com	markpatterson74@gmail.com	MS	\N	\N
714	12886	Mackay	Elsie	4	mandyamackay@gmail.com	tpmackay@gmail.com	ES	\N	\N
656	12428	Wittmann	Emilie	6	benedicte.wittmann@yahoo.fr	christophewittmann@yahoo.fr	MS	Beginning Band 1 2023	ewittmann30@isk.ac.ke
695	13022	Reza	Reehan	6	ruintoo@gmail.com	areza@usaid.gov	MS	Beginning Band 8 - 2023	rreza30@isk.ac.ke
666	12681	Hercberg	Noga	6	avigili3012@gmail.com	avigili3012@gmail.com	MS	Beginning Band 7 2023	nhercberg30@isk.ac.ke
699	12674	Ghelani-Decorte	Emiel	7	rghelani14@gmail.com	decorte@un.org	MS	Concert Band 2023	eghelani-decorte29@isk.ac.ke
676	12922	Dove	Georgia	6	meganlpdove@gmail.com	stephencarterdove@gmail.com	MS	Concert Band 2023	gdove30@isk.ac.ke
715	12885	Mackay	Nora	6	mandyamackay@gmail.com	tpmackay@gmail.com	MS	\N	\N
716	12832	Ishee	Samantha	K	vickie.ishee@gmail.com	jon.ishee1@gmail.com	ES	\N	\N
717	12836	Ishee	Emily	5	vickie.ishee@gmail.com	jon.ishee1@gmail.com	ES	\N	\N
718	12892	Wagner	Sonya	4	schakravarty@worldbank.org	williamchristianwagner@gmail.com	ES	\N	\N
719	12256	Pabani	Ayaan	1	sofia.jadavji@gmail.com	hanif.pabani@gmail.com	ES	\N	\N
720	13088	Jain	Arth	K	nidhigw@gmail.com	padiraja@gmail.com	ES	\N	\N
721	12641	Fekadeneh	Caleb	5	Shewit2003@yahoo.com	abi_fek@yahoo.com	ES	\N	\N
722	12633	Fekadeneh	Sina	10	Shewit2003@yahoo.com	abi_fek@yahoo.com	HS	\N	\N
723	12604	Bachmann	Marc-Andri	8	bettina.bachmann@ggaweb.ch	marcel.bachmann@roche.com	MS	\N	\N
724	13066	Daher	Ralia	PK	eguerahma@gmail.com	libdaher@gmail.com	ES	\N	\N
725	12435	Daher	Abbas	1	eguerahma@gmail.com	libdaher@gmail.com	ES	\N	\N
726	13099	Tafesse	Ruth Yifru	11	semene1975@gmail.com	yifrutaf2006@gmail.com	HS	\N	\N
727	13019	Grundberg	Emil	8	nimagrundberg@gmail.com	jgrundberg@iom.int	MS	\N	\N
728	10498	Mezemir	Amen	8	gtigistamha@yahoo.com	tdamte@unicef.org	MS	\N	\N
729	13101	Chikapa	Zizwani	PK	luyckx.ilke@gmail.com	zwangiegasha@gmail.com	ES	\N	\N
730	12292	Mkandawire	Chawanangwa	7	luyckx.ilke@gmail.com	zwangiegasha@gmail.com	MS	\N	\N
731	12272	Mkandawire	Daniel	11	luyckx.ilke@gmail.com	zwangiegasha@gmail.com	HS	\N	\N
732	12995	Douglas-Hamilton Pope	Selkie	9	saba@savetheelephants.org	frank@savetheelephants.org	HS	\N	\N
733	12649	Margovsky-Lotem	Yoav	PK	yahelmlotem@gmail.com	ambassador@nairobi.mfa.gov.il	ES	\N	\N
734	13039	Irungu	Liam	K	nicole.m.irungu@gmail.com	dominic.i.wanyoike@gmail.com	ES	\N	\N
735	13038	Irungu	Aiden	2	nicole.m.irungu@gmail.com	dominic.i.wanyoike@gmail.com	ES	\N	\N
736	13024	Li	Feng Zimo	5	ugandayog01@hotmail.com	simonlee831001@hotmail.com	ES	\N	\N
737	13023	Li	Feng Milun	7	ugandayog01@hotmail.com	simonlee831001@hotmail.com	MS	\N	\N
738	12900	Grindell	Alice	K	kaptuiya@gmail.com	ricgrin@gmail.com	ES	\N	\N
739	12061	Grindell	Emily	2	kaptuiya@gmail.com	ricgrin@gmail.com	ES	\N	\N
740	13016	Abbonizio	Emilie	11	oriane.abbonizio@gmail.com	askari606@gmail.com	HS	\N	\N
741	13035	Muttersbaugh	Cassidy	K	brennan.winter@gmail.com	smuttersbaugh@gmail.com	ES	\N	\N
742	13034	Muttersbaugh	Magnolia	3	brennan.winter@gmail.com	smuttersbaugh@gmail.com	ES	\N	\N
743	12823	Bellamy	Mathis	K	ahuggins@mercycorps.org	bellamy.paul@gmail.com	ES	\N	\N
744	12590	Donne	Maisha	11	omazzaroni@unicef.org	william55don@gmail.com	HS	\N	\N
746	12800	Romero Sánchez-Miranda	Amanda	3	carmen.sanchez@un.org	ricardoromerolopez@gmail.com	ES	\N	\N
747	12799	Romero	Candela	8	carmen.sanchez@un.org	ricardoromerolopez@gmail.com	MS	\N	\N
748	12860	Nora	Nadia	11	caranora@gmail.com	nora.enrico@gmail.com	HS	\N	\N
749	12626	Lee	Nayoon	5	euniceyhlee@gmail.com	ts0930.lee@samsung.com	ES	\N	\N
751	12718	Womble	Gaspard	1	priscillia.womble@gmail.com	david.womble@gmail.com	ES	\N	\N
752	13065	Sudra	Nile	PK	maryleakeysudra@gmail.com	msudra@isk.ac.ke	ES	\N	\N
753	13074	Huang	Xinyi	1	ruiyingwang2018@gmail.com	jinfamilygroup@yahoo.com	ES	\N	\N
754	13030	Baral	Aabhar	5	archanabibhor@gmail.com	bibhorbaral@gmail.com	ES	\N	\N
755	12982	Rollins	Azza	9	faamai@gmail.com	salimrollins@gmail.com	HS	\N	\N
756	13070	Hussain	Bushra	PK	sajdakhalil@gmail.com	aminmnhussain@gmail.com	ES	\N	\N
757	12999	Srutova	Monika	8	lehau.mnk@gmail.com	dusan_sruta@mzv.cz	MS	\N	\N
758	12815	Houndeganme	Nyx Verena	6	kougblenouchristelle@gmail.com	ahoundeganme@unicef.org	MS	\N	\N
759	12814	Houndeganme	Michael	9	kougblenouchristelle@gmail.com	ahoundeganme@unicef.org	HS	\N	\N
760	12813	Houndeganme	Crédo Terrence	12	kougblenouchristelle@gmail.com	ahoundeganme@unicef.org	HS	\N	\N
761	13103	Patrikios	Zefyros	PK	aepatrikios@gmail.com	jairey@isk.ac.ke	ES	\N	\N
762	13067	Trujillo	Emilio	PK	prisscilagbaxter@gmail.com	mtrujillo@isk.ac.ke	ES	\N	\N
763	12862	Segev	Eitan	PK	noggasegev@gmail.com	avivsegev1@gmail.com	ES	\N	\N
764	12721	Segev	Amitai	1	noggasegev@gmail.com	avivsegev1@gmail.com	ES	\N	\N
765	12986	Maini	Karina	10	shilpamaini9@gmail.com	rajesh@usnkenya.com	HS	\N	\N
767	12851	Moons	Elena	7	kasia@laud.nl	leander@laud.nl	MS	\N	\N
768	12809	Zeynu	Aymen	3	nebihat.muktar@gmail.com	zeynu.ummer@undp.org	ES	\N	\N
769	12552	Zeynu	Abem	7	nebihat.muktar@gmail.com	zeynu.ummer@undp.org	MS	\N	\N
770	13015	Simek	Alan	8	jiskakova@yahoo.com	ondrej.simek@eeas.europa.eu	MS	\N	\N
771	13014	Simek	Emil	11	jiskakova@yahoo.com	ondrej.simek@eeas.europa.eu	HS	\N	\N
772	13083	Gallagher	Hachim	2	habibanouh@yahoo.com	cuhullan89@gmail.com	ES	\N	\N
773	12646	Jaffer	Kabir	K	zeeya.jaffer@gmail.com	aj@onepet.co.ke	ES	\N	\N
774	11646	Jaffer	Ayaan	4	zeeya.jaffer@gmail.com	aj@onepet.co.ke	ES	\N	\N
776	12580	Dawoodbhai	Alifiya	12	munizola77@yahoo.com	zoher@royalgroupkenya.com	HS	\N	\N
777	12578	Lindkvist	Ruth	9	wanjira.mathai@wri.org	larsbasecamp@me.com	HS	\N	\N
778	12884	Otieno	Adrian	7	maureenagengo@gmail.com	jotieno@isk.ac.ke	MS	\N	\N
779	12583	Shah	Aanya	8	bhattdeepa@hotmail.com	smeet@sapphirelimited.net	MS	\N	\N
750	12627	Lee	Dongyoon	6	euniceyhlee@gmail.com	ts0930.lee@samsung.com	MS	Concert Band 2023	dlee30@isk.ac.ke
861	12582	Schei	Nora	8	ghk@spk.no	gas@mfa.no	MS	\N	\N
781	13086	Schoneveld	Jake	PK	nicoliendelange@hotmail.com	georgeschoneveld@gmail.com	ES	\N	\N
782	12818	Gitiba	Roy	7	mollygathoni@gmail.com	\N	MS	\N	\N
783	12817	Gitiba	Kirk Wise	9	mollygathoni@gmail.com	\N	HS	\N	\N
784	12539	Geller	Isaiah	9	egeller75@gmail.com	scge@niras.com	HS	\N	\N
785	12603	Mbera	Bianca	10	julie.onyuka@gmail.com	gototo24@gmail.com	HS	\N	\N
786	12545	Ukumu	Kors	9	ukumuphyllis@gmail.com	ukumu2002@gmail.com	HS	\N	\N
787	12857	Shah	Jiya	8	miraa9@hotmail.com	adarsh@statpack.co.ke	MS	\N	\N
788	13098	Karmali	Zayan	10	shameenkarmali@outlook.com	shirazkarmali10@gmail.com	HS	\N	\N
789	12954	Angima	Serenae	8	chao_laura@yahoo.co.uk	\N	MS	\N	\N
790	12735	Fatty	Fatoumatta	12	fatoumatafatty542@gmail.com	fatty@un.org	HS	\N	\N
791	12985	Kwena	Saone	10	cathymbithi7@gmail.com	matthewkwena@gmail.com	HS	\N	\N
792	12861	Wesley Iii	Howard	PK	wnyakiti@gmail.com	ajawesley@yahoo.com	ES	\N	\N
793	12629	Mason	Isabella	11	serenamason66@icloud.com	cldm@habari.co.tz	HS	\N	\N
794	13085	Limpered	Ayana	PK	christabel.owino@gmail.com	eodunguli@isk.ac.ke	ES	\N	\N
795	12795	Limpered	Arielle	2	christabel.owino@gmail.com	eodunguli@isk.ac.ke	ES	\N	\N
796	12412	Teklemichael	Rakeb	10	milen682@gmail.com	keburaku@gmail.com	HS	\N	\N
797	12987	Shah	Pranai	11	shahreena7978@yahoo.com	dhiresh.shah55@gmail.com	HS	\N	\N
798	12541	Shah	Dhiya	7	s_shah21@hotmail.co.uk	jaimin@bobmilgroup.com	MS	\N	\N
799	12644	Roquebrune	Marianne	PK	mroquebrune@yahoo.ca	\N	ES	\N	\N
800	12842	Somaia	Nichelle	1	ishisomaia@gmail.com	vishal@murbanmovers.co.ke	ES	\N	\N
801	11769	Somaia	Shivail	4	ishisomaia@gmail.com	vishal@murbanmovers.co.ke	ES	\N	\N
802	13068	Stiles	Lukas	PK	ppappas@isk.ac.ke	stilesdavid@gmail.com	ES	\N	\N
803	11137	Stiles	Nikolas	5	ppappas@isk.ac.ke	stilesdavid@gmail.com	ES	\N	\N
804	12979	Matimu	Nathan	9	liz.matimu@gmail.com	mngacha@gmail.com	HS	\N	\N
805	12895	Abreu	Aristophanes	K	katerina_papaioannou@yahoo.com	herson_abreu@hotmail.com	ES	\N	\N
806	12896	Abreu	Herson Alexandros	1	katerina_papaioannou@yahoo.com	herson_abreu@hotmail.com	ES	\N	\N
807	12825	Bailey	Arthur	9	tertia.bailey@fcdo.gov.uk	petergrahambailey@gmail.com	HS	\N	\N
808	12812	Bailey	Florrie	11	tertia.bailey@fcdo.gov.uk	petergrahambailey@gmail.com	HS	\N	\N
809	11368	Kone	Adam	10	sonjalk@unops.org	zakskone@gmail.com	HS	\N	\N
810	11367	Kone	Zahra	12	sonjalk@unops.org	zakskone@gmail.com	HS	\N	\N
811	12670	Wimber	Thomas	8	nancyaburi@gmail.com	\N	MS	\N	\N
812	12755	Ali	Rahmaan	12	rahima.khawaja@gmail.com	rahim.khawaja@aku.edu	HS	\N	\N
813	13029	Chowdhury	Davran	5	mohira22@yahoo.com	numayr_chowdhury@yahoo.com	ES	\N	\N
814	12868	Chowdhury	Nevzad	11	mohira22@yahoo.com	numayr_chowdhury@yahoo.com	HS	\N	\N
815	12553	Patel	Aariyana	9	roshninp1128@gmail.com	niknpatel@gmail.com	HS	\N	\N
816	12938	Mueller	Graham	7	carlabenini1@gmail.com	mueller10r@aol.com	MS	\N	\N
817	12937	Mueller	Willem	9	carlabenini1@gmail.com	mueller10r@aol.com	HS	\N	\N
818	12936	Mueller	Christian	11	carlabenini1@gmail.com	mueller10r@aol.com	HS	\N	\N
819	13075	Ndoye	Libasse	8	fatou.ndoye@un.org	\N	MS	\N	\N
820	13020	Wang	Yi (Gavin)	3	supermomcccc@gmail.com	mcbgwang@gmail.com	ES	\N	\N
821	12950	Wang	Shuyi (Bella)	8	supermomcccc@gmail.com	mcbgwang@gmail.com	MS	\N	\N
822	12715	David-Tafida	Mariam	2	fatymahit@gmail.com	bradleyeugenedavid@gmail.com	ES	\N	\N
823	12720	Farrell	James	1	katherinedfarrell@gmail.com	farrellmp@gmail.com	ES	\N	\N
824	12801	Gronborg	Anna Toft	K	trinegronborg@gmail.com	laschi@um.dk	ES	\N	\N
825	13036	Sidari	Rocco	2	geven@hotmail.com	jsidari@usaid.gov	ES	\N	\N
826	13072	Ajidahun	David	PK	ajidahun.olori@gmail.com	caliphlex@yahoo.com	ES	\N	\N
827	12805	Ajidahun	Darian	2	ajidahun.olori@gmail.com	caliphlex@yahoo.com	ES	\N	\N
828	12804	Ajidahun	Annabelle	4	ajidahun.olori@gmail.com	caliphlex@yahoo.com	ES	\N	\N
829	12328	Hussain	Saif	4	milhemrana@gmail.com	omarhussain_80@hotmail.com	ES	\N	\N
830	12899	Hussain	Taim	K	milhemrana@gmail.com	omarhussain_80@hotmail.com	ES	\N	\N
831	13048	Hayer	Kaveer Singh	2	manpreetkh@gmail.com	csh@hayerone.com	ES	\N	\N
832	12471	Hayer	Manvir Singh	7	manpreetkh@gmail.com	csh@hayerone.com	MS	\N	\N
834	12898	Bin Taif	Ahmed Jabir	K	shanchita02@gmail.com	ul.taif@gmail.com	ES	\N	\N
835	12311	Bin Taif	Ahmed Jayed	2	shanchita02@gmail.com	ul.taif@gmail.com	ES	\N	\N
836	12312	Bin Taif	Ahmed Jawad	5	shanchita02@gmail.com	ul.taif@gmail.com	ES	\N	\N
837	12978	Nas	Rebekah Ysabelle	9	gretchen.nas79@gmail.com	t.nas@cgiar.org	HS	\N	\N
838	12949	Husemann	Emilia	8	annahusemann@web.de	christoph.zipfel@web.de	MS	\N	\N
839	12891	Bonde-Nielsen	Luna	4	nike@terramoyo.com	pbn@oldonyolaro.com	ES	\N	\N
841	13000	Alemayehu	Naomi	4	hayatabdulahi@gmail.com	alexw9@gmail.com	ES	\N	\N
842	13105	Hales	Arabella	PK	amberley.hales@gmail.com	christopher.w.hales@gmail.com	ES	\N	\N
780	13076	Ibrahim	Masoud	6	ibrahimkhadija@gmail.com	ibradaud@gmail.com	MS	Beginning Band 1 2023	mibrahim30@isk.ac.ke
833	12756	Tulga	Titu	6	buyanu@gmail.com	tulgaad@gmail.com	MS	Beginning Band 7 2023	ttulga30@isk.ac.ke
843	13087	Khan	Zari	9	asmaibrar2023@gmail.com	ibrardiplo@gmail.com	HS	\N	\N
844	13026	Alwedo	Cradle Terry	5	ogwangk@unhcr.org	\N	ES	\N	\N
846	13095	Braun	Felix	8	wibke.braun@eeas.europa.eu	\N	MS	\N	\N
847	12998	Verstraete	Io	10	cornelia2vanzyl@gmail.com	lverstraete@unicef.org	HS	\N	\N
848	12560	Crabtree	Matthew	11	crabtreeak@state.gov	crabtreejd@state.gov	HS	\N	\N
849	12269	Sansculotte	Kieu	12	thanhluu77@hotmail.com	kwesi.sansculotte@wfp.org	HS	\N	\N
850	12496	Berkouwer	Daniel	1	lijiayu211@gmail.com	meskesberkouwer@gmail.com	ES	\N	\N
851	12820	Opere	Kayla	PK	rineke-van.dam@minbuza.nl	alexopereh@yahoo.com	ES	\N	\N
852	12794	Berthellier-Antoine	Léa	1	dberthellier@gmail.com	malick74@gmail.com	ES	\N	\N
853	13104	Kaseva	Lukas	PK	linda.kaseva@gmail.com	johannes.tarvainen@gmail.com	ES	\N	\N
854	13096	Kaseva	Lauri	3	linda.kaseva@gmail.com	johannes.tarvainen@gmail.com	ES	\N	\N
855	12550	Khan	Layal	2	zehrahyderali@gmail.com	ikhan2@worldbank.org	ES	\N	\N
856	13062	Croze	Ishbel	9	anna.croze@gmail.com	lengai.croze@gmail.com	HS	\N	\N
857	12873	Croucher	Emily	5	clairebedelian@hotmail.com	crouchermatthew@hotmail.com	ES	\N	\N
858	12874	Croucher	Oliver	7	clairebedelian@hotmail.com	crouchermatthew@hotmail.com	MS	\N	\N
859	12875	Croucher	Anabelle	9	clairebedelian@hotmail.com	crouchermatthew@hotmail.com	HS	\N	\N
860	12953	Olvik	Vera	8	uakesson@hotmail.com	gunnarolvik@hotmail.com	MS	\N	\N
862	12845	Skaaraas-Gjoelberg	Theodor	1	ceciskaa@yahoo.com	erlendmagnus@hotmail.com	ES	\N	\N
863	12846	Skaaraas-Gjoelberg	Cedrik	5	ceciskaa@yahoo.com	erlendmagnus@hotmail.com	ES	\N	\N
864	13089	Lee	David	2	podo416@gmail.com	mkthestyle@icloud.com	ES	\N	\N
865	12736	Jijina	Sanaya	12	shahnazjijjina@gmail.com	percy.jijina@jotun.com	HS	\N	\N
866	13010	Arora	Harshaan	8	dearbhawna1@yahoo.co.in	kapil.arora@eni.com	MS	\N	\N
867	13009	Arora	Tisya	10	dearbhawna1@yahoo.co.in	kapil.arora@eni.com	HS	\N	\N
868	13001	Elkana	Gai	1	maayan180783@gmail.com	tamir260983@gmail.com	ES	\N	\N
869	13002	Elkana	Yuval	3	maayan180783@gmail.com	tamir260983@gmail.com	ES	\N	\N
870	13003	Elkana	Matan	5	maayan180783@gmail.com	tamir260983@gmail.com	ES	\N	\N
871	12901	Nasidze	Niccolo	K	topuridze.tamar@gmail.com	alexander.nasidze@un.org	ES	\N	\N
872	12472	Aditya	Jayesh	8	\N	NANDKITTU@YAHOO.COM	MS	\N	\N
875	11851	Bredin	Zara	10	nickolls@un.org	milesbredin@mac.com	HS	\N	\N
876	20817	Lavack	Mark	8	patricia.wanyee@gmail.com	slavack@isk.ac.ke	MS	\N	\N
877	26015	Lavack	Michael	10	patricia.wanyee@gmail.com	slavack@isk.ac.ke	HS	\N	\N
878	10820	Dodhia	Rohin	11	tejal@capet.co.ke	ketul.dodhia@gmail.com	HS	\N	\N
879	12508	Bunch	Jaidyn	11	tsjbunch2@gmail.com	tsjbunch@gmail.com	HS	\N	\N
880	12529	Victor	Chalita	11	\N	Michaelnoahvictor@gmail.com	HS	\N	\N
881	12598	Waalewijn	Hannah	7	manonwaalewijn@gmail.com	manonenpieter@gmail.com	MS	\N	\N
883	12596	Waalewijn	Simon	11	manonwaalewijn@gmail.com	manonenpieter@gmail.com	HS	\N	\N
885	12591	Wietecha	Kaitlin	10	aitkenjennifer@hotmail.com	rwietecha@yahoo.com	HS	\N	\N
886	12702	Molloy	Saoirse	2	kacey.molloy@gmail.com	cmolloy.mt@gmail.com	ES	\N	\N
887	12701	Molloy	Caelan	4	kacey.molloy@gmail.com	cmolloy.mt@gmail.com	ES	\N	\N
888	12594	Mollier-Camus	Victor	5	carole.mollier.camus@gmail.com	simon.mollier-camus@bakerhughes.com	ES	\N	\N
889	12586	Mollier-Camus	Elisa	8	carole.mollier.camus@gmail.com	simon.mollier-camus@bakerhughes.com	MS	\N	\N
891	12684	Varun	Jaishna	7	liveatpresent83@gmail.com	liveatpresent83@gmail.com	MS	\N	\N
892	12782	Heijstee	Leah	3	vivien.jarl@gmail.com	vivien.jarl@gmail.com	ES	\N	\N
893	12781	Heijstee	Zara	8	vivien.jarl@gmail.com	vivien.jarl@gmail.com	MS	\N	\N
894	12902	Sotiriou	Graciela	K	enehrling@gmail.com	b.and.g.sotiriou@gmail.com	ES	\N	\N
895	12239	Sotiriou	Leonidas	2	enehrling@gmail.com	b.and.g.sotiriou@gmail.com	ES	\N	\N
896	12612	Barbacci	Evangelina	7	kbarbacci@hotmail.com	fbarbacci@hotmail.com	MS	\N	\N
897	12611	Barbacci	Gabriella	10	kbarbacci@hotmail.com	fbarbacci@hotmail.com	HS	\N	\N
898	12581	Moyle	Santiago	9	trina.schofield@gmail.com	fernandomoyle@gmail.com	HS	\N	\N
899	13082	Yakusik	Alissa	4	annayakusik@gmail.com	davidwilson1760@gmail.com	ES	\N	\N
900	12662	Ghariani	Farah	9	wafaek@hotmail.com	tewfickg@hotmail.com	HS	\N	\N
901	12634	Cameron-Mutyaba	Lillian	10	jennifer.cameron@international.gc.ca	mutyaba32@gmail.com	HS	\N	\N
902	12635	Cameron-Mutyaba	Rose	10	jennifer.cameron@international.gc.ca	mutyaba32@gmail.com	HS	\N	\N
903	12984	Teferi	Nathan	10	lula.tewfik@gmail.com	tamessay@hotmail.com	HS	\N	\N
904	13057	Mayar	Angab	11	mmonoja@yahoo.com	ayueldit2@gmail.com	HS	\N	\N
905	12737	Abdosh	Hanina	12	\N	el.abdosh@gmail.com	HS	\N	\N
890	12683	Varun	Harsha	6	liveatpresent83@gmail.com	liveatpresent83@gmail.com	MS	Beginning Band 8 - 2023	hvarun30@isk.ac.ke
873	12668	Szuchman	Sadie	6	sonyaedelman@gmail.com	szuchman@gmail.com	MS	Beginning Band 7 2023	sszuchman30@isk.ac.ke
845	13018	Agenorwot	Maria	8	bpido100@gmail.com	\N	MS	Concert Band 2023	magenorwot28@isk.ac.ke
874	12667	Szuchman	Reuben	8	sonyaedelman@gmail.com	szuchman@gmail.com	MS	Concert Band 2023	rszuchman28@isk.ac.ke
907	12732	Alemu	Liri	3	alemus20022@gmail.com	alemus20022@gmail.com	ES	\N	\N
908	13053	Ishanvi	Ishanvi	K	anupuniaahlawat@gmail.com	neerajahlawat88@gmail.com	ES	\N	\N
909	12373	Goyal	Seher	10	vitastasingh@hotmail.com	sgoyal@worldbank.org	HS	\N	\N
910	12917	Assi	Michael Omar	7	esmeralda.naji@hotmail.com	assi.mohamed@gmail.com	MS	\N	\N
911	12728	Singh	Abhimanyu	2	\N	rkc.jack@gmail.com	ES	\N	\N
913	13013	Otieno	Sifa	12	linet.otieno@gmail.com	tcpauldbtcol@gmail.com	HS	\N	\N
914	12819	Ibrahim	Iman	9	\N	ibradaud@gmail.com	HS	\N	\N
915	12994	Mathews	Tarquin	11	nadia@africaonline.co.ke	phil@heliprops.co.ke	HS	\N	\N
916	10437	Pandit	Jia	10	purvipandit@gmail.com	dhruvpandit@gmail.com	HS	\N	\N
917	12844	Waugh	Josephine	1	annabajorek125@gmail.com	minwaugh22@gmail.com	ES	\N	\N
918	12843	Waugh	Rosemary	4	annabajorek125@gmail.com	minwaugh22@gmail.com	ES	\N	\N
919	13025	Kisukye	Daudi	5	dmulira16@gmail.com	kisukye@un.org	ES	\N	\N
920	12759	Kisukye	Gabriel	10	dmulira16@gmail.com	kisukye@un.org	HS	\N	\N
921	12483	Virani	Aydin	3	mehreenrv@gmail.com	rahimwv@gmail.com	ES	\N	\N
922	12927	Huysdens	Yasmin	7	mhuysdens@gmail.com	merchan_nl@hotmail.com	MS	\N	\N
923	12926	Huysdens	Jacey	9	mhuysdens@gmail.com	merchan_nl@hotmail.com	HS	\N	\N
924	13028	Schonemann	Esther	5	\N	stesch@um.dk	ES	\N	\N
925	13046	Khouma	Nabou	K	ceciliakleimert@gmail.com	tallakhouma92@gmail.com	ES	\N	\N
926	13045	Khouma	Khady	3	ceciliakleimert@gmail.com	tallakhouma92@gmail.com	ES	\N	\N
927	13102	Ellinger	Emily	5	hello@dianaellinger.com	c_ellinger@hotmail.com	ES	\N	\N
929	12501	D'souza	Isaac	8	lizannec@hotmail.com	royden.dsouza@gmail.com	MS	\N	\N
930	13071	Kane	Ezra	PK	danionatangent@gmail.com	\N	ES	\N	\N
931	13091	Pijovic	Sapia	PK	somatatakone@yahoo.com	somatatakone@yahoo.com	ES	\N	\N
932	13052	Birschbach	Mubanga	K	mubangabirsch@gmail.com	birschbachjl@state.gov	ES	\N	\N
933	12748	Granot	Ben	K	maayanalmagor@gmail.com	granotb@gmail.com	ES	\N	\N
934	12747	Khalid	Zyla	K	aryana.c.khalid@gmail.com	waqqas.khalid@gmail.com	ES	\N	\N
935	12751	Kishiue-Turkstra	Hannah	K	akishiue@worldbank.org	jan.turkstra@gmail.com	ES	\N	\N
936	12824	Magnusson	Alexander	K	ericaselles@gmail.com	jon.a.magnusson@gmail.com	ES	\N	\N
937	12834	Nau	Emerson	K	kimdsimon@gmail.com	nau.hew@gmail.com	ES	\N	\N
938	12743	Patenaude	Alexandre	K	shanyoung86@gmail.com	patenaude.joel@gmail.com	ES	\N	\N
939	13040	Hirose	Ren	1	r.imamoto@gmail.com	yusuke.hirose@sumitomocorp.com	ES	\N	\N
940	12767	Johnson	Abel	1	ameenahbsaleem@gmail.com	ibnabu@aol.com	ES	\N	\N
941	13037	Kane	Issa	1	danionatangent@gmail.com	\N	ES	\N	\N
942	12717	Kiers	Beatrix	1	smallwood.marianne@gmail.com	alexis.kiers@gmail.com	ES	\N	\N
943	12459	Menkerios	Yousif	1	oh_hassan@hotmail.com	hmenkerios@aol.com	ES	\N	\N
944	12687	Oberjuerge	Clayton	1	kateharris22@gmail.com	loberjue@gmail.com	ES	\N	\N
945	12480	Pant	Yash	1	pantjoyindia@gmail.com	hem7star@gmail.com	ES	\N	\N
946	13090	Pijovic	Amandla	1	somatatakone@yahoo.com	somatatakone@yahoo.com	ES	\N	\N
947	13094	Santos	Paola	1	achang_911@yahoo.com	jsants16@yahoo.com	ES	\N	\N
948	12608	Sarfaraz	Amaya	1	sarahbafridi@gmail.com	sarfarazabid@gmail.com	ES	\N	\N
949	12841	Schrader	Clarice	1	schraderhub@gmail.com	schraderjp09@gmail.com	ES	\N	\N
950	12939	Sobantu	Mandisa	1	mbemelaphi@gmail.com	monwabisi.sobantu@gmail.com	ES	\N	\N
951	12877	Kamenga	Tasheni	2	nompumelelo.nkosi@gmail.com	kamenga@gmail.com	ES	\N	\N
952	12713	Patenaude	Theodore	2	shanyoung86@gmail.com	patenaude.joel@gmail.com	ES	\N	\N
953	12714	Soobrattee	Ewyn	2	jhomanchuk@yahoo.com	rsoobrattee@hotmail.com	ES	\N	\N
954	12888	Von Platen-Hallermund	Anna	2	mspliid@gmail.com	thobobs@hotmail.com	ES	\N	\N
955	12527	Wendelboe	Tristan	2	maria.wendelboe@outlook.dk	morwen@um.dk	ES	\N	\N
956	12570	Andersen	Signe	3	millelund@gmail.com	steensandersen@gmail.com	ES	\N	\N
957	12944	Asquith	Holly	3	kamilla.henningsen@gmail.com	m.asquith@icloud.com	ES	\N	\N
958	13033	Diop Weyer	Aurélien	3	frederique.weyer@graduateinstitute.ch	amadou.diop@graduateinstitute.ch	ES	\N	\N
959	12693	Lundell	Levi	3	rebekahlundell@gmail.com	redlundell@gmail.com	ES	\N	\N
960	13093	Santos	Santiago	3	achang_911@yahoo.com	jsants16@yahoo.com	ES	\N	\N
961	12840	Schrader	Genevieve	3	schraderhub@gmail.com	schraderjp09@gmail.com	ES	\N	\N
962	12369	Vazquez Eraso	Martin	3	berasopuig@worldbank.org	vvazquez@worldbank.org	ES	\N	\N
963	12664	Vestergaard	Magne	3	marves@um.dk	elrulu@protonmail.com	ES	\N	\N
964	12665	Vestergaard	Nanna	3	marves@um.dk	elrulu@protonmail.com	ES	\N	\N
965	12849	Weill	Benjamin	3	robineberlin@gmail.com	matthew_weill@mac.com	ES	\N	\N
966	12289	Bailey	Kira	4	anneli.veiszhaupt.bailey@gov.se	dbailey1971@gmail.com	ES	\N	\N
967	12850	Bixby	Aaryama	4	rkaria@gmail.com	malcolmbixby@gmail.com	ES	\N	\N
968	12925	Carlevato	Armelle	4	awishous@gmail.com	scarlevato@gmail.com	ES	\N	\N
969	12942	Corbin	Sonia	4	corbincf@gmail.com	james.corbin.pa@gmail.com	ES	\N	\N
970	12617	Khalid	Zaria	4	aryana.c.khalid@gmail.com	waqqas.khalid@gmail.com	ES	\N	\N
912	13056	Otieno	Uzima	7	linet.otieno@gmail.com	tcpauldbtcol@gmail.com	MS	Concert Band 2023	uotieno29@isk.ac.ke
1	12607	Farraj	Carlos Laith	4	gmcabrera2017@gmail.com	amer_farraj@yahoo.com	ES	\N	\N
2	12606	Farraj	Jarius	11	gmcabrera2017@gmail.com	amer_farraj@yahoo.com	HS	\N	\N
3	12768	Dadashev	Murad	8	huseynovags@yahoo.com	adadashev@unicef.org	MS	\N	\N
4	12769	Dadasheva	Zubeyda	12	huseynovags@yahoo.com	adadashev@unicef.org	HS	\N	\N
5	12433	Iversen	Sumaiya	12	sahfana.ali.mubarak@mfa.no	iiv@lyse.net	HS	\N	\N
6	12542	Borg Aidnell	Nike	2	aidnell@gmail.com	parborg70@hotmail.com	ES	\N	\N
7	12543	Borg Aidnell	Siv	2	aidnell@gmail.com	parborg70@hotmail.com	ES	\N	\N
8	12696	Borg Aidnell	Disa	5	aidnell@gmail.com	parborg70@hotmail.com	ES	\N	\N
9	12070	Ellis	Ryan	11	etinsley@worldbank.org	pellis@worldbank.org	HS	\N	\N
10	12068	Ellis	Adrienne	12	etinsley@worldbank.org	pellis@worldbank.org	HS	\N	\N
11	12192	Hodge	Emalea	5	janderson12@worldbank.org	jhodge1@worldbank.org	ES	\N	\N
13	12430	Arens	Jip	12	noudwater@gmail.com	luukarens@gmail.com	HS	\N	\N
534	11457	Schenck	Spencer	6	prillakrone@gmail.com	schenck.mills@bcg.com	MS	Beginning Band 8 - 2023	sschenck30@isk.ac.ke
121	12969	Willis	Isla	6	tjpeta.willis@gmail.com	pt.willis@bigpond.com	MS	Beginning Band 8 - 2023	iwillis30@isk.ac.ke
101	10775	Chandaria	Seya	6	farzana@chandaria.biz	sachen@chandaria.biz	MS	Beginning Band 8 - 2023	schandaria30@isk.ac.ke
376	10508	Chopra	Malan	6	tanja.chopra@gmx.de	jarat_chopra@me.com	MS	Beginning Band 8 - 2023	mchopra30@isk.ac.ke
339	11266	Vestergaard	Lilla	6	psarasas@gmail.com	o.vestergaard@gmail.com	MS	Beginning Band 8 - 2023	svestergaard30@isk.ac.ke
369	12427	Sangare	Moussa	6	taissata@yahoo.fr	sangnouh@yahoo.fr	MS	Beginning Band 8 - 2023	msangare30@isk.ac.ke
496	11762	Jansson	Leo	6	sawanakagawa@gmail.com	torjansson@gmail.com	MS	Beginning Band 8 - 2023	ljansson30@isk.ac.ke
549	12619	Saleem	Nora	6	anna.saleem.hogberg@gov.se	saleembaha@gmail.com	MS	Beginning Band 8 - 2023	nsaleem30@isk.ac.ke
572	11804	Stephens	Kaisei	6	mwatanabe1@worldbank.org	mstephens@worldbank.org	MS	Beginning Band 8 - 2023	kstephens30@isk.ac.ke
105	12096	Freiin Von Handel	Olivia	6	igiribaldi@hotmail.com	thomas.von.handel@gmail.com	MS	Beginning Band 8 - 2023	ovonhandel30@isk.ac.ke
518	12152	Materne	Kiara	6	nat.dekeyser@gmail.com	fredmaterne@hotmail.com	MS	Beginning Band 8 - 2023	kmaterne30@isk.ac.ke
229	12689	Eshetu	Mikael	6	olga.petryniak@gmail.com	kassahun.wossene@gmail.com	MS	Beginning Band 8 - 2023	meshetu30@isk.ac.ke
71	12170	Biafore	Ignacio	6	nermil@gmail.com	montiforce@gmail.com	MS	Beginning Band 8 - 2023	ibiafore30@isk.ac.ke
775	12976	Haysmith	Romilly	6	stephanie.haysmith@un.org	davehaysmith@hotmail.com	MS	Beginning Band 8 - 2023	rhaysmith30@isk.ac.ke
884	12725	Wietecha	Alexander	6	aitkenjennifer@hotmail.com	rwietecha@yahoo.com	MS	Beginning Band 8 - 2023	awietecha30@isk.ac.ke
669	12883	Dibling	Julian	6	askfelicia@gmail.com	sdibling@hotmail.com	MS	Beginning Band 8 - 2023	jdibling30@isk.ac.ke
840	12537	Bonde-Nielsen	Gaia	6	nike@terramoyo.com	pbn@oldonyolaro.com	MS	Beginning Band 8 - 2023	gbondenielsen30@isk.ac.ke
139	11096	Tanna	Kush	6	vptanna@gmail.com	priyentanna@gmail.com	MS	Beginning Band 8 - 2023	ktanna30@isk.ac.ke
442	12909	Alnaqbi	Saqer	6	emaraty_a99@hotmail.com	emaraty353@hotmail.com	MS	Beginning Band 8 - 2023	salnaqbi30@isk.ac.ke
176	10812	Mcmurtry	Jack	6	karenpoore77@yahoo.co.uk	seanmcmurtry7@gmail.com	MS	Beginning Band 8 - 2023	jmcmurtry30@isk.ac.ke
928	12500	D'souza	Aiden	6	lizannec@hotmail.com	royden.dsouza@gmail.com	MS	Beginning Band 8 - 2023	adsouza30@isk.ac.ke
12	12193	Hodge	Eliana	7	janderson12@worldbank.org	jhodge1@worldbank.org	MS	Concert Band 2023	ehodge29@isk.ac.ke
640	11463	Dokunmu	Abdul-Lateef Boluwatife (Bolu)	7	JJAGUN@GMAIL.COM	\N	MS	Beginning Band 7 2023	adokunmu29@isk.ac.ke
324	11262	Khubchandani	Anaiya	6	ramji.farzana@gmail.com	rishi.khubchandani@gmail.com	MS	Beginning Band 7 2023	akhubchandani30@isk.ac.ke
906	12549	Mutombo	Ariel	6	nathaliesindamut@gmail.com	mutombok@churchofjesuschrist.org	MS	Beginning Band 7 2023	amutombo30@isk.ac.ke
295	10686	Cutler	Edie	6	megseyjackson@gmail.com	adrianhcutler@gmail.com	MS	Beginning Band 7 2023	ecutler30@isk.ac.ke
22	11883	Camisa	Eugénie	6	katerinelafreniere@hotmail.com	laurentcamisa@hotmail.com	MS	Beginning Band 7 2023	ecamisa30@isk.ac.ke
203	10562	Haswell	Finlay	6	ahaswell@isk.ac.ke	danhaswell@hotmail.co.uk	MS	Beginning Band 7 2023	fhaswell30@isk.ac.ke
20	12967	Andersen	Yonatan Wondim Belachew	6	louian@um.dk	wondim_b@yahoo.com	MS	Beginning Band 7 2023	ywondimandersen30@isk.ac.ke
500	10708	Choi	Yoonseo	6	shy_cool@naver.com	flymax2002@hotmail.com	MS	Beginning Band 7 2023	ychoi30@isk.ac.ke
689	13073	Daines	Evan	6	foreverdaines143@gmail.com	dainesy@gmail.com	MS	Beginning Band 1 2023	edaines30@isk.ac.ke>
175	10817	Mcmurtry	Holly	6	karenpoore77@yahoo.co.uk	seanmcmurtry7@gmail.com	MS	Beginning Band 1 2023	hmcmurtry30@isk.ac.ke
693	12915	Stock	Max	6	rydebstock@hotmail.com	stockr2@state.gov	MS	Beginning Band 1 2023	mstock30@isk.ac.ke
456	11458	O'neill Calver	Rowan	6	laraoneill@gmail.com	timcalver@gmail.com	MS	Beginning Band 1 2023	roneillcalver30@isk.ac.ke
588	12392	Mensah	Selma	6	sabinemensah@gmail.com	henrimensah@gmail.com	MS	Beginning Band 1 2023	smensah30@isk.ac.ke
522	10621	Hire	Ainsley	7	jhire@isk.ac.ke	bhire@isk.ac.ke	MS	Concert Band 2023	ahire29@isk.ac.ke
123	10474	Awori	Aisha	8	Annmarieawori@gmail.com	Michael.awori@gmail.com	MS	Concert Band 2023	aawori28@isk.ac.ke
567	11677	Ross	Caleb	8	skeddington@yahoo.com	sross78665@gmail.com	MS	Concert Band 2023	cross28@isk.ac.ke
428	11703	Kimuli	Ean	7	jusmug@yahoo.com	e.sennoga@afdb.org	MS	Concert Band 2023	ekimuli29@isk.ac.ke
542	11904	Jensen	Emiliana	8	amag32@gmail.com	jonathon.jensen@gmail.com	MS	Concert Band 2023	ejensen28@isk.ac.ke
72	12171	Biafore	Giancarlo	8	nermil@gmail.com	montiforce@gmail.com	MS	Concert Band 2023	gbiafore28@isk.ac.ke
124	10475	Awori	Joan	8	Annmarieawori@gmail.com	Michael.awori@gmail.com	MS	Concert Band 2023	jawori28@isk.ac.ke
312	12196	Herman-Roloff	Keza	7	amykateherman@hotmail.com	khermanroloff@gmail.com	MS	Concert Band 2023	kherman-roloff29@isk.ac.ke
194	10493	Jayaram	Milan	7	sonali.murthy@gmail.com	kartik_j@yahoo.com	MS	Concert Band 2023	mijayaram29@isk.ac.ke
543	11926	Jensen	Nickolas	8	amag32@gmail.com	jonathon.jensen@gmail.com	MS	Concert Band 2023	njensen28@isk.ac.ke
882	12597	Waalewijn	Noam	8	manonwaalewijn@gmail.com	manonenpieter@gmail.com	MS	Concert Band 2023	nwaalewijn28@isk.ac.ke
384	12853	Plunkett	Wataru	7	makiplunkett@live.jp	jplun585@gmail.com	MS	Concert Band 2023	wplunkett29@isk.ac.ke
622	11996	Buksh	Sultan	8	aarif@ifc.org	\N	MS	\N	\N
766	12852	Moons	Olivia	4	kasia@laud.nl	leander@laud.nl	ES	\N	\N
996	13080	Nam	Seung Hyun	6	hope7993@qq.com	sknam@mofa.go.kr	MS	Beginning Band 7 2023	shyun-nam30@isk.ac.ke
988	13007	Cherickel	Tanay	6	urpmathew@gmail.com	cherickel@gmail.com	MS	Beginning Band 7 2023	tcherickel30@isk.ac.ke
990	12616	Khalid	Zayn	6	aryana.c.khalid@gmail.com	waqqas.khalid@gmail.com	MS	Beginning Band 8 - 2023	zkhalid30@isk.ac.ke
992	12621	Meyers	Balazs	6	krisztina.meyers@gmail.com	jemeyers@usaid.gov	MS	Beginning Band 8 - 2023	bmeyers30@isk.ac.ke
995	12761	Muneeb	Mahdiyah	6	libra_779@hotmail.com	muneeb_bakhshi@hotmail.com	MS	Beginning Band 8 - 2023	mmuneeb30@isk.ac.ke
986	13050	Birschbach	Mapalo	6	mubangabirsch@gmail.com	birschbachjl@state.gov	MS	Beginning Band 1 2023	mbirschbach30@isk.ac.ke
994	11622	Mulema	Anastasia	6	a.abenakyo@gmail.com	jmulema@cabi.org	MS	Beginning Band 1 2023	amulema30@isk.ac.ke
1001	12924	Carlevato	Etienne	7	awishous@gmail.com	scarlevato@gmail.com	MS	Beginning Band 1 2023	ecarlevato29@isk.ac.ke
993	12694	Mucci	Lauren	6	crista.mcinnis@gmail.com	warren.mucci@gmail.com	MS	Beginning Band 7 2023	lmucci30@isk.ac.ke
991	12691	Lundell	Seth	6	rebekahlundell@gmail.com	redlundell@gmail.com	MS	Beginning Band 7 2023	slundell30@isk.ac.ke
989	12973	Hobbs	Evyn	6	ywhobbs@yahoo.com	hbhobbs95@gmail.com	MS	Beginning Band 1 2023	ehobbs30@isk.ac.ke
1006	12997	Joymungul	Nirvi	7	sikam04@yahoo.com	s.joymungul@afdb.org	MS	Concert Band 2023	njoymungul29@isk.ac.ke
971	11954	Menkerios	Safiya	4	oh_hassan@hotmail.com	hmenkerios@aol.com	ES	\N	\N
972	12622	Meyers	Tamas	4	krisztina.meyers@gmail.com	jemeyers@usaid.gov	ES	\N	\N
973	12695	Mucci	Arianna	4	crista.mcinnis@gmail.com	warren.mucci@gmail.com	ES	\N	\N
974	12686	Oberjuerge	Graham	4	kateharris22@gmail.com	loberjue@gmail.com	ES	\N	\N
975	12816	Ryan	Patrick	4	jemichler@gmail.com	dpryan999@gmail.com	ES	\N	\N
976	12839	Schrader	Penelope	4	schraderhub@gmail.com	schraderjp09@gmail.com	ES	\N	\N
977	12887	Von Platen-Hallermund	Rebecca	4	mspliid@gmail.com	thobobs@hotmail.com	ES	\N	\N
978	12577	Chappell	Sebastian	5	mgorzelanska@usaid.gov	jchappell@usaid.gov	ES	\N	\N
979	12935	Fritts	Alayna	5	frittsalexa@gmail.com	jfrittsdc@gmail.com	ES	\N	\N
980	12676	Janisse	Riley	5	katlawlor@icloud.com	marcjanisse@icloud.com	ES	\N	\N
981	12327	Johnson	Adam	5	ameenahbsaleem@gmail.com	ibnabu@aol.com	ES	\N	\N
982	12692	Lundell	Elijah	5	rebekahlundell@gmail.com	redlundell@gmail.com	ES	\N	\N
983	12700	Mpatswe	Johannah	5	olivia.mutambo19@gmail.com	gkmpatswe@gmail.com	ES	\N	\N
984	12913	Bergqvist	Bella	6	moa.m.bergqvist@gmail.com	jbergqvist@hotmail.com	MS	\N	\N
985	12699	Birk	Bertram	6	gerbir@um.dk	thobirk@gmail.com	MS	\N	\N
987	12923	Carey	Elijah	6	twilford98@yahoo.com	scarey192003@yahoo.com	MS	\N	\N
997	12618	Ryan	Eva	6	jemichler@gmail.com	dpryan999@gmail.com	MS	\N	\N
998	12146	Bagenda	Mitchell	7	katy@katymitchell.com	xolani@mac.com	MS	\N	\N
999	12183	Breda	Luka	7	jlbarak@hotmail.com	cybreda@hotmail.com	MS	\N	\N
1000	12184	Breda	Paco	7	jlbarak@hotmail.com	cybreda@hotmail.com	MS	\N	\N
1002	12941	Corbin	Camille	7	corbincf@gmail.com	james.corbin.pa@gmail.com	MS	\N	\N
1003	12974	Eldridge	Colin	7	780711th@gmail.com	tomheldridge@hotmail.com	MS	\N	\N
1004	11726	Ferede	Maya	7	sinkineshb@gmail.com	fasikaf@gmail.com	MS	\N	\N
1005	12928	Fritts	Ava	7	frittsalexa@gmail.com	jfrittsdc@gmail.com	MS	\N	\N
1007	12679	Kishiue	Mahiro	7	akishiue@worldbank.org	jan.turkstra@gmail.com	MS	\N	\N
1008	12870	Lemley	Lola	7	julielemley@gmail.com	johnlemley@gmail.com	MS	\N	\N
1009	12685	Oberjuerge	Wesley	7	kateharris22@gmail.com	loberjue@gmail.com	MS	\N	\N
1010	12940	Sobantu	Nicholas	7	mbemelaphi@gmail.com	monwabisi.sobantu@gmail.com	MS	\N	\N
1011	12943	Asquith	Elliot	8	kamilla.henningsen@gmail.com	m.asquith@icloud.com	MS	\N	\N
1012	12450	Basnet	Anshika	8	gamu_sharma@yahoo.com	mbasnet@iom.int	MS	\N	\N
1013	12912	Bergqvist	Fanny	8	moa.m.bergqvist@gmail.com	jbergqvist@hotmail.com	MS	\N	\N
1014	12666	Cizek	Norah (Rebel)	8	suzcizek@gmail.com	\N	MS	\N	\N
1015	12675	Janisse	Alexa	8	katlawlor@icloud.com	marcjanisse@icloud.com	MS	\N	\N
1016	12948	Mendonca-Gray	Tiago	8	eduarda.gray@fcdo.gov.uk	johnathangray.1@icloud.com	MS	\N	\N
1017	12595	Spitler	Alexa	8	deborah.spitler@gmail.com	spitlerj@gmail.com	MS	\N	\N
1018	12952	Sykes	Maia	8	cate@colinsykes.com	mail@colinsykes.com	MS	\N	\N
1019	12848	Weill	Sonia	8	robineberlin@gmail.com	matthew_weill@mac.com	MS	\N	\N
1021	12672	Zulberti	Sienna	8	zjenemi@gmail.com	emiliano.zulberti@gmail.com	MS	\N	\N
1022	12147	Bagenda	Maya	9	katy@katymitchell.com	xolani@mac.com	HS	\N	\N
1023	12760	Bakhshi	Muhammad Uneeb	9	libra_779@hotmail.com	muneeb_bakhshi@hotmail.com	HS	\N	\N
1024	13058	Birschbach	Natasha	9	mubangabirsch@gmail.com	birschbachjl@state.gov	HS	\N	\N
1025	12858	Blanc Yeo	Lara	9	yeodeblanc@gmail.com	julian.blanc@gmail.com	HS	\N	\N
1026	13006	Cherickel	Jai	9	urpmathew@gmail.com	cherickel@gmail.com	HS	\N	\N
1027	12859	Dalal	Samarth	9	sapnarathi04@gmail.com	bharpurdalal@gmail.com	HS	\N	\N
1028	11772	Ephrem Yohannes	Dan	9	berhe@unhcr.org	jdephi@gmail.com	HS	\N	\N
1029	12972	Hobbs	Rowan	9	ywhobbs@yahoo.com	hbhobbs95@gmail.com	HS	\N	\N
1030	13012	Johansson-Desai	Benjamin	9	karin.johansson@eeas.europa.eu	j.desai@email.com	HS	\N	\N
1031	12996	Joymungul	Vashnie	9	sikam04@yahoo.com	s.joymungul@afdb.org	HS	\N	\N
1032	12876	Kamenga	Sphesihle	9	nompumelelo.nkosi@gmail.com	kamenga@gmail.com	HS	\N	\N
1033	13079	Nam	Seung Yoon	9	hope7993@qq.com	sknam@mofa.go.kr	HS	\N	\N
1034	12983	Rathore	Ishita	9	priyanka.gupta.rathore@gmail.com	abhishek.rathore@cgiar.org	HS	\N	\N
1035	10884	Rex	Nicholas	9	helenerex@gmail.com	familyrex@gmail.com	HS	\N	\N
1036	12663	Vestergaard	Asbjørn	9	marves@um.dk	elrulu@protonmail.com	HS	\N	\N
1037	12904	Adamec	Filip	10	nicol_adamcova@mzv.cz	adamec.r@gmail.com	HS	\N	\N
1038	12569	Andersen	Solveig	10	millelund@gmail.com	steensandersen@gmail.com	HS	\N	\N
1039	12790	Astier	Eugène	10	oberegoi@yahoo.com	astier6@bluewin.ch	HS	\N	\N
1040	12911	Bergqvist	Elsa	10	moa.m.bergqvist@gmail.com	jbergqvist@hotmail.com	HS	\N	\N
1041	12576	Chappell	Maximilian	10	mgorzelanska@usaid.gov	jchappell@usaid.gov	HS	\N	\N
1042	12653	De Geer-Howard	Charlotte	10	catharina_degeer@yahoo.com	jackhoward03@yahoo.com	HS	\N	\N
1043	13008	Islam	Aarish	10	aarishsaima11@yahoo.com	zahed.shimul@gmail.com	HS	\N	\N
1044	13011	Johansson-Desai	Daniel	10	karin.johansson@eeas.europa.eu	j.desai@email.com	HS	\N	\N
1045	11438	Lawrence	Dario	10	dandrea.claudia@gmail.com	ted.lawrence65@gmail.com	HS	\N	\N
1046	12869	Lemley	Maximo	10	julielemley@gmail.com	johnlemley@gmail.com	HS	\N	\N
1047	12555	Roquitte	Lila	10	sroquitte@hotmail.com	tptrenkle@hotmail.com	HS	\N	\N
1048	12558	Scanlon	Mathilde	10	kim@wolfenden.net	shane.scanlon@rescue.org	HS	\N	\N
1049	13055	Birschbach	Chisanga	11	mubangabirsch@gmail.com	birschbachjl@state.gov	HS	\N	\N
1050	12975	Eldridge	Wade	11	780711th@gmail.com	tomheldridge@hotmail.com	HS	\N	\N
1051	11748	Ephrem Yohannes	Reem	11	berhe@unhcr.org	jdephi@gmail.com	HS	\N	\N
1052	12971	Hobbs	Liam	11	ywhobbs@yahoo.com	hbhobbs95@gmail.com	HS	\N	\N
1053	12991	Kadilli	Daniel	11	ekadilli@unicef.org	bardh.kadilli@gmail.com	HS	\N	\N
1054	12749	Nimubona	Jay Austin	11	jnkinabacura@gmail.com	boubaroy19@gmail.com	HS	\N	\N
1055	25052	Stabrawa	Anna Sophia	11	stabrawaa@gmail.com	\N	HS	\N	\N
1056	12951	Sykes	Elliot	11	cate@colinsykes.com	mail@colinsykes.com	HS	\N	\N
1057	12628	Sylla	Lalia	11	mchaidara@gmail.com	syllamas@gmail.com	HS	\N	\N
1058	12568	Valdivieso Santos	Camila	11	metamelia@gmail.com	valdivieso@unfpa.org	HS	\N	\N
1059	12567	Wright	Emma	11	robertsonwright@gmail.com	robertsonwright@gmail.com	HS	\N	\N
1060	12651	Ata	Dzidzor	12	parissa.ata@gmail.com	a.ata@kokonetworks.com	HS	\N	\N
1061	12738	Bhandari	Nandini	12	trpt.bhandari@googlemail.com	Arvind.bhandari@ke.nestle.com	HS	\N	\N
1062	12652	De Geer-Howard	Isabella	12	catharina_degeer@yahoo.com	jackhoward03@yahoo.com	HS	\N	\N
1063	10464	Khan	Hanan	12	rahilak@yahoo.com	imtiaz.khan@cassiacap.com	HS	\N	\N
1064	11447	Lawrence	Vincenzo	12	dandrea.claudia@gmail.com	ted.lawrence65@gmail.com	HS	\N	\N
1066	24008	Lutz	Noah	12	azents@isk.ac.ke	stephanlutz@worldrenew.net	HS	\N	\N
1067	10922	Rex	Julian	12	helenerex@gmail.com	familyrex@gmail.com	HS	\N	\N
1068	12557	Scanlon	Luca	12	kim@wolfenden.net	shane.scanlon@rescue.org	HS	\N	\N
1069	12556	Trenkle	Noah	12	sroquitte@hotmail.com	tptrenkle@hotmail.com	HS	\N	\N
1020	12566	Wright	Theodore	8	robertsonwright@gmail.com	robertsonwright@gmail.com	MS	Concert Band 2023	twright28@isk.ac.ke
\.


--
-- TOC entry 3936 (class 0 OID 24250)
-- Dependencies: 222
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, first_name, last_name, email, role, number, grade_level, division, room, username) FROM stdin;
59	Vilma Doret	Rosen	vrosen30@isk.ac.ke	STUDENT	11763	6	MS	\N	vrosen30
60	Elizabeth	Gardner	egardner29@isk.ac.ke	STUDENT	11467	7	MS	\N	egardner29
61	Shai	Bedein	sbedein29@isk.ac.ke	STUDENT	12614	7	MS	\N	sbedein29
114	Maartje	Stott	mstott30@isk.ac.ke	STUDENT	12519	6	MS	\N	mstott30
115	Owen	Harris	oharris30@isk.ac.ke	STUDENT	12609	6	MS	\N	oharris30
116	Alexander	Mogilnicki	amogilnicki29@isk.ac.ke	STUDENT	11480	7	MS	\N	amogilnicki29
117	Cahir	Patel	cpatel29@isk.ac.ke	STUDENT	10772	7	MS	\N	cpatel29
118	Ehsan	Akuete	eakuete28@isk.ac.ke	STUDENT	12156	8	MS	\N	eakuete28
176	Lucile	Bamlango	lbamlango30@isk.ac.ke	STUDENT	10977	6	MS	\N	lbamlango30
177	Tawheed	Hussain	thussain30@isk.ac.ke	STUDENT	11469	6	MS	\N	thussain30
178	Florencia	Anding	fanding28@isk.ac.ke	STUDENT	10967	8	MS	\N	fanding28
179	Tobias	Godfrey	tgodfrey29@isk.ac.ke	STUDENT	11227	7	MS	\N	tgodfrey29
239	Stefanie	Landolt	slandolt30@isk.ac.ke	STUDENT	12286	6	MS	\N	slandolt30
240	Arhum	Bid	abid30@isk.ac.ke	STUDENT	11706	6	MS	\N	abid30
241	Hawi	Okwany	hokwany29@isk.ac.ke	STUDENT	10696	7	MS	\N	hokwany29
298	Ayana	Butt	abutt30@isk.ac.ke	STUDENT	11402	6	MS	\N	abutt30
299	Connor	Fort	cfort30@isk.ac.ke	STUDENT	11650	6	MS	\N	cfort30
300	Ochieng	Simbiri	osimbiri30@isk.ac.ke	STUDENT	11265	6	MS	\N	osimbiri30
301	Fatuma	Tall	ftall28@isk.ac.ke	STUDENT	11515	8	MS	\N	ftall28
302	Jana	Landolt	jlandolt28@isk.ac.ke	STUDENT	12285	8	MS	\N	jlandolt28
356	Anaiya	Shah	ashah30@isk.ac.ke	STUDENT	11264	6	MS	\N	ashah30
357	Lilyrose	Trottier	ltrottier30@isk.ac.ke	STUDENT	11944	6	MS	\N	ltrottier30
358	Lorian	Inglis	linglis30@isk.ac.ke	STUDENT	12133	6	MS	\N	linglis30
359	Anne	Bamlango	abamlango28@isk.ac.ke	STUDENT	10978	8	MS	\N	abamlango28
360	Arjan	Arora	aarora28@isk.ac.ke>	STUDENT	12130	8	MS	\N	aarora28
361	Naomi	Yohannes	nyohannes29@isk.ac.ke	STUDENT	10787	7	MS	\N	nyohannes29
421	Phuc Anh	Nguyen	pnguyen30@isk.ac.ke	STUDENT	11260	6	MS	\N	pnguyen30
422	Aiden	Gremley	agremley29@isk.ac.ke	STUDENT	12393	7	MS	\N	agremley29
1082	Kennedy	Wando	kwando@isk.ac.ke	INVENTORY MANAGER	\N	\N	\N	INSTRUMENT STORE	kwando
480	Kai	O'Bra	kobra30@isk.ac.ke	STUDENT	12342	6	MS	\N	kobra30
481	Luke	O'Hara	lohara30@isk.ac.ke	STUDENT	12063	6	MS	\N	lohara30
482	Ansh	Mehta	amehta29@isk.ac.ke	STUDENT	10657	7	MS	\N	amehta29
483	Isla	Goold	igoold28@isk.ac.ke	STUDENT	11836	8	MS	\N	igoold28
538	Zecarun	Caminha	zcaminha30@isk.ac.ke	STUDENT	12081	6	MS	\N	zcaminha30
539	Fatima	Zucca	fazucca30@isk.ac.ke	STUDENT	10566	6	MS	\N	fazucca30
540	Grace	Njenga	gnjenga29@isk.ac.ke	STUDENT	12280	7	MS	\N	gnjenga29
541	Natéa	Firzé Al Ghaoui	nfirzealghaoui29@isk.ac.ke	STUDENT	12190	7	MS	\N	nfirzealghaoui29
601	Olivia	Patel	opatel30@isk.ac.ke	STUDENT	10561	6	MS	\N	opatel30
602	Naia	Friedhoff Jaeschke	nfriedhoffjaeschke29@isk.ac.ke	STUDENT	11822	7	MS	\N	nfriedhoffjaeschke29
659	Emilie	Wittmann	ewittmann30@isk.ac.ke	STUDENT	12428	6	MS	\N	ewittmann30
660	Reehan	Reza	rreza30@isk.ac.ke	STUDENT	13022	6	MS	\N	rreza30
661	Noga	Hercberg	nhercberg30@isk.ac.ke	STUDENT	12681	6	MS	\N	nhercberg30
662	Emiel	Ghelani-Decorte	eghelani-decorte29@isk.ac.ke	STUDENT	12674	7	MS	\N	eghelani-decorte29
663	Georgia	Dove	gdove30@isk.ac.ke	STUDENT	12922	6	MS	\N	gdove30
725	Dongyoon	Lee	dlee30@isk.ac.ke	STUDENT	12627	6	MS	\N	dlee30
787	Masoud	Ibrahim	mibrahim30@isk.ac.ke	STUDENT	13076	6	MS	\N	mibrahim30
788	Titu	Tulga	ttulga30@isk.ac.ke	STUDENT	12756	6	MS	\N	ttulga30
845	Harsha	Varun	hvarun30@isk.ac.ke	STUDENT	12683	6	MS	\N	hvarun30
846	Sadie	Szuchman	sszuchman30@isk.ac.ke	STUDENT	12668	6	MS	\N	sszuchman30
847	Maria	Agenorwot	magenorwot28@isk.ac.ke	STUDENT	13018	8	MS	\N	magenorwot28
848	Reuben	Szuchman	rszuchman28@isk.ac.ke	STUDENT	12667	8	MS	\N	rszuchman28
929	Moussa	Sangare	msangare30@isk.ac.ke	STUDENT	12427	6	MS	\N	msangare30
930	Leo	Jansson	ljansson30@isk.ac.ke	STUDENT	11762	6	MS	\N	ljansson30
931	Nora	Saleem	nsaleem30@isk.ac.ke	STUDENT	12619	6	MS	\N	nsaleem30
932	Kaisei	Stephens	kstephens30@isk.ac.ke	STUDENT	11804	6	MS	\N	kstephens30
933	Olivia	Freiin Von Handel	ovonhandel30@isk.ac.ke	STUDENT	12096	6	MS	\N	ovonhandel30
934	Kiara	Materne	kmaterne30@isk.ac.ke	STUDENT	12152	6	MS	\N	kmaterne30
935	Mikael	Eshetu	meshetu30@isk.ac.ke	STUDENT	12689	6	MS	\N	meshetu30
936	Ignacio	Biafore	ibiafore30@isk.ac.ke	STUDENT	12170	6	MS	\N	ibiafore30
937	Romilly	Haysmith	rhaysmith30@isk.ac.ke	STUDENT	12976	6	MS	\N	rhaysmith30
938	Alexander	Wietecha	awietecha30@isk.ac.ke	STUDENT	12725	6	MS	\N	awietecha30
939	Julian	Dibling	jdibling30@isk.ac.ke	STUDENT	12883	6	MS	\N	jdibling30
940	Gaia	Bonde-Nielsen	gbondenielsen30@isk.ac.ke	STUDENT	12537	6	MS	\N	gbondenielsen30
941	Kush	Tanna	ktanna30@isk.ac.ke	STUDENT	11096	6	MS	\N	ktanna30
942	Saqer	Alnaqbi	salnaqbi30@isk.ac.ke	STUDENT	12909	6	MS	\N	salnaqbi30
943	Jack	Mcmurtry	jmcmurtry30@isk.ac.ke	STUDENT	10812	6	MS	\N	jmcmurtry30
944	Aiden	D'Souza	adsouza30@isk.ac.ke	STUDENT	12500	6	MS	\N	adsouza30
945	Eliana	Hodge	ehodge29@isk.ac.ke	STUDENT	12193	7	MS	\N	ehodge29
946	Abdul-Lateef Boluwatife (Bolu)	Dokunmu	adokunmu29@isk.ac.ke	STUDENT	11463	7	MS	\N	adokunmu29
947	Anaiya	Khubchandani	akhubchandani30@isk.ac.ke	STUDENT	11262	6	MS	\N	akhubchandani30
948	Ariel	Mutombo	amutombo30@isk.ac.ke	STUDENT	12549	6	MS	\N	amutombo30
949	Edie	Cutler	ecutler30@isk.ac.ke	STUDENT	10686	6	MS	\N	ecutler30
950	Eugénie	Camisa	ecamisa30@isk.ac.ke	STUDENT	11883	6	MS	\N	ecamisa30
32	Cheryl	Cole	\N	STUDENT	12497	12	HS	\N	\N
951	Finlay	Haswell	fhaswell30@isk.ac.ke	STUDENT	10562	6	MS	\N	fhaswell30
1081	Nellie	Odera	\nnodera.sub@isk.ac.ke	SUBSTITUTE	\N	\N	\N	\N	\nnodera.sub
18	Hugo	Ashton	\N	STUDENT	11902	6	MS	\N	\N
33	Oria	Bunbury	\N	STUDENT	12247	K	ES	\N	\N
625	Ruth	Dove	\N	STUDENT	12921	9	HS	\N	\N
34	Dawon	Eom	\N	STUDENT	12733	10	HS	\N	\N
35	Arnav	Mohan	\N	STUDENT	11925	12	HS	\N	\N
36	Alexander	Roe	\N	STUDENT	12188	7	MS	\N	\N
37	Elizabeth	Roe	\N	STUDENT	12186	9	HS	\N	\N
38	Freja	Lindvig	\N	STUDENT	12535	5	ES	\N	\N
39	Hana	Linck	\N	STUDENT	12559	12	HS	\N	\N
40	Sif	Lindvig	\N	STUDENT	12502	8	MS	\N	\N
41	Mimer	Lindvig	\N	STUDENT	12503	10	HS	\N	\N
42	Frida	Weurlander	\N	STUDENT	12440	4	ES	\N	\N
43	Zahra	Singh	\N	STUDENT	11505	9	HS	\N	\N
44	Dylan	Zhang	\N	STUDENT	12206	1	ES	\N	\N
45	Carys	Aubrey	\N	STUDENT	11838	8	MS	\N	\N
46	Evie	Aubrey	\N	STUDENT	10950	12	HS	\N	\N
47	Raeed	Mahmud	\N	STUDENT	11910	12	HS	\N	\N
48	Kaleb	Mekonnen	\N	STUDENT	11185	5	ES	\N	\N
49	Yonathan	Mekonnen	\N	STUDENT	11015	7	MS	\N	\N
50	Aya	Mathers	\N	STUDENT	11793	4	ES	\N	\N
51	Yui	Mathers	\N	STUDENT	11110	8	MS	\N	\N
52	Madeleine	Gardner	\N	STUDENT	11468	5	ES	\N	\N
53	Sofia	Russo	\N	STUDENT	11362	4	ES	\N	\N
54	Leandro	Russo	\N	STUDENT	11361	8	MS	\N	\N
55	Gerald	Murathi	\N	STUDENT	11724	4	ES	\N	\N
56	Megan	Murathi	\N	STUDENT	11735	7	MS	\N	\N
57	Eunice	Murathi	\N	STUDENT	11736	11	HS	\N	\N
58	Abby Angelica	Manzano	\N	STUDENT	11479	7	MS	\N	\N
62	Or	Alemu	\N	STUDENT	13005	K	ES	\N	\N
63	Lillia	Bellamy	\N	STUDENT	11942	3	ES	\N	\N
64	Destiny	Ouma	\N	STUDENT	10319	8	MS	\N	\N
65	Louis	Ronzio	\N	STUDENT	12197	3	ES	\N	\N
66	George	Ronzio	\N	STUDENT	12199	7	MS	\N	\N
67	Andre	Awori	\N	STUDENT	24068	12	HS	\N	\N
68	Krishi	Shah	\N	STUDENT	12121	10	HS	\N	\N
69	Isabella	Fisher	\N	STUDENT	11416	9	HS	\N	\N
70	Charles	Fisher	\N	STUDENT	11415	11	HS	\N	\N
71	Joy	Mwangi	\N	STUDENT	10557	12	HS	\N	\N
72	Hassan	Akuete	\N	STUDENT	11985	10	HS	\N	\N
73	Leul	Alemu	\N	STUDENT	13004	5	ES	\N	\N
74	Lisa	Otterstedt	\N	STUDENT	12336	12	HS	\N	\N
75	Helena	Stott	\N	STUDENT	12520	9	HS	\N	\N
76	Patrick	Stott	\N	STUDENT	12521	10	HS	\N	\N
77	Isla	Kimani	\N	STUDENT	12397	K	ES	\N	\N
78	Christodoulos	Van De Velden	\N	STUDENT	11788	3	ES	\N	\N
79	Evangelia	Van De Velden	\N	STUDENT	10704	7	MS	\N	\N
80	Sofia	Todd	\N	STUDENT	11731	2	ES	\N	\N
81	Dominik	Mogilnicki	\N	STUDENT	11481	5	ES	\N	\N
82	Kieran	Echalar	\N	STUDENT	12723	1	ES	\N	\N
83	Liam	Echalar	\N	STUDENT	11882	4	ES	\N	\N
84	Nova	Wilkes	\N	STUDENT	12750	PK	ES	\N	\N
85	Maximilian	Freiherr Von Handel	\N	STUDENT	12095	11	HS	\N	\N
86	Lucas	Lopez Abella	\N	STUDENT	11759	3	ES	\N	\N
87	Mara	Lopez Abella	\N	STUDENT	11819	5	ES	\N	\N
88	Cassius	Miller	\N	STUDENT	27007	9	HS	\N	\N
89	Albert	Miller	\N	STUDENT	25051	11	HS	\N	\N
90	Axel	Rose	\N	STUDENT	12753	PK	ES	\N	\N
91	Evelyn	James	\N	STUDENT	10843	5	ES	\N	\N
92	Ellis	Sudra	\N	STUDENT	11941	1	ES	\N	\N
93	Arav	Shah	\N	STUDENT	10784	7	MS	\N	\N
94	Lucia	Thornton	\N	STUDENT	12993	5	ES	\N	\N
95	Robert	Thornton	\N	STUDENT	12992	7	MS	\N	\N
96	Jeongu	Yun	\N	STUDENT	12492	2	ES	\N	\N
97	Geonu	Yun	\N	STUDENT	12487	3	ES	\N	\N
98	David	Carter	\N	STUDENT	11937	8	MS	\N	\N
99	Gabrielle	Willis	\N	STUDENT	12970	5	ES	\N	\N
100	Julian	Schmidlin Guerrero	\N	STUDENT	11803	5	ES	\N	\N
101	Malaika	Awori	\N	STUDENT	10476	8	MS	\N	\N
102	Aarav	Sagar	\N	STUDENT	12248	1	ES	\N	\N
103	Indira	Sheridan	\N	STUDENT	11592	10	HS	\N	\N
104	Erika	Sheridan	\N	STUDENT	11591	12	HS	\N	\N
105	Téa	Andries-Munshi	\N	STUDENT	12798	K	ES	\N	\N
106	Zaha	Andries-Munshi	\N	STUDENT	12788	3	ES	\N	\N
107	Samir	Wallbridge	\N	STUDENT	10841	5	ES	\N	\N
108	Lylah	Wallbridge	\N	STUDENT	20867	8	MS	\N	\N
109	Oscar	Ansell	\N	STUDENT	12134	9	HS	\N	\N
110	Louise	Ansell	\N	STUDENT	11852	10	HS	\N	\N
111	Omar	Harris Ii	\N	STUDENT	12625	11	HS	\N	\N
112	Boele	Hissink	\N	STUDENT	11003	5	ES	\N	\N
113	Pomeline	Hissink	\N	STUDENT	10683	7	MS	\N	\N
119	Ismail	Liban	\N	STUDENT	11647	7	MS	\N	\N
120	Shreya	Tanna	\N	STUDENT	10703	8	MS	\N	\N
121	Samuel	Clark	\N	STUDENT	13049	4	ES	\N	\N
122	Ohad	Yarkoni	\N	STUDENT	12167	3	ES	\N	\N
123	Matan	Yarkoni	\N	STUDENT	12168	5	ES	\N	\N
124	Itay	Yarkoni	\N	STUDENT	12169	8	MS	\N	\N
125	Yen	Nguyen	\N	STUDENT	11672	7	MS	\N	\N
126	Binh	Nguyen	\N	STUDENT	11671	9	HS	\N	\N
127	Shams	Hussain	\N	STUDENT	11496	3	ES	\N	\N
128	Salam	Hussain	\N	STUDENT	11495	4	ES	\N	\N
129	Basile	Pozzi	\N	STUDENT	10275	12	HS	\N	\N
130	Ibrahim	Ibrahim	\N	STUDENT	11666	12	HS	\N	\N
131	Mateo	Lopez Salazar	\N	STUDENT	12752	K	ES	\N	\N
132	Benjamin	Godfrey	\N	STUDENT	11242	5	ES	\N	\N
133	Jamal	Sana	\N	STUDENT	11525	11	HS	\N	\N
134	Saba	Feizzadeh	\N	STUDENT	12872	4	ES	\N	\N
135	Kasra	Feizzadeh	\N	STUDENT	12871	9	HS	\N	\N
136	Kayla	Fazal	\N	STUDENT	12201	6	MS	\N	\N
137	Alyssia	Fazal	\N	STUDENT	11878	8	MS	\N	\N
138	Chloe	Foster	\N	STUDENT	11530	11	HS	\N	\N
139	Joyous	Miyanue	\N	STUDENT	11582	10	HS	\N	\N
140	Marvelous Peace	Nkahnue	\N	STUDENT	11583	12	HS	\N	\N
141	Rafaelle	Patella Ross	\N	STUDENT	10707	7	MS	\N	\N
142	Juna	Patella Ross	\N	STUDENT	10617	10	HS	\N	\N
143	Tyler	Good	\N	STUDENT	12879	4	ES	\N	\N
144	Julia	Good	\N	STUDENT	12878	8	MS	\N	\N
145	Maria-Antonina (Jay)	Biesiada	\N	STUDENT	11723	10	HS	\N	\N
146	Ben	Nannes	\N	STUDENT	10980	9	HS	\N	\N
147	Kaiam	Hajee	\N	STUDENT	11520	5	ES	\N	\N
148	Kadin	Hajee	\N	STUDENT	11542	7	MS	\N	\N
149	Kahara	Hajee	\N	STUDENT	11541	8	MS	\N	\N
150	Maria	Gebremedhin	\N	STUDENT	10688	6	MS	\N	\N
151	Rainey	Copeland	\N	STUDENT	12003	12	HS	\N	\N
152	Zawadi	Ndinguri	\N	STUDENT	11936	5	ES	\N	\N
153	Max	De Jong	\N	STUDENT	24001	11	HS	\N	\N
154	Maximiliano	Davis - Arana	\N	STUDENT	12372	1	ES	\N	\N
155	Emilia	Nicolau Meganck	\N	STUDENT	12797	K	ES	\N	\N
156	Zane	Anding	\N	STUDENT	10968	11	HS	\N	\N
157	Otis	Rogers	\N	STUDENT	11940	1	ES	\N	\N
158	Liam	Rogers	\N	STUDENT	12744	PK	ES	\N	\N
159	Teagan	Wood	\N	STUDENT	10972	9	HS	\N	\N
160	Caitlin	Wood	\N	STUDENT	10934	11	HS	\N	\N
161	Anusha	Masrani	\N	STUDENT	10632	8	MS	\N	\N
162	Jin	Handa	\N	STUDENT	10641	10	HS	\N	\N
163	Lina	Fest	\N	STUDENT	10279	11	HS	\N	\N
164	Marie	Fest	\N	STUDENT	10278	11	HS	\N	\N
165	Divyaan	Ramrakha	\N	STUDENT	11830	7	MS	\N	\N
166	Niyam	Ramrakha	\N	STUDENT	11379	10	HS	\N	\N
167	Akeyo	Jayaram	\N	STUDENT	11404	3	ES	\N	\N
168	Gendhis	Sapta	\N	STUDENT	10320	8	MS	\N	\N
169	Kianna	Venkataya	\N	STUDENT	12706	4	ES	\N	\N
170	Taegan	Line	\N	STUDENT	11627	7	MS	\N	\N
171	Bronwyn	Line	\N	STUDENT	11626	9	HS	\N	\N
172	Jamison	Line	\N	STUDENT	11625	11	HS	\N	\N
173	Tangaaza	Mujuni	\N	STUDENT	10788	7	MS	\N	\N
174	Rugaba	Mujuni	\N	STUDENT	20828	10	HS	\N	\N
175	Laia	Guyard Suengas	\N	STUDENT	20805	11	HS	\N	\N
180	Zeeon	Ahmed	\N	STUDENT	11570	12	HS	\N	\N
181	Emily	Haswell	\N	STUDENT	27066	8	MS	\N	\N
182	Yago	Dalla Vedova Sanjuan	\N	STUDENT	12444	12	HS	\N	\N
183	Ariana	Choda	\N	STUDENT	10973	10	HS	\N	\N
184	Isabella	Schmid	\N	STUDENT	10974	11	HS	\N	\N
185	Sophia	Schmid	\N	STUDENT	10975	11	HS	\N	\N
186	Kai	Ernst	\N	STUDENT	13043	K	ES	\N	\N
187	Aika	Ernst	\N	STUDENT	11628	3	ES	\N	\N
188	Amira	Varga	\N	STUDENT	11705	5	ES	\N	\N
189	Jonah	Veverka	\N	STUDENT	12835	K	ES	\N	\N
190	Theocles	Veverka	\N	STUDENT	12838	2	ES	\N	\N
191	Adam-Angelo	Sankoh	\N	STUDENT	12441	3	ES	\N	\N
192	Mwende	Mittelstadt	\N	STUDENT	11098	10	HS	\N	\N
193	Miles	Charette	\N	STUDENT	20780	9	HS	\N	\N
194	Tea	Charette	\N	STUDENT	20781	12	HS	\N	\N
195	Drew (Tilly)	Giblin	\N	STUDENT	12963	2	ES	\N	\N
196	Auberlin (Addie)	Giblin	\N	STUDENT	12964	7	MS	\N	\N
197	Ryan	Burns	\N	STUDENT	11199	12	HS	\N	\N
198	Bella	Jama	\N	STUDENT	12457	1	ES	\N	\N
199	Ari	Jama	\N	STUDENT	12452	3	ES	\N	\N
200	Isaiah	Marriott	\N	STUDENT	11572	12	HS	\N	\N
201	Sianna	Byrne-Ilako	\N	STUDENT	11751	11	HS	\N	\N
202	Camden	Teel	\N	STUDENT	12360	4	ES	\N	\N
203	Jaidyn	Teel	\N	STUDENT	12361	6	MS	\N	\N
204	Lukas	Eshetu	\N	STUDENT	12793	9	HS	\N	\N
205	Dylan	Okanda	\N	STUDENT	11511	9	HS	\N	\N
206	Sasha	Blaschke	\N	STUDENT	11599	4	ES	\N	\N
207	Kaitlyn	Blaschke	\N	STUDENT	11052	6	MS	\N	\N
208	Georges	Marin Fonseca Choucair Ramos	\N	STUDENT	12789	3	ES	\N	\N
209	Maaya	Kobayashi	\N	STUDENT	11575	5	ES	\N	\N
210	Isabel	Hansen Meiro	\N	STUDENT	11943	5	ES	\N	\N
211	Finley	Eckert-Crosse	\N	STUDENT	11568	4	ES	\N	\N
212	Mohammad Haroon	Bajwa	\N	STUDENT	10941	8	MS	\N	\N
213	Erik	Suther	\N	STUDENT	10511	7	MS	\N	\N
214	Aarav	Chandaria	\N	STUDENT	11792	4	ES	\N	\N
215	Aarini Vijay	Chandaria	\N	STUDENT	10338	9	HS	\N	\N
216	Leo	Korvenoja	\N	STUDENT	11526	11	HS	\N	\N
217	Mandisa	Mathew	\N	STUDENT	10881	12	HS	\N	\N
218	Hafsa	Ahmed	\N	STUDENT	12158	8	MS	\N	\N
219	Mariam	Ahmed	\N	STUDENT	12159	8	MS	\N	\N
220	Osman	Ahmed	\N	STUDENT	11745	12	HS	\N	\N
221	Tessa	Steel	\N	STUDENT	12116	10	HS	\N	\N
222	Ethan	Steel	\N	STUDENT	11442	12	HS	\N	\N
223	Brianna	Otieno	\N	STUDENT	11271	8	MS	\N	\N
224	Sohum	Bid	\N	STUDENT	13042	K	ES	\N	\N
225	Yara	Janmohamed	\N	STUDENT	12173	4	ES	\N	\N
226	Aila	Janmohamed	\N	STUDENT	12174	8	MS	\N	\N
227	Rwenzori	Rogers	\N	STUDENT	12208	4	ES	\N	\N
228	Junin	Rogers	\N	STUDENT	12209	5	ES	\N	\N
229	Jasmine	Schoneveld	\N	STUDENT	11879	3	ES	\N	\N
230	Hiyabel	Kefela	\N	STUDENT	11444	12	HS	\N	\N
231	Arra	Manji	\N	STUDENT	12416	4	ES	\N	\N
232	Deesha	Shah	\N	STUDENT	12108	10	HS	\N	\N
233	Sidh	Rughani	\N	STUDENT	10770	9	HS	\N	\N
234	Sohil	Chandaria	\N	STUDENT	12124	10	HS	\N	\N
235	Imara	Patel	\N	STUDENT	12275	11	HS	\N	\N
236	Riyaan	Wissanji	\N	STUDENT	11437	10	HS	\N	\N
237	Mikayla	Wissanji	\N	STUDENT	11440	12	HS	\N	\N
238	Leti	Bwonya	\N	STUDENT	12270	12	HS	\N	\N
242	Mairi	Kurauchi	\N	STUDENT	11491	3	ES	\N	\N
243	Meiya	Chandaria	\N	STUDENT	10932	5	ES	\N	\N
244	Aiden	Inwani	\N	STUDENT	12531	11	HS	\N	\N
245	Nirvaan	Shah	\N	STUDENT	10774	12	HS	\N	\N
246	Ziya	Butt	\N	STUDENT	11401	9	HS	\N	\N
247	Sofia	Shamji	\N	STUDENT	11839	8	MS	\N	\N
248	Oumi	Tall	\N	STUDENT	11472	5	ES	\N	\N
249	Yasmin	Price-Abdi	\N	STUDENT	10487	12	HS	\N	\N
250	Kaitlyn	Fort	\N	STUDENT	11704	3	ES	\N	\N
251	Keiya	Raja	\N	STUDENT	10637	8	MS	\N	\N
252	Ryka	Shah	\N	STUDENT	10955	12	HS	\N	\N
253	Ruby	Muoki	\N	STUDENT	12278	11	HS	\N	\N
254	Siana	Chandaria	\N	STUDENT	25072	11	HS	\N	\N
255	Tatyana	Wangari	\N	STUDENT	11877	12	HS	\N	\N
256	Sohan	Shah	\N	STUDENT	11190	12	HS	\N	\N
257	Zameer	Nanji	\N	STUDENT	10416	9	HS	\N	\N
258	Esther	Paul	\N	STUDENT	11326	8	MS	\N	\N
259	Liam	Sanders	\N	STUDENT	10430	10	HS	\N	\N
260	Teresa	Sanders	\N	STUDENT	10431	12	HS	\N	\N
261	Sarah	Melson	\N	STUDENT	12132	9	HS	\N	\N
262	Kaysan Karim	Kurji	\N	STUDENT	12229	3	ES	\N	\N
263	Ashi	Doshi	\N	STUDENT	11768	4	ES	\N	\N
264	Anay	Doshi	\N	STUDENT	10636	8	MS	\N	\N
265	Bianca	Bini	\N	STUDENT	12731	2	ES	\N	\N
266	Otis	Cutler	\N	STUDENT	11535	4	ES	\N	\N
267	Leo	Cutler	\N	STUDENT	10673	9	HS	\N	\N
268	Andrew	Wachira	\N	STUDENT	20866	10	HS	\N	\N
269	Jordan	Nzioka	\N	STUDENT	11884	2	ES	\N	\N
270	Zuriel	Nzioka	\N	STUDENT	11313	4	ES	\N	\N
271	Radek Tidi	Otieno	\N	STUDENT	10865	5	ES	\N	\N
272	Ranam Telu	Otieno	\N	STUDENT	10943	5	ES	\N	\N
273	Riani Tunu	Otieno	\N	STUDENT	10866	5	ES	\N	\N
274	Sachin	Weaver	\N	STUDENT	10715	11	HS	\N	\N
275	Mark	Landolt	\N	STUDENT	12284	8	MS	\N	\N
276	Kianu	Ruiz Stannah	\N	STUDENT	10247	7	MS	\N	\N
277	Tamia	Ruiz Stannah	\N	STUDENT	25032	11	HS	\N	\N
278	Ahmad Eissa	Noordin	\N	STUDENT	11611	4	ES	\N	\N
279	Lily	Herman-Roloff	\N	STUDENT	12194	3	ES	\N	\N
280	Shela	Herman-Roloff	\N	STUDENT	12195	5	ES	\N	\N
281	Bruke	Baheta	\N	STUDENT	10800	8	MS	\N	\N
282	Helina	Baheta	\N	STUDENT	20766	11	HS	\N	\N
283	Jonathan	Bjornholm	\N	STUDENT	11040	11	HS	\N	\N
284	Rose	Vellenga	\N	STUDENT	11574	4	ES	\N	\N
285	Solomon	Vellenga	\N	STUDENT	11573	5	ES	\N	\N
286	Ishaan	Patel	\N	STUDENT	11255	4	ES	\N	\N
287	Ciaran	Clements	\N	STUDENT	11843	8	MS	\N	\N
288	Ahana	Nair	\N	STUDENT	12332	1	ES	\N	\N
289	Aryaan	Pattni	\N	STUDENT	11729	4	ES	\N	\N
290	Hana	Boxer	\N	STUDENT	11200	11	HS	\N	\N
291	Parth	Shah	\N	STUDENT	10993	10	HS	\N	\N
292	Layla	Khubchandani	\N	STUDENT	11263	9	HS	\N	\N
293	Nikhil	Patel	\N	STUDENT	12494	1	ES	\N	\N
294	Janak	Shah	\N	STUDENT	10830	11	HS	\N	\N
295	Saba	Tunbridge	\N	STUDENT	10645	12	HS	\N	\N
296	Shriya	Manek	\N	STUDENT	11777	11	HS	\N	\N
297	Diane	Bamlango	\N	STUDENT	12371	K	ES	\N	\N
303	Cecile	Bamlango	\N	STUDENT	10979	11	HS	\N	\N
304	Vanaaya	Patel	\N	STUDENT	20839	9	HS	\N	\N
305	Veer	Patel	\N	STUDENT	20840	9	HS	\N	\N
306	Laina	Shah	\N	STUDENT	11502	4	ES	\N	\N
307	Savir	Shah	\N	STUDENT	10965	7	MS	\N	\N
308	Nikolaj	Vestergaard	\N	STUDENT	11789	3	ES	\N	\N
309	Kian	Allport	\N	STUDENT	11445	12	HS	\N	\N
310	Reid	Hagelberg	\N	STUDENT	12094	9	HS	\N	\N
311	Zoe Rose	Hagelberg	\N	STUDENT	12077	11	HS	\N	\N
312	Juju	Kimmelman-May	\N	STUDENT	12354	4	ES	\N	\N
313	Chloe	Kimmelman-May	\N	STUDENT	12353	8	MS	\N	\N
314	Tara	Uberoi	\N	STUDENT	11452	11	HS	\N	\N
315	Chansa	Mwenya	\N	STUDENT	24018	12	HS	\N	\N
316	Liam	Patel	\N	STUDENT	11486	4	ES	\N	\N
317	Shane	Patel	\N	STUDENT	10138	8	MS	\N	\N
318	Rhiyana	Patel	\N	STUDENT	26025	10	HS	\N	\N
319	Yash	Pattni	\N	STUDENT	10334	7	MS	\N	\N
320	Gaurav	Samani	\N	STUDENT	11179	5	ES	\N	\N
321	Siddharth	Samani	\N	STUDENT	11180	5	ES	\N	\N
322	Kiara	Bhandari	\N	STUDENT	10791	9	HS	\N	\N
323	Safa	Monadjem	\N	STUDENT	12224	3	ES	\N	\N
324	Malaika	Monadjem	\N	STUDENT	25076	11	HS	\N	\N
325	Sam	Khagram	\N	STUDENT	11858	10	HS	\N	\N
326	Radha	Shah	\N	STUDENT	10786	7	MS	\N	\N
327	Vishnu	Shah	\N	STUDENT	10796	10	HS	\N	\N
328	Cuyuni	Khan	\N	STUDENT	12013	10	HS	\N	\N
329	Lengai	Inglis	\N	STUDENT	12131	9	HS	\N	\N
330	Mathias	Yohannes	\N	STUDENT	20875	10	HS	\N	\N
331	Avish	Arora	\N	STUDENT	12129	9	HS	\N	\N
332	Saptha Girish	Bommadevara	\N	STUDENT	10504	10	HS	\N	\N
333	Sharmila Devi	Bommadevara	\N	STUDENT	10505	12	HS	\N	\N
334	Adama	Sangare	\N	STUDENT	12309	11	HS	\N	\N
335	Gabrielle	Trottier	\N	STUDENT	11945	9	HS	\N	\N
336	Mannat	Suri	\N	STUDENT	11485	4	ES	\N	\N
337	Armaan	Suri	\N	STUDENT	11076	7	MS	\N	\N
338	Zoe	Furness	\N	STUDENT	11101	12	HS	\N	\N
339	Tandin	Tshomo	\N	STUDENT	12442	7	MS	\N	\N
340	Thuji	Zangmo	\N	STUDENT	12394	8	MS	\N	\N
341	Maxym	Berezhny	\N	STUDENT	10878	9	HS	\N	\N
342	Thomas	Higgins	\N	STUDENT	11744	10	HS	\N	\N
343	Louisa	Higgins	\N	STUDENT	11743	12	HS	\N	\N
344	Indhira	Startup	\N	STUDENT	12244	2	ES	\N	\N
345	Anyamarie	Lindgren	\N	STUDENT	11389	8	MS	\N	\N
346	Takumi	Plunkett	\N	STUDENT	12854	8	MS	\N	\N
347	Catherina	Gagnidze	\N	STUDENT	11556	12	HS	\N	\N
348	Adam	Jama	\N	STUDENT	11676	2	ES	\N	\N
349	Amina	Jama	\N	STUDENT	11675	4	ES	\N	\N
350	Guled	Jama	\N	STUDENT	12757	6	MS	\N	\N
351	Noha	Salituri	\N	STUDENT	12211	1	ES	\N	\N
352	Amaia	Salituri	\N	STUDENT	12212	4	ES	\N	\N
353	Leone	Salituri	\N	STUDENT	12213	4	ES	\N	\N
354	Sorawit (Nico)	Thongmod	\N	STUDENT	12214	5	ES	\N	\N
355	Henk	Makimei	\N	STUDENT	11860	12	HS	\N	\N
989	Patrick	Ryan	\N	STUDENT	12816	4	ES	\N	\N
362	Mira	Maldonado	\N	STUDENT	11175	10	HS	\N	\N
363	Che	Maldonado	\N	STUDENT	11170	12	HS	\N	\N
364	Phuong An	Nguyen	\N	STUDENT	11261	4	ES	\N	\N
365	Charlotte	Smith	\N	STUDENT	12705	4	ES	\N	\N
366	Olivia	Von Strauss	\N	STUDENT	12719	1	ES	\N	\N
367	Gabriel	Petrangeli	\N	STUDENT	11009	12	HS	\N	\N
368	Jihwan	Hwang	\N	STUDENT	11951	5	ES	\N	\N
369	Anneka	Hornor	\N	STUDENT	12377	10	HS	\N	\N
370	Florencia	Veveiros	\N	STUDENT	12008	5	ES	\N	\N
371	Xavier	Veveiros	\N	STUDENT	12009	10	HS	\N	\N
372	Laras	Clark	\N	STUDENT	11786	3	ES	\N	\N
373	Galuh	Clark	\N	STUDENT	11787	7	MS	\N	\N
374	Miriam	Schwabel	\N	STUDENT	12267	12	HS	\N	\N
375	Ben	Gremley	\N	STUDENT	12113	10	HS	\N	\N
376	Calvin	Gremley	\N	STUDENT	12115	10	HS	\N	\N
377	Danial	Baig-Giannotti	\N	STUDENT	12546	1	ES	\N	\N
378	Daria	Baig-Giannotti	\N	STUDENT	11593	4	ES	\N	\N
379	Ciara	Jackson	\N	STUDENT	12071	11	HS	\N	\N
380	Ansley	Nelson	\N	STUDENT	12806	1	ES	\N	\N
381	Caroline	Nelson	\N	STUDENT	12803	4	ES	\N	\N
382	Tamara	Wanyoike	\N	STUDENT	12658	11	HS	\N	\N
383	Marcella	Cowan	\N	STUDENT	12437	8	MS	\N	\N
384	Alisia	Sommerlund	\N	STUDENT	11717	7	MS	\N	\N
385	Lea	Castel-Wang	\N	STUDENT	12507	10	HS	\N	\N
386	Anisha	Som Chaudhuri	\N	STUDENT	12707	4	ES	\N	\N
387	Gloria	Jacques	\N	STUDENT	12067	11	HS	\N	\N
388	Dana	Nurshaikhova	\N	STUDENT	11938	9	HS	\N	\N
389	Raheel	Shah	\N	STUDENT	12161	8	MS	\N	\N
390	Rohan	Shah	\N	STUDENT	20850	10	HS	\N	\N
391	Malou	Burmester	\N	STUDENT	11395	5	ES	\N	\N
392	Nicholas	Burmester	\N	STUDENT	11394	8	MS	\N	\N
393	Ethan	Sengendo	\N	STUDENT	11702	10	HS	\N	\N
394	Omer	Osman	\N	STUDENT	12443	1	ES	\N	\N
395	Felix	Jensen	\N	STUDENT	12238	2	ES	\N	\N
396	Fiona	Jensen	\N	STUDENT	12237	3	ES	\N	\N
397	Andrew	Gerba	\N	STUDENT	11462	7	MS	\N	\N
398	Madigan	Gerba	\N	STUDENT	11507	9	HS	\N	\N
399	Porter	Gerba	\N	STUDENT	11449	11	HS	\N	\N
400	Aaron	Atamuradov	\N	STUDENT	11800	5	ES	\N	\N
401	Arina	Atamuradova	\N	STUDENT	11752	11	HS	\N	\N
402	Seojun	Yoon	\N	STUDENT	12792	7	MS	\N	\N
403	Seohyeon	Yoon	\N	STUDENT	12791	9	HS	\N	\N
404	Sasha	Allard Ruiz	\N	STUDENT	11387	12	HS	\N	\N
405	Ali	Alnaqbi	\N	STUDENT	12910	2	ES	\N	\N
406	Almayasa	Alnaqbi	\N	STUDENT	12908	7	MS	\N	\N
407	Fatima	Alnaqbi	\N	STUDENT	12907	9	HS	\N	\N
408	Ibrahim	Alnaqbi	\N	STUDENT	12906	10	HS	\N	\N
409	Rasmus	Jabbour	\N	STUDENT	12396	1	ES	\N	\N
410	Olivia	Jabbour	\N	STUDENT	12395	4	ES	\N	\N
411	Tobin	Allen	\N	STUDENT	12308	9	HS	\N	\N
412	Corinne	Allen	\N	STUDENT	12307	12	HS	\N	\N
413	Maya	Ben Anat	\N	STUDENT	12643	PK	ES	\N	\N
414	Ella	Ben Anat	\N	STUDENT	11475	5	ES	\N	\N
415	Shira	Ben Anat	\N	STUDENT	11518	8	MS	\N	\N
416	Amishi	Mishra	\N	STUDENT	12489	12	HS	\N	\N
417	Arushi	Mishra	\N	STUDENT	12488	12	HS	\N	\N
418	Riley	O'neill Calver	\N	STUDENT	11488	4	ES	\N	\N
419	Lukas	Norman	\N	STUDENT	11534	10	HS	\N	\N
420	Lise	Norman	\N	STUDENT	11533	12	HS	\N	\N
423	Ella	Sims	\N	STUDENT	24043	12	HS	\N	\N
424	Sebastian	Wikenczy Thomsen	\N	STUDENT	11446	11	HS	\N	\N
425	Logan Lilly	Foley	\N	STUDENT	11758	3	ES	\N	\N
426	James	Mills	\N	STUDENT	12376	11	HS	\N	\N
427	Amira	Goold	\N	STUDENT	11820	5	ES	\N	\N
428	Micaella	Shenge	\N	STUDENT	11527	6	MS	\N	\N
429	Siri	Huber	\N	STUDENT	12338	5	ES	\N	\N
430	Lisa	Huber	\N	STUDENT	12339	9	HS	\N	\N
431	Jara	Huber	\N	STUDENT	12340	10	HS	\N	\N
432	Case	O'hearn	\N	STUDENT	12764	7	MS	\N	\N
433	Maeve	O'hearn	\N	STUDENT	12763	10	HS	\N	\N
434	Komborero	Chigudu	\N	STUDENT	11375	5	ES	\N	\N
435	Munashe	Chigudu	\N	STUDENT	11376	8	MS	\N	\N
436	Nyasha	Chigudu	\N	STUDENT	11373	11	HS	\N	\N
437	Kodjiro	Sakaedani Petrovic	\N	STUDENT	12271	11	HS	\N	\N
438	Ines Clelia	Essoungou	\N	STUDENT	12522	10	HS	\N	\N
439	Caspian	Mcsharry	\N	STUDENT	12562	5	ES	\N	\N
440	Theodore	Mcsharry	\N	STUDENT	12563	9	HS	\N	\N
441	Joshua	Exel	\N	STUDENT	12073	10	HS	\N	\N
442	Hannah	Exel	\N	STUDENT	12074	12	HS	\N	\N
443	Sumedh Vedya	Vutukuru	\N	STUDENT	11569	12	HS	\N	\N
444	Nyasha	Mabaso	\N	STUDENT	11657	5	ES	\N	\N
445	Jack	Young	\N	STUDENT	12323	8	MS	\N	\N
446	Annie	Young	\N	STUDENT	12378	11	HS	\N	\N
447	Sofia	Peck	\N	STUDENT	11892	12	HS	\N	\N
448	Elia	O'hara	\N	STUDENT	12062	11	HS	\N	\N
449	Becca	Friedman	\N	STUDENT	12200	5	ES	\N	\N
450	Nandipha	Murape	\N	STUDENT	11700	11	HS	\N	\N
451	Sarah	Van Der Vliet	\N	STUDENT	11630	7	MS	\N	\N
452	Grecy	Van Der Vliet	\N	STUDENT	11629	12	HS	\N	\N
453	Maila	Giri	\N	STUDENT	12421	3	ES	\N	\N
454	Rohan	Giri	\N	STUDENT	12410	10	HS	\N	\N
455	Ao	Kasahara	\N	STUDENT	13041	K	ES	\N	\N
456	Leonard	Laurits	\N	STUDENT	12250	1	ES	\N	\N
457	Charlotte	Laurits	\N	STUDENT	12249	3	ES	\N	\N
458	Kai	Jansson	\N	STUDENT	11761	3	ES	\N	\N
459	Ines Elise	Hansen	\N	STUDENT	12363	2	ES	\N	\N
460	Marius	Hansen	\N	STUDENT	12365	6	MS	\N	\N
461	Minseo	Choi	\N	STUDENT	11145	4	ES	\N	\N
462	Abigail	Tassew	\N	STUDENT	12637	3	ES	\N	\N
463	Nathan	Tassew	\N	STUDENT	12636	10	HS	\N	\N
464	Catherine	Johnson	\N	STUDENT	12867	1	ES	\N	\N
465	Brycelyn	Johnson	\N	STUDENT	12866	6	MS	\N	\N
466	Azzalina	Johnson	\N	STUDENT	12865	10	HS	\N	\N
467	Aaditya	Raja	\N	STUDENT	12103	10	HS	\N	\N
468	Leila	Priestley	\N	STUDENT	20843	11	HS	\N	\N
469	Saron	Piper	\N	STUDENT	25038	11	HS	\N	\N
470	Maxwell	Mazibuko	\N	STUDENT	12574	10	HS	\N	\N
471	Naledi	Mazibuko	\N	STUDENT	12573	10	HS	\N	\N
472	Sechaba	Mazibuko	\N	STUDENT	12575	10	HS	\N	\N
473	Ananya	Raval	\N	STUDENT	12257	1	ES	\N	\N
474	Christopher Ross	Donohue	\N	STUDENT	10333	7	MS	\N	\N
475	Luna	Cooney	\N	STUDENT	12111	3	ES	\N	\N
476	Maïa	Cooney	\N	STUDENT	12110	10	HS	\N	\N
477	Danaé	Materne	\N	STUDENT	12154	9	HS	\N	\N
478	Ameya	Dale	\N	STUDENT	10495	11	HS	\N	\N
479	Arthur	Hire	\N	STUDENT	11232	4	ES	\N	\N
484	Akshith	Sekar	\N	STUDENT	10676	10	HS	\N	\N
485	Elsa	Lloyd	\N	STUDENT	11464	7	MS	\N	\N
486	Laé	Firzé Al Ghaoui	\N	STUDENT	12191	5	ES	\N	\N
487	Alessia	Quacquarella	\N	STUDENT	11461	5	ES	\N	\N
488	Hamish	Ledgard	\N	STUDENT	12268	12	HS	\N	\N
489	Sophia	Shahbal	\N	STUDENT	12742	K	ES	\N	\N
490	Saif	Shahbal	\N	STUDENT	12712	2	ES	\N	\N
491	Jonathan	Rwehumbiza	\N	STUDENT	11854	10	HS	\N	\N
492	Simone	Eidex	\N	STUDENT	11897	11	HS	\N	\N
493	Alston	Schenck	\N	STUDENT	11484	4	ES	\N	\N
494	Troy	Hopps	\N	STUDENT	12306	3	ES	\N	\N
495	Noah	Hughes	\N	STUDENT	10477	11	HS	\N	\N
496	Maximus	Njenga	\N	STUDENT	12303	2	ES	\N	\N
497	Sadie	Njenga	\N	STUDENT	12279	5	ES	\N	\N
498	Justin	Njenga	\N	STUDENT	12281	10	HS	\N	\N
499	Daniel	Jensen	\N	STUDENT	11898	10	HS	\N	\N
500	Maya	Thibodeau	\N	STUDENT	12357	8	MS	\N	\N
501	Lorenzo	De Vries Aguirre	\N	STUDENT	11552	9	HS	\N	\N
502	Marco	De Vries Aguirre	\N	STUDENT	11551	12	HS	\N	\N
503	Adam	Saleem	\N	STUDENT	12620	2	ES	\N	\N
504	Emir	Abdellahi	\N	STUDENT	11605	11	HS	\N	\N
505	Maliah	O'neal	\N	STUDENT	11912	8	MS	\N	\N
506	Caio	Kraemer	\N	STUDENT	11906	9	HS	\N	\N
507	Isabela	Kraemer	\N	STUDENT	11907	12	HS	\N	\N
508	Eva	Bannikau	\N	STUDENT	11780	4	ES	\N	\N
509	Alba	Prawitz	\N	STUDENT	12291	2	ES	\N	\N
510	Max	Prawitz	\N	STUDENT	12298	5	ES	\N	\N
511	Leo	Prawitz	\N	STUDENT	12297	6	MS	\N	\N
512	Abigail	Holder	\N	STUDENT	12060	5	ES	\N	\N
513	Charles	Holder	\N	STUDENT	12059	11	HS	\N	\N
514	Isabel	Holder	\N	STUDENT	12056	12	HS	\N	\N
515	Sebastian	Ansorg	\N	STUDENT	12656	7	MS	\N	\N
516	Leon	Ansorg	\N	STUDENT	12655	11	HS	\N	\N
517	Pilar	Bosch	\N	STUDENT	12217	K	ES	\N	\N
518	Moira	Bosch	\N	STUDENT	12218	2	ES	\N	\N
519	Blanca	Bosch	\N	STUDENT	12219	4	ES	\N	\N
520	Aven	Ross	\N	STUDENT	11678	7	MS	\N	\N
521	Kai	Herbst	\N	STUDENT	12231	2	ES	\N	\N
522	Sofia	Herbst	\N	STUDENT	12230	4	ES	\N	\N
523	Michael	Bierly	\N	STUDENT	12179	8	MS	\N	\N
524	Miya	Stephens	\N	STUDENT	11802	5	ES	\N	\N
525	Jihong	Joo	\N	STUDENT	11686	10	HS	\N	\N
526	Hyojin	Joo	\N	STUDENT	11685	12	HS	\N	\N
527	Bruno	Sottsas	\N	STUDENT	12358	4	ES	\N	\N
528	Natasha	Sottsas	\N	STUDENT	12359	7	MS	\N	\N
19	Theodore	Ashton	\N	STUDENT	11893	9	HS	\N	\N
529	Krishna	Gandhi	\N	STUDENT	12525	10	HS	\N	\N
530	Hrushikesh	Gandhi	\N	STUDENT	12524	12	HS	\N	\N
531	Max	Leon	\N	STUDENT	12490	12	HS	\N	\N
532	Myra	Korngold	\N	STUDENT	12775	5	ES	\N	\N
533	Mila Ruth	Korngold	\N	STUDENT	12773	7	MS	\N	\N
534	Alexander	Tarquini	\N	STUDENT	12223	4	ES	\N	\N
535	Marian	Abukari	\N	STUDENT	10602	7	MS	\N	\N
536	Manuela	Abukari	\N	STUDENT	10672	9	HS	\N	\N
537	Soren	Mansourian	\N	STUDENT	12470	1	ES	\N	\N
542	Manali	Caminha	\N	STUDENT	12079	9	HS	\N	\N
543	Nomi	Leca Turner	\N	STUDENT	12894	PK	ES	\N	\N
544	Enzo	Leca Turner	\N	STUDENT	12893	1	ES	\N	\N
545	Kelsie	Karuga	\N	STUDENT	12162	6	MS	\N	\N
546	Kayla	Karuga	\N	STUDENT	12163	8	MS	\N	\N
547	Tamar	Jones-Avni	\N	STUDENT	12897	K	ES	\N	\N
548	Dov	Jones-Avni	\N	STUDENT	12784	2	ES	\N	\N
549	Nahal	Jones-Avni	\N	STUDENT	12783	4	ES	\N	\N
550	Noa	Godden	\N	STUDENT	12504	5	ES	\N	\N
551	Emma	Godden	\N	STUDENT	12479	9	HS	\N	\N
552	Lisa	Godden	\N	STUDENT	12478	10	HS	\N	\N
553	Ella	Acharya	\N	STUDENT	12882	1	ES	\N	\N
554	Anshi	Acharya	\N	STUDENT	12881	7	MS	\N	\N
555	Clara	Hardy	\N	STUDENT	12722	1	ES	\N	\N
556	Safari	Dara	\N	STUDENT	11958	4	ES	\N	\N
557	Moira	Koucheravy	\N	STUDENT	12305	4	ES	\N	\N
558	Carys	Koucheravy	\N	STUDENT	12304	8	MS	\N	\N
559	Edouard	Germain	\N	STUDENT	12258	11	HS	\N	\N
560	Jacob	Germain	\N	STUDENT	12259	11	HS	\N	\N
561	Lynn Htet	Aung	\N	STUDENT	12293	5	ES	\N	\N
562	Phyo Nyein Nyein	Thu	\N	STUDENT	12302	7	MS	\N	\N
563	Ronan	Patel	\N	STUDENT	10119	8	MS	\N	\N
564	Annabel	Asamoah	\N	STUDENT	10746	11	HS	\N	\N
565	Teo	Duwyn	\N	STUDENT	12085	5	ES	\N	\N
566	Mia	Duwyn	\N	STUDENT	12086	9	HS	\N	\N
567	Cato	Van Bommel	\N	STUDENT	12028	11	HS	\N	\N
568	Henrik	Raehalme	\N	STUDENT	12698	1	ES	\N	\N
569	Emilia	Raehalme	\N	STUDENT	12697	5	ES	\N	\N
570	Asara	O'bra	\N	STUDENT	12341	9	HS	\N	\N
571	Seonu	Lee	\N	STUDENT	12449	3	ES	\N	\N
572	Maya	Davis	\N	STUDENT	10953	12	HS	\N	\N
573	Anika	Bruhwiler	\N	STUDENT	12050	12	HS	\N	\N
574	Mila	Jovanovic	\N	STUDENT	12678	5	ES	\N	\N
575	Dunja	Jovanovic	\N	STUDENT	12677	8	MS	\N	\N
576	Elise	Walji	\N	STUDENT	12740	2	ES	\N	\N
577	Felyne	Walji	\N	STUDENT	12739	3	ES	\N	\N
578	Dechen	Jacob	\N	STUDENT	12765	7	MS	\N	\N
579	Tenzin	Jacob	\N	STUDENT	12766	11	HS	\N	\N
580	Fatoumata	Touré	\N	STUDENT	12324	4	ES	\N	\N
581	Ousmane	Touré	\N	STUDENT	12325	5	ES	\N	\N
582	Helena	Khayat De Andrade	\N	STUDENT	12642	PK	ES	\N	\N
583	Sophia	Khayat De Andrade	\N	STUDENT	12650	1	ES	\N	\N
584	Maelle	Nitcheu	\N	STUDENT	12762	PK	ES	\N	\N
585	Margot	Nitcheu	\N	STUDENT	12415	2	ES	\N	\N
586	Marion	Nitcheu	\N	STUDENT	12417	3	ES	\N	\N
587	Eva	Fernstrom	\N	STUDENT	11939	5	ES	\N	\N
588	Sienna	Barragan Sofrony	\N	STUDENT	12831	K	ES	\N	\N
589	Gael	Barragan Sofrony	\N	STUDENT	12711	3	ES	\N	\N
590	William	Jansen	\N	STUDENT	11837	8	MS	\N	\N
591	Matias	Jansen	\N	STUDENT	11855	10	HS	\N	\N
592	Siri	Maagaard	\N	STUDENT	12827	4	ES	\N	\N
593	Laerke	Maagaard	\N	STUDENT	12826	9	HS	\N	\N
594	Chae Hyun	Jin	\N	STUDENT	12647	PK	ES	\N	\N
595	A-Hyun	Jin	\N	STUDENT	12246	2	ES	\N	\N
596	Pietro	Fundaro	\N	STUDENT	11329	10	HS	\N	\N
597	Jade	Onderi	\N	STUDENT	11847	9	HS	\N	\N
598	Nikhil	Kimatrai	\N	STUDENT	11810	9	HS	\N	\N
599	Rhea	Kimatrai	\N	STUDENT	11809	9	HS	\N	\N
600	Kennedy	Ireri	\N	STUDENT	10313	9	HS	\N	\N
603	Kaynan	Abshir	\N	STUDENT	12830	K	ES	\N	\N
604	Farzin	Taneem	\N	STUDENT	11335	7	MS	\N	\N
605	Umaiza	Taneem	\N	STUDENT	11336	8	MS	\N	\N
606	Oagile	Mothobi	\N	STUDENT	12808	1	ES	\N	\N
607	Resegofetse	Mothobi	\N	STUDENT	12807	4	ES	\N	\N
608	Soline	Wittmann	\N	STUDENT	12429	10	HS	\N	\N
609	Mateo	Muziramakenga	\N	STUDENT	12704	1	ES	\N	\N
610	Aiden	Muziramakenga	\N	STUDENT	12703	4	ES	\N	\N
611	Charlie	Carver Wildig	\N	STUDENT	12602	5	ES	\N	\N
612	Barney	Carver Wildig	\N	STUDENT	12601	7	MS	\N	\N
613	Jijoon	Park	\N	STUDENT	12787	2	ES	\N	\N
614	Jooan	Park	\N	STUDENT	12786	4	ES	\N	\N
615	Zohar	Hercberg	\N	STUDENT	12745	PK	ES	\N	\N
616	Amitai	Hercberg	\N	STUDENT	12680	3	ES	\N	\N
617	Uriya	Hercberg	\N	STUDENT	12682	7	MS	\N	\N
618	Rafael	Carter	\N	STUDENT	12776	8	MS	\N	\N
619	Vihaan	Arora	\N	STUDENT	12242	2	ES	\N	\N
620	Sofia	Crandall	\N	STUDENT	12990	12	HS	\N	\N
621	Almaira	Ihsan	\N	STUDENT	13061	5	ES	\N	\N
622	Rayyan	Ihsan	\N	STUDENT	13060	7	MS	\N	\N
623	Zakhrafi	Ihsan	\N	STUDENT	13063	11	HS	\N	\N
624	Alexander	Thomas	\N	STUDENT	12579	11	HS	\N	\N
626	Samuel	Dove	\N	STUDENT	12920	11	HS	\N	\N
627	Alvin	Ngumi	\N	STUDENT	12588	11	HS	\N	\N
628	Julia	Handler	\N	STUDENT	13100	6	MS	\N	\N
629	Josephine	Maguire	\N	STUDENT	12592	8	MS	\N	\N
630	Theodore	Maguire	\N	STUDENT	12593	10	HS	\N	\N
631	Deniza	Kasymbekova Tauras	\N	STUDENT	13027	5	ES	\N	\N
632	Amman	Assefa	\N	STUDENT	12669	8	MS	\N	\N
633	Lucas	Maasdorp Mogollon	\N	STUDENT	12822	1	ES	\N	\N
634	Gabriela	Maasdorp Mogollon	\N	STUDENT	12821	4	ES	\N	\N
635	Dallin	Daines	\N	STUDENT	13064	2	ES	\N	\N
636	Caleb	Daines	\N	STUDENT	13084	4	ES	\N	\N
637	Gabriel	Mccown	\N	STUDENT	12833	K	ES	\N	\N
638	Clea	Mccown	\N	STUDENT	12837	2	ES	\N	\N
639	Beckham	Stock	\N	STUDENT	12916	2	ES	\N	\N
640	Payton	Stock	\N	STUDENT	12914	11	HS	\N	\N
641	Ruhan	Reza	\N	STUDENT	13021	7	MS	\N	\N
642	Nandita	Sankar	\N	STUDENT	12802	3	ES	\N	\N
643	Ian	Kavaleuski	\N	STUDENT	13059	10	HS	\N	\N
644	Kian	Ghelani-Decorte	\N	STUDENT	12673	8	MS	\N	\N
645	Elrad	Abdurazakov	\N	STUDENT	12690	6	MS	\N	\N
646	Malik	Kamara	\N	STUDENT	12724	1	ES	\N	\N
647	Ethan	Diehl	\N	STUDENT	12863	PK	ES	\N	\N
648	Malcolm	Diehl	\N	STUDENT	12864	1	ES	\N	\N
649	Elena	Mosher	\N	STUDENT	12710	1	ES	\N	\N
650	Emma	Mosher	\N	STUDENT	12709	3	ES	\N	\N
651	Abibatou	Magassouba	\N	STUDENT	13092	2	ES	\N	\N
652	Sada	Bomba	\N	STUDENT	12989	11	HS	\N	\N
653	Tamaki	Ishikawa	\N	STUDENT	13054	3	ES	\N	\N
654	Colin	Walls	\N	STUDENT	12475	3	ES	\N	\N
655	Ethan	Walls	\N	STUDENT	12474	5	ES	\N	\N
656	Emilin	Patterson	\N	STUDENT	12811	3	ES	\N	\N
657	Kaitlin	Patterson	\N	STUDENT	12810	7	MS	\N	\N
658	Elsie	Mackay	\N	STUDENT	12886	4	ES	\N	\N
664	Nora	Mackay	\N	STUDENT	12885	6	MS	\N	\N
665	Samantha	Ishee	\N	STUDENT	12832	K	ES	\N	\N
666	Emily	Ishee	\N	STUDENT	12836	5	ES	\N	\N
667	Sonya	Wagner	\N	STUDENT	12892	4	ES	\N	\N
668	Ayaan	Pabani	\N	STUDENT	12256	1	ES	\N	\N
669	Arth	Jain	\N	STUDENT	13088	K	ES	\N	\N
670	Caleb	Fekadeneh	\N	STUDENT	12641	5	ES	\N	\N
671	Sina	Fekadeneh	\N	STUDENT	12633	10	HS	\N	\N
672	Marc-Andri	Bachmann	\N	STUDENT	12604	8	MS	\N	\N
673	Ralia	Daher	\N	STUDENT	13066	PK	ES	\N	\N
674	Abbas	Daher	\N	STUDENT	12435	1	ES	\N	\N
675	Ruth Yifru	Tafesse	\N	STUDENT	13099	11	HS	\N	\N
676	Emil	Grundberg	\N	STUDENT	13019	8	MS	\N	\N
677	Amen	Mezemir	\N	STUDENT	10498	8	MS	\N	\N
678	Zizwani	Chikapa	\N	STUDENT	13101	PK	ES	\N	\N
679	Chawanangwa	Mkandawire	\N	STUDENT	12292	7	MS	\N	\N
680	Daniel	Mkandawire	\N	STUDENT	12272	11	HS	\N	\N
681	Selkie	Douglas-Hamilton Pope	\N	STUDENT	12995	9	HS	\N	\N
682	Yoav	Margovsky-Lotem	\N	STUDENT	12649	PK	ES	\N	\N
683	Liam	Irungu	\N	STUDENT	13039	K	ES	\N	\N
684	Aiden	Irungu	\N	STUDENT	13038	2	ES	\N	\N
685	Feng Zimo	Li	\N	STUDENT	13024	5	ES	\N	\N
686	Feng Milun	Li	\N	STUDENT	13023	7	MS	\N	\N
687	Alice	Grindell	\N	STUDENT	12900	K	ES	\N	\N
688	Emily	Grindell	\N	STUDENT	12061	2	ES	\N	\N
689	Emilie	Abbonizio	\N	STUDENT	13016	11	HS	\N	\N
690	Cassidy	Muttersbaugh	\N	STUDENT	13035	K	ES	\N	\N
691	Magnolia	Muttersbaugh	\N	STUDENT	13034	3	ES	\N	\N
692	Mathis	Bellamy	\N	STUDENT	12823	K	ES	\N	\N
693	Maisha	Donne	\N	STUDENT	12590	11	HS	\N	\N
694	Amanda	Romero Sánchez-Miranda	\N	STUDENT	12800	3	ES	\N	\N
695	Candela	Romero	\N	STUDENT	12799	8	MS	\N	\N
696	Nadia	Nora	\N	STUDENT	12860	11	HS	\N	\N
697	Nayoon	Lee	\N	STUDENT	12626	5	ES	\N	\N
698	Gaspard	Womble	\N	STUDENT	12718	1	ES	\N	\N
699	Nile	Sudra	\N	STUDENT	13065	PK	ES	\N	\N
700	Xinyi	Huang	\N	STUDENT	13074	1	ES	\N	\N
701	Aabhar	Baral	\N	STUDENT	13030	5	ES	\N	\N
702	Azza	Rollins	\N	STUDENT	12982	9	HS	\N	\N
703	Bushra	Hussain	\N	STUDENT	13070	PK	ES	\N	\N
704	Monika	Srutova	\N	STUDENT	12999	8	MS	\N	\N
705	Nyx Verena	Houndeganme	\N	STUDENT	12815	6	MS	\N	\N
706	Michael	Houndeganme	\N	STUDENT	12814	9	HS	\N	\N
707	Crédo Terrence	Houndeganme	\N	STUDENT	12813	12	HS	\N	\N
708	Zefyros	Patrikios	\N	STUDENT	13103	PK	ES	\N	\N
709	Emilio	Trujillo	\N	STUDENT	13067	PK	ES	\N	\N
710	Eitan	Segev	\N	STUDENT	12862	PK	ES	\N	\N
711	Amitai	Segev	\N	STUDENT	12721	1	ES	\N	\N
712	Karina	Maini	\N	STUDENT	12986	10	HS	\N	\N
713	Elena	Moons	\N	STUDENT	12851	7	MS	\N	\N
714	Aymen	Zeynu	\N	STUDENT	12809	3	ES	\N	\N
715	Abem	Zeynu	\N	STUDENT	12552	7	MS	\N	\N
716	Alan	Simek	\N	STUDENT	13015	8	MS	\N	\N
717	Emil	Simek	\N	STUDENT	13014	11	HS	\N	\N
718	Hachim	Gallagher	\N	STUDENT	13083	2	ES	\N	\N
719	Kabir	Jaffer	\N	STUDENT	12646	K	ES	\N	\N
720	Ayaan	Jaffer	\N	STUDENT	11646	4	ES	\N	\N
721	Alifiya	Dawoodbhai	\N	STUDENT	12580	12	HS	\N	\N
722	Ruth	Lindkvist	\N	STUDENT	12578	9	HS	\N	\N
723	Adrian	Otieno	\N	STUDENT	12884	7	MS	\N	\N
724	Aanya	Shah	\N	STUDENT	12583	8	MS	\N	\N
20	Vera	Ashton	\N	STUDENT	11896	11	HS	\N	\N
726	Nora	Schei	\N	STUDENT	12582	8	MS	\N	\N
727	Jake	Schoneveld	\N	STUDENT	13086	PK	ES	\N	\N
728	Roy	Gitiba	\N	STUDENT	12818	7	MS	\N	\N
729	Kirk Wise	Gitiba	\N	STUDENT	12817	9	HS	\N	\N
730	Isaiah	Geller	\N	STUDENT	12539	9	HS	\N	\N
731	Bianca	Mbera	\N	STUDENT	12603	10	HS	\N	\N
732	Kors	Ukumu	\N	STUDENT	12545	9	HS	\N	\N
733	Jiya	Shah	\N	STUDENT	12857	8	MS	\N	\N
734	Zayan	Karmali	\N	STUDENT	13098	10	HS	\N	\N
735	Serenae	Angima	\N	STUDENT	12954	8	MS	\N	\N
736	Fatoumatta	Fatty	\N	STUDENT	12735	12	HS	\N	\N
737	Saone	Kwena	\N	STUDENT	12985	10	HS	\N	\N
738	Howard	Wesley Iii	\N	STUDENT	12861	PK	ES	\N	\N
739	Isabella	Mason	\N	STUDENT	12629	11	HS	\N	\N
740	Ayana	Limpered	\N	STUDENT	13085	PK	ES	\N	\N
741	Arielle	Limpered	\N	STUDENT	12795	2	ES	\N	\N
742	Rakeb	Teklemichael	\N	STUDENT	12412	10	HS	\N	\N
743	Pranai	Shah	\N	STUDENT	12987	11	HS	\N	\N
744	Dhiya	Shah	\N	STUDENT	12541	7	MS	\N	\N
745	Marianne	Roquebrune	\N	STUDENT	12644	PK	ES	\N	\N
746	Nichelle	Somaia	\N	STUDENT	12842	1	ES	\N	\N
747	Shivail	Somaia	\N	STUDENT	11769	4	ES	\N	\N
748	Lukas	Stiles	\N	STUDENT	13068	PK	ES	\N	\N
749	Nikolas	Stiles	\N	STUDENT	11137	5	ES	\N	\N
750	Nathan	Matimu	\N	STUDENT	12979	9	HS	\N	\N
751	Aristophanes	Abreu	\N	STUDENT	12895	K	ES	\N	\N
752	Herson Alexandros	Abreu	\N	STUDENT	12896	1	ES	\N	\N
753	Arthur	Bailey	\N	STUDENT	12825	9	HS	\N	\N
754	Florrie	Bailey	\N	STUDENT	12812	11	HS	\N	\N
755	Adam	Kone	\N	STUDENT	11368	10	HS	\N	\N
756	Zahra	Kone	\N	STUDENT	11367	12	HS	\N	\N
757	Thomas	Wimber	\N	STUDENT	12670	8	MS	\N	\N
758	Rahmaan	Ali	\N	STUDENT	12755	12	HS	\N	\N
759	Davran	Chowdhury	\N	STUDENT	13029	5	ES	\N	\N
760	Nevzad	Chowdhury	\N	STUDENT	12868	11	HS	\N	\N
761	Aariyana	Patel	\N	STUDENT	12553	9	HS	\N	\N
762	Graham	Mueller	\N	STUDENT	12938	7	MS	\N	\N
763	Willem	Mueller	\N	STUDENT	12937	9	HS	\N	\N
764	Christian	Mueller	\N	STUDENT	12936	11	HS	\N	\N
765	Libasse	Ndoye	\N	STUDENT	13075	8	MS	\N	\N
766	Yi (Gavin)	Wang	\N	STUDENT	13020	3	ES	\N	\N
767	Shuyi (Bella)	Wang	\N	STUDENT	12950	8	MS	\N	\N
776	Taim	Hussain	\N	STUDENT	12899	K	ES	\N	\N
777	Kaveer Singh	Hayer	\N	STUDENT	13048	2	ES	\N	\N
778	Manvir Singh	Hayer	\N	STUDENT	12471	7	MS	\N	\N
779	Ahmed Jabir	Bin Taif	\N	STUDENT	12898	K	ES	\N	\N
780	Ahmed Jayed	Bin Taif	\N	STUDENT	12311	2	ES	\N	\N
781	Ahmed Jawad	Bin Taif	\N	STUDENT	12312	5	ES	\N	\N
782	Rebekah Ysabelle	Nas	\N	STUDENT	12978	9	HS	\N	\N
783	Emilia	Husemann	\N	STUDENT	12949	8	MS	\N	\N
784	Luna	Bonde-Nielsen	\N	STUDENT	12891	4	ES	\N	\N
785	Naomi	Alemayehu	\N	STUDENT	13000	4	ES	\N	\N
786	Arabella	Hales	\N	STUDENT	13105	PK	ES	\N	\N
789	Zari	Khan	\N	STUDENT	13087	9	HS	\N	\N
790	Cradle Terry	Alwedo	\N	STUDENT	13026	5	ES	\N	\N
791	Felix	Braun	\N	STUDENT	13095	8	MS	\N	\N
792	Io	Verstraete	\N	STUDENT	12998	10	HS	\N	\N
793	Matthew	Crabtree	\N	STUDENT	12560	11	HS	\N	\N
794	Kieu	Sansculotte	\N	STUDENT	12269	12	HS	\N	\N
795	Daniel	Berkouwer	\N	STUDENT	12496	1	ES	\N	\N
796	Kayla	Opere	\N	STUDENT	12820	PK	ES	\N	\N
797	Léa	Berthellier-Antoine	\N	STUDENT	12794	1	ES	\N	\N
798	Lukas	Kaseva	\N	STUDENT	13104	PK	ES	\N	\N
799	Lauri	Kaseva	\N	STUDENT	13096	3	ES	\N	\N
800	Layal	Khan	\N	STUDENT	12550	2	ES	\N	\N
801	Ishbel	Croze	\N	STUDENT	13062	9	HS	\N	\N
802	Emily	Croucher	\N	STUDENT	12873	5	ES	\N	\N
803	Oliver	Croucher	\N	STUDENT	12874	7	MS	\N	\N
804	Anabelle	Croucher	\N	STUDENT	12875	9	HS	\N	\N
805	Vera	Olvik	\N	STUDENT	12953	8	MS	\N	\N
806	Theodor	Skaaraas-Gjoelberg	\N	STUDENT	12845	1	ES	\N	\N
807	Cedrik	Skaaraas-Gjoelberg	\N	STUDENT	12846	5	ES	\N	\N
808	David	Lee	\N	STUDENT	13089	2	ES	\N	\N
809	Sanaya	Jijina	\N	STUDENT	12736	12	HS	\N	\N
810	Harshaan	Arora	\N	STUDENT	13010	8	MS	\N	\N
811	Tisya	Arora	\N	STUDENT	13009	10	HS	\N	\N
812	Gai	Elkana	\N	STUDENT	13001	1	ES	\N	\N
813	Yuval	Elkana	\N	STUDENT	13002	3	ES	\N	\N
814	Matan	Elkana	\N	STUDENT	13003	5	ES	\N	\N
815	Niccolo	Nasidze	\N	STUDENT	12901	K	ES	\N	\N
816	Jayesh	Aditya	\N	STUDENT	12472	8	MS	\N	\N
817	Zara	Bredin	\N	STUDENT	11851	10	HS	\N	\N
818	Mark	Lavack	\N	STUDENT	20817	8	MS	\N	\N
819	Michael	Lavack	\N	STUDENT	26015	10	HS	\N	\N
820	Rohin	Dodhia	\N	STUDENT	10820	11	HS	\N	\N
821	Jaidyn	Bunch	\N	STUDENT	12508	11	HS	\N	\N
822	Chalita	Victor	\N	STUDENT	12529	11	HS	\N	\N
823	Hannah	Waalewijn	\N	STUDENT	12598	7	MS	\N	\N
824	Simon	Waalewijn	\N	STUDENT	12596	11	HS	\N	\N
825	Kaitlin	Wietecha	\N	STUDENT	12591	10	HS	\N	\N
826	Saoirse	Molloy	\N	STUDENT	12702	2	ES	\N	\N
827	Caelan	Molloy	\N	STUDENT	12701	4	ES	\N	\N
828	Victor	Mollier-Camus	\N	STUDENT	12594	5	ES	\N	\N
829	Elisa	Mollier-Camus	\N	STUDENT	12586	8	MS	\N	\N
830	Jaishna	Varun	\N	STUDENT	12684	7	MS	\N	\N
21	Nathan	Massawe	\N	STUDENT	11932	4	ES	\N	\N
22	Noah	Massawe	\N	STUDENT	11933	8	MS	\N	\N
23	Ziv	Bedein	\N	STUDENT	12746	K	ES	\N	\N
24	Itai	Bedein	\N	STUDENT	12615	4	ES	\N	\N
25	Annika	Purdy	\N	STUDENT	12345	2	ES	\N	\N
26	Christiaan	Purdy	\N	STUDENT	12348	5	ES	\N	\N
27	Gunnar	Purdy	\N	STUDENT	12349	8	MS	\N	\N
28	Lana	Abou Hamda	\N	STUDENT	12780	5	ES	\N	\N
29	Samer	Abou Hamda	\N	STUDENT	12779	8	MS	\N	\N
30	Youssef	Abou Hamda	\N	STUDENT	12778	11	HS	\N	\N
31	Ida-Marie	Andersen	\N	STUDENT	12075	12	HS	\N	\N
831	Leah	Heijstee	\N	STUDENT	12782	3	ES	\N	\N
832	Zara	Heijstee	\N	STUDENT	12781	8	MS	\N	\N
833	Graciela	Sotiriou	\N	STUDENT	12902	K	ES	\N	\N
834	Leonidas	Sotiriou	\N	STUDENT	12239	2	ES	\N	\N
835	Evangelina	Barbacci	\N	STUDENT	12612	7	MS	\N	\N
836	Gabriella	Barbacci	\N	STUDENT	12611	10	HS	\N	\N
837	Santiago	Moyle	\N	STUDENT	12581	9	HS	\N	\N
838	Alissa	Yakusik	\N	STUDENT	13082	4	ES	\N	\N
839	Farah	Ghariani	\N	STUDENT	12662	9	HS	\N	\N
840	Lillian	Cameron-Mutyaba	\N	STUDENT	12634	10	HS	\N	\N
841	Rose	Cameron-Mutyaba	\N	STUDENT	12635	10	HS	\N	\N
842	Nathan	Teferi	\N	STUDENT	12984	10	HS	\N	\N
843	Angab	Mayar	\N	STUDENT	13057	11	HS	\N	\N
844	Hanina	Abdosh	\N	STUDENT	12737	12	HS	\N	\N
849	Liri	Alemu	\N	STUDENT	12732	3	ES	\N	\N
850	Ishanvi	Ishanvi	\N	STUDENT	13053	K	ES	\N	\N
878	Alexandre	Patenaude	\N	STUDENT	12743	K	ES	\N	\N
879	Ren	Hirose	\N	STUDENT	13040	1	ES	\N	\N
880	Abel	Johnson	\N	STUDENT	12767	1	ES	\N	\N
881	Issa	Kane	\N	STUDENT	13037	1	ES	\N	\N
882	Beatrix	Kiers	\N	STUDENT	12717	1	ES	\N	\N
883	Yousif	Menkerios	\N	STUDENT	12459	1	ES	\N	\N
884	Clayton	Oberjuerge	\N	STUDENT	12687	1	ES	\N	\N
885	Yash	Pant	\N	STUDENT	12480	1	ES	\N	\N
886	Amandla	Pijovic	\N	STUDENT	13090	1	ES	\N	\N
887	Paola	Santos	\N	STUDENT	13094	1	ES	\N	\N
888	Amaya	Sarfaraz	\N	STUDENT	12608	1	ES	\N	\N
889	Clarice	Schrader	\N	STUDENT	12841	1	ES	\N	\N
911	Uzima	Otieno	uotieno29@isk.ac.ke	STUDENT	13056	7	MS	\N	uotieno29
924	Spencer	Schenck	sschenck30@isk.ac.ke	STUDENT	11457	6	MS	\N	sschenck30
925	Isla	Willis	iwillis30@isk.ac.ke	STUDENT	12969	6	MS	\N	iwillis30
926	Seya	Chandaria	schandaria30@isk.ac.ke	STUDENT	10775	6	MS	\N	schandaria30
927	Malan	Chopra	mchopra30@isk.ac.ke	STUDENT	10508	6	MS	\N	mchopra30
928	Lilla	Vestergaard	svestergaard30@isk.ac.ke	STUDENT	11266	6	MS	\N	svestergaard30
890	Mandisa	Sobantu	\N	STUDENT	12939	1	ES	\N	\N
891	Tasheni	Kamenga	\N	STUDENT	12877	2	ES	\N	\N
892	Theodore	Patenaude	\N	STUDENT	12713	2	ES	\N	\N
893	Ewyn	Soobrattee	\N	STUDENT	12714	2	ES	\N	\N
894	Anna	Von Platen-Hallermund	\N	STUDENT	12888	2	ES	\N	\N
895	Tristan	Wendelboe	\N	STUDENT	12527	2	ES	\N	\N
896	Signe	Andersen	\N	STUDENT	12570	3	ES	\N	\N
897	Holly	Asquith	\N	STUDENT	12944	3	ES	\N	\N
898	Aurélien	Diop Weyer	\N	STUDENT	13033	3	ES	\N	\N
899	Levi	Lundell	\N	STUDENT	12693	3	ES	\N	\N
900	Santiago	Santos	\N	STUDENT	13093	3	ES	\N	\N
901	Genevieve	Schrader	\N	STUDENT	12840	3	ES	\N	\N
902	Martin	Vazquez Eraso	\N	STUDENT	12369	3	ES	\N	\N
903	Magne	Vestergaard	\N	STUDENT	12664	3	ES	\N	\N
904	Nanna	Vestergaard	\N	STUDENT	12665	3	ES	\N	\N
905	Benjamin	Weill	\N	STUDENT	12849	3	ES	\N	\N
906	Kira	Bailey	\N	STUDENT	12289	4	ES	\N	\N
907	Aaryama	Bixby	\N	STUDENT	12850	4	ES	\N	\N
908	Armelle	Carlevato	\N	STUDENT	12925	4	ES	\N	\N
909	Sonia	Corbin	\N	STUDENT	12942	4	ES	\N	\N
910	Zaria	Khalid	\N	STUDENT	12617	4	ES	\N	\N
912	Carlos Laith	Farraj	\N	STUDENT	12607	4	ES	\N	\N
913	Jarius	Farraj	\N	STUDENT	12606	11	HS	\N	\N
914	Murad	Dadashev	\N	STUDENT	12768	8	MS	\N	\N
915	Zubeyda	Dadasheva	\N	STUDENT	12769	12	HS	\N	\N
916	Sumaiya	Iversen	\N	STUDENT	12433	12	HS	\N	\N
917	Nike	Borg Aidnell	\N	STUDENT	12542	2	ES	\N	\N
918	Siv	Borg Aidnell	\N	STUDENT	12543	2	ES	\N	\N
919	Disa	Borg Aidnell	\N	STUDENT	12696	5	ES	\N	\N
920	Ryan	Ellis	\N	STUDENT	12070	11	HS	\N	\N
921	Adrienne	Ellis	\N	STUDENT	12068	12	HS	\N	\N
922	Emalea	Hodge	\N	STUDENT	12192	5	ES	\N	\N
923	Jip	Arens	\N	STUDENT	12430	12	HS	\N	\N
2	Rosa Marie	Rosen	\N	STUDENT	11764	3	ES	\N	\N
3	August	Rosen	\N	STUDENT	11845	9	HS	\N	\N
4	Dawit	Abdissa	\N	STUDENT	13077	8	MS	\N	\N
5	Meron	Abdissa	\N	STUDENT	13078	8	MS	\N	\N
6	Yohanna Wondim Belachew	Andersen	\N	STUDENT	12966	1	ES	\N	\N
7	Yonas Wondim Belachew	Andersen	\N	STUDENT	12968	10	HS	\N	\N
768	Mariam	David-Tafida	\N	STUDENT	12715	2	ES	\N	\N
769	James	Farrell	\N	STUDENT	12720	1	ES	\N	\N
770	Anna Toft	Gronborg	\N	STUDENT	12801	K	ES	\N	\N
771	Rocco	Sidari	\N	STUDENT	13036	2	ES	\N	\N
772	David	Ajidahun	\N	STUDENT	13072	PK	ES	\N	\N
773	Darian	Ajidahun	\N	STUDENT	12805	2	ES	\N	\N
774	Annabelle	Ajidahun	\N	STUDENT	12804	4	ES	\N	\N
775	Saif	Hussain	\N	STUDENT	12328	4	ES	\N	\N
10	Kennedy	Armstrong	\N	STUDENT	12276	11	HS	\N	\N
11	Lily	De Backer	\N	STUDENT	11856	10	HS	\N	\N
12	Emma	Kuehnle	\N	STUDENT	11801	5	ES	\N	\N
13	John (Trey)	Kuehnle	\N	STUDENT	11833	7	MS	\N	\N
14	Rahsi	Abraha	\N	STUDENT	12465	4	ES	\N	\N
15	Siyam	Abraha	\N	STUDENT	12464	8	MS	\N	\N
16	Risty	Abraha	\N	STUDENT	12463	9	HS	\N	\N
17	Seret	Abraha	\N	STUDENT	12462	12	HS	\N	\N
996	Elijah	Lundell	\N	STUDENT	12692	5	ES	\N	\N
851	Seher	Goyal	\N	STUDENT	12373	10	HS	\N	\N
852	Michael Omar	Assi	\N	STUDENT	12917	7	MS	\N	\N
853	Abhimanyu	Singh	\N	STUDENT	12728	2	ES	\N	\N
854	Sifa	Otieno	\N	STUDENT	13013	12	HS	\N	\N
855	Iman	Ibrahim	\N	STUDENT	12819	9	HS	\N	\N
856	Tarquin	Mathews	\N	STUDENT	12994	11	HS	\N	\N
857	Jia	Pandit	\N	STUDENT	10437	10	HS	\N	\N
858	Josephine	Waugh	\N	STUDENT	12844	1	ES	\N	\N
859	Rosemary	Waugh	\N	STUDENT	12843	4	ES	\N	\N
860	Daudi	Kisukye	\N	STUDENT	13025	5	ES	\N	\N
861	Gabriel	Kisukye	\N	STUDENT	12759	10	HS	\N	\N
862	Aydin	Virani	\N	STUDENT	12483	3	ES	\N	\N
863	Yasmin	Huysdens	\N	STUDENT	12927	7	MS	\N	\N
864	Jacey	Huysdens	\N	STUDENT	12926	9	HS	\N	\N
865	Esther	Schonemann	\N	STUDENT	13028	5	ES	\N	\N
866	Nabou	Khouma	\N	STUDENT	13046	K	ES	\N	\N
867	Khady	Khouma	\N	STUDENT	13045	3	ES	\N	\N
868	Emily	Ellinger	\N	STUDENT	13102	5	ES	\N	\N
869	Isaac	D'souza	\N	STUDENT	12501	8	MS	\N	\N
870	Ezra	Kane	\N	STUDENT	13071	PK	ES	\N	\N
871	Sapia	Pijovic	\N	STUDENT	13091	PK	ES	\N	\N
872	Mubanga	Birschbach	\N	STUDENT	13052	K	ES	\N	\N
873	Ben	Granot	\N	STUDENT	12748	K	ES	\N	\N
874	Zyla	Khalid	\N	STUDENT	12747	K	ES	\N	\N
875	Hannah	Kishiue-Turkstra	\N	STUDENT	12751	K	ES	\N	\N
876	Alexander	Magnusson	\N	STUDENT	12824	K	ES	\N	\N
877	Emerson	Nau	\N	STUDENT	12834	K	ES	\N	\N
993	Alayna	Fritts	\N	STUDENT	12935	5	ES	\N	\N
8	Cassandre	Camisa	\N	STUDENT	11881	9	HS	\N	\N
9	Cole	Armstrong	\N	STUDENT	12277	7	MS	\N	\N
997	Johannah	Mpatswe	\N	STUDENT	12700	5	ES	\N	\N
998	Bella	Bergqvist	\N	STUDENT	12913	6	MS	\N	\N
999	Bertram	Birk	\N	STUDENT	12699	6	MS	\N	\N
1000	Elijah	Carey	\N	STUDENT	12923	6	MS	\N	\N
1001	Eva	Ryan	\N	STUDENT	12618	6	MS	\N	\N
1002	Mitchell	Bagenda	\N	STUDENT	12146	7	MS	\N	\N
1003	Luka	Breda	\N	STUDENT	12183	7	MS	\N	\N
1004	Paco	Breda	\N	STUDENT	12184	7	MS	\N	\N
1005	Camille	Corbin	\N	STUDENT	12941	7	MS	\N	\N
1006	Colin	Eldridge	\N	STUDENT	12974	7	MS	\N	\N
1007	Maya	Ferede	\N	STUDENT	11726	7	MS	\N	\N
1008	Ava	Fritts	\N	STUDENT	12928	7	MS	\N	\N
1009	Mahiro	Kishiue	\N	STUDENT	12679	7	MS	\N	\N
1010	Lola	Lemley	\N	STUDENT	12870	7	MS	\N	\N
1011	Wesley	Oberjuerge	\N	STUDENT	12685	7	MS	\N	\N
1012	Nicholas	Sobantu	\N	STUDENT	12940	7	MS	\N	\N
1013	Elliot	Asquith	\N	STUDENT	12943	8	MS	\N	\N
1014	Anshika	Basnet	\N	STUDENT	12450	8	MS	\N	\N
1015	Fanny	Bergqvist	\N	STUDENT	12912	8	MS	\N	\N
1016	Norah (Rebel)	Cizek	\N	STUDENT	12666	8	MS	\N	\N
1017	Alexa	Janisse	\N	STUDENT	12675	8	MS	\N	\N
1018	Tiago	Mendonca-Gray	\N	STUDENT	12948	8	MS	\N	\N
1019	Alexa	Spitler	\N	STUDENT	12595	8	MS	\N	\N
1020	Maia	Sykes	\N	STUDENT	12952	8	MS	\N	\N
1021	Sonia	Weill	\N	STUDENT	12848	8	MS	\N	\N
1022	Sienna	Zulberti	\N	STUDENT	12672	8	MS	\N	\N
1023	Maya	Bagenda	\N	STUDENT	12147	9	HS	\N	\N
1024	Muhammad Uneeb	Bakhshi	\N	STUDENT	12760	9	HS	\N	\N
1025	Natasha	Birschbach	\N	STUDENT	13058	9	HS	\N	\N
1026	Lara	Blanc Yeo	\N	STUDENT	12858	9	HS	\N	\N
1027	Jai	Cherickel	\N	STUDENT	13006	9	HS	\N	\N
1028	Samarth	Dalal	\N	STUDENT	12859	9	HS	\N	\N
1029	Dan	Ephrem Yohannes	\N	STUDENT	11772	9	HS	\N	\N
1030	Rowan	Hobbs	\N	STUDENT	12972	9	HS	\N	\N
1031	Benjamin	Johansson-Desai	\N	STUDENT	13012	9	HS	\N	\N
1032	Vashnie	Joymungul	\N	STUDENT	12996	9	HS	\N	\N
1033	Sphesihle	Kamenga	\N	STUDENT	12876	9	HS	\N	\N
1034	Seung Yoon	Nam	\N	STUDENT	13079	9	HS	\N	\N
1035	Ishita	Rathore	\N	STUDENT	12983	9	HS	\N	\N
1036	Nicholas	Rex	\N	STUDENT	10884	9	HS	\N	\N
1037	Asbjørn	Vestergaard	\N	STUDENT	12663	9	HS	\N	\N
1038	Filip	Adamec	\N	STUDENT	12904	10	HS	\N	\N
1039	Solveig	Andersen	\N	STUDENT	12569	10	HS	\N	\N
1040	Eugène	Astier	\N	STUDENT	12790	10	HS	\N	\N
1041	Elsa	Bergqvist	\N	STUDENT	12911	10	HS	\N	\N
1042	Maximilian	Chappell	\N	STUDENT	12576	10	HS	\N	\N
1043	Charlotte	De Geer-Howard	\N	STUDENT	12653	10	HS	\N	\N
1044	Aarish	Islam	\N	STUDENT	13008	10	HS	\N	\N
1045	Daniel	Johansson-Desai	\N	STUDENT	13011	10	HS	\N	\N
1046	Dario	Lawrence	\N	STUDENT	11438	10	HS	\N	\N
1047	Maximo	Lemley	\N	STUDENT	12869	10	HS	\N	\N
1048	Lila	Roquitte	\N	STUDENT	12555	10	HS	\N	\N
1049	Mathilde	Scanlon	\N	STUDENT	12558	10	HS	\N	\N
1050	Chisanga	Birschbach	\N	STUDENT	13055	11	HS	\N	\N
1051	Wade	Eldridge	\N	STUDENT	12975	11	HS	\N	\N
1052	Reem	Ephrem Yohannes	\N	STUDENT	11748	11	HS	\N	\N
1053	Liam	Hobbs	\N	STUDENT	12971	11	HS	\N	\N
1054	Daniel	Kadilli	\N	STUDENT	12991	11	HS	\N	\N
1055	Jay Austin	Nimubona	\N	STUDENT	12749	11	HS	\N	\N
1056	Anna Sophia	Stabrawa	\N	STUDENT	25052	11	HS	\N	\N
1057	Elliot	Sykes	\N	STUDENT	12951	11	HS	\N	\N
1058	Lalia	Sylla	\N	STUDENT	12628	11	HS	\N	\N
1059	Camila	Valdivieso Santos	\N	STUDENT	12568	11	HS	\N	\N
1060	Emma	Wright	\N	STUDENT	12567	11	HS	\N	\N
1061	Dzidzor	Ata	\N	STUDENT	12651	12	HS	\N	\N
1062	Nandini	Bhandari	\N	STUDENT	12738	12	HS	\N	\N
1063	Isabella	De Geer-Howard	\N	STUDENT	12652	12	HS	\N	\N
1064	Hanan	Khan	\N	STUDENT	10464	12	HS	\N	\N
1065	Vincenzo	Lawrence	\N	STUDENT	11447	12	HS	\N	\N
1066	Noah	Lutz	\N	STUDENT	24008	12	HS	\N	\N
1067	Julian	Rex	\N	STUDENT	10922	12	HS	\N	\N
1068	Luca	Scanlon	\N	STUDENT	12557	12	HS	\N	\N
1069	Noah	Trenkle	\N	STUDENT	12556	12	HS	\N	\N
1070	Theodore	Wright	twright28@isk.ac.ke	STUDENT	12566	8	MS	\N	twright28
1071	Noah	Ochomo	nochomo@isk.ac.ke	MUSIC TA	\N	\N	MS	INSTRUMENT STORE	nochomo
971	Sultan	Buksh	\N	STUDENT	11996	8	MS	\N	\N
972	Olivia	Moons	\N	STUDENT	12852	4	ES	\N	\N
985	Safiya	Menkerios	\N	STUDENT	11954	4	ES	\N	\N
986	Tamas	Meyers	\N	STUDENT	12622	4	ES	\N	\N
987	Arianna	Mucci	\N	STUDENT	12695	4	ES	\N	\N
988	Graham	Oberjuerge	\N	STUDENT	12686	4	ES	\N	\N
1072	DUMMY 1	STUDENT	\N	STUDENT	\N	\N	MS	\N	\N
1074	DUMMY 1	STUDENT	\N	STUDENT	\N	\N	MS	\N	\N
952	Yonatan Wondim Belachew	Andersen	ywondimandersen30@isk.ac.ke	STUDENT	12967	6	MS	\N	ywondimandersen30
953	Yoonseo	Choi	ychoi30@isk.ac.ke	STUDENT	10708	6	MS	\N	ychoi30
954	Evan	Daines	edaines30@isk.ac.ke>	STUDENT	13073	6	MS	\N	edaines30
955	Holly	Mcmurtry	hmcmurtry30@isk.ac.ke	STUDENT	10817	6	MS	\N	hmcmurtry30
956	Max	Stock	mstock30@isk.ac.ke	STUDENT	12915	6	MS	\N	mstock30
957	Rowan	O'neill Calver	roneillcalver30@isk.ac.ke	STUDENT	11458	6	MS	\N	roneillcalver30
958	Selma	Mensah	smensah30@isk.ac.ke	STUDENT	12392	6	MS	\N	smensah30
959	Ainsley	Hire	ahire29@isk.ac.ke	STUDENT	10621	7	MS	\N	ahire29
960	Aisha	Awori	aawori28@isk.ac.ke	STUDENT	10474	8	MS	\N	aawori28
961	Caleb	Ross	cross28@isk.ac.ke	STUDENT	11677	8	MS	\N	cross28
962	Ean	Kimuli	ekimuli29@isk.ac.ke	STUDENT	11703	7	MS	\N	ekimuli29
963	Emiliana	Jensen	ejensen28@isk.ac.ke	STUDENT	11904	8	MS	\N	ejensen28
964	Giancarlo	Biafore	gbiafore28@isk.ac.ke	STUDENT	12171	8	MS	\N	gbiafore28
973	Seung Hyun	Nam	shyun-nam30@isk.ac.ke	STUDENT	13080	6	MS	\N	shyun-nam30
974	Tanay	Cherickel	tcherickel30@isk.ac.ke	STUDENT	13007	6	MS	\N	tcherickel30
975	Zayn	Khalid	zkhalid30@isk.ac.ke	STUDENT	12616	6	MS	\N	zkhalid30
976	Balazs	Meyers	bmeyers30@isk.ac.ke	STUDENT	12621	6	MS	\N	bmeyers30
977	Mahdiyah	Muneeb	mmuneeb30@isk.ac.ke	STUDENT	12761	6	MS	\N	mmuneeb30
978	Mapalo	Birschbach	mbirschbach30@isk.ac.ke	STUDENT	13050	6	MS	\N	mbirschbach30
979	Anastasia	Mulema	amulema30@isk.ac.ke	STUDENT	11622	6	MS	\N	amulema30
980	Etienne	Carlevato	ecarlevato29@isk.ac.ke	STUDENT	12924	7	MS	\N	ecarlevato29
981	Lauren	Mucci	lmucci30@isk.ac.ke	STUDENT	12694	6	MS	\N	lmucci30
982	Seth	Lundell	slundell30@isk.ac.ke	STUDENT	12691	6	MS	\N	slundell30
983	Evyn	Hobbs	ehobbs30@isk.ac.ke	STUDENT	12973	6	MS	\N	ehobbs30
984	Nirvi	Joymungul	njoymungul29@isk.ac.ke	STUDENT	12997	7	MS	\N	njoymungul29
1080	Rachel	Aondo	raondo@isk.ac.ke	MUSIC TEACHER	\N	\N	ES	LOWER ES MUSIC	raondo
1079	Laois	Rogers	lrogers@isk.ac.ke	MUSIC TEACHER	\N	\N	ES	UPPER ES MUSIC	lrogers
1078	Margaret	Oganda	moganda@isk.ac.ke	MUSIC TA	\N	\N	ES	UPPER ES MUSIC	moganda
1077	Gwendolyn	Anding	ganding@isk.ac.ke	MUSIC TEACHER	\N	\N	HS	HS MUSIC	ganding
1076	Mark	Anding	manding@isk.ac.ke	MUSIC TEACHER	\N	\N	MS	MS MUSIC	manding
1075	Gakenia	Mucharie	gmucharie@isk.ac.ke	MUSIC TA	\N	\N	HS	HS MUSIC	gmucharie
965	Joan	Awori	jawori28@isk.ac.ke	STUDENT	10475	8	MS	\N	jawori28
966	Keza	Herman-Roloff	kherman-roloff29@isk.ac.ke	STUDENT	12196	7	MS	\N	kherman-roloff29
967	Milan	Jayaram	mijayaram29@isk.ac.ke	STUDENT	10493	7	MS	\N	mijayaram29
968	Nickolas	Jensen	njensen28@isk.ac.ke	STUDENT	11926	8	MS	\N	njensen28
969	Noam	Waalewijn	nwaalewijn28@isk.ac.ke	STUDENT	12597	8	MS	\N	nwaalewijn28
970	Wataru	Plunkett	wplunkett29@isk.ac.ke	STUDENT	12853	7	MS	\N	wplunkett29
990	Penelope	Schrader	\N	STUDENT	12839	4	ES	\N	\N
991	Rebecca	Von Platen-Hallermund	\N	STUDENT	12887	4	ES	\N	\N
992	Sebastian	Chappell	\N	STUDENT	12577	5	ES	\N	\N
994	Riley	Janisse	\N	STUDENT	12676	5	ES	\N	\N
995	Adam	Johnson	\N	STUDENT	12327	5	ES	\N	\N
\.


--
-- TOC entry 3973 (class 0 OID 0)
-- Dependencies: 239
-- Name: all_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.all_instruments_id_seq', 348, true);


--
-- TOC entry 3974 (class 0 OID 0)
-- Dependencies: 223
-- Name: class_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.class_id_seq', 1, false);


--
-- TOC entry 3975 (class 0 OID 0)
-- Dependencies: 225
-- Name: dispatches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dispatches_id_seq', 127, true);


--
-- TOC entry 3976 (class 0 OID 0)
-- Dependencies: 243
-- Name: duplicate_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.duplicate_instruments_id_seq', 96, true);


--
-- TOC entry 3977 (class 0 OID 0)
-- Dependencies: 245
-- Name: hardware_and_equipment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.hardware_and_equipment_id_seq', 20, true);


--
-- TOC entry 3978 (class 0 OID 0)
-- Dependencies: 235
-- Name: instrument_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instrument_history_id_seq', 3144, true);


--
-- TOC entry 3979 (class 0 OID 0)
-- Dependencies: 217
-- Name: instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instruments_id_seq', 4166, true);


--
-- TOC entry 3980 (class 0 OID 0)
-- Dependencies: 215
-- Name: legacy_database_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.legacy_database_id_seq', 669, true);


--
-- TOC entry 3981 (class 0 OID 0)
-- Dependencies: 248
-- Name: locations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.locations_id_seq', 16, true);


--
-- TOC entry 3982 (class 0 OID 0)
-- Dependencies: 241
-- Name: music_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.music_instruments_id_seq', 544, true);


--
-- TOC entry 3983 (class 0 OID 0)
-- Dependencies: 249
-- Name: new_instrument_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.new_instrument_id_seq', 11, true);


--
-- TOC entry 3984 (class 0 OID 0)
-- Dependencies: 253
-- Name: receive_instrument_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.receive_instrument_id_seq', 1, false);


--
-- TOC entry 3985 (class 0 OID 0)
-- Dependencies: 229
-- Name: repairs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.repairs_id_seq', 1, false);


--
-- TOC entry 3986 (class 0 OID 0)
-- Dependencies: 233
-- Name: requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requests_id_seq', 1, false);


--
-- TOC entry 3987 (class 0 OID 0)
-- Dependencies: 231
-- Name: resolve_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.resolve_id_seq', 1, false);


--
-- TOC entry 3988 (class 0 OID 0)
-- Dependencies: 227
-- Name: returns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.returns_id_seq', 98, true);


--
-- TOC entry 3989 (class 0 OID 0)
-- Dependencies: 219
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 11, true);


--
-- TOC entry 3990 (class 0 OID 0)
-- Dependencies: 237
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.students_id_seq', 1069, true);


--
-- TOC entry 3991 (class 0 OID 0)
-- Dependencies: 221
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 1082, true);


--
-- TOC entry 3693 (class 2606 OID 24691)
-- Name: equipment all_instruments_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.equipment
    ADD CONSTRAINT all_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text, 'SOUND'::text]))) NOT VALID;


--
-- TOC entry 3738 (class 2606 OID 24641)
-- Name: equipment all_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT all_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3718 (class 2606 OID 24273)
-- Name: class class_class_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_class_name_key UNIQUE (class_name);


--
-- TOC entry 3720 (class 2606 OID 24271)
-- Name: class class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);


--
-- TOC entry 3722 (class 2606 OID 24285)
-- Name: dispatches dispatches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_pkey PRIMARY KEY (id);


--
-- TOC entry 3750 (class 2606 OID 24665)
-- Name: duplicate_instruments duplicate_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.duplicate_instruments
    ADD CONSTRAINT duplicate_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3740 (class 2606 OID 24824)
-- Name: equipment equipment_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_code_key UNIQUE (code) INCLUDE (code);


--
-- TOC entry 3742 (class 2606 OID 24643)
-- Name: equipment equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_description_key UNIQUE (description);


--
-- TOC entry 3752 (class 2606 OID 24690)
-- Name: hardware_and_equipment hardware_and_equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_description_key UNIQUE (description);


--
-- TOC entry 3695 (class 2606 OID 24692)
-- Name: hardware_and_equipment hardware_and_equipment_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_family_check CHECK ((upper((family)::text) = ANY (ARRAY['MISCELLANEOUS'::text, 'SOUND'::text]))) NOT VALID;


--
-- TOC entry 3754 (class 2606 OID 24688)
-- Name: hardware_and_equipment hardware_and_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_pkey PRIMARY KEY (id);


--
-- TOC entry 3734 (class 2606 OID 24369)
-- Name: instrument_history instrument_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3702 (class 2606 OID 24845)
-- Name: instruments instruments_code_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_number_key UNIQUE (code, number);


--
-- TOC entry 3704 (class 2606 OID 24212)
-- Name: instruments instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3706 (class 2606 OID 24214)
-- Name: instruments instruments_serial_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_serial_key UNIQUE (serial);


--
-- TOC entry 3698 (class 2606 OID 23620)
-- Name: legacy_database legacy_database_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.legacy_database
    ADD CONSTRAINT legacy_database_pkey PRIMARY KEY (id);


--
-- TOC entry 3756 (class 2606 OID 25112)
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- TOC entry 3744 (class 2606 OID 24831)
-- Name: music_instruments music_instruments_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_code_key UNIQUE (code) INCLUDE (code);


--
-- TOC entry 3746 (class 2606 OID 24655)
-- Name: music_instruments music_instruments_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_description_key UNIQUE (description);


--
-- TOC entry 3748 (class 2606 OID 24653)
-- Name: music_instruments music_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3760 (class 2606 OID 25134)
-- Name: receive_instrument receive_instrument_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receive_instrument
    ADD CONSTRAINT receive_instrument_pkey PRIMARY KEY (id);


--
-- TOC entry 3726 (class 2606 OID 24320)
-- Name: repair_request repairs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_pkey PRIMARY KEY (id);


--
-- TOC entry 3730 (class 2606 OID 24802)
-- Name: requests requests_instrument_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_instrument_key UNIQUE (instrument);


--
-- TOC entry 3732 (class 2606 OID 24348)
-- Name: requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);


--
-- TOC entry 3728 (class 2606 OID 24334)
-- Name: resolve resolve_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_pkey PRIMARY KEY (id);


--
-- TOC entry 3724 (class 2606 OID 24306)
-- Name: returns returns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_pkey PRIMARY KEY (id);


--
-- TOC entry 3708 (class 2606 OID 24246)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 3710 (class 2606 OID 24248)
-- Name: roles roles_role_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_role_name_key UNIQUE (role_name);


--
-- TOC entry 3758 (class 2606 OID 24735)
-- Name: locations room; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT room UNIQUE (room);


--
-- TOC entry 3736 (class 2606 OID 24390)
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- TOC entry 3712 (class 2606 OID 24258)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 3714 (class 2606 OID 24755)
-- Name: users users_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_number_key UNIQUE (number);


--
-- TOC entry 3716 (class 2606 OID 24256)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 3699 (class 1259 OID 24817)
-- Name: fki_instruments_code_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_instruments_code_fkey ON public.instruments USING btree (code);


--
-- TOC entry 3700 (class 1259 OID 24726)
-- Name: fki_instruments_description_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_instruments_description_fkey ON public.instruments USING btree (description);


--
-- TOC entry 3777 (class 2620 OID 24775)
-- Name: dispatches assign_user; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER assign_user BEFORE INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.dispatch();


--
-- TOC entry 3779 (class 2620 OID 27161)
-- Name: returns log_return; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_return AFTER INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3778 (class 2620 OID 24780)
-- Name: dispatches log_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_transaction AFTER INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3775 (class 2620 OID 24859)
-- Name: instruments new_instr; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_instr AFTER INSERT OR UPDATE ON public.instruments FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3781 (class 2620 OID 24858)
-- Name: new_instrument new_instrument_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_instrument_trigger AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.new_instr_function();


--
-- TOC entry 3780 (class 2620 OID 27835)
-- Name: returns return_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER return_trigger BEFORE INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.return();


--
-- TOC entry 3776 (class 2620 OID 24380)
-- Name: class trg_check_teacher_role; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_teacher_role BEFORE INSERT OR UPDATE ON public.class FOR EACH ROW EXECUTE FUNCTION public.check_teacher_role();


--
-- TOC entry 3766 (class 2606 OID 24274)
-- Name: class class_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);


--
-- TOC entry 3767 (class 2606 OID 24295)
-- Name: dispatches dispatches_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);


--
-- TOC entry 3773 (class 2606 OID 24375)
-- Name: instrument_history instrument_history_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);


--
-- TOC entry 3761 (class 2606 OID 24825)
-- Name: instruments instruments_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_fkey FOREIGN KEY (code) REFERENCES public.equipment(code) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3762 (class 2606 OID 24721)
-- Name: instruments instruments_description_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_description_fkey FOREIGN KEY (description) REFERENCES public.equipment(description) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3763 (class 2606 OID 24738)
-- Name: instruments instruments_location_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_location_fkey FOREIGN KEY (location) REFERENCES public.locations(room) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3774 (class 2606 OID 25135)
-- Name: receive_instrument receive_instruments_instrument_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.receive_instrument
    ADD CONSTRAINT receive_instruments_instrument_id_fk FOREIGN KEY (instrument_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3769 (class 2606 OID 24796)
-- Name: repair_request repairs_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3771 (class 2606 OID 24808)
-- Name: requests requests_instrument_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_instrument_fkey FOREIGN KEY (instrument) REFERENCES public.equipment(description) NOT VALID;


--
-- TOC entry 3772 (class 2606 OID 24351)
-- Name: requests requests_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);


--
-- TOC entry 3770 (class 2606 OID 24335)
-- Name: resolve resolve_case_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_case_fkey FOREIGN KEY ("case") REFERENCES public.repair_request(id);


--
-- TOC entry 3768 (class 2606 OID 24791)
-- Name: returns returns_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3764 (class 2606 OID 25155)
-- Name: users user_room_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT user_room_fk FOREIGN KEY (room) REFERENCES public.locations(room) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3765 (class 2606 OID 24259)
-- Name: users users_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.roles(role_name);


-- Completed on 2024-03-13 09:58:07 EAT

--
-- PostgreSQL database dump complete
--

