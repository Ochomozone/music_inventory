
CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;


COMMENT ON SCHEMA public IS 'standard public schema';



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
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = username) THEN
            EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', username, default_password);
            EXECUTE format('COMMENT ON ROLE %I IS %L', username, 'User ID: ' || user_id);

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


CREATE FUNCTION public.dispatch() RETURNS trigger
    LANGUAGE plpgsql
    AS $$DECLARE
    instrument_user_name TEXT;
BEGIN
   
    IF (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD') THEN
        RAISE EXCEPTION 'Item cannot be rented out';
    END IF;

    SELECT INTO instrument_user_name first_name || ' ' || last_name
    FROM users
    WHERE "id" = (SELECT user_id FROM instruments WHERE "id" = NEW.item_id)::integer;


    IF instrument_user_name IS NOT NULL THEN
        RAISE EXCEPTION 'Instrument already checked out to %', instrument_user_name;
    END IF;

    UPDATE instruments
    SET "user_id" = NEW.user_id,
        location = NULL
    WHERE id = NEW.item_id;

    RETURN NEW;
END;$$;


ALTER FUNCTION public.dispatch() OWNER TO postgres;



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



CREATE FUNCTION public.insert_type(p_code character varying, p_description character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO types (code, description) VALUES (UPPER(p_code), UPPER(p_description));
END;
$$;


ALTER FUNCTION public.insert_type(p_code character varying, p_description character varying) OWNER TO postgres;



CREATE FUNCTION public.log_transaction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
    IF TG_TABLE_NAME = 'instruments' THEN
        IF TG_OP = 'UPDATE' THEN
            IF NEW.state <> OLD.state OR NEW.number <> OLD.number THEN
                INSERT INTO instrument_history (transaction_type, created_by, item_id)
                SELECT 'Details Updated', username, NEW.id FROM new_instruments WHERE description = NEW.description AND number = NEW.number;
            END IF;
        ELSIF TG_OP = 'INSERT' THEN
            INSERT INTO instrument_history (transaction_type, created_by, item_id)
            SELECT 'New Instrument', username, NEW.id FROM new_instrument WHERE description = NEW.description AND number = NEW.number;
        END IF;
    ELSIF TG_TABLE_NAME = 'dispatches' THEN
        IF TG_OP = 'INSERT' THEN
            INSERT INTO instrument_history (transaction_type, created_by, item_id, assigned_to)
            VALUES ('Instrument Out',NEW.created_by, NEW.item_id, NEW.profile_id);
        END IF;
    ELSIF TG_TABLE_NAME = 'returns' THEN
        IF TG_OP = 'INSERT' THEN
            INSERT INTO instrument_history (transaction_type, item_id, created_by, returned_by_id)
            VALUES ('Instrument Returned', NEW.item_id,NEW.created_by, NEW.former_user_id);
        END IF;
    ELSIF TG_TABLE_NAME = 'lost_and_found' THEN
        IF TG_OP = 'INSERT' THEN
            INSERT INTO instrument_history (transaction_type, item_id, created_by, "location", transaction_timestamp, contact)
            VALUES ('Instrument Found', NEW.item_id, NEW.finder_name, NEW.location, NEW.date, NEW.contact );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_transaction() OWNER TO postgres;



CREATE FUNCTION public.new_instr_function() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    n_code VARCHAR;
    legacy_code VARCHAR;
BEGIN
    
    SELECT equipment.code INTO n_code FROM equipment WHERE equipment.description = NEW.description;
    SELECT equipment.legacy_code INTO legacy_code FROM equipment WHERE equipment.description = UPPER(NEW.description);
	
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



CREATE FUNCTION public.return() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    
    IF (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL THEN
        
        UPDATE instruments
        SET user_id = NULL,
            location = (SELECT room FROM users WHERE users.id = NEW.user_id),
            user_name = NULL
        WHERE id = NEW.item_id;
    ELSE
      
        RAISE EXCEPTION 'User cannot return instrument. No room assigned.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.return() OWNER TO postgres;


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



CREATE TABLE public.equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);


ALTER TABLE public.equipment OWNER TO postgres;



ALTER TABLE public.equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.all_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



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
    user_id integer
);


ALTER TABLE public.instruments OWNER TO postgres;



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
    username character varying,
    active boolean DEFAULT true
);


