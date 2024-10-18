--
-- PostgreSQL database dump
--

-- Dumped from database version 15.6 (Postgres.app)
-- Dumped by pg_dump version 15.6

-- Started on 2024-10-11 00:31:41 EAT

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
-- TOC entry 2 (class 3079 OID 30807)
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- TOC entry 4047 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- TOC entry 314 (class 1255 OID 31724)
-- Name: advance_school_year(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.advance_school_year() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE public.students
    SET grade_level = (grade_level::integer + 1)::integer
    WHERE  grade_level::integer <= 12;
END;
$$;


ALTER FUNCTION public.advance_school_year() OWNER TO postgres;

--
-- TOC entry 341 (class 1255 OID 30685)
-- Name: check_teacher_role(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_teacher_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (SELECT role FROM users WHERE id = NEW.teacher_id) <> 'MUSIC TEACHER' THEN
    RAISE EXCEPTION 'Teacher_id must correspond to a user with the role "TEACHER".';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_teacher_role() OWNER TO postgres;

--
-- TOC entry 326 (class 1255 OID 30686)
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
-- TOC entry 327 (class 1255 OID 30687)
-- Name: dispatch(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.dispatch() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    instrument_user_name TEXT;
    current_user_id INTEGER;
BEGIN
    -- Check if the family is valid
    IF (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD') THEN
        RAISE EXCEPTION 'Item cannot be rented out';
    END IF;

    -- Check if the instrument is already checked out
    SELECT user_id INTO current_user_id
    FROM instruments
    WHERE id = NEW.item_id;

    IF current_user_id IS NOT NULL THEN
        SELECT first_name || ' ' || last_name INTO instrument_user_name
        FROM users
        WHERE id = current_user_id;

        RAISE EXCEPTION 'Instrument already checked out to %', instrument_user_name;
    END IF;

    -- Retrieve the name of the user checking out the instrument
    SELECT first_name || ' ' || last_name INTO instrument_user_name
    FROM users
    WHERE id = NEW.user_id;

    -- Update the instruments table
    UPDATE instruments
    SET user_id = NEW.user_id,
        location = NULL,
        user_name = instrument_user_name,
        issued_on = CURRENT_DATE
    WHERE id = NEW.item_id;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.dispatch() OWNER TO postgres;

--
-- TOC entry 328 (class 1255 OID 30688)
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
-- TOC entry 313 (class 1255 OID 30912)
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
-- TOC entry 329 (class 1255 OID 30689)
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
-- TOC entry 330 (class 1255 OID 30690)
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
-- TOC entry 331 (class 1255 OID 30691)
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
-- TOC entry 332 (class 1255 OID 30692)
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
-- TOC entry 333 (class 1255 OID 30693)
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
-- TOC entry 334 (class 1255 OID 30694)
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
-- TOC entry 267 (class 1255 OID 30695)
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
-- TOC entry 343 (class 1255 OID 30696)
-- Name: log_transaction(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_transaction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_TABLE_NAME = 'instruments' THEN
        IF TG_OP = 'UPDATE' THEN
            IF NEW.state <> OLD.state THEN
                INSERT INTO instrument_history (transaction_type, created_by, item_id)
                SELECT 'Instrument State Updated', username, NEW.id FROM new_instruments WHERE description = NEW.description AND number = NEW.number;
            END IF;
			
        ELSIF TG_OP = 'INSERT' THEN
            INSERT INTO instrument_history (transaction_type, created_by, item_id)
            SELECT 'New Instrument', username, NEW.id FROM new_instrument WHERE description = NEW.description AND number = NEW.number;
        END IF;
    ELSIF TG_TABLE_NAME = 'dispatches' THEN
        -- Insert on the dispatches table
        IF TG_OP = 'INSERT' THEN
            -- Instrument dispatched
            INSERT INTO instrument_history (transaction_type, created_by, item_id, assigned_to)
            VALUES ('Instrument Out',NEW.created_by, NEW.item_id, NEW.user_id);
        END IF;
	ELSIF TG_TABLE_NAME = 'take_stock' THEN
       
        IF TG_OP = 'INSERT' THEN
            
            INSERT INTO instrument_history (transaction_type, location,  created_by, item_id, notes)
            VALUES ('Instrument Confirmed', NEW.location,   NEW.created_by, NEW.item_id, NEW.notes);
        END IF;
		
    ELSIF TG_TABLE_NAME = 'returns' THEN
        -- Insert on the returns table
        IF TG_OP = 'INSERT' THEN
            -- Instrument returned
            INSERT INTO instrument_history (transaction_type, item_id, created_by, returned_by_id)
            VALUES ('Instrument Returned', NEW.item_id,NEW.created_by, NEW.former_user_id);
        END IF;
    ELSIF TG_TABLE_NAME = 'lost_and_found' THEN
        IF TG_OP = 'INSERT' THEN
            -- Instrument reported
            INSERT INTO instrument_history (transaction_type, item_id, created_by, "location", transaction_timestamp, contact)
            VALUES ('Instrument Found', NEW.item_id, NEW.finder_name, NEW.location, NEW.date, NEW.contact );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_transaction() OWNER TO postgres;

--
-- TOC entry 335 (class 1255 OID 30697)
-- Name: new_instr_function(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.new_instr_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    n_code VARCHAR;
    legacy_code VARCHAR;
BEGIN
    -- Work out correct code
    SELECT equipment.code INTO n_code FROM equipment WHERE equipment.description = NEW.description;
    SELECT equipment.legacy_code INTO legacy_code FROM equipment WHERE equipment.description = UPPER(NEW.description);
	

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
        NEW.number,
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
-- TOC entry 340 (class 1255 OID 31646)
-- Name: new_student_function(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.new_student_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO users (
        "first_name",
        "last_name",
		"email",
		"role",
        "number",
        "grade_level",
		division
        
    ) VALUES (
        NEW.first_name,
        NEW.last_name,
		NEW.email,
		'STUDENT',
		NEW.student_number,
		NEW.grade_level,
		CASE 
            WHEN (NEW.grade_level >= -1 AND NEW.grade_level <= 5) THEN 'ES'::character varying
            WHEN (NEW.grade_level >= 6 AND NEW.grade_level <= 8) THEN 'MS'::character varying
            WHEN (NEW.grade_level >= 9 AND NEW.grade_level <= 12) THEN 'HS'::character varying
            WHEN (NEW.grade_level > 12) THEN 'Alumni'::character varying
            ELSE NULL
        END
        
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.new_student_function() OWNER TO postgres;

--
-- TOC entry 336 (class 1255 OID 30698)
-- Name: return(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.return() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the current user has a room assigned
    IF (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL THEN
        -- Instrument returned
        UPDATE instruments
        SET user_id = NULL,
            location = (SELECT room FROM users WHERE users.id = NEW.user_id),
            user_name = NULL
        WHERE id = NEW.item_id;
    ELSE
        -- Do not allow instrument return if the current user has no room assigned
        RAISE EXCEPTION 'User cannot return instrument. No room assigned.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.return() OWNER TO postgres;

--
-- TOC entry 337 (class 1255 OID 30699)
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

--
-- TOC entry 339 (class 1255 OID 31721)
-- Name: set_user_role_based_on_grade_level(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_user_role_based_on_grade_level() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Set role to 'STUDENT' if grade_level is between -1 and 12
    IF NEW.grade_level BETWEEN -1 AND 12 THEN
        NEW.role := 'STUDENT';
    
    -- Set role to 'ALUMNUS' if grade_level is greater than 12
    ELSIF NEW.grade_level > 12 THEN
        NEW.role := 'ALUMNUS';
    END IF;

    -- Return the new record with the updated role
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_user_role_based_on_grade_level() OWNER TO postgres;

--
-- TOC entry 338 (class 1255 OID 31521)
-- Name: swap_cases_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.swap_cases_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   
    PERFORM public.swap_instrument_numbers(
        NEW.instr_code, 
        NEW.item_id_1, 
        NEW.item_id_2, 
        NEW.created_by
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.swap_cases_trigger() OWNER TO postgres;

--
-- TOC entry 342 (class 1255 OID 31529)
-- Name: swap_instrument_numbers(public.citext, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.swap_instrument_numbers(instr_code public.citext, item_id_1 integer, item_id_2 integer, created_by character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    number1 INTEGER;
    number2 INTEGER;
BEGIN
    -- Retrieve the numbers of the instruments with the specified IDs
    SELECT i."number" INTO number1 
    FROM public.instruments i
    WHERE i.code = code AND i.id = item_id_1;

    SELECT i."number" INTO number2 
    FROM public.instruments i
    WHERE i.code = code AND i.id = item_id_2;

    -- Ensure both instruments exist and have the same code
    IF number1 IS NULL OR number2 IS NULL THEN
        RAISE EXCEPTION 'Instruments with specified code and IDs not found';
    END IF;

    -- Begin transaction
    PERFORM pg_advisory_xact_lock(item_id_1, item_id_2);
    
    -- Swap the numbers
    UPDATE public.instruments SET "number" = number2 WHERE id = item_id_1;
    UPDATE public.instruments SET "number" = number1 WHERE id = item_id_2;

    -- Log the transaction for both instruments
    INSERT INTO public.instrument_history (item_id, transaction_type, transaction_timestamp, created_by)
    VALUES (item_id_1, 'Cases swapped from ' || number1 || ' to ' || number2, CURRENT_TIMESTAMP, created_by);
    
    INSERT INTO public.instrument_history (item_id, transaction_type, transaction_timestamp, created_by)
    VALUES (item_id_2, 'Cases swapped from ' || number2 || ' to ' || number1, CURRENT_TIMESTAMP, created_by);
END;
$$;


ALTER FUNCTION public.swap_instrument_numbers(instr_code public.citext, item_id_1 integer, item_id_2 integer, created_by character varying) OWNER TO postgres;

--
-- TOC entry 344 (class 1255 OID 31719)
-- Name: update_students(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_students() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    UPDATE public.users
    SET 
        first_name = COALESCE(NEW.first_name, first_name),
        last_name = COALESCE(NEW.last_name, last_name),
        email = COALESCE(NEW.email, email),
        grade_level = COALESCE(NEW.grade_level, grade_level)
		
    WHERE number = NEW.student_number;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_students() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 235 (class 1259 OID 30913)
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
-- TOC entry 236 (class 1259 OID 30918)
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
-- TOC entry 237 (class 1259 OID 30919)
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
    issued_on date DEFAULT CURRENT_DATE
);


ALTER TABLE public.instruments OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 30926)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying,
    email character varying,
    role character varying NOT NULL,
    room public.citext,
    grade_level integer,
    number character varying,
    username character varying GENERATED ALWAYS AS (SUBSTRING(email FROM 1 FOR (POSITION(('@'::text) IN (email)) - 1))) STORED,
    active boolean GENERATED ALWAYS AS (
CASE
    WHEN ((role)::text = ANY ((ARRAY['ALUMNUS'::character varying, 'EX EMPLOYEE'::character varying])::text[])) THEN false
    ELSE true
END) STORED,
    division character varying
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 30932)
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


ALTER TABLE public.all_instruments_view OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 30937)
-- Name: students; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.students (
    id integer NOT NULL,
    last_name character varying NOT NULL,
    first_name character varying NOT NULL,
    full_name character varying GENERATED ALWAYS AS ((((first_name)::text || ' '::text) || (last_name)::text)) STORED,
    parent1_email character varying,
    parent2_email character varying,
    email character varying,
    grade_level integer,
    student_number character varying,
    division character varying GENERATED ALWAYS AS (
CASE
    WHEN ((grade_level >= '-1'::integer) AND (grade_level <= 5)) THEN 'ES'::text
    WHEN ((grade_level >= 6) AND (grade_level <= 8)) THEN 'MS'::text
    WHEN ((grade_level >= 9) AND (grade_level <= 12)) THEN 'HS'::text
    WHEN (grade_level > 12) THEN 'Alumni'::text
    ELSE NULL::text
END) STORED,
    class character varying
);


ALTER TABLE public.students OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 39772)
-- Name: all_users_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.all_users_view AS
 SELECT u.id,
    u.first_name,
    u.last_name,
    (((u.first_name)::text || ' '::text) || (u.last_name)::text) AS full_name,
    u.number,
    u.email,
    u.username,
    u.role,
    u.room,
    u.grade_level,
    u.division,
    u.active,
    s.class
   FROM (public.users u
     LEFT JOIN public.students s ON (((u.number)::text = (s.student_number)::text)))
  ORDER BY (((u.first_name)::text || ' '::text) || (u.last_name)::text);


ALTER TABLE public.all_users_view OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 30700)
-- Name: class; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.class (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    class_name character varying
);


ALTER TABLE public.class OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 30705)
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
-- TOC entry 265 (class 1259 OID 39811)
-- Name: class_students; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.class_students (
    class_id integer NOT NULL,
    user_id integer NOT NULL,
    primary_instrument character varying(255)
);


ALTER TABLE public.class_students OWNER TO postgres;

--
-- TOC entry 266 (class 1259 OID 39830)
-- Name: class_students_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.class_students_view AS
 SELECT cs.class_id,
    cs.user_id,
    u.first_name,
    u.last_name,
    u.grade_level,
    cl.class_name,
    cs.primary_instrument
   FROM ((public.class_students cs
     JOIN public.users u ON ((cs.user_id = u.id)))
     JOIN public.class cl ON ((cs.class_id = cl.id)));


ALTER TABLE public.class_students_view OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 30948)
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


ALTER TABLE public.dispatched_instruments_view OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 30706)
-- Name: dispatches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dispatches (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    user_id integer,
    item_id integer,
    created_by character varying,
    profile_id integer
);


ALTER TABLE public.dispatches OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 30712)
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
-- TOC entry 219 (class 1259 OID 30713)
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
-- TOC entry 220 (class 1259 OID 30720)
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
-- TOC entry 242 (class 1259 OID 30952)
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
-- TOC entry 243 (class 1259 OID 30957)
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
-- TOC entry 221 (class 1259 OID 30721)
-- Name: instrument_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instrument_history (
    id integer NOT NULL,
    transaction_type character varying NOT NULL,
    transaction_timestamp timestamp with time zone DEFAULT now(),
    item_id integer NOT NULL,
    notes text,
    assigned_to character varying,
    created_by character varying,
    location character varying,
    contact text,
    returned_by_id integer
);


ALTER TABLE public.instrument_history OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 31547)
-- Name: history_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.history_view AS
 SELECT instrument_history.id,
    instrument_history.transaction_type,
    instrument_history.transaction_timestamp,
    instrument_history.item_id AS instrument_id,
    initcap((instruments.description)::text) AS description,
    instruments.number,
    (instrument_history.assigned_to)::integer AS user_id,
    initcap(COALESCE((((users.first_name)::text || ' '::text) || (users.last_name)::text), (users.first_name)::text, (users.last_name)::text)) AS full_name,
    users.email,
    initcap((instrument_history.created_by)::text) AS created_by,
    initcap((instrument_history.location)::text) AS location,
    instrument_history.returned_by_id
   FROM ((public.instrument_history
     LEFT JOIN public.users ON ((users.id = (instrument_history.assigned_to)::integer)))
     LEFT JOIN public.instruments ON ((instruments.id = instrument_history.item_id)))
  ORDER BY instrument_history.id;


ALTER TABLE public.history_view OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 30727)
-- Name: instrument_conditions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instrument_conditions (
    id integer NOT NULL,
    condition character varying
);


ALTER TABLE public.instrument_conditions OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 30732)
-- Name: instrument_conditions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.instrument_conditions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_conditions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 244 (class 1259 OID 30963)
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


ALTER TABLE public.instrument_distribution_view OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 30733)
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
-- TOC entry 258 (class 1259 OID 31155)
-- Name: instrument_placeholder_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.instrument_placeholder_seq
    START WITH -1
    INCREMENT BY -1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.instrument_placeholder_seq OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 30968)
-- Name: instrument_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instrument_requests (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id integer,
    instrument public.citext NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    status character varying DEFAULT 'Pending'::character varying,
    success character varying,
    unique_id character varying(15),
    notes text,
    attended_by character varying,
    attended_by_id integer,
    instruments_granted integer[],
    resolved_at timestamp with time zone
);


ALTER TABLE public.instrument_requests OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 30976)
-- Name: instrument_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.instrument_requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 247 (class 1259 OID 30977)
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
-- TOC entry 248 (class 1259 OID 30978)
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
-- TOC entry 249 (class 1259 OID 30985)
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
-- TOC entry 250 (class 1259 OID 30986)
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.locations (
    room public.citext NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 30991)
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
-- TOC entry 225 (class 1259 OID 30734)
-- Name: lost_and_found; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lost_and_found (
    id integer NOT NULL,
    item_id integer NOT NULL,
    finder_name character varying,
    date date DEFAULT CURRENT_DATE,
    location text,
    contact text
);


ALTER TABLE public.lost_and_found OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 30740)
-- Name: lost_and_found_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.lost_and_found ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.lost_and_found_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 252 (class 1259 OID 30992)
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
-- TOC entry 253 (class 1259 OID 30998)
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
-- TOC entry 254 (class 1259 OID 30999)
-- Name: new_instrument; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.new_instrument (
    id integer NOT NULL,
    description public.citext,
    serial public.citext,
    state character varying,
    make public.citext,
    model public.citext,
    number integer,
    profile_id integer,
    username public.citext,
    location public.citext,
    CONSTRAINT instruments_state_check CHECK (((state)::text = ANY (ARRAY[('New'::character varying)::text, ('Good'::character varying)::text, ('Worn'::character varying)::text, ('Damaged'::character varying)::text, ('Write-off'::character varying)::text])))
);


ALTER TABLE public.new_instrument OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 31005)
-- Name: new_instrument_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.new_instrument ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.new_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 227 (class 1259 OID 30741)
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
-- TOC entry 228 (class 1259 OID 30747)
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
-- TOC entry 229 (class 1259 OID 30748)
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
-- TOC entry 230 (class 1259 OID 30754)
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
-- TOC entry 231 (class 1259 OID 30755)
-- Name: returns; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.returns (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    created_by character varying,
    user_id integer,
    former_user_id integer
);


ALTER TABLE public.returns OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 30761)
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
-- TOC entry 233 (class 1259 OID 30762)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    role_name character varying DEFAULT 'STUDENT'::character varying
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 30768)
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
-- TOC entry 256 (class 1259 OID 31006)
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
-- TOC entry 260 (class 1259 OID 31502)
-- Name: swap_cases; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.swap_cases (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    instr_code public.citext,
    item_id_1 integer,
    item_id_2 integer,
    created_by character varying
);


ALTER TABLE public.swap_cases OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 31501)
-- Name: swap_cases_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.swap_cases ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.swap_cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 262 (class 1259 OID 31538)
-- Name: take_stock; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.take_stock (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    location public.citext,
    created_by character varying,
    item_id integer,
    description public.citext NOT NULL,
    number integer,
    status character varying,
    notes text
);


ALTER TABLE public.take_stock OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 31537)
-- Name: take_stock_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.take_stock ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.take_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 257 (class 1259 OID 31007)
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
-- TOC entry 3995 (class 0 OID 30700)
-- Dependencies: 215
-- Data for Name: class; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.class (id, teacher_id, class_name) VALUES
	(8, 1076, 'Beginning Band 1, 2024-2025'),
	(9, 1076, 'Beginning Band 7, 2024-2025'),
	(10, 1076, 'Beginning Band 8, 2024-2025'),
	(13, 1076, 'Concert Band 5, 2024-2025'),
	(14, 1076, 'Experimental class') ON CONFLICT DO NOTHING;


--
-- TOC entry 4040 (class 0 OID 39811)
-- Dependencies: 265
-- Data for Name: class_students; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.class_students (class_id, user_id, primary_instrument) VALUES
	(8, 574, 'ALTO SAX'),
	(8, 444, 'TROMBONE'),
	(8, 321, 'TROMBONE') ON CONFLICT DO NOTHING;


--
-- TOC entry 3997 (class 0 OID 30706)
-- Dependencies: 217
-- Data for Name: dispatches; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.dispatches (id, created_at, user_id, item_id, created_by, profile_id) VALUES
	(277, '2024-06-26', 1074, 4163, 'nochomo', 1071),
	(278, '2024-06-26', 1071, 4165, 'Noah Ochomo', 1071),
	(279, '2024-06-26', 1071, 4209, 'Noah Ochomo', 1071),
	(280, '2024-06-26', 1071, 4166, 'Noah Ochomo', 1071),
	(281, '2024-06-26', 1071, 4203, 'Noah Ochomo', 1071),
	(282, '2024-06-27', 1071, 4164, 'Noah Ochomo', 1071),
	(283, '2024-06-27', 1071, 2129, 'Noah Ochomo', 1071),
	(284, '2024-10-07', 574, 1555, 'nochomo', 1071) ON CONFLICT DO NOTHING;


--
-- TOC entry 3999 (class 0 OID 30713)
-- Dependencies: 219
-- Data for Name: duplicate_instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.duplicate_instruments (id, number, legacy_number, family, equipment, make, model, serial, class, year, name, school_storage, return_2023) VALUES
	(1, 37, 121, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '619468', NULL, NULL, NULL, NULL, NULL),
	(2, 37, 121, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '619468', NULL, NULL, NULL, NULL, NULL),
	(3, 11, 498, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'K96124', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL),
	(4, 11, 498, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'K96124', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL),
	(5, 11, 498, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'K96124', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL),
	(6, 35, 117, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '619276', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL),
	(7, 35, 117, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '619276', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL),
	(8, 35, 117, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '619276', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL),
	(9, 35, 117, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '619276', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL),
	(10, 6, 414, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65670', NULL, NULL, NULL, NULL, NULL),
	(11, 6, 414, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65670', NULL, NULL, NULL, NULL, NULL),
	(12, 6, 414, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65670', NULL, NULL, NULL, NULL, NULL),
	(13, 6, 414, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65670', NULL, NULL, NULL, NULL, NULL),
	(14, 6, 414, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65670', NULL, NULL, NULL, NULL, NULL),
	(15, 40, 127, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H32043', NULL, NULL, NULL, NULL, NULL),
	(16, 40, 127, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H32043', NULL, NULL, NULL, NULL, NULL),
	(17, 31, 599, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '354121A', NULL, NULL, NULL, NULL, NULL),
	(18, 31, 599, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '354121A', NULL, NULL, NULL, NULL, NULL),
	(19, 31, 599, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '354121A', NULL, NULL, NULL, NULL, NULL),
	(20, 31, 599, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '354121A', NULL, NULL, NULL, NULL, NULL),
	(21, 31, 599, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '354121A', NULL, NULL, NULL, NULL, NULL),
	(22, 31, 599, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '354121A', NULL, NULL, NULL, NULL, NULL),
	(23, 3, 408, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65679', NULL, NULL, NULL, NULL, NULL),
	(24, 3, 408, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65679', NULL, NULL, NULL, NULL, NULL),
	(25, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(26, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(27, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(28, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(29, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(30, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(31, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(32, 15, 507, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '566919A', NULL, NULL, NULL, NULL, NULL),
	(33, 32, 601, 'WOODWIND', 'SAXOPHONE, ALTO', 'BARRINGTON', NULL, 'AS1003852', NULL, NULL, NULL, NULL, NULL),
	(34, 32, 601, 'WOODWIND', 'SAXOPHONE, ALTO', 'BARRINGTON', NULL, 'AS1003852', NULL, NULL, NULL, NULL, NULL),
	(35, 42, 131, 'BRASS', 'TRUMPET, B FLAT', 'KOHLERT', NULL, 'A6570', NULL, NULL, NULL, NULL, NULL),
	(36, 42, 131, 'BRASS', 'TRUMPET, B FLAT', 'KOHLERT', NULL, 'A6570', NULL, NULL, NULL, NULL, NULL),
	(37, 9, 495, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'R-28', NULL, NULL, NULL, NULL, NULL),
	(38, 9, 495, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'R-28', NULL, NULL, NULL, NULL, NULL),
	(39, 41, 129, 'BRASS', 'TRUMPET, B FLAT', 'BACH', 'Stradivarius', '488350', NULL, NULL, NULL, NULL, NULL),
	(40, 41, 129, 'BRASS', 'TRUMPET, B FLAT', 'BACH', 'Stradivarius', '488350', NULL, NULL, NULL, NULL, NULL),
	(41, 16, 509, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '737508', NULL, NULL, NULL, NULL, NULL),
	(42, 16, 509, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '737508', NULL, NULL, NULL, NULL, NULL),
	(43, 16, 509, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '737508', NULL, NULL, NULL, NULL, NULL),
	(44, 36, 119, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '259/970406', NULL, NULL, NULL, NULL, NULL),
	(45, 36, 119, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '259/970406', NULL, NULL, NULL, NULL, NULL),
	(46, 36, 119, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '259/970406', NULL, NULL, NULL, NULL, NULL),
	(47, 36, 119, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '259/970406', NULL, NULL, NULL, NULL, NULL),
	(48, 36, 119, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '259/970406', NULL, NULL, NULL, NULL, NULL),
	(49, 36, 119, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '259/970406', NULL, NULL, NULL, NULL, NULL),
	(50, 36, 119, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '259/970406', NULL, NULL, NULL, NULL, NULL),
	(51, 13, 503, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '916386', NULL, NULL, NULL, NULL, NULL),
	(52, 13, 503, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '916386', NULL, NULL, NULL, NULL, NULL),
	(53, 39, 125, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H31434', NULL, NULL, NULL, NULL, NULL),
	(54, 39, 125, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H31434', NULL, NULL, NULL, NULL, NULL),
	(55, 18, 513, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '28411024', NULL, NULL, NULL, NULL, NULL),
	(56, 18, 513, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '28411024', NULL, NULL, NULL, NULL, NULL),
	(57, 18, 513, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '28411024', NULL, NULL, NULL, NULL, NULL),
	(58, 18, 513, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '28411024', NULL, NULL, NULL, NULL, NULL),
	(59, 5, 412, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65449', NULL, NULL, NULL, NULL, NULL),
	(60, 5, 412, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65449', NULL, NULL, NULL, NULL, NULL),
	(61, 5, 412, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65449', NULL, NULL, NULL, NULL, NULL),
	(62, 2, 406, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '405227', NULL, NULL, NULL, NULL, NULL),
	(63, 2, 406, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '405227', NULL, NULL, NULL, NULL, NULL),
	(64, 2, 406, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '405227', NULL, NULL, NULL, NULL, NULL),
	(65, 2, 406, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '405227', NULL, NULL, NULL, NULL, NULL),
	(66, 30, 597, 'WOODWIND', 'SAXOPHONE, ALTO', 'GIARDINELLI', NULL, '200494', NULL, NULL, NULL, NULL, NULL),
	(67, 30, 597, 'WOODWIND', 'SAXOPHONE, ALTO', 'GIARDINELLI', NULL, '200494', NULL, NULL, NULL, NULL, NULL),
	(68, 7, 491, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '608552', NULL, NULL, NULL, NULL, NULL),
	(69, 7, 491, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '608552', NULL, NULL, NULL, NULL, NULL),
	(70, 29, 595, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11120089', NULL, NULL, NULL, NULL, NULL),
	(71, 29, 595, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11120089', NULL, NULL, NULL, NULL, NULL),
	(72, 4, 410, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65480', NULL, NULL, NULL, NULL, NULL),
	(73, 4, 410, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65480', NULL, NULL, NULL, NULL, NULL),
	(74, 38, 123, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '619528', NULL, NULL, NULL, NULL, NULL),
	(75, 38, 123, 'BRASS', 'TRUMPET, B FLAT', 'HOLTON', NULL, '619528', NULL, NULL, NULL, NULL, NULL),
	(76, 12, 501, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '740478', NULL, NULL, NULL, NULL, NULL),
	(77, 12, 501, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '740478', NULL, NULL, NULL, NULL, NULL),
	(78, 10, 497, 'WOODWIND', 'FLUTE', 'ARTLEU', NULL, '3827353', NULL, NULL, NULL, NULL, NULL),
	(79, 10, 497, 'WOODWIND', 'FLUTE', 'ARTLEU', NULL, '3827353', NULL, NULL, NULL, NULL, NULL),
	(80, 17, 511, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'Y-60', NULL, NULL, NULL, NULL, NULL),
	(81, 17, 511, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'Y-60', NULL, NULL, NULL, NULL, NULL),
	(82, 17, 511, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'Y-60', NULL, NULL, NULL, NULL, NULL),
	(83, 17, 511, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'Y-60', NULL, NULL, NULL, NULL, NULL),
	(84, 17, 511, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'Y-60', NULL, NULL, NULL, NULL, NULL),
	(85, 34, 115, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '458367', NULL, NULL, NULL, NULL, NULL),
	(86, 34, 115, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '458367', NULL, NULL, NULL, NULL, NULL),
	(87, 34, 115, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '458367', NULL, NULL, NULL, NULL, NULL),
	(88, 34, 115, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '458367', NULL, NULL, NULL, NULL, NULL),
	(89, 34, 115, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '458367', NULL, NULL, NULL, NULL, NULL),
	(90, 1, 404, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '443895', NULL, NULL, NULL, NULL, NULL),
	(91, 1, 404, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '443895', NULL, NULL, NULL, NULL, NULL),
	(92, 14, 505, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '917448', NULL, NULL, NULL, NULL, NULL),
	(93, 14, 505, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '917448', NULL, NULL, NULL, NULL, NULL),
	(94, 13, 370, 'STRING', 'GUITAR, CLASSICAL', 'PARADISE', '14', NULL, NULL, 'under repair', NULL, 'MS MUSIC', NULL),
	(95, 13, 370, 'STRING', 'GUITAR, CLASSICAL', 'PARADISE', '14', NULL, NULL, 'under repair', NULL, 'MS MUSIC', NULL),
	(96, 8, 493, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '848024', NULL, NULL, NULL, 'PIANO ROOM', NULL) ON CONFLICT DO NOTHING;


--
-- TOC entry 4015 (class 0 OID 30913)
-- Dependencies: 235
-- Data for Name: equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.equipment (id, family, description, legacy_code, code, notes) VALUES
	(3, 'BRASS', 'BUGLE', NULL, 'BG', NULL),
	(4, 'BRASS', 'BUGLE , KEYED', NULL, 'BGK', NULL),
	(5, 'BRASS', 'CIMBASSO', NULL, 'CS', NULL),
	(6, 'BRASS', 'CIMBASSO, B FLAT', NULL, 'CSB', NULL),
	(7, 'BRASS', 'CIMBASSO, C', NULL, 'CSC', NULL),
	(8, 'BRASS', 'CIMBASSO, E FLAT', NULL, 'CSE', NULL),
	(9, 'BRASS', 'CIMBASSO, F', NULL, 'CSF', NULL),
	(10, 'BRASS', 'CORNET', NULL, 'CT', NULL),
	(11, 'BRASS', 'CORNET , POCKET', NULL, 'CTP', NULL),
	(12, 'BRASS', 'CORNET, A', NULL, 'CTA', NULL),
	(13, 'BRASS', 'CORNET, C', NULL, 'CTC', NULL),
	(14, 'BRASS', 'CORNET, E♭  FLAT', NULL, 'CTE', NULL),
	(15, 'BRASS', 'DIDGERIDOO', NULL, 'DGD', NULL),
	(16, 'BRASS', 'EUPHONIUM', NULL, 'EP', NULL),
	(17, 'BRASS', 'EUPHONIUM , DOUBLE BELL', NULL, 'EPD', NULL),
	(18, 'BRASS', 'FLUGELHORN', NULL, 'FGH', NULL),
	(19, 'BRASS', 'FRENCH HORN', NULL, 'FH', NULL),
	(20, 'BRASS', 'HORN, ALTO', NULL, 'HNE', NULL),
	(21, 'BRASS', 'HORN, F', NULL, 'HNF', NULL),
	(23, 'BRASS', 'METALLOPHONE', NULL, 'MTL', NULL),
	(24, 'BRASS', 'SAXHORN', NULL, 'SXH', NULL),
	(25, 'BRASS', 'SAXOTROMBA', NULL, 'STB', NULL),
	(26, 'BRASS', 'SAXTUBA', NULL, 'STU', NULL),
	(30, 'BRASS', 'TROMBONE, BASS', NULL, 'TNB', NULL),
	(31, 'BRASS', 'TROMBONE, PICCOLO', NULL, 'TNP', NULL),
	(32, 'BRASS', 'TROMBONE, SOPRANO', NULL, 'TNS', NULL),
	(33, 'BRASS', 'TROMBONE, TENOR', NULL, 'TN', NULL),
	(35, 'BRASS', 'TROMBONE, VALVE', NULL, 'TNV', NULL),
	(36, 'BRASS', 'TRUMPET , PICCOLO', NULL, 'TPC', NULL),
	(37, 'BRASS', 'TRUMPET ,TUBE', NULL, 'TPX', NULL),
	(39, 'BRASS', 'TRUMPET, BAROQUE', NULL, 'TPQ', NULL),
	(40, 'BRASS', 'TRUMPET, BASS', NULL, 'TPB', NULL),
	(42, 'BRASS', 'TRUMPET, ROTARY', NULL, 'TPR', NULL),
	(43, 'BRASS', 'TRUMPET, SLIDE', NULL, 'TPSL', NULL),
	(44, 'BRASS', 'TRUMPET,SOPRANO', NULL, 'TPS', NULL),
	(46, 'BRASS', 'TUBA, BASS', NULL, 'TBB', NULL),
	(47, 'BRASS', 'TUBA, WAGNER', NULL, 'TBW', NULL),
	(48, 'BRASS', 'VUVUZELA', NULL, 'VV', NULL),
	(49, 'ELECTRIC', 'AMPLIFIER', NULL, 'AM', NULL),
	(50, 'ELECTRIC', 'AMPLIFIER, BASS', NULL, 'AMB', NULL),
	(51, 'ELECTRIC', 'AMPLIFIER, GUITAR', NULL, 'AMG', NULL),
	(52, 'ELECTRIC', 'AMPLIFIER, KEYBOARD', NULL, 'AMK', NULL),
	(56, 'KEYBOARD', 'KEYBOARD', NULL, 'KB', NULL),
	(57, 'KEYBOARD', 'PIANO, GRAND', NULL, 'PG', NULL),
	(58, 'KEYBOARD', 'PIANO, UPRIGHT', NULL, 'PU', NULL),
	(59, 'KEYBOARD', 'PIANO (PIANOFORTE)', NULL, 'P', NULL),
	(60, 'KEYBOARD', 'PIANO, ELECTRIC', NULL, 'PE', NULL),
	(61, 'MISCELLANEOUS', 'HARNESS', NULL, NULL, NULL),
	(62, 'MISCELLANEOUS', 'PEDAL, SUSTAIN', NULL, NULL, NULL),
	(63, 'MISCELLANEOUS', 'STAND, GUITAR', NULL, NULL, NULL),
	(64, 'MISCELLANEOUS', 'STAND, MUSIC', NULL, NULL, NULL),
	(65, 'PERCUSSION', 'ASHIKO', NULL, 'ASK', NULL),
	(66, 'PERCUSSION', 'BARREL DRUM', NULL, 'BRD', NULL),
	(67, 'PERCUSSION', 'BASS DRUM', NULL, 'BD', NULL),
	(68, 'PERCUSSION', 'BONGO DRUMS', NULL, 'BNG', NULL),
	(69, 'PERCUSSION', 'CABASA', NULL, 'CBS', NULL),
	(70, 'PERCUSSION', 'CARILLON', NULL, 'CRL', NULL),
	(71, 'PERCUSSION', 'CASTANETS', NULL, 'CST', NULL),
	(72, 'PERCUSSION', 'CLAPSTICK', NULL, 'CLP', NULL),
	(73, 'PERCUSSION', 'CLAVES', NULL, 'CLV', NULL),
	(74, 'PERCUSSION', 'CONGA', NULL, 'CG', NULL),
	(75, 'PERCUSSION', 'COWBELL', NULL, 'CWB', NULL),
	(76, 'PERCUSSION', 'CYMBAL', NULL, 'CM', NULL),
	(77, 'PERCUSSION', 'DJEMBE', NULL, 'DJ', NULL),
	(78, 'PERCUSSION', 'FLEXATONE', NULL, 'FXT', NULL),
	(79, 'PERCUSSION', 'GLOCKENSPIEL', NULL, 'GLK', NULL),
	(80, 'PERCUSSION', 'GOBLET DRUM', NULL, 'GBL', NULL),
	(81, 'PERCUSSION', 'GONG', NULL, 'GNG', NULL),
	(82, 'PERCUSSION', 'HANDBELLS', NULL, 'HB', NULL),
	(83, 'PERCUSSION', 'HANDPAN', NULL, 'HPN', NULL),
	(84, 'PERCUSSION', 'ILIMBA DRUM', NULL, 'ILD', NULL),
	(85, 'PERCUSSION', 'KALIMBA', NULL, 'KLM', NULL),
	(86, 'PERCUSSION', 'KANJIRA', NULL, 'KNJ', NULL),
	(87, 'PERCUSSION', 'KAYAMBA', NULL, 'KYM', NULL),
	(88, 'PERCUSSION', 'KEBERO', NULL, 'KBR', NULL),
	(89, 'PERCUSSION', 'KEMANAK', NULL, 'KMK', NULL),
	(90, 'PERCUSSION', 'MARIMBA', NULL, 'MRM', NULL),
	(91, 'PERCUSSION', 'MBIRA', NULL, 'MB', NULL),
	(92, 'PERCUSSION', 'MRIDANGAM', NULL, 'MRG', NULL),
	(93, 'PERCUSSION', 'NAGARA (DRUM)', NULL, 'NGR', NULL),
	(94, 'PERCUSSION', 'OCTA-VIBRAPHONE', NULL, 'OV', NULL),
	(95, 'PERCUSSION', 'PATE', NULL, 'PT', NULL),
	(96, 'PERCUSSION', 'SANDPAPER BLOCKS', NULL, 'SPB', NULL),
	(97, 'PERCUSSION', 'SHEKERE', NULL, 'SKR', NULL),
	(98, 'PERCUSSION', 'SLIT DRUM', NULL, 'SLD', NULL),
	(99, 'PERCUSSION', 'SNARE', NULL, 'SR', NULL),
	(100, 'PERCUSSION', 'STEELPAN', NULL, 'SP', NULL),
	(101, 'PERCUSSION', 'TABLA', NULL, 'TBL', NULL),
	(102, 'PERCUSSION', 'TALKING DRUM', NULL, 'TDR', NULL),
	(103, 'PERCUSSION', 'TAMBOURINE', NULL, 'TR', NULL),
	(104, 'PERCUSSION', 'TIMBALES (PAILAS)', NULL, 'TMP', NULL),
	(105, 'PERCUSSION', 'TOM-TOM DRUM', NULL, 'TT', NULL),
	(106, 'PERCUSSION', 'TRIANGLE', NULL, 'TGL', NULL),
	(107, 'PERCUSSION', 'VIBRAPHONE', NULL, 'VBR', NULL),
	(108, 'PERCUSSION', 'VIBRASLAP', NULL, 'VS', NULL),
	(109, 'PERCUSSION', 'WOOD BLOCK', NULL, 'WB', NULL),
	(110, 'PERCUSSION', 'XYLOPHONE', NULL, 'X', NULL),
	(111, 'PERCUSSION', 'AGOGO BELL', NULL, 'AGG', NULL),
	(112, 'PERCUSSION', 'BELL SET', NULL, 'BL', NULL),
	(113, 'PERCUSSION', 'BELL TREE', NULL, 'BLR', NULL),
	(114, 'PERCUSSION', 'BELLS, CONCERT', NULL, 'BLC', NULL),
	(115, 'PERCUSSION', 'BELLS, SLEIGH', NULL, 'BLS', NULL),
	(116, 'PERCUSSION', 'BELLS, TUBULAR', NULL, 'BLT', NULL),
	(118, 'PERCUSSION', 'CYMBAL, SUSPENDED 18 INCH', NULL, 'CMS', NULL),
	(119, 'PERCUSSION', 'CYMBALS, HANDHELD 16 INCH', NULL, 'CMY', NULL),
	(120, 'PERCUSSION', 'CYMBALS, HANDHELD 18 INCH', NULL, 'CMZ', NULL),
	(121, 'PERCUSSION', 'DRUMSET', NULL, 'DK', NULL),
	(122, 'PERCUSSION', 'DRUMSET, ELECTRIC', NULL, 'DKE', NULL),
	(123, 'PERCUSSION', 'EGG SHAKERS', NULL, 'EGS', NULL),
	(124, 'PERCUSSION', 'GUIRO', NULL, 'GUR', NULL),
	(125, 'PERCUSSION', 'MARACAS', NULL, 'MRC', NULL),
	(127, 'PERCUSSION', 'PRACTICE KIT', NULL, 'PK', NULL),
	(128, 'PERCUSSION', 'PRACTICE PAD', NULL, 'PD', NULL),
	(129, 'PERCUSSION', 'QUAD, MARCHING', NULL, 'Q', NULL),
	(130, 'PERCUSSION', 'RAINSTICK', NULL, 'RK', NULL),
	(132, 'PERCUSSION', 'SNARE, CONCERT', NULL, 'SRC', NULL),
	(133, 'PERCUSSION', 'SNARE, MARCHING', NULL, 'SRM', NULL),
	(131, 'MISCELLANEOUS', 'SHIELD', NULL, NULL, NULL),
	(126, 'MISCELLANEOUS', 'MOUNTING BRACKET, BELL TREE', NULL, NULL, NULL),
	(54, 'SOUND', 'MIXER', NULL, 'MX', NULL),
	(55, 'SOUND', 'PA SYSTEM, ALL-IN-ONE', NULL, NULL, NULL),
	(53, 'SOUND', 'MICROPHONE', NULL, NULL, NULL),
	(135, 'PERCUSSION', 'TAMBOURINE, 10 INCH', NULL, 'TRT', NULL),
	(136, 'PERCUSSION', 'TAMBOURINE, 6 INCH', NULL, 'TRS', NULL),
	(137, 'PERCUSSION', 'TAMBOURINE, 8 INCH', NULL, 'TRE', NULL),
	(138, 'PERCUSSION', 'TIMBALI', NULL, 'TML', NULL),
	(139, 'PERCUSSION', 'TIMPANI, 23 INCH', NULL, 'TPT', NULL),
	(140, 'PERCUSSION', 'TIMPANI, 26 INCH', NULL, 'TPD', NULL),
	(141, 'PERCUSSION', 'TIMPANI, 29 INCH', NULL, 'TPN', NULL),
	(142, 'PERCUSSION', 'TIMPANI, 32 INCH', NULL, 'TPW', NULL),
	(143, 'PERCUSSION', 'TOM, MARCHING', NULL, 'TTM', NULL),
	(144, 'PERCUSSION', 'TUBANOS', NULL, 'TBN', NULL),
	(145, 'PERCUSSION', 'WIND CHIMES', NULL, 'WC', NULL),
	(146, 'STRING', 'ADUNGU', NULL, 'ADG', NULL),
	(147, 'STRING', 'AEOLIAN HARP', NULL, 'AHP', NULL),
	(148, 'STRING', 'AUTOHARP', NULL, 'HPA', NULL),
	(149, 'STRING', 'BALALAIKA', NULL, 'BLK', NULL),
	(150, 'STRING', 'BANJO', NULL, 'BJ', NULL),
	(151, 'STRING', 'BANJO CELLO', NULL, 'BJC', NULL),
	(152, 'STRING', 'BANJO, 4-STRING', NULL, 'BJX', NULL),
	(153, 'STRING', 'BANJO, 5-STRING', NULL, 'BJY', NULL),
	(154, 'STRING', 'BANJO, 6-STRING', NULL, 'BJW', NULL),
	(155, 'STRING', 'BANJO, BASS', NULL, 'BJB', NULL),
	(156, 'STRING', 'BANJO, BLUEGRASS', NULL, 'BJG', NULL),
	(157, 'STRING', 'BANJO, PLECTRUM', NULL, 'BJP', NULL),
	(158, 'STRING', 'BANJO, TENOR', NULL, 'BJT', NULL),
	(159, 'STRING', 'BANJO, ZITHER', NULL, 'BJZ', NULL),
	(160, 'STRING', 'CARIMBA', NULL, 'CRM', NULL),
	(161, 'STRING', 'CELLO, (VIOLONCELLO)', NULL, 'VCL', NULL),
	(162, 'STRING', 'CELLO, ELECTRIC', NULL, 'VCE', NULL),
	(163, 'STRING', 'CHAPMAN STICK', NULL, 'CPS', NULL),
	(164, 'STRING', 'CLAVICHORD', NULL, 'CVC', NULL),
	(165, 'STRING', 'CLAVINET', NULL, 'CVN', NULL),
	(166, 'STRING', 'CONTRAGUITAR', NULL, 'GTC', NULL),
	(167, 'STRING', 'CRWTH, (CROWD)', NULL, 'CRW', NULL),
	(168, 'STRING', 'DIDDLEY BOW', NULL, 'DDB', NULL),
	(169, 'STRING', 'DOUBLE BASS', NULL, 'DB', NULL),
	(170, 'STRING', 'DOUBLE BASS, 5-STRING', NULL, 'DBF', NULL),
	(171, 'STRING', 'DOUBLE BASS, ELECTRIC', NULL, 'DBE', NULL),
	(172, 'STRING', 'DULCIMER', NULL, 'DCM', NULL),
	(173, 'STRING', 'ELECTRIC CYMBALUM', NULL, 'CYE', NULL),
	(174, 'STRING', 'FIDDLE', NULL, 'FDD', NULL),
	(175, 'STRING', 'GUITAR SYNTHESIZER', NULL, 'GR', NULL),
	(176, 'STRING', 'GUITAR, 10-STRING', NULL, 'GRK', NULL),
	(177, 'STRING', 'GUITAR, 12-STRING', NULL, 'GRL', NULL),
	(178, 'STRING', 'GUITAR, 7-STRING', NULL, 'GRM', NULL),
	(179, 'STRING', 'GUITAR, 8-STRING', NULL, 'GRN', NULL),
	(180, 'STRING', 'GUITAR, 9-STRING', NULL, 'GRP', NULL),
	(181, 'STRING', 'GUITAR, ACOUSTIC', NULL, 'GRA', NULL),
	(182, 'STRING', 'GUITAR, ACOUSTIC-ELECTRIC', NULL, 'GRJ', NULL),
	(183, 'STRING', 'GUITAR, ARCHTOP', NULL, 'GRH', NULL),
	(184, 'STRING', 'GUITAR, BARITONE', NULL, 'GRR', NULL),
	(185, 'STRING', 'GUITAR, BAROQUE', NULL, 'GRQ', NULL),
	(186, 'STRING', 'GUITAR, BASS', NULL, 'GRB', NULL),
	(187, 'STRING', 'GUITAR, BASS ACOUSTIC', NULL, 'GRG', NULL),
	(188, 'STRING', 'GUITAR, BRAHMS', NULL, 'GRZ', NULL),
	(189, 'STRING', 'GUITAR, CLASSICAL', NULL, 'GRC', NULL),
	(190, 'STRING', 'GUITAR, CUTAWAY', NULL, 'GRW', NULL),
	(191, 'STRING', 'GUITAR, DOUBLE-NECK', NULL, 'GRD', NULL),
	(192, 'STRING', 'GUITAR, ELECTRIC', NULL, 'GRE', NULL),
	(193, 'STRING', 'GUITAR, FLAMENCO', NULL, 'GRF', NULL),
	(194, 'STRING', 'GUITAR, FRETLESS', NULL, 'GRY', NULL),
	(195, 'STRING', 'GUITAR, HALF', NULL, 'GRT', NULL),
	(196, 'STRING', 'GUITAR, OCTAVE', NULL, 'GRO', NULL),
	(197, 'STRING', 'GUITAR, SEMI-ACOUSTIC', NULL, 'GRX', NULL),
	(198, 'STRING', 'GUITAR, STEEL', NULL, 'GRS', NULL),
	(199, 'STRING', 'HARDANGER FIDDLE', NULL, 'FDH', NULL),
	(200, 'STRING', 'HARMONICO', NULL, 'HMR', NULL),
	(201, 'STRING', 'HARP', NULL, 'HP', NULL),
	(202, 'STRING', 'HARP GUITAR', NULL, 'HPG', NULL),
	(203, 'STRING', 'HARP, ELECTRIC', NULL, 'HPE', NULL),
	(204, 'STRING', 'HARPSICHORD', NULL, 'HRC', NULL),
	(205, 'STRING', 'HURDY-GURDY', NULL, 'HG', NULL),
	(206, 'STRING', 'KORA', NULL, 'KR', NULL),
	(207, 'STRING', 'KOTO', NULL, 'KT', NULL),
	(208, 'STRING', 'LOKANGA', NULL, 'LK', NULL),
	(209, 'STRING', 'LUTE', NULL, 'LT', NULL),
	(210, 'STRING', 'LUTE GUITAR', NULL, 'LTG', NULL),
	(211, 'STRING', 'LYRA (BYZANTINE)', NULL, 'LYB', NULL),
	(212, 'STRING', 'LYRA (CRETAN)', NULL, 'LYC', NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.equipment (id, family, description, legacy_code, code, notes) VALUES
	(213, 'STRING', 'LYRE', NULL, 'LY', NULL),
	(214, 'STRING', 'MANDOBASS', NULL, 'MDB', NULL),
	(215, 'STRING', 'MANDOCELLO', NULL, 'MDC', NULL),
	(216, 'STRING', 'MANDOLA', NULL, 'MDL', NULL),
	(217, 'STRING', 'MANDOLIN', NULL, 'MD', NULL),
	(218, 'STRING', 'MANDOLIN , BUEGRASS', NULL, 'MDX', NULL),
	(219, 'STRING', 'MANDOLIN , ELECTRIC', NULL, 'MDE', NULL),
	(220, 'STRING', 'MANDOLIN-BANJO', NULL, 'MDJ', NULL),
	(221, 'STRING', 'MANDOLIN, OCTAVE', NULL, 'MDO', NULL),
	(222, 'STRING', 'MANDOLUTE', NULL, 'MDT', NULL),
	(223, 'STRING', 'MUSICAL BOW', NULL, 'MSB', NULL),
	(224, 'STRING', 'OCTOBASS', NULL, 'OCB', NULL),
	(225, 'STRING', 'OUD', NULL, 'OUD', NULL),
	(226, 'STRING', 'PSALTERY', NULL, 'PS', NULL),
	(227, 'STRING', 'SITAR', NULL, 'STR', NULL),
	(228, 'STRING', 'THEORBO', NULL, 'TRB', NULL),
	(229, 'STRING', 'U-BASS', NULL, 'UB', NULL),
	(230, 'STRING', 'UKULELE, 5-STRING TENOR', NULL, 'UKF', NULL),
	(231, 'STRING', 'UKULELE, 6-STRING TENOR', NULL, 'UKX', NULL),
	(232, 'STRING', 'UKULELE, 8-STRING TENOR', NULL, 'UKW', NULL),
	(233, 'STRING', 'UKULELE, BARITONE', NULL, 'UKR', NULL),
	(234, 'STRING', 'UKULELE, BASS', NULL, 'UKB', NULL),
	(235, 'STRING', 'UKULELE, CONCERT', NULL, 'UKC', NULL),
	(236, 'STRING', 'UKULELE, CONTRABASS', NULL, 'UKZ', NULL),
	(237, 'STRING', 'UKULELE, ELECTRIC', NULL, 'UKE', NULL),
	(238, 'STRING', 'UKULELE, HARP', NULL, 'UKH', NULL),
	(239, 'STRING', 'UKULELE, LAP STEEL', NULL, 'UKL', NULL),
	(240, 'STRING', 'UKULELE, POCKET', NULL, 'UKP', NULL),
	(241, 'STRING', 'UKULELE, SOPRANO', NULL, 'UKS', NULL),
	(242, 'STRING', 'UKULELE, TENOR', NULL, 'UKT', NULL),
	(243, 'STRING', 'VIOLA 13 INCH', NULL, 'VLT', NULL),
	(244, 'STRING', 'VIOLA 16 INCH (FULL)', NULL, 'VL', NULL),
	(245, 'STRING', 'VIOLA, ELECTRIC', NULL, 'VLE', NULL),
	(246, 'STRING', 'VIOLIN', NULL, 'VN', NULL),
	(247, 'STRING', 'VIOLIN, 1/2', NULL, 'VNH', NULL),
	(248, 'STRING', 'VIOLIN, 1/4', NULL, 'VNQ', NULL),
	(249, 'STRING', 'VIOLIN, 3/4', NULL, 'VNT', NULL),
	(250, 'STRING', 'VIOLIN, ELECTRIC', NULL, 'VNE', NULL),
	(251, 'STRING', 'ZITHER', NULL, 'Z', NULL),
	(252, 'STRING', 'ZITHER, ALPINE (HARP ZITHER)', NULL, 'ZA', NULL),
	(253, 'STRING', 'ZITHER, CONCERT', NULL, 'ZC', NULL),
	(254, 'WOODWIND', 'ALPHORN', NULL, 'ALH', NULL),
	(255, 'WOODWIND', 'BAGPIPE', NULL, 'BGP', NULL),
	(256, 'WOODWIND', 'BASSOON', NULL, 'BS', NULL),
	(257, 'WOODWIND', 'CHALUMEAU', NULL, 'CHM', NULL),
	(258, 'WOODWIND', 'CLARINET, ALTO IN E FLAT', NULL, 'CLE', NULL),
	(261, 'WOODWIND', 'CLARINET, BASSET IN A', NULL, 'CLA', NULL),
	(262, 'WOODWIND', 'CLARINET, CONTRA-ALTO', NULL, 'CLT', NULL),
	(263, 'WOODWIND', 'CLARINET, CONTRABASS', NULL, 'CLU', NULL),
	(264, 'WOODWIND', 'CLARINET, PICCOLO IN A FLAT (OR G)', NULL, 'CLC', NULL),
	(265, 'WOODWIND', 'CLARINET, SOPRANINO IN E FLAT (OR D)', NULL, 'CLS', NULL),
	(266, 'WOODWIND', 'CONCERTINA', NULL, 'CNT', NULL),
	(267, 'WOODWIND', 'CONTRABASSOON/DOUBLE BASSOON', NULL, 'BSD', NULL),
	(268, 'WOODWIND', 'DULCIAN', NULL, 'DLC', NULL),
	(269, 'WOODWIND', 'DULCIAN, ALTO', NULL, 'DLCA', NULL),
	(270, 'WOODWIND', 'DULCIAN, BASS', NULL, 'DLCB', NULL),
	(271, 'WOODWIND', 'DULCIAN, SOPRANO', NULL, 'DLCS', NULL),
	(272, 'WOODWIND', 'DULCIAN, TENOR', NULL, 'DLCT', NULL),
	(273, 'WOODWIND', 'DZUMARI', NULL, 'DZ', NULL),
	(274, 'WOODWIND', 'ENGLISH HORN', NULL, 'CA', NULL),
	(275, 'WOODWIND', 'FIFE', NULL, 'FF', NULL),
	(276, 'WOODWIND', 'FLAGEOLET', NULL, 'FGL', NULL),
	(278, 'WOODWIND', 'FLUTE , NOSE', NULL, 'FLN', NULL),
	(279, 'WOODWIND', 'FLUTE, ALTO', NULL, 'FLA', NULL),
	(280, 'WOODWIND', 'FLUTE, BASS', NULL, 'FLB', NULL),
	(281, 'WOODWIND', 'FLUTE, CONTRA-ALTO', NULL, 'FLX', NULL),
	(282, 'WOODWIND', 'FLUTE, CONTRABASS', NULL, 'FLC', NULL),
	(283, 'WOODWIND', 'FLUTE, IRISH', NULL, 'FLI', NULL),
	(284, 'WOODWIND', 'HARMONICA', NULL, 'HM', NULL),
	(285, 'WOODWIND', 'HARMONICA, CHROMATIC', NULL, 'HMC', NULL),
	(286, 'WOODWIND', 'HARMONICA, DIATONIC', NULL, 'HMD', NULL),
	(287, 'WOODWIND', 'HARMONICA, ORCHESTRAL', NULL, 'HMO', NULL),
	(288, 'WOODWIND', 'HARMONICA, TREMOLO', NULL, 'HMT', NULL),
	(289, 'WOODWIND', 'KAZOO', NULL, 'KZO', NULL),
	(290, 'WOODWIND', 'MELODEON', NULL, 'MLD', NULL),
	(291, 'WOODWIND', 'MELODICA', NULL, 'ML', NULL),
	(292, 'WOODWIND', 'MUSETTE DE COUR', NULL, 'MSC', NULL),
	(294, 'WOODWIND', 'OCARINA', NULL, 'OCR', NULL),
	(295, 'WOODWIND', 'PAN FLUTE', NULL, 'PF', NULL),
	(297, 'WOODWIND', 'PIPE ORGAN', NULL, 'PO', NULL),
	(298, 'WOODWIND', 'PITCH PIPE', NULL, 'PP', NULL),
	(299, 'WOODWIND', 'RECORDER', NULL, 'R', NULL),
	(300, 'WOODWIND', 'RECORDER, BASS', NULL, 'RB', NULL),
	(301, 'WOODWIND', 'RECORDER, CONTRA BASS', NULL, 'RC', NULL),
	(302, 'WOODWIND', 'RECORDER, DESCANT', NULL, 'RD', NULL),
	(303, 'WOODWIND', 'RECORDER, GREAT BASS', NULL, 'RG', NULL),
	(304, 'WOODWIND', 'RECORDER, SOPRANINO', NULL, 'RS', NULL),
	(305, 'WOODWIND', 'RECORDER, SUBCONTRA BASS', NULL, 'RX', NULL),
	(306, 'WOODWIND', 'RECORDER, TENOR', NULL, 'RT', NULL),
	(307, 'WOODWIND', 'RECORDER, TREBLE OR ALTO', NULL, 'RA', NULL),
	(308, 'WOODWIND', 'ROTHPHONE', NULL, 'RP', NULL),
	(309, 'WOODWIND', 'ROTHPHONE , ALTO', NULL, 'RPA', NULL),
	(310, 'WOODWIND', 'ROTHPHONE , BARITONE', NULL, 'RPX', NULL),
	(311, 'WOODWIND', 'ROTHPHONE , BASS', NULL, 'RPB', NULL),
	(312, 'WOODWIND', 'ROTHPHONE , SOPRANO', NULL, 'RPS', NULL),
	(313, 'WOODWIND', 'ROTHPHONE , TENOR', NULL, 'RPT', NULL),
	(314, 'WOODWIND', 'SARRUSOPHONE', NULL, 'SRP', NULL),
	(318, 'WOODWIND', 'SAXOPHONE, BASS', NULL, 'SXY', NULL),
	(319, 'WOODWIND', 'SAXOPHONE, C MELODY (TENOR IN C)', NULL, 'SXM', NULL),
	(320, 'WOODWIND', 'SAXOPHONE, C SOPRANO', NULL, 'SXC', NULL),
	(321, 'WOODWIND', 'SAXOPHONE, CONTRABASS', NULL, 'SXZ', NULL),
	(322, 'WOODWIND', 'SAXOPHONE, MEZZO-SOPRANO (ALTO IN F)', NULL, 'SXF', NULL),
	(323, 'WOODWIND', 'SAXOPHONE, PICCOLO (SOPRILLO)', NULL, 'SXP', NULL),
	(324, 'WOODWIND', 'SAXOPHONE, SOPRANINO', NULL, 'SXX', NULL),
	(325, 'WOODWIND', 'SAXOPHONE, SOPRANO', NULL, 'SXS', NULL),
	(327, 'WOODWIND', 'SEMICONTRABASSOON', NULL, 'BSS', NULL),
	(328, 'WOODWIND', 'WHISTLE, TIN', NULL, 'WT', NULL),
	(117, 'MISCELLANEOUS', 'CRADLE, CONCERT CYMBAL', NULL, NULL, NULL),
	(134, 'MISCELLANEOUS', 'STAND, CYMBAL', NULL, NULL, NULL),
	(329, 'PERCUSSION', 'BELL KIT', NULL, 'BK', NULL),
	(330, 'BRASS', 'BARITONE/EUPHONIUM', 'BH', 'BH', NULL),
	(331, 'BRASS', 'BARITONE/TENOR HORN', 'BH', 'BT', NULL),
	(332, 'BRASS', 'MELLOPHONE', 'M', 'M', NULL),
	(333, 'BRASS', 'SOUSAPHONE', 'T', 'SSP', NULL),
	(334, 'BRASS', 'TROMBONE, ALTO', 'PTB', 'TNA', NULL),
	(335, 'BRASS', 'TROMBONE, ALTO - PLASTIC', 'PTB', 'TNAP', NULL),
	(336, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PTB', 'TNTP', NULL),
	(337, 'BRASS', 'TRUMPET, B FLAT', 'TP', 'TP', NULL),
	(338, 'BRASS', 'TRUMPET, POCKET', 'TPP', 'TPP', NULL),
	(339, 'BRASS', 'TUBA', 'T', 'TB', NULL),
	(340, 'WOODWIND', 'CLARINET, B FLAT', 'CL', 'CL', NULL),
	(341, 'WOODWIND', 'CLARINET, BASS', 'BCL', 'CLB', NULL),
	(342, 'WOODWIND', 'FLUTE', 'FL', 'FL', NULL),
	(343, 'WOODWIND', 'OBOE', 'OB', 'OB', NULL),
	(344, 'WOODWIND', 'PICCOLO', 'PC', 'PC', NULL),
	(345, 'WOODWIND', 'SAXOPHONE, ALTO', 'AX', 'SXA', NULL),
	(346, 'WOODWIND', 'SAXOPHONE, BARITONE', 'BX', 'SXB', NULL),
	(347, 'WOODWIND', 'SAXOPHONE, TENOR', 'TX', 'SXT', NULL),
	(348, 'STRING', 'DUMMY 1', NULL, 'DMMO', NULL),
	(349, 'ELECTRIC', 'AMPLIFIER, COMBO', NULL, 'AMC', NULL),
	(350, 'BRASS', 'TROMBONE, BASS PLASTIC', NULL, 'TNBP', NULL) ON CONFLICT DO NOTHING;


--
-- TOC entry 4020 (class 0 OID 30952)
-- Dependencies: 242
-- Data for Name: hardware_and_equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.hardware_and_equipment (id, family, description, legacy_code, code, notes) VALUES
	(10, 'SOUND', 'MIXER', NULL, 'MX', NULL),
	(11, 'SOUND', 'PA SYSTEM, ALL-IN-ONE', NULL, NULL, NULL),
	(12, 'SOUND', 'MICROPHONE', NULL, NULL, NULL),
	(13, 'MISCELLANEOUS', 'HARNESS', NULL, NULL, NULL),
	(14, 'MISCELLANEOUS', 'PEDAL, SUSTAIN', NULL, NULL, NULL),
	(15, 'MISCELLANEOUS', 'STAND, GUITAR', NULL, NULL, NULL),
	(16, 'MISCELLANEOUS', 'STAND, MUSIC', NULL, NULL, NULL),
	(17, 'MISCELLANEOUS', 'SHIELD', NULL, NULL, NULL),
	(18, 'MISCELLANEOUS', 'MOUNTING BRACKET, BELL TREE', NULL, NULL, NULL),
	(19, 'MISCELLANEOUS', 'CRADLE, CONCERT CYMBAL', NULL, NULL, NULL),
	(20, 'MISCELLANEOUS', 'STAND, CYMBAL', NULL, NULL, NULL) ON CONFLICT DO NOTHING;


--
-- TOC entry 4002 (class 0 OID 30727)
-- Dependencies: 222
-- Data for Name: instrument_conditions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.instrument_conditions (id, condition) VALUES
	(1, 'New'),
	(2, 'Good'),
	(3, 'Worn'),
	(4, 'Damaged'),
	(5, 'Write off'),
	(6, 'Lost') ON CONFLICT DO NOTHING;


--
-- TOC entry 4001 (class 0 OID 30721)
-- Dependencies: 221
-- Data for Name: instrument_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.instrument_history (id, transaction_type, transaction_timestamp, item_id, notes, assigned_to, created_by, location, contact, returned_by_id) VALUES
	(3529, 'Instrument Returned', '2024-06-24 14:27:14.39395+03', 1906, NULL, NULL, 'kwando', NULL, NULL, 1071),
	(3530, 'Instrument Returned', '2024-06-24 14:27:14.39395+03', 1818, NULL, NULL, 'kwando', NULL, NULL, 1071),
	(3531, 'Instrument Returned', '2024-06-24 14:27:14.39395+03', 1873, NULL, NULL, 'kwando', NULL, NULL, 1071),
	(3532, 'Instrument Returned', '2024-06-24 14:27:14.39395+03', 1856, NULL, NULL, 'kwando', NULL, NULL, 1071),
	(3533, 'Instrument Returned', '2024-06-24 14:27:14.39395+03', 1496, NULL, NULL, 'kwando', NULL, NULL, 1071),
	(3534, 'Instrument Returned', '2024-06-24 15:34:23.115925+03', 4163, NULL, NULL, 'nochomo', NULL, NULL, 1074),
	(3535, 'Cases swapped from 8 to 7', '2024-06-25 12:42:31.781236+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3536, 'Cases swapped from 7 to 8', '2024-06-25 12:42:31.781236+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3537, 'Cases swapped from 7 to 8', '2024-06-25 15:03:12.487984+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3538, 'Cases swapped from 8 to 7', '2024-06-25 15:03:12.487984+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3539, 'Cases swapped from 8 to 7', '2024-06-25 15:05:35.319038+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3540, 'Cases swapped from 7 to 8', '2024-06-25 15:05:35.319038+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3541, 'Cases swapped from 7 to 8', '2024-06-26 15:17:02.638002+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3542, 'Cases swapped from 8 to 7', '2024-06-26 15:17:02.638002+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3543, 'Instrument Out', '2024-06-26 15:32:57.706057+03', 4163, NULL, '1074', 'nochomo', NULL, NULL, NULL),
	(3544, 'Instrument Out', '2024-06-26 16:29:16.501146+03', 4165, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
	(3545, 'Instrument Out', '2024-06-26 16:46:18.333044+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
	(3546, 'Instrument Out', '2024-06-26 16:46:35.995986+03', 4166, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
	(3547, 'Instrument Out', '2024-06-26 16:46:36.00323+03', 4203, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
	(3548, 'Instrument Out', '2024-06-27 11:04:26.464125+03', 4164, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
	(3549, 'Instrument Out', '2024-06-27 11:05:32.544647+03', 2129, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
	(3550, 'Cases swapped from 11 to 1', '2024-06-27 11:31:25.809604+03', 1681, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3551, 'Cases swapped from 1 to 11', '2024-06-27 11:31:25.809604+03', 2024, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3552, 'Cases swapped from 11 to 1', '2024-06-27 11:32:23.678501+03', 2024, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3553, 'Cases swapped from 1 to 11', '2024-06-27 11:32:23.678501+03', 1681, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3554, 'Cases swapped from 9 to 9', '2024-06-27 11:33:25.796283+03', 1950, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3555, 'Cases swapped from 9 to 9', '2024-06-27 11:33:25.796283+03', 1950, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3556, 'Cases swapped from 11 to 1', '2024-06-27 11:36:04.831854+03', 1681, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3557, 'Cases swapped from 1 to 11', '2024-06-27 11:36:04.831854+03', 2024, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3558, 'Cases swapped from 11 to 1', '2024-06-27 11:37:07.114056+03', 2024, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3559, 'Cases swapped from 1 to 11', '2024-06-27 11:37:07.114056+03', 1681, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3560, 'Cases swapped from 11 to 1', '2024-06-27 11:53:18.742094+03', 1681, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3561, 'Cases swapped from 1 to 11', '2024-06-27 11:53:18.742094+03', 2024, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3562, 'Cases swapped from 11 to 3', '2024-06-27 11:53:34.19496+03', 1978, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3563, 'Cases swapped from 3 to 11', '2024-06-27 11:53:34.19496+03', 1935, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3564, 'Cases swapped from 3 to 11', '2024-06-27 13:23:24.619563+03', 1978, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3565, 'Cases swapped from 11 to 3', '2024-06-27 13:23:24.619563+03', 1935, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3566, 'Cases swapped from 8 to 7', '2024-06-27 15:08:00.081665+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3567, 'Cases swapped from 7 to 8', '2024-06-27 15:08:00.081665+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3568, 'Instrument Confirmed', '2024-06-27 15:39:21.113361+03', 1926, 'Just a check of the system', NULL, 'nochomo', 'INSTRUMENT STORE', NULL, NULL),
	(3569, 'Instrument Confirmed', '2024-06-27 15:52:46.075297+03', 1926, 'Just a check of the system', NULL, 'nochomo', 'INSTRUMENT STORE', NULL, NULL),
	(3570, 'Cases swapped from 20 to 9', '2024-09-10 06:51:40.323904+03', 1991, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3571, 'Cases swapped from 9 to 20', '2024-09-10 06:51:40.323904+03', 1807, NULL, NULL, 'nochomo', NULL, NULL, NULL),
	(3572, 'Instrument Returned', '2024-09-10 06:55:40.891563+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, 1071),
	(3573, 'Instrument Returned', '2024-09-10 06:55:45.369714+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, 1071),
	(3574, 'Instrument Returned', '2024-09-10 06:55:50.402763+03', 4203, NULL, NULL, 'nochomo', NULL, NULL, 1071),
	(3575, 'Instrument Returned', '2024-09-10 06:55:53.955428+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
	(3576, 'Instrument Returned', '2024-09-10 06:55:57.167488+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, 1071),
	(3577, 'Instrument Returned', '2024-09-10 06:56:01.88639+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, 1071),
	(3578, 'Instrument Out', '2024-10-07 13:42:28.397927+03', 1555, NULL, '574', 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;


--
-- TOC entry 4022 (class 0 OID 30968)
-- Dependencies: 245
-- Data for Name: instrument_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.instrument_requests (id, created_at, user_id, instrument, quantity, status, success, unique_id, notes, attended_by, attended_by_id, instruments_granted, resolved_at) VALUES
	(89, '2024-06-27 11:05:15.277823+03', 1071, 'DUMMY 1', 1, 'Resolved', 'Yes', '1071978124410', 'Your Instruments are ready for collection', 'Noah Ochomo', 1071, '{2129}', '2024-06-27 11:05:32.570862+03'),
	(84, '2024-06-24 15:31:55.164114+03', 1071, 'DUMMY 1', 1, 'Resolved', 'Yes', '1071841385837', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{4165}', '2024-06-26 16:29:16.519168+03'),
	(86, '2024-06-26 16:45:12.770025+03', 1071, 'DUMMY 1', 1, 'Resolved', 'Yes', '1071722473459', 'Your Instruments are ready for collection', 'Noah Ochomo', 1071, '{4209}', '2024-06-26 16:46:18.349081+03'),
	(90, '2024-06-27 11:05:46.592464+03', 1071, 'DUMMY 1', 1, NULL, NULL, '1071762444127', 'Nothing', 'Noah Ochomo', 1071, NULL, '2024-06-27 11:06:04.622533+03'),
	(85, '2024-06-26 16:45:02.046396+03', 1071, 'DUMMY 1', 5, 'Resolved', 'Partial', '1071900930881', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{4166,4203}', '2024-06-26 16:46:36.004988+03'),
	(87, '2024-06-27 10:53:33.692729+03', 1071, 'DUMMY 1', 1, NULL, NULL, '1071425147725', 'NOthing to do here', 'Noah Ochomo', 1071, NULL, '2024-06-27 10:54:40.382754+03'),
	(91, '2024-06-27 11:16:56.873558+03', 1071, 'DUMMY 1', 1, 'Pending', NULL, '107133266178', NULL, NULL, NULL, NULL, NULL),
	(88, '2024-06-27 11:01:36.298947+03', 1071, 'DUMMY 1', 1, 'Resolved', 'Yes', '1071100015438', 'Your Instruments are ready for collection', 'Noah Ochomo', 1071, '{4164}', '2024-06-27 11:04:26.478884+03') ON CONFLICT DO NOTHING;


--
-- TOC entry 4017 (class 0 OID 30919)
-- Dependencies: 237
-- Data for Name: instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.instruments (id, legacy_number, code, description, serial, state, location, make, model, legacy_code, number, user_name, user_id, issued_on) VALUES
	(1734, 216, NULL, 'STAND, GUITAR', NULL, 'Good', 'HS MUSIC', 'UNKNOWN', NULL, NULL, 1, NULL, NULL, NULL),
	(1774, 589, 'SXA', 'SAXOPHONE, ALTO', '11110739', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 24, NULL, NULL, NULL),
	(1773, 519, 'FL', 'FLUTE', '28411028', 'Good', 'INSTRUMENT STORE', 'PRELUDE', NULL, 'FL', 24, NULL, NULL, NULL),
	(1791, 302, 'TBN', 'TUBANOS', NULL, 'Good', 'MS MUSIC', 'REMO', '14 inch', NULL, 4, NULL, NULL, NULL),
	(1804, 566, 'SXA', 'SAXOPHONE, ALTO', '11120071', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 1, NULL, NULL, NULL),
	(1811, 287, 'SR', 'SNARE', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 3, NULL, NULL, NULL),
	(1813, 207, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 7, NULL, NULL, NULL),
	(1821, 631, 'SXA', 'SAXOPHONE, ALTO', 'BF54273', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 62, NULL, NULL, NULL),
	(1829, 626, 'SXA', 'SAXOPHONE, ALTO', 'AF53354', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 57, NULL, NULL, NULL),
	(1832, 627, 'SXA', 'SAXOPHONE, ALTO', 'AF53345', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 58, NULL, NULL, NULL),
	(1835, 630, 'SXA', 'SAXOPHONE, ALTO', 'BF54625', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 61, NULL, NULL, NULL),
	(1837, 637, 'SXA', 'SAXOPHONE, ALTO', 'CF57292', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 68, NULL, NULL, NULL),
	(1838, 638, 'SXA', 'SAXOPHONE, ALTO', 'CF57202', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 69, NULL, NULL, NULL),
	(1839, 639, 'SXA', 'SAXOPHONE, ALTO', 'CF56658', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 70, NULL, NULL, NULL),
	(1782, 78, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 46, NULL, NULL, NULL),
	(1784, 79, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 47, NULL, NULL, NULL),
	(1789, 80, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 48, NULL, NULL, NULL),
	(1792, 56, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 24, NULL, NULL, NULL),
	(1793, 36, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 4, NULL, NULL, NULL),
	(1799, 37, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 5, NULL, NULL, NULL),
	(1801, 33, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 1, NULL, NULL, NULL),
	(1840, 238, 'CLV', 'CLAVES', NULL, 'Good', 'MS MUSIC', 'LP', 'GRENADILLA', NULL, 2, NULL, NULL, NULL),
	(1841, 251, 'CWB', 'COWBELL', NULL, 'Good', 'MS MUSIC', 'LP', 'Black Beauty', NULL, 2, NULL, NULL, NULL),
	(1808, 657, 'SXT', 'SAXOPHONE, TENOR', 'TS10050022', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'TX', 13, NULL, NULL, NULL),
	(1781, 525, 'FL', 'FLUTE', 'D1206510', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 30, NULL, NULL, NULL),
	(1815, 647, 'SXT', 'SAXOPHONE, TENOR', '31840', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TX', 3, NULL, NULL, NULL),
	(1775, 25, 'TN', 'TROMBONE, TENOR', '452363', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TB', 11, NULL, NULL, NULL),
	(1776, 27, 'TN', 'TROMBONE, TENOR', '9120158', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'TB', 13, NULL, NULL, NULL),
	(1777, 28, 'TN', 'TROMBONE, TENOR', '9120243', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'TB', 14, NULL, NULL, NULL),
	(1783, 159, 'TP', 'TRUMPET, B FLAT', 'CAS15598', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 70, NULL, NULL, NULL),
	(1794, 490, 'FL', 'FLUTE', '2922376', 'Good', 'INSTRUMENT STORE', 'WT.AMSTRONG', '104', 'FL', 7, NULL, NULL, NULL),
	(1796, 13, 'M', 'MELLOPHONE', 'L02630', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'M', 1, NULL, NULL, NULL),
	(1802, 562, 'OB', 'OBOE', 'B33327', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'OB', 1, NULL, NULL, NULL),
	(1803, 564, 'PC', 'PICCOLO', '11010007', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'PC', 1, NULL, NULL, NULL),
	(1778, 29, 'TN', 'TROMBONE, TENOR', '9120157', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'TB', 15, NULL, NULL, NULL),
	(1779, 30, 'TN', 'TROMBONE, TENOR', '1107197', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TB', 16, NULL, NULL, NULL),
	(1780, 31, 'TN', 'TROMBONE, TENOR', '1107273', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TB', 17, NULL, NULL, NULL),
	(1735, 226, 'BLT', 'BELLS, TUBULAR', NULL, 'Good', 'HS MUSIC', 'ROSS', NULL, NULL, 1, NULL, NULL, NULL),
	(1909, 582, 'SXA', 'SAXOPHONE, ALTO', '388666A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 17, NULL, NULL, NULL),
	(1910, 583, 'SXA', 'SAXOPHONE, ALTO', 'T14584', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YAS 23', 'AX', 18, NULL, NULL, NULL),
	(1845, 293, 'TR', 'TAMBOURINE', NULL, 'Good', 'MS MUSIC', 'REMO', 'Fiberskyn 3 black', NULL, 2, NULL, NULL, NULL),
	(1846, 199, 'PU', 'PIANO, UPRIGHT', NULL, 'Good', 'PRACTICE ROOM 2', 'EAVESTAFF', NULL, NULL, 2, NULL, NULL, NULL),
	(1847, 200, 'PU', 'PIANO, UPRIGHT', NULL, 'Good', 'PRACTICE ROOM 3', 'SPENCER', NULL, NULL, 3, NULL, NULL, NULL),
	(1849, 272, 'Q', 'QUAD, MARCHING', '202902', 'Good', 'MS MUSIC', 'PEARL', 'Black', NULL, 1, NULL, NULL, NULL),
	(1850, 385, 'GRT', 'GUITAR, HALF', '11', 'Good', NULL, 'KAY', NULL, NULL, 1, NULL, NULL, NULL),
	(1851, 387, 'GRT', 'GUITAR, HALF', '9', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 3, NULL, NULL, NULL),
	(1852, 267, 'EGS', 'EGG SHAKERS', NULL, 'Good', 'MS MUSIC', 'LP', 'Black 2 pr', NULL, 2, NULL, NULL, NULL),
	(1853, 271, 'MRC', 'MARACAS', NULL, 'Good', 'MS MUSIC', 'LP', 'Pro Yellow Light Handle', NULL, 2, NULL, NULL, NULL),
	(1854, 210, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 10, NULL, NULL, NULL),
	(1855, 211, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 11, NULL, NULL, NULL),
	(2029, 574, 'SXA', 'SAXOPHONE, ALTO', '348075', 'Good', NULL, 'YAMAHA', NULL, 'AX', 9, 'Mwende Mittelstadt', 192, NULL),
	(1927, 579, 'SXA', 'SAXOPHONE, ALTO', '290365', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 14, NULL, NULL, NULL),
	(1858, 306, 'WB', 'WOOD BLOCK', NULL, 'Good', 'HS MUSIC', 'BLACK SWAMP', 'BLA-MWB1', NULL, 1, NULL, NULL, NULL),
	(1812, 206, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 6, NULL, NULL, NULL),
	(1859, 166, 'AM', 'AMPLIFIER', '72168', 'Good', 'MS MUSIC', 'GALLEN-K', NULL, NULL, 2, NULL, NULL, NULL),
	(1860, 317, 'CMS', 'CYMBAL, SUSPENDED 18 INCH', 'AD 69101 046', 'Good', 'HS MUSIC', 'ZILDJIAN', 'Orchestral Selection ZIL-A0419', NULL, 1, NULL, NULL, NULL),
	(1862, 348, 'GRB', 'GUITAR, BASS', 'CGF1307326', 'Good', 'DRUM ROOM 1', 'FENDER', NULL, NULL, 5, NULL, NULL, NULL),
	(1863, 388, 'GRT', 'GUITAR, HALF', '4', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 4, NULL, NULL, NULL),
	(1864, 168, 'AMB', 'AMPLIFIER, BASS', 'M 1053205', 'Good', 'DRUM ROOM 1', 'FENDER', 'BASSMAN', NULL, 4, NULL, NULL, NULL),
	(1866, 393, 'GRT', 'GUITAR, HALF', '8', 'Good', NULL, 'KAY', NULL, NULL, 9, NULL, NULL, NULL),
	(1867, 247, 'CG', 'CONGA', 'ISK 3120157238', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '12 inch', NULL, 4, NULL, NULL, NULL),
	(1868, 248, 'CG', 'CONGA', 'ISK 23 JAN 02', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '14 Inch', NULL, 5, NULL, NULL, NULL),
	(1869, 244, 'CG', 'CONGA', 'ISK 3120138881', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '10 Inch', NULL, 3, NULL, NULL, NULL),
	(1870, 249, 'CG', 'CONGA', 'ISK 312138881', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '10 Inch', NULL, 6, NULL, NULL, NULL),
	(1871, 250, 'CG', 'CONGA', 'ISK 312120138881', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '10 Inch', NULL, 7, NULL, NULL, NULL),
	(1865, 46, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'MS MUSIC', 'TROMBA', 'Pro', 'PTB', 14, NULL, NULL, NULL),
	(1875, 183, 'KB', 'KEYBOARD', 'AH24202', 'Good', NULL, 'ROLAND', '813', NULL, 1, NULL, NULL, NULL),
	(1883, 264, 'DK', 'DRUMSET', NULL, 'Good', 'MS MUSIC', 'PEARL', 'Vision', NULL, 3, NULL, NULL, NULL),
	(1884, 325, 'SR', 'SNARE', NULL, 'Good', 'UPPER ES MUSIC', 'PEARL', NULL, NULL, 4, NULL, NULL, NULL),
	(1887, 205, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 5, NULL, NULL, NULL),
	(1888, 274, 'SRM', 'SNARE, MARCHING', '1P-3095', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 1, NULL, NULL, NULL),
	(1993, 665, 'SXT', 'SAXOPHONE, TENOR', 'CF07553', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTS700', 'TX', 21, NULL, NULL, NULL),
	(1890, 22, 'TN', 'TROMBONE, TENOR', '320963', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'TB', 8, NULL, NULL, NULL),
	(1881, 39, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM17120413', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 7, NULL, NULL, NULL),
	(1807, 653, 'SXT', 'SAXOPHONE, TENOR', 'N495304', 'Good', 'INSTRUMENT STORE', 'SELMER', NULL, 'TX', 20, NULL, NULL, NULL),
	(1882, 41, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM17120388', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 9, NULL, NULL, NULL),
	(1889, 164, 'SSP', 'SOUSAPHONE', '910530', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'T', 1, NULL, NULL, NULL),
	(1912, 241, 'SRC', 'SNARE, CONCERT', NULL, 'Good', 'HS MUSIC', 'BLACK SWAMP', 'BLA-CM514BL', NULL, 1, NULL, NULL, NULL),
	(1913, 297, 'TPT', 'TIMPANI, 23 INCH', '52479', 'Good', 'HS MUSIC', 'LUDWIG', 'LKS423FG', NULL, 6, NULL, NULL, NULL),
	(1914, 282, NULL, 'SHIELD', NULL, 'Good', 'HS MUSIC', 'GIBRALTAR', 'GIB-GDS-5', NULL, 1, NULL, NULL, NULL),
	(1917, 280, 'PK', 'PRACTICE KIT', NULL, 'Good', 'UPPER ES MUSIC', 'PEARL', NULL, NULL, 1, NULL, NULL, NULL),
	(1919, 261, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 6, NULL, NULL, NULL),
	(1920, 259, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 4, NULL, NULL, NULL),
	(1921, 224, 'RK', 'RAINSTICK', NULL, 'Good', 'UPPER ES MUSIC', 'CUSTOM', NULL, NULL, 3, NULL, NULL, NULL),
	(1805, 417, 'CL', 'CLARINET, B FLAT', '989832', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'CL', 9, NULL, NULL, NULL),
	(1810, 107, 'TP', 'TRUMPET, B FLAT', 'H34971', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 27, NULL, NULL, NULL),
	(1816, 413, 'CL', 'CLARINET, B FLAT', '7943', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 6, NULL, NULL, NULL),
	(1817, 432, 'CL', 'CLARINET, B FLAT', '444451', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 24, NULL, NULL, NULL),
	(1820, 556, 'FL', 'FLUTE', 'BD62736', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 62, NULL, NULL, NULL),
	(1822, 471, 'CL', 'CLARINET, B FLAT', 'YE67775', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 63, NULL, NULL, NULL),
	(1823, 472, 'CL', 'CLARINET, B FLAT', 'YE67468', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 64, NULL, NULL, NULL),
	(1824, 476, 'CL', 'CLARINET, B FLAT', 'BE63558', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 68, NULL, NULL, NULL),
	(1825, 462, 'CL', 'CLARINET, B FLAT', 'XE50000', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 54, NULL, NULL, NULL),
	(1826, 549, 'FL', 'FLUTE', 'YD66218', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 55, NULL, NULL, NULL),
	(1827, 550, 'FL', 'FLUTE', 'YD66291', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 56, NULL, NULL, NULL),
	(1828, 465, 'CL', 'CLARINET, B FLAT', 'XE54699', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 57, NULL, NULL, NULL),
	(1830, 466, 'CL', 'CLARINET, B FLAT', 'XE54697', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 58, NULL, NULL, NULL),
	(1831, 552, 'FL', 'FLUTE', 'BD62678', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 58, NULL, NULL, NULL),
	(1922, 331, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 3, NULL, NULL, NULL),
	(1834, 554, 'FL', 'FLUTE', 'BD63433', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 60, NULL, NULL, NULL),
	(1737, 576, 'SXA', 'SAXOPHONE, ALTO', '3468', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'AX', 11, NULL, NULL, NULL),
	(2098, 62, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 30, NULL, NULL, NULL),
	(1530, 315, 'BL', 'BELL SET', NULL, 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 4, NULL, NULL, NULL),
	(1886, 204, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 4, NULL, NULL, NULL),
	(1929, 223, 'RK', 'RAINSTICK', NULL, 'Good', 'UPPER ES MUSIC', 'CUSTOM', NULL, NULL, 2, NULL, NULL, NULL),
	(1930, 330, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 2, NULL, NULL, NULL),
	(1491, 273, 'Q', 'QUAD, MARCHING', '203143', 'Good', 'MS MUSIC', 'PEARL', 'Black', NULL, 2, NULL, NULL, NULL),
	(1492, 276, 'SRM', 'SNARE, MARCHING', NULL, 'Good', 'MS MUSIC', 'VERVE', 'White', NULL, 3, NULL, NULL, NULL),
	(1493, 277, 'SRM', 'SNARE, MARCHING', NULL, 'Good', 'MS MUSIC', 'VERVE', 'White', NULL, 4, NULL, NULL, NULL),
	(1495, 75, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 43, NULL, NULL, NULL),
	(1497, 76, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 44, NULL, NULL, NULL),
	(1504, 77, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 45, NULL, NULL, NULL),
	(1506, 48, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 16, NULL, NULL, NULL),
	(1507, 51, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 19, NULL, NULL, NULL),
	(1980, 52, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'HS MUSIC', 'KAIZER', NULL, 'PTB', 20, NULL, NULL, NULL),
	(1981, 53, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'HS MUSIC', 'KAIZER', NULL, 'PTB', 21, NULL, NULL, NULL),
	(1932, 333, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 5, NULL, NULL, NULL),
	(1933, 334, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 6, NULL, NULL, NULL),
	(1934, 335, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 7, NULL, NULL, NULL),
	(1936, 399, 'VN', 'VIOLIN', 'V2024618', 'Good', 'HS MUSIC', 'ANDREAS EASTMAN', NULL, NULL, 4, NULL, NULL, NULL),
	(1937, 298, 'TPD', 'TIMPANI, 26 INCH', '51734', 'Good', 'HS MUSIC', 'LUDWIG', 'SUD-LKS426FG', NULL, 2, NULL, NULL, NULL),
	(1938, 400, 'VN', 'VIOLIN', 'V2025159', 'Good', 'HS MUSIC', 'ANDREAS EASTMAN', NULL, NULL, 5, NULL, NULL, NULL),
	(1939, 326, 'TPN', 'TIMPANI, 29 INCH', '36346', 'Good', 'HS MUSIC', 'LUDWIG', NULL, NULL, 5, NULL, NULL, NULL),
	(1940, 172, 'AMG', 'AMPLIFIER, GUITAR', 'ICTB1500267', 'Good', 'HS MUSIC', 'FENDER', 'Frontman 15G', NULL, 7, NULL, NULL, NULL),
	(1941, 232, NULL, 'MOUNTING BRACKET, BELL TREE', NULL, 'Good', 'HS MUSIC', 'TREEWORKS', 'TW-TRE52', NULL, 1, NULL, NULL, NULL),
	(1942, 327, 'TPW', 'TIMPANI, 32 INCH', '36301', 'Good', 'HS MUSIC', 'LUDWIG', NULL, NULL, 4, NULL, NULL, NULL),
	(1944, 222, 'RK', 'RAINSTICK', NULL, 'Good', 'UPPER ES MUSIC', 'CUSTOM', NULL, NULL, 1, NULL, NULL, NULL),
	(1945, 329, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 1, NULL, NULL, NULL),
	(1947, 165, 'AM', 'AMPLIFIER', 'M 1134340', 'Good', 'HS MUSIC', 'FENDER', NULL, NULL, 1, NULL, NULL, NULL),
	(1948, 229, 'BD', 'BASS DRUM', '3442181', 'Good', 'HS MUSIC', 'LUDWIG', NULL, NULL, 1, NULL, NULL, NULL),
	(1949, 311, 'X', 'XYLOPHONE', NULL, 'Good', 'HS MUSIC', 'DII', 'Decator', NULL, 18, NULL, NULL, NULL),
	(1960, 20, 'TN', 'TROMBONE, TENOR', '071009A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 6, NULL, NULL, NULL),
	(1953, 328, 'X', 'XYLOPHONE', '660845710719', 'Good', 'HS MUSIC', 'UNKNOWN', NULL, NULL, 19, NULL, NULL, NULL),
	(1955, 233, 'CBS', 'CABASA', NULL, 'Good', 'HS MUSIC', 'LP', 'LP234A', NULL, 1, NULL, NULL, NULL),
	(1956, 268, 'GUR', 'GUIRO', NULL, 'Good', 'HS MUSIC', 'LP', 'Super LP243', NULL, 1, NULL, NULL, NULL),
	(1957, 231, 'BLR', 'BELL TREE', NULL, 'Good', 'HS MUSIC', 'TREEWORKS', 'TW-TRE35', NULL, 1, NULL, NULL, NULL),
	(1958, 270, 'MRC', 'MARACAS', NULL, 'Good', 'HS MUSIC', 'WEISS', NULL, NULL, 1, NULL, NULL, NULL),
	(1961, 300, 'TGL', 'TRIANGLE', NULL, 'Good', 'HS MUSIC', 'ALAN ABEL', '6" Inch Symphonic', NULL, 1, NULL, NULL, NULL),
	(1962, 236, 'CLV', 'CLAVES', NULL, 'Good', 'HS MUSIC', 'LP', 'GRENADILLA', NULL, 3, NULL, NULL, NULL),
	(1963, 368, 'GRC', 'GUITAR, CLASSICAL', 'HKPO64008', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 12, NULL, NULL, NULL),
	(1964, 369, 'GRC', 'GUITAR, CLASSICAL', 'HKP054554', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 13, NULL, NULL, NULL),
	(1733, 611, 'SXA', 'SAXOPHONE, ALTO', 'XF53790', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 42, NULL, NULL, NULL),
	(1926, 169, 'AMB', 'AMPLIFIER, BASS', 'AX78271', 'Good', 'INSTRUMENT STORE', 'ROLAND', 'CUBE-100', NULL, 5, NULL, NULL, NULL),
	(1928, 227, 'VS', 'VIBRASLAP', NULL, 'Good', 'INSTRUMENT STORE', 'WEISS', 'SW-VIBRA', NULL, 1, NULL, NULL, NULL),
	(1971, 220, 'CWB', 'COWBELL', NULL, 'Good', 'INSTRUMENT STORE', 'LP', 'Black Beauty', NULL, 1, NULL, NULL, NULL),
	(1954, 179, NULL, 'MICROPHONE', NULL, 'Good', 'INSTRUMENT STORE', 'SHURE', 'SM58', NULL, 1, NULL, NULL, NULL),
	(1972, 337, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 9, NULL, NULL, NULL),
	(1973, 338, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 10, NULL, NULL, NULL),
	(1974, 339, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 11, NULL, NULL, NULL),
	(1975, 340, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 12, NULL, NULL, NULL),
	(1976, 341, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 13, NULL, NULL, NULL),
	(1977, 342, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 14, NULL, NULL, NULL),
	(1935, 167, 'AMB', 'AMPLIFIER, BASS', 'ICTB15016929', 'Good', 'HS MUSIC', 'FENDER', 'Rumble 25', NULL, 3, NULL, NULL, NULL),
	(1979, 343, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 15, NULL, NULL, NULL),
	(1836, 470, 'CL', 'CLARINET, B FLAT', 'YE67470', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 62, NULL, NULL, NULL),
	(1843, 146, 'TP', 'TRUMPET, B FLAT', 'XA04125', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 57, NULL, NULL, NULL),
	(2073, 446, 'CL', 'CLARINET, B FLAT', 'J65493', 'Good', NULL, 'YAMAHA', NULL, 'CL', 38, 'Vashnie Joymungul', 1032, NULL),
	(1946, 336, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 8, NULL, NULL, NULL),
	(1984, 307, 'WB', 'WOOD BLOCK', NULL, 'Good', 'MS MUSIC', 'LP', 'PLASTIC RED', NULL, 2, NULL, NULL, NULL),
	(1985, 380, 'GRE', 'GUITAR, ELECTRIC', '115085004', 'Good', 'HS MUSIC', 'FENDER', 'CD-60CE Mahogany', NULL, 26, NULL, NULL, NULL),
	(1986, 308, 'WB', 'WOOD BLOCK', NULL, 'Good', 'MS MUSIC', 'LP', 'PLASTIC BLUE', NULL, 3, NULL, NULL, NULL),
	(1987, 269, 'GUR', 'GUIRO', NULL, 'Good', 'MS MUSIC', 'LP', 'Plastic', NULL, 2, NULL, NULL, NULL),
	(1988, 310, 'X', 'XYLOPHONE', '587', 'Good', 'MS MUSIC', 'ROSS', '410', NULL, 17, NULL, NULL, NULL),
	(1992, 373, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'MS MUSIC', 'PARADISE', '19', NULL, 19, NULL, NULL, NULL),
	(1998, 390, 'GRT', 'GUITAR, HALF', '3', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 6, NULL, NULL, NULL),
	(2000, 382, 'GRE', 'GUITAR, ELECTRIC', '115085034', 'Good', NULL, 'FENDER', 'CD-60CE Mahogany', NULL, 25, NULL, NULL, NULL),
	(2001, 266, 'DKE', 'DRUMSET, ELECTRIC', '694318011177', 'Good', 'DRUM ROOM 2', 'ALESIS', 'DM8', NULL, 5, NULL, NULL, NULL),
	(2026, 578, 'SXA', 'SAXOPHONE, ALTO', '352128A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 13, NULL, NULL, NULL),
	(2003, 197, 'PG', 'PIANO, GRAND', '302697', 'Good', 'PIANO ROOM', 'GEBR. PERZINO', 'GBT 175', NULL, 1, NULL, NULL, NULL),
	(2004, 198, 'PU', 'PIANO, UPRIGHT', NULL, 'Good', 'PRACTICE ROOM 1', 'ELSENBERG', NULL, NULL, 1, NULL, NULL, NULL),
	(2005, 391, 'GRT', 'GUITAR, HALF', '1', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 7, NULL, NULL, NULL),
	(2007, 392, 'GRT', 'GUITAR, HALF', '12', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 8, NULL, NULL, NULL),
	(2008, 395, 'GRT', 'GUITAR, HALF', '6', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 11, NULL, NULL, NULL),
	(2009, 228, 'AGG', 'AGOGO BELL', NULL, 'Good', 'MS MUSIC', 'LP', '577 Dry', NULL, 1, NULL, NULL, NULL),
	(2010, 292, 'TR', 'TAMBOURINE', NULL, 'Good', 'MS MUSIC', 'MEINL', 'Open face', NULL, 1, NULL, NULL, NULL),
	(2011, 323, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 6, NULL, NULL, NULL),
	(2012, 318, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 1, NULL, NULL, NULL),
	(2013, 284, 'BLS', 'BELLS, SLEIGH', NULL, 'Good', 'MS MUSIC', 'LUDWIG', 'Red Handle', NULL, 2, NULL, NULL, NULL),
	(2015, 218, NULL, 'STAND, MUSIC', NULL, 'Good', 'MS MUSIC', 'GMS', NULL, NULL, 2, NULL, NULL, NULL),
	(2017, 301, 'TGL', 'TRIANGLE', NULL, 'Good', 'MS MUSIC', 'ALAN ABEL', '6 inch', NULL, 2, NULL, NULL, NULL),
	(2018, 234, 'CBS', 'CABASA', NULL, 'Good', 'MS MUSIC', 'LP', 'Small', NULL, 2, NULL, NULL, NULL),
	(2019, 202, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 2, NULL, NULL, NULL),
	(2020, 237, 'CLV', 'CLAVES', NULL, 'Good', 'MS MUSIC', 'KING', NULL, NULL, 1, NULL, NULL, NULL),
	(2021, 376, 'GRC', 'GUITAR, CLASSICAL', '265931HRJ', 'Good', 'INSTRUMENT STORE', 'YAMAHA', '40', NULL, 28, NULL, NULL, NULL),
	(1982, 58, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'HS MUSIC', 'KAIZER', NULL, 'PTB', 26, NULL, NULL, NULL),
	(2023, 362, 'GRC', 'GUITAR, CLASSICAL', 'HKPO065675', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 6, NULL, NULL, NULL),
	(2002, 15, 'TN', 'TROMBONE, TENOR', '970406', 'Good', 'MS MUSIC', 'HOLTON', 'TR259', 'TB', 1, NULL, NULL, NULL),
	(2030, 191, 'PE', 'PIANO, ELECTRIC', 'YCQM01249', 'Good', 'MS MUSIC', 'YAMAHA', 'CAP 320', NULL, 4, NULL, NULL, NULL),
	(2027, 19, 'TN', 'TROMBONE, TENOR', '334792', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 5, NULL, NULL, NULL),
	(2033, 481, 'CLB', 'CLARINET, BASS', '43084', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'BCL', 3, NULL, NULL, NULL),
	(2035, 190, 'PE', 'PIANO, ELECTRIC', '7163', 'Good', 'MUSIC OFFICE', 'YAMAHA', 'CVP 87A', NULL, 3, NULL, NULL, NULL),
	(2036, 366, 'GRC', 'GUITAR, CLASSICAL', 'HKP064183', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 10, NULL, NULL, NULL),
	(2037, 357, 'GRC', 'GUITAR, CLASSICAL', 'HKZ107832', 'Good', NULL, 'YAMAHA', '40', NULL, 1, NULL, NULL, NULL),
	(2038, 358, 'GRC', 'GUITAR, CLASSICAL', 'HKZ034412', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 2, NULL, NULL, NULL),
	(2039, 359, 'GRC', 'GUITAR, CLASSICAL', 'HKP065151', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 3, NULL, NULL, NULL),
	(1857, 81, 'TP', 'TRUMPET, B FLAT', '808845', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 1, NULL, NULL, NULL),
	(1874, 415, 'CL', 'CLARINET, B FLAT', 'B 859866/7112-STORE', 'Good', NULL, 'VITO', NULL, 'CL', 7, NULL, NULL, NULL),
	(1893, 488, 'FL', 'FLUTE', '452046A', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'FL', 5, NULL, NULL, NULL),
	(1896, 89, 'TP', 'TRUMPET, B FLAT', '556519', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 9, NULL, NULL, NULL),
	(1897, 532, 'FL', 'FLUTE', 'AP28041129', 'Good', NULL, 'PRELUDE', NULL, 'FL', 37, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.instruments (id, legacy_number, code, description, serial, state, location, make, model, legacy_code, number, user_name, user_id, issued_on) VALUES
	(1903, 95, 'TP', 'TRUMPET, B FLAT', '634070', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 15, NULL, NULL, NULL),
	(1904, 110, 'TP', 'TRUMPET, B FLAT', '501720', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 30, NULL, NULL, NULL),
	(1911, 428, 'CL', 'CLARINET, B FLAT', 'J65540', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 20, NULL, NULL, NULL),
	(1916, 112, 'TP', 'TRUMPET, B FLAT', '638850', 'Good', 'MS MUSIC', 'YAMAHA', 'YTR 2335', 'TP', 32, NULL, NULL, NULL),
	(1736, 416, 'CL', 'CLARINET, B FLAT', '504869', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'CL', 8, NULL, NULL, NULL),
	(1498, 97, 'TP', 'TRUMPET, B FLAT', 'S-756323', 'Good', 'INSTRUMENT STORE', 'CONN', NULL, 'TP', 17, NULL, NULL, NULL),
	(1499, 98, 'TP', 'TRUMPET, B FLAT', 'H35537', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BTR 1270', 'TP', 18, NULL, NULL, NULL),
	(1500, 102, 'TP', 'TRUMPET, B FLAT', 'H34929', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BIR 1270', 'TP', 22, NULL, NULL, NULL),
	(1501, 104, 'TP', 'TRUMPET, B FLAT', 'H32053', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BIR 1270', 'TP', 24, NULL, NULL, NULL),
	(1502, 105, 'TP', 'TRUMPET, B FLAT', 'H31491', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BIR 1270', 'TP', 25, NULL, NULL, NULL),
	(1503, 108, 'TP', 'TRUMPET, B FLAT', 'F24304', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 28, NULL, NULL, NULL),
	(1505, 133, 'TP', 'TRUMPET, B FLAT', 'XA07789', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 44, NULL, NULL, NULL),
	(2014, 279, 'TTM', 'TOM, MARCHING', '6 PAIRS', 'Good', 'INSTRUMENT STORE', 'PEARL', NULL, NULL, 1, NULL, NULL, NULL),
	(2016, 305, 'WC', 'WIND CHIMES', NULL, 'Good', 'INSTRUMENT STORE', 'LP', 'LP236D', NULL, 1, NULL, NULL, NULL),
	(2055, 49, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PR18100094', 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 17, NULL, NULL, NULL),
	(1785, 557, 'FL', 'FLUTE', 'DD58225', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JFL 700', 'FL', 63, NULL, NULL, NULL),
	(2040, 421, 'CL', 'CLARINET, B FLAT', '27303', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 13, NULL, NULL, NULL),
	(2120, 409, 'CL', 'CLARINET, B FLAT', '7988', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'CL', 4, NULL, NULL, NULL),
	(1755, 441, 'CL', 'CLARINET, B FLAT', 'J65382', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'CL', 33, NULL, NULL, NULL),
	(1951, 429, 'CL', 'CLARINET, B FLAT', 'J65851', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 21, NULL, NULL, NULL),
	(1952, 442, 'CL', 'CLARINET, B FLAT', 'J65593', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 34, NULL, NULL, NULL),
	(1959, 443, 'CL', 'CLARINET, B FLAT', 'J65299', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 35, NULL, NULL, NULL),
	(1965, 499, 'FL', 'FLUTE', '617224', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'FL', 11, NULL, NULL, NULL),
	(2096, 580, 'SXA', 'SAXOPHONE, ALTO', '362547A', 'Good', NULL, 'YAMAHA', NULL, 'AX', 15, 'Caitlin Wood', 160, NULL),
	(1764, 575, 'SXA', 'SAXOPHONE, ALTO', '387824A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 10, NULL, NULL, NULL),
	(1766, 636, 'SXA', 'SAXOPHONE, ALTO', 'CF57086', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 67, NULL, NULL, NULL),
	(1966, 420, 'CL', 'CLARINET, B FLAT', '7980', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 12, NULL, NULL, NULL),
	(1967, 434, 'CL', 'CLARINET, B FLAT', 'B88822', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 26, NULL, NULL, NULL),
	(1978, 171, 'AMB', 'AMPLIFIER, BASS', 'OJBHE2300098', 'Good', 'HS MUSIC', 'PEAVEY', 'TKO-230EU', NULL, 11, NULL, NULL, NULL),
	(1968, 405, 'CL', 'CLARINET, B FLAT', '206603A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 2, NULL, NULL, NULL),
	(1969, 485, 'FL', 'FLUTE', '826706', 'Good', 'INSTRUMENT STORE', 'YAMAHA', '222', 'FL', 2, NULL, NULL, NULL),
	(2022, 6, 'BH', 'BARITONE/EUPHONIUM', '534386', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'BH', 7, NULL, NULL, NULL),
	(2025, 484, 'FL', 'FLUTE', '609368', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'FL', 1, NULL, NULL, NULL),
	(1494, 506, 'FL', 'FLUTE', 'K96338', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 15, NULL, NULL, NULL),
	(2032, 407, 'CL', 'CLARINET, B FLAT', '7291', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 3, NULL, NULL, NULL),
	(1739, 431, 'CL', 'CLARINET, B FLAT', '193026A', 'Good', NULL, 'YAMAHA', NULL, 'CL', 23, 'Fatuma Tall', 301, NULL),
	(1768, 489, 'FL', 'FLUTE', '42684', 'Good', 'INSTRUMENT STORE', 'EMERSON', 'EF1', 'FL', 6, NULL, NULL, NULL),
	(1742, 422, 'CL', 'CLARINET, B FLAT', '206167', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'CL', 14, NULL, NULL, NULL),
	(1763, 492, 'FL', 'FLUTE', '650122', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'FL', 8, NULL, NULL, NULL),
	(1765, 475, 'CL', 'CLARINET, B FLAT', 'BE63660', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 67, NULL, NULL, NULL),
	(1767, 502, 'FL', 'FLUTE', 'K96367', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 13, NULL, NULL, NULL),
	(1770, 518, 'FL', 'FLUTE', '33111112', 'Good', 'INSTRUMENT STORE', 'PRELUDE', NULL, 'FL', 23, NULL, NULL, NULL),
	(1786, 122, 'TP', 'TRUMPET, B FLAT', '124911', 'Good', NULL, 'ETUDE', NULL, 'TP', 38, 'Mark Anding', 1076, NULL),
	(1745, 254, NULL, 'STAND, CYMBAL', NULL, 'Good', 'HS MUSIC', 'GIBRALTAR', 'GIB-5710', NULL, 1, NULL, NULL, NULL),
	(1747, 296, 'TPT', 'TIMPANI, 23 INCH', '36264', 'Good', 'MS MUSIC', 'LUDWIG', 'LKS423FG', NULL, 1, NULL, NULL, NULL),
	(1748, 309, 'X', 'XYLOPHONE', '25', 'Good', 'MS MUSIC', 'MAJESTIC', 'x55 352', NULL, 16, NULL, NULL, NULL),
	(1749, 182, NULL, 'PA SYSTEM, ALL-IN-ONE', 'S1402186AA8', 'Good', 'HS MUSIC', 'BEHRINGER', 'EPS500MP3', NULL, 1, NULL, NULL, NULL),
	(1570, 96, 'TP', 'TRUMPET, B FLAT', '33911', 'Good', NULL, 'SCHILKE', 'B1L', 'TP', 16, 'Mark Anding', 1076, NULL),
	(1753, 209, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 9, NULL, NULL, NULL),
	(1758, 215, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 15, NULL, NULL, NULL),
	(1759, 203, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 3, NULL, NULL, NULL),
	(1760, 253, 'CMZ', 'CYMBALS, HANDHELD 18 INCH', 'ZIL-A0447', 'Good', 'HS MUSIC', 'ZILDJIAN', '18 Inch Symphonic Viennese Tone', NULL, 1, NULL, NULL, NULL),
	(1761, 378, 'GRW', 'GUITAR, CUTAWAY', NULL, 'Good', 'MS MUSIC', 'UNKNOWN', NULL, NULL, 15, NULL, NULL, NULL),
	(1762, 379, 'GRW', 'GUITAR, CUTAWAY', NULL, 'Good', 'MS MUSIC', 'UNKNOWN', NULL, NULL, 16, NULL, NULL, NULL),
	(1769, 304, 'TBN', 'TUBANOS', '1-7', 'Good', 'MS MUSIC', 'REMO', '12 inch', NULL, 7, NULL, NULL, NULL),
	(2064, 263, 'DK', 'DRUMSET', NULL, 'Good', 'DRUM ROOM 1', 'YAMAHA', NULL, NULL, 2, NULL, NULL, NULL),
	(2061, 361, 'GRC', 'GUITAR, CLASSICAL', 'HKZ114314', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 5, NULL, NULL, NULL),
	(2065, 324, 'DK', 'DRUMSET', NULL, 'Good', 'DRUM ROOM 2', 'YAMAHA', NULL, NULL, 6, NULL, NULL, NULL),
	(2066, 411, 'CL', 'CLARINET, B FLAT', '27251', 'Good', NULL, 'YAMAHA', NULL, 'CL', 5, 'Mark Anding', 1076, NULL),
	(1885, 398, 'VN', 'VIOLIN', 'D 0933 1998', 'Good', NULL, 'WILLIAM LEWIS & SON', NULL, NULL, 3, 'Gakenia Mucharie', 1075, NULL),
	(1771, 588, 'SXA', 'SAXOPHONE, ALTO', '11110695', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 23, NULL, NULL, NULL),
	(1877, 614, 'SXA', 'SAXOPHONE, ALTO', 'XF57089', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 45, 'Fatuma Tall', 301, NULL),
	(2059, 402, 'CLE', 'CLARINET, ALTO IN E FLAT', '1260', 'Good', NULL, 'YAMAHA', NULL, NULL, 1, 'Mark Anding', 1076, NULL),
	(1879, 634, 'SXA', 'SAXOPHONE, ALTO', 'BF54604', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 65, 'Ethan Sengendo', 393, NULL),
	(2056, 120, 'TP', 'TRUMPET, B FLAT', '124816', 'Good', NULL, 'ETUDE', NULL, 'TP', 37, 'Masoud Ibrahim', 787, NULL),
	(1743, 126, 'TP', 'TRUMPET, B FLAT', 'H35214', 'Good', NULL, 'BLESSING', NULL, 'TP', 40, 'Masoud Ibrahim', 787, NULL),
	(1588, 478, 'CL', 'CLARINET, B FLAT', 'BE63657', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 70, 'Gakenia Mucharie', 1075, NULL),
	(1514, 140, 'TP', 'TRUMPET, B FLAT', 'XA06017', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 51, NULL, NULL, NULL),
	(1772, 667, 'SXT', 'SAXOPHONE, TENOR', 'CF08026', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTS700', 'TX', 23, NULL, NULL, NULL),
	(1741, 32, 'TN', 'TROMBONE, TENOR', '646721', 'Good', NULL, 'YAMAHA', NULL, 'TB', 18, 'Andrew Wachira', 268, NULL),
	(1892, 24, 'TN', 'TROMBONE, TENOR', '316975', 'Good', NULL, 'YAMAHA', NULL, 'TB', 10, 'Margaret Oganda', 1078, NULL),
	(1527, 573, 'SXA', 'SAXOPHONE, ALTO', '200547', 'Good', 'INSTRUMENT STORE', 'GIARDINELLI', NULL, 'AX', 8, NULL, NULL, NULL),
	(1511, 137, 'TP', 'TRUMPET, B FLAT', 'XA08294', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 48, NULL, NULL, NULL),
	(1723, 312, 'BL', 'BELL SET', NULL, 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 1, NULL, NULL, NULL),
	(1534, 569, 'SXA', 'SAXOPHONE, ALTO', '11120109', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 4, NULL, NULL, NULL),
	(1512, 138, 'TP', 'TRUMPET, B FLAT', 'XA08319', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 49, NULL, NULL, NULL),
	(1725, 397, 'VN', 'VIOLIN', '3923725', 'Good', 'INSTRUMENT STORE', 'AUBERT', NULL, NULL, 2, NULL, NULL, NULL),
	(1548, 571, 'SXA', 'SAXOPHONE, ALTO', '12080618', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 6, NULL, NULL, NULL),
	(1580, 568, 'SXA', 'SAXOPHONE, ALTO', '11120090', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 3, NULL, NULL, NULL),
	(1602, 585, 'SXA', 'SAXOPHONE, ALTO', 'AS1003847', 'Good', 'INSTRUMENT STORE', 'BARRINGTON', NULL, 'AX', 20, NULL, NULL, NULL),
	(1726, 45, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 13, NULL, NULL, NULL),
	(1728, 34, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 2, NULL, NULL, NULL),
	(1549, 35, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 3, NULL, NULL, NULL),
	(1578, 584, 'SXA', 'SAXOPHONE, ALTO', 'AS1001039', 'Good', 'MS MUSIC', 'BARRINGTON', NULL, 'AX', 19, NULL, NULL, NULL),
	(1582, 180, NULL, 'MICROPHONE', NULL, 'Good', 'INSTRUMENT STORE', 'SHURE', 'SM58', NULL, 2, NULL, NULL, NULL),
	(1746, 468, 'CL', 'CLARINET, B FLAT', 'XE54704', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 60, NULL, NULL, NULL),
	(1787, 134, 'TP', 'TRUMPET, B FLAT', 'XA08653', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 45, NULL, NULL, NULL),
	(1878, 615, 'SXA', 'SAXOPHONE, ALTO', 'XF57192', 'Good', 'MS MUSIC', 'JUPITER', 'JAS 710', 'AX', 46, NULL, NULL, NULL),
	(1931, 332, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 4, NULL, NULL, NULL),
	(1579, 50, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PB17070322', 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 18, NULL, NULL, NULL),
	(1526, 645, 'SXT', 'SAXOPHONE, TENOR', '403557', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'TX', 1, NULL, NULL, NULL),
	(1528, 652, 'SXT', 'SAXOPHONE, TENOR', 'N4200829', 'Good', 'INSTRUMENT STORE', 'SELMER', NULL, 'TX', 8, NULL, NULL, NULL),
	(1532, 650, 'SXT', 'SAXOPHONE, TENOR', '310278', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'TX', 6, NULL, NULL, NULL),
	(1536, 659, 'SXT', 'SAXOPHONE, TENOR', '13120021', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TX', 15, NULL, NULL, NULL),
	(1724, 9, 'HNF', 'HORN, F', '619468', 'Good', 'INSTRUMENT STORE', 'HOLTON', 'H281', 'HN', 2, NULL, NULL, NULL),
	(1727, 480, 'CLB', 'CLARINET, BASS', 'Y3717', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'BCL', 2, NULL, NULL, NULL),
	(1861, 12, 'HNF', 'HORN, F', 'BC00278', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JHR1100', 'HN', 5, NULL, NULL, NULL),
	(1756, 444, 'CL', 'CLARINET, B FLAT', 'J65434', 'Good', NULL, 'YAMAHA', NULL, 'CL', 36, 'Anastasia Mulema', 979, '2024-06-04'),
	(1518, 640, 'SXB', 'SAXOPHONE, BARITONE', '1360873', 'Good', 'INSTRUMENT STORE', 'SELMER', NULL, 'BX', 1, NULL, NULL, NULL),
	(1540, 644, 'SXB', 'SAXOPHONE, BARITONE', 'CF05160', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JBS 1000', 'BX', 5, NULL, NULL, NULL),
	(1517, 163, 'TB', 'TUBA', NULL, 'Good', 'INSTRUMENT STORE', 'BOOSEY & HAWKES', 'Imperial EEb', 'T', 3, NULL, NULL, NULL),
	(1544, 303, 'TBN', 'TUBANOS', NULL, 'Good', 'MS MUSIC', 'REMO', '10 Inch', NULL, 5, NULL, NULL, NULL),
	(1555, 612, 'SXA', 'SAXOPHONE, ALTO', 'XF56514', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 43, 'Mila Jovanovic', 574, '2024-10-07'),
	(1551, 170, 'AMB', 'AMPLIFIER, BASS', 'Z9G3740', 'Good', 'MS MUSIC', 'ROLAND', 'Cube-120 XL', NULL, 6, NULL, NULL, NULL),
	(1552, 173, 'AMG', 'AMPLIFIER, GUITAR', 'M 1005297', 'Good', 'MS MUSIC', 'FENDER', 'STAGE 160', NULL, 8, NULL, NULL, NULL),
	(1559, 252, 'CMY', 'CYMBALS, HANDHELD 16 INCH', NULL, 'Good', 'HS MUSIC', 'SABIAN', 'SAB SR 16BOL', NULL, 1, NULL, NULL, NULL),
	(1581, 175, 'AMK', 'AMPLIFIER, KEYBOARD', 'OBD#1230164', 'Good', 'MS MUSIC', 'PEAVEY', 'KB4', NULL, 10, NULL, NULL, NULL),
	(1583, 184, 'KB', 'KEYBOARD', 'TCK 611', 'Good', 'HS MUSIC', 'CASIO', NULL, NULL, 2, NULL, NULL, NULL),
	(1584, 256, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 2, NULL, NULL, NULL),
	(1585, 258, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 3, NULL, NULL, NULL),
	(1586, 260, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 5, NULL, NULL, NULL),
	(1587, 255, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 1, NULL, NULL, NULL),
	(1589, 14, 'MTL', 'METALLOPHONE', NULL, 'Good', NULL, 'ORFF', NULL, NULL, 1, NULL, NULL, NULL),
	(1590, 187, 'KB', 'KEYBOARD', NULL, 'Good', NULL, 'CASIO', 'TC-360', NULL, 23, NULL, NULL, NULL),
	(1591, 217, NULL, 'STAND, MUSIC', '50052', 'Good', NULL, 'WENGER', NULL, NULL, 1, NULL, NULL, NULL),
	(1597, 176, 'AMG', 'AMPLIFIER, GUITAR', 'S190700059B4P', 'Good', NULL, 'BUGERA', NULL, NULL, 12, NULL, NULL, NULL),
	(1599, 320, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 3, NULL, NULL, NULL),
	(1600, 177, 'AMG', 'AMPLIFIER, GUITAR', 'B-749002', 'Good', NULL, 'FENDER', 'Blue Junior', NULL, 13, NULL, NULL, NULL),
	(1601, 351, 'GRA', 'GUITAR, ACOUSTIC', NULL, 'Good', NULL, 'UNKNOWN', NULL, NULL, 32, NULL, NULL, NULL),
	(1604, 322, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 5, NULL, NULL, NULL),
	(1513, 139, 'TP', 'TRUMPET, B FLAT', 'XA08322', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 50, NULL, NULL, NULL),
	(1515, 141, 'TP', 'TRUMPET, B FLAT', 'XA05452', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 52, NULL, NULL, NULL),
	(1605, 319, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 2, NULL, NULL, NULL),
	(1607, 291, 'SRM', 'SNARE, MARCHING', '1P-3086', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 6, NULL, NULL, NULL),
	(1609, 620, 'SXA', 'SAXOPHONE, ALTO', 'XF56962', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 51, NULL, NULL, NULL),
	(1612, 633, 'SXA', 'SAXOPHONE, ALTO', 'BF54617', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 64, NULL, NULL, NULL),
	(1638, 586, 'SXA', 'SAXOPHONE, ALTO', 'AS 1010089', 'Good', 'INSTRUMENT STORE', 'BARRINGTON', NULL, 'AX', 21, NULL, NULL, NULL),
	(1655, 607, 'SXA', 'SAXOPHONE, ALTO', 'XF54539', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 38, NULL, NULL, NULL),
	(1658, 609, 'SXA', 'SAXOPHONE, ALTO', 'XF54577', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 40, NULL, NULL, NULL),
	(1616, 212, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 12, NULL, NULL, NULL),
	(1617, 178, 'AMG', 'AMPLIFIER, GUITAR', 'LCB500-A126704', 'Good', NULL, 'FISHMAN', '494-000-582', NULL, 14, NULL, NULL, NULL),
	(1619, 286, 'SR', 'SNARE', NULL, 'Good', 'UPPER ES MUSIC', 'PEARL', NULL, NULL, 2, NULL, NULL, NULL),
	(1620, 181, 'MX', 'MIXER', 'BGXL01101', 'Good', 'MS MUSIC', 'YAMAHA', 'MG12XU', NULL, 15, NULL, NULL, NULL),
	(1622, 347, 'GRB', 'GUITAR, BASS', '15020198', 'Good', 'HS MUSIC', 'SQUIER', 'Modified Jaguar', NULL, 4, NULL, NULL, NULL),
	(1623, 240, NULL, 'CRADLE, CONCERT CYMBAL', NULL, 'Good', 'HS MUSIC', 'GIBRALTAR', 'GIB-7614', NULL, 1, NULL, NULL, NULL),
	(1631, 381, 'GRE', 'GUITAR, ELECTRIC', '15029891', 'Good', 'HS MUSIC', 'SQUIER', 'StratPkHSSCAR', NULL, 1, NULL, NULL, NULL),
	(1686, 577, 'SXA', 'SAXOPHONE, ALTO', '11120110', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 12, NULL, NULL, NULL),
	(1688, 590, 'SXA', 'SAXOPHONE, ALTO', '11110696', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 25, NULL, NULL, NULL),
	(1693, 591, 'SXA', 'SAXOPHONE, ALTO', '91145', 'Good', 'INSTRUMENT STORE', 'CONSERVETE', NULL, 'AX', 26, NULL, NULL, NULL),
	(1624, 54, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 22, NULL, NULL, NULL),
	(1625, 55, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 23, NULL, NULL, NULL),
	(1626, 63, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 31, NULL, NULL, NULL),
	(1627, 65, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 33, NULL, NULL, NULL),
	(1628, 67, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 35, NULL, NULL, NULL),
	(1664, 314, 'BL', 'BELL SET', NULL, 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 3, NULL, NULL, NULL),
	(1629, 69, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 37, NULL, NULL, NULL),
	(1630, 70, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 38, NULL, NULL, NULL),
	(1634, 71, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 39, NULL, NULL, NULL),
	(1635, 72, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 40, NULL, NULL, NULL),
	(1637, 73, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 41, NULL, NULL, NULL),
	(1682, 59, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 27, NULL, NULL, NULL),
	(1683, 354, 'GRA', 'GUITAR, ACOUSTIC', '00Y145219', 'Good', NULL, 'YAMAHA', 'F 325', NULL, 22, NULL, NULL, NULL),
	(1690, 245, 'CG', 'CONGA', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 24, NULL, NULL, NULL),
	(1691, 246, 'CG', 'CONGA', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 25, NULL, NULL, NULL),
	(1666, 201, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 1, NULL, NULL, NULL),
	(1685, 60, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 28, NULL, NULL, NULL),
	(1689, 61, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 29, NULL, NULL, NULL),
	(1695, 44, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 12, NULL, NULL, NULL),
	(1697, 221, 'PD', 'PRACTICE PAD', 'ISK NO.26', 'Good', 'UPPER ES MUSIC', 'YAMAHA', '4 INCH', NULL, 1, NULL, NULL, NULL),
	(1707, 355, 'GRA', 'GUITAR, ACOUSTIC', '00Y224899', 'Good', 'HS MUSIC', 'YAMAHA', 'F 325', NULL, 23, NULL, NULL, NULL),
	(1708, 356, 'GRA', 'GUITAR, ACOUSTIC', '00Y224741', 'Good', 'HS MUSIC', 'YAMAHA', 'F 325', NULL, 24, NULL, NULL, NULL),
	(1709, 194, 'PE', 'PIANO, ELECTRIC', 'BCAZ01088', 'Good', 'LOWER ES MUSIC', 'YAMAHA', 'CLP 7358', NULL, 9, NULL, NULL, NULL),
	(1711, 281, 'PD', 'PRACTICE PAD', NULL, 'Good', 'UPPER ES MUSIC', 'YAMAHA', '4 INCH', NULL, 2, NULL, NULL, NULL),
	(1675, 352, 'GRA', 'GUITAR, ACOUSTIC', '00Y224811', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'F 325', NULL, 19, NULL, NULL, NULL),
	(1615, 225, 'TDR', 'TALKING DRUM', NULL, 'Good', 'INSTRUMENT STORE', 'REMO', 'Small', NULL, 1, NULL, NULL, NULL),
	(1717, 375, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 27, NULL, NULL, NULL),
	(1684, 655, 'SXT', 'SAXOPHONE, TENOR', '420486', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'TX', 11, NULL, NULL, NULL),
	(1516, 142, 'TP', 'TRUMPET, B FLAT', 'XA06111', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 53, NULL, NULL, NULL),
	(1994, 602, 'SXA', 'SAXOPHONE, ALTO', 'XF54322', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 33, 'Noah Ochomo', 1071, NULL),
	(2058, 593, 'SXA', 'SAXOPHONE, ALTO', 'XF54181', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 28, 'Romilly Haysmith', 937, NULL),
	(2054, 661, 'SXT', 'SAXOPHONE, TENOR', 'XF03739', 'Good', NULL, 'JUPITER', NULL, 'TX', 17, 'Rohan Giri', 454, NULL),
	(2087, 162, 'TB', 'TUBA', '533558', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'T', 2, NULL, NULL, NULL),
	(1752, 208, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 8, NULL, NULL, NULL),
	(1732, 372, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'MS MUSIC', 'PARADISE', '18', NULL, 18, NULL, NULL, NULL),
	(2090, 195, 'PE', 'PIANO, ELECTRIC', 'BCZZ01016', 'Good', 'UPPER ES MUSIC', 'YAMAHA', 'CLP-645B', NULL, 7, NULL, NULL, NULL),
	(2079, 192, 'PE', 'PIANO, ELECTRIC', 'YCQN01006', 'Good', 'HS MUSIC', 'YAMAHA', 'CAP 329', NULL, 5, NULL, NULL, NULL),
	(2081, 193, 'PE', 'PIANO, ELECTRIC', 'EBQN02222', 'Good', 'HS MUSIC', 'YAMAHA', 'P-95', NULL, 6, NULL, NULL, NULL),
	(2082, 262, 'DK', 'DRUMSET', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 1, NULL, NULL, NULL),
	(2083, 239, 'BLC', 'BELLS, CONCERT', '112158', 'Good', 'HS MUSIC', 'YAMAHA', 'YG-250D Standard', NULL, 1, NULL, NULL, NULL),
	(2085, 289, 'SR', 'SNARE', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 27, NULL, NULL, NULL),
	(2086, 290, 'SR', 'SNARE', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 28, NULL, NULL, NULL),
	(1667, 213, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 13, NULL, NULL, NULL),
	(1519, 151, 'TP', 'TRUMPET, B FLAT', 'BA09236', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 62, NULL, NULL, NULL),
	(1520, 152, 'TP', 'TRUMPET, B FLAT', 'BA08359', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 63, NULL, NULL, NULL),
	(1521, 154, 'TP', 'TRUMPET, B FLAT', 'BA09193', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 65, NULL, NULL, NULL),
	(1523, 156, 'TP', 'TRUMPET, B FLAT', 'CA16033', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 67, NULL, NULL, NULL),
	(1524, 157, 'TP', 'TRUMPET, B FLAT', 'CAS15546', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 68, NULL, NULL, NULL),
	(1525, 158, 'TP', 'TRUMPET, B FLAT', 'CAS16006', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 69, NULL, NULL, NULL),
	(1529, 500, 'FL', 'FLUTE', 'K96337', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 12, NULL, NULL, NULL),
	(1535, 423, 'CL', 'CLARINET, B FLAT', '282570', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'CL', 15, NULL, NULL, NULL),
	(1537, 424, 'CL', 'CLARINET, B FLAT', '206244', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'CL', 16, NULL, NULL, NULL),
	(1538, 508, 'FL', 'FLUTE', '2SP-K96103', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 16, NULL, NULL, NULL),
	(1539, 4, 'BH', 'BARITONE/EUPHONIUM', '987998', 'Good', 'INSTRUMENT STORE', 'KING', NULL, 'BH', 5, NULL, NULL, NULL),
	(1541, 541, 'FL', 'FLUTE', 'XD59821', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 46, NULL, NULL, NULL),
	(1542, 542, 'FL', 'FLUTE', 'XD59741', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 47, NULL, NULL, NULL),
	(1543, 561, 'FL', 'FLUTE', 'DD58003', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JFL 700', 'FL', 67, NULL, NULL, NULL),
	(1546, 147, 'TP', 'TRUMPET, B FLAT', 'XA14523', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 58, NULL, NULL, NULL),
	(1547, 85, 'TP', 'TRUMPET, B FLAT', '831664', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 5, NULL, NULL, NULL),
	(1553, 537, 'FL', 'FLUTE', 'WD62143', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 42, NULL, NULL, NULL),
	(1554, 451, 'CL', 'CLARINET, B FLAT', '1312128', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'CL', 43, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.instruments (id, legacy_number, code, description, serial, state, location, make, model, legacy_code, number, user_name, user_id, issued_on) VALUES
	(1556, 452, 'CL', 'CLARINET, B FLAT', '1312139', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'CL', 44, NULL, NULL, NULL),
	(1557, 539, 'FL', 'FLUTE', 'XD59192', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 44, NULL, NULL, NULL),
	(1558, 453, 'CL', 'CLARINET, B FLAT', 'KE54780', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 45, NULL, NULL, NULL),
	(1608, 526, 'FL', 'FLUTE', 'D1206521', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 31, NULL, NULL, NULL),
	(1610, 460, 'CL', 'CLARINET, B FLAT', 'XE54946', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 52, NULL, NULL, NULL),
	(1611, 558, 'FL', 'FLUTE', 'DD57954', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JFL 700', 'FL', 64, NULL, NULL, NULL),
	(1613, 559, 'FL', 'FLUTE', 'DD58158', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JFL 700', 'FL', 65, NULL, NULL, NULL),
	(1614, 474, 'CL', 'CLARINET, B FLAT', 'BE63671', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 66, NULL, NULL, NULL),
	(1633, 504, 'FL', 'FLUTE', '2SP-K90658', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 14, NULL, NULL, NULL),
	(1636, 520, 'FL', 'FLUTE', '28411029', 'Good', 'INSTRUMENT STORE', 'PRELUDE', '711', 'FL', 25, NULL, NULL, NULL),
	(1657, 448, 'CL', 'CLARINET, B FLAT', '1209179', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 40, NULL, NULL, NULL),
	(1659, 449, 'CL', 'CLARINET, B FLAT', '1209180', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 41, NULL, NULL, NULL),
	(1660, 450, 'CL', 'CLARINET, B FLAT', '1209177', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 42, NULL, NULL, NULL),
	(1661, 544, 'FL', 'FLUTE', 'XD59774', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 49, NULL, NULL, NULL),
	(1662, 545, 'FL', 'FLUTE', 'XD59164', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 50, NULL, NULL, NULL),
	(1663, 459, 'CL', 'CLARINET, B FLAT', 'KE54774', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 51, NULL, NULL, NULL),
	(1677, 148, 'TP', 'TRUMPET, B FLAT', 'XA14343', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 59, NULL, NULL, NULL),
	(1678, 149, 'TP', 'TRUMPET, B FLAT', 'XA033335', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 60, NULL, NULL, NULL),
	(1679, 150, 'TP', 'TRUMPET, B FLAT', 'BA09439', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 61, NULL, NULL, NULL),
	(1680, 418, 'CL', 'CLARINET, B FLAT', '30614E', 'Good', 'INSTRUMENT STORE', 'SIGNET', NULL, 'CL', 10, NULL, NULL, NULL),
	(1692, 521, 'FL', 'FLUTE', 'K98973', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 26, NULL, NULL, NULL),
	(1694, 522, 'FL', 'FLUTE', 'P11876', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 27, NULL, NULL, NULL),
	(1696, 436, 'CL', 'CLARINET, B FLAT', '11299279', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 28, NULL, NULL, NULL),
	(1719, 523, 'FL', 'FLUTE', 'K98879', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 28, NULL, NULL, NULL),
	(1720, 437, 'CL', 'CLARINET, B FLAT', '11299280', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 29, NULL, NULL, NULL),
	(1721, 524, 'FL', 'FLUTE', 'K99078', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 29, NULL, NULL, NULL),
	(1618, 374, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'INSTRUMENT STORE', 'PARADISE', '20', NULL, 20, NULL, NULL, NULL),
	(1722, 438, 'CL', 'CLARINET, B FLAT', '11299277', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 30, NULL, NULL, NULL),
	(1729, 563, 'OB', 'OBOE', 'B33402', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'OB', 2, NULL, NULL, NULL),
	(1730, 565, 'PC', 'PICCOLO', '12111016', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'PC', 2, NULL, NULL, NULL),
	(1508, 118, 'TP', 'TRUMPET, B FLAT', 'H35268', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 36, NULL, NULL, NULL),
	(1509, 135, 'TP', 'TRUMPET, B FLAT', 'XA08649', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 46, NULL, NULL, NULL),
	(1744, 658, 'SXT', 'SAXOPHONE, TENOR', '13120005', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TX', 14, NULL, NULL, NULL),
	(1665, 487, 'FL', 'FLUTE', 'T479', 'Good', 'INSTRUMENT STORE', 'HEIMAR', NULL, 'FL', 4, NULL, NULL, NULL),
	(2091, 188, 'PE', 'PIANO, ELECTRIC', 'GBRCKK 01021', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'CVP 303', NULL, 1, NULL, NULL, NULL),
	(1712, 598, 'SXA', 'SAXOPHONE, ALTO', 'XF54370', 'Good', 'MS MUSIC', 'JUPITER', 'JAS 710', 'AX', 31, NULL, NULL, NULL),
	(1510, 136, 'TP', 'TRUMPET, B FLAT', 'XA08643', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 47, NULL, NULL, NULL),
	(2084, 515, 'FL', 'FLUTE', '917792', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'FL', 20, NULL, NULL, NULL),
	(1989, 109, 'TP', 'TRUMPET, B FLAT', 'G27536', 'Good', NULL, 'BLESSING', NULL, 'TP', 29, 'Noah Ochomo', 1071, NULL),
	(1595, 516, 'FL', 'FLUTE', 'J94358', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 21, NULL, NULL, NULL),
	(1594, 494, 'FL', 'FLUTE', 'G15104', 'Good', NULL, 'GEMEINHARDT', '2SP', 'FL', 9, 'Margaret Oganda', 1078, NULL),
	(1687, 656, 'SXT', 'SAXOPHONE, TENOR', 'TS10050027', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'TX', 12, NULL, NULL, NULL),
	(1566, 11, 'HNF', 'HORN, F', 'XC07411', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JHR700', 'HN', 4, NULL, NULL, NULL),
	(1705, 648, 'SXT', 'SAXOPHONE, TENOR', '26286', 'Good', NULL, 'YAMAHA', NULL, 'TX', 4, NULL, NULL, NULL),
	(1872, 10, 'HNF', 'HORN, F', '602', 'Good', NULL, 'HOLTON', NULL, 'HN', 3, 'Jamison Line', 172, NULL),
	(1800, 479, 'CLB', 'CLARINET, BASS', '18250', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'BCL', 1, NULL, NULL, NULL),
	(2063, 93, 'TP', 'TRUMPET, B FLAT', '553853', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 13, NULL, NULL, NULL),
	(1606, 321, 'BK', 'BELL KIT', NULL, 'Good', NULL, 'PEARL', 'PK900C', NULL, 4, 'Mahori', NULL, NULL),
	(1596, 496, 'FL', 'FLUTE', '2SP-L89133', 'Good', NULL, 'GEMEINHARDT', NULL, 'FL', 10, 'Zoe Mcdowell', NULL, NULL),
	(1842, 642, 'SXB', 'SAXOPHONE, BARITONE', 'XF05936', 'Good', 'PIANO ROOM', 'JUPITER', 'JBS 1000', 'BX', 3, NULL, NULL, NULL),
	(1788, 641, 'SXB', 'SAXOPHONE, BARITONE', 'B15217', 'Good', NULL, 'VIENNA', NULL, 'BX', 2, 'Fatuma Tall', 301, NULL),
	(1814, 38, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM18030151', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 6, NULL, NULL, NULL),
	(1750, 40, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM17120387', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 8, NULL, NULL, NULL),
	(1565, 350, 'VCL', 'CELLO, (VIOLONCELLO)', NULL, 'Good', NULL, 'WENZER KOHLER', NULL, 'C', 2, 'Mark Anding', 1076, NULL),
	(1795, 7, 'BT', 'BARITONE/TENOR HORN', '575586', 'Good', 'INSTRUMENT STORE', 'BESSON', NULL, 'BH', 1, NULL, NULL, NULL),
	(1592, 572, 'SXA', 'SAXOPHONE, ALTO', '200585', 'Good', NULL, 'GIARDINELLI', NULL, 'AX', 7, 'Gwendolyn Anding', 1077, NULL),
	(1713, 632, 'SXA', 'SAXOPHONE, ALTO', 'BF54335', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 63, 'Tawheed Hussain', 177, NULL),
	(1706, 47, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'TROMBA', 'Pro', 'PTB', 15, 'Kianu Ruiz Stannah', 276, NULL),
	(1593, 8, 'HNF', 'HORN, F', '619528', 'Good', NULL, 'HOLTON', 'H281', 'HN', 1, 'Gwendolyn Anding', 1077, NULL),
	(1603, 349, 'VCL', 'CELLO, (VIOLONCELLO)', '100725', 'Good', NULL, 'CREMONA', NULL, 'C', 1, 'Gwendolyn Anding', 1077, NULL),
	(1621, 383, 'GRE', 'GUITAR, ELECTRIC', '116108513', 'Good', NULL, 'FENDER', 'CD-60CE Mahogany', NULL, 30, 'Gakenia Mucharie', 1075, NULL),
	(1905, 111, 'TP', 'TRUMPET, B FLAT', '645447', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 31, NULL, NULL, NULL),
	(2044, 543, 'FL', 'FLUTE', 'XD59816', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 48, 'Teagan Wood', 159, NULL),
	(1844, 605, 'SXA', 'SAXOPHONE, ALTO', 'XF53797', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 36, 'Thomas Higgins', 342, NULL),
	(1990, 666, 'SXT', 'SAXOPHONE, TENOR', 'CF07965', 'Good', NULL, 'JUPITER', 'JTS700', 'TX', 22, 'Tawheed Hussain', 177, NULL),
	(2043, 23, 'TN', 'TROMBONE, TENOR', '303168', 'Good', NULL, 'YAMAHA', NULL, 'TB', 9, 'Zameer Nanji', 257, NULL),
	(1757, 433, 'CL', 'CLARINET, B FLAT', '405117', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 25, NULL, NULL, NULL),
	(1908, 363, 'GRC', 'GUITAR, CLASSICAL', 'HKZ104831', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 7, NULL, NULL, NULL),
	(1901, 1, 'BH', 'BARITONE/EUPHONIUM', '601249', 'Good', NULL, 'BOOSEY & HAWKES', 'Soveriegn', 'BH', 2, 'Kasra Feizzadeh', 135, NULL),
	(1533, 546, 'FL', 'FLUTE', 'XD60579', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 51, 'Nellie Odera', 1081, NULL),
	(1894, 596, 'SXA', 'SAXOPHONE, ALTO', 'XF54480', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 30, 'Margaret Oganda', 1078, NULL),
	(1899, 628, 'SXA', 'SAXOPHONE, ALTO', 'AF53348', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 59, 'Reuben Szuchman', 848, NULL),
	(1848, 455, 'CL', 'CLARINET, B FLAT', 'KE56579', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 47, NULL, NULL, NULL),
	(1698, 477, 'CL', 'CLARINET, B FLAT', 'BE63692', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 69, NULL, NULL, NULL),
	(1699, 128, 'TP', 'TRUMPET, B FLAT', '34928', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 41, NULL, NULL, NULL),
	(1703, 604, 'SXA', 'SAXOPHONE, ALTO', 'XF54451', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 35, NULL, NULL, NULL),
	(1819, 608, 'SXA', 'SAXOPHONE, ALTO', 'XF54476', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 39, NULL, NULL, NULL),
	(1701, 663, 'SXT', 'SAXOPHONE, TENOR', 'AF04276', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TX', 19, NULL, NULL, NULL),
	(2097, 43, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PB17070488', 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 11, NULL, NULL, NULL),
	(1700, 130, 'TP', 'TRUMPET, B FLAT', '35272', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 42, NULL, NULL, NULL),
	(1918, 458, 'CL', 'CLARINET, B FLAT', 'KE54751', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 50, NULL, NULL, NULL),
	(1718, 426, 'CL', 'CLARINET, B FLAT', '25247', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 18, NULL, NULL, NULL),
	(1880, 555, 'FL', 'FLUTE', 'BD62784', 'Good', 'MS MUSIC', 'JUPITER', 'JEL 710', 'FL', 61, NULL, NULL, NULL),
	(2101, 101, 'TP', 'TRUMPET, B FLAT', 'H35502', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 21, NULL, NULL, NULL),
	(1674, 68, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 36, NULL, NULL, NULL),
	(1715, 346, 'GRB', 'GUITAR, BASS', 'ICS10191321', 'Good', 'INSTRUMENT STORE', 'FENDER', 'Squire', NULL, 3, NULL, NULL, NULL),
	(1716, 82, 'TP', 'TRUMPET, B FLAT', 'G29437', 'Good', 'MS MUSIC', 'BLESSING', NULL, 'TP', 2, NULL, NULL, NULL),
	(1876, 313, 'BL', 'BELL SET', NULL, 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 2, NULL, NULL, NULL),
	(1740, 427, 'CL', 'CLARINET, B FLAT', 'J65020', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'CL', 19, NULL, NULL, NULL),
	(1797, 160, 'TPP', 'TRUMPET, POCKET', 'PT1309020', 'Good', 'MS MUSIC', 'ALLORA', NULL, 'TPP', 1, NULL, NULL, NULL),
	(1702, 145, 'TP', 'TRUMPET, B FLAT', 'XA04094', 'Good', 'MS MUSIC', 'JUPITER', NULL, 'TP', 56, NULL, NULL, NULL),
	(2099, 457, 'CL', 'CLARINET, B FLAT', 'KE54676', 'Good', 'MS MUSIC', 'JUPITER', 'JCL710', 'CL', 49, NULL, NULL, NULL),
	(1915, 621, 'SXA', 'SAXOPHONE, ALTO', 'YF57348', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 52, 'Mark Anding', 1076, NULL),
	(1923, 617, 'SXA', 'SAXOPHONE, ALTO', 'XF56283', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 48, 'Vanaaya Patel', 304, NULL),
	(1895, 384, 'GRE', 'GUITAR, ELECTRIC', '116108578', 'Good', NULL, 'FENDER', 'CD-60CE Mahogany', NULL, 31, 'Angel Gray', NULL, NULL),
	(1561, 567, 'SXA', 'SAXOPHONE, ALTO', '11120072', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 2, NULL, NULL, NULL),
	(1562, 646, 'SXT', 'SAXOPHONE, TENOR', '227671', 'Good', 'INSTRUMENT STORE', 'BUSCHER', NULL, 'TX', 2, NULL, NULL, NULL),
	(1564, 389, 'GRT', 'GUITAR, HALF', '10', 'Good', NULL, 'KAY', NULL, NULL, 5, NULL, NULL, NULL),
	(1567, 285, 'SR', 'SNARE', '6276793', 'Good', 'MS MUSIC', 'LUDWIG', NULL, NULL, 1, NULL, NULL, NULL),
	(1568, 295, 'TML', 'TIMBALI', '3112778', 'Good', 'MS MUSIC', 'LUDWIG', NULL, NULL, 1, NULL, NULL, NULL),
	(1569, 257, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 7, NULL, NULL, NULL),
	(1571, 275, 'SRM', 'SNARE, MARCHING', '1P-3099', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 2, NULL, NULL, NULL),
	(1572, 278, 'SRM', 'SNARE, MARCHING', '1P-3076', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 5, NULL, NULL, NULL),
	(1574, 288, 'SR', 'SNARE', 'NIL', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, NULL, 26, NULL, NULL, NULL),
	(1560, 143, 'TP', 'TRUMPET, B FLAT', 'XA02614', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 54, NULL, NULL, NULL),
	(1754, 5, 'BH', 'BARITONE/EUPHONIUM', '533835', 'Good', NULL, 'YAMAHA', NULL, 'BH', 6, 'Etienne Carlevato', 980, '2024-06-04'),
	(1704, 547, 'FL', 'FLUTE', 'YD66330', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 53, NULL, NULL, '2024-06-04'),
	(1738, 467, 'CL', 'CLARINET, B FLAT', 'XE54680', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 59, 'Aisha Awori', 960, '2024-06-04'),
	(1900, 464, 'CL', 'CLARINET, B FLAT', 'XE54692', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 56, 'Lilla Vestergaard', 928, '2024-06-04'),
	(2102, 103, 'TP', 'TRUMPET, B FLAT', 'H35099', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 23, NULL, NULL, NULL),
	(2057, 606, 'SXA', 'SAXOPHONE, ALTO', 'XF54452', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 37, 'Tanay Cherickel', 974, '2024-06-04'),
	(1550, 624, 'SXA', 'SAXOPHONE, ALTO', 'XF54149', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 55, NULL, NULL, NULL),
	(1598, 90, 'TP', 'TRUMPET, B FLAT', 'F24090', 'Good', NULL, 'BLESSING', NULL, 'TP', 10, 'Gakenia Mucharie', 1075, '2024-06-04'),
	(1714, 463, 'CL', 'CLARINET, B FLAT', 'XE54729', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 55, 'Lauren Mucci', 981, '2024-06-04'),
	(2046, 625, 'SXA', 'SAXOPHONE, ALTO', 'AF53425', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 56, 'Milan Jayaram', 967, '2024-06-04'),
	(1902, 456, 'CL', 'CLARINET, B FLAT', 'KE56608', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 48, NULL, NULL, NULL),
	(1563, 153, 'TP', 'TRUMPET, B FLAT', 'BA09444', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 64, NULL, NULL, NULL),
	(1573, 3, 'BH', 'BARITONE/EUPHONIUM', '839431', 'Good', NULL, 'AMATI KRASLICE', NULL, 'BH', 4, NULL, NULL, NULL),
	(1575, 510, 'FL', 'FLUTE', 'K98713', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 17, NULL, NULL, NULL),
	(1576, 512, 'FL', 'FLUTE', '2SP-K99109', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 18, NULL, NULL, NULL),
	(1640, 587, 'SXA', 'SAXOPHONE, ALTO', '11110740', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 22, NULL, NULL, NULL),
	(1641, 386, 'GRT', 'GUITAR, HALF', '7', 'Good', NULL, 'KAY', NULL, NULL, 2, NULL, NULL, NULL),
	(1644, 600, 'SXA', 'SAXOPHONE, ALTO', 'XF54574', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 32, NULL, NULL, NULL),
	(1648, 603, 'SXA', 'SAXOPHONE, ALTO', 'XF54336', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 34, NULL, NULL, NULL),
	(1650, 581, 'SXA', 'SAXOPHONE, ALTO', '362477A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 16, NULL, NULL, NULL),
	(1646, 74, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 42, NULL, NULL, NULL),
	(1649, 42, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PB17070395', 'Good', NULL, 'TROMBA', 'Pro', 'PTB', 10, NULL, NULL, NULL),
	(1639, 517, 'FL', 'FLUTE', '28411021', 'Good', 'INSTRUMENT STORE', 'PRELUDE', NULL, 'FL', 22, NULL, NULL, NULL),
	(1642, 439, 'CL', 'CLARINET, B FLAT', '11299276', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 31, NULL, NULL, NULL),
	(1643, 527, 'FL', 'FLUTE', 'D1206485', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 32, NULL, NULL, NULL),
	(1645, 528, 'FL', 'FLUTE', 'D1206556', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 33, NULL, NULL, NULL),
	(1647, 529, 'FL', 'FLUTE', '206295', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 34, NULL, NULL, NULL),
	(1651, 116, 'TP', 'TRUMPET, B FLAT', '756323', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 35, NULL, NULL, NULL),
	(1652, 530, 'FL', 'FLUTE', '206261', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 35, NULL, NULL, NULL),
	(1653, 531, 'FL', 'FLUTE', 'K96124', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 36, NULL, NULL, NULL),
	(1654, 533, 'FL', 'FLUTE', 'WD57818', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 38, NULL, NULL, NULL),
	(1656, 447, 'CL', 'CLARINET, B FLAT', '1209178', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 39, NULL, NULL, NULL),
	(1970, 92, 'TP', 'TRUMPET, B FLAT', '678970', 'Good', NULL, 'YAMAHA', 'YTR 2335', 'TP', 12, 'Ignacio Biafore', 936, NULL),
	(2051, 536, 'FL', 'FLUTE', 'WD62303', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 41, 'Julian Dibling', 939, NULL),
	(2049, 534, 'FL', 'FLUTE', 'WD62211', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 39, 'Leo Cutler', 267, NULL),
	(1997, 538, 'FL', 'FLUTE', 'WD62183', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 43, 'Mark Anding', 1076, NULL),
	(1983, 57, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'KAIZER', NULL, 'PTB', 25, 'Mark Anding', 1076, NULL),
	(2042, 654, 'SXT', 'SAXOPHONE, TENOR', '063739A', 'Good', NULL, 'YAMAHA', NULL, 'TX', 10, 'Finlay Haswell', 951, NULL),
	(2048, 662, 'SXT', 'SAXOPHONE, TENOR', 'YF06601', 'Good', NULL, 'JUPITER', 'JTS710', 'TX', 18, 'Gunnar Purdy', 27, NULL),
	(2052, 660, 'SXT', 'SAXOPHONE, TENOR', '3847', 'Good', NULL, 'JUPITER', NULL, 'TX', 16, 'Adam Kone', 755, NULL),
	(2031, 26, 'TN', 'TROMBONE, TENOR', '406896', 'Good', NULL, 'YAMAHA', NULL, 'TB', 12, 'Marco De Vries Aguirre', 502, NULL),
	(2028, 482, 'CLB', 'CLARINET, BASS', 'YE 69248', 'Good', NULL, 'YAMAHA', 'Hex 1000', 'BCL', 4, 'Gwendolyn Anding', 1077, NULL),
	(1632, 396, 'VN', 'VIOLIN', 'J052107087', 'Good', 'HS MUSIC', 'HOFNER', NULL, NULL, 1, NULL, NULL, NULL),
	(2072, 445, 'CL', 'CLARINET, B FLAT', 'J65342', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 37, NULL, NULL, NULL),
	(2088, 230, 'BD', 'BASS DRUM', 'PO-1575', 'Good', 'MS MUSIC', 'YAMAHA', 'CB628', NULL, 2, NULL, NULL, NULL),
	(2094, 440, 'CL', 'CLARINET, B FLAT', 'J65438', 'Good', NULL, 'YAMAHA', NULL, 'CL', 32, 'Io Verstraete', 792, NULL),
	(2092, 435, 'CL', 'CLARINET, B FLAT', '074011A', 'Good', NULL, 'YAMAHA', NULL, 'CL', 27, 'Leo Prawitz', 511, NULL),
	(2113, 618, 'SXA', 'SAXOPHONE, ALTO', 'XF56319', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 49, 'Barney Carver Wildig', 612, NULL),
	(1731, 371, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'INSTRUMENT STORE', 'PARADISE', '17', NULL, 17, NULL, NULL, NULL),
	(1751, 283, 'BLS', 'BELLS, SLEIGH', NULL, 'Good', 'HS MUSIC', 'WEISS', NULL, NULL, 1, NULL, NULL, NULL),
	(2071, 430, 'CL', 'CLARINET, B FLAT', 'J07292', 'Good', NULL, 'YAMAHA', NULL, 'CL', 22, 'Kevin Keene', NULL, NULL),
	(2117, 540, 'FL', 'FLUTE', 'XD58187', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 45, 'Saptha Girish Bommadevara', 332, NULL),
	(2041, 18, 'TN', 'TROMBONE, TENOR', '406948', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 4, NULL, NULL, NULL),
	(2114, 461, 'CL', 'CLARINET, B FLAT', 'XE54957', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 53, NULL, NULL, NULL),
	(2095, 86, 'TP', 'TRUMPET, B FLAT', '556107', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 6, NULL, NULL, NULL),
	(2093, 83, 'TP', 'TRUMPET, B FLAT', '533719', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 3, NULL, NULL, NULL),
	(2047, 132, 'TP', 'TRUMPET, B FLAT', 'WA26516', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 43, NULL, NULL, NULL),
	(2100, 594, 'SXA', 'SAXOPHONE, ALTO', 'XF54576', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 29, NULL, NULL, NULL),
	(1996, 113, 'TP', 'TRUMPET, B FLAT', 'F19277', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 33, NULL, NULL, NULL),
	(2006, 144, 'TP', 'TRUMPET, B FLAT', '488350', 'Good', 'INSTRUMENT STORE', 'BACH', NULL, 'TP', 55, NULL, NULL, NULL),
	(2053, 114, 'TP', 'TRUMPET, B FLAT', '511564', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 34, NULL, NULL, NULL),
	(2045, 473, 'CL', 'CLARINET, B FLAT', 'YE67756', 'Good', 'MS MUSIC', 'JUPITER', 'JCL710', 'CL', 65, NULL, NULL, NULL),
	(2067, 88, 'TP', 'TRUMPET, B FLAT', '806725', 'Good', 'MS MUSIC', 'YAMAHA', 'YTR 2335', 'TP', 8, NULL, NULL, NULL),
	(1924, 616, 'SXA', 'SAXOPHONE, ALTO', 'XF57296', 'Good', 'MS MUSIC', 'JUPITER', 'JAS 710', 'AX', 47, NULL, NULL, NULL),
	(1995, 100, 'TP', 'TRUMPET, B FLAT', 'H31438', 'Good', 'MS MUSIC', 'BLESSING', NULL, 'TP', 20, NULL, NULL, NULL),
	(2118, 570, 'SXA', 'SAXOPHONE, ALTO', '11110173', 'Good', NULL, 'ETUDE', NULL, 'AX', 5, 'Lukas Norman', 419, NULL),
	(2121, 649, 'SXT', 'SAXOPHONE, TENOR', '31870', 'Good', NULL, 'YAMAHA', NULL, 'TX', 5, 'Spencer Schenck', 924, NULL),
	(2119, 643, 'SXB', 'SAXOPHONE, BARITONE', 'AF03351', 'Good', NULL, 'JUPITER', 'JBS 1000', 'BX', 4, 'Lukas Norman', 419, NULL),
	(2068, 196, 'PE', 'PIANO, ELECTRIC', NULL, 'Good', 'DANCE STUDIO', 'YAMAHA', NULL, NULL, 8, NULL, NULL, NULL),
	(2069, 185, 'KB', 'KEYBOARD', '913094', 'Good', NULL, 'YAMAHA', 'PSR 220', NULL, 21, NULL, NULL, NULL),
	(2070, 186, 'KB', 'KEYBOARD', '13143', 'Good', NULL, 'YAMAHA', 'PSR 83', NULL, 22, NULL, NULL, NULL),
	(2077, 345, 'GRB', 'GUITAR, BASS', NULL, 'Good', 'MS MUSIC', 'YAMAHA', 'BB1000', NULL, 2, NULL, NULL, NULL),
	(2078, 219, NULL, 'PEDAL, SUSTAIN', NULL, 'Good', 'HS MUSIC', 'YAMAHA', 'FC4', NULL, 7, NULL, NULL, NULL),
	(2080, 316, 'BL', 'BELL SET', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 5, NULL, NULL, NULL),
	(2089, 377, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', NULL, 'YAMAHA', '40', NULL, 29, 'Keeara Walji', NULL, NULL),
	(2075, 365, 'GRC', 'GUITAR, CLASSICAL', 'HKP064005', 'Good', NULL, 'YAMAHA', '40', NULL, 9, 'Finola Doherty', NULL, NULL),
	(2076, 367, 'GRC', 'GUITAR, CLASSICAL', 'HKP054553', 'Good', NULL, 'YAMAHA', '40', NULL, 11, 'Marwa Baker', NULL, NULL),
	(1898, 91, 'TP', 'TRUMPET, B FLAT', '554189', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 11, NULL, NULL, NULL),
	(1907, 161, 'TB', 'TUBA', '106508', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'T', 1, NULL, NULL, NULL),
	(2062, 265, 'DK', 'DRUMSET', 'SBB2217', 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 4, NULL, NULL, NULL),
	(1668, 214, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 14, NULL, NULL, NULL),
	(1669, 425, 'CL', 'CLARINET, B FLAT', '443788', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 17, NULL, NULL, NULL),
	(1531, 623, 'SXA', 'SAXOPHONE, ALTO', 'YF57320', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 54, NULL, NULL, '2024-06-04'),
	(1672, 360, 'GRC', 'GUITAR, CLASSICAL', 'HKP064875', 'Good', NULL, 'YAMAHA', '40', NULL, 4, 'Jihong Joo', 525, NULL),
	(1670, 635, 'SXA', 'SAXOPHONE, ALTO', 'CF57209', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 66, NULL, NULL, NULL),
	(1673, 17, 'TN', 'TROMBONE, TENOR', '336151', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 3, NULL, NULL, NULL),
	(1671, 364, 'GRC', 'GUITAR, CLASSICAL', 'HKP064163', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 8, NULL, NULL, NULL),
	(2103, 106, 'TP', 'TRUMPET, B FLAT', 'H31450', 'Good', NULL, 'BLESSING', 'BIR 1270', 'TP', 26, 'Saqer Alnaqbi', 942, NULL),
	(2106, 629, 'SXA', 'SAXOPHONE, ALTO', 'AF53502', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 60, 'Noga Hercberg', 661, NULL),
	(2108, 592, 'SXA', 'SAXOPHONE, ALTO', 'XF54339', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 27, 'Alexander Roe', 36, NULL),
	(2104, 64, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'PBONE', NULL, 'PTB', 32, 'Seth Lundell', 982, NULL),
	(2112, 124, 'TP', 'TRUMPET, B FLAT', '1107571', 'Good', 'INSTRUMENT STORE', 'LIBRETTO', NULL, 'TP', 39, NULL, NULL, NULL),
	(1577, 514, 'FL', 'FLUTE', 'P11203', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 19, NULL, NULL, NULL),
	(1999, 454, 'CL', 'CLARINET, B FLAT', 'KE56526', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 46, 'Noah Ochomo', 1071, NULL),
	(1676, 353, 'GRA', 'GUITAR, ACOUSTIC', '00Y224884', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'F 325', NULL, 20, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.instruments (id, legacy_number, code, description, serial, state, location, make, model, legacy_code, number, user_name, user_id, issued_on) VALUES
	(2034, 189, 'PE', 'PIANO, ELECTRIC', 'GBRCKK 01006', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'CVP303x', NULL, 2, NULL, NULL, NULL),
	(1943, 294, 'TRT', 'TAMBOURINE, 10 INCH', NULL, 'Good', 'INSTRUMENT STORE', 'PEARL', 'Symphonic Double Row PEA-PETM1017', NULL, 1, NULL, NULL, NULL),
	(1545, 84, 'TP', 'TRUMPET, B FLAT', 'H31816', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 4, NULL, NULL, NULL),
	(2110, 551, 'FL', 'FLUTE', 'YD65954', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 57, NULL, NULL, NULL),
	(2107, 469, 'CL', 'CLARINET, B FLAT', 'YE67254', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 61, NULL, NULL, NULL),
	(2074, 16, 'TN', 'TROMBONE, TENOR', '406538', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'TB', 2, NULL, NULL, NULL),
	(1798, 401, 'BS', 'BASSOON', '33CVC02', 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 1, NULL, NULL, NULL),
	(1925, 235, 'CST', 'CASTANETS', NULL, 'Good', 'INSTRUMENT STORE', 'DANMAR', 'DAN-17A', NULL, 1, NULL, NULL, NULL),
	(1710, 619, 'SXA', 'SAXOPHONE, ALTO', 'XF56406', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 50, NULL, NULL, NULL),
	(2122, 21, 'TN', 'TROMBONE, TENOR', '325472', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 7, NULL, NULL, NULL),
	(2111, 99, 'TP', 'TRUMPET, B FLAT', 'H35203', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BTR 1270', 'TP', 19, NULL, NULL, NULL),
	(2109, 344, 'GRB', 'GUITAR, BASS', NULL, 'Good', 'INSTRUMENT STORE', 'ARCHER', NULL, NULL, 1, NULL, NULL, NULL),
	(1833, 553, 'FL', 'FLUTE', 'BD63526', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 59, NULL, NULL, '2024-06-04'),
	(1891, 486, 'FL', 'FLUTE', '600365', 'Good', NULL, 'YAMAHA', NULL, 'FL', 3, 'Eliana Hodge', 945, '2024-06-04'),
	(2060, 610, 'SXA', 'SAXOPHONE, ALTO', 'XF54140', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 41, 'Lucile Bamlango', 176, '2024-06-04'),
	(1522, 155, 'TP', 'TRUMPET, B FLAT', 'CA15052', 'Good', NULL, 'JUPITER', 'JTR 700', 'TP', 66, 'Mikael Eshetu', 935, '2024-06-04'),
	(1806, 483, 'CLB', 'CLARINET, BASS', 'CE69047', 'Good', NULL, 'JUPITER', 'JBC 1000', 'BCL', 5, 'Moussa Sangare', 929, '2024-06-04'),
	(1790, 613, 'SXA', 'SAXOPHONE, ALTO', 'XF56401', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 44, 'Nirvi Joymungul', 984, '2024-06-04'),
	(2105, 66, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'PBONE', NULL, 'PTB', 34, 'Sadie Szuchman', 846, '2024-06-04'),
	(2116, 2, 'BH', 'BARITONE/EUPHONIUM', '770765', 'Good', NULL, 'BESSON', 'Soveriegn 968', 'BH', 3, 'Saqer Alnaqbi', 942, '2024-06-04'),
	(2115, 548, 'FL', 'FLUTE', 'YD66080', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 54, 'Seya Chandaria', 926, '2024-06-04'),
	(2050, 535, 'FL', 'FLUTE', 'WD62108', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 40, 'Yoonseo Choi', 953, '2024-06-04'),
	(1809, 622, 'SXA', 'SAXOPHONE, ALTO', 'YF57624', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 53, 'Gakenia Mucharie', 1075, '2024-06-04'),
	(1906, 651, 'SXT', 'SAXOPHONE, TENOR', '10355', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TX', 7, NULL, NULL, NULL),
	(1818, 243, 'CG', 'CONGA', NULL, 'Good', 'INSTRUMENT STORE', 'MEINL', 'HEADLINER RANGE', NULL, 2, NULL, NULL, NULL),
	(1873, 242, 'CG', 'CONGA', NULL, 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'Red 14 inch', NULL, 1, NULL, NULL, NULL),
	(1856, 87, 'TP', 'TRUMPET, B FLAT', '638871', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 7, NULL, NULL, NULL),
	(1496, 94, 'TP', 'TRUMPET, B FLAT', 'L306677', 'Good', 'INSTRUMENT STORE', 'BACH', 'Stradivarius 37L', 'TP', 14, NULL, NULL, NULL),
	(1950, 174, 'AMK', 'AMPLIFIER, KEYBOARD', 'ODB#1230169', 'Good', 'HS MUSIC', 'PEAVEY', NULL, NULL, 9, NULL, NULL, NULL),
	(4163, NULL, 'DMMO', 'DUMMY 1', 'DUMMM1', 'Good', NULL, 'DUMMY MAKER', 'DUMDUM', NULL, 2, 'DUMMY 1 STUDENT', 1074, '2024-06-26'),
	(1681, 419, 'CL', 'CLARINET, B FLAT', 'B59862', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'CL', 1, NULL, NULL, NULL),
	(2024, 403, 'CL', 'CLARINET, B FLAT', '206681A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 11, NULL, NULL, NULL),
	(4208, NULL, 'DMMO', 'DUMMY 1', 'DUMM19378G', 'New', 'INSTRUMENT STORE', 'CUSTOM', NULL, NULL, 8, NULL, NULL, NULL),
	(1991, 664, 'SXT', 'SAXOPHONE, TENOR', 'CF07952', 'Good', NULL, 'JUPITER', 'JTS700', 'TX', 9, 'Mark Anding', 1076, NULL),
	(4165, NULL, 'DMMO', 'DUMMY 1', 'DUMMM3', 'New', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, 4, NULL, NULL, '2024-06-26'),
	(4166, NULL, 'DMMO', 'DUMMY 1', 'DUMMM4', 'New', 'INSTRUMENT STORE', 'DUMMY MAKER', NULL, NULL, 5, NULL, NULL, '2024-06-26'),
	(4203, NULL, 'DMMO', 'DUMMY 1', 'DUMMM34124JKKLDF', 'New', 'INSTRUMENT STORE', 'CUSTOM', NULL, NULL, 6, NULL, NULL, '2024-06-26'),
	(4209, NULL, 'DMMO', 'DUMMY 1', 'DUMMM1234FE', 'New', 'INSTRUMENT STORE', 'CUSTOM', NULL, NULL, 7, NULL, NULL, '2024-06-26'),
	(2129, NULL, 'DMMO', 'DUMMY 1', NULL, 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMMY MODEL', NULL, 1, NULL, NULL, '2024-06-27'),
	(4164, NULL, 'DMMO', 'DUMMY 1', 'DUMMM2', 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, 3, NULL, NULL, '2024-06-27') ON CONFLICT DO NOTHING;


--
-- TOC entry 4025 (class 0 OID 30978)
-- Dependencies: 248
-- Data for Name: legacy_database; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.legacy_database (id, number, legacy_number, family, equipment, make, model, serial, class, year, full_name, school_storage, return_2023, student_number, code) VALUES
	(23, 2, 273, 'PERCUSSION', 'QUAD, MARCHING', 'PEARL', 'Black', '203143', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'Q'),
	(60, 3, 276, 'PERCUSSION', 'SNARE, MARCHING', 'VERVE', 'White', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SRM'),
	(89, 4, 277, 'PERCUSSION', 'SNARE, MARCHING', 'VERVE', 'White', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SRM'),
	(359, 15, 506, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'K96338', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(551, 43, 75, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(342, 14, 94, 'BRASS', 'TRUMPET, B FLAT', 'BACH', 'Stradivarius 37L', 'L306677', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(556, 44, 76, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(374, 17, 97, 'BRASS', 'TRUMPET, B FLAT', 'CONN', NULL, 'S-756323', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(383, 18, 98, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', 'BTR 1270', 'H35537', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(414, 22, 102, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', 'BIR 1270', 'H34929', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(430, 24, 104, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', 'BIR 1270', 'H32053', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(437, 25, 105, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', 'BIR 1270', 'H31491', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(458, 28, 108, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'F24304', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(561, 45, 77, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(557, 44, 133, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA07789', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(364, 16, 48, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(390, 19, 51, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(510, 36, 118, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H35268', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(567, 46, 135, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA08649', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(572, 47, 136, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA08643', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(577, 48, 137, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA08294', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(581, 49, 138, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA08319', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(585, 50, 139, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA08322', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(589, 51, 140, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA06017', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(593, 52, 141, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA05452', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(596, 53, 142, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA06111', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(51, 3, 163, 'BRASS', 'TUBA', 'BOOSEY & HAWKES', 'Imperial  EEb', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TB'),
	(260, 1, 640, 'WOODWIND', 'SAXOPHONE, BARITONE', 'SELMER', NULL, '1360873', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXB'),
	(632, 62, 151, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'BA09236', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(636, 63, 152, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'BA08359', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(644, 65, 154, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'BA09193', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(648, 66, 155, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', 'JTR 700', 'CA15052', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(652, 67, 156, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', 'JTR 700', 'CA16033', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(656, 68, 157, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', 'JTR 700', 'CAS15546', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(659, 69, 158, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', 'JTR 700', 'CAS16006', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(261, 1, 645, 'WOODWIND', 'SAXOPHONE, TENOR', 'VITO', NULL, '403557', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(274, 8, 573, 'WOODWIND', 'SAXOPHONE, ALTO', 'GIARDINELLI', NULL, '200547', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(275, 8, 652, 'WOODWIND', 'SAXOPHONE, TENOR', 'SELMER', NULL, 'N4200829', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(323, 12, 500, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'K96337', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(91, 4, 315, 'PERCUSSION', 'BELL SET', 'UNKNOWN', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'BL'),
	(603, 54, 623, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'YF57320', NULL, '2023/24', 'Nirvi Joymungul', NULL, NULL, 12997, 'SXA'),
	(156, 6, 650, 'WOODWIND', 'SAXOPHONE, TENOR', 'AMATI KRASLICE', NULL, '310278', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(591, 51, 546, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD60579', NULL, '2023', 'Nellie Odera', NULL, NULL, NULL, 'FL'),
	(105, 4, 569, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11120109', NULL, 'xx', NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(358, 15, 423, 'WOODWIND', 'CLARINET, B FLAT', 'VITO', NULL, '282570', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(362, 15, 659, 'WOODWIND', 'SAXOPHONE, TENOR', 'ALLORA', NULL, '13120021', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(367, 16, 424, 'WOODWIND', 'CLARINET, B FLAT', 'AMATI KRASLICE', NULL, '206244', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(368, 16, 508, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, '2SP-K96103', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(108, 5, 4, 'BRASS', 'BARITONE/EUPHONIUM', 'KING', NULL, '987998', NULL, 'x', NULL, 'INSTRUMENT STORE', NULL, NULL, 'BH'),
	(134, 5, 644, 'WOODWIND', 'SAXOPHONE, BARITONE', 'JUPITER', 'JBS 1000', 'CF05160', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXB'),
	(569, 46, 541, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD59821', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(574, 47, 542, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD59741', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(654, 67, 561, 'WOODWIND', 'FLUTE', 'JUPITER', 'JFL 700', 'DD58003', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(120, 5, 303, 'PERCUSSION', 'TUBANOS', 'REMO', '10 Inch', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TBN'),
	(82, 4, 84, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H31816', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(616, 58, 147, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA14523', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(112, 5, 85, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, '831664', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(155, 6, 571, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '12080618', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(49, 3, 35, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(607, 55, 624, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54149', 'HS MUSIC', '2023/24', 'Gakenia Mucharie', NULL, NULL, NULL, 'SXA'),
	(140, 6, 170, 'ELECTRIC', 'AMPLIFIER, BASS', 'ROLAND', 'Cube-120 XL', 'Z9G3740', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'AMB'),
	(265, 8, 173, 'ELECTRIC', 'AMPLIFIER, GUITAR', 'FENDER', 'STAGE 160', 'M 1005297', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'AMG'),
	(549, 42, 537, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'WD62143', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(553, 43, 451, 'WOODWIND', 'CLARINET, B FLAT', 'ALLORA', NULL, '1312128', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(555, 43, 612, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56514', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(558, 44, 452, 'WOODWIND', 'CLARINET, B FLAT', 'ALLORA', NULL, '1312139', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(559, 44, 539, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD59192', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(563, 45, 453, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'KE54780', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(215, 1, 252, 'PERCUSSION', 'CYMBALS, HANDHELD 16 INCH', 'SABIAN', 'SAB SR 16BOL', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CMY'),
	(600, 54, 143, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA02614', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(43, 2, 567, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11120072', NULL, 'xx', NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(45, 2, 646, 'WOODWIND', 'SAXOPHONE, TENOR', 'BUSCHER', NULL, '227671', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(640, 64, 153, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'BA09444', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(127, 5, 389, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '10', NULL, NULL, NULL, NULL, NULL, NULL, 'GRT'),
	(33, 2, 350, 'STRING', 'CELLO, (VIOLONCELLO)', 'WENZER KOHLER', NULL, NULL, NULL, '2023/24', 'Mark Anding', NULL, '7/6/23', NULL, 'VCL'),
	(79, 4, 11, 'BRASS', 'HORN, F', 'JUPITER', 'JHR700', 'XC07411', NULL, '2023/24', 'Mark Anding', 'MS MUSIC', NULL, NULL, 'HNF'),
	(228, 1, 285, 'PERCUSSION', 'SNARE', 'LUDWIG', NULL, '6276793', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SR'),
	(232, 1, 295, 'PERCUSSION', 'TIMBALI', 'LUDWIG', NULL, '3112778', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TML'),
	(19, 7, 257, 'PERCUSSION', 'DJEMBE', 'CUSTOM', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DJ'),
	(365, 16, 96, 'BRASS', 'TRUMPET, B FLAT', 'SCHILKE', 'B1L', '33911', NULL, '2023/24', 'Mark Anding', 'MS MUSIC', NULL, NULL, 'TP'),
	(24, 2, 275, 'PERCUSSION', 'SNARE, MARCHING', 'YAMAHA', 'MS 9014', '1P-3099', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SRM'),
	(119, 5, 278, 'PERCUSSION', 'SNARE, MARCHING', 'YAMAHA', 'MS 9014', '1P-3076', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SRM'),
	(78, 4, 3, 'BRASS', 'BARITONE/EUPHONIUM', 'AMATI KRASLICE', NULL, '839431', NULL, 'x', NULL, NULL, NULL, NULL, 'BH'),
	(445, 26, 288, 'PERCUSSION', 'SNARE', 'YAMAHA', NULL, 'NIL', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SR'),
	(377, 17, 510, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'K98713', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(386, 18, 512, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, '2SP-K99109', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(395, 19, 514, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'P11203', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(396, 19, 584, 'WOODWIND', 'SAXOPHONE, ALTO', 'BARRINGTON', NULL, 'AS1001039', NULL, 'xx', NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(382, 18, 50, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', 'PB17070322', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(75, 3, 568, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11120090', NULL, 'xx', NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(292, 10, 175, 'ELECTRIC', 'AMPLIFIER, KEYBOARD', 'PEAVEY', 'KB4', 'OBD#1230164', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'AMK'),
	(8, 2, 180, 'SOUND', 'MICROPHONE', 'SHURE', 'SM58', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(9, 2, 184, 'KEYBOARD', 'KEYBOARD', 'CASIO', NULL, 'TCK 611', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'KB'),
	(18, 2, 256, 'PERCUSSION', 'DJEMBE', 'CUSTOM', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DJ'),
	(58, 3, 258, 'PERCUSSION', 'DJEMBE', 'CUSTOM', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DJ'),
	(117, 5, 260, 'PERCUSSION', 'DJEMBE', 'CUSTOM', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DJ'),
	(218, 1, 255, 'PERCUSSION', 'DJEMBE', 'CUSTOM', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DJ'),
	(663, 70, 478, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'BE63657', 'HS MUSIC', '2023/24', 'Gakenia Mucharie', NULL, NULL, NULL, 'CL'),
	(178, 1, 14, 'BRASS', 'METALLOPHONE', 'ORFF', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'MTL'),
	(423, 23, 187, 'KEYBOARD', 'KEYBOARD', 'CASIO', 'TC-360', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'KB'),
	(194, 1, 217, 'MISCELLANEOUS', 'STAND, MUSIC', 'WENGER', NULL, '50052', 'HS MUSIC', '2022/23', NULL, NULL, NULL, NULL, NULL),
	(173, 7, 572, 'WOODWIND', 'SAXOPHONE, ALTO', 'GIARDINELLI', NULL, '200585', 'HS MUSIC', '2021/22', 'Gwendolyn Anding', NULL, NULL, NULL, 'SXA'),
	(176, 1, 8, 'BRASS', 'HORN, F', 'HOLTON', 'H281', '619528', 'HS MUSIC', '2023/24', 'Gwendolyn Anding', NULL, NULL, NULL, 'HNF'),
	(285, 9, 494, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'G15104', 'ES MUSIC', '2021/22', 'Magaret Oganda', NULL, NULL, NULL, 'FL'),
	(410, 21, 516, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'J94358', 'MS Band 8', '2022/23', 'Vera Ballan', NULL, '7/6/2023', NULL, 'FL'),
	(298, 10, 496, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, '2SP-L89133', 'ms concert band', '2021/22', 'Zoe Mcdowell', NULL, NULL, NULL, 'FL'),
	(318, 12, 176, 'ELECTRIC', 'AMPLIFIER, GUITAR', 'BUGERA', NULL, 'S190700059B4P', NULL, NULL, NULL, NULL, NULL, NULL, 'AMG'),
	(291, 10, 90, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'F24090', 'HS MUSIC', '2023/24', 'Gakenia Mucharie', NULL, NULL, NULL, 'TP'),
	(65, 3, 320, 'PERCUSSION', 'BELL KIT', 'PEARL', 'PK900C', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'BK'),
	(330, 13, 177, 'ELECTRIC', 'AMPLIFIER, GUITAR', 'FENDER', 'Blue Junior', 'B-749002', NULL, NULL, NULL, NULL, NULL, NULL, 'AMG'),
	(487, 32, 351, 'STRING', 'GUITAR, ACOUSTIC', 'UNKNOWN', NULL, NULL, NULL, 'under repair', NULL, NULL, NULL, NULL, 'GRA'),
	(404, 20, 585, 'WOODWIND', 'SAXOPHONE, ALTO', 'BARRINGTON', NULL, 'AS1003847', NULL, 'xx', NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(246, 1, 349, 'STRING', 'CELLO, (VIOLONCELLO)', 'CREMONA', NULL, '100725', 'HS MUSIC', '2021/22', 'Gwendolyn Anding', NULL, NULL, NULL, 'VCL'),
	(122, 5, 322, 'PERCUSSION', 'BELL KIT', 'PEARL', 'PK900C', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'BK'),
	(30, 2, 319, 'PERCUSSION', 'BELL KIT', 'PEARL', 'PK900C', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'BK'),
	(92, 4, 321, 'PERCUSSION', 'BELL KIT', 'PEARL', 'PK900C', NULL, NULL, '2022/23', 'Mahori', NULL, NULL, NULL, 'BK'),
	(229, 6, 291, 'PERCUSSION', 'SNARE, MARCHING', 'YAMAHA', 'MS 9014', '1P-3086', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SRM'),
	(482, 31, 526, 'WOODWIND', 'FLUTE', 'ETUDE', NULL, 'D1206521', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(592, 51, 620, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56962', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(594, 52, 460, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54946', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(642, 64, 558, 'WOODWIND', 'FLUTE', 'JUPITER', 'JFL 700', 'DD57954', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(643, 64, 633, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'BF54617', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(646, 65, 559, 'WOODWIND', 'FLUTE', 'JUPITER', 'JFL 700', 'DD58158', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(649, 66, 474, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'BE63671', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(199, 1, 225, 'PERCUSSION', 'TALKING DRUM', 'REMO', 'Small', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TDR'),
	(319, 12, 212, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(343, 14, 178, 'ELECTRIC', 'AMPLIFIER, GUITAR', 'FISHMAN', '494-000-582', 'LCB500-A126704', NULL, NULL, NULL, NULL, NULL, NULL, 'AMG'),
	(401, 20, 374, 'STRING', 'GUITAR, CLASSICAL', 'PARADISE', '20', NULL, NULL, 'yes, no case', 'Amin Hussein', NULL, NULL, NULL, 'GRC'),
	(25, 2, 286, 'PERCUSSION', 'SNARE', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'SR'),
	(354, 15, 181, 'SOUND', 'MIXER', 'YAMAHA', 'MG12XU', 'BGXL01101', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'MX'),
	(473, 30, 383, 'STRING', 'GUITAR, ELECTRIC', 'FENDER', 'CD-60CE Mahogany', '116108513', 'HS MUSIC', '2023/24', 'Gakenia Mucharie', NULL, NULL, NULL, 'GRE'),
	(97, 4, 347, 'STRING', 'GUITAR, BASS', 'SQUIER', 'Modified Jaguar', '15020198', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'GRB'),
	(212, 1, 240, 'PERCUSSION', 'CRADLE, CONCERT CYMBAL', 'GIBRALTAR', 'GIB-7614', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(413, 22, 54, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(421, 23, 55, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(478, 31, 63, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(492, 33, 65, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(503, 35, 67, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(515, 37, 69, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(521, 38, 70, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(248, 1, 381, 'STRING', 'GUITAR, ELECTRIC', 'SQUIER', 'StratPkHSSCAR', '15029891', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'GRE'),
	(250, 1, 396, 'STRING', 'VIOLIN', 'HOFNER', NULL, 'J052107087', 'HS MUSIC', '2023/24', NULL, 'HS MUSIC', NULL, NULL, 'VN'),
	(347, 14, 504, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, '2SP-K90658', NULL, 'Flute damaged, but still works', NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(527, 39, 71, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(533, 40, 72, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(441, 25, 520, 'WOODWIND', 'FLUTE', 'PRELUDE', '711', '28411029', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(539, 41, 73, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(411, 21, 586, 'WOODWIND', 'SAXOPHONE, ALTO', 'BARRINGTON', NULL, 'AS 1010089', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(418, 22, 517, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '28411021', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(419, 22, 587, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11110740', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(35, 2, 386, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '7', NULL, NULL, NULL, NULL, NULL, NULL, 'GRT'),
	(481, 31, 439, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '11299276', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(489, 32, 527, 'WOODWIND', 'FLUTE', 'ETUDE', NULL, 'D1206485', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(490, 32, 600, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54574', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(495, 33, 528, 'WOODWIND', 'FLUTE', 'ETUDE', NULL, 'D1206556', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(545, 42, 74, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(501, 34, 529, 'WOODWIND', 'FLUTE', 'ETUDE', NULL, '206295', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(502, 34, 603, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54336', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(290, 10, 42, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', 'PB17070395', NULL, '2022/23', NULL, NULL, NULL, NULL, 'TNTP'),
	(370, 16, 581, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '362477A', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(504, 35, 116, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '756323', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(507, 35, 530, 'WOODWIND', 'FLUTE', 'ETUDE', NULL, '206261', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(513, 36, 531, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, 'K96124', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(525, 38, 533, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'WD57818', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(526, 38, 607, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54539', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(530, 39, 447, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '1209178', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(536, 40, 448, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '1209179', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(538, 40, 609, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54577', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(542, 41, 449, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '1209180', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(548, 42, 450, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '1209177', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(583, 49, 544, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD59774', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(587, 50, 545, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD59164', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(590, 51, 459, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'KE54774', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(64, 3, 314, 'PERCUSSION', 'BELL SET', 'UNKNOWN', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'BL'),
	(104, 4, 487, 'WOODWIND', 'FLUTE', 'HEIMAR', NULL, 'T479', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(192, 1, 201, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(331, 13, 213, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(344, 14, 214, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(376, 17, 425, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '443788', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(651, 66, 635, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'CF57209', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(269, 8, 364, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKP064163', NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(98, 4, 360, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKP064875', NULL, '2021/22', 'Jihong Joo', 'MS MUSIC', NULL, 11686, 'GRC'),
	(48, 3, 17, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '336151', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(509, 36, 68, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, 'Arhum Bid', NULL, NULL, 11706, 'TNTP'),
	(392, 19, 352, 'STRING', 'GUITAR, ACOUSTIC', 'YAMAHA', 'F 325', '00Y224811', NULL, NULL, NULL, NULL, NULL, NULL, 'GRA'),
	(400, 20, 353, 'STRING', 'GUITAR, ACOUSTIC', 'YAMAHA', 'F 325', '00Y224884', NULL, NULL, NULL, NULL, NULL, NULL, 'GRA'),
	(620, 59, 148, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA14343', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(624, 60, 149, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA033335', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(628, 61, 150, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'BA09439', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(297, 10, 418, 'WOODWIND', 'CLARINET, B FLAT', 'SIGNET', NULL, '30614E', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(310, 11, 419, 'WOODWIND', 'CLARINET, B FLAT', 'VITO', NULL, 'B59862', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(450, 27, 59, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(416, 22, 354, 'STRING', 'GUITAR, ACOUSTIC', 'YAMAHA', 'F 325', '00Y145219', 'HS MUSIC', NULL, NULL, NULL, NULL, NULL, 'GRA'),
	(314, 11, 655, 'WOODWIND', 'SAXOPHONE, TENOR', 'VITO', NULL, '420486', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(457, 28, 60, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(325, 12, 577, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11120110', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(326, 12, 656, 'WOODWIND', 'SAXOPHONE, TENOR', 'BUNDY', NULL, 'TS10050027', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(442, 25, 590, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11110696', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(464, 29, 61, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(431, 24, 245, 'PERCUSSION', 'CONGA', 'YAMAHA', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CG') ON CONFLICT DO NOTHING;
INSERT INTO public.legacy_database (id, number, legacy_number, family, equipment, make, model, serial, class, year, full_name, school_storage, return_2023, student_number, code) VALUES
	(438, 25, 246, 'PERCUSSION', 'CONGA', 'YAMAHA', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CG'),
	(448, 26, 521, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, 'K98973', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(449, 26, 591, 'WOODWIND', 'SAXOPHONE, ALTO', 'CONSERVETE', NULL, '91145', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(455, 27, 522, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, 'P11876', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(316, 12, 44, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(461, 28, 436, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '11299279', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(197, 1, 221, 'PERCUSSION', 'PRACTICE PAD', 'YAMAHA', '4 INCH', 'ISK NO.26', 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'PD'),
	(660, 69, 477, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'BE63692', 'BB1', '2023/24', 'Olivia Patel', NULL, NULL, 10561, 'CL'),
	(540, 41, 128, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, '34928', NULL, '2023/24', 'Ansh Mehta', NULL, NULL, 10657, 'TP'),
	(546, 42, 130, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, '35272', NULL, '2023/24', 'Ainsley Hire', NULL, NULL, 10621, 'TP'),
	(397, 19, 663, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', NULL, 'AF04276', NULL, '2023/24', 'Ean Kimuli', NULL, NULL, 11703, 'SXT'),
	(608, 56, 145, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA04094', 'BB1', '2023/24', 'Etienne Carlevato', NULL, NULL, 12924, 'TP'),
	(508, 35, 604, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54451', NULL, '2023/24', 'Uzima Otieno', NULL, NULL, 13056, 'SXA'),
	(598, 53, 547, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'YD66330', NULL, '2023/24', 'Eliana Hodge', NULL, NULL, 12193, 'FL'),
	(107, 4, 648, 'WOODWIND', 'SAXOPHONE, TENOR', 'YAMAHA', NULL, '26286', 'HS MUSIC', '2022/23', NULL, NULL, NULL, NULL, 'SXT'),
	(352, 15, 47, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, 'MS Band 8', '2022/23', 'Kianu Ruiz Stannah', NULL, NULL, 10247, 'TNTP'),
	(424, 23, 355, 'STRING', 'GUITAR, ACOUSTIC', 'YAMAHA', 'F 325', '00Y224899', 'HS MUSIC', 'yes, no case', NULL, 'HS MUSIC', NULL, NULL, 'GRA'),
	(432, 24, 356, 'STRING', 'GUITAR, ACOUSTIC', 'YAMAHA', 'F 325', '00Y224741', 'HS MUSIC', 'yes, no case', NULL, 'HS MUSIC', NULL, NULL, 'GRA'),
	(142, 9, 194, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CLP 7358', 'BCAZ01088', NULL, NULL, NULL, 'LOWER ES MUSIC', NULL, NULL, 'PE'),
	(588, 50, 619, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56406', 'BB7', '2023/24', 'Luke O''Hara', NULL, NULL, 12063, 'SXA'),
	(667, 2, 281, 'PERCUSSION', 'PRACTICE PAD', 'YAMAHA', '4 INCH', NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'PD'),
	(483, 31, 598, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54370', 'BB1', '2023/24', 'Emilie Wittmann', NULL, NULL, 12428, 'SXA'),
	(639, 63, 632, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'BF54335', 'ES MUSIC', '84 7/24', 'Tawheed Hussain', NULL, NULL, 11469, 'SXA'),
	(605, 55, 463, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54729', 'BB7', '2023/24', 'Lauren Mucci', NULL, NULL, 12694, 'CL'),
	(67, 3, 346, 'STRING', 'GUITAR, BASS', 'FENDER', 'Squire', 'ICS10191321', 'BB8', '2023/24', 'Isla Willis', NULL, NULL, 12969, 'GRB'),
	(5, 2, 82, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'G29437', 'BB8', '2023/24', 'Fatima Zucca', NULL, NULL, 10566, 'TP'),
	(453, 27, 375, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', NULL, NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(385, 18, 426, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '25247', 'BB1', '2023/24', 'Balazs Meyers', NULL, NULL, 12621, 'CL'),
	(462, 28, 523, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, 'K98879', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(467, 29, 437, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '11299280', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(468, 29, 524, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', NULL, 'K99078', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(474, 30, 438, 'WOODWIND', 'CLARINET, B FLAT', 'ETUDE', NULL, '11299277', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(241, 1, 312, 'PERCUSSION', 'BELL SET', 'UNKNOWN', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'BL'),
	(2, 2, 9, 'BRASS', 'HORN, F', 'HOLTON', 'H281', '619468', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'HNF'),
	(36, 2, 397, 'STRING', 'VIOLIN', 'AUBERT', NULL, '3923725', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'VN'),
	(328, 13, 45, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(39, 2, 480, 'WOODWIND', 'CLARINET, BASS', 'VITO', NULL, 'Y3717', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CLB'),
	(4, 2, 34, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(41, 2, 563, 'WOODWIND', 'OBOE', 'BUNDY', NULL, 'B33402', NULL, 'yes', NULL, 'INSTRUMENT STORE', NULL, NULL, 'OB'),
	(42, 2, 565, 'WOODWIND', 'PICCOLO', 'BUNDY', NULL, '12111016', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'PC'),
	(375, 17, 371, 'STRING', 'GUITAR, CLASSICAL', 'PARADISE', '17', NULL, NULL, 'yes, no case', 'Amin Hussein', 'MS MUSIC', NULL, NULL, 'GRC'),
	(384, 18, 372, 'STRING', 'GUITAR, CLASSICAL', 'PARADISE', '18', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(550, 42, 611, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF53790', 'BB8', '2023/24', 'Olivia Freiin von Handel', NULL, NULL, 12096, 'SXA'),
	(193, 1, 216, 'MISCELLANEOUS', 'STAND, GUITAR', 'UNKNOWN', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(200, 1, 226, 'PERCUSSION', 'BELLS, TUBULAR', 'ROSS', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'BLT'),
	(271, 8, 416, 'WOODWIND', 'CLARINET, B FLAT', 'AMATI KRASLICE', NULL, '504869', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(313, 11, 576, 'WOODWIND', 'SAXOPHONE, ALTO', 'BLESSING', NULL, '3468', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(621, 59, 467, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54680', NULL, '2023/24', 'Aisha Awori', NULL, NULL, 10474, 'CL'),
	(425, 23, 431, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '193026A', 'HS MUSIC', '2023/24', 'Fatuma Tall', NULL, NULL, 11515, 'CL'),
	(394, 19, 427, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65020', 'BB1', '2023/24', 'Zayn Khalid', NULL, NULL, 12616, 'CL'),
	(381, 18, 32, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '646721', 'HS MUSIC', '2023/24', 'Andrew Wachira', NULL, NULL, 20866, 'TN'),
	(346, 14, 422, 'WOODWIND', 'CLARINET, B FLAT', 'AMATI KRASLICE', NULL, '206167', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(534, 40, 126, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H35214', 'BB1', '2023/24', 'Masoud Ibrahim', NULL, NULL, 13076, 'TP'),
	(350, 14, 658, 'WOODWIND', 'SAXOPHONE, TENOR', 'ALLORA', NULL, '13120005', 'BB1', '2023/24', 'Ochieng Simbiri', NULL, NULL, 11265, 'SXT'),
	(217, 1, 254, 'PERCUSSION', 'STAND, CYMBAL', 'GIBRALTAR', 'GIB-5710', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(625, 60, 468, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54704', 'BB7', '2023/24', 'Lorian Inglis', NULL, NULL, 12133, 'CL'),
	(233, 1, 296, 'PERCUSSION', 'TIMPANI, 23 INCH', 'LUDWIG', 'LKS423FG', '36264', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TPT'),
	(240, 16, 309, 'PERCUSSION', 'XYLOPHONE', 'MAJESTIC', 'x55 352', '25', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'X'),
	(187, 1, 182, 'SOUND', 'PA SYSTEM, ALL-IN-ONE', 'BEHRINGER', 'EPS500MP3', 'S1402186AA8', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(263, 8, 40, 'BRASS', 'TROMBONE, ALTO - PLASTIC', 'PBONE', 'Mini', 'BM17120387', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNAP'),
	(226, 1, 283, 'PERCUSSION', 'BELLS, SLEIGH', 'WEISS', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'BLS'),
	(267, 8, 208, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(280, 9, 209, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(136, 6, 5, 'BRASS', 'BARITONE/EUPHONIUM', 'YAMAHA', NULL, '533835', 'BB8', '2023/24', 'Saqer Alnaqbi', NULL, NULL, 12909, 'BH'),
	(494, 33, 441, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65382', 'BB8', '2023/24', 'Moussa Sangare', NULL, NULL, 12427, 'CL'),
	(512, 36, 444, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65434', 'BB1', '2023/24', 'Anastasia Mulema', NULL, NULL, 11622, 'CL'),
	(440, 25, 433, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '405117', 'MS Band 8', '2022/23', 'Tangaaza Mujuni', NULL, NULL, 10788, 'CL'),
	(355, 15, 215, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(55, 3, 203, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(216, 1, 253, 'PERCUSSION', 'CYMBALS, HANDHELD 18 INCH', 'ZILDJIAN', '18 Inch Symphonic Viennese Tone', 'ZIL-A0447', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CMZ'),
	(357, 15, 378, 'STRING', 'GUITAR, CUTAWAY', 'UNKNOWN', NULL, NULL, NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRW'),
	(366, 16, 379, 'STRING', 'GUITAR, CUTAWAY', 'UNKNOWN', NULL, NULL, NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRW'),
	(272, 8, 492, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '650122', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(300, 10, 575, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '387824A', NULL, 'present x', NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(653, 67, 475, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'BE63660', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(655, 67, 636, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'CF57086', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(336, 13, 502, 'WOODWIND', 'FLUTE', 'GEMEINHARDT', '2SP', 'K96367', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(154, 6, 489, 'WOODWIND', 'FLUTE', 'EMERSON', 'EF1', '42684', NULL, '2023/24', 'Ji-June', NULL, NULL, NULL, 'FL'),
	(166, 7, 304, 'PERCUSSION', 'TUBANOS', 'REMO', '12 inch', '1-7', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TBN'),
	(426, 23, 518, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '33111112', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(427, 23, 588, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11110695', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(428, 23, 667, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', 'JTS700', 'CF08026', NULL, '2023/24', NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(434, 24, 519, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '28411028', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(435, 24, 589, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11110739', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(302, 11, 25, 'BRASS', 'TROMBONE, TENOR', 'BLESSING', NULL, '452363', NULL, 'x', NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(327, 13, 27, 'BRASS', 'TROMBONE, TENOR', 'ETUDE', NULL, '9120158', NULL, 'x', NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(340, 14, 28, 'BRASS', 'TROMBONE, TENOR', 'ETUDE', NULL, '9120243', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(351, 15, 29, 'BRASS', 'TROMBONE, TENOR', 'ETUDE', NULL, '9120157', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(363, 16, 30, 'BRASS', 'TROMBONE, TENOR', 'ALLORA', NULL, '1107197', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(372, 17, 31, 'BRASS', 'TROMBONE, TENOR', 'ALLORA', NULL, '1107273', NULL, NULL, NULL, 'INSTRUMENT STORE', '7/6/2023', NULL, 'TN'),
	(475, 30, 525, 'WOODWIND', 'FLUTE', 'ETUDE', NULL, 'D1206510', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(566, 46, 78, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(662, 70, 159, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', 'JTR 700', 'CAS15598', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(571, 47, 79, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(638, 63, 557, 'WOODWIND', 'FLUTE', 'JUPITER', 'JFL 700', 'DD58225', 'BB8', '2023/24', 'Malan Chopra', NULL, NULL, 10508, 'FL'),
	(522, 38, 122, 'BRASS', 'TRUMPET, B FLAT', 'ETUDE', NULL, '124911', NULL, '2022/23', 'Mark Anding', NULL, NULL, NULL, 'TP'),
	(562, 45, 134, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA08653', 'BB7', '2023/24', 'Connor Fort', NULL, NULL, 11650, 'TP'),
	(44, 2, 641, 'WOODWIND', 'SAXOPHONE, BARITONE', 'VIENNA', NULL, 'B15217', NULL, '2023/24', 'Fatuma Tall', NULL, NULL, 11515, 'SXB'),
	(576, 48, 80, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(560, 44, 613, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56401', NULL, '2023/24', 'Emiel Ghelani-Decorte', NULL, NULL, 12674, 'SXA'),
	(90, 4, 302, 'PERCUSSION', 'TUBANOS', 'REMO', '14 inch', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TBN'),
	(429, 24, 56, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(81, 4, 36, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(171, 7, 490, 'WOODWIND', 'FLUTE', 'WT.AMSTRONG', '104', '2922376', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(175, 1, 7, 'BRASS', 'BARITONE/TENOR HORN', 'BESSON', NULL, '575586', NULL, 'x', NULL, 'INSTRUMENT STORE', NULL, NULL, 'BT'),
	(177, 1, 13, 'BRASS', 'MELLOPHONE', 'JUPITER', NULL, 'L02630', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'M'),
	(182, 1, 160, 'BRASS', 'TRUMPET, POCKET', 'ALLORA', NULL, 'PT1309020', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TPP'),
	(251, 1, 401, 'WOODWIND', 'BASSOON', 'UNKNOWN', NULL, '33CVC02', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'BS'),
	(111, 5, 37, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(255, 1, 479, 'WOODWIND', 'CLARINET, BASS', 'VITO', NULL, '18250', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CLB'),
	(180, 1, 33, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP'),
	(257, 1, 562, 'WOODWIND', 'OBOE', 'BUNDY', NULL, 'B33327', NULL, 'yes needs repair', NULL, 'INSTRUMENT STORE', NULL, NULL, 'OB'),
	(258, 1, 564, 'WOODWIND', 'PICCOLO', 'BUNDY', NULL, '11010007', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'PC'),
	(259, 1, 566, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11120071', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(284, 9, 417, 'WOODWIND', 'CLARINET, B FLAT', 'BUNDY', NULL, '989832', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(131, 5, 483, 'WOODWIND', 'CLARINET, BASS', 'JUPITER', 'JBC 1000', 'CE69047', 'BB8', '2023/24', 'Mikael Eshetu', NULL, NULL, 12689, 'CLB'),
	(288, 9, 653, 'WOODWIND', 'SAXOPHONE, TENOR', 'SELMER', NULL, 'N495304', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(339, 13, 657, 'WOODWIND', 'SAXOPHONE, TENOR', 'BUNDY', NULL, 'TS10050022', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(599, 53, 622, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'YF57624', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(451, 27, 107, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H34971', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(61, 3, 287, 'PERCUSSION', 'SNARE', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SR'),
	(143, 6, 206, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(163, 7, 207, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(138, 6, 38, 'BRASS', 'TROMBONE, ALTO - PLASTIC', 'PBONE', 'Mini', 'BM18030151', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNAP'),
	(77, 3, 647, 'WOODWIND', 'SAXOPHONE, TENOR', 'YAMAHA', NULL, '31840', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXT'),
	(152, 6, 413, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '7943', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(433, 24, 432, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '444451', NULL, '2021/22', NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(16, 2, 243, 'PERCUSSION', 'CONGA', 'MEINL', 'HEADLINER RANGE', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG'),
	(532, 39, 608, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54476', NULL, '2023/24', 'Tobias Godfrey', NULL, NULL, 11227, 'SXA'),
	(634, 62, 556, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'BD62736', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(635, 62, 631, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'BF54273', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(637, 63, 471, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'YE67775', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(641, 64, 472, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'YE67468', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(657, 68, 476, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'BE63558', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(601, 54, 462, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE50000', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(606, 55, 549, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'YD66218', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(610, 56, 550, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'YD66291', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(613, 57, 465, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54699', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(615, 57, 626, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'AF53354', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(617, 58, 466, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54697', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(618, 58, 552, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'BD62678', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(619, 58, 627, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'AF53345', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(622, 59, 553, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'BD63526', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(626, 60, 554, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'BD63433', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(631, 61, 630, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'BF54625', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(633, 62, 470, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'YE67470', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(658, 68, 637, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'CF57292', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(661, 69, 638, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'CF57202', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(664, 70, 639, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'CF56658', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(15, 2, 238, 'PERCUSSION', 'CLAVES', 'LP', 'GRENADILLA', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CLV'),
	(17, 2, 251, 'PERCUSSION', 'COWBELL', 'LP', 'Black Beauty', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CWB'),
	(76, 3, 642, 'WOODWIND', 'SAXOPHONE, BARITONE', 'JUPITER', 'JBS 1000', 'XF05936', NULL, NULL, NULL, 'PIANO ROOM', NULL, NULL, 'SXB'),
	(612, 57, 146, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA04125', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(514, 36, 605, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF53797', 'HS MUSIC', '2023/24', 'Thomas Higgins', NULL, NULL, 11744, 'SXA'),
	(26, 2, 293, 'PERCUSSION', 'TAMBOURINE', 'REMO', 'Fiberskyn 3 black', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TR'),
	(11, 2, 199, 'KEYBOARD', 'PIANO, UPRIGHT', 'EAVESTAFF', NULL, NULL, NULL, NULL, NULL, 'PRACTICE ROOM 2', NULL, NULL, 'PU'),
	(54, 3, 200, 'KEYBOARD', 'PIANO, UPRIGHT', 'SPENCER', NULL, NULL, NULL, NULL, NULL, 'PRACTICE ROOM 3', NULL, NULL, 'PU'),
	(573, 47, 455, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'KE56579', 'BB1', '2023/24', 'Owen Harris', NULL, NULL, 12609, 'CL'),
	(223, 1, 272, 'PERCUSSION', 'QUAD, MARCHING', 'PEARL', 'Black', '202902', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'Q'),
	(249, 1, 385, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '11', NULL, NULL, NULL, NULL, NULL, NULL, 'GRT'),
	(69, 3, 387, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '9', NULL, 'under repair', NULL, 'PRACTICE ROOM 3', NULL, NULL, 'GRT'),
	(21, 2, 267, 'PERCUSSION', 'EGG SHAKERS', 'LP', 'Black 2 pr', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'EGS'),
	(22, 2, 271, 'PERCUSSION', 'MARACAS', 'LP', 'Pro Yellow Light Handle', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'MRC'),
	(293, 10, 210, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(306, 11, 211, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(160, 7, 87, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '638871', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(181, 1, 81, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '808845', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(237, 1, 306, 'PERCUSSION', 'WOOD BLOCK', 'BLACK SWAMP', 'BLA-MWB1', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'WB'),
	(7, 2, 166, 'ELECTRIC', 'AMPLIFIER', 'GALLEN-K', NULL, '72168', 'MS Band 7', '2022/23', NULL, 'MS MUSIC', NULL, NULL, 'AM'),
	(242, 1, 317, 'PERCUSSION', 'CYMBAL, SUSPENDED 18 INCH', 'ZILDJIAN', 'Orchestral Selection ZIL-A0419', 'AD 69101 046', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CMS'),
	(109, 5, 12, 'BRASS', 'HORN, F', 'JUPITER', 'JHR1100', 'BC00278', 'BB8', '2023/24', 'Kai O''Bra', NULL, NULL, 12342, 'HNF'),
	(125, 5, 348, 'STRING', 'GUITAR, BASS', 'FENDER', NULL, 'CGF1307326', NULL, '2023/24', NULL, 'DRUM ROOM 1', NULL, NULL, 'GRB'),
	(99, 4, 388, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '4', NULL, NULL, NULL, 'PRACTICE ROOM 3', NULL, NULL, 'GRT'),
	(83, 4, 168, 'ELECTRIC', 'AMPLIFIER, BASS', 'FENDER', 'BASSMAN', 'M 1053205', NULL, NULL, NULL, 'DRUM ROOM 1', NULL, NULL, 'AMB'),
	(341, 14, 46, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TNTP'),
	(283, 9, 393, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '8', NULL, NULL, NULL, NULL, NULL, NULL, 'GRT'),
	(86, 4, 247, 'PERCUSSION', 'CONGA', 'LATIN PERCUSSION', '12 inch', 'ISK 3120157238', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG'),
	(116, 5, 248, 'PERCUSSION', 'CONGA', 'LATIN PERCUSSION', '14 Inch', 'ISK 23 JAN 02', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG'),
	(57, 3, 244, 'PERCUSSION', 'CONGA', 'LATIN PERCUSSION', '10 Inch', 'ISK 3120138881', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG'),
	(144, 6, 249, 'PERCUSSION', 'CONGA', 'LATIN PERCUSSION', '10 Inch', 'ISK 312138881', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG'),
	(165, 7, 250, 'PERCUSSION', 'CONGA', 'LATIN PERCUSSION', '10 Inch', 'ISK 312120138881', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG'),
	(47, 3, 10, 'BRASS', 'HORN, F', 'HOLTON', NULL, '602', 'HS MUSIC', '2023/24', 'Jamison Line', NULL, NULL, 11625, 'HNF'),
	(214, 1, 242, 'PERCUSSION', 'CONGA', 'YAMAHA', 'Red 14 inch', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG'),
	(170, 7, 415, 'WOODWIND', 'CLARINET, B FLAT', 'VITO', NULL, 'B 859866/7112-STORE', NULL, NULL, NULL, NULL, NULL, NULL, 'CL'),
	(188, 1, 183, 'KEYBOARD', 'KEYBOARD', 'ROLAND', '813', 'AH24202', NULL, NULL, NULL, NULL, NULL, NULL, 'KB'),
	(29, 2, 313, 'PERCUSSION', 'BELL SET', 'UNKNOWN', NULL, NULL, 'BB8', '2023/24', 'Selma Mensah', NULL, NULL, 12392, 'BL'),
	(565, 45, 614, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF57089', 'MS Band 5', '2022/23', 'Fatuma Tall', NULL, NULL, 11515, 'SXA'),
	(570, 46, 615, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF57192', 'BB1', '2023/24', 'Max Stock', NULL, NULL, 12915, 'SXA'),
	(647, 65, 634, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'BF54604', 'HS MUSIC', '2023/24', 'Ethan Sengendo', NULL, NULL, 11702, 'SXA'),
	(630, 61, 555, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'BD62784', 'BB1', '2023/24', 'Nora Saleem', NULL, NULL, 12619, 'FL'),
	(159, 7, 39, 'BRASS', 'TROMBONE, ALTO - PLASTIC', 'PBONE', 'Mini', 'BM17120413', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNAP'),
	(277, 9, 41, 'BRASS', 'TROMBONE, ALTO - PLASTIC', 'PBONE', 'Mini', 'BM17120388', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNAP'),
	(59, 3, 264, 'PERCUSSION', 'DRUMSET', 'PEARL', 'Vision', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DK'),
	(93, 4, 325, 'PERCUSSION', 'SNARE', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'SR'),
	(70, 3, 398, 'STRING', 'VIOLIN', 'WILLIAM LEWIS & SON', NULL, 'D 0933 1998', NULL, '2023/24', 'Gakenia Mucharie', NULL, NULL, NULL, 'VN'),
	(85, 4, 204, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(115, 5, 205, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(224, 1, 274, 'PERCUSSION', 'SNARE, MARCHING', 'YAMAHA', 'MS 9014', '1P-3095', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'SRM'),
	(184, 1, 164, 'BRASS', 'SOUSAPHONE', 'YAMAHA', NULL, '910530', NULL, NULL, NULL, 'MS MUSIC', '7/6/2023', NULL, 'SSP'),
	(262, 8, 22, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '320963', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TN') ON CONFLICT DO NOTHING;
INSERT INTO public.legacy_database (id, number, legacy_number, family, equipment, make, model, serial, class, year, full_name, school_storage, return_2023, student_number, code) VALUES
	(74, 3, 486, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '600365', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(289, 10, 24, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '316975', NULL, '2022/23', 'Margaret Oganda', NULL, NULL, NULL, 'TN'),
	(132, 5, 488, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '452046A', NULL, NULL, NULL, 'MS MUSIC', 'MS', NULL, 'FL'),
	(476, 30, 596, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54480', 'ES MUSIC', '2021/22', 'Magaret Oganda', NULL, NULL, NULL, 'SXA'),
	(480, 31, 384, 'STRING', 'GUITAR, ELECTRIC', 'FENDER', 'CD-60CE Mahogany', '116108578', NULL, 'yes', 'Angel Gray', NULL, NULL, NULL, 'GRE'),
	(278, 9, 89, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '556519', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(519, 37, 532, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, 'AP28041129', NULL, 'PRESENT', NULL, NULL, NULL, NULL, 'FL'),
	(304, 11, 91, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '554189', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(623, 59, 628, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'AF53348', NULL, '2023/24', 'Reuben Szuchman', NULL, NULL, 12667, 'SXA'),
	(609, 56, 464, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54692', 'BB8', '2023/24', 'Lilla Vestergaard', NULL, NULL, 11266, 'CL'),
	(1, 2, 1, 'BRASS', 'BARITONE/EUPHONIUM', 'BOOSEY & HAWKES', 'Soveriegn', '601249', 'HS MUSIC', '2023/24', 'Kasra Feizzadeh', 'PIANO ROOM', NULL, 12871, 'BH'),
	(578, 48, 456, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'KE56608', 'BB7', '2023/24', 'Ariel Mutombo', NULL, NULL, 12549, 'CL'),
	(353, 15, 95, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '634070', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(472, 30, 110, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '501720', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(479, 31, 111, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '645447', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP'),
	(174, 7, 651, 'WOODWIND', 'SAXOPHONE, TENOR', 'YAMAHA', NULL, '10355', NULL, '2022', 'Noah Ochomo', NULL, NULL, NULL, 'SXT'),
	(183, 1, 161, 'BRASS', 'TUBA', 'YAMAHA', NULL, '106508', NULL, 'Mark Class', NULL, 'MS MUSIC', '7/6/2023', NULL, 'TB'),
	(168, 7, 363, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKZ104831', NULL, 'yes, no case', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(379, 17, 582, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '388666A', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(388, 18, 583, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', 'YAS 23', 'T14584', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(402, 20, 428, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65540', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(213, 1, 241, 'PERCUSSION', 'SNARE, CONCERT', 'BLACK SWAMP', 'BLA-CM514BL', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'SRC'),
	(146, 6, 297, 'PERCUSSION', 'TIMPANI, 23 INCH', 'LUDWIG', 'LKS423FG', '52479', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TPT'),
	(225, 1, 282, 'PERCUSSION', 'SHIELD', 'GIBRALTAR', 'GIB-GDS-5', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(595, 52, 621, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'YF57348', NULL, '2022/23', 'Mark Anding', NULL, '7/6/2023', NULL, 'SXA'),
	(486, 32, 112, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '638850', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TP'),
	(666, 1, 280, 'PERCUSSION', 'PRACTICE KIT', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'PK'),
	(586, 50, 458, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'KE54751', 'BB7', '2023/24', 'Seung Hyun Nam', NULL, NULL, 13080, 'CL'),
	(145, 6, 261, 'PERCUSSION', 'DJEMBE', 'CUSTOM', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DJ'),
	(87, 4, 259, 'PERCUSSION', 'DJEMBE', 'CUSTOM', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'DJ'),
	(56, 3, 224, 'PERCUSSION', 'RAINSTICK', 'CUSTOM', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'RK'),
	(66, 3, 331, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(580, 48, 617, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56283', 'ES ROOM', NULL, 'Vanaaya Patel', NULL, NULL, 20839, 'SXA'),
	(575, 47, 616, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF57296', 'BB7', '2023/24', 'Yonatan Wondim Belachew Andersen', NULL, NULL, 12967, 'SXA'),
	(208, 1, 235, 'PERCUSSION', 'CASTANETS', 'DANMAR', 'DAN-17A', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CST'),
	(113, 5, 169, 'ELECTRIC', 'AMPLIFIER, BASS', 'ROLAND', 'CUBE-100', 'AX78271', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'AMB'),
	(349, 14, 579, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '290365', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(201, 1, 227, 'PERCUSSION', 'VIBRASLAP', 'WEISS', 'SW-VIBRA', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'VS'),
	(13, 2, 223, 'PERCUSSION', 'RAINSTICK', 'CUSTOM', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'RK'),
	(31, 2, 330, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(96, 4, 332, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(124, 5, 333, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(149, 6, 334, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(167, 7, 335, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(52, 3, 167, 'ELECTRIC', 'AMPLIFIER, BASS', 'FENDER', 'Rumble 25', 'ICTB15016929', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'AMB'),
	(100, 4, 399, 'STRING', 'VIOLIN', 'ANDREAS EASTMAN', NULL, 'V2024618', 'HS MUSIC', '2023/24', NULL, 'HS MUSIC', NULL, NULL, 'VN'),
	(27, 2, 298, 'PERCUSSION', 'TIMPANI, 26 INCH', 'LUDWIG', 'SUD-LKS426FG', '51734', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TPD'),
	(128, 5, 400, 'STRING', 'VIOLIN', 'ANDREAS EASTMAN', NULL, 'V2025159', 'HS MUSIC', '2023/24', NULL, 'HS MUSIC', NULL, NULL, 'VN'),
	(123, 5, 326, 'PERCUSSION', 'TIMPANI, 29 INCH', 'LUDWIG', NULL, '36346', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TPN'),
	(161, 7, 172, 'ELECTRIC', 'AMPLIFIER, GUITAR', 'FENDER', 'Frontman 15G', 'ICTB1500267', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'AMG'),
	(205, 1, 232, 'PERCUSSION', 'MOUNTING BRACKET, BELL TREE', 'TREEWORKS', 'TW-TRE52', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(94, 4, 327, 'PERCUSSION', 'TIMPANI, 32 INCH', 'LUDWIG', NULL, '36301', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TPW'),
	(231, 1, 294, 'PERCUSSION', 'TAMBOURINE, 10 INCH', 'PEARL', 'Symphonic Double Row PEA-PETM1017', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TRT'),
	(198, 1, 222, 'PERCUSSION', 'RAINSTICK', 'CUSTOM', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'RK'),
	(244, 1, 329, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(268, 8, 336, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(185, 1, 165, 'ELECTRIC', 'AMPLIFIER', 'FENDER', NULL, 'M 1134340', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'AM'),
	(203, 1, 229, 'PERCUSSION', 'BASS DRUM', 'LUDWIG', NULL, '3442181', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'BD'),
	(63, 18, 311, 'PERCUSSION', 'XYLOPHONE', 'DII', 'Decator', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'X'),
	(279, 9, 174, 'ELECTRIC', 'AMPLIFIER, KEYBOARD', 'PEAVEY', NULL, 'ODB#1230169', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'AMK'),
	(409, 21, 429, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65851', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(500, 34, 442, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65593', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(95, 19, 328, 'PERCUSSION', 'XYLOPHONE', 'UNKNOWN', NULL, '660845710719', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'X'),
	(186, 1, 179, 'SOUND', 'MICROPHONE', 'SHURE', 'SM58', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(206, 1, 233, 'PERCUSSION', 'CABASA', 'LP', 'LP234A', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CBS'),
	(220, 1, 268, 'PERCUSSION', 'GUIRO', 'LP', 'Super LP243', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'GUR'),
	(204, 1, 231, 'PERCUSSION', 'BELL TREE', 'TREEWORKS', 'TW-TRE35', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'BLR'),
	(222, 1, 270, 'PERCUSSION', 'MARACAS', 'WEISS', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'MRC'),
	(506, 35, 443, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65299', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(137, 6, 20, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '071009A', NULL, 'x', NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(234, 1, 300, 'PERCUSSION', 'TRIANGLE', 'ALAN ABEL', '6" Inch Symphonic', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TGL'),
	(209, 3, 236, 'PERCUSSION', 'CLAVES', 'LP', 'GRENADILLA', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CLV'),
	(321, 12, 368, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKPO64008', NULL, 'yes, no case', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(333, 13, 369, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKP054554', NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(312, 11, 499, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '617224', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(322, 12, 420, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '7980', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(447, 26, 434, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'B88822', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(37, 2, 405, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '206603A', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(40, 2, 485, 'WOODWIND', 'FLUTE', 'YAMAHA', '222', '826706', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(317, 12, 92, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '678970', 'BB8', '2023/24', 'Ignacio Biafore', NULL, NULL, 12170, 'TP'),
	(196, 1, 220, 'PERCUSSION', 'COWBELL', 'LP', 'Black Beauty', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'CWB'),
	(281, 9, 337, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(294, 10, 338, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(307, 11, 339, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(320, 12, 340, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(332, 13, 341, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(345, 14, 342, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(305, 11, 171, 'ELECTRIC', 'AMPLIFIER, BASS', 'PEAVEY', 'TKO-230EU', 'OJBHE2300098', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'AMB'),
	(356, 15, 343, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X'),
	(398, 20, 52, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TNTP'),
	(406, 21, 53, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TNTP'),
	(443, 26, 58, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TNTP'),
	(436, 25, 57, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'KAIZER', NULL, NULL, NULL, '2022/23', 'Mark Anding', 'MS MUSIC', NULL, NULL, 'TNTP'),
	(238, 2, 307, 'PERCUSSION', 'WOOD BLOCK', 'LP', 'PLASTIC RED', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'WB'),
	(446, 26, 380, 'STRING', 'GUITAR, ELECTRIC', 'FENDER', 'CD-60CE Mahogany', '115085004', 'HS MUSIC', 'Yes,with case', NULL, 'HS MUSIC', NULL, NULL, 'GRE'),
	(239, 3, 308, 'PERCUSSION', 'WOOD BLOCK', 'LP', 'PLASTIC BLUE', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'WB'),
	(221, 2, 269, 'PERCUSSION', 'GUIRO', 'LP', 'Plastic', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'GUR'),
	(28, 17, 310, 'PERCUSSION', 'XYLOPHONE', 'ROSS', '410', '587', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'X'),
	(465, 29, 109, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'G27536', NULL, '2023/24', 'Noah Ochomo', NULL, NULL, NULL, 'TP'),
	(420, 22, 666, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', 'JTS700', 'CF07965', NULL, '2023/24', 'Tawheed Hussain', 'MS MUSIC', NULL, 11469, 'SXT'),
	(405, 20, 664, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', 'JTS700', 'CF07952', NULL, '2023/24', 'Mark Anding', 'MS MUSIC', NULL, NULL, 'SXT'),
	(393, 19, 373, 'STRING', 'GUITAR, CLASSICAL', 'PARADISE', '19', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(412, 21, 665, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', 'JTS700', 'CF07553', NULL, '2023/24', 'Naomi Yohannes', NULL, NULL, 10787, 'SXT'),
	(496, 33, 602, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54322', NULL, '2022/23', 'Noah Ochomo', NULL, NULL, NULL, 'SXA'),
	(399, 20, 100, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H31438', NULL, '2023/24', 'Maria Agenorwot', NULL, NULL, 13018, 'TP'),
	(493, 33, 113, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'F19277', 'BB8', '2023/24', 'Kush Tanna', NULL, NULL, 11096, 'TP'),
	(554, 43, 538, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'WD62183', NULL, '2022/23', 'Mark Anding', NULL, NULL, NULL, 'FL'),
	(151, 6, 390, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '3', NULL, 'yes', NULL, 'PRACTICE ROOM 3', NULL, NULL, 'GRT'),
	(568, 46, 454, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'KE56526', NULL, '2023/24', 'Noah Ochomo', NULL, NULL, NULL, 'CL'),
	(439, 25, 382, 'STRING', 'GUITAR, ELECTRIC', 'FENDER', 'CD-60CE Mahogany', '115085034', NULL, 'yes, no case', NULL, NULL, NULL, NULL, 'GRE'),
	(118, 5, 266, 'PERCUSSION', 'DRUMSET, ELECTRIC', 'ALESIS', 'DM8', '694318011177', NULL, NULL, NULL, 'DRUM ROOM 2', NULL, NULL, 'DKE'),
	(179, 1, 15, 'BRASS', 'TROMBONE, TENOR', 'HOLTON', 'TR259', '970406', NULL, 'x', NULL, 'MS MUSIC', NULL, NULL, 'TN'),
	(190, 1, 197, 'KEYBOARD', 'PIANO, GRAND', 'GEBR. PERZINO', 'GBT 175', '302697', NULL, NULL, NULL, 'PIANO ROOM', NULL, NULL, 'PG'),
	(191, 1, 198, 'KEYBOARD', 'PIANO, UPRIGHT', 'ELSENBERG', NULL, NULL, NULL, NULL, NULL, 'PRACTICE ROOM 1', NULL, NULL, 'PU'),
	(169, 7, 391, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '1', NULL, 'yes', NULL, 'PRACTICE ROOM 3', NULL, NULL, 'GRT'),
	(604, 55, 144, 'BRASS', 'TRUMPET, B FLAT', 'BACH', NULL, '488350', 'BB8', '2023/24', 'Kaisei Stephens', NULL, NULL, 11804, 'TP'),
	(270, 8, 392, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '12', NULL, 'yes', NULL, 'PRACTICE ROOM 3', NULL, NULL, 'GRT'),
	(309, 11, 395, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '6', NULL, 'yes', NULL, 'PRACTICE ROOM 3', NULL, NULL, 'GRT'),
	(202, 1, 228, 'PERCUSSION', 'AGOGO BELL', 'LP', '577 Dry', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'AGG'),
	(230, 1, 292, 'PERCUSSION', 'TAMBOURINE', 'MEINL', 'Open face', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TR'),
	(147, 6, 323, 'PERCUSSION', 'BELL KIT', 'PEARL', 'PK900C', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'BK'),
	(243, 1, 318, 'PERCUSSION', 'BELL KIT', 'PEARL', 'PK900C', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'BK'),
	(227, 2, 284, 'PERCUSSION', 'BELLS, SLEIGH', 'LUDWIG', 'Red Handle', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'BLS'),
	(665, 1, 279, 'PERCUSSION', 'TOM, MARCHING', 'PEARL', NULL, '6 PAIRS', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'TTM'),
	(195, 2, 218, 'MISCELLANEOUS', 'STAND, MUSIC', 'GMS', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(236, 1, 305, 'PERCUSSION', 'WIND CHIMES', 'LP', 'LP236D', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'WC'),
	(235, 2, 301, 'PERCUSSION', 'TRIANGLE', 'ALAN ABEL', '6 inch', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TGL'),
	(207, 2, 234, 'PERCUSSION', 'CABASA', 'LP', 'Small', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CBS'),
	(12, 2, 202, 'MISCELLANEOUS', 'HARNESS', 'PEARL', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, NULL),
	(210, 1, 237, 'PERCUSSION', 'CLAVES', 'KING', NULL, NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CLV'),
	(460, 28, 376, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', '265931HRJ', NULL, 'yes, no case', NULL, 'INSTRUMENT STORE', NULL, NULL, 'GRC'),
	(157, 7, 6, 'BRASS', 'BARITONE/EUPHONIUM', 'YAMAHA', NULL, '534386', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'BH'),
	(150, 6, 362, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKPO065675', NULL, 'yes, no case', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(253, 1, 403, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '206681A', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(256, 1, 484, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '609368', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL'),
	(338, 13, 578, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '352128A', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA'),
	(110, 5, 19, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '334792', NULL, 'x', NULL, 'INSTRUMENT STORE', NULL, NULL, 'TN'),
	(103, 4, 482, 'WOODWIND', 'CLARINET, BASS', 'YAMAHA', 'Hex 1000', 'YE 69248', NULL, '2023/24', 'Gwendolyn Anding', NULL, NULL, NULL, 'CLB'),
	(287, 9, 574, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '348075', 'MS band 8', NULL, 'Mwende Mittelstadt', NULL, NULL, 11098, 'SXA'),
	(84, 4, 191, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CAP 320', 'YCQM01249', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'PE'),
	(315, 12, 26, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '406896', 'HS MUSIC', '2023/24', 'Marco De Vries Aguirre', NULL, NULL, 11551, 'TN'),
	(71, 3, 407, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '7291', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL'),
	(73, 3, 481, 'WOODWIND', 'CLARINET, BASS', 'YAMAHA', NULL, '43084', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CLB'),
	(10, 2, 189, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CVP303x', 'GBRCKK 01006', NULL, NULL, NULL, 'MUSIC OFFICE', NULL, NULL, 'PE'),
	(53, 3, 190, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CVP 87A', '7163', NULL, NULL, NULL, 'MUSIC OFFICE', NULL, NULL, 'PE'),
	(295, 10, 366, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKP064183', NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(247, 1, 357, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKZ107832', NULL, '?', NULL, NULL, NULL, NULL, 'GRC'),
	(34, 2, 358, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKZ034412', NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(68, 3, 359, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKP065151', NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(335, 13, 421, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '27303', NULL, '2023/24', 'Naia Friedhoff Jaeschke', NULL, NULL, 11822, 'CL'),
	(80, 4, 18, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '406948', 'BB1', '2023/24', 'Arhum Bid', NULL, NULL, 11706, 'TN'),
	(301, 10, 654, 'WOODWIND', 'SAXOPHONE, TENOR', 'YAMAHA', NULL, '063739A', 'BB7', '2023/24', 'Finlay Haswell', NULL, NULL, 10562, 'SXT'),
	(276, 9, 23, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '303168', NULL, 'xx', 'Zameer Nanji', 'MS MUSIC', NULL, 10416, 'TN'),
	(579, 48, 543, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD59816', 'HS MUSIC', '2023/24', 'Teagan Wood', NULL, NULL, 10972, 'FL'),
	(645, 65, 473, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'YE67756', 'BB8', '2023/24', 'Gaia Bonde-Nielsen', NULL, NULL, 12537, 'CL'),
	(611, 56, 625, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'AF53425', NULL, '2023/24', 'Milan Jayaram', NULL, NULL, 10493, 'SXA'),
	(552, 43, 132, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'WA26516', 'BB7', '2023/24', 'Anaiya Khubchandani', NULL, NULL, 11262, 'TP'),
	(389, 18, 662, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', 'JTS710', 'YF06601', NULL, '2023/24', 'Gunnar Purdy', NULL, NULL, 12349, 'SXT'),
	(531, 39, 534, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'WD62211', 'HS MUSIC', '2023/24', 'Leo Cutler', NULL, NULL, 10673, 'FL'),
	(537, 40, 535, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'WD62108', 'BB7', '2023/24', 'Yoonseo Choi', NULL, NULL, 10708, 'FL'),
	(543, 41, 536, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'WD62303', 'BB8', '2023/24', 'Julian Dibling', NULL, NULL, 12883, 'FL'),
	(371, 16, 660, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', NULL, '3847', 'HS MUSIC', '2023/24', 'Adam Kone', NULL, NULL, 11368, 'SXT'),
	(498, 34, 114, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '511564', 'BB8', '2023/24', 'Aiden D''Souza', 'PIANO ROOM', NULL, 12500, 'TP'),
	(380, 17, 661, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', NULL, 'XF03739', 'HS MUSIC', '2023/24', 'Rohan Giri', NULL, NULL, 12410, 'SXT'),
	(373, 17, 49, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', 'PR18100094', 'BB7', '2023/24', 'Lilyrose Trottier', NULL, NULL, 11944, 'TNTP'),
	(516, 37, 120, 'BRASS', 'TRUMPET, B FLAT', 'ETUDE', NULL, '124816', 'BB1', '2023/24', 'Masoud Ibrahim', NULL, NULL, 13076, 'TP'),
	(520, 37, 606, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54452', 'BB7', '2023/24', 'Tanay Cherickel', NULL, '7/6/2023', 13007, 'SXA'),
	(463, 28, 593, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54181', 'BB8', '2023/24', 'Romilly Haysmith', NULL, NULL, 12976, 'SXA'),
	(252, 1, 402, 'WOODWIND', 'CLARINET, ALTO IN E FLAT', 'YAMAHA', NULL, '1260', NULL, '2024/25', 'Mark Anding', NULL, NULL, NULL, 'CLE'),
	(544, 41, 610, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54140', 'BB1', '2023/24', 'Lucile Bamlango', NULL, NULL, 10977, 'SXA'),
	(126, 5, 361, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKZ114314', NULL, 'yes', NULL, 'MS MUSIC', NULL, NULL, 'GRC'),
	(88, 4, 265, 'PERCUSSION', 'DRUMSET', 'YAMAHA', NULL, 'SBB2217', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'DK'),
	(329, 13, 93, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '553853', NULL, '2023/24', 'Natéa Firzé Al Ghaoui', NULL, NULL, 12190, 'TP'),
	(20, 2, 263, 'PERCUSSION', 'DRUMSET', 'YAMAHA', NULL, NULL, NULL, NULL, NULL, 'DRUM ROOM 1', NULL, NULL, 'DK'),
	(148, 6, 324, 'PERCUSSION', 'DRUMSET', 'YAMAHA', NULL, NULL, NULL, NULL, NULL, 'DRUM ROOM 2', NULL, NULL, 'DK'),
	(129, 5, 411, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '27251', NULL, '2022/23', 'Mark Anding', NULL, NULL, NULL, 'CL'),
	(264, 8, 88, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '806725', NULL, '2023/24', 'Arjan Arora', NULL, NULL, 12130, 'TP'),
	(266, 8, 196, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', NULL, NULL, NULL, NULL, NULL, 'DANCE STUDIO', NULL, NULL, 'PE'),
	(408, 21, 185, 'KEYBOARD', 'KEYBOARD', 'YAMAHA', 'PSR 220', '913094', NULL, NULL, NULL, NULL, NULL, NULL, 'KB'),
	(415, 22, 186, 'KEYBOARD', 'KEYBOARD', 'YAMAHA', 'PSR 83', '13143', NULL, NULL, NULL, NULL, NULL, NULL, 'KB'),
	(417, 22, 430, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J07292', NULL, '2022/23', 'Kevin Keene', 'HS MUSIC', NULL, NULL, 'CL'),
	(518, 37, 445, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65342', 'HS MUSIC', '2023/24', 'Lo', NULL, NULL, NULL, 'CL'),
	(524, 38, 446, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65493', 'HS MUSIC', '2023/24', 'Vashnie Joymungul', NULL, NULL, 12996, 'CL'),
	(3, 2, 16, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '406538', NULL, '2023/24', 'Anne Bamlango', NULL, NULL, 10978, 'TN'),
	(282, 9, 365, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKP064005', NULL, 'just the case', 'Finola Doherty', 'MS MUSIC', NULL, NULL, 'GRC'),
	(308, 11, 367, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', 'HKP054553', NULL, 'Checked out', 'Marwa Baker', 'MS MUSIC', NULL, NULL, 'GRC'),
	(32, 2, 345, 'STRING', 'GUITAR, BASS', 'YAMAHA', 'BB1000', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'GRB'),
	(164, 7, 219, 'MISCELLANEOUS', 'PEDAL, SUSTAIN', 'YAMAHA', 'FC4', NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, NULL),
	(114, 5, 192, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CAP 329', 'YCQN01006', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'PE'),
	(121, 5, 316, 'PERCUSSION', 'BELL SET', 'YAMAHA', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'BL'),
	(141, 6, 193, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'P-95', 'EBQN02222', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'PE'),
	(219, 1, 262, 'PERCUSSION', 'DRUMSET', 'YAMAHA', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'DK'),
	(211, 1, 239, 'PERCUSSION', 'BELLS, CONCERT', 'YAMAHA', 'YG-250D Standard', '112158', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'BLC'),
	(403, 20, 515, 'WOODWIND', 'FLUTE', 'YAMAHA', NULL, '917792', 'MS band 8', '2022/23', NULL, 'MS MUSIC', '7/6/2023', NULL, 'FL'),
	(452, 27, 289, 'PERCUSSION', 'SNARE', 'YAMAHA', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'SR'),
	(459, 28, 290, 'PERCUSSION', 'SNARE', 'YAMAHA', NULL, NULL, 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'SR'),
	(6, 2, 162, 'BRASS', 'TUBA', 'YAMAHA', NULL, '533558', NULL, NULL, NULL, 'MS MUSIC', '7/6/2023', NULL, 'TB'),
	(14, 2, 230, 'PERCUSSION', 'BASS DRUM', 'YAMAHA', 'CB628', 'PO-1575', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'BD'),
	(466, 29, 377, 'STRING', 'GUITAR, CLASSICAL', 'YAMAHA', '40', NULL, NULL, 'yes', 'Keeara Walji', 'MS MUSIC', NULL, NULL, 'GRC'),
	(162, 7, 195, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CLP-645B', 'BCZZ01016', NULL, NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'PE') ON CONFLICT DO NOTHING;
INSERT INTO public.legacy_database (id, number, legacy_number, family, equipment, make, model, serial, class, year, full_name, school_storage, return_2023, student_number, code) VALUES
	(189, 1, 188, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CVP 303', 'GBRCKK 01021', NULL, NULL, NULL, 'THEATRE/FOYER', NULL, NULL, 'PE'),
	(454, 27, 435, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '074011A', 'BB1', '2023/24', 'Leo Prawitz', NULL, NULL, 12297, 'CL'),
	(50, 3, 83, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', NULL, '533719', NULL, NULL, 'Evan Daines', NULL, NULL, 13073, 'TP'),
	(488, 32, 440, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65438', 'HS MUSIC', '2023/24', 'Io Verstraete', NULL, NULL, 12998, 'CL'),
	(139, 6, 86, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '556107', 'BB1', '2023/24', 'Holly Mcmurtry', NULL, NULL, 10817, 'TP'),
	(361, 15, 580, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '362547A', 'HS MUSIC', '2023/24', 'Caitlin Wood', NULL, NULL, 10934, 'SXA'),
	(303, 11, 43, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'TROMBA', 'Pro', 'PB17070488', 'BB7', '2023/24', 'Titu Tulga', NULL, NULL, 12756, 'TNTP'),
	(471, 30, 62, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, 'BB8', '2023/24', 'Alexander Wietecha', NULL, NULL, 12725, 'TNTP'),
	(582, 49, 457, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'KE54676', NULL, '2023/24', 'Theodore Wright', NULL, 'xx', 12566, 'CL'),
	(469, 29, 594, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54576', 'BB8', '2023/24', 'Stefanie Landolt', NULL, NULL, 12286, 'SXA'),
	(407, 21, 101, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H35502', 'BB8', '2023/24', 'Kiara Materne', NULL, NULL, 12152, 'TP'),
	(422, 23, 103, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H35099', 'BB8', '2023/24', 'Mikael Eshetu', NULL, NULL, 12689, 'TP'),
	(444, 26, 106, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', 'BIR 1270', 'H31450', 'BB8', '2023/24', 'Saqer Alnaqbi', NULL, NULL, 12909, 'TP'),
	(485, 32, 64, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, 'BB7', '2023/24', 'Seth Lundell', NULL, NULL, 12691, 'TNTP'),
	(497, 34, 66, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, 'BB7', '2023/24', 'Sadie Szuchman', NULL, NULL, 12668, 'TNTP'),
	(627, 60, 629, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'AF53502', 'BB7', '2023/24', 'Noga Hercberg', NULL, NULL, 12681, 'SXA'),
	(629, 61, 469, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'YE67254', 'BB7', '2023/24', 'Vilma Doret Rosen', NULL, NULL, 11763, 'CL'),
	(456, 27, 592, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54339', 'MS Band 8', '2022/23', 'Alexander Roe', NULL, '5/6/2023', 12188, 'SXA'),
	(245, 1, 344, 'STRING', 'GUITAR, BASS', 'ARCHER', NULL, NULL, NULL, '2023/24', 'Jana Landolt', NULL, NULL, 12285, 'GRB'),
	(614, 57, 551, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'YD65954', 'BB7', '2023/24', 'Anaiya Shah', NULL, NULL, 11264, 'FL'),
	(391, 19, 99, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', 'BTR 1270', 'H35203', NULL, '2023/24', 'Cahir Patel', NULL, NULL, 10772, 'TP'),
	(528, 39, 124, 'BRASS', 'TRUMPET, B FLAT', 'LIBRETTO', NULL, '1107571', NULL, '2023/24', 'Caleb Ross', NULL, NULL, 11677, 'TP'),
	(584, 49, 618, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56319', 'MS Band 8', '2022/23', 'Barney Carver Wildig', NULL, NULL, 12601, 'SXA'),
	(597, 53, 461, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54957', 'BB8', '2023/24', 'Mahdiyah Muneeb', NULL, NULL, 12761, 'CL'),
	(602, 54, 548, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'YD66080', 'BB8', '2023/24', 'Seya Chandaria', NULL, NULL, 10775, 'FL'),
	(46, 3, 2, 'BRASS', 'BARITONE/EUPHONIUM', 'BESSON', 'Soveriegn 968', '770765', 'HS MUSIC', '2023/24', 'Saqer Alnaqbi', NULL, NULL, 12909, 'BH'),
	(564, 45, 540, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'XD58187', 'HS MUSIC', '2023/24', 'Saptha Girish Bommadevara', NULL, NULL, 10504, 'FL'),
	(133, 5, 570, 'WOODWIND', 'SAXOPHONE, ALTO', 'ETUDE', NULL, '11110173', 'ms concert band', '2021/22', 'Lukas Norman', NULL, NULL, 11534, 'SXA'),
	(106, 4, 643, 'WOODWIND', 'SAXOPHONE, BARITONE', 'JUPITER', 'JBS 1000', 'AF03351', 'HS MUSIC', '2023/24', 'Lukas Norman', NULL, NULL, 11534, 'SXB'),
	(101, 4, 409, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, '7988', 'BB1', '2023/24', 'Zecarun Caminha', NULL, NULL, 12081, 'CL'),
	(135, 5, 649, 'WOODWIND', 'SAXOPHONE, TENOR', 'YAMAHA', NULL, '31870', 'BB1', '2023/24', 'Spencer Schenck', NULL, NULL, 11457, 'SXT'),
	(158, 7, 21, 'BRASS', 'TROMBONE, TENOR', 'YAMAHA', NULL, '325472', 'BB1', '2023/24', 'Maartje Stott', NULL, NULL, 12519, 'TN') ON CONFLICT DO NOTHING;


--
-- TOC entry 4027 (class 0 OID 30986)
-- Dependencies: 250
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.locations (room, id) VALUES
	('PIANO ROOM', 3),
	('INSTRUMENT STORE', 4),
	('PRACTICE ROOM 3', 5),
	('PRACTICE ROOM 2', 6),
	('DRUM ROOM 2', 7),
	('LOWER ES MUSIC', 8),
	('MUSIC OFFICE', 9),
	('HS MUSIC', 10),
	('UPPER ES MUSIC', 11),
	('THEATRE/FOYER', 12),
	('MS MUSIC', 13),
	('DANCE STUDIO', 14),
	('PRACTICE ROOM 1', 15),
	('DRUM ROOM 1', 16) ON CONFLICT DO NOTHING;


--
-- TOC entry 4005 (class 0 OID 30734)
-- Dependencies: 225
-- Data for Name: lost_and_found; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4029 (class 0 OID 30992)
-- Dependencies: 252
-- Data for Name: music_instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.music_instruments (id, family, description, legacy_code, code, notes) VALUES
	(221, 'BRASS', 'BARITONE/EUPHONIUM', 'BH', 'BH', NULL),
	(222, 'BRASS', 'BARITONE/TENOR HORN', 'BH', 'BT', NULL),
	(223, 'BRASS', 'BUGLE', NULL, 'BG', NULL),
	(224, 'BRASS', 'BUGLE , KEYED', NULL, 'BGK', NULL),
	(225, 'BRASS', 'CIMBASSO', NULL, 'CS', NULL),
	(226, 'BRASS', 'CIMBASSO, B FLAT', NULL, 'CSB', NULL),
	(227, 'BRASS', 'CIMBASSO, C', NULL, 'CSC', NULL),
	(228, 'BRASS', 'CIMBASSO, E FLAT', NULL, 'CSE', NULL),
	(229, 'BRASS', 'CIMBASSO, F', NULL, 'CSF', NULL),
	(230, 'BRASS', 'CORNET', NULL, 'CT', NULL),
	(231, 'BRASS', 'CORNET , POCKET', NULL, 'CTP', NULL),
	(232, 'BRASS', 'CORNET, A', NULL, 'CTA', NULL),
	(233, 'BRASS', 'CORNET, C', NULL, 'CTC', NULL),
	(234, 'BRASS', 'CORNET, E♭  FLAT', NULL, 'CTE', NULL),
	(235, 'BRASS', 'DIDGERIDOO', NULL, 'DGD', NULL),
	(236, 'BRASS', 'EUPHONIUM', NULL, 'EP', NULL),
	(237, 'BRASS', 'EUPHONIUM , DOUBLE BELL', NULL, 'EPD', NULL),
	(238, 'BRASS', 'FLUGELHORN', NULL, 'FGH', NULL),
	(239, 'BRASS', 'FRENCH HORN', NULL, 'FH', NULL),
	(240, 'BRASS', 'HORN, ALTO', NULL, 'HNE', NULL),
	(241, 'BRASS', 'HORN, F', NULL, 'HNF', NULL),
	(242, 'BRASS', 'MELLOPHONE', 'M', 'M', NULL),
	(243, 'BRASS', 'METALLOPHONE', NULL, 'MTL', NULL),
	(244, 'BRASS', 'SAXHORN', NULL, 'SXH', NULL),
	(245, 'BRASS', 'SAXOTROMBA', NULL, 'STB', NULL),
	(246, 'BRASS', 'SAXTUBA', NULL, 'STU', NULL),
	(247, 'BRASS', 'SOUSAPHONE', 'T', 'SSP', NULL),
	(248, 'BRASS', 'TROMBONE, ALTO', 'PTB', 'TNA', NULL),
	(249, 'BRASS', 'TROMBONE, ALTO - PLASTIC', 'PTB', 'TNAP', NULL),
	(250, 'BRASS', 'TROMBONE, BASS', NULL, 'TNB', NULL),
	(251, 'BRASS', 'TROMBONE, PICCOLO', NULL, 'TNP', NULL),
	(252, 'BRASS', 'TROMBONE, SOPRANO', NULL, 'TNS', NULL),
	(253, 'BRASS', 'TROMBONE, TENOR', NULL, 'TN', NULL),
	(254, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PTB', 'TNTP', NULL),
	(255, 'BRASS', 'TROMBONE, VALVE', NULL, 'TNV', NULL),
	(256, 'BRASS', 'TRUMPET , PICCOLO', NULL, 'TPC', NULL),
	(257, 'BRASS', 'TRUMPET ,TUBE', NULL, 'TPX', NULL),
	(258, 'BRASS', 'TRUMPET, B FLAT', 'TP', 'TP', NULL),
	(259, 'BRASS', 'TRUMPET, BAROQUE', NULL, 'TPQ', NULL),
	(260, 'BRASS', 'TRUMPET, BASS', NULL, 'TPB', NULL),
	(261, 'BRASS', 'TRUMPET, POCKET', 'TPP', 'TPP', NULL),
	(262, 'BRASS', 'TRUMPET, ROTARY', NULL, 'TPR', NULL),
	(263, 'BRASS', 'TRUMPET, SLIDE', NULL, 'TPSL', NULL),
	(264, 'BRASS', 'TRUMPET,SOPRANO', NULL, 'TPS', NULL),
	(265, 'BRASS', 'TUBA', 'T', 'TB', NULL),
	(266, 'BRASS', 'TUBA, BASS', NULL, 'TBB', NULL),
	(267, 'BRASS', 'TUBA, WAGNER', NULL, 'TBW', NULL),
	(268, 'BRASS', 'VUVUZELA', NULL, 'VV', NULL),
	(269, 'KEYBOARD', 'KEYBOARD', NULL, 'KB', NULL),
	(270, 'KEYBOARD', 'PIANO, GRAND', NULL, 'PG', NULL),
	(271, 'KEYBOARD', 'PIANO, UPRIGHT', NULL, 'PU', NULL),
	(272, 'KEYBOARD', 'PIANO (PIANOFORTE)', NULL, 'P', NULL),
	(273, 'KEYBOARD', 'PIANO, ELECTRIC', NULL, 'PE', NULL),
	(274, 'PERCUSSION', 'ASHIKO', NULL, 'ASK', NULL),
	(275, 'PERCUSSION', 'BARREL DRUM', NULL, 'BRD', NULL),
	(276, 'PERCUSSION', 'BASS DRUM', NULL, 'BD', NULL),
	(277, 'PERCUSSION', 'BONGO DRUMS', NULL, 'BNG', NULL),
	(278, 'PERCUSSION', 'CABASA', NULL, 'CBS', NULL),
	(279, 'PERCUSSION', 'CARILLON', NULL, 'CRL', NULL),
	(280, 'PERCUSSION', 'CASTANETS', NULL, 'CST', NULL),
	(281, 'PERCUSSION', 'CLAPSTICK', NULL, 'CLP', NULL),
	(282, 'PERCUSSION', 'CLAVES', NULL, 'CLV', NULL),
	(283, 'PERCUSSION', 'CONGA', NULL, 'CG', NULL),
	(284, 'PERCUSSION', 'COWBELL', NULL, 'CWB', NULL),
	(285, 'PERCUSSION', 'CYMBAL', NULL, 'CM', NULL),
	(286, 'PERCUSSION', 'DJEMBE', NULL, 'DJ', NULL),
	(287, 'PERCUSSION', 'FLEXATONE', NULL, 'FXT', NULL),
	(288, 'PERCUSSION', 'GLOCKENSPIEL', NULL, 'GLK', NULL),
	(289, 'PERCUSSION', 'GOBLET DRUM', NULL, 'GBL', NULL),
	(290, 'PERCUSSION', 'GONG', NULL, 'GNG', NULL),
	(291, 'PERCUSSION', 'HANDBELLS', NULL, 'HB', NULL),
	(292, 'PERCUSSION', 'HANDPAN', NULL, 'HPN', NULL),
	(293, 'PERCUSSION', 'ILIMBA DRUM', NULL, 'ILD', NULL),
	(294, 'PERCUSSION', 'KALIMBA', NULL, 'KLM', NULL),
	(295, 'PERCUSSION', 'KANJIRA', NULL, 'KNJ', NULL),
	(296, 'PERCUSSION', 'KAYAMBA', NULL, 'KYM', NULL),
	(297, 'PERCUSSION', 'KEBERO', NULL, 'KBR', NULL),
	(298, 'PERCUSSION', 'KEMANAK', NULL, 'KMK', NULL),
	(299, 'PERCUSSION', 'MARIMBA', NULL, 'MRM', NULL),
	(300, 'PERCUSSION', 'MBIRA', NULL, 'MB', NULL),
	(301, 'PERCUSSION', 'MRIDANGAM', NULL, 'MRG', NULL),
	(302, 'PERCUSSION', 'NAGARA (DRUM)', NULL, 'NGR', NULL),
	(303, 'PERCUSSION', 'OCTA-VIBRAPHONE', NULL, 'OV', NULL),
	(304, 'PERCUSSION', 'PATE', NULL, 'PT', NULL),
	(305, 'PERCUSSION', 'SANDPAPER BLOCKS', NULL, 'SPB', NULL),
	(306, 'PERCUSSION', 'SHEKERE', NULL, 'SKR', NULL),
	(307, 'PERCUSSION', 'SLIT DRUM', NULL, 'SLD', NULL),
	(308, 'PERCUSSION', 'SNARE', NULL, 'SR', NULL),
	(309, 'PERCUSSION', 'STEELPAN', NULL, 'SP', NULL),
	(310, 'PERCUSSION', 'TABLA', NULL, 'TBL', NULL),
	(311, 'PERCUSSION', 'TALKING DRUM', NULL, 'TDR', NULL),
	(312, 'PERCUSSION', 'TAMBOURINE', NULL, 'TR', NULL),
	(313, 'PERCUSSION', 'TIMBALES (PAILAS)', NULL, 'TMP', NULL),
	(314, 'PERCUSSION', 'TOM-TOM DRUM', NULL, 'TT', NULL),
	(315, 'PERCUSSION', 'TRIANGLE', NULL, 'TGL', NULL),
	(316, 'PERCUSSION', 'VIBRAPHONE', NULL, 'VBR', NULL),
	(317, 'PERCUSSION', 'VIBRASLAP', NULL, 'VS', NULL),
	(318, 'PERCUSSION', 'WOOD BLOCK', NULL, 'WB', NULL),
	(319, 'PERCUSSION', 'XYLOPHONE', NULL, 'X', NULL),
	(320, 'PERCUSSION', 'AGOGO BELL', NULL, 'AGG', NULL),
	(321, 'PERCUSSION', 'BELL SET', NULL, 'BL', NULL),
	(322, 'PERCUSSION', 'BELL TREE', NULL, 'BLR', NULL),
	(323, 'PERCUSSION', 'BELLS, CONCERT', NULL, 'BLC', NULL),
	(324, 'PERCUSSION', 'BELLS, SLEIGH', NULL, 'BLS', NULL),
	(325, 'PERCUSSION', 'BELLS, TUBULAR', NULL, 'BLT', NULL),
	(326, 'PERCUSSION', 'CYMBAL, SUSPENDED 18 INCH', NULL, 'CMS', NULL),
	(327, 'PERCUSSION', 'CYMBALS, HANDHELD 16 INCH', NULL, 'CMY', NULL),
	(328, 'PERCUSSION', 'CYMBALS, HANDHELD 18 INCH', NULL, 'CMZ', NULL),
	(329, 'PERCUSSION', 'DRUMSET', NULL, 'DK', NULL),
	(330, 'PERCUSSION', 'DRUMSET, ELECTRIC', NULL, 'DKE', NULL),
	(331, 'PERCUSSION', 'EGG SHAKERS', NULL, 'EGS', NULL),
	(332, 'PERCUSSION', 'GUIRO', NULL, 'GUR', NULL),
	(333, 'PERCUSSION', 'MARACAS', NULL, 'MRC', NULL),
	(334, 'PERCUSSION', 'PRACTICE KIT', NULL, 'PK', NULL),
	(335, 'PERCUSSION', 'PRACTICE PAD', NULL, 'PD', NULL),
	(336, 'PERCUSSION', 'QUAD, MARCHING', NULL, 'Q', NULL),
	(337, 'PERCUSSION', 'RAINSTICK', NULL, 'RK', NULL),
	(338, 'PERCUSSION', 'SNARE, CONCERT', NULL, 'SRC', NULL),
	(339, 'PERCUSSION', 'SNARE, MARCHING', NULL, 'SRM', NULL),
	(340, 'PERCUSSION', 'TAMBOURINE, 10 INCH', NULL, 'TRT', NULL),
	(341, 'PERCUSSION', 'TAMBOURINE, 6 INCH', NULL, 'TRS', NULL),
	(342, 'PERCUSSION', 'TAMBOURINE, 8 INCH', NULL, 'TRE', NULL),
	(343, 'PERCUSSION', 'TIMBALI', NULL, 'TML', NULL),
	(344, 'PERCUSSION', 'TIMPANI, 23 INCH', NULL, 'TPT', NULL),
	(345, 'PERCUSSION', 'TIMPANI, 26 INCH', NULL, 'TPD', NULL),
	(346, 'PERCUSSION', 'TIMPANI, 29 INCH', NULL, 'TPN', NULL),
	(347, 'PERCUSSION', 'TIMPANI, 32 INCH', NULL, 'TPW', NULL),
	(348, 'PERCUSSION', 'TOM, MARCHING', NULL, 'TTM', NULL),
	(349, 'PERCUSSION', 'TUBANOS', NULL, 'TBN', NULL),
	(350, 'PERCUSSION', 'WIND CHIMES', NULL, 'WC', NULL),
	(351, 'STRING', 'ADUNGU', NULL, 'ADG', NULL),
	(352, 'STRING', 'AEOLIAN HARP', NULL, 'AHP', NULL),
	(353, 'STRING', 'AUTOHARP', NULL, 'HPA', NULL),
	(354, 'STRING', 'BALALAIKA', NULL, 'BLK', NULL),
	(355, 'STRING', 'BANJO', NULL, 'BJ', NULL),
	(356, 'STRING', 'BANJO CELLO', NULL, 'BJC', NULL),
	(357, 'STRING', 'BANJO, 4-STRING', NULL, 'BJX', NULL),
	(358, 'STRING', 'BANJO, 5-STRING', NULL, 'BJY', NULL),
	(359, 'STRING', 'BANJO, 6-STRING', NULL, 'BJW', NULL),
	(360, 'STRING', 'BANJO, BASS', NULL, 'BJB', NULL),
	(361, 'STRING', 'BANJO, BLUEGRASS', NULL, 'BJG', NULL),
	(362, 'STRING', 'BANJO, PLECTRUM', NULL, 'BJP', NULL),
	(363, 'STRING', 'BANJO, TENOR', NULL, 'BJT', NULL),
	(364, 'STRING', 'BANJO, ZITHER', NULL, 'BJZ', NULL),
	(365, 'STRING', 'CARIMBA', NULL, 'CRM', NULL),
	(366, 'STRING', 'CELLO, (VIOLONCELLO)', NULL, 'VCL', NULL),
	(367, 'STRING', 'CELLO, ELECTRIC', NULL, 'VCE', NULL),
	(368, 'STRING', 'CHAPMAN STICK', NULL, 'CPS', NULL),
	(369, 'STRING', 'CLAVICHORD', NULL, 'CVC', NULL),
	(370, 'STRING', 'CLAVINET', NULL, 'CVN', NULL),
	(371, 'STRING', 'CONTRAGUITAR', NULL, 'GTC', NULL),
	(372, 'STRING', 'CRWTH, (CROWD)', NULL, 'CRW', NULL),
	(373, 'STRING', 'DIDDLEY BOW', NULL, 'DDB', NULL),
	(374, 'STRING', 'DOUBLE BASS', NULL, 'DB', NULL),
	(375, 'STRING', 'DOUBLE BASS, 5-STRING', NULL, 'DBF', NULL),
	(376, 'STRING', 'DOUBLE BASS, ELECTRIC', NULL, 'DBE', NULL),
	(377, 'STRING', 'DULCIMER', NULL, 'DCM', NULL),
	(378, 'STRING', 'ELECTRIC CYMBALUM', NULL, 'CYE', NULL),
	(379, 'STRING', 'FIDDLE', NULL, 'FDD', NULL),
	(380, 'STRING', 'GUITAR SYNTHESIZER', NULL, 'GR', NULL),
	(381, 'STRING', 'GUITAR, 10-STRING', NULL, 'GRK', NULL),
	(382, 'STRING', 'GUITAR, 12-STRING', NULL, 'GRL', NULL),
	(383, 'STRING', 'GUITAR, 7-STRING', NULL, 'GRM', NULL),
	(384, 'STRING', 'GUITAR, 8-STRING', NULL, 'GRN', NULL),
	(385, 'STRING', 'GUITAR, 9-STRING', NULL, 'GRP', NULL),
	(386, 'STRING', 'GUITAR, ACOUSTIC', NULL, 'GRA', NULL),
	(387, 'STRING', 'GUITAR, ACOUSTIC-ELECTRIC', NULL, 'GRJ', NULL),
	(388, 'STRING', 'GUITAR, ARCHTOP', NULL, 'GRH', NULL),
	(389, 'STRING', 'GUITAR, BARITONE', NULL, 'GRR', NULL),
	(390, 'STRING', 'GUITAR, BAROQUE', NULL, 'GRQ', NULL),
	(391, 'STRING', 'GUITAR, BASS', NULL, 'GRB', NULL),
	(392, 'STRING', 'GUITAR, BASS ACOUSTIC', NULL, 'GRG', NULL),
	(393, 'STRING', 'GUITAR, BRAHMS', NULL, 'GRZ', NULL),
	(394, 'STRING', 'GUITAR, CLASSICAL', NULL, 'GRC', NULL),
	(395, 'STRING', 'GUITAR, CUTAWAY', NULL, 'GRW', NULL),
	(396, 'STRING', 'GUITAR, DOUBLE-NECK', NULL, 'GRD', NULL),
	(397, 'STRING', 'GUITAR, ELECTRIC', NULL, 'GRE', NULL),
	(398, 'STRING', 'GUITAR, FLAMENCO', NULL, 'GRF', NULL),
	(399, 'STRING', 'GUITAR, FRETLESS', NULL, 'GRY', NULL),
	(400, 'STRING', 'GUITAR, HALF', NULL, 'GRT', NULL),
	(401, 'STRING', 'GUITAR, OCTAVE', NULL, 'GRO', NULL),
	(402, 'STRING', 'GUITAR, SEMI-ACOUSTIC', NULL, 'GRX', NULL),
	(403, 'STRING', 'GUITAR, STEEL', NULL, 'GRS', NULL),
	(404, 'STRING', 'HARDANGER FIDDLE', NULL, 'FDH', NULL),
	(405, 'STRING', 'HARMONICO', NULL, 'HMR', NULL),
	(406, 'STRING', 'HARP', NULL, 'HP', NULL),
	(407, 'STRING', 'HARP GUITAR', NULL, 'HPG', NULL),
	(408, 'STRING', 'HARP, ELECTRIC', NULL, 'HPE', NULL),
	(409, 'STRING', 'HARPSICHORD', NULL, 'HRC', NULL),
	(410, 'STRING', 'HURDY-GURDY', NULL, 'HG', NULL),
	(411, 'STRING', 'KORA', NULL, 'KR', NULL),
	(412, 'STRING', 'KOTO', NULL, 'KT', NULL),
	(413, 'STRING', 'LOKANGA', NULL, 'LK', NULL),
	(414, 'STRING', 'LUTE', NULL, 'LT', NULL),
	(415, 'STRING', 'LUTE GUITAR', NULL, 'LTG', NULL),
	(416, 'STRING', 'LYRA (BYZANTINE)', NULL, 'LYB', NULL),
	(417, 'STRING', 'LYRA (CRETAN)', NULL, 'LYC', NULL),
	(418, 'STRING', 'LYRE', NULL, 'LY', NULL),
	(419, 'STRING', 'MANDOBASS', NULL, 'MDB', NULL),
	(420, 'STRING', 'MANDOCELLO', NULL, 'MDC', NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.music_instruments (id, family, description, legacy_code, code, notes) VALUES
	(421, 'STRING', 'MANDOLA', NULL, 'MDL', NULL),
	(422, 'STRING', 'MANDOLIN', NULL, 'MD', NULL),
	(423, 'STRING', 'MANDOLIN , BUEGRASS', NULL, 'MDX', NULL),
	(424, 'STRING', 'MANDOLIN , ELECTRIC', NULL, 'MDE', NULL),
	(425, 'STRING', 'MANDOLIN-BANJO', NULL, 'MDJ', NULL),
	(426, 'STRING', 'MANDOLIN, OCTAVE', NULL, 'MDO', NULL),
	(427, 'STRING', 'MANDOLUTE', NULL, 'MDT', NULL),
	(428, 'STRING', 'MUSICAL BOW', NULL, 'MSB', NULL),
	(429, 'STRING', 'OCTOBASS', NULL, 'OCB', NULL),
	(430, 'STRING', 'OUD', NULL, 'OUD', NULL),
	(431, 'STRING', 'PSALTERY', NULL, 'PS', NULL),
	(432, 'STRING', 'SITAR', NULL, 'STR', NULL),
	(433, 'STRING', 'THEORBO', NULL, 'TRB', NULL),
	(434, 'STRING', 'U-BASS', NULL, 'UB', NULL),
	(435, 'STRING', 'UKULELE, 5-STRING TENOR', NULL, 'UKF', NULL),
	(436, 'STRING', 'UKULELE, 6-STRING TENOR', NULL, 'UKX', NULL),
	(437, 'STRING', 'UKULELE, 8-STRING TENOR', NULL, 'UKW', NULL),
	(438, 'STRING', 'UKULELE, BARITONE', NULL, 'UKR', NULL),
	(439, 'STRING', 'UKULELE, BASS', NULL, 'UKB', NULL),
	(440, 'STRING', 'UKULELE, CONCERT', NULL, 'UKC', NULL),
	(441, 'STRING', 'UKULELE, CONTRABASS', NULL, 'UKZ', NULL),
	(442, 'STRING', 'UKULELE, ELECTRIC', NULL, 'UKE', NULL),
	(443, 'STRING', 'UKULELE, HARP', NULL, 'UKH', NULL),
	(444, 'STRING', 'UKULELE, LAP STEEL', NULL, 'UKL', NULL),
	(445, 'STRING', 'UKULELE, POCKET', NULL, 'UKP', NULL),
	(446, 'STRING', 'UKULELE, SOPRANO', NULL, 'UKS', NULL),
	(447, 'STRING', 'UKULELE, TENOR', NULL, 'UKT', NULL),
	(448, 'STRING', 'VIOLA 13 INCH', NULL, 'VLT', NULL),
	(449, 'STRING', 'VIOLA 16 INCH (FULL)', NULL, 'VL', NULL),
	(450, 'STRING', 'VIOLA, ELECTRIC', NULL, 'VLE', NULL),
	(451, 'STRING', 'VIOLIN', NULL, 'VN', NULL),
	(452, 'STRING', 'VIOLIN, 1/2', NULL, 'VNH', NULL),
	(453, 'STRING', 'VIOLIN, 1/4', NULL, 'VNQ', NULL),
	(454, 'STRING', 'VIOLIN, 3/4', NULL, 'VNT', NULL),
	(455, 'STRING', 'VIOLIN, ELECTRIC', NULL, 'VNE', NULL),
	(456, 'STRING', 'ZITHER', NULL, 'Z', NULL),
	(457, 'STRING', 'ZITHER, ALPINE (HARP ZITHER)', NULL, 'ZA', NULL),
	(458, 'STRING', 'ZITHER, CONCERT', NULL, 'ZC', NULL),
	(459, 'WOODWIND', 'ALPHORN', NULL, 'ALH', NULL),
	(460, 'WOODWIND', 'BAGPIPE', NULL, 'BGP', NULL),
	(461, 'WOODWIND', 'BASSOON', NULL, 'BS', NULL),
	(462, 'WOODWIND', 'CHALUMEAU', NULL, 'CHM', NULL),
	(463, 'WOODWIND', 'CLARINET, ALTO IN E FLAT', NULL, 'CLE', NULL),
	(464, 'WOODWIND', 'CLARINET, B FLAT', 'CL', 'CL', NULL),
	(465, 'WOODWIND', 'CLARINET, BASS', 'BCL', 'CLB', NULL),
	(466, 'WOODWIND', 'CLARINET, BASSET IN A', NULL, 'CLA', NULL),
	(467, 'WOODWIND', 'CLARINET, CONTRA-ALTO', NULL, 'CLT', NULL),
	(468, 'WOODWIND', 'CLARINET, CONTRABASS', NULL, 'CLU', NULL),
	(469, 'WOODWIND', 'CLARINET, PICCOLO IN A FLAT (OR G)', NULL, 'CLC', NULL),
	(470, 'WOODWIND', 'CLARINET, SOPRANINO IN E FLAT (OR D)', NULL, 'CLS', NULL),
	(471, 'WOODWIND', 'CONCERTINA', NULL, 'CNT', NULL),
	(472, 'WOODWIND', 'CONTRABASSOON/DOUBLE BASSOON', NULL, 'BSD', NULL),
	(473, 'WOODWIND', 'DULCIAN', NULL, 'DLC', NULL),
	(474, 'WOODWIND', 'DULCIAN, ALTO', NULL, 'DLCA', NULL),
	(475, 'WOODWIND', 'DULCIAN, BASS', NULL, 'DLCB', NULL),
	(476, 'WOODWIND', 'DULCIAN, SOPRANO', NULL, 'DLCS', NULL),
	(477, 'WOODWIND', 'DULCIAN, TENOR', NULL, 'DLCT', NULL),
	(478, 'WOODWIND', 'DZUMARI', NULL, 'DZ', NULL),
	(479, 'WOODWIND', 'ENGLISH HORN', NULL, 'CA', NULL),
	(480, 'WOODWIND', 'FIFE', NULL, 'FF', NULL),
	(481, 'WOODWIND', 'FLAGEOLET', NULL, 'FGL', NULL),
	(482, 'WOODWIND', 'FLUTE', 'FL', 'FL', NULL),
	(483, 'WOODWIND', 'FLUTE , NOSE', NULL, 'FLN', NULL),
	(484, 'WOODWIND', 'FLUTE, ALTO', NULL, 'FLA', NULL),
	(485, 'WOODWIND', 'FLUTE, BASS', NULL, 'FLB', NULL),
	(486, 'WOODWIND', 'FLUTE, CONTRA-ALTO', NULL, 'FLX', NULL),
	(487, 'WOODWIND', 'FLUTE, CONTRABASS', NULL, 'FLC', NULL),
	(488, 'WOODWIND', 'FLUTE, IRISH', NULL, 'FLI', NULL),
	(489, 'WOODWIND', 'HARMONICA', NULL, 'HM', NULL),
	(490, 'WOODWIND', 'HARMONICA, CHROMATIC', NULL, 'HMC', NULL),
	(491, 'WOODWIND', 'HARMONICA, DIATONIC', NULL, 'HMD', NULL),
	(492, 'WOODWIND', 'HARMONICA, ORCHESTRAL', NULL, 'HMO', NULL),
	(493, 'WOODWIND', 'HARMONICA, TREMOLO', NULL, 'HMT', NULL),
	(494, 'WOODWIND', 'KAZOO', NULL, 'KZO', NULL),
	(495, 'WOODWIND', 'MELODEON', NULL, 'MLD', NULL),
	(496, 'WOODWIND', 'MELODICA', NULL, 'ML', NULL),
	(497, 'WOODWIND', 'MUSETTE DE COUR', NULL, 'MSC', NULL),
	(498, 'WOODWIND', 'OBOE', 'OB', 'OB', NULL),
	(499, 'WOODWIND', 'OCARINA', NULL, 'OCR', NULL),
	(500, 'WOODWIND', 'PAN FLUTE', NULL, 'PF', NULL),
	(501, 'WOODWIND', 'PICCOLO', 'PC', 'PC', NULL),
	(502, 'WOODWIND', 'PIPE ORGAN', NULL, 'PO', NULL),
	(503, 'WOODWIND', 'PITCH PIPE', NULL, 'PP', NULL),
	(504, 'WOODWIND', 'RECORDER', NULL, 'R', NULL),
	(505, 'WOODWIND', 'RECORDER, BASS', NULL, 'RB', NULL),
	(506, 'WOODWIND', 'RECORDER, CONTRA BASS', NULL, 'RC', NULL),
	(507, 'WOODWIND', 'RECORDER, DESCANT', NULL, 'RD', NULL),
	(508, 'WOODWIND', 'RECORDER, GREAT BASS', NULL, 'RG', NULL),
	(509, 'WOODWIND', 'RECORDER, SOPRANINO', NULL, 'RS', NULL),
	(510, 'WOODWIND', 'RECORDER, SUBCONTRA BASS', NULL, 'RX', NULL),
	(511, 'WOODWIND', 'RECORDER, TENOR', NULL, 'RT', NULL),
	(512, 'WOODWIND', 'RECORDER, TREBLE OR ALTO', NULL, 'RA', NULL),
	(513, 'WOODWIND', 'ROTHPHONE', NULL, 'RP', NULL),
	(514, 'WOODWIND', 'ROTHPHONE , ALTO', NULL, 'RPA', NULL),
	(515, 'WOODWIND', 'ROTHPHONE , BARITONE', NULL, 'RPX', NULL),
	(516, 'WOODWIND', 'ROTHPHONE , BASS', NULL, 'RPB', NULL),
	(517, 'WOODWIND', 'ROTHPHONE , SOPRANO', NULL, 'RPS', NULL),
	(518, 'WOODWIND', 'ROTHPHONE , TENOR', NULL, 'RPT', NULL),
	(519, 'WOODWIND', 'SARRUSOPHONE', NULL, 'SRP', NULL),
	(520, 'WOODWIND', 'SAXOPHONE', NULL, 'SX', NULL),
	(521, 'WOODWIND', 'SAXOPHONE, ALTO', 'AX', 'SXA', NULL),
	(522, 'WOODWIND', 'SAXOPHONE, BARITONE', 'BX', 'SXB', NULL),
	(523, 'WOODWIND', 'SAXOPHONE, BASS', NULL, 'SXY', NULL),
	(524, 'WOODWIND', 'SAXOPHONE, C MELODY (TENOR IN C)', NULL, 'SXM', NULL),
	(525, 'WOODWIND', 'SAXOPHONE, C SOPRANO', NULL, 'SXC', NULL),
	(526, 'WOODWIND', 'SAXOPHONE, CONTRABASS', NULL, 'SXZ', NULL),
	(527, 'WOODWIND', 'SAXOPHONE, MEZZO-SOPRANO (ALTO IN F)', NULL, 'SXF', NULL),
	(528, 'WOODWIND', 'SAXOPHONE, PICCOLO (SOPRILLO)', NULL, 'SXP', NULL),
	(529, 'WOODWIND', 'SAXOPHONE, SOPRANINO', NULL, 'SXX', NULL),
	(530, 'WOODWIND', 'SAXOPHONE, SOPRANO', NULL, 'SXS', NULL),
	(531, 'WOODWIND', 'SAXOPHONE, TENOR', 'TX', 'SXT', NULL),
	(532, 'WOODWIND', 'SEMICONTRABASSOON', NULL, 'BSS', NULL),
	(533, 'WOODWIND', 'WHISTLE, TIN', NULL, 'WT', NULL),
	(534, 'PERCUSSION', 'BELL KIT', NULL, 'BK', NULL),
	(541, 'ELECTRIC', 'AMPLIFIER', NULL, 'AM', NULL),
	(542, 'ELECTRIC', 'AMPLIFIER, BASS', NULL, 'AMB', NULL),
	(543, 'ELECTRIC', 'AMPLIFIER, GUITAR', NULL, 'AMG', NULL),
	(544, 'ELECTRIC', 'AMPLIFIER, KEYBOARD', NULL, 'AMK', NULL) ON CONFLICT DO NOTHING;


--
-- TOC entry 4031 (class 0 OID 30999)
-- Dependencies: 254
-- Data for Name: new_instrument; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4007 (class 0 OID 30741)
-- Dependencies: 227
-- Data for Name: repair_request; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4009 (class 0 OID 30748)
-- Dependencies: 229
-- Data for Name: resolve; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 4011 (class 0 OID 30755)
-- Dependencies: 231
-- Data for Name: returns; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.returns (id, created_at, item_id, created_by, user_id, former_user_id) VALUES
	(304, '2024-06-07', 1906, 'kwando', 1082, 1071),
	(305, '2024-06-07', 1818, 'kwando', 1082, 1071),
	(306, '2024-06-07', 1873, 'kwando', 1082, 1071),
	(307, '2024-06-07', 1856, 'kwando', 1082, 1071),
	(308, '2024-06-07', 1496, 'kwando', 1082, 1071),
	(309, '2024-06-24', 4163, 'nochomo', 1071, 1074),
	(310, '2024-09-10', 4165, 'nochomo', 1071, 1071),
	(311, '2024-09-10', 4166, 'nochomo', 1071, 1071),
	(312, '2024-09-10', 4203, 'nochomo', 1071, 1071),
	(313, '2024-09-10', 4209, 'nochomo', 1071, 1071),
	(314, '2024-09-10', 2129, 'nochomo', 1071, 1071),
	(315, '2024-09-10', 4164, 'nochomo', 1071, 1071) ON CONFLICT DO NOTHING;


--
-- TOC entry 4013 (class 0 OID 30762)
-- Dependencies: 233
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.roles (id, role_name) VALUES
	(4, 'STUDENT'),
	(5, 'MUSIC TEACHER'),
	(6, 'INVENTORY MANAGER'),
	(7, 'COMMUNITY'),
	(10, 'MUSIC TA'),
	(11, 'SUBSTITUTE'),
	(8, 'ADMINISTRATOR'),
	(12, 'TEACHER'),
	(13, 'ALUMNUS'),
	(14, 'EX EMPLOYEE') ON CONFLICT DO NOTHING;


--
-- TOC entry 4019 (class 0 OID 30937)
-- Dependencies: 240
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.students (id, last_name, first_name, parent1_email, parent2_email, email, grade_level, student_number, class) VALUES
	(701, 'Abdurazakov', 'Elrad', 'abdurazakova@un.org', 'akmal.abdurazakov@gmail.com', 'eabdurazakov30@isk.ac.ke', 7, '12690', NULL),
	(448, 'Allen', 'Tobin', 'beth1421@hotmail.com', 'jeff_allen_1@yahoo.com', 'tallen27@isk.ac.ke', 10, '12308', NULL),
	(21, 'Andersen', 'Yonas Wondim Belachew', 'louian@um.dk', 'wondim_b@yahoo.com', 'ywondim-andersen26@isk.ac.ke', 11, '12968', NULL),
	(123, 'Awori', 'Aisha', 'Annmarieawori@gmail.com', 'Michael.awori@gmail.com', 'aawori28@isk.ac.ke', 9, '10474', 'Concert Band 2023'),
	(367, 'Bommadevara', 'Saptha Girish', 'malini.hemamalini@gmail.com', 'bvramana@hotmail.com', 'gbommadevara26@isk.ac.ke', 11, '10504', NULL),
	(23, 'Camisa', 'Cassandre', 'katerinelafreniere@hotmail.com', 'laurentcamisa@hotmail.com', 'ccamisa27@isk.ac.ke', 10, '11881', NULL),
	(179, 'Davis - Arana', 'Maximiliano', 'majo.arana@gmail.com', 'nick.diallo@gmail.com', 'mdavis-arana35@isk.ac.ke', 2, '12372', NULL),
	(237, 'Eckert-Crosse', 'Finley', 'ekarleckert@gmail.com', 'billycrosse@gmail.com', 'feckertcrosse32@isk.ac.ke', 5, '11568', NULL),
	(617, 'Friedhoff Jaeschke', 'Naia', 'heike_friedhoff@hotmail.com', 'thomas.jaeschke.e@outlook.com', 'nfriedhoffjaeschke29@isk.ac.ke', 8, '11822', 'Concert Band 2023'),
	(705, 'Mosher', 'Elena', 'anabgonzalez@gmail.com', 'james.mosher@gmail.com', 'emosher35@isk.ac.ke', 2, '12710', NULL),
	(742, 'Muttersbaugh', 'Magnolia', 'brennan.winter@gmail.com', 'smuttersbaugh@gmail.com', 'mmuttersbaugh33@isk.ac.ke', 4, '13034', NULL),
	(1065, 'Linck', 'Hana', 'anitapetitpierre@gmail.com', NULL, 'hlinck24@isk.ac.ke', 13, '12559', NULL),
	(816, 'Mueller', 'Graham', 'carlabenini1@gmail.com', 'mueller10r@aol.com', 'gmueller29@isk.ac.ke', 8, '12938', NULL),
	(449, 'Allen', 'Corinne', 'beth1421@hotmail.com', 'jeff_allen_1@yahoo.com', 'callen24@isk.ac.ke', 13, '12307', NULL),
	(1085, 'Test', 'Four', NULL, NULL, 'tone@isk.ac.ke', NULL, '11660', NULL),
	(1086, 'Test', 'Eight', NULL, NULL, 'ttest29@isk.ac.ke', 8, '11661', NULL),
	(1087, 'Test', 'Ten', NULL, NULL, 'mcstudent10@isk.ac.ke', 27, '11662', NULL),
	(1078, 'Dumn', 'Dummy', NULL, NULL, 'dummy2@gmail.com', 1, 'DUMMY123', NULL),
	(1088, 'Friedman', 'Becca', NULL, NULL, 'bfriedman31@isk.ac.ke', 6, '12200', NULL),
	(45, 'Abou Hamda', 'Samer', 'hiba_hassan1983@hotmail.com', 'designcenter2011@live.com', 'sabouhamda28@isk.ac.ke', 9, '12779', NULL),
	(805, 'Abreu', 'Aristophanes', 'katerina_papaioannou@yahoo.com', 'herson_abreu@hotmail.com', 'abreu36@isk.ac.ke', 1, '12895', NULL),
	(806, 'Abreu', 'Herson Alexandros', 'katerina_papaioannou@yahoo.com', 'herson_abreu@hotmail.com', 'halexandrosabreu35@isk.ac.ke', 2, '12896', NULL),
	(599, 'Acharya', 'Ella', 'isk@kuttaemail.com', 'thaipeppers2020@gmail.com', 'eacharya35@isk.ac.ke', 2, '12882', NULL),
	(1037, 'Adamec', 'Filip', 'nicol_adamcova@mzv.cz', 'adamec.r@gmail.com', 'fadamec26@isk.ac.ke', 11, '12904', NULL),
	(845, 'Agenorwot', 'Maria', 'bpido100@gmail.com', NULL, 'magenorwot28@isk.ac.ke', 9, '13018', 'Concert Band 2023'),
	(244, 'Ahmed', 'Hafsa', 'zahraaden@gmail.com', 'yassinoahmed@gmail.com', 'hahmed28@isk.ac.ke', 9, '12158', NULL),
	(88, 'Akuete', 'Hassan', 'kaycwed@gmail.com', 'pkakuete@gmail.com', 'hakuete26@isk.ac.ke', 11, '11985', NULL),
	(87, 'Akuete', 'Ehsan', 'kaycwed@gmail.com', 'pkakuete@gmail.com', 'eakuete28@isk.ac.ke', 9, '12156', 'Concert Band 2023'),
	(812, 'Ali', 'Rahmaan', 'rahima.khawaja@gmail.com', 'rahim.khawaja@aku.edu', 'rrahim-ali24@isk.ac.ke', 13, '12755', NULL),
	(444, 'Alnaqbi', 'Fatima', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'falnaqbi27@isk.ac.ke', 10, '12907', NULL),
	(443, 'Alnaqbi', 'Almayasa', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'alnaqbi29@isk.ac.ke', 8, '12908', NULL),
	(19, 'Andersen', 'Yohanna Wondim Belachew', 'louian@um.dk', 'wondim_b@yahoo.com', 'ywondimandersen35@isk.ac.ke', 2, '12966', NULL),
	(20, 'Andersen', 'Yonatan Wondim Belachew', 'louian@um.dk', 'wondim_b@yahoo.com', 'ywondimandersen30@isk.ac.ke', 7, '12967', 'Beginning Band 7 2023'),
	(181, 'Anding', 'Florencia', 'ganding@isk.ac.ke', 'manding@isk.ac.ke', 'fanding28@isk.ac.ke', 9, '10967', 'Concert Band 2023'),
	(130, 'Andries-Munshi', 'Zaha', 'sarah.andries@gmail.com', 'neilmunshi@gmail.com', 'zandries-munshi33@isk.ac.ke', 4, '12788', NULL),
	(866, 'Arora', 'Harshaan', 'dearbhawna1@yahoo.co.in', 'kapil.arora@eni.com', 'harora28@isk.ac.ke', 9, '13010', NULL),
	(1011, 'Asquith', 'Elliot', 'kamilla.henningsen@gmail.com', 'm.asquith@icloud.com', 'easquith28@isk.ac.ke', 9, '12943', NULL),
	(684, 'Assefa', 'Amman', 'selamh27@yahoo.com', 'Assefaft@Gmail.com', 'aassefa28@isk.ac.ke', 9, '12669', NULL),
	(331, 'Bamlango', 'Lucile', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'lbamlango30@isk.ac.ke', 7, '10977', 'Beginning Band 8 - 2023'),
	(897, 'Barbacci', 'Gabriella', 'kbarbacci@hotmail.com', 'fbarbacci@hotmail.com', 'gbarbacci26@isk.ac.ke', 11, '12611', NULL),
	(639, 'Barragan Sofrony', 'Gael', 'angelica.sofrony@gmail.com', 'barraganc@un.org', 'gbarragansofrony33@isk.ac.ke', 4, '12711', NULL),
	(638, 'Barragan Sofrony', 'Sienna', 'angelica.sofrony@gmail.com', 'barraganc@un.org', 'sbarragansofrony36@isk.ac.ke', 1, '12831', NULL),
	(451, 'Ben Anat', 'Ella', 'benanatim@gmail.com', 'benanatim25@gmail.com', 'ebenanat31@isk.ac.ke', 6, '11475', NULL),
	(452, 'Ben Anat', 'Shira', 'benanatim@gmail.com', 'benanatim25@gmail.com', 'sbenanat28@isk.ac.ke', 9, '11518', NULL),
	(570, 'Bierly', 'Michael', 'abierly02@gmail.com', 'BierlyJE@state.gov', 'mbierly28@isk.ac.ke', 9, '12179', NULL),
	(836, 'Bin Taif', 'Ahmed Jawad', 'shanchita02@gmail.com', 'ul.taif@gmail.com', 'abintaif31@isk.ac.ke', 6, '12312', 'Band 8 2024'),
	(932, 'Birschbach', 'Mubanga', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'mbirschbach36@isk.ac.ke', 1, '13052', NULL),
	(233, 'Blaschke', 'Kaitlyn', 'cmcmorrison@gmail.com', 'sean.blaschke@gmail.com', 'kblaschke30@isk.ac.ke', 7, '11052', NULL),
	(839, 'Bonde-Nielsen', 'Luna', 'nike@terramoyo.com', 'pbn@oldonyolaro.com', 'lbonde-nielsen32@isk.ac.ke', 5, '12891', NULL),
	(879, 'Bunch', 'Jaidyn', 'tsjbunch2@gmail.com', 'tsjbunch@gmail.com', 'jbunch25@isk.ac.ke', 12, '12508', NULL),
	(101, 'Chandaria', 'Seya', 'farzana@chandaria.biz', 'sachen@chandaria.biz', 'schandaria30@isk.ac.ke', 7, '10775', 'Beginning Band 8 - 2023'),
	(471, 'Chigudu', 'Munashe', 'memoshiri@yahoo.co.uk', 'vchigudu@yahoo.co.uk', 'mchigudu28@isk.ac.ke', 9, '11376', NULL),
	(729, 'Chikapa', 'Zizwani', 'luyckx.ilke@gmail.com', 'zwangiegasha@gmail.com', 'zchikapa37@isk.ac.ke', 0, '13101', NULL),
	(813, 'Chowdhury', 'Davran', 'mohira22@yahoo.com', 'numayr_chowdhury@yahoo.com', 'dchowdhury31@isk.ac.ke', 6, '13029', NULL),
	(407, 'Clark', 'Galuh', 'agniparamita@gmail.com', 'samueltclark@gmail.com', 'gclark29@isk.ac.ke', 8, '11787', NULL),
	(1002, 'Corbin', 'Camille', 'corbincf@gmail.com', 'james.corbin.pa@gmail.com', 'ccorbin29@isk.ac.ke', 8, '12941', NULL),
	(295, 'Cutler', 'Edie', 'megseyjackson@gmail.com', 'adrianhcutler@gmail.com', 'ecutler30@isk.ac.ke', 7, '10686', 'Beginning Band 7 2023'),
	(689, 'Daines', 'Evan', 'foreverdaines143@gmail.com', 'dainesy@gmail.com', 'edaines30@isk.ac.ke', 7, '13073', 'Beginning Band 1 2023'),
	(546, 'De Vries Aguirre', 'Lorenzo', 'pangolinaty@yahoo.com', 'mmgoez1989@gmail.com', 'ldevriesaguirre27@isk.ac.ke', 10, '11552', NULL),
	(677, 'Dove', 'Ruth', 'meganlpdove@gmail.com', 'stephencarterdove@gmail.com', 'rdove27@isk.ac.ke', 10, '12921', NULL),
	(676, 'Dove', 'Georgia', 'meganlpdove@gmail.com', 'stephencarterdove@gmail.com', 'gdove30@isk.ac.ke', 7, '12922', 'Concert Band 2023'),
	(591, 'Karuga', 'Kelsie', 'irene.karuga2@gmail.com', 'karugafamily@gmail.com', 'kkaruga30@isk.ac.ke', 7, '12162', NULL),
	(740, 'Abbonizio', 'Emilie', 'oriane.abbonizio@gmail.com', 'askari606@gmail.com', 'eabbonizio25@isk.ac.ke', 12, '13016', NULL),
	(550, 'Abdellahi', 'Emir', 'knwazota@ifc.org', NULL, 'eabdellahi25@isk.ac.ke', 12, '11605', NULL),
	(17, 'Abdissa', 'Dawit', 'addisalemt96@gmail.com', 'tesemaa@un.org', 'dabdissa28@isk.ac.ke', 9, '13077', NULL),
	(46, 'Abou Hamda', 'Youssef', 'hiba_hassan1983@hotmail.com', 'designcenter2011@live.com', 'yabouhamda25@isk.ac.ke', 12, '12778', NULL),
	(68, 'Gardner', 'Elizabeth', 'michelle.barrett@wfp.org', 'calum.gardner@wfp.org', 'egardner29@isk.ac.ke', 8, '11467', 'Concert Band 2023'),
	(434, 'Gerba', 'Madigan', 'erin.gerba@gmail.com', 'mogerba2@gmail.com', 'mgerba27@isk.ac.ke', 10, '11507', NULL),
	(598, 'Godden', 'Lisa', 'martinettegodden@gmail.com', 'kieranrgodden@gmail.com', 'lgodden26@isk.ac.ke', 11, '12478', NULL),
	(411, 'Gremley', 'Calvin', 'emmagremley@gmail.com', 'andrewgremley@gmail.com', 'cgremley26@isk.ac.ke', 11, '12115', NULL),
	(409, 'Gremley', 'Aiden', 'emmagremley@gmail.com', 'andrewgremley@gmail.com', 'agremley29@isk.ac.ke', 8, '12393', 'Concert Band 2023'),
	(824, 'Gronborg', 'Anna Toft', 'trinegronborg@gmail.com', 'laschi@um.dk', 'agronborg36@isk.ac.ke', 1, '12801', NULL),
	(342, 'Hagelberg', 'Zoe Rose', 'Lisa@virginbushsafaris.com', 'niklas.hagelberg@un.org', 'zhagelberg25@isk.ac.ke', 12, '12077', NULL),
	(172, 'Hajee', 'Kahara', 'jhajee@isk.ac.ke', 'khalil.hajee@gmail.com', 'khajee28@isk.ac.ke', 9, '11541', NULL),
	(831, 'Hayer', 'Kaveer Singh', 'manpreetkh@gmail.com', 'csh@hayerone.com', 'khayer34@isk.ac.ke', 3, '13048', NULL),
	(311, 'Herman-Roloff', 'Shela', 'amykateherman@hotmail.com', 'khermanroloff@gmail.com', 'sherman-roloff31@isk.ac.ke', 6, '12195', NULL),
	(312, 'Herman-Roloff', 'Keza', 'amykateherman@hotmail.com', 'khermanroloff@gmail.com', 'kherman-roloff29@isk.ac.ke', 8, '12196', 'Concert Band 2023'),
	(11, 'Hodge', 'Emalea', 'janderson12@worldbank.org', 'jhodge1@worldbank.org', 'ehodge31@isk.ac.ke', 6, '12192', NULL),
	(759, 'Houndeganme', 'Michael', 'kougblenouchristelle@gmail.com', 'ahoundeganme@unicef.org', 'mhoundeganme27@isk.ac.ke', 10, '12814', NULL),
	(922, 'Huysdens', 'Yasmin', 'mhuysdens@gmail.com', 'merchan_nl@hotmail.com', 'yhuysdens29@isk.ac.ke', 8, '12927', NULL),
	(735, 'Irungu', 'Aiden', 'nicole.m.irungu@gmail.com', 'dominic.i.wanyoike@gmail.com', 'airungu34@isk.ac.ke', 3, '13038', NULL),
	(5, 'Iversen', 'Sumaiya', 'sahfana.ali.mubarak@mfa.no', 'iiv@lyse.net', 'siversen24@isk.ac.ke', 13, '12433', NULL),
	(224, 'Jama', 'Ari', 'katie.elles@gmail.com', 'jama.artan@gmail.com', 'ajama33@isk.ac.ke', 4, '12452', NULL),
	(253, 'Janmohamed', 'Aila', 'nabila.wissanji@gmail.com', 'gj@jansons.co.za', 'ajanmohamed28@isk.ac.ke', 9, '12174', NULL),
	(646, 'Jin', 'A-Hyun', 'h.lee2@afdb.org', 'jinseungsoo@gmail.com', 'ajin34@isk.ac.ke', 3, '12246', NULL),
	(1044, 'Johansson-Desai', 'Daniel', 'karin.johansson@eeas.europa.eu', 'j.desai@email.com', 'djohansson-desai26@isk.ac.ke', 11, '13011', NULL),
	(1030, 'Johansson-Desai', 'Benjamin', 'karin.johansson@eeas.europa.eu', 'j.desai@email.com', 'bjohansson-desai27@isk.ac.ke', 10, '13012', NULL),
	(504, 'Johnson', 'Brycelyn', 'bobbiejohnsonbjj@gmail.com', 'donovanshanej@gmail.com', 'bjohnson30@isk.ac.ke', 7, '12866', NULL),
	(788, 'Karmali', 'Zayan', 'shameenkarmali@outlook.com', 'shirazkarmali10@gmail.com', 'zkarmali26@isk.ac.ke', 11, '13098', NULL),
	(492, 'Kasahara', 'Ao', 'miho.a.yonekura@gmail.com', 'aito.kasahara@sumitomocorp.com', 'akasahara36@isk.ac.ke', 1, '13041', NULL),
	(683, 'Kasymbekova Tauras', 'Deniza', 'aisuluukasymbekova@yahoo.com', 'ttauras@gmail.com', 'dkasymbekova31@isk.ac.ke', 6, '13027', NULL),
	(934, 'Khalid', 'Zyla', 'aryana.c.khalid@gmail.com', 'waqqas.khalid@gmail.com', 'zkhalid36@isk.ac.ke', 1, '12747', NULL),
	(95, 'Kimani', 'Isla', 'rjones@isk.ac.ke', 'anthonykimani001@gmail.com', 'ikimani36@isk.ac.ke', 1, '12397', NULL),
	(649, 'Kimatrai', 'Nikhil', 'aditikimatrai@gmail.com', 'ranjeevkimatrai@gmail.com', 'nkimatrai27@isk.ac.ke', 10, '11810', NULL),
	(343, 'Kimmelman-May', 'Juju', 'shannon.k.may@gmail.com', 'jay.kimmelman@gmail.com', 'jkimmelman-may32@isk.ac.ke', 5, '12354', NULL),
	(266, 'Kurauchi', 'Mairi', 'yuko.kurauchi@gmail.com', 'kunal.chandaria@gmail.com', 'mkurauchi33@isk.ac.ke', 4, '11491', NULL),
	(290, 'Kurji', 'Kaysan Karim', 'shabz.karmali1908@gmail.com', 'shaukatali@primecuts.co.ke', 'kkurji33@isk.ac.ke', 4, '12229', NULL),
	(737, 'Li', 'Feng Milun', 'ugandayog01@hotmail.com', 'simonlee831001@hotmail.com', 'fli29@isk.ac.ke', 8, '13023', NULL),
	(714, 'Mackay', 'Elsie', 'mandyamackay@gmail.com', 'tpmackay@gmail.com', 'emackay32@isk.ac.ke', 5, '12886', NULL),
	(707, 'Magassouba', 'Abibatou', 'mnoel.fall@gmail.com', 'mmagass9@gmail.com', 'amagassouba34@isk.ac.ke', 3, '13092', NULL),
	(936, 'Magnusson', 'Alexander', 'ericaselles@gmail.com', 'jon.a.magnusson@gmail.com', 'amagnusson36@isk.ac.ke', 1, '12824', NULL),
	(329, 'Manek', 'Shriya', 'devika@maneknet.com', 'jay@maneknet.com', 'smanek25@isk.ac.ke', 12, '11777', NULL),
	(915, 'Mathews', 'Tarquin', 'nadia@africaonline.co.ke', 'phil@heliprops.co.ke', 'tmathews25@isk.ac.ke', 12, '12994', NULL),
	(511, 'Mazibuko', 'Maxwell', 'mazibukos@yahoo.com', NULL, 'mmazibuko26@isk.ac.ke', 11, '12574', NULL),
	(63, 'Mekonnen', 'Kaleb', 'helenabebaw35@gmail.com', 'm.loulseged@afdb.org', 'kmekonnen31@isk.ac.ke', 6, '11185', NULL),
	(289, 'Melson', 'Sarah', 'metmel@um.dk', 'clausmelson@gmail.com', 'smelson27@isk.ac.ke', 10, '12132', NULL),
	(972, 'Meyers', 'Tamas', 'krisztina.meyers@gmail.com', 'jemeyers@usaid.gov', 'tmeyers32@isk.ac.ke', 5, '12622', NULL),
	(217, 'Mittelstadt', 'Mwende', 'mmaingi84@gmail.com', 'joel@meridian.co.ke', 'mmittelstadt26@isk.ac.ke', 11, '11098', NULL),
	(162, 'Miyanue', 'Joyous', 'knbajia8@gmail.com', 'tpngwa@gmail.com', 'jmiyanue26@isk.ac.ke', 11, '11582', NULL),
	(888, 'Mollier-Camus', 'Victor', 'carole.mollier.camus@gmail.com', 'simon.mollier-camus@bakerhughes.com', 'vmollier-camus31@isk.ac.ke', 6, '12594', NULL),
	(869, 'Elkana', 'Yuval', 'maayan180783@gmail.com', 'tamir260983@gmail.com', 'yelkana33@isk.ac.ke', 4, '13002', NULL),
	(1051, 'Ephrem Yohannes', 'Reem', 'berhe@unhcr.org', 'jdephi@gmail.com', 'rephremyohannes25@isk.ac.ke', 12, '11748', NULL),
	(189, 'Fest', 'Lina', 'marilou_de_wit@hotmail.com', 'michel.fest@gmail.com', 'lfest25@isk.ac.ke', 12, '10279', NULL),
	(525, 'Firzé Al Ghaoui', 'Laé', 'agnaima@gmail.com', 'olivierfirze@gmail.com', 'lfirzealghaoui31@isk.ac.ke', 6, '12191', NULL),
	(180, 'Nicolau Meganck', 'Emilia', 'nicolau.joana@gmail.com', 'joana.olivier2016@gmail.com', 'enicolaumeganck36@isk.ac.ke', 1, '12797', NULL),
	(309, 'Noordin', 'Ahmad Eissa', 'iman@thenoordins.com', 'nadeem.noordin@copycatgroup.com', 'anoordin32@isk.ac.ke', 5, '11611', NULL),
	(618, 'O''Bra', 'Kai', 'hbobra@gmail.com', 'bcobra@gmail.com', 'kobra30@isk.ac.ke', 7, '12342', 'Beginning Band 8 - 2023'),
	(1009, 'Oberjuerge', 'Wesley', 'kateharris22@gmail.com', 'loberjue@gmail.com', 'woberjuerge29@isk.ac.ke', 8, '12685', NULL),
	(609, 'Patel', 'Olivia', 'vbeiner@isk.ac.ke', 'nilesh140@hotmail.com', 'opatel30@isk.ac.ke', 7, '10561', 'Beginning Band 1 2023'),
	(815, 'Patel', 'Aariyana', 'roshninp1128@gmail.com', 'niknpatel@gmail.com', 'apatel27@isk.ac.ke', 10, '12553', NULL),
	(334, 'Patel', 'Vanaaya', 'sunira29@gmail.com', 'umang@vegpro-group.com', 'vpatel27@isk.ac.ke', 10, '20839', NULL),
	(938, 'Patenaude', 'Alexandre', 'shanyoung86@gmail.com', 'patenaude.joel@gmail.com', 'apatenaude36@isk.ac.ke', 1, '12743', NULL),
	(946, 'Pijovic', 'Amandla', 'somatatakone@yahoo.com', 'somatatakone@yahoo.com', 'apijovic35@isk.ac.ke', 2, '13090', NULL),
	(385, 'Plunkett', 'Takumi', 'makiplunkett@live.jp', 'jplun585@gmail.com', 'tplunkett28@isk.ac.ke', 9, '12854', NULL),
	(42, 'Purdy', 'Christiaan', 'Mangoshy@yahoo.com', 'jess_a_purdy@yahoo.com', 'cpurdy31@isk.ac.ke', 6, '12348', NULL),
	(53, 'Roe', 'Elizabeth', 'christinarece@gmail.com', 'aron.roe@international.gc.ca', 'eroe27@isk.ac.ke', 10, '12186', NULL),
	(746, 'Romero SáNchez-Miranda', 'Amanda', 'carmen.sanchez@un.org', 'ricardoromerolopez@gmail.com', 'asanchez-miranda33@isk.ac.ke', 4, '12800', NULL),
	(16, 'Rosen', 'August', 'Lollerosen@gmail.com', 'mikaeldissing@gmail.com', 'arosen27@isk.ac.ke', 10, '11845', NULL),
	(260, 'Rughani', 'Sidh', 'priticrughani@gmail.com', 'cirughani@gmail.com', 'srughani27@isk.ac.ke', 10, '10770', NULL),
	(216, 'Sankoh', 'Adam-Angelo', 'ckoroma@unicef.org', 'baimankay.sankoh@wfp.org', 'aasankoh33@isk.ac.ke', 4, '12441', NULL),
	(960, 'Santos', 'Santiago', 'achang_911@yahoo.com', 'jsants16@yahoo.com', 'ssantos33@isk.ac.ke', 4, '13093', NULL),
	(781, 'Schoneveld', 'Jake', 'nicoliendelange@hotmail.com', 'georgeschoneveld@gmail.com', 'jschoneveld37@isk.ac.ke', 0, '13086', NULL),
	(429, 'Sengendo', 'Ethan', 'jusmug@yahoo.com', 'e.sennoga@afdb.org', 'esengendo26@isk.ac.ke', 11, '11702', NULL),
	(357, 'Shah', 'Radha', 'reena23sarit@gmail.com', 'sarit.shah@saritcentre.com', 'rshah29@isk.ac.ke', 8, '10786', NULL),
	(359, 'Shah', 'Anaiya', 'heena1joshi25@yahoo.co.uk', 'jilan21@hotmail.com', 'ashah30@isk.ac.ke', 7, '11264', 'Beginning Band 7 2023'),
	(779, 'Shah', 'Aanya', 'bhattdeepa@hotmail.com', 'smeet@sapphirelimited.net', 'ashah28@isk.ac.ke', 9, '12583', NULL),
	(862, 'Skaaraas-Gjoelberg', 'Theodor', 'ceciskaa@yahoo.com', 'erlendmagnus@hotmail.com', 'tgjoelberg35@isk.ac.ke', 2, '12845', NULL),
	(800, 'Somaia', 'Nichelle', 'ishisomaia@gmail.com', 'vishal@murbanmovers.co.ke', 'nsomaia35@isk.ac.ke', 2, '12842', NULL),
	(953, 'Soobrattee', 'Ewyn', 'jhomanchuk@yahoo.com', 'rsoobrattee@hotmail.com', 'esoobrattee34@isk.ac.ke', 3, '12714', NULL),
	(92, 'Stott', 'Maartje', 'arineachterstraat@me.com', 'stottbrian@me.com', 'mstott30@isk.ac.ke', 7, '12519', 'Beginning Band 1 2023'),
	(1056, 'Sykes', 'Elliot', 'cate@colinsykes.com', 'mail@colinsykes.com', 'esykes25@isk.ac.ke', 12, '12951', NULL),
	(275, 'Tall', 'Fatuma', 'jgacheke@isk.ac.ke', 'pmtall@gmail.com', 'ftall28@isk.ac.ke', 9, '11515', 'Concert Band 2023'),
	(653, 'Taneem', 'Umaiza', 'mahfuhai@gmail.com', 'taneem.a@gmail.com', 'utaneem28@isk.ac.ke', 9, '11336', NULL),
	(501, 'Tassew', 'Abigail', 'faithmekuria24@gmail.com', 'tassew@gmail.com', 'atassew33@isk.ac.ke', 4, '12637', NULL),
	(393, 'Thongmod', 'Sorawit (Nico)', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'sthongmod31@isk.ac.ke', 6, '12214', NULL),
	(608, 'Thu', 'Phyo Nyein Nyein', 'lwint@unhcr.org', 'lwinkyawkyaw@gmail.com', 'pthu29@isk.ac.ke', 8, '12302', NULL),
	(762, 'Trujillo', 'Emilio', 'prisscilagbaxter@gmail.com', 'mtrujillo@isk.ac.ke', 'etrujillo37@isk.ac.ke', 0, '13067', NULL),
	(316, 'Vellenga', 'Rose', 'kristenmaddock@hotmail.co.uk', 'Rvellenga@unicef.org', 'rvellenga32@isk.ac.ke', 5, '11574', NULL),
	(1036, 'Vestergaard', 'AsbjøRn', 'marves@um.dk', 'elrulu@protonmail.com', 'avestergaard27@isk.ac.ke', 10, '12663', NULL),
	(964, 'Vestergaard', 'Nanna', 'marves@um.dk', 'elrulu@protonmail.com', 'navestergaard33@isk.ac.ke', 4, '12665', NULL),
	(883, 'Waalewijn', 'Simon', 'manonwaalewijn@gmail.com', 'manonenpieter@gmail.com', 'swaalewijn25@isk.ac.ke', 12, '12596', NULL),
	(57, 'Weurlander', 'Frida', 'pia.weurlander@gmail.com', 'matts.weurlander@gmail.com', 'fweurlander32@isk.ac.ke', 5, '12440', NULL),
	(121, 'Willis', 'Isla', 'tjpeta.willis@gmail.com', 'pt.willis@bigpond.com', 'iwillis30@isk.ac.ke', 7, '12969', 'Beginning Band 8 - 2023'),
	(657, 'Wittmann', 'Soline', 'benedicte.wittmann@yahoo.fr', 'christophewittmann@yahoo.fr', 'swittmann26@isk.ac.ke', 11, '12429', NULL),
	(185, 'Wood', 'Teagan', 'carriewoodtz@gmail.com', 'cwood.ken@gmail.com', 'twood27@isk.ac.ke', 10, '10972', NULL),
	(118, 'Yun', 'Geonu', 'juhee907000@gmail.com', 'tony.yun80@gmail.com', 'gyun33@isk.ac.ke', 4, '12487', NULL),
	(117, 'Yun', 'Jeongu', 'juhee907000@gmail.com', 'tony.yun80@gmail.com', 'jyun34@isk.ac.ke', 3, '12492', NULL),
	(769, 'Zeynu', 'Abem', 'nebihat.muktar@gmail.com', 'zeynu.ummer@undp.org', 'azeynu29@isk.ac.ke', 8, '12552', NULL),
	(768, 'Zeynu', 'Aymen', 'nebihat.muktar@gmail.com', 'zeynu.ummer@undp.org', 'azeynu33@isk.ac.ke', 4, '12809', NULL),
	(74, 'Murathi', 'Megan', 'ngugir@hotmail.com', 'ammuturi@yahoo.com', 'mmurathi29@isk.ac.ke', 8, '11735', NULL),
	(398, 'Nguyen', 'Phuc Anh', 'vietha.sbvhn@gmail.com', 'hnguyen@isk.ac.ke', 'pnguyen30@isk.ac.ke', 7, '11260', 'Beginning Band 1 2023'),
	(397, 'Nguyen', 'Phuong An', 'vietha.sbvhn@gmail.com', 'hnguyen@isk.ac.ke', 'pnguyen32@isk.ac.ke', 5, '11261', NULL),
	(991, 'Lundell', 'Seth', 'rebekahlundell@gmail.com', 'redlundell@gmail.com', 'slundell30@isk.ac.ke', 7, '12691', 'Beginning Band 7 2023'),
	(90, 'Alemu', 'Leul', 'esti20022@gmail.com', 'alemus20022@gmail.com', 'lalemu31@isk.ac.ke', 6, '13004', NULL),
	(213, 'Varga', 'Amira', 'hugi.ev@gmail.com', NULL, 'avarga31@isk.ac.ke', 6, '11705', NULL),
	(532, 'Eidex', 'Simone', 'waterlily6970@gmail.com', NULL, 'seidex25@isk.ac.ke', 12, '11897', NULL),
	(61, 'Aubrey', 'Evie', 'joaubrey829@gmail.com', 'dyfed.aubrey@un.org', 'eaubrey24@isk.ac.ke', 13, '10950', NULL),
	(82, 'Awori', 'Andre', 'jeawori@gmail.com', 'jeremyawori@gmail.com', 'aawori24@isk.ac.ke', 13, '24068', NULL),
	(219, 'Charette', 'Tea', 'mdimitracopoulos@isk.ac.ke', 'acharette@isk.ac.ke', 'tcharette24@isk.ac.ke', 13, '20781', NULL),
	(814, 'Chowdhury', 'Nevzad', 'mohira22@yahoo.com', 'numayr_chowdhury@yahoo.com', 'nchowdhury25@isk.ac.ke', 12, '12868', NULL),
	(1, 'Farraj', 'Carlos Laith', 'gmcabrera2017@gmail.com', 'amer_farraj@yahoo.com', 'cfarraj32@isk.ac.ke', 16, '12607', NULL),
	(62, 'Mahmud', 'Raeed', 'eshajasmine@gmail.com', 'kmahmud@gmail.com', 'rmahmud24@isk.ac.ke', 13, '11910', NULL),
	(86, 'Mwangi', 'Joy', 'winrose@flexi-personnel.com', 'wawerujamesmwangi@gmail.com', 'jmwangi24@isk.ac.ke', 13, '10557', NULL),
	(91, 'Otterstedt', 'Lisa', 'annika.otterstedt@icloud.com', 'isak.isaksson@naturskyddsforeningen.se', 'lotterstedt24@isk.ac.ke', 13, '12336', NULL),
	(1067, 'Rex', 'Julian', 'helenerex@gmail.com', 'familyrex@gmail.com', 'jrex24@isk.ac.ke', 13, '10922', NULL),
	(1068, 'Scanlon', 'Luca', 'kim@wolfenden.net', 'shane.scanlon@rescue.org', 'lscanlon24@isk.ac.ke', 13, '12557', NULL),
	(368, 'Bommadevara', 'Sharmila Devi', 'malini.hemamalini@gmail.com', 'bvramana@hotmail.com', 'sbommadevera24@isk.ac.ke', 13, '10505', NULL),
	(222, 'Burns', 'Ryan', 'sburns@isk.ac.ke', 'Johnburnskenya@gmail.com', 'rburns24@isk.ac.ke', 13, '11199', NULL),
	(174, 'Copeland', 'Rainey', 'susancopeland@gmail.com', 'charlescopeland@gmail.com', 'rcopeland24@isk.ac.ke', 13, '12003', NULL),
	(205, 'Dalla Vedova Sanjuan', 'Yago', 'felasanjuan13@gmail.com', 'giovanni.dalla-vedova@ericsson.com', 'ydallavedova24@isk.ac.ke', 13, '12444', NULL),
	(621, 'Davis', 'Maya', 'jdavis@isk.ac.ke', 'matt.davis@crs.org', 'mdavis24@isk.ac.ke', 13, '10953', NULL),
	(547, 'De Vries Aguirre', 'Marco', 'pangolinaty@yahoo.com', 'mmgoez1989@gmail.com', 'mdevries-aguirre24@isk.ac.ke', 13, '11551', NULL),
	(478, 'Exel', 'Hannah', 'kexel@usaid.gov', 'jexel@worldbank.org', 'hexel24@isk.ac.ke', 13, '12074', NULL),
	(386, 'Gagnidze', 'Catherina', 'laramief@yahoo.com', 'LEVGAG@YAHOO.COM', 'cgagnidze24@isk.ac.ke', 13, '11556', NULL),
	(578, 'Gandhi', 'Hrushikesh', 'gayatri.gandhi0212@gmail.com', 'gandhi.harish@gmail.com', 'hgandhi24@isk.ac.ke', 13, '12524', NULL),
	(381, 'Higgins', 'Louisa', 'katehiggins77@yahoo.com', 'kevanphiggins@gmail.com', 'lhiggins24@isk.ac.ke', 13, '11743', NULL),
	(152, 'Ibrahim', 'Ibrahim', 'shukrih77@gmail.com', 'aliban@cdc.gov', 'ijuma24@isk.ac.ke', 13, '11666', NULL),
	(431, 'Jensen', 'Felix', 'arietajensen@gmail.com', 'dannje@um.dk', 'fjensen34@isk.ac.ke', 3, '12238', NULL),
	(574, 'Joo', 'Hyojin', 'ruvigirl@icloud.com', 'jeongje.joo@gmail.com', 'hjoo24@isk.ac.ke', 13, '11685', NULL),
	(257, 'Kefela', 'Hiyabel', 'mehari.kefela@palmoil.co.ke', 'akberethabtay2@gmail.com', 'hkefela24@isk.ac.ke', 13, '11444', NULL),
	(553, 'Kraemer', 'Isabela', 'leticiarc73@gmail.com', 'eduardovk03@gmail.com', 'ikraemer24@isk.ac.ke', 13, '11907', NULL),
	(528, 'Ledgard', 'Hamish', 'marta_ledgard@mzv.cz', 'eternaut@icloud.com', 'hledgard24@isk.ac.ke', 13, '12268', NULL),
	(579, 'Leon', 'Max', 'andrealeon@gmx.de', 'm.d.lance007@gmail.com', 'mleon24@isk.ac.ke', 13, '12490', NULL),
	(394, 'Makimei', 'Henk', 'MariaTwerda@redcross.org.uk', 'ig.makimei2014@gmail.com', 'hmakimei24@isk.ac.ke', 13, '11860', NULL),
	(396, 'Maldonado', 'Che', 'smaldonado@isk.ac.ke', 'mam27553@yahoo.com', 'cmaldonado24@isk.ac.ke', 13, '11170', NULL),
	(225, 'Marriott', 'Isaiah', 'sibilawsonmarriott@gmail.com', 'rkmarriott@gmail.com', 'imarriott24@isk.ac.ke', 13, '11572', NULL),
	(243, 'Mathew', 'Mandisa', 'bhattacharjee.parinita@gmail.com', 'aniljmathew@gmail.com', 'mmathew24@isk.ac.ke', 13, '10881', NULL),
	(454, 'Mishra', 'Arushi', 'sumananjali@gmail.com', 'prafulla2001@gmail.com', 'armishra24@isk.ac.ke', 13, '12488', NULL),
	(453, 'Mishra', 'Amishi', 'sumananjali@gmail.com', 'prafulla2001@gmail.com', 'ammishra24@isk.ac.ke', 13, '12489', NULL),
	(346, 'Mwenya', 'Chansa', 'mwansachishimba10@yahoo.co.uk', 'kasonde.mwenya@un.org', 'cmwenya24@isk.ac.ke', 13, '24018', NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.students (id, last_name, first_name, parent1_email, parent2_email, email, grade_level, student_number, class) VALUES
	(458, 'Norman', 'Lise', 'hambrouc@unhcr.org', 'johannorman62@gmail.com', 'lnorman24@isk.ac.ke', 13, '11533', NULL),
	(483, 'Peck', 'Sofia', 'andrea.m.peck@gmail.com', 'robert.b.peck@gmail.com', 'speck24@isk.ac.ke', 13, '11892', NULL),
	(401, 'Petrangeli', 'Gabriel', 'ivanikolicinkampala@yahoo.com', 'junior.antonio@sobetrainternational.com', 'gpetrangeli24@isk.ac.ke', 13, '11009', NULL),
	(150, 'Pozzi', 'Basile', 'brucama@gmail.com', 'brucama@gmail.com', 'bpozzi24@isk.ac.ke', 13, '10275', NULL),
	(276, 'Price-Abdi', 'Yasmin', 'Suzyyprice@yahoo.com', 'yusufhas@gmail.com', 'yprice-abdi24@isk.ac.ke', 13, '10487', NULL),
	(14, 'Rosen', 'Rosa Marie', 'Lollerosen@gmail.com', 'mikaeldissing@gmail.com', 'rrosen33@isk.ac.ke', 4, '11764', NULL),
	(288, 'Sanders', 'Teresa', 'angelaferrsan@gmail.com', 'jpsanders32@gmail.com', 'tsanders24@isk.ac.ke', 13, '10431', NULL),
	(408, 'Schwabel', 'Miriam', 'kschwabel@gmail.com', 'jasones99@gmail.com', 'mschwabel24@isk.ac.ke', 13, '12267', NULL),
	(270, 'Shah', 'Nirvaan', 'bsshah1@gmail.com', 'bhartesh1@gmail.com', 'nshah24@isk.ac.ke', 13, '10774', NULL),
	(280, 'Shah', 'Ryka', 'bshah63@gmail.com', 'pk64shah@gmail.com', 'rshah24@isk.ac.ke', 13, '10955', NULL),
	(128, 'Sheridan', 'Erika', 'noush007@hotmail.com', 'alan.sheridan@wfp.org', 'esheridan24@isk.ac.ke', 13, '11591', NULL),
	(508, 'Sims', 'Ella', 'kwest@mac.com', 'oscar.sims@mac.com', 'esims24@isk.ac.ke', 13, '24043', NULL),
	(248, 'Steel', 'Ethan', 'dianna.kopansky@un.org', 'derek@ramco.co.ke', 'esteel24@isk.ac.ke', 13, '11442', NULL),
	(328, 'Tunbridge', 'Saba', 'louise.tunbridge@gmail.com', NULL, 'stunbridge24@isk.ac.ke', 13, '10645', NULL),
	(489, 'Van Der Vliet', 'Grecy', 'lauretavdva@gmail.com', 'janisvliet@gmail.com', 'gvandervliet24@isk.ac.ke', 13, '11629', NULL),
	(479, 'Vutukuru', 'Sumedh Vedya', 'schodavarapu@ifc.org', 'vvutukuru@worldbank.org', 'svutukuru24@isk.ac.ke', 13, '11569', NULL),
	(283, 'Wangari', 'Tatyana', 'yndungu@gmail.com', NULL, 'twangari24@isk.ac.ke', 13, '11877', NULL),
	(264, 'Wissanji', 'Mikayla', 'rwissanji@gmail.com', 'shaheed.wissanji@sopalodges.com', 'mwissanji24@isk.ac.ke', 13, '11440', NULL),
	(163, 'Nkahnue', 'Marvelous Peace', 'knbajia8@gmail.com', 'tpngwa@gmail.com', 'mnkahnue24@isk.ac.ke', 13, '11583', NULL),
	(211, 'Ahmed', 'Zeeon', 'nahreen.farjana@gmail.com', 'ahmedzu@gmail.com', 'zahmed24@isk.ac.ke', 13, '11570', NULL),
	(246, 'Ahmed', 'Osman', 'zahraaden@gmail.com', 'yassinoahmed@gmail.com', 'oahmed24@isk.ac.ke', 13, '11745', NULL),
	(340, 'Allport', 'Kian', 'shelina@safari-mania.com', 'rallport75@gmail.com', 'kallport24@isk.ac.ke', 13, '11445', NULL),
	(77, 'Bellamy', 'Lillia', 'ahuggins@mercycorps.org', 'bellamy.paul@gmail.com', 'lbellamy33@isk.ac.ke', 4, '11942', NULL),
	(330, 'Bamlango', 'Diane', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'dbamlango36@isk.ac.ke', 1, '12371', NULL),
	(251, 'Bid', 'Arhum', 'snehalbid@gmail.com', 'rahulbid23@gmail.com', 'abid30@isk.ac.ke', 7, '11706', 'Beginning Band 1 2023'),
	(293, 'Bini', 'Bianca', 'boschettiraffaella@gmail.com', 'boschettiraffaella@gmail.com', 'bbini34@isk.ac.ke', 3, '12731', NULL),
	(315, 'Bjornholm', 'Jonathan', 'sbjornholm@me.com', 'ulf.bjornholm@un.org', 'jbjornholm25@isk.ac.ke', 12, '11040', NULL),
	(232, 'Blaschke', 'Sasha', 'cmcmorrison@gmail.com', 'sean.blaschke@gmail.com', 'sblaschke32@isk.ac.ke', 5, '11599', NULL),
	(267, 'Chandaria', 'Meiya', 'yuko.kurauchi@gmail.com', 'kunal.chandaria@gmail.com', 'mchandaria31@isk.ac.ke', 6, '10932', NULL),
	(240, 'Chandaria', 'Aarav', 'preenas@gmail.com', 'vijaychandaria@gmail.com', 'achandaria32@isk.ac.ke', 5, '11792', NULL),
	(319, 'Clements', 'Ciaran', 'jill.a.clements@gmail.com', 'shanedanielricketts@gmail.com', 'cclements28@isk.ac.ke', 9, '11843', NULL),
	(296, 'Cutler', 'Leo', 'megseyjackson@gmail.com', 'adrianhcutler@gmail.com', 'lcutler27@isk.ac.ke', 10, '10673', NULL),
	(292, 'Doshi', 'Anay', 'adoshi@wave.co.ke', 'vdoshi@wave.co.ke', 'adoshi28@isk.ac.ke', 9, '10636', NULL),
	(221, 'Giblin', 'Auberlin (Addie)', 'kloehr@gmail.com', 'drewgiblin@gmail.com', 'agiblin29@isk.ac.ke', 8, '12964', NULL),
	(341, 'Hagelberg', 'Reid', 'Lisa@virginbushsafaris.com', 'niklas.hagelberg@un.org', 'rhagelberg27@isk.ac.ke', 10, '12094', NULL),
	(147, 'Hussain', 'Shams', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'shussain33@isk.ac.ke', 4, '11496', NULL),
	(252, 'Janmohamed', 'Yara', 'nabila.wissanji@gmail.com', 'gj@jansons.co.za', 'yjanmohamed32@isk.ac.ke', 5, '12173', NULL),
	(325, 'Khubchandani', 'Layla', 'ramji.farzana@gmail.com', 'rishi.khubchandani@gmail.com', 'lkhubchandani27@isk.ac.ke', 10, '11263', NULL),
	(235, 'Kobayashi', 'Maaya', 'kobayashiyoko8@gmail.com', 'jdasilva66@gmail.com', 'mkobayashi31@isk.ac.ke', 6, '11575', NULL),
	(306, 'Landolt', 'Mark', 'nadia.landolt@yahoo.com', 'jclandolt@icrc.org', 'mlandolt28@isk.ac.ke', 9, '12284', NULL),
	(305, 'Landolt', 'Jana', 'nadia.landolt@yahoo.com', 'jclandolt@icrc.org', 'jlandolt28@isk.ac.ke', 9, '12285', 'Concert Band 2023'),
	(304, 'Landolt', 'Stefanie', 'nadia.landolt@yahoo.com', 'jclandolt@icrc.org', 'slandolt30@isk.ac.ke', 7, '12286', 'Beginning Band 8 - 2023'),
	(107, 'Lopez Abella', 'Lucas', 'monica.lopezconlon@gmail.com', 'iniakiag@gmail.com', 'llopezabella33@isk.ac.ke', 4, '11759', NULL),
	(258, 'Manji', 'Arra', 'tnathoo@gmail.com', 'allymanji@gmail.com', 'amanji32@isk.ac.ke', 5, '12416', NULL),
	(320, 'Nair', 'Ahana', 'pinkilika@gmail.com', 'gautamn@techno-associates.co.ke', 'anair35@isk.ac.ke', 2, '12332', NULL),
	(285, 'Nanji', 'Zameer', 'Narmeen_r@yahoo.com', 'zahid@abc-place.com', 'znanji27@isk.ac.ke', 10, '10416', NULL),
	(298, 'Nzioka', 'Jordan', 'bmusyoka@isk.ac.ke', 'nziokarobert.rn@gmail.com', 'jnzioka34@isk.ac.ke', 3, '11884', NULL),
	(212, 'Okwany', 'Hawi', 'bijaflowers@yahoo.com', 'stonekidi@yahoo.com', 'hokwany29@isk.ac.ke', 8, '10696', 'Concert Band 2023'),
	(249, 'Otieno', 'Brianna', 'maureenagengo@gmail.com', 'jotieno@isk.ac.ke', 'botieno28@isk.ac.ke', 9, '11271', NULL),
	(326, 'Patel', 'Nikhil', 'shruti.bahety@gmail.com', 'akithpatel@gmail.com', 'npatel35@isk.ac.ke', 2, '12494', NULL),
	(335, 'Patel', 'Veer', 'sunira29@gmail.com', 'umang@vegpro-group.com', 'veerpatel27@isk.ac.ke', 10, '20840', NULL),
	(349, 'Patel', 'Rhiyana', 'rajul@ramco.co.ke', 'hasit@ramco.co.ke', 'rpatel26@isk.ac.ke', 11, '26025', NULL),
	(286, 'Paul', 'Esther', 'Megpaul47@icloud.Com', NULL, 'epaul28@isk.ac.ke', 9, '11326', NULL),
	(279, 'Raja', 'Keiya', 'nlpwithshilpa@gmail.com', 'neeraj@raja.org.uk', 'kraja28@isk.ac.ke', 9, '10637', NULL),
	(255, 'Rogers', 'Junin', 'sorogers@usaid.gov', 'drogers@usaid.gov', 'jrogers31@isk.ac.ke', 6, '12209', NULL),
	(79, 'Ronzio', 'Louis', 'janinecocker@gmail.com', 'jronzio@gmail.com', 'lronzio33@isk.ac.ke', 4, '12197', NULL),
	(308, 'Ruiz Stannah', 'Tamia', 'ruizstannah@gmail.com', 'stephen.stannah@un.org', 'truizstannah25@isk.ac.ke', 12, '25032', NULL),
	(287, 'Sanders', 'Liam', 'angelaferrsan@gmail.com', 'jpsanders32@gmail.com', 'lsanders26@isk.ac.ke', 11, '10430', NULL),
	(323, 'Shah', 'Parth', 'KAUSHISHAH@HOTMAIL.COM', 'KBS.KIFARU@GMAIL.COM', 'pshah26@isk.ac.ke', 11, '10993', NULL),
	(273, 'Shamji', 'Sofia', 'farah@aaagrowers.co.ke', 'ariff@aaagrowers.co.ke', 'sshamji28@isk.ac.ke', 9, '11839', NULL),
	(239, 'Suther', 'Erik', 'ansuther@hotmail.com', 'dansuther@hotmail.com', 'esuther29@isk.ac.ke', 8, '10511', NULL),
	(274, 'Tall', 'Oumi', 'jgacheke@isk.ac.ke', 'pmtall@gmail.com', 'otall31@isk.ac.ke', 6, '11472', NULL),
	(227, 'Teel', 'Camden', 'destiny1908@hotmail.com', 'bernard1906@hotmail.com', 'cteel32@isk.ac.ke', 5, '12360', NULL),
	(228, 'Teel', 'Jaidyn', 'destiny1908@hotmail.com', 'bernard1906@hotmail.com', 'jteel30@isk.ac.ke', 7, '12361', NULL),
	(98, 'Todd', 'Sofia', 'carli@vovohappilyorganic.com', 'rich.toddy77@gmail.com', 'stodd34@isk.ac.ke', 3, '11731', NULL),
	(96, 'Van De Velden', 'Christodoulos', 'smafro@gmail.com', 'jaapvandevelden@gmail.com', 'cvandevelden33@isk.ac.ke', 4, '11788', NULL),
	(297, 'Wachira', 'Andrew', 'suzielawrence@yahoo.co.uk', 'lawrence.githinji@ke.atlascopco.com', 'awachira26@isk.ac.ke', 11, '20866', NULL),
	(303, 'Weaver', 'Sachin', 'rebeccajaneweaver@gmail.com', NULL, 'sweaver25@isk.ac.ke', 12, '10715', NULL),
	(142, 'Yarkoni', 'Ohad', 'dvorayarkoni4@gmail.com', 'yarkan1@yahoo.com', 'oyarkoni33@isk.ac.ke', 4, '12167', NULL),
	(245, 'Ahmed', 'Mariam', 'zahraaden@gmail.com', 'yassinoahmed@gmail.com', 'mahmed28@isk.ac.ke', 9, '12159', NULL),
	(313, 'Baheta', 'Bruke', 'Thadera@hotmail.com', 'dbaheta@unicef.org', 'bbaheta28@isk.ac.ke', 9, '10800', NULL),
	(314, 'Baheta', 'Helina', 'Thadera@hotmail.com', 'dbaheta@unicef.org', 'hebaheta25@isk.ac.ke', 12, '20766', NULL),
	(238, 'Bajwa', 'Mohammad Haroon', 'akbarfarzana12@gmail.com', 'mabajwa@unicef.org', 'mbajwa28@isk.ac.ke', 9, '10941', NULL),
	(379, 'Berezhny', 'Maxym', 'lubashara078@gmail.com', 'oles@berezhny.net', 'mberezhny27@isk.ac.ke', 10, '10878', NULL),
	(353, 'Bhandari', 'Kiara', 'srbhandari406@gmail.com', 'avnish@intercool.co.ke', 'kbhandari27@isk.ac.ke', 10, '10791', NULL),
	(271, 'Butt', 'Ayana', 'flalani-butt@isk.ac.ke', 'sameer.butt@outlook.com', 'abutt30@isk.ac.ke', 7, '11402', 'Beginning Band 1 2023'),
	(406, 'Clark', 'Laras', 'agniparamita@gmail.com', 'samueltclark@gmail.com', 'lclark33@isk.ac.ke', 4, '11786', NULL),
	(294, 'Cutler', 'Otis', 'megseyjackson@gmail.com', 'adrianhcutler@gmail.com', 'ocutler32@isk.ac.ke', 5, '11535', NULL),
	(291, 'Doshi', 'Ashi', 'adoshi@wave.co.ke', 'vdoshi@wave.co.ke', 'adoshi32@isk.ac.ke', 5, '11768', NULL),
	(278, 'Fort', 'Connor', 'kellymaura@gmail.com', 'brycelfort@gmail.com', 'cfort30@isk.ac.ke', 7, '11650', 'Beginning Band 7 2023'),
	(375, 'Furness', 'Zoe', 'terrifurness@gmail.com', 'tim@amanzi.ke', 'zfurness24@isk.ac.ke', 13, '11101', NULL),
	(410, 'Gremley', 'Ben', 'emmagremley@gmail.com', 'andrewgremley@gmail.com', 'bgremley26@isk.ac.ke', 11, '12113', NULL),
	(380, 'Higgins', 'Thomas', 'katehiggins77@yahoo.com', 'kevanphiggins@gmail.com', 'thiggins26@isk.ac.ke', 11, '11744', NULL),
	(362, 'Inglis', 'Lengai', 'lieslkareninglis@gmail.com', NULL, 'linglis27@isk.ac.ke', 10, '12131', NULL),
	(414, 'Jackson', 'Ciara', 'laurajfrost@gmail.com', 'stephenwjackson@gmail.com', 'cjackson25@isk.ac.ke', 12, '12071', NULL),
	(389, 'Jama', 'Guled', 'lucky74f@gmail.com', 'hargeisa1000@gmail.com', 'gjama30@isk.ac.ke', 7, '12757', NULL),
	(356, 'Khagram', 'Sam', 'karen@khagram.org', 'vishal@riftcot.com', 'skhagram26@isk.ac.ke', 11, '11858', NULL),
	(360, 'Khan', 'Cuyuni', 'sheila.aggarwalkhan@gmail.com', 'seanadriankhan@gmail.com', 'ckhan26@isk.ac.ke', 11, '12013', NULL),
	(344, 'Kimmelman-May', 'Chloe', 'shannon.k.may@gmail.com', 'jay.kimmelman@gmail.com', 'ckimmelman-may28@isk.ac.ke', 9, '12353', NULL),
	(383, 'Lindgren', 'Anyamarie', 'annewendy13@gmail.com', 'jalsweden@gmail.com', 'alindgren28@isk.ac.ke', 9, '11389', NULL),
	(395, 'Maldonado', 'Mira', 'smaldonado@isk.ac.ke', 'mam27553@yahoo.com', 'mmaldonado26@isk.ac.ke', 11, '11175', NULL),
	(354, 'Monadjem', 'Safa', 'shekufehk@yahoo.com', 'bmonadjem@gmail.com', 'smonadjem33@isk.ac.ke', 4, '12224', NULL),
	(355, 'Monadjem', 'Malaika', 'shekufehk@yahoo.com', 'bmonadjem@gmail.com', 'mmonadjem25@isk.ac.ke', 12, '25076', NULL),
	(415, 'Nelson', 'Ansley', 'kmctamney@gmail.com', 'nelsonex1080@gmail.com', 'anelson35@isk.ac.ke', 2, '12806', NULL),
	(299, 'Nzioka', 'Zuriel', 'bmusyoka@isk.ac.ke', 'nziokarobert.rn@gmail.com', 'znzioka32@isk.ac.ke', 5, '11313', NULL),
	(302, 'Otieno', 'Riani Tunu', 'alividza@isk.ac.ke', 'eotieno@isk.ac.ke', 'riaotieno31@isk.ac.ke', 6, '10866', NULL),
	(301, 'Otieno', 'Ranam Telu', 'alividza@isk.ac.ke', 'eotieno@isk.ac.ke', 'ranotieno31@isk.ac.ke', 6, '10943', NULL),
	(945, 'Pant', 'Yash', 'pantjoyindia@gmail.com', 'hem7star@gmail.com', 'ypant35@isk.ac.ke', 2, '12480', NULL),
	(318, 'Patel', 'Ishaan', 'priya@ramco.co.ke', 'amit@ramco.co.ke', 'ipatel32@isk.ac.ke', 5, '11255', NULL),
	(350, 'Pattni', 'Yash', 'poonampatt@gmail.com', 'pulin@anmoljewellers.biz', 'ypattni29@isk.ac.ke', 8, '10334', NULL),
	(321, 'Pattni', 'Aryaan', 'azmina@vicbank.com', 'yogesh@vicbank.com', 'apattni32@isk.ac.ke', 5, '11729', NULL),
	(307, 'Ruiz Stannah', 'Kianu', 'ruizstannah@gmail.com', 'stephen.stannah@un.org', 'kruizstannah29@isk.ac.ke', 8, '10247', NULL),
	(390, 'Salituri', 'Noha', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'nsalituri35@isk.ac.ke', 2, '12211', NULL),
	(370, 'Sangare', 'Adama', 'taissata@yahoo.fr', 'sangnouh@yahoo.fr', 'asangare25@isk.ac.ke', 12, '12309', NULL),
	(358, 'Shah', 'Vishnu', 'reena23sarit@gmail.com', 'sarit.shah@saritcentre.com', 'vshah26@isk.ac.ke', 11, '10796', NULL),
	(337, 'Shah', 'Savir', 'skhamar77@gmail.com', 'sonaars@gmail.com', 'sshah29@isk.ac.ke', 8, '10965', NULL),
	(336, 'Shah', 'Laina', 'skhamar77@gmail.com', 'sonaars@gmail.com', 'lshah32@isk.ac.ke', 5, '11502', NULL),
	(268, 'Simbiri', 'Ochieng', 'sandra.simbiri@gmail.com', 'davidsimbiri@gmail.com', 'osimbiri30@isk.ac.ke', 7, '11265', 'Beginning Band 1 2023'),
	(382, 'Startup', 'Indhira', 's.mai.rattanavong@gmail.com', 'joshstartup@gmail.com', 'istartup34@isk.ac.ke', 3, '12244', NULL),
	(373, 'Suri', 'Mannat', 'shipra.unhabitat@gmail.com', 'suri.raj@gmail.com', 'msuri32@isk.ac.ke', 5, '11485', NULL),
	(372, 'Trottier', 'Gabrielle', 'gabydou123@hotmail.com', 'ftrotier@hotmail.com', 'gtrottier27@isk.ac.ke', 10, '11945', NULL),
	(377, 'Tshomo', 'Tandin', 'sangdema@gmail.com', 'kpenjor@unicef.org', 'ttshomo29@isk.ac.ke', 8, '12442', NULL),
	(317, 'Vellenga', 'Solomon', 'kristenmaddock@hotmail.co.uk', 'Rvellenga@unicef.org', 'svellenga31@isk.ac.ke', 6, '11573', NULL),
	(400, 'Von Strauss', 'Olivia', 'malin.vonstrauss@gmail.com', 'adam.ojdahl@gmail.com', 'ovonstrauss35@isk.ac.ke', 2, '12719', NULL),
	(363, 'Yohannes', 'Naomi', 'sewit.a@gmail.com', 'biniam.yohannes@gmail.com', 'nyohannes29@isk.ac.ke', 8, '10787', 'Concert Band 2023'),
	(364, 'Yohannes', 'Mathias', 'sewit.a@gmail.com', 'biniam.yohannes@gmail.com', 'myohannes26@isk.ac.ke', 11, '20875', NULL),
	(378, 'Zangmo', 'Thuji', 'sangdema@gmail.com', 'kpenjor@unicef.org', 'tzangmo28@isk.ac.ke', 9, '12394', NULL),
	(59, 'Zhang', 'Dylan', 'bonjourchelsea.zz@gmail.com', 'zhangwei@bucg.cc', 'dzhang35@isk.ac.ke', 2, '12206', NULL),
	(366, 'Arora', 'Avish', 'kulpreet.vikram@gmail.com', 'aroravikramsingh@gmail.com', 'aarora27@isk.ac.ke', 10, '12129', NULL),
	(365, 'Arora', 'Arjan', 'kulpreet.vikram@gmail.com', 'aroravikramsingh@gmail.com', 'aarora28@isk.ac.ke', 9, '12130', 'Concert Band 2023'),
	(412, 'Baig-Giannotti', 'Danial', 'giannotti76@yahoo.it', 'khbaig@yahoo.com', 'dbaig-giannotti35@isk.ac.ke', 2, '12546', NULL),
	(332, 'Bamlango', 'Anne', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'abamlango28@isk.ac.ke', 9, '10978', 'Concert Band 2023'),
	(437, 'Atamuradova', 'Arina', 'businka2101@gmail.com', 'atamoura@unhcr.org', 'aatamuradova25@isk.ac.ke', 12, '11752', NULL),
	(413, 'Baig-Giannotti', 'Daria', 'giannotti76@yahoo.it', 'khbaig@yahoo.com', 'dbaiggiannotti32@isk.ac.ke', 5, '11593', NULL),
	(38, 'Bedein', 'Ziv', 'bebedein@gmail.com', 'gilbeinken@gmail.com', 'zbedein36@isk.ac.ke', 1, '12746', NULL),
	(450, 'Ben Anat', 'Maya', 'benanatim@gmail.com', 'benanatim25@gmail.com', 'mben-anat37@isk.ac.ke', 0, '12643', NULL),
	(250, 'Bid', 'Sohum', 'snehalbid@gmail.com', 'rahulbid23@gmail.com', 'sbid36@isk.ac.ke', 1, '13042', NULL),
	(49, 'Bunbury', 'Oria', 'tammybunbury@gmail.com', 'robertbunbury@gmail.com', 'obunbury36@isk.ac.ke', 1, '12247', NULL),
	(427, 'Burmester', 'Nicholas', 'Margs.Burmester@hotmail.com', 'mads.burmester@hotmail.com', 'nburmester28@isk.ac.ke', 9, '11394', NULL),
	(420, 'Castel-Wang', 'Lea', 'weiyangwang88@gmail.com', NULL, 'lcastel-wang26@isk.ac.ke', 11, '12507', NULL),
	(472, 'Chigudu', 'Nyasha', 'memoshiri@yahoo.co.uk', 'vchigudu@yahoo.co.uk', 'nchigudu25@isk.ac.ke', 12, '11373', NULL),
	(418, 'Cowan', 'Marcella', 'cowseal@aol.com', 'cowanjc@state.gov', 'mcowan28@isk.ac.ke', 9, '12437', NULL),
	(474, 'Essoungou', 'Ines Clelia', 'maymuchka@yahoo.com', 'essoungou@gmail.com', 'iessoungou26@isk.ac.ke', 11, '12522', NULL),
	(460, 'Foley', 'Logan Lilly', 'koech.maureen@gmail.com', 'MPFoley@icloud.com', 'lfoley33@isk.ac.ke', 4, '11758', NULL),
	(435, 'Gerba', 'Porter', 'erin.gerba@gmail.com', 'mogerba2@gmail.com', 'pgerba25@isk.ac.ke', 12, '11449', NULL),
	(433, 'Gerba', 'Andrew', 'erin.gerba@gmail.com', 'mogerba2@gmail.com', 'agerba29@isk.ac.ke', 8, '11462', NULL),
	(466, 'Huber', 'Lisa', 'griet.kenis@gmail.com', 'thorsten.huber@giz.de', 'lhuber27@isk.ac.ke', 10, '12339', NULL),
	(467, 'Huber', 'Jara', 'griet.kenis@gmail.com', 'thorsten.huber@giz.de', 'jhuber26@isk.ac.ke', 11, '12340', NULL),
	(361, 'Inglis', 'Lorian', 'lieslkareninglis@gmail.com', NULL, 'linglis30@isk.ac.ke', 7, '12133', 'Beginning Band 7 2023'),
	(446, 'Jabbour', 'Rasmus', 'anna.kontorov@gmail.com', 'jason.jabbour@gmail.com', 'rjabbour35@isk.ac.ke', 2, '12396', NULL),
	(422, 'Jacques', 'Gloria', 'deuwba@hotmail.com', 'pageja1@hotmail.com', 'gjacques25@isk.ac.ke', 12, '12067', NULL),
	(388, 'Jama', 'Amina', 'lucky74f@gmail.com', 'hargeisa1000@gmail.com', 'ajama32@isk.ac.ke', 5, '11675', NULL),
	(234, 'Marin Fonseca Choucair Ramos', 'Georges', 'jmarin@ifc.org', 'ychoucair@hotmail.com', 'gfonsecaramos33@isk.ac.ke', 4, '12789', NULL),
	(476, 'Mcsharry', 'Theodore', 'emmeline@mcsharry.net', 'patrick@mcsharry.net', 'tmcsharry27@isk.ac.ke', 10, '12563', NULL),
	(461, 'Mills', 'James', 'staceyinvienna@gmail.com', 'pmills27@yahoo.com', 'jmills25@isk.ac.ke', 12, '12376', NULL),
	(416, 'Nelson', 'Caroline', 'kmctamney@gmail.com', 'nelsonex1080@gmail.com', 'cnelson32@isk.ac.ke', 5, '12803', NULL),
	(457, 'Norman', 'Lukas', 'hambrouc@unhcr.org', 'johannorman62@gmail.com', 'lnorman26@isk.ac.ke', 11, '11534', NULL),
	(423, 'Nurshaikhova', 'Dana', 'alma.nurshaikhova@gmail.com', NULL, 'dnurshaikhova27@isk.ac.ke', 10, '11938', NULL),
	(469, 'O''Hearn', 'Maeve', 'ohearnek7@gmail.com', 'ohearn4@msn.com', 'mo''hearn26@isk.ac.ke', 11, '12763', NULL),
	(430, 'Osman', 'Omer', 'rwan.adil13@gmail.com', 'hishammsalih@gmail.com', 'oosman35@isk.ac.ke', 2, '12443', NULL),
	(663, 'Park', 'Jooan', 'hypakuo@gmail.com', 'joonwoo.park@undp.org', 'jpark32@isk.ac.ke', 5, '12786', NULL),
	(473, 'Sakaedani Petrovic', 'Kodjiro', 'asakaedani@unicef.org', 'opetrovic@unicef.org', 'ksakaedanipetrovic25@isk.ac.ke', 12, '12271', NULL),
	(391, 'Salituri', 'Amaia', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'asalituri32@isk.ac.ke', 5, '12212', NULL),
	(392, 'Salituri', 'Leone', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'lsalituri32@isk.ac.ke', 5, '12213', NULL),
	(351, 'Samani', 'Gaurav', 'pooja@amsproperties.com', 'rupen@amsgroup.co.ke', 'gsamani31@isk.ac.ke', 6, '11179', 'Band 8 2024'),
	(352, 'Samani', 'Siddharth', 'pooja@amsproperties.com', 'rupen@amsgroup.co.ke', 'ssamani31@isk.ac.ke', 6, '11180', NULL),
	(947, 'Santos', 'Paola', 'achang_911@yahoo.com', 'jsants16@yahoo.com', 'psantos35@isk.ac.ke', 2, '13094', NULL),
	(424, 'Shah', 'Raheel', 'bhavisha@eazy-group.com', 'neel@eazy-group.com', 'rshah28@isk.ac.ke', 9, '12161', NULL),
	(425, 'Shah', 'Rohan', 'bhavisha@eazy-group.com', 'neel@eazy-group.com', 'rshah26@isk.ac.ke', 11, '20850', NULL),
	(399, 'Smith', 'Charlotte', 'asarahday@gmail.com', 'randysmith@usaid.gov', 'csmith32@isk.ac.ke', 5, '12705', NULL),
	(419, 'Sommerlund', 'Andre', 'sommerlundsurat@yahoo.com', 'sommerlu@unhcr.org', 'asommerlund29@isk.ac.ke', 8, '11717', NULL),
	(371, 'Trottier', 'Lilyrose', 'gabydou123@hotmail.com', 'ftrotier@hotmail.com', 'ltrottier30@isk.ac.ke', 7, '11944', 'Beginning Band 7 2023'),
	(404, 'Veveiros', 'Florencia', 'julie.veveiros5@gmail.com', 'aveveiros@yahoo.com', 'fveveiros31@isk.ac.ke', 6, '12008', NULL),
	(417, 'Wanyoike', 'Tamara', 'lois.wanyoike@gmail.com', 'joe.wanyoike@gmail.com', 'twanyoike25@isk.ac.ke', 12, '12658', NULL),
	(459, 'Wikenczy Thomsen', 'Sebastian', 'swikenczy@yahoo.com', 'anders_thomsen@yahoo.com', 'swikenczy-thomsen25@isk.ac.ke', 12, '11446', NULL),
	(439, 'Yoon', 'Seohyeon', 'japark1981@naver.com', 'yoonzie@gmail.com', 'syoon27@isk.ac.ke', 10, '12791', NULL),
	(481, 'Young', 'Jack', 'dyoung1462@gmail.com', 'dianeandjody@yahoo.com', 'jyoung28@isk.ac.ke', 9, '12323', NULL),
	(445, 'Alnaqbi', 'Ibrahim', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'ialnaqbi26@isk.ac.ke', 11, '12906', NULL),
	(441, 'Alnaqbi', 'Ali', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'aalnaqbi34@isk.ac.ke', 3, '12910', NULL),
	(25, 'Armstrong', 'Kennedy', 'stacia.armstrong@ymail.com', 'patrick.k.armstrong@gmail.com', 'karmstrong25@isk.ac.ke', 12, '12276', NULL),
	(35, 'Ashton', 'Vera', '1charlotteashton@gmail.com', 'todd.ashton@ericsson.com', 'vashton25@isk.ac.ke', 12, '11896', NULL),
	(516, 'Cooney', 'Luna', 'mireillefc@gmail.com', 'danielcooney@gmail.com', 'lcooney33@isk.ac.ke', 4, '12111', NULL),
	(520, 'Dale', 'Ameya', 'gdale@isk.ac.ke', 'jdale@isk.ac.ke', 'adale25@isk.ac.ke', 12, '10495', NULL),
	(26, 'De Backer', 'Lily', 'camilletanza@yahoo.fr', 'pierredeb1@gmail.com', 'ldebacker26@isk.ac.ke', 11, '11856', NULL),
	(515, 'Donohue', 'Christopher Ross', 'adriennedonohue@gmail.com', 'crdonohue@gmail.com', 'cdonohue29@isk.ac.ke', 8, '10333', NULL),
	(50, 'Eom', 'Dawon', 'yinjing7890@gmail.com', 'ikhyuneom@hotmail.com', 'deom26@isk.ac.ke', 11, '12733', NULL),
	(491, 'Giri', 'Rohan', 'lisebendiksen@gmail.com', 'rgiri@unicef.org', 'rgiri26@isk.ac.ke', 11, '12410', NULL),
	(490, 'Giri', 'Maila', 'lisebendiksen@gmail.com', 'rgiri@unicef.org', 'mgiri33@isk.ac.ke', 4, '12421', NULL),
	(462, 'Goold', 'Amira', 'lizagoold@hotmail.co.uk', 'alistairgoold@hotmail.com', 'agoold31@isk.ac.ke', 6, '11820', NULL),
	(463, 'Goold', 'Isla', 'lizagoold@hotmail.co.uk', 'alistairgoold@hotmail.com', 'igoold28@isk.ac.ke', 9, '11836', 'Concert Band 2023'),
	(497, 'Hansen', 'Ines Elise', 'metteojensen@gmail.com', 'thomasnikolaj@hotmail.com', 'ihansen34@isk.ac.ke', 3, '12363', NULL),
	(498, 'Hansen', 'Marius', 'metteojensen@gmail.com', 'thomasnikolaj@hotmail.com', 'mhansen30@isk.ac.ke', 7, '12365', NULL),
	(310, 'Herman-Roloff', 'Lily', 'amykateherman@hotmail.com', 'khermanroloff@gmail.com', 'lherman-roloff33@isk.ac.ke', 4, '12194', NULL),
	(535, 'Hopps', 'Troy', 'rharrison90@gmail.com', 'jasonhopps@gmail.com', 'thopps33@isk.ac.ke', 4, '12306', NULL),
	(465, 'Huber', 'Siri', 'griet.kenis@gmail.com', 'thorsten.huber@giz.de', 'shuber31@isk.ac.ke', 6, '12338', NULL),
	(447, 'Jabbour', 'Olivia', 'anna.kontorov@gmail.com', 'jason.jabbour@gmail.com', 'ojabbour32@isk.ac.ke', 5, '12395', NULL),
	(495, 'Jansson', 'Kai', 'sawanakagawa@gmail.com', 'torjansson@gmail.com', 'kjansson33@isk.ac.ke', 4, '11761', NULL),
	(505, 'Johnson', 'Azzalina', 'bobbiejohnsonbjj@gmail.com', 'donovanshanej@gmail.com', 'ajohnson26@isk.ac.ke', 11, '12865', NULL),
	(494, 'Laurits', 'Charlotte', 'emily.laurits@gmail.com', 'eric.laurits@gmail.com', 'claurits33@isk.ac.ke', 4, '12249', NULL),
	(493, 'Laurits', 'Leonard', 'emily.laurits@gmail.com', 'eric.laurits@gmail.com', 'llaurits35@isk.ac.ke', 2, '12250', NULL),
	(56, 'Lindvig', 'Mimer', 'elisa@lindvig.com', 'jglindvig@gmail.com', 'mlindvig26@isk.ac.ke', 11, '12503', NULL),
	(524, 'Lloyd', 'Elsa', 'apaolo@isk.ac.ke', 'bobcoulibaly@yahoo.com', 'elloyd29@isk.ac.ke', 8, '11464', NULL),
	(480, 'Mabaso', 'Nyasha', 'loicemabaso@icloud.com', 'tmabaso@icao.int', 'nmabaso31@isk.ac.ke', 6, '11657', NULL),
	(519, 'Materne', 'Danaé', 'nat.dekeyser@gmail.com', 'fredmaterne@hotmail.com', 'dmaterne27@isk.ac.ke', 10, '12154', NULL),
	(512, 'Mazibuko', 'Naledi', 'mazibukos@yahoo.com', NULL, 'nmazibuko26@isk.ac.ke', 11, '12573', NULL),
	(513, 'Mazibuko', 'Sechaba', 'mazibukos@yahoo.com', NULL, 'smazibuko26@isk.ac.ke', 11, '12575', NULL),
	(507, 'Mehta', 'Ansh', 'mehtakrishnay@gmail.com', 'ymehta@cevaltd.com', 'amehta29@isk.ac.ke', 8, '10657', 'Concert Band 2023'),
	(487, 'Murape', 'Nandipha', 'tmurape@unicef.org', 'lloydmurape@gmail.com', 'nmurape25@isk.ac.ke', 12, '11700', NULL),
	(75, 'Murathi', 'Eunice', 'ngugir@hotmail.com', 'ammuturi@yahoo.com', 'emurathi25@isk.ac.ke', 12, '11736', NULL),
	(485, 'O''Hara', 'Elia', 'siemerm@hotmail.com', 'corykohara@gmail.com', 'eohara25@isk.ac.ke', 12, '12062', NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.students (id, last_name, first_name, parent1_email, parent2_email, email, grade_level, student_number, class) VALUES
	(468, 'O''Hearn', 'Case', 'ohearnek7@gmail.com', 'ohearn4@msn.com', 'cohearn29@isk.ac.ke', 8, '12764', NULL),
	(551, 'O''Neal', 'Maliah', 'onealp1@yahoo.com', 'onealap@state.gov', 'moneal28@isk.ac.ke', 9, '11912', NULL),
	(455, 'O''Neill Calver', 'Riley', 'laraoneill@gmail.com', 'timcalver@gmail.com', 'roneillcalver32@isk.ac.ke', 5, '11488', NULL),
	(555, 'Prawitz', 'Alba', 'camillaprawitz@gmail.com', 'peter.nilsson@scb.se', 'aprawitz34@isk.ac.ke', 3, '12291', NULL),
	(509, 'Priestley', 'Leila', 'samela.priestley@gmail.com', 'mark.priestley@trademarkea.com', 'lpriestley25@isk.ac.ke', 12, '20843', NULL),
	(506, 'Raja', 'Aaditya', 'darshanaraja@aol.com', 'praja42794@aol.com', 'araja26@isk.ac.ke', 11, '12103', NULL),
	(548, 'Saleem', 'Adam', 'anna.saleem.hogberg@gov.se', 'saleembaha@gmail.com', 'asaleem34@isk.ac.ke', 3, '12620', NULL),
	(530, 'Shahbal', 'Saif', 'kaitlin.hillis@gmail.com', 'saud.shahbal@gmail.com', 'sshahbal34@isk.ac.ke', 3, '12712', NULL),
	(464, 'Shenge', 'Micaella', 'uangelique@gmail.com', 'kaganzielly@gmail.com', 'mshenge30@isk.ac.ke', 7, '11527', NULL),
	(421, 'Som Chaudhuri', 'Anisha', 'deyshr@gmail.com', 'dchaudhuri@ifc.org', 'asomchaudhuri32@isk.ac.ke', 5, '12707', NULL),
	(502, 'Tassew', 'Nathan', 'faithmekuria24@gmail.com', 'tassew@gmail.com', 'ntassew26@isk.ac.ke', 11, '12636', NULL),
	(545, 'Thibodeau', 'Maya', 'gerry@grayemail.com', 'ace@thibodeau.com', 'mthibodeau28@isk.ac.ke', 9, '12357', NULL),
	(488, 'Van Der Vliet', 'Sarah', 'lauretavdva@gmail.com', 'janisvliet@gmail.com', 'svandervliet29@isk.ac.ke', 8, '11630', NULL),
	(338, 'Vestergaard', 'Nikolaj', 'psarasas@gmail.com', 'o.vestergaard@gmail.com', 'nvestergaard33@isk.ac.ke', 4, '11789', NULL),
	(438, 'Yoon', 'Seojun', 'japark1981@naver.com', 'yoonzie@gmail.com', 'syoon29@isk.ac.ke', 8, '12792', NULL),
	(482, 'Young', 'Annie', 'dyoung1462@gmail.com', 'dianeandjody@yahoo.com', 'ayoung25@isk.ac.ke', 12, '12378', NULL),
	(537, 'Njenga', 'Maximus', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'mnjenga34@isk.ac.ke', 3, '12303', NULL),
	(436, 'Atamuradov', 'Aaron', 'businka2101@gmail.com', 'atamoura@unhcr.org', 'aatamuradov31@isk.ac.ke', 6, '11800', NULL),
	(426, 'Burmester', 'Malou', 'Margs.Burmester@hotmail.com', 'mads.burmester@hotmail.com', 'mburmester31@isk.ac.ke', 6, '11395', NULL),
	(470, 'Chigudu', 'Komborero', 'memoshiri@yahoo.co.uk', 'vchigudu@yahoo.co.uk', 'kchigudu31@isk.ac.ke', 6, '11375', NULL),
	(517, 'Cooney', 'MaïA', 'mireillefc@gmail.com', 'danielcooney@gmail.com', 'mcooney26@isk.ac.ke', 11, '12110', NULL),
	(584, 'Abukari', 'Manuela', 'moprissy@gmail.com', 'm.abukari@ME.com', 'mabukari27@isk.ac.ke', 10, '10672', NULL),
	(562, 'Ansorg', 'Leon', 'katy.agg@gmail.com', 'tansorg@gmail.com', 'lansorg25@isk.ac.ke', 12, '12655', NULL),
	(561, 'Ansorg', 'Sebastian', 'katy.agg@gmail.com', 'tansorg@gmail.com', 'sansorg29@isk.ac.ke', 8, '12656', NULL),
	(611, 'Asamoah', 'Annabel', 'msuya.eunice1@gmail.com', 'Samuelasamoah4321@gmail.com', 'aasamoah25@isk.ac.ke', 12, '10746', NULL),
	(34, 'Ashton', 'Theodore', '1charlotteashton@gmail.com', 'todd.ashton@ericsson.com', 'tashton27@isk.ac.ke', 10, '11893', NULL),
	(554, 'Bannikau', 'Eva', 'lenusia@hotmail.com', 'elena.sahlin@gov.se', 'ebannikau32@isk.ac.ke', 5, '11780', NULL),
	(563, 'Bosch', 'Pilar', 'jasmin.gohl@gmail.com', 'luis.bosch@outlook.com', 'pbosch36@isk.ac.ke', 1, '12217', NULL),
	(565, 'Bosch', 'Blanca', 'jasmin.gohl@gmail.com', 'luis.bosch@outlook.com', 'bbosch32@isk.ac.ke', 5, '12219', NULL),
	(587, 'Caminha', 'Manali', 'sunita1214@gmail.com', 'zesopolcaminha@gmail.com', 'mcaminha27@isk.ac.ke', 10, '12079', NULL),
	(499, 'Choi', 'Minseo', 'shy_cool@naver.com', 'flymax2002@hotmail.com', 'mchoi32@isk.ac.ke', 5, '11145', NULL),
	(613, 'Duwyn', 'Mia', 'angeladuwyn@gmail.com', 'dduwyn@gmail.com', 'mduwyn27@isk.ac.ke', 10, '12086', NULL),
	(577, 'Gandhi', 'Krishna', 'gayatri.gandhi0212@gmail.com', 'gandhi.harish@gmail.com', 'kgandhi26@isk.ac.ke', 11, '12525', NULL),
	(605, 'Germain', 'Edouard', 'mel_laroche1@hotmail.com', 'alexgermain69@hotmail.com', 'egermain25@isk.ac.ke', 12, '12258', NULL),
	(606, 'Germain', 'Jacob', 'mel_laroche1@hotmail.com', 'alexgermain69@hotmail.com', 'jgermain25@isk.ac.ke', 12, '12259', NULL),
	(783, 'Gitiba', 'Kirk Wise', 'mollygathoni@gmail.com', NULL, 'kgitiba27@isk.ac.ke', 10, '12817', NULL),
	(597, 'Godden', 'Emma', 'martinettegodden@gmail.com', 'kieranrgodden@gmail.com', 'egodden27@isk.ac.ke', 10, '12479', NULL),
	(601, 'Hardy', 'Clara', 'rlbeckster@yahoo.com', 'jamesphardy211@gmail.com', 'chardy35@isk.ac.ke', 2, '12722', NULL),
	(569, 'Herbst', 'Sofia', 'magdaa002@hotmail.com', 'torstenherbst@hotmail.com', 'sherbst32@isk.ac.ke', 5, '12230', NULL),
	(521, 'Hire', 'Arthur', 'jhire@isk.ac.ke', 'bhire@isk.ac.ke', 'ahire32@isk.ac.ke', 5, '11232', NULL),
	(559, 'Holder', 'Charles', 'nickandstephholder@gmail.com', 'stephiemiddleton@hotmail.com', 'cholder25@isk.ac.ke', 12, '12059', NULL),
	(387, 'Jama', 'Adam', 'lucky74f@gmail.com', 'hargeisa1000@gmail.com', 'ajama34@isk.ac.ke', 3, '11676', NULL),
	(503, 'Johnson', 'Catherine', 'bobbiejohnsonbjj@gmail.com', 'donovanshanej@gmail.com', 'cjohnson35@isk.ac.ke', 2, '12867', NULL),
	(594, 'Jones-Avni', 'Dov', 'erinjonesavni@gmail.com', 'danielgavni@gmail.com', 'djones-avni34@isk.ac.ke', 3, '12784', NULL),
	(593, 'Jones-Avni', 'Tamar', 'erinjonesavni@gmail.com', 'danielgavni@gmail.com', 'tjones-avni36@isk.ac.ke', 1, '12897', NULL),
	(573, 'Joo', 'Jihong', 'ruvigirl@icloud.com', 'jeongje.joo@gmail.com', 'jjoo26@isk.ac.ke', 11, '11686', NULL),
	(592, 'Karuga', 'Kayla', 'irene.karuga2@gmail.com', 'karugafamily@gmail.com', 'kkaruga28@isk.ac.ke', 9, '12163', NULL),
	(581, 'Korngold', 'Mila Ruth', 'yenyen321@gmail.com', 'korngold.caleb@gmail.com', 'mkorngold29@isk.ac.ke', 8, '12773', NULL),
	(604, 'Koucheravy', 'Carys', 'grace.koucheravy@gmail.com', 'patrick.e.koucheravy@gmail.com', 'ckoucheravy28@isk.ac.ke', 9, '12304', NULL),
	(590, 'Leca Turner', 'Enzo', 'lecalaurianne@yahoo.co.uk', 'ejamturner@yahoo.com', 'elecaturner35@isk.ac.ke', 2, '12893', NULL),
	(585, 'Mansourian', 'Soren', 'braedenr@gmail.com', 'hani.mansourian@gmail.com', 'smansourian35@isk.ac.ke', 2, '12470', NULL),
	(37, 'Massawe', 'Noah', 'kikii.brown78@gmail.com', 'nmassawe@hotmail.com', 'nmassawe28@isk.ac.ke', 9, '11933', NULL),
	(538, 'Njenga', 'Sadie', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'snjenga31@isk.ac.ke', 6, '12279', NULL),
	(619, 'O''Bra', 'Asara', 'hbobra@gmail.com', 'bcobra@gmail.com', 'aobra27@isk.ac.ke', 10, '12341', NULL),
	(484, 'O''Hara', 'Luke', 'siemerm@hotmail.com', 'corykohara@gmail.com', 'lohara30@isk.ac.ke', 7, '12063', 'Beginning Band 7 2023'),
	(610, 'Patel', 'Ronan', 'vbeiner@isk.ac.ke', 'nilesh140@hotmail.com', 'rpatel28@isk.ac.ke', 9, '10119', NULL),
	(510, 'Piper', 'Saron', 'piperlilly@gmail.com', 'piperben@gmail.com', 'spiper25@isk.ac.ke', 12, '25038', NULL),
	(557, 'Prawitz', 'Leo', 'camillaprawitz@gmail.com', 'peter.nilsson@scb.se', 'lprawitz30@isk.ac.ke', 7, '12297', NULL),
	(527, 'Quacquarella', 'Alessia', 'lisa_limahken@yahoo.com', 'q_gioik@hotmail.com', 'aquacquarella31@isk.ac.ke', 6, '11461', NULL),
	(615, 'Raehalme', 'Henrik', 'johanna.raehalme@gmail.com', 'raehalme@gmail.com', 'hraehalme35@isk.ac.ke', 2, '12698', NULL),
	(514, 'Raval', 'Ananya', 'prakrutidevang@icloud.com', 'devang.raval1990@gmail.com', 'araval35@isk.ac.ke', 2, '12257', NULL),
	(566, 'Ross', 'Aven', 'skeddington@yahoo.com', 'sross78665@gmail.com', 'aross29@isk.ac.ke', 8, '11678', NULL),
	(533, 'Schenck', 'Alston', 'prillakrone@gmail.com', 'schenck.mills@bcg.com', 'aschenck32@isk.ac.ke', 5, '11484', NULL),
	(529, 'Shahbal', 'Sophia', 'kaitlin.hillis@gmail.com', 'saud.shahbal@gmail.com', 'sshahbal36@isk.ac.ke', 1, '12742', NULL),
	(58, 'Singh', 'Zahra', 'ypande@gmail.com', 'kabirsingh75@gmail.com', 'zsingh27@isk.ac.ke', 10, '11505', NULL),
	(576, 'Sottsas', 'Natasha', 'sinxayvoravong@hotmail.com', 'ssottsas@worldbank.org', 'nsottsas29@isk.ac.ke', 8, '12359', NULL),
	(18, 'Abdissa', 'Meron', 'addisalemt96@gmail.com', 'tesemaa@un.org', 'mabdissa28@isk.ac.ke', 9, '13078', NULL),
	(31, 'Abraha', 'Risty', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'rabraha27@isk.ac.ke', 10, '12463', NULL),
	(30, 'Abraha', 'Siyam', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'sabraha28@isk.ac.ke', 9, '12464', NULL),
	(583, 'Abukari', 'Marian', 'moprissy@gmail.com', 'm.abukari@ME.com', 'mabukari29@isk.ac.ke', 8, '10602', NULL),
	(668, 'Carter', 'Rafael', 'ksvensson@worldbank.org', 'miguelcarter.4@gmail.com', 'rcarter28@isk.ac.ke', 9, '12776', NULL),
	(661, 'Carver Wildig', 'Barney', 'zoe.wildig@gmail.com', 'freddie.carver@gmail.com', 'bcarver-wildig29@isk.ac.ke', 8, '12601', NULL),
	(602, 'Dara', 'Safari', 'yndege@gmail.com', 'dara_andrew@yahoo.com', 'sdara32@isk.ac.ke', 5, '11958', NULL),
	(647, 'Fundaro', 'Pietro', 'bethroca9@gmail.com', 'funroc@gmail.com', 'pfundaro26@isk.ac.ke', 11, '11329', NULL),
	(680, 'Handler', 'Julia', 'lholley@gmail.com', 'nhandler@gmail.com', 'jhandler30@isk.ac.ke', 7, '13100', NULL),
	(665, 'Hercberg', 'Amitai', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'ahercberg33@isk.ac.ke', 4, '12680', NULL),
	(667, 'Hercberg', 'Uriya', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'uhercberg29@isk.ac.ke', 8, '12682', NULL),
	(558, 'Holder', 'Abigail', 'nickandstephholder@gmail.com', 'stephiemiddleton@hotmail.com', 'aholder31@isk.ac.ke', 6, '12060', NULL),
	(673, 'Ihsan', 'Rayyan', 'tyuwono@worldbank.org', 'aihsan@gmail.com', 'rihsan29@isk.ac.ke', 8, '13060', NULL),
	(674, 'Ihsan', 'Zakhrafi', 'tyuwono@worldbank.org', 'aihsan@gmail.com', 'zihsan25@isk.ac.ke', 12, '13063', NULL),
	(628, 'Jacob', 'Dechen', 'namgya@gmail.com', 'vinodkjacobpminy@gmail.com', 'djacob29@isk.ac.ke', 8, '12765', NULL),
	(629, 'Jacob', 'Tenzin', 'namgya@gmail.com', 'vinodkjacobpminy@gmail.com', 'tjacob25@isk.ac.ke', 12, '12766', NULL),
	(641, 'Jansen', 'William', 'sjansen@usaid.gov', 'tmjjansen@hotmail.com', 'wjansen28@isk.ac.ke', 9, '11837', NULL),
	(642, 'Jansen', 'Matias', 'sjansen@usaid.gov', 'tmjjansen@hotmail.com', 'mswearingen26@isk.ac.ke', 11, '11855', NULL),
	(432, 'Jensen', 'Fiona', 'arietajensen@gmail.com', 'dannje@um.dk', 'fjensen33@isk.ac.ke', 4, '12237', NULL),
	(595, 'Jones-Avni', 'Nahal', 'erinjonesavni@gmail.com', 'danielgavni@gmail.com', 'njonesavni32@isk.ac.ke', 5, '12783', NULL),
	(625, 'Jovanovic', 'Dunja', 'jjovanovic@unicef.org', 'milansgml@gmail.com', 'djovanovic28@isk.ac.ke', 9, '12677', NULL),
	(650, 'Kimatrai', 'Rhea', 'aditikimatrai@gmail.com', 'ranjeevkimatrai@gmail.com', 'rkimatrai27@isk.ac.ke', 10, '11809', NULL),
	(580, 'Korngold', 'Myra', 'yenyen321@gmail.com', 'korngold.caleb@gmail.com', 'mkorngold31@isk.ac.ke', 6, '12775', NULL),
	(603, 'Koucheravy', 'Moira', 'grace.koucheravy@gmail.com', 'patrick.e.koucheravy@gmail.com', 'mkoucheravy32@isk.ac.ke', 5, '12305', NULL),
	(28, 'Kuehnle', 'John (Trey)', 'jk.payan@gmail.com', 'jkuehnle@usaid.gov', 'jkuehnle29@isk.ac.ke', 8, '11833', NULL),
	(589, 'Leca Turner', 'Nomi', 'lecalaurianne@yahoo.co.uk', 'ejamturner@yahoo.com', 'nlecaturner37@isk.ac.ke', 0, '12894', NULL),
	(644, 'Maagaard', 'Laerke', 'pil_larsen@hotmail.com', 'chmaagaard@live.dk', 'lmaagaard27@isk.ac.ke', 10, '12826', NULL),
	(681, 'Maguire', 'Josephine', 'carybmaguire@gmail.com', 'spencer.maguire@gmail.com', 'jmaguire28@isk.ac.ke', 9, '12592', NULL),
	(682, 'Maguire', 'Theodore', 'carybmaguire@gmail.com', 'spencer.maguire@gmail.com', 'tmaguire26@isk.ac.ke', 11, '12593', NULL),
	(76, 'Manzano', 'Abby Angelica', 'mira_manzano@yahoo.com', 'jose.manzano@undp.org', 'amanzano29@isk.ac.ke', 8, '11479', NULL),
	(65, 'Mathers', 'Aya', 'eri77s@gmail.com', 'nickmathers@gmail.com', 'amathers32@isk.ac.ke', 5, '11793', NULL),
	(64, 'Mekonnen', 'Yonathan', 'helenabebaw35@gmail.com', 'm.loulseged@afdb.org', 'ymekonnen29@isk.ac.ke', 8, '11015', NULL),
	(635, 'Nitcheu', 'Margot', 'lilimakole@yahoo.fr', 'georges.nitcheu@gmail.com', 'mnitcheu34@isk.ac.ke', 3, '12415', NULL),
	(636, 'Nitcheu', 'Marion', 'lilimakole@yahoo.fr', 'georges.nitcheu@gmail.com', 'mnitcheu33@isk.ac.ke', 4, '12417', NULL),
	(648, 'Onderi', 'Jade', 'ligamic@gmail.com', 'nathan.mabeya@gmail.com', 'jonderi27@isk.ac.ke', 10, '11847', NULL),
	(662, 'Park', 'Jijoon', 'hypakuo@gmail.com', 'joonwoo.park@undp.org', 'jpark34@isk.ac.ke', 3, '12787', NULL),
	(556, 'Prawitz', 'Max', 'camillaprawitz@gmail.com', 'peter.nilsson@scb.se', 'mprawitz31@isk.ac.ke', 6, '12298', 'Band 8 2024'),
	(43, 'Purdy', 'Gunnar', 'Mangoshy@yahoo.com', 'jess_a_purdy@yahoo.com', 'gpurdy28@isk.ac.ke', 9, '12349', NULL),
	(616, 'Raehalme', 'Emilia', 'johanna.raehalme@gmail.com', 'raehalme@gmail.com', 'eraehalme31@isk.ac.ke', 6, '12697', 'Band 8 2024'),
	(52, 'Roe', 'Alexander', 'christinarece@gmail.com', 'aron.roe@international.gc.ca', 'aroe29@isk.ac.ke', 8, '12188', NULL),
	(575, 'Sottsas', 'Bruno', 'sinxayvoravong@hotmail.com', 'ssottsas@worldbank.org', 'bsottsas32@isk.ac.ke', 5, '12358', NULL),
	(571, 'Stephens', 'Miya', 'mwatanabe1@worldbank.org', 'mstephens@worldbank.org', 'mstephens31@isk.ac.ke', 6, '11802', NULL),
	(652, 'Taneem', 'Farzin', 'mahfuhai@gmail.com', 'taneem.a@gmail.com', 'ftaneem29@isk.ac.ke', 8, '11335', NULL),
	(582, 'Tarquini', 'Alexander', 'caroline.bird@wfp.org', 'drmarcellotarquini@gmail.com', 'atarquini32@isk.ac.ke', 5, '12223', NULL),
	(631, 'Touré', 'Ousmane', 'adja_samb@yahoo.fr', 'cheikhtoure@hotmail.com', 'otoure31@isk.ac.ke', 6, '12325', NULL),
	(627, 'Walji', 'Felyne', 'marlouswergerwalji@gmail.com', 'shafranw@gmail.com', 'fwalji33@isk.ac.ke', 4, '12739', NULL),
	(626, 'Walji', 'Elise', 'marlouswergerwalji@gmail.com', 'shafranw@gmail.com', 'ewalji34@isk.ac.ke', 3, '12740', NULL),
	(541, 'Zucca', 'Fatima', 'mariacristina.zucca@gmail.com', NULL, 'fazucca30@isk.ac.ke', 7, '10566', 'Beginning Band 8 - 2023'),
	(24, 'Armstrong', 'Cole', 'stacia.armstrong@ymail.com', 'patrick.k.armstrong@gmail.com', 'carmstrong29@isk.ac.ke', 8, '12277', NULL),
	(1060, 'Ata', 'Dzidzor', 'parissa.ata@gmail.com', 'a.ata@kokonetworks.com', 'data24@isk.ac.ke', 13, '12651', NULL),
	(607, 'Aung', 'Lynn Htet', 'lwint@unhcr.org', 'lwinkyawkyaw@gmail.com', 'laung31@isk.ac.ke', 6, '12293', NULL),
	(586, 'Caminha', 'Zecarun', 'sunita1214@gmail.com', 'zesopolcaminha@gmail.com', 'zcaminha30@isk.ac.ke', 7, '12081', 'Beginning Band 1 2023'),
	(624, 'Jovanovic', 'Mila', 'jjovanovic@unicef.org', 'milansgml@gmail.com', 'mjovanovic31@isk.ac.ke', 6, '12678', 'Beginning Band 1, 2024-2025'),
	(723, 'Bachmann', 'Marc-Andri', 'bettina.bachmann@ggaweb.ch', 'marcel.bachmann@roche.com', 'mbachmann28@isk.ac.ke', 9, '12604', NULL),
	(40, 'Bedein', 'Shai', 'bebedein@gmail.com', 'gilbeinken@gmail.com', 'sbedein29@isk.ac.ke', 8, '12614', 'Concert Band 2023'),
	(39, 'Bedein', 'Itai', 'bebedein@gmail.com', 'gilbeinken@gmail.com', 'ibedein32@isk.ac.ke', 5, '12615', NULL),
	(564, 'Bosch', 'Moira', 'jasmin.gohl@gmail.com', 'luis.bosch@outlook.com', 'mbosch34@isk.ac.ke', 3, '12218', NULL),
	(660, 'Carver Wildig', 'Charlie', 'zoe.wildig@gmail.com', 'freddie.carver@gmail.com', 'ccarverwildig31@isk.ac.ke', 6, '12602', NULL),
	(687, 'Daines', 'Dallin', 'foreverdaines143@gmail.com', 'dainesy@gmail.com', 'ddaines34@isk.ac.ke', 3, '13064', NULL),
	(732, 'Douglas-Hamilton Pope', 'Selkie', 'saba@savetheelephants.org', 'frank@savetheelephants.org', 'spope27@isk.ac.ke', 10, '12995', NULL),
	(722, 'Fekadeneh', 'Sina', 'Shewit2003@yahoo.com', 'abi_fek@yahoo.com', 'sfekadeneh26@isk.ac.ke', 11, '12633', NULL),
	(637, 'Fernstrom', 'Eva', 'anushika00@hotmail.com', 'erik_fernstrom@yahoo.se', 'efernstrom31@isk.ac.ke', 6, '11939', NULL),
	(700, 'Ghelani-Decorte', 'Kian', 'rghelani14@gmail.com', 'decorte@un.org', 'kghelani-decorte28@isk.ac.ke', 9, '12673', NULL),
	(699, 'Ghelani-Decorte', 'Emiel', 'rghelani14@gmail.com', 'decorte@un.org', 'eghelani-decorte29@isk.ac.ke', 8, '12674', 'Concert Band 2023'),
	(727, 'Grundberg', 'Emil', 'nimagrundberg@gmail.com', 'jgrundberg@iom.int', 'egrundberg28@isk.ac.ke', 9, '13019', NULL),
	(568, 'Herbst', 'Kai', 'magdaa002@hotmail.com', 'torstenherbst@hotmail.com', 'kherbst34@isk.ac.ke', 3, '12231', NULL),
	(664, 'Hercberg', 'Zohar', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'zhercberg37@isk.ac.ke', 0, '12745', NULL),
	(672, 'Ihsan', 'Almaira', 'tyuwono@worldbank.org', 'aihsan@gmail.com', 'aihsan31@isk.ac.ke', 6, '13061', NULL),
	(709, 'Ishikawa', 'Tamaki', 'n2project@cobi.jp', 'ishikawan@un.org', 'tishikawa33@isk.ac.ke', 4, '13054', NULL),
	(645, 'Jin', 'Chae Hyun', 'h.lee2@afdb.org', 'jinseungsoo@gmail.com', 'cjin37@isk.ac.ke', 0, '12647', NULL),
	(698, 'Kavaleuski', 'Ian', 'kavaleuskaya@gmail.com', 'm.kavaleuskaya@gmail.com', 'ikavaleuski26@isk.ac.ke', 11, '13059', NULL),
	(632, 'Khayat De Andrade', 'Helena', 'nathaliakhayat@gmail.com', 'orestejunior@gmail.com', 'hkhayatdeandrade37@isk.ac.ke', 0, '12642', NULL),
	(633, 'Khayat De Andrade', 'Sophia', 'nathaliakhayat@gmail.com', 'orestejunior@gmail.com', 'skhayatdeandrade35@isk.ac.ke', 2, '12650', NULL),
	(27, 'Kuehnle', 'Emma', 'jk.payan@gmail.com', 'jkuehnle@usaid.gov', 'ekuehnle31@isk.ac.ke', 6, '11801', NULL),
	(620, 'Lee', 'Seonu', 'eduinun@gmail.com', 'stuff0521@gmail.com', 'slee33@isk.ac.ke', 4, '12449', NULL),
	(54, 'Lindvig', 'Freja', 'elisa@lindvig.com', 'jglindvig@gmail.com', 'flindvig31@isk.ac.ke', 6, '12535', NULL),
	(643, 'Maagaard', 'Siri', 'pil_larsen@hotmail.com', 'chmaagaard@live.dk', 'smaagaard32@isk.ac.ke', 5, '12827', NULL),
	(685, 'Maasdorp Mogollon', 'Lucas', 'inamogollon@gmail.com', 'maasdorp@gmail.com', 'lmaasdorpmogollon35@isk.ac.ke', 2, '12822', NULL),
	(36, 'Massawe', 'Nathan', 'kikii.brown78@gmail.com', 'nmassawe@hotmail.com', 'nmassawe32@isk.ac.ke', 5, '11932', NULL),
	(691, 'Mccown', 'Clea', 'nickigreenlee@gmail.com', 'andrew.mccown@gmail.com', 'cmccown34@isk.ac.ke', 3, '12837', NULL),
	(728, 'Mezemir', 'Amen', 'gtigistamha@yahoo.com', 'tdamte@unicef.org', 'amezemir28@isk.ac.ke', 9, '10498', NULL),
	(730, 'Mkandawire', 'Chawanangwa', 'luyckx.ilke@gmail.com', 'zwangiegasha@gmail.com', 'cmkandawire29@isk.ac.ke', 8, '12292', NULL),
	(706, 'Mosher', 'Emma', 'anabgonzalez@gmail.com', 'james.mosher@gmail.com', 'emosher33@isk.ac.ke', 4, '12709', NULL),
	(655, 'Mothobi', 'Resegofetse', 'shielamothobi@gmail.com', 'imothobi@gmail.com', 'rmothobi32@isk.ac.ke', 5, '12807', NULL),
	(654, 'Mothobi', 'Oagile', 'shielamothobi@gmail.com', 'imothobi@gmail.com', 'omothobi35@isk.ac.ke', 2, '12808', NULL),
	(659, 'Muziramakenga', 'Aiden', 'kristina.leuchowius@gmail.com', 'lionel.muzira@gmail.com', 'amuziramakenga32@isk.ac.ke', 5, '12703', NULL),
	(658, 'Muziramakenga', 'Mateo', 'kristina.leuchowius@gmail.com', 'lionel.muzira@gmail.com', 'mmuziramakenga35@isk.ac.ke', 2, '12704', NULL),
	(713, 'Patterson', 'Kaitlin', 'refinceyaa@gmail.com', 'markpatterson74@gmail.com', 'kpatterson29@isk.ac.ke', 8, '12810', NULL),
	(712, 'Patterson', 'Emilin', 'refinceyaa@gmail.com', 'markpatterson74@gmail.com', 'epatterson33@isk.ac.ke', 4, '12811', NULL),
	(696, 'Reza', 'Ruhan', 'ruintoo@gmail.com', 'areza@usaid.gov', 'rreza29@isk.ac.ke', 8, '13021', NULL),
	(747, 'Romero', 'Candela', 'carmen.sanchez@un.org', 'ricardoromerolopez@gmail.com', 'cromero28@isk.ac.ke', 9, '12799', NULL),
	(15, 'Rosen', 'Vilma Doret', 'Lollerosen@gmail.com', 'mikaeldissing@gmail.com', 'vrosen30@isk.ac.ke', 7, '11763', 'Beginning Band 7 2023'),
	(694, 'Stock', 'Payton', 'rydebstock@hotmail.com', 'stockr2@state.gov', 'pstock25@isk.ac.ke', 12, '12914', NULL),
	(630, 'Touré', 'Fatoumata', 'adja_samb@yahoo.fr', 'cheikhtoure@hotmail.com', 'ftoure32@isk.ac.ke', 5, '12324', NULL),
	(710, 'Walls', 'Colin', 'sabinalily@yahoo.com', 'mattmw29@gmail.com', 'cwalls33@isk.ac.ke', 4, '12475', NULL),
	(656, 'Wittmann', 'Emilie', 'benedicte.wittmann@yahoo.fr', 'christophewittmann@yahoo.fr', 'ewittmann30@isk.ac.ke', 7, '12428', 'Beginning Band 1 2023'),
	(634, 'Nitcheu', 'Maelle', 'lilimakole@yahoo.fr', 'georges.nitcheu@gmail.com', 'mnitcheu36@isk.ac.ke', 0, '12762', NULL),
	(44, 'Abou Hamda', 'Lana', 'hiba_hassan1983@hotmail.com', 'designcenter2011@live.com', 'labouhamda31@isk.ac.ke', 6, '12780', NULL),
	(29, 'Abraha', 'Rahsi', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'rabraha32@isk.ac.ke', 5, '12465', NULL),
	(670, 'Arora', 'Vihaan', 'miss.sikka@gmail.com', 'yash2201@gmail.com', 'varora34@isk.ac.ke', 3, '12242', NULL),
	(33, 'Ashton', 'Hugo', '1charlotteashton@gmail.com', 'todd.ashton@ericsson.com', 'hashton30@isk.ac.ke', 7, '11902', NULL),
	(725, 'Daher', 'Abbas', 'eguerahma@gmail.com', 'libdaher@gmail.com', 'adaher35@isk.ac.ke', 2, '12435', NULL),
	(724, 'Daher', 'Ralia', 'eguerahma@gmail.com', 'libdaher@gmail.com', 'rdaher37@isk.ac.ke', 0, '13066', NULL),
	(688, 'Daines', 'Caleb', 'foreverdaines143@gmail.com', 'dainesy@gmail.com', 'cdaines32@isk.ac.ke', 5, '13084', NULL),
	(703, 'Diehl', 'Ethan', 'mlegg85@gmail.com', 'adiehl1@gmail.com', 'ediehl37@isk.ac.ke', 0, '12863', NULL),
	(704, 'Diehl', 'Malcolm', 'mlegg85@gmail.com', 'adiehl1@gmail.com', 'mdiehl35@isk.ac.ke', 2, '12864', NULL),
	(102, 'Echalar', 'Kieran', 'shortjas@gmail.com', 'ricardo.echalar@gmail.com', 'kechalar35@isk.ac.ke', 2, '12723', NULL),
	(721, 'Fekadeneh', 'Caleb', 'Shewit2003@yahoo.com', 'abi_fek@yahoo.com', 'cfekadeneh31@isk.ac.ke', 6, '12641', NULL),
	(772, 'Gallagher', 'Hachim', 'habibanouh@yahoo.com', 'cuhullan89@gmail.com', 'hgallagher34@isk.ac.ke', 3, '13083', NULL),
	(784, 'Geller', 'Isaiah', 'egeller75@gmail.com', 'scge@niras.com', 'igeller27@isk.ac.ke', 10, '12539', NULL),
	(739, 'Grindell', 'Emily', 'kaptuiya@gmail.com', 'ricgrin@gmail.com', 'egrindell34@isk.ac.ke', 3, '12061', NULL),
	(738, 'Grindell', 'Alice', 'kaptuiya@gmail.com', 'ricgrin@gmail.com', 'agrindell36@isk.ac.ke', 1, '12900', NULL),
	(666, 'Hercberg', 'Noga', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'nhercberg30@isk.ac.ke', 7, '12681', 'Beginning Band 7 2023'),
	(753, 'Huang', 'Xinyi', 'ruiyingwang2018@gmail.com', 'jinfamilygroup@yahoo.com', 'xhuang35@isk.ac.ke', 2, '13074', NULL),
	(734, 'Irungu', 'Liam', 'nicole.m.irungu@gmail.com', 'dominic.i.wanyoike@gmail.com', 'lirungu36@isk.ac.ke', 1, '13039', NULL),
	(716, 'Ishee', 'Samantha', 'vickie.ishee@gmail.com', 'jon.ishee1@gmail.com', 'sishee36@isk.ac.ke', 1, '12832', NULL),
	(773, 'Jaffer', 'Kabir', 'zeeya.jaffer@gmail.com', 'aj@onepet.co.ke', 'kjaffer36@isk.ac.ke', 1, '12646', NULL),
	(720, 'Jain', 'Arth', 'nidhigw@gmail.com', 'padiraja@gmail.com', 'ajain36@isk.ac.ke', 1, '13088', NULL),
	(702, 'Kamara', 'Malik', 'rdagash@gmail.com', 'kamara1ster@gmail.com', 'mkamara35@isk.ac.ke', 2, '12724', NULL),
	(809, 'Kone', 'Adam', 'sonjalk@unops.org', 'zakskone@gmail.com', 'akone26@isk.ac.ke', 11, '11368', NULL),
	(791, 'Kwena', 'Saone', 'cathymbithi7@gmail.com', 'matthewkwena@gmail.com', 'skwena26@isk.ac.ke', 11, '12985', NULL),
	(749, 'Lee', 'Nayoon', 'euniceyhlee@gmail.com', 'ts0930.lee@samsung.com', 'nlee31@isk.ac.ke', 6, '12626', NULL),
	(736, 'Li', 'Feng Zimo', 'ugandayog01@hotmail.com', 'simonlee831001@hotmail.com', 'fli31@isk.ac.ke', 6, '13024', NULL),
	(795, 'Limpered', 'Arielle', 'christabel.owino@gmail.com', 'eodunguli@isk.ac.ke', 'alimered34@isk.ac.ke', 3, '12795', NULL),
	(777, 'Lindkvist', 'Ruth', 'wanjira.mathai@wri.org', 'larsbasecamp@me.com', 'rwangarilindkvist27@isk.ac.ke', 10, '12578', NULL),
	(715, 'Mackay', 'Nora', 'mandyamackay@gmail.com', 'tpmackay@gmail.com', 'nmackay30@isk.ac.ke', 7, '12885', NULL),
	(765, 'Maini', 'Karina', 'shilpamaini9@gmail.com', 'rajesh@usnkenya.com', 'kmaini26@isk.ac.ke', 11, '12986', NULL),
	(733, 'Margovsky-Lotem', 'Yoav', 'yahelmlotem@gmail.com', 'ambassador@nairobi.mfa.gov.il', 'ymargovsky37@isk.ac.ke', 0, '12649', NULL),
	(793, 'Mason', 'Isabella', 'serenamason66@icloud.com', 'cldm@habari.co.tz', 'imason25@isk.ac.ke', 12, '12629', NULL),
	(785, 'Mbera', 'Bianca', 'julie.onyuka@gmail.com', 'gototo24@gmail.com', 'bmbera26@isk.ac.ke', 11, '12603', NULL),
	(690, 'Mccown', 'Gabriel', 'nickigreenlee@gmail.com', 'andrew.mccown@gmail.com', 'gmccown36@isk.ac.ke', 1, '12833', NULL),
	(73, 'Murathi', 'Gerald', 'ngugir@hotmail.com', 'ammuturi@yahoo.com', 'gmurathi32@isk.ac.ke', 5, '11724', NULL),
	(741, 'Muttersbaugh', 'Cassidy', 'brennan.winter@gmail.com', 'smuttersbaugh@gmail.com', 'cmuttersbaugh36@isk.ac.ke', 1, '13035', NULL),
	(719, 'Pabani', 'Ayaan', 'sofia.jadavji@gmail.com', 'hanif.pabani@gmail.com', 'apabani35@isk.ac.ke', 2, '12256', NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.students (id, last_name, first_name, parent1_email, parent2_email, email, grade_level, student_number, class) VALUES
	(695, 'Reza', 'Reehan', 'ruintoo@gmail.com', 'areza@usaid.gov', 'rreza30@isk.ac.ke', 7, '13022', 'Beginning Band 8 - 2023'),
	(755, 'Rollins', 'Azza', 'faamai@gmail.com', 'salimrollins@gmail.com', 'arollins27@isk.ac.ke', 10, '12982', NULL),
	(69, 'Russo', 'Sofia', 'samiaabdul@yahoo.com', 'andrearux@yahoo.it', 'srusso32@isk.ac.ke', 5, '11362', NULL),
	(861, 'Schei', 'Nora', 'ghk@spk.no', 'gas@mfa.no', 'nschei28@isk.ac.ke', 9, '12582', NULL),
	(787, 'Shah', 'Jiya', 'miraa9@hotmail.com', 'adarsh@statpack.co.ke', 'jshah28@isk.ac.ke', 9, '12857', NULL),
	(797, 'Shah', 'Pranai', 'shahreena7978@yahoo.com', 'dhiresh.shah55@gmail.com', 'pshah25@isk.ac.ke', 12, '12987', NULL),
	(771, 'Simek', 'Emil', 'jiskakova@yahoo.com', 'ondrej.simek@eeas.europa.eu', 'esimek25@isk.ac.ke', 12, '13014', NULL),
	(770, 'Simek', 'Alan', 'jiskakova@yahoo.com', 'ondrej.simek@eeas.europa.eu', 'asimek28@isk.ac.ke', 9, '13015', NULL),
	(757, 'Srutova', 'Monika', 'lehau.mnk@gmail.com', 'dusan_sruta@mzv.cz', 'msrutova28@isk.ac.ke', 9, '12999', NULL),
	(692, 'Stock', 'Beckham', 'rydebstock@hotmail.com', 'stockr2@state.gov', 'bstock34@isk.ac.ke', 3, '12916', NULL),
	(796, 'Teklemichael', 'Rakeb', 'milen682@gmail.com', 'keburaku@gmail.com', 'rteklemichael26@isk.ac.ke', 11, '12412', NULL),
	(718, 'Wagner', 'Sonya', 'schakravarty@worldbank.org', 'williamchristianwagner@gmail.com', 'swangner32@isk.ac.ke', 5, '12892', NULL),
	(711, 'Walls', 'Ethan', 'sabinalily@yahoo.com', 'mattmw29@gmail.com', 'ewalls31@isk.ac.ke', 6, '12474', NULL),
	(751, 'Womble', 'Gaspard', 'priscillia.womble@gmail.com', 'david.womble@gmail.com', 'gwomble35@isk.ac.ke', 2, '12718', NULL),
	(89, 'Alemu', 'Or', 'esti20022@gmail.com', 'alemus20022@gmail.com', 'oalemu36@isk.ac.ke', 1, '13005', NULL),
	(789, 'Angima', 'Serenae', 'chao_laura@yahoo.co.uk', NULL, 'sangima28@isk.ac.ke', 9, '12954', NULL),
	(808, 'Bailey', 'Florrie', 'tertia.bailey@fcdo.gov.uk', 'petergrahambailey@gmail.com', 'fbailey25@isk.ac.ke', 12, '12812', NULL),
	(743, 'Bellamy', 'Mathis', 'ahuggins@mercycorps.org', 'bellamy.paul@gmail.com', 'mbellamy36@isk.ac.ke', 1, '12823', NULL),
	(754, 'Baral', 'Aabhar', 'archanabibhor@gmail.com', 'bibhorbaral@gmail.com', 'abaral31@isk.ac.ke', 6, '13030', NULL),
	(835, 'Bin Taif', 'Ahmed Jayed', 'shanchita02@gmail.com', 'ul.taif@gmail.com', 'abintaif34@isk.ac.ke', 3, '12311', NULL),
	(846, 'Braun', 'Felix', 'wibke.braun@eeas.europa.eu', NULL, 'fbraun28@isk.ac.ke', 9, '13095', NULL),
	(875, 'Bredin', 'Zara', 'nickolls@un.org', 'milesbredin@mac.com', 'zbredin26@isk.ac.ke', 11, '11851', NULL),
	(848, 'Crabtree', 'Matthew', 'crabtreeak@state.gov', 'crabtreejd@state.gov', 'mcrabtree25@isk.ac.ke', 12, '12560', NULL),
	(857, 'Croucher', 'Emily', 'clairebedelian@hotmail.com', 'crouchermatthew@hotmail.com', 'ecroucher31@isk.ac.ke', 6, '12873', NULL),
	(858, 'Croucher', 'Oliver', 'clairebedelian@hotmail.com', 'crouchermatthew@hotmail.com', 'ocroucher29@isk.ac.ke', 8, '12874', NULL),
	(859, 'Croucher', 'Anabelle', 'clairebedelian@hotmail.com', 'crouchermatthew@hotmail.com', 'acroucher27@isk.ac.ke', 10, '12875', NULL),
	(856, 'Croze', 'Ishbel', 'anna.croze@gmail.com', 'lengai.croze@gmail.com', 'icroze27@isk.ac.ke', 10, '13062', NULL),
	(822, 'David-Tafida', 'Mariam', 'fatymahit@gmail.com', 'bradleyeugenedavid@gmail.com', 'mdavid-tafida34@isk.ac.ke', 3, '12715', NULL),
	(870, 'Elkana', 'Matan', 'maayan180783@gmail.com', 'tamir260983@gmail.com', 'melkana31@isk.ac.ke', 6, '13003', NULL),
	(85, 'Fisher', 'Charles', 'nataliafisheranne@gmail.com', 'ben.fisher@fcdo.gov.uk', 'cfisher25@isk.ac.ke', 12, '11415', NULL),
	(106, 'Freiherr Von Handel', 'Maximilian', 'igiribaldi@hotmail.com', 'thomas.von.handel@gmail.com', 'mvonhandel25@isk.ac.ke', 12, '12095', NULL),
	(782, 'Gitiba', 'Roy', 'mollygathoni@gmail.com', NULL, 'rgitiba29@isk.ac.ke', 8, '12818', NULL),
	(832, 'Hayer', 'Manvir Singh', 'manpreetkh@gmail.com', 'csh@hayerone.com', 'mhayer29@isk.ac.ke', 8, '12471', NULL),
	(761, 'Patrikios', 'Zefyros', 'aepatrikios@gmail.com', 'jairey@isk.ac.ke', NULL, 0, '13103', NULL),
	(758, 'Houndeganme', 'Nyx Verena', 'kougblenouchristelle@gmail.com', 'ahoundeganme@unicef.org', 'nhoundeganme30@isk.ac.ke', 7, '12815', NULL),
	(838, 'Husemann', 'Emilia', 'annahusemann@web.de', 'christoph.zipfel@web.de', 'ehusemann28@isk.ac.ke', 9, '12949', NULL),
	(756, 'Hussain', 'Bushra', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'bhussain37@isk.ac.ke', 0, '13070', NULL),
	(780, 'Ibrahim', 'Masoud', 'ibrahimkhadija@gmail.com', 'ibradaud@gmail.com', 'mibrahim30@isk.ac.ke', 7, '13076', 'Beginning Band 1 2023'),
	(774, 'Jaffer', 'Ayaan', 'zeeya.jaffer@gmail.com', 'aj@onepet.co.ke', 'ajaffer32@isk.ac.ke', 5, '11646', NULL),
	(854, 'Kaseva', 'Lauri', 'linda.kaseva@gmail.com', 'johannes.tarvainen@gmail.com', 'lkaseva33@isk.ac.ke', 4, '13096', NULL),
	(843, 'Khan', 'Zari', 'asmaibrar2023@gmail.com', 'ibrardiplo@gmail.com', 'zkhan27@isk.ac.ke', 10, '13087', NULL),
	(877, 'Lavack', 'Michael', 'patricia.wanyee@gmail.com', 'slavack@isk.ac.ke', 'mlavack26@isk.ac.ke', 11, '26015', NULL),
	(750, 'Lee', 'Dongyoon', 'euniceyhlee@gmail.com', 'ts0930.lee@samsung.com', 'dlee30@isk.ac.ke', 7, '12627', 'Concert Band 2023'),
	(767, 'Moons', 'Elena', 'kasia@laud.nl', 'leander@laud.nl', 'emoons29@isk.ac.ke', 8, '12851', NULL),
	(818, 'Mueller', 'Christian', 'carlabenini1@gmail.com', 'mueller10r@aol.com', 'cmueller25@isk.ac.ke', 12, '12936', NULL),
	(817, 'Mueller', 'Willem', 'carlabenini1@gmail.com', 'mueller10r@aol.com', 'wmueller27@isk.ac.ke', 10, '12937', NULL),
	(837, 'Nas', 'Rebekah Ysabelle', 'gretchen.nas79@gmail.com', 't.nas@cgiar.org', 'rysabellenas27@isk.ac.ke', 10, '12978', NULL),
	(819, 'Ndoye', 'Libasse', 'fatou.ndoye@un.org', NULL, 'lndonye28@isk.ac.ke', 9, '13075', NULL),
	(860, 'Olvik', 'Vera', 'uakesson@hotmail.com', 'gunnarolvik@hotmail.com', 'volvik28@isk.ac.ke', 9, '12953', NULL),
	(778, 'Otieno', 'Adrian', 'maureenagengo@gmail.com', 'jotieno@isk.ac.ke', 'aotieno29@isk.ac.ke', 8, '12884', NULL),
	(697, 'Sankar', 'Nandita', 'sankarpr@state.gov', NULL, 'nsankar33@isk.ac.ke', 4, '12802', NULL),
	(763, 'Segev', 'Eitan', 'noggasegev@gmail.com', 'avivsegev1@gmail.com', 'esegev37@isk.ac.ke', 0, '12862', NULL),
	(798, 'Shah', 'Dhiya', 's_shah21@hotmail.co.uk', 'jaimin@bobmilgroup.com', 'dshah29@isk.ac.ke', 8, '12541', NULL),
	(825, 'Sidari', 'Rocco', 'geven@hotmail.com', 'jsidari@usaid.gov', 'rsidari34@isk.ac.ke', 3, '13036', NULL),
	(863, 'Skaaraas-Gjoelberg', 'Cedrik', 'ceciskaa@yahoo.com', 'erlendmagnus@hotmail.com', 'cgjoelberg31@isk.ac.ke', 6, '12846', NULL),
	(801, 'Somaia', 'Shivail', 'ishisomaia@gmail.com', 'vishal@murbanmovers.co.ke', 'ssomaia32@isk.ac.ke', 5, '11769', NULL),
	(803, 'Stiles', 'Nikolas', 'ppappas@isk.ac.ke', 'stilesdavid@gmail.com', 'nstiles31@isk.ac.ke', 6, '11137', NULL),
	(752, 'Sudra', 'Nile', 'maryleakeysudra@gmail.com', 'msudra@isk.ac.ke', 'nsudra37@isk.ac.ke', 0, '13065', NULL),
	(833, 'Tulga', 'Titu', 'buyanu@gmail.com', 'tulgaad@gmail.com', 'ttulga30@isk.ac.ke', 7, '12756', 'Beginning Band 7 2023'),
	(847, 'Verstraete', 'Io', 'cornelia2vanzyl@gmail.com', 'lverstraete@unicef.org', 'iverstraete26@isk.ac.ke', 11, '12998', NULL),
	(881, 'Waalewijn', 'Hannah', 'manonwaalewijn@gmail.com', 'manonenpieter@gmail.com', 'hwaalewijn29@isk.ac.ke', 8, '12598', NULL),
	(821, 'Wang', 'Shuyi (Bella)', 'supermomcccc@gmail.com', 'mcbgwang@gmail.com', 'swang28@isk.ac.ke', 9, '12950', NULL),
	(820, 'Wang', 'Yi (Gavin)', 'supermomcccc@gmail.com', 'mcbgwang@gmail.com', 'ywang33@isk.ac.ke', 4, '13020', NULL),
	(811, 'Wimber', 'Thomas', 'nancyaburi@gmail.com', NULL, 'twimber28@isk.ac.ke', 9, '12670', NULL),
	(827, 'Ajidahun', 'Darian', 'ajidahun.olori@gmail.com', 'caliphlex@yahoo.com', 'dajidahun34@isk.ac.ke', 3, '12805', NULL),
	(844, 'Alwedo', 'Cradle Terry', 'ogwangk@unhcr.org', NULL, 'calwedo31@isk.ac.ke', 6, '13026', NULL),
	(129, 'Andries-Munshi', 'TéA', 'sarah.andries@gmail.com', 'neilmunshi@gmail.com', 'tandries-munshi36@isk.ac.ke', 1, '12798', NULL),
	(867, 'Arora', 'Tisya', 'dearbhawna1@yahoo.co.in', 'kapil.arora@eni.com', 'tarora26@isk.ac.ke', 11, '13009', NULL),
	(133, 'Ansell', 'Oscar', 'emily.ansell@gmail.com', 'damon.ansell@gmail.com', 'oansell27@isk.ac.ke', 10, '12134', NULL),
	(910, 'Assi', 'Michael Omar', 'esmeralda.naji@hotmail.com', 'assi.mohamed@gmail.com', 'm-omarassi29@isk.ac.ke', 8, '12917', NULL),
	(896, 'Barbacci', 'Evangelina', 'kbarbacci@hotmail.com', 'fbarbacci@hotmail.com', 'ebarbacci29@isk.ac.ke', 8, '12612', NULL),
	(850, 'Berkouwer', 'Daniel', 'lijiayu211@gmail.com', 'meskesberkouwer@gmail.com', 'dberkouwer35@isk.ac.ke', 2, '12496', NULL),
	(852, 'Berthellier-Antoine', 'LéA', 'dberthellier@gmail.com', 'malick74@gmail.com', 'leaberthellier35@isk.ac.ke', 2, '12794', NULL),
	(1061, 'Bhandari', 'Nandini', 'trpt.bhandari@googlemail.com', 'Arvind.bhandari@ke.nestle.com', 'nbhandari24@isk.ac.ke', 13, '12738', NULL),
	(834, 'Bin Taif', 'Ahmed Jabir', 'shanchita02@gmail.com', 'ul.taif@gmail.com', 'abintaif36@isk.ac.ke', 1, '12898', NULL),
	(929, 'D''Souza', 'Isaac', 'lizannec@hotmail.com', 'royden.dsouza@gmail.com', 'idsouza28@isk.ac.ke', 9, '12501', NULL),
	(868, 'Elkana', 'Gai', 'maayan180783@gmail.com', 'tamir260983@gmail.com', 'gelkana35@isk.ac.ke', 2, '13001', NULL),
	(823, 'Farrell', 'James', 'katherinedfarrell@gmail.com', 'farrellmp@gmail.com', 'jfarrell35@isk.ac.ke', 2, '12720', NULL),
	(84, 'Fisher', 'Isabella', 'nataliafisheranne@gmail.com', 'ben.fisher@fcdo.gov.uk', 'ifisher27@isk.ac.ke', 10, '11416', NULL),
	(900, 'Ghariani', 'Farah', 'wafaek@hotmail.com', 'tewfickg@hotmail.com', 'fghariani27@isk.ac.ke', 10, '12662', NULL),
	(136, 'Harris Ii', 'Omar', 'tnicoleharris@sbcglobal.net', 'omarharris@sbcglobal.net', 'oharrisii25@isk.ac.ke', 12, '12625', NULL),
	(893, 'Heijstee', 'Zara', 'vivien.jarl@gmail.com', 'vivien.jarl@gmail.com', 'zheijstee28@isk.ac.ke', 9, '12781', NULL),
	(829, 'Hussain', 'Saif', 'milhemrana@gmail.com', 'omarhussain_80@hotmail.com', 'sahussain32@isk.ac.ke', 5, '12328', NULL),
	(830, 'Hussain', 'Taim', 'milhemrana@gmail.com', 'omarhussain_80@hotmail.com', 'thussain36@isk.ac.ke', 1, '12899', NULL),
	(923, 'Huysdens', 'Jacey', 'mhuysdens@gmail.com', 'merchan_nl@hotmail.com', 'jhuysdens27@isk.ac.ke', 10, '12926', NULL),
	(914, 'Ibrahim', 'Iman', NULL, 'ibradaud@gmail.com', 'iibrahim27@isk.ac.ke', 10, '12819', NULL),
	(855, 'Khan', 'Layal', 'zehrahyderali@gmail.com', 'ikhan2@worldbank.org', 'lkhan34@isk.ac.ke', 3, '12550', NULL),
	(926, 'Khouma', 'Khady', 'ceciliakleimert@gmail.com', 'tallakhouma92@gmail.com', 'kkhouma33@isk.ac.ke', 4, '13045', NULL),
	(919, 'Kisukye', 'Daudi', 'dmulira16@gmail.com', 'kisukye@un.org', 'dkisukye31@isk.ac.ke', 6, '13025', NULL),
	(864, 'Lee', 'David', 'podo416@gmail.com', 'mkthestyle@icloud.com', 'dlee34@isk.ac.ke', 3, '13089', NULL),
	(904, 'Mayar', 'Angab', 'mmonoja@yahoo.com', 'ayueldit2@gmail.com', 'amayar25@isk.ac.ke', 12, '13057', NULL),
	(110, 'Miller', 'Albert', 'emiller@isk.ac.ke', 'Angus.miller@fcdo.gov.uk', 'amiller25@isk.ac.ke', 12, '25051', NULL),
	(109, 'Miller', 'Cassius', 'emiller@isk.ac.ke', 'Angus.miller@fcdo.gov.uk', 'cmiller27@isk.ac.ke', 10, '27007', NULL),
	(889, 'Mollier-Camus', 'Elisa', 'carole.mollier.camus@gmail.com', 'simon.mollier-camus@bakerhughes.com', 'emollier-camus28@isk.ac.ke', 9, '12586', NULL),
	(886, 'Molloy', 'Saoirse', 'kacey.molloy@gmail.com', 'cmolloy.mt@gmail.com', 'smolloy34@isk.ac.ke', 3, '12702', NULL),
	(898, 'Moyle', 'Santiago', 'trina.schofield@gmail.com', 'fernandomoyle@gmail.com', 'smoyle27@isk.ac.ke', 10, '12581', NULL),
	(871, 'Nasidze', 'Niccolo', 'topuridze.tamar@gmail.com', 'alexander.nasidze@un.org', 'nnasidze36@isk.ac.ke', 1, '12901', NULL),
	(842, 'Hales', 'Arabella', 'amberley.hales@gmail.com', 'christopher.w.hales@gmail.com', NULL, 0, '13105', NULL),
	(146, 'Nguyen', 'Binh', 'nnguyen@parallelconsultants.com', 'luu@un.org', 'bnguyen27@isk.ac.ke', 10, '11671', NULL),
	(853, 'Kaseva', 'Lukas', 'linda.kaseva@gmail.com', 'johannes.tarvainen@gmail.com', NULL, 0, '13104', NULL),
	(851, 'Opere', 'Kayla', 'rineke-van.dam@minbuza.nl', 'alexopereh@yahoo.com', 'kopere36@isk.ac.ke', 0, '12820', NULL),
	(83, 'Shah', 'Krishi', 'komal.kevs@gmail.com', 'keval.shah@cloudhop.it', 'kshah26@isk.ac.ke', 11, '12121', NULL),
	(127, 'Sheridan', 'Indira', 'noush007@hotmail.com', 'alan.sheridan@wfp.org', 'isheridan26@isk.ac.ke', 11, '11592', NULL),
	(895, 'Sotiriou', 'Leonidas', 'enehrling@gmail.com', 'b.and.g.sotiriou@gmail.com', 'lsotiriou34@isk.ac.ke', 3, '12239', NULL),
	(93, 'Stott', 'Helena', 'arineachterstraat@me.com', 'stottbrian@me.com', 'hstott27@isk.ac.ke', 10, '12520', NULL),
	(94, 'Stott', 'Patrick', 'arineachterstraat@me.com', 'stottbrian@me.com', 'pstott26@isk.ac.ke', 11, '12521', NULL),
	(874, 'Szuchman', 'Reuben', 'sonyaedelman@gmail.com', 'szuchman@gmail.com', 'rszuchman28@isk.ac.ke', 9, '12667', 'Concert Band 2023'),
	(873, 'Szuchman', 'Sadie', 'sonyaedelman@gmail.com', 'szuchman@gmail.com', 'sszuchman30@isk.ac.ke', 7, '12668', 'Beginning Band 7 2023'),
	(890, 'Varun', 'Harsha', 'liveatpresent83@gmail.com', 'liveatpresent83@gmail.com', 'hvarun30@isk.ac.ke', 7, '12683', 'Beginning Band 8 - 2023'),
	(891, 'Varun', 'Jaishna', 'liveatpresent83@gmail.com', 'liveatpresent83@gmail.com', 'jvarun29@isk.ac.ke', 8, '12684', NULL),
	(921, 'Virani', 'Aydin', 'mehreenrv@gmail.com', 'rahimwv@gmail.com', 'avirani33@isk.ac.ke', 4, '12483', NULL),
	(917, 'Waugh', 'Josephine', 'annabajorek125@gmail.com', 'minwaugh22@gmail.com', 'jwaugh35@isk.ac.ke', 2, '12844', NULL),
	(885, 'Wietecha', 'Kaitlin', 'aitkenjennifer@hotmail.com', 'rwietecha@yahoo.com', 'kwietecha26@isk.ac.ke', 11, '12591', NULL),
	(828, 'Ajidahun', 'Annabelle', 'ajidahun.olori@gmail.com', 'caliphlex@yahoo.com', 'aajidahun32@isk.ac.ke', 5, '12804', NULL),
	(826, 'Ajidahun', 'David', 'ajidahun.olori@gmail.com', 'caliphlex@yahoo.com', 'daajidahun37@isk.ac.ke', 0, '13072', NULL),
	(841, 'Alemayehu', 'Naomi', 'hayatabdulahi@gmail.com', 'alexw9@gmail.com', 'nalemayehu32@isk.ac.ke', 5, '13000', NULL),
	(907, 'Alemu', 'Liri', 'alemus20022@gmail.com', 'alemus20022@gmail.com', 'lalemu33@isk.ac.ke', 4, '12732', NULL),
	(7, 'Borg Aidnell', 'Siv', 'aidnell@gmail.com', 'parborg70@hotmail.com', 'sborgaidnell34@isk.ac.ke', 3, '12543', NULL),
	(8, 'Borg Aidnell', 'Disa', 'aidnell@gmail.com', 'parborg70@hotmail.com', 'dborgaidnell31@isk.ac.ke', 6, '12696', NULL),
	(119, 'Carter', 'David', 'ksvensson@worldbank.org', 'miguelcarter.4@gmail.com', 'dcarter28@isk.ac.ke', 9, '11937', NULL),
	(3, 'Dadashev', 'Murad', 'huseynovags@yahoo.com', 'adadashev@unicef.org', 'mdadashev28@isk.ac.ke', 9, '12768', NULL),
	(958, 'Diop Weyer', 'AuréLien', 'frederique.weyer@graduateinstitute.ch', 'amadou.diop@graduateinstitute.ch', 'adiop-weyer33@isk.ac.ke', 4, '13033', NULL),
	(927, 'Ellinger', 'Emily', 'hello@dianaellinger.com', 'c_ellinger@hotmail.com', 'eellinger31@isk.ac.ke', 6, '13102', NULL),
	(9, 'Ellis', 'Ryan', 'etinsley@worldbank.org', 'pellis@worldbank.org', 'rellis25@isk.ac.ke', 12, '12070', NULL),
	(2, 'Farraj', 'Jarius', 'gmcabrera2017@gmail.com', 'amer_farraj@yahoo.com', 'jfarraj25@isk.ac.ke', 12, '12606', NULL),
	(933, 'Granot', 'Ben', 'maayanalmagor@gmail.com', 'granotb@gmail.com', 'bgranot36@isk.ac.ke', 1, '12748', NULL),
	(939, 'Hirose', 'Ren', 'r.imamoto@gmail.com', 'yusuke.hirose@sumitomocorp.com', 'rhirose35@isk.ac.ke', 2, '13040', NULL),
	(269, 'Inwani', 'Aiden', 'cirablue@gmail.com', NULL, 'ainwani25@isk.ac.ke', 12, '12531', NULL),
	(908, 'Ishanvi', 'Ishanvi', 'anupuniaahlawat@gmail.com', 'neerajahlawat88@gmail.com', 'iishanvi36@isk.ac.ke', 1, '13053', NULL),
	(940, 'Johnson', 'Abel', 'ameenahbsaleem@gmail.com', 'ibnabu@aol.com', 'ajohnson35@isk.ac.ke', 2, '12767', NULL),
	(951, 'Kamenga', 'Tasheni', 'nompumelelo.nkosi@gmail.com', 'kamenga@gmail.com', 'tkamenga34@isk.ac.ke', 3, '12877', NULL),
	(941, 'Kane', 'Issa', 'danionatangent@gmail.com', NULL, 'ikane35@isk.ac.ke', 2, '13037', NULL),
	(930, 'Kane', 'Ezra', 'danionatangent@gmail.com', NULL, 'ekane37@isk.ac.ke', 0, '13071', NULL),
	(925, 'Khouma', 'Nabou', 'ceciliakleimert@gmail.com', 'tallakhouma92@gmail.com', 'nkhouma36@isk.ac.ke', 1, '13046', NULL),
	(942, 'Kiers', 'Beatrix', 'smallwood.marianne@gmail.com', 'alexis.kiers@gmail.com', 'bkiers35@isk.ac.ke', 2, '12717', NULL),
	(935, 'Kishiue-Turkstra', 'Hannah', 'akishiue@worldbank.org', 'jan.turkstra@gmail.com', 'hkishiue-turkstra36@isk.ac.ke', 1, '12751', NULL),
	(959, 'Lundell', 'Levi', 'rebekahlundell@gmail.com', 'redlundell@gmail.com', 'llundell33@isk.ac.ke', 4, '12693', NULL),
	(943, 'Menkerios', 'Yousif', 'oh_hassan@hotmail.com', 'hmenkerios@aol.com', 'ymenkerios35@isk.ac.ke', 2, '12459', NULL),
	(887, 'Molloy', 'Caelan', 'kacey.molloy@gmail.com', 'cmolloy.mt@gmail.com', 'cmolloy32@isk.ac.ke', 5, '12701', NULL),
	(937, 'Nau', 'Emerson', 'kimdsimon@gmail.com', 'nau.hew@gmail.com', 'enau36@isk.ac.ke', 1, '12834', NULL),
	(944, 'Oberjuerge', 'Clayton', 'kateharris22@gmail.com', 'loberjue@gmail.com', 'coberjuerge35@isk.ac.ke', 2, '12687', NULL),
	(912, 'Otieno', 'Uzima', 'linet.otieno@gmail.com', 'tcpauldbtcol@gmail.com', 'uotieno29@isk.ac.ke', 8, '13056', 'Concert Band 2023'),
	(952, 'Patenaude', 'Theodore', 'shanyoung86@gmail.com', 'patenaude.joel@gmail.com', 'tpatenaude34@isk.ac.ke', 3, '12713', NULL),
	(931, 'Pijovic', 'Sapia', 'somatatakone@yahoo.com', 'somatatakone@yahoo.com', 'spijovic37@isk.ac.ke', 0, '13091', NULL),
	(80, 'Ronzio', 'George', 'janinecocker@gmail.com', 'jronzio@gmail.com', 'gronzio29@isk.ac.ke', 8, '12199', NULL),
	(534, 'Schenck', 'Spencer', 'prillakrone@gmail.com', 'schenck.mills@bcg.com', 'sschenck30@isk.ac.ke', 7, '11457', 'Beginning Band 8 - 2023'),
	(924, 'Schonemann', 'Esther', NULL, 'stesch@um.dk', 'eschonemann31@isk.ac.ke', 6, '13028', NULL),
	(961, 'Schrader', 'Genevieve', 'schraderhub@gmail.com', 'schraderjp09@gmail.com', 'gschrader33@isk.ac.ke', 4, '12840', NULL),
	(949, 'Schrader', 'Clarice', 'schraderhub@gmail.com', 'schraderjp09@gmail.com', 'cschrader35@isk.ac.ke', 2, '12841', NULL),
	(950, 'Sobantu', 'Mandisa', 'mbemelaphi@gmail.com', 'monwabisi.sobantu@gmail.com', 'msobantu35@isk.ac.ke', 2, '12939', NULL),
	(894, 'Sotiriou', 'Graciela', 'enehrling@gmail.com', 'b.and.g.sotiriou@gmail.com', 'gsotiriou36@isk.ac.ke', 1, '12902', NULL),
	(140, 'Tanna', 'Shreya', 'vptanna@gmail.com', 'priyentanna@gmail.com', 'stanna28@isk.ac.ke', 9, '10703', NULL),
	(97, 'Van De Velden', 'Evangelia', 'smafro@gmail.com', 'jaapvandevelden@gmail.com', 'evandevelden29@isk.ac.ke', 8, '10704', NULL),
	(962, 'Vazquez Eraso', 'Martin', 'berasopuig@worldbank.org', 'vvazquez@worldbank.org', 'mvazquezeraso33@isk.ac.ke', 4, '12369', NULL),
	(963, 'Vestergaard', 'Magne', 'marves@um.dk', 'elrulu@protonmail.com', 'mvestergaard33@isk.ac.ke', 4, '12664', NULL),
	(954, 'Von Platen-Hallermund', 'Anna', 'mspliid@gmail.com', 'thobobs@hotmail.com', 'aplatenhallermund34@isk.ac.ke', 3, '12888', NULL),
	(132, 'Wallbridge', 'Lylah', 'awallbridge@isk.ac.ke', 'tcwallbridge@gmail.com', 'lwallbridge28@isk.ac.ke', 9, '20867', NULL),
	(918, 'Waugh', 'Rosemary', 'annabajorek125@gmail.com', 'minwaugh22@gmail.com', 'rwaugh32@isk.ac.ke', 5, '12843', NULL),
	(965, 'Weill', 'Benjamin', 'robineberlin@gmail.com', 'matthew_weill@mac.com', 'bweill33@isk.ac.ke', 4, '12849', NULL),
	(955, 'Wendelboe', 'Tristan', 'maria.wendelboe@outlook.dk', 'morwen@um.dk', 'twendelboe34@isk.ac.ke', 3, '12527', NULL),
	(899, 'Yakusik', 'Alissa', 'annayakusik@gmail.com', 'davidwilson1760@gmail.com', 'ayakusik32@isk.ac.ke', 5, '13082', NULL),
	(948, 'Sarfaraz', 'Amaya', 'sarahbafridi@gmail.com', 'sarfarazabid@gmail.com', NULL, 2, '12608', NULL),
	(956, 'Andersen', 'Signe', 'millelund@gmail.com', 'steensandersen@gmail.com', 'sandersen33@isk.ac.ke', 4, '12570', NULL),
	(957, 'Asquith', 'Holly', 'kamilla.henningsen@gmail.com', 'm.asquith@icloud.com', 'hasquith33@isk.ac.ke', 4, '12944', NULL),
	(125, 'Awori', 'Malaika', 'Annmarieawori@gmail.com', 'Michael.awori@gmail.com', 'mawori28@isk.ac.ke', 9, '10476', NULL),
	(6, 'Borg Aidnell', 'Nike', 'aidnell@gmail.com', 'parborg70@hotmail.com', 'nborgaidnell34@isk.ac.ke', 3, '12542', NULL),
	(1001, 'Carlevato', 'Etienne', 'awishous@gmail.com', 'scarlevato@gmail.com', 'ecarlevato29@isk.ac.ke', 8, '12924', 'Beginning Band 1 2023'),
	(968, 'Carlevato', 'Armelle', 'awishous@gmail.com', 'scarlevato@gmail.com', 'acarlevato32@isk.ac.@isk.ac.ke', 5, '12925', NULL),
	(978, 'Chappell', 'Sebastian', 'mgorzelanska@usaid.gov', 'jchappell@usaid.gov', 'schappell31@isk.ac.ke', 6, '12577', NULL),
	(500, 'Choi', 'Yoonseo', 'shy_cool@naver.com', 'flymax2002@hotmail.com', 'ychoi30@isk.ac.ke', 7, '10708', 'Beginning Band 7 2023'),
	(141, 'Clark', 'Samuel', 'jwang7@ifc.org', 'davidjclark000@gmail.com', 'sclark32@isk.ac.ke', 5, '13049', NULL),
	(969, 'Corbin', 'Sonia', 'corbincf@gmail.com', 'james.corbin.pa@gmail.com', 'scorbin32@isk.ac.ke', 5, '12942', NULL),
	(928, 'D''Souza', 'Aiden', 'lizannec@hotmail.com', 'royden.dsouza@gmail.com', 'adsouza30@isk.ac.ke', 7, '12500', 'Beginning Band 8 - 2023'),
	(1062, 'De Geer-Howard', 'Isabella', 'catharina_degeer@yahoo.com', 'jackhoward03@yahoo.com', 'idegeer-howard24@isk.ac.ke', 13, '12652', NULL),
	(103, 'Echalar', 'Liam', 'shortjas@gmail.com', 'ricardo.echalar@gmail.com', 'lechalar32@isk.ac.ke', 5, '11882', NULL),
	(1050, 'Eldridge', 'Wade', '780711th@gmail.com', 'tomheldridge@hotmail.com', 'weldridge25@isk.ac.ke', 12, '12975', NULL),
	(979, 'Fritts', 'Alayna', 'frittsalexa@gmail.com', 'jfrittsdc@gmail.com', 'afritts31@isk.ac.ke', 6, '12935', NULL),
	(135, 'Harris', 'Owen', 'tnicoleharris@sbcglobal.net', 'omarharris@sbcglobal.net', 'oharris30@isk.ac.ke', 7, '12609', 'Beginning Band 1 2023'),
	(203, 'Haswell', 'Finlay', 'ahaswell@isk.ac.ke', 'danhaswell@hotmail.co.uk', 'fhaswell30@isk.ac.ke', 7, '10562', 'Beginning Band 7 2023'),
	(892, 'Heijstee', 'Leah', 'vivien.jarl@gmail.com', 'vivien.jarl@gmail.com', 'lheijstee33@isk.ac.ke', 4, '12782', NULL),
	(522, 'Hire', 'Ainsley', 'jhire@isk.ac.ke', 'bhire@isk.ac.ke', 'ahire29@isk.ac.ke', 8, '10621', 'Concert Band 2023'),
	(138, 'Hissink', 'Pomeline', 'saskia@dobequity.nl', 'lodewijkh@gmail.com', 'phissink29@isk.ac.ke', 8, '10683', NULL),
	(12, 'Hodge', 'Eliana', 'janderson12@worldbank.org', 'jhodge1@worldbank.org', 'ehodge29@isk.ac.ke', 8, '12193', 'Concert Band 2023'),
	(112, 'James', 'Evelyn', 'tiarae@rocketmail.com', 'rosetimothy@gmail.com', 'ejames31@isk.ac.ke', 6, '10843', NULL),
	(980, 'Janisse', 'Riley', 'katlawlor@icloud.com', 'marcjanisse@icloud.com', 'rjanisse31@isk.ac.ke', 6, '12676', NULL),
	(194, 'Jayaram', 'Milan', 'sonali.murthy@gmail.com', 'kartik_j@yahoo.com', 'mijayaram29@isk.ac.ke', 8, '10493', 'Concert Band 2023'),
	(970, 'Khalid', 'Zaria', 'aryana.c.khalid@gmail.com', 'waqqas.khalid@gmail.com', 'zkhalid32@isk.ac.ke', 5, '12617', NULL),
	(324, 'Khubchandani', 'Anaiya', 'ramji.farzana@gmail.com', 'rishi.khubchandani@gmail.com', 'akhubchandani30@isk.ac.ke', 7, '11262', 'Beginning Band 7 2023'),
	(428, 'Kimuli', 'Ean', 'jusmug@yahoo.com', 'e.sennoga@afdb.org', 'ekimuli29@isk.ac.ke', 8, '11703', 'Concert Band 2023'),
	(108, 'Lopez Abella', 'Mara', 'monica.lopezconlon@gmail.com', 'iniakiag@gmail.com', 'mlopezabella31@isk.ac.ke', 6, '11819', NULL),
	(982, 'Lundell', 'Elijah', 'rebekahlundell@gmail.com', 'redlundell@gmail.com', 'elundell31@isk.ac.ke', 6, '12692', NULL),
	(971, 'Menkerios', 'Safiya', 'oh_hassan@hotmail.com', 'hmenkerios@aol.com', 'smenkerios32@isk.ac.ke', 5, '11954', NULL),
	(99, 'Mogilnicki', 'Dominik', 'aurelia_micko@yahoo.com', 'milosz.mogilnicki@gmail.com', 'dmogilnicki31@isk.ac.ke', 6, '11481', NULL),
	(983, 'Mpatswe', 'Johannah', 'olivia.mutambo19@gmail.com', 'gkmpatswe@gmail.com', 'jmpatswe31@isk.ac.ke', 6, '12700', NULL),
	(973, 'Mucci', 'Arianna', 'crista.mcinnis@gmail.com', 'warren.mucci@gmail.com', 'amucci32@isk.ac.ke', 5, '12695', NULL),
	(974, 'Oberjuerge', 'Graham', 'kateharris22@gmail.com', 'loberjue@gmail.com', 'goberjuerge32@isk.ac.ke', 5, '12686', NULL),
	(384, 'Plunkett', 'Wataru', 'makiplunkett@live.jp', 'jplun585@gmail.com', 'wplunkett29@isk.ac.ke', 8, '12853', 'Concert Band 2023'),
	(192, 'Ramrakha', 'Niyam', 'leenagehlot@gmail.com', 'rishiramrakha@gmail.com', 'nramrakha26@isk.ac.ke', 11, '11379', NULL),
	(111, 'Rose', 'Axel', 'tiarae@rocketmail.com', 'rosetimothy@gmail.com', 'arose37@isk.ac.ke', 0, '12753', NULL),
	(975, 'Ryan', 'Patrick', 'jemichler@gmail.com', 'dpryan999@gmail.com', 'pryan32@isk.ac.ke', 5, '12816', NULL) ON CONFLICT DO NOTHING;
INSERT INTO public.students (id, last_name, first_name, parent1_email, parent2_email, email, grade_level, student_number, class) VALUES
	(122, 'Schmidlin Guerrero', 'Julian', 'ag.guerreroserdan@gmail.com', 'gaby.juerg@gmail.com', 'jschmidlin31@isk.ac.ke', 6, '11803', NULL),
	(976, 'Schrader', 'Penelope', 'schraderhub@gmail.com', 'schraderjp09@gmail.com', 'pschrader32@isk.ac.ke', 5, '12839', NULL),
	(114, 'Shah', 'Arav', 'alpadodhia@gmail.com', 'whiteicepharmaceuticals@gmail.com', 'ashah29@isk.ac.ke', 8, '10784', NULL),
	(116, 'Thornton', 'Robert', 'emilypt1980@outlook.com', 'thorntoncr1@state.gov', 'rthornton29@isk.ac.ke', 8, '12992', NULL),
	(115, 'Thornton', 'Lucia', 'emilypt1980@outlook.com', 'thorntoncr1@state.gov', 'lthornton31@isk.ac.ke', 6, '12993', NULL),
	(977, 'Von Platen-Hallermund', 'Rebecca', 'mspliid@gmail.com', 'thobobs@hotmail.com', 'rplatenhallermund32@isk.ac.ke', 5, '12887', NULL),
	(792, 'Wesley Iii', 'Howard', 'wnyakiti@gmail.com', 'ajawesley@yahoo.com', 'hwesleyiii37@isk.ac.ke', 0, '12861', NULL),
	(104, 'Wilkes', 'Nova', 'aninepier@gmail.com', 'joshuawilkes@hotmail.co.uk', 'nwilkes37@isk.ac.ke', 0, '12750', NULL),
	(120, 'Willis', 'Gabrielle', 'tjpeta.willis@gmail.com', 'pt.willis@bigpond.com', 'gwillis31@isk.ac.ke', 6, '12970', NULL),
	(966, 'Bailey', 'Kira', 'anneli.veiszhaupt.bailey@gov.se', 'dbailey1971@gmail.com', 'kbailey32@isk.ac.ke', 5, '12289', NULL),
	(1049, 'Birschbach', 'Chisanga', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'cbirschbach25@isk.ac.ke', 12, '13055', NULL),
	(967, 'Bixby', 'Aaryama', 'rkaria@gmail.com', 'malcolmbixby@gmail.com', 'abixby32@isk.ac.ke', 5, '12850', NULL),
	(22, 'Camisa', 'EugéNie', 'katerinelafreniere@hotmail.com', 'laurentcamisa@hotmail.com', 'ecamisa30@isk.ac.ke', 7, '11883', 'Beginning Band 7 2023'),
	(168, 'Biesiada', 'Maria-Antonina (Jay)', 'magda.biesiada@gmail.com', NULL, 'mbiesiada26@isk.ac.ke', 11, '11723', NULL),
	(1041, 'Chappell', 'Maximilian', 'mgorzelanska@usaid.gov', 'jchappell@usaid.gov', 'mchappell26@isk.ac.ke', 11, '12576', NULL),
	(206, 'Choda', 'Ariana', 'gabriele@sunworldsafaris.com', 'dchoda22@gmail.com', 'achoda26@isk.ac.ke', 11, '10973', NULL),
	(1042, 'De Geer-Howard', 'Charlotte', 'catharina_degeer@yahoo.com', 'jackhoward03@yahoo.com', 'cdegeer-howard26@isk.ac.ke', 11, '12653', NULL),
	(178, 'De Jong', 'Max', 'anouk.paauwe@gmail.com', 'rob.jong@un.org', 'mdejong25@isk.ac.ke', 12, '24001', NULL),
	(210, 'Ernst', 'Aika', 'andreaernst@gmail.com', 'ebaimu@gmail.com', 'aernst33@isk.ac.ke', 4, '11628', NULL),
	(209, 'Ernst', 'Kai', 'andreaernst@gmail.com', 'ebaimu@gmail.com', 'kernst36@isk.ac.ke', 1, '13043', NULL),
	(160, 'Fazal', 'Alyssia', 'aleeda@gmail.com', 'rizwanfazal2013@gmail.com', 'afazal28@isk.ac.ke', 9, '11878', NULL),
	(158, 'Feizzadeh', 'Kasra', 'mahshidtaj88@gmail.com', 'feizzadeha@unaids.org', 'kfeizzadeh27@isk.ac.ke', 10, '12871', NULL),
	(157, 'Feizzadeh', 'Saba', 'mahshidtaj88@gmail.com', 'feizzadeha@unaids.org', 'sfeizzadeh32@isk.ac.ke', 5, '12872', NULL),
	(161, 'Foster', 'Chloe', 'Ttruong@isk.ac.ke', 'Bfoster@isk.ac.ke', 'cfoster25@isk.ac.ke', 12, '11530', NULL),
	(155, 'Godfrey', 'Tobias', 'amakagodfrey@gmail.com', 'drsamgodfrey@yahoo.co.uk', 'tgodfrey29@isk.ac.ke', 8, '11227', 'Concert Band 2023'),
	(154, 'Godfrey', 'Benjamin', 'amakagodfrey@gmail.com', 'drsamgodfrey@yahoo.co.uk', 'bgodfrey31@isk.ac.ke', 6, '11242', NULL),
	(167, 'Good', 'Julia', 'jenniferaharwood@yahoo.com', 'travistcg@gmail.com', 'jgood28@isk.ac.ke', 9, '12878', NULL),
	(166, 'Good', 'Tyler', 'jenniferaharwood@yahoo.com', 'travistcg@gmail.com', 'tgood32@isk.ac.ke', 5, '12879', NULL),
	(170, 'Hajee', 'Kaiam', 'jhajee@isk.ac.ke', 'khalil.hajee@gmail.com', 'khajee31@isk.ac.ke', 6, '11520', NULL),
	(171, 'Hajee', 'Kadin', 'jhajee@isk.ac.ke', 'khalil.hajee@gmail.com', 'khajee29@isk.ac.ke', 8, '11542', NULL),
	(188, 'Handa', 'Jin', 'jinln-2009@163.com', 'jinzhe322406@gmail.com', 'kjin26@isk.ac.ke', 11, '10641', NULL),
	(149, 'Hussain', 'Tawheed', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'thussain30@isk.ac.ke', 7, '11469', 'Beginning Band 1 2023'),
	(148, 'Hussain', 'Salam', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'shussain32@isk.ac.ke', 5, '11495', NULL),
	(1043, 'Islam', 'Aarish', 'aarishsaima11@yahoo.com', 'zahed.shimul@gmail.com', 'aislam26@isk.ac.ke', 11, '13008', NULL),
	(193, 'Jayaram', 'Akeyo', 'sonali.murthy@gmail.com', 'kartik_j@yahoo.com', 'ajayaram33@isk.ac.ke', 4, '11404', NULL),
	(1045, 'Lawrence', 'Dario', 'dandrea.claudia@gmail.com', 'ted.lawrence65@gmail.com', 'dlawrence26@isk.ac.ke', 11, '11438', NULL),
	(1046, 'Lemley', 'Maximo', 'julielemley@gmail.com', 'johnlemley@gmail.com', 'mlemley26@isk.ac.ke', 11, '12869', NULL),
	(794, 'Limpered', 'Ayana', 'christabel.owino@gmail.com', 'eodunguli@isk.ac.ke', 'alimpered37@isk.ac.ke', 0, '13085', NULL),
	(198, 'Line', 'Bronwyn', 'emeraldcardinal7@gmail.com', 'kris.line@ice.dhs.gov', 'bline27@isk.ac.ke', 10, '11626', NULL),
	(197, 'Line', 'Taegan', 'emeraldcardinal7@gmail.com', 'kris.line@ice.dhs.gov', 'tline29@isk.ac.ke', 8, '11627', NULL),
	(153, 'Lopez Salazar', 'Mateo', 'alopez@isk.ac.ke', NULL, 'mlopezsalazar36@isk.ac.ke', 1, '12752', NULL),
	(187, 'Masrani', 'Anusha', 'shrutimasrani@gmail.com', 'rupinmasrani@gmail.com', 'amasrani28@isk.ac.ke', 9, '10632', NULL),
	(200, 'Mujuni', 'Tangaaza', 'barbara.bamanya@gmail.com', 'benardmujuni@gmail.com', 'tmujuni29@isk.ac.ke', 8, '10788', NULL),
	(201, 'Mujuni', 'Rugaba', 'barbara.bamanya@gmail.com', 'benardmujuni@gmail.com', 'rmujuni26@isk.ac.ke', 11, '20828', NULL),
	(169, 'Nannes', 'Ben', 'pamela@terrasolkenya.com', 'sjaak@terrasolkenya.com', 'bnannes27@isk.ac.ke', 10, '10980', NULL),
	(177, 'Ndinguri', 'Zawadi', 'muriithifiona@gmail.com', 'joramgatei@gmail.com', 'zndinguri31@isk.ac.ke', 6, '11936', NULL),
	(165, 'Patella Ross', 'Juna', 'sarahpatella@icloud.com', 'bross@unicef.org', 'jpatellaross26@isk.ac.ke', 11, '10617', NULL),
	(164, 'Patella Ross', 'Rafaelle', 'sarahpatella@icloud.com', 'bross@unicef.org', 'rpatellaross29@isk.ac.ke', 8, '10707', NULL),
	(191, 'Ramrakha', 'Divyaan', 'leenagehlot@gmail.com', 'rishiramrakha@gmail.com', 'dramrakha29@isk.ac.ke', 8, '11830', NULL),
	(183, 'Rogers', 'Otis', 'laoisosullivan@yahoo.com.au', 'mrogers@isk.ac.ke', 'orogers35@isk.ac.ke', 2, '11940', NULL),
	(184, 'Rogers', 'Liam', 'laoisosullivan@yahoo.com.au', 'mrogers@isk.ac.ke', 'lrogers37@isk.ac.ke', 0, '12744', NULL),
	(799, 'Roquebrune', 'Marianne', 'mroquebrune@yahoo.ca', NULL, 'mroquebrune37@isk.ac.ke', 0, '12644', NULL),
	(156, 'Sana', 'Jamal', 'hadizamounkaila4@gmail.com', 'moussa.sana@wfp.org', 'jsana25@isk.ac.ke', 12, '11525', NULL),
	(195, 'Sapta', 'Gendhis', 'vanda.andromeda@yahoo.com', 'sapta.hendra@yahoo.com', 'gsapta28@isk.ac.ke', 9, '10320', NULL),
	(802, 'Stiles', 'Lukas', 'ppappas@isk.ac.ke', 'stilesdavid@gmail.com', 'lstiles37@isk.ac.ke', 0, '13068', NULL),
	(196, 'Venkataya', 'Kianna', 'e.venkataya@gmail.com', NULL, 'kvenkataya32@isk.ac.ke', 5, '12706', NULL),
	(214, 'Veverka', 'Jonah', 'cveverka@usaid.gov', 'jveverka@usaid.gov', 'jveverka36@isk.ac.ke', 1, '12835', NULL),
	(215, 'Veverka', 'Theocles', 'cveverka@usaid.gov', 'jveverka@usaid.gov', 'tveverka34@isk.ac.ke', 3, '12838', NULL),
	(186, 'Wood', 'Caitlin', 'carriewoodtz@gmail.com', 'cwood.ken@gmail.com', 'cwood25@isk.ac.ke', 12, '10934', NULL),
	(1038, 'Andersen', 'Solveig', 'millelund@gmail.com', 'steensandersen@gmail.com', 'sandersen26@isk.ac.ke', 11, '12569', NULL),
	(1039, 'Astier', 'EugèNe', 'oberegoi@yahoo.com', 'astier6@bluewin.ch', 'eastier26@isk.ac.ke', 11, '12790', NULL),
	(1022, 'Bagenda', 'Maya', 'katy@katymitchell.com', 'xolani@mac.com', 'mbagenda27@isk.ac.ke', 10, '12147', NULL),
	(1040, 'Bergqvist', 'Elsa', 'moa.m.bergqvist@gmail.com', 'jbergqvist@hotmail.com', 'ebergqvist26@isk.ac.ke', 11, '12911', NULL),
	(1013, 'Bergqvist', 'Fanny', 'moa.m.bergqvist@gmail.com', 'jbergqvist@hotmail.com', 'fbergqvist28@isk.ac.ke', 9, '12912', NULL),
	(985, 'Birk', 'Bertram', 'gerbir@um.dk', 'thobirk@gmail.com', 'bbirk30@isk.ac.ke', 7, '12699', NULL),
	(999, 'Breda', 'Luka', 'jlbarak@hotmail.com', 'cybreda@hotmail.com', 'lbreda29@isk.ac.ke', 8, '12183', NULL),
	(1000, 'Breda', 'Paco', 'jlbarak@hotmail.com', 'cybreda@hotmail.com', 'pbreda29@isk.ac.ke', 8, '12184', NULL),
	(226, 'Byrne-Ilako', 'Sianna', 'ailish.byrne@crs.org', 'james10s@aol.com', 'sbyrne-ilako25@isk.ac.ke', 12, '11751', NULL),
	(987, 'Carey', 'Elijah', 'twilford98@yahoo.com', 'scarey192003@yahoo.com', 'ecarey30@isk.ac.ke', 7, '12923', NULL),
	(1026, 'Cherickel', 'Jai', 'urpmathew@gmail.com', 'cherickel@gmail.com', 'jcherickel27@isk.ac.ke', 10, '13006', NULL),
	(1014, 'Cizek', 'Norah (Rebel)', 'suzcizek@gmail.com', NULL, 'ncizek28@isk.ac.ke', 9, '12666', NULL),
	(1027, 'Dalal', 'Samarth', 'sapnarathi04@gmail.com', 'bharpurdalal@gmail.com', 'sdalal27@isk.ac.ke', 10, '12859', NULL),
	(878, 'Dodhia', 'Rohin', 'tejal@capet.co.ke', 'ketul.dodhia@gmail.com', 'rdodhia25@isk.ac.ke', 12, '10820', NULL),
	(744, 'Donne', 'Maisha', 'omazzaroni@unicef.org', 'william55don@gmail.com', 'mdone25@isk.ac.ke', 12, '12590', NULL),
	(1003, 'Eldridge', 'Colin', '780711th@gmail.com', 'tomheldridge@hotmail.com', 'celdridge29@isk.ac.ke', 8, '12974', NULL),
	(1028, 'Ephrem Yohannes', 'Dan', 'berhe@unhcr.org', 'jdephi@gmail.com', 'dephremyohannes27@isk.ac.ke', 10, '11772', NULL),
	(477, 'Exel', 'Joshua', 'kexel@usaid.gov', 'jexel@worldbank.org', 'jexel26@isk.ac.ke', 11, '12073', NULL),
	(1004, 'Ferede', 'Maya', 'sinkineshb@gmail.com', 'fasikaf@gmail.com', 'mferede29@isk.ac.ke', 8, '11726', NULL),
	(277, 'Fort', 'Kaitlyn', 'kellymaura@gmail.com', 'brycelfort@gmail.com', 'kfort33@isk.ac.ke', 4, '11704', NULL),
	(1005, 'Fritts', 'Ava', 'frittsalexa@gmail.com', 'jfrittsdc@gmail.com', 'afritts29@isk.ac.ke', 8, '12928', NULL),
	(220, 'Giblin', 'Drew (Tilly)', 'kloehr@gmail.com', 'drewgiblin@gmail.com', 'dgiblin34@isk.ac.ke', 3, '12963', NULL),
	(1052, 'Hobbs', 'Liam', 'ywhobbs@yahoo.com', 'hbhobbs95@gmail.com', 'lhobbs25@isk.ac.ke', 12, '12971', NULL),
	(1029, 'Hobbs', 'Rowan', 'ywhobbs@yahoo.com', 'hbhobbs95@gmail.com', 'rhobbs27@isk.ac.ke', 10, '12972', NULL),
	(403, 'Hornor', 'Anneka', 'schlesingermaria@gmail.com', 'chris@powerhive.com', 'ahornor26@isk.ac.ke', 11, '12377', NULL),
	(223, 'Jama', 'Bella', 'katie.elles@gmail.com', 'jama.artan@gmail.com', 'bjama35@isk.ac.ke', 2, '12457', NULL),
	(1015, 'Janisse', 'Alexa', 'katlawlor@icloud.com', 'marcjanisse@icloud.com', 'ajanisse28@isk.ac.ke', 9, '12675', NULL),
	(1031, 'Joymungul', 'Vashnie', 'sikam04@yahoo.com', 's.joymungul@afdb.org', 'vjoymungul27@isk.ac.ke', 10, '12996', NULL),
	(1053, 'Kadilli', 'Daniel', 'ekadilli@unicef.org', 'bardh.kadilli@gmail.com', 'dkadilli25@isk.ac.ke', 12, '12991', NULL),
	(1032, 'Kamenga', 'Sphesihle', 'nompumelelo.nkosi@gmail.com', 'kamenga@gmail.com', 'skamenga27@isk.ac.ke', 10, '12876', NULL),
	(1007, 'Kishiue', 'Mahiro', 'akishiue@worldbank.org', 'jan.turkstra@gmail.com', 'mkishiue29@isk.ac.ke', 8, '12679', NULL),
	(242, 'Korvenoja', 'Leo', 'tita.korvenoja@gmail.com', 'korvean@gmail.com', 'lkorvenoja25@isk.ac.ke', 12, '11526', NULL),
	(1008, 'Lemley', 'Lola', 'julielemley@gmail.com', 'johnlemley@gmail.com', 'llemley29@isk.ac.ke', 8, '12870', NULL),
	(1016, 'Mendonca-Gray', 'Tiago', 'eduarda.gray@fcdo.gov.uk', 'johnathangray.1@icloud.com', 'tmendonca-gray28@isk.ac.ke', 9, '12948', NULL),
	(1033, 'Nam', 'Seung Yoon', 'hope7993@qq.com', 'sknam@mofa.go.kr', 'syoon-nam27@isk.ac.ke', 10, '13079', NULL),
	(1054, 'Nimubona', 'Jay Austin', 'jnkinabacura@gmail.com', 'boubaroy19@gmail.com', 'jnimubona25@isk.ac.ke', 12, '12749', NULL),
	(748, 'Nora', 'Nadia', 'caranora@gmail.com', 'nora.enrico@gmail.com', 'nnora25@isk.ac.ke', 12, '12860', NULL),
	(262, 'Patel', 'Imara', 'bindyaracing@hotmail.com', 'patelsatyan@hotmail.com', 'ipatel25@isk.ac.ke', 12, '12275', NULL),
	(997, 'Ryan', 'Eva', 'jemichler@gmail.com', 'dpryan999@gmail.com', 'eryan30@isk.ac.ke', 7, '12618', NULL),
	(256, 'Schoneveld', 'Jasmine', 'nicoliendelange@hotmail.com', 'georgeschoneveld@gmail.com', 'jschoneveld33@isk.ac.ke', 4, '11879', NULL),
	(1010, 'Sobantu', 'Nicholas', 'mbemelaphi@gmail.com', 'monwabisi.sobantu@gmail.com', 'nsobantu29@isk.ac.ke', 8, '12940', NULL),
	(1017, 'Spitler', 'Alexa', 'deborah.spitler@gmail.com', 'spitlerj@gmail.com', 'aspitler28@isk.ac.ke', 9, '12595', NULL),
	(1055, 'Stabrawa', 'Anna Sophia', 'stabrawaa@gmail.com', NULL, 'astabrawa25@isk.ac.ke', 12, '25052', NULL),
	(1018, 'Sykes', 'Maia', 'cate@colinsykes.com', 'mail@colinsykes.com', 'msykes28@isk.ac.ke', 9, '12952', NULL),
	(1057, 'Sylla', 'Lalia', 'mchaidara@gmail.com', 'syllamas@gmail.com', 'lsylla25@isk.ac.ke', 12, '12628', NULL),
	(1058, 'Valdivieso Santos', 'Camila', 'metamelia@gmail.com', 'valdivieso@unfpa.org', 'cvaldivieso25@isk.ac.ke', 12, '12568', NULL),
	(405, 'Veveiros', 'Xavier', 'julie.veveiros5@gmail.com', 'aveveiros@yahoo.com', 'xveveiros26@isk.ac.ke', 11, '12009', NULL),
	(880, 'Victor', 'Chalita', NULL, 'Michaelnoahvictor@gmail.com', 'cvictor25@isk.ac.ke', 12, '12529', NULL),
	(1019, 'Weill', 'Sonia', 'robineberlin@gmail.com', 'matthew_weill@mac.com', 'sweill28@isk.ac.ke', 9, '12848', NULL),
	(1059, 'Wright', 'Emma', 'robertsonwright@gmail.com', 'robertsonwright@gmail.com', 'ewright25@isk.ac.ke', 12, '12567', NULL),
	(1021, 'Zulberti', 'Sienna', 'zjenemi@gmail.com', 'emiliano.zulberti@gmail.com', 'szulberti28@isk.ac.ke', 9, '12672', NULL),
	(600, 'Acharya', 'Anshi', 'isk@kuttaemail.com', 'thaipeppers2020@gmail.com', 'aacharya29@isk.ac.ke', 8, '12881', NULL),
	(134, 'Ansell', 'Louise', 'emily.ansell@gmail.com', 'damon.ansell@gmail.com', 'lansell26@isk.ac.ke', 11, '11852', NULL),
	(998, 'Bagenda', 'Mitchell', 'katy@katymitchell.com', 'xolani@mac.com', 'mbagenda29@isk.ac.ke', 8, '12146', NULL),
	(1012, 'Basnet', 'Anshika', 'gamu_sharma@yahoo.com', 'mbasnet@iom.int', 'abasnet28@isk.ac.ke', 9, '12450', NULL),
	(807, 'Bailey', 'Arthur', 'tertia.bailey@fcdo.gov.uk', 'petergrahambailey@gmail.com', 'abailey27@isk.ac.ke', 10, '12825', NULL),
	(1023, 'Bakhshi', 'Muhammad Uneeb', 'libra_779@hotmail.com', 'muneeb_bakhshi@hotmail.com', 'mbakhshi27@isk.ac.ke', 10, '12760', NULL),
	(72, 'Biafore', 'Giancarlo', 'nermil@gmail.com', 'montiforce@gmail.com', 'gbiafore28@isk.ac.ke', 9, '12171', 'Concert Band 2023'),
	(1024, 'Birschbach', 'Natasha', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'nbirschbach27@isk.ac.ke', 10, '13058', NULL),
	(1025, 'Blanc Yeo', 'Lara', 'yeodeblanc@gmail.com', 'julian.blanc@gmail.com', 'lblanc-yeo27@isk.ac.ke', 10, '12858', NULL),
	(622, 'Buksh', 'Sultan', 'aarif@ifc.org', NULL, 'sbuksh28@isk.ac.ke', 9, '11996', NULL),
	(901, 'Cameron-Mutyaba', 'Lillian', 'jennifer.cameron@international.gc.ca', 'mutyaba32@gmail.com', 'lcameron-mutyaba26@isk.ac.ke', 11, '12634', NULL),
	(902, 'Cameron-Mutyaba', 'Rose', 'jennifer.cameron@international.gc.ca', 'mutyaba32@gmail.com', 'rcameron-mutyaba26@isk.ac.ke', 11, '12635', NULL),
	(261, 'Chandaria', 'Sohil', 'avni@stjohnslodge.com', 'hc@kincap.com', 'schandaria26@isk.ac.ke', 11, '12124', NULL),
	(282, 'Chandaria', 'Siana', 'rupalbid@gmail.com', 'bchandaria@gmail.com', 'schandaria25@isk.ac.ke', 12, '25072', NULL),
	(159, 'Fazal', 'Kayla', 'aleeda@gmail.com', 'rizwanfazal2013@gmail.com', 'kfazal30@isk.ac.ke', 7, '12201', NULL),
	(173, 'Gebremedhin', 'Maria', 'donicamerhazion@gmail.com', 'mgebremedhin@gmail.com', 'mgebremedhin30@isk.ac.ke', 7, '10688', NULL),
	(204, 'Haswell', 'Emily', 'ahaswell@isk.ac.ke', 'danhaswell@hotmail.co.uk', 'ehaswell28@isk.ac.ke', 9, '27066', NULL),
	(544, 'Jensen', 'Daniel', 'amag32@gmail.com', 'jonathon.jensen@gmail.com', 'djensen26@isk.ac.ke', 11, '11898', NULL),
	(542, 'Jensen', 'Emiliana', 'amag32@gmail.com', 'jonathon.jensen@gmail.com', 'ejensen28@isk.ac.ke', 9, '11904', 'Concert Band 2023'),
	(543, 'Jensen', 'Nickolas', 'amag32@gmail.com', 'jonathon.jensen@gmail.com', 'njensen28@isk.ac.ke', 9, '11926', 'Concert Band 2023'),
	(1063, 'Khan', 'Hanan', 'rahilak@yahoo.com', 'imtiaz.khan@cassiacap.com', 'hkhan24@isk.ac.ke', 13, '10464', NULL),
	(920, 'Kisukye', 'Gabriel', 'dmulira16@gmail.com', 'kisukye@un.org', 'gkisukye26@isk.ac.ke', 11, '12759', NULL),
	(552, 'Kraemer', 'Caio', 'leticiarc73@gmail.com', 'eduardovk03@gmail.com', 'ckraemer27@isk.ac.ke', 10, '11906', NULL),
	(876, 'Lavack', 'Mark', 'patricia.wanyee@gmail.com', 'slavack@isk.ac.ke', 'mlavack28@isk.ac.ke', 9, '20817', NULL),
	(55, 'Lindvig', 'Sif', 'elisa@lindvig.com', 'jglindvig@gmail.com', 'slindvig28@isk.ac.ke', 9, '12502', NULL),
	(66, 'Mathers', 'Yui', 'eri77s@gmail.com', 'nickmathers@gmail.com', 'ymathers28@isk.ac.ke', 9, '11110', NULL),
	(804, 'Matimu', 'Nathan', 'liz.matimu@gmail.com', 'mngacha@gmail.com', 'nmatimu27@isk.ac.ke', 10, '12979', NULL),
	(100, 'Mogilnicki', 'Alexander', 'aurelia_micko@yahoo.com', 'milosz.mogilnicki@gmail.com', 'amogilnicki29@isk.ac.ke', 8, '11480', 'Concert Band 2023'),
	(281, 'Muoki', 'Ruby', 'angelawokabi11@gmail.com', 'jmuoki@outlook.com', 'rmuoki25@isk.ac.ke', 12, '12278', NULL),
	(540, 'Njenga', 'Justin', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'jnjenga26@isk.ac.ke', 11, '12281', NULL),
	(78, 'Ouma', 'Destiny', 'aouso05@gmail.com', 'oumajao05@gmail.com', 'douma28@isk.ac.ke', 9, '10319', NULL),
	(916, 'Pandit', 'Jia', 'purvipandit@gmail.com', 'dhruvpandit@gmail.com', 'jpandit26@isk.ac.ke', 11, '10437', NULL),
	(348, 'Patel', 'Shane', 'rajul@ramco.co.ke', 'hasit@ramco.co.ke', 'spatel28@isk.ac.ke', 9, '10138', NULL),
	(1034, 'Rathore', 'Ishita', 'priyanka.gupta.rathore@gmail.com', 'abhishek.rathore@cgiar.org', 'irathore27@isk.ac.ke', 10, '12983', NULL),
	(1035, 'Rex', 'Nicholas', 'helenerex@gmail.com', 'familyrex@gmail.com', 'nrex27@isk.ac.ke', 10, '10884', NULL),
	(1047, 'Roquitte', 'Lila', 'sroquitte@hotmail.com', 'tptrenkle@hotmail.com', 'lroquitte26@isk.ac.ke', 11, '12555', NULL),
	(567, 'Ross', 'Caleb', 'skeddington@yahoo.com', 'sross78665@gmail.com', 'cross28@isk.ac.ke', 9, '11677', 'Concert Band 2023'),
	(531, 'Rwehumbiza', 'Jonathan', 'abakilana@worldbank.org', 'abakilana@worldbank.org', 'jrwehumbiza26@isk.ac.ke', 11, '11854', NULL),
	(1048, 'Scanlon', 'Mathilde', 'kim@wolfenden.net', 'shane.scanlon@rescue.org', 'mscanlon26@isk.ac.ke', 11, '12558', NULL),
	(208, 'Schmid', 'Sophia', 'aschmid@isk.ac.ke', 'sschmid@isk.ac.ke', 'sschmid25@isk.ac.ke', 12, '10975', NULL),
	(284, 'Shah', 'Sohan', 'diyasohan@gmail.com', 'bhavan@cpshoes.com', 'sshah24@isk.ac.ke', 13, '11190', NULL),
	(259, 'Shah', 'Deesha', 'hemapiyu@yahoo.com', 'priyesh@eazy-group.com', 'dshah26@isk.ac.ke', 11, '12108', NULL),
	(247, 'Steel', 'Tessa', 'dianna.kopansky@un.org', 'derek@ramco.co.ke', 'tsteel26@isk.ac.ke', 11, '12116', NULL),
	(374, 'Suri', 'Armaan', 'shipra.unhabitat@gmail.com', 'suri.raj@gmail.com', 'asuri29@isk.ac.ke', 8, '11076', NULL),
	(903, 'Teferi', 'Nathan', 'lula.tewfik@gmail.com', 'tamessay@hotmail.com', 'nteferi26@isk.ac.ke', 11, '12984', NULL),
	(786, 'Ukumu', 'Kors', 'ukumuphyllis@gmail.com', 'ukumu2002@gmail.com', 'kukumu27@isk.ac.ke', 10, '12545', NULL),
	(882, 'Waalewijn', 'Noam', 'manonwaalewijn@gmail.com', 'manonenpieter@gmail.com', 'nwaalewijn28@isk.ac.ke', 9, '12597', 'Concert Band 2023'),
	(263, 'Wissanji', 'Riyaan', 'rwissanji@gmail.com', 'shaheed.wissanji@sopalodges.com', 'rwissanji26@isk.ac.ke', 11, '11437', NULL),
	(1020, 'Wright', 'Theodore', 'robertsonwright@gmail.com', 'robertsonwright@gmail.com', 'twright28@isk.ac.ke', 9, '12566', 'Concert Band 2023'),
	(144, 'Yarkoni', 'Itay', 'dvorayarkoni4@gmail.com', 'yarkan1@yahoo.com', 'iyarkoni28@isk.ac.ke', 9, '12169', NULL),
	(745, 'Abshir', 'Kaynan', 'nada.abshir@gmail.com', NULL, 'kabshir36@isk.ac.ke', 1, '12830', NULL),
	(872, 'Aditya', 'Jayesh', NULL, 'NANDKITTU@YAHOO.COM', 'jaditya28@isk.ac.ke', 9, '12472', NULL),
	(60, 'Aubrey', 'Carys', 'joaubrey829@gmail.com', 'dyfed.aubrey@un.org', 'caubrey28@isk.ac.ke', 9, '11838', NULL),
	(124, 'Awori', 'Joan', 'Annmarieawori@gmail.com', 'Michael.awori@gmail.com', 'jawori28@isk.ac.ke', 9, '10475', 'Concert Band 2023'),
	(984, 'Bergqvist', 'Bella', 'moa.m.bergqvist@gmail.com', 'jbergqvist@hotmail.com', 'bbergqvist30@isk.ac.ke', 7, '12913', NULL),
	(840, 'Bonde-Nielsen', 'Gaia', 'nike@terramoyo.com', 'pbn@oldonyolaro.com', 'gbondenielsen30@isk.ac.ke', 7, '12537', 'Beginning Band 8 - 2023'),
	(322, 'Boxer', 'Hana', 'mboxer@isk.ac.ke', 'bendboxer@hotmail.com', 'hboxer25@isk.ac.ke', 12, '11200', NULL),
	(623, 'Bruhwiler', 'Anika', 'bruehome@gmail.com', 'mbruhwiler@ifc.org', 'abruhwiler24@isk.ac.ke', 13, '12050', NULL),
	(272, 'Butt', 'Ziya', 'flalani-butt@isk.ac.ke', 'sameer.butt@outlook.com', 'zbutt27@isk.ac.ke', 10, '11401', NULL),
	(671, 'Crandall', 'Sofia', 'mariama1@mac.com', 'mail@billcrandall.com', 'scrandall24@isk.ac.ke', 13, '12990', NULL),
	(4, 'Dadasheva', 'Zubeyda', 'huseynovags@yahoo.com', 'adadashev@unicef.org', 'zdadasheva24@isk.ac.ke', 13, '12769', NULL),
	(776, 'Dawoodbhai', 'Alifiya', 'munizola77@yahoo.com', 'zoher@royalgroupkenya.com', 'adawoodbhai24@isk.ac.ke', 13, '12580', NULL),
	(640, 'Dokunmu', 'Abdul-Lateef Boluwatife (Bolu)', 'JJAGUN@GMAIL.COM', NULL, 'adokunmu29@isk.ac.ke', 8, '11463', 'Band 8 2024'),
	(612, 'Duwyn', 'Teo', 'angeladuwyn@gmail.com', 'dduwyn@gmail.com', 'tduwyn31@isk.ac.ke', 6, '12085', NULL),
	(790, 'Fatty', 'Fatoumatta', 'fatoumatafatty542@gmail.com', 'fatty@un.org', 'ffatty24@isk.ac.ke', 13, '12735', NULL),
	(190, 'Fest', 'Marie', 'marilou_de_wit@hotmail.com', 'michel.fest@gmail.com', 'mfest25@isk.ac.ke', 12, '10278', NULL),
	(526, 'Firzé Al Ghaoui', 'NatéA', 'agnaima@gmail.com', 'olivierfirze@gmail.com', 'nfirzealghaoui29@isk.ac.ke', 8, '12190', 'Concert Band 2023'),
	(67, 'Gardner', 'Madeleine', 'michelle.barrett@wfp.org', 'calum.gardner@wfp.org', 'mgardner31@isk.ac.ke', 6, '11468', 'Band 8 2024'),
	(596, 'Godden', 'Noa', 'martinettegodden@gmail.com', 'kieranrgodden@gmail.com', 'ngodden31@isk.ac.ke', 6, '12504', 'Band 8 2024'),
	(909, 'Goyal', 'Seher', 'vitastasingh@hotmail.com', 'sgoyal@worldbank.org', 'sgoyal26@isk.ac.ke', 11, '12373', NULL),
	(202, 'Guyard Suengas', 'Laia', 'tetxusu@gmail.com', NULL, 'lguyard25@isk.ac.ke', 12, '20805', NULL),
	(236, 'Hansen Meiro', 'Isabel', 'mmeirolorenzo@gmail.com', 'keithehansen@gmail.com', 'ihansenmeiro31@isk.ac.ke', 6, '11943', 'Band 8 2024'),
	(760, 'Houndeganme', 'CréDo Terrence', 'kougblenouchristelle@gmail.com', 'ahoundeganme@unicef.org', 'thoundeganme24@isk.ac.ke', 13, '12813', NULL),
	(536, 'Hughes', 'Noah', 'ahughes@isk.ac.ke', 'ethiopiashaun@gmail.com', 'nhughes25@isk.ac.ke', 12, '10477', NULL),
	(402, 'Hwang', 'Jihwan', 'choijungh83@gmail.com', 'cs5085.hwang@samsung.com', 'jhwang31@isk.ac.ke', 6, '11951', 'Band 8 2024'),
	(651, 'Ireri', 'Kennedy', 'mwebi@unhcr.org', NULL, 'kireri27@isk.ac.ke', 10, '10313', NULL),
	(865, 'Jijina', 'Sanaya', 'shahnazjijjina@gmail.com', 'percy.jijina@jotun.com', 'sjijina24@isk.ac.ke', 13, '12736', NULL),
	(1006, 'Joymungul', 'Nirvi', 'sikam04@yahoo.com', 's.joymungul@afdb.org', 'njoymungul29@isk.ac.ke', 8, '12997', 'Concert Band 2023'),
	(810, 'Kone', 'Zahra', 'sonjalk@unops.org', 'zakskone@gmail.com', 'zkone24@isk.ac.ke', 13, '11367', NULL),
	(1064, 'Lawrence', 'Vincenzo', 'dandrea.claudia@gmail.com', 'ted.lawrence65@gmail.com', 'vlawrence24@isk.ac.ke', 13, '11447', NULL),
	(151, 'Liban', 'Ismail', 'shukrih77@gmail.com', 'aliban@cdc.gov', 'iliban29@isk.ac.ke', 8, '11647', NULL),
	(199, 'Line', 'Jamison', 'emeraldcardinal7@gmail.com', 'kris.line@ice.dhs.gov', 'jline25@isk.ac.ke', 12, '11625', NULL),
	(1066, 'Lutz', 'Noah', 'azents@isk.ac.ke', 'stephanlutz@worldrenew.net', 'nlutz24@isk.ac.ke', 13, '24008', NULL),
	(176, 'Mcmurtry', 'Jack', 'karenpoore77@yahoo.co.uk', 'seanmcmurtry7@gmail.com', 'jmcmurtry30@isk.ac.ke', 7, '10812', 'Beginning Band 8 - 2023'),
	(175, 'Mcmurtry', 'Holly', 'karenpoore77@yahoo.co.uk', 'seanmcmurtry7@gmail.com', 'hmcmurtry30@isk.ac.ke', 7, '10817', 'Beginning Band 1 2023'),
	(766, 'Moons', 'Olivia', 'kasia@laud.nl', 'leander@laud.nl', 'omoons32@isk.ac.ke', 5, '12852', NULL),
	(145, 'Nguyen', 'Yen', 'nnguyen@parallelconsultants.com', 'luu@un.org', 'ynguyen29@isk.ac.ke', 8, '11672', NULL),
	(539, 'Njenga', 'Grace', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'gnjenga29@isk.ac.ke', 8, '12280', 'Concert Band 2023'),
	(913, 'Otieno', 'Sifa', 'linet.otieno@gmail.com', 'tcpauldbtcol@gmail.com', 'sotieno24@isk.ac.ke', 13, '13013', NULL),
	(81, 'Patel', 'Cahir', 'nads_k@hotmail.com', 'samir@aura-capital.com', 'cpatel29@isk.ac.ke', 8, '10772', 'Concert Band 2023') ON CONFLICT DO NOTHING;
INSERT INTO public.students (id, last_name, first_name, parent1_email, parent2_email, email, grade_level, student_number, class) VALUES
	(41, 'Purdy', 'Annika', 'Mangoshy@yahoo.com', 'jess_a_purdy@yahoo.com', 'apurdy34@isk.ac.ke', 3, '12345', NULL),
	(207, 'Schmid', 'Isabella', 'aschmid@isk.ac.ke', 'sschmid@isk.ac.ke', 'ischmid25@isk.ac.ke', 12, '10974', NULL),
	(327, 'Shah', 'Janak', 'nishshah@hotmail.co.uk', 'nipshah@dunhillconsulting.com', 'jshah25@isk.ac.ke', 12, '10830', NULL),
	(911, 'Singh', 'Abhimanyu', NULL, 'rkc.jack@gmail.com', 'asingh34@isk.ac.ke', 3, '12728', NULL),
	(693, 'Stock', 'Max', 'rydebstock@hotmail.com', 'stockr2@state.gov', 'mstock30@isk.ac.ke', 7, '12915', 'Beginning Band 1 2023'),
	(675, 'Thomas', 'Alexander', 'claire@go-two-one.net', 'sunfish62@gmail.com', 'athomas25@isk.ac.ke', 12, '12579', NULL),
	(1069, 'Trenkle', 'Noah', 'sroquitte@hotmail.com', 'tptrenkle@hotmail.com', 'ntrenkle24@isk.ac.ke', 13, '12556', NULL),
	(345, 'Uberoi', 'Tara', 'alpaub@hotmail.com', 'moby@sivoko.com', 'tuberoi25@isk.ac.ke', 12, '11452', NULL),
	(614, 'Van Bommel', 'Cato', 'jorismarij@hotmail.com', 'joris-van.bommel@minbuza.nl', 'cvanbommel25@isk.ac.ke', 12, '12028', NULL),
	(440, 'Allard Ruiz', 'Sasha', 'katiadesouza@sobetrainternational.com', NULL, 'sruiz24@isk.ac.ke', 13, '11387', NULL),
	(442, 'Alnaqbi', 'Saqer', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'salnaqbi30@isk.ac.ke', 7, '12909', 'Beginning Band 8 - 2023'),
	(13, 'Arens', 'Jip', 'noudwater@gmail.com', 'luukarens@gmail.com', 'jarens24@isk.ac.ke', 13, '12430', NULL),
	(333, 'Bamlango', 'Cecile', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'cbamlango25@isk.ac.ke', 12, '10979', NULL),
	(218, 'Charette', 'Miles', 'mdimitracopoulos@isk.ac.ke', 'acharette@isk.ac.ke', 'mcharette27@isk.ac.ke', 10, '20780', NULL),
	(669, 'Dibling', 'Julian', 'askfelicia@gmail.com', 'sdibling@hotmail.com', 'jdibling30@isk.ac.ke', 7, '12883', 'Beginning Band 8 - 2023'),
	(678, 'Dove', 'Samuel', 'meganlpdove@gmail.com', 'stephencarterdove@gmail.com', 'sdove25@isk.ac.ke', 12, '12920', NULL),
	(229, 'Eshetu', 'Mikael', 'olga.petryniak@gmail.com', 'kassahun.wossene@gmail.com', 'meshetu30@isk.ac.ke', 7, '12689', 'Beginning Band 8 - 2023'),
	(230, 'Eshetu', 'Lukas', 'olga.petryniak@gmail.com', 'kassahun.wossene@gmail.com', 'leshetu27@isk.ac.ke', 10, '12793', NULL),
	(137, 'Hissink', 'Boele', 'saskia@dobequity.nl', 'lodewijkh@gmail.com', 'bhissink31@isk.ac.ke', 6, '11003', NULL),
	(560, 'Holder', 'Isabel', 'nickandstephholder@gmail.com', 'stephiemiddleton@hotmail.com', 'iholder24@isk.ac.ke', 13, '12056', NULL),
	(496, 'Jansson', 'Leo', 'sawanakagawa@gmail.com', 'torjansson@gmail.com', 'ljansson30@isk.ac.ke', 7, '11762', 'Beginning Band 8 - 2023'),
	(981, 'Johnson', 'Adam', 'ameenahbsaleem@gmail.com', 'ibnabu@aol.com', 'ajohnson31@isk.ac.ke', 6, '12327', NULL),
	(686, 'Maasdorp Mogollon', 'Gabriela', 'inamogollon@gmail.com', 'maasdorp@gmail.com', 'gmaasdorpmogollon32@isk.ac.ke', 5, '12821', NULL),
	(475, 'Mcsharry', 'Caspian', 'emmeline@mcsharry.net', 'patrick@mcsharry.net', 'cmcsharry31@isk.ac.ke', 6, '12562', 'Band 8 2024'),
	(731, 'Mkandawire', 'Daniel', 'luyckx.ilke@gmail.com', 'zwangiegasha@gmail.com', 'dmkandawire25@isk.ac.ke', 12, '12272', NULL),
	(51, 'Mohan', 'Arnav', 'divyamohan2000@gmail.com', 'rakmohan1@yahoo.com', 'amohan24@isk.ac.ke', 13, '11925', NULL),
	(906, 'Mutombo', 'Ariel', 'nathaliesindamut@gmail.com', 'mutombok@churchofjesuschrist.org', 'amutombo30@isk.ac.ke', 7, '12549', 'Band 8 2024'),
	(679, 'Ngumi', 'Alvin', 'rsituma@yahoo.com', NULL, 'angumi25@isk.ac.ke', 12, '12588', NULL),
	(231, 'Okanda', 'Dylan', 'indiakk@yahoo.com', 'mbauro@gmail.com', 'dokanda27@isk.ac.ke', 10, '11511', NULL),
	(300, 'Otieno', 'Radek Tidi', 'alividza@isk.ac.ke', 'eotieno@isk.ac.ke', 'radotieno31@isk.ac.ke', 6, '10865', 'Band 8 2024'),
	(347, 'Patel', 'Liam', 'rajul@ramco.co.ke', 'hasit@ramco.co.ke', 'lpatel32@isk.ac.ke', 5, '11486', NULL),
	(254, 'Rogers', 'Rwenzori', 'sorogers@usaid.gov', 'drogers@usaid.gov', 'rrogers32@isk.ac.ke', 5, '12208', NULL),
	(70, 'Russo', 'Leandro', 'samiaabdul@yahoo.com', 'andrearux@yahoo.it', 'lrusso28@isk.ac.ke', 9, '11361', NULL),
	(126, 'Sagar', 'Aarav', 'preeti74472@yahoo.com', 'sagaramit1@gmail.com', 'asagar35@isk.ac.ke', 2, '12248', NULL),
	(549, 'Saleem', 'Nora', 'anna.saleem.hogberg@gov.se', 'saleembaha@gmail.com', 'nsaleem30@isk.ac.ke', 7, '12619', 'Beginning Band 8 - 2023'),
	(369, 'Sangare', 'Moussa', 'taissata@yahoo.fr', 'sangnouh@yahoo.fr', 'msangare30@isk.ac.ke', 7, '12427', 'Beginning Band 8 - 2023'),
	(849, 'Sansculotte', 'Kieu', 'thanhluu77@hotmail.com', 'kwesi.sansculotte@wfp.org', 'ksansculotte24@isk.ac.ke', 13, '12269', NULL),
	(764, 'Segev', 'Amitai', 'noggasegev@gmail.com', 'avivsegev1@gmail.com', 'samitai35@isk.ac.ke', 2, '12721', NULL),
	(523, 'Sekar', 'Akshith', 'rsekar1999@yahoo.com', 'rekhasekar@yahoo.co.in', 'asekar26@isk.ac.ke', 11, '10676', NULL),
	(113, 'Sudra', 'Ellis', 'maryleakeysudra@gmail.com', 'msudra@isk.ac.ke', 'esudra35@isk.ac.ke', 2, '11941', NULL),
	(726, 'Tafesse', 'Ruth Yifru', 'semene1975@gmail.com', 'yifrutaf2006@gmail.com', 'rtafesse25@isk.ac.ke', 12, '13099', NULL),
	(139, 'Tanna', 'Kush', 'vptanna@gmail.com', 'priyentanna@gmail.com', 'ktanna30@isk.ac.ke', 7, '11096', 'Beginning Band 8 - 2023'),
	(884, 'Wietecha', 'Alexander', 'aitkenjennifer@hotmail.com', 'rwietecha@yahoo.com', 'awietecha30@isk.ac.ke', 7, '12725', 'Beginning Band 8 - 2023'),
	(143, 'Yarkoni', 'Matan', 'dvorayarkoni4@gmail.com', 'yarkan1@yahoo.com', 'myarkoni31@isk.ac.ke', 6, '12168', NULL),
	(905, 'Abdosh', 'Hanina', NULL, 'el.abdosh@gmail.com', 'habdosh24@isk.ac.ke', 13, '12737', NULL),
	(32, 'Abraha', 'Seret', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'sabraha24@isk.ac.ke', 13, '12462', NULL),
	(47, 'Andersen', 'Ida-Marie', 'hanneseverin@hotmail.com', 'martin.andersen@eeas.europa.eu', 'iandersen24@isk.ac.ke', 13, '12075', NULL),
	(182, 'Anding', 'Zane', 'ganding@isk.ac.ke', 'manding@isk.ac.ke', 'zanding25@isk.ac.ke', 12, '10968', NULL),
	(71, 'Biafore', 'Ignacio', 'nermil@gmail.com', 'montiforce@gmail.com', 'ibiafore30@isk.ac.ke', 7, '12170', 'Beginning Band 8 - 2023'),
	(708, 'Bomba', 'Sada', 'williams.kristi@gmail.com', 'khalid.bomba@gmail.com', 'sbomba25@isk.ac.ke', 12, '12989', NULL),
	(265, 'Bwonya', 'Leti', 'faith.bwonya@gmail.com', NULL, 'lbwonya24@isk.ac.ke', 13, '12270', NULL),
	(376, 'Chopra', 'Malan', 'tanja.chopra@gmx.de', 'jarat_chopra@me.com', 'mchopra30@isk.ac.ke', 7, '10508', 'Beginning Band 8 - 2023'),
	(48, 'Cole', 'Cheryl', 'colevira@gmail.com', 'acole@unicef.org', 'ccole24@isk.ac.ke', 13, '12497', NULL),
	(10, 'Ellis', 'Adrienne', 'etinsley@worldbank.org', 'pellis@worldbank.org', 'aellis24@isk.ac.ke', 13, '12068', NULL),
	(775, 'Haysmith', 'Romilly', 'stephanie.haysmith@un.org', 'davehaysmith@hotmail.com', 'rhaysmith30@isk.ac.ke', 7, '12976', 'Beginning Band 8 - 2023'),
	(717, 'Ishee', 'Emily', 'vickie.ishee@gmail.com', 'jon.ishee1@gmail.com', 'eishee31@isk.ac.ke', 6, '12836', 'Band 8 2024'),
	(989, 'Hobbs', 'Evyn', 'ywhobbs@yahoo.com', 'hbhobbs95@gmail.com', 'ehobbs30@isk.ac.ke', 7, '12973', 'Beginning Band 1 2023'),
	(990, 'Khalid', 'Zayn', 'aryana.c.khalid@gmail.com', 'waqqas.khalid@gmail.com', 'zkhalid30@isk.ac.ke', 7, '12616', 'Beginning Band 8 - 2023'),
	(518, 'Materne', 'Kiara', 'nat.dekeyser@gmail.com', 'fredmaterne@hotmail.com', 'kmaterne30@isk.ac.ke', 7, '12152', 'Beginning Band 8 - 2023'),
	(588, 'Mensah', 'Selma', 'sabinemensah@gmail.com', 'henrimensah@gmail.com', 'smensah30@isk.ac.ke', 7, '12392', 'Beginning Band 1 2023'),
	(992, 'Meyers', 'Balazs', 'krisztina.meyers@gmail.com', 'jemeyers@usaid.gov', 'bmeyers30@isk.ac.ke', 7, '12621', 'Beginning Band 8 - 2023'),
	(993, 'Mucci', 'Lauren', 'crista.mcinnis@gmail.com', 'warren.mucci@gmail.com', 'lmucci30@isk.ac.ke', 7, '12694', 'Beginning Band 7 2023'),
	(994, 'Mulema', 'Anastasia', 'a.abenakyo@gmail.com', 'jmulema@cabi.org', 'amulema30@isk.ac.ke', 7, '11622', 'Beginning Band 1 2023'),
	(995, 'Muneeb', 'Mahdiyah', 'libra_779@hotmail.com', 'muneeb_bakhshi@hotmail.com', 'mmuneeb30@isk.ac.ke', 7, '12761', 'Beginning Band 8 - 2023'),
	(996, 'Nam', 'Seung Hyun', 'hope7993@qq.com', 'sknam@mofa.go.kr', 'shyun-nam30@isk.ac.ke', 7, '13080', 'Beginning Band 7 2023'),
	(456, 'O''Neill Calver', 'Rowan', 'laraoneill@gmail.com', 'timcalver@gmail.com', 'roneillcalver30@isk.ac.ke', 7, '11458', 'Beginning Band 1 2023'),
	(572, 'Stephens', 'Kaisei', 'mwatanabe1@worldbank.org', 'mstephens@worldbank.org', 'kstephens30@isk.ac.ke', 7, '11804', 'Beginning Band 8 - 2023'),
	(339, 'Vestergaard', 'Lilla', 'psarasas@gmail.com', 'o.vestergaard@gmail.com', 'svestergaard30@isk.ac.ke', 7, '11266', 'Beginning Band 8 - 2023'),
	(131, 'Wallbridge', 'Samir', 'awallbridge@isk.ac.ke', 'tcwallbridge@gmail.com', 'swallbridge31@isk.ac.ke', 6, '10841', NULL),
	(986, 'Birschbach', 'Mapalo', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'mbirschbach30@isk.ac.ke', 7, '13050', 'Beginning Band 1 2023'),
	(241, 'Chandaria', 'Aarini Vijay', 'preenas@gmail.com', 'vijaychandaria@gmail.com', 'achandaria27@isk.ac.ke', 10, '10338', NULL),
	(988, 'Cherickel', 'Tanay', 'urpmathew@gmail.com', 'cherickel@gmail.com', 'tcherickel30@isk.ac.ke', 7, '13007', 'Beginning Band 7 2023'),
	(105, 'Freiin Von Handel', 'Olivia', 'igiribaldi@hotmail.com', 'thomas.von.handel@gmail.com', 'ofreiinvonhandel30@isk.ac.ke', 7, '12096', 'Beginning Band 8 - 2023') ON CONFLICT DO NOTHING;


--
-- TOC entry 4037 (class 0 OID 31502)
-- Dependencies: 260
-- Data for Name: swap_cases; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.swap_cases (id, created_at, instr_code, item_id_1, item_id_2, created_by) VALUES
	(20, '2024-06-25', 'DMMO', 4209, 4208, 'nochomo'),
	(21, '2024-06-25', 'DMMO', 4209, 4208, 'nochomo'),
	(22, '2024-06-25', 'DMMO', 4209, 4208, 'nochomo'),
	(23, '2024-06-26', 'DMMO', 4209, 4208, 'nochomo'),
	(24, '2024-06-27', 'CL', 1681, 2024, 'nochomo'),
	(25, '2024-06-27', 'CL', 2024, 1681, 'nochomo'),
	(26, '2024-06-27', 'AMK', 1950, 1950, 'nochomo'),
	(27, '2024-06-27', 'CL', 1681, 2024, 'nochomo'),
	(28, '2024-06-27', 'CL', 2024, 1681, 'nochomo'),
	(29, '2024-06-27', 'CL', 1681, 2024, 'nochomo'),
	(30, '2024-06-27', 'AMB', 1978, 1935, 'nochomo'),
	(40, '2024-06-27', 'AMB', 1978, 1935, 'nochomo'),
	(47, '2024-06-27', 'DMMO', 4209, 4208, 'nochomo'),
	(50, '2024-09-10', 'SXT', 1991, 1807, 'nochomo') ON CONFLICT DO NOTHING;


--
-- TOC entry 4039 (class 0 OID 31538)
-- Dependencies: 262
-- Data for Name: take_stock; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.take_stock (id, created_at, location, created_by, item_id, description, number, status, notes) VALUES
	(1, '2024-06-27 15:18:59.5289+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system'),
	(2, '2024-06-27 15:31:17.325573+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system'),
	(3, '2024-06-27 15:31:42.3207+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system'),
	(4, '2024-06-27 15:32:39.483956+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system'),
	(5, '2024-06-27 15:34:22.507847+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system'),
	(6, '2024-06-27 15:35:49.945512+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system'),
	(9, '2024-06-27 15:39:21.113361+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system'),
	(10, '2024-06-27 15:52:46.075297+03', 'INSTRUMENT STORE', 'nochomo', 1926, 'Amplifier, Bass', 5, 'Good', 'Just a check of the system') ON CONFLICT DO NOTHING;


--
-- TOC entry 4018 (class 0 OID 30926)
-- Dependencies: 238
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.users (id, first_name, last_name, email, role, room, grade_level, number, division) VALUES
	(689, 'Emilie', 'Abbonizio', 'eabbonizio25@isk.ac.ke', 'STUDENT', NULL, 12, '13016', 'HS'),
	(504, 'Emir', 'Abdellahi', 'eabdellahi25@isk.ac.ke', 'STUDENT', NULL, 12, '11605', 'HS'),
	(4, 'Dawit', 'Abdissa', 'dabdissa28@isk.ac.ke', 'STUDENT', NULL, 9, '13077', 'HS'),
	(844, 'Hanina', 'Abdosh', 'habdosh24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12737', 'Alumni'),
	(645, 'Elrad', 'Abdurazakov', 'eabdurazakov30@isk.ac.ke', 'STUDENT', NULL, 7, '12690', 'MS'),
	(30, 'Youssef', 'Abou Hamda', 'yabouhamda25@isk.ac.ke', 'STUDENT', NULL, 12, '12778', 'HS'),
	(29, 'Samer', 'Abou Hamda', 'sabouhamda28@isk.ac.ke', 'STUDENT', NULL, 9, '12779', 'HS'),
	(16, 'Risty', 'Abraha', 'rabraha27@isk.ac.ke', 'STUDENT', NULL, 10, '12463', 'HS'),
	(751, 'Aristophanes', 'Abreu', 'abreu36@isk.ac.ke', 'STUDENT', NULL, 1, '12895', 'ES'),
	(752, 'Herson Alexandros', 'Abreu', 'halexandrosabreu35@isk.ac.ke', 'STUDENT', NULL, 2, '12896', 'ES'),
	(535, 'Marian', 'Abukari', 'mabukari29@isk.ac.ke', 'STUDENT', NULL, 8, '10602', 'MS'),
	(554, 'Anshi', 'Acharya', 'aacharya29@isk.ac.ke', 'STUDENT', NULL, 8, '12881', 'MS'),
	(1038, 'Filip', 'Adamec', 'fadamec26@isk.ac.ke', 'STUDENT', NULL, 11, '12904', 'HS'),
	(220, 'Osman', 'Ahmed', 'oahmed24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11745', 'Alumni'),
	(773, 'Darian', 'Ajidahun', 'dajidahun34@isk.ac.ke', 'STUDENT', NULL, 3, '12805', 'ES'),
	(73, 'Leul', 'Alemu', 'lalemu31@isk.ac.ke', 'STUDENT', NULL, 6, '13004', 'MS'),
	(309, 'Kian', 'Allport', 'kallport24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11445', 'Alumni'),
	(407, 'Fatima', 'Alnaqbi', 'falnaqbi27@isk.ac.ke', 'STUDENT', NULL, 10, '12907', 'HS'),
	(406, 'Almayasa', 'Alnaqbi', 'alnaqbi29@isk.ac.ke', 'STUDENT', NULL, 8, '12908', 'MS'),
	(31, 'Ida-Marie', 'Andersen', 'iandersen24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12075', 'Alumni'),
	(1039, 'Solveig', 'Andersen', 'sandersen26@isk.ac.ke', 'STUDENT', NULL, 11, '12569', 'HS'),
	(896, 'Signe', 'Andersen', 'sandersen33@isk.ac.ke', 'STUDENT', NULL, 4, '12570', 'ES'),
	(6, 'Yohanna Wondim Belachew', 'Andersen', 'ywondimandersen35@isk.ac.ke', 'STUDENT', NULL, 2, '12966', 'ES'),
	(105, 'TéA', 'Andries-Munshi', 'tandries-munshi36@isk.ac.ke', 'STUDENT', NULL, 1, '12798', 'ES'),
	(515, 'Sebastian', 'Ansorg', 'sansorg29@isk.ac.ke', 'STUDENT', NULL, 8, '12656', 'MS'),
	(810, 'Harshaan', 'Arora', 'harora28@isk.ac.ke', 'STUDENT', NULL, 9, '13010', 'HS'),
	(400, 'Aaron', 'Atamuradov', 'aatamuradov31@isk.ac.ke', 'STUDENT', NULL, 6, '11800', 'MS'),
	(561, 'Lynn Htet', 'Aung', 'laung31@isk.ac.ke', 'STUDENT', NULL, 6, '12293', 'MS'),
	(1002, 'Mitchell', 'Bagenda', 'mbagenda29@isk.ac.ke', 'STUDENT', NULL, 8, '12146', 'MS'),
	(281, 'Bruke', 'Baheta', 'bbaheta28@isk.ac.ke', 'STUDENT', NULL, 9, '10800', 'HS'),
	(378, 'Daria', 'Baig-Giannotti', 'dbaiggiannotti32@isk.ac.ke', 'STUDENT', NULL, 5, '11593', 'ES'),
	(906, 'Kira', 'Bailey', 'kbailey32@isk.ac.ke', 'STUDENT', NULL, 5, '12289', 'ES'),
	(303, 'Cecile', 'Bamlango', 'cbamlango25@isk.ac.ke', 'STUDENT', NULL, 12, '10979', 'HS'),
	(588, 'Sienna', 'Barragan Sofrony', 'sbarragansofrony36@isk.ac.ke', 'STUDENT', NULL, 1, '12831', 'ES'),
	(1015, 'Fanny', 'Bergqvist', 'fbergqvist28@isk.ac.ke', 'STUDENT', NULL, 9, '12912', 'HS'),
	(797, 'LéA', 'Berthellier-Antoine', 'leaberthellier35@isk.ac.ke', 'STUDENT', NULL, 2, '12794', 'ES'),
	(322, 'Kiara', 'Bhandari', 'kbhandari27@isk.ac.ke', 'STUDENT', NULL, 10, '10791', 'HS'),
	(145, 'Maria-Antonina (Jay)', 'Biesiada', 'mbiesiada26@isk.ac.ke', 'STUDENT', NULL, 11, '11723', 'HS'),
	(872, 'Mubanga', 'Birschbach', 'mbirschbach36@isk.ac.ke', 'STUDENT', NULL, 1, '13052', 'ES'),
	(1025, 'Natasha', 'Birschbach', 'nbirschbach27@isk.ac.ke', 'STUDENT', NULL, 10, '13058', 'HS'),
	(333, 'Sharmila Devi', 'Bommadevara', 'sbommadevera24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10505', 'Alumni'),
	(919, 'Disa', 'Borg Aidnell', 'dborgaidnell31@isk.ac.ke', 'STUDENT', NULL, 6, '12696', 'MS'),
	(517, 'Pilar', 'Bosch', 'pbosch36@isk.ac.ke', 'STUDENT', NULL, 1, '12217', 'ES'),
	(519, 'Blanca', 'Bosch', 'bbosch32@isk.ac.ke', 'STUDENT', NULL, 5, '12219', 'ES'),
	(791, 'Felix', 'Braun', 'fbraun28@isk.ac.ke', 'STUDENT', NULL, 9, '13095', 'HS'),
	(971, 'Sultan', 'Buksh', 'sbuksh28@isk.ac.ke', 'STUDENT', NULL, 9, '11996', 'HS'),
	(821, 'Jaidyn', 'Bunch', 'jbunch25@isk.ac.ke', 'STUDENT', NULL, 12, '12508', 'HS'),
	(197, 'Ryan', 'Burns', 'rburns24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11199', 'Alumni'),
	(841, 'Rose', 'Cameron-Mutyaba', 'rcameron-mutyaba26@isk.ac.ke', 'STUDENT', NULL, 11, '12635', 'HS'),
	(8, 'Cassandre', 'Camisa', 'ccamisa27@isk.ac.ke', 'STUDENT', NULL, 10, '11881', 'HS'),
	(612, 'Barney', 'Carver Wildig', 'bcarver-wildig29@isk.ac.ke', 'STUDENT', NULL, 8, '12601', 'MS'),
	(385, 'Lea', 'Castel-Wang', 'lcastel-wang26@isk.ac.ke', 'STUDENT', NULL, 11, '12507', 'HS'),
	(183, 'Ariana', 'Choda', 'achoda26@isk.ac.ke', 'STUDENT', NULL, 11, '10973', 'HS'),
	(760, 'Nevzad', 'Chowdhury', 'nchowdhury25@isk.ac.ke', 'STUDENT', NULL, 12, '12868', 'HS'),
	(373, 'Galuh', 'Clark', 'gclark29@isk.ac.ke', 'STUDENT', NULL, 8, '11787', 'MS'),
	(217, 'Mandisa', 'Mathew', 'mmathew24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10881', 'Alumni'),
	(315, 'Chansa', 'Mwenya', 'cmwenya24@isk.ac.ke', 'ALUMNUS', NULL, 13, '24018', 'Alumni'),
	(32, 'Cheryl', 'Cole', 'ccole24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12497', 'Alumni'),
	(295, 'Saba', 'Tunbridge', 'stunbridge24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10645', 'Alumni'),
	(249, 'Yasmin', 'Price-Abdi', 'yprice-abdi24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10487', 'Alumni'),
	(252, 'Ryka', 'Shah', 'rshah24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10955', 'Alumni'),
	(260, 'Teresa', 'Sanders', 'tsanders24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10431', 'Alumni'),
	(222, 'Ethan', 'Steel', 'esteel24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11442', 'Alumni'),
	(255, 'Tatyana', 'Wangari', 'twangari24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11877', 'Alumni'),
	(476, 'MaïA', 'Cooney', 'mcooney26@isk.ac.ke', 'STUDENT', NULL, 11, '12110', 'HS'),
	(909, 'Sonia', 'Corbin', 'scorbin32@isk.ac.ke', 'STUDENT', NULL, 5, '12942', 'ES'),
	(802, 'Emily', 'Croucher', 'ecroucher31@isk.ac.ke', 'STUDENT', NULL, 6, '12873', 'MS'),
	(356, 'Anaiya', 'Shah', 'ashah30@isk.ac.ke', 'STUDENT', NULL, 7, '11264', 'MS'),
	(357, 'Lilyrose', 'Trottier', 'ltrottier30@isk.ac.ke', 'STUDENT', NULL, 7, '11944', 'MS'),
	(358, 'Lorian', 'Inglis', 'linglis30@isk.ac.ke', 'STUDENT', NULL, 7, '12133', 'MS'),
	(422, 'Aiden', 'Gremley', 'agremley29@isk.ac.ke', 'STUDENT', NULL, 8, '12393', 'MS'),
	(421, 'Phuc Anh', 'Nguyen', 'pnguyen30@isk.ac.ke', 'STUDENT', NULL, 7, '11260', 'MS'),
	(483, 'Isla', 'Goold', 'igoold28@isk.ac.ke', 'STUDENT', NULL, 9, '11836', 'HS'),
	(482, 'Ansh', 'Mehta', 'amehta29@isk.ac.ke', 'STUDENT', NULL, 8, '10657', 'MS'),
	(538, 'Zecarun', 'Caminha', 'zcaminha30@isk.ac.ke', 'STUDENT', NULL, 7, '12081', 'MS'),
	(539, 'Fatima', 'Zucca', 'fazucca30@isk.ac.ke', 'STUDENT', NULL, 7, '10566', 'MS'),
	(17, 'Seret', 'Abraha', 'sabraha24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12462', 'Alumni'),
	(758, 'Rahmaan', 'Ali', 'rrahim-ali24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12755', 'Alumni'),
	(412, 'Corinne', 'Allen', 'callen24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12307', 'Alumni'),
	(106, 'Zaha', 'Andries-Munshi', 'zandries-munshi33@isk.ac.ke', 'STUDENT', NULL, 4, '12788', 'ES'),
	(923, 'Jip', 'Arens', 'jarens24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12430', 'Alumni'),
	(1061, 'Dzidzor', 'Ata', 'data24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12651', 'Alumni'),
	(1062, 'Nandini', 'Bhandari', 'nbhandari24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12738', 'Alumni'),
	(573, 'Anika', 'Bruhwiler', 'abruhwiler24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12050', 'Alumni'),
	(238, 'Leti', 'Bwonya', 'lbwonya24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12270', 'Alumni'),
	(620, 'Sofia', 'Crandall', 'scrandall24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12990', 'Alumni'),
	(267, 'Leo', 'Cutler', 'lcutler27@isk.ac.ke', 'STUDENT', NULL, 10, '10673', 'HS'),
	(572, 'Maya', 'Davis', 'mdavis24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10953', 'Alumni'),
	(721, 'Alifiya', 'Dawoodbhai', 'adawoodbhai24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12580', 'Alumni'),
	(1063, 'Isabella', 'De Geer-Howard', 'idegeer-howard24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12652', 'Alumni'),
	(264, 'Anay', 'Doshi', 'adoshi28@isk.ac.ke', 'STUDENT', NULL, 9, '10636', 'HS'),
	(921, 'Adrienne', 'Ellis', 'aellis24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12068', 'Alumni'),
	(442, 'Hannah', 'Exel', 'hexel24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12074', 'Alumni'),
	(736, 'Fatoumatta', 'Fatty', 'ffatty24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12735', 'Alumni'),
	(338, 'Zoe', 'Furness', 'zfurness24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11101', 'Alumni'),
	(530, 'Hrushikesh', 'Gandhi', 'hgandhi24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12524', 'Alumni'),
	(310, 'Reid', 'Hagelberg', 'rhagelberg27@isk.ac.ke', 'STUDENT', NULL, 10, '12094', 'HS'),
	(343, 'Louisa', 'Higgins', 'lhiggins24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11743', 'Alumni'),
	(707, 'CréDo Terrence', 'Houndeganme', 'thoundeganme24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12813', 'Alumni'),
	(916, 'Sumaiya', 'Iversen', 'siversen24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12433', 'Alumni'),
	(809, 'Sanaya', 'Jijina', 'sjijina24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12736', 'Alumni'),
	(1064, 'Hanan', 'Khan', 'hkhan24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10464', 'Alumni'),
	(292, 'Layla', 'Khubchandani', 'lkhubchandani27@isk.ac.ke', 'STUDENT', NULL, 10, '11263', 'HS'),
	(756, 'Zahra', 'Kone', 'zkone24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11367', 'Alumni'),
	(507, 'Isabela', 'Kraemer', 'ikraemer24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11907', 'Alumni'),
	(275, 'Mark', 'Landolt', 'mlandolt28@isk.ac.ke', 'STUDENT', NULL, 9, '12284', 'HS'),
	(488, 'Hamish', 'Ledgard', 'hledgard24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12268', 'Alumni'),
	(531, 'Max', 'Leon', 'mleon24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12490', 'Alumni'),
	(39, 'Hana', 'Linck', 'hlinck24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12559', 'Alumni'),
	(86, 'Lucas', 'Lopez Abella', 'llopezabella33@isk.ac.ke', 'STUDENT', NULL, 4, '11759', 'ES'),
	(1066, 'Noah', 'Lutz', 'nlutz24@isk.ac.ke', 'ALUMNUS', NULL, 13, '24008', 'Alumni'),
	(363, 'Che', 'Maldonado', 'cmaldonado24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11170', 'Alumni'),
	(261, 'Sarah', 'Melson', 'smelson27@isk.ac.ke', 'STUDENT', NULL, 10, '12132', 'HS'),
	(416, 'Amishi', 'Mishra', 'ammishra24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12489', 'Alumni'),
	(35, 'Arnav', 'Mohan', 'amohan24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11925', 'Alumni'),
	(420, 'Lise', 'Norman', 'lnorman24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11533', 'Alumni'),
	(480, 'Kai', 'O''Bra', 'kobra30@isk.ac.ke', 'STUDENT', NULL, 7, '12342', 'MS'),
	(481, 'Luke', 'O''Hara', 'lohara30@isk.ac.ke', 'STUDENT', NULL, 7, '12063', 'MS'),
	(272, 'Ranam Telu', 'Otieno', 'ranotieno31@isk.ac.ke', 'STUDENT', NULL, 6, '10943', 'MS'),
	(304, 'Vanaaya', 'Patel', 'vpatel27@isk.ac.ke', 'STUDENT', NULL, 10, '20839', 'HS'),
	(305, 'Veer', 'Patel', 'veerpatel27@isk.ac.ke', 'STUDENT', NULL, 10, '20840', 'HS'),
	(319, 'Yash', 'Pattni', 'ypattni29@isk.ac.ke', 'STUDENT', NULL, 8, '10334', 'MS'),
	(447, 'Sofia', 'Peck', 'speck24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11892', 'Alumni'),
	(367, 'Gabriel', 'Petrangeli', 'gpetrangeli24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11009', 'Alumni'),
	(1067, 'Julian', 'Rex', 'jrex24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10922', 'Alumni'),
	(794, 'Kieu', 'Sansculotte', 'ksansculotte24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12269', 'Alumni'),
	(1068, 'Luca', 'Scanlon', 'lscanlon24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12557', 'Alumni'),
	(374, 'Miriam', 'Schwabel', 'mschwabel24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12267', 'Alumni'),
	(256, 'Sohan', 'Shah', 'sshah24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11190', 'Alumni'),
	(1069, 'Noah', 'Trenkle', 'ntrenkle24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12556', 'Alumni'),
	(452, 'Grecy', 'Van Der Vliet', 'gvandervliet24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11629', 'Alumni'),
	(443, 'Sumedh Vedya', 'Vutukuru', 'svutukuru24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11569', 'Alumni'),
	(122, 'Ohad', 'Yarkoni', 'oyarkoni33@isk.ac.ke', 'STUDENT', NULL, 4, '12167', 'ES'),
	(97, 'Geonu', 'Yun', 'gyun33@isk.ac.ke', 'STUDENT', NULL, 4, '12487', 'ES'),
	(411, 'Tobin', 'Allen', 'tallen27@isk.ac.ke', 'STUDENT', NULL, 10, '12308', 'HS'),
	(408, 'Ibrahim', 'Alnaqbi', 'ialnaqbi26@isk.ac.ke', 'STUDENT', NULL, 11, '12906', 'HS'),
	(405, 'Ali', 'Alnaqbi', 'aalnaqbi34@isk.ac.ke', 'STUDENT', NULL, 3, '12910', 'ES'),
	(10, 'Kennedy', 'Armstrong', 'karmstrong25@isk.ac.ke', 'STUDENT', NULL, 12, '12276', 'HS'),
	(331, 'Avish', 'Arora', 'aarora27@isk.ac.ke', 'STUDENT', NULL, 10, '12129', 'HS'),
	(20, 'Vera', 'Ashton', 'vashton25@isk.ac.ke', 'STUDENT', NULL, 12, '11896', 'HS'),
	(401, 'Arina', 'Atamuradova', 'aatamuradova25@isk.ac.ke', 'STUDENT', NULL, 12, '11752', 'HS'),
	(377, 'Danial', 'Baig-Giannotti', 'dbaig-giannotti35@isk.ac.ke', 'STUDENT', NULL, 2, '12546', 'ES'),
	(23, 'Ziv', 'Bedein', 'zbedein36@isk.ac.ke', 'STUDENT', NULL, 1, '12746', 'ES'),
	(341, 'Maxym', 'Berezhny', 'mberezhny27@isk.ac.ke', 'STUDENT', NULL, 10, '10878', 'HS'),
	(224, 'Sohum', 'Bid', 'sbid36@isk.ac.ke', 'STUDENT', NULL, 1, '13042', 'ES'),
	(332, 'Saptha Girish', 'Bommadevara', 'gbommadevara26@isk.ac.ke', 'STUDENT', NULL, 11, '10504', 'HS'),
	(33, 'Oria', 'Bunbury', 'obunbury36@isk.ac.ke', 'STUDENT', NULL, 1, '12247', 'ES'),
	(436, 'Nyasha', 'Chigudu', 'nchigudu25@isk.ac.ke', 'STUDENT', NULL, 12, '11373', 'HS'),
	(372, 'Laras', 'Clark', 'lclark33@isk.ac.ke', 'STUDENT', NULL, 4, '11786', 'ES'),
	(266, 'Otis', 'Cutler', 'ocutler32@isk.ac.ke', 'STUDENT', NULL, 5, '11535', 'ES'),
	(263, 'Ashi', 'Doshi', 'adoshi32@isk.ac.ke', 'STUDENT', NULL, 5, '11768', 'ES'),
	(438, 'Ines Clelia', 'Essoungou', 'iessoungou26@isk.ac.ke', 'STUDENT', NULL, 11, '12522', 'HS'),
	(399, 'Porter', 'Gerba', 'pgerba25@isk.ac.ke', 'STUDENT', NULL, 12, '11449', 'HS'),
	(398, 'Madigan', 'Gerba', 'mgerba27@isk.ac.ke', 'STUDENT', NULL, 10, '11507', 'HS'),
	(375, 'Ben', 'Gremley', 'bgremley26@isk.ac.ke', 'STUDENT', NULL, 11, '12113', 'HS'),
	(342, 'Thomas', 'Higgins', 'thiggins26@isk.ac.ke', 'STUDENT', NULL, 11, '11744', 'HS'),
	(430, 'Lisa', 'Huber', 'lhuber27@isk.ac.ke', 'STUDENT', NULL, 10, '12339', 'HS'),
	(431, 'Jara', 'Huber', 'jhuber26@isk.ac.ke', 'STUDENT', NULL, 11, '12340', 'HS'),
	(409, 'Rasmus', 'Jabbour', 'rjabbour35@isk.ac.ke', 'STUDENT', NULL, 2, '12396', 'ES'),
	(379, 'Ciara', 'Jackson', 'cjackson25@isk.ac.ke', 'STUDENT', NULL, 12, '12071', 'HS'),
	(349, 'Amina', 'Jama', 'ajama32@isk.ac.ke', 'STUDENT', NULL, 5, '11675', 'ES'),
	(199, 'Ari', 'Jama', 'ajama33@isk.ac.ke', 'STUDENT', NULL, 4, '12452', 'ES'),
	(350, 'Guled', 'Jama', 'gjama30@isk.ac.ke', 'STUDENT', NULL, 7, '12757', 'MS'),
	(328, 'Cuyuni', 'Khan', 'ckhan26@isk.ac.ke', 'STUDENT', NULL, 11, '12013', 'HS'),
	(312, 'Juju', 'Kimmelman-May', 'jkimmelman-may32@isk.ac.ke', 'STUDENT', NULL, 5, '12354', 'ES'),
	(362, 'Mira', 'Maldonado', 'mmaldonado26@isk.ac.ke', 'STUDENT', NULL, 11, '11175', 'HS'),
	(208, 'Georges', 'Marin Fonseca Choucair Ramos', 'gfonsecaramos33@isk.ac.ke', 'STUDENT', NULL, 4, '12789', 'ES'),
	(426, 'James', 'Mills', 'jmills25@isk.ac.ke', 'STUDENT', NULL, 12, '12376', 'HS'),
	(323, 'Safa', 'Monadjem', 'smonadjem33@isk.ac.ke', 'STUDENT', NULL, 4, '12224', 'ES'),
	(324, 'Malaika', 'Monadjem', 'mmonadjem25@isk.ac.ke', 'STUDENT', NULL, 12, '25076', 'HS'),
	(381, 'Caroline', 'Nelson', 'cnelson32@isk.ac.ke', 'STUDENT', NULL, 5, '12803', 'ES'),
	(364, 'Phuong An', 'Nguyen', 'pnguyen32@isk.ac.ke', 'STUDENT', NULL, 5, '11261', 'ES'),
	(278, 'Ahmad Eissa', 'Noordin', 'anoordin32@isk.ac.ke', 'STUDENT', NULL, 5, '11611', 'ES'),
	(388, 'Dana', 'Nurshaikhova', 'dnurshaikhova27@isk.ac.ke', 'STUDENT', NULL, 10, '11938', 'HS'),
	(270, 'Zuriel', 'Nzioka', 'znzioka32@isk.ac.ke', 'STUDENT', NULL, 5, '11313', 'ES'),
	(394, 'Omer', 'Osman', 'oosman35@isk.ac.ke', 'STUDENT', NULL, 2, '12443', 'ES'),
	(273, 'Riani Tunu', 'Otieno', 'riaotieno31@isk.ac.ke', 'STUDENT', NULL, 6, '10866', 'MS'),
	(885, 'Yash', 'Pant', 'ypant35@isk.ac.ke', 'STUDENT', NULL, 2, '12480', 'ES'),
	(286, 'Ishaan', 'Patel', 'ipatel32@isk.ac.ke', 'STUDENT', NULL, 5, '11255', 'ES'),
	(886, 'Amandla', 'Pijovic', 'apijovic35@isk.ac.ke', 'STUDENT', NULL, 2, '13090', 'ES'),
	(346, 'Takumi', 'Plunkett', 'tplunkett28@isk.ac.ke', 'STUDENT', NULL, 9, '12854', 'HS'),
	(351, 'Noha', 'Salituri', 'nsalituri35@isk.ac.ke', 'STUDENT', NULL, 2, '12211', 'ES'),
	(352, 'Amaia', 'Salituri', 'asalituri32@isk.ac.ke', 'STUDENT', NULL, 5, '12212', 'ES'),
	(353, 'Leone', 'Salituri', 'lsalituri32@isk.ac.ke', 'STUDENT', NULL, 5, '12213', 'ES'),
	(321, 'Siddharth', 'Samani', 'ssamani31@isk.ac.ke', 'STUDENT', NULL, 6, '11180', 'MS'),
	(334, 'Adama', 'Sangare', 'asangare25@isk.ac.ke', 'STUDENT', NULL, 12, '12309', 'HS'),
	(393, 'Ethan', 'Sengendo', 'esengendo26@isk.ac.ke', 'STUDENT', NULL, 11, '11702', 'HS'),
	(327, 'Vishnu', 'Shah', 'vshah26@isk.ac.ke', 'STUDENT', NULL, 11, '10796', 'HS'),
	(306, 'Laina', 'Shah', 'lshah32@isk.ac.ke', 'STUDENT', NULL, 5, '11502', 'ES'),
	(365, 'Charlotte', 'Smith', 'csmith32@isk.ac.ke', 'STUDENT', NULL, 5, '12705', 'ES'),
	(344, 'Indhira', 'Startup', 'istartup34@isk.ac.ke', 'STUDENT', NULL, 3, '12244', 'ES'),
	(354, 'Sorawit (Nico)', 'Thongmod', 'sthongmod31@isk.ac.ke', 'STUDENT', NULL, 6, '12214', 'MS'),
	(335, 'Gabrielle', 'Trottier', 'gtrottier27@isk.ac.ke', 'STUDENT', NULL, 10, '11945', 'HS'),
	(339, 'Tandin', 'Tshomo', 'ttshomo29@isk.ac.ke', 'STUDENT', NULL, 8, '12442', 'MS'),
	(284, 'Rose', 'Vellenga', 'rvellenga32@isk.ac.ke', 'STUDENT', NULL, 5, '11574', 'ES'),
	(370, 'Florencia', 'Veveiros', 'fveveiros31@isk.ac.ke', 'STUDENT', NULL, 6, '12008', 'MS'),
	(382, 'Tamara', 'Wanyoike', 'twanyoike25@isk.ac.ke', 'STUDENT', NULL, 12, '12658', 'HS'),
	(424, 'Sebastian', 'Wikenczy Thomsen', 'swikenczy-thomsen25@isk.ac.ke', 'STUDENT', NULL, 12, '11446', 'HS'),
	(403, 'Seohyeon', 'Yoon', 'syoon27@isk.ac.ke', 'STUDENT', NULL, 10, '12791', 'HS'),
	(340, 'Thuji', 'Zangmo', 'tzangmo28@isk.ac.ke', 'STUDENT', NULL, 9, '12394', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO public.users (id, first_name, last_name, email, role, room, grade_level, number, division) VALUES
	(44, 'Dylan', 'Zhang', 'dzhang35@isk.ac.ke', 'STUDENT', NULL, 2, '12206', 'ES'),
	(5, 'Meron', 'Abdissa', 'mabdissa28@isk.ac.ke', 'STUDENT', NULL, 9, '13078', 'HS'),
	(15, 'Siyam', 'Abraha', 'sabraha28@isk.ac.ke', 'STUDENT', NULL, 9, '12464', 'HS'),
	(553, 'Ella', 'Acharya', 'eacharya35@isk.ac.ke', 'STUDENT', NULL, 2, '12882', 'ES'),
	(7, 'Yonas Wondim Belachew', 'Andersen', 'ywondim-andersen26@isk.ac.ke', 'STUDENT', NULL, 11, '12968', 'HS'),
	(19, 'Theodore', 'Ashton', 'tashton27@isk.ac.ke', 'STUDENT', NULL, 10, '11893', 'HS'),
	(508, 'Eva', 'Bannikau', 'ebannikau32@isk.ac.ke', 'STUDENT', NULL, 5, '11780', 'ES'),
	(414, 'Ella', 'Ben Anat', 'ebenanat31@isk.ac.ke', 'STUDENT', NULL, 6, '11475', 'MS'),
	(415, 'Shira', 'Ben Anat', 'sbenanat28@isk.ac.ke', 'STUDENT', NULL, 9, '11518', 'HS'),
	(392, 'Nicholas', 'Burmester', 'nburmester28@isk.ac.ke', 'STUDENT', NULL, 9, '11394', 'HS'),
	(391, 'Malou', 'Burmester', 'mburmester31@isk.ac.ke', 'STUDENT', NULL, 6, '11395', 'MS'),
	(434, 'Komborero', 'Chigudu', 'kchigudu31@isk.ac.ke', 'STUDENT', NULL, 6, '11375', 'MS'),
	(435, 'Munashe', 'Chigudu', 'mchigudu28@isk.ac.ke', 'STUDENT', NULL, 9, '11376', 'HS'),
	(461, 'Minseo', 'Choi', 'mchoi32@isk.ac.ke', 'STUDENT', NULL, 5, '11145', 'ES'),
	(475, 'Luna', 'Cooney', 'lcooney33@isk.ac.ke', 'STUDENT', NULL, 4, '12111', 'ES'),
	(383, 'Marcella', 'Cowan', 'mcowan28@isk.ac.ke', 'STUDENT', NULL, 9, '12437', 'HS'),
	(478, 'Ameya', 'Dale', 'adale25@isk.ac.ke', 'STUDENT', NULL, 12, '10495', 'HS'),
	(501, 'Lorenzo', 'De Vries Aguirre', 'ldevriesaguirre27@isk.ac.ke', 'STUDENT', NULL, 10, '11552', 'HS'),
	(474, 'Christopher Ross', 'Donohue', 'cdonohue29@isk.ac.ke', 'STUDENT', NULL, 8, '10333', 'MS'),
	(486, 'Laé', 'Firzé Al Ghaoui', 'lfirzealghaoui31@isk.ac.ke', 'STUDENT', NULL, 6, '12191', 'MS'),
	(454, 'Rohan', 'Giri', 'rgiri26@isk.ac.ke', 'STUDENT', NULL, 11, '12410', 'HS'),
	(453, 'Maila', 'Giri', 'mgiri33@isk.ac.ke', 'STUDENT', NULL, 4, '12421', 'ES'),
	(427, 'Amira', 'Goold', 'agoold31@isk.ac.ke', 'STUDENT', NULL, 6, '11820', 'MS'),
	(460, 'Marius', 'Hansen', 'mhansen30@isk.ac.ke', 'STUDENT', NULL, 7, '12365', 'MS'),
	(555, 'Clara', 'Hardy', 'chardy35@isk.ac.ke', 'STUDENT', NULL, 2, '12722', 'ES'),
	(479, 'Arthur', 'Hire', 'ahire32@isk.ac.ke', 'STUDENT', NULL, 5, '11232', 'ES'),
	(494, 'Troy', 'Hopps', 'thopps33@isk.ac.ke', 'STUDENT', NULL, 4, '12306', 'ES'),
	(429, 'Siri', 'Huber', 'shuber31@isk.ac.ke', 'STUDENT', NULL, 6, '12338', 'MS'),
	(410, 'Olivia', 'Jabbour', 'ojabbour32@isk.ac.ke', 'STUDENT', NULL, 5, '12395', 'ES'),
	(458, 'Kai', 'Jansson', 'kjansson33@isk.ac.ke', 'STUDENT', NULL, 4, '11761', 'ES'),
	(466, 'Azzalina', 'Johnson', 'ajohnson26@isk.ac.ke', 'STUDENT', NULL, 11, '12865', 'HS'),
	(464, 'Catherine', 'Johnson', 'cjohnson35@isk.ac.ke', 'STUDENT', NULL, 2, '12867', 'ES'),
	(548, 'Dov', 'Jones-Avni', 'djones-avni34@isk.ac.ke', 'STUDENT', NULL, 3, '12784', 'ES'),
	(455, 'Ao', 'Kasahara', 'akasahara36@isk.ac.ke', 'STUDENT', NULL, 1, '13041', 'ES'),
	(457, 'Charlotte', 'Laurits', 'claurits33@isk.ac.ke', 'STUDENT', NULL, 4, '12249', 'ES'),
	(456, 'Leonard', 'Laurits', 'llaurits35@isk.ac.ke', 'STUDENT', NULL, 2, '12250', 'ES'),
	(41, 'Mimer', 'Lindvig', 'mlindvig26@isk.ac.ke', 'STUDENT', NULL, 11, '12503', 'HS'),
	(485, 'Elsa', 'Lloyd', 'elloyd29@isk.ac.ke', 'STUDENT', NULL, 8, '11464', 'MS'),
	(444, 'Nyasha', 'Mabaso', 'nmabaso31@isk.ac.ke', 'STUDENT', NULL, 6, '11657', 'MS'),
	(477, 'Danaé', 'Materne', 'dmaterne27@isk.ac.ke', 'STUDENT', NULL, 10, '12154', 'HS'),
	(471, 'Naledi', 'Mazibuko', 'nmazibuko26@isk.ac.ke', 'STUDENT', NULL, 11, '12573', 'HS'),
	(470, 'Maxwell', 'Mazibuko', 'mmazibuko26@isk.ac.ke', 'STUDENT', NULL, 11, '12574', 'HS'),
	(450, 'Nandipha', 'Murape', 'nmurape25@isk.ac.ke', 'STUDENT', NULL, 12, '11700', 'HS'),
	(57, 'Eunice', 'Murathi', 'emurathi25@isk.ac.ke', 'STUDENT', NULL, 12, '11736', 'HS'),
	(497, 'Sadie', 'Njenga', 'snjenga31@isk.ac.ke', 'STUDENT', NULL, 6, '12279', 'MS'),
	(448, 'Elia', 'O''Hara', 'eohara25@isk.ac.ke', 'STUDENT', NULL, 12, '12062', 'HS'),
	(432, 'Case', 'O''Hearn', 'cohearn29@isk.ac.ke', 'STUDENT', NULL, 8, '12764', 'MS'),
	(505, 'Maliah', 'O''Neal', 'moneal28@isk.ac.ke', 'STUDENT', NULL, 9, '11912', 'HS'),
	(614, 'Jooan', 'Park', 'jpark32@isk.ac.ke', 'STUDENT', NULL, 5, '12786', 'ES'),
	(509, 'Alba', 'Prawitz', 'aprawitz34@isk.ac.ke', 'STUDENT', NULL, 3, '12291', 'ES'),
	(468, 'Leila', 'Priestley', 'lpriestley25@isk.ac.ke', 'STUDENT', NULL, 12, '20843', 'HS'),
	(568, 'Henrik', 'Raehalme', 'hraehalme35@isk.ac.ke', 'STUDENT', NULL, 2, '12698', 'ES'),
	(467, 'Aaditya', 'Raja', 'araja26@isk.ac.ke', 'STUDENT', NULL, 11, '12103', 'HS'),
	(473, 'Ananya', 'Raval', 'araval35@isk.ac.ke', 'STUDENT', NULL, 2, '12257', 'ES'),
	(3, 'August', 'Rosen', 'arosen27@isk.ac.ke', 'STUDENT', NULL, 10, '11845', 'HS'),
	(503, 'Adam', 'Saleem', 'asaleem34@isk.ac.ke', 'STUDENT', NULL, 3, '12620', 'ES'),
	(389, 'Raheel', 'Shah', 'rshah28@isk.ac.ke', 'STUDENT', NULL, 9, '12161', 'HS'),
	(490, 'Saif', 'Shahbal', 'sshahbal34@isk.ac.ke', 'STUDENT', NULL, 3, '12712', 'ES'),
	(489, 'Sophia', 'Shahbal', 'sshahbal36@isk.ac.ke', 'STUDENT', NULL, 1, '12742', 'ES'),
	(43, 'Zahra', 'Singh', 'zsingh27@isk.ac.ke', 'STUDENT', NULL, 10, '11505', 'HS'),
	(386, 'Anisha', 'Som Chaudhuri', 'asomchaudhuri32@isk.ac.ke', 'STUDENT', NULL, 5, '12707', 'ES'),
	(463, 'Nathan', 'Tassew', 'ntassew26@isk.ac.ke', 'STUDENT', NULL, 11, '12636', 'HS'),
	(462, 'Abigail', 'Tassew', 'atassew33@isk.ac.ke', 'STUDENT', NULL, 4, '12637', 'ES'),
	(500, 'Maya', 'Thibodeau', 'mthibodeau28@isk.ac.ke', 'STUDENT', NULL, 9, '12357', 'HS'),
	(308, 'Nikolaj', 'Vestergaard', 'nvestergaard33@isk.ac.ke', 'STUDENT', NULL, 4, '11789', 'ES'),
	(402, 'Seojun', 'Yoon', 'syoon29@isk.ac.ke', 'STUDENT', NULL, 8, '12792', 'MS'),
	(446, 'Annie', 'Young', 'ayoung25@isk.ac.ke', 'STUDENT', NULL, 12, '12378', 'HS'),
	(602, 'Naia', 'Friedhoff Jaeschke', 'nfriedhoffjaeschke29@isk.ac.ke', 'STUDENT', NULL, 8, '11822', 'MS'),
	(601, 'Olivia', 'Patel', 'opatel30@isk.ac.ke', 'STUDENT', NULL, 7, '10561', 'MS'),
	(60, 'Elizabeth', 'Gardner', 'egardner29@isk.ac.ke', 'STUDENT', NULL, 8, '11467', 'MS'),
	(61, 'Shai', 'Bedein', 'sbedein29@isk.ac.ke', 'STUDENT', NULL, 8, '12614', 'MS'),
	(59, 'Vilma Doret', 'Rosen', 'vrosen30@isk.ac.ke', 'STUDENT', NULL, 7, '11763', 'MS'),
	(28, 'Lana', 'Abou Hamda', 'labouhamda31@isk.ac.ke', 'STUDENT', NULL, 6, '12780', 'MS'),
	(536, 'Manuela', 'Abukari', 'mabukari27@isk.ac.ke', 'STUDENT', NULL, 10, '10672', 'HS'),
	(516, 'Leon', 'Ansorg', 'lansorg25@isk.ac.ke', 'STUDENT', NULL, 12, '12655', 'HS'),
	(9, 'Cole', 'Armstrong', 'carmstrong29@isk.ac.ke', 'STUDENT', NULL, 8, '12277', 'MS'),
	(564, 'Annabel', 'Asamoah', 'aasamoah25@isk.ac.ke', 'STUDENT', NULL, 12, '10746', 'HS'),
	(18, 'Hugo', 'Ashton', 'hashton30@isk.ac.ke', 'STUDENT', NULL, 7, '11902', 'MS'),
	(589, 'Gael', 'Barragan Sofrony', 'gbarragansofrony33@isk.ac.ke', 'STUDENT', NULL, 4, '12711', 'ES'),
	(523, 'Michael', 'Bierly', 'mbierly28@isk.ac.ke', 'STUDENT', NULL, 9, '12179', 'HS'),
	(542, 'Manali', 'Caminha', 'mcaminha27@isk.ac.ke', 'STUDENT', NULL, 10, '12079', 'HS'),
	(618, 'Rafael', 'Carter', 'rcarter28@isk.ac.ke', 'STUDENT', NULL, 9, '12776', 'HS'),
	(611, 'Charlie', 'Carver Wildig', 'ccarverwildig31@isk.ac.ke', 'STUDENT', NULL, 6, '12602', 'MS'),
	(556, 'Safari', 'Dara', 'sdara32@isk.ac.ke', 'STUDENT', NULL, 5, '11958', 'ES'),
	(566, 'Mia', 'Duwyn', 'mduwyn27@isk.ac.ke', 'STUDENT', NULL, 10, '12086', 'HS'),
	(596, 'Pietro', 'Fundaro', 'pfundaro26@isk.ac.ke', 'STUDENT', NULL, 11, '11329', 'HS'),
	(529, 'Krishna', 'Gandhi', 'kgandhi26@isk.ac.ke', 'STUDENT', NULL, 11, '12525', 'HS'),
	(560, 'Jacob', 'Germain', 'jgermain25@isk.ac.ke', 'STUDENT', NULL, 12, '12259', 'HS'),
	(729, 'Kirk Wise', 'Gitiba', 'kgitiba27@isk.ac.ke', 'STUDENT', NULL, 10, '12817', 'HS'),
	(552, 'Lisa', 'Godden', 'lgodden26@isk.ac.ke', 'STUDENT', NULL, 11, '12478', 'HS'),
	(628, 'Julia', 'Handler', 'jhandler30@isk.ac.ke', 'STUDENT', NULL, 7, '13100', 'MS'),
	(522, 'Sofia', 'Herbst', 'sherbst32@isk.ac.ke', 'STUDENT', NULL, 5, '12230', 'ES'),
	(616, 'Amitai', 'Hercberg', 'ahercberg33@isk.ac.ke', 'STUDENT', NULL, 4, '12680', 'ES'),
	(513, 'Charles', 'Holder', 'cholder25@isk.ac.ke', 'STUDENT', NULL, 12, '12059', 'HS'),
	(512, 'Abigail', 'Holder', 'aholder31@isk.ac.ke', 'STUDENT', NULL, 6, '12060', 'MS'),
	(621, 'Almaira', 'Ihsan', 'aihsan31@isk.ac.ke', 'STUDENT', NULL, 6, '13061', 'MS'),
	(623, 'Zakhrafi', 'Ihsan', 'zihsan25@isk.ac.ke', 'STUDENT', NULL, 12, '13063', 'HS'),
	(578, 'Dechen', 'Jacob', 'djacob29@isk.ac.ke', 'STUDENT', NULL, 8, '12765', 'MS'),
	(590, 'William', 'Jansen', 'wjansen28@isk.ac.ke', 'STUDENT', NULL, 9, '11837', 'HS'),
	(591, 'Matias', 'Jansen', 'mswearingen26@isk.ac.ke', 'STUDENT', NULL, 11, '11855', 'HS'),
	(396, 'Fiona', 'Jensen', 'fjensen33@isk.ac.ke', 'STUDENT', NULL, 4, '12237', 'ES'),
	(549, 'Nahal', 'Jones-Avni', 'njonesavni32@isk.ac.ke', 'STUDENT', NULL, 5, '12783', 'ES'),
	(547, 'Tamar', 'Jones-Avni', 'tjones-avni36@isk.ac.ke', 'STUDENT', NULL, 1, '12897', 'ES'),
	(525, 'Jihong', 'Joo', 'jjoo26@isk.ac.ke', 'STUDENT', NULL, 11, '11686', 'HS'),
	(545, 'Kelsie', 'Karuga', 'kkaruga30@isk.ac.ke', 'STUDENT', NULL, 7, '12162', 'MS'),
	(599, 'Rhea', 'Kimatrai', 'rkimatrai27@isk.ac.ke', 'STUDENT', NULL, 10, '11809', 'HS'),
	(598, 'Nikhil', 'Kimatrai', 'nkimatrai27@isk.ac.ke', 'STUDENT', NULL, 10, '11810', 'HS'),
	(532, 'Myra', 'Korngold', 'mkorngold31@isk.ac.ke', 'STUDENT', NULL, 6, '12775', 'MS'),
	(558, 'Carys', 'Koucheravy', 'ckoucheravy28@isk.ac.ke', 'STUDENT', NULL, 9, '12304', 'HS'),
	(557, 'Moira', 'Koucheravy', 'mkoucheravy32@isk.ac.ke', 'STUDENT', NULL, 5, '12305', 'ES'),
	(13, 'John (Trey)', 'Kuehnle', 'jkuehnle29@isk.ac.ke', 'STUDENT', NULL, 8, '11833', 'MS'),
	(593, 'Laerke', 'Maagaard', 'lmaagaard27@isk.ac.ke', 'STUDENT', NULL, 10, '12826', 'HS'),
	(629, 'Josephine', 'Maguire', 'jmaguire28@isk.ac.ke', 'STUDENT', NULL, 9, '12592', 'HS'),
	(630, 'Theodore', 'Maguire', 'tmaguire26@isk.ac.ke', 'STUDENT', NULL, 11, '12593', 'HS'),
	(50, 'Aya', 'Mathers', 'amathers32@isk.ac.ke', 'STUDENT', NULL, 5, '11793', 'ES'),
	(49, 'Yonathan', 'Mekonnen', 'ymekonnen29@isk.ac.ke', 'STUDENT', NULL, 8, '11015', 'MS'),
	(56, 'Megan', 'Murathi', 'mmurathi29@isk.ac.ke', 'STUDENT', NULL, 8, '11735', 'MS'),
	(586, 'Marion', 'Nitcheu', 'mnitcheu33@isk.ac.ke', 'STUDENT', NULL, 4, '12417', 'ES'),
	(570, 'Asara', 'O''Bra', 'aobra27@isk.ac.ke', 'STUDENT', NULL, 10, '12341', 'HS'),
	(597, 'Jade', 'Onderi', 'jonderi27@isk.ac.ke', 'STUDENT', NULL, 10, '11847', 'HS'),
	(563, 'Ronan', 'Patel', 'rpatel28@isk.ac.ke', 'STUDENT', NULL, 9, '10119', 'HS'),
	(511, 'Leo', 'Prawitz', 'lprawitz30@isk.ac.ke', 'STUDENT', NULL, 7, '12297', 'MS'),
	(26, 'Christiaan', 'Purdy', 'cpurdy31@isk.ac.ke', 'STUDENT', NULL, 6, '12348', 'MS'),
	(27, 'Gunnar', 'Purdy', 'gpurdy28@isk.ac.ke', 'STUDENT', NULL, 9, '12349', 'HS'),
	(569, 'Emilia', 'Raehalme', 'eraehalme31@isk.ac.ke', 'STUDENT', NULL, 6, '12697', 'MS'),
	(36, 'Alexander', 'Roe', 'aroe29@isk.ac.ke', 'STUDENT', NULL, 8, '12188', 'MS'),
	(527, 'Bruno', 'Sottsas', 'bsottsas32@isk.ac.ke', 'STUDENT', NULL, 5, '12358', 'ES'),
	(528, 'Natasha', 'Sottsas', 'nsottsas29@isk.ac.ke', 'STUDENT', NULL, 8, '12359', 'MS'),
	(604, 'Farzin', 'Taneem', 'ftaneem29@isk.ac.ke', 'STUDENT', NULL, 8, '11335', 'MS'),
	(605, 'Umaiza', 'Taneem', 'utaneem28@isk.ac.ke', 'STUDENT', NULL, 9, '11336', 'HS'),
	(581, 'Ousmane', 'Touré', 'otoure31@isk.ac.ke', 'STUDENT', NULL, 6, '12325', 'MS'),
	(577, 'Felyne', 'Walji', 'fwalji33@isk.ac.ke', 'STUDENT', NULL, 4, '12739', 'ES'),
	(576, 'Elise', 'Walji', 'ewalji34@isk.ac.ke', 'STUDENT', NULL, 3, '12740', 'ES'),
	(608, 'Soline', 'Wittmann', 'swittmann26@isk.ac.ke', 'STUDENT', NULL, 11, '12429', 'HS'),
	(662, 'Emiel', 'Ghelani-Decorte', 'eghelani-decorte29@isk.ac.ke', 'STUDENT', NULL, 8, '12674', 'MS'),
	(659, 'Emilie', 'Wittmann', 'ewittmann30@isk.ac.ke', 'STUDENT', NULL, 7, '12428', 'MS'),
	(660, 'Reehan', 'Reza', 'rreza30@isk.ac.ke', 'STUDENT', NULL, 7, '13022', 'MS'),
	(661, 'Noga', 'Hercberg', 'nhercberg30@isk.ac.ke', 'STUDENT', NULL, 7, '12681', 'MS'),
	(663, 'Georgia', 'Dove', 'gdove30@isk.ac.ke', 'STUDENT', NULL, 7, '12922', 'MS'),
	(14, 'Rahsi', 'Abraha', 'rabraha32@isk.ac.ke', 'STUDENT', NULL, 5, '12465', 'ES'),
	(62, 'Or', 'Alemu', 'oalemu36@isk.ac.ke', 'STUDENT', NULL, 1, '13005', 'ES'),
	(619, 'Vihaan', 'Arora', 'varora34@isk.ac.ke', 'STUDENT', NULL, 3, '12242', 'ES'),
	(672, 'Marc-Andri', 'Bachmann', 'mbachmann28@isk.ac.ke', 'STUDENT', NULL, 9, '12604', 'HS'),
	(754, 'Florrie', 'Bailey', 'fbailey25@isk.ac.ke', 'STUDENT', NULL, 12, '12812', 'HS'),
	(24, 'Itai', 'Bedein', 'ibedein32@isk.ac.ke', 'STUDENT', NULL, 5, '12615', 'ES'),
	(692, 'Mathis', 'Bellamy', 'mbellamy36@isk.ac.ke', 'STUDENT', NULL, 1, '12823', 'ES'),
	(518, 'Moira', 'Bosch', 'mbosch34@isk.ac.ke', 'STUDENT', NULL, 3, '12218', 'ES'),
	(635, 'Dallin', 'Daines', 'ddaines34@isk.ac.ke', 'STUDENT', NULL, 3, '13064', 'ES'),
	(636, 'Caleb', 'Daines', 'cdaines32@isk.ac.ke', 'STUDENT', NULL, 5, '13084', 'ES'),
	(648, 'Malcolm', 'Diehl', 'mdiehl35@isk.ac.ke', 'STUDENT', NULL, 2, '12864', 'ES'),
	(82, 'Kieran', 'Echalar', 'kechalar35@isk.ac.ke', 'STUDENT', NULL, 2, '12723', 'ES'),
	(671, 'Sina', 'Fekadeneh', 'sfekadeneh26@isk.ac.ke', 'STUDENT', NULL, 11, '12633', 'HS'),
	(718, 'Hachim', 'Gallagher', 'hgallagher34@isk.ac.ke', 'STUDENT', NULL, 3, '13083', 'ES'),
	(644, 'Kian', 'Ghelani-Decorte', 'kghelani-decorte28@isk.ac.ke', 'STUDENT', NULL, 9, '12673', 'HS'),
	(687, 'Alice', 'Grindell', 'agrindell36@isk.ac.ke', 'STUDENT', NULL, 1, '12900', 'ES'),
	(676, 'Emil', 'Grundberg', 'egrundberg28@isk.ac.ke', 'STUDENT', NULL, 9, '13019', 'HS'),
	(521, 'Kai', 'Herbst', 'kherbst34@isk.ac.ke', 'STUDENT', NULL, 3, '12231', 'ES'),
	(684, 'Aiden', 'Irungu', 'airungu34@isk.ac.ke', 'STUDENT', NULL, 3, '13038', 'ES'),
	(683, 'Liam', 'Irungu', 'lirungu36@isk.ac.ke', 'STUDENT', NULL, 1, '13039', 'ES'),
	(665, 'Samantha', 'Ishee', 'sishee36@isk.ac.ke', 'STUDENT', NULL, 1, '12832', 'ES'),
	(719, 'Kabir', 'Jaffer', 'kjaffer36@isk.ac.ke', 'STUDENT', NULL, 1, '12646', 'ES'),
	(669, 'Arth', 'Jain', 'ajain36@isk.ac.ke', 'STUDENT', NULL, 1, '13088', 'ES'),
	(646, 'Malik', 'Kamara', 'mkamara35@isk.ac.ke', 'STUDENT', NULL, 2, '12724', 'ES'),
	(631, 'Deniza', 'Kasymbekova Tauras', 'dkasymbekova31@isk.ac.ke', 'STUDENT', NULL, 6, '13027', 'MS'),
	(643, 'Ian', 'Kavaleuski', 'ikavaleuski26@isk.ac.ke', 'STUDENT', NULL, 11, '13059', 'HS'),
	(755, 'Adam', 'Kone', 'akone26@isk.ac.ke', 'STUDENT', NULL, 11, '11368', 'HS'),
	(737, 'Saone', 'Kwena', 'skwena26@isk.ac.ke', 'STUDENT', NULL, 11, '12985', 'HS'),
	(571, 'Seonu', 'Lee', 'slee33@isk.ac.ke', 'STUDENT', NULL, 4, '12449', 'ES'),
	(697, 'Nayoon', 'Lee', 'nlee31@isk.ac.ke', 'STUDENT', NULL, 6, '12626', 'MS'),
	(686, 'Feng Milun', 'Li', 'fli29@isk.ac.ke', 'STUDENT', NULL, 8, '13023', 'MS'),
	(741, 'Arielle', 'Limpered', 'alimered34@isk.ac.ke', 'STUDENT', NULL, 3, '12795', 'ES'),
	(38, 'Freja', 'Lindvig', 'flindvig31@isk.ac.ke', 'STUDENT', NULL, 6, '12535', 'MS'),
	(633, 'Lucas', 'Maasdorp Mogollon', 'lmaasdorpmogollon35@isk.ac.ke', 'STUDENT', NULL, 2, '12822', 'ES'),
	(664, 'Nora', 'Mackay', 'nmackay30@isk.ac.ke', 'STUDENT', NULL, 7, '12885', 'MS'),
	(712, 'Karina', 'Maini', 'kmaini26@isk.ac.ke', 'STUDENT', NULL, 11, '12986', 'HS'),
	(739, 'Isabella', 'Mason', 'imason25@isk.ac.ke', 'STUDENT', NULL, 12, '12629', 'HS'),
	(21, 'Nathan', 'Massawe', 'nmassawe32@isk.ac.ke', 'STUDENT', NULL, 5, '11932', 'ES'),
	(637, 'Gabriel', 'Mccown', 'gmccown36@isk.ac.ke', 'STUDENT', NULL, 1, '12833', 'ES'),
	(638, 'Clea', 'Mccown', 'cmccown34@isk.ac.ke', 'STUDENT', NULL, 3, '12837', 'ES'),
	(48, 'Kaleb', 'Mekonnen', 'kmekonnen31@isk.ac.ke', 'STUDENT', NULL, 6, '11185', 'MS'),
	(679, 'Chawanangwa', 'Mkandawire', 'cmkandawire29@isk.ac.ke', 'STUDENT', NULL, 8, '12292', 'MS'),
	(650, 'Emma', 'Mosher', 'emosher33@isk.ac.ke', 'STUDENT', NULL, 4, '12709', 'ES'),
	(607, 'Resegofetse', 'Mothobi', 'rmothobi32@isk.ac.ke', 'STUDENT', NULL, 5, '12807', 'ES'),
	(606, 'Oagile', 'Mothobi', 'omothobi35@isk.ac.ke', 'STUDENT', NULL, 2, '12808', 'ES'),
	(691, 'Magnolia', 'Muttersbaugh', 'mmuttersbaugh33@isk.ac.ke', 'STUDENT', NULL, 4, '13034', 'ES'),
	(690, 'Cassidy', 'Muttersbaugh', 'cmuttersbaugh36@isk.ac.ke', 'STUDENT', NULL, 1, '13035', 'ES'),
	(609, 'Mateo', 'Muziramakenga', 'mmuziramakenga35@isk.ac.ke', 'STUDENT', NULL, 2, '12704', 'ES'),
	(668, 'Ayaan', 'Pabani', 'apabani35@isk.ac.ke', 'STUDENT', NULL, 2, '12256', 'ES'),
	(656, 'Emilin', 'Patterson', 'epatterson33@isk.ac.ke', 'STUDENT', NULL, 4, '12811', 'ES'),
	(641, 'Ruhan', 'Reza', 'rreza29@isk.ac.ke', 'STUDENT', NULL, 8, '13021', 'MS'),
	(702, 'Azza', 'Rollins', 'arollins27@isk.ac.ke', 'STUDENT', NULL, 10, '12982', 'HS'),
	(695, 'Candela', 'Romero', 'cromero28@isk.ac.ke', 'STUDENT', NULL, 9, '12799', 'HS'),
	(743, 'Pranai', 'Shah', 'pshah25@isk.ac.ke', 'STUDENT', NULL, 12, '12987', 'HS'),
	(717, 'Emil', 'Simek', 'esimek25@isk.ac.ke', 'STUDENT', NULL, 12, '13014', 'HS'),
	(746, 'Nichelle', 'Somaia', 'nsomaia35@isk.ac.ke', 'STUDENT', NULL, 2, '12842', 'ES'),
	(639, 'Beckham', 'Stock', 'bstock34@isk.ac.ke', 'STUDENT', NULL, 3, '12916', 'ES'),
	(742, 'Rakeb', 'Teklemichael', 'rteklemichael26@isk.ac.ke', 'STUDENT', NULL, 11, '12412', 'HS'),
	(667, 'Sonya', 'Wagner', 'swangner32@isk.ac.ke', 'STUDENT', NULL, 5, '12892', 'ES'),
	(655, 'Ethan', 'Walls', 'ewalls31@isk.ac.ke', 'STUDENT', NULL, 6, '12474', 'MS'),
	(654, 'Colin', 'Walls', 'cwalls33@isk.ac.ke', 'STUDENT', NULL, 4, '12475', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO public.users (id, first_name, last_name, email, role, room, grade_level, number, division) VALUES
	(698, 'Gaspard', 'Womble', 'gwomble35@isk.ac.ke', 'STUDENT', NULL, 2, '12718', 'ES'),
	(96, 'Jeongu', 'Yun', 'jyun34@isk.ac.ke', 'STUDENT', NULL, 3, '12492', 'ES'),
	(725, 'Dongyoon', 'Lee', 'dlee30@isk.ac.ke', 'STUDENT', NULL, 7, '12627', 'MS'),
	(787, 'Masoud', 'Ibrahim', 'mibrahim30@isk.ac.ke', 'STUDENT', NULL, 7, '13076', 'MS'),
	(788, 'Titu', 'Tulga', 'ttulga30@isk.ac.ke', 'STUDENT', NULL, 7, '12756', 'MS'),
	(786, 'Arabella', 'Hales', NULL, 'STUDENT', NULL, 0, '13105', 'ES'),
	(774, 'Annabelle', 'Ajidahun', 'aajidahun32@isk.ac.ke', 'STUDENT', NULL, 5, '12804', 'ES'),
	(785, 'Naomi', 'Alemayehu', 'nalemayehu32@isk.ac.ke', 'STUDENT', NULL, 5, '13000', 'ES'),
	(849, 'Liri', 'Alemu', 'lalemu33@isk.ac.ke', 'STUDENT', NULL, 4, '12732', 'ES'),
	(790, 'Cradle Terry', 'Alwedo', 'calwedo31@isk.ac.ke', 'STUDENT', NULL, 6, '13026', 'MS'),
	(735, 'Serenae', 'Angima', 'sangima28@isk.ac.ke', 'STUDENT', NULL, 9, '12954', 'HS'),
	(109, 'Oscar', 'Ansell', 'oansell27@isk.ac.ke', 'STUDENT', NULL, 10, '12134', 'HS'),
	(811, 'Tisya', 'Arora', 'tarora26@isk.ac.ke', 'STUDENT', NULL, 11, '13009', 'HS'),
	(701, 'Aabhar', 'Baral', 'abaral31@isk.ac.ke', 'STUDENT', NULL, 6, '13030', 'MS'),
	(795, 'Daniel', 'Berkouwer', 'dberkouwer35@isk.ac.ke', 'STUDENT', NULL, 2, '12496', 'ES'),
	(780, 'Ahmed Jayed', 'Bin Taif', 'abintaif34@isk.ac.ke', 'STUDENT', NULL, 3, '12311', 'ES'),
	(779, 'Ahmed Jabir', 'Bin Taif', 'abintaif36@isk.ac.ke', 'STUDENT', NULL, 1, '12898', 'ES'),
	(784, 'Luna', 'Bonde-Nielsen', 'lbonde-nielsen32@isk.ac.ke', 'STUDENT', NULL, 5, '12891', 'ES'),
	(817, 'Zara', 'Bredin', 'zbredin26@isk.ac.ke', 'STUDENT', NULL, 11, '11851', 'HS'),
	(759, 'Davran', 'Chowdhury', 'dchowdhury31@isk.ac.ke', 'STUDENT', NULL, 6, '13029', 'MS'),
	(793, 'Matthew', 'Crabtree', 'mcrabtree25@isk.ac.ke', 'STUDENT', NULL, 12, '12560', 'HS'),
	(803, 'Oliver', 'Croucher', 'ocroucher29@isk.ac.ke', 'STUDENT', NULL, 8, '12874', 'MS'),
	(804, 'Anabelle', 'Croucher', 'acroucher27@isk.ac.ke', 'STUDENT', NULL, 10, '12875', 'HS'),
	(801, 'Ishbel', 'Croze', 'icroze27@isk.ac.ke', 'STUDENT', NULL, 10, '13062', 'HS'),
	(812, 'Gai', 'Elkana', 'gelkana35@isk.ac.ke', 'STUDENT', NULL, 2, '13001', 'ES'),
	(813, 'Yuval', 'Elkana', 'yelkana33@isk.ac.ke', 'STUDENT', NULL, 4, '13002', 'ES'),
	(814, 'Matan', 'Elkana', 'melkana31@isk.ac.ke', 'STUDENT', NULL, 6, '13003', 'MS'),
	(70, 'Charles', 'Fisher', 'cfisher25@isk.ac.ke', 'STUDENT', NULL, 12, '11415', 'HS'),
	(69, 'Isabella', 'Fisher', 'ifisher27@isk.ac.ke', 'STUDENT', NULL, 10, '11416', 'HS'),
	(730, 'Isaiah', 'Geller', 'igeller27@isk.ac.ke', 'STUDENT', NULL, 10, '12539', 'HS'),
	(728, 'Roy', 'Gitiba', 'rgitiba29@isk.ac.ke', 'STUDENT', NULL, 8, '12818', 'MS'),
	(770, 'Anna Toft', 'Gronborg', 'agronborg36@isk.ac.ke', 'STUDENT', NULL, 1, '12801', 'ES'),
	(111, 'Omar', 'Harris Ii', 'oharrisii25@isk.ac.ke', 'STUDENT', NULL, 12, '12625', 'HS'),
	(777, 'Kaveer Singh', 'Hayer', 'khayer34@isk.ac.ke', 'STUDENT', NULL, 3, '13048', 'ES'),
	(705, 'Nyx Verena', 'Houndeganme', 'nhoundeganme30@isk.ac.ke', 'STUDENT', NULL, 7, '12815', 'MS'),
	(775, 'Saif', 'Hussain', 'sahussain32@isk.ac.ke', 'STUDENT', NULL, 5, '12328', 'ES'),
	(776, 'Taim', 'Hussain', 'thussain36@isk.ac.ke', 'STUDENT', NULL, 1, '12899', 'ES'),
	(720, 'Ayaan', 'Jaffer', 'ajaffer32@isk.ac.ke', 'STUDENT', NULL, 5, '11646', 'ES'),
	(799, 'Lauri', 'Kaseva', 'lkaseva33@isk.ac.ke', 'STUDENT', NULL, 4, '13096', 'ES'),
	(800, 'Layal', 'Khan', 'lkhan34@isk.ac.ke', 'STUDENT', NULL, 3, '12550', 'ES'),
	(789, 'Zari', 'Khan', 'zkhan27@isk.ac.ke', 'STUDENT', NULL, 10, '13087', 'HS'),
	(77, 'Isla', 'Kimani', 'ikimani36@isk.ac.ke', 'STUDENT', NULL, 1, '12397', 'ES'),
	(819, 'Michael', 'Lavack', 'mlavack26@isk.ac.ke', 'STUDENT', NULL, 11, '26015', 'HS'),
	(808, 'David', 'Lee', 'dlee34@isk.ac.ke', 'STUDENT', NULL, 3, '13089', 'ES'),
	(89, 'Albert', 'Miller', 'amiller25@isk.ac.ke', 'STUDENT', NULL, 12, '25051', 'HS'),
	(88, 'Cassius', 'Miller', 'cmiller27@isk.ac.ke', 'STUDENT', NULL, 10, '27007', 'HS'),
	(713, 'Elena', 'Moons', 'emoons29@isk.ac.ke', 'STUDENT', NULL, 8, '12851', 'MS'),
	(763, 'Willem', 'Mueller', 'wmueller27@isk.ac.ke', 'STUDENT', NULL, 10, '12937', 'HS'),
	(762, 'Graham', 'Mueller', 'gmueller29@isk.ac.ke', 'STUDENT', NULL, 8, '12938', 'MS'),
	(815, 'Niccolo', 'Nasidze', 'nnasidze36@isk.ac.ke', 'STUDENT', NULL, 1, '12901', 'ES'),
	(765, 'Libasse', 'Ndoye', 'lndonye28@isk.ac.ke', 'STUDENT', NULL, 9, '13075', 'HS'),
	(126, 'Binh', 'Nguyen', 'bnguyen27@isk.ac.ke', 'STUDENT', NULL, 10, '11671', 'HS'),
	(723, 'Adrian', 'Otieno', 'aotieno29@isk.ac.ke', 'STUDENT', NULL, 8, '12884', 'MS'),
	(642, 'Nandita', 'Sankar', 'nsankar33@isk.ac.ke', 'STUDENT', NULL, 4, '12802', 'ES'),
	(726, 'Nora', 'Schei', 'nschei28@isk.ac.ke', 'STUDENT', NULL, 9, '12582', 'HS'),
	(744, 'Dhiya', 'Shah', 'dshah29@isk.ac.ke', 'STUDENT', NULL, 8, '12541', 'MS'),
	(724, 'Aanya', 'Shah', 'ashah28@isk.ac.ke', 'STUDENT', NULL, 9, '12583', 'HS'),
	(733, 'Jiya', 'Shah', 'jshah28@isk.ac.ke', 'STUDENT', NULL, 9, '12857', 'HS'),
	(771, 'Rocco', 'Sidari', 'rsidari34@isk.ac.ke', 'STUDENT', NULL, 3, '13036', 'ES'),
	(716, 'Alan', 'Simek', 'asimek28@isk.ac.ke', 'STUDENT', NULL, 9, '13015', 'HS'),
	(807, 'Cedrik', 'Skaaraas-Gjoelberg', 'cgjoelberg31@isk.ac.ke', 'STUDENT', NULL, 6, '12846', 'MS'),
	(747, 'Shivail', 'Somaia', 'ssomaia32@isk.ac.ke', 'STUDENT', NULL, 5, '11769', 'ES'),
	(704, 'Monika', 'Srutova', 'msrutova28@isk.ac.ke', 'STUDENT', NULL, 9, '12999', 'HS'),
	(749, 'Nikolas', 'Stiles', 'nstiles31@isk.ac.ke', 'STUDENT', NULL, 6, '11137', 'MS'),
	(76, 'Patrick', 'Stott', 'pstott26@isk.ac.ke', 'STUDENT', NULL, 11, '12521', 'HS'),
	(792, 'Io', 'Verstraete', 'iverstraete26@isk.ac.ke', 'STUDENT', NULL, 11, '12998', 'HS'),
	(823, 'Hannah', 'Waalewijn', 'hwaalewijn29@isk.ac.ke', 'STUDENT', NULL, 8, '12598', 'MS'),
	(767, 'Shuyi (Bella)', 'Wang', 'swang28@isk.ac.ke', 'STUDENT', NULL, 9, '12950', 'HS'),
	(766, 'Yi (Gavin)', 'Wang', 'ywang33@isk.ac.ke', 'STUDENT', NULL, 4, '13020', 'ES'),
	(715, 'Abem', 'Zeynu', 'azeynu29@isk.ac.ke', 'STUDENT', NULL, 8, '12552', 'MS'),
	(714, 'Aymen', 'Zeynu', 'azeynu33@isk.ac.ke', 'STUDENT', NULL, 4, '12809', 'ES'),
	(847, 'Maria', 'Agenorwot', 'magenorwot28@isk.ac.ke', 'STUDENT', NULL, 9, '13018', 'HS'),
	(848, 'Reuben', 'Szuchman', 'rszuchman28@isk.ac.ke', 'STUDENT', NULL, 9, '12667', 'HS'),
	(845, 'Harsha', 'Varun', 'hvarun30@isk.ac.ke', 'STUDENT', NULL, 7, '12683', 'MS'),
	(846, 'Sadie', 'Szuchman', 'sszuchman30@isk.ac.ke', 'STUDENT', NULL, 7, '12668', 'MS'),
	(888, 'Amaya', 'Sarfaraz', NULL, 'STUDENT', NULL, 2, '12608', 'ES'),
	(911, 'Uzima', 'Otieno', 'uotieno29@isk.ac.ke', 'STUDENT', NULL, 8, '13056', 'MS'),
	(924, 'Spencer', 'Schenck', 'sschenck30@isk.ac.ke', 'STUDENT', NULL, 7, '11457', 'MS'),
	(925, 'Isla', 'Willis', 'iwillis30@isk.ac.ke', 'STUDENT', NULL, 7, '12969', 'MS'),
	(926, 'Seya', 'Chandaria', 'schandaria30@isk.ac.ke', 'STUDENT', NULL, 7, '10775', 'MS'),
	(114, 'Maartje', 'Stott', 'mstott30@isk.ac.ke', 'STUDENT', NULL, 7, '12519', 'MS'),
	(115, 'Owen', 'Harris', 'oharris30@isk.ac.ke', 'STUDENT', NULL, 7, '12609', 'MS'),
	(897, 'Holly', 'Asquith', 'hasquith33@isk.ac.ke', 'STUDENT', NULL, 4, '12944', 'ES'),
	(852, 'Michael Omar', 'Assi', 'm-omarassi29@isk.ac.ke', 'STUDENT', NULL, 8, '12917', 'MS'),
	(101, 'Malaika', 'Awori', 'mawori28@isk.ac.ke', 'STUDENT', NULL, 9, '10476', 'HS'),
	(836, 'Gabriella', 'Barbacci', 'gbarbacci26@isk.ac.ke', 'STUDENT', NULL, 11, '12611', 'HS'),
	(835, 'Evangelina', 'Barbacci', 'ebarbacci29@isk.ac.ke', 'STUDENT', NULL, 8, '12612', 'MS'),
	(907, 'Aaryama', 'Bixby', 'abixby32@isk.ac.ke', 'STUDENT', NULL, 5, '12850', 'ES'),
	(917, 'Nike', 'Borg Aidnell', 'nborgaidnell34@isk.ac.ke', 'STUDENT', NULL, 3, '12542', 'ES'),
	(918, 'Siv', 'Borg Aidnell', 'sborgaidnell34@isk.ac.ke', 'STUDENT', NULL, 3, '12543', 'ES'),
	(908, 'Armelle', 'Carlevato', 'acarlevato32@isk.ac.@isk.ac.ke', 'STUDENT', NULL, 5, '12925', 'ES'),
	(98, 'David', 'Carter', 'dcarter28@isk.ac.ke', 'STUDENT', NULL, 9, '11937', 'HS'),
	(869, 'Isaac', 'D''Souza', 'idsouza28@isk.ac.ke', 'STUDENT', NULL, 9, '12501', 'HS'),
	(914, 'Murad', 'Dadashev', 'mdadashev28@isk.ac.ke', 'STUDENT', NULL, 9, '12768', 'HS'),
	(868, 'Emily', 'Ellinger', 'eellinger31@isk.ac.ke', 'STUDENT', NULL, 6, '13102', 'MS'),
	(920, 'Ryan', 'Ellis', 'rellis25@isk.ac.ke', 'STUDENT', NULL, 12, '12070', 'HS'),
	(913, 'Jarius', 'Farraj', 'jfarraj25@isk.ac.ke', 'STUDENT', NULL, 12, '12606', 'HS'),
	(839, 'Farah', 'Ghariani', 'fghariani27@isk.ac.ke', 'STUDENT', NULL, 10, '12662', 'HS'),
	(832, 'Zara', 'Heijstee', 'zheijstee28@isk.ac.ke', 'STUDENT', NULL, 9, '12781', 'HS'),
	(831, 'Leah', 'Heijstee', 'lheijstee33@isk.ac.ke', 'STUDENT', NULL, 4, '12782', 'ES'),
	(113, 'Pomeline', 'Hissink', 'phissink29@isk.ac.ke', 'STUDENT', NULL, 8, '10683', 'MS'),
	(922, 'Emalea', 'Hodge', 'ehodge31@isk.ac.ke', 'STUDENT', NULL, 6, '12192', 'MS'),
	(863, 'Yasmin', 'Huysdens', 'yhuysdens29@isk.ac.ke', 'STUDENT', NULL, 8, '12927', 'MS'),
	(244, 'Aiden', 'Inwani', 'ainwani25@isk.ac.ke', 'STUDENT', NULL, 12, '12531', 'HS'),
	(850, 'Ishanvi', 'Ishanvi', 'iishanvi36@isk.ac.ke', 'STUDENT', NULL, 1, '13053', 'ES'),
	(891, 'Tasheni', 'Kamenga', 'tkamenga34@isk.ac.ke', 'STUDENT', NULL, 3, '12877', 'ES'),
	(881, 'Issa', 'Kane', 'ikane35@isk.ac.ke', 'STUDENT', NULL, 2, '13037', 'ES'),
	(910, 'Zaria', 'Khalid', 'zkhalid32@isk.ac.ke', 'STUDENT', NULL, 5, '12617', 'ES'),
	(866, 'Nabou', 'Khouma', 'nkhouma36@isk.ac.ke', 'STUDENT', NULL, 1, '13046', 'ES'),
	(882, 'Beatrix', 'Kiers', 'bkiers35@isk.ac.ke', 'STUDENT', NULL, 2, '12717', 'ES'),
	(860, 'Daudi', 'Kisukye', 'dkisukye31@isk.ac.ke', 'STUDENT', NULL, 6, '13025', 'MS'),
	(899, 'Levi', 'Lundell', 'llundell33@isk.ac.ke', 'STUDENT', NULL, 4, '12693', 'ES'),
	(876, 'Alexander', 'Magnusson', 'amagnusson36@isk.ac.ke', 'STUDENT', NULL, 1, '12824', 'ES'),
	(843, 'Angab', 'Mayar', 'amayar25@isk.ac.ke', 'STUDENT', NULL, 12, '13057', 'HS'),
	(883, 'Yousif', 'Menkerios', 'ymenkerios35@isk.ac.ke', 'STUDENT', NULL, 2, '12459', 'ES'),
	(829, 'Elisa', 'Mollier-Camus', 'emollier-camus28@isk.ac.ke', 'STUDENT', NULL, 9, '12586', 'HS'),
	(828, 'Victor', 'Mollier-Camus', 'vmollier-camus31@isk.ac.ke', 'STUDENT', NULL, 6, '12594', 'MS'),
	(827, 'Caelan', 'Molloy', 'cmolloy32@isk.ac.ke', 'STUDENT', NULL, 5, '12701', 'ES'),
	(837, 'Santiago', 'Moyle', 'smoyle27@isk.ac.ke', 'STUDENT', NULL, 10, '12581', 'HS'),
	(877, 'Emerson', 'Nau', 'enau36@isk.ac.ke', 'STUDENT', NULL, 1, '12834', 'ES'),
	(892, 'Theodore', 'Patenaude', 'tpatenaude34@isk.ac.ke', 'STUDENT', NULL, 3, '12713', 'ES'),
	(66, 'George', 'Ronzio', 'gronzio29@isk.ac.ke', 'STUDENT', NULL, 8, '12199', 'MS'),
	(865, 'Esther', 'Schonemann', 'eschonemann31@isk.ac.ke', 'STUDENT', NULL, 6, '13028', 'MS'),
	(889, 'Clarice', 'Schrader', 'cschrader35@isk.ac.ke', 'STUDENT', NULL, 2, '12841', 'ES'),
	(93, 'Arav', 'Shah', 'ashah29@isk.ac.ke', 'STUDENT', NULL, 8, '10784', 'MS'),
	(890, 'Mandisa', 'Sobantu', 'msobantu35@isk.ac.ke', 'STUDENT', NULL, 2, '12939', 'ES'),
	(834, 'Leonidas', 'Sotiriou', 'lsotiriou34@isk.ac.ke', 'STUDENT', NULL, 3, '12239', 'ES'),
	(833, 'Graciela', 'Sotiriou', 'gsotiriou36@isk.ac.ke', 'STUDENT', NULL, 1, '12902', 'ES'),
	(120, 'Shreya', 'Tanna', 'stanna28@isk.ac.ke', 'STUDENT', NULL, 9, '10703', 'HS'),
	(830, 'Jaishna', 'Varun', 'jvarun29@isk.ac.ke', 'STUDENT', NULL, 8, '12684', 'MS'),
	(902, 'Martin', 'Vazquez Eraso', 'mvazquezeraso33@isk.ac.ke', 'STUDENT', NULL, 4, '12369', 'ES'),
	(904, 'Nanna', 'Vestergaard', 'navestergaard33@isk.ac.ke', 'STUDENT', NULL, 4, '12665', 'ES'),
	(894, 'Anna', 'Von Platen-Hallermund', 'aplatenhallermund34@isk.ac.ke', 'STUDENT', NULL, 3, '12888', 'ES'),
	(859, 'Rosemary', 'Waugh', 'rwaugh32@isk.ac.ke', 'STUDENT', NULL, 5, '12843', 'ES'),
	(858, 'Josephine', 'Waugh', 'jwaugh35@isk.ac.ke', 'STUDENT', NULL, 2, '12844', 'ES'),
	(905, 'Benjamin', 'Weill', 'bweill33@isk.ac.ke', 'STUDENT', NULL, 4, '12849', 'ES'),
	(825, 'Kaitlin', 'Wietecha', 'kwietecha26@isk.ac.ke', 'STUDENT', NULL, 11, '12591', 'HS'),
	(838, 'Alissa', 'Yakusik', 'ayakusik32@isk.ac.ke', 'STUDENT', NULL, 5, '13082', 'ES'),
	(960, 'Aisha', 'Awori', 'aawori28@isk.ac.ke', 'STUDENT', NULL, 9, '10474', 'HS'),
	(945, 'Eliana', 'Hodge', 'ehodge29@isk.ac.ke', 'STUDENT', NULL, 8, '12193', 'MS'),
	(959, 'Ainsley', 'Hire', 'ahire29@isk.ac.ke', 'STUDENT', NULL, 8, '10621', 'MS'),
	(962, 'Ean', 'Kimuli', 'ekimuli29@isk.ac.ke', 'STUDENT', NULL, 8, '11703', 'MS'),
	(947, 'Anaiya', 'Khubchandani', 'akhubchandani30@isk.ac.ke', 'STUDENT', NULL, 7, '11262', 'MS'),
	(949, 'Edie', 'Cutler', 'ecutler30@isk.ac.ke', 'STUDENT', NULL, 7, '10686', 'MS'),
	(951, 'Finlay', 'Haswell', 'fhaswell30@isk.ac.ke', 'STUDENT', NULL, 7, '10562', 'MS'),
	(952, 'Yonatan Wondim Belachew', 'Andersen', 'ywondimandersen30@isk.ac.ke', 'STUDENT', NULL, 7, '12967', 'MS'),
	(1096, 'Four', 'Test', 'tone@isk.ac.ke', 'STUDENT', NULL, NULL, '11660', NULL),
	(953, 'Yoonseo', 'Choi', 'ychoi30@isk.ac.ke', 'STUDENT', NULL, 7, '10708', 'MS'),
	(1040, 'EugèNe', 'Astier', 'eastier26@isk.ac.ke', 'STUDENT', NULL, 11, '12790', 'HS'),
	(1023, 'Maya', 'Bagenda', 'mbagenda27@isk.ac.ke', 'STUDENT', NULL, 10, '12147', 'HS'),
	(1041, 'Elsa', 'Bergqvist', 'ebergqvist26@isk.ac.ke', 'STUDENT', NULL, 11, '12911', 'HS'),
	(1050, 'Chisanga', 'Birschbach', 'cbirschbach25@isk.ac.ke', 'STUDENT', NULL, 12, '13055', 'HS'),
	(950, 'EugéNie', 'Camisa', 'ecamisa30@isk.ac.ke', 'STUDENT', NULL, 7, '11883', 'MS'),
	(1042, 'Maximilian', 'Chappell', 'mchappell26@isk.ac.ke', 'STUDENT', NULL, 11, '12576', 'HS'),
	(1027, 'Jai', 'Cherickel', 'jcherickel27@isk.ac.ke', 'STUDENT', NULL, 10, '13006', 'HS'),
	(121, 'Samuel', 'Clark', 'sclark32@isk.ac.ke', 'STUDENT', NULL, 5, '13049', 'ES'),
	(944, 'Aiden', 'D''Souza', 'adsouza30@isk.ac.ke', 'STUDENT', NULL, 7, '12500', 'MS'),
	(1028, 'Samarth', 'Dalal', 'sdalal27@isk.ac.ke', 'STUDENT', NULL, 10, '12859', 'HS'),
	(1043, 'Charlotte', 'De Geer-Howard', 'cdegeer-howard26@isk.ac.ke', 'STUDENT', NULL, 11, '12653', 'HS'),
	(153, 'Max', 'De Jong', 'mdejong25@isk.ac.ke', 'STUDENT', NULL, 12, '24001', 'HS'),
	(83, 'Liam', 'Echalar', 'lechalar32@isk.ac.ke', 'STUDENT', NULL, 5, '11882', 'ES'),
	(1029, 'Dan', 'Ephrem Yohannes', 'dephremyohannes27@isk.ac.ke', 'STUDENT', NULL, 10, '11772', 'HS'),
	(187, 'Aika', 'Ernst', 'aernst33@isk.ac.ke', 'STUDENT', NULL, 4, '11628', 'ES'),
	(186, 'Kai', 'Ernst', 'kernst36@isk.ac.ke', 'STUDENT', NULL, 1, '13043', 'ES'),
	(135, 'Kasra', 'Feizzadeh', 'kfeizzadeh27@isk.ac.ke', 'STUDENT', NULL, 10, '12871', 'HS'),
	(134, 'Saba', 'Feizzadeh', 'sfeizzadeh32@isk.ac.ke', 'STUDENT', NULL, 5, '12872', 'ES'),
	(138, 'Chloe', 'Foster', 'cfoster25@isk.ac.ke', 'STUDENT', NULL, 12, '11530', 'HS'),
	(993, 'Alayna', 'Fritts', 'afritts31@isk.ac.ke', 'STUDENT', NULL, 6, '12935', 'MS'),
	(132, 'Benjamin', 'Godfrey', 'bgodfrey31@isk.ac.ke', 'STUDENT', NULL, 6, '11242', 'MS'),
	(143, 'Tyler', 'Good', 'tgood32@isk.ac.ke', 'STUDENT', NULL, 5, '12879', 'ES'),
	(147, 'Kaiam', 'Hajee', 'khajee31@isk.ac.ke', 'STUDENT', NULL, 6, '11520', 'MS'),
	(149, 'Kahara', 'Hajee', 'khajee28@isk.ac.ke', 'STUDENT', NULL, 9, '11541', 'HS'),
	(162, 'Jin', 'Handa', 'kjin26@isk.ac.ke', 'STUDENT', NULL, 11, '10641', 'HS'),
	(1030, 'Rowan', 'Hobbs', 'rhobbs27@isk.ac.ke', 'STUDENT', NULL, 10, '12972', 'HS'),
	(128, 'Salam', 'Hussain', 'shussain32@isk.ac.ke', 'STUDENT', NULL, 5, '11495', 'ES'),
	(91, 'Evelyn', 'James', 'ejames31@isk.ac.ke', 'STUDENT', NULL, 6, '10843', 'MS'),
	(167, 'Akeyo', 'Jayaram', 'ajayaram33@isk.ac.ke', 'STUDENT', NULL, 4, '11404', 'ES'),
	(1046, 'Dario', 'Lawrence', 'dlawrence26@isk.ac.ke', 'STUDENT', NULL, 11, '11438', 'HS'),
	(1047, 'Maximo', 'Lemley', 'mlemley26@isk.ac.ke', 'STUDENT', NULL, 11, '12869', 'HS'),
	(171, 'Bronwyn', 'Line', 'bline27@isk.ac.ke', 'STUDENT', NULL, 10, '11626', 'HS'),
	(87, 'Mara', 'Lopez Abella', 'mlopezabella31@isk.ac.ke', 'STUDENT', NULL, 6, '11819', 'MS'),
	(131, 'Mateo', 'Lopez Salazar', 'mlopezsalazar36@isk.ac.ke', 'STUDENT', NULL, 1, '12752', 'ES'),
	(161, 'Anusha', 'Masrani', 'amasrani28@isk.ac.ke', 'STUDENT', NULL, 9, '10632', 'HS'),
	(985, 'Safiya', 'Menkerios', 'smenkerios32@isk.ac.ke', 'STUDENT', NULL, 5, '11954', 'ES'),
	(986, 'Tamas', 'Meyers', 'tmeyers32@isk.ac.ke', 'STUDENT', NULL, 5, '12622', 'ES'),
	(997, 'Johannah', 'Mpatswe', 'jmpatswe31@isk.ac.ke', 'STUDENT', NULL, 6, '12700', 'MS'),
	(987, 'Arianna', 'Mucci', 'amucci32@isk.ac.ke', 'STUDENT', NULL, 5, '12695', 'ES'),
	(173, 'Tangaaza', 'Mujuni', 'tmujuni29@isk.ac.ke', 'STUDENT', NULL, 8, '10788', 'MS'),
	(146, 'Ben', 'Nannes', 'bnannes27@isk.ac.ke', 'STUDENT', NULL, 10, '10980', 'HS'),
	(152, 'Zawadi', 'Ndinguri', 'zndinguri31@isk.ac.ke', 'STUDENT', NULL, 6, '11936', 'MS'),
	(988, 'Graham', 'Oberjuerge', 'goberjuerge32@isk.ac.ke', 'STUDENT', NULL, 5, '12686', 'ES'),
	(142, 'Juna', 'Patella Ross', 'jpatellaross26@isk.ac.ke', 'STUDENT', NULL, 11, '10617', 'HS'),
	(878, 'Alexandre', 'Patenaude', 'apatenaude36@isk.ac.ke', 'STUDENT', NULL, 1, '12743', 'ES'),
	(166, 'Niyam', 'Ramrakha', 'nramrakha26@isk.ac.ke', 'STUDENT', NULL, 11, '11379', 'HS'),
	(165, 'Divyaan', 'Ramrakha', 'dramrakha29@isk.ac.ke', 'STUDENT', NULL, 8, '11830', 'MS'),
	(989, 'Patrick', 'Ryan', 'pryan32@isk.ac.ke', 'STUDENT', NULL, 5, '12816', 'ES'),
	(133, 'Jamal', 'Sana', 'jsana25@isk.ac.ke', 'STUDENT', NULL, 12, '11525', 'HS'),
	(191, 'Adam-Angelo', 'Sankoh', 'aasankoh33@isk.ac.ke', 'STUDENT', NULL, 4, '12441', 'ES'),
	(100, 'Julian', 'Schmidlin Guerrero', 'jschmidlin31@isk.ac.ke', 'STUDENT', NULL, 6, '11803', 'MS'),
	(229, 'Jasmine', 'Schoneveld', 'jschoneveld33@isk.ac.ke', 'STUDENT', NULL, 4, '11879', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO public.users (id, first_name, last_name, email, role, room, grade_level, number, division) VALUES
	(188, 'Amira', 'Varga', 'avarga31@isk.ac.ke', 'STUDENT', NULL, 6, '11705', 'MS'),
	(169, 'Kianna', 'Venkataya', 'kvenkataya32@isk.ac.ke', 'STUDENT', NULL, 5, '12706', 'ES'),
	(189, 'Jonah', 'Veverka', 'jveverka36@isk.ac.ke', 'STUDENT', NULL, 1, '12835', 'ES'),
	(84, 'Nova', 'Wilkes', 'nwilkes37@isk.ac.ke', 'STUDENT', NULL, 0, '12750', 'ES'),
	(99, 'Gabrielle', 'Willis', 'gwillis31@isk.ac.ke', 'STUDENT', NULL, 6, '12970', 'MS'),
	(160, 'Caitlin', 'Wood', 'cwood25@isk.ac.ke', 'STUDENT', NULL, 12, '10934', 'HS'),
	(1070, 'Theodore', 'Wright', 'twright28@isk.ac.ke', 'STUDENT', NULL, 9, '12566', 'HS'),
	(946, 'Abdul-Lateef Boluwatife (Bolu)', 'Dokunmu', 'adokunmu29@isk.ac.ke', 'STUDENT', NULL, 8, '11463', 'MS'),
	(603, 'Kaynan', 'Abshir', 'kabshir36@isk.ac.ke', 'STUDENT', NULL, 1, '12830', 'ES'),
	(110, 'Louise', 'Ansell', 'lansell26@isk.ac.ke', 'STUDENT', NULL, 11, '11852', 'HS'),
	(1013, 'Elliot', 'Asquith', 'easquith28@isk.ac.ke', 'STUDENT', NULL, 9, '12943', 'HS'),
	(45, 'Carys', 'Aubrey', 'caubrey28@isk.ac.ke', 'STUDENT', NULL, 9, '11838', 'HS'),
	(753, 'Arthur', 'Bailey', 'abailey27@isk.ac.ke', 'STUDENT', NULL, 10, '12825', 'HS'),
	(1024, 'Muhammad Uneeb', 'Bakhshi', 'mbakhshi27@isk.ac.ke', 'STUDENT', NULL, 10, '12760', 'HS'),
	(1014, 'Anshika', 'Basnet', 'abasnet28@isk.ac.ke', 'STUDENT', NULL, 9, '12450', 'HS'),
	(781, 'Ahmed Jawad', 'Bin Taif', 'abintaif31@isk.ac.ke', 'STUDENT', NULL, 6, '12312', 'MS'),
	(999, 'Bertram', 'Birk', 'bbirk30@isk.ac.ke', 'STUDENT', NULL, 7, '12699', 'MS'),
	(1026, 'Lara', 'Blanc Yeo', 'lblanc-yeo27@isk.ac.ke', 'STUDENT', NULL, 10, '12858', 'HS'),
	(1003, 'Luka', 'Breda', 'lbreda29@isk.ac.ke', 'STUDENT', NULL, 8, '12183', 'MS'),
	(1004, 'Paco', 'Breda', 'pbreda29@isk.ac.ke', 'STUDENT', NULL, 8, '12184', 'MS'),
	(201, 'Sianna', 'Byrne-Ilako', 'sbyrne-ilako25@isk.ac.ke', 'STUDENT', NULL, 12, '11751', 'HS'),
	(840, 'Lillian', 'Cameron-Mutyaba', 'lcameron-mutyaba26@isk.ac.ke', 'STUDENT', NULL, 11, '12634', 'HS'),
	(1000, 'Elijah', 'Carey', 'ecarey30@isk.ac.ke', 'STUDENT', NULL, 7, '12923', 'MS'),
	(1016, 'Norah (Rebel)', 'Cizek', 'ncizek28@isk.ac.ke', 'STUDENT', NULL, 9, '12666', 'HS'),
	(1005, 'Camille', 'Corbin', 'ccorbin29@isk.ac.ke', 'STUDENT', NULL, 8, '12941', 'MS'),
	(693, 'Maisha', 'Donne', 'mdone25@isk.ac.ke', 'STUDENT', NULL, 12, '12590', 'HS'),
	(625, 'Ruth', 'Dove', 'rdove27@isk.ac.ke', 'STUDENT', NULL, 10, '12921', 'HS'),
	(565, 'Teo', 'Duwyn', 'tduwyn31@isk.ac.ke', 'STUDENT', NULL, 6, '12085', 'MS'),
	(1052, 'Reem', 'Ephrem Yohannes', 'rephremyohannes25@isk.ac.ke', 'STUDENT', NULL, 12, '11748', 'HS'),
	(441, 'Joshua', 'Exel', 'jexel26@isk.ac.ke', 'STUDENT', NULL, 11, '12073', 'HS'),
	(136, 'Kayla', 'Fazal', 'kfazal30@isk.ac.ke', 'STUDENT', NULL, 7, '12201', 'MS'),
	(250, 'Kaitlyn', 'Fort', 'kfort33@isk.ac.ke', 'STUDENT', NULL, 4, '11704', 'ES'),
	(1008, 'Ava', 'Fritts', 'afritts29@isk.ac.ke', 'STUDENT', NULL, 8, '12928', 'MS'),
	(150, 'Maria', 'Gebremedhin', 'mgebremedhin30@isk.ac.ke', 'STUDENT', NULL, 7, '10688', 'MS'),
	(195, 'Drew (Tilly)', 'Giblin', 'dgiblin34@isk.ac.ke', 'STUDENT', NULL, 3, '12963', 'ES'),
	(550, 'Noa', 'Godden', 'ngodden31@isk.ac.ke', 'STUDENT', NULL, 6, '12504', 'MS'),
	(1053, 'Liam', 'Hobbs', 'lhobbs25@isk.ac.ke', 'STUDENT', NULL, 12, '12971', 'HS'),
	(369, 'Anneka', 'Hornor', 'ahornor26@isk.ac.ke', 'STUDENT', NULL, 11, '12377', 'HS'),
	(198, 'Bella', 'Jama', 'bjama35@isk.ac.ke', 'STUDENT', NULL, 2, '12457', 'ES'),
	(1017, 'Alexa', 'Janisse', 'ajanisse28@isk.ac.ke', 'STUDENT', NULL, 9, '12675', 'HS'),
	(499, 'Daniel', 'Jensen', 'djensen26@isk.ac.ke', 'STUDENT', NULL, 11, '11898', 'HS'),
	(1032, 'Vashnie', 'Joymungul', 'vjoymungul27@isk.ac.ke', 'STUDENT', NULL, 10, '12996', 'HS'),
	(1054, 'Daniel', 'Kadilli', 'dkadilli25@isk.ac.ke', 'STUDENT', NULL, 12, '12991', 'HS'),
	(1033, 'Sphesihle', 'Kamenga', 'skamenga27@isk.ac.ke', 'STUDENT', NULL, 10, '12876', 'HS'),
	(1009, 'Mahiro', 'Kishiue', 'mkishiue29@isk.ac.ke', 'STUDENT', NULL, 8, '12679', 'MS'),
	(216, 'Leo', 'Korvenoja', 'lkorvenoja25@isk.ac.ke', 'STUDENT', NULL, 12, '11526', 'HS'),
	(506, 'Caio', 'Kraemer', 'ckraemer27@isk.ac.ke', 'STUDENT', NULL, 10, '11906', 'HS'),
	(1010, 'Lola', 'Lemley', 'llemley29@isk.ac.ke', 'STUDENT', NULL, 8, '12870', 'MS'),
	(40, 'Sif', 'Lindvig', 'slindvig28@isk.ac.ke', 'STUDENT', NULL, 9, '12502', 'HS'),
	(750, 'Nathan', 'Matimu', 'nmatimu27@isk.ac.ke', 'STUDENT', NULL, 10, '12979', 'HS'),
	(1018, 'Tiago', 'Mendonca-Gray', 'tmendonca-gray28@isk.ac.ke', 'STUDENT', NULL, 9, '12948', 'HS'),
	(1055, 'Jay Austin', 'Nimubona', 'jnimubona25@isk.ac.ke', 'STUDENT', NULL, 12, '12749', 'HS'),
	(498, 'Justin', 'Njenga', 'jnjenga26@isk.ac.ke', 'STUDENT', NULL, 11, '12281', 'HS'),
	(696, 'Nadia', 'Nora', 'nnora25@isk.ac.ke', 'STUDENT', NULL, 12, '12860', 'HS'),
	(64, 'Destiny', 'Ouma', 'douma28@isk.ac.ke', 'STUDENT', NULL, 9, '10319', 'HS'),
	(857, 'Jia', 'Pandit', 'jpandit26@isk.ac.ke', 'STUDENT', NULL, 11, '10437', 'HS'),
	(235, 'Imara', 'Patel', 'ipatel25@isk.ac.ke', 'STUDENT', NULL, 12, '12275', 'HS'),
	(1035, 'Ishita', 'Rathore', 'irathore27@isk.ac.ke', 'STUDENT', NULL, 10, '12983', 'HS'),
	(1048, 'Lila', 'Roquitte', 'lroquitte26@isk.ac.ke', 'STUDENT', NULL, 11, '12555', 'HS'),
	(1001, 'Eva', 'Ryan', 'eryan30@isk.ac.ke', 'STUDENT', NULL, 7, '12618', 'MS'),
	(1049, 'Mathilde', 'Scanlon', 'mscanlon26@isk.ac.ke', 'STUDENT', NULL, 11, '12558', 'HS'),
	(185, 'Sophia', 'Schmid', 'sschmid25@isk.ac.ke', 'STUDENT', NULL, 12, '10975', 'HS'),
	(1012, 'Nicholas', 'Sobantu', 'nsobantu29@isk.ac.ke', 'STUDENT', NULL, 8, '12940', 'MS'),
	(1056, 'Anna Sophia', 'Stabrawa', 'astabrawa25@isk.ac.ke', 'STUDENT', NULL, 12, '25052', 'HS'),
	(1057, 'Elliot', 'Sykes', 'esykes25@isk.ac.ke', 'STUDENT', NULL, 12, '12951', 'HS'),
	(1020, 'Maia', 'Sykes', 'msykes28@isk.ac.ke', 'STUDENT', NULL, 9, '12952', 'HS'),
	(842, 'Nathan', 'Teferi', 'nteferi26@isk.ac.ke', 'STUDENT', NULL, 11, '12984', 'HS'),
	(732, 'Kors', 'Ukumu', 'kukumu27@isk.ac.ke', 'STUDENT', NULL, 10, '12545', 'HS'),
	(1037, 'AsbjøRn', 'Vestergaard', 'avestergaard27@isk.ac.ke', 'STUDENT', NULL, 10, '12663', 'HS'),
	(371, 'Xavier', 'Veveiros', 'xveveiros26@isk.ac.ke', 'STUDENT', NULL, 11, '12009', 'HS'),
	(822, 'Chalita', 'Victor', 'cvictor25@isk.ac.ke', 'STUDENT', NULL, 12, '12529', 'HS'),
	(1021, 'Sonia', 'Weill', 'sweill28@isk.ac.ke', 'STUDENT', NULL, 9, '12848', 'HS'),
	(1060, 'Emma', 'Wright', 'ewright25@isk.ac.ke', 'STUDENT', NULL, 12, '12567', 'HS'),
	(1022, 'Sienna', 'Zulberti', 'szulberti28@isk.ac.ke', 'STUDENT', NULL, 9, '12672', 'HS'),
	(1097, 'Eight', 'Test', 'ttest29@isk.ac.ke', 'STUDENT', NULL, 8, '11661', 'MS'),
	(940, 'Gaia', 'Bonde-Nielsen', 'gbondenielsen30@isk.ac.ke', 'STUDENT', NULL, 7, '12537', 'MS'),
	(942, 'Saqer', 'Alnaqbi', 'salnaqbi30@isk.ac.ke', 'STUDENT', NULL, 7, '12909', 'MS'),
	(943, 'Jack', 'Mcmurtry', 'jmcmurtry30@isk.ac.ke', 'STUDENT', NULL, 7, '10812', 'MS'),
	(955, 'Holly', 'Mcmurtry', 'hmcmurtry30@isk.ac.ke', 'STUDENT', NULL, 7, '10817', 'MS'),
	(956, 'Max', 'Stock', 'mstock30@isk.ac.ke', 'STUDENT', NULL, 7, '12915', 'MS'),
	(117, 'Cahir', 'Patel', 'cpatel29@isk.ac.ke', 'STUDENT', NULL, 8, '10772', 'MS'),
	(935, 'Mikael', 'Eshetu', 'meshetu30@isk.ac.ke', 'STUDENT', NULL, 7, '12689', 'MS'),
	(936, 'Ignacio', 'Biafore', 'ibiafore30@isk.ac.ke', 'STUDENT', NULL, 7, '12170', 'MS'),
	(937, 'Romilly', 'Haysmith', 'rhaysmith30@isk.ac.ke', 'STUDENT', NULL, 7, '12976', 'MS'),
	(938, 'Alexander', 'Wietecha', 'awietecha30@isk.ac.ke', 'STUDENT', NULL, 7, '12725', 'MS'),
	(939, 'Julian', 'Dibling', 'jdibling30@isk.ac.ke', 'STUDENT', NULL, 7, '12883', 'MS'),
	(941, 'Kush', 'Tanna', 'ktanna30@isk.ac.ke', 'STUDENT', NULL, 7, '11096', 'MS'),
	(948, 'Ariel', 'Mutombo', 'amutombo30@isk.ac.ke', 'STUDENT', NULL, 7, '12549', 'MS'),
	(927, 'Malan', 'Chopra', 'mchopra30@isk.ac.ke', 'STUDENT', NULL, 7, '10508', 'MS'),
	(929, 'Moussa', 'Sangare', 'msangare30@isk.ac.ke', 'STUDENT', NULL, 7, '12427', 'MS'),
	(930, 'Leo', 'Jansson', 'ljansson30@isk.ac.ke', 'STUDENT', NULL, 7, '11762', 'MS'),
	(931, 'Nora', 'Saleem', 'nsaleem30@isk.ac.ke', 'STUDENT', NULL, 7, '12619', 'MS'),
	(928, 'Lilla', 'Vestergaard', 'svestergaard30@isk.ac.ke', 'STUDENT', NULL, 7, '11266', 'MS'),
	(932, 'Kaisei', 'Stephens', 'kstephens30@isk.ac.ke', 'STUDENT', NULL, 7, '11804', 'MS'),
	(934, 'Kiara', 'Materne', 'kmaterne30@isk.ac.ke', 'STUDENT', NULL, 7, '12152', 'MS'),
	(958, 'Selma', 'Mensah', 'smensah30@isk.ac.ke', 'STUDENT', NULL, 7, '12392', 'MS'),
	(973, 'Seung Hyun', 'Nam', 'shyun-nam30@isk.ac.ke', 'STUDENT', NULL, 7, '13080', 'MS'),
	(974, 'Tanay', 'Cherickel', 'tcherickel30@isk.ac.ke', 'STUDENT', NULL, 7, '13007', 'MS'),
	(975, 'Zayn', 'Khalid', 'zkhalid30@isk.ac.ke', 'STUDENT', NULL, 7, '12616', 'MS'),
	(976, 'Balazs', 'Meyers', 'bmeyers30@isk.ac.ke', 'STUDENT', NULL, 7, '12621', 'MS'),
	(977, 'Mahdiyah', 'Muneeb', 'mmuneeb30@isk.ac.ke', 'STUDENT', NULL, 7, '12761', 'MS'),
	(978, 'Mapalo', 'Birschbach', 'mbirschbach30@isk.ac.ke', 'STUDENT', NULL, 7, '13050', 'MS'),
	(979, 'Anastasia', 'Mulema', 'amulema30@isk.ac.ke', 'STUDENT', NULL, 7, '11622', 'MS'),
	(982, 'Seth', 'Lundell', 'slundell30@isk.ac.ke', 'STUDENT', NULL, 7, '12691', 'MS'),
	(241, 'Hawi', 'Okwany', 'hokwany29@isk.ac.ke', 'STUDENT', NULL, 8, '10696', 'MS'),
	(239, 'Stefanie', 'Landolt', 'slandolt30@isk.ac.ke', 'STUDENT', NULL, 7, '12286', 'MS'),
	(998, 'Bella', 'Bergqvist', 'bbergqvist30@isk.ac.ke', 'STUDENT', NULL, 7, '12913', 'MS'),
	(652, 'Sada', 'Bomba', 'sbomba25@isk.ac.ke', 'STUDENT', NULL, 12, '12989', 'HS'),
	(290, 'Hana', 'Boxer', 'hboxer25@isk.ac.ke', 'STUDENT', NULL, 12, '11200', 'HS'),
	(246, 'Ziya', 'Butt', 'zbutt27@isk.ac.ke', 'STUDENT', NULL, 10, '11401', 'HS'),
	(215, 'Aarini Vijay', 'Chandaria', 'achandaria27@isk.ac.ke', 'STUDENT', NULL, 10, '10338', 'HS'),
	(193, 'Miles', 'Charette', 'mcharette27@isk.ac.ke', 'STUDENT', NULL, 10, '20780', 'HS'),
	(954, 'Evan', 'Daines', 'edaines30@isk.ac.ke', 'STUDENT', NULL, 7, '13073', 'MS'),
	(626, 'Samuel', 'Dove', 'sdove25@isk.ac.ke', 'STUDENT', NULL, 12, '12920', 'HS'),
	(492, 'Simone', 'Eidex', 'seidex25@isk.ac.ke', 'STUDENT', NULL, 12, '11897', 'HS'),
	(204, 'Lukas', 'Eshetu', 'leshetu27@isk.ac.ke', 'STUDENT', NULL, 10, '12793', 'HS'),
	(933, 'Olivia', 'Freiin Von Handel', 'ofreiinvonhandel30@isk.ac.ke', 'STUDENT', NULL, 7, '12096', 'MS'),
	(851, 'Seher', 'Goyal', 'sgoyal26@isk.ac.ke', 'STUDENT', NULL, 11, '12373', 'HS'),
	(175, 'Laia', 'Guyard Suengas', 'lguyard25@isk.ac.ke', 'STUDENT', NULL, 12, '20805', 'HS'),
	(210, 'Isabel', 'Hansen Meiro', 'ihansenmeiro31@isk.ac.ke', 'STUDENT', NULL, 6, '11943', 'MS'),
	(112, 'Boele', 'Hissink', 'bhissink31@isk.ac.ke', 'STUDENT', NULL, 6, '11003', 'MS'),
	(495, 'Noah', 'Hughes', 'nhughes25@isk.ac.ke', 'STUDENT', NULL, 12, '10477', 'HS'),
	(600, 'Kennedy', 'Ireri', 'kireri27@isk.ac.ke', 'STUDENT', NULL, 10, '10313', 'HS'),
	(666, 'Emily', 'Ishee', 'eishee31@isk.ac.ke', 'STUDENT', NULL, 6, '12836', 'MS'),
	(119, 'Ismail', 'Liban', 'iliban29@isk.ac.ke', 'STUDENT', NULL, 8, '11647', 'MS'),
	(634, 'Gabriela', 'Maasdorp Mogollon', 'gmaasdorpmogollon32@isk.ac.ke', 'STUDENT', NULL, 5, '12821', 'ES'),
	(296, 'Shriya', 'Manek', 'smanek25@isk.ac.ke', 'STUDENT', NULL, 12, '11777', 'HS'),
	(680, 'Daniel', 'Mkandawire', 'dmkandawire25@isk.ac.ke', 'STUDENT', NULL, 12, '12272', 'HS'),
	(972, 'Olivia', 'Moons', 'omoons32@isk.ac.ke', 'STUDENT', NULL, 5, '12852', 'ES'),
	(627, 'Alvin', 'Ngumi', 'angumi25@isk.ac.ke', 'STUDENT', NULL, 12, '12588', 'HS'),
	(957, 'Rowan', 'O''Neill Calver', 'roneillcalver30@isk.ac.ke', 'STUDENT', NULL, 7, '11458', 'MS'),
	(205, 'Dylan', 'Okanda', 'dokanda27@isk.ac.ke', 'STUDENT', NULL, 10, '11511', 'HS'),
	(271, 'Radek Tidi', 'Otieno', 'radotieno31@isk.ac.ke', 'STUDENT', NULL, 6, '10865', 'MS'),
	(469, 'Saron', 'Piper', 'spiper25@isk.ac.ke', 'STUDENT', NULL, 12, '25038', 'HS'),
	(25, 'Annika', 'Purdy', 'apurdy34@isk.ac.ke', 'STUDENT', NULL, 3, '12345', 'ES'),
	(1036, 'Nicholas', 'Rex', 'nrex27@isk.ac.ke', 'STUDENT', NULL, 10, '10884', 'HS'),
	(184, 'Isabella', 'Schmid', 'ischmid25@isk.ac.ke', 'STUDENT', NULL, 12, '10974', 'HS'),
	(484, 'Akshith', 'Sekar', 'asekar26@isk.ac.ke', 'STUDENT', NULL, 11, '10676', 'HS'),
	(294, 'Janak', 'Shah', 'jshah25@isk.ac.ke', 'STUDENT', NULL, 12, '10830', 'HS'),
	(675, 'Ruth Yifru', 'Tafesse', 'rtafesse25@isk.ac.ke', 'STUDENT', NULL, 12, '13099', 'HS'),
	(624, 'Alexander', 'Thomas', 'athomas25@isk.ac.ke', 'STUDENT', NULL, 12, '12579', 'HS'),
	(314, 'Tara', 'Uberoi', 'tuberoi25@isk.ac.ke', 'STUDENT', NULL, 12, '11452', 'HS'),
	(123, 'Matan', 'Yarkoni', 'myarkoni31@isk.ac.ke', 'STUDENT', NULL, 6, '12168', 'MS'),
	(180, 'Zeeon', 'Ahmed', 'zahmed24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11570', 'Alumni'),
	(360, 'Arjan', 'Arora', 'aarora28@isk.ac.ke', 'STUDENT', NULL, 9, '12130', 'HS'),
	(46, 'Evie', 'Aubrey', 'eaubrey24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10950', 'Alumni'),
	(67, 'Andre', 'Awori', 'aawori24@isk.ac.ke', 'ALUMNUS', NULL, 13, '24068', 'Alumni'),
	(194, 'Tea', 'Charette', 'tcharette24@isk.ac.ke', 'ALUMNUS', NULL, 13, '20781', 'Alumni'),
	(151, 'Rainey', 'Copeland', 'rcopeland24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12003', 'Alumni'),
	(915, 'Zubeyda', 'Dadasheva', 'zdadasheva24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12769', 'Alumni'),
	(674, 'Abbas', 'Daher', 'adaher35@isk.ac.ke', 'STUDENT', NULL, 2, '12435', 'ES'),
	(182, 'Yago', 'Dalla Vedova Sanjuan', 'ydallavedova24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12444', 'Alumni'),
	(768, 'Mariam', 'David-Tafida', 'mdavid-tafida34@isk.ac.ke', 'STUDENT', NULL, 3, '12715', 'ES'),
	(154, 'Maximiliano', 'Davis - Arana', 'mdavis-arana35@isk.ac.ke', 'STUDENT', NULL, 2, '12372', 'ES'),
	(11, 'Lily', 'De Backer', 'ldebacker26@isk.ac.ke', 'STUDENT', NULL, 11, '11856', 'HS'),
	(502, 'Marco', 'De Vries Aguirre', 'mdevries-aguirre24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11551', 'Alumni'),
	(898, 'AuréLien', 'Diop Weyer', 'adiop-weyer33@isk.ac.ke', 'STUDENT', NULL, 4, '13033', 'ES'),
	(820, 'Rohin', 'Dodhia', 'rdodhia25@isk.ac.ke', 'STUDENT', NULL, 12, '10820', 'HS'),
	(148, 'Kadin', 'Hajee', 'khajee29@isk.ac.ke', 'STUDENT', NULL, 8, '11542', 'MS'),
	(107, 'Samir', 'Wallbridge', 'swallbridge31@isk.ac.ke', 'STUDENT', NULL, 6, '10841', 'MS'),
	(459, 'Ines Elise', 'Hansen', 'ihansen34@isk.ac.ke', 'STUDENT', NULL, 3, '12363', 'ES'),
	(778, 'Manvir Singh', 'Hayer', 'mhayer29@isk.ac.ke', 'STUDENT', NULL, 8, '12471', 'MS'),
	(617, 'Uriya', 'Hercberg', 'uhercberg29@isk.ac.ke', 'STUDENT', NULL, 8, '12682', 'MS'),
	(74, 'Lisa', 'Otterstedt', 'lotterstedt24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12336', 'Alumni'),
	(129, 'Basile', 'Pozzi', 'bpozzi24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10275', 'Alumni'),
	(423, 'Ella', 'Sims', 'esims24@isk.ac.ke', 'ALUMNUS', NULL, 13, '24043', 'Alumni'),
	(104, 'Erika', 'Sheridan', 'esheridan24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11591', 'Alumni'),
	(47, 'Raeed', 'Mahmud', 'rmahmud24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11910', 'Alumni'),
	(279, 'Lily', 'Herman-Roloff', 'lherman-roloff33@isk.ac.ke', 'STUDENT', NULL, 4, '12194', 'ES'),
	(280, 'Shela', 'Herman-Roloff', 'sherman-roloff31@isk.ac.ke', 'STUDENT', NULL, 6, '12195', 'MS'),
	(879, 'Ren', 'Hirose', 'rhirose35@isk.ac.ke', 'STUDENT', NULL, 2, '13040', 'ES'),
	(1081, 'Nellie', 'Odera', '
nodera.sub@isk.ac.ke', 'SUBSTITUTE', NULL, NULL, NULL, NULL),
	(1072, 'DUMMY 1', 'STUDENT', NULL, 'STUDENT', NULL, NULL, NULL, NULL),
	(1074, 'DUMMY 1', 'STUDENT', NULL, 'STUDENT', NULL, NULL, NULL, NULL),
	(1082, 'Kennedy', 'Wando', 'kwando@isk.ac.ke', 'INVENTORY MANAGER', 'INSTRUMENT STORE', NULL, NULL, NULL),
	(301, 'Fatuma', 'Tall', 'ftall28@isk.ac.ke', 'STUDENT', NULL, 9, '11515', 'HS'),
	(302, 'Jana', 'Landolt', 'jlandolt28@isk.ac.ke', 'STUDENT', NULL, 9, '12285', 'HS'),
	(299, 'Connor', 'Fort', 'cfort30@isk.ac.ke', 'STUDENT', NULL, 7, '11650', 'MS'),
	(300, 'Ochieng', 'Simbiri', 'osimbiri30@isk.ac.ke', 'STUDENT', NULL, 7, '11265', 'MS'),
	(359, 'Anne', 'Bamlango', 'abamlango28@isk.ac.ke', 'STUDENT', NULL, 9, '10978', 'HS'),
	(514, 'Isabel', 'Holder', 'iholder24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12056', 'Alumni'),
	(361, 'Naomi', 'Yohannes', 'nyohannes29@isk.ac.ke', 'STUDENT', NULL, 8, '10787', 'MS'),
	(140, 'Marvelous Peace', 'Nkahnue', 'mnkahnue24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11583', 'Alumni'),
	(681, 'Selkie', 'Douglas-Hamilton Pope', 'spope27@isk.ac.ke', 'STUDENT', NULL, 10, '12995', 'HS'),
	(1006, 'Colin', 'Eldridge', 'celdridge29@isk.ac.ke', 'STUDENT', NULL, 8, '12974', 'MS'),
	(1051, 'Wade', 'Eldridge', 'weldridge25@isk.ac.ke', 'STUDENT', NULL, 12, '12975', 'HS'),
	(34, 'Dawon', 'Eom', 'deom26@isk.ac.ke', 'STUDENT', NULL, 11, '12733', 'HS'),
	(912, 'Carlos Laith', 'Farraj', 'cfarraj32@isk.ac.ke', 'ALUMNUS', NULL, 16, '12607', 'Alumni'),
	(769, 'James', 'Farrell', 'jfarrell35@isk.ac.ke', 'STUDENT', NULL, 2, '12720', 'ES'),
	(137, 'Alyssia', 'Fazal', 'afazal28@isk.ac.ke', 'STUDENT', NULL, 9, '11878', 'HS'),
	(670, 'Caleb', 'Fekadeneh', 'cfekadeneh31@isk.ac.ke', 'STUDENT', NULL, 6, '12641', 'MS'),
	(1007, 'Maya', 'Ferede', 'mferede29@isk.ac.ke', 'STUDENT', NULL, 8, '11726', 'MS'),
	(587, 'Eva', 'Fernstrom', 'efernstrom31@isk.ac.ke', 'STUDENT', NULL, 6, '11939', 'MS'),
	(164, 'Marie', 'Fest', 'mfest25@isk.ac.ke', 'STUDENT', NULL, 12, '10278', 'HS'),
	(163, 'Lina', 'Fest', 'lfest25@isk.ac.ke', 'STUDENT', NULL, 12, '10279', 'HS'),
	(425, 'Logan Lilly', 'Foley', 'lfoley33@isk.ac.ke', 'STUDENT', NULL, 4, '11758', 'ES'),
	(85, 'Maximilian', 'Freiherr Von Handel', 'mvonhandel25@isk.ac.ke', 'STUDENT', NULL, 12, '12095', 'HS'),
	(347, 'Catherina', 'Gagnidze', 'cgagnidze24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11556', 'Alumni'),
	(52, 'Madeleine', 'Gardner', 'mgardner31@isk.ac.ke', 'STUDENT', NULL, 6, '11468', 'MS'),
	(397, 'Andrew', 'Gerba', 'agerba29@isk.ac.ke', 'STUDENT', NULL, 8, '11462', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO public.users (id, first_name, last_name, email, role, room, grade_level, number, division) VALUES
	(559, 'Edouard', 'Germain', 'egermain25@isk.ac.ke', 'STUDENT', NULL, 12, '12258', 'HS'),
	(551, 'Emma', 'Godden', 'egodden27@isk.ac.ke', 'STUDENT', NULL, 10, '12479', 'HS'),
	(144, 'Julia', 'Good', 'jgood28@isk.ac.ke', 'STUDENT', NULL, 9, '12878', 'HS'),
	(873, 'Ben', 'Granot', 'bgranot36@isk.ac.ke', 'STUDENT', NULL, 1, '12748', 'ES'),
	(376, 'Calvin', 'Gremley', 'cgremley26@isk.ac.ke', 'STUDENT', NULL, 11, '12115', 'HS'),
	(688, 'Emily', 'Grindell', 'egrindell34@isk.ac.ke', 'STUDENT', NULL, 3, '12061', 'ES'),
	(311, 'Zoe Rose', 'Hagelberg', 'zhagelberg25@isk.ac.ke', 'STUDENT', NULL, 12, '12077', 'HS'),
	(706, 'Michael', 'Houndeganme', 'mhoundeganme27@isk.ac.ke', 'STUDENT', NULL, 10, '12814', 'HS'),
	(700, 'Xinyi', 'Huang', 'xhuang35@isk.ac.ke', 'STUDENT', NULL, 2, '13074', 'ES'),
	(783, 'Emilia', 'Husemann', 'ehusemann28@isk.ac.ke', 'STUDENT', NULL, 9, '12949', 'HS'),
	(864, 'Jacey', 'Huysdens', 'jhuysdens27@isk.ac.ke', 'STUDENT', NULL, 10, '12926', 'HS'),
	(368, 'Jihwan', 'Hwang', 'jhwang31@isk.ac.ke', 'STUDENT', NULL, 6, '11951', 'MS'),
	(218, 'Hafsa', 'Ahmed', 'hahmed28@isk.ac.ke', 'STUDENT', NULL, 9, '12158', 'HS'),
	(219, 'Mariam', 'Ahmed', 'mahmed28@isk.ac.ke', 'STUDENT', NULL, 9, '12159', 'HS'),
	(282, 'Helina', 'Baheta', 'hebaheta25@isk.ac.ke', 'STUDENT', NULL, 12, '20766', 'HS'),
	(212, 'Mohammad Haroon', 'Bajwa', 'mbajwa28@isk.ac.ke', 'STUDENT', NULL, 9, '10941', 'HS'),
	(297, 'Diane', 'Bamlango', 'dbamlango36@isk.ac.ke', 'STUDENT', NULL, 1, '12371', 'ES'),
	(63, 'Lillia', 'Bellamy', 'lbellamy33@isk.ac.ke', 'STUDENT', NULL, 4, '11942', 'ES'),
	(265, 'Bianca', 'Bini', 'bbini34@isk.ac.ke', 'STUDENT', NULL, 3, '12731', 'ES'),
	(283, 'Jonathan', 'Bjornholm', 'jbjornholm25@isk.ac.ke', 'STUDENT', NULL, 12, '11040', 'HS'),
	(207, 'Kaitlyn', 'Blaschke', 'kblaschke30@isk.ac.ke', 'STUDENT', NULL, 7, '11052', 'MS'),
	(206, 'Sasha', 'Blaschke', 'sblaschke32@isk.ac.ke', 'STUDENT', NULL, 5, '11599', 'ES'),
	(243, 'Meiya', 'Chandaria', 'mchandaria31@isk.ac.ke', 'STUDENT', NULL, 6, '10932', 'MS'),
	(214, 'Aarav', 'Chandaria', 'achandaria32@isk.ac.ke', 'STUDENT', NULL, 5, '11792', 'ES'),
	(211, 'Finley', 'Eckert-Crosse', 'feckertcrosse32@isk.ac.ke', 'STUDENT', NULL, 5, '11568', 'ES'),
	(196, 'Auberlin (Addie)', 'Giblin', 'agiblin29@isk.ac.ke', 'STUDENT', NULL, 8, '12964', 'MS'),
	(130, 'Ibrahim', 'Ibrahim', 'ijuma24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11666', 'Alumni'),
	(855, 'Iman', 'Ibrahim', 'iibrahim27@isk.ac.ke', 'STUDENT', NULL, 10, '12819', 'HS'),
	(622, 'Rayyan', 'Ihsan', 'rihsan29@isk.ac.ke', 'STUDENT', NULL, 8, '13060', 'MS'),
	(329, 'Lengai', 'Inglis', 'linglis27@isk.ac.ke', 'STUDENT', NULL, 10, '12131', 'HS'),
	(653, 'Tamaki', 'Ishikawa', 'tishikawa33@isk.ac.ke', 'STUDENT', NULL, 4, '13054', 'ES'),
	(1044, 'Aarish', 'Islam', 'aislam26@isk.ac.ke', 'STUDENT', NULL, 11, '13008', 'HS'),
	(579, 'Tenzin', 'Jacob', 'tjacob25@isk.ac.ke', 'STUDENT', NULL, 12, '12766', 'HS'),
	(387, 'Gloria', 'Jacques', 'gjacques25@isk.ac.ke', 'STUDENT', NULL, 12, '12067', 'HS'),
	(348, 'Adam', 'Jama', 'ajama34@isk.ac.ke', 'STUDENT', NULL, 3, '11676', 'ES'),
	(225, 'Yara', 'Janmohamed', 'yjanmohamed32@isk.ac.ke', 'STUDENT', NULL, 5, '12173', 'ES'),
	(226, 'Aila', 'Janmohamed', 'ajanmohamed28@isk.ac.ke', 'STUDENT', NULL, 9, '12174', 'HS'),
	(395, 'Felix', 'Jensen', 'fjensen34@isk.ac.ke', 'STUDENT', NULL, 3, '12238', 'ES'),
	(595, 'A-Hyun', 'Jin', 'ajin34@isk.ac.ke', 'STUDENT', NULL, 3, '12246', 'ES'),
	(1045, 'Daniel', 'Johansson-Desai', 'djohansson-desai26@isk.ac.ke', 'STUDENT', NULL, 11, '13011', 'HS'),
	(1031, 'Benjamin', 'Johansson-Desai', 'bjohansson-desai27@isk.ac.ke', 'STUDENT', NULL, 10, '13012', 'HS'),
	(880, 'Abel', 'Johnson', 'ajohnson35@isk.ac.ke', 'STUDENT', NULL, 2, '12767', 'ES'),
	(465, 'Brycelyn', 'Johnson', 'bjohnson30@isk.ac.ke', 'STUDENT', NULL, 7, '12866', 'MS'),
	(526, 'Hyojin', 'Joo', 'hjoo24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11685', 'Alumni'),
	(575, 'Dunja', 'Jovanovic', 'djovanovic28@isk.ac.ke', 'STUDENT', NULL, 9, '12677', 'HS'),
	(734, 'Zayan', 'Karmali', 'zkarmali26@isk.ac.ke', 'STUDENT', NULL, 11, '13098', 'HS'),
	(546, 'Kayla', 'Karuga', 'kkaruga28@isk.ac.ke', 'STUDENT', NULL, 9, '12163', 'HS'),
	(230, 'Hiyabel', 'Kefela', 'hkefela24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11444', 'Alumni'),
	(1098, 'Ten', 'Test', 'mcstudent10@isk.ac.ke', 'STUDENT', NULL, 27, '11662', 'Alumni'),
	(325, 'Sam', 'Khagram', 'skhagram26@isk.ac.ke', 'STUDENT', NULL, 11, '11858', 'HS'),
	(874, 'Zyla', 'Khalid', 'zkhalid36@isk.ac.ke', 'STUDENT', NULL, 1, '12747', 'ES'),
	(583, 'Sophia', 'Khayat De Andrade', 'skhayatdeandrade35@isk.ac.ke', 'STUDENT', NULL, 2, '12650', 'ES'),
	(867, 'Khady', 'Khouma', 'kkhouma33@isk.ac.ke', 'STUDENT', NULL, 4, '13045', 'ES'),
	(313, 'Chloe', 'Kimmelman-May', 'ckimmelman-may28@isk.ac.ke', 'STUDENT', NULL, 9, '12353', 'HS'),
	(875, 'Hannah', 'Kishiue-Turkstra', 'hkishiue-turkstra36@isk.ac.ke', 'STUDENT', NULL, 1, '12751', 'ES'),
	(861, 'Gabriel', 'Kisukye', 'gkisukye26@isk.ac.ke', 'STUDENT', NULL, 11, '12759', 'HS'),
	(209, 'Maaya', 'Kobayashi', 'mkobayashi31@isk.ac.ke', 'STUDENT', NULL, 6, '11575', 'MS'),
	(533, 'Mila Ruth', 'Korngold', 'mkorngold29@isk.ac.ke', 'STUDENT', NULL, 8, '12773', 'MS'),
	(12, 'Emma', 'Kuehnle', 'ekuehnle31@isk.ac.ke', 'STUDENT', NULL, 6, '11801', 'MS'),
	(242, 'Mairi', 'Kurauchi', 'mkurauchi33@isk.ac.ke', 'STUDENT', NULL, 4, '11491', 'ES'),
	(262, 'Kaysan Karim', 'Kurji', 'kkurji33@isk.ac.ke', 'STUDENT', NULL, 4, '12229', 'ES'),
	(1065, 'Vincenzo', 'Lawrence', 'vlawrence24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11447', 'Alumni'),
	(544, 'Enzo', 'Leca Turner', 'elecaturner35@isk.ac.ke', 'STUDENT', NULL, 2, '12893', 'ES'),
	(685, 'Feng Zimo', 'Li', 'fli31@isk.ac.ke', 'STUDENT', NULL, 6, '13024', 'MS'),
	(345, 'Anyamarie', 'Lindgren', 'alindgren28@isk.ac.ke', 'STUDENT', NULL, 9, '11389', 'HS'),
	(288, 'Ahana', 'Nair', 'anair35@isk.ac.ke', 'STUDENT', NULL, 2, '12332', 'ES'),
	(257, 'Zameer', 'Nanji', 'znanji27@isk.ac.ke', 'STUDENT', NULL, 10, '10416', 'HS'),
	(277, 'Tamia', 'Ruiz Stannah', 'truizstannah25@isk.ac.ke', 'STUDENT', NULL, 12, '25032', 'HS'),
	(65, 'Louis', 'Ronzio', 'lronzio33@isk.ac.ke', 'STUDENT', NULL, 4, '12197', 'ES'),
	(269, 'Jordan', 'Nzioka', 'jnzioka34@isk.ac.ke', 'STUDENT', NULL, 3, '11884', 'ES'),
	(223, 'Brianna', 'Otieno', 'botieno28@isk.ac.ke', 'STUDENT', NULL, 9, '11271', 'HS'),
	(318, 'Rhiyana', 'Patel', 'rpatel26@isk.ac.ke', 'STUDENT', NULL, 11, '26025', 'HS'),
	(251, 'Keiya', 'Raja', 'kraja28@isk.ac.ke', 'STUDENT', NULL, 9, '10637', 'HS'),
	(228, 'Junin', 'Rogers', 'jrogers31@isk.ac.ke', 'STUDENT', NULL, 6, '12209', 'MS'),
	(213, 'Erik', 'Suther', 'esuther29@isk.ac.ke', 'STUDENT', NULL, 8, '10511', 'MS'),
	(259, 'Liam', 'Sanders', 'lsanders26@isk.ac.ke', 'STUDENT', NULL, 11, '10430', 'HS'),
	(247, 'Sofia', 'Shamji', 'sshamji28@isk.ac.ke', 'STUDENT', NULL, 9, '11839', 'HS'),
	(248, 'Oumi', 'Tall', 'otall31@isk.ac.ke', 'STUDENT', NULL, 6, '11472', 'MS'),
	(268, 'Andrew', 'Wachira', 'awachira26@isk.ac.ke', 'STUDENT', NULL, 11, '20866', 'HS'),
	(202, 'Camden', 'Teel', 'cteel32@isk.ac.ke', 'STUDENT', NULL, 5, '12360', 'ES'),
	(274, 'Sachin', 'Weaver', 'sweaver25@isk.ac.ke', 'STUDENT', NULL, 12, '10715', 'HS'),
	(496, 'Maximus', 'Njenga', 'mnjenga34@isk.ac.ke', 'STUDENT', NULL, 3, '12303', 'ES'),
	(287, 'Ciaran', 'Clements', 'cclements28@isk.ac.ke', 'STUDENT', NULL, 9, '11843', 'HS'),
	(127, 'Shams', 'Hussain', 'shussain33@isk.ac.ke', 'STUDENT', NULL, 4, '11496', 'ES'),
	(722, 'Ruth', 'Lindkvist', 'rwangarilindkvist27@isk.ac.ke', 'STUDENT', NULL, 10, '12578', 'HS'),
	(172, 'Jamison', 'Line', 'jline25@isk.ac.ke', 'STUDENT', NULL, 12, '11625', 'HS'),
	(170, 'Taegan', 'Line', 'tline29@isk.ac.ke', 'STUDENT', NULL, 8, '11627', 'MS'),
	(996, 'Elijah', 'Lundell', 'elundell31@isk.ac.ke', 'STUDENT', NULL, 6, '12692', 'MS'),
	(592, 'Siri', 'Maagaard', 'smaagaard32@isk.ac.ke', 'STUDENT', NULL, 5, '12827', 'ES'),
	(658, 'Elsie', 'Mackay', 'emackay32@isk.ac.ke', 'STUDENT', NULL, 5, '12886', 'ES'),
	(651, 'Abibatou', 'Magassouba', 'amagassouba34@isk.ac.ke', 'STUDENT', NULL, 3, '13092', 'ES'),
	(355, 'Henk', 'Makimei', 'hmakimei24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11860', 'Alumni'),
	(231, 'Arra', 'Manji', 'amanji32@isk.ac.ke', 'STUDENT', NULL, 5, '12416', 'ES'),
	(537, 'Soren', 'Mansourian', 'smansourian35@isk.ac.ke', 'STUDENT', NULL, 2, '12470', 'ES'),
	(58, 'Abby Angelica', 'Manzano', 'amanzano29@isk.ac.ke', 'STUDENT', NULL, 8, '11479', 'MS'),
	(200, 'Isaiah', 'Marriott', 'imarriott24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11572', 'Alumni'),
	(51, 'Yui', 'Mathers', 'ymathers28@isk.ac.ke', 'STUDENT', NULL, 9, '11110', 'HS'),
	(856, 'Tarquin', 'Mathews', 'tmathews25@isk.ac.ke', 'STUDENT', NULL, 12, '12994', 'HS'),
	(472, 'Sechaba', 'Mazibuko', 'smazibuko26@isk.ac.ke', 'STUDENT', NULL, 11, '12575', 'HS'),
	(731, 'Bianca', 'Mbera', 'bmbera26@isk.ac.ke', 'STUDENT', NULL, 11, '12603', 'HS'),
	(439, 'Caspian', 'Mcsharry', 'cmcsharry31@isk.ac.ke', 'STUDENT', NULL, 6, '12562', 'MS'),
	(440, 'Theodore', 'Mcsharry', 'tmcsharry27@isk.ac.ke', 'STUDENT', NULL, 10, '12563', 'HS'),
	(677, 'Amen', 'Mezemir', 'amezemir28@isk.ac.ke', 'STUDENT', NULL, 9, '10498', 'HS'),
	(417, 'Arushi', 'Mishra', 'armishra24@isk.ac.ke', 'ALUMNUS', NULL, 13, '12488', 'Alumni'),
	(139, 'Joyous', 'Miyanue', 'jmiyanue26@isk.ac.ke', 'STUDENT', NULL, 11, '11582', 'HS'),
	(81, 'Dominik', 'Mogilnicki', 'dmogilnicki31@isk.ac.ke', 'STUDENT', NULL, 6, '11481', 'MS'),
	(826, 'Saoirse', 'Molloy', 'smolloy34@isk.ac.ke', 'STUDENT', NULL, 3, '12702', 'ES'),
	(649, 'Elena', 'Mosher', 'emosher35@isk.ac.ke', 'STUDENT', NULL, 2, '12710', 'ES'),
	(764, 'Christian', 'Mueller', 'cmueller25@isk.ac.ke', 'STUDENT', NULL, 12, '12936', 'HS'),
	(174, 'Rugaba', 'Mujuni', 'rmujuni26@isk.ac.ke', 'STUDENT', NULL, 11, '20828', 'HS'),
	(55, 'Gerald', 'Murathi', 'gmurathi32@isk.ac.ke', 'STUDENT', NULL, 5, '11724', 'ES'),
	(610, 'Aiden', 'Muziramakenga', 'amuziramakenga32@isk.ac.ke', 'STUDENT', NULL, 5, '12703', 'ES'),
	(71, 'Joy', 'Mwangi', 'jmwangi24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10557', 'Alumni'),
	(1034, 'Seung Yoon', 'Nam', 'syoon-nam27@isk.ac.ke', 'STUDENT', NULL, 10, '13079', 'HS'),
	(782, 'Rebekah Ysabelle', 'Nas', 'rysabellenas27@isk.ac.ke', 'STUDENT', NULL, 10, '12978', 'HS'),
	(380, 'Ansley', 'Nelson', 'anelson35@isk.ac.ke', 'STUDENT', NULL, 2, '12806', 'ES'),
	(125, 'Yen', 'Nguyen', 'ynguyen29@isk.ac.ke', 'STUDENT', NULL, 8, '11672', 'MS'),
	(155, 'Emilia', 'Nicolau Meganck', 'enicolaumeganck36@isk.ac.ke', 'STUDENT', NULL, 1, '12797', 'ES'),
	(585, 'Margot', 'Nitcheu', 'mnitcheu34@isk.ac.ke', 'STUDENT', NULL, 3, '12415', 'ES'),
	(419, 'Lukas', 'Norman', 'lnorman26@isk.ac.ke', 'STUDENT', NULL, 11, '11534', 'HS'),
	(433, 'Maeve', 'O''Hearn', 'mo''hearn26@isk.ac.ke', 'STUDENT', NULL, 11, '12763', 'HS'),
	(418, 'Riley', 'O''Neill Calver', 'roneillcalver32@isk.ac.ke', 'STUDENT', NULL, 5, '11488', 'ES'),
	(1011, 'Wesley', 'Oberjuerge', 'woberjuerge29@isk.ac.ke', 'STUDENT', NULL, 8, '12685', 'MS'),
	(884, 'Clayton', 'Oberjuerge', 'coberjuerge35@isk.ac.ke', 'STUDENT', NULL, 2, '12687', 'ES'),
	(805, 'Vera', 'Olvik', 'volvik28@isk.ac.ke', 'STUDENT', NULL, 9, '12953', 'HS'),
	(854, 'Sifa', 'Otieno', 'sotieno24@isk.ac.ke', 'ALUMNUS', NULL, 13, '13013', 'Alumni'),
	(613, 'Jijoon', 'Park', 'jpark34@isk.ac.ke', 'STUDENT', NULL, 3, '12787', 'ES'),
	(316, 'Liam', 'Patel', 'lpatel32@isk.ac.ke', 'STUDENT', NULL, 5, '11486', 'ES'),
	(293, 'Nikhil', 'Patel', 'npatel35@isk.ac.ke', 'STUDENT', NULL, 2, '12494', 'ES'),
	(761, 'Aariyana', 'Patel', 'apatel27@isk.ac.ke', 'STUDENT', NULL, 10, '12553', 'HS'),
	(141, 'Rafaelle', 'Patella Ross', 'rpatellaross29@isk.ac.ke', 'STUDENT', NULL, 8, '10707', 'MS'),
	(657, 'Kaitlin', 'Patterson', 'kpatterson29@isk.ac.ke', 'STUDENT', NULL, 8, '12810', 'MS'),
	(289, 'Aryaan', 'Pattni', 'apattni32@isk.ac.ke', 'STUDENT', NULL, 5, '11729', 'ES'),
	(258, 'Esther', 'Paul', 'epaul28@isk.ac.ke', 'STUDENT', NULL, 9, '11326', 'HS'),
	(510, 'Max', 'Prawitz', 'mprawitz31@isk.ac.ke', 'STUDENT', NULL, 6, '12298', 'MS'),
	(487, 'Alessia', 'Quacquarella', 'aquacquarella31@isk.ac.ke', 'STUDENT', NULL, 6, '11461', 'MS'),
	(37, 'Elizabeth', 'Roe', 'eroe27@isk.ac.ke', 'STUDENT', NULL, 10, '12186', 'HS'),
	(157, 'Otis', 'Rogers', 'orogers35@isk.ac.ke', 'STUDENT', NULL, 2, '11940', 'ES'),
	(694, 'Amanda', 'Romero SáNchez-Miranda', 'asanchez-miranda33@isk.ac.ke', 'STUDENT', NULL, 4, '12800', 'ES'),
	(2, 'Rosa Marie', 'Rosen', 'rrosen33@isk.ac.ke', 'STUDENT', NULL, 4, '11764', 'ES'),
	(520, 'Aven', 'Ross', 'aross29@isk.ac.ke', 'STUDENT', NULL, 8, '11678', 'MS'),
	(233, 'Sidh', 'Rughani', 'srughani27@isk.ac.ke', 'STUDENT', NULL, 10, '10770', 'HS'),
	(276, 'Kianu', 'Ruiz Stannah', 'kruizstannah29@isk.ac.ke', 'STUDENT', NULL, 8, '10247', 'MS'),
	(53, 'Sofia', 'Russo', 'srusso32@isk.ac.ke', 'STUDENT', NULL, 5, '11362', 'ES'),
	(491, 'Jonathan', 'Rwehumbiza', 'jrwehumbiza26@isk.ac.ke', 'STUDENT', NULL, 11, '11854', 'HS'),
	(437, 'Kodjiro', 'Sakaedani Petrovic', 'ksakaedanipetrovic25@isk.ac.ke', 'STUDENT', NULL, 12, '12271', 'HS'),
	(320, 'Gaurav', 'Samani', 'gsamani31@isk.ac.ke', 'STUDENT', NULL, 6, '11179', 'MS'),
	(887, 'Paola', 'Santos', 'psantos35@isk.ac.ke', 'STUDENT', NULL, 2, '13094', 'ES'),
	(168, 'Gendhis', 'Sapta', 'gsapta28@isk.ac.ke', 'STUDENT', NULL, 9, '10320', 'HS'),
	(574, 'Mila', 'Jovanovic', NULL, 'STUDENT', NULL, 6, '12678', 'MS'),
	(493, 'Alston', 'Schenck', 'aschenck32@isk.ac.ke', 'STUDENT', NULL, 5, '11484', 'ES'),
	(901, 'Genevieve', 'Schrader', 'gschrader33@isk.ac.ke', 'STUDENT', NULL, 4, '12840', 'ES'),
	(245, 'Nirvaan', 'Shah', 'nshah24@isk.ac.ke', 'ALUMNUS', NULL, 13, '10774', 'Alumni'),
	(307, 'Savir', 'Shah', 'sshah29@isk.ac.ke', 'STUDENT', NULL, 8, '10965', 'MS'),
	(291, 'Parth', 'Shah', 'pshah26@isk.ac.ke', 'STUDENT', NULL, 11, '10993', 'HS'),
	(68, 'Krishi', 'Shah', 'kshah26@isk.ac.ke', 'STUDENT', NULL, 11, '12121', 'HS'),
	(390, 'Rohan', 'Shah', 'rshah26@isk.ac.ke', 'STUDENT', NULL, 11, '20850', 'HS'),
	(428, 'Micaella', 'Shenge', 'mshenge30@isk.ac.ke', 'STUDENT', NULL, 7, '11527', 'MS'),
	(103, 'Indira', 'Sheridan', 'isheridan26@isk.ac.ke', 'STUDENT', NULL, 11, '11592', 'HS'),
	(853, 'Abhimanyu', 'Singh', 'asingh34@isk.ac.ke', 'STUDENT', NULL, 3, '12728', 'ES'),
	(806, 'Theodor', 'Skaaraas-Gjoelberg', 'tgjoelberg35@isk.ac.ke', 'STUDENT', NULL, 2, '12845', 'ES'),
	(384, 'Andre', 'Sommerlund', 'asommerlund29@isk.ac.ke', 'STUDENT', NULL, 8, '11717', 'MS'),
	(893, 'Ewyn', 'Soobrattee', 'esoobrattee34@isk.ac.ke', 'STUDENT', NULL, 3, '12714', 'ES'),
	(1019, 'Alexa', 'Spitler', 'aspitler28@isk.ac.ke', 'STUDENT', NULL, 9, '12595', 'HS'),
	(524, 'Miya', 'Stephens', 'mstephens31@isk.ac.ke', 'STUDENT', NULL, 6, '11802', 'MS'),
	(640, 'Payton', 'Stock', 'pstock25@isk.ac.ke', 'STUDENT', NULL, 12, '12914', 'HS'),
	(75, 'Helena', 'Stott', 'hstott27@isk.ac.ke', 'STUDENT', NULL, 10, '12520', 'HS'),
	(336, 'Mannat', 'Suri', 'msuri32@isk.ac.ke', 'STUDENT', NULL, 5, '11485', 'ES'),
	(1058, 'Lalia', 'Sylla', 'lsylla25@isk.ac.ke', 'STUDENT', NULL, 12, '12628', 'HS'),
	(534, 'Alexander', 'Tarquini', 'atarquini32@isk.ac.ke', 'STUDENT', NULL, 5, '12223', 'ES'),
	(203, 'Jaidyn', 'Teel', 'jteel30@isk.ac.ke', 'STUDENT', NULL, 7, '12361', 'MS'),
	(95, 'Robert', 'Thornton', 'rthornton29@isk.ac.ke', 'STUDENT', NULL, 8, '12992', 'MS'),
	(94, 'Lucia', 'Thornton', 'lthornton31@isk.ac.ke', 'STUDENT', NULL, 6, '12993', 'MS'),
	(80, 'Sofia', 'Todd', 'stodd34@isk.ac.ke', 'STUDENT', NULL, 3, '11731', 'ES'),
	(580, 'Fatoumata', 'Touré', 'ftoure32@isk.ac.ke', 'STUDENT', NULL, 5, '12324', 'ES'),
	(1059, 'Camila', 'Valdivieso Santos', 'cvaldivieso25@isk.ac.ke', 'STUDENT', NULL, 12, '12568', 'HS'),
	(567, 'Cato', 'Van Bommel', 'cvanbommel25@isk.ac.ke', 'STUDENT', NULL, 12, '12028', 'HS'),
	(78, 'Christodoulos', 'Van De Velden', 'cvandevelden33@isk.ac.ke', 'STUDENT', NULL, 4, '11788', 'ES'),
	(451, 'Sarah', 'Van Der Vliet', 'svandervliet29@isk.ac.ke', 'STUDENT', NULL, 8, '11630', 'MS'),
	(285, 'Solomon', 'Vellenga', 'svellenga31@isk.ac.ke', 'STUDENT', NULL, 6, '11573', 'MS'),
	(903, 'Magne', 'Vestergaard', 'mvestergaard33@isk.ac.ke', 'STUDENT', NULL, 4, '12664', 'ES'),
	(190, 'Theocles', 'Veverka', 'tveverka34@isk.ac.ke', 'STUDENT', NULL, 3, '12838', 'ES'),
	(862, 'Aydin', 'Virani', 'avirani33@isk.ac.ke', 'STUDENT', NULL, 4, '12483', 'ES'),
	(366, 'Olivia', 'Von Strauss', 'ovonstrauss35@isk.ac.ke', 'STUDENT', NULL, 2, '12719', 'ES'),
	(824, 'Simon', 'Waalewijn', 'swaalewijn25@isk.ac.ke', 'STUDENT', NULL, 12, '12596', 'HS'),
	(108, 'Lylah', 'Wallbridge', 'lwallbridge28@isk.ac.ke', 'STUDENT', NULL, 9, '20867', 'HS'),
	(895, 'Tristan', 'Wendelboe', 'twendelboe34@isk.ac.ke', 'STUDENT', NULL, 3, '12527', 'ES'),
	(42, 'Frida', 'Weurlander', 'fweurlander32@isk.ac.ke', 'STUDENT', NULL, 5, '12440', 'ES'),
	(757, 'Thomas', 'Wimber', 'twimber28@isk.ac.ke', 'STUDENT', NULL, 9, '12670', 'HS'),
	(237, 'Mikayla', 'Wissanji', 'mwissanji24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11440', 'Alumni'),
	(159, 'Teagan', 'Wood', 'twood27@isk.ac.ke', 'STUDENT', NULL, 10, '10972', 'HS'),
	(330, 'Mathias', 'Yohannes', 'myohannes26@isk.ac.ke', 'STUDENT', NULL, 11, '20875', 'HS'),
	(445, 'Jack', 'Young', 'jyoung28@isk.ac.ke', 'STUDENT', NULL, 9, '12323', 'HS'),
	(1099, 'Becca', 'Friedman', 'bfriedman31@isk.ac.ke', 'STUDENT', NULL, 6, '12200', 'MS'),
	(22, 'Noah', 'Massawe', 'nmassawe28@isk.ac.ke', 'STUDENT', NULL, 9, '11933', 'HS'),
	(72, 'Hassan', 'Akuete', 'hakuete26@isk.ac.ke', 'STUDENT', NULL, 11, '11985', 'HS'),
	(79, 'Evangelia', 'Van De Velden', 'evandevelden29@isk.ac.ke', 'STUDENT', NULL, 8, '10704', 'MS'),
	(816, 'Jayesh', 'Aditya', 'jaditya28@isk.ac.ke', 'STUDENT', NULL, 9, '12472', 'HS'),
	(632, 'Amman', 'Assefa', 'aassefa28@isk.ac.ke', 'STUDENT', NULL, 9, '12669', 'HS'),
	(234, 'Sohil', 'Chandaria', 'schandaria26@isk.ac.ke', 'STUDENT', NULL, 11, '12124', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO public.users (id, first_name, last_name, email, role, room, grade_level, number, division) VALUES
	(254, 'Siana', 'Chandaria', 'schandaria25@isk.ac.ke', 'STUDENT', NULL, 12, '25072', 'HS'),
	(181, 'Emily', 'Haswell', 'ehaswell28@isk.ac.ke', 'STUDENT', NULL, 9, '27066', 'HS'),
	(818, 'Mark', 'Lavack', 'mlavack28@isk.ac.ke', 'STUDENT', NULL, 9, '20817', 'HS'),
	(192, 'Mwende', 'Mittelstadt', 'mmittelstadt26@isk.ac.ke', 'STUDENT', NULL, 11, '11098', 'HS'),
	(253, 'Ruby', 'Muoki', 'rmuoki25@isk.ac.ke', 'STUDENT', NULL, 12, '12278', 'HS'),
	(317, 'Shane', 'Patel', 'spatel28@isk.ac.ke', 'STUDENT', NULL, 9, '10138', 'HS'),
	(326, 'Radha', 'Shah', 'rshah29@isk.ac.ke', 'STUDENT', NULL, 8, '10786', 'MS'),
	(232, 'Deesha', 'Shah', 'dshah26@isk.ac.ke', 'STUDENT', NULL, 11, '12108', 'HS'),
	(221, 'Tessa', 'Steel', 'tsteel26@isk.ac.ke', 'STUDENT', NULL, 11, '12116', 'HS'),
	(337, 'Armaan', 'Suri', 'asuri29@isk.ac.ke', 'STUDENT', NULL, 8, '11076', 'MS'),
	(236, 'Riyaan', 'Wissanji', 'rwissanji26@isk.ac.ke', 'STUDENT', NULL, 11, '11437', 'HS'),
	(124, 'Itay', 'Yarkoni', 'iyarkoni28@isk.ac.ke', 'STUDENT', NULL, 9, '12169', 'HS'),
	(961, 'Caleb', 'Ross', 'cross28@isk.ac.ke', 'STUDENT', NULL, 9, '11677', 'HS'),
	(963, 'Emiliana', 'Jensen', 'ejensen28@isk.ac.ke', 'STUDENT', NULL, 9, '11904', 'HS'),
	(964, 'Giancarlo', 'Biafore', 'gbiafore28@isk.ac.ke', 'STUDENT', NULL, 9, '12171', 'HS'),
	(116, 'Alexander', 'Mogilnicki', 'amogilnicki29@isk.ac.ke', 'STUDENT', NULL, 8, '11480', 'MS'),
	(156, 'Zane', 'Anding', 'zanding25@isk.ac.ke', 'STUDENT', NULL, 12, '10968', 'HS'),
	(541, 'NatéA', 'Firzé Al Ghaoui', 'nfirzealghaoui29@isk.ac.ke', 'STUDENT', NULL, 8, '12190', 'MS'),
	(227, 'Rwenzori', 'Rogers', 'rrogers32@isk.ac.ke', 'STUDENT', NULL, 5, '12208', 'ES'),
	(54, 'Leandro', 'Russo', 'lrusso28@isk.ac.ke', 'STUDENT', NULL, 9, '11361', 'HS'),
	(102, 'Aarav', 'Sagar', 'asagar35@isk.ac.ke', 'STUDENT', NULL, 2, '12248', 'ES'),
	(711, 'Amitai', 'Segev', 'samitai35@isk.ac.ke', 'STUDENT', NULL, 2, '12721', 'ES'),
	(92, 'Ellis', 'Sudra', 'esudra35@isk.ac.ke', 'STUDENT', NULL, 2, '11941', 'ES'),
	(562, 'Phyo Nyein Nyein', 'Thu', 'pthu29@isk.ac.ke', 'STUDENT', NULL, 8, '12302', 'MS'),
	(540, 'Grace', 'Njenga', 'gnjenga29@isk.ac.ke', 'STUDENT', NULL, 8, '12280', 'MS'),
	(584, 'Maelle', 'Nitcheu', 'mnitcheu36@isk.ac.ke', 'STUDENT', NULL, 0, '12762', 'ES'),
	(404, 'Sasha', 'Allard Ruiz', 'sruiz24@isk.ac.ke', 'ALUMNUS', NULL, 13, '11387', 'Alumni'),
	(413, 'Maya', 'Ben Anat', 'mben-anat37@isk.ac.ke', 'STUDENT', NULL, 0, '12643', 'ES'),
	(678, 'Zizwani', 'Chikapa', 'zchikapa37@isk.ac.ke', 'STUDENT', NULL, 0, '13101', 'ES'),
	(673, 'Ralia', 'Daher', 'rdaher37@isk.ac.ke', 'STUDENT', NULL, 0, '13066', 'ES'),
	(647, 'Ethan', 'Diehl', 'ediehl37@isk.ac.ke', 'STUDENT', NULL, 0, '12863', 'ES'),
	(615, 'Zohar', 'Hercberg', 'zhercberg37@isk.ac.ke', 'STUDENT', NULL, 0, '12745', 'ES'),
	(703, 'Bushra', 'Hussain', 'bhussain37@isk.ac.ke', 'STUDENT', NULL, 0, '13070', 'ES'),
	(594, 'Chae Hyun', 'Jin', 'cjin37@isk.ac.ke', 'STUDENT', NULL, 0, '12647', 'ES'),
	(582, 'Helena', 'Khayat De Andrade', 'hkhayatdeandrade37@isk.ac.ke', 'STUDENT', NULL, 0, '12642', 'ES'),
	(543, 'Nomi', 'Leca Turner', 'nlecaturner37@isk.ac.ke', 'STUDENT', NULL, 0, '12894', 'ES'),
	(682, 'Yoav', 'Margovsky-Lotem', 'ymargovsky37@isk.ac.ke', 'STUDENT', NULL, 0, '12649', 'ES'),
	(900, 'Santiago', 'Santos', 'ssantos33@isk.ac.ke', 'STUDENT', NULL, 4, '13093', 'ES'),
	(990, 'Penelope', 'Schrader', 'pschrader32@isk.ac.ke', 'STUDENT', NULL, 5, '12839', 'ES'),
	(699, 'Nile', 'Sudra', 'nsudra37@isk.ac.ke', 'STUDENT', NULL, 0, '13065', 'ES'),
	(1071, 'Noah', 'Ochomo', 'nochomo@isk.ac.ke', 'INVENTORY MANAGER', 'INSTRUMENT STORE', NULL, NULL, NULL),
	(240, 'Arhum', 'Bid', 'abid30@isk.ac.ke', 'STUDENT', NULL, 7, '11706', 'MS'),
	(298, 'Ayana', 'Butt', 'abutt30@isk.ac.ke', 'STUDENT', NULL, 7, '11402', 'MS'),
	(118, 'Ehsan', 'Akuete', 'eakuete28@isk.ac.ke', 'STUDENT', NULL, 9, '12156', 'HS'),
	(966, 'Keza', 'Herman-Roloff', 'kherman-roloff29@isk.ac.ke', 'STUDENT', NULL, 8, '12196', 'MS'),
	(967, 'Milan', 'Jayaram', 'mijayaram29@isk.ac.ke', 'STUDENT', NULL, 8, '10493', 'MS'),
	(980, 'Etienne', 'Carlevato', 'ecarlevato29@isk.ac.ke', 'STUDENT', NULL, 8, '12924', 'MS'),
	(178, 'Florencia', 'Anding', 'fanding28@isk.ac.ke', 'STUDENT', NULL, 9, '10967', 'HS'),
	(179, 'Tobias', 'Godfrey', 'tgodfrey29@isk.ac.ke', 'STUDENT', NULL, 8, '11227', 'MS'),
	(177, 'Tawheed', 'Hussain', 'thussain30@isk.ac.ke', 'STUDENT', NULL, 7, '11469', 'MS'),
	(965, 'Joan', 'Awori', 'jawori28@isk.ac.ke', 'STUDENT', NULL, 9, '10475', 'HS'),
	(176, 'Lucile', 'Bamlango', 'lbamlango30@isk.ac.ke', 'STUDENT', NULL, 7, '10977', 'MS'),
	(984, 'Nirvi', 'Joymungul', 'njoymungul29@isk.ac.ke', 'STUDENT', NULL, 8, '12997', 'MS'),
	(981, 'Lauren', 'Mucci', 'lmucci30@isk.ac.ke', 'STUDENT', NULL, 7, '12694', 'MS'),
	(983, 'Evyn', 'Hobbs', 'ehobbs30@isk.ac.ke', 'STUDENT', NULL, 7, '12973', 'MS'),
	(1080, 'Rachel', 'Aondo', 'raondo@isk.ac.ke', 'MUSIC TEACHER', 'LOWER ES MUSIC', NULL, NULL, NULL),
	(1079, 'Laois', 'Rogers', 'lrogers@isk.ac.ke', 'MUSIC TEACHER', 'UPPER ES MUSIC', NULL, NULL, NULL),
	(1078, 'Margaret', 'Oganda', 'moganda@isk.ac.ke', 'MUSIC TA', 'UPPER ES MUSIC', NULL, NULL, NULL),
	(1077, 'Gwendolyn', 'Anding', 'ganding@isk.ac.ke', 'MUSIC TEACHER', 'HS MUSIC', NULL, NULL, NULL),
	(1076, 'Mark', 'Anding', 'manding@isk.ac.ke', 'MUSIC TEACHER', 'MS MUSIC', NULL, NULL, NULL),
	(1075, 'Gakenia', 'Mucharie', 'gmucharie@isk.ac.ke', 'MUSIC TA', 'HS MUSIC', NULL, NULL, NULL),
	(708, 'Zefyros', 'Patrikios', NULL, 'STUDENT', NULL, 0, '13103', 'ES'),
	(1089, 'Dummy', 'Dumn', 'dummy2@gmail.com', 'STUDENT', NULL, 1, 'DUMMY123', 'ES'),
	(798, 'Lukas', 'Kaseva', NULL, 'STUDENT', NULL, 0, '13104', 'ES'),
	(970, 'Wataru', 'Plunkett', 'wplunkett29@isk.ac.ke', 'STUDENT', NULL, 8, '12853', 'MS'),
	(968, 'Nickolas', 'Jensen', 'njensen28@isk.ac.ke', 'STUDENT', NULL, 9, '11926', 'HS'),
	(969, 'Noam', 'Waalewijn', 'nwaalewijn28@isk.ac.ke', 'STUDENT', NULL, 9, '12597', 'HS'),
	(772, 'David', 'Ajidahun', 'daajidahun37@isk.ac.ke', 'STUDENT', NULL, 0, '13072', 'ES'),
	(992, 'Sebastian', 'Chappell', 'schappell31@isk.ac.ke', 'STUDENT', NULL, 6, '12577', 'MS'),
	(994, 'Riley', 'Janisse', 'rjanisse31@isk.ac.ke', 'STUDENT', NULL, 6, '12676', 'MS'),
	(995, 'Adam', 'Johnson', 'ajohnson31@isk.ac.ke', 'STUDENT', NULL, 6, '12327', 'MS'),
	(870, 'Ezra', 'Kane', 'ekane37@isk.ac.ke', 'STUDENT', NULL, 0, '13071', 'ES'),
	(740, 'Ayana', 'Limpered', 'alimpered37@isk.ac.ke', 'STUDENT', NULL, 0, '13085', 'ES'),
	(796, 'Kayla', 'Opere', 'kopere36@isk.ac.ke', 'STUDENT', NULL, 0, '12820', 'ES'),
	(871, 'Sapia', 'Pijovic', 'spijovic37@isk.ac.ke', 'STUDENT', NULL, 0, '13091', 'ES'),
	(158, 'Liam', 'Rogers', 'lrogers37@isk.ac.ke', 'STUDENT', NULL, 0, '12744', 'ES'),
	(745, 'Marianne', 'Roquebrune', 'mroquebrune37@isk.ac.ke', 'STUDENT', NULL, 0, '12644', 'ES'),
	(90, 'Axel', 'Rose', 'arose37@isk.ac.ke', 'STUDENT', NULL, 0, '12753', 'ES'),
	(727, 'Jake', 'Schoneveld', 'jschoneveld37@isk.ac.ke', 'STUDENT', NULL, 0, '13086', 'ES'),
	(710, 'Eitan', 'Segev', 'esegev37@isk.ac.ke', 'STUDENT', NULL, 0, '12862', 'ES'),
	(748, 'Lukas', 'Stiles', 'lstiles37@isk.ac.ke', 'STUDENT', NULL, 0, '13068', 'ES'),
	(709, 'Emilio', 'Trujillo', 'etrujillo37@isk.ac.ke', 'STUDENT', NULL, 0, '13067', 'ES'),
	(991, 'Rebecca', 'Von Platen-Hallermund', 'rplatenhallermund32@isk.ac.ke', 'STUDENT', NULL, 5, '12887', 'ES'),
	(738, 'Howard', 'Wesley Iii', 'hwesleyiii37@isk.ac.ke', 'STUDENT', NULL, 0, '12861', 'ES') ON CONFLICT DO NOTHING;


--
-- TOC entry 4048 (class 0 OID 0)
-- Dependencies: 236
-- Name: all_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.all_instruments_id_seq', 350, true);


--
-- TOC entry 4049 (class 0 OID 0)
-- Dependencies: 216
-- Name: class_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.class_id_seq', 14, true);


--
-- TOC entry 4050 (class 0 OID 0)
-- Dependencies: 218
-- Name: dispatches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dispatches_id_seq', 284, true);


--
-- TOC entry 4051 (class 0 OID 0)
-- Dependencies: 220
-- Name: duplicate_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.duplicate_instruments_id_seq', 96, true);


--
-- TOC entry 4052 (class 0 OID 0)
-- Dependencies: 243
-- Name: hardware_and_equipment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.hardware_and_equipment_id_seq', 20, true);


--
-- TOC entry 4053 (class 0 OID 0)
-- Dependencies: 223
-- Name: instrument_conditions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instrument_conditions_id_seq', 6, true);


--
-- TOC entry 4054 (class 0 OID 0)
-- Dependencies: 224
-- Name: instrument_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instrument_history_id_seq', 3578, true);


--
-- TOC entry 4055 (class 0 OID 0)
-- Dependencies: 258
-- Name: instrument_placeholder_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instrument_placeholder_seq', -1, false);


--
-- TOC entry 4056 (class 0 OID 0)
-- Dependencies: 246
-- Name: instrument_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instrument_requests_id_seq', 91, true);


--
-- TOC entry 4057 (class 0 OID 0)
-- Dependencies: 247
-- Name: instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.instruments_id_seq', 4215, true);


--
-- TOC entry 4058 (class 0 OID 0)
-- Dependencies: 249
-- Name: legacy_database_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.legacy_database_id_seq', 669, true);


--
-- TOC entry 4059 (class 0 OID 0)
-- Dependencies: 251
-- Name: locations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.locations_id_seq', 16, true);


--
-- TOC entry 4060 (class 0 OID 0)
-- Dependencies: 226
-- Name: lost_and_found_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lost_and_found_id_seq', 15, true);


--
-- TOC entry 4061 (class 0 OID 0)
-- Dependencies: 253
-- Name: music_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.music_instruments_id_seq', 544, true);


--
-- TOC entry 4062 (class 0 OID 0)
-- Dependencies: 255
-- Name: new_instrument_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.new_instrument_id_seq', 44, true);


--
-- TOC entry 4063 (class 0 OID 0)
-- Dependencies: 228
-- Name: repairs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.repairs_id_seq', 1, false);


--
-- TOC entry 4064 (class 0 OID 0)
-- Dependencies: 230
-- Name: resolve_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.resolve_id_seq', 1, false);


--
-- TOC entry 4065 (class 0 OID 0)
-- Dependencies: 232
-- Name: returns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.returns_id_seq', 315, true);


--
-- TOC entry 4066 (class 0 OID 0)
-- Dependencies: 234
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_id_seq', 14, true);


--
-- TOC entry 4067 (class 0 OID 0)
-- Dependencies: 256
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.students_id_seq', 1088, true);


--
-- TOC entry 4068 (class 0 OID 0)
-- Dependencies: 259
-- Name: swap_cases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.swap_cases_id_seq', 50, true);


--
-- TOC entry 4069 (class 0 OID 0)
-- Dependencies: 261
-- Name: take_stock_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.take_stock_id_seq', 10, true);


--
-- TOC entry 4070 (class 0 OID 0)
-- Dependencies: 257
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 1099, true);


--
-- TOC entry 3730 (class 2606 OID 31008)
-- Name: equipment all_instruments_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.equipment
    ADD CONSTRAINT all_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text, 'SOUND'::text]))) NOT VALID;


--
-- TOC entry 3761 (class 2606 OID 31010)
-- Name: equipment all_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT all_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3735 (class 2606 OID 30770)
-- Name: class class_class_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_class_name_key UNIQUE (class_name);


--
-- TOC entry 3737 (class 2606 OID 30772)
-- Name: class class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);


--
-- TOC entry 3809 (class 2606 OID 39815)
-- Name: class_students class_students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_students
    ADD CONSTRAINT class_students_pkey PRIMARY KEY (class_id, user_id);


--
-- TOC entry 3739 (class 2606 OID 30774)
-- Name: dispatches dispatches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_pkey PRIMARY KEY (id);


--
-- TOC entry 3741 (class 2606 OID 30776)
-- Name: duplicate_instruments duplicate_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.duplicate_instruments
    ADD CONSTRAINT duplicate_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3763 (class 2606 OID 31012)
-- Name: equipment equipment_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_code_key UNIQUE (code) INCLUDE (code);


--
-- TOC entry 3765 (class 2606 OID 31014)
-- Name: equipment equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_description_key UNIQUE (description);


--
-- TOC entry 3785 (class 2606 OID 31016)
-- Name: hardware_and_equipment hardware_and_equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_description_key UNIQUE (description);


--
-- TOC entry 3731 (class 2606 OID 31017)
-- Name: hardware_and_equipment hardware_and_equipment_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_family_check CHECK ((upper((family)::text) = ANY (ARRAY['MISCELLANEOUS'::text, 'SOUND'::text]))) NOT VALID;


--
-- TOC entry 3787 (class 2606 OID 31019)
-- Name: hardware_and_equipment hardware_and_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_pkey PRIMARY KEY (id);


--
-- TOC entry 3745 (class 2606 OID 30778)
-- Name: instrument_conditions instrument_conditions_condition_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_conditions
    ADD CONSTRAINT instrument_conditions_condition_key UNIQUE (condition);


--
-- TOC entry 3747 (class 2606 OID 30780)
-- Name: instrument_conditions instrument_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_conditions
    ADD CONSTRAINT instrument_conditions_pkey PRIMARY KEY (id);


--
-- TOC entry 3743 (class 2606 OID 30782)
-- Name: instrument_history instrument_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3769 (class 2606 OID 31153)
-- Name: instruments instruments_code_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_number_key UNIQUE (code, number) DEFERRABLE INITIALLY DEFERRED;


--
-- TOC entry 3771 (class 2606 OID 31023)
-- Name: instruments instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3773 (class 2606 OID 31025)
-- Name: instruments instruments_serial_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_serial_key UNIQUE (serial);


--
-- TOC entry 3791 (class 2606 OID 31027)
-- Name: legacy_database legacy_database_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.legacy_database
    ADD CONSTRAINT legacy_database_pkey PRIMARY KEY (id);


--
-- TOC entry 3793 (class 2606 OID 31029)
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- TOC entry 3749 (class 2606 OID 30784)
-- Name: lost_and_found lost_and_found_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_and_found
    ADD CONSTRAINT lost_and_found_pkey PRIMARY KEY (id);


--
-- TOC entry 3797 (class 2606 OID 31031)
-- Name: music_instruments music_instruments_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_code_key UNIQUE (code) INCLUDE (code);


--
-- TOC entry 3799 (class 2606 OID 31033)
-- Name: music_instruments music_instruments_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_description_key UNIQUE (description);


--
-- TOC entry 3801 (class 2606 OID 31035)
-- Name: music_instruments music_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3803 (class 2606 OID 31037)
-- Name: new_instrument new_instrument_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.new_instrument
    ADD CONSTRAINT new_instrument_pkey PRIMARY KEY (id);


--
-- TOC entry 3751 (class 2606 OID 30786)
-- Name: repair_request repairs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_pkey PRIMARY KEY (id);


--
-- TOC entry 3789 (class 2606 OID 31039)
-- Name: instrument_requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);


--
-- TOC entry 3753 (class 2606 OID 30788)
-- Name: resolve resolve_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_pkey PRIMARY KEY (id);


--
-- TOC entry 3755 (class 2606 OID 30790)
-- Name: returns returns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_pkey PRIMARY KEY (id);


--
-- TOC entry 3757 (class 2606 OID 30792)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 3759 (class 2606 OID 30794)
-- Name: roles roles_role_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_role_name_key UNIQUE (role_name);


--
-- TOC entry 3795 (class 2606 OID 31041)
-- Name: locations room; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT room UNIQUE (room);


--
-- TOC entry 3779 (class 2606 OID 31683)
-- Name: students students_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_email_key UNIQUE (email);


--
-- TOC entry 3781 (class 2606 OID 31043)
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- TOC entry 3783 (class 2606 OID 31685)
-- Name: students students_student_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_student_number_key UNIQUE (student_number);


--
-- TOC entry 3805 (class 2606 OID 31509)
-- Name: swap_cases swap_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.swap_cases
    ADD CONSTRAINT swap_cases_pkey PRIMARY KEY (id);


--
-- TOC entry 3807 (class 2606 OID 31545)
-- Name: take_stock take_stock_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.take_stock
    ADD CONSTRAINT take_stock_pkey PRIMARY KEY (id);


--
-- TOC entry 3775 (class 2606 OID 31045)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 3777 (class 2606 OID 31049)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 3766 (class 1259 OID 31050)
-- Name: fki_instruments_code_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_instruments_code_fkey ON public.instruments USING btree (code);


--
-- TOC entry 3767 (class 1259 OID 31051)
-- Name: fki_instruments_description_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_instruments_description_fkey ON public.instruments USING btree (description);


--
-- TOC entry 3834 (class 2620 OID 30795)
-- Name: dispatches assign_user; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER assign_user BEFORE INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.dispatch();


--
-- TOC entry 3845 (class 2620 OID 31528)
-- Name: swap_cases before_swap_cases_insert; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER before_swap_cases_insert AFTER INSERT ON public.swap_cases FOR EACH ROW EXECUTE FUNCTION public.swap_cases_trigger();


--
-- TOC entry 3836 (class 2620 OID 30796)
-- Name: lost_and_found log_instrument; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_instrument AFTER INSERT ON public.lost_and_found FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3837 (class 2620 OID 30797)
-- Name: returns log_return; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_return AFTER INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3846 (class 2620 OID 31546)
-- Name: take_stock log_take_stock; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_take_stock AFTER INSERT ON public.take_stock FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3835 (class 2620 OID 30798)
-- Name: dispatches log_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_transaction AFTER INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3843 (class 2620 OID 31052)
-- Name: new_instrument log_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_transaction AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.log_transaction();

ALTER TABLE public.new_instrument DISABLE TRIGGER log_transaction;


--
-- TOC entry 3839 (class 2620 OID 31053)
-- Name: instruments new_instr; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_instr AFTER INSERT OR UPDATE ON public.instruments FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3844 (class 2620 OID 31054)
-- Name: new_instrument new_instrument_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_instrument_trigger AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.new_instr_function();


--
-- TOC entry 3841 (class 2620 OID 31716)
-- Name: students new_student_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_student_trigger BEFORE INSERT ON public.students FOR EACH ROW EXECUTE FUNCTION public.new_student_function();


--
-- TOC entry 3838 (class 2620 OID 30799)
-- Name: returns return_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER return_trigger BEFORE INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.return();


--
-- TOC entry 3833 (class 2620 OID 30800)
-- Name: class trg_check_teacher_role; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_teacher_role BEFORE INSERT OR UPDATE ON public.class FOR EACH ROW EXECUTE FUNCTION public.check_teacher_role();


--
-- TOC entry 3840 (class 2620 OID 31722)
-- Name: users update_role_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_role_trigger AFTER INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_user_role_based_on_grade_level();


--
-- TOC entry 3842 (class 2620 OID 31720)
-- Name: students update_student_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_student_trigger AFTER UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.update_students();


--
-- TOC entry 3831 (class 2606 OID 39816)
-- Name: class_students class_students_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_students
    ADD CONSTRAINT class_students_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.class(id) ON DELETE CASCADE;


--
-- TOC entry 3832 (class 2606 OID 39821)
-- Name: class_students class_students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class_students
    ADD CONSTRAINT class_students_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3810 (class 2606 OID 31055)
-- Name: class class_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);


--
-- TOC entry 3811 (class 2606 OID 31060)
-- Name: dispatches dispatches_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);


--
-- TOC entry 3812 (class 2606 OID 31065)
-- Name: dispatches dispatches_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3813 (class 2606 OID 31070)
-- Name: instrument_history instrument_history_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);


--
-- TOC entry 3820 (class 2606 OID 31075)
-- Name: instruments instruments_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_fkey FOREIGN KEY (code) REFERENCES public.equipment(code) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3821 (class 2606 OID 31080)
-- Name: instruments instruments_description_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_description_fkey FOREIGN KEY (description) REFERENCES public.equipment(description) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3822 (class 2606 OID 31085)
-- Name: instruments instruments_location_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_location_fkey FOREIGN KEY (location) REFERENCES public.locations(room) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3823 (class 2606 OID 31090)
-- Name: instruments instruments_state_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_state_fkey FOREIGN KEY (state) REFERENCES public.instrument_conditions(condition) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3814 (class 2606 OID 31095)
-- Name: lost_and_found lost_and_found_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_and_found
    ADD CONSTRAINT lost_and_found_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE;


--
-- TOC entry 3815 (class 2606 OID 31100)
-- Name: repair_request repairs_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3826 (class 2606 OID 31105)
-- Name: instrument_requests requests_attended_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_attended_by_id_fkey FOREIGN KEY (attended_by_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3827 (class 2606 OID 31110)
-- Name: instrument_requests requests_instrument_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_instrument_fkey FOREIGN KEY (instrument) REFERENCES public.equipment(description);


--
-- TOC entry 3828 (class 2606 OID 31115)
-- Name: instrument_requests requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 3816 (class 2606 OID 30801)
-- Name: resolve resolve_case_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_case_fkey FOREIGN KEY ("case") REFERENCES public.repair_request(id);


--
-- TOC entry 3817 (class 2606 OID 31120)
-- Name: returns returns_former_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_former_user_id FOREIGN KEY (former_user_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3829 (class 2606 OID 31510)
-- Name: swap_cases returns_item_id_1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.swap_cases
    ADD CONSTRAINT returns_item_id_1_fkey FOREIGN KEY (item_id_1) REFERENCES public.instruments(id) ON UPDATE CASCADE;


--
-- TOC entry 3830 (class 2606 OID 31515)
-- Name: swap_cases returns_item_id_2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.swap_cases
    ADD CONSTRAINT returns_item_id_2_fkey FOREIGN KEY (item_id_2) REFERENCES public.instruments(id) ON UPDATE CASCADE;


--
-- TOC entry 3818 (class 2606 OID 31125)
-- Name: returns returns_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3819 (class 2606 OID 31130)
-- Name: returns returns_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3824 (class 2606 OID 31135)
-- Name: users user_room_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT user_room_fk FOREIGN KEY (room) REFERENCES public.locations(room) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3825 (class 2606 OID 31140)
-- Name: users users_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.roles(role_name);


--
-- TOC entry 4046 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2024-10-11 00:31:42 EAT

--
-- PostgreSQL database dump complete
--

