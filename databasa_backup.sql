--
-- PostgreSQL database dump
--

-- Dumped from database version 15.4
-- Dumped by pg_dump version 16.0

-- Started on 2024-02-13 11:10:29 EAT

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

CREATE SCHEMA "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";

--
-- TOC entry 3952 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA "public"; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA "public" IS 'standard public schema';


--
-- TOC entry 305 (class 1255 OID 22925)
-- Name: check_teacher_role(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."check_teacher_role"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF (SELECT role FROM users WHERE id = NEW.teacher_id) <> 'TEACHER' THEN
    RAISE EXCEPTION 'Teacher_id must correspond to a user with the role "TEACHER".';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_teacher_role"() OWNER TO "postgres";

--
-- TOC entry 324 (class 1255 OID 24774)
-- Name: dispatch(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."dispatch"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."dispatch"() OWNER TO "postgres";

--
-- TOC entry 313 (class 1255 OID 24759)
-- Name: get_division(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_division"("grade_level" character varying) RETURNS character varying
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."get_division"("grade_level" character varying) OWNER TO "postgres";

--
-- TOC entry 320 (class 1255 OID 25099)
-- Name: get_instruments_by_name(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_instruments_by_name"("p_name" character varying) RETURNS TABLE("description" "public"."citext", "make" "public"."citext", "number" integer, "username" character varying)
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    RETURN QUERY EXECUTE '
    SELECT description, make, number, user_name
    FROM all_instruments_view
    WHERE user_name ILIKE $1'
    USING '%' || p_name || '%';
END;
$_$;


ALTER FUNCTION "public"."get_instruments_by_name"("p_name" character varying) OWNER TO "postgres";

--
-- TOC entry 316 (class 1255 OID 25009)
-- Name: get_item_id_by_code(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_item_id_by_code"("p_code" character varying, "p_number" integer, OUT "item_id" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE code = p_code
    AND number = p_number;
END;
$$;


ALTER FUNCTION "public"."get_item_id_by_code"("p_code" character varying, "p_number" integer, OUT "item_id" integer) OWNER TO "postgres";

--
-- TOC entry 314 (class 1255 OID 25007)
-- Name: get_item_id_by_description(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_item_id_by_description"("p_description" character varying, "p_number" integer) RETURNS integer
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."get_item_id_by_description"("p_description" character varying, "p_number" integer) OWNER TO "postgres";

--
-- TOC entry 315 (class 1255 OID 25008)
-- Name: get_item_id_by_old_code(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_item_id_by_old_code"("p_code" character varying, "p_number" integer, OUT "item_id" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE legacy_code = p_code
    AND number = p_number;
END;
$$;


ALTER FUNCTION "public"."get_item_id_by_old_code"("p_code" character varying, "p_number" integer, OUT "item_id" integer) OWNER TO "postgres";

--
-- TOC entry 317 (class 1255 OID 25010)
-- Name: get_item_id_by_serial(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_item_id_by_serial"("p_serial" character varying, OUT "item_id" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE "serial" = p_serial;
END;
$$;


ALTER FUNCTION "public"."get_item_id_by_serial"("p_serial" character varying, OUT "item_id" integer) OWNER TO "postgres";

--
-- TOC entry 318 (class 1255 OID 25033)
-- Name: get_user_id_by_number(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."get_user_id_by_number"("p_number" character varying, OUT "user_id" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM all_users_view
    WHERE "number" = p_number;
END;
$$;


ALTER FUNCTION "public"."get_user_id_by_number"("p_number" character varying, OUT "user_id" integer) OWNER TO "postgres";

--
-- TOC entry 300 (class 1255 OID 22927)
-- Name: insert_type(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."insert_type"("p_code" character varying, "p_description" character varying) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO types (code, description) VALUES (UPPER(p_code), UPPER(p_description));
END;
$$;


ALTER FUNCTION "public"."insert_type"("p_code" character varying, "p_description" character varying) OWNER TO "postgres";

--
-- TOC entry 323 (class 1255 OID 24770)
-- Name: log_transaction(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."log_transaction"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    IF TG_TABLE_NAME = 'instruments' THEN
        -- Insert or update on the instruments table
        IF TG_OP = 'INSERT' THEN
            -- Instrument created
            INSERT INTO instrument_history (transaction_type, created_by, item_id)
            VALUES ('Instrument Created', CURRENT_USER, NEW.id);
        ELSIF TG_OP = 'UPDATE' THEN
            -- Instrument updated
            INSERT INTO instrument_history (transaction_type, created_by, item_id)
            VALUES ('Details Updated', CURRENT_USER, NEW.id);
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
END;$$;


ALTER FUNCTION "public"."log_transaction"() OWNER TO "postgres";

--
-- TOC entry 321 (class 1255 OID 24846)
-- Name: new_instr_function(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."new_instr_function"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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


ALTER FUNCTION "public"."new_instr_function"() OWNER TO "postgres";

--
-- TOC entry 322 (class 1255 OID 24779)
-- Name: return(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."return"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN
            -- Instrument returned
            UPDATE instruments
			SET "user_id" = NULL,
			location = 'INSTRUMENT STORE',
			user_name = NULL
			WHERE id = NEW.item_id;
		NEW.created_by = CURRENT_USER;
      
    RETURN NEW;
END;$$;


ALTER FUNCTION "public"."return"() OWNER TO "postgres";

--
-- TOC entry 319 (class 1255 OID 25048)
-- Name: search_user_by_name(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION "public"."search_user_by_name"("p_name" character varying, OUT "user_id" integer, OUT "full_name" "text", OUT "grade_level" character varying) RETURNS SETOF "record"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT all_users_view.id, all_users_view.full_name, all_users_view.grade_level
    FROM all_users_view
    WHERE all_users_view.full_name ILIKE '%' || p_name || '%';
END;
$$;


ALTER FUNCTION "public"."search_user_by_name"("p_name" character varying, OUT "user_id" integer, OUT "full_name" "text", OUT "grade_level" character varying) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- TOC entry 240 (class 1259 OID 24634)
-- Name: equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."equipment" (
    "id" integer NOT NULL,
    "family" "public"."citext" NOT NULL,
    "description" "public"."citext",
    "legacy_code" "public"."citext",
    "code" "public"."citext",
    "notes" character varying
);


ALTER TABLE "public"."equipment" OWNER TO "postgres";

--
-- TOC entry 239 (class 1259 OID 24633)
-- Name: all_instruments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."equipment" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."all_instruments_id_seq"
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

CREATE TABLE "public"."instruments" (
    "id" integer NOT NULL,
    "legacy_number" integer,
    "code" "public"."citext",
    "description" "public"."citext",
    "serial" "public"."citext",
    "state" character varying,
    "location" "public"."citext" DEFAULT 'INSTRUMENT STORE'::character varying,
    "make" "public"."citext",
    "model" "public"."citext",
    "legacy_code" "public"."citext",
    "number" integer,
    "user_name" "public"."citext",
    "user_id" integer,
    CONSTRAINT "instruments_state_check" CHECK ((("state")::"text" = ANY ((ARRAY['New'::character varying, 'Good'::character varying, 'Worn'::character varying, 'Damaged'::character varying, 'Write-off'::character varying])::"text"[])))
);


ALTER TABLE "public"."instruments" OWNER TO "postgres";

--
-- TOC entry 222 (class 1259 OID 24250)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."users" (
    "id" integer NOT NULL,
    "first_name" character varying NOT NULL,
    "last_name" character varying,
    "email" character varying,
    "role" character varying NOT NULL,
    "number" "public"."citext",
    "grade_level" character varying,
    "division" character varying
);


ALTER TABLE "public"."users" OWNER TO "postgres";

--
-- TOC entry 252 (class 1259 OID 24998)
-- Name: all_instruments_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW "public"."all_instruments_view" AS
 SELECT "instruments"."id",
    "instruments"."description",
    "instruments"."make",
    "instruments"."model",
    "instruments"."serial",
    "instruments"."legacy_code",
    "instruments"."code",
    "instruments"."number",
    "instruments"."location",
    (COALESCE(((("users"."first_name")::"text" || ' '::"text") || ("users"."last_name")::"text"), NULL::"text"))::character varying AS "user_name"
   FROM ("public"."instruments"
     LEFT JOIN "public"."users" ON (("instruments"."user_id" = "users"."id")))
  ORDER BY "instruments"."description", "instruments"."number";


ALTER VIEW "public"."all_instruments_view" OWNER TO "postgres";

--
-- TOC entry 254 (class 1259 OID 25035)
-- Name: all_users_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW "public"."all_users_view" AS
 SELECT "users"."id",
    "users"."role",
    "users"."division",
    "users"."grade_level",
    "users"."first_name",
    "users"."last_name",
    ((("users"."first_name")::"text" || ' '::"text") || ("users"."last_name")::"text") AS "full_name",
    "users"."number",
    "users"."email"
   FROM "public"."users"
  ORDER BY "users"."role", "users"."first_name";


ALTER VIEW "public"."all_users_view" OWNER TO "postgres";

--
-- TOC entry 224 (class 1259 OID 24265)
-- Name: class; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."class" (
    "id" integer NOT NULL,
    "teacher_id" integer NOT NULL,
    "class_name" character varying
);


ALTER TABLE "public"."class" OWNER TO "postgres";

--
-- TOC entry 223 (class 1259 OID 24264)
-- Name: class_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."class" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."class_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 253 (class 1259 OID 25003)
-- Name: dispatched_instruments_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW "public"."dispatched_instruments_view" AS
 SELECT "all_instruments_view"."description",
    "all_instruments_view"."number",
    "all_instruments_view"."make",
    "all_instruments_view"."serial",
    "all_instruments_view"."user_name"
   FROM "public"."all_instruments_view"
  WHERE ("all_instruments_view"."user_name" IS NOT NULL);


ALTER VIEW "public"."dispatched_instruments_view" OWNER TO "postgres";

--
-- TOC entry 226 (class 1259 OID 24280)
-- Name: dispatches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."dispatches" (
    "id" integer NOT NULL,
    "created_at" "date" DEFAULT CURRENT_DATE,
    "user_id" integer,
    "item_id" integer,
    "created_by" character varying
);


ALTER TABLE "public"."dispatches" OWNER TO "postgres";

--
-- TOC entry 225 (class 1259 OID 24279)
-- Name: dispatches_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."dispatches" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."dispatches_id_seq"
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

CREATE TABLE "public"."duplicate_instruments" (
    "id" integer NOT NULL,
    "number" integer NOT NULL,
    "legacy_number" integer,
    "family" character varying DEFAULT 'MISCELLANEOUS'::character varying NOT NULL,
    "equipment" character varying NOT NULL,
    "make" character varying,
    "model" character varying,
    "serial" character varying,
    "class" character varying,
    "year" character varying,
    "name" character varying,
    "school_storage" character varying DEFAULT 'Instrument Storage'::character varying,
    "return_2023" character varying
);


ALTER TABLE "public"."duplicate_instruments" OWNER TO "postgres";

--
-- TOC entry 243 (class 1259 OID 24656)
-- Name: duplicate_instruments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."duplicate_instruments" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."duplicate_instruments_id_seq"
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

CREATE TABLE "public"."hardware_and_equipment" (
    "id" integer NOT NULL,
    "family" "public"."citext" NOT NULL,
    "description" "public"."citext",
    "legacy_code" "public"."citext",
    "code" "public"."citext",
    "notes" character varying
);


ALTER TABLE "public"."hardware_and_equipment" OWNER TO "postgres";

--
-- TOC entry 245 (class 1259 OID 24680)
-- Name: hardware_and_equipment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."hardware_and_equipment" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."hardware_and_equipment_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 251 (class 1259 OID 24951)
-- Name: instrument_distribution_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW "public"."instrument_distribution_view" AS
 SELECT "subquery"."description",
    "subquery"."legacy_code",
    "subquery"."code",
    "subquery"."total",
    "subquery"."available",
    "subquery"."dispatched",
    "subquery"."ms_music",
    "subquery"."hs_music",
    "subquery"."upper_es_music",
    "subquery"."lower_es_music",
    (((((("subquery"."total" - COALESCE("subquery"."available", (0)::bigint)) - COALESCE("subquery"."ms_music", (0)::bigint)) - COALESCE("subquery"."hs_music", (0)::bigint)) - COALESCE("subquery"."upper_es_music", (0)::bigint)) - COALESCE("subquery"."lower_es_music", (0)::bigint)) - COALESCE("subquery"."dispatched", (0)::bigint)) AS "unknown_count"
   FROM ( SELECT "instruments"."description",
            "instruments"."legacy_code",
            "instruments"."code",
            "count"("instruments"."description") AS "total",
            "count"(
                CASE
                    WHEN ("instruments"."location" OPERATOR("public".=) 'INSTRUMENT STORE'::"public"."citext") THEN 1
                    ELSE NULL::integer
                END) AS "available",
            "count"(
                CASE
                    WHEN (("instruments"."user_id" IS NOT NULL) OR ("instruments"."user_name" IS NOT NULL)) THEN 1
                    ELSE NULL::integer
                END) AS "dispatched",
            "count"(
                CASE
                    WHEN ("instruments"."location" OPERATOR("public".=) 'MS MUSIC'::"public"."citext") THEN 1
                    ELSE NULL::integer
                END) AS "ms_music",
            "count"(
                CASE
                    WHEN ("instruments"."location" OPERATOR("public".=) 'HS MUSIC'::"public"."citext") THEN 1
                    ELSE NULL::integer
                END) AS "hs_music",
            "count"(
                CASE
                    WHEN ("instruments"."location" OPERATOR("public".=) 'UPPER ES MUSIC'::"public"."citext") THEN 1
                    ELSE NULL::integer
                END) AS "upper_es_music",
            "count"(
                CASE
                    WHEN ("instruments"."location" OPERATOR("public".=) 'LOWER ES MUSIC'::"public"."citext") THEN 1
                    ELSE NULL::integer
                END) AS "lower_es_music"
           FROM "public"."instruments"
          GROUP BY "instruments"."description", "instruments"."legacy_code", "instruments"."code") "subquery"
  ORDER BY "subquery"."total" DESC;


ALTER VIEW "public"."instrument_distribution_view" OWNER TO "postgres";

--
-- TOC entry 236 (class 1259 OID 24362)
-- Name: instrument_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."instrument_history" (
    "id" integer NOT NULL,
    "transaction_type" character varying NOT NULL,
    "transaction_timestamp" "date" DEFAULT CURRENT_DATE,
    "item_id" integer NOT NULL,
    "notes" "text",
    "assigned_to" character varying,
    "created_by" character varying
);


ALTER TABLE "public"."instrument_history" OWNER TO "postgres";

--
-- TOC entry 235 (class 1259 OID 24361)
-- Name: instrument_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."instrument_history" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."instrument_history_id_seq"
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

ALTER TABLE "public"."instruments" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."instruments_id_seq"
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

CREATE TABLE "public"."legacy_database" (
    "id" integer NOT NULL,
    "number" integer NOT NULL,
    "legacy_number" integer,
    "family" character varying DEFAULT 'MISCELLANEOUS'::character varying NOT NULL,
    "equipment" character varying NOT NULL,
    "make" character varying,
    "model" character varying,
    "serial" character varying,
    "class" character varying,
    "year" character varying,
    "full_name" character varying,
    "school_storage" character varying DEFAULT 'Instrument Storage'::character varying,
    "return_2023" character varying,
    "student_number" integer,
    "code" "public"."citext"
);


ALTER TABLE "public"."legacy_database" OWNER TO "postgres";

--
-- TOC entry 215 (class 1259 OID 23611)
-- Name: legacy_database_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."legacy_database" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."legacy_database_id_seq"
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

CREATE TABLE "public"."locations" (
    "room" "public"."citext" NOT NULL,
    "custodian" "public"."citext",
    "id" integer NOT NULL
);


ALTER TABLE "public"."locations" OWNER TO "postgres";

--
-- TOC entry 248 (class 1259 OID 24743)
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."locations" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."locations_id_seq"
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

CREATE TABLE "public"."music_instruments" (
    "id" integer NOT NULL,
    "family" "public"."citext" NOT NULL,
    "description" "public"."citext",
    "legacy_code" "public"."citext",
    "code" "public"."citext" NOT NULL,
    "notes" character varying,
    CONSTRAINT "music_instruments_family_check" CHECK (("upper"(("family")::"text") = ANY (ARRAY['STRING'::"text", 'WOODWIND'::"text", 'BRASS'::"text", 'PERCUSSION'::"text", 'MISCELLANEOUS'::"text", 'ELECTRIC'::"text", 'KEYBOARD'::"text"])))
);


ALTER TABLE "public"."music_instruments" OWNER TO "postgres";

--
-- TOC entry 241 (class 1259 OID 24645)
-- Name: music_instruments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."music_instruments" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."music_instruments_id_seq"
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

CREATE TABLE "public"."new_instrument" (
    "id" integer NOT NULL,
    "legacy_number" integer,
    "code" "public"."citext",
    "description" "public"."citext",
    "serial" "public"."citext",
    "state" character varying,
    "location" "public"."citext" DEFAULT 'INSTRUMENT STORE'::character varying,
    "make" "public"."citext",
    "model" "public"."citext",
    "legacy_code" "public"."citext",
    "number" integer,
    "user_name" "public"."citext",
    "user_id" integer,
    CONSTRAINT "instruments_state_check" CHECK ((("state")::"text" = ANY ((ARRAY['New'::character varying, 'Good'::character varying, 'Worn'::character varying, 'Damaged'::character varying, 'Write-off'::character varying])::"text"[])))
);


ALTER TABLE "public"."new_instrument" OWNER TO "postgres";

--
-- TOC entry 249 (class 1259 OID 24849)
-- Name: new_instrument_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."new_instrument" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."new_instrument_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 24313)
-- Name: repair_request; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."repair_request" (
    "id" integer NOT NULL,
    "created_at" "date" DEFAULT CURRENT_DATE,
    "item_id" integer,
    "complaint" "text" NOT NULL
);


ALTER TABLE "public"."repair_request" OWNER TO "postgres";

--
-- TOC entry 229 (class 1259 OID 24312)
-- Name: repairs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."repair_request" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."repairs_id_seq"
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

CREATE TABLE "public"."requests" (
    "id" integer NOT NULL,
    "created_at" "date" DEFAULT CURRENT_DATE,
    "teacher_id" integer,
    "instrument" "public"."citext" NOT NULL,
    "quantity" integer NOT NULL
);


ALTER TABLE "public"."requests" OWNER TO "postgres";

--
-- TOC entry 233 (class 1259 OID 24340)
-- Name: requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."requests" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."requests_id_seq"
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

CREATE TABLE "public"."resolve" (
    "id" integer NOT NULL,
    "created_at" "date" DEFAULT CURRENT_DATE,
    "case" integer,
    "notes" "text"
);


ALTER TABLE "public"."resolve" OWNER TO "postgres";

--
-- TOC entry 231 (class 1259 OID 24326)
-- Name: resolve_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."resolve" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."resolve_id_seq"
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

CREATE TABLE "public"."returns" (
    "id" integer NOT NULL,
    "created_at" "date" DEFAULT CURRENT_DATE,
    "item_id" integer,
    "created_by" character varying
);


ALTER TABLE "public"."returns" OWNER TO "postgres";

--
-- TOC entry 227 (class 1259 OID 24300)
-- Name: returns_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."returns" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."returns_id_seq"
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

CREATE TABLE "public"."roles" (
    "id" integer NOT NULL,
    "role_name" character varying DEFAULT 'STUDENT'::character varying
);


ALTER TABLE "public"."roles" OWNER TO "postgres";

--
-- TOC entry 219 (class 1259 OID 24237)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."roles" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."roles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 238 (class 1259 OID 24383)
-- Name: students; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "public"."students" (
    "id" integer NOT NULL,
    "student_number" integer NOT NULL,
    "last_name" character varying NOT NULL,
    "first_name" character varying NOT NULL,
    "full_name" character varying GENERATED ALWAYS AS (((("first_name")::"text" || ' '::"text") || ("last_name")::"text")) STORED,
    "grade_level" character varying NOT NULL,
    "parent1_email" character varying,
    "parent2_email" character varying,
    "division" "public"."citext",
    "class" "public"."citext",
    "email" character varying
);


ALTER TABLE "public"."students" OWNER TO "postgres";

--
-- TOC entry 237 (class 1259 OID 24382)
-- Name: students_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE "public"."students" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."students_id_seq"
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

ALTER TABLE "public"."users" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."users_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 3920 (class 0 OID 24265)
-- Dependencies: 224
-- Data for Name: class; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3922 (class 0 OID 24280)
-- Dependencies: 226
-- Data for Name: dispatches; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."dispatches" ("id", "created_at", "user_id", "item_id", "created_by") VALUES
	(19, '2024-01-31', 1072, 2129, 'postgres'),
	(23, '2024-01-31', 1072, 2129, 'postgres'),
	(24, '2024-02-01', 1072, 4166, 'postgres'),
	(25, '2024-02-01', 1072, 4166, 'postgres'),
	(26, '2024-02-01', 1072, 4166, NULL),
	(32, '2024-02-01', 1072, 4166, NULL),
	(35, '2024-02-01', 1072, 4166, 'postgres') ON CONFLICT DO NOTHING;


--
-- TOC entry 3940 (class 0 OID 24657)
-- Dependencies: 244
-- Data for Name: duplicate_instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."duplicate_instruments" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "name", "school_storage", "return_2023") VALUES
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
	(20, 31, 599, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '354121A', NULL, NULL, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."duplicate_instruments" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "name", "school_storage", "return_2023") VALUES
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
	(40, 41, 129, 'BRASS', 'TRUMPET, B FLAT', 'BACH', 'Stradivarius', '488350', NULL, NULL, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."duplicate_instruments" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "name", "school_storage", "return_2023") VALUES
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
	(60, 5, 412, 'WOODWIND', 'CLARINET, B FLAT', 'YAMAHA', NULL, 'J65449', NULL, NULL, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."duplicate_instruments" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "name", "school_storage", "return_2023") VALUES
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
	(80, 17, 511, 'WOODWIND', 'FLUTE', 'HUANG', NULL, 'Y-60', NULL, NULL, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."duplicate_instruments" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "name", "school_storage", "return_2023") VALUES
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
-- TOC entry 3936 (class 0 OID 24634)
-- Dependencies: 240
-- Data for Name: equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(23, 'BRASS', 'METALLOPHONE', NULL, 'MTL', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(50, 'ELECTRIC', 'AMPLIFIER, BASS', NULL, 'AMB', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(73, 'PERCUSSION', 'CLAVES', NULL, 'CLV', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(93, 'PERCUSSION', 'NAGARA (DRUM)', NULL, 'NGR', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(113, 'PERCUSSION', 'BELL TREE', NULL, 'BLR', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(54, 'SOUND', 'MIXER', NULL, 'MX', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(152, 'STRING', 'BANJO, 4-STRING', NULL, 'BJX', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(172, 'STRING', 'DULCIMER', NULL, 'DCM', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(192, 'STRING', 'GUITAR, ELECTRIC', NULL, 'GRE', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(232, 'STRING', 'UKULELE, 8-STRING TENOR', NULL, 'UKW', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(252, 'STRING', 'ZITHER, ALPINE (HARP ZITHER)', NULL, 'ZA', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(274, 'WOODWIND', 'ENGLISH HORN', NULL, 'CA', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(297, 'WOODWIND', 'PIPE ORGAN', NULL, 'PO', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(315, 'WOODWIND', 'SAXOPHONE', NULL, 'SX', NULL),
	(318, 'WOODWIND', 'SAXOPHONE, BASS', NULL, 'SXY', NULL),
	(319, 'WOODWIND', 'SAXOPHONE, C MELODY (TENOR IN C)', NULL, 'SXM', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(338, 'BRASS', 'TRUMPET, POCKET', 'TPP', 'TPP', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
	(339, 'BRASS', 'TUBA', 'T', 'TB', NULL),
	(340, 'WOODWIND', 'CLARINET, B FLAT', 'CL', 'CL', NULL),
	(341, 'WOODWIND', 'CLARINET, BASS', 'BCL', 'CLB', NULL),
	(342, 'WOODWIND', 'FLUTE', 'FL', 'FL', NULL),
	(343, 'WOODWIND', 'OBOE', 'OB', 'OB', NULL),
	(344, 'WOODWIND', 'PICCOLO', 'PC', 'PC', NULL),
	(345, 'WOODWIND', 'SAXOPHONE, ALTO', 'AX', 'SXA', NULL),
	(346, 'WOODWIND', 'SAXOPHONE, BARITONE', 'BX', 'SXB', NULL),
	(347, 'WOODWIND', 'SAXOPHONE, TENOR', 'TX', 'SXT', NULL),
	(348, 'STRING', 'DUMMY 1', NULL, 'DMMO', NULL) ON CONFLICT DO NOTHING;


--
-- TOC entry 3942 (class 0 OID 24681)
-- Dependencies: 246
-- Data for Name: hardware_and_equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."hardware_and_equipment" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
-- TOC entry 3932 (class 0 OID 24362)
-- Dependencies: 236
-- Data for Name: instrument_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(11, 'Instrument Created', '2024-02-01', 4163, NULL, NULL, 'postgres'),
	(12, 'Instrument Created', '2024-02-01', 4164, NULL, NULL, 'postgres'),
	(13, 'Instrument Created', '2024-02-01', 4165, NULL, NULL, 'postgres'),
	(14, 'Instrument Created', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(15, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(16, 'Instrument Out', '2024-02-01', 4166, NULL, '1072', 'postgres'),
	(17, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(18, 'Instrument Out', '2024-02-01', 4166, NULL, '1072', 'postgres'),
	(19, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(20, 'Instrument Out', '2024-02-01', 4166, NULL, '1072', 'postgres'),
	(21, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(22, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(23, 'Instrument Out', '2024-02-01', 4166, NULL, '1072', 'postgres'),
	(24, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(25, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(26, 'Instrument Out', '2024-02-01', 4166, NULL, '1072', 'postgres'),
	(27, 'Instrument Returned', '2024-02-01', 2129, NULL, NULL, 'postgres'),
	(28, 'Details Updated', '2024-02-01', 2129, NULL, NULL, 'postgres'),
	(29, 'Details Updated', '2024-02-01', 2129, NULL, NULL, 'postgres'),
	(30, 'Instrument Returned', '2024-02-01', 2129, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(31, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(32, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(33, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(34, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(35, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(36, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(37, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(38, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(39, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(40, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(41, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(42, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(43, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(44, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(45, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(46, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(47, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(48, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(49, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(50, 'Details Updated', '2024-02-01', 1894, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(51, 'Details Updated', '2024-02-01', 1895, NULL, NULL, 'postgres'),
	(52, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(53, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(54, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(55, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(56, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(57, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(58, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(59, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(60, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(61, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(62, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(63, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(64, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(65, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(66, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(67, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(68, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(69, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(70, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(71, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(72, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(73, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(74, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres'),
	(75, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(76, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(77, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(78, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(79, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(80, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(81, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(82, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(83, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(84, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(85, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(86, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(87, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(88, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(89, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(90, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(91, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(92, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(93, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(94, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(95, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(96, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(97, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(98, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(99, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(100, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(101, 'Details Updated', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(102, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(103, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(104, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(105, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(106, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(107, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(108, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(109, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(110, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(111, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(112, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(113, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(114, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(115, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(116, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(117, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(118, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(119, 'Details Updated', '2024-02-01', 1533, NULL, NULL, 'postgres'),
	(120, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(121, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(122, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(123, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(124, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(125, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(126, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(127, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(128, 'Details Updated', '2024-02-01', 1594, NULL, NULL, 'postgres'),
	(129, 'Details Updated', '2024-02-01', 1595, NULL, NULL, 'postgres'),
	(130, 'Details Updated', '2024-02-01', 1596, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(131, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(132, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(133, 'Details Updated', '2024-02-01', 1606, NULL, NULL, 'postgres'),
	(134, 'Details Updated', '2024-02-01', 1618, NULL, NULL, 'postgres'),
	(135, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(136, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(137, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(138, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(139, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(140, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(141, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(142, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(143, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(144, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(145, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(146, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(147, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(148, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(149, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(150, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(151, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(152, 'Details Updated', '2024-02-01', 1731, NULL, NULL, 'postgres'),
	(153, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(154, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(155, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(156, 'Details Updated', '2024-02-01', 2089, NULL, NULL, 'postgres'),
	(157, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(158, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(159, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(160, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(161, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(162, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(163, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(164, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(165, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(166, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(167, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(168, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(169, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(170, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(171, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(172, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(173, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(174, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(175, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(176, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(177, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(178, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(179, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(180, 'Details Updated', '2024-02-01', 2071, NULL, NULL, 'postgres'),
	(181, 'Details Updated', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(182, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(183, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(184, 'Details Updated', '2024-02-01', 2075, NULL, NULL, 'postgres'),
	(185, 'Details Updated', '2024-02-01', 2076, NULL, NULL, 'postgres'),
	(186, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(187, 'Details Updated', '2024-02-01', 1734, NULL, NULL, 'postgres'),
	(188, 'Details Updated', '2024-02-01', 1773, NULL, NULL, 'postgres'),
	(189, 'Details Updated', '2024-02-01', 1774, NULL, NULL, 'postgres'),
	(190, 'Details Updated', '2024-02-01', 1775, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(191, 'Details Updated', '2024-02-01', 1776, NULL, NULL, 'postgres'),
	(192, 'Details Updated', '2024-02-01', 1777, NULL, NULL, 'postgres'),
	(193, 'Details Updated', '2024-02-01', 1778, NULL, NULL, 'postgres'),
	(194, 'Details Updated', '2024-02-01', 1779, NULL, NULL, 'postgres'),
	(195, 'Details Updated', '2024-02-01', 1780, NULL, NULL, 'postgres'),
	(196, 'Details Updated', '2024-02-01', 1781, NULL, NULL, 'postgres'),
	(197, 'Details Updated', '2024-02-01', 1782, NULL, NULL, 'postgres'),
	(198, 'Details Updated', '2024-02-01', 1783, NULL, NULL, 'postgres'),
	(199, 'Details Updated', '2024-02-01', 1784, NULL, NULL, 'postgres'),
	(200, 'Details Updated', '2024-02-01', 1789, NULL, NULL, 'postgres'),
	(201, 'Details Updated', '2024-02-01', 1791, NULL, NULL, 'postgres'),
	(202, 'Details Updated', '2024-02-01', 1792, NULL, NULL, 'postgres'),
	(203, 'Details Updated', '2024-02-01', 1793, NULL, NULL, 'postgres'),
	(204, 'Details Updated', '2024-02-01', 1794, NULL, NULL, 'postgres'),
	(205, 'Details Updated', '2024-02-01', 1795, NULL, NULL, 'postgres'),
	(206, 'Details Updated', '2024-02-01', 1796, NULL, NULL, 'postgres'),
	(207, 'Details Updated', '2024-02-01', 1797, NULL, NULL, 'postgres'),
	(208, 'Details Updated', '2024-02-01', 1798, NULL, NULL, 'postgres'),
	(209, 'Details Updated', '2024-02-01', 1799, NULL, NULL, 'postgres'),
	(210, 'Details Updated', '2024-02-01', 1800, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(211, 'Details Updated', '2024-02-01', 1801, NULL, NULL, 'postgres'),
	(212, 'Details Updated', '2024-02-01', 1802, NULL, NULL, 'postgres'),
	(213, 'Details Updated', '2024-02-01', 1803, NULL, NULL, 'postgres'),
	(214, 'Details Updated', '2024-02-01', 1804, NULL, NULL, 'postgres'),
	(215, 'Details Updated', '2024-02-01', 1805, NULL, NULL, 'postgres'),
	(216, 'Details Updated', '2024-02-01', 1807, NULL, NULL, 'postgres'),
	(217, 'Details Updated', '2024-02-01', 1808, NULL, NULL, 'postgres'),
	(218, 'Details Updated', '2024-02-01', 1809, NULL, NULL, 'postgres'),
	(219, 'Details Updated', '2024-02-01', 1810, NULL, NULL, 'postgres'),
	(220, 'Details Updated', '2024-02-01', 1811, NULL, NULL, 'postgres'),
	(221, 'Details Updated', '2024-02-01', 1813, NULL, NULL, 'postgres'),
	(222, 'Details Updated', '2024-02-01', 1814, NULL, NULL, 'postgres'),
	(223, 'Details Updated', '2024-02-01', 1815, NULL, NULL, 'postgres'),
	(224, 'Details Updated', '2024-02-01', 1816, NULL, NULL, 'postgres'),
	(225, 'Details Updated', '2024-02-01', 1817, NULL, NULL, 'postgres'),
	(226, 'Details Updated', '2024-02-01', 1818, NULL, NULL, 'postgres'),
	(227, 'Details Updated', '2024-02-01', 1820, NULL, NULL, 'postgres'),
	(228, 'Details Updated', '2024-02-01', 1821, NULL, NULL, 'postgres'),
	(229, 'Details Updated', '2024-02-01', 1822, NULL, NULL, 'postgres'),
	(230, 'Details Updated', '2024-02-01', 1823, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(231, 'Details Updated', '2024-02-01', 1824, NULL, NULL, 'postgres'),
	(232, 'Details Updated', '2024-02-01', 1825, NULL, NULL, 'postgres'),
	(233, 'Details Updated', '2024-02-01', 1826, NULL, NULL, 'postgres'),
	(234, 'Details Updated', '2024-02-01', 1827, NULL, NULL, 'postgres'),
	(235, 'Details Updated', '2024-02-01', 1828, NULL, NULL, 'postgres'),
	(236, 'Details Updated', '2024-02-01', 1829, NULL, NULL, 'postgres'),
	(237, 'Details Updated', '2024-02-01', 1830, NULL, NULL, 'postgres'),
	(238, 'Details Updated', '2024-02-01', 1831, NULL, NULL, 'postgres'),
	(239, 'Details Updated', '2024-02-01', 1832, NULL, NULL, 'postgres'),
	(240, 'Details Updated', '2024-02-01', 1833, NULL, NULL, 'postgres'),
	(241, 'Details Updated', '2024-02-01', 1834, NULL, NULL, 'postgres'),
	(242, 'Details Updated', '2024-02-01', 1835, NULL, NULL, 'postgres'),
	(243, 'Details Updated', '2024-02-01', 1836, NULL, NULL, 'postgres'),
	(244, 'Details Updated', '2024-02-01', 1837, NULL, NULL, 'postgres'),
	(245, 'Details Updated', '2024-02-01', 1838, NULL, NULL, 'postgres'),
	(246, 'Details Updated', '2024-02-01', 1839, NULL, NULL, 'postgres'),
	(247, 'Details Updated', '2024-02-01', 1840, NULL, NULL, 'postgres'),
	(248, 'Details Updated', '2024-02-01', 1841, NULL, NULL, 'postgres'),
	(249, 'Details Updated', '2024-02-01', 1842, NULL, NULL, 'postgres'),
	(250, 'Details Updated', '2024-02-01', 1843, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(251, 'Details Updated', '2024-02-01', 1735, NULL, NULL, 'postgres'),
	(252, 'Details Updated', '2024-02-01', 1845, NULL, NULL, 'postgres'),
	(253, 'Details Updated', '2024-02-01', 1846, NULL, NULL, 'postgres'),
	(254, 'Details Updated', '2024-02-01', 1847, NULL, NULL, 'postgres'),
	(255, 'Details Updated', '2024-02-01', 1849, NULL, NULL, 'postgres'),
	(256, 'Details Updated', '2024-02-01', 1850, NULL, NULL, 'postgres'),
	(257, 'Details Updated', '2024-02-01', 1851, NULL, NULL, 'postgres'),
	(258, 'Details Updated', '2024-02-01', 1852, NULL, NULL, 'postgres'),
	(259, 'Details Updated', '2024-02-01', 1853, NULL, NULL, 'postgres'),
	(260, 'Details Updated', '2024-02-01', 1854, NULL, NULL, 'postgres'),
	(261, 'Details Updated', '2024-02-01', 1855, NULL, NULL, 'postgres'),
	(262, 'Details Updated', '2024-02-01', 1856, NULL, NULL, 'postgres'),
	(263, 'Details Updated', '2024-02-01', 1857, NULL, NULL, 'postgres'),
	(264, 'Details Updated', '2024-02-01', 1858, NULL, NULL, 'postgres'),
	(265, 'Details Updated', '2024-02-01', 1812, NULL, NULL, 'postgres'),
	(266, 'Details Updated', '2024-02-01', 1859, NULL, NULL, 'postgres'),
	(267, 'Details Updated', '2024-02-01', 1860, NULL, NULL, 'postgres'),
	(268, 'Details Updated', '2024-02-01', 1862, NULL, NULL, 'postgres'),
	(269, 'Details Updated', '2024-02-01', 1863, NULL, NULL, 'postgres'),
	(270, 'Details Updated', '2024-02-01', 1864, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(271, 'Details Updated', '2024-02-01', 1865, NULL, NULL, 'postgres'),
	(272, 'Details Updated', '2024-02-01', 1866, NULL, NULL, 'postgres'),
	(273, 'Details Updated', '2024-02-01', 1867, NULL, NULL, 'postgres'),
	(274, 'Details Updated', '2024-02-01', 1868, NULL, NULL, 'postgres'),
	(275, 'Details Updated', '2024-02-01', 1869, NULL, NULL, 'postgres'),
	(276, 'Details Updated', '2024-02-01', 1870, NULL, NULL, 'postgres'),
	(277, 'Details Updated', '2024-02-01', 1871, NULL, NULL, 'postgres'),
	(278, 'Details Updated', '2024-02-01', 1873, NULL, NULL, 'postgres'),
	(279, 'Details Updated', '2024-02-01', 1874, NULL, NULL, 'postgres'),
	(280, 'Details Updated', '2024-02-01', 1875, NULL, NULL, 'postgres'),
	(281, 'Details Updated', '2024-02-01', 1881, NULL, NULL, 'postgres'),
	(282, 'Details Updated', '2024-02-01', 1882, NULL, NULL, 'postgres'),
	(283, 'Details Updated', '2024-02-01', 1883, NULL, NULL, 'postgres'),
	(284, 'Details Updated', '2024-02-01', 1884, NULL, NULL, 'postgres'),
	(285, 'Details Updated', '2024-02-01', 1887, NULL, NULL, 'postgres'),
	(286, 'Details Updated', '2024-02-01', 1888, NULL, NULL, 'postgres'),
	(287, 'Details Updated', '2024-02-01', 1889, NULL, NULL, 'postgres'),
	(288, 'Details Updated', '2024-02-01', 1890, NULL, NULL, 'postgres'),
	(289, 'Details Updated', '2024-02-01', 1891, NULL, NULL, 'postgres'),
	(290, 'Details Updated', '2024-02-01', 1893, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(291, 'Details Updated', '2024-02-01', 1896, NULL, NULL, 'postgres'),
	(292, 'Details Updated', '2024-02-01', 1897, NULL, NULL, 'postgres'),
	(293, 'Details Updated', '2024-02-01', 1903, NULL, NULL, 'postgres'),
	(294, 'Details Updated', '2024-02-01', 1904, NULL, NULL, 'postgres'),
	(295, 'Details Updated', '2024-02-01', 1905, NULL, NULL, 'postgres'),
	(296, 'Details Updated', '2024-02-01', 1908, NULL, NULL, 'postgres'),
	(297, 'Details Updated', '2024-02-01', 1909, NULL, NULL, 'postgres'),
	(298, 'Details Updated', '2024-02-01', 1910, NULL, NULL, 'postgres'),
	(299, 'Details Updated', '2024-02-01', 1911, NULL, NULL, 'postgres'),
	(300, 'Details Updated', '2024-02-01', 1912, NULL, NULL, 'postgres'),
	(301, 'Details Updated', '2024-02-01', 1913, NULL, NULL, 'postgres'),
	(302, 'Details Updated', '2024-02-01', 1914, NULL, NULL, 'postgres'),
	(303, 'Details Updated', '2024-02-01', 1916, NULL, NULL, 'postgres'),
	(304, 'Details Updated', '2024-02-01', 1917, NULL, NULL, 'postgres'),
	(305, 'Details Updated', '2024-02-01', 1919, NULL, NULL, 'postgres'),
	(306, 'Details Updated', '2024-02-01', 1920, NULL, NULL, 'postgres'),
	(307, 'Details Updated', '2024-02-01', 1921, NULL, NULL, 'postgres'),
	(308, 'Details Updated', '2024-02-01', 1922, NULL, NULL, 'postgres'),
	(309, 'Details Updated', '2024-02-01', 1736, NULL, NULL, 'postgres'),
	(310, 'Details Updated', '2024-02-01', 1737, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(311, 'Details Updated', '2024-02-01', 1925, NULL, NULL, 'postgres'),
	(312, 'Details Updated', '2024-02-01', 1530, NULL, NULL, 'postgres'),
	(313, 'Details Updated', '2024-02-01', 1926, NULL, NULL, 'postgres'),
	(314, 'Details Updated', '2024-02-01', 1927, NULL, NULL, 'postgres'),
	(315, 'Details Updated', '2024-02-01', 1928, NULL, NULL, 'postgres'),
	(316, 'Details Updated', '2024-02-01', 1929, NULL, NULL, 'postgres'),
	(317, 'Details Updated', '2024-02-01', 1930, NULL, NULL, 'postgres'),
	(318, 'Details Updated', '2024-02-01', 1491, NULL, NULL, 'postgres'),
	(319, 'Details Updated', '2024-02-01', 1492, NULL, NULL, 'postgres'),
	(320, 'Details Updated', '2024-02-01', 1493, NULL, NULL, 'postgres'),
	(321, 'Details Updated', '2024-02-01', 1495, NULL, NULL, 'postgres'),
	(322, 'Details Updated', '2024-02-01', 1496, NULL, NULL, 'postgres'),
	(323, 'Details Updated', '2024-02-01', 1497, NULL, NULL, 'postgres'),
	(324, 'Details Updated', '2024-02-01', 1498, NULL, NULL, 'postgres'),
	(325, 'Details Updated', '2024-02-01', 1499, NULL, NULL, 'postgres'),
	(326, 'Details Updated', '2024-02-01', 1500, NULL, NULL, 'postgres'),
	(327, 'Details Updated', '2024-02-01', 1501, NULL, NULL, 'postgres'),
	(328, 'Details Updated', '2024-02-01', 1502, NULL, NULL, 'postgres'),
	(329, 'Details Updated', '2024-02-01', 1886, NULL, NULL, 'postgres'),
	(330, 'Details Updated', '2024-02-01', 1503, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(331, 'Details Updated', '2024-02-01', 1504, NULL, NULL, 'postgres'),
	(332, 'Details Updated', '2024-02-01', 1505, NULL, NULL, 'postgres'),
	(333, 'Details Updated', '2024-02-01', 1506, NULL, NULL, 'postgres'),
	(334, 'Details Updated', '2024-02-01', 1507, NULL, NULL, 'postgres'),
	(335, 'Details Updated', '2024-02-01', 1932, NULL, NULL, 'postgres'),
	(336, 'Details Updated', '2024-02-01', 1933, NULL, NULL, 'postgres'),
	(337, 'Details Updated', '2024-02-01', 1934, NULL, NULL, 'postgres'),
	(338, 'Details Updated', '2024-02-01', 1935, NULL, NULL, 'postgres'),
	(339, 'Details Updated', '2024-02-01', 1936, NULL, NULL, 'postgres'),
	(340, 'Details Updated', '2024-02-01', 1937, NULL, NULL, 'postgres'),
	(341, 'Details Updated', '2024-02-01', 1938, NULL, NULL, 'postgres'),
	(342, 'Details Updated', '2024-02-01', 1939, NULL, NULL, 'postgres'),
	(343, 'Details Updated', '2024-02-01', 1940, NULL, NULL, 'postgres'),
	(344, 'Details Updated', '2024-02-01', 1941, NULL, NULL, 'postgres'),
	(345, 'Details Updated', '2024-02-01', 1942, NULL, NULL, 'postgres'),
	(346, 'Details Updated', '2024-02-01', 1943, NULL, NULL, 'postgres'),
	(347, 'Details Updated', '2024-02-01', 1944, NULL, NULL, 'postgres'),
	(348, 'Details Updated', '2024-02-01', 1945, NULL, NULL, 'postgres'),
	(349, 'Details Updated', '2024-02-01', 1947, NULL, NULL, 'postgres'),
	(350, 'Details Updated', '2024-02-01', 1948, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(351, 'Details Updated', '2024-02-01', 1949, NULL, NULL, 'postgres'),
	(352, 'Details Updated', '2024-02-01', 1950, NULL, NULL, 'postgres'),
	(353, 'Details Updated', '2024-02-01', 1951, NULL, NULL, 'postgres'),
	(354, 'Details Updated', '2024-02-01', 1952, NULL, NULL, 'postgres'),
	(355, 'Details Updated', '2024-02-01', 1953, NULL, NULL, 'postgres'),
	(356, 'Details Updated', '2024-02-01', 1954, NULL, NULL, 'postgres'),
	(357, 'Details Updated', '2024-02-01', 1955, NULL, NULL, 'postgres'),
	(358, 'Details Updated', '2024-02-01', 1956, NULL, NULL, 'postgres'),
	(359, 'Details Updated', '2024-02-01', 1957, NULL, NULL, 'postgres'),
	(360, 'Details Updated', '2024-02-01', 1958, NULL, NULL, 'postgres'),
	(361, 'Details Updated', '2024-02-01', 1959, NULL, NULL, 'postgres'),
	(362, 'Details Updated', '2024-02-01', 1960, NULL, NULL, 'postgres'),
	(363, 'Details Updated', '2024-02-01', 1961, NULL, NULL, 'postgres'),
	(364, 'Details Updated', '2024-02-01', 1962, NULL, NULL, 'postgres'),
	(365, 'Details Updated', '2024-02-01', 1963, NULL, NULL, 'postgres'),
	(366, 'Details Updated', '2024-02-01', 1964, NULL, NULL, 'postgres'),
	(367, 'Details Updated', '2024-02-01', 1965, NULL, NULL, 'postgres'),
	(368, 'Details Updated', '2024-02-01', 1966, NULL, NULL, 'postgres'),
	(369, 'Details Updated', '2024-02-01', 1967, NULL, NULL, 'postgres'),
	(370, 'Details Updated', '2024-02-01', 1968, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(371, 'Details Updated', '2024-02-01', 1969, NULL, NULL, 'postgres'),
	(372, 'Details Updated', '2024-02-01', 1971, NULL, NULL, 'postgres'),
	(373, 'Details Updated', '2024-02-01', 1972, NULL, NULL, 'postgres'),
	(374, 'Details Updated', '2024-02-01', 1973, NULL, NULL, 'postgres'),
	(375, 'Details Updated', '2024-02-01', 1974, NULL, NULL, 'postgres'),
	(376, 'Details Updated', '2024-02-01', 1975, NULL, NULL, 'postgres'),
	(377, 'Details Updated', '2024-02-01', 1976, NULL, NULL, 'postgres'),
	(378, 'Details Updated', '2024-02-01', 1977, NULL, NULL, 'postgres'),
	(379, 'Details Updated', '2024-02-01', 1978, NULL, NULL, 'postgres'),
	(380, 'Details Updated', '2024-02-01', 1979, NULL, NULL, 'postgres'),
	(381, 'Details Updated', '2024-02-01', 1980, NULL, NULL, 'postgres'),
	(382, 'Details Updated', '2024-02-01', 1981, NULL, NULL, 'postgres'),
	(383, 'Details Updated', '2024-02-01', 4163, NULL, NULL, 'postgres'),
	(384, 'Details Updated', '2024-02-01', 1982, NULL, NULL, 'postgres'),
	(385, 'Details Updated', '2024-02-01', 1946, NULL, NULL, 'postgres'),
	(386, 'Details Updated', '2024-02-01', 1984, NULL, NULL, 'postgres'),
	(387, 'Details Updated', '2024-02-01', 1985, NULL, NULL, 'postgres'),
	(388, 'Details Updated', '2024-02-01', 1986, NULL, NULL, 'postgres'),
	(389, 'Details Updated', '2024-02-01', 1987, NULL, NULL, 'postgres'),
	(390, 'Details Updated', '2024-02-01', 1988, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(391, 'Details Updated', '2024-02-01', 1992, NULL, NULL, 'postgres'),
	(392, 'Details Updated', '2024-02-01', 1998, NULL, NULL, 'postgres'),
	(393, 'Details Updated', '2024-02-01', 2000, NULL, NULL, 'postgres'),
	(394, 'Details Updated', '2024-02-01', 2001, NULL, NULL, 'postgres'),
	(395, 'Details Updated', '2024-02-01', 2002, NULL, NULL, 'postgres'),
	(396, 'Details Updated', '2024-02-01', 2003, NULL, NULL, 'postgres'),
	(397, 'Details Updated', '2024-02-01', 2004, NULL, NULL, 'postgres'),
	(398, 'Details Updated', '2024-02-01', 2005, NULL, NULL, 'postgres'),
	(399, 'Details Updated', '2024-02-01', 2007, NULL, NULL, 'postgres'),
	(400, 'Details Updated', '2024-02-01', 2008, NULL, NULL, 'postgres'),
	(401, 'Details Updated', '2024-02-01', 2009, NULL, NULL, 'postgres'),
	(402, 'Details Updated', '2024-02-01', 2010, NULL, NULL, 'postgres'),
	(403, 'Details Updated', '2024-02-01', 2011, NULL, NULL, 'postgres'),
	(404, 'Details Updated', '2024-02-01', 2012, NULL, NULL, 'postgres'),
	(405, 'Details Updated', '2024-02-01', 2013, NULL, NULL, 'postgres'),
	(406, 'Details Updated', '2024-02-01', 2014, NULL, NULL, 'postgres'),
	(407, 'Details Updated', '2024-02-01', 2015, NULL, NULL, 'postgres'),
	(408, 'Details Updated', '2024-02-01', 2016, NULL, NULL, 'postgres'),
	(409, 'Details Updated', '2024-02-01', 2017, NULL, NULL, 'postgres'),
	(410, 'Details Updated', '2024-02-01', 2018, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(411, 'Details Updated', '2024-02-01', 2019, NULL, NULL, 'postgres'),
	(412, 'Details Updated', '2024-02-01', 2020, NULL, NULL, 'postgres'),
	(413, 'Details Updated', '2024-02-01', 2021, NULL, NULL, 'postgres'),
	(414, 'Details Updated', '2024-02-01', 2022, NULL, NULL, 'postgres'),
	(415, 'Details Updated', '2024-02-01', 2023, NULL, NULL, 'postgres'),
	(416, 'Details Updated', '2024-02-01', 2024, NULL, NULL, 'postgres'),
	(417, 'Details Updated', '2024-02-01', 2025, NULL, NULL, 'postgres'),
	(418, 'Details Updated', '2024-02-01', 2026, NULL, NULL, 'postgres'),
	(419, 'Details Updated', '2024-02-01', 2027, NULL, NULL, 'postgres'),
	(420, 'Details Updated', '2024-02-01', 2030, NULL, NULL, 'postgres'),
	(421, 'Details Updated', '2024-02-01', 1494, NULL, NULL, 'postgres'),
	(422, 'Details Updated', '2024-02-01', 2032, NULL, NULL, 'postgres'),
	(423, 'Details Updated', '2024-02-01', 2033, NULL, NULL, 'postgres'),
	(424, 'Details Updated', '2024-02-01', 2034, NULL, NULL, 'postgres'),
	(425, 'Details Updated', '2024-02-01', 2035, NULL, NULL, 'postgres'),
	(426, 'Details Updated', '2024-02-01', 2036, NULL, NULL, 'postgres'),
	(427, 'Details Updated', '2024-02-01', 2037, NULL, NULL, 'postgres'),
	(428, 'Details Updated', '2024-02-01', 2038, NULL, NULL, 'postgres'),
	(429, 'Details Updated', '2024-02-01', 2039, NULL, NULL, 'postgres'),
	(430, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(431, 'Details Updated', '2024-02-01', 4164, NULL, NULL, 'postgres'),
	(432, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(433, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(434, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(435, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(436, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(437, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(438, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(439, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(440, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(441, 'Details Updated', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(442, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(443, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(444, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(445, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(446, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(447, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(448, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(449, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(450, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(451, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(452, 'Details Updated', '2024-02-01', 1742, NULL, NULL, 'postgres'),
	(453, 'Details Updated', '2024-02-01', 1745, NULL, NULL, 'postgres'),
	(454, 'Details Updated', '2024-02-01', 1747, NULL, NULL, 'postgres'),
	(455, 'Details Updated', '2024-02-01', 1748, NULL, NULL, 'postgres'),
	(456, 'Details Updated', '2024-02-01', 1749, NULL, NULL, 'postgres'),
	(457, 'Details Updated', '2024-02-01', 1750, NULL, NULL, 'postgres'),
	(458, 'Details Updated', '2024-02-01', 1753, NULL, NULL, 'postgres'),
	(459, 'Details Updated', '2024-02-01', 1758, NULL, NULL, 'postgres'),
	(460, 'Details Updated', '2024-02-01', 1759, NULL, NULL, 'postgres'),
	(461, 'Details Updated', '2024-02-01', 1760, NULL, NULL, 'postgres'),
	(462, 'Details Updated', '2024-02-01', 1761, NULL, NULL, 'postgres'),
	(463, 'Details Updated', '2024-02-01', 1762, NULL, NULL, 'postgres'),
	(464, 'Details Updated', '2024-02-01', 1763, NULL, NULL, 'postgres'),
	(465, 'Details Updated', '2024-02-01', 1764, NULL, NULL, 'postgres'),
	(466, 'Details Updated', '2024-02-01', 1765, NULL, NULL, 'postgres'),
	(467, 'Details Updated', '2024-02-01', 1766, NULL, NULL, 'postgres'),
	(468, 'Details Updated', '2024-02-01', 1767, NULL, NULL, 'postgres'),
	(469, 'Details Updated', '2024-02-01', 1769, NULL, NULL, 'postgres'),
	(470, 'Details Updated', '2024-02-01', 1770, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(471, 'Details Updated', '2024-02-01', 1771, NULL, NULL, 'postgres'),
	(472, 'Details Updated', '2024-02-01', 1772, NULL, NULL, 'postgres'),
	(473, 'Details Updated', '2024-02-01', 2064, NULL, NULL, 'postgres'),
	(474, 'Details Updated', '2024-02-01', 2061, NULL, NULL, 'postgres'),
	(475, 'Details Updated', '2024-02-01', 2065, NULL, NULL, 'postgres'),
	(476, 'Details Updated', '2024-02-01', 4165, NULL, NULL, 'postgres'),
	(477, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(478, 'Details Updated', '2024-02-01', 2129, NULL, NULL, 'postgres'),
	(479, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(480, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(481, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(482, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(483, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(484, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(485, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(486, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(487, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(488, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(489, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(490, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(491, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(492, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(493, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(494, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(495, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(496, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(497, 'Details Updated', '2024-02-01', 1894, NULL, NULL, 'postgres'),
	(498, 'Details Updated', '2024-02-01', 1895, NULL, NULL, 'postgres'),
	(499, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(500, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(501, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(502, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(503, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(504, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(505, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(506, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(507, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(508, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(509, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(510, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(511, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(512, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(513, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(514, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(515, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(516, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(517, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(518, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(519, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(520, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres'),
	(521, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(522, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(523, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(524, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(525, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(526, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(527, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(528, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(529, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(530, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(531, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(532, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(533, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(534, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(535, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(536, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(537, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(538, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(539, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(540, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(541, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(542, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(543, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(544, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(545, 'Details Updated', '2024-02-01', 1594, NULL, NULL, 'postgres'),
	(546, 'Details Updated', '2024-02-01', 1595, NULL, NULL, 'postgres'),
	(547, 'Details Updated', '2024-02-01', 1596, NULL, NULL, 'postgres'),
	(548, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(549, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(550, 'Details Updated', '2024-02-01', 1606, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(551, 'Details Updated', '2024-02-01', 1618, NULL, NULL, 'postgres'),
	(552, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(553, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(554, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(555, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(556, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(557, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(558, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(559, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(560, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(561, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(562, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(563, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(564, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(565, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(566, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(567, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(568, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(569, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(570, 'Details Updated', '2024-02-01', 1582, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(571, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(572, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(573, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(574, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(575, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(576, 'Details Updated', '2024-02-01', 1533, NULL, NULL, 'postgres'),
	(577, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(578, 'Details Updated', '2024-02-01', 1511, NULL, NULL, 'postgres'),
	(579, 'Details Updated', '2024-02-01', 1512, NULL, NULL, 'postgres'),
	(580, 'Details Updated', '2024-02-01', 1513, NULL, NULL, 'postgres'),
	(581, 'Details Updated', '2024-02-01', 1514, NULL, NULL, 'postgres'),
	(582, 'Details Updated', '2024-02-01', 1515, NULL, NULL, 'postgres'),
	(583, 'Details Updated', '2024-02-01', 1516, NULL, NULL, 'postgres'),
	(584, 'Details Updated', '2024-02-01', 1517, NULL, NULL, 'postgres'),
	(585, 'Details Updated', '2024-02-01', 1518, NULL, NULL, 'postgres'),
	(586, 'Details Updated', '2024-02-01', 1519, NULL, NULL, 'postgres'),
	(587, 'Details Updated', '2024-02-01', 1520, NULL, NULL, 'postgres'),
	(588, 'Details Updated', '2024-02-01', 1521, NULL, NULL, 'postgres'),
	(589, 'Details Updated', '2024-02-01', 1522, NULL, NULL, 'postgres'),
	(590, 'Details Updated', '2024-02-01', 1523, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(591, 'Details Updated', '2024-02-01', 1931, NULL, NULL, 'postgres'),
	(592, 'Details Updated', '2024-02-01', 1524, NULL, NULL, 'postgres'),
	(593, 'Details Updated', '2024-02-01', 1525, NULL, NULL, 'postgres'),
	(594, 'Details Updated', '2024-02-01', 1526, NULL, NULL, 'postgres'),
	(595, 'Details Updated', '2024-02-01', 1527, NULL, NULL, 'postgres'),
	(596, 'Details Updated', '2024-02-01', 1528, NULL, NULL, 'postgres'),
	(597, 'Details Updated', '2024-02-01', 1529, NULL, NULL, 'postgres'),
	(598, 'Details Updated', '2024-02-01', 1532, NULL, NULL, 'postgres'),
	(599, 'Details Updated', '2024-02-01', 1534, NULL, NULL, 'postgres'),
	(600, 'Details Updated', '2024-02-01', 1535, NULL, NULL, 'postgres'),
	(601, 'Details Updated', '2024-02-01', 1536, NULL, NULL, 'postgres'),
	(602, 'Details Updated', '2024-02-01', 1537, NULL, NULL, 'postgres'),
	(603, 'Details Updated', '2024-02-01', 1538, NULL, NULL, 'postgres'),
	(604, 'Details Updated', '2024-02-01', 1539, NULL, NULL, 'postgres'),
	(605, 'Details Updated', '2024-02-01', 1540, NULL, NULL, 'postgres'),
	(606, 'Details Updated', '2024-02-01', 1541, NULL, NULL, 'postgres'),
	(607, 'Details Updated', '2024-02-01', 1542, NULL, NULL, 'postgres'),
	(608, 'Details Updated', '2024-02-01', 1543, NULL, NULL, 'postgres'),
	(609, 'Details Updated', '2024-02-01', 1544, NULL, NULL, 'postgres'),
	(610, 'Details Updated', '2024-02-01', 1545, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(611, 'Details Updated', '2024-02-01', 1546, NULL, NULL, 'postgres'),
	(612, 'Details Updated', '2024-02-01', 1547, NULL, NULL, 'postgres'),
	(613, 'Details Updated', '2024-02-01', 1548, NULL, NULL, 'postgres'),
	(614, 'Details Updated', '2024-02-01', 1549, NULL, NULL, 'postgres'),
	(615, 'Details Updated', '2024-02-01', 1551, NULL, NULL, 'postgres'),
	(616, 'Details Updated', '2024-02-01', 1552, NULL, NULL, 'postgres'),
	(617, 'Details Updated', '2024-02-01', 1553, NULL, NULL, 'postgres'),
	(618, 'Details Updated', '2024-02-01', 1554, NULL, NULL, 'postgres'),
	(619, 'Details Updated', '2024-02-01', 1555, NULL, NULL, 'postgres'),
	(620, 'Details Updated', '2024-02-01', 1556, NULL, NULL, 'postgres'),
	(621, 'Details Updated', '2024-02-01', 1557, NULL, NULL, 'postgres'),
	(622, 'Details Updated', '2024-02-01', 1558, NULL, NULL, 'postgres'),
	(623, 'Details Updated', '2024-02-01', 1559, NULL, NULL, 'postgres'),
	(624, 'Details Updated', '2024-02-01', 1560, NULL, NULL, 'postgres'),
	(625, 'Details Updated', '2024-02-01', 1561, NULL, NULL, 'postgres'),
	(626, 'Details Updated', '2024-02-01', 1562, NULL, NULL, 'postgres'),
	(627, 'Details Updated', '2024-02-01', 1563, NULL, NULL, 'postgres'),
	(628, 'Details Updated', '2024-02-01', 1564, NULL, NULL, 'postgres'),
	(629, 'Details Updated', '2024-02-01', 1567, NULL, NULL, 'postgres'),
	(630, 'Details Updated', '2024-02-01', 1568, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(631, 'Details Updated', '2024-02-01', 1569, NULL, NULL, 'postgres'),
	(632, 'Details Updated', '2024-02-01', 1571, NULL, NULL, 'postgres'),
	(633, 'Details Updated', '2024-02-01', 1572, NULL, NULL, 'postgres'),
	(634, 'Details Updated', '2024-02-01', 1573, NULL, NULL, 'postgres'),
	(635, 'Details Updated', '2024-02-01', 1574, NULL, NULL, 'postgres'),
	(636, 'Details Updated', '2024-02-01', 1575, NULL, NULL, 'postgres'),
	(637, 'Details Updated', '2024-02-01', 1576, NULL, NULL, 'postgres'),
	(638, 'Details Updated', '2024-02-01', 1577, NULL, NULL, 'postgres'),
	(639, 'Details Updated', '2024-02-01', 1578, NULL, NULL, 'postgres'),
	(640, 'Details Updated', '2024-02-01', 1579, NULL, NULL, 'postgres'),
	(641, 'Details Updated', '2024-02-01', 1580, NULL, NULL, 'postgres'),
	(642, 'Details Updated', '2024-02-01', 1581, NULL, NULL, 'postgres'),
	(643, 'Details Updated', '2024-02-01', 1583, NULL, NULL, 'postgres'),
	(644, 'Details Updated', '2024-02-01', 1584, NULL, NULL, 'postgres'),
	(645, 'Details Updated', '2024-02-01', 1585, NULL, NULL, 'postgres'),
	(646, 'Details Updated', '2024-02-01', 1586, NULL, NULL, 'postgres'),
	(647, 'Details Updated', '2024-02-01', 1587, NULL, NULL, 'postgres'),
	(648, 'Details Updated', '2024-02-01', 1589, NULL, NULL, 'postgres'),
	(649, 'Details Updated', '2024-02-01', 1590, NULL, NULL, 'postgres'),
	(650, 'Details Updated', '2024-02-01', 1591, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(651, 'Details Updated', '2024-02-01', 1597, NULL, NULL, 'postgres'),
	(652, 'Details Updated', '2024-02-01', 1599, NULL, NULL, 'postgres'),
	(653, 'Details Updated', '2024-02-01', 1600, NULL, NULL, 'postgres'),
	(654, 'Details Updated', '2024-02-01', 1601, NULL, NULL, 'postgres'),
	(655, 'Details Updated', '2024-02-01', 1602, NULL, NULL, 'postgres'),
	(656, 'Details Updated', '2024-02-01', 1604, NULL, NULL, 'postgres'),
	(657, 'Details Updated', '2024-02-01', 1605, NULL, NULL, 'postgres'),
	(658, 'Details Updated', '2024-02-01', 1607, NULL, NULL, 'postgres'),
	(659, 'Details Updated', '2024-02-01', 1608, NULL, NULL, 'postgres'),
	(660, 'Details Updated', '2024-02-01', 1609, NULL, NULL, 'postgres'),
	(661, 'Details Updated', '2024-02-01', 1610, NULL, NULL, 'postgres'),
	(662, 'Details Updated', '2024-02-01', 1611, NULL, NULL, 'postgres'),
	(663, 'Details Updated', '2024-02-01', 1612, NULL, NULL, 'postgres'),
	(664, 'Details Updated', '2024-02-01', 1613, NULL, NULL, 'postgres'),
	(665, 'Details Updated', '2024-02-01', 1614, NULL, NULL, 'postgres'),
	(666, 'Details Updated', '2024-02-01', 1615, NULL, NULL, 'postgres'),
	(667, 'Details Updated', '2024-02-01', 1616, NULL, NULL, 'postgres'),
	(668, 'Details Updated', '2024-02-01', 1617, NULL, NULL, 'postgres'),
	(669, 'Details Updated', '2024-02-01', 1619, NULL, NULL, 'postgres'),
	(670, 'Details Updated', '2024-02-01', 1620, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(671, 'Details Updated', '2024-02-01', 1622, NULL, NULL, 'postgres'),
	(672, 'Details Updated', '2024-02-01', 1623, NULL, NULL, 'postgres'),
	(673, 'Details Updated', '2024-02-01', 1624, NULL, NULL, 'postgres'),
	(674, 'Details Updated', '2024-02-01', 1625, NULL, NULL, 'postgres'),
	(675, 'Details Updated', '2024-02-01', 1626, NULL, NULL, 'postgres'),
	(676, 'Details Updated', '2024-02-01', 1627, NULL, NULL, 'postgres'),
	(677, 'Details Updated', '2024-02-01', 1628, NULL, NULL, 'postgres'),
	(678, 'Details Updated', '2024-02-01', 1629, NULL, NULL, 'postgres'),
	(679, 'Details Updated', '2024-02-01', 1630, NULL, NULL, 'postgres'),
	(680, 'Details Updated', '2024-02-01', 1631, NULL, NULL, 'postgres'),
	(681, 'Details Updated', '2024-02-01', 1632, NULL, NULL, 'postgres'),
	(682, 'Details Updated', '2024-02-01', 1633, NULL, NULL, 'postgres'),
	(683, 'Details Updated', '2024-02-01', 1634, NULL, NULL, 'postgres'),
	(684, 'Details Updated', '2024-02-01', 1635, NULL, NULL, 'postgres'),
	(685, 'Details Updated', '2024-02-01', 1636, NULL, NULL, 'postgres'),
	(686, 'Details Updated', '2024-02-01', 1637, NULL, NULL, 'postgres'),
	(687, 'Details Updated', '2024-02-01', 1638, NULL, NULL, 'postgres'),
	(688, 'Details Updated', '2024-02-01', 1639, NULL, NULL, 'postgres'),
	(689, 'Details Updated', '2024-02-01', 1640, NULL, NULL, 'postgres'),
	(690, 'Details Updated', '2024-02-01', 1641, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(691, 'Details Updated', '2024-02-01', 1642, NULL, NULL, 'postgres'),
	(692, 'Details Updated', '2024-02-01', 1643, NULL, NULL, 'postgres'),
	(693, 'Details Updated', '2024-02-01', 1644, NULL, NULL, 'postgres'),
	(694, 'Details Updated', '2024-02-01', 1645, NULL, NULL, 'postgres'),
	(695, 'Details Updated', '2024-02-01', 1646, NULL, NULL, 'postgres'),
	(696, 'Details Updated', '2024-02-01', 1647, NULL, NULL, 'postgres'),
	(697, 'Details Updated', '2024-02-01', 1648, NULL, NULL, 'postgres'),
	(698, 'Details Updated', '2024-02-01', 1649, NULL, NULL, 'postgres'),
	(699, 'Details Updated', '2024-02-01', 1650, NULL, NULL, 'postgres'),
	(700, 'Details Updated', '2024-02-01', 1651, NULL, NULL, 'postgres'),
	(701, 'Details Updated', '2024-02-01', 1652, NULL, NULL, 'postgres'),
	(702, 'Details Updated', '2024-02-01', 1653, NULL, NULL, 'postgres'),
	(703, 'Details Updated', '2024-02-01', 1654, NULL, NULL, 'postgres'),
	(704, 'Details Updated', '2024-02-01', 1655, NULL, NULL, 'postgres'),
	(705, 'Details Updated', '2024-02-01', 1656, NULL, NULL, 'postgres'),
	(706, 'Details Updated', '2024-02-01', 1657, NULL, NULL, 'postgres'),
	(707, 'Details Updated', '2024-02-01', 1658, NULL, NULL, 'postgres'),
	(708, 'Details Updated', '2024-02-01', 1659, NULL, NULL, 'postgres'),
	(709, 'Details Updated', '2024-02-01', 1660, NULL, NULL, 'postgres'),
	(710, 'Details Updated', '2024-02-01', 1661, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(711, 'Details Updated', '2024-02-01', 1662, NULL, NULL, 'postgres'),
	(712, 'Details Updated', '2024-02-01', 1663, NULL, NULL, 'postgres'),
	(713, 'Details Updated', '2024-02-01', 1664, NULL, NULL, 'postgres'),
	(714, 'Details Updated', '2024-02-01', 1665, NULL, NULL, 'postgres'),
	(715, 'Details Updated', '2024-02-01', 1675, NULL, NULL, 'postgres'),
	(716, 'Details Updated', '2024-02-01', 1676, NULL, NULL, 'postgres'),
	(717, 'Details Updated', '2024-02-01', 1677, NULL, NULL, 'postgres'),
	(718, 'Details Updated', '2024-02-01', 1678, NULL, NULL, 'postgres'),
	(719, 'Details Updated', '2024-02-01', 1679, NULL, NULL, 'postgres'),
	(720, 'Details Updated', '2024-02-01', 1680, NULL, NULL, 'postgres'),
	(721, 'Details Updated', '2024-02-01', 1681, NULL, NULL, 'postgres'),
	(722, 'Details Updated', '2024-02-01', 1682, NULL, NULL, 'postgres'),
	(723, 'Details Updated', '2024-02-01', 1683, NULL, NULL, 'postgres'),
	(724, 'Details Updated', '2024-02-01', 1684, NULL, NULL, 'postgres'),
	(725, 'Details Updated', '2024-02-01', 1685, NULL, NULL, 'postgres'),
	(726, 'Details Updated', '2024-02-01', 1686, NULL, NULL, 'postgres'),
	(727, 'Details Updated', '2024-02-01', 1687, NULL, NULL, 'postgres'),
	(728, 'Details Updated', '2024-02-01', 1688, NULL, NULL, 'postgres'),
	(729, 'Details Updated', '2024-02-01', 1689, NULL, NULL, 'postgres'),
	(730, 'Details Updated', '2024-02-01', 1690, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(731, 'Details Updated', '2024-02-01', 1691, NULL, NULL, 'postgres'),
	(732, 'Details Updated', '2024-02-01', 1666, NULL, NULL, 'postgres'),
	(733, 'Details Updated', '2024-02-01', 1692, NULL, NULL, 'postgres'),
	(734, 'Details Updated', '2024-02-01', 1693, NULL, NULL, 'postgres'),
	(735, 'Details Updated', '2024-02-01', 1694, NULL, NULL, 'postgres'),
	(736, 'Details Updated', '2024-02-01', 1695, NULL, NULL, 'postgres'),
	(737, 'Details Updated', '2024-02-01', 1696, NULL, NULL, 'postgres'),
	(738, 'Details Updated', '2024-02-01', 1697, NULL, NULL, 'postgres'),
	(739, 'Details Updated', '2024-02-01', 1705, NULL, NULL, 'postgres'),
	(740, 'Details Updated', '2024-02-01', 1707, NULL, NULL, 'postgres'),
	(741, 'Details Updated', '2024-02-01', 1708, NULL, NULL, 'postgres'),
	(742, 'Details Updated', '2024-02-01', 1709, NULL, NULL, 'postgres'),
	(743, 'Details Updated', '2024-02-01', 1711, NULL, NULL, 'postgres'),
	(744, 'Details Updated', '2024-02-01', 1717, NULL, NULL, 'postgres'),
	(745, 'Details Updated', '2024-02-01', 1719, NULL, NULL, 'postgres'),
	(746, 'Details Updated', '2024-02-01', 1720, NULL, NULL, 'postgres'),
	(747, 'Details Updated', '2024-02-01', 1721, NULL, NULL, 'postgres'),
	(748, 'Details Updated', '2024-02-01', 1722, NULL, NULL, 'postgres'),
	(749, 'Details Updated', '2024-02-01', 1723, NULL, NULL, 'postgres'),
	(750, 'Details Updated', '2024-02-01', 1724, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(751, 'Details Updated', '2024-02-01', 1725, NULL, NULL, 'postgres'),
	(752, 'Details Updated', '2024-02-01', 1726, NULL, NULL, 'postgres'),
	(753, 'Details Updated', '2024-02-01', 1727, NULL, NULL, 'postgres'),
	(754, 'Details Updated', '2024-02-01', 1728, NULL, NULL, 'postgres'),
	(755, 'Details Updated', '2024-02-01', 1729, NULL, NULL, 'postgres'),
	(756, 'Details Updated', '2024-02-01', 1730, NULL, NULL, 'postgres'),
	(757, 'Details Updated', '2024-02-01', 1508, NULL, NULL, 'postgres'),
	(758, 'Details Updated', '2024-02-01', 1509, NULL, NULL, 'postgres'),
	(759, 'Details Updated', '2024-02-01', 1510, NULL, NULL, 'postgres'),
	(760, 'Details Updated', '2024-02-01', 1752, NULL, NULL, 'postgres'),
	(761, 'Details Updated', '2024-02-01', 1732, NULL, NULL, 'postgres'),
	(762, 'Details Updated', '2024-02-01', 2090, NULL, NULL, 'postgres'),
	(763, 'Details Updated', '2024-02-01', 2091, NULL, NULL, 'postgres'),
	(764, 'Details Updated', '2024-02-01', 2079, NULL, NULL, 'postgres'),
	(765, 'Details Updated', '2024-02-01', 2081, NULL, NULL, 'postgres'),
	(766, 'Details Updated', '2024-02-01', 2082, NULL, NULL, 'postgres'),
	(767, 'Details Updated', '2024-02-01', 2083, NULL, NULL, 'postgres'),
	(768, 'Details Updated', '2024-02-01', 2084, NULL, NULL, 'postgres'),
	(769, 'Details Updated', '2024-02-01', 2085, NULL, NULL, 'postgres'),
	(770, 'Details Updated', '2024-02-01', 2086, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(771, 'Details Updated', '2024-02-01', 2087, NULL, NULL, 'postgres'),
	(772, 'Details Updated', '2024-02-01', 2088, NULL, NULL, 'postgres'),
	(773, 'Details Updated', '2024-02-01', 1731, NULL, NULL, 'postgres'),
	(774, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(775, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(776, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(777, 'Details Updated', '2024-02-01', 2089, NULL, NULL, 'postgres'),
	(778, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(779, 'Details Updated', '2024-02-01', 1667, NULL, NULL, 'postgres'),
	(780, 'Details Updated', '2024-02-01', 1751, NULL, NULL, 'postgres'),
	(781, 'Details Updated', '2024-02-01', 1898, NULL, NULL, 'postgres'),
	(782, 'Details Updated', '2024-02-01', 1907, NULL, NULL, 'postgres'),
	(783, 'Details Updated', '2024-02-01', 2062, NULL, NULL, 'postgres'),
	(784, 'Details Updated', '2024-02-01', 1668, NULL, NULL, 'postgres'),
	(785, 'Details Updated', '2024-02-01', 1669, NULL, NULL, 'postgres'),
	(786, 'Details Updated', '2024-02-01', 1670, NULL, NULL, 'postgres'),
	(787, 'Details Updated', '2024-02-01', 1671, NULL, NULL, 'postgres'),
	(788, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(789, 'Details Updated', '2024-02-01', 1673, NULL, NULL, 'postgres'),
	(790, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(791, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(792, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(793, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(794, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(795, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(796, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(797, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(798, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(799, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(800, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(801, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(802, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(803, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(804, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(805, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(806, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(807, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(808, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(809, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(810, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(811, 'Details Updated', '2024-02-01', 2071, NULL, NULL, 'postgres'),
	(812, 'Details Updated', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(813, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(814, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(815, 'Details Updated', '2024-02-01', 2075, NULL, NULL, 'postgres'),
	(816, 'Details Updated', '2024-02-01', 2076, NULL, NULL, 'postgres'),
	(817, 'Details Updated', '2024-02-01', 2068, NULL, NULL, 'postgres'),
	(818, 'Details Updated', '2024-02-01', 2069, NULL, NULL, 'postgres'),
	(819, 'Details Updated', '2024-02-01', 2070, NULL, NULL, 'postgres'),
	(820, 'Details Updated', '2024-02-01', 2077, NULL, NULL, 'postgres'),
	(821, 'Details Updated', '2024-02-01', 2078, NULL, NULL, 'postgres'),
	(822, 'Details Updated', '2024-02-01', 2080, NULL, NULL, 'postgres'),
	(823, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(824, 'Details Updated', '2024-02-01', 1734, NULL, NULL, 'postgres'),
	(825, 'Details Updated', '2024-02-01', 1773, NULL, NULL, 'postgres'),
	(826, 'Details Updated', '2024-02-01', 1774, NULL, NULL, 'postgres'),
	(827, 'Details Updated', '2024-02-01', 1775, NULL, NULL, 'postgres'),
	(828, 'Details Updated', '2024-02-01', 1776, NULL, NULL, 'postgres'),
	(829, 'Details Updated', '2024-02-01', 1777, NULL, NULL, 'postgres'),
	(830, 'Details Updated', '2024-02-01', 1778, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(831, 'Details Updated', '2024-02-01', 1779, NULL, NULL, 'postgres'),
	(832, 'Details Updated', '2024-02-01', 1780, NULL, NULL, 'postgres'),
	(833, 'Details Updated', '2024-02-01', 1735, NULL, NULL, 'postgres'),
	(834, 'Details Updated', '2024-02-01', 1845, NULL, NULL, 'postgres'),
	(835, 'Details Updated', '2024-02-01', 1846, NULL, NULL, 'postgres'),
	(836, 'Details Updated', '2024-02-01', 1847, NULL, NULL, 'postgres'),
	(837, 'Details Updated', '2024-02-01', 1849, NULL, NULL, 'postgres'),
	(838, 'Details Updated', '2024-02-01', 1850, NULL, NULL, 'postgres'),
	(839, 'Details Updated', '2024-02-01', 1851, NULL, NULL, 'postgres'),
	(840, 'Details Updated', '2024-02-01', 1852, NULL, NULL, 'postgres'),
	(841, 'Details Updated', '2024-02-01', 1853, NULL, NULL, 'postgres'),
	(842, 'Details Updated', '2024-02-01', 1854, NULL, NULL, 'postgres'),
	(843, 'Details Updated', '2024-02-01', 1855, NULL, NULL, 'postgres'),
	(844, 'Details Updated', '2024-02-01', 1856, NULL, NULL, 'postgres'),
	(845, 'Details Updated', '2024-02-01', 1857, NULL, NULL, 'postgres'),
	(846, 'Details Updated', '2024-02-01', 1858, NULL, NULL, 'postgres'),
	(847, 'Details Updated', '2024-02-01', 1812, NULL, NULL, 'postgres'),
	(848, 'Details Updated', '2024-02-01', 1859, NULL, NULL, 'postgres'),
	(849, 'Details Updated', '2024-02-01', 1860, NULL, NULL, 'postgres'),
	(850, 'Details Updated', '2024-02-01', 1862, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(851, 'Details Updated', '2024-02-01', 1863, NULL, NULL, 'postgres'),
	(852, 'Details Updated', '2024-02-01', 1864, NULL, NULL, 'postgres'),
	(853, 'Details Updated', '2024-02-01', 1865, NULL, NULL, 'postgres'),
	(854, 'Details Updated', '2024-02-01', 1866, NULL, NULL, 'postgres'),
	(855, 'Details Updated', '2024-02-01', 1873, NULL, NULL, 'postgres'),
	(856, 'Details Updated', '2024-02-01', 1736, NULL, NULL, 'postgres'),
	(857, 'Details Updated', '2024-02-01', 1737, NULL, NULL, 'postgres'),
	(858, 'Details Updated', '2024-02-01', 1925, NULL, NULL, 'postgres'),
	(859, 'Details Updated', '2024-02-01', 1530, NULL, NULL, 'postgres'),
	(860, 'Details Updated', '2024-02-01', 1926, NULL, NULL, 'postgres'),
	(861, 'Details Updated', '2024-02-01', 1886, NULL, NULL, 'postgres'),
	(862, 'Details Updated', '2024-02-01', 4163, NULL, NULL, 'postgres'),
	(863, 'Details Updated', '2024-02-01', 1982, NULL, NULL, 'postgres'),
	(864, 'Details Updated', '2024-02-01', 1946, NULL, NULL, 'postgres'),
	(865, 'Details Updated', '2024-02-01', 1984, NULL, NULL, 'postgres'),
	(866, 'Details Updated', '2024-02-01', 1985, NULL, NULL, 'postgres'),
	(867, 'Details Updated', '2024-02-01', 1986, NULL, NULL, 'postgres'),
	(868, 'Details Updated', '2024-02-01', 1987, NULL, NULL, 'postgres'),
	(869, 'Details Updated', '2024-02-01', 1988, NULL, NULL, 'postgres'),
	(870, 'Details Updated', '2024-02-01', 1992, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(871, 'Details Updated', '2024-02-01', 1998, NULL, NULL, 'postgres'),
	(872, 'Details Updated', '2024-02-01', 2000, NULL, NULL, 'postgres'),
	(873, 'Details Updated', '2024-02-01', 2001, NULL, NULL, 'postgres'),
	(874, 'Details Updated', '2024-02-01', 2002, NULL, NULL, 'postgres'),
	(875, 'Details Updated', '2024-02-01', 2003, NULL, NULL, 'postgres'),
	(876, 'Details Updated', '2024-02-01', 2004, NULL, NULL, 'postgres'),
	(877, 'Details Updated', '2024-02-01', 2005, NULL, NULL, 'postgres'),
	(878, 'Details Updated', '2024-02-01', 2007, NULL, NULL, 'postgres'),
	(879, 'Details Updated', '2024-02-01', 2008, NULL, NULL, 'postgres'),
	(880, 'Details Updated', '2024-02-01', 2009, NULL, NULL, 'postgres'),
	(881, 'Details Updated', '2024-02-01', 2010, NULL, NULL, 'postgres'),
	(882, 'Details Updated', '2024-02-01', 2011, NULL, NULL, 'postgres'),
	(883, 'Details Updated', '2024-02-01', 2012, NULL, NULL, 'postgres'),
	(884, 'Details Updated', '2024-02-01', 2013, NULL, NULL, 'postgres'),
	(885, 'Details Updated', '2024-02-01', 2014, NULL, NULL, 'postgres'),
	(886, 'Details Updated', '2024-02-01', 2015, NULL, NULL, 'postgres'),
	(887, 'Details Updated', '2024-02-01', 2016, NULL, NULL, 'postgres'),
	(888, 'Details Updated', '2024-02-01', 2017, NULL, NULL, 'postgres'),
	(889, 'Details Updated', '2024-02-01', 2018, NULL, NULL, 'postgres'),
	(890, 'Details Updated', '2024-02-01', 2019, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(891, 'Details Updated', '2024-02-01', 2020, NULL, NULL, 'postgres'),
	(892, 'Details Updated', '2024-02-01', 2021, NULL, NULL, 'postgres'),
	(893, 'Details Updated', '2024-02-01', 2022, NULL, NULL, 'postgres'),
	(894, 'Details Updated', '2024-02-01', 4164, NULL, NULL, 'postgres'),
	(895, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(896, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(897, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(898, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(899, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(900, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(901, 'Details Updated', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(902, 'Details Updated', '2024-02-01', 4165, NULL, NULL, 'postgres'),
	(903, 'Details Updated', '2024-02-01', 4166, NULL, NULL, 'postgres'),
	(904, 'Details Updated', '2024-02-01', 2129, NULL, NULL, 'postgres'),
	(905, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(906, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(907, 'Details Updated', '2024-02-01', 1594, NULL, NULL, 'postgres'),
	(908, 'Details Updated', '2024-02-01', 1595, NULL, NULL, 'postgres'),
	(909, 'Details Updated', '2024-02-01', 1596, NULL, NULL, 'postgres'),
	(910, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(911, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(912, 'Details Updated', '2024-02-01', 1606, NULL, NULL, 'postgres'),
	(913, 'Details Updated', '2024-02-01', 1618, NULL, NULL, 'postgres'),
	(914, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(915, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(916, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(917, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(918, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(919, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(920, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(921, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(922, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(923, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(924, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(925, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(926, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(927, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(928, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(929, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(930, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(931, 'Details Updated', '2024-02-01', 1781, NULL, NULL, 'postgres'),
	(932, 'Details Updated', '2024-02-01', 1782, NULL, NULL, 'postgres'),
	(933, 'Details Updated', '2024-02-01', 1783, NULL, NULL, 'postgres'),
	(934, 'Details Updated', '2024-02-01', 1784, NULL, NULL, 'postgres'),
	(935, 'Details Updated', '2024-02-01', 1789, NULL, NULL, 'postgres'),
	(936, 'Details Updated', '2024-02-01', 1791, NULL, NULL, 'postgres'),
	(937, 'Details Updated', '2024-02-01', 1792, NULL, NULL, 'postgres'),
	(938, 'Details Updated', '2024-02-01', 1793, NULL, NULL, 'postgres'),
	(939, 'Details Updated', '2024-02-01', 1794, NULL, NULL, 'postgres'),
	(940, 'Details Updated', '2024-02-01', 1795, NULL, NULL, 'postgres'),
	(941, 'Details Updated', '2024-02-01', 1796, NULL, NULL, 'postgres'),
	(942, 'Details Updated', '2024-02-01', 1797, NULL, NULL, 'postgres'),
	(943, 'Details Updated', '2024-02-01', 1798, NULL, NULL, 'postgres'),
	(944, 'Details Updated', '2024-02-01', 1799, NULL, NULL, 'postgres'),
	(945, 'Details Updated', '2024-02-01', 1800, NULL, NULL, 'postgres'),
	(946, 'Details Updated', '2024-02-01', 1801, NULL, NULL, 'postgres'),
	(947, 'Details Updated', '2024-02-01', 1802, NULL, NULL, 'postgres'),
	(948, 'Details Updated', '2024-02-01', 1803, NULL, NULL, 'postgres'),
	(949, 'Details Updated', '2024-02-01', 1804, NULL, NULL, 'postgres'),
	(950, 'Details Updated', '2024-02-01', 1805, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(951, 'Details Updated', '2024-02-01', 1807, NULL, NULL, 'postgres'),
	(952, 'Details Updated', '2024-02-01', 1808, NULL, NULL, 'postgres'),
	(953, 'Details Updated', '2024-02-01', 1809, NULL, NULL, 'postgres'),
	(954, 'Details Updated', '2024-02-01', 1810, NULL, NULL, 'postgres'),
	(955, 'Details Updated', '2024-02-01', 1811, NULL, NULL, 'postgres'),
	(956, 'Details Updated', '2024-02-01', 1813, NULL, NULL, 'postgres'),
	(957, 'Details Updated', '2024-02-01', 1814, NULL, NULL, 'postgres'),
	(958, 'Details Updated', '2024-02-01', 1815, NULL, NULL, 'postgres'),
	(959, 'Details Updated', '2024-02-01', 1816, NULL, NULL, 'postgres'),
	(960, 'Details Updated', '2024-02-01', 1817, NULL, NULL, 'postgres'),
	(961, 'Details Updated', '2024-02-01', 1818, NULL, NULL, 'postgres'),
	(962, 'Details Updated', '2024-02-01', 1820, NULL, NULL, 'postgres'),
	(963, 'Details Updated', '2024-02-01', 1821, NULL, NULL, 'postgres'),
	(964, 'Details Updated', '2024-02-01', 1822, NULL, NULL, 'postgres'),
	(965, 'Details Updated', '2024-02-01', 1823, NULL, NULL, 'postgres'),
	(966, 'Details Updated', '2024-02-01', 1824, NULL, NULL, 'postgres'),
	(967, 'Details Updated', '2024-02-01', 1825, NULL, NULL, 'postgres'),
	(968, 'Details Updated', '2024-02-01', 1826, NULL, NULL, 'postgres'),
	(969, 'Details Updated', '2024-02-01', 1827, NULL, NULL, 'postgres'),
	(970, 'Details Updated', '2024-02-01', 1828, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(971, 'Details Updated', '2024-02-01', 1829, NULL, NULL, 'postgres'),
	(972, 'Details Updated', '2024-02-01', 1830, NULL, NULL, 'postgres'),
	(973, 'Details Updated', '2024-02-01', 1831, NULL, NULL, 'postgres'),
	(974, 'Details Updated', '2024-02-01', 1832, NULL, NULL, 'postgres'),
	(975, 'Details Updated', '2024-02-01', 1833, NULL, NULL, 'postgres'),
	(976, 'Details Updated', '2024-02-01', 1834, NULL, NULL, 'postgres'),
	(977, 'Details Updated', '2024-02-01', 1835, NULL, NULL, 'postgres'),
	(978, 'Details Updated', '2024-02-01', 1836, NULL, NULL, 'postgres'),
	(979, 'Details Updated', '2024-02-01', 1837, NULL, NULL, 'postgres'),
	(980, 'Details Updated', '2024-02-01', 1838, NULL, NULL, 'postgres'),
	(981, 'Details Updated', '2024-02-01', 1839, NULL, NULL, 'postgres'),
	(982, 'Details Updated', '2024-02-01', 1840, NULL, NULL, 'postgres'),
	(983, 'Details Updated', '2024-02-01', 1841, NULL, NULL, 'postgres'),
	(984, 'Details Updated', '2024-02-01', 1842, NULL, NULL, 'postgres'),
	(985, 'Details Updated', '2024-02-01', 1843, NULL, NULL, 'postgres'),
	(986, 'Details Updated', '2024-02-01', 1867, NULL, NULL, 'postgres'),
	(987, 'Details Updated', '2024-02-01', 1868, NULL, NULL, 'postgres'),
	(988, 'Details Updated', '2024-02-01', 1869, NULL, NULL, 'postgres'),
	(989, 'Details Updated', '2024-02-01', 1870, NULL, NULL, 'postgres'),
	(990, 'Details Updated', '2024-02-01', 1871, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(991, 'Details Updated', '2024-02-01', 1874, NULL, NULL, 'postgres'),
	(992, 'Details Updated', '2024-02-01', 1875, NULL, NULL, 'postgres'),
	(993, 'Details Updated', '2024-02-01', 1881, NULL, NULL, 'postgres'),
	(994, 'Details Updated', '2024-02-01', 1882, NULL, NULL, 'postgres'),
	(995, 'Details Updated', '2024-02-01', 1883, NULL, NULL, 'postgres'),
	(996, 'Details Updated', '2024-02-01', 1884, NULL, NULL, 'postgres'),
	(997, 'Details Updated', '2024-02-01', 1887, NULL, NULL, 'postgres'),
	(998, 'Details Updated', '2024-02-01', 1888, NULL, NULL, 'postgres'),
	(999, 'Details Updated', '2024-02-01', 1889, NULL, NULL, 'postgres'),
	(1000, 'Details Updated', '2024-02-01', 1890, NULL, NULL, 'postgres'),
	(1001, 'Details Updated', '2024-02-01', 1891, NULL, NULL, 'postgres'),
	(1002, 'Details Updated', '2024-02-01', 1893, NULL, NULL, 'postgres'),
	(1003, 'Details Updated', '2024-02-01', 1896, NULL, NULL, 'postgres'),
	(1004, 'Details Updated', '2024-02-01', 1897, NULL, NULL, 'postgres'),
	(1005, 'Details Updated', '2024-02-01', 1903, NULL, NULL, 'postgres'),
	(1006, 'Details Updated', '2024-02-01', 1904, NULL, NULL, 'postgres'),
	(1007, 'Details Updated', '2024-02-01', 1905, NULL, NULL, 'postgres'),
	(1008, 'Details Updated', '2024-02-01', 1908, NULL, NULL, 'postgres'),
	(1009, 'Details Updated', '2024-02-01', 1909, NULL, NULL, 'postgres'),
	(1010, 'Details Updated', '2024-02-01', 1910, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1011, 'Details Updated', '2024-02-01', 1911, NULL, NULL, 'postgres'),
	(1012, 'Details Updated', '2024-02-01', 1912, NULL, NULL, 'postgres'),
	(1013, 'Details Updated', '2024-02-01', 1913, NULL, NULL, 'postgres'),
	(1014, 'Details Updated', '2024-02-01', 1914, NULL, NULL, 'postgres'),
	(1015, 'Details Updated', '2024-02-01', 1916, NULL, NULL, 'postgres'),
	(1016, 'Details Updated', '2024-02-01', 1917, NULL, NULL, 'postgres'),
	(1017, 'Details Updated', '2024-02-01', 1919, NULL, NULL, 'postgres'),
	(1018, 'Details Updated', '2024-02-01', 1920, NULL, NULL, 'postgres'),
	(1019, 'Details Updated', '2024-02-01', 1921, NULL, NULL, 'postgres'),
	(1020, 'Details Updated', '2024-02-01', 1922, NULL, NULL, 'postgres'),
	(1021, 'Details Updated', '2024-02-01', 1927, NULL, NULL, 'postgres'),
	(1022, 'Details Updated', '2024-02-01', 1928, NULL, NULL, 'postgres'),
	(1023, 'Details Updated', '2024-02-01', 1929, NULL, NULL, 'postgres'),
	(1024, 'Details Updated', '2024-02-01', 1930, NULL, NULL, 'postgres'),
	(1025, 'Details Updated', '2024-02-01', 1491, NULL, NULL, 'postgres'),
	(1026, 'Details Updated', '2024-02-01', 1492, NULL, NULL, 'postgres'),
	(1027, 'Details Updated', '2024-02-01', 1493, NULL, NULL, 'postgres'),
	(1028, 'Details Updated', '2024-02-01', 1495, NULL, NULL, 'postgres'),
	(1029, 'Details Updated', '2024-02-01', 1496, NULL, NULL, 'postgres'),
	(1030, 'Details Updated', '2024-02-01', 1497, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1031, 'Details Updated', '2024-02-01', 1498, NULL, NULL, 'postgres'),
	(1032, 'Details Updated', '2024-02-01', 1499, NULL, NULL, 'postgres'),
	(1033, 'Details Updated', '2024-02-01', 1500, NULL, NULL, 'postgres'),
	(1034, 'Details Updated', '2024-02-01', 1501, NULL, NULL, 'postgres'),
	(1035, 'Details Updated', '2024-02-01', 1502, NULL, NULL, 'postgres'),
	(1036, 'Details Updated', '2024-02-01', 1503, NULL, NULL, 'postgres'),
	(1037, 'Details Updated', '2024-02-01', 1504, NULL, NULL, 'postgres'),
	(1038, 'Details Updated', '2024-02-01', 1505, NULL, NULL, 'postgres'),
	(1039, 'Details Updated', '2024-02-01', 1506, NULL, NULL, 'postgres'),
	(1040, 'Details Updated', '2024-02-01', 1507, NULL, NULL, 'postgres'),
	(1041, 'Details Updated', '2024-02-01', 1932, NULL, NULL, 'postgres'),
	(1042, 'Details Updated', '2024-02-01', 1933, NULL, NULL, 'postgres'),
	(1043, 'Details Updated', '2024-02-01', 1934, NULL, NULL, 'postgres'),
	(1044, 'Details Updated', '2024-02-01', 1935, NULL, NULL, 'postgres'),
	(1045, 'Details Updated', '2024-02-01', 1936, NULL, NULL, 'postgres'),
	(1046, 'Details Updated', '2024-02-01', 1937, NULL, NULL, 'postgres'),
	(1047, 'Details Updated', '2024-02-01', 1938, NULL, NULL, 'postgres'),
	(1048, 'Details Updated', '2024-02-01', 1939, NULL, NULL, 'postgres'),
	(1049, 'Details Updated', '2024-02-01', 1940, NULL, NULL, 'postgres'),
	(1050, 'Details Updated', '2024-02-01', 1941, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1051, 'Details Updated', '2024-02-01', 1942, NULL, NULL, 'postgres'),
	(1052, 'Details Updated', '2024-02-01', 1943, NULL, NULL, 'postgres'),
	(1053, 'Details Updated', '2024-02-01', 1944, NULL, NULL, 'postgres'),
	(1054, 'Details Updated', '2024-02-01', 1945, NULL, NULL, 'postgres'),
	(1055, 'Details Updated', '2024-02-01', 1947, NULL, NULL, 'postgres'),
	(1056, 'Details Updated', '2024-02-01', 1948, NULL, NULL, 'postgres'),
	(1057, 'Details Updated', '2024-02-01', 1949, NULL, NULL, 'postgres'),
	(1058, 'Details Updated', '2024-02-01', 1950, NULL, NULL, 'postgres'),
	(1059, 'Details Updated', '2024-02-01', 1951, NULL, NULL, 'postgres'),
	(1060, 'Details Updated', '2024-02-01', 1952, NULL, NULL, 'postgres'),
	(1061, 'Details Updated', '2024-02-01', 1953, NULL, NULL, 'postgres'),
	(1062, 'Details Updated', '2024-02-01', 1954, NULL, NULL, 'postgres'),
	(1063, 'Details Updated', '2024-02-01', 1955, NULL, NULL, 'postgres'),
	(1064, 'Details Updated', '2024-02-01', 1956, NULL, NULL, 'postgres'),
	(1065, 'Details Updated', '2024-02-01', 1957, NULL, NULL, 'postgres'),
	(1066, 'Details Updated', '2024-02-01', 1958, NULL, NULL, 'postgres'),
	(1067, 'Details Updated', '2024-02-01', 1959, NULL, NULL, 'postgres'),
	(1068, 'Details Updated', '2024-02-01', 1960, NULL, NULL, 'postgres'),
	(1069, 'Details Updated', '2024-02-01', 1961, NULL, NULL, 'postgres'),
	(1070, 'Details Updated', '2024-02-01', 1962, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1071, 'Details Updated', '2024-02-01', 1963, NULL, NULL, 'postgres'),
	(1072, 'Details Updated', '2024-02-01', 1964, NULL, NULL, 'postgres'),
	(1073, 'Details Updated', '2024-02-01', 1965, NULL, NULL, 'postgres'),
	(1074, 'Details Updated', '2024-02-01', 1966, NULL, NULL, 'postgres'),
	(1075, 'Details Updated', '2024-02-01', 1967, NULL, NULL, 'postgres'),
	(1076, 'Details Updated', '2024-02-01', 1968, NULL, NULL, 'postgres'),
	(1077, 'Details Updated', '2024-02-01', 1969, NULL, NULL, 'postgres'),
	(1078, 'Details Updated', '2024-02-01', 1971, NULL, NULL, 'postgres'),
	(1079, 'Details Updated', '2024-02-01', 1972, NULL, NULL, 'postgres'),
	(1080, 'Details Updated', '2024-02-01', 1973, NULL, NULL, 'postgres'),
	(1081, 'Details Updated', '2024-02-01', 1974, NULL, NULL, 'postgres'),
	(1082, 'Details Updated', '2024-02-01', 1975, NULL, NULL, 'postgres'),
	(1083, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(1084, 'Details Updated', '2024-02-01', 1976, NULL, NULL, 'postgres'),
	(1085, 'Details Updated', '2024-02-01', 1977, NULL, NULL, 'postgres'),
	(1086, 'Details Updated', '2024-02-01', 1978, NULL, NULL, 'postgres'),
	(1087, 'Details Updated', '2024-02-01', 1979, NULL, NULL, 'postgres'),
	(1088, 'Details Updated', '2024-02-01', 1980, NULL, NULL, 'postgres'),
	(1089, 'Details Updated', '2024-02-01', 1981, NULL, NULL, 'postgres'),
	(1090, 'Details Updated', '2024-02-01', 2023, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1091, 'Details Updated', '2024-02-01', 2024, NULL, NULL, 'postgres'),
	(1092, 'Details Updated', '2024-02-01', 2025, NULL, NULL, 'postgres'),
	(1093, 'Details Updated', '2024-02-01', 2026, NULL, NULL, 'postgres'),
	(1094, 'Details Updated', '2024-02-01', 2027, NULL, NULL, 'postgres'),
	(1095, 'Details Updated', '2024-02-01', 2030, NULL, NULL, 'postgres'),
	(1096, 'Details Updated', '2024-02-01', 1494, NULL, NULL, 'postgres'),
	(1097, 'Details Updated', '2024-02-01', 2032, NULL, NULL, 'postgres'),
	(1098, 'Details Updated', '2024-02-01', 2033, NULL, NULL, 'postgres'),
	(1099, 'Details Updated', '2024-02-01', 2034, NULL, NULL, 'postgres'),
	(1100, 'Details Updated', '2024-02-01', 2035, NULL, NULL, 'postgres'),
	(1101, 'Details Updated', '2024-02-01', 2036, NULL, NULL, 'postgres'),
	(1102, 'Details Updated', '2024-02-01', 2037, NULL, NULL, 'postgres'),
	(1103, 'Details Updated', '2024-02-01', 2038, NULL, NULL, 'postgres'),
	(1104, 'Details Updated', '2024-02-01', 2039, NULL, NULL, 'postgres'),
	(1105, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(1106, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(1107, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(1108, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(1109, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(1110, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1111, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(1112, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(1113, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(1114, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(1115, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(1116, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(1117, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(1118, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(1119, 'Details Updated', '2024-02-01', 1742, NULL, NULL, 'postgres'),
	(1120, 'Details Updated', '2024-02-01', 1745, NULL, NULL, 'postgres'),
	(1121, 'Details Updated', '2024-02-01', 1747, NULL, NULL, 'postgres'),
	(1122, 'Details Updated', '2024-02-01', 1748, NULL, NULL, 'postgres'),
	(1123, 'Details Updated', '2024-02-01', 1749, NULL, NULL, 'postgres'),
	(1124, 'Details Updated', '2024-02-01', 1750, NULL, NULL, 'postgres'),
	(1125, 'Details Updated', '2024-02-01', 1753, NULL, NULL, 'postgres'),
	(1126, 'Details Updated', '2024-02-01', 1758, NULL, NULL, 'postgres'),
	(1127, 'Details Updated', '2024-02-01', 1759, NULL, NULL, 'postgres'),
	(1128, 'Details Updated', '2024-02-01', 1760, NULL, NULL, 'postgres'),
	(1129, 'Details Updated', '2024-02-01', 1761, NULL, NULL, 'postgres'),
	(1130, 'Details Updated', '2024-02-01', 1762, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1131, 'Details Updated', '2024-02-01', 1763, NULL, NULL, 'postgres'),
	(1132, 'Details Updated', '2024-02-01', 1764, NULL, NULL, 'postgres'),
	(1133, 'Details Updated', '2024-02-01', 1765, NULL, NULL, 'postgres'),
	(1134, 'Details Updated', '2024-02-01', 1766, NULL, NULL, 'postgres'),
	(1135, 'Details Updated', '2024-02-01', 1767, NULL, NULL, 'postgres'),
	(1136, 'Details Updated', '2024-02-01', 1769, NULL, NULL, 'postgres'),
	(1137, 'Details Updated', '2024-02-01', 1770, NULL, NULL, 'postgres'),
	(1138, 'Details Updated', '2024-02-01', 1771, NULL, NULL, 'postgres'),
	(1139, 'Details Updated', '2024-02-01', 1772, NULL, NULL, 'postgres'),
	(1140, 'Details Updated', '2024-02-01', 2064, NULL, NULL, 'postgres'),
	(1141, 'Details Updated', '2024-02-01', 2061, NULL, NULL, 'postgres'),
	(1142, 'Details Updated', '2024-02-01', 2065, NULL, NULL, 'postgres'),
	(1143, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(1144, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(1145, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(1146, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(1147, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(1148, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(1149, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(1150, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1151, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(1152, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(1153, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(1154, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(1155, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(1156, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(1157, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(1158, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(1159, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(1160, 'Details Updated', '2024-02-01', 1894, NULL, NULL, 'postgres'),
	(1161, 'Details Updated', '2024-02-01', 1895, NULL, NULL, 'postgres'),
	(1162, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(1163, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(1164, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(1165, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(1166, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(1167, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(1168, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(1169, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(1170, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1171, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(1172, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(1173, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(1174, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(1175, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(1176, 'Details Updated', '2024-02-01', 1533, NULL, NULL, 'postgres'),
	(1177, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(1178, 'Details Updated', '2024-02-01', 1560, NULL, NULL, 'postgres'),
	(1179, 'Details Updated', '2024-02-01', 1561, NULL, NULL, 'postgres'),
	(1180, 'Details Updated', '2024-02-01', 1562, NULL, NULL, 'postgres'),
	(1181, 'Details Updated', '2024-02-01', 1563, NULL, NULL, 'postgres'),
	(1182, 'Details Updated', '2024-02-01', 1564, NULL, NULL, 'postgres'),
	(1183, 'Details Updated', '2024-02-01', 1567, NULL, NULL, 'postgres'),
	(1184, 'Details Updated', '2024-02-01', 1568, NULL, NULL, 'postgres'),
	(1185, 'Details Updated', '2024-02-01', 1569, NULL, NULL, 'postgres'),
	(1186, 'Details Updated', '2024-02-01', 1571, NULL, NULL, 'postgres'),
	(1187, 'Details Updated', '2024-02-01', 1572, NULL, NULL, 'postgres'),
	(1188, 'Details Updated', '2024-02-01', 1573, NULL, NULL, 'postgres'),
	(1189, 'Details Updated', '2024-02-01', 1574, NULL, NULL, 'postgres'),
	(1190, 'Details Updated', '2024-02-01', 1575, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1191, 'Details Updated', '2024-02-01', 1576, NULL, NULL, 'postgres'),
	(1192, 'Details Updated', '2024-02-01', 1577, NULL, NULL, 'postgres'),
	(1193, 'Details Updated', '2024-02-01', 1639, NULL, NULL, 'postgres'),
	(1194, 'Details Updated', '2024-02-01', 1640, NULL, NULL, 'postgres'),
	(1195, 'Details Updated', '2024-02-01', 1641, NULL, NULL, 'postgres'),
	(1196, 'Details Updated', '2024-02-01', 1642, NULL, NULL, 'postgres'),
	(1197, 'Details Updated', '2024-02-01', 1643, NULL, NULL, 'postgres'),
	(1198, 'Details Updated', '2024-02-01', 1644, NULL, NULL, 'postgres'),
	(1199, 'Details Updated', '2024-02-01', 1645, NULL, NULL, 'postgres'),
	(1200, 'Details Updated', '2024-02-01', 1646, NULL, NULL, 'postgres'),
	(1201, 'Details Updated', '2024-02-01', 1647, NULL, NULL, 'postgres'),
	(1202, 'Details Updated', '2024-02-01', 1648, NULL, NULL, 'postgres'),
	(1203, 'Details Updated', '2024-02-01', 1649, NULL, NULL, 'postgres'),
	(1204, 'Details Updated', '2024-02-01', 1650, NULL, NULL, 'postgres'),
	(1205, 'Details Updated', '2024-02-01', 1651, NULL, NULL, 'postgres'),
	(1206, 'Details Updated', '2024-02-01', 1652, NULL, NULL, 'postgres'),
	(1207, 'Details Updated', '2024-02-01', 1653, NULL, NULL, 'postgres'),
	(1208, 'Details Updated', '2024-02-01', 1654, NULL, NULL, 'postgres'),
	(1209, 'Details Updated', '2024-02-01', 1656, NULL, NULL, 'postgres'),
	(1210, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1211, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(1212, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(1213, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(1214, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(1215, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(1216, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(1217, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(1218, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(1219, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(1220, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(1221, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(1222, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres'),
	(1223, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(1224, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(1225, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(1226, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(1227, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(1228, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(1229, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(1230, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1231, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(1232, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(1233, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(1234, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(1235, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(1236, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(1237, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(1238, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(1239, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(1240, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(1241, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(1242, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(1243, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(1244, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(1245, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(1246, 'Details Updated', '2024-02-01', 1582, NULL, NULL, 'postgres'),
	(1247, 'Details Updated', '2024-02-01', 1511, NULL, NULL, 'postgres'),
	(1248, 'Details Updated', '2024-02-01', 1512, NULL, NULL, 'postgres'),
	(1249, 'Details Updated', '2024-02-01', 1723, NULL, NULL, 'postgres'),
	(1250, 'Details Updated', '2024-02-01', 1724, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1251, 'Details Updated', '2024-02-01', 1725, NULL, NULL, 'postgres'),
	(1252, 'Details Updated', '2024-02-01', 1726, NULL, NULL, 'postgres'),
	(1253, 'Details Updated', '2024-02-01', 1727, NULL, NULL, 'postgres'),
	(1254, 'Details Updated', '2024-02-01', 1728, NULL, NULL, 'postgres'),
	(1255, 'Details Updated', '2024-02-01', 1513, NULL, NULL, 'postgres'),
	(1256, 'Details Updated', '2024-02-01', 1514, NULL, NULL, 'postgres'),
	(1257, 'Details Updated', '2024-02-01', 1515, NULL, NULL, 'postgres'),
	(1258, 'Details Updated', '2024-02-01', 1516, NULL, NULL, 'postgres'),
	(1259, 'Details Updated', '2024-02-01', 1517, NULL, NULL, 'postgres'),
	(1260, 'Details Updated', '2024-02-01', 1518, NULL, NULL, 'postgres'),
	(1261, 'Details Updated', '2024-02-01', 1519, NULL, NULL, 'postgres'),
	(1262, 'Details Updated', '2024-02-01', 1520, NULL, NULL, 'postgres'),
	(1263, 'Details Updated', '2024-02-01', 1521, NULL, NULL, 'postgres'),
	(1264, 'Details Updated', '2024-02-01', 1522, NULL, NULL, 'postgres'),
	(1265, 'Details Updated', '2024-02-01', 1523, NULL, NULL, 'postgres'),
	(1266, 'Details Updated', '2024-02-01', 1931, NULL, NULL, 'postgres'),
	(1267, 'Details Updated', '2024-02-01', 1524, NULL, NULL, 'postgres'),
	(1268, 'Details Updated', '2024-02-01', 1525, NULL, NULL, 'postgres'),
	(1269, 'Details Updated', '2024-02-01', 1526, NULL, NULL, 'postgres'),
	(1270, 'Details Updated', '2024-02-01', 1527, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1271, 'Details Updated', '2024-02-01', 1528, NULL, NULL, 'postgres'),
	(1272, 'Details Updated', '2024-02-01', 1529, NULL, NULL, 'postgres'),
	(1273, 'Details Updated', '2024-02-01', 1532, NULL, NULL, 'postgres'),
	(1274, 'Details Updated', '2024-02-01', 1534, NULL, NULL, 'postgres'),
	(1275, 'Details Updated', '2024-02-01', 1535, NULL, NULL, 'postgres'),
	(1276, 'Details Updated', '2024-02-01', 1536, NULL, NULL, 'postgres'),
	(1277, 'Details Updated', '2024-02-01', 1537, NULL, NULL, 'postgres'),
	(1278, 'Details Updated', '2024-02-01', 1538, NULL, NULL, 'postgres'),
	(1279, 'Details Updated', '2024-02-01', 1539, NULL, NULL, 'postgres'),
	(1280, 'Details Updated', '2024-02-01', 1540, NULL, NULL, 'postgres'),
	(1281, 'Details Updated', '2024-02-01', 1541, NULL, NULL, 'postgres'),
	(1282, 'Details Updated', '2024-02-01', 1542, NULL, NULL, 'postgres'),
	(1283, 'Details Updated', '2024-02-01', 1543, NULL, NULL, 'postgres'),
	(1284, 'Details Updated', '2024-02-01', 1544, NULL, NULL, 'postgres'),
	(1285, 'Details Updated', '2024-02-01', 1545, NULL, NULL, 'postgres'),
	(1286, 'Details Updated', '2024-02-01', 1546, NULL, NULL, 'postgres'),
	(1287, 'Details Updated', '2024-02-01', 1547, NULL, NULL, 'postgres'),
	(1288, 'Details Updated', '2024-02-01', 1548, NULL, NULL, 'postgres'),
	(1289, 'Details Updated', '2024-02-01', 1549, NULL, NULL, 'postgres'),
	(1290, 'Details Updated', '2024-02-01', 1551, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1291, 'Details Updated', '2024-02-01', 1552, NULL, NULL, 'postgres'),
	(1292, 'Details Updated', '2024-02-01', 1553, NULL, NULL, 'postgres'),
	(1293, 'Details Updated', '2024-02-01', 1554, NULL, NULL, 'postgres'),
	(1294, 'Details Updated', '2024-02-01', 1555, NULL, NULL, 'postgres'),
	(1295, 'Details Updated', '2024-02-01', 1556, NULL, NULL, 'postgres'),
	(1296, 'Details Updated', '2024-02-01', 1557, NULL, NULL, 'postgres'),
	(1297, 'Details Updated', '2024-02-01', 1558, NULL, NULL, 'postgres'),
	(1298, 'Details Updated', '2024-02-01', 1559, NULL, NULL, 'postgres'),
	(1299, 'Details Updated', '2024-02-01', 1578, NULL, NULL, 'postgres'),
	(1300, 'Details Updated', '2024-02-01', 1579, NULL, NULL, 'postgres'),
	(1301, 'Details Updated', '2024-02-01', 1580, NULL, NULL, 'postgres'),
	(1302, 'Details Updated', '2024-02-01', 1581, NULL, NULL, 'postgres'),
	(1303, 'Details Updated', '2024-02-01', 1583, NULL, NULL, 'postgres'),
	(1304, 'Details Updated', '2024-02-01', 1584, NULL, NULL, 'postgres'),
	(1305, 'Details Updated', '2024-02-01', 1585, NULL, NULL, 'postgres'),
	(1306, 'Details Updated', '2024-02-01', 1586, NULL, NULL, 'postgres'),
	(1307, 'Details Updated', '2024-02-01', 1587, NULL, NULL, 'postgres'),
	(1308, 'Details Updated', '2024-02-01', 1589, NULL, NULL, 'postgres'),
	(1309, 'Details Updated', '2024-02-01', 1590, NULL, NULL, 'postgres'),
	(1310, 'Details Updated', '2024-02-01', 1591, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1311, 'Details Updated', '2024-02-01', 1597, NULL, NULL, 'postgres'),
	(1312, 'Details Updated', '2024-02-01', 1599, NULL, NULL, 'postgres'),
	(1313, 'Details Updated', '2024-02-01', 1600, NULL, NULL, 'postgres'),
	(1314, 'Details Updated', '2024-02-01', 1601, NULL, NULL, 'postgres'),
	(1315, 'Details Updated', '2024-02-01', 1602, NULL, NULL, 'postgres'),
	(1316, 'Details Updated', '2024-02-01', 1604, NULL, NULL, 'postgres'),
	(1317, 'Details Updated', '2024-02-01', 1605, NULL, NULL, 'postgres'),
	(1318, 'Details Updated', '2024-02-01', 1607, NULL, NULL, 'postgres'),
	(1319, 'Details Updated', '2024-02-01', 1608, NULL, NULL, 'postgres'),
	(1320, 'Details Updated', '2024-02-01', 1609, NULL, NULL, 'postgres'),
	(1321, 'Details Updated', '2024-02-01', 1610, NULL, NULL, 'postgres'),
	(1322, 'Details Updated', '2024-02-01', 1611, NULL, NULL, 'postgres'),
	(1323, 'Details Updated', '2024-02-01', 1612, NULL, NULL, 'postgres'),
	(1324, 'Details Updated', '2024-02-01', 1613, NULL, NULL, 'postgres'),
	(1325, 'Details Updated', '2024-02-01', 1614, NULL, NULL, 'postgres'),
	(1326, 'Details Updated', '2024-02-01', 1615, NULL, NULL, 'postgres'),
	(1327, 'Details Updated', '2024-02-01', 1616, NULL, NULL, 'postgres'),
	(1328, 'Details Updated', '2024-02-01', 1617, NULL, NULL, 'postgres'),
	(1329, 'Details Updated', '2024-02-01', 1619, NULL, NULL, 'postgres'),
	(1330, 'Details Updated', '2024-02-01', 1620, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1331, 'Details Updated', '2024-02-01', 1622, NULL, NULL, 'postgres'),
	(1332, 'Details Updated', '2024-02-01', 1623, NULL, NULL, 'postgres'),
	(1333, 'Details Updated', '2024-02-01', 1624, NULL, NULL, 'postgres'),
	(1334, 'Details Updated', '2024-02-01', 1625, NULL, NULL, 'postgres'),
	(1335, 'Details Updated', '2024-02-01', 1626, NULL, NULL, 'postgres'),
	(1336, 'Details Updated', '2024-02-01', 1627, NULL, NULL, 'postgres'),
	(1337, 'Details Updated', '2024-02-01', 1628, NULL, NULL, 'postgres'),
	(1338, 'Details Updated', '2024-02-01', 1629, NULL, NULL, 'postgres'),
	(1339, 'Details Updated', '2024-02-01', 1630, NULL, NULL, 'postgres'),
	(1340, 'Details Updated', '2024-02-01', 1631, NULL, NULL, 'postgres'),
	(1341, 'Details Updated', '2024-02-01', 1632, NULL, NULL, 'postgres'),
	(1342, 'Details Updated', '2024-02-01', 1633, NULL, NULL, 'postgres'),
	(1343, 'Details Updated', '2024-02-01', 1634, NULL, NULL, 'postgres'),
	(1344, 'Details Updated', '2024-02-01', 1635, NULL, NULL, 'postgres'),
	(1345, 'Details Updated', '2024-02-01', 1636, NULL, NULL, 'postgres'),
	(1346, 'Details Updated', '2024-02-01', 1637, NULL, NULL, 'postgres'),
	(1347, 'Details Updated', '2024-02-01', 1638, NULL, NULL, 'postgres'),
	(1348, 'Details Updated', '2024-02-01', 1655, NULL, NULL, 'postgres'),
	(1349, 'Details Updated', '2024-02-01', 1657, NULL, NULL, 'postgres'),
	(1350, 'Details Updated', '2024-02-01', 1658, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1351, 'Details Updated', '2024-02-01', 1659, NULL, NULL, 'postgres'),
	(1352, 'Details Updated', '2024-02-01', 1660, NULL, NULL, 'postgres'),
	(1353, 'Details Updated', '2024-02-01', 1661, NULL, NULL, 'postgres'),
	(1354, 'Details Updated', '2024-02-01', 1662, NULL, NULL, 'postgres'),
	(1355, 'Details Updated', '2024-02-01', 1663, NULL, NULL, 'postgres'),
	(1356, 'Details Updated', '2024-02-01', 1664, NULL, NULL, 'postgres'),
	(1357, 'Details Updated', '2024-02-01', 1665, NULL, NULL, 'postgres'),
	(1358, 'Details Updated', '2024-02-01', 1675, NULL, NULL, 'postgres'),
	(1359, 'Details Updated', '2024-02-01', 1676, NULL, NULL, 'postgres'),
	(1360, 'Details Updated', '2024-02-01', 1677, NULL, NULL, 'postgres'),
	(1361, 'Details Updated', '2024-02-01', 1678, NULL, NULL, 'postgres'),
	(1362, 'Details Updated', '2024-02-01', 1679, NULL, NULL, 'postgres'),
	(1363, 'Details Updated', '2024-02-01', 1680, NULL, NULL, 'postgres'),
	(1364, 'Details Updated', '2024-02-01', 1681, NULL, NULL, 'postgres'),
	(1365, 'Details Updated', '2024-02-01', 1682, NULL, NULL, 'postgres'),
	(1366, 'Details Updated', '2024-02-01', 1683, NULL, NULL, 'postgres'),
	(1367, 'Details Updated', '2024-02-01', 1684, NULL, NULL, 'postgres'),
	(1368, 'Details Updated', '2024-02-01', 1685, NULL, NULL, 'postgres'),
	(1369, 'Details Updated', '2024-02-01', 1686, NULL, NULL, 'postgres'),
	(1370, 'Details Updated', '2024-02-01', 1687, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1371, 'Details Updated', '2024-02-01', 1688, NULL, NULL, 'postgres'),
	(1372, 'Details Updated', '2024-02-01', 1689, NULL, NULL, 'postgres'),
	(1373, 'Details Updated', '2024-02-01', 1690, NULL, NULL, 'postgres'),
	(1374, 'Details Updated', '2024-02-01', 1691, NULL, NULL, 'postgres'),
	(1375, 'Details Updated', '2024-02-01', 1666, NULL, NULL, 'postgres'),
	(1376, 'Details Updated', '2024-02-01', 1692, NULL, NULL, 'postgres'),
	(1377, 'Details Updated', '2024-02-01', 1693, NULL, NULL, 'postgres'),
	(1378, 'Details Updated', '2024-02-01', 1694, NULL, NULL, 'postgres'),
	(1379, 'Details Updated', '2024-02-01', 1695, NULL, NULL, 'postgres'),
	(1380, 'Details Updated', '2024-02-01', 1696, NULL, NULL, 'postgres'),
	(1381, 'Details Updated', '2024-02-01', 1697, NULL, NULL, 'postgres'),
	(1382, 'Details Updated', '2024-02-01', 1705, NULL, NULL, 'postgres'),
	(1383, 'Details Updated', '2024-02-01', 1707, NULL, NULL, 'postgres'),
	(1384, 'Details Updated', '2024-02-01', 1708, NULL, NULL, 'postgres'),
	(1385, 'Details Updated', '2024-02-01', 1709, NULL, NULL, 'postgres'),
	(1386, 'Details Updated', '2024-02-01', 1711, NULL, NULL, 'postgres'),
	(1387, 'Details Updated', '2024-02-01', 1717, NULL, NULL, 'postgres'),
	(1388, 'Details Updated', '2024-02-01', 1719, NULL, NULL, 'postgres'),
	(1389, 'Details Updated', '2024-02-01', 1720, NULL, NULL, 'postgres'),
	(1390, 'Details Updated', '2024-02-01', 1721, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1391, 'Details Updated', '2024-02-01', 1722, NULL, NULL, 'postgres'),
	(1392, 'Details Updated', '2024-02-01', 1729, NULL, NULL, 'postgres'),
	(1393, 'Details Updated', '2024-02-01', 1730, NULL, NULL, 'postgres'),
	(1394, 'Details Updated', '2024-02-01', 1508, NULL, NULL, 'postgres'),
	(1395, 'Details Updated', '2024-02-01', 1509, NULL, NULL, 'postgres'),
	(1396, 'Details Updated', '2024-02-01', 1510, NULL, NULL, 'postgres'),
	(1397, 'Details Updated', '2024-02-01', 1752, NULL, NULL, 'postgres'),
	(1398, 'Details Updated', '2024-02-01', 1732, NULL, NULL, 'postgres'),
	(1399, 'Details Updated', '2024-02-01', 2090, NULL, NULL, 'postgres'),
	(1400, 'Details Updated', '2024-02-01', 2091, NULL, NULL, 'postgres'),
	(1401, 'Details Updated', '2024-02-01', 2079, NULL, NULL, 'postgres'),
	(1402, 'Details Updated', '2024-02-01', 2081, NULL, NULL, 'postgres'),
	(1403, 'Details Updated', '2024-02-01', 2082, NULL, NULL, 'postgres'),
	(1404, 'Details Updated', '2024-02-01', 2083, NULL, NULL, 'postgres'),
	(1405, 'Details Updated', '2024-02-01', 2084, NULL, NULL, 'postgres'),
	(1406, 'Details Updated', '2024-02-01', 2085, NULL, NULL, 'postgres'),
	(1407, 'Details Updated', '2024-02-01', 2086, NULL, NULL, 'postgres'),
	(1408, 'Details Updated', '2024-02-01', 2087, NULL, NULL, 'postgres'),
	(1409, 'Details Updated', '2024-02-01', 1667, NULL, NULL, 'postgres'),
	(1410, 'Details Updated', '2024-02-01', 2088, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1411, 'Details Updated', '2024-02-01', 1731, NULL, NULL, 'postgres'),
	(1412, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(1413, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(1414, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(1415, 'Details Updated', '2024-02-01', 2089, NULL, NULL, 'postgres'),
	(1416, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(1417, 'Details Updated', '2024-02-01', 1751, NULL, NULL, 'postgres'),
	(1418, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(1419, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(1420, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(1421, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(1422, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(1423, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(1424, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(1425, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(1426, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(1427, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(1428, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(1429, 'Details Updated', '2024-02-01', 2071, NULL, NULL, 'postgres'),
	(1430, 'Details Updated', '2024-02-01', 2072, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1431, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(1432, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(1433, 'Details Updated', '2024-02-01', 2075, NULL, NULL, 'postgres'),
	(1434, 'Details Updated', '2024-02-01', 2076, NULL, NULL, 'postgres'),
	(1435, 'Details Updated', '2024-02-01', 2068, NULL, NULL, 'postgres'),
	(1436, 'Details Updated', '2024-02-01', 2069, NULL, NULL, 'postgres'),
	(1437, 'Details Updated', '2024-02-01', 2070, NULL, NULL, 'postgres'),
	(1438, 'Details Updated', '2024-02-01', 2077, NULL, NULL, 'postgres'),
	(1439, 'Details Updated', '2024-02-01', 2078, NULL, NULL, 'postgres'),
	(1440, 'Details Updated', '2024-02-01', 2080, NULL, NULL, 'postgres'),
	(1441, 'Details Updated', '2024-02-01', 1898, NULL, NULL, 'postgres'),
	(1442, 'Details Updated', '2024-02-01', 1907, NULL, NULL, 'postgres'),
	(1443, 'Details Updated', '2024-02-01', 2062, NULL, NULL, 'postgres'),
	(1444, 'Details Updated', '2024-02-01', 1668, NULL, NULL, 'postgres'),
	(1445, 'Details Updated', '2024-02-01', 1669, NULL, NULL, 'postgres'),
	(1446, 'Details Updated', '2024-02-01', 1670, NULL, NULL, 'postgres'),
	(1447, 'Details Updated', '2024-02-01', 1671, NULL, NULL, 'postgres'),
	(1448, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(1449, 'Details Updated', '2024-02-01', 1673, NULL, NULL, 'postgres'),
	(1450, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1451, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(1452, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(1453, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(1454, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(1455, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(1456, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(1457, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(1458, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(1459, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(1460, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(1461, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(1462, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(1463, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(1464, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(1465, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(1466, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(1467, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(1468, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(1469, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(1470, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1471, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(1472, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(1473, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(1474, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(1475, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(1476, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(1477, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(1478, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(1479, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(1480, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(1481, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(1482, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(1483, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(1484, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(1485, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(1486, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(1487, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(1488, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(1489, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(1490, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1491, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(1492, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(1493, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(1494, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(1495, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(1496, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(1497, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(1498, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(1499, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(1500, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(1501, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(1502, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(1503, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(1504, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(1505, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(1506, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(1507, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(1508, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(1509, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(1510, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1511, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(1512, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(1513, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(1514, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(1515, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(1516, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(1517, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(1518, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(1519, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(1520, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(1521, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(1522, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(1523, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(1524, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(1525, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(1526, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(1527, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(1528, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(1529, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(1530, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1531, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(1532, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(1533, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(1534, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(1535, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(1536, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(1537, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(1538, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(1539, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(1540, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(1541, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(1542, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(1543, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(1544, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(1545, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(1546, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(1547, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(1548, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(1549, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(1550, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1551, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(1552, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(1553, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(1554, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(1555, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(1556, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(1557, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(1558, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(1559, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(1560, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(1561, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(1562, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(1563, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(1564, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(1565, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(1566, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(1567, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(1568, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(1569, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(1570, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1571, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(1572, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(1573, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(1574, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(1575, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(1576, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(1577, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(1578, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(1579, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(1580, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(1581, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(1582, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(1583, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(1584, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(1585, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(1586, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(1587, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(1588, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(1589, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(1590, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1591, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(1592, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(1593, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(1594, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(1595, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(1596, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(1597, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(1598, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(1599, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(1600, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(1601, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(1602, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(1603, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(1604, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(1605, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(1606, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(1607, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(1608, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(1609, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(1610, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1611, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(1612, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(1613, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(1614, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(1615, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(1616, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(1617, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(1618, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(1619, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(1620, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(1621, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(1622, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(1623, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(1624, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(1625, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(1626, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(1627, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(1628, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(1629, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(1630, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1631, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(1632, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(1633, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(1634, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(1635, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(1636, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(1637, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(1638, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(1639, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(1640, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(1641, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(1642, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(1643, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(1644, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(1645, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(1646, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(1647, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(1648, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(1649, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(1650, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1651, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(1652, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(1653, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(1654, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(1655, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(1656, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(1657, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(1658, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(1659, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(1660, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(1661, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(1662, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(1663, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(1664, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(1665, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(1666, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(1667, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(1668, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(1669, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(1670, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1671, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(1672, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(1673, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(1674, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(1675, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(1676, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(1677, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(1678, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(1679, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(1680, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(1681, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(1682, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(1683, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(1684, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(1685, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(1686, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(1687, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(1688, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(1689, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(1690, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1691, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(1692, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(1693, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(1694, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(1695, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(1696, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(1697, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(1698, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(1699, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(1700, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(1701, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(1702, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(1703, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(1704, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(1705, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(1706, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(1707, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(1708, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(1709, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(1710, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1711, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(1712, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(1713, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(1714, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(1715, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(1716, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(1717, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(1718, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(1719, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(1720, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(1721, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(1722, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(1723, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(1724, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(1725, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(1726, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(1727, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(1728, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(1729, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(1730, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1731, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(1732, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(1733, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(1734, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(1735, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(1736, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(1737, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(1738, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(1739, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(1740, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(1741, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(1742, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(1743, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(1744, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(1745, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(1746, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(1747, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(1748, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(1749, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(1750, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1751, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(1752, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(1753, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(1754, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(1755, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(1756, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(1757, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(1758, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(1759, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(1760, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(1761, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(1762, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(1763, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(1764, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(1765, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(1766, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(1767, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(1768, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(1769, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(1770, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1771, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(1772, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(1773, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(1774, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(1775, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(1776, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(1777, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(1778, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(1779, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(1780, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(1781, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(1782, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(1783, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(1784, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(1785, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(1786, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(1787, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(1788, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(1789, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(1790, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1791, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(1792, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(1793, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(1794, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(1795, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(1796, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(1797, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(1798, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(1799, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(1800, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(1801, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(1802, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(1803, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(1804, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(1805, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(1806, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(1807, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(1808, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(1809, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(1810, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1811, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(1812, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(1813, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(1814, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(1815, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(1816, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(1817, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(1818, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(1819, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(1820, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(1821, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(1822, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(1823, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(1824, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(1825, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(1826, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(1827, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(1828, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(1829, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(1830, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1831, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(1832, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(1833, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(1834, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(1835, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(1836, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(1837, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(1838, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(1839, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(1840, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(1841, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(1842, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(1843, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(1844, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(1845, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(1846, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(1847, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(1848, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(1849, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(1850, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1851, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(1852, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(1853, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(1854, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(1855, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(1856, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(1857, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(1858, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(1859, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(1860, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(1861, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(1862, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(1863, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(1864, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(1865, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(1866, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(1867, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(1868, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(1869, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(1870, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1871, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(1872, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(1873, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(1874, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(1875, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(1876, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(1877, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(1878, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(1879, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(1880, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(1881, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(1882, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(1883, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(1884, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(1885, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(1886, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(1887, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(1888, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(1889, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(1890, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1891, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(1892, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(1893, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(1894, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(1895, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(1896, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(1897, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(1898, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(1899, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(1900, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(1901, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(1902, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(1903, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(1904, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(1905, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(1906, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(1907, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(1908, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(1909, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(1910, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1911, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(1912, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(1913, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(1914, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(1915, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(1916, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(1917, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(1918, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(1919, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(1920, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(1921, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(1922, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(1923, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(1924, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(1925, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(1926, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(1927, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(1928, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(1929, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(1930, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1931, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(1932, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(1933, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(1934, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(1935, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(1936, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(1937, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(1938, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(1939, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(1940, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(1941, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(1942, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(1943, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(1944, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(1945, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(1946, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(1947, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(1948, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(1949, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(1950, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1951, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(1952, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(1953, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(1954, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(1955, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(1956, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(1957, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(1958, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(1959, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(1960, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(1961, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(1962, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(1963, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(1964, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(1965, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(1966, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(1967, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(1968, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(1969, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(1970, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1971, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(1972, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(1973, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(1974, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(1975, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(1976, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(1977, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(1978, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(1979, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(1980, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(1981, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(1982, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(1983, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(1984, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(1985, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(1986, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(1987, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(1988, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(1989, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(1990, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(1991, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(1992, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(1993, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(1994, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(1995, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(1996, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(1997, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(1998, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(1999, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(2000, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(2001, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(2002, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(2003, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(2004, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(2005, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(2006, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(2007, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(2008, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(2009, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(2010, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2011, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(2012, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(2013, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(2014, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(2015, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(2016, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(2017, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(2018, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(2019, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(2020, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(2021, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(2022, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(2023, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(2024, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(2025, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(2026, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(2027, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres'),
	(2028, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(2029, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(2030, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2031, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(2032, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(2033, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(2034, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(2035, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(2036, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(2037, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(2038, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(2039, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(2040, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(2041, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(2042, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(2043, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(2044, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(2045, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(2046, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(2047, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(2048, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(2049, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(2050, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2051, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(2052, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(2053, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(2054, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(2055, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(2056, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(2057, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(2058, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(2059, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(2060, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(2061, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(2062, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(2063, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(2064, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(2065, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(2066, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(2067, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(2068, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(2069, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(2070, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2071, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(2072, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(2073, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(2074, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(2075, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(2076, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(2077, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(2078, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(2079, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(2080, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(2081, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(2082, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(2083, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(2084, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(2085, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(2086, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(2087, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(2088, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(2089, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(2090, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2091, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(2092, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(2093, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(2094, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(2095, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(2096, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(2097, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(2098, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(2099, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(2100, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(2101, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(2102, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(2103, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(2104, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(2105, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(2106, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(2107, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(2108, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(2109, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(2110, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2111, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(2112, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(2113, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(2114, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(2115, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(2116, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(2117, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(2118, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(2119, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(2120, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(2121, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(2122, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(2123, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(2124, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(2125, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(2126, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(2127, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(2128, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(2129, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(2130, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2131, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(2132, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(2133, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(2134, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(2135, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(2136, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(2137, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(2138, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(2139, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(2140, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(2141, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(2142, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(2143, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(2144, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(2145, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(2146, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(2147, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(2148, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(2149, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(2150, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2151, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(2152, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(2153, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(2154, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(2155, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(2156, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(2157, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(2158, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(2159, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(2160, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(2161, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(2162, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(2163, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(2164, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(2165, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(2166, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres'),
	(2167, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(2168, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(2169, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(2170, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2171, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(2172, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(2173, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(2174, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(2175, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(2176, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(2177, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(2178, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(2179, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(2180, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(2181, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(2182, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(2183, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(2184, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(2185, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(2186, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(2187, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(2188, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(2189, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(2190, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2191, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(2192, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(2193, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(2194, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(2195, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(2196, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(2197, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(2198, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(2199, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(2200, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(2201, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(2202, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(2203, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(2204, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(2205, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(2206, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(2207, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(2208, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(2209, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(2210, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2211, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(2212, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(2213, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(2214, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(2215, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(2216, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(2217, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(2218, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(2219, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(2220, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(2221, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(2222, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(2223, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(2224, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(2225, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(2226, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(2227, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(2228, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(2229, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(2230, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2231, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(2232, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(2233, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(2234, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(2235, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(2236, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(2237, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(2238, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(2239, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(2240, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(2241, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(2242, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(2243, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(2244, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(2245, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(2246, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(2247, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(2248, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(2249, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(2250, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2251, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(2252, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(2253, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(2254, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(2255, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(2256, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(2257, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(2258, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(2259, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(2260, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(2261, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(2262, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(2263, 'Details Updated', '2024-02-01', 1731, NULL, NULL, 'postgres'),
	(2264, 'Instrument Returned', '2024-02-01', 1731, NULL, NULL, 'postgres'),
	(2265, 'Details Updated', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(2266, 'Instrument Returned', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(2267, 'Details Updated', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(2268, 'Instrument Returned', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(2269, 'Details Updated', '2024-02-01', 1595, NULL, NULL, 'postgres'),
	(2270, 'Instrument Returned', '2024-02-01', 1595, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2271, 'Details Updated', '2024-02-01', 1618, NULL, NULL, 'postgres'),
	(2272, 'Instrument Returned', '2024-02-01', 1618, NULL, NULL, 'postgres'),
	(2273, 'Details Updated', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(2274, 'Instrument Returned', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(2275, 'Details Updated', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(2276, 'Instrument Returned', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(2277, 'Details Updated', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(2278, 'Instrument Returned', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(2279, 'Details Updated', '2024-02-01', 1618, NULL, NULL, 'postgres'),
	(2280, 'Instrument Returned', '2024-02-01', 1618, NULL, NULL, 'postgres'),
	(2281, 'Details Updated', '2024-02-01', 1731, NULL, NULL, 'postgres'),
	(2282, 'Instrument Returned', '2024-02-01', 1731, NULL, NULL, 'postgres'),
	(2283, 'Details Updated', '2024-02-01', 1595, NULL, NULL, 'postgres'),
	(2284, 'Instrument Returned', '2024-02-01', 1595, NULL, NULL, 'postgres'),
	(2285, 'Details Updated', '2024-02-01', 1594, NULL, NULL, 'postgres'),
	(2286, 'Details Updated', '2024-02-01', 1894, NULL, NULL, 'postgres'),
	(2287, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(2288, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(2289, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(2290, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2291, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(2292, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(2293, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(2294, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(2295, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(2296, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(2297, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(2298, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(2299, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(2300, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(2301, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(2302, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(2303, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(2304, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(2305, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres'),
	(2306, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(2307, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(2308, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(2309, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(2310, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2311, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(2312, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(2313, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(2314, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(2315, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(2316, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(2317, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(2318, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(2319, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(2320, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(2321, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(2322, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(2323, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(2324, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(2325, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(2326, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(2327, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(2328, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(2329, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(2330, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2331, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(2332, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(2333, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(2334, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(2335, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres'),
	(2336, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(2337, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(2338, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(2339, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(2340, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(2341, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(2342, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(2343, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(2344, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(2345, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(2346, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(2347, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(2348, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(2349, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(2350, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2351, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(2352, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(2353, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(2354, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(2355, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(2356, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(2357, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(2358, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(2359, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(2360, 'Details Updated', '2024-02-01', 1594, NULL, NULL, 'postgres'),
	(2361, 'Details Updated', '2024-02-01', 1894, NULL, NULL, 'postgres'),
	(2362, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(2363, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(2364, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(2365, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(2366, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(2367, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(2368, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(2369, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(2370, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2371, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(2372, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(2373, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(2374, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(2375, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(2376, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(2377, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(2378, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(2379, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(2380, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(2381, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(2382, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(2383, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(2384, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(2385, 'Details Updated', '2024-02-01', 1533, NULL, NULL, 'postgres'),
	(2386, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(2387, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(2388, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(2389, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(2390, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2391, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(2392, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(2393, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(2394, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(2395, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(2396, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(2397, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(2398, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(2399, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(2400, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(2401, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(2402, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(2403, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(2404, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(2405, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(2406, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(2407, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(2408, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(2409, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(2410, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2411, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(2412, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(2413, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(2414, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(2415, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(2416, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(2417, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(2418, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(2419, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(2420, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(2421, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(2422, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(2423, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(2424, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(2425, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(2426, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(2427, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(2428, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(2429, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(2430, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2431, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(2432, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(2433, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(2434, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(2435, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(2436, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(2437, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(2438, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(2439, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(2440, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(2441, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(2442, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(2443, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(2444, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(2445, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(2446, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(2447, 'Details Updated', '2024-02-01', 1885, NULL, NULL, 'postgres'),
	(2448, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres'),
	(2449, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres'),
	(2450, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2451, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(2452, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(2453, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(2454, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(2455, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(2456, 'Details Updated', '2024-02-01', 2059, NULL, NULL, 'postgres'),
	(2457, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(2458, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(2459, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(2460, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(2461, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(2462, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(2463, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(2464, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(2465, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(2466, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(2467, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(2468, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(2469, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(2470, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2471, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(2472, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(2473, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(2474, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(2475, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(2476, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(2477, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(2478, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(2479, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(2480, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(2481, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(2482, 'Details Updated', '2024-02-01', 1594, NULL, NULL, 'postgres'),
	(2483, 'Details Updated', '2024-02-01', 1596, NULL, NULL, 'postgres'),
	(2484, 'Details Updated', '2024-02-01', 1606, NULL, NULL, 'postgres'),
	(2485, 'Details Updated', '2024-02-01', 1621, NULL, NULL, 'postgres'),
	(2486, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(2487, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(2488, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(2489, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(2490, 'Details Updated', '2024-02-01', 1715, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2491, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(2492, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(2493, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(2494, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(2495, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(2496, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(2497, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(2498, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(2499, 'Details Updated', '2024-02-01', 1876, NULL, NULL, 'postgres'),
	(2500, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(2501, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(2502, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(2503, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(2504, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(2505, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(2506, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(2507, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(2508, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(2509, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(2510, 'Details Updated', '2024-02-01', 1895, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2511, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(2512, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(2513, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(2514, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(2515, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(2516, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(2517, 'Details Updated', '2024-02-01', 1894, NULL, NULL, 'postgres'),
	(2518, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(2519, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(2520, 'Details Updated', '2024-02-01', 1533, NULL, NULL, 'postgres'),
	(2521, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(2522, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(2523, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(2524, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(2525, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(2526, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(2527, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres'),
	(2528, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(2529, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(2530, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2531, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(2532, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(2533, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(2534, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(2535, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres'),
	(2536, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(2537, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres'),
	(2538, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(2539, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(2540, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(2541, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(2542, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(2543, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(2544, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(2545, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(2546, 'Details Updated', '2024-02-01', 2089, NULL, NULL, 'postgres'),
	(2547, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(2548, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(2549, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(2550, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2551, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(2552, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(2553, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(2554, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(2555, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(2556, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(2557, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(2558, 'Details Updated', '2024-02-01', 2071, NULL, NULL, 'postgres'),
	(2559, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(2560, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(2561, 'Details Updated', '2024-02-01', 2075, NULL, NULL, 'postgres'),
	(2562, 'Details Updated', '2024-02-01', 2076, NULL, NULL, 'postgres'),
	(2563, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(2564, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres'),
	(2565, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(2566, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(2567, 'Details Updated', '2024-02-01', 1672, NULL, NULL, 'postgres'),
	(2568, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(2569, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(2570, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2571, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(2572, 'Details Updated', '2024-02-01', 2109, NULL, NULL, 'postgres'),
	(2573, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(2574, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(2575, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(2576, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(2577, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(2578, 'Details Updated', '2024-02-01', 1773, NULL, NULL, 'postgres'),
	(2579, 'Details Updated', '2024-02-01', 1781, NULL, NULL, 'postgres'),
	(2580, 'Details Updated', '2024-02-01', 1783, NULL, NULL, 'postgres'),
	(2581, 'Details Updated', '2024-02-01', 1794, NULL, NULL, 'postgres'),
	(2582, 'Details Updated', '2024-02-01', 1796, NULL, NULL, 'postgres'),
	(2583, 'Details Updated', '2024-02-01', 1802, NULL, NULL, 'postgres'),
	(2584, 'Details Updated', '2024-02-01', 1803, NULL, NULL, 'postgres'),
	(2585, 'Details Updated', '2024-02-01', 1805, NULL, NULL, 'postgres'),
	(2586, 'Details Updated', '2024-02-01', 1810, NULL, NULL, 'postgres'),
	(2587, 'Details Updated', '2024-02-01', 1816, NULL, NULL, 'postgres'),
	(2588, 'Details Updated', '2024-02-01', 1817, NULL, NULL, 'postgres'),
	(2589, 'Details Updated', '2024-02-01', 1820, NULL, NULL, 'postgres'),
	(2590, 'Details Updated', '2024-02-01', 1822, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2591, 'Details Updated', '2024-02-01', 1823, NULL, NULL, 'postgres'),
	(2592, 'Details Updated', '2024-02-01', 1824, NULL, NULL, 'postgres'),
	(2593, 'Details Updated', '2024-02-01', 1825, NULL, NULL, 'postgres'),
	(2594, 'Details Updated', '2024-02-01', 1826, NULL, NULL, 'postgres'),
	(2595, 'Details Updated', '2024-02-01', 1827, NULL, NULL, 'postgres'),
	(2596, 'Details Updated', '2024-02-01', 1828, NULL, NULL, 'postgres'),
	(2597, 'Details Updated', '2024-02-01', 1830, NULL, NULL, 'postgres'),
	(2598, 'Details Updated', '2024-02-01', 1831, NULL, NULL, 'postgres'),
	(2599, 'Details Updated', '2024-02-01', 1833, NULL, NULL, 'postgres'),
	(2600, 'Details Updated', '2024-02-01', 1834, NULL, NULL, 'postgres'),
	(2601, 'Details Updated', '2024-02-01', 1836, NULL, NULL, 'postgres'),
	(2602, 'Details Updated', '2024-02-01', 1843, NULL, NULL, 'postgres'),
	(2603, 'Details Updated', '2024-02-01', 1785, NULL, NULL, 'postgres'),
	(2604, 'Details Updated', '2024-02-01', 2073, NULL, NULL, 'postgres'),
	(2605, 'Details Updated', '2024-02-01', 2120, NULL, NULL, 'postgres'),
	(2606, 'Details Updated', '2024-02-01', 1856, NULL, NULL, 'postgres'),
	(2607, 'Details Updated', '2024-02-01', 1857, NULL, NULL, 'postgres'),
	(2608, 'Details Updated', '2024-02-01', 1874, NULL, NULL, 'postgres'),
	(2609, 'Details Updated', '2024-02-01', 1891, NULL, NULL, 'postgres'),
	(2610, 'Details Updated', '2024-02-01', 1893, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2611, 'Details Updated', '2024-02-01', 1896, NULL, NULL, 'postgres'),
	(2612, 'Details Updated', '2024-02-01', 1897, NULL, NULL, 'postgres'),
	(2613, 'Details Updated', '2024-02-01', 1903, NULL, NULL, 'postgres'),
	(2614, 'Details Updated', '2024-02-01', 1904, NULL, NULL, 'postgres'),
	(2615, 'Details Updated', '2024-02-01', 1911, NULL, NULL, 'postgres'),
	(2616, 'Details Updated', '2024-02-01', 1916, NULL, NULL, 'postgres'),
	(2617, 'Details Updated', '2024-02-01', 1755, NULL, NULL, 'postgres'),
	(2618, 'Details Updated', '2024-02-01', 2040, NULL, NULL, 'postgres'),
	(2619, 'Details Updated', '2024-02-01', 1736, NULL, NULL, 'postgres'),
	(2620, 'Details Updated', '2024-02-01', 1496, NULL, NULL, 'postgres'),
	(2621, 'Details Updated', '2024-02-01', 1498, NULL, NULL, 'postgres'),
	(2622, 'Details Updated', '2024-02-01', 1499, NULL, NULL, 'postgres'),
	(2623, 'Details Updated', '2024-02-01', 1500, NULL, NULL, 'postgres'),
	(2624, 'Details Updated', '2024-02-01', 1501, NULL, NULL, 'postgres'),
	(2625, 'Details Updated', '2024-02-01', 1502, NULL, NULL, 'postgres'),
	(2626, 'Details Updated', '2024-02-01', 1503, NULL, NULL, 'postgres'),
	(2627, 'Details Updated', '2024-02-01', 1505, NULL, NULL, 'postgres'),
	(2628, 'Details Updated', '2024-02-01', 1951, NULL, NULL, 'postgres'),
	(2629, 'Details Updated', '2024-02-01', 1952, NULL, NULL, 'postgres'),
	(2630, 'Details Updated', '2024-02-01', 1959, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2631, 'Details Updated', '2024-02-01', 1965, NULL, NULL, 'postgres'),
	(2632, 'Details Updated', '2024-02-01', 1966, NULL, NULL, 'postgres'),
	(2633, 'Details Updated', '2024-02-01', 1967, NULL, NULL, 'postgres'),
	(2634, 'Details Updated', '2024-02-01', 1968, NULL, NULL, 'postgres'),
	(2635, 'Details Updated', '2024-02-01', 1969, NULL, NULL, 'postgres'),
	(2636, 'Details Updated', '2024-02-01', 2022, NULL, NULL, 'postgres'),
	(2637, 'Details Updated', '2024-02-01', 2024, NULL, NULL, 'postgres'),
	(2638, 'Details Updated', '2024-02-01', 2025, NULL, NULL, 'postgres'),
	(2639, 'Details Updated', '2024-02-01', 1494, NULL, NULL, 'postgres'),
	(2640, 'Details Updated', '2024-02-01', 2032, NULL, NULL, 'postgres'),
	(2641, 'Details Updated', '2024-02-01', 1739, NULL, NULL, 'postgres'),
	(2642, 'Details Updated', '2024-02-01', 1756, NULL, NULL, 'postgres'),
	(2643, 'Details Updated', '2024-02-01', 1768, NULL, NULL, 'postgres'),
	(2644, 'Details Updated', '2024-02-01', 1787, NULL, NULL, 'postgres'),
	(2645, 'Details Updated', '2024-02-01', 1742, NULL, NULL, 'postgres'),
	(2646, 'Details Updated', '2024-02-01', 1763, NULL, NULL, 'postgres'),
	(2647, 'Details Updated', '2024-02-01', 1765, NULL, NULL, 'postgres'),
	(2648, 'Details Updated', '2024-02-01', 1767, NULL, NULL, 'postgres'),
	(2649, 'Details Updated', '2024-02-01', 1770, NULL, NULL, 'postgres'),
	(2650, 'Details Updated', '2024-02-01', 1746, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2651, 'Details Updated', '2024-02-01', 1786, NULL, NULL, 'postgres'),
	(2652, 'Details Updated', '2024-02-01', 1570, NULL, NULL, 'postgres'),
	(2653, 'Details Updated', '2024-02-01', 2066, NULL, NULL, 'postgres'),
	(2654, 'Details Updated', '2024-02-01', 2056, NULL, NULL, 'postgres'),
	(2655, 'Details Updated', '2024-02-01', 1743, NULL, NULL, 'postgres'),
	(2656, 'Details Updated', '2024-02-01', 1511, NULL, NULL, 'postgres'),
	(2657, 'Details Updated', '2024-02-01', 1512, NULL, NULL, 'postgres'),
	(2658, 'Details Updated', '2024-02-01', 1588, NULL, NULL, 'postgres'),
	(2659, 'Details Updated', '2024-02-01', 1513, NULL, NULL, 'postgres'),
	(2660, 'Details Updated', '2024-02-01', 1514, NULL, NULL, 'postgres'),
	(2661, 'Details Updated', '2024-02-01', 1515, NULL, NULL, 'postgres'),
	(2662, 'Details Updated', '2024-02-01', 1516, NULL, NULL, 'postgres'),
	(2663, 'Details Updated', '2024-02-01', 1519, NULL, NULL, 'postgres'),
	(2664, 'Details Updated', '2024-02-01', 1520, NULL, NULL, 'postgres'),
	(2665, 'Details Updated', '2024-02-01', 1521, NULL, NULL, 'postgres'),
	(2666, 'Details Updated', '2024-02-01', 1522, NULL, NULL, 'postgres'),
	(2667, 'Details Updated', '2024-02-01', 1523, NULL, NULL, 'postgres'),
	(2668, 'Details Updated', '2024-02-01', 1524, NULL, NULL, 'postgres'),
	(2669, 'Details Updated', '2024-02-01', 1525, NULL, NULL, 'postgres'),
	(2670, 'Details Updated', '2024-02-01', 1529, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2671, 'Details Updated', '2024-02-01', 1535, NULL, NULL, 'postgres'),
	(2672, 'Details Updated', '2024-02-01', 1537, NULL, NULL, 'postgres'),
	(2673, 'Details Updated', '2024-02-01', 1538, NULL, NULL, 'postgres'),
	(2674, 'Details Updated', '2024-02-01', 1539, NULL, NULL, 'postgres'),
	(2675, 'Details Updated', '2024-02-01', 1541, NULL, NULL, 'postgres'),
	(2676, 'Details Updated', '2024-02-01', 1542, NULL, NULL, 'postgres'),
	(2677, 'Details Updated', '2024-02-01', 1543, NULL, NULL, 'postgres'),
	(2678, 'Details Updated', '2024-02-01', 1545, NULL, NULL, 'postgres'),
	(2679, 'Details Updated', '2024-02-01', 1546, NULL, NULL, 'postgres'),
	(2680, 'Details Updated', '2024-02-01', 1547, NULL, NULL, 'postgres'),
	(2681, 'Details Updated', '2024-02-01', 1553, NULL, NULL, 'postgres'),
	(2682, 'Details Updated', '2024-02-01', 1554, NULL, NULL, 'postgres'),
	(2683, 'Details Updated', '2024-02-01', 1556, NULL, NULL, 'postgres'),
	(2684, 'Details Updated', '2024-02-01', 1557, NULL, NULL, 'postgres'),
	(2685, 'Details Updated', '2024-02-01', 1558, NULL, NULL, 'postgres'),
	(2686, 'Details Updated', '2024-02-01', 1608, NULL, NULL, 'postgres'),
	(2687, 'Details Updated', '2024-02-01', 1610, NULL, NULL, 'postgres'),
	(2688, 'Details Updated', '2024-02-01', 1611, NULL, NULL, 'postgres'),
	(2689, 'Details Updated', '2024-02-01', 1613, NULL, NULL, 'postgres'),
	(2690, 'Details Updated', '2024-02-01', 1614, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2691, 'Details Updated', '2024-02-01', 1633, NULL, NULL, 'postgres'),
	(2692, 'Details Updated', '2024-02-01', 1636, NULL, NULL, 'postgres'),
	(2693, 'Details Updated', '2024-02-01', 1657, NULL, NULL, 'postgres'),
	(2694, 'Details Updated', '2024-02-01', 1659, NULL, NULL, 'postgres'),
	(2695, 'Details Updated', '2024-02-01', 1660, NULL, NULL, 'postgres'),
	(2696, 'Details Updated', '2024-02-01', 1661, NULL, NULL, 'postgres'),
	(2697, 'Details Updated', '2024-02-01', 1662, NULL, NULL, 'postgres'),
	(2698, 'Details Updated', '2024-02-01', 1663, NULL, NULL, 'postgres'),
	(2699, 'Details Updated', '2024-02-01', 1665, NULL, NULL, 'postgres'),
	(2700, 'Details Updated', '2024-02-01', 1677, NULL, NULL, 'postgres'),
	(2701, 'Details Updated', '2024-02-01', 1678, NULL, NULL, 'postgres'),
	(2702, 'Details Updated', '2024-02-01', 1679, NULL, NULL, 'postgres'),
	(2703, 'Details Updated', '2024-02-01', 1680, NULL, NULL, 'postgres'),
	(2704, 'Details Updated', '2024-02-01', 1681, NULL, NULL, 'postgres'),
	(2705, 'Details Updated', '2024-02-01', 1692, NULL, NULL, 'postgres'),
	(2706, 'Details Updated', '2024-02-01', 1694, NULL, NULL, 'postgres'),
	(2707, 'Details Updated', '2024-02-01', 1696, NULL, NULL, 'postgres'),
	(2708, 'Details Updated', '2024-02-01', 1719, NULL, NULL, 'postgres'),
	(2709, 'Details Updated', '2024-02-01', 1720, NULL, NULL, 'postgres'),
	(2710, 'Details Updated', '2024-02-01', 1721, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2711, 'Details Updated', '2024-02-01', 1722, NULL, NULL, 'postgres'),
	(2712, 'Details Updated', '2024-02-01', 1729, NULL, NULL, 'postgres'),
	(2713, 'Details Updated', '2024-02-01', 1730, NULL, NULL, 'postgres'),
	(2714, 'Details Updated', '2024-02-01', 1508, NULL, NULL, 'postgres'),
	(2715, 'Details Updated', '2024-02-01', 1509, NULL, NULL, 'postgres'),
	(2716, 'Details Updated', '2024-02-01', 1510, NULL, NULL, 'postgres'),
	(2717, 'Details Updated', '2024-02-01', 2084, NULL, NULL, 'postgres'),
	(2718, 'Details Updated', '2024-02-01', 2063, NULL, NULL, 'postgres'),
	(2719, 'Details Updated', '2024-02-01', 1989, NULL, NULL, 'postgres'),
	(2720, 'Details Updated', '2024-02-01', 1999, NULL, NULL, 'postgres'),
	(2721, 'Details Updated', '2024-02-01', 1880, NULL, NULL, 'postgres'),
	(2722, 'Details Updated', '2024-02-01', 1848, NULL, NULL, 'postgres'),
	(2723, 'Details Updated', '2024-02-01', 1595, NULL, NULL, 'postgres'),
	(2724, 'Details Updated', '2024-02-01', 1700, NULL, NULL, 'postgres'),
	(2725, 'Details Updated', '2024-02-01', 1699, NULL, NULL, 'postgres'),
	(2726, 'Details Updated', '2024-02-01', 1718, NULL, NULL, 'postgres'),
	(2727, 'Details Updated', '2024-02-01', 1704, NULL, NULL, 'postgres'),
	(2728, 'Details Updated', '2024-02-01', 1702, NULL, NULL, 'postgres'),
	(2729, 'Details Updated', '2024-02-01', 1716, NULL, NULL, 'postgres'),
	(2730, 'Details Updated', '2024-02-01', 1594, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2731, 'Details Updated', '2024-02-01', 1596, NULL, NULL, 'postgres'),
	(2732, 'Details Updated', '2024-02-01', 1598, NULL, NULL, 'postgres'),
	(2733, 'Details Updated', '2024-02-01', 1714, NULL, NULL, 'postgres'),
	(2734, 'Details Updated', '2024-02-01', 1698, NULL, NULL, 'postgres'),
	(2735, 'Details Updated', '2024-02-01', 1905, NULL, NULL, 'postgres'),
	(2736, 'Details Updated', '2024-02-01', 1754, NULL, NULL, 'postgres'),
	(2737, 'Details Updated', '2024-02-01', 1757, NULL, NULL, 'postgres'),
	(2738, 'Details Updated', '2024-02-01', 2044, NULL, NULL, 'postgres'),
	(2739, 'Details Updated', '2024-02-01', 2050, NULL, NULL, 'postgres'),
	(2740, 'Details Updated', '2024-02-01', 1740, NULL, NULL, 'postgres'),
	(2741, 'Details Updated', '2024-02-01', 1738, NULL, NULL, 'postgres'),
	(2742, 'Details Updated', '2024-02-01', 1902, NULL, NULL, 'postgres'),
	(2743, 'Details Updated', '2024-02-01', 1901, NULL, NULL, 'postgres'),
	(2744, 'Details Updated', '2024-02-01', 2101, NULL, NULL, 'postgres'),
	(2745, 'Details Updated', '2024-02-01', 1900, NULL, NULL, 'postgres'),
	(2746, 'Details Updated', '2024-02-01', 2102, NULL, NULL, 'postgres'),
	(2747, 'Details Updated', '2024-02-01', 1533, NULL, NULL, 'postgres'),
	(2748, 'Details Updated', '2024-02-01', 1918, NULL, NULL, 'postgres'),
	(2749, 'Details Updated', '2024-02-01', 2099, NULL, NULL, 'postgres'),
	(2750, 'Details Updated', '2024-02-01', 1560, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2751, 'Details Updated', '2024-02-01', 1563, NULL, NULL, 'postgres'),
	(2752, 'Details Updated', '2024-02-01', 1573, NULL, NULL, 'postgres'),
	(2753, 'Details Updated', '2024-02-01', 1575, NULL, NULL, 'postgres'),
	(2754, 'Details Updated', '2024-02-01', 1576, NULL, NULL, 'postgres'),
	(2755, 'Details Updated', '2024-02-01', 1577, NULL, NULL, 'postgres'),
	(2756, 'Details Updated', '2024-02-01', 1639, NULL, NULL, 'postgres'),
	(2757, 'Details Updated', '2024-02-01', 1642, NULL, NULL, 'postgres'),
	(2758, 'Details Updated', '2024-02-01', 1643, NULL, NULL, 'postgres'),
	(2759, 'Details Updated', '2024-02-01', 1645, NULL, NULL, 'postgres'),
	(2760, 'Details Updated', '2024-02-01', 1647, NULL, NULL, 'postgres'),
	(2761, 'Details Updated', '2024-02-01', 1651, NULL, NULL, 'postgres'),
	(2762, 'Details Updated', '2024-02-01', 1652, NULL, NULL, 'postgres'),
	(2763, 'Details Updated', '2024-02-01', 1653, NULL, NULL, 'postgres'),
	(2764, 'Details Updated', '2024-02-01', 1654, NULL, NULL, 'postgres'),
	(2765, 'Details Updated', '2024-02-01', 1656, NULL, NULL, 'postgres'),
	(2766, 'Details Updated', '2024-02-01', 2053, NULL, NULL, 'postgres'),
	(2767, 'Details Updated', '2024-02-01', 2047, NULL, NULL, 'postgres'),
	(2768, 'Details Updated', '2024-02-01', 2045, NULL, NULL, 'postgres'),
	(2769, 'Details Updated', '2024-02-01', 1970, NULL, NULL, 'postgres'),
	(2770, 'Details Updated', '2024-02-01', 2051, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2771, 'Details Updated', '2024-02-01', 2006, NULL, NULL, 'postgres'),
	(2772, 'Details Updated', '2024-02-01', 1996, NULL, NULL, 'postgres'),
	(2773, 'Details Updated', '2024-02-01', 2049, NULL, NULL, 'postgres'),
	(2774, 'Details Updated', '2024-02-01', 1995, NULL, NULL, 'postgres'),
	(2775, 'Details Updated', '2024-02-01', 1997, NULL, NULL, 'postgres'),
	(2776, 'Details Updated', '2024-02-01', 2072, NULL, NULL, 'postgres'),
	(2777, 'Details Updated', '2024-02-01', 2067, NULL, NULL, 'postgres'),
	(2778, 'Details Updated', '2024-02-01', 2093, NULL, NULL, 'postgres'),
	(2779, 'Details Updated', '2024-02-01', 2095, NULL, NULL, 'postgres'),
	(2780, 'Details Updated', '2024-02-01', 2094, NULL, NULL, 'postgres'),
	(2781, 'Details Updated', '2024-02-01', 2092, NULL, NULL, 'postgres'),
	(2782, 'Details Updated', '2024-02-01', 2114, NULL, NULL, 'postgres'),
	(2783, 'Details Updated', '2024-02-01', 2071, NULL, NULL, 'postgres'),
	(2784, 'Details Updated', '2024-02-01', 2117, NULL, NULL, 'postgres'),
	(2785, 'Details Updated', '2024-02-01', 2116, NULL, NULL, 'postgres'),
	(2786, 'Details Updated', '2024-02-01', 2115, NULL, NULL, 'postgres'),
	(2787, 'Details Updated', '2024-02-01', 1898, NULL, NULL, 'postgres'),
	(2788, 'Details Updated', '2024-02-01', 1669, NULL, NULL, 'postgres'),
	(2789, 'Details Updated', '2024-02-01', 2110, NULL, NULL, 'postgres'),
	(2790, 'Details Updated', '2024-02-01', 2111, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2791, 'Details Updated', '2024-02-01', 2112, NULL, NULL, 'postgres'),
	(2792, 'Details Updated', '2024-02-01', 2103, NULL, NULL, 'postgres'),
	(2793, 'Details Updated', '2024-02-01', 2107, NULL, NULL, 'postgres'),
	(2794, 'Details Updated', '2024-02-01', 1774, NULL, NULL, 'postgres'),
	(2795, 'Details Updated', '2024-02-01', 1804, NULL, NULL, 'postgres'),
	(2796, 'Details Updated', '2024-02-01', 1809, NULL, NULL, 'postgres'),
	(2797, 'Details Updated', '2024-02-01', 1821, NULL, NULL, 'postgres'),
	(2798, 'Details Updated', '2024-02-01', 1829, NULL, NULL, 'postgres'),
	(2799, 'Details Updated', '2024-02-01', 1832, NULL, NULL, 'postgres'),
	(2800, 'Details Updated', '2024-02-01', 1835, NULL, NULL, 'postgres'),
	(2801, 'Details Updated', '2024-02-01', 1837, NULL, NULL, 'postgres'),
	(2802, 'Details Updated', '2024-02-01', 1838, NULL, NULL, 'postgres'),
	(2803, 'Details Updated', '2024-02-01', 1839, NULL, NULL, 'postgres'),
	(2804, 'Details Updated', '2024-02-01', 1909, NULL, NULL, 'postgres'),
	(2805, 'Details Updated', '2024-02-01', 1910, NULL, NULL, 'postgres'),
	(2806, 'Details Updated', '2024-02-01', 2029, NULL, NULL, 'postgres'),
	(2807, 'Details Updated', '2024-02-01', 1927, NULL, NULL, 'postgres'),
	(2808, 'Details Updated', '2024-02-01', 1737, NULL, NULL, 'postgres'),
	(2809, 'Details Updated', '2024-02-01', 1733, NULL, NULL, 'postgres'),
	(2810, 'Details Updated', '2024-02-01', 2026, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2811, 'Details Updated', '2024-02-01', 2096, NULL, NULL, 'postgres'),
	(2812, 'Details Updated', '2024-02-01', 1764, NULL, NULL, 'postgres'),
	(2813, 'Details Updated', '2024-02-01', 1766, NULL, NULL, 'postgres'),
	(2814, 'Details Updated', '2024-02-01', 1771, NULL, NULL, 'postgres'),
	(2815, 'Details Updated', '2024-02-01', 1790, NULL, NULL, 'postgres'),
	(2816, 'Details Updated', '2024-02-01', 1877, NULL, NULL, 'postgres'),
	(2817, 'Details Updated', '2024-02-01', 1879, NULL, NULL, 'postgres'),
	(2818, 'Details Updated', '2024-02-01', 2060, NULL, NULL, 'postgres'),
	(2819, 'Details Updated', '2024-02-01', 1878, NULL, NULL, 'postgres'),
	(2820, 'Details Updated', '2024-02-01', 1527, NULL, NULL, 'postgres'),
	(2821, 'Details Updated', '2024-02-01', 1534, NULL, NULL, 'postgres'),
	(2822, 'Details Updated', '2024-02-01', 1548, NULL, NULL, 'postgres'),
	(2823, 'Details Updated', '2024-02-01', 1555, NULL, NULL, 'postgres'),
	(2824, 'Details Updated', '2024-02-01', 1578, NULL, NULL, 'postgres'),
	(2825, 'Details Updated', '2024-02-01', 1580, NULL, NULL, 'postgres'),
	(2826, 'Details Updated', '2024-02-01', 1602, NULL, NULL, 'postgres'),
	(2827, 'Details Updated', '2024-02-01', 1609, NULL, NULL, 'postgres'),
	(2828, 'Details Updated', '2024-02-01', 1612, NULL, NULL, 'postgres'),
	(2829, 'Details Updated', '2024-02-01', 1638, NULL, NULL, 'postgres'),
	(2830, 'Details Updated', '2024-02-01', 1655, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2831, 'Details Updated', '2024-02-01', 1658, NULL, NULL, 'postgres'),
	(2832, 'Details Updated', '2024-02-01', 1686, NULL, NULL, 'postgres'),
	(2833, 'Details Updated', '2024-02-01', 1688, NULL, NULL, 'postgres'),
	(2834, 'Details Updated', '2024-02-01', 1693, NULL, NULL, 'postgres'),
	(2835, 'Details Updated', '2024-02-01', 1994, NULL, NULL, 'postgres'),
	(2836, 'Details Updated', '2024-02-01', 2058, NULL, NULL, 'postgres'),
	(2837, 'Details Updated', '2024-02-01', 1712, NULL, NULL, 'postgres'),
	(2838, 'Details Updated', '2024-02-01', 1592, NULL, NULL, 'postgres'),
	(2839, 'Details Updated', '2024-02-01', 1710, NULL, NULL, 'postgres'),
	(2840, 'Details Updated', '2024-02-01', 2046, NULL, NULL, 'postgres'),
	(2841, 'Details Updated', '2024-02-01', 1713, NULL, NULL, 'postgres'),
	(2842, 'Details Updated', '2024-02-01', 1703, NULL, NULL, 'postgres'),
	(2843, 'Details Updated', '2024-02-01', 2057, NULL, NULL, 'postgres'),
	(2844, 'Details Updated', '2024-02-01', 1844, NULL, NULL, 'postgres'),
	(2845, 'Details Updated', '2024-02-01', 1819, NULL, NULL, 'postgres'),
	(2846, 'Details Updated', '2024-02-01', 1894, NULL, NULL, 'postgres'),
	(2847, 'Details Updated', '2024-02-01', 1899, NULL, NULL, 'postgres'),
	(2848, 'Details Updated', '2024-02-01', 1915, NULL, NULL, 'postgres'),
	(2849, 'Details Updated', '2024-02-01', 1923, NULL, NULL, 'postgres'),
	(2850, 'Details Updated', '2024-02-01', 1924, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2851, 'Details Updated', '2024-02-01', 2100, NULL, NULL, 'postgres'),
	(2852, 'Details Updated', '2024-02-01', 1531, NULL, NULL, 'postgres'),
	(2853, 'Details Updated', '2024-02-01', 1550, NULL, NULL, 'postgres'),
	(2854, 'Details Updated', '2024-02-01', 1561, NULL, NULL, 'postgres'),
	(2855, 'Details Updated', '2024-02-01', 1640, NULL, NULL, 'postgres'),
	(2856, 'Details Updated', '2024-02-01', 1644, NULL, NULL, 'postgres'),
	(2857, 'Details Updated', '2024-02-01', 1648, NULL, NULL, 'postgres'),
	(2858, 'Details Updated', '2024-02-01', 1650, NULL, NULL, 'postgres'),
	(2859, 'Details Updated', '2024-02-01', 2113, NULL, NULL, 'postgres'),
	(2860, 'Details Updated', '2024-02-01', 2118, NULL, NULL, 'postgres'),
	(2861, 'Details Updated', '2024-02-01', 1670, NULL, NULL, 'postgres'),
	(2862, 'Details Updated', '2024-02-01', 2106, NULL, NULL, 'postgres'),
	(2863, 'Details Updated', '2024-02-01', 2108, NULL, NULL, 'postgres'),
	(2864, 'Details Updated', '2024-02-01', 1782, NULL, NULL, 'postgres'),
	(2865, 'Details Updated', '2024-02-01', 1784, NULL, NULL, 'postgres'),
	(2866, 'Details Updated', '2024-02-01', 1789, NULL, NULL, 'postgres'),
	(2867, 'Details Updated', '2024-02-01', 1792, NULL, NULL, 'postgres'),
	(2868, 'Details Updated', '2024-02-01', 1793, NULL, NULL, 'postgres'),
	(2869, 'Details Updated', '2024-02-01', 1799, NULL, NULL, 'postgres'),
	(2870, 'Details Updated', '2024-02-01', 1801, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2871, 'Details Updated', '2024-02-01', 1865, NULL, NULL, 'postgres'),
	(2872, 'Details Updated', '2024-02-01', 1495, NULL, NULL, 'postgres'),
	(2873, 'Details Updated', '2024-02-01', 1497, NULL, NULL, 'postgres'),
	(2874, 'Details Updated', '2024-02-01', 1504, NULL, NULL, 'postgres'),
	(2875, 'Details Updated', '2024-02-01', 1506, NULL, NULL, 'postgres'),
	(2876, 'Details Updated', '2024-02-01', 1507, NULL, NULL, 'postgres'),
	(2877, 'Details Updated', '2024-02-01', 2098, NULL, NULL, 'postgres'),
	(2878, 'Details Updated', '2024-02-01', 1980, NULL, NULL, 'postgres'),
	(2879, 'Details Updated', '2024-02-01', 1981, NULL, NULL, 'postgres'),
	(2880, 'Details Updated', '2024-02-01', 1982, NULL, NULL, 'postgres'),
	(2881, 'Details Updated', '2024-02-01', 2055, NULL, NULL, 'postgres'),
	(2882, 'Details Updated', '2024-02-01', 1726, NULL, NULL, 'postgres'),
	(2883, 'Details Updated', '2024-02-01', 1728, NULL, NULL, 'postgres'),
	(2884, 'Details Updated', '2024-02-01', 1549, NULL, NULL, 'postgres'),
	(2885, 'Details Updated', '2024-02-01', 1579, NULL, NULL, 'postgres'),
	(2886, 'Details Updated', '2024-02-01', 1624, NULL, NULL, 'postgres'),
	(2887, 'Details Updated', '2024-02-01', 1625, NULL, NULL, 'postgres'),
	(2888, 'Details Updated', '2024-02-01', 1626, NULL, NULL, 'postgres'),
	(2889, 'Details Updated', '2024-02-01', 1627, NULL, NULL, 'postgres'),
	(2890, 'Details Updated', '2024-02-01', 1628, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2891, 'Details Updated', '2024-02-01', 1629, NULL, NULL, 'postgres'),
	(2892, 'Details Updated', '2024-02-01', 1630, NULL, NULL, 'postgres'),
	(2893, 'Details Updated', '2024-02-01', 1634, NULL, NULL, 'postgres'),
	(2894, 'Details Updated', '2024-02-01', 1635, NULL, NULL, 'postgres'),
	(2895, 'Details Updated', '2024-02-01', 1637, NULL, NULL, 'postgres'),
	(2896, 'Details Updated', '2024-02-01', 1682, NULL, NULL, 'postgres'),
	(2897, 'Details Updated', '2024-02-01', 1685, NULL, NULL, 'postgres'),
	(2898, 'Details Updated', '2024-02-01', 1689, NULL, NULL, 'postgres'),
	(2899, 'Details Updated', '2024-02-01', 1695, NULL, NULL, 'postgres'),
	(2900, 'Details Updated', '2024-02-01', 1674, NULL, NULL, 'postgres'),
	(2901, 'Details Updated', '2024-02-01', 1706, NULL, NULL, 'postgres'),
	(2902, 'Details Updated', '2024-02-01', 2097, NULL, NULL, 'postgres'),
	(2903, 'Details Updated', '2024-02-01', 1646, NULL, NULL, 'postgres'),
	(2904, 'Details Updated', '2024-02-01', 1649, NULL, NULL, 'postgres'),
	(2905, 'Details Updated', '2024-02-01', 1983, NULL, NULL, 'postgres'),
	(2906, 'Details Updated', '2024-02-01', 2104, NULL, NULL, 'postgres'),
	(2907, 'Details Updated', '2024-02-01', 2105, NULL, NULL, 'postgres'),
	(2908, 'Details Updated', '2024-02-01', 1807, NULL, NULL, 'postgres'),
	(2909, 'Details Updated', '2024-02-01', 1808, NULL, NULL, 'postgres'),
	(2910, 'Details Updated', '2024-02-01', 1815, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2911, 'Details Updated', '2024-02-01', 1993, NULL, NULL, 'postgres'),
	(2912, 'Details Updated', '2024-02-01', 1772, NULL, NULL, 'postgres'),
	(2913, 'Details Updated', '2024-02-01', 1526, NULL, NULL, 'postgres'),
	(2914, 'Details Updated', '2024-02-01', 1528, NULL, NULL, 'postgres'),
	(2915, 'Details Updated', '2024-02-01', 1532, NULL, NULL, 'postgres'),
	(2916, 'Details Updated', '2024-02-01', 1536, NULL, NULL, 'postgres'),
	(2917, 'Details Updated', '2024-02-01', 1684, NULL, NULL, 'postgres'),
	(2918, 'Details Updated', '2024-02-01', 1687, NULL, NULL, 'postgres'),
	(2919, 'Details Updated', '2024-02-01', 1705, NULL, NULL, 'postgres'),
	(2920, 'Details Updated', '2024-02-01', 1906, NULL, NULL, 'postgres'),
	(2921, 'Details Updated', '2024-02-01', 1744, NULL, NULL, 'postgres'),
	(2922, 'Details Updated', '2024-02-01', 2054, NULL, NULL, 'postgres'),
	(2923, 'Details Updated', '2024-02-01', 1701, NULL, NULL, 'postgres'),
	(2924, 'Details Updated', '2024-02-01', 1990, NULL, NULL, 'postgres'),
	(2925, 'Details Updated', '2024-02-01', 1562, NULL, NULL, 'postgres'),
	(2926, 'Details Updated', '2024-02-01', 1991, NULL, NULL, 'postgres'),
	(2927, 'Details Updated', '2024-02-01', 2042, NULL, NULL, 'postgres'),
	(2928, 'Details Updated', '2024-02-01', 2048, NULL, NULL, 'postgres'),
	(2929, 'Details Updated', '2024-02-01', 2052, NULL, NULL, 'postgres'),
	(2930, 'Details Updated', '2024-02-01', 2121, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2931, 'Details Updated', '2024-02-01', 1775, NULL, NULL, 'postgres'),
	(2932, 'Details Updated', '2024-02-01', 1776, NULL, NULL, 'postgres'),
	(2933, 'Details Updated', '2024-02-01', 1777, NULL, NULL, 'postgres'),
	(2934, 'Details Updated', '2024-02-01', 1778, NULL, NULL, 'postgres'),
	(2935, 'Details Updated', '2024-02-01', 1779, NULL, NULL, 'postgres'),
	(2936, 'Details Updated', '2024-02-01', 1780, NULL, NULL, 'postgres'),
	(2937, 'Details Updated', '2024-02-01', 1890, NULL, NULL, 'postgres'),
	(2938, 'Details Updated', '2024-02-01', 1960, NULL, NULL, 'postgres'),
	(2939, 'Details Updated', '2024-02-01', 2002, NULL, NULL, 'postgres'),
	(2940, 'Details Updated', '2024-02-01', 2027, NULL, NULL, 'postgres'),
	(2941, 'Details Updated', '2024-02-01', 1741, NULL, NULL, 'postgres'),
	(2942, 'Details Updated', '2024-02-01', 1892, NULL, NULL, 'postgres'),
	(2943, 'Details Updated', '2024-02-01', 2043, NULL, NULL, 'postgres'),
	(2944, 'Details Updated', '2024-02-01', 2031, NULL, NULL, 'postgres'),
	(2945, 'Details Updated', '2024-02-01', 2041, NULL, NULL, 'postgres'),
	(2946, 'Details Updated', '2024-02-01', 2122, NULL, NULL, 'postgres'),
	(2947, 'Details Updated', '2024-02-01', 2074, NULL, NULL, 'postgres'),
	(2948, 'Details Updated', '2024-02-01', 1673, NULL, NULL, 'postgres'),
	(2949, 'Details Updated', '2024-02-01', 1872, NULL, NULL, 'postgres'),
	(2950, 'Details Updated', '2024-02-01', 1861, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2951, 'Details Updated', '2024-02-01', 1566, NULL, NULL, 'postgres'),
	(2952, 'Details Updated', '2024-02-01', 1724, NULL, NULL, 'postgres'),
	(2953, 'Details Updated', '2024-02-01', 1593, NULL, NULL, 'postgres'),
	(2954, 'Details Updated', '2024-02-01', 1800, NULL, NULL, 'postgres'),
	(2955, 'Details Updated', '2024-02-01', 2033, NULL, NULL, 'postgres'),
	(2956, 'Details Updated', '2024-02-01', 1727, NULL, NULL, 'postgres'),
	(2957, 'Details Updated', '2024-02-01', 1806, NULL, NULL, 'postgres'),
	(2958, 'Details Updated', '2024-02-01', 2028, NULL, NULL, 'postgres'),
	(2959, 'Details Updated', '2024-02-01', 1842, NULL, NULL, 'postgres'),
	(2960, 'Details Updated', '2024-02-01', 1788, NULL, NULL, 'postgres'),
	(2961, 'Details Updated', '2024-02-01', 1518, NULL, NULL, 'postgres'),
	(2962, 'Details Updated', '2024-02-01', 1540, NULL, NULL, 'postgres'),
	(2963, 'Details Updated', '2024-02-01', 2119, NULL, NULL, 'postgres'),
	(2964, 'Details Updated', '2024-02-01', 1814, NULL, NULL, 'postgres'),
	(2965, 'Details Updated', '2024-02-01', 1881, NULL, NULL, 'postgres'),
	(2966, 'Details Updated', '2024-02-01', 1882, NULL, NULL, 'postgres'),
	(2967, 'Details Updated', '2024-02-01', 1750, NULL, NULL, 'postgres'),
	(2968, 'Details Updated', '2024-02-01', 1517, NULL, NULL, 'postgres'),
	(2969, 'Details Updated', '2024-02-01', 2087, NULL, NULL, 'postgres'),
	(2970, 'Details Updated', '2024-02-01', 1907, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;
INSERT INTO "public"."instrument_history" ("id", "transaction_type", "transaction_timestamp", "item_id", "notes", "assigned_to", "created_by") VALUES
	(2971, 'Details Updated', '2024-02-01', 1565, NULL, NULL, 'postgres'),
	(2972, 'Details Updated', '2024-02-01', 1603, NULL, NULL, 'postgres'),
	(2973, 'Details Updated', '2024-02-01', 1795, NULL, NULL, 'postgres'),
	(2974, 'Details Updated', '2024-02-01', 1797, NULL, NULL, 'postgres'),
	(2975, 'Details Updated', '2024-02-01', 1889, NULL, NULL, 'postgres') ON CONFLICT DO NOTHING;


--
-- TOC entry 3914 (class 0 OID 24202)
-- Dependencies: 218
-- Data for Name: instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1734, 216, NULL, 'STAND, GUITAR', NULL, 'Good', 'HS MUSIC', 'UNKNOWN', NULL, NULL, 1, NULL, NULL),
	(1774, 589, 'SXA', 'SAXOPHONE, ALTO', '11110739', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 24, NULL, NULL),
	(1773, 519, 'FL', 'FLUTE', '28411028', 'Good', 'INSTRUMENT STORE', 'PRELUDE', NULL, 'FL', 24, NULL, NULL),
	(1791, 302, 'TBN', 'TUBANOS', NULL, 'Good', 'MS MUSIC', 'REMO', '14 inch', NULL, 4, NULL, NULL),
	(1798, 401, 'BS', 'BASSOON', '33CVC02', 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 1, NULL, NULL),
	(1804, 566, 'SXA', 'SAXOPHONE, ALTO', '11120071', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 1, NULL, NULL),
	(1809, 622, 'SXA', 'SAXOPHONE, ALTO', 'YF57624', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 53, NULL, NULL),
	(1811, 287, 'SR', 'SNARE', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 3, NULL, NULL),
	(1813, 207, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 7, NULL, NULL),
	(1821, 631, 'SXA', 'SAXOPHONE, ALTO', 'BF54273', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 62, NULL, NULL),
	(1829, 626, 'SXA', 'SAXOPHONE, ALTO', 'AF53354', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 57, NULL, NULL),
	(1818, 243, 'CG', 'CONGA', NULL, 'Good', 'MS MUSIC', 'MEINL', 'HEADLINER RANGE', NULL, 2, NULL, NULL),
	(1832, 627, 'SXA', 'SAXOPHONE, ALTO', 'AF53345', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 58, NULL, NULL),
	(1835, 630, 'SXA', 'SAXOPHONE, ALTO', 'BF54625', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 61, NULL, NULL),
	(1837, 637, 'SXA', 'SAXOPHONE, ALTO', 'CF57292', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 68, NULL, NULL),
	(1838, 638, 'SXA', 'SAXOPHONE, ALTO', 'CF57202', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 69, NULL, NULL),
	(1839, 639, 'SXA', 'SAXOPHONE, ALTO', 'CF56658', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 70, NULL, NULL),
	(1782, 78, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 46, NULL, NULL),
	(1784, 79, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 47, NULL, NULL),
	(1789, 80, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 48, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1792, 56, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 24, NULL, NULL),
	(1793, 36, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 4, NULL, NULL),
	(1799, 37, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 5, NULL, NULL),
	(1801, 33, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 1, NULL, NULL),
	(1807, 653, 'SXT', 'SAXOPHONE, TENOR', 'N495304', 'Good', 'INSTRUMENT STORE', 'SELMER', NULL, 'TX', 9, NULL, NULL),
	(1840, 238, 'CLV', 'CLAVES', NULL, 'Good', 'MS MUSIC', 'LP', 'GRENADILLA', NULL, 2, NULL, NULL),
	(1841, 251, 'CWB', 'COWBELL', NULL, 'Good', 'MS MUSIC', 'LP', 'Black Beauty', NULL, 2, NULL, NULL),
	(1808, 657, 'SXT', 'SAXOPHONE, TENOR', 'TS10050022', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'TX', 13, NULL, NULL),
	(1781, 525, 'FL', 'FLUTE', 'D1206510', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 30, NULL, NULL),
	(1815, 647, 'SXT', 'SAXOPHONE, TENOR', '31840', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TX', 3, NULL, NULL),
	(1775, 25, 'TN', 'TROMBONE, TENOR', '452363', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TB', 11, NULL, NULL),
	(1776, 27, 'TN', 'TROMBONE, TENOR', '9120158', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'TB', 13, NULL, NULL),
	(1777, 28, 'TN', 'TROMBONE, TENOR', '9120243', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'TB', 14, NULL, NULL),
	(1783, 159, 'TP', 'TRUMPET, B FLAT', 'CAS15598', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 70, NULL, NULL),
	(1794, 490, 'FL', 'FLUTE', '2922376', 'Good', 'INSTRUMENT STORE', 'WT.AMSTRONG', '104', 'FL', 7, NULL, NULL),
	(1796, 13, 'M', 'MELLOPHONE', 'L02630', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'M', 1, NULL, NULL),
	(1802, 562, 'OB', 'OBOE', 'B33327', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'OB', 1, NULL, NULL),
	(1803, 564, 'PC', 'PICCOLO', '11010007', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'PC', 1, NULL, NULL),
	(1778, 29, 'TN', 'TROMBONE, TENOR', '9120157', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'TB', 15, NULL, NULL),
	(1779, 30, 'TN', 'TROMBONE, TENOR', '1107197', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TB', 16, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1780, 31, 'TN', 'TROMBONE, TENOR', '1107273', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TB', 17, NULL, NULL),
	(1735, 226, 'BLT', 'BELLS, TUBULAR', NULL, 'Good', 'HS MUSIC', 'ROSS', NULL, NULL, 1, NULL, NULL),
	(1909, 582, 'SXA', 'SAXOPHONE, ALTO', '388666A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 17, NULL, NULL),
	(1910, 583, 'SXA', 'SAXOPHONE, ALTO', 'T14584', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YAS 23', 'AX', 18, NULL, NULL),
	(1845, 293, 'TR', 'TAMBOURINE', NULL, 'Good', 'MS MUSIC', 'REMO', 'Fiberskyn 3 black', NULL, 2, NULL, NULL),
	(1846, 199, 'PU', 'PIANO, UPRIGHT', NULL, 'Good', 'PRACTICE ROOM 2', 'EAVESTAFF', NULL, NULL, 2, NULL, NULL),
	(1847, 200, 'PU', 'PIANO, UPRIGHT', NULL, 'Good', 'PRACTICE ROOM 3', 'SPENCER', NULL, NULL, 3, NULL, NULL),
	(1849, 272, 'Q', 'QUAD, MARCHING', '202902', 'Good', 'MS MUSIC', 'PEARL', 'Black', NULL, 1, NULL, NULL),
	(1850, 385, 'GRT', 'GUITAR, HALF', '11', 'Good', NULL, 'KAY', NULL, NULL, 1, NULL, NULL),
	(1851, 387, 'GRT', 'GUITAR, HALF', '9', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 3, NULL, NULL),
	(1852, 267, 'EGS', 'EGG SHAKERS', NULL, 'Good', 'MS MUSIC', 'LP', 'Black 2 pr', NULL, 2, NULL, NULL),
	(1853, 271, 'MRC', 'MARACAS', NULL, 'Good', 'MS MUSIC', 'LP', 'Pro Yellow Light Handle', NULL, 2, NULL, NULL),
	(1854, 210, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 10, NULL, NULL),
	(1855, 211, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 11, NULL, NULL),
	(2029, 574, 'SXA', 'SAXOPHONE, ALTO', '348075', 'Good', NULL, 'YAMAHA', NULL, 'AX', 9, 'Mwende Mittelstadt', 192),
	(1927, 579, 'SXA', 'SAXOPHONE, ALTO', '290365', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 14, NULL, NULL),
	(1858, 306, 'WB', 'WOOD BLOCK', NULL, 'Good', 'HS MUSIC', 'BLACK SWAMP', 'BLA-MWB1', NULL, 1, NULL, NULL),
	(1812, 206, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 6, NULL, NULL),
	(1859, 166, 'AM', 'AMPLIFIER', '72168', 'Good', 'MS MUSIC', 'GALLEN-K', NULL, NULL, 2, NULL, NULL),
	(1860, 317, 'CMS', 'CYMBAL, SUSPENDED 18 INCH', 'AD 69101 046', 'Good', 'HS MUSIC', 'ZILDJIAN', 'Orchestral Selection ZIL-A0419', NULL, 1, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1862, 348, 'GRB', 'GUITAR, BASS', 'CGF1307326', 'Good', 'DRUM ROOM 1', 'FENDER', NULL, NULL, 5, NULL, NULL),
	(1863, 388, 'GRT', 'GUITAR, HALF', '4', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 4, NULL, NULL),
	(1864, 168, 'AMB', 'AMPLIFIER, BASS', 'M 1053205', 'Good', 'DRUM ROOM 1', 'FENDER', 'BASSMAN', NULL, 4, NULL, NULL),
	(1866, 393, 'GRT', 'GUITAR, HALF', '8', 'Good', NULL, 'KAY', NULL, NULL, 9, NULL, NULL),
	(1873, 242, 'CG', 'CONGA', NULL, 'Good', 'MS MUSIC', 'YAMAHA', 'Red 14 inch', NULL, 1, NULL, NULL),
	(1867, 247, 'CG', 'CONGA', 'ISK 3120157238', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '12 inch', NULL, 4, NULL, NULL),
	(1868, 248, 'CG', 'CONGA', 'ISK 23 JAN 02', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '14 Inch', NULL, 5, NULL, NULL),
	(1869, 244, 'CG', 'CONGA', 'ISK 3120138881', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '10 Inch', NULL, 3, NULL, NULL),
	(1870, 249, 'CG', 'CONGA', 'ISK 312138881', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '10 Inch', NULL, 6, NULL, NULL),
	(1871, 250, 'CG', 'CONGA', 'ISK 312120138881', 'Good', 'MS MUSIC', 'LATIN PERCUSSION', '10 Inch', NULL, 7, NULL, NULL),
	(1865, 46, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'MS MUSIC', 'TROMBA', 'Pro', 'PTB', 14, NULL, NULL),
	(1875, 183, 'KB', 'KEYBOARD', 'AH24202', 'Good', NULL, 'ROLAND', '813', NULL, 1, NULL, NULL),
	(1883, 264, 'DK', 'DRUMSET', NULL, 'Good', 'MS MUSIC', 'PEARL', 'Vision', NULL, 3, NULL, NULL),
	(1884, 325, 'SR', 'SNARE', NULL, 'Good', 'UPPER ES MUSIC', 'PEARL', NULL, NULL, 4, NULL, NULL),
	(1887, 205, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 5, NULL, NULL),
	(1888, 274, 'SRM', 'SNARE, MARCHING', '1P-3095', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 1, NULL, NULL),
	(1993, 665, 'SXT', 'SAXOPHONE, TENOR', 'CF07553', 'Good', NULL, 'JUPITER', 'JTS700', 'TX', 21, 'Naomi Yohannes', 361),
	(1890, 22, 'TN', 'TROMBONE, TENOR', '320963', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'TB', 8, NULL, NULL),
	(1881, 39, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM17120413', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 7, NULL, NULL),
	(1882, 41, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM17120388', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 9, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1889, 164, 'SSP', 'SOUSAPHONE', '910530', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'T', 1, NULL, NULL),
	(1912, 241, 'SRC', 'SNARE, CONCERT', NULL, 'Good', 'HS MUSIC', 'BLACK SWAMP', 'BLA-CM514BL', NULL, 1, NULL, NULL),
	(1913, 297, 'TPT', 'TIMPANI, 23 INCH', '52479', 'Good', 'HS MUSIC', 'LUDWIG', 'LKS423FG', NULL, 6, NULL, NULL),
	(1914, 282, NULL, 'SHIELD', NULL, 'Good', 'HS MUSIC', 'GIBRALTAR', 'GIB-GDS-5', NULL, 1, NULL, NULL),
	(1917, 280, 'PK', 'PRACTICE KIT', NULL, 'Good', 'UPPER ES MUSIC', 'PEARL', NULL, NULL, 1, NULL, NULL),
	(1919, 261, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 6, NULL, NULL),
	(1920, 259, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 4, NULL, NULL),
	(1921, 224, 'RK', 'RAINSTICK', NULL, 'Good', 'UPPER ES MUSIC', 'CUSTOM', NULL, NULL, 3, NULL, NULL),
	(1805, 417, 'CL', 'CLARINET, B FLAT', '989832', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'CL', 9, NULL, NULL),
	(1810, 107, 'TP', 'TRUMPET, B FLAT', 'H34971', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 27, NULL, NULL),
	(1816, 413, 'CL', 'CLARINET, B FLAT', '7943', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 6, NULL, NULL),
	(1817, 432, 'CL', 'CLARINET, B FLAT', '444451', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 24, NULL, NULL),
	(1820, 556, 'FL', 'FLUTE', 'BD62736', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 62, NULL, NULL),
	(1822, 471, 'CL', 'CLARINET, B FLAT', 'YE67775', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 63, NULL, NULL),
	(1823, 472, 'CL', 'CLARINET, B FLAT', 'YE67468', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 64, NULL, NULL),
	(1824, 476, 'CL', 'CLARINET, B FLAT', 'BE63558', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 68, NULL, NULL),
	(1825, 462, 'CL', 'CLARINET, B FLAT', 'XE50000', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 54, NULL, NULL),
	(1826, 549, 'FL', 'FLUTE', 'YD66218', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 55, NULL, NULL),
	(1827, 550, 'FL', 'FLUTE', 'YD66291', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 56, NULL, NULL),
	(1828, 465, 'CL', 'CLARINET, B FLAT', 'XE54699', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 57, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1830, 466, 'CL', 'CLARINET, B FLAT', 'XE54697', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 58, NULL, NULL),
	(1831, 552, 'FL', 'FLUTE', 'BD62678', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 58, NULL, NULL),
	(1833, 553, 'FL', 'FLUTE', 'BD63526', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 59, NULL, NULL),
	(1922, 331, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 3, NULL, NULL),
	(1928, 227, 'VS', 'VIBRASLAP', NULL, 'Good', 'HS MUSIC', 'WEISS', 'SW-VIBRA', NULL, 1, NULL, NULL),
	(1834, 554, 'FL', 'FLUTE', 'BD63433', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 60, NULL, NULL),
	(1737, 576, 'SXA', 'SAXOPHONE, ALTO', '3468', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'AX', 11, NULL, NULL),
	(1925, 235, 'CST', 'CASTANETS', NULL, 'Good', 'HS MUSIC', 'DANMAR', 'DAN-17A', NULL, 1, NULL, NULL),
	(1733, 611, 'SXA', 'SAXOPHONE, ALTO', 'XF53790', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 42, 'Olivia Freiin Von Handel', 933),
	(1530, 315, 'BL', 'BELL SET', NULL, 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 4, NULL, NULL),
	(1926, 169, 'AMB', 'AMPLIFIER, BASS', 'AX78271', 'Good', 'MS MUSIC', 'ROLAND', 'CUBE-100', NULL, 5, NULL, NULL),
	(1886, 204, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 4, NULL, NULL),
	(1929, 223, 'RK', 'RAINSTICK', NULL, 'Good', 'UPPER ES MUSIC', 'CUSTOM', NULL, NULL, 2, NULL, NULL),
	(1930, 330, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 2, NULL, NULL),
	(1491, 273, 'Q', 'QUAD, MARCHING', '203143', 'Good', 'MS MUSIC', 'PEARL', 'Black', NULL, 2, NULL, NULL),
	(1492, 276, 'SRM', 'SNARE, MARCHING', NULL, 'Good', 'MS MUSIC', 'VERVE', 'White', NULL, 3, NULL, NULL),
	(1493, 277, 'SRM', 'SNARE, MARCHING', NULL, 'Good', 'MS MUSIC', 'VERVE', 'White', NULL, 4, NULL, NULL),
	(1495, 75, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 43, NULL, NULL),
	(1497, 76, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 44, NULL, NULL),
	(1504, 77, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 45, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1506, 48, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 16, NULL, NULL),
	(1507, 51, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 19, NULL, NULL),
	(2098, 62, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'PBONE', NULL, 'PTB', 30, 'Alexander Wietecha', 938),
	(1980, 52, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'HS MUSIC', 'KAIZER', NULL, 'PTB', 20, NULL, NULL),
	(1981, 53, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'HS MUSIC', 'KAIZER', NULL, 'PTB', 21, NULL, NULL),
	(1932, 333, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 5, NULL, NULL),
	(1933, 334, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 6, NULL, NULL),
	(1934, 335, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 7, NULL, NULL),
	(1935, 167, 'AMB', 'AMPLIFIER, BASS', 'ICTB15016929', 'Good', 'HS MUSIC', 'FENDER', 'Rumble 25', NULL, 3, NULL, NULL),
	(1936, 399, 'VN', 'VIOLIN', 'V2024618', 'Good', 'HS MUSIC', 'ANDREAS EASTMAN', NULL, NULL, 4, NULL, NULL),
	(1937, 298, 'TPD', 'TIMPANI, 26 INCH', '51734', 'Good', 'HS MUSIC', 'LUDWIG', 'SUD-LKS426FG', NULL, 2, NULL, NULL),
	(1938, 400, 'VN', 'VIOLIN', 'V2025159', 'Good', 'HS MUSIC', 'ANDREAS EASTMAN', NULL, NULL, 5, NULL, NULL),
	(1939, 326, 'TPN', 'TIMPANI, 29 INCH', '36346', 'Good', 'HS MUSIC', 'LUDWIG', NULL, NULL, 5, NULL, NULL),
	(1940, 172, 'AMG', 'AMPLIFIER, GUITAR', 'ICTB1500267', 'Good', 'HS MUSIC', 'FENDER', 'Frontman 15G', NULL, 7, NULL, NULL),
	(1941, 232, NULL, 'MOUNTING BRACKET, BELL TREE', NULL, 'Good', 'HS MUSIC', 'TREEWORKS', 'TW-TRE52', NULL, 1, NULL, NULL),
	(1942, 327, 'TPW', 'TIMPANI, 32 INCH', '36301', 'Good', 'HS MUSIC', 'LUDWIG', NULL, NULL, 4, NULL, NULL),
	(1943, 294, 'TRT', 'TAMBOURINE, 10 INCH', NULL, 'Good', 'HS MUSIC', 'PEARL', 'Symphonic Double Row PEA-PETM1017', NULL, 1, NULL, NULL),
	(1944, 222, 'RK', 'RAINSTICK', NULL, 'Good', 'UPPER ES MUSIC', 'CUSTOM', NULL, NULL, 1, NULL, NULL),
	(1945, 329, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 1, NULL, NULL),
	(1947, 165, 'AM', 'AMPLIFIER', 'M 1134340', 'Good', 'HS MUSIC', 'FENDER', NULL, NULL, 1, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1948, 229, 'BD', 'BASS DRUM', '3442181', 'Good', 'HS MUSIC', 'LUDWIG', NULL, NULL, 1, NULL, NULL),
	(1949, 311, 'X', 'XYLOPHONE', NULL, 'Good', 'HS MUSIC', 'DII', 'Decator', NULL, 18, NULL, NULL),
	(1950, 174, 'AMK', 'AMPLIFIER, KEYBOARD', 'ODB#1230169', 'Good', 'HS MUSIC', 'PEAVEY', NULL, NULL, 9, NULL, NULL),
	(1960, 20, 'TN', 'TROMBONE, TENOR', '071009A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 6, NULL, NULL),
	(1953, 328, 'X', 'XYLOPHONE', '660845710719', 'Good', 'HS MUSIC', 'UNKNOWN', NULL, NULL, 19, NULL, NULL),
	(1954, 179, NULL, 'MICROPHONE', NULL, 'Good', 'HS MUSIC', 'SHURE', 'SM58', NULL, 1, NULL, NULL),
	(1955, 233, 'CBS', 'CABASA', NULL, 'Good', 'HS MUSIC', 'LP', 'LP234A', NULL, 1, NULL, NULL),
	(1956, 268, 'GUR', 'GUIRO', NULL, 'Good', 'HS MUSIC', 'LP', 'Super LP243', NULL, 1, NULL, NULL),
	(1957, 231, 'BLR', 'BELL TREE', NULL, 'Good', 'HS MUSIC', 'TREEWORKS', 'TW-TRE35', NULL, 1, NULL, NULL),
	(1958, 270, 'MRC', 'MARACAS', NULL, 'Good', 'HS MUSIC', 'WEISS', NULL, NULL, 1, NULL, NULL),
	(1961, 300, 'TGL', 'TRIANGLE', NULL, 'Good', 'HS MUSIC', 'ALAN ABEL', '6" Inch Symphonic', NULL, 1, NULL, NULL),
	(1962, 236, 'CLV', 'CLAVES', NULL, 'Good', 'HS MUSIC', 'LP', 'GRENADILLA', NULL, 3, NULL, NULL),
	(1963, 368, 'GRC', 'GUITAR, CLASSICAL', 'HKPO64008', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 12, NULL, NULL),
	(1964, 369, 'GRC', 'GUITAR, CLASSICAL', 'HKP054554', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 13, NULL, NULL),
	(1971, 220, 'CWB', 'COWBELL', NULL, 'Good', 'HS MUSIC', 'LP', 'Black Beauty', NULL, 1, NULL, NULL),
	(1972, 337, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 9, NULL, NULL),
	(1973, 338, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 10, NULL, NULL),
	(1974, 339, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 11, NULL, NULL),
	(1975, 340, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 12, NULL, NULL),
	(1976, 341, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 13, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1977, 342, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 14, NULL, NULL),
	(1978, 171, 'AMB', 'AMPLIFIER, BASS', 'OJBHE2300098', 'Good', 'HS MUSIC', 'PEAVEY', 'TKO-230EU', NULL, 11, NULL, NULL),
	(1979, 343, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 15, NULL, NULL),
	(1836, 470, 'CL', 'CLARINET, B FLAT', 'YE67470', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 62, NULL, NULL),
	(1843, 146, 'TP', 'TRUMPET, B FLAT', 'XA04125', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 57, NULL, NULL),
	(1785, 557, 'FL', 'FLUTE', 'DD58225', 'Good', NULL, 'JUPITER', 'JFL 700', 'FL', 63, 'Malan Chopra', 927),
	(2073, 446, 'CL', 'CLARINET, B FLAT', 'J65493', 'Good', NULL, 'YAMAHA', NULL, 'CL', 38, 'Vashnie Joymungul', 1032),
	(4163, NULL, 'DMMO', 'DUMMY 1', 'DUMMM1', 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, 2, NULL, NULL),
	(1946, 336, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 8, NULL, NULL),
	(1984, 307, 'WB', 'WOOD BLOCK', NULL, 'Good', 'MS MUSIC', 'LP', 'PLASTIC RED', NULL, 2, NULL, NULL),
	(1985, 380, 'GRE', 'GUITAR, ELECTRIC', '115085004', 'Good', 'HS MUSIC', 'FENDER', 'CD-60CE Mahogany', NULL, 26, NULL, NULL),
	(1986, 308, 'WB', 'WOOD BLOCK', NULL, 'Good', 'MS MUSIC', 'LP', 'PLASTIC BLUE', NULL, 3, NULL, NULL),
	(1987, 269, 'GUR', 'GUIRO', NULL, 'Good', 'MS MUSIC', 'LP', 'Plastic', NULL, 2, NULL, NULL),
	(1988, 310, 'X', 'XYLOPHONE', '587', 'Good', 'MS MUSIC', 'ROSS', '410', NULL, 17, NULL, NULL),
	(1992, 373, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'MS MUSIC', 'PARADISE', '19', NULL, 19, NULL, NULL),
	(1998, 390, 'GRT', 'GUITAR, HALF', '3', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 6, NULL, NULL),
	(2000, 382, 'GRE', 'GUITAR, ELECTRIC', '115085034', 'Good', NULL, 'FENDER', 'CD-60CE Mahogany', NULL, 25, NULL, NULL),
	(2001, 266, 'DKE', 'DRUMSET, ELECTRIC', '694318011177', 'Good', 'DRUM ROOM 2', 'ALESIS', 'DM8', NULL, 5, NULL, NULL),
	(2026, 578, 'SXA', 'SAXOPHONE, ALTO', '352128A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 13, NULL, NULL),
	(2003, 197, 'PG', 'PIANO, GRAND', '302697', 'Good', 'PIANO ROOM', 'GEBR. PERZINO', 'GBT 175', NULL, 1, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(2004, 198, 'PU', 'PIANO, UPRIGHT', NULL, 'Good', 'PRACTICE ROOM 1', 'ELSENBERG', NULL, NULL, 1, NULL, NULL),
	(2005, 391, 'GRT', 'GUITAR, HALF', '1', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 7, NULL, NULL),
	(2007, 392, 'GRT', 'GUITAR, HALF', '12', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 8, NULL, NULL),
	(2008, 395, 'GRT', 'GUITAR, HALF', '6', 'Good', 'PRACTICE ROOM 3', 'KAY', NULL, NULL, 11, NULL, NULL),
	(2009, 228, 'AGG', 'AGOGO BELL', NULL, 'Good', 'MS MUSIC', 'LP', '577 Dry', NULL, 1, NULL, NULL),
	(2010, 292, 'TR', 'TAMBOURINE', NULL, 'Good', 'MS MUSIC', 'MEINL', 'Open face', NULL, 1, NULL, NULL),
	(2011, 323, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 6, NULL, NULL),
	(2012, 318, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 1, NULL, NULL),
	(2013, 284, 'BLS', 'BELLS, SLEIGH', NULL, 'Good', 'MS MUSIC', 'LUDWIG', 'Red Handle', NULL, 2, NULL, NULL),
	(2014, 279, 'TTM', 'TOM, MARCHING', '6 PAIRS', 'Good', 'HS MUSIC', 'PEARL', NULL, NULL, 1, NULL, NULL),
	(2015, 218, NULL, 'STAND, MUSIC', NULL, 'Good', 'MS MUSIC', 'GMS', NULL, NULL, 2, NULL, NULL),
	(2016, 305, 'WC', 'WIND CHIMES', NULL, 'Good', 'MS MUSIC', 'LP', 'LP236D', NULL, 1, NULL, NULL),
	(2017, 301, 'TGL', 'TRIANGLE', NULL, 'Good', 'MS MUSIC', 'ALAN ABEL', '6 inch', NULL, 2, NULL, NULL),
	(2018, 234, 'CBS', 'CABASA', NULL, 'Good', 'MS MUSIC', 'LP', 'Small', NULL, 2, NULL, NULL),
	(2019, 202, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 2, NULL, NULL),
	(2020, 237, 'CLV', 'CLAVES', NULL, 'Good', 'MS MUSIC', 'KING', NULL, NULL, 1, NULL, NULL),
	(2021, 376, 'GRC', 'GUITAR, CLASSICAL', '265931HRJ', 'Good', 'INSTRUMENT STORE', 'YAMAHA', '40', NULL, 28, NULL, NULL),
	(1982, 58, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'HS MUSIC', 'KAIZER', NULL, 'PTB', 26, NULL, NULL),
	(2023, 362, 'GRC', 'GUITAR, CLASSICAL', 'HKPO065675', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 6, NULL, NULL),
	(2055, 49, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PR18100094', 'Good', NULL, 'TROMBA', 'Pro', 'PTB', 17, 'Lilyrose Trottier', 357) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(2002, 15, 'TN', 'TROMBONE, TENOR', '970406', 'Good', 'MS MUSIC', 'HOLTON', 'TR259', 'TB', 1, NULL, NULL),
	(2030, 191, 'PE', 'PIANO, ELECTRIC', 'YCQM01249', 'Good', 'MS MUSIC', 'YAMAHA', 'CAP 320', NULL, 4, NULL, NULL),
	(2027, 19, 'TN', 'TROMBONE, TENOR', '334792', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 5, NULL, NULL),
	(2033, 481, 'CLB', 'CLARINET, BASS', '43084', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'BCL', 3, NULL, NULL),
	(2034, 189, 'PE', 'PIANO, ELECTRIC', 'GBRCKK 01006', 'Good', 'MUSIC OFFICE', 'YAMAHA', 'CVP303x', NULL, 2, NULL, NULL),
	(2035, 190, 'PE', 'PIANO, ELECTRIC', '7163', 'Good', 'MUSIC OFFICE', 'YAMAHA', 'CVP 87A', NULL, 3, NULL, NULL),
	(2036, 366, 'GRC', 'GUITAR, CLASSICAL', 'HKP064183', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 10, NULL, NULL),
	(2037, 357, 'GRC', 'GUITAR, CLASSICAL', 'HKZ107832', 'Good', NULL, 'YAMAHA', '40', NULL, 1, NULL, NULL),
	(2038, 358, 'GRC', 'GUITAR, CLASSICAL', 'HKZ034412', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 2, NULL, NULL),
	(2039, 359, 'GRC', 'GUITAR, CLASSICAL', 'HKP065151', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 3, NULL, NULL),
	(2120, 409, 'CL', 'CLARINET, B FLAT', '7988', 'Good', NULL, 'YAMAHA', NULL, 'CL', 4, 'Zecarun Caminha', 538),
	(1856, 87, 'TP', 'TRUMPET, B FLAT', '638871', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 7, NULL, NULL),
	(1857, 81, 'TP', 'TRUMPET, B FLAT', '808845', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 1, NULL, NULL),
	(1874, 415, 'CL', 'CLARINET, B FLAT', 'B 859866/7112-STORE', 'Good', NULL, 'VITO', NULL, 'CL', 7, NULL, NULL),
	(1891, 486, 'FL', 'FLUTE', '600365', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'FL', 3, NULL, NULL),
	(1893, 488, 'FL', 'FLUTE', '452046A', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'FL', 5, NULL, NULL),
	(1896, 89, 'TP', 'TRUMPET, B FLAT', '556519', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 9, NULL, NULL),
	(1897, 532, 'FL', 'FLUTE', 'AP28041129', 'Good', NULL, 'PRELUDE', NULL, 'FL', 37, NULL, NULL),
	(1903, 95, 'TP', 'TRUMPET, B FLAT', '634070', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 15, NULL, NULL),
	(1904, 110, 'TP', 'TRUMPET, B FLAT', '501720', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 30, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1911, 428, 'CL', 'CLARINET, B FLAT', 'J65540', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 20, NULL, NULL),
	(1916, 112, 'TP', 'TRUMPET, B FLAT', '638850', 'Good', 'MS MUSIC', 'YAMAHA', 'YTR 2335', 'TP', 32, NULL, NULL),
	(1755, 441, 'CL', 'CLARINET, B FLAT', 'J65382', 'Good', NULL, 'YAMAHA', NULL, 'CL', 33, 'Moussa Sangare', 929),
	(2040, 421, 'CL', 'CLARINET, B FLAT', '27303', 'Good', NULL, 'YAMAHA', NULL, 'CL', 13, 'Naia Friedhoff Jaeschke', 602),
	(1736, 416, 'CL', 'CLARINET, B FLAT', '504869', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'CL', 8, NULL, NULL),
	(1496, 94, 'TP', 'TRUMPET, B FLAT', 'L306677', 'Good', 'INSTRUMENT STORE', 'BACH', 'Stradivarius 37L', 'TP', 14, NULL, NULL),
	(1498, 97, 'TP', 'TRUMPET, B FLAT', 'S-756323', 'Good', 'INSTRUMENT STORE', 'CONN', NULL, 'TP', 17, NULL, NULL),
	(1499, 98, 'TP', 'TRUMPET, B FLAT', 'H35537', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BTR 1270', 'TP', 18, NULL, NULL),
	(1500, 102, 'TP', 'TRUMPET, B FLAT', 'H34929', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BIR 1270', 'TP', 22, NULL, NULL),
	(1501, 104, 'TP', 'TRUMPET, B FLAT', 'H32053', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BIR 1270', 'TP', 24, NULL, NULL),
	(1502, 105, 'TP', 'TRUMPET, B FLAT', 'H31491', 'Good', 'INSTRUMENT STORE', 'BLESSING', 'BIR 1270', 'TP', 25, NULL, NULL),
	(1503, 108, 'TP', 'TRUMPET, B FLAT', 'F24304', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 28, NULL, NULL),
	(1505, 133, 'TP', 'TRUMPET, B FLAT', 'XA07789', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 44, NULL, NULL),
	(1951, 429, 'CL', 'CLARINET, B FLAT', 'J65851', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 21, NULL, NULL),
	(1952, 442, 'CL', 'CLARINET, B FLAT', 'J65593', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 34, NULL, NULL),
	(1959, 443, 'CL', 'CLARINET, B FLAT', 'J65299', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 35, NULL, NULL),
	(1965, 499, 'FL', 'FLUTE', '617224', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'FL', 11, NULL, NULL),
	(2096, 580, 'SXA', 'SAXOPHONE, ALTO', '362547A', 'Good', NULL, 'YAMAHA', NULL, 'AX', 15, 'Caitlin Wood', 160),
	(4164, NULL, 'DMMO', 'DUMMY 1', 'DUMMM2', 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, 3, NULL, NULL),
	(1764, 575, 'SXA', 'SAXOPHONE, ALTO', '387824A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 10, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1766, 636, 'SXA', 'SAXOPHONE, ALTO', 'CF57086', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 67, NULL, NULL),
	(1966, 420, 'CL', 'CLARINET, B FLAT', '7980', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 12, NULL, NULL),
	(1967, 434, 'CL', 'CLARINET, B FLAT', 'B88822', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 26, NULL, NULL),
	(1968, 405, 'CL', 'CLARINET, B FLAT', '206603A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 2, NULL, NULL),
	(1969, 485, 'FL', 'FLUTE', '826706', 'Good', 'INSTRUMENT STORE', 'YAMAHA', '222', 'FL', 2, NULL, NULL),
	(2022, 6, 'BH', 'BARITONE/EUPHONIUM', '534386', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'BH', 7, NULL, NULL),
	(2024, 403, 'CL', 'CLARINET, B FLAT', '206681A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 1, NULL, NULL),
	(2025, 484, 'FL', 'FLUTE', '609368', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'FL', 1, NULL, NULL),
	(1494, 506, 'FL', 'FLUTE', 'K96338', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 15, NULL, NULL),
	(2032, 407, 'CL', 'CLARINET, B FLAT', '7291', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 3, NULL, NULL),
	(1739, 431, 'CL', 'CLARINET, B FLAT', '193026A', 'Good', NULL, 'YAMAHA', NULL, 'CL', 23, 'Fatuma Tall', 301),
	(1756, 444, 'CL', 'CLARINET, B FLAT', 'J65434', 'Good', NULL, 'YAMAHA', NULL, 'CL', 36, 'Anastasia Mulema', 979),
	(1768, 489, 'FL', 'FLUTE', '42684', 'Good', 'INSTRUMENT STORE', 'EMERSON', 'EF1', 'FL', 6, NULL, NULL),
	(1787, 134, 'TP', 'TRUMPET, B FLAT', 'XA08653', 'Good', NULL, 'JUPITER', NULL, 'TP', 45, 'Connor Fort', 299),
	(1742, 422, 'CL', 'CLARINET, B FLAT', '206167', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'CL', 14, NULL, NULL),
	(1763, 492, 'FL', 'FLUTE', '650122', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'FL', 8, NULL, NULL),
	(1765, 475, 'CL', 'CLARINET, B FLAT', 'BE63660', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 67, NULL, NULL),
	(1767, 502, 'FL', 'FLUTE', 'K96367', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 13, NULL, NULL),
	(1770, 518, 'FL', 'FLUTE', '33111112', 'Good', 'INSTRUMENT STORE', 'PRELUDE', NULL, 'FL', 23, NULL, NULL),
	(1746, 468, 'CL', 'CLARINET, B FLAT', 'XE54704', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 60, 'Lorian Inglis', 358) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1786, 122, 'TP', 'TRUMPET, B FLAT', '124911', 'Good', NULL, 'ETUDE', NULL, 'TP', 38, 'Mark Anding', 1076),
	(1745, 254, NULL, 'STAND, CYMBAL', NULL, 'Good', 'HS MUSIC', 'GIBRALTAR', 'GIB-5710', NULL, 1, NULL, NULL),
	(1747, 296, 'TPT', 'TIMPANI, 23 INCH', '36264', 'Good', 'MS MUSIC', 'LUDWIG', 'LKS423FG', NULL, 1, NULL, NULL),
	(1748, 309, 'X', 'XYLOPHONE', '25', 'Good', 'MS MUSIC', 'MAJESTIC', 'x55 352', NULL, 16, NULL, NULL),
	(1749, 182, NULL, 'PA SYSTEM, ALL-IN-ONE', 'S1402186AA8', 'Good', 'HS MUSIC', 'BEHRINGER', 'EPS500MP3', NULL, 1, NULL, NULL),
	(1570, 96, 'TP', 'TRUMPET, B FLAT', '33911', 'Good', NULL, 'SCHILKE', 'B1L', 'TP', 16, 'Mark Anding', 1076),
	(1753, 209, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 9, NULL, NULL),
	(1758, 215, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 15, NULL, NULL),
	(1759, 203, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 3, NULL, NULL),
	(1760, 253, 'CMZ', 'CYMBALS, HANDHELD 18 INCH', 'ZIL-A0447', 'Good', 'HS MUSIC', 'ZILDJIAN', '18 Inch Symphonic Viennese Tone', NULL, 1, NULL, NULL),
	(1761, 378, 'GRW', 'GUITAR, CUTAWAY', NULL, 'Good', 'MS MUSIC', 'UNKNOWN', NULL, NULL, 15, NULL, NULL),
	(1762, 379, 'GRW', 'GUITAR, CUTAWAY', NULL, 'Good', 'MS MUSIC', 'UNKNOWN', NULL, NULL, 16, NULL, NULL),
	(1769, 304, 'TBN', 'TUBANOS', '1-7', 'Good', 'MS MUSIC', 'REMO', '12 inch', NULL, 7, NULL, NULL),
	(2064, 263, 'DK', 'DRUMSET', NULL, 'Good', 'DRUM ROOM 1', 'YAMAHA', NULL, NULL, 2, NULL, NULL),
	(2061, 361, 'GRC', 'GUITAR, CLASSICAL', 'HKZ114314', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 5, NULL, NULL),
	(2065, 324, 'DK', 'DRUMSET', NULL, 'Good', 'DRUM ROOM 2', 'YAMAHA', NULL, NULL, 6, NULL, NULL),
	(2066, 411, 'CL', 'CLARINET, B FLAT', '27251', 'Good', NULL, 'YAMAHA', NULL, 'CL', 5, 'Mark Anding', 1076),
	(1885, 398, 'VN', 'VIOLIN', 'D 0933 1998', 'Good', NULL, 'WILLIAM LEWIS & SON', NULL, NULL, 3, 'Gakenia Mucharie', 1075),
	(1771, 588, 'SXA', 'SAXOPHONE, ALTO', '11110695', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 23, NULL, NULL),
	(1790, 613, 'SXA', 'SAXOPHONE, ALTO', 'XF56401', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 44, 'Emiel Ghelani-Decorte', 662) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1877, 614, 'SXA', 'SAXOPHONE, ALTO', 'XF57089', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 45, 'Fatuma Tall', 301),
	(2059, 402, 'CLE', 'CLARINET, ALTO IN E FLAT', '1260', 'Good', NULL, 'YAMAHA', NULL, NULL, 1, 'Mark Anding', 1076),
	(1879, 634, 'SXA', 'SAXOPHONE, ALTO', 'BF54604', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 65, 'Ethan Sengendo', 393),
	(2060, 610, 'SXA', 'SAXOPHONE, ALTO', 'XF54140', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 41, 'Lucile Bamlango', 176),
	(1878, 615, 'SXA', 'SAXOPHONE, ALTO', 'XF57192', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 46, 'Max Stock', 956),
	(2056, 120, 'TP', 'TRUMPET, B FLAT', '124816', 'Good', NULL, 'ETUDE', NULL, 'TP', 37, 'Masoud Ibrahim', 787),
	(1743, 126, 'TP', 'TRUMPET, B FLAT', 'H35214', 'Good', NULL, 'BLESSING', NULL, 'TP', 40, 'Masoud Ibrahim', 787),
	(1588, 478, 'CL', 'CLARINET, B FLAT', 'BE63657', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 70, 'Gakenia Mucharie', 1075),
	(1514, 140, 'TP', 'TRUMPET, B FLAT', 'XA06017', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 51, NULL, NULL),
	(1772, 667, 'SXT', 'SAXOPHONE, TENOR', 'CF08026', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTS700', 'TX', 23, NULL, NULL),
	(1741, 32, 'TN', 'TROMBONE, TENOR', '646721', 'Good', NULL, 'YAMAHA', NULL, 'TB', 18, 'Andrew Wachira', 268),
	(1892, 24, 'TN', 'TROMBONE, TENOR', '316975', 'Good', NULL, 'YAMAHA', NULL, 'TB', 10, 'Margaret Oganda', 1078),
	(1861, 12, 'HNF', 'HORN, F', 'BC00278', 'Good', NULL, 'JUPITER', 'JHR1100', 'HN', 5, 'Kai O''Bra', 480),
	(4165, NULL, 'DMMO', 'DUMMY 1', 'DUMMM3', 'New', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, 4, NULL, NULL),
	(4166, NULL, 'DMMO', 'DUMMY 1', 'DUMMM4', 'New', NULL, 'DUMMY MAKER', NULL, NULL, 5, NULL, NULL),
	(1527, 573, 'SXA', 'SAXOPHONE, ALTO', '200547', 'Good', 'INSTRUMENT STORE', 'GIARDINELLI', NULL, 'AX', 8, NULL, NULL),
	(1511, 137, 'TP', 'TRUMPET, B FLAT', 'XA08294', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 48, NULL, NULL),
	(1582, 180, NULL, 'MICROPHONE', NULL, 'Good', 'HS MUSIC', 'SHURE', 'SM58', NULL, 2, NULL, NULL),
	(1723, 312, 'BL', 'BELL SET', NULL, 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 1, NULL, NULL),
	(1534, 569, 'SXA', 'SAXOPHONE, ALTO', '11120109', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 4, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1512, 138, 'TP', 'TRUMPET, B FLAT', 'XA08319', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 49, NULL, NULL),
	(1725, 397, 'VN', 'VIOLIN', '3923725', 'Good', 'INSTRUMENT STORE', 'AUBERT', NULL, NULL, 2, NULL, NULL),
	(1548, 571, 'SXA', 'SAXOPHONE, ALTO', '12080618', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 6, NULL, NULL),
	(1555, 612, 'SXA', 'SAXOPHONE, ALTO', 'XF56514', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 43, NULL, NULL),
	(1578, 584, 'SXA', 'SAXOPHONE, ALTO', 'AS1001039', 'Good', 'INSTRUMENT STORE', 'BARRINGTON', NULL, 'AX', 19, NULL, NULL),
	(1580, 568, 'SXA', 'SAXOPHONE, ALTO', '11120090', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 3, NULL, NULL),
	(1602, 585, 'SXA', 'SAXOPHONE, ALTO', 'AS1003847', 'Good', 'INSTRUMENT STORE', 'BARRINGTON', NULL, 'AX', 20, NULL, NULL),
	(1726, 45, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 13, NULL, NULL),
	(1728, 34, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 2, NULL, NULL),
	(1549, 35, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 3, NULL, NULL),
	(1931, 332, 'X', 'XYLOPHONE', NULL, 'Good', 'UPPER ES MUSIC', 'ORFF', NULL, NULL, 4, NULL, NULL),
	(1579, 50, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PB17070322', 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 18, NULL, NULL),
	(1526, 645, 'SXT', 'SAXOPHONE, TENOR', '403557', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'TX', 1, NULL, NULL),
	(1528, 652, 'SXT', 'SAXOPHONE, TENOR', 'N4200829', 'Good', 'INSTRUMENT STORE', 'SELMER', NULL, 'TX', 8, NULL, NULL),
	(1532, 650, 'SXT', 'SAXOPHONE, TENOR', '310278', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'TX', 6, NULL, NULL),
	(1536, 659, 'SXT', 'SAXOPHONE, TENOR', '13120021', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TX', 15, NULL, NULL),
	(1724, 9, 'HNF', 'HORN, F', '619468', 'Good', 'INSTRUMENT STORE', 'HOLTON', 'H281', 'HN', 2, NULL, NULL),
	(1727, 480, 'CLB', 'CLARINET, BASS', 'Y3717', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'BCL', 2, NULL, NULL),
	(1518, 640, 'SXB', 'SAXOPHONE, BARITONE', '1360873', 'Good', 'INSTRUMENT STORE', 'SELMER', NULL, 'BX', 1, NULL, NULL),
	(1540, 644, 'SXB', 'SAXOPHONE, BARITONE', 'CF05160', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JBS 1000', 'BX', 5, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1517, 163, 'TB', 'TUBA', NULL, 'Good', 'INSTRUMENT STORE', 'BOOSEY & HAWKES', 'Imperial  EEb', 'T', 3, NULL, NULL),
	(1544, 303, 'TBN', 'TUBANOS', NULL, 'Good', 'MS MUSIC', 'REMO', '10 Inch', NULL, 5, NULL, NULL),
	(1551, 170, 'AMB', 'AMPLIFIER, BASS', 'Z9G3740', 'Good', 'MS MUSIC', 'ROLAND', 'Cube-120 XL', NULL, 6, NULL, NULL),
	(1552, 173, 'AMG', 'AMPLIFIER, GUITAR', 'M 1005297', 'Good', 'MS MUSIC', 'FENDER', 'STAGE 160', NULL, 8, NULL, NULL),
	(1559, 252, 'CMY', 'CYMBALS, HANDHELD 16 INCH', NULL, 'Good', 'HS MUSIC', 'SABIAN', 'SAB SR 16BOL', NULL, 1, NULL, NULL),
	(1581, 175, 'AMK', 'AMPLIFIER, KEYBOARD', 'OBD#1230164', 'Good', 'MS MUSIC', 'PEAVEY', 'KB4', NULL, 10, NULL, NULL),
	(1583, 184, 'KB', 'KEYBOARD', 'TCK 611', 'Good', 'HS MUSIC', 'CASIO', NULL, NULL, 2, NULL, NULL),
	(1584, 256, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 2, NULL, NULL),
	(1585, 258, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 3, NULL, NULL),
	(1586, 260, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 5, NULL, NULL),
	(1587, 255, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 1, NULL, NULL),
	(1589, 14, 'MTL', 'METALLOPHONE', NULL, 'Good', NULL, 'ORFF', NULL, NULL, 1, NULL, NULL),
	(1590, 187, 'KB', 'KEYBOARD', NULL, 'Good', NULL, 'CASIO', 'TC-360', NULL, 23, NULL, NULL),
	(1591, 217, NULL, 'STAND, MUSIC', '50052', 'Good', NULL, 'WENGER', NULL, NULL, 1, NULL, NULL),
	(1597, 176, 'AMG', 'AMPLIFIER, GUITAR', 'S190700059B4P', 'Good', NULL, 'BUGERA', NULL, NULL, 12, NULL, NULL),
	(1599, 320, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 3, NULL, NULL),
	(1600, 177, 'AMG', 'AMPLIFIER, GUITAR', 'B-749002', 'Good', NULL, 'FENDER', 'Blue Junior', NULL, 13, NULL, NULL),
	(1601, 351, 'GRA', 'GUITAR, ACOUSTIC', NULL, 'Good', NULL, 'UNKNOWN', NULL, NULL, 32, NULL, NULL),
	(1604, 322, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 5, NULL, NULL),
	(1513, 139, 'TP', 'TRUMPET, B FLAT', 'XA08322', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 50, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(2129, NULL, 'DMMO', 'DUMMY 1', NULL, 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMMY MODEL', NULL, 1, NULL, NULL),
	(1515, 141, 'TP', 'TRUMPET, B FLAT', 'XA05452', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 52, NULL, NULL),
	(1605, 319, 'BK', 'BELL KIT', NULL, 'Good', 'MS MUSIC', 'PEARL', 'PK900C', NULL, 2, NULL, NULL),
	(1607, 291, 'SRM', 'SNARE, MARCHING', '1P-3086', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 6, NULL, NULL),
	(1609, 620, 'SXA', 'SAXOPHONE, ALTO', 'XF56962', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 51, NULL, NULL),
	(1612, 633, 'SXA', 'SAXOPHONE, ALTO', 'BF54617', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 64, NULL, NULL),
	(1638, 586, 'SXA', 'SAXOPHONE, ALTO', 'AS 1010089', 'Good', 'INSTRUMENT STORE', 'BARRINGTON', NULL, 'AX', 21, NULL, NULL),
	(1655, 607, 'SXA', 'SAXOPHONE, ALTO', 'XF54539', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 38, NULL, NULL),
	(1658, 609, 'SXA', 'SAXOPHONE, ALTO', 'XF54577', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 40, NULL, NULL),
	(1615, 225, 'TDR', 'TALKING DRUM', NULL, 'Good', 'MS MUSIC', 'REMO', 'Small', NULL, 1, NULL, NULL),
	(1616, 212, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 12, NULL, NULL),
	(1617, 178, 'AMG', 'AMPLIFIER, GUITAR', 'LCB500-A126704', 'Good', NULL, 'FISHMAN', '494-000-582', NULL, 14, NULL, NULL),
	(1619, 286, 'SR', 'SNARE', NULL, 'Good', 'UPPER ES MUSIC', 'PEARL', NULL, NULL, 2, NULL, NULL),
	(1620, 181, 'MX', 'MIXER', 'BGXL01101', 'Good', 'MS MUSIC', 'YAMAHA', 'MG12XU', NULL, 15, NULL, NULL),
	(1622, 347, 'GRB', 'GUITAR, BASS', '15020198', 'Good', 'HS MUSIC', 'SQUIER', 'Modified Jaguar', NULL, 4, NULL, NULL),
	(1623, 240, NULL, 'CRADLE, CONCERT CYMBAL', NULL, 'Good', 'HS MUSIC', 'GIBRALTAR', 'GIB-7614', NULL, 1, NULL, NULL),
	(1631, 381, 'GRE', 'GUITAR, ELECTRIC', '15029891', 'Good', 'HS MUSIC', 'SQUIER', 'StratPkHSSCAR', NULL, 1, NULL, NULL),
	(1686, 577, 'SXA', 'SAXOPHONE, ALTO', '11120110', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 12, NULL, NULL),
	(1688, 590, 'SXA', 'SAXOPHONE, ALTO', '11110696', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 25, NULL, NULL),
	(1693, 591, 'SXA', 'SAXOPHONE, ALTO', '91145', 'Good', 'INSTRUMENT STORE', 'CONSERVETE', NULL, 'AX', 26, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1624, 54, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 22, NULL, NULL),
	(1625, 55, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 23, NULL, NULL),
	(1626, 63, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 31, NULL, NULL),
	(1627, 65, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 33, NULL, NULL),
	(1628, 67, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 35, NULL, NULL),
	(1664, 314, 'BL', 'BELL SET', NULL, 'Good', 'INSTRUMENT STORE', 'UNKNOWN', NULL, NULL, 3, NULL, NULL),
	(1629, 69, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 37, NULL, NULL),
	(1675, 352, 'GRA', 'GUITAR, ACOUSTIC', '00Y224811', 'Good', NULL, 'YAMAHA', 'F 325', NULL, 19, NULL, NULL),
	(1676, 353, 'GRA', 'GUITAR, ACOUSTIC', '00Y224884', 'Good', NULL, 'YAMAHA', 'F 325', NULL, 20, NULL, NULL),
	(1630, 70, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 38, NULL, NULL),
	(1634, 71, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 39, NULL, NULL),
	(1635, 72, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 40, NULL, NULL),
	(1637, 73, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 41, NULL, NULL),
	(1682, 59, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 27, NULL, NULL),
	(1683, 354, 'GRA', 'GUITAR, ACOUSTIC', '00Y145219', 'Good', NULL, 'YAMAHA', 'F 325', NULL, 22, NULL, NULL),
	(1690, 245, 'CG', 'CONGA', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 24, NULL, NULL),
	(1691, 246, 'CG', 'CONGA', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 25, NULL, NULL),
	(1666, 201, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 1, NULL, NULL),
	(1685, 60, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'KAIZER', NULL, 'PTB', 28, NULL, NULL),
	(1689, 61, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 29, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1695, 44, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'TROMBA', 'Pro', 'PTB', 12, NULL, NULL),
	(1697, 221, 'PD', 'PRACTICE PAD', 'ISK NO.26', 'Good', 'UPPER ES MUSIC', 'YAMAHA', '4 INCH', NULL, 1, NULL, NULL),
	(1707, 355, 'GRA', 'GUITAR, ACOUSTIC', '00Y224899', 'Good', 'HS MUSIC', 'YAMAHA', 'F 325', NULL, 23, NULL, NULL),
	(1708, 356, 'GRA', 'GUITAR, ACOUSTIC', '00Y224741', 'Good', 'HS MUSIC', 'YAMAHA', 'F 325', NULL, 24, NULL, NULL),
	(1709, 194, 'PE', 'PIANO, ELECTRIC', 'BCAZ01088', 'Good', 'LOWER ES MUSIC', 'YAMAHA', 'CLP 7358', NULL, 9, NULL, NULL),
	(1711, 281, 'PD', 'PRACTICE PAD', NULL, 'Good', 'UPPER ES MUSIC', 'YAMAHA', '4 INCH', NULL, 2, NULL, NULL),
	(1717, 375, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 27, NULL, NULL),
	(1684, 655, 'SXT', 'SAXOPHONE, TENOR', '420486', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'TX', 11, NULL, NULL),
	(1516, 142, 'TP', 'TRUMPET, B FLAT', 'XA06111', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 53, NULL, NULL),
	(1994, 602, 'SXA', 'SAXOPHONE, ALTO', 'XF54322', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 33, 'Noah Ochomo', 1071),
	(2058, 593, 'SXA', 'SAXOPHONE, ALTO', 'XF54181', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 28, 'Romilly Haysmith', 937),
	(1906, 651, 'SXT', 'SAXOPHONE, TENOR', '10355', 'Good', NULL, 'YAMAHA', NULL, 'TX', 7, 'Noah Ochomo', 1071),
	(1744, 658, 'SXT', 'SAXOPHONE, TENOR', '13120005', 'Good', NULL, 'ALLORA', NULL, 'TX', 14, 'Ochieng Simbiri', 300),
	(2054, 661, 'SXT', 'SAXOPHONE, TENOR', 'XF03739', 'Good', NULL, 'JUPITER', NULL, 'TX', 17, 'Rohan Giri', 454),
	(2087, 162, 'TB', 'TUBA', '533558', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'T', 2, NULL, NULL),
	(1752, 208, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 8, NULL, NULL),
	(1732, 372, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'MS MUSIC', 'PARADISE', '18', NULL, 18, NULL, NULL),
	(2090, 195, 'PE', 'PIANO, ELECTRIC', 'BCZZ01016', 'Good', 'UPPER ES MUSIC', 'YAMAHA', 'CLP-645B', NULL, 7, NULL, NULL),
	(2091, 188, 'PE', 'PIANO, ELECTRIC', 'GBRCKK 01021', 'Good', 'THEATRE/FOYER', 'YAMAHA', 'CVP 303', NULL, 1, NULL, NULL),
	(2079, 192, 'PE', 'PIANO, ELECTRIC', 'YCQN01006', 'Good', 'HS MUSIC', 'YAMAHA', 'CAP 329', NULL, 5, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(2081, 193, 'PE', 'PIANO, ELECTRIC', 'EBQN02222', 'Good', 'HS MUSIC', 'YAMAHA', 'P-95', NULL, 6, NULL, NULL),
	(2082, 262, 'DK', 'DRUMSET', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 1, NULL, NULL),
	(2083, 239, 'BLC', 'BELLS, CONCERT', '112158', 'Good', 'HS MUSIC', 'YAMAHA', 'YG-250D Standard', NULL, 1, NULL, NULL),
	(2085, 289, 'SR', 'SNARE', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 27, NULL, NULL),
	(2086, 290, 'SR', 'SNARE', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 28, NULL, NULL),
	(1667, 213, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 13, NULL, NULL),
	(1519, 151, 'TP', 'TRUMPET, B FLAT', 'BA09236', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 62, NULL, NULL),
	(1520, 152, 'TP', 'TRUMPET, B FLAT', 'BA08359', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 63, NULL, NULL),
	(1521, 154, 'TP', 'TRUMPET, B FLAT', 'BA09193', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 65, NULL, NULL),
	(1522, 155, 'TP', 'TRUMPET, B FLAT', 'CA15052', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 66, NULL, NULL),
	(1523, 156, 'TP', 'TRUMPET, B FLAT', 'CA16033', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 67, NULL, NULL),
	(1524, 157, 'TP', 'TRUMPET, B FLAT', 'CAS15546', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 68, NULL, NULL),
	(1525, 158, 'TP', 'TRUMPET, B FLAT', 'CAS16006', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JTR 700', 'TP', 69, NULL, NULL),
	(1529, 500, 'FL', 'FLUTE', 'K96337', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 12, NULL, NULL),
	(1535, 423, 'CL', 'CLARINET, B FLAT', '282570', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'CL', 15, NULL, NULL),
	(1537, 424, 'CL', 'CLARINET, B FLAT', '206244', 'Good', 'INSTRUMENT STORE', 'AMATI KRASLICE', NULL, 'CL', 16, NULL, NULL),
	(1538, 508, 'FL', 'FLUTE', '2SP-K96103', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 16, NULL, NULL),
	(1539, 4, 'BH', 'BARITONE/EUPHONIUM', '987998', 'Good', 'INSTRUMENT STORE', 'KING', NULL, 'BH', 5, NULL, NULL),
	(1541, 541, 'FL', 'FLUTE', 'XD59821', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 46, NULL, NULL),
	(1542, 542, 'FL', 'FLUTE', 'XD59741', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 47, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1543, 561, 'FL', 'FLUTE', 'DD58003', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JFL 700', 'FL', 67, NULL, NULL),
	(1545, 84, 'TP', 'TRUMPET, B FLAT', 'H31816', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 4, NULL, NULL),
	(1546, 147, 'TP', 'TRUMPET, B FLAT', 'XA14523', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 58, NULL, NULL),
	(1547, 85, 'TP', 'TRUMPET, B FLAT', '831664', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 5, NULL, NULL),
	(1553, 537, 'FL', 'FLUTE', 'WD62143', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 42, NULL, NULL),
	(1554, 451, 'CL', 'CLARINET, B FLAT', '1312128', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'CL', 43, NULL, NULL),
	(1556, 452, 'CL', 'CLARINET, B FLAT', '1312139', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'CL', 44, NULL, NULL),
	(1557, 539, 'FL', 'FLUTE', 'XD59192', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 44, NULL, NULL),
	(1558, 453, 'CL', 'CLARINET, B FLAT', 'KE54780', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 45, NULL, NULL),
	(1608, 526, 'FL', 'FLUTE', 'D1206521', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 31, NULL, NULL),
	(1610, 460, 'CL', 'CLARINET, B FLAT', 'XE54946', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 52, NULL, NULL),
	(1611, 558, 'FL', 'FLUTE', 'DD57954', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JFL 700', 'FL', 64, NULL, NULL),
	(1613, 559, 'FL', 'FLUTE', 'DD58158', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JFL 700', 'FL', 65, NULL, NULL),
	(1614, 474, 'CL', 'CLARINET, B FLAT', 'BE63671', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 66, NULL, NULL),
	(1633, 504, 'FL', 'FLUTE', '2SP-K90658', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 14, NULL, NULL),
	(1636, 520, 'FL', 'FLUTE', '28411029', 'Good', 'INSTRUMENT STORE', 'PRELUDE', '711', 'FL', 25, NULL, NULL),
	(1657, 448, 'CL', 'CLARINET, B FLAT', '1209179', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 40, NULL, NULL),
	(1659, 449, 'CL', 'CLARINET, B FLAT', '1209180', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 41, NULL, NULL),
	(1660, 450, 'CL', 'CLARINET, B FLAT', '1209177', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 42, NULL, NULL),
	(1661, 544, 'FL', 'FLUTE', 'XD59774', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 49, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1662, 545, 'FL', 'FLUTE', 'XD59164', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 50, NULL, NULL),
	(1663, 459, 'CL', 'CLARINET, B FLAT', 'KE54774', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JCL710', 'CL', 51, NULL, NULL),
	(1665, 487, 'FL', 'FLUTE', 'T479', 'Good', 'INSTRUMENT STORE', 'HEIMAR', NULL, 'FL', 4, NULL, NULL),
	(1677, 148, 'TP', 'TRUMPET, B FLAT', 'XA14343', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 59, NULL, NULL),
	(1678, 149, 'TP', 'TRUMPET, B FLAT', 'XA033335', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 60, NULL, NULL),
	(1679, 150, 'TP', 'TRUMPET, B FLAT', 'BA09439', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 61, NULL, NULL),
	(1680, 418, 'CL', 'CLARINET, B FLAT', '30614E', 'Good', 'INSTRUMENT STORE', 'SIGNET', NULL, 'CL', 10, NULL, NULL),
	(1681, 419, 'CL', 'CLARINET, B FLAT', 'B59862', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'CL', 11, NULL, NULL),
	(1692, 521, 'FL', 'FLUTE', 'K98973', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 26, NULL, NULL),
	(1694, 522, 'FL', 'FLUTE', 'P11876', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 27, NULL, NULL),
	(1696, 436, 'CL', 'CLARINET, B FLAT', '11299279', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 28, NULL, NULL),
	(1719, 523, 'FL', 'FLUTE', 'K98879', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 28, NULL, NULL),
	(1720, 437, 'CL', 'CLARINET, B FLAT', '11299280', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 29, NULL, NULL),
	(1721, 524, 'FL', 'FLUTE', 'K99078', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 29, NULL, NULL),
	(1618, 374, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'INSTRUMENT STORE', 'PARADISE', '20', NULL, 20, NULL, NULL),
	(1712, 598, 'SXA', 'SAXOPHONE, ALTO', 'XF54370', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 31, 'Emilie Wittmann', 659),
	(1722, 438, 'CL', 'CLARINET, B FLAT', '11299277', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 30, NULL, NULL),
	(1729, 563, 'OB', 'OBOE', 'B33402', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'OB', 2, NULL, NULL),
	(1730, 565, 'PC', 'PICCOLO', '12111016', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'PC', 2, NULL, NULL),
	(1508, 118, 'TP', 'TRUMPET, B FLAT', 'H35268', 'Good', 'INSTRUMENT STORE', 'BLESSING', NULL, 'TP', 36, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1509, 135, 'TP', 'TRUMPET, B FLAT', 'XA08649', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 46, NULL, NULL),
	(1510, 136, 'TP', 'TRUMPET, B FLAT', 'XA08643', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 47, NULL, NULL),
	(2084, 515, 'FL', 'FLUTE', '917792', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'FL', 20, NULL, NULL),
	(2063, 93, 'TP', 'TRUMPET, B FLAT', '553853', 'Good', NULL, 'YAMAHA', 'YTR 2335', 'TP', 13, 'Natéa Firzé Al Ghaoui', 541),
	(1989, 109, 'TP', 'TRUMPET, B FLAT', 'G27536', 'Good', NULL, 'BLESSING', NULL, 'TP', 29, 'Noah Ochomo', 1071),
	(1999, 454, 'CL', 'CLARINET, B FLAT', 'KE56526', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 46, 'Noah Ochomo', 1071),
	(1880, 555, 'FL', 'FLUTE', 'BD62784', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 61, 'Nora Saleem', 931),
	(1848, 455, 'CL', 'CLARINET, B FLAT', 'KE56579', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 47, 'Owen Harris', 115),
	(1595, 516, 'FL', 'FLUTE', 'J94358', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 21, NULL, NULL),
	(1700, 130, 'TP', 'TRUMPET, B FLAT', '35272', 'Good', NULL, 'BLESSING', NULL, 'TP', 42, 'Ainsley Hire', 959),
	(1699, 128, 'TP', 'TRUMPET, B FLAT', '34928', 'Good', NULL, 'BLESSING', NULL, 'TP', 41, 'Ansh Mehta', 482),
	(1718, 426, 'CL', 'CLARINET, B FLAT', '25247', 'Good', NULL, 'YAMAHA', NULL, 'CL', 18, 'Balazs Meyers', 976),
	(1704, 547, 'FL', 'FLUTE', 'YD66330', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 53, 'Eliana Hodge', 945),
	(1702, 145, 'TP', 'TRUMPET, B FLAT', 'XA04094', 'Good', NULL, 'JUPITER', NULL, 'TP', 56, 'Etienne Carlevato', 980),
	(1716, 82, 'TP', 'TRUMPET, B FLAT', 'G29437', 'Good', NULL, 'BLESSING', NULL, 'TP', 2, 'Fatima Zucca', 539),
	(1594, 494, 'FL', 'FLUTE', 'G15104', 'Good', NULL, 'GEMEINHARDT', '2SP', 'FL', 9, 'Margaret Oganda', 1078),
	(1674, 68, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'PBONE', NULL, 'PTB', 36, 'Arhum Bid', 240),
	(1687, 656, 'SXT', 'SAXOPHONE, TENOR', 'TS10050027', 'Good', 'INSTRUMENT STORE', 'BUNDY', NULL, 'TX', 12, NULL, NULL),
	(1705, 648, 'SXT', 'SAXOPHONE, TENOR', '26286', 'Good', NULL, 'YAMAHA', NULL, 'TX', 4, NULL, NULL),
	(1701, 663, 'SXT', 'SAXOPHONE, TENOR', 'AF04276', 'Good', NULL, 'JUPITER', NULL, 'TX', 19, 'Ean Kimuli', 962) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1872, 10, 'HNF', 'HORN, F', '602', 'Good', NULL, 'HOLTON', NULL, 'HN', 3, 'Jamison Line', 172),
	(1566, 11, 'HNF', 'HORN, F', 'XC07411', 'Good', NULL, 'JUPITER', 'JHR700', 'HN', 4, 'Mark Anding', 1076),
	(1800, 479, 'CLB', 'CLARINET, BASS', '18250', 'Good', 'INSTRUMENT STORE', 'VITO', NULL, 'BCL', 1, NULL, NULL),
	(1806, 483, 'CLB', 'CLARINET, BASS', 'CE69047', 'Good', NULL, 'JUPITER', 'JBC 1000', 'BCL', 5, 'Mikael Eshetu', 935),
	(1606, 321, 'BK', 'BELL KIT', NULL, 'Good', NULL, 'PEARL', 'PK900C', NULL, 4, 'Mahori', NULL),
	(1596, 496, 'FL', 'FLUTE', '2SP-L89133', 'Good', NULL, 'GEMEINHARDT', NULL, 'FL', 10, 'Zoe Mcdowell', NULL),
	(1842, 642, 'SXB', 'SAXOPHONE, BARITONE', 'XF05936', 'Good', 'PIANO ROOM', 'JUPITER', 'JBS 1000', 'BX', 3, NULL, NULL),
	(1788, 641, 'SXB', 'SAXOPHONE, BARITONE', 'B15217', 'Good', NULL, 'VIENNA', NULL, 'BX', 2, 'Fatuma Tall', 301),
	(1814, 38, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM18030151', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 6, NULL, NULL),
	(1750, 40, 'TNAP', 'TROMBONE, ALTO - PLASTIC', 'BM17120387', 'Good', 'INSTRUMENT STORE', 'PBONE', 'Mini', 'PTB', 8, NULL, NULL),
	(1565, 350, 'VCL', 'CELLO, (VIOLONCELLO)', NULL, 'Good', NULL, 'WENZER KOHLER', NULL, 'C', 2, 'Mark Anding', 1076),
	(1795, 7, 'BT', 'BARITONE/TENOR HORN', '575586', 'Good', 'INSTRUMENT STORE', 'BESSON', NULL, 'BH', 1, NULL, NULL),
	(1797, 160, 'TPP', 'TRUMPET, POCKET', 'PT1309020', 'Good', 'INSTRUMENT STORE', 'ALLORA', NULL, 'TPP', 1, NULL, NULL),
	(1598, 90, 'TP', 'TRUMPET, B FLAT', 'F24090', 'Good', NULL, 'BLESSING', NULL, 'TP', 10, 'Gakenia Mucharie', 1075),
	(1714, 463, 'CL', 'CLARINET, B FLAT', 'XE54729', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 55, 'Lauren Mucci', 981),
	(1698, 477, 'CL', 'CLARINET, B FLAT', 'BE63692', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 69, 'Olivia Patel', 601),
	(1592, 572, 'SXA', 'SAXOPHONE, ALTO', '200585', 'Good', NULL, 'GIARDINELLI', NULL, 'AX', 7, 'Gwendolyn Anding', 1077),
	(1710, 619, 'SXA', 'SAXOPHONE, ALTO', 'XF56406', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 50, 'Luke O''Hara', 481),
	(2046, 625, 'SXA', 'SAXOPHONE, ALTO', 'AF53425', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 56, 'Milan Jayaram', 967),
	(1713, 632, 'SXA', 'SAXOPHONE, ALTO', 'BF54335', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 63, 'Tawheed Hussain', 177) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1703, 604, 'SXA', 'SAXOPHONE, ALTO', 'XF54451', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 35, 'Uzima Otieno', 911),
	(1706, 47, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'TROMBA', 'Pro', 'PTB', 15, 'Kianu Ruiz Stannah', 276),
	(1593, 8, 'HNF', 'HORN, F', '619528', 'Good', NULL, 'HOLTON', 'H281', 'HN', 1, 'Gwendolyn Anding', 1077),
	(1603, 349, 'VCL', 'CELLO, (VIOLONCELLO)', '100725', 'Good', NULL, 'CREMONA', NULL, 'C', 1, 'Gwendolyn Anding', 1077),
	(1621, 383, 'GRE', 'GUITAR, ELECTRIC', '116108513', 'Good', NULL, 'FENDER', 'CD-60CE Mahogany', NULL, 30, 'Gakenia Mucharie', 1075),
	(1715, 346, 'GRB', 'GUITAR, BASS', 'ICS10191321', 'Good', NULL, 'FENDER', 'Squire', NULL, 3, 'Isla Willis', 925),
	(2057, 606, 'SXA', 'SAXOPHONE, ALTO', 'XF54452', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 37, 'Tanay Cherickel', 974),
	(1905, 111, 'TP', 'TRUMPET, B FLAT', '645447', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 31, NULL, NULL),
	(1754, 5, 'BH', 'BARITONE/EUPHONIUM', '533835', 'Good', NULL, 'YAMAHA', NULL, 'BH', 6, 'Saqer Alnaqbi', 942),
	(1757, 433, 'CL', 'CLARINET, B FLAT', '405117', 'Good', NULL, 'YAMAHA', NULL, 'CL', 25, 'Tangaaza Mujuni', 173),
	(2044, 543, 'FL', 'FLUTE', 'XD59816', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 48, 'Teagan Wood', 159),
	(2050, 535, 'FL', 'FLUTE', 'WD62108', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 40, 'Yoonseo Choi', 953),
	(1740, 427, 'CL', 'CLARINET, B FLAT', 'J65020', 'Good', NULL, 'YAMAHA', NULL, 'CL', 19, 'Zayn Khalid', 975),
	(1844, 605, 'SXA', 'SAXOPHONE, ALTO', 'XF53797', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 36, 'Thomas Higgins', 342),
	(1819, 608, 'SXA', 'SAXOPHONE, ALTO', 'XF54476', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 39, 'Tobias Godfrey', 179),
	(2097, 43, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PB17070488', 'Good', NULL, 'TROMBA', 'Pro', 'PTB', 11, 'Titu Tulga', 788),
	(1990, 666, 'SXT', 'SAXOPHONE, TENOR', 'CF07965', 'Good', NULL, 'JUPITER', 'JTS700', 'TX', 22, 'Tawheed Hussain', 177),
	(2043, 23, 'TN', 'TROMBONE, TENOR', '303168', 'Good', NULL, 'YAMAHA', NULL, 'TB', 9, 'Zameer Nanji', 257),
	(1876, 313, 'BL', 'BELL SET', NULL, 'Good', NULL, 'UNKNOWN', NULL, NULL, 2, 'Selma Mensah', 958),
	(1908, 363, 'GRC', 'GUITAR, CLASSICAL', 'HKZ104831', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 7, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1738, 467, 'CL', 'CLARINET, B FLAT', 'XE54680', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 59, 'Aisha Awori', 960),
	(1902, 456, 'CL', 'CLARINET, B FLAT', 'KE56608', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 48, 'Ariel Mutombo', 948),
	(1901, 1, 'BH', 'BARITONE/EUPHONIUM', '601249', 'Good', NULL, 'BOOSEY & HAWKES', 'Soveriegn', 'BH', 2, 'Kasra Feizzadeh', 135),
	(2101, 101, 'TP', 'TRUMPET, B FLAT', 'H35502', 'Good', NULL, 'BLESSING', NULL, 'TP', 21, 'Kiara Materne', 934),
	(1900, 464, 'CL', 'CLARINET, B FLAT', 'XE54692', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 56, 'Lilla Vestergaard', 928),
	(2102, 103, 'TP', 'TRUMPET, B FLAT', 'H35099', 'Good', NULL, 'BLESSING', NULL, 'TP', 23, 'Mikael Eshetu', 935),
	(1533, 546, 'FL', 'FLUTE', 'XD60579', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 51, 'Nellie Odera', 1081),
	(1918, 458, 'CL', 'CLARINET, B FLAT', 'KE54751', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 50, 'Seung Hyun Nam', 973),
	(2099, 457, 'CL', 'CLARINET, B FLAT', 'KE54676', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 49, 'Theodore Wright', 1070),
	(1894, 596, 'SXA', 'SAXOPHONE, ALTO', 'XF54480', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 30, 'Margaret Oganda', 1078),
	(1899, 628, 'SXA', 'SAXOPHONE, ALTO', 'AF53348', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 59, 'Reuben Szuchman', 848),
	(1915, 621, 'SXA', 'SAXOPHONE, ALTO', 'YF57348', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 52, 'Mark Anding', 1076),
	(1923, 617, 'SXA', 'SAXOPHONE, ALTO', 'XF56283', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 48, 'Vanaaya Patel', 304),
	(1924, 616, 'SXA', 'SAXOPHONE, ALTO', 'XF57296', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 47, 'Yonatan Wondim Belachew Andersen', 952),
	(2100, 594, 'SXA', 'SAXOPHONE, ALTO', 'XF54576', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 29, 'Stefanie Landolt', 239),
	(1531, 623, 'SXA', 'SAXOPHONE, ALTO', 'YF57320', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 54, 'Nirvi Joymungul', 984),
	(1550, 624, 'SXA', 'SAXOPHONE, ALTO', 'XF54149', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 55, 'Gakenia Mucharie', 1075),
	(1895, 384, 'GRE', 'GUITAR, ELECTRIC', '116108578', 'Good', NULL, 'FENDER', 'CD-60CE Mahogany', NULL, 31, 'Angel Gray', NULL),
	(1561, 567, 'SXA', 'SAXOPHONE, ALTO', '11120072', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 2, NULL, NULL),
	(1562, 646, 'SXT', 'SAXOPHONE, TENOR', '227671', 'Good', 'INSTRUMENT STORE', 'BUSCHER', NULL, 'TX', 2, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1564, 389, 'GRT', 'GUITAR, HALF', '10', 'Good', NULL, 'KAY', NULL, NULL, 5, NULL, NULL),
	(1567, 285, 'SR', 'SNARE', '6276793', 'Good', 'MS MUSIC', 'LUDWIG', NULL, NULL, 1, NULL, NULL),
	(1568, 295, 'TML', 'TIMBALI', '3112778', 'Good', 'MS MUSIC', 'LUDWIG', NULL, NULL, 1, NULL, NULL),
	(1569, 257, 'DJ', 'DJEMBE', NULL, 'Good', 'MS MUSIC', 'CUSTOM', NULL, NULL, 7, NULL, NULL),
	(1571, 275, 'SRM', 'SNARE, MARCHING', '1P-3099', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 2, NULL, NULL),
	(1572, 278, 'SRM', 'SNARE, MARCHING', '1P-3076', 'Good', 'MS MUSIC', 'YAMAHA', 'MS 9014', NULL, 5, NULL, NULL),
	(1574, 288, 'SR', 'SNARE', 'NIL', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, NULL, 26, NULL, NULL),
	(1560, 143, 'TP', 'TRUMPET, B FLAT', 'XA02614', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 54, NULL, NULL),
	(1563, 153, 'TP', 'TRUMPET, B FLAT', 'BA09444', 'Good', 'INSTRUMENT STORE', 'JUPITER', NULL, 'TP', 64, NULL, NULL),
	(1573, 3, 'BH', 'BARITONE/EUPHONIUM', '839431', 'Good', NULL, 'AMATI KRASLICE', NULL, 'BH', 4, NULL, NULL),
	(1575, 510, 'FL', 'FLUTE', 'K98713', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 17, NULL, NULL),
	(1576, 512, 'FL', 'FLUTE', '2SP-K99109', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 18, NULL, NULL),
	(1577, 514, 'FL', 'FLUTE', 'P11203', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', '2SP', 'FL', 19, NULL, NULL),
	(1640, 587, 'SXA', 'SAXOPHONE, ALTO', '11110740', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'AX', 22, NULL, NULL),
	(1641, 386, 'GRT', 'GUITAR, HALF', '7', 'Good', NULL, 'KAY', NULL, NULL, 2, NULL, NULL),
	(1644, 600, 'SXA', 'SAXOPHONE, ALTO', 'XF54574', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 32, NULL, NULL),
	(1648, 603, 'SXA', 'SAXOPHONE, ALTO', 'XF54336', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 34, NULL, NULL),
	(1650, 581, 'SXA', 'SAXOPHONE, ALTO', '362477A', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'AX', 16, NULL, NULL),
	(1646, 74, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', 'INSTRUMENT STORE', 'PBONE', NULL, 'PTB', 42, NULL, NULL),
	(1649, 42, 'TNTP', 'TROMBONE, TENOR - PLASTIC', 'PB17070395', 'Good', NULL, 'TROMBA', 'Pro', 'PTB', 10, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1639, 517, 'FL', 'FLUTE', '28411021', 'Good', 'INSTRUMENT STORE', 'PRELUDE', NULL, 'FL', 22, NULL, NULL),
	(1642, 439, 'CL', 'CLARINET, B FLAT', '11299276', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 31, NULL, NULL),
	(1643, 527, 'FL', 'FLUTE', 'D1206485', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 32, NULL, NULL),
	(1645, 528, 'FL', 'FLUTE', 'D1206556', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 33, NULL, NULL),
	(1647, 529, 'FL', 'FLUTE', '206295', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 34, NULL, NULL),
	(1651, 116, 'TP', 'TRUMPET, B FLAT', '756323', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TP', 35, NULL, NULL),
	(1652, 530, 'FL', 'FLUTE', '206261', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'FL', 35, NULL, NULL),
	(1653, 531, 'FL', 'FLUTE', 'K96124', 'Good', 'INSTRUMENT STORE', 'GEMEINHARDT', NULL, 'FL', 36, NULL, NULL),
	(1654, 533, 'FL', 'FLUTE', 'WD57818', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JEL 710', 'FL', 38, NULL, NULL),
	(1656, 447, 'CL', 'CLARINET, B FLAT', '1209178', 'Good', 'INSTRUMENT STORE', 'ETUDE', NULL, 'CL', 39, NULL, NULL),
	(2053, 114, 'TP', 'TRUMPET, B FLAT', '511564', 'Good', NULL, 'YAMAHA', NULL, 'TP', 34, 'Aiden D''Souza', 944),
	(2047, 132, 'TP', 'TRUMPET, B FLAT', 'WA26516', 'Good', NULL, 'JUPITER', NULL, 'TP', 43, 'Anaiya Khubchandani', 947),
	(2045, 473, 'CL', 'CLARINET, B FLAT', 'YE67756', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 65, 'Gaia Bonde-Nielsen', 940),
	(1970, 92, 'TP', 'TRUMPET, B FLAT', '678970', 'Good', NULL, 'YAMAHA', 'YTR 2335', 'TP', 12, 'Ignacio Biafore', 936),
	(2051, 536, 'FL', 'FLUTE', 'WD62303', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 41, 'Julian Dibling', 939),
	(2006, 144, 'TP', 'TRUMPET, B FLAT', '488350', 'Good', NULL, 'BACH', NULL, 'TP', 55, 'Kaisei Stephens', 932),
	(1996, 113, 'TP', 'TRUMPET, B FLAT', 'F19277', 'Good', NULL, 'BLESSING', NULL, 'TP', 33, 'Kush Tanna', 941),
	(2049, 534, 'FL', 'FLUTE', 'WD62211', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 39, 'Leo Cutler', 267),
	(1995, 100, 'TP', 'TRUMPET, B FLAT', 'H31438', 'Good', NULL, 'BLESSING', NULL, 'TP', 20, 'Maria Agenorwot', 847),
	(1997, 538, 'FL', 'FLUTE', 'WD62183', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 43, 'Mark Anding', 1076) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(1983, 57, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'KAIZER', NULL, 'PTB', 25, 'Mark Anding', 1076),
	(1991, 664, 'SXT', 'SAXOPHONE, TENOR', 'CF07952', 'Good', NULL, 'JUPITER', 'JTS700', 'TX', 20, 'Mark Anding', 1076),
	(2042, 654, 'SXT', 'SAXOPHONE, TENOR', '063739A', 'Good', NULL, 'YAMAHA', NULL, 'TX', 10, 'Finlay Haswell', 951),
	(2048, 662, 'SXT', 'SAXOPHONE, TENOR', 'YF06601', 'Good', NULL, 'JUPITER', 'JTS710', 'TX', 18, 'Gunnar Purdy', 27),
	(2052, 660, 'SXT', 'SAXOPHONE, TENOR', '3847', 'Good', NULL, 'JUPITER', NULL, 'TX', 16, 'Adam Kone', 755),
	(2031, 26, 'TN', 'TROMBONE, TENOR', '406896', 'Good', NULL, 'YAMAHA', NULL, 'TB', 12, 'Marco De Vries Aguirre', 502),
	(2041, 18, 'TN', 'TROMBONE, TENOR', '406948', 'Good', NULL, 'YAMAHA', NULL, 'TB', 4, 'Arhum Bid', 240),
	(2028, 482, 'CLB', 'CLARINET, BASS', 'YE 69248', 'Good', NULL, 'YAMAHA', 'Hex 1000', 'BCL', 4, 'Gwendolyn Anding', 1077),
	(1632, 396, 'VN', 'VIOLIN', 'J052107087', 'Good', 'HS MUSIC', 'HOFNER', NULL, NULL, 1, NULL, NULL),
	(2072, 445, 'CL', 'CLARINET, B FLAT', 'J65342', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 37, NULL, NULL),
	(2067, 88, 'TP', 'TRUMPET, B FLAT', '806725', 'Good', NULL, 'YAMAHA', 'YTR 2335', 'TP', 8, 'Arjan Arora', 360),
	(2093, 83, 'TP', 'TRUMPET, B FLAT', '533719', 'Good', NULL, 'YAMAHA', NULL, 'TP', 3, 'Evan Daines', 954),
	(2088, 230, 'BD', 'BASS DRUM', 'PO-1575', 'Good', 'MS MUSIC', 'YAMAHA', 'CB628', NULL, 2, NULL, NULL),
	(2095, 86, 'TP', 'TRUMPET, B FLAT', '556107', 'Good', NULL, 'YAMAHA', 'YTR 2335', 'TP', 6, 'Holly Mcmurtry', 955),
	(2094, 440, 'CL', 'CLARINET, B FLAT', 'J65438', 'Good', NULL, 'YAMAHA', NULL, 'CL', 32, 'Io Verstraete', 792),
	(2092, 435, 'CL', 'CLARINET, B FLAT', '074011A', 'Good', NULL, 'YAMAHA', NULL, 'CL', 27, 'Leo Prawitz', 511),
	(2113, 618, 'SXA', 'SAXOPHONE, ALTO', 'XF56319', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 49, 'Barney Carver Wildig', 612),
	(2114, 461, 'CL', 'CLARINET, B FLAT', 'XE54957', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 53, 'Mahdiyah Muneeb', 977),
	(1731, 371, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', 'INSTRUMENT STORE', 'PARADISE', '17', NULL, 17, NULL, NULL),
	(1751, 283, 'BLS', 'BELLS, SLEIGH', NULL, 'Good', 'HS MUSIC', 'WEISS', NULL, NULL, 1, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(2071, 430, 'CL', 'CLARINET, B FLAT', 'J07292', 'Good', NULL, 'YAMAHA', NULL, 'CL', 22, 'Kevin Keene', NULL),
	(2117, 540, 'FL', 'FLUTE', 'XD58187', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 45, 'Saptha Girish Bommadevara', 332),
	(2116, 2, 'BH', 'BARITONE/EUPHONIUM', '770765', 'Good', NULL, 'BESSON', 'Soveriegn 968', 'BH', 3, 'Saqer Alnaqbi', 942),
	(2115, 548, 'FL', 'FLUTE', 'YD66080', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 54, 'Seya Chandaria', 926),
	(2118, 570, 'SXA', 'SAXOPHONE, ALTO', '11110173', 'Good', NULL, 'ETUDE', NULL, 'AX', 5, 'Lukas Norman', 419),
	(2121, 649, 'SXT', 'SAXOPHONE, TENOR', '31870', 'Good', NULL, 'YAMAHA', NULL, 'TX', 5, 'Spencer Schenck', 924),
	(2122, 21, 'TN', 'TROMBONE, TENOR', '325472', 'Good', NULL, 'YAMAHA', NULL, 'TB', 7, 'Maartje Stott', 114),
	(2074, 16, 'TN', 'TROMBONE, TENOR', '406538', 'Good', NULL, 'YAMAHA', NULL, 'TB', 2, 'Anne Bamlango', 359),
	(2119, 643, 'SXB', 'SAXOPHONE, BARITONE', 'AF03351', 'Good', NULL, 'JUPITER', 'JBS 1000', 'BX', 4, 'Lukas Norman', 419),
	(2068, 196, 'PE', 'PIANO, ELECTRIC', NULL, 'Good', 'DANCE STUDIO', 'YAMAHA', NULL, NULL, 8, NULL, NULL),
	(2069, 185, 'KB', 'KEYBOARD', '913094', 'Good', NULL, 'YAMAHA', 'PSR 220', NULL, 21, NULL, NULL),
	(2070, 186, 'KB', 'KEYBOARD', '13143', 'Good', NULL, 'YAMAHA', 'PSR 83', NULL, 22, NULL, NULL),
	(2077, 345, 'GRB', 'GUITAR, BASS', NULL, 'Good', 'MS MUSIC', 'YAMAHA', 'BB1000', NULL, 2, NULL, NULL),
	(2078, 219, NULL, 'PEDAL, SUSTAIN', NULL, 'Good', 'HS MUSIC', 'YAMAHA', 'FC4', NULL, 7, NULL, NULL),
	(2080, 316, 'BL', 'BELL SET', NULL, 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 5, NULL, NULL),
	(2089, 377, 'GRC', 'GUITAR, CLASSICAL', NULL, 'Good', NULL, 'YAMAHA', '40', NULL, 29, 'Keeara Walji', NULL),
	(2075, 365, 'GRC', 'GUITAR, CLASSICAL', 'HKP064005', 'Good', NULL, 'YAMAHA', '40', NULL, 9, 'Finola Doherty', NULL),
	(2076, 367, 'GRC', 'GUITAR, CLASSICAL', 'HKP054553', 'Good', NULL, 'YAMAHA', '40', NULL, 11, 'Marwa Baker', NULL),
	(1898, 91, 'TP', 'TRUMPET, B FLAT', '554189', 'Good', 'INSTRUMENT STORE', 'YAMAHA', 'YTR 2335', 'TP', 11, NULL, NULL),
	(1907, 161, 'TB', 'TUBA', '106508', 'Good', 'MS MUSIC', 'YAMAHA', NULL, 'T', 1, NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."instruments" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(2062, 265, 'DK', 'DRUMSET', 'SBB2217', 'Good', 'HS MUSIC', 'YAMAHA', NULL, NULL, 4, NULL, NULL),
	(1668, 214, NULL, 'HARNESS', NULL, 'Good', 'MS MUSIC', 'PEARL', NULL, NULL, 14, NULL, NULL),
	(1669, 425, 'CL', 'CLARINET, B FLAT', '443788', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'CL', 17, NULL, NULL),
	(1672, 360, 'GRC', 'GUITAR, CLASSICAL', 'HKP064875', 'Good', NULL, 'YAMAHA', '40', NULL, 4, 'Jihong Joo', 525),
	(1670, 635, 'SXA', 'SAXOPHONE, ALTO', 'CF57209', 'Good', 'INSTRUMENT STORE', 'JUPITER', 'JAS 710', 'AX', 66, NULL, NULL),
	(1673, 17, 'TN', 'TROMBONE, TENOR', '336151', 'Good', 'INSTRUMENT STORE', 'YAMAHA', NULL, 'TB', 3, NULL, NULL),
	(1671, 364, 'GRC', 'GUITAR, CLASSICAL', 'HKP064163', 'Good', 'MS MUSIC', 'YAMAHA', '40', NULL, 8, NULL, NULL),
	(2110, 551, 'FL', 'FLUTE', 'YD65954', 'Good', NULL, 'JUPITER', 'JEL 710', 'FL', 57, 'Anaiya Shah', 356),
	(2111, 99, 'TP', 'TRUMPET, B FLAT', 'H35203', 'Good', NULL, 'BLESSING', 'BTR 1270', 'TP', 19, 'Cahir Patel', 117),
	(2112, 124, 'TP', 'TRUMPET, B FLAT', '1107571', 'Good', NULL, 'LIBRETTO', NULL, 'TP', 39, 'Caleb Ross', 961),
	(2103, 106, 'TP', 'TRUMPET, B FLAT', 'H31450', 'Good', NULL, 'BLESSING', 'BIR 1270', 'TP', 26, 'Saqer Alnaqbi', 942),
	(2107, 469, 'CL', 'CLARINET, B FLAT', 'YE67254', 'Good', NULL, 'JUPITER', 'JCL710', 'CL', 61, 'Vilma Doret Rosen', 59),
	(2106, 629, 'SXA', 'SAXOPHONE, ALTO', 'AF53502', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 60, 'Noga Hercberg', 661),
	(2108, 592, 'SXA', 'SAXOPHONE, ALTO', 'XF54339', 'Good', NULL, 'JUPITER', 'JAS 710', 'AX', 27, 'Alexander Roe', 36),
	(2104, 64, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'PBONE', NULL, 'PTB', 32, 'Seth Lundell', 982),
	(2105, 66, 'TNTP', 'TROMBONE, TENOR - PLASTIC', NULL, 'Good', NULL, 'PBONE', NULL, 'PTB', 34, 'Sadie Szuchman', 846),
	(2109, 344, 'GRB', 'GUITAR, BASS', NULL, 'Good', NULL, 'ARCHER', NULL, NULL, 1, 'Jana Landolt', 302) ON CONFLICT DO NOTHING;


--
-- TOC entry 3912 (class 0 OID 23612)
-- Dependencies: 216
-- Data for Name: legacy_database; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(572, 47, 136, 'BRASS', 'TRUMPET, B FLAT', 'JUPITER', NULL, 'XA08643', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(91, 4, 315, 'PERCUSSION', 'BELL SET', 'UNKNOWN', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'BL') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(607, 55, 624, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF54149', 'HS MUSIC', '2023/24', 'Gakenia Mucharie', NULL, NULL, NULL, 'SXA') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(365, 16, 96, 'BRASS', 'TRUMPET, B FLAT', 'SCHILKE', 'B1L', '33911', NULL, '2023/24', 'Mark Anding', 'MS MUSIC', NULL, NULL, 'TP') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(423, 23, 187, 'KEYBOARD', 'KEYBOARD', 'CASIO', 'TC-360', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'KB') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(594, 52, 460, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54946', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(521, 38, 70, 'BRASS', 'TROMBONE, TENOR - PLASTIC', 'PBONE', NULL, NULL, NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNTP') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(370, 16, 581, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', NULL, '362477A', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(651, 66, 635, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'CF57209', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(588, 50, 619, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56406', 'BB7', '2023/24', 'Luke O''Hara', NULL, NULL, 12063, 'SXA') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(42, 2, 565, 'WOODWIND', 'PICCOLO', 'BUNDY', NULL, '12111016', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'PC') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(263, 8, 40, 'BRASS', 'TROMBONE, ALTO - PLASTIC', 'PBONE', 'Mini', 'BM17120387', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TNAP') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(426, 23, 518, 'WOODWIND', 'FLUTE', 'PRELUDE', NULL, '33111112', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'FL') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(560, 44, 613, 'WOODWIND', 'SAXOPHONE, ALTO', 'JUPITER', 'JAS 710', 'XF56401', NULL, '2023/24', 'Emiel Ghelani-Decorte', NULL, NULL, 12674, 'SXA') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(451, 27, 107, 'BRASS', 'TRUMPET, B FLAT', 'BLESSING', NULL, 'H34971', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'TP') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(617, 58, 466, 'WOODWIND', 'CLARINET, B FLAT', 'JUPITER', 'JCL710', 'XE54697', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'CL') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(249, 1, 385, 'STRING', 'GUITAR, HALF', 'KAY', NULL, '11', NULL, NULL, NULL, NULL, NULL, NULL, 'GRT') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(144, 6, 249, 'PERCUSSION', 'CONGA', 'LATIN PERCUSSION', '10 Inch', 'ISK 312138881', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'CG') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(388, 18, 583, 'WOODWIND', 'SAXOPHONE, ALTO', 'YAMAHA', 'YAS 23', 'T14584', NULL, NULL, NULL, 'INSTRUMENT STORE', NULL, NULL, 'SXA') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(31, 2, 330, 'PERCUSSION', 'XYLOPHONE', 'ORFF', NULL, NULL, 'ES MUSIC', NULL, NULL, 'UPPER ES MUSIC', NULL, NULL, 'X') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(279, 9, 174, 'ELECTRIC', 'AMPLIFIER, KEYBOARD', 'PEAVEY', NULL, 'ODB#1230169', 'HS MUSIC', NULL, NULL, 'HS MUSIC', NULL, NULL, 'AMK') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(317, 12, 92, 'BRASS', 'TRUMPET, B FLAT', 'YAMAHA', 'YTR 2335', '678970', 'BB8', '2023/24', 'Ignacio Biafore', NULL, NULL, 12170, 'TP') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(420, 22, 666, 'WOODWIND', 'SAXOPHONE, TENOR', 'JUPITER', 'JTS700', 'CF07965', NULL, '2023/24', 'Tawheed Hussain', 'MS MUSIC', NULL, 11469, 'SXT') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(230, 1, 292, 'PERCUSSION', 'TAMBOURINE', 'MEINL', 'Open face', NULL, NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'TR') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(84, 4, 191, 'KEYBOARD', 'PIANO, ELECTRIC', 'YAMAHA', 'CAP 320', 'YCQM01249', NULL, NULL, NULL, 'MS MUSIC', NULL, NULL, 'PE') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(537, 40, 535, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'WD62108', 'BB7', '2023/24', 'Yoonseo Choi', NULL, NULL, 10708, 'FL') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(415, 22, 186, 'KEYBOARD', 'KEYBOARD', 'YAMAHA', 'PSR 83', '13143', NULL, NULL, NULL, NULL, NULL, NULL, 'KB') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
	(614, 57, 551, 'WOODWIND', 'FLUTE', 'JUPITER', 'JEL 710', 'YD65954', 'BB7', '2023/24', 'Anaiya Shah', NULL, NULL, 11264, 'FL') ON CONFLICT DO NOTHING;
INSERT INTO "public"."legacy_database" ("id", "number", "legacy_number", "family", "equipment", "make", "model", "serial", "class", "year", "full_name", "school_storage", "return_2023", "student_number", "code") VALUES
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
-- TOC entry 3943 (class 0 OID 24727)
-- Dependencies: 247
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."locations" ("room", "custodian", "id") VALUES
	('PIANO ROOM', NULL, 3),
	('INSTRUMENT STORE', NULL, 4),
	('PRACTICE ROOM 3', NULL, 5),
	('PRACTICE ROOM 2', NULL, 6),
	('DRUM ROOM 2', NULL, 7),
	('LOWER ES MUSIC', NULL, 8),
	('MUSIC OFFICE', NULL, 9),
	('HS MUSIC', NULL, 10),
	('UPPER ES MUSIC', NULL, 11),
	('THEATRE/FOYER', NULL, 12),
	('MS MUSIC', NULL, 13),
	('DANCE STUDIO', NULL, 14),
	('PRACTICE ROOM 1', NULL, 15),
	('DRUM ROOM 1', NULL, 16) ON CONFLICT DO NOTHING;


--
-- TOC entry 3938 (class 0 OID 24646)
-- Dependencies: 242
-- Data for Name: music_instruments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(240, 'BRASS', 'HORN, ALTO', NULL, 'HNE', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(260, 'BRASS', 'TRUMPET, BASS', NULL, 'TPB', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(280, 'PERCUSSION', 'CASTANETS', NULL, 'CST', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(300, 'PERCUSSION', 'MBIRA', NULL, 'MB', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(320, 'PERCUSSION', 'AGOGO BELL', NULL, 'AGG', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(340, 'PERCUSSION', 'TAMBOURINE, 10 INCH', NULL, 'TRT', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(360, 'STRING', 'BANJO, BASS', NULL, 'BJB', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(380, 'STRING', 'GUITAR SYNTHESIZER', NULL, 'GR', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(400, 'STRING', 'GUITAR, HALF', NULL, 'GRT', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(440, 'STRING', 'UKULELE, CONCERT', NULL, 'UKC', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(460, 'WOODWIND', 'BAGPIPE', NULL, 'BGP', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(480, 'WOODWIND', 'FIFE', NULL, 'FF', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(500, 'WOODWIND', 'PAN FLUTE', NULL, 'PF', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
	(520, 'WOODWIND', 'SAXOPHONE', NULL, 'SX', NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."music_instruments" ("id", "family", "description", "legacy_code", "code", "notes") VALUES
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
-- TOC entry 3946 (class 0 OID 24850)
-- Dependencies: 250
-- Data for Name: new_instrument; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."new_instrument" ("id", "legacy_number", "code", "description", "serial", "state", "location", "make", "model", "legacy_code", "number", "user_name", "user_id") VALUES
	(3, NULL, NULL, 'DUMMY 1', 'DUMMM1', 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, NULL, NULL, NULL),
	(8, NULL, NULL, 'DUMMY 1', 'DUMMM1', 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, NULL, NULL, NULL),
	(9, NULL, NULL, 'DUMMY 1', 'DUMMM2', 'Good', 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, NULL, NULL, NULL),
	(10, NULL, NULL, 'DUMMY 1', 'DUMMM3', NULL, 'INSTRUMENT STORE', 'DUMMY MAKER', 'DUMDUM', NULL, NULL, NULL, NULL),
	(11, NULL, NULL, 'DUMMY 1', 'DUMMM4', NULL, 'INSTRUMENT STORE', 'DUMMY MAKER', NULL, NULL, NULL, NULL, NULL) ON CONFLICT DO NOTHING;


--
-- TOC entry 3926 (class 0 OID 24313)
-- Dependencies: 230
-- Data for Name: repair_request; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3930 (class 0 OID 24341)
-- Dependencies: 234
-- Data for Name: requests; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3928 (class 0 OID 24327)
-- Dependencies: 232
-- Data for Name: resolve; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- TOC entry 3924 (class 0 OID 24301)
-- Dependencies: 228
-- Data for Name: returns; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."returns" ("id", "created_at", "item_id", "created_by") VALUES
	(6, '2024-01-31', 2129, NULL),
	(8, '2024-01-31', 2129, NULL),
	(9, '2024-01-31', 2129, NULL),
	(11, '2024-01-31', 2129, NULL),
	(12, '2024-01-31', 1494, NULL),
	(13, '2024-01-31', 1494, NULL),
	(14, '2024-02-01', 2129, NULL),
	(15, '2024-02-01', 2129, 'postgres'),
	(16, '2024-02-01', 1731, 'postgres'),
	(17, '2024-02-01', 1768, 'postgres'),
	(18, '2024-02-01', 2072, 'postgres'),
	(19, '2024-02-01', 1595, 'postgres'),
	(20, '2024-02-01', 1618, 'postgres'),
	(21, '2024-02-01', 2072, 'postgres'),
	(22, '2024-02-01', 2072, 'postgres'),
	(23, '2024-02-01', 1768, 'postgres'),
	(24, '2024-02-01', 1618, 'postgres'),
	(25, '2024-02-01', 1731, 'postgres'),
	(26, '2024-02-01', 1595, 'postgres') ON CONFLICT DO NOTHING;


--
-- TOC entry 3916 (class 0 OID 24238)
-- Dependencies: 220
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."roles" ("id", "role_name") VALUES
	(4, 'STUDENT'),
	(5, 'MUSIC TEACHER'),
	(6, 'INVENTORY MANAGER'),
	(7, 'COMMUNITY'),
	(8, 'ADMIN'),
	(10, 'MUSIC TA'),
	(11, 'SUBSTITUTE') ON CONFLICT DO NOTHING;


--
-- TOC entry 3934 (class 0 OID 24383)
-- Dependencies: 238
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(14, 11764, 'Rosen', 'Rosa Marie', '3', 'Lollerosen@gmail.com', 'mikaeldissing@gmail.com', 'ES', NULL, NULL),
	(16, 11845, 'Rosen', 'August', '9', 'Lollerosen@gmail.com', 'mikaeldissing@gmail.com', 'HS', NULL, NULL),
	(17, 13077, 'Abdissa', 'Dawit', '8', 'addisalemt96@gmail.com', 'tesemaa@un.org', 'MS', NULL, NULL),
	(18, 13078, 'Abdissa', 'Meron', '8', 'addisalemt96@gmail.com', 'tesemaa@un.org', 'MS', NULL, NULL),
	(19, 12966, 'Andersen', 'Yohanna Wondim Belachew', '1', 'louian@um.dk', 'wondim_b@yahoo.com', 'ES', NULL, NULL),
	(21, 12968, 'Andersen', 'Yonas Wondim Belachew', '10', 'louian@um.dk', 'wondim_b@yahoo.com', 'HS', NULL, NULL),
	(23, 11881, 'Camisa', 'Cassandre', '9', 'katerinelafreniere@hotmail.com', 'laurentcamisa@hotmail.com', 'HS', NULL, NULL),
	(24, 12277, 'Armstrong', 'Cole', '7', 'stacia.armstrong@ymail.com', 'patrick.k.armstrong@gmail.com', 'MS', NULL, NULL),
	(25, 12276, 'Armstrong', 'Kennedy', '11', 'stacia.armstrong@ymail.com', 'patrick.k.armstrong@gmail.com', 'HS', NULL, NULL),
	(26, 11856, 'De Backer', 'Lily', '10', 'camilletanza@yahoo.fr', 'pierredeb1@gmail.com', 'HS', NULL, NULL),
	(27, 11801, 'Kuehnle', 'Emma', '5', 'jk.payan@gmail.com', 'jkuehnle@usaid.gov', 'ES', NULL, NULL),
	(28, 11833, 'Kuehnle', 'John (Trey)', '7', 'jk.payan@gmail.com', 'jkuehnle@usaid.gov', 'MS', NULL, NULL),
	(29, 12465, 'Abraha', 'Rahsi', '4', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'ES', NULL, NULL),
	(30, 12464, 'Abraha', 'Siyam', '8', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'MS', NULL, NULL),
	(31, 12463, 'Abraha', 'Risty', '9', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'HS', NULL, NULL),
	(32, 12462, 'Abraha', 'Seret', '12', 'senait.zwerasi@gmail.com', 'yosiefa@gmail.com', 'HS', NULL, NULL),
	(33, 11902, 'Ashton', 'Hugo', '6', '1charlotteashton@gmail.com', 'todd.ashton@ericsson.com', 'MS', NULL, NULL),
	(34, 11893, 'Ashton', 'Theodore', '9', '1charlotteashton@gmail.com', 'todd.ashton@ericsson.com', 'HS', NULL, NULL),
	(35, 11896, 'Ashton', 'Vera', '11', '1charlotteashton@gmail.com', 'todd.ashton@ericsson.com', 'HS', NULL, NULL),
	(36, 11932, 'Massawe', 'Nathan', '4', 'kikii.brown78@gmail.com', 'nmassawe@hotmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(37, 11933, 'Massawe', 'Noah', '8', 'kikii.brown78@gmail.com', 'nmassawe@hotmail.com', 'MS', NULL, NULL),
	(38, 12746, 'Bedein', 'Ziv', 'K', 'bebedein@gmail.com', 'gilbeinken@gmail.com', 'ES', NULL, NULL),
	(39, 12615, 'Bedein', 'Itai', '4', 'bebedein@gmail.com', 'gilbeinken@gmail.com', 'ES', NULL, NULL),
	(41, 12345, 'Purdy', 'Annika', '2', 'Mangoshy@yahoo.com', 'jess_a_purdy@yahoo.com', 'ES', NULL, NULL),
	(42, 12348, 'Purdy', 'Christiaan', '5', 'Mangoshy@yahoo.com', 'jess_a_purdy@yahoo.com', 'ES', NULL, NULL),
	(43, 12349, 'Purdy', 'Gunnar', '8', 'Mangoshy@yahoo.com', 'jess_a_purdy@yahoo.com', 'MS', NULL, NULL),
	(44, 12780, 'Abou Hamda', 'Lana', '5', 'hiba_hassan1983@hotmail.com', 'designcenter2011@live.com', 'ES', NULL, NULL),
	(45, 12779, 'Abou Hamda', 'Samer', '8', 'hiba_hassan1983@hotmail.com', 'designcenter2011@live.com', 'MS', NULL, NULL),
	(46, 12778, 'Abou Hamda', 'Youssef', '11', 'hiba_hassan1983@hotmail.com', 'designcenter2011@live.com', 'HS', NULL, NULL),
	(47, 12075, 'Andersen', 'Ida-Marie', '12', 'hanneseverin@hotmail.com', 'martin.andersen@eeas.europa.eu', 'HS', NULL, NULL),
	(48, 12497, 'Cole', 'Cheryl', '12', 'colevira@gmail.com', 'acole@unicef.org', 'HS', NULL, NULL),
	(49, 12247, 'Bunbury', 'Oria', 'K', 'tammybunbury@gmail.com', 'robertbunbury@gmail.com', 'ES', NULL, NULL),
	(50, 12733, 'Eom', 'Dawon', '10', 'yinjing7890@gmail.com', 'ikhyuneom@hotmail.com', 'HS', NULL, NULL),
	(51, 11925, 'Mohan', 'Arnav', '12', 'divyamohan2000@gmail.com', 'rakmohan1@yahoo.com', 'HS', NULL, NULL),
	(52, 12188, 'Roe', 'Alexander', '7', 'christinarece@gmail.com', 'aron.roe@international.gc.ca', 'MS', NULL, NULL),
	(53, 12186, 'Roe', 'Elizabeth', '9', 'christinarece@gmail.com', 'aron.roe@international.gc.ca', 'HS', NULL, NULL),
	(54, 12535, 'Lindvig', 'Freja', '5', 'elisa@lindvig.com', 'jglindvig@gmail.com', 'ES', NULL, NULL),
	(1065, 12559, 'Linck', 'Hana', '12', 'anitapetitpierre@gmail.com', NULL, 'HS', NULL, NULL),
	(55, 12502, 'Lindvig', 'Sif', '8', 'elisa@lindvig.com', 'jglindvig@gmail.com', 'MS', NULL, NULL),
	(56, 12503, 'Lindvig', 'Mimer', '10', 'elisa@lindvig.com', 'jglindvig@gmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(57, 12440, 'Weurlander', 'Frida', '4', 'pia.weurlander@gmail.com', 'matts.weurlander@gmail.com', 'ES', NULL, NULL),
	(58, 11505, 'Singh', 'Zahra', '9', 'ypande@gmail.com', 'kabirsingh75@gmail.com', 'HS', NULL, NULL),
	(59, 12206, 'Zhang', 'Dylan', '1', 'bonjourchelsea.zz@gmail.com', 'zhangwei@bucg.cc', 'ES', NULL, NULL),
	(60, 11838, 'Aubrey', 'Carys', '8', 'joaubrey829@gmail.com', 'dyfed.aubrey@un.org', 'MS', NULL, NULL),
	(61, 10950, 'Aubrey', 'Evie', '12', 'joaubrey829@gmail.com', 'dyfed.aubrey@un.org', 'HS', NULL, NULL),
	(62, 11910, 'Mahmud', 'Raeed', '12', 'eshajasmine@gmail.com', 'kmahmud@gmail.com', 'HS', NULL, NULL),
	(63, 11185, 'Mekonnen', 'Kaleb', '5', 'helenabebaw35@gmail.com', 'm.loulseged@afdb.org', 'ES', NULL, NULL),
	(64, 11015, 'Mekonnen', 'Yonathan', '7', 'helenabebaw35@gmail.com', 'm.loulseged@afdb.org', 'MS', NULL, NULL),
	(65, 11793, 'Mathers', 'Aya', '4', 'eri77s@gmail.com', 'nickmathers@gmail.com', 'ES', NULL, NULL),
	(66, 11110, 'Mathers', 'Yui', '8', 'eri77s@gmail.com', 'nickmathers@gmail.com', 'MS', NULL, NULL),
	(67, 11468, 'Gardner', 'Madeleine', '5', 'michelle.barrett@wfp.org', 'calum.gardner@wfp.org', 'ES', NULL, NULL),
	(69, 11362, 'Russo', 'Sofia', '4', 'samiaabdul@yahoo.com', 'andrearux@yahoo.it', 'ES', NULL, NULL),
	(70, 11361, 'Russo', 'Leandro', '8', 'samiaabdul@yahoo.com', 'andrearux@yahoo.it', 'MS', NULL, NULL),
	(73, 11724, 'Murathi', 'Gerald', '4', 'ngugir@hotmail.com', 'ammuturi@yahoo.com', 'ES', NULL, NULL),
	(74, 11735, 'Murathi', 'Megan', '7', 'ngugir@hotmail.com', 'ammuturi@yahoo.com', 'MS', NULL, NULL),
	(75, 11736, 'Murathi', 'Eunice', '11', 'ngugir@hotmail.com', 'ammuturi@yahoo.com', 'HS', NULL, NULL),
	(76, 11479, 'Manzano', 'Abby Angelica', '7', 'mira_manzano@yahoo.com', 'jose.manzano@undp.org', 'MS', NULL, NULL),
	(15, 11763, 'Rosen', 'Vilma Doret', '6', 'Lollerosen@gmail.com', 'mikaeldissing@gmail.com', 'MS', 'Beginning Band 7 2023', 'vrosen30@isk.ac.ke'),
	(68, 11467, 'Gardner', 'Elizabeth', '7', 'michelle.barrett@wfp.org', 'calum.gardner@wfp.org', 'MS', 'Concert Band 2023', 'egardner29@isk.ac.ke'),
	(40, 12614, 'Bedein', 'Shai', '7', 'bebedein@gmail.com', 'gilbeinken@gmail.com', 'MS', 'Concert Band 2023', 'sbedein29@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(89, 13005, 'Alemu', 'Or', 'K', 'esti20022@gmail.com', 'alemus20022@gmail.com', 'ES', NULL, NULL),
	(77, 11942, 'Bellamy', 'Lillia', '3', 'ahuggins@mercycorps.org', 'bellamy.paul@gmail.com', 'ES', NULL, NULL),
	(78, 10319, 'Ouma', 'Destiny', '8', 'aouso05@gmail.com', 'oumajao05@gmail.com', 'MS', NULL, NULL),
	(79, 12197, 'Ronzio', 'Louis', '3', 'janinecocker@gmail.com', 'jronzio@gmail.com', 'ES', NULL, NULL),
	(80, 12199, 'Ronzio', 'George', '7', 'janinecocker@gmail.com', 'jronzio@gmail.com', 'MS', NULL, NULL),
	(82, 24068, 'Awori', 'Andre', '12', 'jeawori@gmail.com', 'jeremyawori@gmail.com', 'HS', NULL, NULL),
	(83, 12121, 'Shah', 'Krishi', '10', 'komal.kevs@gmail.com', 'keval.shah@cloudhop.it', 'HS', NULL, NULL),
	(84, 11416, 'Fisher', 'Isabella', '9', 'nataliafisheranne@gmail.com', 'ben.fisher@fcdo.gov.uk', 'HS', NULL, NULL),
	(85, 11415, 'Fisher', 'Charles', '11', 'nataliafisheranne@gmail.com', 'ben.fisher@fcdo.gov.uk', 'HS', NULL, NULL),
	(86, 10557, 'Mwangi', 'Joy', '12', 'winrose@flexi-personnel.com', 'wawerujamesmwangi@gmail.com', 'HS', NULL, NULL),
	(88, 11985, 'Akuete', 'Hassan', '10', 'kaycwed@gmail.com', 'pkakuete@gmail.com', 'HS', NULL, NULL),
	(90, 13004, 'Alemu', 'Leul', '5', 'esti20022@gmail.com', 'alemus20022@gmail.com', 'ES', NULL, NULL),
	(91, 12336, 'Otterstedt', 'Lisa', '12', 'annika.otterstedt@icloud.com', 'isak.isaksson@naturskyddsforeningen.se', 'HS', NULL, NULL),
	(93, 12520, 'Stott', 'Helena', '9', 'arineachterstraat@me.com', 'stottbrian@me.com', 'HS', NULL, NULL),
	(94, 12521, 'Stott', 'Patrick', '10', 'arineachterstraat@me.com', 'stottbrian@me.com', 'HS', NULL, NULL),
	(95, 12397, 'Kimani', 'Isla', 'K', 'rjones@isk.ac.ke', 'anthonykimani001@gmail.com', 'ES', NULL, NULL),
	(96, 11788, 'Van De Velden', 'Christodoulos', '3', 'smafro@gmail.com', 'jaapvandevelden@gmail.com', 'ES', NULL, NULL),
	(97, 10704, 'Van De Velden', 'Evangelia', '7', 'smafro@gmail.com', 'jaapvandevelden@gmail.com', 'MS', NULL, NULL),
	(98, 11731, 'Todd', 'Sofia', '2', 'carli@vovohappilyorganic.com', 'rich.toddy77@gmail.com', 'ES', NULL, NULL),
	(99, 11481, 'Mogilnicki', 'Dominik', '5', 'aurelia_micko@yahoo.com', 'milosz.mogilnicki@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(102, 12723, 'Echalar', 'Kieran', '1', 'shortjas@gmail.com', 'ricardo.echalar@gmail.com', 'ES', NULL, NULL),
	(103, 11882, 'Echalar', 'Liam', '4', 'shortjas@gmail.com', 'ricardo.echalar@gmail.com', 'ES', NULL, NULL),
	(104, 12750, 'Wilkes', 'Nova', 'PK', 'aninepier@gmail.com', 'joshuawilkes@hotmail.co.uk', 'ES', NULL, NULL),
	(106, 12095, 'Freiherr Von Handel', 'Maximilian', '11', 'igiribaldi@hotmail.com', 'thomas.von.handel@gmail.com', 'HS', NULL, NULL),
	(107, 11759, 'Lopez Abella', 'Lucas', '3', 'monica.lopezconlon@gmail.com', 'iniakiag@gmail.com', 'ES', NULL, NULL),
	(108, 11819, 'Lopez Abella', 'Mara', '5', 'monica.lopezconlon@gmail.com', 'iniakiag@gmail.com', 'ES', NULL, NULL),
	(109, 27007, 'Miller', 'Cassius', '9', 'emiller@isk.ac.ke', 'Angus.miller@fcdo.gov.uk', 'HS', NULL, NULL),
	(110, 25051, 'Miller', 'Albert', '11', 'emiller@isk.ac.ke', 'Angus.miller@fcdo.gov.uk', 'HS', NULL, NULL),
	(111, 12753, 'Rose', 'Axel', 'PK', 'tiarae@rocketmail.com', 'rosetimothy@gmail.com', 'ES', NULL, NULL),
	(112, 10843, 'James', 'Evelyn', '5', 'tiarae@rocketmail.com', 'rosetimothy@gmail.com', 'ES', NULL, NULL),
	(113, 11941, 'Sudra', 'Ellis', '1', 'maryleakeysudra@gmail.com', 'msudra@isk.ac.ke', 'ES', NULL, NULL),
	(114, 10784, 'Shah', 'Arav', '7', 'alpadodhia@gmail.com', 'whiteicepharmaceuticals@gmail.com', 'MS', NULL, NULL),
	(115, 12993, 'Thornton', 'Lucia', '5', 'emilypt1980@outlook.com', 'thorntoncr1@state.gov', 'ES', NULL, NULL),
	(116, 12992, 'Thornton', 'Robert', '7', 'emilypt1980@outlook.com', 'thorntoncr1@state.gov', 'MS', NULL, NULL),
	(117, 12492, 'Yun', 'Jeongu', '2', 'juhee907000@gmail.com', 'tony.yun80@gmail.com', 'ES', NULL, NULL),
	(118, 12487, 'Yun', 'Geonu', '3', 'juhee907000@gmail.com', 'tony.yun80@gmail.com', 'ES', NULL, NULL),
	(119, 11937, 'Carter', 'David', '8', 'ksvensson@worldbank.org', 'miguelcarter.4@gmail.com', 'MS', NULL, NULL),
	(120, 12970, 'Willis', 'Gabrielle', '5', 'tjpeta.willis@gmail.com', 'pt.willis@bigpond.com', 'ES', NULL, NULL),
	(122, 11803, 'Schmidlin Guerrero', 'Julian', '5', 'ag.guerreroserdan@gmail.com', 'gaby.juerg@gmail.com', 'ES', NULL, NULL),
	(125, 10476, 'Awori', 'Malaika', '8', 'Annmarieawori@gmail.com', 'Michael.awori@gmail.com', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(126, 12248, 'Sagar', 'Aarav', '1', 'preeti74472@yahoo.com', 'sagaramit1@gmail.com', 'ES', NULL, NULL),
	(127, 11592, 'Sheridan', 'Indira', '10', 'noush007@hotmail.com', 'alan.sheridan@wfp.org', 'HS', NULL, NULL),
	(128, 11591, 'Sheridan', 'Erika', '12', 'noush007@hotmail.com', 'alan.sheridan@wfp.org', 'HS', NULL, NULL),
	(129, 12798, 'Andries-Munshi', 'Téa', 'K', 'sarah.andries@gmail.com', 'neilmunshi@gmail.com', 'ES', NULL, NULL),
	(130, 12788, 'Andries-Munshi', 'Zaha', '3', 'sarah.andries@gmail.com', 'neilmunshi@gmail.com', 'ES', NULL, NULL),
	(131, 10841, 'Wallbridge', 'Samir', '5', 'awallbridge@isk.ac.ke', 'tcwallbridge@gmail.com', 'ES', NULL, NULL),
	(132, 20867, 'Wallbridge', 'Lylah', '8', 'awallbridge@isk.ac.ke', 'tcwallbridge@gmail.com', 'MS', NULL, NULL),
	(133, 12134, 'Ansell', 'Oscar', '9', 'emily.ansell@gmail.com', 'damon.ansell@gmail.com', 'HS', NULL, NULL),
	(134, 11852, 'Ansell', 'Louise', '10', 'emily.ansell@gmail.com', 'damon.ansell@gmail.com', 'HS', NULL, NULL),
	(136, 12625, 'Harris Ii', 'Omar', '11', 'tnicoleharris@sbcglobal.net', 'omarharris@sbcglobal.net', 'HS', NULL, NULL),
	(137, 11003, 'Hissink', 'Boele', '5', 'saskia@dobequity.nl', 'lodewijkh@gmail.com', 'ES', NULL, NULL),
	(138, 10683, 'Hissink', 'Pomeline', '7', 'saskia@dobequity.nl', 'lodewijkh@gmail.com', 'MS', NULL, NULL),
	(92, 12519, 'Stott', 'Maartje', '6', 'arineachterstraat@me.com', 'stottbrian@me.com', 'MS', 'Beginning Band 1 2023', 'mstott30@isk.ac.ke'),
	(135, 12609, 'Harris', 'Owen', '6', 'tnicoleharris@sbcglobal.net', 'omarharris@sbcglobal.net', 'MS', 'Beginning Band 1 2023', 'oharris30@isk.ac.ke'),
	(100, 11480, 'Mogilnicki', 'Alexander', '7', 'aurelia_micko@yahoo.com', 'milosz.mogilnicki@gmail.com', 'MS', 'Concert Band 2023', 'amogilnicki29@isk.ac.ke'),
	(81, 10772, 'Patel', 'Cahir', '7', 'nads_k@hotmail.com', 'samir@aura-capital.com', 'MS', 'Concert Band 2023', 'cpatel29@isk.ac.ke'),
	(87, 12156, 'Akuete', 'Ehsan', '8', 'kaycwed@gmail.com', 'pkakuete@gmail.com', 'MS', 'Concert Band 2023', 'eakuete28@isk.ac.ke'),
	(151, 11647, 'Liban', 'Ismail', '7', 'shukrih77@gmail.com', 'aliban@cdc.gov', 'MS', NULL, NULL),
	(140, 10703, 'Tanna', 'Shreya', '8', 'vptanna@gmail.com', 'priyentanna@gmail.com', 'MS', NULL, NULL),
	(141, 13049, 'Clark', 'Samuel', '4', 'jwang7@ifc.org', 'davidjclark000@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(142, 12167, 'Yarkoni', 'Ohad', '3', 'dvorayarkoni4@gmail.com', 'yarkan1@yahoo.com', 'ES', NULL, NULL),
	(143, 12168, 'Yarkoni', 'Matan', '5', 'dvorayarkoni4@gmail.com', 'yarkan1@yahoo.com', 'ES', NULL, NULL),
	(144, 12169, 'Yarkoni', 'Itay', '8', 'dvorayarkoni4@gmail.com', 'yarkan1@yahoo.com', 'MS', NULL, NULL),
	(145, 11672, 'Nguyen', 'Yen', '7', 'nnguyen@parallelconsultants.com', 'luu@un.org', 'MS', NULL, NULL),
	(146, 11671, 'Nguyen', 'Binh', '9', 'nnguyen@parallelconsultants.com', 'luu@un.org', 'HS', NULL, NULL),
	(147, 11496, 'Hussain', 'Shams', '3', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'ES', NULL, NULL),
	(148, 11495, 'Hussain', 'Salam', '4', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'ES', NULL, NULL),
	(150, 10275, 'Pozzi', 'Basile', '12', 'brucama@gmail.com', 'brucama@gmail.com', 'HS', NULL, NULL),
	(152, 11666, 'Ibrahim', 'Ibrahim', '12', 'shukrih77@gmail.com', 'aliban@cdc.gov', 'HS', NULL, NULL),
	(153, 12752, 'Lopez Salazar', 'Mateo', 'K', 'alopez@isk.ac.ke', NULL, 'ES', NULL, NULL),
	(154, 11242, 'Godfrey', 'Benjamin', '5', 'amakagodfrey@gmail.com', 'drsamgodfrey@yahoo.co.uk', 'ES', NULL, NULL),
	(156, 11525, 'Sana', 'Jamal', '11', 'hadizamounkaila4@gmail.com', 'moussa.sana@wfp.org', 'HS', NULL, NULL),
	(157, 12872, 'Feizzadeh', 'Saba', '4', 'mahshidtaj88@gmail.com', 'feizzadeha@unaids.org', 'ES', NULL, NULL),
	(158, 12871, 'Feizzadeh', 'Kasra', '9', 'mahshidtaj88@gmail.com', 'feizzadeha@unaids.org', 'HS', NULL, NULL),
	(159, 12201, 'Fazal', 'Kayla', '6', 'aleeda@gmail.com', 'rizwanfazal2013@gmail.com', 'MS', NULL, NULL),
	(160, 11878, 'Fazal', 'Alyssia', '8', 'aleeda@gmail.com', 'rizwanfazal2013@gmail.com', 'MS', NULL, NULL),
	(161, 11530, 'Foster', 'Chloe', '11', 'Ttruong@isk.ac.ke', 'Bfoster@isk.ac.ke', 'HS', NULL, NULL),
	(162, 11582, 'Miyanue', 'Joyous', '10', 'knbajia8@gmail.com', 'tpngwa@gmail.com', 'HS', NULL, NULL),
	(163, 11583, 'Nkahnue', 'Marvelous Peace', '12', 'knbajia8@gmail.com', 'tpngwa@gmail.com', 'HS', NULL, NULL),
	(164, 10707, 'Patella Ross', 'Rafaelle', '7', 'sarahpatella@icloud.com', 'bross@unicef.org', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(165, 10617, 'Patella Ross', 'Juna', '10', 'sarahpatella@icloud.com', 'bross@unicef.org', 'HS', NULL, NULL),
	(166, 12879, 'Good', 'Tyler', '4', 'jenniferaharwood@yahoo.com', 'travistcg@gmail.com', 'ES', NULL, NULL),
	(167, 12878, 'Good', 'Julia', '8', 'jenniferaharwood@yahoo.com', 'travistcg@gmail.com', 'MS', NULL, NULL),
	(168, 11723, 'Biesiada', 'Maria-Antonina (Jay)', '10', 'magda.biesiada@gmail.com', NULL, 'HS', NULL, NULL),
	(169, 10980, 'Nannes', 'Ben', '9', 'pamela@terrasolkenya.com', 'sjaak@terrasolkenya.com', 'HS', NULL, NULL),
	(170, 11520, 'Hajee', 'Kaiam', '5', 'jhajee@isk.ac.ke', 'khalil.hajee@gmail.com', 'ES', NULL, NULL),
	(171, 11542, 'Hajee', 'Kadin', '7', 'jhajee@isk.ac.ke', 'khalil.hajee@gmail.com', 'MS', NULL, NULL),
	(172, 11541, 'Hajee', 'Kahara', '8', 'jhajee@isk.ac.ke', 'khalil.hajee@gmail.com', 'MS', NULL, NULL),
	(173, 10688, 'Gebremedhin', 'Maria', '6', 'donicamerhazion@gmail.com', 'mgebremedhin@gmail.com', 'MS', NULL, NULL),
	(174, 12003, 'Copeland', 'Rainey', '12', 'susancopeland@gmail.com', 'charlescopeland@gmail.com', 'HS', NULL, NULL),
	(177, 11936, 'Ndinguri', 'Zawadi', '5', 'muriithifiona@gmail.com', 'joramgatei@gmail.com', 'ES', NULL, NULL),
	(178, 24001, 'De Jong', 'Max', '11', 'anouk.paauwe@gmail.com', 'rob.jong@un.org', 'HS', NULL, NULL),
	(179, 12372, 'Davis - Arana', 'Maximiliano', '1', 'majo.arana@gmail.com', 'nick.diallo@gmail.com', 'ES', NULL, NULL),
	(180, 12797, 'Nicolau Meganck', 'Emilia', 'K', 'nicolau.joana@gmail.com', 'joana.olivier2016@gmail.com', 'ES', NULL, NULL),
	(182, 10968, 'Anding', 'Zane', '11', 'ganding@isk.ac.ke', 'manding@isk.ac.ke', 'HS', NULL, NULL),
	(183, 11940, 'Rogers', 'Otis', '1', 'laoisosullivan@yahoo.com.au', 'mrogers@isk.ac.ke', 'ES', NULL, NULL),
	(184, 12744, 'Rogers', 'Liam', 'PK', 'laoisosullivan@yahoo.com.au', 'mrogers@isk.ac.ke', 'ES', NULL, NULL),
	(185, 10972, 'Wood', 'Teagan', '9', 'carriewoodtz@gmail.com', 'cwood.ken@gmail.com', 'HS', NULL, NULL),
	(186, 10934, 'Wood', 'Caitlin', '11', 'carriewoodtz@gmail.com', 'cwood.ken@gmail.com', 'HS', NULL, NULL),
	(187, 10632, 'Masrani', 'Anusha', '8', 'shrutimasrani@gmail.com', 'rupinmasrani@gmail.com', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(188, 10641, 'Handa', 'Jin', '10', 'jinln-2009@163.com', 'jinzhe322406@gmail.com', 'HS', NULL, NULL),
	(189, 10279, 'Fest', 'Lina', '11', 'marilou_de_wit@hotmail.com', 'michel.fest@gmail.com', 'HS', NULL, NULL),
	(190, 10278, 'Fest', 'Marie', '11', 'marilou_de_wit@hotmail.com', 'michel.fest@gmail.com', 'HS', NULL, NULL),
	(191, 11830, 'Ramrakha', 'Divyaan', '7', 'leenagehlot@gmail.com', 'rishiramrakha@gmail.com', 'MS', NULL, NULL),
	(192, 11379, 'Ramrakha', 'Niyam', '10', 'leenagehlot@gmail.com', 'rishiramrakha@gmail.com', 'HS', NULL, NULL),
	(193, 11404, 'Jayaram', 'Akeyo', '3', 'sonali.murthy@gmail.com', 'kartik_j@yahoo.com', 'ES', NULL, NULL),
	(195, 10320, 'Sapta', 'Gendhis', '8', 'vanda.andromeda@yahoo.com', 'sapta.hendra@yahoo.com', 'MS', NULL, NULL),
	(196, 12706, 'Venkataya', 'Kianna', '4', 'e.venkataya@gmail.com', NULL, 'ES', NULL, NULL),
	(197, 11627, 'Line', 'Taegan', '7', 'emeraldcardinal7@gmail.com', 'kris.line@ice.dhs.gov', 'MS', NULL, NULL),
	(198, 11626, 'Line', 'Bronwyn', '9', 'emeraldcardinal7@gmail.com', 'kris.line@ice.dhs.gov', 'HS', NULL, NULL),
	(199, 11625, 'Line', 'Jamison', '11', 'emeraldcardinal7@gmail.com', 'kris.line@ice.dhs.gov', 'HS', NULL, NULL),
	(200, 10788, 'Mujuni', 'Tangaaza', '7', 'barbara.bamanya@gmail.com', 'benardmujuni@gmail.com', 'MS', NULL, NULL),
	(201, 20828, 'Mujuni', 'Rugaba', '10', 'barbara.bamanya@gmail.com', 'benardmujuni@gmail.com', 'HS', NULL, NULL),
	(202, 20805, 'Guyard Suengas', 'Laia', '11', 'tetxusu@gmail.com', NULL, 'HS', NULL, NULL),
	(331, 10977, 'Bamlango', 'Lucile', '6', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'lbamlango30@isk.ac.ke'),
	(149, 11469, 'Hussain', 'Tawheed', '6', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'MS', 'Beginning Band 1 2023', 'thussain30@isk.ac.ke'),
	(181, 10967, 'Anding', 'Florencia', '8', 'ganding@isk.ac.ke', 'manding@isk.ac.ke', 'MS', 'Concert Band 2023', 'fanding28@isk.ac.ke'),
	(155, 11227, 'Godfrey', 'Tobias', '7', 'amakagodfrey@gmail.com', 'drsamgodfrey@yahoo.co.uk', 'MS', 'Concert Band 2023', 'tgodfrey29@isk.ac.ke'),
	(211, 11570, 'Ahmed', 'Zeeon', '12', 'nahreen.farjana@gmail.com', 'ahmedzu@gmail.com', 'HS', NULL, NULL),
	(204, 27066, 'Haswell', 'Emily', '8', 'ahaswell@isk.ac.ke', 'danhaswell@hotmail.co.uk', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(205, 12444, 'Dalla Vedova Sanjuan', 'Yago', '12', 'felasanjuan13@gmail.com', 'giovanni.dalla-vedova@ericsson.com', 'HS', NULL, NULL),
	(206, 10973, 'Choda', 'Ariana', '10', 'gabriele@sunworldsafaris.com', 'dchoda22@gmail.com', 'HS', NULL, NULL),
	(207, 10974, 'Schmid', 'Isabella', '11', 'aschmid@isk.ac.ke', 'sschmid@isk.ac.ke', 'HS', NULL, NULL),
	(208, 10975, 'Schmid', 'Sophia', '11', 'aschmid@isk.ac.ke', 'sschmid@isk.ac.ke', 'HS', NULL, NULL),
	(209, 13043, 'Ernst', 'Kai', 'K', 'andreaernst@gmail.com', 'ebaimu@gmail.com', 'ES', NULL, NULL),
	(210, 11628, 'Ernst', 'Aika', '3', 'andreaernst@gmail.com', 'ebaimu@gmail.com', 'ES', NULL, NULL),
	(213, 11705, 'Varga', 'Amira', '5', 'hugi.ev@gmail.com', NULL, 'ES', NULL, NULL),
	(214, 12835, 'Veverka', 'Jonah', 'K', 'cveverka@usaid.gov', 'jveverka@usaid.gov', 'ES', NULL, NULL),
	(215, 12838, 'Veverka', 'Theocles', '2', 'cveverka@usaid.gov', 'jveverka@usaid.gov', 'ES', NULL, NULL),
	(216, 12441, 'Sankoh', 'Adam-Angelo', '3', 'ckoroma@unicef.org', 'baimankay.sankoh@wfp.org', 'ES', NULL, NULL),
	(217, 11098, 'Mittelstadt', 'Mwende', '10', 'mmaingi84@gmail.com', 'joel@meridian.co.ke', 'HS', NULL, NULL),
	(218, 20780, 'Charette', 'Miles', '9', 'mdimitracopoulos@isk.ac.ke', 'acharette@isk.ac.ke', 'HS', NULL, NULL),
	(219, 20781, 'Charette', 'Tea', '12', 'mdimitracopoulos@isk.ac.ke', 'acharette@isk.ac.ke', 'HS', NULL, NULL),
	(220, 12963, 'Giblin', 'Drew (Tilly)', '2', 'kloehr@gmail.com', 'drewgiblin@gmail.com', 'ES', NULL, NULL),
	(221, 12964, 'Giblin', 'Auberlin (Addie)', '7', 'kloehr@gmail.com', 'drewgiblin@gmail.com', 'MS', NULL, NULL),
	(222, 11199, 'Burns', 'Ryan', '12', 'sburns@isk.ac.ke', 'Johnburnskenya@gmail.com', 'HS', NULL, NULL),
	(223, 12457, 'Jama', 'Bella', '1', 'katie.elles@gmail.com', 'jama.artan@gmail.com', 'ES', NULL, NULL),
	(224, 12452, 'Jama', 'Ari', '3', 'katie.elles@gmail.com', 'jama.artan@gmail.com', 'ES', NULL, NULL),
	(225, 11572, 'Marriott', 'Isaiah', '12', 'sibilawsonmarriott@gmail.com', 'rkmarriott@gmail.com', 'HS', NULL, NULL),
	(226, 11751, 'Byrne-Ilako', 'Sianna', '11', 'ailish.byrne@crs.org', 'james10s@aol.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(227, 12360, 'Teel', 'Camden', '4', 'destiny1908@hotmail.com', 'bernard1906@hotmail.com', 'ES', NULL, NULL),
	(228, 12361, 'Teel', 'Jaidyn', '6', 'destiny1908@hotmail.com', 'bernard1906@hotmail.com', 'MS', NULL, NULL),
	(230, 12793, 'Eshetu', 'Lukas', '9', 'olga.petryniak@gmail.com', 'kassahun.wossene@gmail.com', 'HS', NULL, NULL),
	(231, 11511, 'Okanda', 'Dylan', '9', 'indiakk@yahoo.com', 'mbauro@gmail.com', 'HS', NULL, NULL),
	(232, 11599, 'Blaschke', 'Sasha', '4', 'cmcmorrison@gmail.com', 'sean.blaschke@gmail.com', 'ES', NULL, NULL),
	(233, 11052, 'Blaschke', 'Kaitlyn', '6', 'cmcmorrison@gmail.com', 'sean.blaschke@gmail.com', 'MS', NULL, NULL),
	(234, 12789, 'Marin Fonseca Choucair Ramos', 'Georges', '3', 'jmarin@ifc.org', 'ychoucair@hotmail.com', 'ES', NULL, NULL),
	(235, 11575, 'Kobayashi', 'Maaya', '5', 'kobayashiyoko8@gmail.com', 'jdasilva66@gmail.com', 'ES', NULL, NULL),
	(236, 11943, 'Hansen Meiro', 'Isabel', '5', 'mmeirolorenzo@gmail.com', 'keithehansen@gmail.com', 'ES', NULL, NULL),
	(237, 11568, 'Eckert-Crosse', 'Finley', '4', 'ekarleckert@gmail.com', 'billycrosse@gmail.com', 'ES', NULL, NULL),
	(238, 10941, 'Bajwa', 'Mohammad Haroon', '8', 'akbarfarzana12@gmail.com', 'mabajwa@unicef.org', 'MS', NULL, NULL),
	(239, 10511, 'Suther', 'Erik', '7', 'ansuther@hotmail.com', 'dansuther@hotmail.com', 'MS', NULL, NULL),
	(240, 11792, 'Chandaria', 'Aarav', '4', 'preenas@gmail.com', 'vijaychandaria@gmail.com', 'ES', NULL, NULL),
	(241, 10338, 'Chandaria', 'Aarini Vijay', '9', 'preenas@gmail.com', 'vijaychandaria@gmail.com', 'HS', NULL, NULL),
	(242, 11526, 'Korvenoja', 'Leo', '11', 'tita.korvenoja@gmail.com', 'korvean@gmail.com', 'HS', NULL, NULL),
	(243, 10881, 'Mathew', 'Mandisa', '12', 'bhattacharjee.parinita@gmail.com', 'aniljmathew@gmail.com', 'HS', NULL, NULL),
	(244, 12158, 'Ahmed', 'Hafsa', '8', 'zahraaden@gmail.com', 'yassinoahmed@gmail.com', 'MS', NULL, NULL),
	(245, 12159, 'Ahmed', 'Mariam', '8', 'zahraaden@gmail.com', 'yassinoahmed@gmail.com', 'MS', NULL, NULL),
	(246, 11745, 'Ahmed', 'Osman', '12', 'zahraaden@gmail.com', 'yassinoahmed@gmail.com', 'HS', NULL, NULL),
	(247, 12116, 'Steel', 'Tessa', '10', 'dianna.kopansky@un.org', 'derek@ramco.co.ke', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(248, 11442, 'Steel', 'Ethan', '12', 'dianna.kopansky@un.org', 'derek@ramco.co.ke', 'HS', NULL, NULL),
	(249, 11271, 'Otieno', 'Brianna', '8', 'maureenagengo@gmail.com', 'jotieno@isk.ac.ke', 'MS', NULL, NULL),
	(250, 13042, 'Bid', 'Sohum', 'K', 'snehalbid@gmail.com', 'rahulbid23@gmail.com', 'ES', NULL, NULL),
	(252, 12173, 'Janmohamed', 'Yara', '4', 'nabila.wissanji@gmail.com', 'gj@jansons.co.za', 'ES', NULL, NULL),
	(253, 12174, 'Janmohamed', 'Aila', '8', 'nabila.wissanji@gmail.com', 'gj@jansons.co.za', 'MS', NULL, NULL),
	(254, 12208, 'Rogers', 'Rwenzori', '4', 'sorogers@usaid.gov', 'drogers@usaid.gov', 'ES', NULL, NULL),
	(255, 12209, 'Rogers', 'Junin', '5', 'sorogers@usaid.gov', 'drogers@usaid.gov', 'ES', NULL, NULL),
	(256, 11879, 'Schoneveld', 'Jasmine', '3', 'nicoliendelange@hotmail.com', 'georgeschoneveld@gmail.com', 'ES', NULL, NULL),
	(257, 11444, 'Kefela', 'Hiyabel', '12', 'mehari.kefela@palmoil.co.ke', 'akberethabtay2@gmail.com', 'HS', NULL, NULL),
	(258, 12416, 'Manji', 'Arra', '4', 'tnathoo@gmail.com', 'allymanji@gmail.com', 'ES', NULL, NULL),
	(259, 12108, 'Shah', 'Deesha', '10', 'hemapiyu@yahoo.com', 'priyesh@eazy-group.com', 'HS', NULL, NULL),
	(260, 10770, 'Rughani', 'Sidh', '9', 'priticrughani@gmail.com', 'cirughani@gmail.com', 'HS', NULL, NULL),
	(261, 12124, 'Chandaria', 'Sohil', '10', 'avni@stjohnslodge.com', 'hc@kincap.com', 'HS', NULL, NULL),
	(262, 12275, 'Patel', 'Imara', '11', 'bindyaracing@hotmail.com', 'patelsatyan@hotmail.com', 'HS', NULL, NULL),
	(263, 11437, 'Wissanji', 'Riyaan', '10', 'rwissanji@gmail.com', 'shaheed.wissanji@sopalodges.com', 'HS', NULL, NULL),
	(264, 11440, 'Wissanji', 'Mikayla', '12', 'rwissanji@gmail.com', 'shaheed.wissanji@sopalodges.com', 'HS', NULL, NULL),
	(265, 12270, 'Bwonya', 'Leti', '12', 'faith.bwonya@gmail.com', NULL, 'HS', NULL, NULL),
	(304, 12286, 'Landolt', 'Stefanie', '6', 'nadia.landolt@yahoo.com', 'jclandolt@icrc.org', 'MS', 'Beginning Band 8 - 2023', 'slandolt30@isk.ac.ke'),
	(251, 11706, 'Bid', 'Arhum', '6', 'snehalbid@gmail.com', 'rahulbid23@gmail.com', 'MS', 'Beginning Band 1 2023', 'abid30@isk.ac.ke'),
	(212, 10696, 'Okwany', 'Hawi', '7', 'bijaflowers@yahoo.com', 'stonekidi@yahoo.com', 'MS', 'Concert Band 2023', 'hokwany29@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(266, 11491, 'Kurauchi', 'Mairi', '3', 'yuko.kurauchi@gmail.com', 'kunal.chandaria@gmail.com', 'ES', NULL, NULL),
	(267, 10932, 'Chandaria', 'Meiya', '5', 'yuko.kurauchi@gmail.com', 'kunal.chandaria@gmail.com', 'ES', NULL, NULL),
	(269, 12531, 'Inwani', 'Aiden', '11', 'cirablue@gmail.com', NULL, 'HS', NULL, NULL),
	(270, 10774, 'Shah', 'Nirvaan', '12', 'bsshah1@gmail.com', 'bhartesh1@gmail.com', 'HS', NULL, NULL),
	(272, 11401, 'Butt', 'Ziya', '9', 'flalani-butt@isk.ac.ke', 'sameer.butt@outlook.com', 'HS', NULL, NULL),
	(273, 11839, 'Shamji', 'Sofia', '8', 'farah@aaagrowers.co.ke', 'ariff@aaagrowers.co.ke', 'MS', NULL, NULL),
	(274, 11472, 'Tall', 'Oumi', '5', 'jgacheke@isk.ac.ke', 'pmtall@gmail.com', 'ES', NULL, NULL),
	(276, 10487, 'Price-Abdi', 'Yasmin', '12', 'Suzyyprice@yahoo.com', 'yusufhas@gmail.com', 'HS', NULL, NULL),
	(277, 11704, 'Fort', 'Kaitlyn', '3', 'kellymaura@gmail.com', 'brycelfort@gmail.com', 'ES', NULL, NULL),
	(279, 10637, 'Raja', 'Keiya', '8', 'nlpwithshilpa@gmail.com', 'neeraj@raja.org.uk', 'MS', NULL, NULL),
	(280, 10955, 'Shah', 'Ryka', '12', 'bshah63@gmail.com', 'pk64shah@gmail.com', 'HS', NULL, NULL),
	(281, 12278, 'Muoki', 'Ruby', '11', 'angelawokabi11@gmail.com', 'jmuoki@outlook.com', 'HS', NULL, NULL),
	(282, 25072, 'Chandaria', 'Siana', '11', 'rupalbid@gmail.com', 'bchandaria@gmail.com', 'HS', NULL, NULL),
	(283, 11877, 'Wangari', 'Tatyana', '12', 'yndungu@gmail.com', NULL, 'HS', NULL, NULL),
	(284, 11190, 'Shah', 'Sohan', '12', 'diyasohan@gmail.com', 'bhavan@cpshoes.com', 'HS', NULL, NULL),
	(285, 10416, 'Nanji', 'Zameer', '9', 'Narmeen_r@yahoo.com', 'zahid@abc-place.com', 'HS', NULL, NULL),
	(286, 11326, 'Paul', 'Esther', '8', 'Megpaul47@icloud.Com', NULL, 'MS', NULL, NULL),
	(287, 10430, 'Sanders', 'Liam', '10', 'angelaferrsan@gmail.com', 'jpsanders32@gmail.com', 'HS', NULL, NULL),
	(288, 10431, 'Sanders', 'Teresa', '12', 'angelaferrsan@gmail.com', 'jpsanders32@gmail.com', 'HS', NULL, NULL),
	(289, 12132, 'Melson', 'Sarah', '9', 'metmel@um.dk', 'clausmelson@gmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(290, 12229, 'Kurji', 'Kaysan Karim', '3', 'shabz.karmali1908@gmail.com', 'shaukatali@primecuts.co.ke', 'ES', NULL, NULL),
	(291, 11768, 'Doshi', 'Ashi', '4', 'adoshi@wave.co.ke', 'vdoshi@wave.co.ke', 'ES', NULL, NULL),
	(292, 10636, 'Doshi', 'Anay', '8', 'adoshi@wave.co.ke', 'vdoshi@wave.co.ke', 'MS', NULL, NULL),
	(293, 12731, 'Bini', 'Bianca', '2', 'boschettiraffaella@gmail.com', 'boschettiraffaella@gmail.com', 'ES', NULL, NULL),
	(294, 11535, 'Cutler', 'Otis', '4', 'megseyjackson@gmail.com', 'adrianhcutler@gmail.com', 'ES', NULL, NULL),
	(296, 10673, 'Cutler', 'Leo', '9', 'megseyjackson@gmail.com', 'adrianhcutler@gmail.com', 'HS', NULL, NULL),
	(297, 20866, 'Wachira', 'Andrew', '10', 'suzielawrence@yahoo.co.uk', 'lawrence.githinji@ke.atlascopco.com', 'HS', NULL, NULL),
	(298, 11884, 'Nzioka', 'Jordan', '2', 'bmusyoka@isk.ac.ke', 'nziokarobert.rn@gmail.com', 'ES', NULL, NULL),
	(299, 11313, 'Nzioka', 'Zuriel', '4', 'bmusyoka@isk.ac.ke', 'nziokarobert.rn@gmail.com', 'ES', NULL, NULL),
	(300, 10865, 'Otieno', 'Radek Tidi', '5', 'alividza@isk.ac.ke', 'eotieno@isk.ac.ke', 'ES', NULL, NULL),
	(301, 10943, 'Otieno', 'Ranam Telu', '5', 'alividza@isk.ac.ke', 'eotieno@isk.ac.ke', 'ES', NULL, NULL),
	(302, 10866, 'Otieno', 'Riani Tunu', '5', 'alividza@isk.ac.ke', 'eotieno@isk.ac.ke', 'ES', NULL, NULL),
	(303, 10715, 'Weaver', 'Sachin', '11', 'rebeccajaneweaver@gmail.com', NULL, 'HS', NULL, NULL),
	(306, 12284, 'Landolt', 'Mark', '8', 'nadia.landolt@yahoo.com', 'jclandolt@icrc.org', 'MS', NULL, NULL),
	(307, 10247, 'Ruiz Stannah', 'Kianu', '7', 'ruizstannah@gmail.com', 'stephen.stannah@un.org', 'MS', NULL, NULL),
	(308, 25032, 'Ruiz Stannah', 'Tamia', '11', 'ruizstannah@gmail.com', 'stephen.stannah@un.org', 'HS', NULL, NULL),
	(309, 11611, 'Noordin', 'Ahmad Eissa', '4', 'iman@thenoordins.com', 'nadeem.noordin@copycatgroup.com', 'ES', NULL, NULL),
	(310, 12194, 'Herman-Roloff', 'Lily', '3', 'amykateherman@hotmail.com', 'khermanroloff@gmail.com', 'ES', NULL, NULL),
	(311, 12195, 'Herman-Roloff', 'Shela', '5', 'amykateherman@hotmail.com', 'khermanroloff@gmail.com', 'ES', NULL, NULL),
	(313, 10800, 'Baheta', 'Bruke', '8', 'Thadera@hotmail.com', 'dbaheta@unicef.org', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(314, 20766, 'Baheta', 'Helina', '11', 'Thadera@hotmail.com', 'dbaheta@unicef.org', 'HS', NULL, NULL),
	(315, 11040, 'Bjornholm', 'Jonathan', '11', 'sbjornholm@me.com', 'ulf.bjornholm@un.org', 'HS', NULL, NULL),
	(316, 11574, 'Vellenga', 'Rose', '4', 'kristenmaddock@hotmail.co.uk', 'Rvellenga@unicef.org', 'ES', NULL, NULL),
	(317, 11573, 'Vellenga', 'Solomon', '5', 'kristenmaddock@hotmail.co.uk', 'Rvellenga@unicef.org', 'ES', NULL, NULL),
	(318, 11255, 'Patel', 'Ishaan', '4', 'priya@ramco.co.ke', 'amit@ramco.co.ke', 'ES', NULL, NULL),
	(319, 11843, 'Clements', 'Ciaran', '8', 'jill.a.clements@gmail.com', 'shanedanielricketts@gmail.com', 'MS', NULL, NULL),
	(320, 12332, 'Nair', 'Ahana', '1', 'pinkilika@gmail.com', 'gautamn@techno-associates.co.ke', 'ES', NULL, NULL),
	(321, 11729, 'Pattni', 'Aryaan', '4', 'azmina@vicbank.com', 'yogesh@vicbank.com', 'ES', NULL, NULL),
	(322, 11200, 'Boxer', 'Hana', '11', 'mboxer@isk.ac.ke', 'bendboxer@hotmail.com', 'HS', NULL, NULL),
	(323, 10993, 'Shah', 'Parth', '10', 'KAUSHISHAH@HOTMAIL.COM', 'KBS.KIFARU@GMAIL.COM', 'HS', NULL, NULL),
	(325, 11263, 'Khubchandani', 'Layla', '9', 'ramji.farzana@gmail.com', 'rishi.khubchandani@gmail.com', 'HS', NULL, NULL),
	(326, 12494, 'Patel', 'Nikhil', '1', 'shruti.bahety@gmail.com', 'akithpatel@gmail.com', 'ES', NULL, NULL),
	(327, 10830, 'Shah', 'Janak', '11', 'nishshah@hotmail.co.uk', 'nipshah@dunhillconsulting.com', 'HS', NULL, NULL),
	(328, 10645, 'Tunbridge', 'Saba', '12', 'louise.tunbridge@gmail.com', NULL, 'HS', NULL, NULL),
	(329, 11777, 'Manek', 'Shriya', '11', 'devika@maneknet.com', 'jay@maneknet.com', 'HS', NULL, NULL),
	(330, 12371, 'Bamlango', 'Diane', 'K', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'ES', NULL, NULL),
	(271, 11402, 'Butt', 'Ayana', '6', 'flalani-butt@isk.ac.ke', 'sameer.butt@outlook.com', 'MS', 'Beginning Band 1 2023', 'abutt30@isk.ac.ke'),
	(278, 11650, 'Fort', 'Connor', '6', 'kellymaura@gmail.com', 'brycelfort@gmail.com', 'MS', 'Beginning Band 7 2023', 'cfort30@isk.ac.ke'),
	(268, 11265, 'Simbiri', 'Ochieng', '6', 'sandra.simbiri@gmail.com', 'davidsimbiri@gmail.com', 'MS', 'Beginning Band 1 2023', 'osimbiri30@isk.ac.ke'),
	(275, 11515, 'Tall', 'Fatuma', '8', 'jgacheke@isk.ac.ke', 'pmtall@gmail.com', 'MS', 'Concert Band 2023', 'ftall28@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(305, 12285, 'Landolt', 'Jana', '8', 'nadia.landolt@yahoo.com', 'jclandolt@icrc.org', 'MS', 'Concert Band 2023', 'jlandolt28@isk.ac.ke'),
	(333, 10979, 'Bamlango', 'Cecile', '11', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'HS', NULL, NULL),
	(334, 20839, 'Patel', 'Vanaaya', '9', 'sunira29@gmail.com', 'umang@vegpro-group.com', 'HS', NULL, NULL),
	(335, 20840, 'Patel', 'Veer', '9', 'sunira29@gmail.com', 'umang@vegpro-group.com', 'HS', NULL, NULL),
	(336, 11502, 'Shah', 'Laina', '4', 'skhamar77@gmail.com', 'sonaars@gmail.com', 'ES', NULL, NULL),
	(337, 10965, 'Shah', 'Savir', '7', 'skhamar77@gmail.com', 'sonaars@gmail.com', 'MS', NULL, NULL),
	(338, 11789, 'Vestergaard', 'Nikolaj', '3', 'psarasas@gmail.com', 'o.vestergaard@gmail.com', 'ES', NULL, NULL),
	(340, 11445, 'Allport', 'Kian', '12', 'shelina@safari-mania.com', 'rallport75@gmail.com', 'HS', NULL, NULL),
	(341, 12094, 'Hagelberg', 'Reid', '9', 'Lisa@virginbushsafaris.com', 'niklas.hagelberg@un.org', 'HS', NULL, NULL),
	(342, 12077, 'Hagelberg', 'Zoe Rose', '11', 'Lisa@virginbushsafaris.com', 'niklas.hagelberg@un.org', 'HS', NULL, NULL),
	(343, 12354, 'Kimmelman-May', 'Juju', '4', 'shannon.k.may@gmail.com', 'jay.kimmelman@gmail.com', 'ES', NULL, NULL),
	(344, 12353, 'Kimmelman-May', 'Chloe', '8', 'shannon.k.may@gmail.com', 'jay.kimmelman@gmail.com', 'MS', NULL, NULL),
	(345, 11452, 'Uberoi', 'Tara', '11', 'alpaub@hotmail.com', 'moby@sivoko.com', 'HS', NULL, NULL),
	(346, 24018, 'Mwenya', 'Chansa', '12', 'mwansachishimba10@yahoo.co.uk', 'kasonde.mwenya@un.org', 'HS', NULL, NULL),
	(347, 11486, 'Patel', 'Liam', '4', 'rajul@ramco.co.ke', 'hasit@ramco.co.ke', 'ES', NULL, NULL),
	(348, 10138, 'Patel', 'Shane', '8', 'rajul@ramco.co.ke', 'hasit@ramco.co.ke', 'MS', NULL, NULL),
	(349, 26025, 'Patel', 'Rhiyana', '10', 'rajul@ramco.co.ke', 'hasit@ramco.co.ke', 'HS', NULL, NULL),
	(350, 10334, 'Pattni', 'Yash', '7', 'poonampatt@gmail.com', 'pulin@anmoljewellers.biz', 'MS', NULL, NULL),
	(351, 11179, 'Samani', 'Gaurav', '5', 'pooja@amsproperties.com', 'rupen@amsgroup.co.ke', 'ES', NULL, NULL),
	(352, 11180, 'Samani', 'Siddharth', '5', 'pooja@amsproperties.com', 'rupen@amsgroup.co.ke', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(353, 10791, 'Bhandari', 'Kiara', '9', 'srbhandari406@gmail.com', 'avnish@intercool.co.ke', 'HS', NULL, NULL),
	(354, 12224, 'Monadjem', 'Safa', '3', 'shekufehk@yahoo.com', 'bmonadjem@gmail.com', 'ES', NULL, NULL),
	(355, 25076, 'Monadjem', 'Malaika', '11', 'shekufehk@yahoo.com', 'bmonadjem@gmail.com', 'HS', NULL, NULL),
	(356, 11858, 'Khagram', 'Sam', '10', 'karen@khagram.org', 'vishal@riftcot.com', 'HS', NULL, NULL),
	(357, 10786, 'Shah', 'Radha', '7', 'reena23sarit@gmail.com', 'sarit.shah@saritcentre.com', 'MS', NULL, NULL),
	(358, 10796, 'Shah', 'Vishnu', '10', 'reena23sarit@gmail.com', 'sarit.shah@saritcentre.com', 'HS', NULL, NULL),
	(360, 12013, 'Khan', 'Cuyuni', '10', 'sheila.aggarwalkhan@gmail.com', 'seanadriankhan@gmail.com', 'HS', NULL, NULL),
	(362, 12131, 'Inglis', 'Lengai', '9', 'lieslkareninglis@gmail.com', NULL, 'HS', NULL, NULL),
	(364, 20875, 'Yohannes', 'Mathias', '10', 'sewit.a@gmail.com', 'biniam.yohannes@gmail.com', 'HS', NULL, NULL),
	(366, 12129, 'Arora', 'Avish', '9', 'kulpreet.vikram@gmail.com', 'aroravikramsingh@gmail.com', 'HS', NULL, NULL),
	(367, 10504, 'Bommadevara', 'Saptha Girish', '10', 'malini.hemamalini@gmail.com', 'bvramana@hotmail.com', 'HS', NULL, NULL),
	(368, 10505, 'Bommadevara', 'Sharmila Devi', '12', 'malini.hemamalini@gmail.com', 'bvramana@hotmail.com', 'HS', NULL, NULL),
	(370, 12309, 'Sangare', 'Adama', '11', 'taissata@yahoo.fr', 'sangnouh@yahoo.fr', 'HS', NULL, NULL),
	(372, 11945, 'Trottier', 'Gabrielle', '9', 'gabydou123@hotmail.com', 'ftrotier@hotmail.com', 'HS', NULL, NULL),
	(373, 11485, 'Suri', 'Mannat', '4', 'shipra.unhabitat@gmail.com', 'suri.raj@gmail.com', 'ES', NULL, NULL),
	(374, 11076, 'Suri', 'Armaan', '7', 'shipra.unhabitat@gmail.com', 'suri.raj@gmail.com', 'MS', NULL, NULL),
	(375, 11101, 'Furness', 'Zoe', '12', 'terrifurness@gmail.com', 'tim@amanzi.ke', 'HS', NULL, NULL),
	(377, 12442, 'Tshomo', 'Tandin', '7', 'sangdema@gmail.com', 'kpenjor@unicef.org', 'MS', NULL, NULL),
	(378, 12394, 'Zangmo', 'Thuji', '8', 'sangdema@gmail.com', 'kpenjor@unicef.org', 'MS', NULL, NULL),
	(379, 10878, 'Berezhny', 'Maxym', '9', 'lubashara078@gmail.com', 'oles@berezhny.net', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(380, 11744, 'Higgins', 'Thomas', '10', 'katehiggins77@yahoo.com', 'kevanphiggins@gmail.com', 'HS', NULL, NULL),
	(381, 11743, 'Higgins', 'Louisa', '12', 'katehiggins77@yahoo.com', 'kevanphiggins@gmail.com', 'HS', NULL, NULL),
	(382, 12244, 'Startup', 'Indhira', '2', 's.mai.rattanavong@gmail.com', 'joshstartup@gmail.com', 'ES', NULL, NULL),
	(383, 11389, 'Lindgren', 'Anyamarie', '8', 'annewendy13@gmail.com', 'jalsweden@gmail.com', 'MS', NULL, NULL),
	(385, 12854, 'Plunkett', 'Takumi', '8', 'makiplunkett@live.jp', 'jplun585@gmail.com', 'MS', NULL, NULL),
	(386, 11556, 'Gagnidze', 'Catherina', '12', 'laramief@yahoo.com', 'LEVGAG@YAHOO.COM', 'HS', NULL, NULL),
	(387, 11676, 'Jama', 'Adam', '2', 'lucky74f@gmail.com', 'hargeisa1000@gmail.com', 'ES', NULL, NULL),
	(388, 11675, 'Jama', 'Amina', '4', 'lucky74f@gmail.com', 'hargeisa1000@gmail.com', 'ES', NULL, NULL),
	(389, 12757, 'Jama', 'Guled', '6', 'lucky74f@gmail.com', 'hargeisa1000@gmail.com', 'MS', NULL, NULL),
	(390, 12211, 'Salituri', 'Noha', '1', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'ES', NULL, NULL),
	(391, 12212, 'Salituri', 'Amaia', '4', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'ES', NULL, NULL),
	(392, 12213, 'Salituri', 'Leone', '4', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'ES', NULL, NULL),
	(393, 12214, 'Thongmod', 'Sorawit (Nico)', '5', 'bakermelissamarie@gmail.com', 'jpsalituri@hotmail.com', 'ES', NULL, NULL),
	(394, 11860, 'Makimei', 'Henk', '12', 'MariaTwerda@redcross.org.uk', 'ig.makimei2014@gmail.com', 'HS', NULL, NULL),
	(359, 11264, 'Shah', 'Anaiya', '6', 'heena1joshi25@yahoo.co.uk', 'jilan21@hotmail.com', 'MS', 'Beginning Band 7 2023', 'ashah30@isk.ac.ke'),
	(371, 11944, 'Trottier', 'Lilyrose', '6', 'gabydou123@hotmail.com', 'ftrotier@hotmail.com', 'MS', 'Beginning Band 7 2023', 'ltrottier30@isk.ac.ke'),
	(361, 12133, 'Inglis', 'Lorian', '6', 'lieslkareninglis@gmail.com', NULL, 'MS', 'Beginning Band 7 2023', 'linglis30@isk.ac.ke'),
	(332, 10978, 'Bamlango', 'Anne', '8', 'leabamlango@gmail.com', 'bamlango@gmail.com', 'MS', 'Concert Band 2023', 'abamlango28@isk.ac.ke'),
	(365, 12130, 'Arora', 'Arjan', '8', 'kulpreet.vikram@gmail.com', 'aroravikramsingh@gmail.com', 'MS', 'Concert Band 2023', 'aarora28@isk.ac.ke>'),
	(363, 10787, 'Yohannes', 'Naomi', '7', 'sewit.a@gmail.com', 'biniam.yohannes@gmail.com', 'MS', 'Concert Band 2023', 'nyohannes29@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(395, 11175, 'Maldonado', 'Mira', '10', 'smaldonado@isk.ac.ke', 'mam27553@yahoo.com', 'HS', NULL, NULL),
	(396, 11170, 'Maldonado', 'Che', '12', 'smaldonado@isk.ac.ke', 'mam27553@yahoo.com', 'HS', NULL, NULL),
	(397, 11261, 'Nguyen', 'Phuong An', '4', 'vietha.sbvhn@gmail.com', 'hnguyen@isk.ac.ke', 'ES', NULL, NULL),
	(399, 12705, 'Smith', 'Charlotte', '4', 'asarahday@gmail.com', 'randysmith@usaid.gov', 'ES', NULL, NULL),
	(400, 12719, 'Von Strauss', 'Olivia', '1', 'malin.vonstrauss@gmail.com', 'adam.ojdahl@gmail.com', 'ES', NULL, NULL),
	(401, 11009, 'Petrangeli', 'Gabriel', '12', 'ivanikolicinkampala@yahoo.com', 'junior.antonio@sobetrainternational.com', 'HS', NULL, NULL),
	(402, 11951, 'Hwang', 'Jihwan', '5', 'choijungh83@gmail.com', 'cs5085.hwang@samsung.com', 'ES', NULL, NULL),
	(403, 12377, 'Hornor', 'Anneka', '10', 'schlesingermaria@gmail.com', 'chris@powerhive.com', 'HS', NULL, NULL),
	(404, 12008, 'Veveiros', 'Florencia', '5', 'julie.veveiros5@gmail.com', 'aveveiros@yahoo.com', 'ES', NULL, NULL),
	(405, 12009, 'Veveiros', 'Xavier', '10', 'julie.veveiros5@gmail.com', 'aveveiros@yahoo.com', 'HS', NULL, NULL),
	(406, 11786, 'Clark', 'Laras', '3', 'agniparamita@gmail.com', 'samueltclark@gmail.com', 'ES', NULL, NULL),
	(407, 11787, 'Clark', 'Galuh', '7', 'agniparamita@gmail.com', 'samueltclark@gmail.com', 'MS', NULL, NULL),
	(408, 12267, 'Schwabel', 'Miriam', '12', 'kschwabel@gmail.com', 'jasones99@gmail.com', 'HS', NULL, NULL),
	(410, 12113, 'Gremley', 'Ben', '10', 'emmagremley@gmail.com', 'andrewgremley@gmail.com', 'HS', NULL, NULL),
	(411, 12115, 'Gremley', 'Calvin', '10', 'emmagremley@gmail.com', 'andrewgremley@gmail.com', 'HS', NULL, NULL),
	(412, 12546, 'Baig-Giannotti', 'Danial', '1', 'giannotti76@yahoo.it', 'khbaig@yahoo.com', 'ES', NULL, NULL),
	(413, 11593, 'Baig-Giannotti', 'Daria', '4', 'giannotti76@yahoo.it', 'khbaig@yahoo.com', 'ES', NULL, NULL),
	(414, 12071, 'Jackson', 'Ciara', '11', 'laurajfrost@gmail.com', 'stephenwjackson@gmail.com', 'HS', NULL, NULL),
	(415, 12806, 'Nelson', 'Ansley', '1', 'kmctamney@gmail.com', 'nelsonex1080@gmail.com', 'ES', NULL, NULL),
	(416, 12803, 'Nelson', 'Caroline', '4', 'kmctamney@gmail.com', 'nelsonex1080@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(417, 12658, 'Wanyoike', 'Tamara', '11', 'lois.wanyoike@gmail.com', 'joe.wanyoike@gmail.com', 'HS', NULL, NULL),
	(418, 12437, 'Cowan', 'Marcella', '8', 'cowseal@aol.com', 'cowanjc@state.gov', 'MS', NULL, NULL),
	(419, 11717, 'Sommerlund', 'Alisia', '7', 'sommerlundsurat@yahoo.com', 'sommerlu@unhcr.org', 'MS', NULL, NULL),
	(420, 12507, 'Castel-Wang', 'Lea', '10', 'weiyangwang88@gmail.com', NULL, 'HS', NULL, NULL),
	(421, 12707, 'Som Chaudhuri', 'Anisha', '4', 'deyshr@gmail.com', 'dchaudhuri@ifc.org', 'ES', NULL, NULL),
	(422, 12067, 'Jacques', 'Gloria', '11', 'deuwba@hotmail.com', 'pageja1@hotmail.com', 'HS', NULL, NULL),
	(423, 11938, 'Nurshaikhova', 'Dana', '9', 'alma.nurshaikhova@gmail.com', NULL, 'HS', NULL, NULL),
	(424, 12161, 'Shah', 'Raheel', '8', 'bhavisha@eazy-group.com', 'neel@eazy-group.com', 'MS', NULL, NULL),
	(425, 20850, 'Shah', 'Rohan', '10', 'bhavisha@eazy-group.com', 'neel@eazy-group.com', 'HS', NULL, NULL),
	(426, 11395, 'Burmester', 'Malou', '5', 'Margs.Burmester@hotmail.com', 'mads.burmester@hotmail.com', 'ES', NULL, NULL),
	(427, 11394, 'Burmester', 'Nicholas', '8', 'Margs.Burmester@hotmail.com', 'mads.burmester@hotmail.com', 'MS', NULL, NULL),
	(429, 11702, 'Sengendo', 'Ethan', '10', 'jusmug@yahoo.com', 'e.sennoga@afdb.org', 'HS', NULL, NULL),
	(430, 12443, 'Osman', 'Omer', '1', 'rwan.adil13@gmail.com', 'hishammsalih@gmail.com', 'ES', NULL, NULL),
	(431, 12238, 'Jensen', 'Felix', '2', 'arietajensen@gmail.com', 'dannje@um.dk', 'ES', NULL, NULL),
	(432, 12237, 'Jensen', 'Fiona', '3', 'arietajensen@gmail.com', 'dannje@um.dk', 'ES', NULL, NULL),
	(433, 11462, 'Gerba', 'Andrew', '7', 'erin.gerba@gmail.com', 'mogerba2@gmail.com', 'MS', NULL, NULL),
	(434, 11507, 'Gerba', 'Madigan', '9', 'erin.gerba@gmail.com', 'mogerba2@gmail.com', 'HS', NULL, NULL),
	(435, 11449, 'Gerba', 'Porter', '11', 'erin.gerba@gmail.com', 'mogerba2@gmail.com', 'HS', NULL, NULL),
	(436, 11800, 'Atamuradov', 'Aaron', '5', 'businka2101@gmail.com', 'atamoura@unhcr.org', 'ES', NULL, NULL),
	(437, 11752, 'Atamuradova', 'Arina', '11', 'businka2101@gmail.com', 'atamoura@unhcr.org', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(438, 12792, 'Yoon', 'Seojun', '7', 'japark1981@naver.com', 'yoonzie@gmail.com', 'MS', NULL, NULL),
	(439, 12791, 'Yoon', 'Seohyeon', '9', 'japark1981@naver.com', 'yoonzie@gmail.com', 'HS', NULL, NULL),
	(440, 11387, 'Allard Ruiz', 'Sasha', '12', 'katiadesouza@sobetrainternational.com', NULL, 'HS', NULL, NULL),
	(441, 12910, 'Alnaqbi', 'Ali', '2', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'ES', NULL, NULL),
	(443, 12908, 'Alnaqbi', 'Almayasa', '7', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'MS', NULL, NULL),
	(444, 12907, 'Alnaqbi', 'Fatima', '9', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'HS', NULL, NULL),
	(445, 12906, 'Alnaqbi', 'Ibrahim', '10', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'HS', NULL, NULL),
	(446, 12396, 'Jabbour', 'Rasmus', '1', 'anna.kontorov@gmail.com', 'jason.jabbour@gmail.com', 'ES', NULL, NULL),
	(447, 12395, 'Jabbour', 'Olivia', '4', 'anna.kontorov@gmail.com', 'jason.jabbour@gmail.com', 'ES', NULL, NULL),
	(448, 12308, 'Allen', 'Tobin', '9', 'beth1421@hotmail.com', 'jeff_allen_1@yahoo.com', 'HS', NULL, NULL),
	(449, 12307, 'Allen', 'Corinne', '12', 'beth1421@hotmail.com', 'jeff_allen_1@yahoo.com', 'HS', NULL, NULL),
	(450, 12643, 'Ben Anat', 'Maya', 'PK', 'benanatim@gmail.com', 'benanatim25@gmail.com', 'ES', NULL, NULL),
	(451, 11475, 'Ben Anat', 'Ella', '5', 'benanatim@gmail.com', 'benanatim25@gmail.com', 'ES', NULL, NULL),
	(452, 11518, 'Ben Anat', 'Shira', '8', 'benanatim@gmail.com', 'benanatim25@gmail.com', 'MS', NULL, NULL),
	(453, 12489, 'Mishra', 'Amishi', '12', 'sumananjali@gmail.com', 'prafulla2001@gmail.com', 'HS', NULL, NULL),
	(454, 12488, 'Mishra', 'Arushi', '12', 'sumananjali@gmail.com', 'prafulla2001@gmail.com', 'HS', NULL, NULL),
	(455, 11488, 'O''neill Calver', 'Riley', '4', 'laraoneill@gmail.com', 'timcalver@gmail.com', 'ES', NULL, NULL),
	(457, 11534, 'Norman', 'Lukas', '10', 'hambrouc@unhcr.org', 'johannorman62@gmail.com', 'HS', NULL, NULL),
	(458, 11533, 'Norman', 'Lise', '12', 'hambrouc@unhcr.org', 'johannorman62@gmail.com', 'HS', NULL, NULL),
	(398, 11260, 'Nguyen', 'Phuc Anh', '6', 'vietha.sbvhn@gmail.com', 'hnguyen@isk.ac.ke', 'MS', 'Beginning Band 1 2023', 'pnguyen30@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(409, 12393, 'Gremley', 'Aiden', '7', 'emmagremley@gmail.com', 'andrewgremley@gmail.com', 'MS', 'Concert Band 2023', 'agremley29@isk.ac.ke'),
	(508, 24043, 'Sims', 'Ella', '12', 'kwest@mac.com', 'oscar.sims@mac.com', 'HS', NULL, NULL),
	(459, 11446, 'Wikenczy Thomsen', 'Sebastian', '11', 'swikenczy@yahoo.com', 'anders_thomsen@yahoo.com', 'HS', NULL, NULL),
	(460, 11758, 'Foley', 'Logan Lilly', '3', 'koech.maureen@gmail.com', 'MPFoley@icloud.com', 'ES', NULL, NULL),
	(461, 12376, 'Mills', 'James', '11', 'staceyinvienna@gmail.com', 'pmills27@yahoo.com', 'HS', NULL, NULL),
	(462, 11820, 'Goold', 'Amira', '5', 'lizagoold@hotmail.co.uk', 'alistairgoold@hotmail.com', 'ES', NULL, NULL),
	(464, 11527, 'Shenge', 'Micaella', '6', 'uangelique@gmail.com', 'kaganzielly@gmail.com', 'MS', NULL, NULL),
	(465, 12338, 'Huber', 'Siri', '5', 'griet.kenis@gmail.com', 'thorsten.huber@giz.de', 'ES', NULL, NULL),
	(466, 12339, 'Huber', 'Lisa', '9', 'griet.kenis@gmail.com', 'thorsten.huber@giz.de', 'HS', NULL, NULL),
	(467, 12340, 'Huber', 'Jara', '10', 'griet.kenis@gmail.com', 'thorsten.huber@giz.de', 'HS', NULL, NULL),
	(468, 12764, 'O''hearn', 'Case', '7', 'ohearnek7@gmail.com', 'ohearn4@msn.com', 'MS', NULL, NULL),
	(469, 12763, 'O''hearn', 'Maeve', '10', 'ohearnek7@gmail.com', 'ohearn4@msn.com', 'HS', NULL, NULL),
	(470, 11375, 'Chigudu', 'Komborero', '5', 'memoshiri@yahoo.co.uk', 'vchigudu@yahoo.co.uk', 'ES', NULL, NULL),
	(471, 11376, 'Chigudu', 'Munashe', '8', 'memoshiri@yahoo.co.uk', 'vchigudu@yahoo.co.uk', 'MS', NULL, NULL),
	(472, 11373, 'Chigudu', 'Nyasha', '11', 'memoshiri@yahoo.co.uk', 'vchigudu@yahoo.co.uk', 'HS', NULL, NULL),
	(473, 12271, 'Sakaedani Petrovic', 'Kodjiro', '11', 'asakaedani@unicef.org', 'opetrovic@unicef.org', 'HS', NULL, NULL),
	(474, 12522, 'Essoungou', 'Ines Clelia', '10', 'maymuchka@yahoo.com', 'essoungou@gmail.com', 'HS', NULL, NULL),
	(475, 12562, 'Mcsharry', 'Caspian', '5', 'emmeline@mcsharry.net', 'patrick@mcsharry.net', 'ES', NULL, NULL),
	(476, 12563, 'Mcsharry', 'Theodore', '9', 'emmeline@mcsharry.net', 'patrick@mcsharry.net', 'HS', NULL, NULL),
	(477, 12073, 'Exel', 'Joshua', '10', 'kexel@usaid.gov', 'jexel@worldbank.org', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(478, 12074, 'Exel', 'Hannah', '12', 'kexel@usaid.gov', 'jexel@worldbank.org', 'HS', NULL, NULL),
	(479, 11569, 'Vutukuru', 'Sumedh Vedya', '12', 'schodavarapu@ifc.org', 'vvutukuru@worldbank.org', 'HS', NULL, NULL),
	(480, 11657, 'Mabaso', 'Nyasha', '5', 'loicemabaso@icloud.com', 'tmabaso@icao.int', 'ES', NULL, NULL),
	(481, 12323, 'Young', 'Jack', '8', 'dyoung1462@gmail.com', 'dianeandjody@yahoo.com', 'MS', NULL, NULL),
	(482, 12378, 'Young', 'Annie', '11', 'dyoung1462@gmail.com', 'dianeandjody@yahoo.com', 'HS', NULL, NULL),
	(483, 11892, 'Peck', 'Sofia', '12', 'andrea.m.peck@gmail.com', 'robert.b.peck@gmail.com', 'HS', NULL, NULL),
	(485, 12062, 'O''hara', 'Elia', '11', 'siemerm@hotmail.com', 'corykohara@gmail.com', 'HS', NULL, NULL),
	(486, 12200, 'Friedman', 'Becca', '5', 'jennysansfer@yahoo.com', NULL, 'ES', NULL, NULL),
	(487, 11700, 'Murape', 'Nandipha', '11', 'tmurape@unicef.org', 'lloydmurape@gmail.com', 'HS', NULL, NULL),
	(488, 11630, 'Van Der Vliet', 'Sarah', '7', 'lauretavdva@gmail.com', 'janisvliet@gmail.com', 'MS', NULL, NULL),
	(489, 11629, 'Van Der Vliet', 'Grecy', '12', 'lauretavdva@gmail.com', 'janisvliet@gmail.com', 'HS', NULL, NULL),
	(490, 12421, 'Giri', 'Maila', '3', 'lisebendiksen@gmail.com', 'rgiri@unicef.org', 'ES', NULL, NULL),
	(491, 12410, 'Giri', 'Rohan', '10', 'lisebendiksen@gmail.com', 'rgiri@unicef.org', 'HS', NULL, NULL),
	(492, 13041, 'Kasahara', 'Ao', 'K', 'miho.a.yonekura@gmail.com', 'aito.kasahara@sumitomocorp.com', 'ES', NULL, NULL),
	(493, 12250, 'Laurits', 'Leonard', '1', 'emily.laurits@gmail.com', 'eric.laurits@gmail.com', 'ES', NULL, NULL),
	(494, 12249, 'Laurits', 'Charlotte', '3', 'emily.laurits@gmail.com', 'eric.laurits@gmail.com', 'ES', NULL, NULL),
	(495, 11761, 'Jansson', 'Kai', '3', 'sawanakagawa@gmail.com', 'torjansson@gmail.com', 'ES', NULL, NULL),
	(497, 12363, 'Hansen', 'Ines Elise', '2', 'metteojensen@gmail.com', 'thomasnikolaj@hotmail.com', 'ES', NULL, NULL),
	(498, 12365, 'Hansen', 'Marius', '6', 'metteojensen@gmail.com', 'thomasnikolaj@hotmail.com', 'MS', NULL, NULL),
	(499, 11145, 'Choi', 'Minseo', '4', 'shy_cool@naver.com', 'flymax2002@hotmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(501, 12637, 'Tassew', 'Abigail', '3', 'faithmekuria24@gmail.com', 'tassew@gmail.com', 'ES', NULL, NULL),
	(502, 12636, 'Tassew', 'Nathan', '10', 'faithmekuria24@gmail.com', 'tassew@gmail.com', 'HS', NULL, NULL),
	(503, 12867, 'Johnson', 'Catherine', '1', 'bobbiejohnsonbjj@gmail.com', 'donovanshanej@gmail.com', 'ES', NULL, NULL),
	(504, 12866, 'Johnson', 'Brycelyn', '6', 'bobbiejohnsonbjj@gmail.com', 'donovanshanej@gmail.com', 'MS', NULL, NULL),
	(505, 12865, 'Johnson', 'Azzalina', '10', 'bobbiejohnsonbjj@gmail.com', 'donovanshanej@gmail.com', 'HS', NULL, NULL),
	(506, 12103, 'Raja', 'Aaditya', '10', 'darshanaraja@aol.com', 'praja42794@aol.com', 'HS', NULL, NULL),
	(509, 20843, 'Priestley', 'Leila', '11', 'samela.priestley@gmail.com', 'mark.priestley@trademarkea.com', 'HS', NULL, NULL),
	(510, 25038, 'Piper', 'Saron', '11', 'piperlilly@gmail.com', 'piperben@gmail.com', 'HS', NULL, NULL),
	(511, 12574, 'Mazibuko', 'Maxwell', '10', 'mazibukos@yahoo.com', NULL, 'HS', NULL, NULL),
	(512, 12573, 'Mazibuko', 'Naledi', '10', 'mazibukos@yahoo.com', NULL, 'HS', NULL, NULL),
	(513, 12575, 'Mazibuko', 'Sechaba', '10', 'mazibukos@yahoo.com', NULL, 'HS', NULL, NULL),
	(514, 12257, 'Raval', 'Ananya', '1', 'prakrutidevang@icloud.com', 'devang.raval1990@gmail.com', 'ES', NULL, NULL),
	(515, 10333, 'Donohue', 'Christopher Ross', '7', 'adriennedonohue@gmail.com', 'crdonohue@gmail.com', 'MS', NULL, NULL),
	(516, 12111, 'Cooney', 'Luna', '3', 'mireillefc@gmail.com', 'danielcooney@gmail.com', 'ES', NULL, NULL),
	(517, 12110, 'Cooney', 'Maïa', '10', 'mireillefc@gmail.com', 'danielcooney@gmail.com', 'HS', NULL, NULL),
	(519, 12154, 'Materne', 'Danaé', '9', 'nat.dekeyser@gmail.com', 'fredmaterne@hotmail.com', 'HS', NULL, NULL),
	(520, 10495, 'Dale', 'Ameya', '11', 'gdale@isk.ac.ke', 'jdale@isk.ac.ke', 'HS', NULL, NULL),
	(521, 11232, 'Hire', 'Arthur', '4', 'jhire@isk.ac.ke', 'bhire@isk.ac.ke', 'ES', NULL, NULL),
	(618, 12342, 'O''bra', 'Kai', '6', 'hbobra@gmail.com', 'bcobra@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'kobra30@isk.ac.ke'),
	(484, 12063, 'O''hara', 'Luke', '6', 'siemerm@hotmail.com', 'corykohara@gmail.com', 'MS', 'Beginning Band 7 2023', 'lohara30@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(507, 10657, 'Mehta', 'Ansh', '7', 'mehtakrishnay@gmail.com', 'ymehta@cevaltd.com', 'MS', 'Concert Band 2023', 'amehta29@isk.ac.ke'),
	(463, 11836, 'Goold', 'Isla', '8', 'lizagoold@hotmail.co.uk', 'alistairgoold@hotmail.com', 'MS', 'Concert Band 2023', 'igoold28@isk.ac.ke'),
	(523, 10676, 'Sekar', 'Akshith', '10', 'rsekar1999@yahoo.com', 'rekhasekar@yahoo.co.in', 'HS', NULL, NULL),
	(524, 11464, 'Lloyd', 'Elsa', '7', 'apaolo@isk.ac.ke', 'bobcoulibaly@yahoo.com', 'MS', NULL, NULL),
	(525, 12191, 'Firzé Al Ghaoui', 'Laé', '5', 'agnaima@gmail.com', 'olivierfirze@gmail.com', 'ES', NULL, NULL),
	(527, 11461, 'Quacquarella', 'Alessia', '5', 'lisa_limahken@yahoo.com', 'q_gioik@hotmail.com', 'ES', NULL, NULL),
	(528, 12268, 'Ledgard', 'Hamish', '12', 'marta_ledgard@mzv.cz', 'eternaut@icloud.com', 'HS', NULL, NULL),
	(529, 12742, 'Shahbal', 'Sophia', 'K', 'kaitlin.hillis@gmail.com', 'saud.shahbal@gmail.com', 'ES', NULL, NULL),
	(530, 12712, 'Shahbal', 'Saif', '2', 'kaitlin.hillis@gmail.com', 'saud.shahbal@gmail.com', 'ES', NULL, NULL),
	(531, 11854, 'Rwehumbiza', 'Jonathan', '10', 'abakilana@worldbank.org', 'abakilana@worldbank.org', 'HS', NULL, NULL),
	(532, 11897, 'Eidex', 'Simone', '11', 'waterlily6970@gmail.com', NULL, 'HS', NULL, NULL),
	(533, 11484, 'Schenck', 'Alston', '4', 'prillakrone@gmail.com', 'schenck.mills@bcg.com', 'ES', NULL, NULL),
	(535, 12306, 'Hopps', 'Troy', '3', 'rharrison90@gmail.com', 'jasonhopps@gmail.com', 'ES', NULL, NULL),
	(536, 10477, 'Hughes', 'Noah', '11', 'ahughes@isk.ac.ke', 'ethiopiashaun@gmail.com', 'HS', NULL, NULL),
	(537, 12303, 'Njenga', 'Maximus', '2', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'ES', NULL, NULL),
	(538, 12279, 'Njenga', 'Sadie', '5', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'ES', NULL, NULL),
	(540, 12281, 'Njenga', 'Justin', '10', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'HS', NULL, NULL),
	(544, 11898, 'Jensen', 'Daniel', '10', 'amag32@gmail.com', 'jonathon.jensen@gmail.com', 'HS', NULL, NULL),
	(545, 12357, 'Thibodeau', 'Maya', '8', 'gerry@grayemail.com', 'ace@thibodeau.com', 'MS', NULL, NULL),
	(546, 11552, 'De Vries Aguirre', 'Lorenzo', '9', 'pangolinaty@yahoo.com', 'mmgoez1989@gmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(547, 11551, 'De Vries Aguirre', 'Marco', '12', 'pangolinaty@yahoo.com', 'mmgoez1989@gmail.com', 'HS', NULL, NULL),
	(548, 12620, 'Saleem', 'Adam', '2', 'anna.saleem.hogberg@gov.se', 'saleembaha@gmail.com', 'ES', NULL, NULL),
	(550, 11605, 'Abdellahi', 'Emir', '11', 'knwazota@ifc.org', NULL, 'HS', NULL, NULL),
	(551, 11912, 'O''neal', 'Maliah', '8', 'onealp1@yahoo.com', 'onealap@state.gov', 'MS', NULL, NULL),
	(552, 11906, 'Kraemer', 'Caio', '9', 'leticiarc73@gmail.com', 'eduardovk03@gmail.com', 'HS', NULL, NULL),
	(553, 11907, 'Kraemer', 'Isabela', '12', 'leticiarc73@gmail.com', 'eduardovk03@gmail.com', 'HS', NULL, NULL),
	(554, 11780, 'Bannikau', 'Eva', '4', 'lenusia@hotmail.com', 'elena.sahlin@gov.se', 'ES', NULL, NULL),
	(555, 12291, 'Prawitz', 'Alba', '2', 'camillaprawitz@gmail.com', 'peter.nilsson@scb.se', 'ES', NULL, NULL),
	(556, 12298, 'Prawitz', 'Max', '5', 'camillaprawitz@gmail.com', 'peter.nilsson@scb.se', 'ES', NULL, NULL),
	(557, 12297, 'Prawitz', 'Leo', '6', 'camillaprawitz@gmail.com', 'peter.nilsson@scb.se', 'MS', NULL, NULL),
	(558, 12060, 'Holder', 'Abigail', '5', 'nickandstephholder@gmail.com', 'stephiemiddleton@hotmail.com', 'ES', NULL, NULL),
	(559, 12059, 'Holder', 'Charles', '11', 'nickandstephholder@gmail.com', 'stephiemiddleton@hotmail.com', 'HS', NULL, NULL),
	(560, 12056, 'Holder', 'Isabel', '12', 'nickandstephholder@gmail.com', 'stephiemiddleton@hotmail.com', 'HS', NULL, NULL),
	(561, 12656, 'Ansorg', 'Sebastian', '7', 'katy.agg@gmail.com', 'tansorg@gmail.com', 'MS', NULL, NULL),
	(562, 12655, 'Ansorg', 'Leon', '11', 'katy.agg@gmail.com', 'tansorg@gmail.com', 'HS', NULL, NULL),
	(563, 12217, 'Bosch', 'Pilar', 'K', 'jasmin.gohl@gmail.com', 'luis.bosch@outlook.com', 'ES', NULL, NULL),
	(564, 12218, 'Bosch', 'Moira', '2', 'jasmin.gohl@gmail.com', 'luis.bosch@outlook.com', 'ES', NULL, NULL),
	(565, 12219, 'Bosch', 'Blanca', '4', 'jasmin.gohl@gmail.com', 'luis.bosch@outlook.com', 'ES', NULL, NULL),
	(566, 11678, 'Ross', 'Aven', '7', 'skeddington@yahoo.com', 'sross78665@gmail.com', 'MS', NULL, NULL),
	(568, 12231, 'Herbst', 'Kai', '2', 'magdaa002@hotmail.com', 'torstenherbst@hotmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(569, 12230, 'Herbst', 'Sofia', '4', 'magdaa002@hotmail.com', 'torstenherbst@hotmail.com', 'ES', NULL, NULL),
	(570, 12179, 'Bierly', 'Michael', '8', 'abierly02@gmail.com', 'BierlyJE@state.gov', 'MS', NULL, NULL),
	(571, 11802, 'Stephens', 'Miya', '5', 'mwatanabe1@worldbank.org', 'mstephens@worldbank.org', 'ES', NULL, NULL),
	(573, 11686, 'Joo', 'Jihong', '10', 'ruvigirl@icloud.com', 'jeongje.joo@gmail.com', 'HS', NULL, NULL),
	(574, 11685, 'Joo', 'Hyojin', '12', 'ruvigirl@icloud.com', 'jeongje.joo@gmail.com', 'HS', NULL, NULL),
	(575, 12358, 'Sottsas', 'Bruno', '4', 'sinxayvoravong@hotmail.com', 'ssottsas@worldbank.org', 'ES', NULL, NULL),
	(576, 12359, 'Sottsas', 'Natasha', '7', 'sinxayvoravong@hotmail.com', 'ssottsas@worldbank.org', 'MS', NULL, NULL),
	(577, 12525, 'Gandhi', 'Krishna', '10', 'gayatri.gandhi0212@gmail.com', 'gandhi.harish@gmail.com', 'HS', NULL, NULL),
	(578, 12524, 'Gandhi', 'Hrushikesh', '12', 'gayatri.gandhi0212@gmail.com', 'gandhi.harish@gmail.com', 'HS', NULL, NULL),
	(579, 12490, 'Leon', 'Max', '12', 'andrealeon@gmx.de', 'm.d.lance007@gmail.com', 'HS', NULL, NULL),
	(580, 12775, 'Korngold', 'Myra', '5', 'yenyen321@gmail.com', 'korngold.caleb@gmail.com', 'ES', NULL, NULL),
	(581, 12773, 'Korngold', 'Mila Ruth', '7', 'yenyen321@gmail.com', 'korngold.caleb@gmail.com', 'MS', NULL, NULL),
	(582, 12223, 'Tarquini', 'Alexander', '4', 'caroline.bird@wfp.org', 'drmarcellotarquini@gmail.com', 'ES', NULL, NULL),
	(583, 10602, 'Abukari', 'Marian', '7', 'moprissy@gmail.com', 'm.abukari@ME.com', 'MS', NULL, NULL),
	(584, 10672, 'Abukari', 'Manuela', '9', 'moprissy@gmail.com', 'm.abukari@ME.com', 'HS', NULL, NULL),
	(585, 12470, 'Mansourian', 'Soren', '1', 'braedenr@gmail.com', 'hani.mansourian@gmail.com', 'ES', NULL, NULL),
	(586, 12081, 'Caminha', 'Zecarun', '6', 'sunita1214@gmail.com', 'zesopolcaminha@gmail.com', 'MS', 'Beginning Band 1 2023', 'zcaminha30@isk.ac.ke'),
	(541, 10566, 'Zucca', 'Fatima', '6', 'mariacristina.zucca@gmail.com', NULL, 'MS', 'Beginning Band 8 - 2023', 'fazucca30@isk.ac.ke'),
	(539, 12280, 'Njenga', 'Grace', '7', 'stephanienjenga@gmail.com', 'njengaj@state.gov', 'MS', 'Concert Band 2023', 'gnjenga29@isk.ac.ke'),
	(526, 12190, 'Firzé Al Ghaoui', 'Natéa', '7', 'agnaima@gmail.com', 'olivierfirze@gmail.com', 'MS', 'Concert Band 2023', 'nfirzealghaoui29@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(587, 12079, 'Caminha', 'Manali', '9', 'sunita1214@gmail.com', 'zesopolcaminha@gmail.com', 'HS', NULL, NULL),
	(589, 12894, 'Leca Turner', 'Nomi', 'PK', 'lecalaurianne@yahoo.co.uk', 'ejamturner@yahoo.com', 'ES', NULL, NULL),
	(590, 12893, 'Leca Turner', 'Enzo', '1', 'lecalaurianne@yahoo.co.uk', 'ejamturner@yahoo.com', 'ES', NULL, NULL),
	(591, 12162, 'Karuga', 'Kelsie', '6', 'irene.karuga2@gmail.com', 'karugafamily@gmail.com', 'MS', NULL, NULL),
	(592, 12163, 'Karuga', 'Kayla', '8', 'irene.karuga2@gmail.com', 'karugafamily@gmail.com', 'MS', NULL, NULL),
	(593, 12897, 'Jones-Avni', 'Tamar', 'K', 'erinjonesavni@gmail.com', 'danielgavni@gmail.com', 'ES', NULL, NULL),
	(594, 12784, 'Jones-Avni', 'Dov', '2', 'erinjonesavni@gmail.com', 'danielgavni@gmail.com', 'ES', NULL, NULL),
	(595, 12783, 'Jones-Avni', 'Nahal', '4', 'erinjonesavni@gmail.com', 'danielgavni@gmail.com', 'ES', NULL, NULL),
	(596, 12504, 'Godden', 'Noa', '5', 'martinettegodden@gmail.com', 'kieranrgodden@gmail.com', 'ES', NULL, NULL),
	(597, 12479, 'Godden', 'Emma', '9', 'martinettegodden@gmail.com', 'kieranrgodden@gmail.com', 'HS', NULL, NULL),
	(598, 12478, 'Godden', 'Lisa', '10', 'martinettegodden@gmail.com', 'kieranrgodden@gmail.com', 'HS', NULL, NULL),
	(599, 12882, 'Acharya', 'Ella', '1', 'isk@kuttaemail.com', 'thaipeppers2020@gmail.com', 'ES', NULL, NULL),
	(600, 12881, 'Acharya', 'Anshi', '7', 'isk@kuttaemail.com', 'thaipeppers2020@gmail.com', 'MS', NULL, NULL),
	(601, 12722, 'Hardy', 'Clara', '1', 'rlbeckster@yahoo.com', 'jamesphardy211@gmail.com', 'ES', NULL, NULL),
	(602, 11958, 'Dara', 'Safari', '4', 'yndege@gmail.com', 'dara_andrew@yahoo.com', 'ES', NULL, NULL),
	(603, 12305, 'Koucheravy', 'Moira', '4', 'grace.koucheravy@gmail.com', 'patrick.e.koucheravy@gmail.com', 'ES', NULL, NULL),
	(604, 12304, 'Koucheravy', 'Carys', '8', 'grace.koucheravy@gmail.com', 'patrick.e.koucheravy@gmail.com', 'MS', NULL, NULL),
	(605, 12258, 'Germain', 'Edouard', '11', 'mel_laroche1@hotmail.com', 'alexgermain69@hotmail.com', 'HS', NULL, NULL),
	(606, 12259, 'Germain', 'Jacob', '11', 'mel_laroche1@hotmail.com', 'alexgermain69@hotmail.com', 'HS', NULL, NULL),
	(607, 12293, 'Aung', 'Lynn Htet', '5', 'lwint@unhcr.org', 'lwinkyawkyaw@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(608, 12302, 'Thu', 'Phyo Nyein Nyein', '7', 'lwint@unhcr.org', 'lwinkyawkyaw@gmail.com', 'MS', NULL, NULL),
	(610, 10119, 'Patel', 'Ronan', '8', 'vbeiner@isk.ac.ke', 'nilesh140@hotmail.com', 'MS', NULL, NULL),
	(611, 10746, 'Asamoah', 'Annabel', '11', 'msuya.eunice1@gmail.com', 'Samuelasamoah4321@gmail.com', 'HS', NULL, NULL),
	(612, 12085, 'Duwyn', 'Teo', '5', 'angeladuwyn@gmail.com', 'dduwyn@gmail.com', 'ES', NULL, NULL),
	(613, 12086, 'Duwyn', 'Mia', '9', 'angeladuwyn@gmail.com', 'dduwyn@gmail.com', 'HS', NULL, NULL),
	(614, 12028, 'Van Bommel', 'Cato', '11', 'jorismarij@hotmail.com', 'joris-van.bommel@minbuza.nl', 'HS', NULL, NULL),
	(615, 12698, 'Raehalme', 'Henrik', '1', 'johanna.raehalme@gmail.com', 'raehalme@gmail.com', 'ES', NULL, NULL),
	(616, 12697, 'Raehalme', 'Emilia', '5', 'johanna.raehalme@gmail.com', 'raehalme@gmail.com', 'ES', NULL, NULL),
	(619, 12341, 'O''bra', 'Asara', '9', 'hbobra@gmail.com', 'bcobra@gmail.com', 'HS', NULL, NULL),
	(620, 12449, 'Lee', 'Seonu', '3', 'eduinun@gmail.com', 'stuff0521@gmail.com', 'ES', NULL, NULL),
	(621, 10953, 'Davis', 'Maya', '12', 'jdavis@isk.ac.ke', 'matt.davis@crs.org', 'HS', NULL, NULL),
	(623, 12050, 'Bruhwiler', 'Anika', '12', 'bruehome@gmail.com', 'mbruhwiler@ifc.org', 'HS', NULL, NULL),
	(624, 12678, 'Jovanovic', 'Mila', '5', 'jjovanovic@unicef.org', 'milansgml@gmail.com', 'ES', NULL, NULL),
	(625, 12677, 'Jovanovic', 'Dunja', '8', 'jjovanovic@unicef.org', 'milansgml@gmail.com', 'MS', NULL, NULL),
	(626, 12740, 'Walji', 'Elise', '2', 'marlouswergerwalji@gmail.com', 'shafranw@gmail.com', 'ES', NULL, NULL),
	(627, 12739, 'Walji', 'Felyne', '3', 'marlouswergerwalji@gmail.com', 'shafranw@gmail.com', 'ES', NULL, NULL),
	(628, 12765, 'Jacob', 'Dechen', '7', 'namgya@gmail.com', 'vinodkjacobpminy@gmail.com', 'MS', NULL, NULL),
	(629, 12766, 'Jacob', 'Tenzin', '11', 'namgya@gmail.com', 'vinodkjacobpminy@gmail.com', 'HS', NULL, NULL),
	(630, 12324, 'Touré', 'Fatoumata', '4', 'adja_samb@yahoo.fr', 'cheikhtoure@hotmail.com', 'ES', NULL, NULL),
	(631, 12325, 'Touré', 'Ousmane', '5', 'adja_samb@yahoo.fr', 'cheikhtoure@hotmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(632, 12642, 'Khayat De Andrade', 'Helena', 'PK', 'nathaliakhayat@gmail.com', 'orestejunior@gmail.com', 'ES', NULL, NULL),
	(633, 12650, 'Khayat De Andrade', 'Sophia', '1', 'nathaliakhayat@gmail.com', 'orestejunior@gmail.com', 'ES', NULL, NULL),
	(634, 12762, 'Nitcheu', 'Maelle', 'PK', 'lilimakole@yahoo.fr', 'georges.nitcheu@gmail.com', 'ES', NULL, NULL),
	(635, 12415, 'Nitcheu', 'Margot', '2', 'lilimakole@yahoo.fr', 'georges.nitcheu@gmail.com', 'ES', NULL, NULL),
	(636, 12417, 'Nitcheu', 'Marion', '3', 'lilimakole@yahoo.fr', 'georges.nitcheu@gmail.com', 'ES', NULL, NULL),
	(637, 11939, 'Fernstrom', 'Eva', '5', 'anushika00@hotmail.com', 'erik_fernstrom@yahoo.se', 'ES', NULL, NULL),
	(638, 12831, 'Barragan Sofrony', 'Sienna', 'K', 'angelica.sofrony@gmail.com', 'barraganc@un.org', 'ES', NULL, NULL),
	(639, 12711, 'Barragan Sofrony', 'Gael', '3', 'angelica.sofrony@gmail.com', 'barraganc@un.org', 'ES', NULL, NULL),
	(641, 11837, 'Jansen', 'William', '8', 'sjansen@usaid.gov', 'tmjjansen@hotmail.com', 'MS', NULL, NULL),
	(642, 11855, 'Jansen', 'Matias', '10', 'sjansen@usaid.gov', 'tmjjansen@hotmail.com', 'HS', NULL, NULL),
	(643, 12827, 'Maagaard', 'Siri', '4', 'pil_larsen@hotmail.com', 'chmaagaard@live.dk', 'ES', NULL, NULL),
	(644, 12826, 'Maagaard', 'Laerke', '9', 'pil_larsen@hotmail.com', 'chmaagaard@live.dk', 'HS', NULL, NULL),
	(645, 12647, 'Jin', 'Chae Hyun', 'PK', 'h.lee2@afdb.org', 'jinseungsoo@gmail.com', 'ES', NULL, NULL),
	(646, 12246, 'Jin', 'A-Hyun', '2', 'h.lee2@afdb.org', 'jinseungsoo@gmail.com', 'ES', NULL, NULL),
	(647, 11329, 'Fundaro', 'Pietro', '10', 'bethroca9@gmail.com', 'funroc@gmail.com', 'HS', NULL, NULL),
	(648, 11847, 'Onderi', 'Jade', '9', 'ligamic@gmail.com', 'nathan.mabeya@gmail.com', 'HS', NULL, NULL),
	(649, 11810, 'Kimatrai', 'Nikhil', '9', 'aditikimatrai@gmail.com', 'ranjeevkimatrai@gmail.com', 'HS', NULL, NULL),
	(650, 11809, 'Kimatrai', 'Rhea', '9', 'aditikimatrai@gmail.com', 'ranjeevkimatrai@gmail.com', 'HS', NULL, NULL),
	(651, 10313, 'Ireri', 'Kennedy', '9', 'mwebi@unhcr.org', NULL, 'HS', NULL, NULL),
	(609, 10561, 'Patel', 'Olivia', '6', 'vbeiner@isk.ac.ke', 'nilesh140@hotmail.com', 'MS', 'Beginning Band 1 2023', 'opatel30@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(617, 11822, 'Friedhoff Jaeschke', 'Naia', '7', 'heike_friedhoff@hotmail.com', 'thomas.jaeschke.e@outlook.com', 'MS', 'Concert Band 2023', 'nfriedhoffjaeschke29@isk.ac.ke'),
	(745, 12830, 'Abshir', 'Kaynan', 'K', 'nada.abshir@gmail.com', NULL, 'ES', NULL, NULL),
	(652, 11335, 'Taneem', 'Farzin', '7', 'mahfuhai@gmail.com', 'taneem.a@gmail.com', 'MS', NULL, NULL),
	(653, 11336, 'Taneem', 'Umaiza', '8', 'mahfuhai@gmail.com', 'taneem.a@gmail.com', 'MS', NULL, NULL),
	(654, 12808, 'Mothobi', 'Oagile', '1', 'shielamothobi@gmail.com', 'imothobi@gmail.com', 'ES', NULL, NULL),
	(655, 12807, 'Mothobi', 'Resegofetse', '4', 'shielamothobi@gmail.com', 'imothobi@gmail.com', 'ES', NULL, NULL),
	(657, 12429, 'Wittmann', 'Soline', '10', 'benedicte.wittmann@yahoo.fr', 'christophewittmann@yahoo.fr', 'HS', NULL, NULL),
	(658, 12704, 'Muziramakenga', 'Mateo', '1', 'kristina.leuchowius@gmail.com', 'lionel.muzira@gmail.com', 'ES', NULL, NULL),
	(659, 12703, 'Muziramakenga', 'Aiden', '4', 'kristina.leuchowius@gmail.com', 'lionel.muzira@gmail.com', 'ES', NULL, NULL),
	(660, 12602, 'Carver Wildig', 'Charlie', '5', 'zoe.wildig@gmail.com', 'freddie.carver@gmail.com', 'ES', NULL, NULL),
	(661, 12601, 'Carver Wildig', 'Barney', '7', 'zoe.wildig@gmail.com', 'freddie.carver@gmail.com', 'MS', NULL, NULL),
	(662, 12787, 'Park', 'Jijoon', '2', 'hypakuo@gmail.com', 'joonwoo.park@undp.org', 'ES', NULL, NULL),
	(663, 12786, 'Park', 'Jooan', '4', 'hypakuo@gmail.com', 'joonwoo.park@undp.org', 'ES', NULL, NULL),
	(664, 12745, 'Hercberg', 'Zohar', 'PK', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'ES', NULL, NULL),
	(665, 12680, 'Hercberg', 'Amitai', '3', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'ES', NULL, NULL),
	(667, 12682, 'Hercberg', 'Uriya', '7', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'MS', NULL, NULL),
	(668, 12776, 'Carter', 'Rafael', '8', 'ksvensson@worldbank.org', 'miguelcarter.4@gmail.com', 'MS', NULL, NULL),
	(670, 12242, 'Arora', 'Vihaan', '2', 'miss.sikka@gmail.com', 'yash2201@gmail.com', 'ES', NULL, NULL),
	(671, 12990, 'Crandall', 'Sofia', '12', 'mariama1@mac.com', 'mail@billcrandall.com', 'HS', NULL, NULL),
	(672, 13061, 'Ihsan', 'Almaira', '5', 'tyuwono@worldbank.org', 'aihsan@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(673, 13060, 'Ihsan', 'Rayyan', '7', 'tyuwono@worldbank.org', 'aihsan@gmail.com', 'MS', NULL, NULL),
	(674, 13063, 'Ihsan', 'Zakhrafi', '11', 'tyuwono@worldbank.org', 'aihsan@gmail.com', 'HS', NULL, NULL),
	(675, 12579, 'Thomas', 'Alexander', '11', 'claire@go-two-one.net', 'sunfish62@gmail.com', 'HS', NULL, NULL),
	(677, 12921, 'Dove', 'Ruth', '9', 'meganlpdove@gmail.com', 'stephencarterdove@gmail.com', 'HS', NULL, NULL),
	(678, 12920, 'Dove', 'Samuel', '11', 'meganlpdove@gmail.com', 'stephencarterdove@gmail.com', 'HS', NULL, NULL),
	(679, 12588, 'Ngumi', 'Alvin', '11', 'rsituma@yahoo.com', NULL, 'HS', NULL, NULL),
	(680, 13100, 'Handler', 'Julia', '6', 'lholley@gmail.com', 'nhandler@gmail.com', 'MS', NULL, NULL),
	(681, 12592, 'Maguire', 'Josephine', '8', 'carybmaguire@gmail.com', 'spencer.maguire@gmail.com', 'MS', NULL, NULL),
	(682, 12593, 'Maguire', 'Theodore', '10', 'carybmaguire@gmail.com', 'spencer.maguire@gmail.com', 'HS', NULL, NULL),
	(683, 13027, 'Kasymbekova Tauras', 'Deniza', '5', 'aisuluukasymbekova@yahoo.com', 'ttauras@gmail.com', 'ES', NULL, NULL),
	(684, 12669, 'Assefa', 'Amman', '8', 'selamh27@yahoo.com', 'Assefaft@Gmail.com', 'MS', NULL, NULL),
	(685, 12822, 'Maasdorp Mogollon', 'Lucas', '1', 'inamogollon@gmail.com', 'maasdorp@gmail.com', 'ES', NULL, NULL),
	(686, 12821, 'Maasdorp Mogollon', 'Gabriela', '4', 'inamogollon@gmail.com', 'maasdorp@gmail.com', 'ES', NULL, NULL),
	(687, 13064, 'Daines', 'Dallin', '2', 'foreverdaines143@gmail.com', 'dainesy@gmail.com', 'ES', NULL, NULL),
	(688, 13084, 'Daines', 'Caleb', '4', 'foreverdaines143@gmail.com', 'dainesy@gmail.com', 'ES', NULL, NULL),
	(690, 12833, 'Mccown', 'Gabriel', 'K', 'nickigreenlee@gmail.com', 'andrew.mccown@gmail.com', 'ES', NULL, NULL),
	(691, 12837, 'Mccown', 'Clea', '2', 'nickigreenlee@gmail.com', 'andrew.mccown@gmail.com', 'ES', NULL, NULL),
	(692, 12916, 'Stock', 'Beckham', '2', 'rydebstock@hotmail.com', 'stockr2@state.gov', 'ES', NULL, NULL),
	(694, 12914, 'Stock', 'Payton', '11', 'rydebstock@hotmail.com', 'stockr2@state.gov', 'HS', NULL, NULL),
	(696, 13021, 'Reza', 'Ruhan', '7', 'ruintoo@gmail.com', 'areza@usaid.gov', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(697, 12802, 'Sankar', 'Nandita', '3', 'sankarpr@state.gov', NULL, 'ES', NULL, NULL),
	(698, 13059, 'Kavaleuski', 'Ian', '10', 'kavaleuskaya@gmail.com', 'm.kavaleuskaya@gmail.com', 'HS', NULL, NULL),
	(700, 12673, 'Ghelani-Decorte', 'Kian', '8', 'rghelani14@gmail.com', 'decorte@un.org', 'MS', NULL, NULL),
	(701, 12690, 'Abdurazakov', 'Elrad', '6', 'abdurazakova@un.org', 'akmal.abdurazakov@gmail.com', 'MS', NULL, NULL),
	(702, 12724, 'Kamara', 'Malik', '1', 'rdagash@gmail.com', 'kamara1ster@gmail.com', 'ES', NULL, NULL),
	(703, 12863, 'Diehl', 'Ethan', 'PK', 'mlegg85@gmail.com', 'adiehl1@gmail.com', 'ES', NULL, NULL),
	(704, 12864, 'Diehl', 'Malcolm', '1', 'mlegg85@gmail.com', 'adiehl1@gmail.com', 'ES', NULL, NULL),
	(705, 12710, 'Mosher', 'Elena', '1', 'anabgonzalez@gmail.com', 'james.mosher@gmail.com', 'ES', NULL, NULL),
	(706, 12709, 'Mosher', 'Emma', '3', 'anabgonzalez@gmail.com', 'james.mosher@gmail.com', 'ES', NULL, NULL),
	(707, 13092, 'Magassouba', 'Abibatou', '2', 'mnoel.fall@gmail.com', 'mmagass9@gmail.com', 'ES', NULL, NULL),
	(708, 12989, 'Bomba', 'Sada', '11', 'williams.kristi@gmail.com', 'khalid.bomba@gmail.com', 'HS', NULL, NULL),
	(709, 13054, 'Ishikawa', 'Tamaki', '3', 'n2project@cobi.jp', 'ishikawan@un.org', 'ES', NULL, NULL),
	(710, 12475, 'Walls', 'Colin', '3', 'sabinalily@yahoo.com', 'mattmw29@gmail.com', 'ES', NULL, NULL),
	(711, 12474, 'Walls', 'Ethan', '5', 'sabinalily@yahoo.com', 'mattmw29@gmail.com', 'ES', NULL, NULL),
	(712, 12811, 'Patterson', 'Emilin', '3', 'refinceyaa@gmail.com', 'markpatterson74@gmail.com', 'ES', NULL, NULL),
	(713, 12810, 'Patterson', 'Kaitlin', '7', 'refinceyaa@gmail.com', 'markpatterson74@gmail.com', 'MS', NULL, NULL),
	(714, 12886, 'Mackay', 'Elsie', '4', 'mandyamackay@gmail.com', 'tpmackay@gmail.com', 'ES', NULL, NULL),
	(656, 12428, 'Wittmann', 'Emilie', '6', 'benedicte.wittmann@yahoo.fr', 'christophewittmann@yahoo.fr', 'MS', 'Beginning Band 1 2023', 'ewittmann30@isk.ac.ke'),
	(695, 13022, 'Reza', 'Reehan', '6', 'ruintoo@gmail.com', 'areza@usaid.gov', 'MS', 'Beginning Band 8 - 2023', 'rreza30@isk.ac.ke'),
	(666, 12681, 'Hercberg', 'Noga', '6', 'avigili3012@gmail.com', 'avigili3012@gmail.com', 'MS', 'Beginning Band 7 2023', 'nhercberg30@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(699, 12674, 'Ghelani-Decorte', 'Emiel', '7', 'rghelani14@gmail.com', 'decorte@un.org', 'MS', 'Concert Band 2023', 'eghelani-decorte29@isk.ac.ke'),
	(676, 12922, 'Dove', 'Georgia', '6', 'meganlpdove@gmail.com', 'stephencarterdove@gmail.com', 'MS', 'Concert Band 2023', 'gdove30@isk.ac.ke'),
	(715, 12885, 'Mackay', 'Nora', '6', 'mandyamackay@gmail.com', 'tpmackay@gmail.com', 'MS', NULL, NULL),
	(716, 12832, 'Ishee', 'Samantha', 'K', 'vickie.ishee@gmail.com', 'jon.ishee1@gmail.com', 'ES', NULL, NULL),
	(717, 12836, 'Ishee', 'Emily', '5', 'vickie.ishee@gmail.com', 'jon.ishee1@gmail.com', 'ES', NULL, NULL),
	(718, 12892, 'Wagner', 'Sonya', '4', 'schakravarty@worldbank.org', 'williamchristianwagner@gmail.com', 'ES', NULL, NULL),
	(719, 12256, 'Pabani', 'Ayaan', '1', 'sofia.jadavji@gmail.com', 'hanif.pabani@gmail.com', 'ES', NULL, NULL),
	(720, 13088, 'Jain', 'Arth', 'K', 'nidhigw@gmail.com', 'padiraja@gmail.com', 'ES', NULL, NULL),
	(721, 12641, 'Fekadeneh', 'Caleb', '5', 'Shewit2003@yahoo.com', 'abi_fek@yahoo.com', 'ES', NULL, NULL),
	(722, 12633, 'Fekadeneh', 'Sina', '10', 'Shewit2003@yahoo.com', 'abi_fek@yahoo.com', 'HS', NULL, NULL),
	(723, 12604, 'Bachmann', 'Marc-Andri', '8', 'bettina.bachmann@ggaweb.ch', 'marcel.bachmann@roche.com', 'MS', NULL, NULL),
	(724, 13066, 'Daher', 'Ralia', 'PK', 'eguerahma@gmail.com', 'libdaher@gmail.com', 'ES', NULL, NULL),
	(725, 12435, 'Daher', 'Abbas', '1', 'eguerahma@gmail.com', 'libdaher@gmail.com', 'ES', NULL, NULL),
	(726, 13099, 'Tafesse', 'Ruth Yifru', '11', 'semene1975@gmail.com', 'yifrutaf2006@gmail.com', 'HS', NULL, NULL),
	(727, 13019, 'Grundberg', 'Emil', '8', 'nimagrundberg@gmail.com', 'jgrundberg@iom.int', 'MS', NULL, NULL),
	(728, 10498, 'Mezemir', 'Amen', '8', 'gtigistamha@yahoo.com', 'tdamte@unicef.org', 'MS', NULL, NULL),
	(729, 13101, 'Chikapa', 'Zizwani', 'PK', 'luyckx.ilke@gmail.com', 'zwangiegasha@gmail.com', 'ES', NULL, NULL),
	(730, 12292, 'Mkandawire', 'Chawanangwa', '7', 'luyckx.ilke@gmail.com', 'zwangiegasha@gmail.com', 'MS', NULL, NULL),
	(731, 12272, 'Mkandawire', 'Daniel', '11', 'luyckx.ilke@gmail.com', 'zwangiegasha@gmail.com', 'HS', NULL, NULL),
	(732, 12995, 'Douglas-Hamilton Pope', 'Selkie', '9', 'saba@savetheelephants.org', 'frank@savetheelephants.org', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(733, 12649, 'Margovsky-Lotem', 'Yoav', 'PK', 'yahelmlotem@gmail.com', 'ambassador@nairobi.mfa.gov.il', 'ES', NULL, NULL),
	(734, 13039, 'Irungu', 'Liam', 'K', 'nicole.m.irungu@gmail.com', 'dominic.i.wanyoike@gmail.com', 'ES', NULL, NULL),
	(735, 13038, 'Irungu', 'Aiden', '2', 'nicole.m.irungu@gmail.com', 'dominic.i.wanyoike@gmail.com', 'ES', NULL, NULL),
	(736, 13024, 'Li', 'Feng Zimo', '5', 'ugandayog01@hotmail.com', 'simonlee831001@hotmail.com', 'ES', NULL, NULL),
	(737, 13023, 'Li', 'Feng Milun', '7', 'ugandayog01@hotmail.com', 'simonlee831001@hotmail.com', 'MS', NULL, NULL),
	(738, 12900, 'Grindell', 'Alice', 'K', 'kaptuiya@gmail.com', 'ricgrin@gmail.com', 'ES', NULL, NULL),
	(739, 12061, 'Grindell', 'Emily', '2', 'kaptuiya@gmail.com', 'ricgrin@gmail.com', 'ES', NULL, NULL),
	(740, 13016, 'Abbonizio', 'Emilie', '11', 'oriane.abbonizio@gmail.com', 'askari606@gmail.com', 'HS', NULL, NULL),
	(741, 13035, 'Muttersbaugh', 'Cassidy', 'K', 'brennan.winter@gmail.com', 'smuttersbaugh@gmail.com', 'ES', NULL, NULL),
	(742, 13034, 'Muttersbaugh', 'Magnolia', '3', 'brennan.winter@gmail.com', 'smuttersbaugh@gmail.com', 'ES', NULL, NULL),
	(743, 12823, 'Bellamy', 'Mathis', 'K', 'ahuggins@mercycorps.org', 'bellamy.paul@gmail.com', 'ES', NULL, NULL),
	(744, 12590, 'Donne', 'Maisha', '11', 'omazzaroni@unicef.org', 'william55don@gmail.com', 'HS', NULL, NULL),
	(746, 12800, 'Romero Sánchez-Miranda', 'Amanda', '3', 'carmen.sanchez@un.org', 'ricardoromerolopez@gmail.com', 'ES', NULL, NULL),
	(747, 12799, 'Romero', 'Candela', '8', 'carmen.sanchez@un.org', 'ricardoromerolopez@gmail.com', 'MS', NULL, NULL),
	(748, 12860, 'Nora', 'Nadia', '11', 'caranora@gmail.com', 'nora.enrico@gmail.com', 'HS', NULL, NULL),
	(749, 12626, 'Lee', 'Nayoon', '5', 'euniceyhlee@gmail.com', 'ts0930.lee@samsung.com', 'ES', NULL, NULL),
	(751, 12718, 'Womble', 'Gaspard', '1', 'priscillia.womble@gmail.com', 'david.womble@gmail.com', 'ES', NULL, NULL),
	(752, 13065, 'Sudra', 'Nile', 'PK', 'maryleakeysudra@gmail.com', 'msudra@isk.ac.ke', 'ES', NULL, NULL),
	(753, 13074, 'Huang', 'Xinyi', '1', 'ruiyingwang2018@gmail.com', 'jinfamilygroup@yahoo.com', 'ES', NULL, NULL),
	(754, 13030, 'Baral', 'Aabhar', '5', 'archanabibhor@gmail.com', 'bibhorbaral@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(755, 12982, 'Rollins', 'Azza', '9', 'faamai@gmail.com', 'salimrollins@gmail.com', 'HS', NULL, NULL),
	(756, 13070, 'Hussain', 'Bushra', 'PK', 'sajdakhalil@gmail.com', 'aminmnhussain@gmail.com', 'ES', NULL, NULL),
	(757, 12999, 'Srutova', 'Monika', '8', 'lehau.mnk@gmail.com', 'dusan_sruta@mzv.cz', 'MS', NULL, NULL),
	(758, 12815, 'Houndeganme', 'Nyx Verena', '6', 'kougblenouchristelle@gmail.com', 'ahoundeganme@unicef.org', 'MS', NULL, NULL),
	(759, 12814, 'Houndeganme', 'Michael', '9', 'kougblenouchristelle@gmail.com', 'ahoundeganme@unicef.org', 'HS', NULL, NULL),
	(760, 12813, 'Houndeganme', 'Crédo Terrence', '12', 'kougblenouchristelle@gmail.com', 'ahoundeganme@unicef.org', 'HS', NULL, NULL),
	(761, 13103, 'Patrikios', 'Zefyros', 'PK', 'aepatrikios@gmail.com', 'jairey@isk.ac.ke', 'ES', NULL, NULL),
	(762, 13067, 'Trujillo', 'Emilio', 'PK', 'prisscilagbaxter@gmail.com', 'mtrujillo@isk.ac.ke', 'ES', NULL, NULL),
	(763, 12862, 'Segev', 'Eitan', 'PK', 'noggasegev@gmail.com', 'avivsegev1@gmail.com', 'ES', NULL, NULL),
	(764, 12721, 'Segev', 'Amitai', '1', 'noggasegev@gmail.com', 'avivsegev1@gmail.com', 'ES', NULL, NULL),
	(765, 12986, 'Maini', 'Karina', '10', 'shilpamaini9@gmail.com', 'rajesh@usnkenya.com', 'HS', NULL, NULL),
	(767, 12851, 'Moons', 'Elena', '7', 'kasia@laud.nl', 'leander@laud.nl', 'MS', NULL, NULL),
	(768, 12809, 'Zeynu', 'Aymen', '3', 'nebihat.muktar@gmail.com', 'zeynu.ummer@undp.org', 'ES', NULL, NULL),
	(769, 12552, 'Zeynu', 'Abem', '7', 'nebihat.muktar@gmail.com', 'zeynu.ummer@undp.org', 'MS', NULL, NULL),
	(770, 13015, 'Simek', 'Alan', '8', 'jiskakova@yahoo.com', 'ondrej.simek@eeas.europa.eu', 'MS', NULL, NULL),
	(771, 13014, 'Simek', 'Emil', '11', 'jiskakova@yahoo.com', 'ondrej.simek@eeas.europa.eu', 'HS', NULL, NULL),
	(772, 13083, 'Gallagher', 'Hachim', '2', 'habibanouh@yahoo.com', 'cuhullan89@gmail.com', 'ES', NULL, NULL),
	(773, 12646, 'Jaffer', 'Kabir', 'K', 'zeeya.jaffer@gmail.com', 'aj@onepet.co.ke', 'ES', NULL, NULL),
	(774, 11646, 'Jaffer', 'Ayaan', '4', 'zeeya.jaffer@gmail.com', 'aj@onepet.co.ke', 'ES', NULL, NULL),
	(776, 12580, 'Dawoodbhai', 'Alifiya', '12', 'munizola77@yahoo.com', 'zoher@royalgroupkenya.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(777, 12578, 'Lindkvist', 'Ruth', '9', 'wanjira.mathai@wri.org', 'larsbasecamp@me.com', 'HS', NULL, NULL),
	(778, 12884, 'Otieno', 'Adrian', '7', 'maureenagengo@gmail.com', 'jotieno@isk.ac.ke', 'MS', NULL, NULL),
	(779, 12583, 'Shah', 'Aanya', '8', 'bhattdeepa@hotmail.com', 'smeet@sapphirelimited.net', 'MS', NULL, NULL),
	(750, 12627, 'Lee', 'Dongyoon', '6', 'euniceyhlee@gmail.com', 'ts0930.lee@samsung.com', 'MS', 'Concert Band 2023', 'dlee30@isk.ac.ke'),
	(861, 12582, 'Schei', 'Nora', '8', 'ghk@spk.no', 'gas@mfa.no', 'MS', NULL, NULL),
	(781, 13086, 'Schoneveld', 'Jake', 'PK', 'nicoliendelange@hotmail.com', 'georgeschoneveld@gmail.com', 'ES', NULL, NULL),
	(782, 12818, 'Gitiba', 'Roy', '7', 'mollygathoni@gmail.com', NULL, 'MS', NULL, NULL),
	(783, 12817, 'Gitiba', 'Kirk Wise', '9', 'mollygathoni@gmail.com', NULL, 'HS', NULL, NULL),
	(784, 12539, 'Geller', 'Isaiah', '9', 'egeller75@gmail.com', 'scge@niras.com', 'HS', NULL, NULL),
	(785, 12603, 'Mbera', 'Bianca', '10', 'julie.onyuka@gmail.com', 'gototo24@gmail.com', 'HS', NULL, NULL),
	(786, 12545, 'Ukumu', 'Kors', '9', 'ukumuphyllis@gmail.com', 'ukumu2002@gmail.com', 'HS', NULL, NULL),
	(787, 12857, 'Shah', 'Jiya', '8', 'miraa9@hotmail.com', 'adarsh@statpack.co.ke', 'MS', NULL, NULL),
	(788, 13098, 'Karmali', 'Zayan', '10', 'shameenkarmali@outlook.com', 'shirazkarmali10@gmail.com', 'HS', NULL, NULL),
	(789, 12954, 'Angima', 'Serenae', '8', 'chao_laura@yahoo.co.uk', NULL, 'MS', NULL, NULL),
	(790, 12735, 'Fatty', 'Fatoumatta', '12', 'fatoumatafatty542@gmail.com', 'fatty@un.org', 'HS', NULL, NULL),
	(791, 12985, 'Kwena', 'Saone', '10', 'cathymbithi7@gmail.com', 'matthewkwena@gmail.com', 'HS', NULL, NULL),
	(792, 12861, 'Wesley Iii', 'Howard', 'PK', 'wnyakiti@gmail.com', 'ajawesley@yahoo.com', 'ES', NULL, NULL),
	(793, 12629, 'Mason', 'Isabella', '11', 'serenamason66@icloud.com', 'cldm@habari.co.tz', 'HS', NULL, NULL),
	(794, 13085, 'Limpered', 'Ayana', 'PK', 'christabel.owino@gmail.com', 'eodunguli@isk.ac.ke', 'ES', NULL, NULL),
	(795, 12795, 'Limpered', 'Arielle', '2', 'christabel.owino@gmail.com', 'eodunguli@isk.ac.ke', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(796, 12412, 'Teklemichael', 'Rakeb', '10', 'milen682@gmail.com', 'keburaku@gmail.com', 'HS', NULL, NULL),
	(797, 12987, 'Shah', 'Pranai', '11', 'shahreena7978@yahoo.com', 'dhiresh.shah55@gmail.com', 'HS', NULL, NULL),
	(798, 12541, 'Shah', 'Dhiya', '7', 's_shah21@hotmail.co.uk', 'jaimin@bobmilgroup.com', 'MS', NULL, NULL),
	(799, 12644, 'Roquebrune', 'Marianne', 'PK', 'mroquebrune@yahoo.ca', NULL, 'ES', NULL, NULL),
	(800, 12842, 'Somaia', 'Nichelle', '1', 'ishisomaia@gmail.com', 'vishal@murbanmovers.co.ke', 'ES', NULL, NULL),
	(801, 11769, 'Somaia', 'Shivail', '4', 'ishisomaia@gmail.com', 'vishal@murbanmovers.co.ke', 'ES', NULL, NULL),
	(802, 13068, 'Stiles', 'Lukas', 'PK', 'ppappas@isk.ac.ke', 'stilesdavid@gmail.com', 'ES', NULL, NULL),
	(803, 11137, 'Stiles', 'Nikolas', '5', 'ppappas@isk.ac.ke', 'stilesdavid@gmail.com', 'ES', NULL, NULL),
	(804, 12979, 'Matimu', 'Nathan', '9', 'liz.matimu@gmail.com', 'mngacha@gmail.com', 'HS', NULL, NULL),
	(805, 12895, 'Abreu', 'Aristophanes', 'K', 'katerina_papaioannou@yahoo.com', 'herson_abreu@hotmail.com', 'ES', NULL, NULL),
	(806, 12896, 'Abreu', 'Herson Alexandros', '1', 'katerina_papaioannou@yahoo.com', 'herson_abreu@hotmail.com', 'ES', NULL, NULL),
	(807, 12825, 'Bailey', 'Arthur', '9', 'tertia.bailey@fcdo.gov.uk', 'petergrahambailey@gmail.com', 'HS', NULL, NULL),
	(808, 12812, 'Bailey', 'Florrie', '11', 'tertia.bailey@fcdo.gov.uk', 'petergrahambailey@gmail.com', 'HS', NULL, NULL),
	(809, 11368, 'Kone', 'Adam', '10', 'sonjalk@unops.org', 'zakskone@gmail.com', 'HS', NULL, NULL),
	(810, 11367, 'Kone', 'Zahra', '12', 'sonjalk@unops.org', 'zakskone@gmail.com', 'HS', NULL, NULL),
	(811, 12670, 'Wimber', 'Thomas', '8', 'nancyaburi@gmail.com', NULL, 'MS', NULL, NULL),
	(812, 12755, 'Ali', 'Rahmaan', '12', 'rahima.khawaja@gmail.com', 'rahim.khawaja@aku.edu', 'HS', NULL, NULL),
	(813, 13029, 'Chowdhury', 'Davran', '5', 'mohira22@yahoo.com', 'numayr_chowdhury@yahoo.com', 'ES', NULL, NULL),
	(814, 12868, 'Chowdhury', 'Nevzad', '11', 'mohira22@yahoo.com', 'numayr_chowdhury@yahoo.com', 'HS', NULL, NULL),
	(815, 12553, 'Patel', 'Aariyana', '9', 'roshninp1128@gmail.com', 'niknpatel@gmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(816, 12938, 'Mueller', 'Graham', '7', 'carlabenini1@gmail.com', 'mueller10r@aol.com', 'MS', NULL, NULL),
	(817, 12937, 'Mueller', 'Willem', '9', 'carlabenini1@gmail.com', 'mueller10r@aol.com', 'HS', NULL, NULL),
	(818, 12936, 'Mueller', 'Christian', '11', 'carlabenini1@gmail.com', 'mueller10r@aol.com', 'HS', NULL, NULL),
	(819, 13075, 'Ndoye', 'Libasse', '8', 'fatou.ndoye@un.org', NULL, 'MS', NULL, NULL),
	(820, 13020, 'Wang', 'Yi (Gavin)', '3', 'supermomcccc@gmail.com', 'mcbgwang@gmail.com', 'ES', NULL, NULL),
	(821, 12950, 'Wang', 'Shuyi (Bella)', '8', 'supermomcccc@gmail.com', 'mcbgwang@gmail.com', 'MS', NULL, NULL),
	(822, 12715, 'David-Tafida', 'Mariam', '2', 'fatymahit@gmail.com', 'bradleyeugenedavid@gmail.com', 'ES', NULL, NULL),
	(823, 12720, 'Farrell', 'James', '1', 'katherinedfarrell@gmail.com', 'farrellmp@gmail.com', 'ES', NULL, NULL),
	(824, 12801, 'Gronborg', 'Anna Toft', 'K', 'trinegronborg@gmail.com', 'laschi@um.dk', 'ES', NULL, NULL),
	(825, 13036, 'Sidari', 'Rocco', '2', 'geven@hotmail.com', 'jsidari@usaid.gov', 'ES', NULL, NULL),
	(826, 13072, 'Ajidahun', 'David', 'PK', 'ajidahun.olori@gmail.com', 'caliphlex@yahoo.com', 'ES', NULL, NULL),
	(827, 12805, 'Ajidahun', 'Darian', '2', 'ajidahun.olori@gmail.com', 'caliphlex@yahoo.com', 'ES', NULL, NULL),
	(828, 12804, 'Ajidahun', 'Annabelle', '4', 'ajidahun.olori@gmail.com', 'caliphlex@yahoo.com', 'ES', NULL, NULL),
	(829, 12328, 'Hussain', 'Saif', '4', 'milhemrana@gmail.com', 'omarhussain_80@hotmail.com', 'ES', NULL, NULL),
	(830, 12899, 'Hussain', 'Taim', 'K', 'milhemrana@gmail.com', 'omarhussain_80@hotmail.com', 'ES', NULL, NULL),
	(831, 13048, 'Hayer', 'Kaveer Singh', '2', 'manpreetkh@gmail.com', 'csh@hayerone.com', 'ES', NULL, NULL),
	(832, 12471, 'Hayer', 'Manvir Singh', '7', 'manpreetkh@gmail.com', 'csh@hayerone.com', 'MS', NULL, NULL),
	(834, 12898, 'Bin Taif', 'Ahmed Jabir', 'K', 'shanchita02@gmail.com', 'ul.taif@gmail.com', 'ES', NULL, NULL),
	(835, 12311, 'Bin Taif', 'Ahmed Jayed', '2', 'shanchita02@gmail.com', 'ul.taif@gmail.com', 'ES', NULL, NULL),
	(836, 12312, 'Bin Taif', 'Ahmed Jawad', '5', 'shanchita02@gmail.com', 'ul.taif@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(837, 12978, 'Nas', 'Rebekah Ysabelle', '9', 'gretchen.nas79@gmail.com', 't.nas@cgiar.org', 'HS', NULL, NULL),
	(838, 12949, 'Husemann', 'Emilia', '8', 'annahusemann@web.de', 'christoph.zipfel@web.de', 'MS', NULL, NULL),
	(839, 12891, 'Bonde-Nielsen', 'Luna', '4', 'nike@terramoyo.com', 'pbn@oldonyolaro.com', 'ES', NULL, NULL),
	(841, 13000, 'Alemayehu', 'Naomi', '4', 'hayatabdulahi@gmail.com', 'alexw9@gmail.com', 'ES', NULL, NULL),
	(842, 13105, 'Hales', 'Arabella', 'PK', 'amberley.hales@gmail.com', 'christopher.w.hales@gmail.com', 'ES', NULL, NULL),
	(780, 13076, 'Ibrahim', 'Masoud', '6', 'ibrahimkhadija@gmail.com', 'ibradaud@gmail.com', 'MS', 'Beginning Band 1 2023', 'mibrahim30@isk.ac.ke'),
	(833, 12756, 'Tulga', 'Titu', '6', 'buyanu@gmail.com', 'tulgaad@gmail.com', 'MS', 'Beginning Band 7 2023', 'ttulga30@isk.ac.ke'),
	(843, 13087, 'Khan', 'Zari', '9', 'asmaibrar2023@gmail.com', 'ibrardiplo@gmail.com', 'HS', NULL, NULL),
	(844, 13026, 'Alwedo', 'Cradle Terry', '5', 'ogwangk@unhcr.org', NULL, 'ES', NULL, NULL),
	(846, 13095, 'Braun', 'Felix', '8', 'wibke.braun@eeas.europa.eu', NULL, 'MS', NULL, NULL),
	(847, 12998, 'Verstraete', 'Io', '10', 'cornelia2vanzyl@gmail.com', 'lverstraete@unicef.org', 'HS', NULL, NULL),
	(848, 12560, 'Crabtree', 'Matthew', '11', 'crabtreeak@state.gov', 'crabtreejd@state.gov', 'HS', NULL, NULL),
	(849, 12269, 'Sansculotte', 'Kieu', '12', 'thanhluu77@hotmail.com', 'kwesi.sansculotte@wfp.org', 'HS', NULL, NULL),
	(850, 12496, 'Berkouwer', 'Daniel', '1', 'lijiayu211@gmail.com', 'meskesberkouwer@gmail.com', 'ES', NULL, NULL),
	(851, 12820, 'Opere', 'Kayla', 'PK', 'rineke-van.dam@minbuza.nl', 'alexopereh@yahoo.com', 'ES', NULL, NULL),
	(852, 12794, 'Berthellier-Antoine', 'Léa', '1', 'dberthellier@gmail.com', 'malick74@gmail.com', 'ES', NULL, NULL),
	(853, 13104, 'Kaseva', 'Lukas', 'PK', 'linda.kaseva@gmail.com', 'johannes.tarvainen@gmail.com', 'ES', NULL, NULL),
	(854, 13096, 'Kaseva', 'Lauri', '3', 'linda.kaseva@gmail.com', 'johannes.tarvainen@gmail.com', 'ES', NULL, NULL),
	(855, 12550, 'Khan', 'Layal', '2', 'zehrahyderali@gmail.com', 'ikhan2@worldbank.org', 'ES', NULL, NULL),
	(856, 13062, 'Croze', 'Ishbel', '9', 'anna.croze@gmail.com', 'lengai.croze@gmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(857, 12873, 'Croucher', 'Emily', '5', 'clairebedelian@hotmail.com', 'crouchermatthew@hotmail.com', 'ES', NULL, NULL),
	(858, 12874, 'Croucher', 'Oliver', '7', 'clairebedelian@hotmail.com', 'crouchermatthew@hotmail.com', 'MS', NULL, NULL),
	(859, 12875, 'Croucher', 'Anabelle', '9', 'clairebedelian@hotmail.com', 'crouchermatthew@hotmail.com', 'HS', NULL, NULL),
	(860, 12953, 'Olvik', 'Vera', '8', 'uakesson@hotmail.com', 'gunnarolvik@hotmail.com', 'MS', NULL, NULL),
	(862, 12845, 'Skaaraas-Gjoelberg', 'Theodor', '1', 'ceciskaa@yahoo.com', 'erlendmagnus@hotmail.com', 'ES', NULL, NULL),
	(863, 12846, 'Skaaraas-Gjoelberg', 'Cedrik', '5', 'ceciskaa@yahoo.com', 'erlendmagnus@hotmail.com', 'ES', NULL, NULL),
	(864, 13089, 'Lee', 'David', '2', 'podo416@gmail.com', 'mkthestyle@icloud.com', 'ES', NULL, NULL),
	(865, 12736, 'Jijina', 'Sanaya', '12', 'shahnazjijjina@gmail.com', 'percy.jijina@jotun.com', 'HS', NULL, NULL),
	(866, 13010, 'Arora', 'Harshaan', '8', 'dearbhawna1@yahoo.co.in', 'kapil.arora@eni.com', 'MS', NULL, NULL),
	(867, 13009, 'Arora', 'Tisya', '10', 'dearbhawna1@yahoo.co.in', 'kapil.arora@eni.com', 'HS', NULL, NULL),
	(868, 13001, 'Elkana', 'Gai', '1', 'maayan180783@gmail.com', 'tamir260983@gmail.com', 'ES', NULL, NULL),
	(869, 13002, 'Elkana', 'Yuval', '3', 'maayan180783@gmail.com', 'tamir260983@gmail.com', 'ES', NULL, NULL),
	(870, 13003, 'Elkana', 'Matan', '5', 'maayan180783@gmail.com', 'tamir260983@gmail.com', 'ES', NULL, NULL),
	(871, 12901, 'Nasidze', 'Niccolo', 'K', 'topuridze.tamar@gmail.com', 'alexander.nasidze@un.org', 'ES', NULL, NULL),
	(872, 12472, 'Aditya', 'Jayesh', '8', NULL, 'NANDKITTU@YAHOO.COM', 'MS', NULL, NULL),
	(875, 11851, 'Bredin', 'Zara', '10', 'nickolls@un.org', 'milesbredin@mac.com', 'HS', NULL, NULL),
	(876, 20817, 'Lavack', 'Mark', '8', 'patricia.wanyee@gmail.com', 'slavack@isk.ac.ke', 'MS', NULL, NULL),
	(877, 26015, 'Lavack', 'Michael', '10', 'patricia.wanyee@gmail.com', 'slavack@isk.ac.ke', 'HS', NULL, NULL),
	(878, 10820, 'Dodhia', 'Rohin', '11', 'tejal@capet.co.ke', 'ketul.dodhia@gmail.com', 'HS', NULL, NULL),
	(879, 12508, 'Bunch', 'Jaidyn', '11', 'tsjbunch2@gmail.com', 'tsjbunch@gmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(880, 12529, 'Victor', 'Chalita', '11', NULL, 'Michaelnoahvictor@gmail.com', 'HS', NULL, NULL),
	(881, 12598, 'Waalewijn', 'Hannah', '7', 'manonwaalewijn@gmail.com', 'manonenpieter@gmail.com', 'MS', NULL, NULL),
	(883, 12596, 'Waalewijn', 'Simon', '11', 'manonwaalewijn@gmail.com', 'manonenpieter@gmail.com', 'HS', NULL, NULL),
	(885, 12591, 'Wietecha', 'Kaitlin', '10', 'aitkenjennifer@hotmail.com', 'rwietecha@yahoo.com', 'HS', NULL, NULL),
	(886, 12702, 'Molloy', 'Saoirse', '2', 'kacey.molloy@gmail.com', 'cmolloy.mt@gmail.com', 'ES', NULL, NULL),
	(887, 12701, 'Molloy', 'Caelan', '4', 'kacey.molloy@gmail.com', 'cmolloy.mt@gmail.com', 'ES', NULL, NULL),
	(888, 12594, 'Mollier-Camus', 'Victor', '5', 'carole.mollier.camus@gmail.com', 'simon.mollier-camus@bakerhughes.com', 'ES', NULL, NULL),
	(889, 12586, 'Mollier-Camus', 'Elisa', '8', 'carole.mollier.camus@gmail.com', 'simon.mollier-camus@bakerhughes.com', 'MS', NULL, NULL),
	(891, 12684, 'Varun', 'Jaishna', '7', 'liveatpresent83@gmail.com', 'liveatpresent83@gmail.com', 'MS', NULL, NULL),
	(892, 12782, 'Heijstee', 'Leah', '3', 'vivien.jarl@gmail.com', 'vivien.jarl@gmail.com', 'ES', NULL, NULL),
	(893, 12781, 'Heijstee', 'Zara', '8', 'vivien.jarl@gmail.com', 'vivien.jarl@gmail.com', 'MS', NULL, NULL),
	(894, 12902, 'Sotiriou', 'Graciela', 'K', 'enehrling@gmail.com', 'b.and.g.sotiriou@gmail.com', 'ES', NULL, NULL),
	(895, 12239, 'Sotiriou', 'Leonidas', '2', 'enehrling@gmail.com', 'b.and.g.sotiriou@gmail.com', 'ES', NULL, NULL),
	(896, 12612, 'Barbacci', 'Evangelina', '7', 'kbarbacci@hotmail.com', 'fbarbacci@hotmail.com', 'MS', NULL, NULL),
	(897, 12611, 'Barbacci', 'Gabriella', '10', 'kbarbacci@hotmail.com', 'fbarbacci@hotmail.com', 'HS', NULL, NULL),
	(898, 12581, 'Moyle', 'Santiago', '9', 'trina.schofield@gmail.com', 'fernandomoyle@gmail.com', 'HS', NULL, NULL),
	(899, 13082, 'Yakusik', 'Alissa', '4', 'annayakusik@gmail.com', 'davidwilson1760@gmail.com', 'ES', NULL, NULL),
	(900, 12662, 'Ghariani', 'Farah', '9', 'wafaek@hotmail.com', 'tewfickg@hotmail.com', 'HS', NULL, NULL),
	(901, 12634, 'Cameron-Mutyaba', 'Lillian', '10', 'jennifer.cameron@international.gc.ca', 'mutyaba32@gmail.com', 'HS', NULL, NULL),
	(902, 12635, 'Cameron-Mutyaba', 'Rose', '10', 'jennifer.cameron@international.gc.ca', 'mutyaba32@gmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(903, 12984, 'Teferi', 'Nathan', '10', 'lula.tewfik@gmail.com', 'tamessay@hotmail.com', 'HS', NULL, NULL),
	(904, 13057, 'Mayar', 'Angab', '11', 'mmonoja@yahoo.com', 'ayueldit2@gmail.com', 'HS', NULL, NULL),
	(905, 12737, 'Abdosh', 'Hanina', '12', NULL, 'el.abdosh@gmail.com', 'HS', NULL, NULL),
	(890, 12683, 'Varun', 'Harsha', '6', 'liveatpresent83@gmail.com', 'liveatpresent83@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'hvarun30@isk.ac.ke'),
	(873, 12668, 'Szuchman', 'Sadie', '6', 'sonyaedelman@gmail.com', 'szuchman@gmail.com', 'MS', 'Beginning Band 7 2023', 'sszuchman30@isk.ac.ke'),
	(845, 13018, 'Agenorwot', 'Maria', '8', 'bpido100@gmail.com', NULL, 'MS', 'Concert Band 2023', 'magenorwot28@isk.ac.ke'),
	(874, 12667, 'Szuchman', 'Reuben', '8', 'sonyaedelman@gmail.com', 'szuchman@gmail.com', 'MS', 'Concert Band 2023', 'rszuchman28@isk.ac.ke'),
	(907, 12732, 'Alemu', 'Liri', '3', 'alemus20022@gmail.com', 'alemus20022@gmail.com', 'ES', NULL, NULL),
	(908, 13053, 'Ishanvi', 'Ishanvi', 'K', 'anupuniaahlawat@gmail.com', 'neerajahlawat88@gmail.com', 'ES', NULL, NULL),
	(909, 12373, 'Goyal', 'Seher', '10', 'vitastasingh@hotmail.com', 'sgoyal@worldbank.org', 'HS', NULL, NULL),
	(910, 12917, 'Assi', 'Michael Omar', '7', 'esmeralda.naji@hotmail.com', 'assi.mohamed@gmail.com', 'MS', NULL, NULL),
	(911, 12728, 'Singh', 'Abhimanyu', '2', NULL, 'rkc.jack@gmail.com', 'ES', NULL, NULL),
	(913, 13013, 'Otieno', 'Sifa', '12', 'linet.otieno@gmail.com', 'tcpauldbtcol@gmail.com', 'HS', NULL, NULL),
	(914, 12819, 'Ibrahim', 'Iman', '9', NULL, 'ibradaud@gmail.com', 'HS', NULL, NULL),
	(915, 12994, 'Mathews', 'Tarquin', '11', 'nadia@africaonline.co.ke', 'phil@heliprops.co.ke', 'HS', NULL, NULL),
	(916, 10437, 'Pandit', 'Jia', '10', 'purvipandit@gmail.com', 'dhruvpandit@gmail.com', 'HS', NULL, NULL),
	(917, 12844, 'Waugh', 'Josephine', '1', 'annabajorek125@gmail.com', 'minwaugh22@gmail.com', 'ES', NULL, NULL),
	(918, 12843, 'Waugh', 'Rosemary', '4', 'annabajorek125@gmail.com', 'minwaugh22@gmail.com', 'ES', NULL, NULL),
	(919, 13025, 'Kisukye', 'Daudi', '5', 'dmulira16@gmail.com', 'kisukye@un.org', 'ES', NULL, NULL),
	(920, 12759, 'Kisukye', 'Gabriel', '10', 'dmulira16@gmail.com', 'kisukye@un.org', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(921, 12483, 'Virani', 'Aydin', '3', 'mehreenrv@gmail.com', 'rahimwv@gmail.com', 'ES', NULL, NULL),
	(922, 12927, 'Huysdens', 'Yasmin', '7', 'mhuysdens@gmail.com', 'merchan_nl@hotmail.com', 'MS', NULL, NULL),
	(923, 12926, 'Huysdens', 'Jacey', '9', 'mhuysdens@gmail.com', 'merchan_nl@hotmail.com', 'HS', NULL, NULL),
	(924, 13028, 'Schonemann', 'Esther', '5', NULL, 'stesch@um.dk', 'ES', NULL, NULL),
	(925, 13046, 'Khouma', 'Nabou', 'K', 'ceciliakleimert@gmail.com', 'tallakhouma92@gmail.com', 'ES', NULL, NULL),
	(926, 13045, 'Khouma', 'Khady', '3', 'ceciliakleimert@gmail.com', 'tallakhouma92@gmail.com', 'ES', NULL, NULL),
	(927, 13102, 'Ellinger', 'Emily', '5', 'hello@dianaellinger.com', 'c_ellinger@hotmail.com', 'ES', NULL, NULL),
	(929, 12501, 'D''souza', 'Isaac', '8', 'lizannec@hotmail.com', 'royden.dsouza@gmail.com', 'MS', NULL, NULL),
	(930, 13071, 'Kane', 'Ezra', 'PK', 'danionatangent@gmail.com', NULL, 'ES', NULL, NULL),
	(931, 13091, 'Pijovic', 'Sapia', 'PK', 'somatatakone@yahoo.com', 'somatatakone@yahoo.com', 'ES', NULL, NULL),
	(932, 13052, 'Birschbach', 'Mubanga', 'K', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'ES', NULL, NULL),
	(933, 12748, 'Granot', 'Ben', 'K', 'maayanalmagor@gmail.com', 'granotb@gmail.com', 'ES', NULL, NULL),
	(934, 12747, 'Khalid', 'Zyla', 'K', 'aryana.c.khalid@gmail.com', 'waqqas.khalid@gmail.com', 'ES', NULL, NULL),
	(935, 12751, 'Kishiue-Turkstra', 'Hannah', 'K', 'akishiue@worldbank.org', 'jan.turkstra@gmail.com', 'ES', NULL, NULL),
	(936, 12824, 'Magnusson', 'Alexander', 'K', 'ericaselles@gmail.com', 'jon.a.magnusson@gmail.com', 'ES', NULL, NULL),
	(937, 12834, 'Nau', 'Emerson', 'K', 'kimdsimon@gmail.com', 'nau.hew@gmail.com', 'ES', NULL, NULL),
	(938, 12743, 'Patenaude', 'Alexandre', 'K', 'shanyoung86@gmail.com', 'patenaude.joel@gmail.com', 'ES', NULL, NULL),
	(939, 13040, 'Hirose', 'Ren', '1', 'r.imamoto@gmail.com', 'yusuke.hirose@sumitomocorp.com', 'ES', NULL, NULL),
	(940, 12767, 'Johnson', 'Abel', '1', 'ameenahbsaleem@gmail.com', 'ibnabu@aol.com', 'ES', NULL, NULL),
	(941, 13037, 'Kane', 'Issa', '1', 'danionatangent@gmail.com', NULL, 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(942, 12717, 'Kiers', 'Beatrix', '1', 'smallwood.marianne@gmail.com', 'alexis.kiers@gmail.com', 'ES', NULL, NULL),
	(943, 12459, 'Menkerios', 'Yousif', '1', 'oh_hassan@hotmail.com', 'hmenkerios@aol.com', 'ES', NULL, NULL),
	(944, 12687, 'Oberjuerge', 'Clayton', '1', 'kateharris22@gmail.com', 'loberjue@gmail.com', 'ES', NULL, NULL),
	(945, 12480, 'Pant', 'Yash', '1', 'pantjoyindia@gmail.com', 'hem7star@gmail.com', 'ES', NULL, NULL),
	(946, 13090, 'Pijovic', 'Amandla', '1', 'somatatakone@yahoo.com', 'somatatakone@yahoo.com', 'ES', NULL, NULL),
	(947, 13094, 'Santos', 'Paola', '1', 'achang_911@yahoo.com', 'jsants16@yahoo.com', 'ES', NULL, NULL),
	(948, 12608, 'Sarfaraz', 'Amaya', '1', 'sarahbafridi@gmail.com', 'sarfarazabid@gmail.com', 'ES', NULL, NULL),
	(949, 12841, 'Schrader', 'Clarice', '1', 'schraderhub@gmail.com', 'schraderjp09@gmail.com', 'ES', NULL, NULL),
	(950, 12939, 'Sobantu', 'Mandisa', '1', 'mbemelaphi@gmail.com', 'monwabisi.sobantu@gmail.com', 'ES', NULL, NULL),
	(951, 12877, 'Kamenga', 'Tasheni', '2', 'nompumelelo.nkosi@gmail.com', 'kamenga@gmail.com', 'ES', NULL, NULL),
	(952, 12713, 'Patenaude', 'Theodore', '2', 'shanyoung86@gmail.com', 'patenaude.joel@gmail.com', 'ES', NULL, NULL),
	(953, 12714, 'Soobrattee', 'Ewyn', '2', 'jhomanchuk@yahoo.com', 'rsoobrattee@hotmail.com', 'ES', NULL, NULL),
	(954, 12888, 'Von Platen-Hallermund', 'Anna', '2', 'mspliid@gmail.com', 'thobobs@hotmail.com', 'ES', NULL, NULL),
	(955, 12527, 'Wendelboe', 'Tristan', '2', 'maria.wendelboe@outlook.dk', 'morwen@um.dk', 'ES', NULL, NULL),
	(956, 12570, 'Andersen', 'Signe', '3', 'millelund@gmail.com', 'steensandersen@gmail.com', 'ES', NULL, NULL),
	(957, 12944, 'Asquith', 'Holly', '3', 'kamilla.henningsen@gmail.com', 'm.asquith@icloud.com', 'ES', NULL, NULL),
	(958, 13033, 'Diop Weyer', 'Aurélien', '3', 'frederique.weyer@graduateinstitute.ch', 'amadou.diop@graduateinstitute.ch', 'ES', NULL, NULL),
	(959, 12693, 'Lundell', 'Levi', '3', 'rebekahlundell@gmail.com', 'redlundell@gmail.com', 'ES', NULL, NULL),
	(960, 13093, 'Santos', 'Santiago', '3', 'achang_911@yahoo.com', 'jsants16@yahoo.com', 'ES', NULL, NULL),
	(961, 12840, 'Schrader', 'Genevieve', '3', 'schraderhub@gmail.com', 'schraderjp09@gmail.com', 'ES', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(962, 12369, 'Vazquez Eraso', 'Martin', '3', 'berasopuig@worldbank.org', 'vvazquez@worldbank.org', 'ES', NULL, NULL),
	(963, 12664, 'Vestergaard', 'Magne', '3', 'marves@um.dk', 'elrulu@protonmail.com', 'ES', NULL, NULL),
	(964, 12665, 'Vestergaard', 'Nanna', '3', 'marves@um.dk', 'elrulu@protonmail.com', 'ES', NULL, NULL),
	(965, 12849, 'Weill', 'Benjamin', '3', 'robineberlin@gmail.com', 'matthew_weill@mac.com', 'ES', NULL, NULL),
	(966, 12289, 'Bailey', 'Kira', '4', 'anneli.veiszhaupt.bailey@gov.se', 'dbailey1971@gmail.com', 'ES', NULL, NULL),
	(967, 12850, 'Bixby', 'Aaryama', '4', 'rkaria@gmail.com', 'malcolmbixby@gmail.com', 'ES', NULL, NULL),
	(968, 12925, 'Carlevato', 'Armelle', '4', 'awishous@gmail.com', 'scarlevato@gmail.com', 'ES', NULL, NULL),
	(969, 12942, 'Corbin', 'Sonia', '4', 'corbincf@gmail.com', 'james.corbin.pa@gmail.com', 'ES', NULL, NULL),
	(970, 12617, 'Khalid', 'Zaria', '4', 'aryana.c.khalid@gmail.com', 'waqqas.khalid@gmail.com', 'ES', NULL, NULL),
	(912, 13056, 'Otieno', 'Uzima', '7', 'linet.otieno@gmail.com', 'tcpauldbtcol@gmail.com', 'MS', 'Concert Band 2023', 'uotieno29@isk.ac.ke'),
	(1, 12607, 'Farraj', 'Carlos Laith', '4', 'gmcabrera2017@gmail.com', 'amer_farraj@yahoo.com', 'ES', NULL, NULL),
	(2, 12606, 'Farraj', 'Jarius', '11', 'gmcabrera2017@gmail.com', 'amer_farraj@yahoo.com', 'HS', NULL, NULL),
	(3, 12768, 'Dadashev', 'Murad', '8', 'huseynovags@yahoo.com', 'adadashev@unicef.org', 'MS', NULL, NULL),
	(4, 12769, 'Dadasheva', 'Zubeyda', '12', 'huseynovags@yahoo.com', 'adadashev@unicef.org', 'HS', NULL, NULL),
	(5, 12433, 'Iversen', 'Sumaiya', '12', 'sahfana.ali.mubarak@mfa.no', 'iiv@lyse.net', 'HS', NULL, NULL),
	(6, 12542, 'Borg Aidnell', 'Nike', '2', 'aidnell@gmail.com', 'parborg70@hotmail.com', 'ES', NULL, NULL),
	(7, 12543, 'Borg Aidnell', 'Siv', '2', 'aidnell@gmail.com', 'parborg70@hotmail.com', 'ES', NULL, NULL),
	(8, 12696, 'Borg Aidnell', 'Disa', '5', 'aidnell@gmail.com', 'parborg70@hotmail.com', 'ES', NULL, NULL),
	(9, 12070, 'Ellis', 'Ryan', '11', 'etinsley@worldbank.org', 'pellis@worldbank.org', 'HS', NULL, NULL),
	(10, 12068, 'Ellis', 'Adrienne', '12', 'etinsley@worldbank.org', 'pellis@worldbank.org', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(11, 12192, 'Hodge', 'Emalea', '5', 'janderson12@worldbank.org', 'jhodge1@worldbank.org', 'ES', NULL, NULL),
	(13, 12430, 'Arens', 'Jip', '12', 'noudwater@gmail.com', 'luukarens@gmail.com', 'HS', NULL, NULL),
	(534, 11457, 'Schenck', 'Spencer', '6', 'prillakrone@gmail.com', 'schenck.mills@bcg.com', 'MS', 'Beginning Band 8 - 2023', 'sschenck30@isk.ac.ke'),
	(121, 12969, 'Willis', 'Isla', '6', 'tjpeta.willis@gmail.com', 'pt.willis@bigpond.com', 'MS', 'Beginning Band 8 - 2023', 'iwillis30@isk.ac.ke'),
	(101, 10775, 'Chandaria', 'Seya', '6', 'farzana@chandaria.biz', 'sachen@chandaria.biz', 'MS', 'Beginning Band 8 - 2023', 'schandaria30@isk.ac.ke'),
	(376, 10508, 'Chopra', 'Malan', '6', 'tanja.chopra@gmx.de', 'jarat_chopra@me.com', 'MS', 'Beginning Band 8 - 2023', 'mchopra30@isk.ac.ke'),
	(339, 11266, 'Vestergaard', 'Lilla', '6', 'psarasas@gmail.com', 'o.vestergaard@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'svestergaard30@isk.ac.ke'),
	(369, 12427, 'Sangare', 'Moussa', '6', 'taissata@yahoo.fr', 'sangnouh@yahoo.fr', 'MS', 'Beginning Band 8 - 2023', 'msangare30@isk.ac.ke'),
	(496, 11762, 'Jansson', 'Leo', '6', 'sawanakagawa@gmail.com', 'torjansson@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'ljansson30@isk.ac.ke'),
	(549, 12619, 'Saleem', 'Nora', '6', 'anna.saleem.hogberg@gov.se', 'saleembaha@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'nsaleem30@isk.ac.ke'),
	(572, 11804, 'Stephens', 'Kaisei', '6', 'mwatanabe1@worldbank.org', 'mstephens@worldbank.org', 'MS', 'Beginning Band 8 - 2023', 'kstephens30@isk.ac.ke'),
	(105, 12096, 'Freiin Von Handel', 'Olivia', '6', 'igiribaldi@hotmail.com', 'thomas.von.handel@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'ovonhandel30@isk.ac.ke'),
	(518, 12152, 'Materne', 'Kiara', '6', 'nat.dekeyser@gmail.com', 'fredmaterne@hotmail.com', 'MS', 'Beginning Band 8 - 2023', 'kmaterne30@isk.ac.ke'),
	(229, 12689, 'Eshetu', 'Mikael', '6', 'olga.petryniak@gmail.com', 'kassahun.wossene@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'meshetu30@isk.ac.ke'),
	(71, 12170, 'Biafore', 'Ignacio', '6', 'nermil@gmail.com', 'montiforce@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'ibiafore30@isk.ac.ke'),
	(775, 12976, 'Haysmith', 'Romilly', '6', 'stephanie.haysmith@un.org', 'davehaysmith@hotmail.com', 'MS', 'Beginning Band 8 - 2023', 'rhaysmith30@isk.ac.ke'),
	(884, 12725, 'Wietecha', 'Alexander', '6', 'aitkenjennifer@hotmail.com', 'rwietecha@yahoo.com', 'MS', 'Beginning Band 8 - 2023', 'awietecha30@isk.ac.ke'),
	(669, 12883, 'Dibling', 'Julian', '6', 'askfelicia@gmail.com', 'sdibling@hotmail.com', 'MS', 'Beginning Band 8 - 2023', 'jdibling30@isk.ac.ke'),
	(840, 12537, 'Bonde-Nielsen', 'Gaia', '6', 'nike@terramoyo.com', 'pbn@oldonyolaro.com', 'MS', 'Beginning Band 8 - 2023', 'gbondenielsen30@isk.ac.ke'),
	(139, 11096, 'Tanna', 'Kush', '6', 'vptanna@gmail.com', 'priyentanna@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'ktanna30@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(442, 12909, 'Alnaqbi', 'Saqer', '6', 'emaraty_a99@hotmail.com', 'emaraty353@hotmail.com', 'MS', 'Beginning Band 8 - 2023', 'salnaqbi30@isk.ac.ke'),
	(176, 10812, 'Mcmurtry', 'Jack', '6', 'karenpoore77@yahoo.co.uk', 'seanmcmurtry7@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'jmcmurtry30@isk.ac.ke'),
	(928, 12500, 'D''souza', 'Aiden', '6', 'lizannec@hotmail.com', 'royden.dsouza@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'adsouza30@isk.ac.ke'),
	(12, 12193, 'Hodge', 'Eliana', '7', 'janderson12@worldbank.org', 'jhodge1@worldbank.org', 'MS', 'Concert Band 2023', 'ehodge29@isk.ac.ke'),
	(640, 11463, 'Dokunmu', 'Abdul-Lateef Boluwatife (Bolu)', '7', 'JJAGUN@GMAIL.COM', NULL, 'MS', 'Beginning Band 7 2023', 'adokunmu29@isk.ac.ke'),
	(324, 11262, 'Khubchandani', 'Anaiya', '6', 'ramji.farzana@gmail.com', 'rishi.khubchandani@gmail.com', 'MS', 'Beginning Band 7 2023', 'akhubchandani30@isk.ac.ke'),
	(906, 12549, 'Mutombo', 'Ariel', '6', 'nathaliesindamut@gmail.com', 'mutombok@churchofjesuschrist.org', 'MS', 'Beginning Band 7 2023', 'amutombo30@isk.ac.ke'),
	(295, 10686, 'Cutler', 'Edie', '6', 'megseyjackson@gmail.com', 'adrianhcutler@gmail.com', 'MS', 'Beginning Band 7 2023', 'ecutler30@isk.ac.ke'),
	(22, 11883, 'Camisa', 'Eugénie', '6', 'katerinelafreniere@hotmail.com', 'laurentcamisa@hotmail.com', 'MS', 'Beginning Band 7 2023', 'ecamisa30@isk.ac.ke'),
	(203, 10562, 'Haswell', 'Finlay', '6', 'ahaswell@isk.ac.ke', 'danhaswell@hotmail.co.uk', 'MS', 'Beginning Band 7 2023', 'fhaswell30@isk.ac.ke'),
	(20, 12967, 'Andersen', 'Yonatan Wondim Belachew', '6', 'louian@um.dk', 'wondim_b@yahoo.com', 'MS', 'Beginning Band 7 2023', 'ywondimandersen30@isk.ac.ke'),
	(500, 10708, 'Choi', 'Yoonseo', '6', 'shy_cool@naver.com', 'flymax2002@hotmail.com', 'MS', 'Beginning Band 7 2023', 'ychoi30@isk.ac.ke'),
	(689, 13073, 'Daines', 'Evan', '6', 'foreverdaines143@gmail.com', 'dainesy@gmail.com', 'MS', 'Beginning Band 1 2023', 'edaines30@isk.ac.ke>'),
	(175, 10817, 'Mcmurtry', 'Holly', '6', 'karenpoore77@yahoo.co.uk', 'seanmcmurtry7@gmail.com', 'MS', 'Beginning Band 1 2023', 'hmcmurtry30@isk.ac.ke'),
	(693, 12915, 'Stock', 'Max', '6', 'rydebstock@hotmail.com', 'stockr2@state.gov', 'MS', 'Beginning Band 1 2023', 'mstock30@isk.ac.ke'),
	(456, 11458, 'O''neill Calver', 'Rowan', '6', 'laraoneill@gmail.com', 'timcalver@gmail.com', 'MS', 'Beginning Band 1 2023', 'roneillcalver30@isk.ac.ke'),
	(588, 12392, 'Mensah', 'Selma', '6', 'sabinemensah@gmail.com', 'henrimensah@gmail.com', 'MS', 'Beginning Band 1 2023', 'smensah30@isk.ac.ke'),
	(522, 10621, 'Hire', 'Ainsley', '7', 'jhire@isk.ac.ke', 'bhire@isk.ac.ke', 'MS', 'Concert Band 2023', 'ahire29@isk.ac.ke'),
	(123, 10474, 'Awori', 'Aisha', '8', 'Annmarieawori@gmail.com', 'Michael.awori@gmail.com', 'MS', 'Concert Band 2023', 'aawori28@isk.ac.ke'),
	(567, 11677, 'Ross', 'Caleb', '8', 'skeddington@yahoo.com', 'sross78665@gmail.com', 'MS', 'Concert Band 2023', 'cross28@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(428, 11703, 'Kimuli', 'Ean', '7', 'jusmug@yahoo.com', 'e.sennoga@afdb.org', 'MS', 'Concert Band 2023', 'ekimuli29@isk.ac.ke'),
	(542, 11904, 'Jensen', 'Emiliana', '8', 'amag32@gmail.com', 'jonathon.jensen@gmail.com', 'MS', 'Concert Band 2023', 'ejensen28@isk.ac.ke'),
	(72, 12171, 'Biafore', 'Giancarlo', '8', 'nermil@gmail.com', 'montiforce@gmail.com', 'MS', 'Concert Band 2023', 'gbiafore28@isk.ac.ke'),
	(124, 10475, 'Awori', 'Joan', '8', 'Annmarieawori@gmail.com', 'Michael.awori@gmail.com', 'MS', 'Concert Band 2023', 'jawori28@isk.ac.ke'),
	(312, 12196, 'Herman-Roloff', 'Keza', '7', 'amykateherman@hotmail.com', 'khermanroloff@gmail.com', 'MS', 'Concert Band 2023', 'kherman-roloff29@isk.ac.ke'),
	(194, 10493, 'Jayaram', 'Milan', '7', 'sonali.murthy@gmail.com', 'kartik_j@yahoo.com', 'MS', 'Concert Band 2023', 'mijayaram29@isk.ac.ke'),
	(543, 11926, 'Jensen', 'Nickolas', '8', 'amag32@gmail.com', 'jonathon.jensen@gmail.com', 'MS', 'Concert Band 2023', 'njensen28@isk.ac.ke'),
	(882, 12597, 'Waalewijn', 'Noam', '8', 'manonwaalewijn@gmail.com', 'manonenpieter@gmail.com', 'MS', 'Concert Band 2023', 'nwaalewijn28@isk.ac.ke'),
	(384, 12853, 'Plunkett', 'Wataru', '7', 'makiplunkett@live.jp', 'jplun585@gmail.com', 'MS', 'Concert Band 2023', 'wplunkett29@isk.ac.ke'),
	(622, 11996, 'Buksh', 'Sultan', '8', 'aarif@ifc.org', NULL, 'MS', NULL, NULL),
	(766, 12852, 'Moons', 'Olivia', '4', 'kasia@laud.nl', 'leander@laud.nl', 'ES', NULL, NULL),
	(996, 13080, 'Nam', 'Seung Hyun', '6', 'hope7993@qq.com', 'sknam@mofa.go.kr', 'MS', 'Beginning Band 7 2023', 'shyun-nam30@isk.ac.ke'),
	(988, 13007, 'Cherickel', 'Tanay', '6', 'urpmathew@gmail.com', 'cherickel@gmail.com', 'MS', 'Beginning Band 7 2023', 'tcherickel30@isk.ac.ke'),
	(990, 12616, 'Khalid', 'Zayn', '6', 'aryana.c.khalid@gmail.com', 'waqqas.khalid@gmail.com', 'MS', 'Beginning Band 8 - 2023', 'zkhalid30@isk.ac.ke'),
	(992, 12621, 'Meyers', 'Balazs', '6', 'krisztina.meyers@gmail.com', 'jemeyers@usaid.gov', 'MS', 'Beginning Band 8 - 2023', 'bmeyers30@isk.ac.ke'),
	(995, 12761, 'Muneeb', 'Mahdiyah', '6', 'libra_779@hotmail.com', 'muneeb_bakhshi@hotmail.com', 'MS', 'Beginning Band 8 - 2023', 'mmuneeb30@isk.ac.ke'),
	(986, 13050, 'Birschbach', 'Mapalo', '6', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'MS', 'Beginning Band 1 2023', 'mbirschbach30@isk.ac.ke'),
	(994, 11622, 'Mulema', 'Anastasia', '6', 'a.abenakyo@gmail.com', 'jmulema@cabi.org', 'MS', 'Beginning Band 1 2023', 'amulema30@isk.ac.ke'),
	(1001, 12924, 'Carlevato', 'Etienne', '7', 'awishous@gmail.com', 'scarlevato@gmail.com', 'MS', 'Beginning Band 1 2023', 'ecarlevato29@isk.ac.ke'),
	(993, 12694, 'Mucci', 'Lauren', '6', 'crista.mcinnis@gmail.com', 'warren.mucci@gmail.com', 'MS', 'Beginning Band 7 2023', 'lmucci30@isk.ac.ke') ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(991, 12691, 'Lundell', 'Seth', '6', 'rebekahlundell@gmail.com', 'redlundell@gmail.com', 'MS', 'Beginning Band 7 2023', 'slundell30@isk.ac.ke'),
	(989, 12973, 'Hobbs', 'Evyn', '6', 'ywhobbs@yahoo.com', 'hbhobbs95@gmail.com', 'MS', 'Beginning Band 1 2023', 'ehobbs30@isk.ac.ke'),
	(1006, 12997, 'Joymungul', 'Nirvi', '7', 'sikam04@yahoo.com', 's.joymungul@afdb.org', 'MS', 'Concert Band 2023', 'njoymungul29@isk.ac.ke'),
	(971, 11954, 'Menkerios', 'Safiya', '4', 'oh_hassan@hotmail.com', 'hmenkerios@aol.com', 'ES', NULL, NULL),
	(972, 12622, 'Meyers', 'Tamas', '4', 'krisztina.meyers@gmail.com', 'jemeyers@usaid.gov', 'ES', NULL, NULL),
	(973, 12695, 'Mucci', 'Arianna', '4', 'crista.mcinnis@gmail.com', 'warren.mucci@gmail.com', 'ES', NULL, NULL),
	(974, 12686, 'Oberjuerge', 'Graham', '4', 'kateharris22@gmail.com', 'loberjue@gmail.com', 'ES', NULL, NULL),
	(975, 12816, 'Ryan', 'Patrick', '4', 'jemichler@gmail.com', 'dpryan999@gmail.com', 'ES', NULL, NULL),
	(976, 12839, 'Schrader', 'Penelope', '4', 'schraderhub@gmail.com', 'schraderjp09@gmail.com', 'ES', NULL, NULL),
	(977, 12887, 'Von Platen-Hallermund', 'Rebecca', '4', 'mspliid@gmail.com', 'thobobs@hotmail.com', 'ES', NULL, NULL),
	(978, 12577, 'Chappell', 'Sebastian', '5', 'mgorzelanska@usaid.gov', 'jchappell@usaid.gov', 'ES', NULL, NULL),
	(979, 12935, 'Fritts', 'Alayna', '5', 'frittsalexa@gmail.com', 'jfrittsdc@gmail.com', 'ES', NULL, NULL),
	(980, 12676, 'Janisse', 'Riley', '5', 'katlawlor@icloud.com', 'marcjanisse@icloud.com', 'ES', NULL, NULL),
	(981, 12327, 'Johnson', 'Adam', '5', 'ameenahbsaleem@gmail.com', 'ibnabu@aol.com', 'ES', NULL, NULL),
	(982, 12692, 'Lundell', 'Elijah', '5', 'rebekahlundell@gmail.com', 'redlundell@gmail.com', 'ES', NULL, NULL),
	(983, 12700, 'Mpatswe', 'Johannah', '5', 'olivia.mutambo19@gmail.com', 'gkmpatswe@gmail.com', 'ES', NULL, NULL),
	(984, 12913, 'Bergqvist', 'Bella', '6', 'moa.m.bergqvist@gmail.com', 'jbergqvist@hotmail.com', 'MS', NULL, NULL),
	(985, 12699, 'Birk', 'Bertram', '6', 'gerbir@um.dk', 'thobirk@gmail.com', 'MS', NULL, NULL),
	(987, 12923, 'Carey', 'Elijah', '6', 'twilford98@yahoo.com', 'scarey192003@yahoo.com', 'MS', NULL, NULL),
	(997, 12618, 'Ryan', 'Eva', '6', 'jemichler@gmail.com', 'dpryan999@gmail.com', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(998, 12146, 'Bagenda', 'Mitchell', '7', 'katy@katymitchell.com', 'xolani@mac.com', 'MS', NULL, NULL),
	(999, 12183, 'Breda', 'Luka', '7', 'jlbarak@hotmail.com', 'cybreda@hotmail.com', 'MS', NULL, NULL),
	(1000, 12184, 'Breda', 'Paco', '7', 'jlbarak@hotmail.com', 'cybreda@hotmail.com', 'MS', NULL, NULL),
	(1002, 12941, 'Corbin', 'Camille', '7', 'corbincf@gmail.com', 'james.corbin.pa@gmail.com', 'MS', NULL, NULL),
	(1003, 12974, 'Eldridge', 'Colin', '7', '780711th@gmail.com', 'tomheldridge@hotmail.com', 'MS', NULL, NULL),
	(1004, 11726, 'Ferede', 'Maya', '7', 'sinkineshb@gmail.com', 'fasikaf@gmail.com', 'MS', NULL, NULL),
	(1005, 12928, 'Fritts', 'Ava', '7', 'frittsalexa@gmail.com', 'jfrittsdc@gmail.com', 'MS', NULL, NULL),
	(1007, 12679, 'Kishiue', 'Mahiro', '7', 'akishiue@worldbank.org', 'jan.turkstra@gmail.com', 'MS', NULL, NULL),
	(1008, 12870, 'Lemley', 'Lola', '7', 'julielemley@gmail.com', 'johnlemley@gmail.com', 'MS', NULL, NULL),
	(1009, 12685, 'Oberjuerge', 'Wesley', '7', 'kateharris22@gmail.com', 'loberjue@gmail.com', 'MS', NULL, NULL),
	(1010, 12940, 'Sobantu', 'Nicholas', '7', 'mbemelaphi@gmail.com', 'monwabisi.sobantu@gmail.com', 'MS', NULL, NULL),
	(1011, 12943, 'Asquith', 'Elliot', '8', 'kamilla.henningsen@gmail.com', 'm.asquith@icloud.com', 'MS', NULL, NULL),
	(1012, 12450, 'Basnet', 'Anshika', '8', 'gamu_sharma@yahoo.com', 'mbasnet@iom.int', 'MS', NULL, NULL),
	(1013, 12912, 'Bergqvist', 'Fanny', '8', 'moa.m.bergqvist@gmail.com', 'jbergqvist@hotmail.com', 'MS', NULL, NULL),
	(1014, 12666, 'Cizek', 'Norah (Rebel)', '8', 'suzcizek@gmail.com', NULL, 'MS', NULL, NULL),
	(1015, 12675, 'Janisse', 'Alexa', '8', 'katlawlor@icloud.com', 'marcjanisse@icloud.com', 'MS', NULL, NULL),
	(1016, 12948, 'Mendonca-Gray', 'Tiago', '8', 'eduarda.gray@fcdo.gov.uk', 'johnathangray.1@icloud.com', 'MS', NULL, NULL),
	(1017, 12595, 'Spitler', 'Alexa', '8', 'deborah.spitler@gmail.com', 'spitlerj@gmail.com', 'MS', NULL, NULL),
	(1018, 12952, 'Sykes', 'Maia', '8', 'cate@colinsykes.com', 'mail@colinsykes.com', 'MS', NULL, NULL),
	(1019, 12848, 'Weill', 'Sonia', '8', 'robineberlin@gmail.com', 'matthew_weill@mac.com', 'MS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(1021, 12672, 'Zulberti', 'Sienna', '8', 'zjenemi@gmail.com', 'emiliano.zulberti@gmail.com', 'MS', NULL, NULL),
	(1022, 12147, 'Bagenda', 'Maya', '9', 'katy@katymitchell.com', 'xolani@mac.com', 'HS', NULL, NULL),
	(1023, 12760, 'Bakhshi', 'Muhammad Uneeb', '9', 'libra_779@hotmail.com', 'muneeb_bakhshi@hotmail.com', 'HS', NULL, NULL),
	(1024, 13058, 'Birschbach', 'Natasha', '9', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'HS', NULL, NULL),
	(1025, 12858, 'Blanc Yeo', 'Lara', '9', 'yeodeblanc@gmail.com', 'julian.blanc@gmail.com', 'HS', NULL, NULL),
	(1026, 13006, 'Cherickel', 'Jai', '9', 'urpmathew@gmail.com', 'cherickel@gmail.com', 'HS', NULL, NULL),
	(1027, 12859, 'Dalal', 'Samarth', '9', 'sapnarathi04@gmail.com', 'bharpurdalal@gmail.com', 'HS', NULL, NULL),
	(1028, 11772, 'Ephrem Yohannes', 'Dan', '9', 'berhe@unhcr.org', 'jdephi@gmail.com', 'HS', NULL, NULL),
	(1029, 12972, 'Hobbs', 'Rowan', '9', 'ywhobbs@yahoo.com', 'hbhobbs95@gmail.com', 'HS', NULL, NULL),
	(1030, 13012, 'Johansson-Desai', 'Benjamin', '9', 'karin.johansson@eeas.europa.eu', 'j.desai@email.com', 'HS', NULL, NULL),
	(1031, 12996, 'Joymungul', 'Vashnie', '9', 'sikam04@yahoo.com', 's.joymungul@afdb.org', 'HS', NULL, NULL),
	(1032, 12876, 'Kamenga', 'Sphesihle', '9', 'nompumelelo.nkosi@gmail.com', 'kamenga@gmail.com', 'HS', NULL, NULL),
	(1033, 13079, 'Nam', 'Seung Yoon', '9', 'hope7993@qq.com', 'sknam@mofa.go.kr', 'HS', NULL, NULL),
	(1034, 12983, 'Rathore', 'Ishita', '9', 'priyanka.gupta.rathore@gmail.com', 'abhishek.rathore@cgiar.org', 'HS', NULL, NULL),
	(1035, 10884, 'Rex', 'Nicholas', '9', 'helenerex@gmail.com', 'familyrex@gmail.com', 'HS', NULL, NULL),
	(1036, 12663, 'Vestergaard', 'Asbjørn', '9', 'marves@um.dk', 'elrulu@protonmail.com', 'HS', NULL, NULL),
	(1037, 12904, 'Adamec', 'Filip', '10', 'nicol_adamcova@mzv.cz', 'adamec.r@gmail.com', 'HS', NULL, NULL),
	(1038, 12569, 'Andersen', 'Solveig', '10', 'millelund@gmail.com', 'steensandersen@gmail.com', 'HS', NULL, NULL),
	(1039, 12790, 'Astier', 'Eugène', '10', 'oberegoi@yahoo.com', 'astier6@bluewin.ch', 'HS', NULL, NULL),
	(1040, 12911, 'Bergqvist', 'Elsa', '10', 'moa.m.bergqvist@gmail.com', 'jbergqvist@hotmail.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(1041, 12576, 'Chappell', 'Maximilian', '10', 'mgorzelanska@usaid.gov', 'jchappell@usaid.gov', 'HS', NULL, NULL),
	(1042, 12653, 'De Geer-Howard', 'Charlotte', '10', 'catharina_degeer@yahoo.com', 'jackhoward03@yahoo.com', 'HS', NULL, NULL),
	(1043, 13008, 'Islam', 'Aarish', '10', 'aarishsaima11@yahoo.com', 'zahed.shimul@gmail.com', 'HS', NULL, NULL),
	(1044, 13011, 'Johansson-Desai', 'Daniel', '10', 'karin.johansson@eeas.europa.eu', 'j.desai@email.com', 'HS', NULL, NULL),
	(1045, 11438, 'Lawrence', 'Dario', '10', 'dandrea.claudia@gmail.com', 'ted.lawrence65@gmail.com', 'HS', NULL, NULL),
	(1046, 12869, 'Lemley', 'Maximo', '10', 'julielemley@gmail.com', 'johnlemley@gmail.com', 'HS', NULL, NULL),
	(1047, 12555, 'Roquitte', 'Lila', '10', 'sroquitte@hotmail.com', 'tptrenkle@hotmail.com', 'HS', NULL, NULL),
	(1048, 12558, 'Scanlon', 'Mathilde', '10', 'kim@wolfenden.net', 'shane.scanlon@rescue.org', 'HS', NULL, NULL),
	(1049, 13055, 'Birschbach', 'Chisanga', '11', 'mubangabirsch@gmail.com', 'birschbachjl@state.gov', 'HS', NULL, NULL),
	(1050, 12975, 'Eldridge', 'Wade', '11', '780711th@gmail.com', 'tomheldridge@hotmail.com', 'HS', NULL, NULL),
	(1051, 11748, 'Ephrem Yohannes', 'Reem', '11', 'berhe@unhcr.org', 'jdephi@gmail.com', 'HS', NULL, NULL),
	(1052, 12971, 'Hobbs', 'Liam', '11', 'ywhobbs@yahoo.com', 'hbhobbs95@gmail.com', 'HS', NULL, NULL),
	(1053, 12991, 'Kadilli', 'Daniel', '11', 'ekadilli@unicef.org', 'bardh.kadilli@gmail.com', 'HS', NULL, NULL),
	(1054, 12749, 'Nimubona', 'Jay Austin', '11', 'jnkinabacura@gmail.com', 'boubaroy19@gmail.com', 'HS', NULL, NULL),
	(1055, 25052, 'Stabrawa', 'Anna Sophia', '11', 'stabrawaa@gmail.com', NULL, 'HS', NULL, NULL),
	(1056, 12951, 'Sykes', 'Elliot', '11', 'cate@colinsykes.com', 'mail@colinsykes.com', 'HS', NULL, NULL),
	(1057, 12628, 'Sylla', 'Lalia', '11', 'mchaidara@gmail.com', 'syllamas@gmail.com', 'HS', NULL, NULL),
	(1058, 12568, 'Valdivieso Santos', 'Camila', '11', 'metamelia@gmail.com', 'valdivieso@unfpa.org', 'HS', NULL, NULL),
	(1059, 12567, 'Wright', 'Emma', '11', 'robertsonwright@gmail.com', 'robertsonwright@gmail.com', 'HS', NULL, NULL),
	(1060, 12651, 'Ata', 'Dzidzor', '12', 'parissa.ata@gmail.com', 'a.ata@kokonetworks.com', 'HS', NULL, NULL) ON CONFLICT DO NOTHING;
INSERT INTO "public"."students" ("id", "student_number", "last_name", "first_name", "grade_level", "parent1_email", "parent2_email", "division", "class", "email") VALUES
	(1061, 12738, 'Bhandari', 'Nandini', '12', 'trpt.bhandari@googlemail.com', 'Arvind.bhandari@ke.nestle.com', 'HS', NULL, NULL),
	(1062, 12652, 'De Geer-Howard', 'Isabella', '12', 'catharina_degeer@yahoo.com', 'jackhoward03@yahoo.com', 'HS', NULL, NULL),
	(1063, 10464, 'Khan', 'Hanan', '12', 'rahilak@yahoo.com', 'imtiaz.khan@cassiacap.com', 'HS', NULL, NULL),
	(1064, 11447, 'Lawrence', 'Vincenzo', '12', 'dandrea.claudia@gmail.com', 'ted.lawrence65@gmail.com', 'HS', NULL, NULL),
	(1066, 24008, 'Lutz', 'Noah', '12', 'azents@isk.ac.ke', 'stephanlutz@worldrenew.net', 'HS', NULL, NULL),
	(1067, 10922, 'Rex', 'Julian', '12', 'helenerex@gmail.com', 'familyrex@gmail.com', 'HS', NULL, NULL),
	(1068, 12557, 'Scanlon', 'Luca', '12', 'kim@wolfenden.net', 'shane.scanlon@rescue.org', 'HS', NULL, NULL),
	(1069, 12556, 'Trenkle', 'Noah', '12', 'sroquitte@hotmail.com', 'tptrenkle@hotmail.com', 'HS', NULL, NULL),
	(1020, 12566, 'Wright', 'Theodore', '8', 'robertsonwright@gmail.com', 'robertsonwright@gmail.com', 'MS', 'Concert Band 2023', 'twright28@isk.ac.ke') ON CONFLICT DO NOTHING;


--
-- TOC entry 3918 (class 0 OID 24250)
-- Dependencies: 222
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(18, 'Hugo', 'Ashton', NULL, 'STUDENT', '11902', '6', 'MS'),
	(19, 'Theodore', 'Ashton', NULL, 'STUDENT', '11893', '9', 'HS'),
	(20, 'Vera', 'Ashton', NULL, 'STUDENT', '11896', '11', 'HS'),
	(21, 'Nathan', 'Massawe', NULL, 'STUDENT', '11932', '4', 'ES'),
	(22, 'Noah', 'Massawe', NULL, 'STUDENT', '11933', '8', 'MS'),
	(23, 'Ziv', 'Bedein', NULL, 'STUDENT', '12746', 'K', 'ES'),
	(24, 'Itai', 'Bedein', NULL, 'STUDENT', '12615', '4', 'ES'),
	(25, 'Annika', 'Purdy', NULL, 'STUDENT', '12345', '2', 'ES'),
	(26, 'Christiaan', 'Purdy', NULL, 'STUDENT', '12348', '5', 'ES'),
	(27, 'Gunnar', 'Purdy', NULL, 'STUDENT', '12349', '8', 'MS'),
	(28, 'Lana', 'Abou Hamda', NULL, 'STUDENT', '12780', '5', 'ES'),
	(29, 'Samer', 'Abou Hamda', NULL, 'STUDENT', '12779', '8', 'MS'),
	(30, 'Youssef', 'Abou Hamda', NULL, 'STUDENT', '12778', '11', 'HS'),
	(31, 'Ida-Marie', 'Andersen', NULL, 'STUDENT', '12075', '12', 'HS'),
	(32, 'Cheryl', 'Cole', NULL, 'STUDENT', '12497', '12', 'HS'),
	(33, 'Oria', 'Bunbury', NULL, 'STUDENT', '12247', 'K', 'ES'),
	(34, 'Dawon', 'Eom', NULL, 'STUDENT', '12733', '10', 'HS'),
	(35, 'Arnav', 'Mohan', NULL, 'STUDENT', '11925', '12', 'HS'),
	(36, 'Alexander', 'Roe', NULL, 'STUDENT', '12188', '7', 'MS'),
	(37, 'Elizabeth', 'Roe', NULL, 'STUDENT', '12186', '9', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(38, 'Freja', 'Lindvig', NULL, 'STUDENT', '12535', '5', 'ES'),
	(39, 'Hana', 'Linck', NULL, 'STUDENT', '12559', '12', 'HS'),
	(40, 'Sif', 'Lindvig', NULL, 'STUDENT', '12502', '8', 'MS'),
	(41, 'Mimer', 'Lindvig', NULL, 'STUDENT', '12503', '10', 'HS'),
	(42, 'Frida', 'Weurlander', NULL, 'STUDENT', '12440', '4', 'ES'),
	(43, 'Zahra', 'Singh', NULL, 'STUDENT', '11505', '9', 'HS'),
	(44, 'Dylan', 'Zhang', NULL, 'STUDENT', '12206', '1', 'ES'),
	(45, 'Carys', 'Aubrey', NULL, 'STUDENT', '11838', '8', 'MS'),
	(46, 'Evie', 'Aubrey', NULL, 'STUDENT', '10950', '12', 'HS'),
	(47, 'Raeed', 'Mahmud', NULL, 'STUDENT', '11910', '12', 'HS'),
	(48, 'Kaleb', 'Mekonnen', NULL, 'STUDENT', '11185', '5', 'ES'),
	(49, 'Yonathan', 'Mekonnen', NULL, 'STUDENT', '11015', '7', 'MS'),
	(50, 'Aya', 'Mathers', NULL, 'STUDENT', '11793', '4', 'ES'),
	(51, 'Yui', 'Mathers', NULL, 'STUDENT', '11110', '8', 'MS'),
	(52, 'Madeleine', 'Gardner', NULL, 'STUDENT', '11468', '5', 'ES'),
	(53, 'Sofia', 'Russo', NULL, 'STUDENT', '11362', '4', 'ES'),
	(54, 'Leandro', 'Russo', NULL, 'STUDENT', '11361', '8', 'MS'),
	(55, 'Gerald', 'Murathi', NULL, 'STUDENT', '11724', '4', 'ES'),
	(56, 'Megan', 'Murathi', NULL, 'STUDENT', '11735', '7', 'MS'),
	(57, 'Eunice', 'Murathi', NULL, 'STUDENT', '11736', '11', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(58, 'Abby Angelica', 'Manzano', NULL, 'STUDENT', '11479', '7', 'MS'),
	(59, 'Vilma Doret', 'Rosen', 'vrosen30@isk.ac.ke', 'STUDENT', '11763', '6', 'MS'),
	(60, 'Elizabeth', 'Gardner', 'egardner29@isk.ac.ke', 'STUDENT', '11467', '7', 'MS'),
	(61, 'Shai', 'Bedein', 'sbedein29@isk.ac.ke', 'STUDENT', '12614', '7', 'MS'),
	(62, 'Or', 'Alemu', NULL, 'STUDENT', '13005', 'K', 'ES'),
	(63, 'Lillia', 'Bellamy', NULL, 'STUDENT', '11942', '3', 'ES'),
	(64, 'Destiny', 'Ouma', NULL, 'STUDENT', '10319', '8', 'MS'),
	(65, 'Louis', 'Ronzio', NULL, 'STUDENT', '12197', '3', 'ES'),
	(66, 'George', 'Ronzio', NULL, 'STUDENT', '12199', '7', 'MS'),
	(67, 'Andre', 'Awori', NULL, 'STUDENT', '24068', '12', 'HS'),
	(68, 'Krishi', 'Shah', NULL, 'STUDENT', '12121', '10', 'HS'),
	(69, 'Isabella', 'Fisher', NULL, 'STUDENT', '11416', '9', 'HS'),
	(70, 'Charles', 'Fisher', NULL, 'STUDENT', '11415', '11', 'HS'),
	(71, 'Joy', 'Mwangi', NULL, 'STUDENT', '10557', '12', 'HS'),
	(72, 'Hassan', 'Akuete', NULL, 'STUDENT', '11985', '10', 'HS'),
	(73, 'Leul', 'Alemu', NULL, 'STUDENT', '13004', '5', 'ES'),
	(74, 'Lisa', 'Otterstedt', NULL, 'STUDENT', '12336', '12', 'HS'),
	(75, 'Helena', 'Stott', NULL, 'STUDENT', '12520', '9', 'HS'),
	(76, 'Patrick', 'Stott', NULL, 'STUDENT', '12521', '10', 'HS'),
	(77, 'Isla', 'Kimani', NULL, 'STUDENT', '12397', 'K', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(78, 'Christodoulos', 'Van De Velden', NULL, 'STUDENT', '11788', '3', 'ES'),
	(79, 'Evangelia', 'Van De Velden', NULL, 'STUDENT', '10704', '7', 'MS'),
	(80, 'Sofia', 'Todd', NULL, 'STUDENT', '11731', '2', 'ES'),
	(81, 'Dominik', 'Mogilnicki', NULL, 'STUDENT', '11481', '5', 'ES'),
	(82, 'Kieran', 'Echalar', NULL, 'STUDENT', '12723', '1', 'ES'),
	(83, 'Liam', 'Echalar', NULL, 'STUDENT', '11882', '4', 'ES'),
	(84, 'Nova', 'Wilkes', NULL, 'STUDENT', '12750', 'PK', 'ES'),
	(85, 'Maximilian', 'Freiherr Von Handel', NULL, 'STUDENT', '12095', '11', 'HS'),
	(86, 'Lucas', 'Lopez Abella', NULL, 'STUDENT', '11759', '3', 'ES'),
	(87, 'Mara', 'Lopez Abella', NULL, 'STUDENT', '11819', '5', 'ES'),
	(88, 'Cassius', 'Miller', NULL, 'STUDENT', '27007', '9', 'HS'),
	(89, 'Albert', 'Miller', NULL, 'STUDENT', '25051', '11', 'HS'),
	(90, 'Axel', 'Rose', NULL, 'STUDENT', '12753', 'PK', 'ES'),
	(91, 'Evelyn', 'James', NULL, 'STUDENT', '10843', '5', 'ES'),
	(92, 'Ellis', 'Sudra', NULL, 'STUDENT', '11941', '1', 'ES'),
	(93, 'Arav', 'Shah', NULL, 'STUDENT', '10784', '7', 'MS'),
	(94, 'Lucia', 'Thornton', NULL, 'STUDENT', '12993', '5', 'ES'),
	(95, 'Robert', 'Thornton', NULL, 'STUDENT', '12992', '7', 'MS'),
	(96, 'Jeongu', 'Yun', NULL, 'STUDENT', '12492', '2', 'ES'),
	(97, 'Geonu', 'Yun', NULL, 'STUDENT', '12487', '3', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(98, 'David', 'Carter', NULL, 'STUDENT', '11937', '8', 'MS'),
	(99, 'Gabrielle', 'Willis', NULL, 'STUDENT', '12970', '5', 'ES'),
	(100, 'Julian', 'Schmidlin Guerrero', NULL, 'STUDENT', '11803', '5', 'ES'),
	(101, 'Malaika', 'Awori', NULL, 'STUDENT', '10476', '8', 'MS'),
	(102, 'Aarav', 'Sagar', NULL, 'STUDENT', '12248', '1', 'ES'),
	(103, 'Indira', 'Sheridan', NULL, 'STUDENT', '11592', '10', 'HS'),
	(104, 'Erika', 'Sheridan', NULL, 'STUDENT', '11591', '12', 'HS'),
	(105, 'Téa', 'Andries-Munshi', NULL, 'STUDENT', '12798', 'K', 'ES'),
	(106, 'Zaha', 'Andries-Munshi', NULL, 'STUDENT', '12788', '3', 'ES'),
	(107, 'Samir', 'Wallbridge', NULL, 'STUDENT', '10841', '5', 'ES'),
	(108, 'Lylah', 'Wallbridge', NULL, 'STUDENT', '20867', '8', 'MS'),
	(109, 'Oscar', 'Ansell', NULL, 'STUDENT', '12134', '9', 'HS'),
	(110, 'Louise', 'Ansell', NULL, 'STUDENT', '11852', '10', 'HS'),
	(111, 'Omar', 'Harris Ii', NULL, 'STUDENT', '12625', '11', 'HS'),
	(112, 'Boele', 'Hissink', NULL, 'STUDENT', '11003', '5', 'ES'),
	(113, 'Pomeline', 'Hissink', NULL, 'STUDENT', '10683', '7', 'MS'),
	(114, 'Maartje', 'Stott', 'mstott30@isk.ac.ke', 'STUDENT', '12519', '6', 'MS'),
	(115, 'Owen', 'Harris', 'oharris30@isk.ac.ke', 'STUDENT', '12609', '6', 'MS'),
	(116, 'Alexander', 'Mogilnicki', 'amogilnicki29@isk.ac.ke', 'STUDENT', '11480', '7', 'MS'),
	(117, 'Cahir', 'Patel', 'cpatel29@isk.ac.ke', 'STUDENT', '10772', '7', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(118, 'Ehsan', 'Akuete', 'eakuete28@isk.ac.ke', 'STUDENT', '12156', '8', 'MS'),
	(119, 'Ismail', 'Liban', NULL, 'STUDENT', '11647', '7', 'MS'),
	(120, 'Shreya', 'Tanna', NULL, 'STUDENT', '10703', '8', 'MS'),
	(121, 'Samuel', 'Clark', NULL, 'STUDENT', '13049', '4', 'ES'),
	(122, 'Ohad', 'Yarkoni', NULL, 'STUDENT', '12167', '3', 'ES'),
	(123, 'Matan', 'Yarkoni', NULL, 'STUDENT', '12168', '5', 'ES'),
	(124, 'Itay', 'Yarkoni', NULL, 'STUDENT', '12169', '8', 'MS'),
	(125, 'Yen', 'Nguyen', NULL, 'STUDENT', '11672', '7', 'MS'),
	(126, 'Binh', 'Nguyen', NULL, 'STUDENT', '11671', '9', 'HS'),
	(127, 'Shams', 'Hussain', NULL, 'STUDENT', '11496', '3', 'ES'),
	(128, 'Salam', 'Hussain', NULL, 'STUDENT', '11495', '4', 'ES'),
	(129, 'Basile', 'Pozzi', NULL, 'STUDENT', '10275', '12', 'HS'),
	(130, 'Ibrahim', 'Ibrahim', NULL, 'STUDENT', '11666', '12', 'HS'),
	(131, 'Mateo', 'Lopez Salazar', NULL, 'STUDENT', '12752', 'K', 'ES'),
	(132, 'Benjamin', 'Godfrey', NULL, 'STUDENT', '11242', '5', 'ES'),
	(133, 'Jamal', 'Sana', NULL, 'STUDENT', '11525', '11', 'HS'),
	(134, 'Saba', 'Feizzadeh', NULL, 'STUDENT', '12872', '4', 'ES'),
	(135, 'Kasra', 'Feizzadeh', NULL, 'STUDENT', '12871', '9', 'HS'),
	(136, 'Kayla', 'Fazal', NULL, 'STUDENT', '12201', '6', 'MS'),
	(137, 'Alyssia', 'Fazal', NULL, 'STUDENT', '11878', '8', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(138, 'Chloe', 'Foster', NULL, 'STUDENT', '11530', '11', 'HS'),
	(139, 'Joyous', 'Miyanue', NULL, 'STUDENT', '11582', '10', 'HS'),
	(140, 'Marvelous Peace', 'Nkahnue', NULL, 'STUDENT', '11583', '12', 'HS'),
	(141, 'Rafaelle', 'Patella Ross', NULL, 'STUDENT', '10707', '7', 'MS'),
	(142, 'Juna', 'Patella Ross', NULL, 'STUDENT', '10617', '10', 'HS'),
	(143, 'Tyler', 'Good', NULL, 'STUDENT', '12879', '4', 'ES'),
	(144, 'Julia', 'Good', NULL, 'STUDENT', '12878', '8', 'MS'),
	(145, 'Maria-Antonina (Jay)', 'Biesiada', NULL, 'STUDENT', '11723', '10', 'HS'),
	(146, 'Ben', 'Nannes', NULL, 'STUDENT', '10980', '9', 'HS'),
	(147, 'Kaiam', 'Hajee', NULL, 'STUDENT', '11520', '5', 'ES'),
	(148, 'Kadin', 'Hajee', NULL, 'STUDENT', '11542', '7', 'MS'),
	(149, 'Kahara', 'Hajee', NULL, 'STUDENT', '11541', '8', 'MS'),
	(150, 'Maria', 'Gebremedhin', NULL, 'STUDENT', '10688', '6', 'MS'),
	(151, 'Rainey', 'Copeland', NULL, 'STUDENT', '12003', '12', 'HS'),
	(152, 'Zawadi', 'Ndinguri', NULL, 'STUDENT', '11936', '5', 'ES'),
	(153, 'Max', 'De Jong', NULL, 'STUDENT', '24001', '11', 'HS'),
	(154, 'Maximiliano', 'Davis - Arana', NULL, 'STUDENT', '12372', '1', 'ES'),
	(155, 'Emilia', 'Nicolau Meganck', NULL, 'STUDENT', '12797', 'K', 'ES'),
	(156, 'Zane', 'Anding', NULL, 'STUDENT', '10968', '11', 'HS'),
	(157, 'Otis', 'Rogers', NULL, 'STUDENT', '11940', '1', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(158, 'Liam', 'Rogers', NULL, 'STUDENT', '12744', 'PK', 'ES'),
	(159, 'Teagan', 'Wood', NULL, 'STUDENT', '10972', '9', 'HS'),
	(160, 'Caitlin', 'Wood', NULL, 'STUDENT', '10934', '11', 'HS'),
	(161, 'Anusha', 'Masrani', NULL, 'STUDENT', '10632', '8', 'MS'),
	(162, 'Jin', 'Handa', NULL, 'STUDENT', '10641', '10', 'HS'),
	(163, 'Lina', 'Fest', NULL, 'STUDENT', '10279', '11', 'HS'),
	(164, 'Marie', 'Fest', NULL, 'STUDENT', '10278', '11', 'HS'),
	(165, 'Divyaan', 'Ramrakha', NULL, 'STUDENT', '11830', '7', 'MS'),
	(166, 'Niyam', 'Ramrakha', NULL, 'STUDENT', '11379', '10', 'HS'),
	(167, 'Akeyo', 'Jayaram', NULL, 'STUDENT', '11404', '3', 'ES'),
	(168, 'Gendhis', 'Sapta', NULL, 'STUDENT', '10320', '8', 'MS'),
	(169, 'Kianna', 'Venkataya', NULL, 'STUDENT', '12706', '4', 'ES'),
	(170, 'Taegan', 'Line', NULL, 'STUDENT', '11627', '7', 'MS'),
	(171, 'Bronwyn', 'Line', NULL, 'STUDENT', '11626', '9', 'HS'),
	(172, 'Jamison', 'Line', NULL, 'STUDENT', '11625', '11', 'HS'),
	(173, 'Tangaaza', 'Mujuni', NULL, 'STUDENT', '10788', '7', 'MS'),
	(174, 'Rugaba', 'Mujuni', NULL, 'STUDENT', '20828', '10', 'HS'),
	(175, 'Laia', 'Guyard Suengas', NULL, 'STUDENT', '20805', '11', 'HS'),
	(176, 'Lucile', 'Bamlango', 'lbamlango30@isk.ac.ke', 'STUDENT', '10977', '6', 'MS'),
	(177, 'Tawheed', 'Hussain', 'thussain30@isk.ac.ke', 'STUDENT', '11469', '6', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(178, 'Florencia', 'Anding', 'fanding28@isk.ac.ke', 'STUDENT', '10967', '8', 'MS'),
	(179, 'Tobias', 'Godfrey', 'tgodfrey29@isk.ac.ke', 'STUDENT', '11227', '7', 'MS'),
	(180, 'Zeeon', 'Ahmed', NULL, 'STUDENT', '11570', '12', 'HS'),
	(181, 'Emily', 'Haswell', NULL, 'STUDENT', '27066', '8', 'MS'),
	(182, 'Yago', 'Dalla Vedova Sanjuan', NULL, 'STUDENT', '12444', '12', 'HS'),
	(183, 'Ariana', 'Choda', NULL, 'STUDENT', '10973', '10', 'HS'),
	(184, 'Isabella', 'Schmid', NULL, 'STUDENT', '10974', '11', 'HS'),
	(185, 'Sophia', 'Schmid', NULL, 'STUDENT', '10975', '11', 'HS'),
	(186, 'Kai', 'Ernst', NULL, 'STUDENT', '13043', 'K', 'ES'),
	(187, 'Aika', 'Ernst', NULL, 'STUDENT', '11628', '3', 'ES'),
	(188, 'Amira', 'Varga', NULL, 'STUDENT', '11705', '5', 'ES'),
	(189, 'Jonah', 'Veverka', NULL, 'STUDENT', '12835', 'K', 'ES'),
	(190, 'Theocles', 'Veverka', NULL, 'STUDENT', '12838', '2', 'ES'),
	(191, 'Adam-Angelo', 'Sankoh', NULL, 'STUDENT', '12441', '3', 'ES'),
	(192, 'Mwende', 'Mittelstadt', NULL, 'STUDENT', '11098', '10', 'HS'),
	(193, 'Miles', 'Charette', NULL, 'STUDENT', '20780', '9', 'HS'),
	(194, 'Tea', 'Charette', NULL, 'STUDENT', '20781', '12', 'HS'),
	(195, 'Drew (Tilly)', 'Giblin', NULL, 'STUDENT', '12963', '2', 'ES'),
	(196, 'Auberlin (Addie)', 'Giblin', NULL, 'STUDENT', '12964', '7', 'MS'),
	(197, 'Ryan', 'Burns', NULL, 'STUDENT', '11199', '12', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(198, 'Bella', 'Jama', NULL, 'STUDENT', '12457', '1', 'ES'),
	(199, 'Ari', 'Jama', NULL, 'STUDENT', '12452', '3', 'ES'),
	(200, 'Isaiah', 'Marriott', NULL, 'STUDENT', '11572', '12', 'HS'),
	(201, 'Sianna', 'Byrne-Ilako', NULL, 'STUDENT', '11751', '11', 'HS'),
	(202, 'Camden', 'Teel', NULL, 'STUDENT', '12360', '4', 'ES'),
	(203, 'Jaidyn', 'Teel', NULL, 'STUDENT', '12361', '6', 'MS'),
	(204, 'Lukas', 'Eshetu', NULL, 'STUDENT', '12793', '9', 'HS'),
	(205, 'Dylan', 'Okanda', NULL, 'STUDENT', '11511', '9', 'HS'),
	(206, 'Sasha', 'Blaschke', NULL, 'STUDENT', '11599', '4', 'ES'),
	(207, 'Kaitlyn', 'Blaschke', NULL, 'STUDENT', '11052', '6', 'MS'),
	(208, 'Georges', 'Marin Fonseca Choucair Ramos', NULL, 'STUDENT', '12789', '3', 'ES'),
	(209, 'Maaya', 'Kobayashi', NULL, 'STUDENT', '11575', '5', 'ES'),
	(210, 'Isabel', 'Hansen Meiro', NULL, 'STUDENT', '11943', '5', 'ES'),
	(211, 'Finley', 'Eckert-Crosse', NULL, 'STUDENT', '11568', '4', 'ES'),
	(212, 'Mohammad Haroon', 'Bajwa', NULL, 'STUDENT', '10941', '8', 'MS'),
	(213, 'Erik', 'Suther', NULL, 'STUDENT', '10511', '7', 'MS'),
	(214, 'Aarav', 'Chandaria', NULL, 'STUDENT', '11792', '4', 'ES'),
	(215, 'Aarini Vijay', 'Chandaria', NULL, 'STUDENT', '10338', '9', 'HS'),
	(216, 'Leo', 'Korvenoja', NULL, 'STUDENT', '11526', '11', 'HS'),
	(217, 'Mandisa', 'Mathew', NULL, 'STUDENT', '10881', '12', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(218, 'Hafsa', 'Ahmed', NULL, 'STUDENT', '12158', '8', 'MS'),
	(219, 'Mariam', 'Ahmed', NULL, 'STUDENT', '12159', '8', 'MS'),
	(220, 'Osman', 'Ahmed', NULL, 'STUDENT', '11745', '12', 'HS'),
	(221, 'Tessa', 'Steel', NULL, 'STUDENT', '12116', '10', 'HS'),
	(222, 'Ethan', 'Steel', NULL, 'STUDENT', '11442', '12', 'HS'),
	(223, 'Brianna', 'Otieno', NULL, 'STUDENT', '11271', '8', 'MS'),
	(224, 'Sohum', 'Bid', NULL, 'STUDENT', '13042', 'K', 'ES'),
	(225, 'Yara', 'Janmohamed', NULL, 'STUDENT', '12173', '4', 'ES'),
	(226, 'Aila', 'Janmohamed', NULL, 'STUDENT', '12174', '8', 'MS'),
	(227, 'Rwenzori', 'Rogers', NULL, 'STUDENT', '12208', '4', 'ES'),
	(228, 'Junin', 'Rogers', NULL, 'STUDENT', '12209', '5', 'ES'),
	(229, 'Jasmine', 'Schoneveld', NULL, 'STUDENT', '11879', '3', 'ES'),
	(230, 'Hiyabel', 'Kefela', NULL, 'STUDENT', '11444', '12', 'HS'),
	(231, 'Arra', 'Manji', NULL, 'STUDENT', '12416', '4', 'ES'),
	(232, 'Deesha', 'Shah', NULL, 'STUDENT', '12108', '10', 'HS'),
	(233, 'Sidh', 'Rughani', NULL, 'STUDENT', '10770', '9', 'HS'),
	(234, 'Sohil', 'Chandaria', NULL, 'STUDENT', '12124', '10', 'HS'),
	(235, 'Imara', 'Patel', NULL, 'STUDENT', '12275', '11', 'HS'),
	(236, 'Riyaan', 'Wissanji', NULL, 'STUDENT', '11437', '10', 'HS'),
	(237, 'Mikayla', 'Wissanji', NULL, 'STUDENT', '11440', '12', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(238, 'Leti', 'Bwonya', NULL, 'STUDENT', '12270', '12', 'HS'),
	(239, 'Stefanie', 'Landolt', 'slandolt30@isk.ac.ke', 'STUDENT', '12286', '6', 'MS'),
	(240, 'Arhum', 'Bid', 'abid30@isk.ac.ke', 'STUDENT', '11706', '6', 'MS'),
	(241, 'Hawi', 'Okwany', 'hokwany29@isk.ac.ke', 'STUDENT', '10696', '7', 'MS'),
	(242, 'Mairi', 'Kurauchi', NULL, 'STUDENT', '11491', '3', 'ES'),
	(243, 'Meiya', 'Chandaria', NULL, 'STUDENT', '10932', '5', 'ES'),
	(244, 'Aiden', 'Inwani', NULL, 'STUDENT', '12531', '11', 'HS'),
	(245, 'Nirvaan', 'Shah', NULL, 'STUDENT', '10774', '12', 'HS'),
	(246, 'Ziya', 'Butt', NULL, 'STUDENT', '11401', '9', 'HS'),
	(247, 'Sofia', 'Shamji', NULL, 'STUDENT', '11839', '8', 'MS'),
	(248, 'Oumi', 'Tall', NULL, 'STUDENT', '11472', '5', 'ES'),
	(249, 'Yasmin', 'Price-Abdi', NULL, 'STUDENT', '10487', '12', 'HS'),
	(250, 'Kaitlyn', 'Fort', NULL, 'STUDENT', '11704', '3', 'ES'),
	(251, 'Keiya', 'Raja', NULL, 'STUDENT', '10637', '8', 'MS'),
	(252, 'Ryka', 'Shah', NULL, 'STUDENT', '10955', '12', 'HS'),
	(253, 'Ruby', 'Muoki', NULL, 'STUDENT', '12278', '11', 'HS'),
	(254, 'Siana', 'Chandaria', NULL, 'STUDENT', '25072', '11', 'HS'),
	(255, 'Tatyana', 'Wangari', NULL, 'STUDENT', '11877', '12', 'HS'),
	(256, 'Sohan', 'Shah', NULL, 'STUDENT', '11190', '12', 'HS'),
	(257, 'Zameer', 'Nanji', NULL, 'STUDENT', '10416', '9', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(258, 'Esther', 'Paul', NULL, 'STUDENT', '11326', '8', 'MS'),
	(259, 'Liam', 'Sanders', NULL, 'STUDENT', '10430', '10', 'HS'),
	(260, 'Teresa', 'Sanders', NULL, 'STUDENT', '10431', '12', 'HS'),
	(261, 'Sarah', 'Melson', NULL, 'STUDENT', '12132', '9', 'HS'),
	(262, 'Kaysan Karim', 'Kurji', NULL, 'STUDENT', '12229', '3', 'ES'),
	(263, 'Ashi', 'Doshi', NULL, 'STUDENT', '11768', '4', 'ES'),
	(264, 'Anay', 'Doshi', NULL, 'STUDENT', '10636', '8', 'MS'),
	(265, 'Bianca', 'Bini', NULL, 'STUDENT', '12731', '2', 'ES'),
	(266, 'Otis', 'Cutler', NULL, 'STUDENT', '11535', '4', 'ES'),
	(267, 'Leo', 'Cutler', NULL, 'STUDENT', '10673', '9', 'HS'),
	(268, 'Andrew', 'Wachira', NULL, 'STUDENT', '20866', '10', 'HS'),
	(269, 'Jordan', 'Nzioka', NULL, 'STUDENT', '11884', '2', 'ES'),
	(270, 'Zuriel', 'Nzioka', NULL, 'STUDENT', '11313', '4', 'ES'),
	(271, 'Radek Tidi', 'Otieno', NULL, 'STUDENT', '10865', '5', 'ES'),
	(272, 'Ranam Telu', 'Otieno', NULL, 'STUDENT', '10943', '5', 'ES'),
	(273, 'Riani Tunu', 'Otieno', NULL, 'STUDENT', '10866', '5', 'ES'),
	(274, 'Sachin', 'Weaver', NULL, 'STUDENT', '10715', '11', 'HS'),
	(275, 'Mark', 'Landolt', NULL, 'STUDENT', '12284', '8', 'MS'),
	(276, 'Kianu', 'Ruiz Stannah', NULL, 'STUDENT', '10247', '7', 'MS'),
	(277, 'Tamia', 'Ruiz Stannah', NULL, 'STUDENT', '25032', '11', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(278, 'Ahmad Eissa', 'Noordin', NULL, 'STUDENT', '11611', '4', 'ES'),
	(279, 'Lily', 'Herman-Roloff', NULL, 'STUDENT', '12194', '3', 'ES'),
	(280, 'Shela', 'Herman-Roloff', NULL, 'STUDENT', '12195', '5', 'ES'),
	(281, 'Bruke', 'Baheta', NULL, 'STUDENT', '10800', '8', 'MS'),
	(282, 'Helina', 'Baheta', NULL, 'STUDENT', '20766', '11', 'HS'),
	(283, 'Jonathan', 'Bjornholm', NULL, 'STUDENT', '11040', '11', 'HS'),
	(284, 'Rose', 'Vellenga', NULL, 'STUDENT', '11574', '4', 'ES'),
	(285, 'Solomon', 'Vellenga', NULL, 'STUDENT', '11573', '5', 'ES'),
	(286, 'Ishaan', 'Patel', NULL, 'STUDENT', '11255', '4', 'ES'),
	(287, 'Ciaran', 'Clements', NULL, 'STUDENT', '11843', '8', 'MS'),
	(288, 'Ahana', 'Nair', NULL, 'STUDENT', '12332', '1', 'ES'),
	(289, 'Aryaan', 'Pattni', NULL, 'STUDENT', '11729', '4', 'ES'),
	(290, 'Hana', 'Boxer', NULL, 'STUDENT', '11200', '11', 'HS'),
	(291, 'Parth', 'Shah', NULL, 'STUDENT', '10993', '10', 'HS'),
	(292, 'Layla', 'Khubchandani', NULL, 'STUDENT', '11263', '9', 'HS'),
	(293, 'Nikhil', 'Patel', NULL, 'STUDENT', '12494', '1', 'ES'),
	(294, 'Janak', 'Shah', NULL, 'STUDENT', '10830', '11', 'HS'),
	(295, 'Saba', 'Tunbridge', NULL, 'STUDENT', '10645', '12', 'HS'),
	(296, 'Shriya', 'Manek', NULL, 'STUDENT', '11777', '11', 'HS'),
	(297, 'Diane', 'Bamlango', NULL, 'STUDENT', '12371', 'K', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(298, 'Ayana', 'Butt', 'abutt30@isk.ac.ke', 'STUDENT', '11402', '6', 'MS'),
	(299, 'Connor', 'Fort', 'cfort30@isk.ac.ke', 'STUDENT', '11650', '6', 'MS'),
	(300, 'Ochieng', 'Simbiri', 'osimbiri30@isk.ac.ke', 'STUDENT', '11265', '6', 'MS'),
	(301, 'Fatuma', 'Tall', 'ftall28@isk.ac.ke', 'STUDENT', '11515', '8', 'MS'),
	(302, 'Jana', 'Landolt', 'jlandolt28@isk.ac.ke', 'STUDENT', '12285', '8', 'MS'),
	(303, 'Cecile', 'Bamlango', NULL, 'STUDENT', '10979', '11', 'HS'),
	(304, 'Vanaaya', 'Patel', NULL, 'STUDENT', '20839', '9', 'HS'),
	(305, 'Veer', 'Patel', NULL, 'STUDENT', '20840', '9', 'HS'),
	(306, 'Laina', 'Shah', NULL, 'STUDENT', '11502', '4', 'ES'),
	(307, 'Savir', 'Shah', NULL, 'STUDENT', '10965', '7', 'MS'),
	(308, 'Nikolaj', 'Vestergaard', NULL, 'STUDENT', '11789', '3', 'ES'),
	(309, 'Kian', 'Allport', NULL, 'STUDENT', '11445', '12', 'HS'),
	(310, 'Reid', 'Hagelberg', NULL, 'STUDENT', '12094', '9', 'HS'),
	(311, 'Zoe Rose', 'Hagelberg', NULL, 'STUDENT', '12077', '11', 'HS'),
	(312, 'Juju', 'Kimmelman-May', NULL, 'STUDENT', '12354', '4', 'ES'),
	(313, 'Chloe', 'Kimmelman-May', NULL, 'STUDENT', '12353', '8', 'MS'),
	(314, 'Tara', 'Uberoi', NULL, 'STUDENT', '11452', '11', 'HS'),
	(315, 'Chansa', 'Mwenya', NULL, 'STUDENT', '24018', '12', 'HS'),
	(316, 'Liam', 'Patel', NULL, 'STUDENT', '11486', '4', 'ES'),
	(317, 'Shane', 'Patel', NULL, 'STUDENT', '10138', '8', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(318, 'Rhiyana', 'Patel', NULL, 'STUDENT', '26025', '10', 'HS'),
	(319, 'Yash', 'Pattni', NULL, 'STUDENT', '10334', '7', 'MS'),
	(320, 'Gaurav', 'Samani', NULL, 'STUDENT', '11179', '5', 'ES'),
	(321, 'Siddharth', 'Samani', NULL, 'STUDENT', '11180', '5', 'ES'),
	(322, 'Kiara', 'Bhandari', NULL, 'STUDENT', '10791', '9', 'HS'),
	(323, 'Safa', 'Monadjem', NULL, 'STUDENT', '12224', '3', 'ES'),
	(324, 'Malaika', 'Monadjem', NULL, 'STUDENT', '25076', '11', 'HS'),
	(325, 'Sam', 'Khagram', NULL, 'STUDENT', '11858', '10', 'HS'),
	(326, 'Radha', 'Shah', NULL, 'STUDENT', '10786', '7', 'MS'),
	(327, 'Vishnu', 'Shah', NULL, 'STUDENT', '10796', '10', 'HS'),
	(328, 'Cuyuni', 'Khan', NULL, 'STUDENT', '12013', '10', 'HS'),
	(329, 'Lengai', 'Inglis', NULL, 'STUDENT', '12131', '9', 'HS'),
	(330, 'Mathias', 'Yohannes', NULL, 'STUDENT', '20875', '10', 'HS'),
	(331, 'Avish', 'Arora', NULL, 'STUDENT', '12129', '9', 'HS'),
	(332, 'Saptha Girish', 'Bommadevara', NULL, 'STUDENT', '10504', '10', 'HS'),
	(333, 'Sharmila Devi', 'Bommadevara', NULL, 'STUDENT', '10505', '12', 'HS'),
	(334, 'Adama', 'Sangare', NULL, 'STUDENT', '12309', '11', 'HS'),
	(335, 'Gabrielle', 'Trottier', NULL, 'STUDENT', '11945', '9', 'HS'),
	(336, 'Mannat', 'Suri', NULL, 'STUDENT', '11485', '4', 'ES'),
	(337, 'Armaan', 'Suri', NULL, 'STUDENT', '11076', '7', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(338, 'Zoe', 'Furness', NULL, 'STUDENT', '11101', '12', 'HS'),
	(339, 'Tandin', 'Tshomo', NULL, 'STUDENT', '12442', '7', 'MS'),
	(340, 'Thuji', 'Zangmo', NULL, 'STUDENT', '12394', '8', 'MS'),
	(341, 'Maxym', 'Berezhny', NULL, 'STUDENT', '10878', '9', 'HS'),
	(342, 'Thomas', 'Higgins', NULL, 'STUDENT', '11744', '10', 'HS'),
	(343, 'Louisa', 'Higgins', NULL, 'STUDENT', '11743', '12', 'HS'),
	(344, 'Indhira', 'Startup', NULL, 'STUDENT', '12244', '2', 'ES'),
	(345, 'Anyamarie', 'Lindgren', NULL, 'STUDENT', '11389', '8', 'MS'),
	(346, 'Takumi', 'Plunkett', NULL, 'STUDENT', '12854', '8', 'MS'),
	(347, 'Catherina', 'Gagnidze', NULL, 'STUDENT', '11556', '12', 'HS'),
	(348, 'Adam', 'Jama', NULL, 'STUDENT', '11676', '2', 'ES'),
	(349, 'Amina', 'Jama', NULL, 'STUDENT', '11675', '4', 'ES'),
	(350, 'Guled', 'Jama', NULL, 'STUDENT', '12757', '6', 'MS'),
	(351, 'Noha', 'Salituri', NULL, 'STUDENT', '12211', '1', 'ES'),
	(352, 'Amaia', 'Salituri', NULL, 'STUDENT', '12212', '4', 'ES'),
	(353, 'Leone', 'Salituri', NULL, 'STUDENT', '12213', '4', 'ES'),
	(354, 'Sorawit (Nico)', 'Thongmod', NULL, 'STUDENT', '12214', '5', 'ES'),
	(355, 'Henk', 'Makimei', NULL, 'STUDENT', '11860', '12', 'HS'),
	(356, 'Anaiya', 'Shah', 'ashah30@isk.ac.ke', 'STUDENT', '11264', '6', 'MS'),
	(357, 'Lilyrose', 'Trottier', 'ltrottier30@isk.ac.ke', 'STUDENT', '11944', '6', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(358, 'Lorian', 'Inglis', 'linglis30@isk.ac.ke', 'STUDENT', '12133', '6', 'MS'),
	(989, 'Patrick', 'Ryan', NULL, 'STUDENT', '12816', '4', 'ES'),
	(359, 'Anne', 'Bamlango', 'abamlango28@isk.ac.ke', 'STUDENT', '10978', '8', 'MS'),
	(360, 'Arjan', 'Arora', 'aarora28@isk.ac.ke>', 'STUDENT', '12130', '8', 'MS'),
	(361, 'Naomi', 'Yohannes', 'nyohannes29@isk.ac.ke', 'STUDENT', '10787', '7', 'MS'),
	(362, 'Mira', 'Maldonado', NULL, 'STUDENT', '11175', '10', 'HS'),
	(363, 'Che', 'Maldonado', NULL, 'STUDENT', '11170', '12', 'HS'),
	(364, 'Phuong An', 'Nguyen', NULL, 'STUDENT', '11261', '4', 'ES'),
	(365, 'Charlotte', 'Smith', NULL, 'STUDENT', '12705', '4', 'ES'),
	(366, 'Olivia', 'Von Strauss', NULL, 'STUDENT', '12719', '1', 'ES'),
	(367, 'Gabriel', 'Petrangeli', NULL, 'STUDENT', '11009', '12', 'HS'),
	(368, 'Jihwan', 'Hwang', NULL, 'STUDENT', '11951', '5', 'ES'),
	(369, 'Anneka', 'Hornor', NULL, 'STUDENT', '12377', '10', 'HS'),
	(370, 'Florencia', 'Veveiros', NULL, 'STUDENT', '12008', '5', 'ES'),
	(371, 'Xavier', 'Veveiros', NULL, 'STUDENT', '12009', '10', 'HS'),
	(372, 'Laras', 'Clark', NULL, 'STUDENT', '11786', '3', 'ES'),
	(373, 'Galuh', 'Clark', NULL, 'STUDENT', '11787', '7', 'MS'),
	(374, 'Miriam', 'Schwabel', NULL, 'STUDENT', '12267', '12', 'HS'),
	(375, 'Ben', 'Gremley', NULL, 'STUDENT', '12113', '10', 'HS'),
	(376, 'Calvin', 'Gremley', NULL, 'STUDENT', '12115', '10', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(377, 'Danial', 'Baig-Giannotti', NULL, 'STUDENT', '12546', '1', 'ES'),
	(378, 'Daria', 'Baig-Giannotti', NULL, 'STUDENT', '11593', '4', 'ES'),
	(379, 'Ciara', 'Jackson', NULL, 'STUDENT', '12071', '11', 'HS'),
	(380, 'Ansley', 'Nelson', NULL, 'STUDENT', '12806', '1', 'ES'),
	(381, 'Caroline', 'Nelson', NULL, 'STUDENT', '12803', '4', 'ES'),
	(382, 'Tamara', 'Wanyoike', NULL, 'STUDENT', '12658', '11', 'HS'),
	(383, 'Marcella', 'Cowan', NULL, 'STUDENT', '12437', '8', 'MS'),
	(384, 'Alisia', 'Sommerlund', NULL, 'STUDENT', '11717', '7', 'MS'),
	(385, 'Lea', 'Castel-Wang', NULL, 'STUDENT', '12507', '10', 'HS'),
	(386, 'Anisha', 'Som Chaudhuri', NULL, 'STUDENT', '12707', '4', 'ES'),
	(387, 'Gloria', 'Jacques', NULL, 'STUDENT', '12067', '11', 'HS'),
	(388, 'Dana', 'Nurshaikhova', NULL, 'STUDENT', '11938', '9', 'HS'),
	(389, 'Raheel', 'Shah', NULL, 'STUDENT', '12161', '8', 'MS'),
	(390, 'Rohan', 'Shah', NULL, 'STUDENT', '20850', '10', 'HS'),
	(391, 'Malou', 'Burmester', NULL, 'STUDENT', '11395', '5', 'ES'),
	(392, 'Nicholas', 'Burmester', NULL, 'STUDENT', '11394', '8', 'MS'),
	(393, 'Ethan', 'Sengendo', NULL, 'STUDENT', '11702', '10', 'HS'),
	(394, 'Omer', 'Osman', NULL, 'STUDENT', '12443', '1', 'ES'),
	(395, 'Felix', 'Jensen', NULL, 'STUDENT', '12238', '2', 'ES'),
	(396, 'Fiona', 'Jensen', NULL, 'STUDENT', '12237', '3', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(397, 'Andrew', 'Gerba', NULL, 'STUDENT', '11462', '7', 'MS'),
	(398, 'Madigan', 'Gerba', NULL, 'STUDENT', '11507', '9', 'HS'),
	(399, 'Porter', 'Gerba', NULL, 'STUDENT', '11449', '11', 'HS'),
	(400, 'Aaron', 'Atamuradov', NULL, 'STUDENT', '11800', '5', 'ES'),
	(401, 'Arina', 'Atamuradova', NULL, 'STUDENT', '11752', '11', 'HS'),
	(402, 'Seojun', 'Yoon', NULL, 'STUDENT', '12792', '7', 'MS'),
	(403, 'Seohyeon', 'Yoon', NULL, 'STUDENT', '12791', '9', 'HS'),
	(404, 'Sasha', 'Allard Ruiz', NULL, 'STUDENT', '11387', '12', 'HS'),
	(405, 'Ali', 'Alnaqbi', NULL, 'STUDENT', '12910', '2', 'ES'),
	(406, 'Almayasa', 'Alnaqbi', NULL, 'STUDENT', '12908', '7', 'MS'),
	(407, 'Fatima', 'Alnaqbi', NULL, 'STUDENT', '12907', '9', 'HS'),
	(408, 'Ibrahim', 'Alnaqbi', NULL, 'STUDENT', '12906', '10', 'HS'),
	(409, 'Rasmus', 'Jabbour', NULL, 'STUDENT', '12396', '1', 'ES'),
	(410, 'Olivia', 'Jabbour', NULL, 'STUDENT', '12395', '4', 'ES'),
	(411, 'Tobin', 'Allen', NULL, 'STUDENT', '12308', '9', 'HS'),
	(412, 'Corinne', 'Allen', NULL, 'STUDENT', '12307', '12', 'HS'),
	(413, 'Maya', 'Ben Anat', NULL, 'STUDENT', '12643', 'PK', 'ES'),
	(414, 'Ella', 'Ben Anat', NULL, 'STUDENT', '11475', '5', 'ES'),
	(415, 'Shira', 'Ben Anat', NULL, 'STUDENT', '11518', '8', 'MS'),
	(416, 'Amishi', 'Mishra', NULL, 'STUDENT', '12489', '12', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(417, 'Arushi', 'Mishra', NULL, 'STUDENT', '12488', '12', 'HS'),
	(418, 'Riley', 'O''neill Calver', NULL, 'STUDENT', '11488', '4', 'ES'),
	(419, 'Lukas', 'Norman', NULL, 'STUDENT', '11534', '10', 'HS'),
	(420, 'Lise', 'Norman', NULL, 'STUDENT', '11533', '12', 'HS'),
	(421, 'Phuc Anh', 'Nguyen', 'pnguyen30@isk.ac.ke', 'STUDENT', '11260', '6', 'MS'),
	(422, 'Aiden', 'Gremley', 'agremley29@isk.ac.ke', 'STUDENT', '12393', '7', 'MS'),
	(423, 'Ella', 'Sims', NULL, 'STUDENT', '24043', '12', 'HS'),
	(424, 'Sebastian', 'Wikenczy Thomsen', NULL, 'STUDENT', '11446', '11', 'HS'),
	(425, 'Logan Lilly', 'Foley', NULL, 'STUDENT', '11758', '3', 'ES'),
	(426, 'James', 'Mills', NULL, 'STUDENT', '12376', '11', 'HS'),
	(427, 'Amira', 'Goold', NULL, 'STUDENT', '11820', '5', 'ES'),
	(428, 'Micaella', 'Shenge', NULL, 'STUDENT', '11527', '6', 'MS'),
	(429, 'Siri', 'Huber', NULL, 'STUDENT', '12338', '5', 'ES'),
	(430, 'Lisa', 'Huber', NULL, 'STUDENT', '12339', '9', 'HS'),
	(431, 'Jara', 'Huber', NULL, 'STUDENT', '12340', '10', 'HS'),
	(432, 'Case', 'O''hearn', NULL, 'STUDENT', '12764', '7', 'MS'),
	(433, 'Maeve', 'O''hearn', NULL, 'STUDENT', '12763', '10', 'HS'),
	(434, 'Komborero', 'Chigudu', NULL, 'STUDENT', '11375', '5', 'ES'),
	(435, 'Munashe', 'Chigudu', NULL, 'STUDENT', '11376', '8', 'MS'),
	(436, 'Nyasha', 'Chigudu', NULL, 'STUDENT', '11373', '11', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(437, 'Kodjiro', 'Sakaedani Petrovic', NULL, 'STUDENT', '12271', '11', 'HS'),
	(438, 'Ines Clelia', 'Essoungou', NULL, 'STUDENT', '12522', '10', 'HS'),
	(439, 'Caspian', 'Mcsharry', NULL, 'STUDENT', '12562', '5', 'ES'),
	(440, 'Theodore', 'Mcsharry', NULL, 'STUDENT', '12563', '9', 'HS'),
	(441, 'Joshua', 'Exel', NULL, 'STUDENT', '12073', '10', 'HS'),
	(442, 'Hannah', 'Exel', NULL, 'STUDENT', '12074', '12', 'HS'),
	(443, 'Sumedh Vedya', 'Vutukuru', NULL, 'STUDENT', '11569', '12', 'HS'),
	(444, 'Nyasha', 'Mabaso', NULL, 'STUDENT', '11657', '5', 'ES'),
	(445, 'Jack', 'Young', NULL, 'STUDENT', '12323', '8', 'MS'),
	(446, 'Annie', 'Young', NULL, 'STUDENT', '12378', '11', 'HS'),
	(447, 'Sofia', 'Peck', NULL, 'STUDENT', '11892', '12', 'HS'),
	(448, 'Elia', 'O''hara', NULL, 'STUDENT', '12062', '11', 'HS'),
	(449, 'Becca', 'Friedman', NULL, 'STUDENT', '12200', '5', 'ES'),
	(450, 'Nandipha', 'Murape', NULL, 'STUDENT', '11700', '11', 'HS'),
	(451, 'Sarah', 'Van Der Vliet', NULL, 'STUDENT', '11630', '7', 'MS'),
	(452, 'Grecy', 'Van Der Vliet', NULL, 'STUDENT', '11629', '12', 'HS'),
	(453, 'Maila', 'Giri', NULL, 'STUDENT', '12421', '3', 'ES'),
	(454, 'Rohan', 'Giri', NULL, 'STUDENT', '12410', '10', 'HS'),
	(455, 'Ao', 'Kasahara', NULL, 'STUDENT', '13041', 'K', 'ES'),
	(456, 'Leonard', 'Laurits', NULL, 'STUDENT', '12250', '1', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(457, 'Charlotte', 'Laurits', NULL, 'STUDENT', '12249', '3', 'ES'),
	(458, 'Kai', 'Jansson', NULL, 'STUDENT', '11761', '3', 'ES'),
	(459, 'Ines Elise', 'Hansen', NULL, 'STUDENT', '12363', '2', 'ES'),
	(460, 'Marius', 'Hansen', NULL, 'STUDENT', '12365', '6', 'MS'),
	(461, 'Minseo', 'Choi', NULL, 'STUDENT', '11145', '4', 'ES'),
	(462, 'Abigail', 'Tassew', NULL, 'STUDENT', '12637', '3', 'ES'),
	(463, 'Nathan', 'Tassew', NULL, 'STUDENT', '12636', '10', 'HS'),
	(464, 'Catherine', 'Johnson', NULL, 'STUDENT', '12867', '1', 'ES'),
	(465, 'Brycelyn', 'Johnson', NULL, 'STUDENT', '12866', '6', 'MS'),
	(466, 'Azzalina', 'Johnson', NULL, 'STUDENT', '12865', '10', 'HS'),
	(467, 'Aaditya', 'Raja', NULL, 'STUDENT', '12103', '10', 'HS'),
	(468, 'Leila', 'Priestley', NULL, 'STUDENT', '20843', '11', 'HS'),
	(469, 'Saron', 'Piper', NULL, 'STUDENT', '25038', '11', 'HS'),
	(470, 'Maxwell', 'Mazibuko', NULL, 'STUDENT', '12574', '10', 'HS'),
	(471, 'Naledi', 'Mazibuko', NULL, 'STUDENT', '12573', '10', 'HS'),
	(472, 'Sechaba', 'Mazibuko', NULL, 'STUDENT', '12575', '10', 'HS'),
	(473, 'Ananya', 'Raval', NULL, 'STUDENT', '12257', '1', 'ES'),
	(474, 'Christopher Ross', 'Donohue', NULL, 'STUDENT', '10333', '7', 'MS'),
	(475, 'Luna', 'Cooney', NULL, 'STUDENT', '12111', '3', 'ES'),
	(476, 'Maïa', 'Cooney', NULL, 'STUDENT', '12110', '10', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(477, 'Danaé', 'Materne', NULL, 'STUDENT', '12154', '9', 'HS'),
	(478, 'Ameya', 'Dale', NULL, 'STUDENT', '10495', '11', 'HS'),
	(479, 'Arthur', 'Hire', NULL, 'STUDENT', '11232', '4', 'ES'),
	(480, 'Kai', 'O''Bra', 'kobra30@isk.ac.ke', 'STUDENT', '12342', '6', 'MS'),
	(481, 'Luke', 'O''Hara', 'lohara30@isk.ac.ke', 'STUDENT', '12063', '6', 'MS'),
	(482, 'Ansh', 'Mehta', 'amehta29@isk.ac.ke', 'STUDENT', '10657', '7', 'MS'),
	(483, 'Isla', 'Goold', 'igoold28@isk.ac.ke', 'STUDENT', '11836', '8', 'MS'),
	(484, 'Akshith', 'Sekar', NULL, 'STUDENT', '10676', '10', 'HS'),
	(485, 'Elsa', 'Lloyd', NULL, 'STUDENT', '11464', '7', 'MS'),
	(486, 'Laé', 'Firzé Al Ghaoui', NULL, 'STUDENT', '12191', '5', 'ES'),
	(487, 'Alessia', 'Quacquarella', NULL, 'STUDENT', '11461', '5', 'ES'),
	(488, 'Hamish', 'Ledgard', NULL, 'STUDENT', '12268', '12', 'HS'),
	(489, 'Sophia', 'Shahbal', NULL, 'STUDENT', '12742', 'K', 'ES'),
	(490, 'Saif', 'Shahbal', NULL, 'STUDENT', '12712', '2', 'ES'),
	(491, 'Jonathan', 'Rwehumbiza', NULL, 'STUDENT', '11854', '10', 'HS'),
	(492, 'Simone', 'Eidex', NULL, 'STUDENT', '11897', '11', 'HS'),
	(493, 'Alston', 'Schenck', NULL, 'STUDENT', '11484', '4', 'ES'),
	(494, 'Troy', 'Hopps', NULL, 'STUDENT', '12306', '3', 'ES'),
	(495, 'Noah', 'Hughes', NULL, 'STUDENT', '10477', '11', 'HS'),
	(496, 'Maximus', 'Njenga', NULL, 'STUDENT', '12303', '2', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(497, 'Sadie', 'Njenga', NULL, 'STUDENT', '12279', '5', 'ES'),
	(498, 'Justin', 'Njenga', NULL, 'STUDENT', '12281', '10', 'HS'),
	(499, 'Daniel', 'Jensen', NULL, 'STUDENT', '11898', '10', 'HS'),
	(500, 'Maya', 'Thibodeau', NULL, 'STUDENT', '12357', '8', 'MS'),
	(501, 'Lorenzo', 'De Vries Aguirre', NULL, 'STUDENT', '11552', '9', 'HS'),
	(502, 'Marco', 'De Vries Aguirre', NULL, 'STUDENT', '11551', '12', 'HS'),
	(503, 'Adam', 'Saleem', NULL, 'STUDENT', '12620', '2', 'ES'),
	(504, 'Emir', 'Abdellahi', NULL, 'STUDENT', '11605', '11', 'HS'),
	(505, 'Maliah', 'O''neal', NULL, 'STUDENT', '11912', '8', 'MS'),
	(506, 'Caio', 'Kraemer', NULL, 'STUDENT', '11906', '9', 'HS'),
	(507, 'Isabela', 'Kraemer', NULL, 'STUDENT', '11907', '12', 'HS'),
	(508, 'Eva', 'Bannikau', NULL, 'STUDENT', '11780', '4', 'ES'),
	(509, 'Alba', 'Prawitz', NULL, 'STUDENT', '12291', '2', 'ES'),
	(510, 'Max', 'Prawitz', NULL, 'STUDENT', '12298', '5', 'ES'),
	(511, 'Leo', 'Prawitz', NULL, 'STUDENT', '12297', '6', 'MS'),
	(512, 'Abigail', 'Holder', NULL, 'STUDENT', '12060', '5', 'ES'),
	(513, 'Charles', 'Holder', NULL, 'STUDENT', '12059', '11', 'HS'),
	(514, 'Isabel', 'Holder', NULL, 'STUDENT', '12056', '12', 'HS'),
	(515, 'Sebastian', 'Ansorg', NULL, 'STUDENT', '12656', '7', 'MS'),
	(516, 'Leon', 'Ansorg', NULL, 'STUDENT', '12655', '11', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(517, 'Pilar', 'Bosch', NULL, 'STUDENT', '12217', 'K', 'ES'),
	(518, 'Moira', 'Bosch', NULL, 'STUDENT', '12218', '2', 'ES'),
	(519, 'Blanca', 'Bosch', NULL, 'STUDENT', '12219', '4', 'ES'),
	(520, 'Aven', 'Ross', NULL, 'STUDENT', '11678', '7', 'MS'),
	(521, 'Kai', 'Herbst', NULL, 'STUDENT', '12231', '2', 'ES'),
	(522, 'Sofia', 'Herbst', NULL, 'STUDENT', '12230', '4', 'ES'),
	(523, 'Michael', 'Bierly', NULL, 'STUDENT', '12179', '8', 'MS'),
	(524, 'Miya', 'Stephens', NULL, 'STUDENT', '11802', '5', 'ES'),
	(525, 'Jihong', 'Joo', NULL, 'STUDENT', '11686', '10', 'HS'),
	(526, 'Hyojin', 'Joo', NULL, 'STUDENT', '11685', '12', 'HS'),
	(527, 'Bruno', 'Sottsas', NULL, 'STUDENT', '12358', '4', 'ES'),
	(528, 'Natasha', 'Sottsas', NULL, 'STUDENT', '12359', '7', 'MS'),
	(529, 'Krishna', 'Gandhi', NULL, 'STUDENT', '12525', '10', 'HS'),
	(530, 'Hrushikesh', 'Gandhi', NULL, 'STUDENT', '12524', '12', 'HS'),
	(531, 'Max', 'Leon', NULL, 'STUDENT', '12490', '12', 'HS'),
	(532, 'Myra', 'Korngold', NULL, 'STUDENT', '12775', '5', 'ES'),
	(533, 'Mila Ruth', 'Korngold', NULL, 'STUDENT', '12773', '7', 'MS'),
	(534, 'Alexander', 'Tarquini', NULL, 'STUDENT', '12223', '4', 'ES'),
	(535, 'Marian', 'Abukari', NULL, 'STUDENT', '10602', '7', 'MS'),
	(536, 'Manuela', 'Abukari', NULL, 'STUDENT', '10672', '9', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(537, 'Soren', 'Mansourian', NULL, 'STUDENT', '12470', '1', 'ES'),
	(538, 'Zecarun', 'Caminha', 'zcaminha30@isk.ac.ke', 'STUDENT', '12081', '6', 'MS'),
	(539, 'Fatima', 'Zucca', 'fazucca30@isk.ac.ke', 'STUDENT', '10566', '6', 'MS'),
	(540, 'Grace', 'Njenga', 'gnjenga29@isk.ac.ke', 'STUDENT', '12280', '7', 'MS'),
	(541, 'Natéa', 'Firzé Al Ghaoui', 'nfirzealghaoui29@isk.ac.ke', 'STUDENT', '12190', '7', 'MS'),
	(542, 'Manali', 'Caminha', NULL, 'STUDENT', '12079', '9', 'HS'),
	(543, 'Nomi', 'Leca Turner', NULL, 'STUDENT', '12894', 'PK', 'ES'),
	(544, 'Enzo', 'Leca Turner', NULL, 'STUDENT', '12893', '1', 'ES'),
	(545, 'Kelsie', 'Karuga', NULL, 'STUDENT', '12162', '6', 'MS'),
	(546, 'Kayla', 'Karuga', NULL, 'STUDENT', '12163', '8', 'MS'),
	(547, 'Tamar', 'Jones-Avni', NULL, 'STUDENT', '12897', 'K', 'ES'),
	(548, 'Dov', 'Jones-Avni', NULL, 'STUDENT', '12784', '2', 'ES'),
	(549, 'Nahal', 'Jones-Avni', NULL, 'STUDENT', '12783', '4', 'ES'),
	(550, 'Noa', 'Godden', NULL, 'STUDENT', '12504', '5', 'ES'),
	(551, 'Emma', 'Godden', NULL, 'STUDENT', '12479', '9', 'HS'),
	(552, 'Lisa', 'Godden', NULL, 'STUDENT', '12478', '10', 'HS'),
	(553, 'Ella', 'Acharya', NULL, 'STUDENT', '12882', '1', 'ES'),
	(554, 'Anshi', 'Acharya', NULL, 'STUDENT', '12881', '7', 'MS'),
	(555, 'Clara', 'Hardy', NULL, 'STUDENT', '12722', '1', 'ES'),
	(556, 'Safari', 'Dara', NULL, 'STUDENT', '11958', '4', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(557, 'Moira', 'Koucheravy', NULL, 'STUDENT', '12305', '4', 'ES'),
	(558, 'Carys', 'Koucheravy', NULL, 'STUDENT', '12304', '8', 'MS'),
	(559, 'Edouard', 'Germain', NULL, 'STUDENT', '12258', '11', 'HS'),
	(560, 'Jacob', 'Germain', NULL, 'STUDENT', '12259', '11', 'HS'),
	(561, 'Lynn Htet', 'Aung', NULL, 'STUDENT', '12293', '5', 'ES'),
	(562, 'Phyo Nyein Nyein', 'Thu', NULL, 'STUDENT', '12302', '7', 'MS'),
	(563, 'Ronan', 'Patel', NULL, 'STUDENT', '10119', '8', 'MS'),
	(564, 'Annabel', 'Asamoah', NULL, 'STUDENT', '10746', '11', 'HS'),
	(565, 'Teo', 'Duwyn', NULL, 'STUDENT', '12085', '5', 'ES'),
	(566, 'Mia', 'Duwyn', NULL, 'STUDENT', '12086', '9', 'HS'),
	(567, 'Cato', 'Van Bommel', NULL, 'STUDENT', '12028', '11', 'HS'),
	(568, 'Henrik', 'Raehalme', NULL, 'STUDENT', '12698', '1', 'ES'),
	(569, 'Emilia', 'Raehalme', NULL, 'STUDENT', '12697', '5', 'ES'),
	(570, 'Asara', 'O''bra', NULL, 'STUDENT', '12341', '9', 'HS'),
	(571, 'Seonu', 'Lee', NULL, 'STUDENT', '12449', '3', 'ES'),
	(572, 'Maya', 'Davis', NULL, 'STUDENT', '10953', '12', 'HS'),
	(573, 'Anika', 'Bruhwiler', NULL, 'STUDENT', '12050', '12', 'HS'),
	(574, 'Mila', 'Jovanovic', NULL, 'STUDENT', '12678', '5', 'ES'),
	(575, 'Dunja', 'Jovanovic', NULL, 'STUDENT', '12677', '8', 'MS'),
	(576, 'Elise', 'Walji', NULL, 'STUDENT', '12740', '2', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(577, 'Felyne', 'Walji', NULL, 'STUDENT', '12739', '3', 'ES'),
	(578, 'Dechen', 'Jacob', NULL, 'STUDENT', '12765', '7', 'MS'),
	(579, 'Tenzin', 'Jacob', NULL, 'STUDENT', '12766', '11', 'HS'),
	(580, 'Fatoumata', 'Touré', NULL, 'STUDENT', '12324', '4', 'ES'),
	(581, 'Ousmane', 'Touré', NULL, 'STUDENT', '12325', '5', 'ES'),
	(582, 'Helena', 'Khayat De Andrade', NULL, 'STUDENT', '12642', 'PK', 'ES'),
	(583, 'Sophia', 'Khayat De Andrade', NULL, 'STUDENT', '12650', '1', 'ES'),
	(584, 'Maelle', 'Nitcheu', NULL, 'STUDENT', '12762', 'PK', 'ES'),
	(585, 'Margot', 'Nitcheu', NULL, 'STUDENT', '12415', '2', 'ES'),
	(586, 'Marion', 'Nitcheu', NULL, 'STUDENT', '12417', '3', 'ES'),
	(587, 'Eva', 'Fernstrom', NULL, 'STUDENT', '11939', '5', 'ES'),
	(588, 'Sienna', 'Barragan Sofrony', NULL, 'STUDENT', '12831', 'K', 'ES'),
	(589, 'Gael', 'Barragan Sofrony', NULL, 'STUDENT', '12711', '3', 'ES'),
	(590, 'William', 'Jansen', NULL, 'STUDENT', '11837', '8', 'MS'),
	(591, 'Matias', 'Jansen', NULL, 'STUDENT', '11855', '10', 'HS'),
	(592, 'Siri', 'Maagaard', NULL, 'STUDENT', '12827', '4', 'ES'),
	(593, 'Laerke', 'Maagaard', NULL, 'STUDENT', '12826', '9', 'HS'),
	(594, 'Chae Hyun', 'Jin', NULL, 'STUDENT', '12647', 'PK', 'ES'),
	(595, 'A-Hyun', 'Jin', NULL, 'STUDENT', '12246', '2', 'ES'),
	(596, 'Pietro', 'Fundaro', NULL, 'STUDENT', '11329', '10', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(597, 'Jade', 'Onderi', NULL, 'STUDENT', '11847', '9', 'HS'),
	(598, 'Nikhil', 'Kimatrai', NULL, 'STUDENT', '11810', '9', 'HS'),
	(599, 'Rhea', 'Kimatrai', NULL, 'STUDENT', '11809', '9', 'HS'),
	(600, 'Kennedy', 'Ireri', NULL, 'STUDENT', '10313', '9', 'HS'),
	(601, 'Olivia', 'Patel', 'opatel30@isk.ac.ke', 'STUDENT', '10561', '6', 'MS'),
	(602, 'Naia', 'Friedhoff Jaeschke', 'nfriedhoffjaeschke29@isk.ac.ke', 'STUDENT', '11822', '7', 'MS'),
	(603, 'Kaynan', 'Abshir', NULL, 'STUDENT', '12830', 'K', 'ES'),
	(604, 'Farzin', 'Taneem', NULL, 'STUDENT', '11335', '7', 'MS'),
	(605, 'Umaiza', 'Taneem', NULL, 'STUDENT', '11336', '8', 'MS'),
	(606, 'Oagile', 'Mothobi', NULL, 'STUDENT', '12808', '1', 'ES'),
	(607, 'Resegofetse', 'Mothobi', NULL, 'STUDENT', '12807', '4', 'ES'),
	(608, 'Soline', 'Wittmann', NULL, 'STUDENT', '12429', '10', 'HS'),
	(609, 'Mateo', 'Muziramakenga', NULL, 'STUDENT', '12704', '1', 'ES'),
	(610, 'Aiden', 'Muziramakenga', NULL, 'STUDENT', '12703', '4', 'ES'),
	(611, 'Charlie', 'Carver Wildig', NULL, 'STUDENT', '12602', '5', 'ES'),
	(612, 'Barney', 'Carver Wildig', NULL, 'STUDENT', '12601', '7', 'MS'),
	(613, 'Jijoon', 'Park', NULL, 'STUDENT', '12787', '2', 'ES'),
	(614, 'Jooan', 'Park', NULL, 'STUDENT', '12786', '4', 'ES'),
	(615, 'Zohar', 'Hercberg', NULL, 'STUDENT', '12745', 'PK', 'ES'),
	(616, 'Amitai', 'Hercberg', NULL, 'STUDENT', '12680', '3', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(617, 'Uriya', 'Hercberg', NULL, 'STUDENT', '12682', '7', 'MS'),
	(618, 'Rafael', 'Carter', NULL, 'STUDENT', '12776', '8', 'MS'),
	(619, 'Vihaan', 'Arora', NULL, 'STUDENT', '12242', '2', 'ES'),
	(620, 'Sofia', 'Crandall', NULL, 'STUDENT', '12990', '12', 'HS'),
	(621, 'Almaira', 'Ihsan', NULL, 'STUDENT', '13061', '5', 'ES'),
	(622, 'Rayyan', 'Ihsan', NULL, 'STUDENT', '13060', '7', 'MS'),
	(623, 'Zakhrafi', 'Ihsan', NULL, 'STUDENT', '13063', '11', 'HS'),
	(624, 'Alexander', 'Thomas', NULL, 'STUDENT', '12579', '11', 'HS'),
	(625, 'Ruth', 'Dove', NULL, 'STUDENT', '12921', '9', 'HS'),
	(626, 'Samuel', 'Dove', NULL, 'STUDENT', '12920', '11', 'HS'),
	(627, 'Alvin', 'Ngumi', NULL, 'STUDENT', '12588', '11', 'HS'),
	(628, 'Julia', 'Handler', NULL, 'STUDENT', '13100', '6', 'MS'),
	(629, 'Josephine', 'Maguire', NULL, 'STUDENT', '12592', '8', 'MS'),
	(630, 'Theodore', 'Maguire', NULL, 'STUDENT', '12593', '10', 'HS'),
	(631, 'Deniza', 'Kasymbekova Tauras', NULL, 'STUDENT', '13027', '5', 'ES'),
	(632, 'Amman', 'Assefa', NULL, 'STUDENT', '12669', '8', 'MS'),
	(633, 'Lucas', 'Maasdorp Mogollon', NULL, 'STUDENT', '12822', '1', 'ES'),
	(634, 'Gabriela', 'Maasdorp Mogollon', NULL, 'STUDENT', '12821', '4', 'ES'),
	(635, 'Dallin', 'Daines', NULL, 'STUDENT', '13064', '2', 'ES'),
	(636, 'Caleb', 'Daines', NULL, 'STUDENT', '13084', '4', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(637, 'Gabriel', 'Mccown', NULL, 'STUDENT', '12833', 'K', 'ES'),
	(638, 'Clea', 'Mccown', NULL, 'STUDENT', '12837', '2', 'ES'),
	(639, 'Beckham', 'Stock', NULL, 'STUDENT', '12916', '2', 'ES'),
	(640, 'Payton', 'Stock', NULL, 'STUDENT', '12914', '11', 'HS'),
	(641, 'Ruhan', 'Reza', NULL, 'STUDENT', '13021', '7', 'MS'),
	(642, 'Nandita', 'Sankar', NULL, 'STUDENT', '12802', '3', 'ES'),
	(643, 'Ian', 'Kavaleuski', NULL, 'STUDENT', '13059', '10', 'HS'),
	(644, 'Kian', 'Ghelani-Decorte', NULL, 'STUDENT', '12673', '8', 'MS'),
	(645, 'Elrad', 'Abdurazakov', NULL, 'STUDENT', '12690', '6', 'MS'),
	(646, 'Malik', 'Kamara', NULL, 'STUDENT', '12724', '1', 'ES'),
	(647, 'Ethan', 'Diehl', NULL, 'STUDENT', '12863', 'PK', 'ES'),
	(648, 'Malcolm', 'Diehl', NULL, 'STUDENT', '12864', '1', 'ES'),
	(649, 'Elena', 'Mosher', NULL, 'STUDENT', '12710', '1', 'ES'),
	(650, 'Emma', 'Mosher', NULL, 'STUDENT', '12709', '3', 'ES'),
	(651, 'Abibatou', 'Magassouba', NULL, 'STUDENT', '13092', '2', 'ES'),
	(652, 'Sada', 'Bomba', NULL, 'STUDENT', '12989', '11', 'HS'),
	(653, 'Tamaki', 'Ishikawa', NULL, 'STUDENT', '13054', '3', 'ES'),
	(654, 'Colin', 'Walls', NULL, 'STUDENT', '12475', '3', 'ES'),
	(655, 'Ethan', 'Walls', NULL, 'STUDENT', '12474', '5', 'ES'),
	(656, 'Emilin', 'Patterson', NULL, 'STUDENT', '12811', '3', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(657, 'Kaitlin', 'Patterson', NULL, 'STUDENT', '12810', '7', 'MS'),
	(658, 'Elsie', 'Mackay', NULL, 'STUDENT', '12886', '4', 'ES'),
	(659, 'Emilie', 'Wittmann', 'ewittmann30@isk.ac.ke', 'STUDENT', '12428', '6', 'MS'),
	(660, 'Reehan', 'Reza', 'rreza30@isk.ac.ke', 'STUDENT', '13022', '6', 'MS'),
	(661, 'Noga', 'Hercberg', 'nhercberg30@isk.ac.ke', 'STUDENT', '12681', '6', 'MS'),
	(662, 'Emiel', 'Ghelani-Decorte', 'eghelani-decorte29@isk.ac.ke', 'STUDENT', '12674', '7', 'MS'),
	(663, 'Georgia', 'Dove', 'gdove30@isk.ac.ke', 'STUDENT', '12922', '6', 'MS'),
	(664, 'Nora', 'Mackay', NULL, 'STUDENT', '12885', '6', 'MS'),
	(665, 'Samantha', 'Ishee', NULL, 'STUDENT', '12832', 'K', 'ES'),
	(666, 'Emily', 'Ishee', NULL, 'STUDENT', '12836', '5', 'ES'),
	(667, 'Sonya', 'Wagner', NULL, 'STUDENT', '12892', '4', 'ES'),
	(668, 'Ayaan', 'Pabani', NULL, 'STUDENT', '12256', '1', 'ES'),
	(669, 'Arth', 'Jain', NULL, 'STUDENT', '13088', 'K', 'ES'),
	(670, 'Caleb', 'Fekadeneh', NULL, 'STUDENT', '12641', '5', 'ES'),
	(671, 'Sina', 'Fekadeneh', NULL, 'STUDENT', '12633', '10', 'HS'),
	(672, 'Marc-Andri', 'Bachmann', NULL, 'STUDENT', '12604', '8', 'MS'),
	(673, 'Ralia', 'Daher', NULL, 'STUDENT', '13066', 'PK', 'ES'),
	(674, 'Abbas', 'Daher', NULL, 'STUDENT', '12435', '1', 'ES'),
	(675, 'Ruth Yifru', 'Tafesse', NULL, 'STUDENT', '13099', '11', 'HS'),
	(676, 'Emil', 'Grundberg', NULL, 'STUDENT', '13019', '8', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(677, 'Amen', 'Mezemir', NULL, 'STUDENT', '10498', '8', 'MS'),
	(678, 'Zizwani', 'Chikapa', NULL, 'STUDENT', '13101', 'PK', 'ES'),
	(679, 'Chawanangwa', 'Mkandawire', NULL, 'STUDENT', '12292', '7', 'MS'),
	(680, 'Daniel', 'Mkandawire', NULL, 'STUDENT', '12272', '11', 'HS'),
	(681, 'Selkie', 'Douglas-Hamilton Pope', NULL, 'STUDENT', '12995', '9', 'HS'),
	(682, 'Yoav', 'Margovsky-Lotem', NULL, 'STUDENT', '12649', 'PK', 'ES'),
	(683, 'Liam', 'Irungu', NULL, 'STUDENT', '13039', 'K', 'ES'),
	(684, 'Aiden', 'Irungu', NULL, 'STUDENT', '13038', '2', 'ES'),
	(685, 'Feng Zimo', 'Li', NULL, 'STUDENT', '13024', '5', 'ES'),
	(686, 'Feng Milun', 'Li', NULL, 'STUDENT', '13023', '7', 'MS'),
	(687, 'Alice', 'Grindell', NULL, 'STUDENT', '12900', 'K', 'ES'),
	(688, 'Emily', 'Grindell', NULL, 'STUDENT', '12061', '2', 'ES'),
	(689, 'Emilie', 'Abbonizio', NULL, 'STUDENT', '13016', '11', 'HS'),
	(690, 'Cassidy', 'Muttersbaugh', NULL, 'STUDENT', '13035', 'K', 'ES'),
	(691, 'Magnolia', 'Muttersbaugh', NULL, 'STUDENT', '13034', '3', 'ES'),
	(692, 'Mathis', 'Bellamy', NULL, 'STUDENT', '12823', 'K', 'ES'),
	(693, 'Maisha', 'Donne', NULL, 'STUDENT', '12590', '11', 'HS'),
	(694, 'Amanda', 'Romero Sánchez-Miranda', NULL, 'STUDENT', '12800', '3', 'ES'),
	(695, 'Candela', 'Romero', NULL, 'STUDENT', '12799', '8', 'MS'),
	(696, 'Nadia', 'Nora', NULL, 'STUDENT', '12860', '11', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(697, 'Nayoon', 'Lee', NULL, 'STUDENT', '12626', '5', 'ES'),
	(698, 'Gaspard', 'Womble', NULL, 'STUDENT', '12718', '1', 'ES'),
	(699, 'Nile', 'Sudra', NULL, 'STUDENT', '13065', 'PK', 'ES'),
	(700, 'Xinyi', 'Huang', NULL, 'STUDENT', '13074', '1', 'ES'),
	(701, 'Aabhar', 'Baral', NULL, 'STUDENT', '13030', '5', 'ES'),
	(702, 'Azza', 'Rollins', NULL, 'STUDENT', '12982', '9', 'HS'),
	(703, 'Bushra', 'Hussain', NULL, 'STUDENT', '13070', 'PK', 'ES'),
	(704, 'Monika', 'Srutova', NULL, 'STUDENT', '12999', '8', 'MS'),
	(705, 'Nyx Verena', 'Houndeganme', NULL, 'STUDENT', '12815', '6', 'MS'),
	(706, 'Michael', 'Houndeganme', NULL, 'STUDENT', '12814', '9', 'HS'),
	(707, 'Crédo Terrence', 'Houndeganme', NULL, 'STUDENT', '12813', '12', 'HS'),
	(708, 'Zefyros', 'Patrikios', NULL, 'STUDENT', '13103', 'PK', 'ES'),
	(709, 'Emilio', 'Trujillo', NULL, 'STUDENT', '13067', 'PK', 'ES'),
	(710, 'Eitan', 'Segev', NULL, 'STUDENT', '12862', 'PK', 'ES'),
	(711, 'Amitai', 'Segev', NULL, 'STUDENT', '12721', '1', 'ES'),
	(712, 'Karina', 'Maini', NULL, 'STUDENT', '12986', '10', 'HS'),
	(713, 'Elena', 'Moons', NULL, 'STUDENT', '12851', '7', 'MS'),
	(714, 'Aymen', 'Zeynu', NULL, 'STUDENT', '12809', '3', 'ES'),
	(715, 'Abem', 'Zeynu', NULL, 'STUDENT', '12552', '7', 'MS'),
	(716, 'Alan', 'Simek', NULL, 'STUDENT', '13015', '8', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(717, 'Emil', 'Simek', NULL, 'STUDENT', '13014', '11', 'HS'),
	(718, 'Hachim', 'Gallagher', NULL, 'STUDENT', '13083', '2', 'ES'),
	(719, 'Kabir', 'Jaffer', NULL, 'STUDENT', '12646', 'K', 'ES'),
	(720, 'Ayaan', 'Jaffer', NULL, 'STUDENT', '11646', '4', 'ES'),
	(721, 'Alifiya', 'Dawoodbhai', NULL, 'STUDENT', '12580', '12', 'HS'),
	(722, 'Ruth', 'Lindkvist', NULL, 'STUDENT', '12578', '9', 'HS'),
	(723, 'Adrian', 'Otieno', NULL, 'STUDENT', '12884', '7', 'MS'),
	(724, 'Aanya', 'Shah', NULL, 'STUDENT', '12583', '8', 'MS'),
	(725, 'Dongyoon', 'Lee', 'dlee30@isk.ac.ke', 'STUDENT', '12627', '6', 'MS'),
	(726, 'Nora', 'Schei', NULL, 'STUDENT', '12582', '8', 'MS'),
	(727, 'Jake', 'Schoneveld', NULL, 'STUDENT', '13086', 'PK', 'ES'),
	(728, 'Roy', 'Gitiba', NULL, 'STUDENT', '12818', '7', 'MS'),
	(729, 'Kirk Wise', 'Gitiba', NULL, 'STUDENT', '12817', '9', 'HS'),
	(730, 'Isaiah', 'Geller', NULL, 'STUDENT', '12539', '9', 'HS'),
	(731, 'Bianca', 'Mbera', NULL, 'STUDENT', '12603', '10', 'HS'),
	(732, 'Kors', 'Ukumu', NULL, 'STUDENT', '12545', '9', 'HS'),
	(733, 'Jiya', 'Shah', NULL, 'STUDENT', '12857', '8', 'MS'),
	(734, 'Zayan', 'Karmali', NULL, 'STUDENT', '13098', '10', 'HS'),
	(735, 'Serenae', 'Angima', NULL, 'STUDENT', '12954', '8', 'MS'),
	(736, 'Fatoumatta', 'Fatty', NULL, 'STUDENT', '12735', '12', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(737, 'Saone', 'Kwena', NULL, 'STUDENT', '12985', '10', 'HS'),
	(738, 'Howard', 'Wesley Iii', NULL, 'STUDENT', '12861', 'PK', 'ES'),
	(739, 'Isabella', 'Mason', NULL, 'STUDENT', '12629', '11', 'HS'),
	(740, 'Ayana', 'Limpered', NULL, 'STUDENT', '13085', 'PK', 'ES'),
	(741, 'Arielle', 'Limpered', NULL, 'STUDENT', '12795', '2', 'ES'),
	(742, 'Rakeb', 'Teklemichael', NULL, 'STUDENT', '12412', '10', 'HS'),
	(743, 'Pranai', 'Shah', NULL, 'STUDENT', '12987', '11', 'HS'),
	(744, 'Dhiya', 'Shah', NULL, 'STUDENT', '12541', '7', 'MS'),
	(745, 'Marianne', 'Roquebrune', NULL, 'STUDENT', '12644', 'PK', 'ES'),
	(746, 'Nichelle', 'Somaia', NULL, 'STUDENT', '12842', '1', 'ES'),
	(747, 'Shivail', 'Somaia', NULL, 'STUDENT', '11769', '4', 'ES'),
	(748, 'Lukas', 'Stiles', NULL, 'STUDENT', '13068', 'PK', 'ES'),
	(749, 'Nikolas', 'Stiles', NULL, 'STUDENT', '11137', '5', 'ES'),
	(750, 'Nathan', 'Matimu', NULL, 'STUDENT', '12979', '9', 'HS'),
	(751, 'Aristophanes', 'Abreu', NULL, 'STUDENT', '12895', 'K', 'ES'),
	(752, 'Herson Alexandros', 'Abreu', NULL, 'STUDENT', '12896', '1', 'ES'),
	(753, 'Arthur', 'Bailey', NULL, 'STUDENT', '12825', '9', 'HS'),
	(754, 'Florrie', 'Bailey', NULL, 'STUDENT', '12812', '11', 'HS'),
	(755, 'Adam', 'Kone', NULL, 'STUDENT', '11368', '10', 'HS'),
	(756, 'Zahra', 'Kone', NULL, 'STUDENT', '11367', '12', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(757, 'Thomas', 'Wimber', NULL, 'STUDENT', '12670', '8', 'MS'),
	(758, 'Rahmaan', 'Ali', NULL, 'STUDENT', '12755', '12', 'HS'),
	(759, 'Davran', 'Chowdhury', NULL, 'STUDENT', '13029', '5', 'ES'),
	(760, 'Nevzad', 'Chowdhury', NULL, 'STUDENT', '12868', '11', 'HS'),
	(761, 'Aariyana', 'Patel', NULL, 'STUDENT', '12553', '9', 'HS'),
	(762, 'Graham', 'Mueller', NULL, 'STUDENT', '12938', '7', 'MS'),
	(763, 'Willem', 'Mueller', NULL, 'STUDENT', '12937', '9', 'HS'),
	(764, 'Christian', 'Mueller', NULL, 'STUDENT', '12936', '11', 'HS'),
	(765, 'Libasse', 'Ndoye', NULL, 'STUDENT', '13075', '8', 'MS'),
	(766, 'Yi (Gavin)', 'Wang', NULL, 'STUDENT', '13020', '3', 'ES'),
	(767, 'Shuyi (Bella)', 'Wang', NULL, 'STUDENT', '12950', '8', 'MS'),
	(768, 'Mariam', 'David-Tafida', NULL, 'STUDENT', '12715', '2', 'ES'),
	(769, 'James', 'Farrell', NULL, 'STUDENT', '12720', '1', 'ES'),
	(770, 'Anna Toft', 'Gronborg', NULL, 'STUDENT', '12801', 'K', 'ES'),
	(771, 'Rocco', 'Sidari', NULL, 'STUDENT', '13036', '2', 'ES'),
	(772, 'David', 'Ajidahun', NULL, 'STUDENT', '13072', 'PK', 'ES'),
	(773, 'Darian', 'Ajidahun', NULL, 'STUDENT', '12805', '2', 'ES'),
	(774, 'Annabelle', 'Ajidahun', NULL, 'STUDENT', '12804', '4', 'ES'),
	(775, 'Saif', 'Hussain', NULL, 'STUDENT', '12328', '4', 'ES'),
	(776, 'Taim', 'Hussain', NULL, 'STUDENT', '12899', 'K', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(777, 'Kaveer Singh', 'Hayer', NULL, 'STUDENT', '13048', '2', 'ES'),
	(778, 'Manvir Singh', 'Hayer', NULL, 'STUDENT', '12471', '7', 'MS'),
	(779, 'Ahmed Jabir', 'Bin Taif', NULL, 'STUDENT', '12898', 'K', 'ES'),
	(780, 'Ahmed Jayed', 'Bin Taif', NULL, 'STUDENT', '12311', '2', 'ES'),
	(781, 'Ahmed Jawad', 'Bin Taif', NULL, 'STUDENT', '12312', '5', 'ES'),
	(782, 'Rebekah Ysabelle', 'Nas', NULL, 'STUDENT', '12978', '9', 'HS'),
	(783, 'Emilia', 'Husemann', NULL, 'STUDENT', '12949', '8', 'MS'),
	(784, 'Luna', 'Bonde-Nielsen', NULL, 'STUDENT', '12891', '4', 'ES'),
	(785, 'Naomi', 'Alemayehu', NULL, 'STUDENT', '13000', '4', 'ES'),
	(786, 'Arabella', 'Hales', NULL, 'STUDENT', '13105', 'PK', 'ES'),
	(787, 'Masoud', 'Ibrahim', 'mibrahim30@isk.ac.ke', 'STUDENT', '13076', '6', 'MS'),
	(788, 'Titu', 'Tulga', 'ttulga30@isk.ac.ke', 'STUDENT', '12756', '6', 'MS'),
	(789, 'Zari', 'Khan', NULL, 'STUDENT', '13087', '9', 'HS'),
	(790, 'Cradle Terry', 'Alwedo', NULL, 'STUDENT', '13026', '5', 'ES'),
	(791, 'Felix', 'Braun', NULL, 'STUDENT', '13095', '8', 'MS'),
	(792, 'Io', 'Verstraete', NULL, 'STUDENT', '12998', '10', 'HS'),
	(793, 'Matthew', 'Crabtree', NULL, 'STUDENT', '12560', '11', 'HS'),
	(794, 'Kieu', 'Sansculotte', NULL, 'STUDENT', '12269', '12', 'HS'),
	(795, 'Daniel', 'Berkouwer', NULL, 'STUDENT', '12496', '1', 'ES'),
	(796, 'Kayla', 'Opere', NULL, 'STUDENT', '12820', 'PK', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(797, 'Léa', 'Berthellier-Antoine', NULL, 'STUDENT', '12794', '1', 'ES'),
	(798, 'Lukas', 'Kaseva', NULL, 'STUDENT', '13104', 'PK', 'ES'),
	(799, 'Lauri', 'Kaseva', NULL, 'STUDENT', '13096', '3', 'ES'),
	(800, 'Layal', 'Khan', NULL, 'STUDENT', '12550', '2', 'ES'),
	(801, 'Ishbel', 'Croze', NULL, 'STUDENT', '13062', '9', 'HS'),
	(802, 'Emily', 'Croucher', NULL, 'STUDENT', '12873', '5', 'ES'),
	(803, 'Oliver', 'Croucher', NULL, 'STUDENT', '12874', '7', 'MS'),
	(804, 'Anabelle', 'Croucher', NULL, 'STUDENT', '12875', '9', 'HS'),
	(805, 'Vera', 'Olvik', NULL, 'STUDENT', '12953', '8', 'MS'),
	(806, 'Theodor', 'Skaaraas-Gjoelberg', NULL, 'STUDENT', '12845', '1', 'ES'),
	(807, 'Cedrik', 'Skaaraas-Gjoelberg', NULL, 'STUDENT', '12846', '5', 'ES'),
	(808, 'David', 'Lee', NULL, 'STUDENT', '13089', '2', 'ES'),
	(809, 'Sanaya', 'Jijina', NULL, 'STUDENT', '12736', '12', 'HS'),
	(810, 'Harshaan', 'Arora', NULL, 'STUDENT', '13010', '8', 'MS'),
	(811, 'Tisya', 'Arora', NULL, 'STUDENT', '13009', '10', 'HS'),
	(812, 'Gai', 'Elkana', NULL, 'STUDENT', '13001', '1', 'ES'),
	(813, 'Yuval', 'Elkana', NULL, 'STUDENT', '13002', '3', 'ES'),
	(814, 'Matan', 'Elkana', NULL, 'STUDENT', '13003', '5', 'ES'),
	(815, 'Niccolo', 'Nasidze', NULL, 'STUDENT', '12901', 'K', 'ES'),
	(816, 'Jayesh', 'Aditya', NULL, 'STUDENT', '12472', '8', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(817, 'Zara', 'Bredin', NULL, 'STUDENT', '11851', '10', 'HS'),
	(818, 'Mark', 'Lavack', NULL, 'STUDENT', '20817', '8', 'MS'),
	(819, 'Michael', 'Lavack', NULL, 'STUDENT', '26015', '10', 'HS'),
	(820, 'Rohin', 'Dodhia', NULL, 'STUDENT', '10820', '11', 'HS'),
	(821, 'Jaidyn', 'Bunch', NULL, 'STUDENT', '12508', '11', 'HS'),
	(822, 'Chalita', 'Victor', NULL, 'STUDENT', '12529', '11', 'HS'),
	(823, 'Hannah', 'Waalewijn', NULL, 'STUDENT', '12598', '7', 'MS'),
	(824, 'Simon', 'Waalewijn', NULL, 'STUDENT', '12596', '11', 'HS'),
	(825, 'Kaitlin', 'Wietecha', NULL, 'STUDENT', '12591', '10', 'HS'),
	(826, 'Saoirse', 'Molloy', NULL, 'STUDENT', '12702', '2', 'ES'),
	(827, 'Caelan', 'Molloy', NULL, 'STUDENT', '12701', '4', 'ES'),
	(828, 'Victor', 'Mollier-Camus', NULL, 'STUDENT', '12594', '5', 'ES'),
	(829, 'Elisa', 'Mollier-Camus', NULL, 'STUDENT', '12586', '8', 'MS'),
	(830, 'Jaishna', 'Varun', NULL, 'STUDENT', '12684', '7', 'MS'),
	(831, 'Leah', 'Heijstee', NULL, 'STUDENT', '12782', '3', 'ES'),
	(832, 'Zara', 'Heijstee', NULL, 'STUDENT', '12781', '8', 'MS'),
	(833, 'Graciela', 'Sotiriou', NULL, 'STUDENT', '12902', 'K', 'ES'),
	(834, 'Leonidas', 'Sotiriou', NULL, 'STUDENT', '12239', '2', 'ES'),
	(835, 'Evangelina', 'Barbacci', NULL, 'STUDENT', '12612', '7', 'MS'),
	(836, 'Gabriella', 'Barbacci', NULL, 'STUDENT', '12611', '10', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(837, 'Santiago', 'Moyle', NULL, 'STUDENT', '12581', '9', 'HS'),
	(838, 'Alissa', 'Yakusik', NULL, 'STUDENT', '13082', '4', 'ES'),
	(839, 'Farah', 'Ghariani', NULL, 'STUDENT', '12662', '9', 'HS'),
	(840, 'Lillian', 'Cameron-Mutyaba', NULL, 'STUDENT', '12634', '10', 'HS'),
	(841, 'Rose', 'Cameron-Mutyaba', NULL, 'STUDENT', '12635', '10', 'HS'),
	(842, 'Nathan', 'Teferi', NULL, 'STUDENT', '12984', '10', 'HS'),
	(843, 'Angab', 'Mayar', NULL, 'STUDENT', '13057', '11', 'HS'),
	(844, 'Hanina', 'Abdosh', NULL, 'STUDENT', '12737', '12', 'HS'),
	(845, 'Harsha', 'Varun', 'hvarun30@isk.ac.ke', 'STUDENT', '12683', '6', 'MS'),
	(846, 'Sadie', 'Szuchman', 'sszuchman30@isk.ac.ke', 'STUDENT', '12668', '6', 'MS'),
	(847, 'Maria', 'Agenorwot', 'magenorwot28@isk.ac.ke', 'STUDENT', '13018', '8', 'MS'),
	(848, 'Reuben', 'Szuchman', 'rszuchman28@isk.ac.ke', 'STUDENT', '12667', '8', 'MS'),
	(849, 'Liri', 'Alemu', NULL, 'STUDENT', '12732', '3', 'ES'),
	(850, 'Ishanvi', 'Ishanvi', NULL, 'STUDENT', '13053', 'K', 'ES'),
	(851, 'Seher', 'Goyal', NULL, 'STUDENT', '12373', '10', 'HS'),
	(852, 'Michael Omar', 'Assi', NULL, 'STUDENT', '12917', '7', 'MS'),
	(853, 'Abhimanyu', 'Singh', NULL, 'STUDENT', '12728', '2', 'ES'),
	(854, 'Sifa', 'Otieno', NULL, 'STUDENT', '13013', '12', 'HS'),
	(855, 'Iman', 'Ibrahim', NULL, 'STUDENT', '12819', '9', 'HS'),
	(856, 'Tarquin', 'Mathews', NULL, 'STUDENT', '12994', '11', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(857, 'Jia', 'Pandit', NULL, 'STUDENT', '10437', '10', 'HS'),
	(858, 'Josephine', 'Waugh', NULL, 'STUDENT', '12844', '1', 'ES'),
	(859, 'Rosemary', 'Waugh', NULL, 'STUDENT', '12843', '4', 'ES'),
	(860, 'Daudi', 'Kisukye', NULL, 'STUDENT', '13025', '5', 'ES'),
	(861, 'Gabriel', 'Kisukye', NULL, 'STUDENT', '12759', '10', 'HS'),
	(862, 'Aydin', 'Virani', NULL, 'STUDENT', '12483', '3', 'ES'),
	(863, 'Yasmin', 'Huysdens', NULL, 'STUDENT', '12927', '7', 'MS'),
	(864, 'Jacey', 'Huysdens', NULL, 'STUDENT', '12926', '9', 'HS'),
	(865, 'Esther', 'Schonemann', NULL, 'STUDENT', '13028', '5', 'ES'),
	(866, 'Nabou', 'Khouma', NULL, 'STUDENT', '13046', 'K', 'ES'),
	(867, 'Khady', 'Khouma', NULL, 'STUDENT', '13045', '3', 'ES'),
	(868, 'Emily', 'Ellinger', NULL, 'STUDENT', '13102', '5', 'ES'),
	(869, 'Isaac', 'D''souza', NULL, 'STUDENT', '12501', '8', 'MS'),
	(870, 'Ezra', 'Kane', NULL, 'STUDENT', '13071', 'PK', 'ES'),
	(871, 'Sapia', 'Pijovic', NULL, 'STUDENT', '13091', 'PK', 'ES'),
	(872, 'Mubanga', 'Birschbach', NULL, 'STUDENT', '13052', 'K', 'ES'),
	(873, 'Ben', 'Granot', NULL, 'STUDENT', '12748', 'K', 'ES'),
	(874, 'Zyla', 'Khalid', NULL, 'STUDENT', '12747', 'K', 'ES'),
	(875, 'Hannah', 'Kishiue-Turkstra', NULL, 'STUDENT', '12751', 'K', 'ES'),
	(876, 'Alexander', 'Magnusson', NULL, 'STUDENT', '12824', 'K', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(877, 'Emerson', 'Nau', NULL, 'STUDENT', '12834', 'K', 'ES'),
	(878, 'Alexandre', 'Patenaude', NULL, 'STUDENT', '12743', 'K', 'ES'),
	(879, 'Ren', 'Hirose', NULL, 'STUDENT', '13040', '1', 'ES'),
	(880, 'Abel', 'Johnson', NULL, 'STUDENT', '12767', '1', 'ES'),
	(881, 'Issa', 'Kane', NULL, 'STUDENT', '13037', '1', 'ES'),
	(882, 'Beatrix', 'Kiers', NULL, 'STUDENT', '12717', '1', 'ES'),
	(883, 'Yousif', 'Menkerios', NULL, 'STUDENT', '12459', '1', 'ES'),
	(884, 'Clayton', 'Oberjuerge', NULL, 'STUDENT', '12687', '1', 'ES'),
	(885, 'Yash', 'Pant', NULL, 'STUDENT', '12480', '1', 'ES'),
	(886, 'Amandla', 'Pijovic', NULL, 'STUDENT', '13090', '1', 'ES'),
	(887, 'Paola', 'Santos', NULL, 'STUDENT', '13094', '1', 'ES'),
	(888, 'Amaya', 'Sarfaraz', NULL, 'STUDENT', '12608', '1', 'ES'),
	(889, 'Clarice', 'Schrader', NULL, 'STUDENT', '12841', '1', 'ES'),
	(890, 'Mandisa', 'Sobantu', NULL, 'STUDENT', '12939', '1', 'ES'),
	(891, 'Tasheni', 'Kamenga', NULL, 'STUDENT', '12877', '2', 'ES'),
	(892, 'Theodore', 'Patenaude', NULL, 'STUDENT', '12713', '2', 'ES'),
	(893, 'Ewyn', 'Soobrattee', NULL, 'STUDENT', '12714', '2', 'ES'),
	(894, 'Anna', 'Von Platen-Hallermund', NULL, 'STUDENT', '12888', '2', 'ES'),
	(895, 'Tristan', 'Wendelboe', NULL, 'STUDENT', '12527', '2', 'ES'),
	(896, 'Signe', 'Andersen', NULL, 'STUDENT', '12570', '3', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(897, 'Holly', 'Asquith', NULL, 'STUDENT', '12944', '3', 'ES'),
	(898, 'Aurélien', 'Diop Weyer', NULL, 'STUDENT', '13033', '3', 'ES'),
	(899, 'Levi', 'Lundell', NULL, 'STUDENT', '12693', '3', 'ES'),
	(900, 'Santiago', 'Santos', NULL, 'STUDENT', '13093', '3', 'ES'),
	(901, 'Genevieve', 'Schrader', NULL, 'STUDENT', '12840', '3', 'ES'),
	(902, 'Martin', 'Vazquez Eraso', NULL, 'STUDENT', '12369', '3', 'ES'),
	(903, 'Magne', 'Vestergaard', NULL, 'STUDENT', '12664', '3', 'ES'),
	(904, 'Nanna', 'Vestergaard', NULL, 'STUDENT', '12665', '3', 'ES'),
	(905, 'Benjamin', 'Weill', NULL, 'STUDENT', '12849', '3', 'ES'),
	(906, 'Kira', 'Bailey', NULL, 'STUDENT', '12289', '4', 'ES'),
	(907, 'Aaryama', 'Bixby', NULL, 'STUDENT', '12850', '4', 'ES'),
	(908, 'Armelle', 'Carlevato', NULL, 'STUDENT', '12925', '4', 'ES'),
	(909, 'Sonia', 'Corbin', NULL, 'STUDENT', '12942', '4', 'ES'),
	(910, 'Zaria', 'Khalid', NULL, 'STUDENT', '12617', '4', 'ES'),
	(911, 'Uzima', 'Otieno', 'uotieno29@isk.ac.ke', 'STUDENT', '13056', '7', 'MS'),
	(912, 'Carlos Laith', 'Farraj', NULL, 'STUDENT', '12607', '4', 'ES'),
	(913, 'Jarius', 'Farraj', NULL, 'STUDENT', '12606', '11', 'HS'),
	(914, 'Murad', 'Dadashev', NULL, 'STUDENT', '12768', '8', 'MS'),
	(915, 'Zubeyda', 'Dadasheva', NULL, 'STUDENT', '12769', '12', 'HS'),
	(916, 'Sumaiya', 'Iversen', NULL, 'STUDENT', '12433', '12', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(917, 'Nike', 'Borg Aidnell', NULL, 'STUDENT', '12542', '2', 'ES'),
	(918, 'Siv', 'Borg Aidnell', NULL, 'STUDENT', '12543', '2', 'ES'),
	(919, 'Disa', 'Borg Aidnell', NULL, 'STUDENT', '12696', '5', 'ES'),
	(920, 'Ryan', 'Ellis', NULL, 'STUDENT', '12070', '11', 'HS'),
	(921, 'Adrienne', 'Ellis', NULL, 'STUDENT', '12068', '12', 'HS'),
	(922, 'Emalea', 'Hodge', NULL, 'STUDENT', '12192', '5', 'ES'),
	(923, 'Jip', 'Arens', NULL, 'STUDENT', '12430', '12', 'HS'),
	(924, 'Spencer', 'Schenck', 'sschenck30@isk.ac.ke', 'STUDENT', '11457', '6', 'MS'),
	(925, 'Isla', 'Willis', 'iwillis30@isk.ac.ke', 'STUDENT', '12969', '6', 'MS'),
	(926, 'Seya', 'Chandaria', 'schandaria30@isk.ac.ke', 'STUDENT', '10775', '6', 'MS'),
	(2, 'Rosa Marie', 'Rosen', NULL, 'STUDENT', '11764', '3', 'ES'),
	(3, 'August', 'Rosen', NULL, 'STUDENT', '11845', '9', 'HS'),
	(4, 'Dawit', 'Abdissa', NULL, 'STUDENT', '13077', '8', 'MS'),
	(5, 'Meron', 'Abdissa', NULL, 'STUDENT', '13078', '8', 'MS'),
	(6, 'Yohanna Wondim Belachew', 'Andersen', NULL, 'STUDENT', '12966', '1', 'ES'),
	(7, 'Yonas Wondim Belachew', 'Andersen', NULL, 'STUDENT', '12968', '10', 'HS'),
	(8, 'Cassandre', 'Camisa', NULL, 'STUDENT', '11881', '9', 'HS'),
	(9, 'Cole', 'Armstrong', NULL, 'STUDENT', '12277', '7', 'MS'),
	(10, 'Kennedy', 'Armstrong', NULL, 'STUDENT', '12276', '11', 'HS'),
	(11, 'Lily', 'De Backer', NULL, 'STUDENT', '11856', '10', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(12, 'Emma', 'Kuehnle', NULL, 'STUDENT', '11801', '5', 'ES'),
	(13, 'John (Trey)', 'Kuehnle', NULL, 'STUDENT', '11833', '7', 'MS'),
	(14, 'Rahsi', 'Abraha', NULL, 'STUDENT', '12465', '4', 'ES'),
	(15, 'Siyam', 'Abraha', NULL, 'STUDENT', '12464', '8', 'MS'),
	(16, 'Risty', 'Abraha', NULL, 'STUDENT', '12463', '9', 'HS'),
	(17, 'Seret', 'Abraha', NULL, 'STUDENT', '12462', '12', 'HS'),
	(927, 'Malan', 'Chopra', 'mchopra30@isk.ac.ke', 'STUDENT', '10508', '6', 'MS'),
	(928, 'Lilla', 'Vestergaard', 'svestergaard30@isk.ac.ke', 'STUDENT', '11266', '6', 'MS'),
	(929, 'Moussa', 'Sangare', 'msangare30@isk.ac.ke', 'STUDENT', '12427', '6', 'MS'),
	(930, 'Leo', 'Jansson', 'ljansson30@isk.ac.ke', 'STUDENT', '11762', '6', 'MS'),
	(931, 'Nora', 'Saleem', 'nsaleem30@isk.ac.ke', 'STUDENT', '12619', '6', 'MS'),
	(932, 'Kaisei', 'Stephens', 'kstephens30@isk.ac.ke', 'STUDENT', '11804', '6', 'MS'),
	(933, 'Olivia', 'Freiin Von Handel', 'ovonhandel30@isk.ac.ke', 'STUDENT', '12096', '6', 'MS'),
	(934, 'Kiara', 'Materne', 'kmaterne30@isk.ac.ke', 'STUDENT', '12152', '6', 'MS'),
	(935, 'Mikael', 'Eshetu', 'meshetu30@isk.ac.ke', 'STUDENT', '12689', '6', 'MS'),
	(936, 'Ignacio', 'Biafore', 'ibiafore30@isk.ac.ke', 'STUDENT', '12170', '6', 'MS'),
	(937, 'Romilly', 'Haysmith', 'rhaysmith30@isk.ac.ke', 'STUDENT', '12976', '6', 'MS'),
	(938, 'Alexander', 'Wietecha', 'awietecha30@isk.ac.ke', 'STUDENT', '12725', '6', 'MS'),
	(939, 'Julian', 'Dibling', 'jdibling30@isk.ac.ke', 'STUDENT', '12883', '6', 'MS'),
	(940, 'Gaia', 'Bonde-Nielsen', 'gbondenielsen30@isk.ac.ke', 'STUDENT', '12537', '6', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(941, 'Kush', 'Tanna', 'ktanna30@isk.ac.ke', 'STUDENT', '11096', '6', 'MS'),
	(942, 'Saqer', 'Alnaqbi', 'salnaqbi30@isk.ac.ke', 'STUDENT', '12909', '6', 'MS'),
	(943, 'Jack', 'Mcmurtry', 'jmcmurtry30@isk.ac.ke', 'STUDENT', '10812', '6', 'MS'),
	(944, 'Aiden', 'D''Souza', 'adsouza30@isk.ac.ke', 'STUDENT', '12500', '6', 'MS'),
	(945, 'Eliana', 'Hodge', 'ehodge29@isk.ac.ke', 'STUDENT', '12193', '7', 'MS'),
	(946, 'Abdul-Lateef Boluwatife (Bolu)', 'Dokunmu', 'adokunmu29@isk.ac.ke', 'STUDENT', '11463', '7', 'MS'),
	(947, 'Anaiya', 'Khubchandani', 'akhubchandani30@isk.ac.ke', 'STUDENT', '11262', '6', 'MS'),
	(948, 'Ariel', 'Mutombo', 'amutombo30@isk.ac.ke', 'STUDENT', '12549', '6', 'MS'),
	(949, 'Edie', 'Cutler', 'ecutler30@isk.ac.ke', 'STUDENT', '10686', '6', 'MS'),
	(950, 'Eugénie', 'Camisa', 'ecamisa30@isk.ac.ke', 'STUDENT', '11883', '6', 'MS'),
	(951, 'Finlay', 'Haswell', 'fhaswell30@isk.ac.ke', 'STUDENT', '10562', '6', 'MS'),
	(952, 'Yonatan Wondim Belachew', 'Andersen', 'ywondimandersen30@isk.ac.ke', 'STUDENT', '12967', '6', 'MS'),
	(953, 'Yoonseo', 'Choi', 'ychoi30@isk.ac.ke', 'STUDENT', '10708', '6', 'MS'),
	(954, 'Evan', 'Daines', 'edaines30@isk.ac.ke>', 'STUDENT', '13073', '6', 'MS'),
	(955, 'Holly', 'Mcmurtry', 'hmcmurtry30@isk.ac.ke', 'STUDENT', '10817', '6', 'MS'),
	(956, 'Max', 'Stock', 'mstock30@isk.ac.ke', 'STUDENT', '12915', '6', 'MS'),
	(957, 'Rowan', 'O''neill Calver', 'roneillcalver30@isk.ac.ke', 'STUDENT', '11458', '6', 'MS'),
	(958, 'Selma', 'Mensah', 'smensah30@isk.ac.ke', 'STUDENT', '12392', '6', 'MS'),
	(959, 'Ainsley', 'Hire', 'ahire29@isk.ac.ke', 'STUDENT', '10621', '7', 'MS'),
	(960, 'Aisha', 'Awori', 'aawori28@isk.ac.ke', 'STUDENT', '10474', '8', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(961, 'Caleb', 'Ross', 'cross28@isk.ac.ke', 'STUDENT', '11677', '8', 'MS'),
	(962, 'Ean', 'Kimuli', 'ekimuli29@isk.ac.ke', 'STUDENT', '11703', '7', 'MS'),
	(963, 'Emiliana', 'Jensen', 'ejensen28@isk.ac.ke', 'STUDENT', '11904', '8', 'MS'),
	(964, 'Giancarlo', 'Biafore', 'gbiafore28@isk.ac.ke', 'STUDENT', '12171', '8', 'MS'),
	(971, 'Sultan', 'Buksh', NULL, 'STUDENT', '11996', '8', 'MS'),
	(972, 'Olivia', 'Moons', NULL, 'STUDENT', '12852', '4', 'ES'),
	(973, 'Seung Hyun', 'Nam', 'shyun-nam30@isk.ac.ke', 'STUDENT', '13080', '6', 'MS'),
	(974, 'Tanay', 'Cherickel', 'tcherickel30@isk.ac.ke', 'STUDENT', '13007', '6', 'MS'),
	(975, 'Zayn', 'Khalid', 'zkhalid30@isk.ac.ke', 'STUDENT', '12616', '6', 'MS'),
	(976, 'Balazs', 'Meyers', 'bmeyers30@isk.ac.ke', 'STUDENT', '12621', '6', 'MS'),
	(977, 'Mahdiyah', 'Muneeb', 'mmuneeb30@isk.ac.ke', 'STUDENT', '12761', '6', 'MS'),
	(978, 'Mapalo', 'Birschbach', 'mbirschbach30@isk.ac.ke', 'STUDENT', '13050', '6', 'MS'),
	(979, 'Anastasia', 'Mulema', 'amulema30@isk.ac.ke', 'STUDENT', '11622', '6', 'MS'),
	(980, 'Etienne', 'Carlevato', 'ecarlevato29@isk.ac.ke', 'STUDENT', '12924', '7', 'MS'),
	(981, 'Lauren', 'Mucci', 'lmucci30@isk.ac.ke', 'STUDENT', '12694', '6', 'MS'),
	(982, 'Seth', 'Lundell', 'slundell30@isk.ac.ke', 'STUDENT', '12691', '6', 'MS'),
	(983, 'Evyn', 'Hobbs', 'ehobbs30@isk.ac.ke', 'STUDENT', '12973', '6', 'MS'),
	(984, 'Nirvi', 'Joymungul', 'njoymungul29@isk.ac.ke', 'STUDENT', '12997', '7', 'MS'),
	(985, 'Safiya', 'Menkerios', NULL, 'STUDENT', '11954', '4', 'ES'),
	(986, 'Tamas', 'Meyers', NULL, 'STUDENT', '12622', '4', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(987, 'Arianna', 'Mucci', NULL, 'STUDENT', '12695', '4', 'ES'),
	(988, 'Graham', 'Oberjuerge', NULL, 'STUDENT', '12686', '4', 'ES'),
	(1072, 'DUMMY 1', 'STUDENT', NULL, 'STUDENT', NULL, NULL, 'MS'),
	(1074, 'DUMMY 1', 'STUDENT', NULL, 'STUDENT', NULL, NULL, 'MS'),
	(1076, 'Mark', 'Anding', 'manding@isk.ac.ke', 'MUSIC TEACHER', NULL, NULL, 'MS'),
	(1077, 'Gwendolyn', 'Anding', 'ganding@isk.ac.ke', 'MUSIC TEACHER', NULL, NULL, 'HS'),
	(1079, 'Laois', 'Rogers', 'lrogers@isk.ac.ke', 'MUSIC TEACHER', NULL, NULL, 'ES'),
	(1080, 'Rachel', 'Aondo', 'raondo@isk.ac.ke', 'MUSIC TEACHER', NULL, NULL, 'ES'),
	(1071, 'Noah', 'Ochomo', 'nochomo@isk.ac.ke', 'MUSIC TA', NULL, NULL, 'MS'),
	(1075, 'Gakenia', 'Mucharie', 'gmucharie@isk.ac.ke', 'MUSIC TA', NULL, NULL, 'HS'),
	(1078, 'Margaret', 'Oganda', 'moganda@isk.ac.ke', 'MUSIC TA', NULL, NULL, 'ES'),
	(1081, 'Nellie', 'Odera', '
nodera.sub@isk.ac.ke', 'SUBSTITUTE', NULL, NULL, NULL),
	(965, 'Joan', 'Awori', 'jawori28@isk.ac.ke', 'STUDENT', '10475', '8', 'MS'),
	(966, 'Keza', 'Herman-Roloff', 'kherman-roloff29@isk.ac.ke', 'STUDENT', '12196', '7', 'MS'),
	(967, 'Milan', 'Jayaram', 'mijayaram29@isk.ac.ke', 'STUDENT', '10493', '7', 'MS'),
	(968, 'Nickolas', 'Jensen', 'njensen28@isk.ac.ke', 'STUDENT', '11926', '8', 'MS'),
	(969, 'Noam', 'Waalewijn', 'nwaalewijn28@isk.ac.ke', 'STUDENT', '12597', '8', 'MS'),
	(970, 'Wataru', 'Plunkett', 'wplunkett29@isk.ac.ke', 'STUDENT', '12853', '7', 'MS'),
	(990, 'Penelope', 'Schrader', NULL, 'STUDENT', '12839', '4', 'ES'),
	(991, 'Rebecca', 'Von Platen-Hallermund', NULL, 'STUDENT', '12887', '4', 'ES') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(992, 'Sebastian', 'Chappell', NULL, 'STUDENT', '12577', '5', 'ES'),
	(993, 'Alayna', 'Fritts', NULL, 'STUDENT', '12935', '5', 'ES'),
	(994, 'Riley', 'Janisse', NULL, 'STUDENT', '12676', '5', 'ES'),
	(995, 'Adam', 'Johnson', NULL, 'STUDENT', '12327', '5', 'ES'),
	(996, 'Elijah', 'Lundell', NULL, 'STUDENT', '12692', '5', 'ES'),
	(997, 'Johannah', 'Mpatswe', NULL, 'STUDENT', '12700', '5', 'ES'),
	(998, 'Bella', 'Bergqvist', NULL, 'STUDENT', '12913', '6', 'MS'),
	(999, 'Bertram', 'Birk', NULL, 'STUDENT', '12699', '6', 'MS'),
	(1000, 'Elijah', 'Carey', NULL, 'STUDENT', '12923', '6', 'MS'),
	(1001, 'Eva', 'Ryan', NULL, 'STUDENT', '12618', '6', 'MS'),
	(1002, 'Mitchell', 'Bagenda', NULL, 'STUDENT', '12146', '7', 'MS'),
	(1003, 'Luka', 'Breda', NULL, 'STUDENT', '12183', '7', 'MS'),
	(1004, 'Paco', 'Breda', NULL, 'STUDENT', '12184', '7', 'MS'),
	(1005, 'Camille', 'Corbin', NULL, 'STUDENT', '12941', '7', 'MS'),
	(1006, 'Colin', 'Eldridge', NULL, 'STUDENT', '12974', '7', 'MS'),
	(1007, 'Maya', 'Ferede', NULL, 'STUDENT', '11726', '7', 'MS'),
	(1008, 'Ava', 'Fritts', NULL, 'STUDENT', '12928', '7', 'MS'),
	(1009, 'Mahiro', 'Kishiue', NULL, 'STUDENT', '12679', '7', 'MS'),
	(1010, 'Lola', 'Lemley', NULL, 'STUDENT', '12870', '7', 'MS'),
	(1011, 'Wesley', 'Oberjuerge', NULL, 'STUDENT', '12685', '7', 'MS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(1012, 'Nicholas', 'Sobantu', NULL, 'STUDENT', '12940', '7', 'MS'),
	(1013, 'Elliot', 'Asquith', NULL, 'STUDENT', '12943', '8', 'MS'),
	(1014, 'Anshika', 'Basnet', NULL, 'STUDENT', '12450', '8', 'MS'),
	(1015, 'Fanny', 'Bergqvist', NULL, 'STUDENT', '12912', '8', 'MS'),
	(1016, 'Norah (Rebel)', 'Cizek', NULL, 'STUDENT', '12666', '8', 'MS'),
	(1017, 'Alexa', 'Janisse', NULL, 'STUDENT', '12675', '8', 'MS'),
	(1018, 'Tiago', 'Mendonca-Gray', NULL, 'STUDENT', '12948', '8', 'MS'),
	(1019, 'Alexa', 'Spitler', NULL, 'STUDENT', '12595', '8', 'MS'),
	(1020, 'Maia', 'Sykes', NULL, 'STUDENT', '12952', '8', 'MS'),
	(1021, 'Sonia', 'Weill', NULL, 'STUDENT', '12848', '8', 'MS'),
	(1022, 'Sienna', 'Zulberti', NULL, 'STUDENT', '12672', '8', 'MS'),
	(1023, 'Maya', 'Bagenda', NULL, 'STUDENT', '12147', '9', 'HS'),
	(1024, 'Muhammad Uneeb', 'Bakhshi', NULL, 'STUDENT', '12760', '9', 'HS'),
	(1025, 'Natasha', 'Birschbach', NULL, 'STUDENT', '13058', '9', 'HS'),
	(1026, 'Lara', 'Blanc Yeo', NULL, 'STUDENT', '12858', '9', 'HS'),
	(1027, 'Jai', 'Cherickel', NULL, 'STUDENT', '13006', '9', 'HS'),
	(1028, 'Samarth', 'Dalal', NULL, 'STUDENT', '12859', '9', 'HS'),
	(1029, 'Dan', 'Ephrem Yohannes', NULL, 'STUDENT', '11772', '9', 'HS'),
	(1030, 'Rowan', 'Hobbs', NULL, 'STUDENT', '12972', '9', 'HS'),
	(1031, 'Benjamin', 'Johansson-Desai', NULL, 'STUDENT', '13012', '9', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(1032, 'Vashnie', 'Joymungul', NULL, 'STUDENT', '12996', '9', 'HS'),
	(1033, 'Sphesihle', 'Kamenga', NULL, 'STUDENT', '12876', '9', 'HS'),
	(1034, 'Seung Yoon', 'Nam', NULL, 'STUDENT', '13079', '9', 'HS'),
	(1035, 'Ishita', 'Rathore', NULL, 'STUDENT', '12983', '9', 'HS'),
	(1036, 'Nicholas', 'Rex', NULL, 'STUDENT', '10884', '9', 'HS'),
	(1037, 'Asbjørn', 'Vestergaard', NULL, 'STUDENT', '12663', '9', 'HS'),
	(1038, 'Filip', 'Adamec', NULL, 'STUDENT', '12904', '10', 'HS'),
	(1039, 'Solveig', 'Andersen', NULL, 'STUDENT', '12569', '10', 'HS'),
	(1040, 'Eugène', 'Astier', NULL, 'STUDENT', '12790', '10', 'HS'),
	(1041, 'Elsa', 'Bergqvist', NULL, 'STUDENT', '12911', '10', 'HS'),
	(1042, 'Maximilian', 'Chappell', NULL, 'STUDENT', '12576', '10', 'HS'),
	(1043, 'Charlotte', 'De Geer-Howard', NULL, 'STUDENT', '12653', '10', 'HS'),
	(1044, 'Aarish', 'Islam', NULL, 'STUDENT', '13008', '10', 'HS'),
	(1045, 'Daniel', 'Johansson-Desai', NULL, 'STUDENT', '13011', '10', 'HS'),
	(1046, 'Dario', 'Lawrence', NULL, 'STUDENT', '11438', '10', 'HS'),
	(1047, 'Maximo', 'Lemley', NULL, 'STUDENT', '12869', '10', 'HS'),
	(1048, 'Lila', 'Roquitte', NULL, 'STUDENT', '12555', '10', 'HS'),
	(1049, 'Mathilde', 'Scanlon', NULL, 'STUDENT', '12558', '10', 'HS'),
	(1050, 'Chisanga', 'Birschbach', NULL, 'STUDENT', '13055', '11', 'HS'),
	(1051, 'Wade', 'Eldridge', NULL, 'STUDENT', '12975', '11', 'HS') ON CONFLICT DO NOTHING;
INSERT INTO "public"."users" ("id", "first_name", "last_name", "email", "role", "number", "grade_level", "division") VALUES
	(1052, 'Reem', 'Ephrem Yohannes', NULL, 'STUDENT', '11748', '11', 'HS'),
	(1053, 'Liam', 'Hobbs', NULL, 'STUDENT', '12971', '11', 'HS'),
	(1054, 'Daniel', 'Kadilli', NULL, 'STUDENT', '12991', '11', 'HS'),
	(1055, 'Jay Austin', 'Nimubona', NULL, 'STUDENT', '12749', '11', 'HS'),
	(1056, 'Anna Sophia', 'Stabrawa', NULL, 'STUDENT', '25052', '11', 'HS'),
	(1057, 'Elliot', 'Sykes', NULL, 'STUDENT', '12951', '11', 'HS'),
	(1058, 'Lalia', 'Sylla', NULL, 'STUDENT', '12628', '11', 'HS'),
	(1059, 'Camila', 'Valdivieso Santos', NULL, 'STUDENT', '12568', '11', 'HS'),
	(1060, 'Emma', 'Wright', NULL, 'STUDENT', '12567', '11', 'HS'),
	(1061, 'Dzidzor', 'Ata', NULL, 'STUDENT', '12651', '12', 'HS'),
	(1062, 'Nandini', 'Bhandari', NULL, 'STUDENT', '12738', '12', 'HS'),
	(1063, 'Isabella', 'De Geer-Howard', NULL, 'STUDENT', '12652', '12', 'HS'),
	(1064, 'Hanan', 'Khan', NULL, 'STUDENT', '10464', '12', 'HS'),
	(1065, 'Vincenzo', 'Lawrence', NULL, 'STUDENT', '11447', '12', 'HS'),
	(1066, 'Noah', 'Lutz', NULL, 'STUDENT', '24008', '12', 'HS'),
	(1067, 'Julian', 'Rex', NULL, 'STUDENT', '10922', '12', 'HS'),
	(1068, 'Luca', 'Scanlon', NULL, 'STUDENT', '12557', '12', 'HS'),
	(1069, 'Noah', 'Trenkle', NULL, 'STUDENT', '12556', '12', 'HS'),
	(1070, 'Theodore', 'Wright', 'twright28@isk.ac.ke', 'STUDENT', '12566', '8', 'MS') ON CONFLICT DO NOTHING;


--
-- TOC entry 3953 (class 0 OID 0)
-- Dependencies: 239
-- Name: all_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."all_instruments_id_seq"', 348, true);


--
-- TOC entry 3954 (class 0 OID 0)
-- Dependencies: 223
-- Name: class_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."class_id_seq"', 1, false);


--
-- TOC entry 3955 (class 0 OID 0)
-- Dependencies: 225
-- Name: dispatches_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."dispatches_id_seq"', 35, true);


--
-- TOC entry 3956 (class 0 OID 0)
-- Dependencies: 243
-- Name: duplicate_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."duplicate_instruments_id_seq"', 96, true);


--
-- TOC entry 3957 (class 0 OID 0)
-- Dependencies: 245
-- Name: hardware_and_equipment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."hardware_and_equipment_id_seq"', 20, true);


--
-- TOC entry 3958 (class 0 OID 0)
-- Dependencies: 235
-- Name: instrument_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."instrument_history_id_seq"', 2975, true);


--
-- TOC entry 3959 (class 0 OID 0)
-- Dependencies: 217
-- Name: instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."instruments_id_seq"', 4166, true);


--
-- TOC entry 3960 (class 0 OID 0)
-- Dependencies: 215
-- Name: legacy_database_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."legacy_database_id_seq"', 669, true);


--
-- TOC entry 3961 (class 0 OID 0)
-- Dependencies: 248
-- Name: locations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."locations_id_seq"', 16, true);


--
-- TOC entry 3962 (class 0 OID 0)
-- Dependencies: 241
-- Name: music_instruments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."music_instruments_id_seq"', 544, true);


--
-- TOC entry 3963 (class 0 OID 0)
-- Dependencies: 249
-- Name: new_instrument_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."new_instrument_id_seq"', 11, true);


--
-- TOC entry 3964 (class 0 OID 0)
-- Dependencies: 229
-- Name: repairs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."repairs_id_seq"', 1, false);


--
-- TOC entry 3965 (class 0 OID 0)
-- Dependencies: 233
-- Name: requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."requests_id_seq"', 1, false);


--
-- TOC entry 3966 (class 0 OID 0)
-- Dependencies: 231
-- Name: resolve_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."resolve_id_seq"', 1, false);


--
-- TOC entry 3967 (class 0 OID 0)
-- Dependencies: 227
-- Name: returns_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."returns_id_seq"', 26, true);


--
-- TOC entry 3968 (class 0 OID 0)
-- Dependencies: 219
-- Name: roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."roles_id_seq"', 11, true);


--
-- TOC entry 3969 (class 0 OID 0)
-- Dependencies: 237
-- Name: students_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."students_id_seq"', 1069, true);


--
-- TOC entry 3970 (class 0 OID 0)
-- Dependencies: 221
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('"public"."users_id_seq"', 1081, true);


--
-- TOC entry 3682 (class 2606 OID 24691)
-- Name: equipment all_instruments_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE "public"."equipment"
    ADD CONSTRAINT "all_instruments_family_check" CHECK (("upper"(("family")::"text") = ANY (ARRAY['STRING'::"text", 'WOODWIND'::"text", 'BRASS'::"text", 'PERCUSSION'::"text", 'MISCELLANEOUS'::"text", 'ELECTRIC'::"text", 'KEYBOARD'::"text", 'SOUND'::"text"]))) NOT VALID;


--
-- TOC entry 3727 (class 2606 OID 24641)
-- Name: equipment all_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."equipment"
    ADD CONSTRAINT "all_instruments_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3707 (class 2606 OID 24273)
-- Name: class class_class_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."class"
    ADD CONSTRAINT "class_class_name_key" UNIQUE ("class_name");


--
-- TOC entry 3709 (class 2606 OID 24271)
-- Name: class class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."class"
    ADD CONSTRAINT "class_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3711 (class 2606 OID 24285)
-- Name: dispatches dispatches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."dispatches"
    ADD CONSTRAINT "dispatches_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3739 (class 2606 OID 24665)
-- Name: duplicate_instruments duplicate_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."duplicate_instruments"
    ADD CONSTRAINT "duplicate_instruments_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3729 (class 2606 OID 24824)
-- Name: equipment equipment_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."equipment"
    ADD CONSTRAINT "equipment_code_key" UNIQUE ("code") INCLUDE ("code");


--
-- TOC entry 3731 (class 2606 OID 24643)
-- Name: equipment equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."equipment"
    ADD CONSTRAINT "equipment_description_key" UNIQUE ("description");


--
-- TOC entry 3741 (class 2606 OID 24690)
-- Name: hardware_and_equipment hardware_and_equipment_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."hardware_and_equipment"
    ADD CONSTRAINT "hardware_and_equipment_description_key" UNIQUE ("description");


--
-- TOC entry 3684 (class 2606 OID 24692)
-- Name: hardware_and_equipment hardware_and_equipment_family_check; Type: CHECK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE "public"."hardware_and_equipment"
    ADD CONSTRAINT "hardware_and_equipment_family_check" CHECK (("upper"(("family")::"text") = ANY (ARRAY['MISCELLANEOUS'::"text", 'SOUND'::"text"]))) NOT VALID;


--
-- TOC entry 3743 (class 2606 OID 24688)
-- Name: hardware_and_equipment hardware_and_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."hardware_and_equipment"
    ADD CONSTRAINT "hardware_and_equipment_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3723 (class 2606 OID 24369)
-- Name: instrument_history instrument_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instrument_history"
    ADD CONSTRAINT "instrument_history_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3691 (class 2606 OID 24845)
-- Name: instruments instruments_code_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instruments"
    ADD CONSTRAINT "instruments_code_number_key" UNIQUE ("code", "number");


--
-- TOC entry 3693 (class 2606 OID 24212)
-- Name: instruments instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instruments"
    ADD CONSTRAINT "instruments_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3695 (class 2606 OID 24214)
-- Name: instruments instruments_serial_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instruments"
    ADD CONSTRAINT "instruments_serial_key" UNIQUE ("serial");


--
-- TOC entry 3687 (class 2606 OID 23620)
-- Name: legacy_database legacy_database_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."legacy_database"
    ADD CONSTRAINT "legacy_database_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3733 (class 2606 OID 24831)
-- Name: music_instruments music_instruments_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."music_instruments"
    ADD CONSTRAINT "music_instruments_code_key" UNIQUE ("code") INCLUDE ("code");


--
-- TOC entry 3735 (class 2606 OID 24655)
-- Name: music_instruments music_instruments_description_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."music_instruments"
    ADD CONSTRAINT "music_instruments_description_key" UNIQUE ("description");


--
-- TOC entry 3737 (class 2606 OID 24653)
-- Name: music_instruments music_instruments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."music_instruments"
    ADD CONSTRAINT "music_instruments_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3715 (class 2606 OID 24320)
-- Name: repair_request repairs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."repair_request"
    ADD CONSTRAINT "repairs_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3719 (class 2606 OID 24802)
-- Name: requests requests_instrument_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_instrument_key" UNIQUE ("instrument");


--
-- TOC entry 3721 (class 2606 OID 24348)
-- Name: requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3717 (class 2606 OID 24334)
-- Name: resolve resolve_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."resolve"
    ADD CONSTRAINT "resolve_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3713 (class 2606 OID 24306)
-- Name: returns returns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."returns"
    ADD CONSTRAINT "returns_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3697 (class 2606 OID 24246)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3699 (class 2606 OID 24248)
-- Name: roles roles_role_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_role_name_key" UNIQUE ("role_name");


--
-- TOC entry 3745 (class 2606 OID 24735)
-- Name: locations room; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "room" UNIQUE ("room");


--
-- TOC entry 3725 (class 2606 OID 24390)
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3701 (class 2606 OID 24258)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");


--
-- TOC entry 3703 (class 2606 OID 24755)
-- Name: users users_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_number_key" UNIQUE ("number");


--
-- TOC entry 3705 (class 2606 OID 24256)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");


--
-- TOC entry 3688 (class 1259 OID 24817)
-- Name: fki_instruments_code_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "fki_instruments_code_fkey" ON "public"."instruments" USING "btree" ("code");


--
-- TOC entry 3689 (class 1259 OID 24726)
-- Name: fki_instruments_description_fkey; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "fki_instruments_description_fkey" ON "public"."instruments" USING "btree" ("description");


--
-- TOC entry 3760 (class 2620 OID 24775)
-- Name: dispatches assign_user; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "assign_user" BEFORE INSERT ON "public"."dispatches" FOR EACH ROW EXECUTE FUNCTION "public"."dispatch"();


--
-- TOC entry 3762 (class 2620 OID 24873)
-- Name: returns create_return; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "create_return" BEFORE INSERT ON "public"."returns" FOR EACH ROW EXECUTE FUNCTION "public"."return"();


--
-- TOC entry 3763 (class 2620 OID 24785)
-- Name: returns log_return; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "log_return" AFTER INSERT ON "public"."returns" FOR EACH ROW EXECUTE FUNCTION "public"."log_transaction"();


--
-- TOC entry 3761 (class 2620 OID 24780)
-- Name: dispatches log_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "log_transaction" AFTER INSERT ON "public"."dispatches" FOR EACH ROW EXECUTE FUNCTION "public"."log_transaction"();


--
-- TOC entry 3758 (class 2620 OID 24859)
-- Name: instruments new_instr; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "new_instr" AFTER INSERT OR UPDATE ON "public"."instruments" FOR EACH ROW EXECUTE FUNCTION "public"."log_transaction"();


--
-- TOC entry 3764 (class 2620 OID 24858)
-- Name: new_instrument new_instrument_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "new_instrument_trigger" AFTER INSERT ON "public"."new_instrument" FOR EACH ROW EXECUTE FUNCTION "public"."new_instr_function"();


--
-- TOC entry 3759 (class 2620 OID 24380)
-- Name: class trg_check_teacher_role; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER "trg_check_teacher_role" BEFORE INSERT OR UPDATE ON "public"."class" FOR EACH ROW EXECUTE FUNCTION "public"."check_teacher_role"();


--
-- TOC entry 3750 (class 2606 OID 24274)
-- Name: class class_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."class"
    ADD CONSTRAINT "class_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "public"."users"("id");


--
-- TOC entry 3751 (class 2606 OID 24295)
-- Name: dispatches dispatches_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."dispatches"
    ADD CONSTRAINT "dispatches_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."instruments"("id");


--
-- TOC entry 3757 (class 2606 OID 24375)
-- Name: instrument_history instrument_history_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instrument_history"
    ADD CONSTRAINT "instrument_history_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."instruments"("id");


--
-- TOC entry 3746 (class 2606 OID 24825)
-- Name: instruments instruments_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instruments"
    ADD CONSTRAINT "instruments_code_fkey" FOREIGN KEY ("code") REFERENCES "public"."equipment"("code") ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3747 (class 2606 OID 24721)
-- Name: instruments instruments_description_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instruments"
    ADD CONSTRAINT "instruments_description_fkey" FOREIGN KEY ("description") REFERENCES "public"."equipment"("description") ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3748 (class 2606 OID 24738)
-- Name: instruments instruments_location_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."instruments"
    ADD CONSTRAINT "instruments_location_fkey" FOREIGN KEY ("location") REFERENCES "public"."locations"("room") ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3753 (class 2606 OID 24796)
-- Name: repair_request repairs_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."repair_request"
    ADD CONSTRAINT "repairs_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."instruments"("id") ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3755 (class 2606 OID 24808)
-- Name: requests requests_instrument_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_instrument_fkey" FOREIGN KEY ("instrument") REFERENCES "public"."equipment"("description") NOT VALID;


--
-- TOC entry 3756 (class 2606 OID 24351)
-- Name: requests requests_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."requests"
    ADD CONSTRAINT "requests_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "public"."users"("id");


--
-- TOC entry 3754 (class 2606 OID 24335)
-- Name: resolve resolve_case_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."resolve"
    ADD CONSTRAINT "resolve_case_fkey" FOREIGN KEY ("case") REFERENCES "public"."repair_request"("id");


--
-- TOC entry 3752 (class 2606 OID 24791)
-- Name: returns returns_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."returns"
    ADD CONSTRAINT "returns_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."instruments"("id") ON UPDATE CASCADE NOT VALID;


--
-- TOC entry 3749 (class 2606 OID 24259)
-- Name: users users_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_role_fkey" FOREIGN KEY ("role") REFERENCES "public"."roles"("role_name");


-- Completed on 2024-02-13 11:10:30 EAT

--
-- PostgreSQL database dump complete
--