ALTER TABLE public.users OWNER TO postgres;



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
    students.class,
    users.active,
    users.username
   FROM (public.users
     LEFT JOIN public.students ON (((students.student_number)::text = (users.number)::text)))
  ORDER BY users.role, users.first_name;


ALTER TABLE public.all_users_view OWNER TO postgres;



CREATE TABLE public.class (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    class_name character varying
);


ALTER TABLE public.class OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16580)
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
-- TOC entry 224 (class 1259 OID 16581)
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
-- TOC entry 225 (class 1259 OID 16585)
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
-- TOC entry 226 (class 1259 OID 16591)
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
-- TOC entry 227 (class 1259 OID 16592)
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
-- TOC entry 228 (class 1259 OID 16599)
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
-- TOC entry 229 (class 1259 OID 16600)
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
-- TOC entry 230 (class 1259 OID 16605)
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
-- TOC entry 231 (class 1259 OID 16606)
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
-- TOC entry 259 (class 1259 OID 16925)
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
    instrument_history.returned_by_id
   FROM ((public.instrument_history
     LEFT JOIN public.users ON ((users.id = (instrument_history.assigned_to)::integer)))
     LEFT JOIN public.instruments ON ((instruments.id = instrument_history.item_id)))
  ORDER BY instrument_history.id;


ALTER TABLE public.history_view OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 16886)
-- Name: instrument_conditions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.instrument_conditions (
    id integer NOT NULL,
    condition character varying
);


ALTER TABLE public.instrument_conditions OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 16885)
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
-- TOC entry 232 (class 1259 OID 16617)
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
-- TOC entry 233 (class 1259 OID 16622)
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
-- TOC entry 234 (class 1259 OID 16623)
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
-- TOC entry 235 (class 1259 OID 16624)
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
-- TOC entry 236 (class 1259 OID 16631)
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
-- TOC entry 237 (class 1259 OID 16632)
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.locations (
    room public.citext NOT NULL,
    id integer NOT NULL
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 16637)
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
-- TOC entry 254 (class 1259 OID 16848)
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
-- TOC entry 253 (class 1259 OID 16847)
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
-- TOC entry 239 (class 1259 OID 16638)
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
-- TOC entry 240 (class 1259 OID 16644)
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
-- TOC entry 256 (class 1259 OID 16873)
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
-- TOC entry 255 (class 1259 OID 16872)
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
-- TOC entry 241 (class 1259 OID 16659)
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
-- TOC entry 242 (class 1259 OID 16665)
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
-- TOC entry 243 (class 1259 OID 16666)
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
-- TOC entry 244 (class 1259 OID 16672)
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
-- TOC entry 245 (class 1259 OID 16673)
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
-- TOC entry 246 (class 1259 OID 16679)
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
-- TOC entry 247 (class 1259 OID 16680)
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
-- TOC entry 248 (class 1259 OID 16686)
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
-- TOC entry 249 (class 1259 OID 16687)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    role_name character varying DEFAULT 'STUDENT'::character varying
);


ALTER TABLE public.roles OWNER TO postgres;

--
-- TOC entry 250 (class 1259 OID 16693)
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
-- TOC entry 251 (class 1259 OID 16694)
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
-- TOC entry 252 (class 1259 OID 16695)
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
-- TOC entry 3676 (class 2606 OID 16696)
-- Name: equipment all_instruments_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.equipment
    ADD CONSTRAINT all_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text, 'SOUND'::text]))) NOT VALID;


--
-- TOC entry 3681 (class 2606 OID 16698)
-- Name: equipment all_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT all_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3703 (class 2606 OID 16700)
-- Name: class class_class_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_class_name_key UNIQUE (class_name);


--
-- TOC entry 3705 (class 2606 OID 16702)
-- Name: class class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);


--
-- TOC entry 3707 (class 2606 OID 16704)
-- Name: dispatches dispatches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_pkey PRIMARY KEY (id);


--
-- TOC entry 3709 (class 2606 OID 16706)
-- Name: duplicate_instruments duplicate_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.duplicate_instruments
    ADD CONSTRAINT duplicate_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3683 (class 2606 OID 16708)
-- Name: equipment equipment_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_code_key UNIQUE (code) INCLUDE (code);


--
-- TOC entry 3685 (class 2606 OID 16710)
-- Name: equipment equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_description_key UNIQUE (description);


--
-- TOC entry 3711 (class 2606 OID 16712)
-- Name: hardware_and_equipment hardware_and_equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_description_key UNIQUE (description);


--
-- TOC entry 3677 (class 2606 OID 16713)
-- Name: hardware_and_equipment hardware_and_equipment_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_family_check CHECK ((upper((family)::text) = ANY (ARRAY['MISCELLANEOUS'::text, 'SOUND'::text]))) NOT VALID;


--
-- TOC entry 3713 (class 2606 OID 16715)
-- Name: hardware_and_equipment hardware_and_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_pkey PRIMARY KEY (id);


--
-- TOC entry 3747 (class 2606 OID 16894)
-- Name: instrument_conditions instrument_conditions_condition_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_conditions
    ADD CONSTRAINT instrument_conditions_condition_key UNIQUE (condition);


--
-- TOC entry 3749 (class 2606 OID 16892)
-- Name: instrument_conditions instrument_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_conditions
    ADD CONSTRAINT instrument_conditions_pkey PRIMARY KEY (id);


--
-- TOC entry 3715 (class 2606 OID 16717)
-- Name: instrument_history instrument_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_pkey PRIMARY KEY (id);


--
-- TOC entry 3689 (class 2606 OID 16719)
-- Name: instruments instruments_code_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_number_key UNIQUE (code, number);


--
-- TOC entry 3691 (class 2606 OID 16721)
-- Name: instruments instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3693 (class 2606 OID 16723)
-- Name: instruments instruments_serial_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_serial_key UNIQUE (serial);


--
-- TOC entry 3717 (class 2606 OID 16725)
-- Name: legacy_database legacy_database_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.legacy_database
    ADD CONSTRAINT legacy_database_pkey PRIMARY KEY (id);


--
-- TOC entry 3719 (class 2606 OID 16727)
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- TOC entry 3743 (class 2606 OID 16855)
-- Name: lost_and_found lost_and_found_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_and_found
    ADD CONSTRAINT lost_and_found_pkey PRIMARY KEY (id);


--
-- TOC entry 3723 (class 2606 OID 16729)
-- Name: music_instruments music_instruments_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_code_key UNIQUE (code) INCLUDE (code);


--
-- TOC entry 3725 (class 2606 OID 16731)
-- Name: music_instruments music_instruments_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_description_key UNIQUE (description);


--
-- TOC entry 3727 (class 2606 OID 16733)
-- Name: music_instruments music_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_pkey PRIMARY KEY (id);


--
-- TOC entry 3745 (class 2606 OID 16902)
-- Name: new_instrument new_instrument_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.new_instrument
    ADD CONSTRAINT new_instrument_pkey PRIMARY KEY (id);


--
-- TOC entry 3729 (class 2606 OID 16737)
-- Name: repair_request repairs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_pkey PRIMARY KEY (id);


--
-- TOC entry 3731 (class 2606 OID 16739)
-- Name: requests requests_instrument_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_instrument_key UNIQUE (instrument);


--
-- TOC entry 3733 (class 2606 OID 16741)
-- Name: requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);


--
-- TOC entry 3735 (class 2606 OID 16743)
-- Name: resolve resolve_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_pkey PRIMARY KEY (id);


--
-- TOC entry 3737 (class 2606 OID 16745)
-- Name: returns returns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_pkey PRIMARY KEY (id);


--
-- TOC entry 3739 (class 2606 OID 16747)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 3741 (class 2606 OID 16749)
-- Name: roles roles_role_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_role_name_key UNIQUE (role_name);


--
-- TOC entry 3721 (class 2606 OID 16751)
-- Name: locations room; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT room UNIQUE (room);


--
-- TOC entry 3701 (class 2606 OID 16753)
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- TOC entry 3695 (class 2606 OID 16755)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 3697 (class 2606 OID 16757)
-- Name: users users_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_number_key UNIQUE (number);


--
-- TOC entry 3699 (class 2606 OID 16759)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 3686 (class 1259 OID 16760)
-- Name: fki_instruments_code_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_instruments_code_fkey ON public.instruments USING btree (code);


--
-- TOC entry 3687 (class 1259 OID 16761)
-- Name: fki_instruments_description_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_instruments_description_fkey ON public.instruments USING btree (description);


--
-- TOC entry 3770 (class 2620 OID 16762)
-- Name: dispatches assign_user; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER assign_user BEFORE INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.dispatch();


--
-- TOC entry 3774 (class 2620 OID 16861)
-- Name: lost_and_found log_instrument; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_instrument AFTER INSERT ON public.lost_and_found FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3772 (class 2620 OID 16763)
-- Name: returns log_return; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_return AFTER INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3771 (class 2620 OID 16764)
-- Name: dispatches log_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_transaction AFTER INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3775 (class 2620 OID 16900)
-- Name: new_instrument log_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_transaction AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.log_transaction();

ALTER TABLE public.new_instrument DISABLE TRIGGER log_transaction;


--
-- TOC entry 3768 (class 2620 OID 16765)
-- Name: instruments new_instr; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_instr AFTER INSERT OR UPDATE ON public.instruments FOR EACH ROW EXECUTE FUNCTION public.log_transaction();


--
-- TOC entry 3776 (class 2620 OID 16879)
-- Name: new_instrument new_instrument_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER new_instrument_trigger AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.new_instr_function();


--
-- TOC entry 3773 (class 2620 OID 16767)
-- Name: returns return_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER return_trigger BEFORE INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.return();


--
-- TOC entry 3769 (class 2620 OID 16768)
-- Name: class trg_check_teacher_role; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_teacher_role BEFORE INSERT OR UPDATE ON public.class FOR EACH ROW EXECUTE FUNCTION public.check_teacher_role();


--
-- TOC entry 3756 (class 2606 OID 16769)
-- Name: class class_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);


--
-- TOC entry 3757 (class 2606 OID 16774)
-- Name: dispatches dispatches_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);


--
-- TOC entry 3758 (class 2606 OID 16867)
-- Name: dispatches dispatches_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3759 (class 2606 OID 16779)
-- Name: instrument_history instrument_history_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);


--
-- TOC entry 3750 (class 2606 OID 16784)
-- Name: instruments instruments_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_fkey FOREIGN KEY (code) REFERENCES public.equipment(code) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3751 (class 2606 OID 16789)
-- Name: instruments instruments_description_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_description_fkey FOREIGN KEY (description) REFERENCES public.equipment(description) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3752 (class 2606 OID 16794)
-- Name: instruments instruments_location_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_location_fkey FOREIGN KEY (location) REFERENCES public.locations(room) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3753 (class 2606 OID 16895)
-- Name: instruments instruments_state_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_state_fkey FOREIGN KEY (state) REFERENCES public.instrument_conditions(condition) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3767 (class 2606 OID 16856)
-- Name: lost_and_found lost_and_found_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_and_found
    ADD CONSTRAINT lost_and_found_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE;


--
-- TOC entry 3760 (class 2606 OID 16804)
-- Name: repair_request repairs_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3761 (class 2606 OID 16809)
-- Name: requests requests_instrument_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_instrument_fkey FOREIGN KEY (instrument) REFERENCES public.equipment(description) NOT VALID;


--
-- TOC entry 3762 (class 2606 OID 16814)
-- Name: requests requests_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);


--
-- TOC entry 3763 (class 2606 OID 16819)
-- Name: resolve resolve_case_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_case_fkey FOREIGN KEY ("case") REFERENCES public.repair_request(id);


--
-- TOC entry 3764 (class 2606 OID 16919)
-- Name: returns returns_former_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_former_user_id FOREIGN KEY (former_user_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3765 (class 2606 OID 16824)
-- Name: returns returns_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3766 (class 2606 OID 16862)
-- Name: returns returns_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3754 (class 2606 OID 16829)
-- Name: users user_room_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT user_room_fk FOREIGN KEY (room) REFERENCES public.locations(room) ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3755 (class 2606 OID 16834)
-- Name: users users_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.roles(role_name);


--
-- TOC entry 3930 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


-- Completed on 2024-03-20 20:39:58 EAT

--
-- PostgreSQL database dump complete
--

