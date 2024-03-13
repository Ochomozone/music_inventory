PGDMP                      |         	   inventory    15.6 (Postgres.app)    16.0 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    22156 	   inventory    DATABASE     �   CREATE DATABASE inventory WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = icu LOCALE = 'en_US.UTF-8' ICU_LOCALE = 'en-US';
    DROP DATABASE inventory;
                postgres    false                        2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                pg_database_owner    false            �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                   pg_database_owner    false    5            4           1255    22925    check_teacher_role()    FUNCTION     !  CREATE FUNCTION public.check_teacher_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (SELECT role FROM users WHERE id = NEW.teacher_id) <> 'TEACHER' THEN
    RAISE EXCEPTION 'Teacher_id must correspond to a user with the role "TEACHER".';
  END IF;
  RETURN NEW;
END;
$$;
 +   DROP FUNCTION public.check_teacher_role();
       public          postgres    false    5            H           1255    27833    create_roles()    FUNCTION     �  CREATE FUNCTION public.create_roles() RETURNS void
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
 %   DROP FUNCTION public.create_roles();
       public          postgres    false    5            G           1255    24774 
   dispatch()    FUNCTION     �  CREATE FUNCTION public.dispatch() RETURNS trigger
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
 !   DROP FUNCTION public.dispatch();
       public          postgres    false    5            <           1255    24759    get_division(character varying)    FUNCTION     �  CREATE FUNCTION public.get_division(grade_level character varying) RETURNS character varying
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
 B   DROP FUNCTION public.get_division(grade_level character varying);
       public          postgres    false    5            C           1255    25099 *   get_instruments_by_name(character varying)    FUNCTION     �  CREATE FUNCTION public.get_instruments_by_name(p_name character varying) RETURNS TABLE(description public.citext, make public.citext, number integer, username character varying)
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
 H   DROP FUNCTION public.get_instruments_by_name(p_name character varying);
       public          postgres    false    5    5    5    5    5    5    5    5    5    5    5            ?           1255    25009 /   get_item_id_by_code(character varying, integer)    FUNCTION       CREATE FUNCTION public.get_item_id_by_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE code = p_code
    AND number = p_number;
END;
$$;
 k   DROP FUNCTION public.get_item_id_by_code(p_code character varying, p_number integer, OUT item_id integer);
       public          postgres    false    5            =           1255    25007 6   get_item_id_by_description(character varying, integer)    FUNCTION     Q  CREATE FUNCTION public.get_item_id_by_description(p_description character varying, p_number integer) RETURNS integer
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
 d   DROP FUNCTION public.get_item_id_by_description(p_description character varying, p_number integer);
       public          postgres    false    5            >           1255    25008 3   get_item_id_by_old_code(character varying, integer)    FUNCTION     !  CREATE FUNCTION public.get_item_id_by_old_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE legacy_code = p_code
    AND number = p_number;
END;
$$;
 o   DROP FUNCTION public.get_item_id_by_old_code(p_code character varying, p_number integer, OUT item_id integer);
       public          postgres    false    5            @           1255    25010 (   get_item_id_by_serial(character varying)    FUNCTION     �   CREATE FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE "serial" = p_serial;
END;
$$;
 ]   DROP FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer);
       public          postgres    false    5            A           1255    25033 (   get_user_id_by_number(character varying)    FUNCTION     �   CREATE FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM all_users_view
    WHERE "number" = p_number;
END;
$$;
 ]   DROP FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer);
       public          postgres    false    5            E           1255    27714 &   get_user_id_by_role(character varying)    FUNCTION     �   CREATE FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM users
    WHERE "username" = p_role;
END;
$$;
 Y   DROP FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer);
       public          postgres    false    5            /           1255    22927 1   insert_type(character varying, character varying)    FUNCTION     �   CREATE FUNCTION public.insert_type(p_code character varying, p_description character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO types (code, description) VALUES (UPPER(p_code), UPPER(p_description));
END;
$$;
 ]   DROP FUNCTION public.insert_type(p_code character varying, p_description character varying);
       public          postgres    false    5            I           1255    24770    log_transaction()    FUNCTION     �  CREATE FUNCTION public.log_transaction() RETURNS trigger
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
 (   DROP FUNCTION public.log_transaction();
       public          postgres    false    5            F           1255    24846    new_instr_function()    FUNCTION     }  CREATE FUNCTION public.new_instr_function() RETURNS trigger
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
 +   DROP FUNCTION public.new_instr_function();
       public          postgres    false    5            D           1255    27834    return()    FUNCTION       CREATE FUNCTION public.return() RETURNS trigger
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
    DROP FUNCTION public.return();
       public          postgres    false    5            B           1255    25048 &   search_user_by_name(character varying)    FUNCTION     �  CREATE FUNCTION public.search_user_by_name(p_name character varying, OUT user_id integer, OUT full_name text, OUT grade_level character varying) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT all_users_view.id, all_users_view.full_name, all_users_view.grade_level
    FROM all_users_view
    WHERE all_users_view.full_name ILIKE '%' || p_name || '%';
END;
$$;
 �   DROP FUNCTION public.search_user_by_name(p_name character varying, OUT user_id integer, OUT full_name text, OUT grade_level character varying);
       public          postgres    false    5            �            1259    24634 	   equipment    TABLE     �   CREATE TABLE public.equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);
    DROP TABLE public.equipment;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24633    all_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.all_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    240            �            1259    24202    instruments    TABLE     �  CREATE TABLE public.instruments (
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
    DROP TABLE public.instruments;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24250    users    TABLE     Z  CREATE TABLE public.users (
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
    DROP TABLE public.users;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24998    all_instruments_view    VIEW     "  CREATE VIEW public.all_instruments_view AS
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
 '   DROP VIEW public.all_instruments_view;
       public          postgres    false    222    218    218    218    218    218    218    218    222    222    218    218    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    218    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24383    students    TABLE     �  CREATE TABLE public.students (
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
    DROP TABLE public.students;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5                        1259    27844    all_users_view    VIEW       CREATE VIEW public.all_users_view AS
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
 !   DROP VIEW public.all_users_view;
       public          postgres    false    222    222    222    222    222    222    222    222    238    238    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24265    class    TABLE     z   CREATE TABLE public.class (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    class_name character varying
);
    DROP TABLE public.class;
       public         heap    postgres    false    5            �            1259    24264    class_id_seq    SEQUENCE     �   ALTER TABLE public.class ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    224            �            1259    27836    dispatched_instruments_view    VIEW     W  CREATE VIEW public.dispatched_instruments_view AS
 SELECT all_instruments_view.id,
    all_instruments_view.description,
    all_instruments_view.number,
    all_instruments_view.make,
    all_instruments_view.serial,
    all_instruments_view.user_name
   FROM public.all_instruments_view
  WHERE (all_instruments_view.user_name IS NOT NULL);
 .   DROP VIEW public.dispatched_instruments_view;
       public          postgres    false    252    252    252    252    252    252    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24280 
   dispatches    TABLE     �   CREATE TABLE public.dispatches (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    user_id integer,
    item_id integer,
    created_by character varying
);
    DROP TABLE public.dispatches;
       public         heap    postgres    false    5            �            1259    24279    dispatches_id_seq    SEQUENCE     �   ALTER TABLE public.dispatches ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dispatches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    226    5            �            1259    24657    duplicate_instruments    TABLE        CREATE TABLE public.duplicate_instruments (
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
 )   DROP TABLE public.duplicate_instruments;
       public         heap    postgres    false    5            �            1259    24656    duplicate_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.duplicate_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.duplicate_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    244    5            �            1259    24681    hardware_and_equipment    TABLE     �   CREATE TABLE public.hardware_and_equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);
 *   DROP TABLE public.hardware_and_equipment;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24680    hardware_and_equipment_id_seq    SEQUENCE     �   ALTER TABLE public.hardware_and_equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.hardware_and_equipment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    246    5            �            1259    24362    instrument_history    TABLE       CREATE TABLE public.instrument_history (
    id integer NOT NULL,
    transaction_type character varying NOT NULL,
    transaction_timestamp date DEFAULT CURRENT_DATE,
    item_id integer NOT NULL,
    notes text,
    assigned_to character varying,
    created_by character varying
);
 &   DROP TABLE public.instrument_history;
       public         heap    postgres    false    5                       1259    27864    history_view    VIEW     2  CREATE VIEW public.history_view AS
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
    DROP VIEW public.history_view;
       public          postgres    false    218    222    222    222    218    218    236    236    236    236    236    236    222    5            �            1259    24951    instrument_distribution_view    VIEW     �  CREATE VIEW public.instrument_distribution_view AS
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
 /   DROP VIEW public.instrument_distribution_view;
       public          postgres    false    218    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    218    218    218    218    218    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24361    instrument_history_id_seq    SEQUENCE     �   ALTER TABLE public.instrument_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    236    5            �            1259    24201    instruments_id_seq    SEQUENCE     �   ALTER TABLE public.instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    218    5            �            1259    23612    legacy_database    TABLE     S  CREATE TABLE public.legacy_database (
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
 #   DROP TABLE public.legacy_database;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5            �            1259    23611    legacy_database_id_seq    SEQUENCE     �   ALTER TABLE public.legacy_database ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.legacy_database_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    216            �            1259    24727 	   locations    TABLE     \   CREATE TABLE public.locations (
    room public.citext NOT NULL,
    id integer NOT NULL
);
    DROP TABLE public.locations;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5            �            1259    24743    locations_id_seq    SEQUENCE     �   ALTER TABLE public.locations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    247    5            �            1259    24646    music_instruments    TABLE     �  CREATE TABLE public.music_instruments (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext NOT NULL,
    notes character varying,
    CONSTRAINT music_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text])))
);
 %   DROP TABLE public.music_instruments;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24645    music_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.music_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.music_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    242            �            1259    24850    new_instrument    TABLE     �  CREATE TABLE public.new_instrument (
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
 "   DROP TABLE public.new_instrument;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �            1259    24849    new_instrument_id_seq    SEQUENCE     �   ALTER TABLE public.new_instrument ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.new_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1
);
            public          postgres    false    250    5            �            1259    25128    receive_instrument    TABLE     �   CREATE TABLE public.receive_instrument (
    id integer NOT NULL,
    created_by_id integer,
    instrument_id integer,
    room public.citext
);
 &   DROP TABLE public.receive_instrument;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5            �            1259    25127    receive_instrument_id_seq    SEQUENCE     �   ALTER TABLE public.receive_instrument ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.receive_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    254    5            �            1259    24313    repair_request    TABLE     �   CREATE TABLE public.repair_request (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    complaint text NOT NULL
);
 "   DROP TABLE public.repair_request;
       public         heap    postgres    false    5            �            1259    24312    repairs_id_seq    SEQUENCE     �   ALTER TABLE public.repair_request ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.repairs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    230    5            �            1259    24341    requests    TABLE     �   CREATE TABLE public.requests (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    teacher_id integer,
    instrument public.citext NOT NULL,
    quantity integer NOT NULL
);
    DROP TABLE public.requests;
       public         heap    postgres    false    5    5    5    5    5    5    5    5    5    5    5            �            1259    24340    requests_id_seq    SEQUENCE     �   ALTER TABLE public.requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    234    5            �            1259    24327    resolve    TABLE     �   CREATE TABLE public.resolve (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    "case" integer,
    notes text
);
    DROP TABLE public.resolve;
       public         heap    postgres    false    5            �            1259    24326    resolve_id_seq    SEQUENCE     �   ALTER TABLE public.resolve ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.resolve_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    232            �            1259    24301    returns    TABLE     �   CREATE TABLE public.returns (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    created_by character varying
);
    DROP TABLE public.returns;
       public         heap    postgres    false    5            �            1259    24300    returns_id_seq    SEQUENCE     �   ALTER TABLE public.returns ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.returns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    228            �            1259    24238    roles    TABLE     }   CREATE TABLE public.roles (
    id integer NOT NULL,
    role_name character varying DEFAULT 'STUDENT'::character varying
);
    DROP TABLE public.roles;
       public         heap    postgres    false    5            �            1259    24237    roles_id_seq    SEQUENCE     �   ALTER TABLE public.roles ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    220            �            1259    24382    students_id_seq    SEQUENCE     �   ALTER TABLE public.students ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.students_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    238            �            1259    24249    users_id_seq    SEQUENCE     �   ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    5    222            b          0    24265    class 
   TABLE DATA                 public          postgres    false    224   �!      d          0    24280 
   dispatches 
   TABLE DATA                 public          postgres    false    226   �!      v          0    24657    duplicate_instruments 
   TABLE DATA                 public          postgres    false    244   s#      r          0    24634 	   equipment 
   TABLE DATA                 public          postgres    false    240   (      x          0    24681    hardware_and_equipment 
   TABLE DATA                 public          postgres    false    246   p8      n          0    24362    instrument_history 
   TABLE DATA                 public          postgres    false    236   �9      \          0    24202    instruments 
   TABLE DATA                 public          postgres    false    218   v>      Z          0    23612    legacy_database 
   TABLE DATA                 public          postgres    false    216   �x      y          0    24727 	   locations 
   TABLE DATA                 public          postgres    false    247   d�      t          0    24646    music_instruments 
   TABLE DATA                 public          postgres    false    242   W�      |          0    24850    new_instrument 
   TABLE DATA                 public          postgres    false    250   ��      ~          0    25128    receive_instrument 
   TABLE DATA                 public          postgres    false    254   ��      h          0    24313    repair_request 
   TABLE DATA                 public          postgres    false    230   �      l          0    24341    requests 
   TABLE DATA                 public          postgres    false    234   -�      j          0    24327    resolve 
   TABLE DATA                 public          postgres    false    232   G�      f          0    24301    returns 
   TABLE DATA                 public          postgres    false    228   a�      ^          0    24238    roles 
   TABLE DATA                 public          postgres    false    220   [�      p          0    24383    students 
   TABLE DATA                 public          postgres    false    238   �      `          0    24250    users 
   TABLE DATA                 public          postgres    false    222   �J      �           0    0    all_instruments_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.all_instruments_id_seq', 348, true);
          public          postgres    false    239            �           0    0    class_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.class_id_seq', 1, false);
          public          postgres    false    223            �           0    0    dispatches_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.dispatches_id_seq', 127, true);
          public          postgres    false    225            �           0    0    duplicate_instruments_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.duplicate_instruments_id_seq', 96, true);
          public          postgres    false    243            �           0    0    hardware_and_equipment_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.hardware_and_equipment_id_seq', 20, true);
          public          postgres    false    245            �           0    0    instrument_history_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.instrument_history_id_seq', 3144, true);
          public          postgres    false    235            �           0    0    instruments_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.instruments_id_seq', 4166, true);
          public          postgres    false    217            �           0    0    legacy_database_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.legacy_database_id_seq', 669, true);
          public          postgres    false    215            �           0    0    locations_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.locations_id_seq', 16, true);
          public          postgres    false    248            �           0    0    music_instruments_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.music_instruments_id_seq', 544, true);
          public          postgres    false    241            �           0    0    new_instrument_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.new_instrument_id_seq', 11, true);
          public          postgres    false    249            �           0    0    receive_instrument_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.receive_instrument_id_seq', 1, false);
          public          postgres    false    253            �           0    0    repairs_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.repairs_id_seq', 1, false);
          public          postgres    false    229            �           0    0    requests_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.requests_id_seq', 1, false);
          public          postgres    false    233            �           0    0    resolve_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.resolve_id_seq', 1, false);
          public          postgres    false    231            �           0    0    returns_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.returns_id_seq', 98, true);
          public          postgres    false    227            �           0    0    roles_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.roles_id_seq', 11, true);
          public          postgres    false    219            �           0    0    students_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.students_id_seq', 1069, true);
          public          postgres    false    237            �           0    0    users_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.users_id_seq', 1082, true);
          public          postgres    false    221            m           2606    24691 &   equipment all_instruments_family_check    CHECK CONSTRAINT       ALTER TABLE public.equipment
    ADD CONSTRAINT all_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text, 'SOUND'::text]))) NOT VALID;
 K   ALTER TABLE public.equipment DROP CONSTRAINT all_instruments_family_check;
       public          postgres    false    240    240            �           2606    24641    equipment all_instruments_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT all_instruments_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.equipment DROP CONSTRAINT all_instruments_pkey;
       public            postgres    false    240            �           2606    24273    class class_class_name_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_class_name_key UNIQUE (class_name);
 D   ALTER TABLE ONLY public.class DROP CONSTRAINT class_class_name_key;
       public            postgres    false    224            �           2606    24271    class class_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.class DROP CONSTRAINT class_pkey;
       public            postgres    false    224            �           2606    24285    dispatches dispatches_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.dispatches DROP CONSTRAINT dispatches_pkey;
       public            postgres    false    226            �           2606    24665 0   duplicate_instruments duplicate_instruments_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.duplicate_instruments
    ADD CONSTRAINT duplicate_instruments_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.duplicate_instruments DROP CONSTRAINT duplicate_instruments_pkey;
       public            postgres    false    244            �           2606    24824    equipment equipment_code_key 
   CONSTRAINT     f   ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_code_key UNIQUE (code) INCLUDE (code);
 F   ALTER TABLE ONLY public.equipment DROP CONSTRAINT equipment_code_key;
       public            postgres    false    240            �           2606    24643 #   equipment equipment_description_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_description_key UNIQUE (description);
 M   ALTER TABLE ONLY public.equipment DROP CONSTRAINT equipment_description_key;
       public            postgres    false    240            �           2606    24690 =   hardware_and_equipment hardware_and_equipment_description_key 
   CONSTRAINT        ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_description_key UNIQUE (description);
 g   ALTER TABLE ONLY public.hardware_and_equipment DROP CONSTRAINT hardware_and_equipment_description_key;
       public            postgres    false    246            o           2606    24692 :   hardware_and_equipment hardware_and_equipment_family_check    CHECK CONSTRAINT     �   ALTER TABLE public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_family_check CHECK ((upper((family)::text) = ANY (ARRAY['MISCELLANEOUS'::text, 'SOUND'::text]))) NOT VALID;
 _   ALTER TABLE public.hardware_and_equipment DROP CONSTRAINT hardware_and_equipment_family_check;
       public          postgres    false    246    246            �           2606    24688 2   hardware_and_equipment hardware_and_equipment_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.hardware_and_equipment DROP CONSTRAINT hardware_and_equipment_pkey;
       public            postgres    false    246            �           2606    24369 *   instrument_history instrument_history_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.instrument_history DROP CONSTRAINT instrument_history_pkey;
       public            postgres    false    236            v           2606    24845 '   instruments instruments_code_number_key 
   CONSTRAINT     j   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_number_key UNIQUE (code, number);
 Q   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_code_number_key;
       public            postgres    false    218    218            x           2606    24212    instruments instruments_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_pkey;
       public            postgres    false    218            z           2606    24214 "   instruments instruments_serial_key 
   CONSTRAINT     _   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_serial_key UNIQUE (serial);
 L   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_serial_key;
       public            postgres    false    218            r           2606    23620 $   legacy_database legacy_database_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.legacy_database
    ADD CONSTRAINT legacy_database_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.legacy_database DROP CONSTRAINT legacy_database_pkey;
       public            postgres    false    216            �           2606    25112    locations locations_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.locations DROP CONSTRAINT locations_pkey;
       public            postgres    false    247            �           2606    24831 ,   music_instruments music_instruments_code_key 
   CONSTRAINT     v   ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_code_key UNIQUE (code) INCLUDE (code);
 V   ALTER TABLE ONLY public.music_instruments DROP CONSTRAINT music_instruments_code_key;
       public            postgres    false    242            �           2606    24655 3   music_instruments music_instruments_description_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_description_key UNIQUE (description);
 ]   ALTER TABLE ONLY public.music_instruments DROP CONSTRAINT music_instruments_description_key;
       public            postgres    false    242            �           2606    24653 (   music_instruments music_instruments_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.music_instruments DROP CONSTRAINT music_instruments_pkey;
       public            postgres    false    242            �           2606    25134 *   receive_instrument receive_instrument_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.receive_instrument
    ADD CONSTRAINT receive_instrument_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.receive_instrument DROP CONSTRAINT receive_instrument_pkey;
       public            postgres    false    254            �           2606    24320    repair_request repairs_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_pkey PRIMARY KEY (id);
 E   ALTER TABLE ONLY public.repair_request DROP CONSTRAINT repairs_pkey;
       public            postgres    false    230            �           2606    24802     requests requests_instrument_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_instrument_key UNIQUE (instrument);
 J   ALTER TABLE ONLY public.requests DROP CONSTRAINT requests_instrument_key;
       public            postgres    false    234            �           2606    24348    requests requests_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.requests DROP CONSTRAINT requests_pkey;
       public            postgres    false    234            �           2606    24334    resolve resolve_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.resolve DROP CONSTRAINT resolve_pkey;
       public            postgres    false    232            �           2606    24306    returns returns_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.returns DROP CONSTRAINT returns_pkey;
       public            postgres    false    228            |           2606    24246    roles roles_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.roles DROP CONSTRAINT roles_pkey;
       public            postgres    false    220            ~           2606    24248    roles roles_role_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_role_name_key UNIQUE (role_name);
 C   ALTER TABLE ONLY public.roles DROP CONSTRAINT roles_role_name_key;
       public            postgres    false    220            �           2606    24735    locations room 
   CONSTRAINT     I   ALTER TABLE ONLY public.locations
    ADD CONSTRAINT room UNIQUE (room);
 8   ALTER TABLE ONLY public.locations DROP CONSTRAINT room;
       public            postgres    false    247            �           2606    24390    students students_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.students DROP CONSTRAINT students_pkey;
       public            postgres    false    238            �           2606    24258    users users_email_key 
   CONSTRAINT     Q   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);
 ?   ALTER TABLE ONLY public.users DROP CONSTRAINT users_email_key;
       public            postgres    false    222            �           2606    24755    users users_number_key 
   CONSTRAINT     S   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_number_key UNIQUE (number);
 @   ALTER TABLE ONLY public.users DROP CONSTRAINT users_number_key;
       public            postgres    false    222            �           2606    24256    users users_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public            postgres    false    222            s           1259    24817    fki_instruments_code_fkey    INDEX     Q   CREATE INDEX fki_instruments_code_fkey ON public.instruments USING btree (code);
 -   DROP INDEX public.fki_instruments_code_fkey;
       public            postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    218            t           1259    24726     fki_instruments_description_fkey    INDEX     _   CREATE INDEX fki_instruments_description_fkey ON public.instruments USING btree (description);
 4   DROP INDEX public.fki_instruments_description_fkey;
       public            postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    218            �           2620    24775    dispatches assign_user    TRIGGER     o   CREATE TRIGGER assign_user BEFORE INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.dispatch();
 /   DROP TRIGGER assign_user ON public.dispatches;
       public          postgres    false    327    226            �           2620    27161    returns log_return    TRIGGER     q   CREATE TRIGGER log_return AFTER INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 +   DROP TRIGGER log_return ON public.returns;
       public          postgres    false    329    228            �           2620    24780    dispatches log_transaction    TRIGGER     y   CREATE TRIGGER log_transaction AFTER INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 3   DROP TRIGGER log_transaction ON public.dispatches;
       public          postgres    false    226    329            �           2620    24859    instruments new_instr    TRIGGER     ~   CREATE TRIGGER new_instr AFTER INSERT OR UPDATE ON public.instruments FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 .   DROP TRIGGER new_instr ON public.instruments;
       public          postgres    false    329    218            �           2620    24858 %   new_instrument new_instrument_trigger    TRIGGER     �   CREATE TRIGGER new_instrument_trigger AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.new_instr_function();
 >   DROP TRIGGER new_instrument_trigger ON public.new_instrument;
       public          postgres    false    250    326            �           2620    27835    returns return_trigger    TRIGGER     m   CREATE TRIGGER return_trigger BEFORE INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.return();
 /   DROP TRIGGER return_trigger ON public.returns;
       public          postgres    false    228    324            �           2620    24380    class trg_check_teacher_role    TRIGGER     �   CREATE TRIGGER trg_check_teacher_role BEFORE INSERT OR UPDATE ON public.class FOR EACH ROW EXECUTE FUNCTION public.check_teacher_role();
 5   DROP TRIGGER trg_check_teacher_role ON public.class;
       public          postgres    false    308    224            �           2606    24274    class class_teacher_id_fkey    FK CONSTRAINT     }   ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
 E   ALTER TABLE ONLY public.class DROP CONSTRAINT class_teacher_id_fkey;
       public          postgres    false    224    222    3716            �           2606    24295 "   dispatches dispatches_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);
 L   ALTER TABLE ONLY public.dispatches DROP CONSTRAINT dispatches_item_id_fkey;
       public          postgres    false    3704    218    226            �           2606    24375 2   instrument_history instrument_history_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);
 \   ALTER TABLE ONLY public.instrument_history DROP CONSTRAINT instrument_history_item_id_fkey;
       public          postgres    false    218    236    3704            �           2606    24825 !   instruments instruments_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_fkey FOREIGN KEY (code) REFERENCES public.equipment(code) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 K   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_code_fkey;
       public          postgres    false    240    218    3740    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �           2606    24721 (   instruments instruments_description_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_description_fkey FOREIGN KEY (description) REFERENCES public.equipment(description) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 R   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_description_fkey;
       public          postgres    false    240    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    3742    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    218            �           2606    24738 %   instruments instruments_location_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_location_fkey FOREIGN KEY (location) REFERENCES public.locations(room) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 O   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_location_fkey;
       public          postgres    false    218    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    247    3758    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5            �           2606    25135 7   receive_instrument receive_instruments_instrument_id_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.receive_instrument
    ADD CONSTRAINT receive_instruments_instrument_id_fk FOREIGN KEY (instrument_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;
 a   ALTER TABLE ONLY public.receive_instrument DROP CONSTRAINT receive_instruments_instrument_id_fk;
       public          postgres    false    254    3704    218            �           2606    24796 #   repair_request repairs_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;
 M   ALTER TABLE ONLY public.repair_request DROP CONSTRAINT repairs_item_id_fkey;
       public          postgres    false    218    3704    230            �           2606    24808 !   requests requests_instrument_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_instrument_fkey FOREIGN KEY (instrument) REFERENCES public.equipment(description) NOT VALID;
 K   ALTER TABLE ONLY public.requests DROP CONSTRAINT requests_instrument_fkey;
       public          postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    3742    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    240    234            �           2606    24351 !   requests requests_teacher_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
 K   ALTER TABLE ONLY public.requests DROP CONSTRAINT requests_teacher_id_fkey;
       public          postgres    false    222    234    3716            �           2606    24335    resolve resolve_case_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_case_fkey FOREIGN KEY ("case") REFERENCES public.repair_request(id);
 C   ALTER TABLE ONLY public.resolve DROP CONSTRAINT resolve_case_fkey;
       public          postgres    false    230    3726    232            �           2606    24791    returns returns_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;
 F   ALTER TABLE ONLY public.returns DROP CONSTRAINT returns_item_id_fkey;
       public          postgres    false    3704    218    228            �           2606    25155    users user_room_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users
    ADD CONSTRAINT user_room_fk FOREIGN KEY (room) REFERENCES public.locations(room) ON UPDATE CASCADE NOT VALID;
 <   ALTER TABLE ONLY public.users DROP CONSTRAINT user_room_fk;
       public          postgres    false    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    222    3758    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    5    247            �           2606    24259    users users_role_fkey    FK CONSTRAINT     x   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.roles(role_name);
 ?   ALTER TABLE ONLY public.users DROP CONSTRAINT users_role_fkey;
       public          postgres    false    3710    220    222            b   
   x���          d   �  x���AO�0�|�޶%�����d�T�c^��G�d��wS�@[���_���JD��SB�(���y���m^�U��J2η6I�ٺʶ�ue�S�W��*ۯ�O7��|.��j�MFH�O)L�l�E� ��ɡ(��cV�&�#3���x�5� ��,�p��O�p3y5obd_��	�����U���m��5�h`���V���
k��?�
�|��H�Y݇�,!w1���1�n��On�����;�AX��z�oZ�6m��x���
��i�:]�S���U}^|�l�~}Gk�~[���V��UX�l��2�������tRj@Q����Ϸ(3��k�t�@-V����,]ֶ���{ @��m `lm������\��	��-��B��뀮+NE������S�      v   �  x�ݚ�n�F����;% ����^�-�bC�I5͕��j*T�]
���#7�B������^X"���ٝ�Fʊ:��M�n����������.���f���-7k�f~������l����K{yw�����z��K�����=A��3�xs5[$h=[�[�|�h����Z��e{��c}�����b��Y�_��j�ٮ�S��j�iZ����$���.���끻h��x�6	:E�s��K�2o��]�<w��.���Ïo�����;un�{�ǲ~̊!H�ϧM
��8͊���;�'���HB�A� +j��iѠ�)�t���y"2O�%�1Ց%�d�vdwWM�(cbp�pTɧc��`��`��`	N�[_Nxg/��ʊ��¿H!�IIد104����8��8��|l��i]g��e�(�̋"�P�h��&��Ĭ����QY�	��`92&�;��GG�8��sPY���x�gg��(��[�O�W���DY
�������b�0<�N�'��3E]q!�!�/V2��
�������U'A�iPu�^p;����r�v�];ek�1ӂz�xT�;�#~(G�;:�8R��&#0����D�M��ϩ�Q�W�U�
H��6i�l�[�ͪ���ݮ��5�s�������Wn;v!�PF�v���(��Z�]g!š"��L����
�Q����r�#"qd$���ё8&G�HHwI�|��ɴ�8)�� X�'7���Ó�.�G�@7�v� ���Ti>�{�9!�g��՗��U`}X߭0�@��=�i�ܫi�88敻I�,���0$���p,(U^��`D8H��c�~癭�����^�c̍W�K��ꗂ&������k���JN[��@�$ub�6��`B����IE"q`C���,1ګ�T,�	��0^}���¯KW"
�轅�\������-<�!��m����A�i�����I����
|Uo`:��O���}�I����M�)�`�<�2���oY��V�̄�Lz�	-#0T���0�
x���Ās���8�g�J�`��|Cq�u�R��Of��A�T�����4kl� ����l/Nle�Y�C���l�W��+���|��Q�5O��`*^�*����{�������$�E���e�v''� P��      r      x�Ŝ͒����S�6�U3�HJ"Y9�$Dr~ g���{��*�vb��G�C��$���7��)5��vf�	���h4@5��z�n샟�����������������O�_����~
����w������)���߾���?��������?�����P�4_��1~
r-�y��*%�ݤ��ku��Óm�vZO�^eI�=E6)�6�?��օ�����OA�)�S*�S

�~@:�����Ԏ;
�+ z�Iz�چn[;�C_���\�)������=�*\���������*��MYIݔ=1|Y� ���4�}�L����O��툕��[Y�R)
��@ ;5UR���n��� ���:` �~ni͢F��u�.���AYر��P��ǀxn;^�C�wA�w;�����Ǻ�?}���bJ�1‣e8\ֺuo� #�|�e�8a뉶��˥�Pٸr��;�E���)�^��iƑ�3��Eľ8�s��zM)�6~���ER��-RS;����h��8�rv�齆0����^��L�}3���b����~�H)T쥌jJ�Q@�}�k�l�Ɓ��u)�GJ\�UT����_���2�LoR�x)�g�H%�Q7��D;�f������=�?�h���h��g55V����l����v�^���6&�\b6�$�!�I+%���M�n��L�D�M�Â��]�G����ܮ�7$�t�`b��fhS�	Yt��N�������E>h�����dF�tw���Z�+�st���yJNn���b2��E3�n�$2�n��D-UPj���R�m����2���]�/�׼�m3+��M/so��C���&d�/4�$�0�ˑt�0�-'�)1��)�R��$�A/��F]��;D�d�v�ډ�7(qEW������TrUWm�E	������l�_~��NɃ!9�О��*5/}:34�t�R�D�+���������As�������=!u�Vۘ0�4O#��j��AW�H�R����י�i2؋�#3��������h�t`���^��wq�����$(�s��RW{يN���t��hḿ~�����osx�L���o�jVX�l�M@3�k�NTB��q�&�f��:�t2Wt}1����lI�C꘹��H��㙫9�8��[���N|�`f���3��KM�f� ���M�y`0�J��?�	��$\��3��
��`�b��o9M�GW���]��2��%�+�Ѻl?��ud�+�qv(%��E��!�[�x�,ƾ}������Շ�+���r�X��q���KΞ�ǂ�D� ���˓voN�a�*�pt�5d\����	����se2��D&��U�Z�*�z��� ���i�Ia�J{���U�5J6�*�B��CO�~"�2|Rt��+V�u�uʲ��� �R�A�ڱ*H��u��/W�]�S�Z*{��s�#\%����Uܾ��U\E.���r����3�[4�{�G�.eU�6꓉BV8h�+��)G5a,�\��B�E��QU�v����]}�1q�q�A�X��\)|3�yQ*t1�ߍ�*Z���v��J{��[fA��60�k�3���`V��J�]EKu���yd�>���n��G�����j�J�Y8�rKq�m��^��{�6�g�����������N$��b|�B���g왼�	�S�X�5F��3���Q��Ʈ_Q�G�QcЈ]�:%.MWp�]ײ��ߚ� ��1�׮{�`�a�S�=y���Cؓ^�8r�W�=ia��|t�Gמ�p�E�C	�u���kӕ��UK�/�l�q�����ҟQN]5�Z����RN��^���Nq�dt��\u��h{��O�r��Ҳ�k�$wϱB.�rJt�d��ơ�8�C 8NK��1O�����+��A,<�"�͍������2�5~������#�ꛭ���Pi��6��,�Q��Ǳ��#����5c-��n�:,x��`������)x|iz5'�7�|)0�n#�f}/�-�����Z'�u]�T�(����uOw\�t���E�t��-J�zϨ�F���-ʢЯcm���¯�:�(�-��l�R�c���7�,Q�[����!�����2ǳ-Ix����9:A���*�d@������#Z%(����u��ȞŸ[�wk�+1	HP�'E����l�7:$�[����S4�t���OF�:I�d�1�$�L= �]���К�^Pv�0RiV��4�"�슻�8����
6���rx�(]{�܆j�=�4J!���sƢҸ:L�¨Qi�_=�.�otq�L�
�봺������c��)�}U�i�P1��U)�A8����;I'�
�h��/!�r���=�\��N�Vv��h��_�;-G%Q<��e~��B�(�	O��M�����ȶy�	k��_�Ku�R��d�S�������y��\q����ڠn5!'`݂m#��s��&�*v��k<���fx6V��F+TE=���\͟�a�CM�{غd#�����~Ķhv������.Z���D���*�+��c5�c�hdu���㛘�[���:���0��O�u5�{�c�I:zG| ԕ]�=NTmɆ`�l-ݖ(�p�"tc�-�O<���$`���>����l���=�uʶD��V^��U#Z<�E�sCo[�F|�-�9"��r�J(\�x�?�P�SL}� TD?��t����0�FI���"4�P
���k�l��뜞լ�h��t��1�{�O�j䶪��i�N��~~{�G�Ƒ�O�����=�P���&��Y��=��g���)gwe�cx��w�Q~�7d?��	��8���qL{Lh��O)1�$j�cT]ߑ/f�c���#[�T��G�]�ѫ#S�Yk��\A��^X�^���fA��Qٍ�z�j
M�j�3Gg)�uE��~j��_GAs�J��YS�d2/#������3��VZ��RtVS?5�7��u�K�|�#��۵��A���/]vb�����>c��df�>#��#{UgÈ\TC3��"��RVG��	�c��RN�@Q�E7)��OQ�Ȥ�Qb�5O/^�1w��c^������{,g���uJ ��O�_+XdX��_�1�jB���_�Y��B��렢5h<7m��o;�Ӧ#c�\J�x�&�r	�u�tt<��o\G���kRrfb�Ln˕�T����?|�'�;|�C,%u/�*�e�	��t&/���&\vW��_��N��ʷi><K��	���*��.d�0���5;Zy�\7�ʴz�d�h���S�Q��[�Io�Ϋ	�ՂqQ�XTI���*j�PP)ԙ�����=���}'�:���:�X�W֥F���)���=�u�
(��-�(7<��f~_i*)�M��uQK;Ӳt��
9�"��e�a�-�mʅ�o�����,�j��KI�f�����gA�x�&ʸh�^��-Ji�3��T�6~�q����4���]7� �`���<��sk��N�u��#pe\C3�5&W�V���E�K�����+���#
V �č;����+��^JS���[�M�W<���JK�|�WHsq��k"C`|%{�uF�)�?7����Q�v6;�G��z%��s�cS.㸑�����0;w�����Q�	�4��dT:�"�[I��-�Б�0�{OߑA��Ic�.u�����!זZO��7l�C���8Æ�����1�#�ܤ�,�%����A�|��@/��g0�+
z��0�D\Q�$2���<��[���?��<^�;�^��\�<{�����*s`�.�j�zO@3RtW{_1���Ǥy/e767��
~�3.U6Z�zeoR�wt�wZ��`�WXo����_z���l�9y�%�S�9l
��u#���5�R����~0�'�</�.$F"�ґV���yh/�9|煱#r}c�a\����1�������焇a�z����I��ד,�J�7��؍��+�����]���%�K����J�Եm���-H��W9}�Ɇ��9�SRݺ�r��Os��/��9^@vO�B���� V   �4�1��{y���IZ�Hx������~���"dqX��u��YL����!?Ӭ�Nؼї�a<��׬�^Nm{�[�)��/Y���L9��      x   6  x�}�[o� ���S�75�E�={B�,�e�'ӵlk��y����.I�9���&4U�06��e���e��#ۺEV�~(7+W��[^�U�<"(�.ߖ�}��,�k���pNc�޻]�0�TGg�� AGK+�/R6���r^Og�u�������kCS��>})��Ot��Qr���/�b�Pα����%X	�u]6�)��Oi�f"h���'"F0��`��-4�����i�	�<��&���5LL`�0y��د�Q4��wM�cN)H���<c�c4h�z��u�Έ�X��&񇿏��G���      n   �  x��Z�NA=�_17�d��fSN���%�\����y��>mCB(�t��郹 ��Q��um������u4�\O����Z.�z����������%:*FQ��-��}].��˪ ���g��(*�b~���Ų.�Q4���qQ<���Qt�.f�����8������j��H�Q4������/��J(s"ԉ��'#=�&7�W˪~\��x�R0��i(�(��<K�gE=+���f�@q��?)�r��X�?-��7{���L7�ז����ɼ@{�l��p�?
j�q�貨7����F�?X�D��� k�!�v��Q�g)�Ϡ����s�ˡh�PHV�9p�X���/�=��؋�ǵC�MАa\����t:�q1>��Φ�dz�k<��m0>�"b�Dr�qgmJX�C�JBϯ�R�*++�M�T�9�RZ`�nUi��h���r'hS��Bs� �����Ac�`!�Cp��X2ȹ�8�ΝŊ��f�X�5~�5F���]*��S���ٔ��I�06i���J���(V�b�3��T��������q���Ʊճc��0����}ck����1�!�A��Q��a?.D��O.��*��ACC��$�I?)"��$%d����..;�x��v��W��C¬���h��@O��#;6J�W��ЃlS(GB���BȎ����I)��q�7h���շDz*P�N�6��-6r�.Uǆ����6$1�,��F������Ҿ�ւ�)���E�^��;��8IL�u��,oֶ81�#t�����a���)}����6"��;�"b�>A�;#��3\�7�'q����ؾR��$
�cyG	Z.�(��Y+��c �MNޡm	_��_i����O�4冢��=
��t��� �X�rfTF+}��G����� �M QL�\5�#Q�^d$���&O��A���L�]�gyn� ��a%����E�����[d����Y,��b%��1E�G|D�G�P�8f0�<_�8�k����5a3rQf.$5띋۫*oCX���[�Ad�s0f+42�#����H˞a"��z,�S���;\J���ޅ+2Q��3�;}k�4��誄om��'�$�8����[Ed��f���\����6WK�L����,1↯��]IJ�̓�cJ�uM�5G����]�:�\qiL����j4|      \      x��}�r�H�����@��܍�fQ� �\�$$��ߐ�e�f���)�����~�����}�S�E���"%9�'bԒ,"QUY�_�w�l<���0����|v�����y��X,�����}��}~��?/�_�Շ�vyW|�����r�!x*V�|n���?��/os������G���9����^�g�c�?�ogw�|J{W��/��_Y$䇀3�!\�z��d������476��X.��O��$�_M�-��jp9^6d������'���)|t�~�:�A�!H{�!������H;Ժ��t|���`2�3�]6�jg�K?�﹤�
C���^�^M�	<���}�F�W���!i%f�"��o�Mؐ���������l�8�ۥ�`��}��1I!6��F��h���p���h}j�ܷ���+Ḵ�È��H��4�N�7�*�\�H~�u���M'A��FIY	�43���h�&�t��On�����N��6��a�yV'���-��G�ùyo-�s˚�J�H�a�4�H�i�9$=WB�7��j�4��h]�_����Խ���;@���v�;���8\lϘZ���ȿD�޲Ę"��`C��j�Қ��"��U��5�W޸H����t�'�u.�	E�Y���!���*�($�zl�,�EO�j���D��l0g���N���{<N*-���OGӦ�Aj����Q�)W8$�?�r�ǂ� 0���mM��0����������9@K8(��۬˴�%���j���H?��k�Z6�'E�6,�b�ǒV,'~8i���b��tO!m��@&J�^�:�z��s�����47���m�>��륟2F���\��A���z[L�R	 KPi]7�ξnf��1$����נY�/�ߝDBP*r��t��P�!����ՠ}��{��xQl֥�a�}3�m �VV�����)�P1X =+p�>�7i?��{��)89��M�_IŅ���fϠ^#nwH� �E#qx䢙��e~U����"�� E:_E�o�y�P��E�U�M?�༗���	S*9	pL�d���cI�����Ixȯ�qi���_Ӿ��O���$�gQ�>�v�}����[��rs�_�z[�u�5%��C�2���2��G'^�a����� ǭ��m����M��J
�C�0u�M�$���}�A�(���%^��9�q�O�
CZH��n�.avӻD]#0	9���ПC�y��9����C��'���.�Z��Tc�>��Q�$:eR�^���i��D��Х�M	� ̳� 5gx5��.����p�ӯ���Fq�0�`����
�t0�\��݋����h���̂�p��d ʦ����I��@���+���MF٠�#u�}\2}l�7��߮������[��Fu&U���vY��p0h���� G.�x	���C�I{����PY��2�ixy?t*�X��_�دC2�^)�M\��ݸ��E0餗��(�m�0~[9�L��ꏭ,5o�E�)�M1�/�����s��w��M���z7'�p������ox���o��Q���4��:�-R��-�+wEП=?s���A%|-� ު��o2wFh������(B� ���A�7l]��G���.��u��<�_7��2`�P����U��at"ELi^��=�Zq�+�y�ѷ���r���U<\�V/j����o&W �Yۨ�PZ|�v��&cA(+�yw�t{�F�����Ca M>&ż�\�?8KCɒ���Y�R�\�;����l����9a$xe�چ׭�E�~����(���U׋�
�8J�S�	L �lÀ�
nf^=T���uaH��nt$U��aK��v��VRn �r�?�W�"�qq�G1)� ����J�ѝ\��
k�pQ{��m��lܺ�L�6�ɸ7zk�$]��� ��($Utw����HJ�j���$�a�.�2��� ��辝,%�#t���`*&���q��e�K��UK���.�x�/���0�Qt�M��Ӛ�x�K�'1ΛO��fh_�Rc�؝�ҟfOFv;��?}{Ψ���G�y�4�A1!�{�z@]-��ܢ�q��U����D�Td/-��o��I�y$ s����w���LT���+N�I���@�|�8n��bQ<5 ���O�E���~I�Xr��7A��b�c�lJ��@��j4�,2�Y2�����5���l{��[��N{#N^�U�ӂ��0^�	n�dx5I7.� Hx4s4h�G<�G3������kecB(y�V_1���s�&�� #�p�n���� oe�D�2�%ܻj_wQ�.'���m��P_	Hyo��Ƥ��zm��.�ͱ�Mt��g�ər���A����]b#��$ ���hD�1�7=�-�v����é�� �0~�Ƈ�#��! ���S��]�P=��
��@3Ik��l�R��Ub0I����P!>�B���`��h+��>!NM�r2]J�2�s�Q�m�
|�aK��N���Oy�I��b`G�I{1�f[�HxcZ��9�I;�,:�4����x��(�NJ�j�֔��R\�Pv�.P�����er�!n�Y�f��:-Gj�2�L8�{��?g*�b����f�@�ߴ��줅��P-��Ez��Ƹ�Qw��A�sg�N�iَ�����iA\Tj���华:6�̌�P�MGobC���1鐞P�-�T�1q*0��7�f�#�����AD���	p:Ǭ�O���m�C;Á﮳���M���#�?'�g!o	�oR�������T�aw�8B�	F��%P���=��r7���� (�&e��45�p)�a;�-@7ߝ��y��f����JDɮ�!����_����gyp�*f�E�i���Z17��a�@	=(<�T{��t�_�A�l�I�����N?GF)�����U3;c��N��
7��z���w ���@ �3d�ET$$�q���������x:I	�z+?�h�����?ٌ����6>LH_�`<:z_B�İ]�~�t����w̕�)W���B)2 z��nz�� (-߱ܢ.b@�m��b?�6���^��w�iM� ��11��y�G��|^��x/�L0PO �އ�\��:�B�ʺ��3�C���F�4���k]�������y����׀9>a8�Sw���� �ZWM�]Jg�3������A�z@ �'x�G�Q�d�u Ctͭyr�>C'��q"�� �tÚ*�j�ҽ@�!YsB��Au��f��X�9)��HA�C�Sڿ��M�x�1��I�s�Z.��E���(^�������W��Qs�1�Z�hB��3��҆���/����g�g�7��	�vakFו|w�Cv�S�*1�!�5m�c��
^㒚cy�7�����r1�����������(��Y�"��!�����${����#ID ��2O�o�[c�WKeHF�'�¯D�36���$~ 	��Rr������tb�8u*�z���)�b��$W*�;Q(�$��P�������q��nU#Ȯ>"K*?wH�����3��Ph  ��꤃}lh�REX�Q�������uŢͿ4�����C�t��5�}t��3��"@k�6��0�fVa���ʅt�n�qsLɻ��٫�xx��'/�����ά�|�=�͞��{���0���4_
7��]N��J��/z�����YF�KAj֌���11+ب�z�gȅ��;�L��2��%�}�ӷ;V�FJ��Զ���Ah�)�۴ ��f1
�A�L��C0TRUa�	R+�;�>�:��M$�h���І��K3Sr&B�i�R�����~ ��* 1�ݜ�$��OI�w�����Oa�{$Ч�>�BAr(�d�7�����`��kM��hL/�g揳���� :�wscP��1�b��œH�!�N&O��֭K��u�4�)A<��A՘�� �U�msN����W�U����~>7�k�a��*7�Kx����t��'���L�<Q2�%���a1+����/����P؊"ɶ�"�v�V(����[c ����    �}(F[�ؾ��r�p�U
T��¨��4eL��-�l�����s!���.�^��<�e-��𑌩0VaX�/�:7Z�3����?,���N�

�C\L@��7��i�� aB��+NxL���O�; ��B�/c�2l������ �l�Pn V��V�Ԣ-�JF?��|��+
���P$��*�J�����s�a����(��x)��<��e��83Yڗ����*a�H�p�*���_��ȴ�M�x�������b6U�n�%g<~e}�!ӛ����4�:.ץ��u�Z�ת&��_��Ys�W(I���^4��A댷�P�}���)Gݒ�&٠����!C.D�kK�O�a�BT� �O�s����t}22�&�$,:��~����08�������r�<�q�Nk��i�8��X�䷅�x 0]���;t��)�dr��2	�m����`N	p�r���h�&%�ɇ`��̥��&����{C��_�%�tد��`�v���3>໚��7\^v.��X�E��D.�ܕk��ځYD���c��m�����^�^�V�ֻU-*%.:{�����<����p��m��չR�ñ|C�ڇ�[�]�&��o>�f¸�b\�D����њ~�;�IK��t��o@��.G�Y+�C�ttD)��")��?����4z�N�� �c]�0Eo6��Z>�t�|~��*����^G#�(���;������G����p�!$2D6�lH�"����F=����td��)�T�#k�8JD���{ɐ�!�#c[��\���ű��Ic�߱iM�i�E@��@�vS/����e ت��������O#�:�0&ʠ%XK8b{շ.�A��� hG��TВ����JP��QnFx����0�íO�&EQ����/�e�{�F��Q�1����Mr&�G�@���.8J�*��[��?��Kq��^A+�-�ϨD���B�3vVj��j�i�1DgQM���j6V��_K6����@ڌH��b��H�.Rj�Jb��=b��mhTw�Sw:��cj� �eL��5��i�f���H�CY���*ڶu5`g�Q��{K�ȓ�
\�͢Q���xJs4���S6�_����?`��x*V��o]��;i���{%/?)�2�n�����V��&Ŷ�����E���B��@����Kw��Y��]�rwY��_�<=��$_��+p$<Y�22K�&�#�f����k�f����_���ᐇ_��yY����`�
���J��np	Uw��a�I_6!��P{"�:��Mm���y���~�W��'#`z�KO���wJ��ur)-������m�՚"!�$�E��k(v�R¿�m9_�i���h��ʤS!v&p^ �L���\!��#͉���M�B�1w���)-�	��	+�
C�>���zi����Ϲ<��]+�������(�O(��%*�MN�7(6�2~m;2w�3Hw� �A���haM�3��>�&�W��4)\�m��=�6`�?'��t�/D�b�@"����.j�Q@6V�x>�=�g����=��Z�@f����^�\�2RHUS�ѭ������I������-���C��}ʣ�-���tRl�q��AK*3Cc9�������dF�D)� Ibb�H�uzyo�e�݉s�AcGyDGM���a�Ϯ�黶@	)��~�ȃ'R�Xl"��$�g�^��d@�dLte�a"��h)I�7Z!�7�L�^:DP;�mw�vs��H',(��ݿ*:�g�n��4)�6�s}��܏-F���<�ڀ�Yic�����itTb�&l�ȍ,|2�O�e^<b�^�� n{L�Sɵߛm�o<�Q��m��{������J���PF-��*8_��ݸ�kr �$w�!s����pq�HL�F��@��E�y��!�<^���w��|V*�~��u��[���"��f��P�˼[Z3֖���R��9��(
�K��F����&�����ϰ婊����F!xF{�t�x�~��5Hw��}���zE8�dۯ�Lа귋�b��*U��wI� VQ�l��6�����GN� �) 7�6��O?fe���Jnک�D0D��N��QLn&Ӭ`�w���iN�9�u��&�7����׳�D�a�,$Sp�g�$�OZ�n�fm6َK�L�֥8�x[���d��a����a<5�Ja�x��)��՜أ�����	�����N֫LyXh�����#�s���Ӭ���E0].\�q�0��J��|�����;����k
>����Q򾄨ۦq�����vV�^H�k�O��3�X��i��7aaد�����mʪ;P�L>�܏�K�� ���M.�J&B���
\R���!�b��@��~c�v`�0㱈��u������]w'��`���ƅQ�����jVXҪ��٪ʺ�"N㮆�HCG������v@h�N�Q�= ��#�An�f��i�ϕ�!q��~u�x�㬘�<_���ŭ�,0>��O�b(��=��3���h�k��eCZ�<D�phM��zٰ�}wd;�b��wn�>��\�c��+�9�>���Ä�f��O��}���B��R� O���f�%��2];������E��S�a�]04�dn�1-K��"l��?���{�%J��Ɗ37�+1ӇIc%BJO˗���u�?�0 >*a+��8v���8КP�/�SD�&#���ue����S��f
�(�έ��fc'���]�"g��ST{�,���8<������f6ݠ>�SK�#ԱMN�2��ݪ�\�3�S�����EN0�3�Β�|��܅�`x�/�r{�%A�N���`MLg8|��f+yD���-쌙�0j����,6M\����#e�빕"� I�w���ۆ�
���T��Τ�����L���QD��e�v��ۺ�P�.��'�~i)��'k�XD�p�,�FQ) E%���pF��Ȅ?M���(��#�n�{`X$\D������;w�:���)`r�;0�C�o�Oq՚�4r�E+v��=���ǂX�AZ:1������5ݱ��o�1����`��C�Ӝ�ib����n����_:�.�J� 6�wl\WBC�vHȱ�J�ʰ�Fl?~�d�O@4�ݺ�P�l��ƨɢ0
�?�Tw�����3N�B)/GWs�+R��I+�8�P��Oڛd�~Eo��8I�B7U����I��i����V��6���!�Ƽ�^o8N����@���UC��:��cn�*"v%QV������FD~c��Bͺ<�!jiO����e2��TƑ7Un���u�$��^���R�hms�� $O�^2l�Y�H<��	��p8�n�	:��ef{$?��8(��+>���JbKu��G����a�?-���#���֗�BD�b��	/_�3s�����	� �m�je��Cœ��Ķ��d�^d��TK�PvJlD�qB������>T���{��-Q��7K0F=/��s��Z}�qF���݋'is93����Ts�=IJ���>�����k����Z�ٶh�l�́%P���������i���4j��J'��ޞR���q���+�������Nx��7>���ؿ
,��>�d��&05�S�q��)���:����J��![��a�3�#V(���i1�r��nb�q@�:[�+x_>B�G\NXb`�!�4��Z��;]Pܙ`O{`��h�B��5:�,�yI�(b綂�9)��/��n�j�$�A�F�mn�:r���W����v�Q%i�����c�H��O8�I�S淭j���
Hv��
i�OJ���y��Q�&�q�$L�3�����6��	��!_IsoQ'���<��QA �j�`�����a��gh��@wJ
f����B�z�l􂆑oǥ�;"��kA �����{����x1�� k�;����Q9����Ή�( F[���$9�n�M�1Z�N뵚���H�v��I�N�i�D�u~��4J�]�M�e��F(��1���8�'Ls@b��y�}/>�B��#�v�/���s�    �ng�J�����KC�ECV��y�r���n�ˬ�>��/�P���oٲ����y��Z��^����Jq#�ecH���V��'qRk�l��ϣ_;�I+;	���-al���*�@��`@�����ɼ,�����J�Q��1��	�8= K)M�W�w�3�4C�s�5Wv��-�&���+��?G����g�?zF� ���K���8���N��<�!��\!`�c��z�D��Yʶ"��1ax�!͕B�87v�N{c"p�q(�G�	�QG�
�j��{��R���;�)SL�L�D��\я�K��܎����<���6��l�5gDVp-?Sp����kᙀE�(Px݁v���NJQ�߽9�71��ua��=~ꞃ�W��{Ω{��u��NI���5pFsl�e'�n��R��;�4��k53����)��F���`l!��Q�.���W+!�d!�&��1$#Yk�Ւ�ʴ��°�Vm��f+���ҿ��^�nn�7�����Nr)�	9�<�=S�#��0����|���(�R$�l_N��i��ylN��6x�Y7��y�cj�d��mU�a���������a;#������=�j�aM���Vx��!�>,��$�6u;�;�W���T?U�8^>����A'���8{���D��.�����$�9��.�D��d�Dv�=�0�*$�	U N�Y��&�ǯ�լ�s'���ڳ��硈���B4�ڤKO*���m7�]{%�����E�@ȒL��-`|�p;7���jo���#O�y���G;3Z�a&��>�]�t;Z�]p��jn(S%� ^P�廚�7�d�t������^�j�m��N��0B��]�oZ4���mھ�1��H�2�ǃ��v����$Ϋ!`z�Fg��P��`r����g�1C�8�|���޺��nY;��0�T���g��Wa;�<C�����i�~�=����F] L����=����sǷ�o���<�31匚7�0�K�]�B��T\RN�Ԅ����M����͟`��ߝ��(���q���i+��'�ҧ�r.��L�[��Ô�b�P֡8a���	���a�Y��J'fW�i��{�Ɋ �QΪ2 �C??i���cA� �ݛ�QQW<��{:��\������H�����p<�\zK�����*0B���٧3��,�rqu����)&v��IcG���C�R��ϣ�|��e���*�������J��%����_(z{�S��9z�*�T�8^�Y�5ʘ����=-�Y���)ͩ�2.��O�4��_�%��^�ԉ����+I���l�$�ۚ3y�I�3;%�fH���i�z��[{&��QC�ܩ��&��?��&J1���#D�N#�?�ʵ�$=h���z�Z#�[ �7ɐT��HM��z/���[!��`�v�x����i ��F2����ńċuR���#���^*�{@����ң�\c2�����*��M�6�T��;UHtC��0Љ��+��h��/N RK�B}�ai#b�ƺd�Ā��n5<Mѩ$셤B���{����&u5�VJ徚v�^�OҤ.�FdH�"��K�/b���ϊԴF0K�nG-t
�8�"E�vWVn�C-t���Ih���:�d���:Y���)���
��2���bp�)ȩ������
]�X��z���:JtA+g�+p�Sr�+Dɤ#�-.Eh�U�#:�^v��ֆ�
nd��<ۄi~^�Fy�U�c�n�.�8�W���;2� p 1G^��Fř����]0x/��x�+8��S�{����~:�%R�p��pO:�K|���2s"`� .1	��-K�D\A��c�{$T�	��L&��0̷sw���z�u�~	W@.Z�8�ϊ�z����/l�Qn-�#�fY�U�EP�E�(&\1�;l��Bz%M�j���<��	쨄�S��Z�޺e��4���球�@K1߸8�oQR�U���B2��M����Y��(�&(>&�AK���E��?P<� �`T= �y����!\��9?N)SCK\W�(�����<8������
R�9�/_ {C�u�J����]�H	��jݔ<xX]JL��R�mt����E�OG;��ؒMg�lkQ���]ƃ�
f�΋��&��$с���ˋ<m���zz��X�|�����]!����W����S��U�a��pBj#!#"_��s�.5�m^|:3;���k�q�D�!�D��:rp~���!�϶�i9�$��n���!��ғ�ཛ�<���P�^�������s�m�P�A��,\�l>�y�Y���6JU��P��	l&��P��`��g����ռ�=����c#`�ؙp���Y'[>`3��c|y����ۓ���/!���b]��j��Vb���s�KB֭`O����cМ�s�V���ڼ�)4yT���w��Ѵ��Sim@�[��V�S_��p��m�L����I��Ǆ� S4�D~V�A���\�����GN�Y9p��,_��Ǘ9 �D�eay��~���G�p�4�+���u?揳��"��pB+�\ŠIdd}5��X̕���z��+��_�V���x�mC�팎ٯy1�����1�*CKPׇ�O�R���>J���ow.(:+B�C�'L��n�3��,�����[�i�P"��!mƸ�����P%ռ2Lmę*�Ra�� U�cgE�%܄d0�?u��`w���B�f%�w�=�鞈����;�/�Y���R��Y��O�ǥm��D��"����7���8.���ֈ�0��C��\�:�O�V�����K6.��ޮ�Y����� �(j������WA��U���ʣi`ĮP�
�bG.[)7���Ѱu�>X�M�&!�
���}|$��lz����$�AH�;"�0�v�q� ?�FA�������bߢ6�Y	�q���݈�Y���h,h��|��Y��h\�����
]ԑ��&�D�E��lg��̿/*\�a8���wG��c��U��/�0��X��x)�j����&G�JHN,�E���&|̿�h���b��7�:U;~���C���(����S>�'3���b8ث�;%IJj<��;�~��EC���ce��u�(EKM,N1�K0~������*�x)̱��(��YQv{Mwg�vvW`�ѭ�kD�%hA�]��:�.��?�q�58��?��+F`�m��V�L��, �g��G�uP��ַ����-c2�a7;�w��b}0k��ɧy\��v�l�UYj&i�n�f����Ad�|�Z�2����=ٔ-��Ș��AK%��.T*y+ϥ*qD�tw�G��3p��� �/�|E�)y)��AD�1m��JA,[䆱�k�!�v���� \��Cz��Sn�Y.O�Ҝ��DY	�����G��8��e�+�%7���!���$)�E�5��wz���շϣ�xX>�OAgvo��V��-�f���Z?�����י�{���eU|G�X$ Yyl��rt�����x�f�/��e~Ęf�w�����Z�a�h؛��k����������[�`�X%9v�2�ca�� _�����`6�p�g*�ocIr3��co �xZ-���+!H+�%��*��`m��{�aqD���b�?G�@� �ݒ,'��a9�����<H�Y�N���X ���!	�(i��ދ(a_�L"��</�"d�f`�������$LDb��d��9��~�(�	�x�?��༘��G~W 7����hx�Щ�;B)�Y;���jH�c�������lw`��4O�g�S|*�����&<.���Vg�,5L���Y*<��!�0[Y��m�)}�����C�9$����v�5�NK�\J�ų��X�[�,�������h�F�Tfv�T �}�w�֠�}(�w�U\�f�ϸ�h}]c�SK���>����� ���`����?�y\�|-��cz<�p�㍬ �m �s�L��$L�ǱE����c��ru3�i���ȿo]J",�$�a�a�0\����>�Y.�gD�f��A��� �	  �7X�z*��y)6 �'~_�:`b����%_�+����}F�RZ�2�������a1����Y�q���\�4�bY����%3J-�c�"�u�OZ�6��g�S#W���mb½����}鈇�I}D�߰�yq|�]������<:���y5iu�j
��b�����N�CO#��e���ۯTi#����+�'����`�����݋=T r8����QSN��|�a�)�f徎N3�}���Z����s�B���q�[��m�=�W�l�x RMx������;�	�\	�/&�(�sr}ʬ�]L��zO�m,�D�<��u��<�"
�Xђv�6�H� i]s|I����q�N���6� o�2�L�"&G�xvdPb���Py�0��ڸ��@*���8���v~o���z���������P��OF�w�qo�L�6�8�߄O���4U�����m1��(=Q��PD d�w�
K�`&w:Y'��4M7!<�u.�?ǐ'�m%ZS��ϭ�5��-�Nc������˜:��U[��=G8�@�2 co�#�e�\�N��c?u�,%�;?X�����B͓׭��d��� 
/��?F�Ⱥw�T��Y�~]K�60!K)5�^�_��%1�)���uۘ�줶{�@z
�HO�!V�{I��&�v�1g���r;��4{����]�ڍ�d��x�0-�O�>&����)7<|Tj.�)�0�E>���/_o�巰��M���#w(�&�Q�Nrsj���As��+��b�v?���	�H��Q�PU���%x`�~��ΖAs����� B��
nA��!L-B��o?L7���L�Q��cLDJ�}���dE�����&�䳧bL���
�'���SL�wC�l�|��K~���L!1�o�-�V�v�S�L\����/���s�2?,�:+����8����}�?��b�\}[��2��ض�P~���s�s��@��V��@��zS:X�Eo��L�|��nݩ�d��Ԁ����rpa*�PC/���*YNb���b�C��u�|�6�*��$o�C�C�%3eۅb-�ŋ�ǫ`���1/ l_�"*bweCe�X�t�?�K��F�����5r��2�1� s-�:�s��E�i5+�̵~��P��p���{�"�P1&�,*t�Њ���el;�Ք��d�N��V�S�s�L��LBlH���O�HH\��w�C���ݿ�s�3<1|������]��QC��.���W�AZ.CS@ggl����t����w�����B���i��j!"�ء�&5�d�N�g����>���Jh����cN��8ww�����o[��tfI�@�i�����I{��,a^B���e����k+�:�TJwG,�+�����2�T��J̋g�-Iy���ݼ	�=Ǝ׭��B��*�6{�d�:3�#��6!� �������jQ|���ߋ�����������>��	PyR�r#,`y�3��C�Y�W8�My*����ꋂ�nk�C8�#�il��ug�I/�^t��J�묻��l?)3��6	��2�J:�����g��(ew�q �%���c��c��=?�8Ę���c~W�nKS��p��_��K�F(�M	�6�,Hl&'>=�u��S�$L(�}I8��N$c���7\ĸ.�A�舙�,"l*�5U/��O�`���7���S97�\v�>s�G$ROKj�ߊŭ��ɭ1Po��ɒ _���g�r�;� ��T�z�{a,��3�R�R�����`�:F�L׍�)�*h��|q�sQ��3�֖6�*.M�C�==�}��U:1� <C�W7�cO2��A+3B���6Wk�Rh �0���x��4��1K��.gXc41�a��	-q��&I0Qm�LR��e��! �Ƥ5F���������c-���m ҜM;5��\M�iwpH�fD\k�'{�'��t��E����	���=p(��T-d�^��W��͖A���L�kt.G���+�(�f��<�ˇb��}�*$�k������Di�*�8��[n�ů���b��v���
f�y#�.G(=JB�Qf�D�L�bF��i:Ԥ�?	z�8�Xn�Qc�l�j ���N�������<��12�6w�Q썌ЅQ�Lk�v�Q�4������>������t��e�P
8{ف�Z�2��Mq�S�.���	X�>�g�(�`(�y�=-'כ�tm��ńNg;��CoU����vjr�<`y�Plk�$�>q�����x�M#����
:�����&��X)%M���� d��� d�ns�M+3>ёc�͋��x���]z ��ND*�x���{k��"Ob]jw&��8��x��fP��^BрY/��6��arw�� �l\W��`y��buk9�=�ی�?��9�Oy����;/��C��Y.�e�Aս~]�O�Ɇ]����!��6o�VY���D���fE�"c�V ~�J!?J.��q%C{�fi|��r�: �z���?VA      Z      x��}Ys9����_�q'b�auH ��7��$J܊�,�/i)�b�"�)�\�_3��7f���9ȍ	$������q�R� g��w���`���������q�z��:�>|��c�?�/�����ksx���X����#|^�����V�=G���9��?�������V����:|yyc}�B�����7���^�����_��]�I�}����a�����(e�؃���a�Fw��_��_�_a���gg6�����tґ��.迱���w=�\u���|_t���g���r[~5�������n1�~����o��yc�⮣�������o����i����Yv1��=���aa�/l�2o,A�3�O������rt��U���pr��K<���q�;�홏y8Y,�w��di-�������H�.��[��+���b�z9���Ӊ����d:�.��(X,�ctf�������,>.�������&�Ƴ��յ.G~�nл�+�������nux�l�od�q�f�lEy	\n�g��+7@� ����M'�N&S�plV����Iq��\�;w��|$�Et�s�2���׶vˋ� 䂰:���}�܆-�� ge�t���w�m)	L�6D�mP�Ӗ�R$�ۨ!��a�0y��逺�G�^Ə|�B�JGP�>s
7w��r0��]@\�k)������*��0���mO�jʗo�J�6��mCP��iPZ_(��bNC�	%�l�>�8M��9��<W�H���fh����Ēf�r4�-��ԚL��%�������x\�>g�����z�=��}N���i[���#���6�X�Ċ�r�`�m=A_ʉ@ǔ6؀��	��1���9�x����p���sl����N���{�߭���v�?>���Ҳ����{W�A8(w��C�E�n:�F+��å2��`4Ο�T��sj�Żxҧ�{ Q(Z��7���l��M8�����-
]x���:p��q����`�	P���6v�Ɗ�6�s#������ m���֞�ꆶ���m�w�:����xy���PB����EuU܆CH�m0	PG�r��(|�T�hr"#Նvb�no �uy�e%F�n�j����`4f�`D�����m����s(*�	���F��Y��\Q�CQcWIf5<�$��S��ِM+���ĭ� W���N���Z���^��+U��A����H�w��\�����|�䅜ٿ0��;�����u���|�|:��J��y�T�Q����	/ ��`,�֭�F�J�+�ؔ0�a��ʷ '@��dm�<��<��"\��<�0��zY��h�w��7�~�P��ne����>�t�$��tj|� IV{*Y�5�荤69���ږyL����FIꃩ��9/��t��Ay�5t�35�> $` 5x��D���bv �ڊ��\��,��]H�KICo$�J�}(�������J�wc��G��s}��	duy�^�k��F��J|��݅EI�\!]��a�K�#�Z�A�^S�LK9��@H�Pay��\�A��;�>��(��}��b���M��%���)
�|0F�H�5�<<��J+w��$.2�z�Fa ��6�h[�=<~� GE�h['�����_;����qZf�0�p��V�2��6vbc�9)lŤ��~;���f�*�j�.���$t�:���v%]��*�Ƈ��p�2W��ɼF�s��|p����\�Q0������쌒��tľ��ct!��z������+S�m�q�S��0�dWw�e��{9���E/����R�3�'�_i���*62 �`_f�k����JQ!��
��+pQ|�F����Q�����=�����Ͼ8GІ*0U@�?�>\��+���0��N�W{v�!��uP�aF.�Va.�$���F�Fn��^���APB�H�4���^j���u-��`ԗ�Q���t��$��Z��Ϻ�Q�W(y�e���'���(��&ej�4����(2,�6	W��	G�p2�Z�n��w��u�s�m����׋ڷ �s�4@L%�*�
j��cl�2 ��K|�����_�aW�$&V�mc�&[�7�Z��׷��h:��������`n�N�G��|��s��8�}����j�)ۤ���KΉ��Mޢ��|��Xs=�O�X�E-p=���w="c �9�|����\�� 12 ��3��&�/FwRsA��VV')��+B�
V���CP?CӚ�|gnYV�4 '1�<g�%����`�ŏ)����ϊS�j��$�!T��?Wz��x8��Ż=/�����k:@̀@�9=F����u��O�>t���&~�q�J?;����-	��� �ȝK_���<��vN��8!�iꊣmr@G�|���ד���1�ڣy-u�QS�
4�K[���(h��\�*�J?��n�P�
�V���|�x$m?>�.\ݫ�K!#�����B�o�ح����(�kj$/:����]��&1@�@��)���z�>iy �G�1�P�%����}w*?� x;x�/��jh���e6�e�����6N(�2�zP�;u�ao�� ��Ni��X�r�5��SUL�A�.�u/�j)[jٻ��/��_UT���eBo���~����
]�~��(U�6���j��n�����_́P`�->�ʡvw�H?�-O�Lc��SW� =���K�u��f:��<��M'����j'B<��K�o��.)'�.��5���z@H�iHm��0��wxW�e0���Dd\x���Q�����_J���Rx�n�d]):��-�_��u��D�������M��"��\ctz=)�߹f�Y�����������R����N��n#�80�8�Jᰦ����8s�OQ���F��h�@gu�J�w,���.�?Y��Mv��/ ��A��{��s��Vr~���)B�:�/R�7�no}��*�͇md��_�u�R�Q��a�.�����|2�(aA}�I���|VQe)~8�����|�v�=��
ӭ)�n���S��[���s��uo�,b����*G��Y��Cd�6���z�r��k|��9�3i�)a���}�SP��a�����-\�N���<I�B��ѽXʳ������q�t�͏��e����'��d��+�4�H�*v�LO�/Q$*�
�Y�W��r��jx>mw+��&�2�cm�N���4�=<f��(�����/�NG�F����+w�	d��J��4���J"xP��Nq'�}�w!�����k��r��?X����r}Ѱ�����N�,�1��{)�Ӵ�*�0���=p�<���<��n�fy�ڴ ��W�3j�@$��\%����9,qϨ�e?I����a�U�¤[;(?/��g���%Ӹ��
�1D��H�cU�Z�Bz��CK=�uexP�%��'�)B�S��
J޿��^�LZ0���@y���I���ZR��'y^m����K�ژ��jދ͜*E3��ؤ�����o�Tm,�C��C?2�'�S����W���C�z7"��!/�����!��9$g���u��/�X�.���+�t�P�	�8�&���*��U��%��%��ůwC����q��U�h݄�!��TF�_Ə,���<�rѸX����'�o$ur�[i�v�9���(~.�/n��8�!�Aﶀc=Q
��J����bV��s�=-����]��O����C�%8x�`���H�#H�lu~&��/�:�O�H&t��Ke�t��-f\��mϜ��ۉL��~��z��)-����FŨ�,0��̱:����*;���s�7D
q�w��qf������Un� s��/Pq�檀���>��gy��?��V��e���ҩ,wi|
�1�u��	^���U��e?o�Sſ$�H=���|0RI������җj�T��� ���L�Di���N`)O�-�WҔ�(ub�3'���.�碮�eC�K{�0�Ri���k�`���w��N�9����W^&91�<!���M��Q��2HV�P�b2ᨇ���8V��\3T>��C�b��S#ܶx%�hJ�G�Ԥhx���AL�<�zT    ��P,��/�>=���-�_ � ,�}�ͯ�nJ��C%��.Y���´r�R��~DGI�c�B�]�h;��n��$^����rJ�����-8>t���.�g/�i[��\���V�=�Fo�Y�\�`BrB˅�m]�״]4[�Q�c�f�Ҵc++�`�۶�;�b��iS"��k� �zΫ`Ɍ[h۸w��9���)#߶4�����s��ׂ�h۽&�p�J��hx� e 42�*�M]��y�G/�c��}���ش�=+U
�Zy�^c�s襅2�AD��PR4"��\�����A.��Mu@J�ǉxp4HU�&��S��*���FĊ�o�Z+�$�(��m�ki^U gb �Y��.�˚���Z��A*�$N�bjVa�
x;��9ur̯Q./YV^L��~ܫ否�{�q���nVO��'�f�!���c�%�	W]�Tu��MyY'���+/کN�}.6���ó�]=�%*�G��1�7S]L6���(f�pi�
�G�{ƸW�Nk�Z�H�R�0�����U�+#@u)׫���m��0h��l��k��v ���b�X�F��qKJ�	�{L��*1�bx5�BH�8���@u�5�/�V�Ҏ������Ҕ(�=6�W��~�29�,B��V��;�)Zd���9�kpD�WFxT�2���w|Ջ���l�	r�!�-!z�Q����Y�+�lL������֖��s��
){Se���fk9�D�f���RnS5��q`(�ѫ���Ŀ�6����tr9����u��w8C%���@�I�Ԩ�7e�O^�T��~��<��?[析O�Fo�~�����0��kZl�z�b=ƫ���w�2,�.���uז�Q��Xx�#c6z���Y�/DY)��pq+��ߘ�;,��� �Y?�9&
��5W��<c�nW�22�t��}Z�pi<�D1�f9R�Ҵ�՟3��rH����˓5����vIi��X'��pG�h�]�1O�jy6������:�j]�vE ���@��*��V�^�K���6�ƺ]=��v!@���w�p^+o2n��c���~m6��w���p_|��q!�fVD�b���ݪUA���Mt���9���+m+6Aw+���a1B��I_���۴�D��*܄����&�}�s����v���I4�i&�K�T)Rg��"�/���Vߥ=ŷ�,�����Z���&,�S�p�<��+T���Jӄ��Q���Y@-+�f�P��(��o��lY�H@2��14�Oo4���t��n/�@()K������ ���\8������8�D���[F�ϑ5�t�C���:��W�3v C��/������9ܳ�O���	L��i0�|W�u��r�Ӑ��A��gK5o�Si�#:�[n��e��)��E)�Z��ˎ��lSD����Z]�.B^M� <���<hf�9�����ܬ��f�ͱ�l�`:�ނ�S�r^a×u(oj�^�h���H�V���M���+�s�gcX�2܃e� �Aw����|��E�k� �jG/�^����"�ZOt�"������/������Wg��t����6n�lP�-sT[{hTוC���%؃�����O��t� �'��i��D�0��{ٴ�w�{�>��,�9��t�lJ�1?����Ŭ%��J/ ;d�g��h�lڃ�l�1���'��{'H�֎3��m�i{zo�yŃj��������nڝ�K/$ϻ��s3��ܲ�䃳x�b%e6�����a]�A�pÄ۬�:�\4�-������\�s}�U�7W��v�5��͘uXU�A����
��R?�v}b�����.Z�3�}+�E�z��(A��
�a�o���e|f�Ҹ˚�T��ر�T2wݻ�Z|>E�fei�����l�k4kuf�	���L,�H�A�[��̐Dmja�{�pNW�2�8�gΘ����
��G�(�Ե��3�2ʤ�aKy&�AT ����2�:w��Y��R4�`�*�R�ʍ�fo�C�uc�>�kX�p�U�	���:��bZߑwɴ��Q��q}��Ç���~a�SWڑ�(�$תP5g�Q�-$��:Pv�I�4cL0Z���/�ã5���V�ŋ2�7��?�GCjW�0�>r��N��J��'k�z����ũG�Y�4.M	��������r�	���]u�,	�oG˒H�n���)AA�{%���ج��]Yǳ`2-�������3���V��z9K����a6щ�޽������A�>�!�񓗄/e+�\3Hŋ*=���fX����`�dt1�\īw���������*�h�9AЄ�%3���=%&�v���W��qL]���*��$x��̉'���c�i1�P���o�?-bO�CCa��=��A�0>�� �Հ���<�h{�m{�0���_��
֛�_�t���.�.2=h�S+� ����o!�m-�pk�P>Ojr!τ�iZR�}p�����e� _�:z�2��A�#�A�05W%��QA1�,�g.�@�?a;�<ltw���$�{u�q�ُ�J���A�2�o���7/�����M<���yx�_�{�nV�[Hպ�n��_��E�JZ�7��܇���F~=C����4Kpź�}��tbk�ǉ}�e�1�����0-*�6�L���H�/�
}DZ���z����N��fo5aDv@*�qm+��PM�\g�U1+��!�j�V���V�� ����f�g;٠8�������|����gN��$onV7�M�<ׄ�)F��?�!��Z�!�zQs�k:���̧�]����6`�i����Xt5�(�F�� ��d�؃sj,��׹Y.bF��%�3��*o'���\!���9K�Զ��LJ������9��b�Asј[�d�KO���|+e���@ i�08�|����;���k�8��JE8m��YㆺduAc�T'U�Go�'n��$Mά��Ӥ�Ѳ�ݕ�wY\�:թR�<��n`��l��B�?�mմg)�f,�럭|i;%@[�X���w�,u�<�E�*��P	�f(j������ �o%��17<c%��q�7V�i����$�Α�0E΃s>Nކ�}�e����b�%8L�/h�P	����@�@1���n6۝u���@l��.�I�'��IF��v8���t�`�:v�:��]��sѡ���O��U�AT�C�п9��a���U����")���~� oGOK9����b��K�e:����$�)��
q��{Ne���-�P��*���F�>��^�T��/����N<�����m;�pªڀ!۬N �v�m���Id�+D.oP���.������x��iّw�nG2��S\C��2��ٴw���E�k��6�6����O��R�D��k\�T��b�N�򽷽�9f�=��PD}(2��'�8'���F���<�8o�N��yƫ�8�3P�>GE���kχĭ���Ǘ�d�ʐCŋ[(�XN`�;�4�{f�?^�B��8h�������yH�]jS8��=�%���SĎ�3� ��t{� ���'���a��J�f��$�ݭ�\K�&$ FTi(]F�V�p_�%#����l S��Q%#V�`�x�2���U���*���/�ݔ'5ׇOUF{:kÎ������i�FI6�6l7��|�a�Qi�i��s��G�Wf�8��{�<��vI���#6iA����U]j��t]��٦^�i �7}�4k�j���7M��(�f ��Zc5�G��=f�k�T���}B��@^��Hnmn̓�թ�A�{Kh[N�FZ���Z����*|������E_��2L��J!m���n�anS��t�"�!�@j��ZM�u�f���(��U�D�j����n�z[F�K� N�͟�������l�*�H�a�k�D�I��F ���9�"�:�Y�|�VqT���h�+Pf��|��Jp�Y���-��1�	2��ίz�~˦R�(�Z�qe�\
�n:+7S�Alʵ�摴���N��S+D)P��,9m�����w���z֚�C;�A-�=�    `m�3�0H?
Q�b���^[��*nDG:Rouӆ�{`+G���ǝ�Uv[��<e��c�Q��v����$�YE��~'\U�m�X��8NSO%��g6���Q�v����W��$�e�k\�\41z�'ԊBg��M��![��>[�(<싁A�E��$8�Ğ�;�k�GY�E�|wI�_B ��5�N��iw5͔#@��n7#�m��q�qeyp��.���Y>m�eDw���i��ڻ��Ӻ�j>Q��q�2w�w���oI��r%-���˶>��4�e�MR�8��D�u7���,��2��<�^"	���UT��]|<�����/f��]w�=˖vm����t�i,2抉����/4��v�?5�(m�cq���W���o�q0�]�(�$Ǧ�C��_��ˮ�פ�Ϗ�������&���/_���+�*�<g�xlY�9l��V\;#���N��,6��epue-����<g��a�o��V*)���INш �@aY)�A/�-9�m���z��b�V�����6C�Ϭ?Nx'PABD���2��j*����E<W��h��/��}Qzұ��TfT[A<Zu�/���5��ҵ�J�x�!muG��-
�(��Z��`<��z1�����uۮRWI�C��)�B��e<��*����l9�Q�ߥ�x	P�ߴTʃq��YL��?nա��Z܁1�J;Ԧ����e���"ZG��vc�=ij"CЗ� %�"���Z�z���,Q`�����9�ʑ��` �"���˷�
x4�MؔL��8  u27�i����.��>��З�Tq�Ee܁�5���7ځ�VU�3�@@�25Q'�w�J:� ��)y�'>��F\?�	4�ȭ�c� .p`�}� 㱟"=*9iOZ1����.N���z������O[�������p~,6��ԓ�ةo8"n��U�UL�`�ʸޘvz$���8��J����+}זi�����R����bE�smw�\�=�Q�����A�.�o䡾H8Zi͗Б/�G(�x=�ǂt�ѣ�������>N�Ģ��S�S��_\Jمɻ*�VZY���g�i>�=�J���(6#��J��a���H �)�6ݧ��"Z?��8ڼ�t�'٥��H�]mC���ϻz��ի�����DYQG��Z;�e�/���b�ՒD���;A��"Z�����-�O�Fz��O��Qy �;ړMT9AhI�*`���c"����Q�c1��u�����u�:����$(����ej�S�nF�sto <���ɪ���4ё����V~/Dk��;�'����eB��?��3����h4��hp?\X�n�1�-��6�U�3a��Y� Q��S�[��$����W�����������Xlw]�\�q4����D���مMʺ��Q�i���7���#i�H1��C(UR ̭hh�],�W�(ޓbW��9��Z�T�c��黺����RL��C��4�V%ց�3��H��wG�0�8�R
$V{k�I��H�R��H�R��)�q�5�#�g�j9����]���<��Dnգ��I����	dPv蹱��a�T�ϑd	�^��!��5��r���@�C�'r`��èHem]�BsjÉ�V�޹�o�eM�����\$؀�А��L��y�;�,W����B�v�\g�I�V�r��(e-�^��� �
 Xc`�B��m�<:|�������ϡ>�E��f��
�ǵ ����j�����>��"������ݍK���1S�u����te���[�}Xl�z;�����^x� ���m�"]��h���c�),�2�H	3��G�-�a�k�bg��M����Ǉ����>�M�C3<[����Fϕ�`8i�J[��l� �ss K^�n�f�d�R�����$�Px-6A��c`zn^jf)�E��¿6نO�T���Dt��³c�������Hr:�!z���w�-\&���އ��1��O��\�~��{v�f��v~� Ȁ��V�X���<�)s5�(av
��r�(�{L�I��J�.���]f����p\hPE�֦�Bc��!q�'O����*���������똋D��E_/�T'ن�X�&ޗ~?��f"&A��ϋ��`��ў_���1�Q� ���fڄ�Z�EG�]�)6�|{G��� D�u��Ӟ' Մ�Z�������Q���]���A�q�K���!+w����ݡEt�|���6�$4���:��/�L��H�7�q�
�ͥ��q���8ѥF�b�w_L(T,�
��PbC�51��pZ��6�.�]��S=bԟ�5�eÕ�%�E���h������OZ�v��wކ�0�j��͈g��D�],<h�kj�?�_2���v#�ƺ�J��lu�u��}%�^"=��c9d�%`�i�^ �(KTI�`2V�X~uAݜ���Y$�'6p��	�v둕�zw��E�	޹+�����R���pB�S���1�y�-w4����`� ��d"@gq�?h~op���L�T~w�`��ݶu�����k�s}��mݡ����"����w^�-�[7l�yeО���w6kLAFP}W��̬ͥ#K�KJ��RA��e���TmRS�����!���| M������%�xoZ�R��Ku�$ID�]%:f,�gC<���_`L��1u�bE�bL�O�����Q�8'R���2eJm�p��<|�<��c;v3��r���Q�x�<J$4N����n����W91%�i4^"_%�55�q<��,�5YҎg�|; �Y��z�����
��/��;��O�%�1��N�)Έ�xG�
;v6|�~ڋ5�t)�!��@�̷_,����)�3���_�H�~�2�ʾ�G��O���3C���ng������x��=�D��e���&��%]wn����4y�qv�p�`�,����z�^B�� ��A��Lx���C(���"��4��r��J�Q�s(�i��oR׃ov�����P���r�6��zM��ҹ[`�qܥօ\5�췤���&�ș���F�
�E�%]�H�R}�r�T�VJ&���y����N�������s��<�!�R�(`�L��l�&u�M��aȎ~��əO�5�ߢ�%W���^��n�h�HfH���a��)�Nw�l��ɦG�>�o2�0�p�sqބ$N�-֖�"�*)��B�'E���F�A#̎}��� ��j�����H9��8��0ȭ��v���H��5�*%�?��V��&��;]1�M�#�U�qZ-d����qg�A9���S��i<m����_P�dMUS�z��aU�ft�F�e-�C�[����l��y^S~�9�R\�֨�i�b7�
��@���n�L��x2�&-I��Y.�oX�t=ߍ���^�O��a�����[�lSlz���ԏ}f�I�S_�ާ��Tu��z:�;ǻ�~ �m�%��K���K���GG�6��`����y(��b�e@�|�q(d�������kr.i�Fڝ���B�؃;��M�z �&]�&��s�F���[��w>�S~�8ՃQanL}�1�i����'�ώ��{��!D��i�|�8��/���r�Q�P����-�1I�z��d�}�f�8�����Q�`{��&�x��-��w�e�*����u��`��GD�L���+z�3a)�n�
����C��`��jY�K�'�1E�O��(«9�7�@��˰��\�>�ኹ�6s��E:����0Ω�)ggƺ�#�Y�_���Ѻ>�������Q�U���ad�h�!�9_l;����ಱ(Ȩ�=CP�`���N�s�+��9�y�����Aa��>�>���ۧp�ɥb1#��mK����hC�k5����Z�S�� ��C��`r���4��r���$cZ��h��}�j�"m�s�S]���<(�k����-�t{xy���N4b'��������1՞����m�m����:����3�����rk����:	d����\���Lju^
�y���lĠ��>N��iE�nR��R�Q-mF���-R&�
�9F	t|nS�PJ��q^iT���d��ʤ��x�� �  4�LAW|�pb�ix�S[��U!�bc��#�j�>���߀���p��ꪻ�Nf�l�J)��y{g	=�O�=x�=�IbG���;�_��\������VD�"���[��F�H8K�����	��y�(��݆��he-��oO���Cz�4�����}�34n�����bȯA	�\���hf(�Wӫ�u���k�w�8����d�%J_O�/�S���E�A>4"2�����R�
�&��B�Lgv�b*W�=�n
E�c�L]\�ג	��ӡa��⍵�D!Mє@֜��;Z$�"1V�����tlf�Nަ5���vZf����1O>��}@S�d�r�u?4��O'���Xb��,����z*��f���b�q�GO�����ΪƱp �E���Y���Z�͠1�3F;?�ۇƊ�PH�j��0���K������8�f��9·�����z�4���T(D�Q��}A��e<װ4�P+P�#�옝��� �'�T����n�O��G[��P��{��qt� �n:�--C�&qU '�Z���k�B�41��O����ܙ&�Jq��aę ^G�SG�,�g%�,W_�Hp�us2��M#Vz­@r����������<�l$�ƫ�>Z���G-�B���Kn�Spw��LQU>��N�̤�����8ad��+g����4&"g�X�M+�s�/�wh[�Yow���
>V;�A��$�滋��T�!���K��t���x��K��&M�2җF�z%�eJ����&��������C�K� ޔ5����I�1��N�(��ay���qi)�^��B���4pG ��|f=8r��
��42n~}���r<3W^�h�D�@l�K�g?2�Q��EC��#�C���!� c�5�J~�+��h�&�*�.��y|����MIM�Y�@v%*�S}��T9�D�<��*����ó�]�c.�H��P ���ϮB�D۵l��\m��WX�|�t�e"����wD��>��0�{bӜ�����i���5	7�\uLBA	�����y`\8�L5�]_�=e��Q�	���};�ь��tU\��y�"�Z(f7�@D�[�]LV�2�+� ���T��)�ƴ}��k���Z�M�5��,'���)`0�d�qj���7��`����������Y"���A�4�k#�(0th�+TG��R�\6�pg��Gm�8Cʇ��d��Y�W��1Z�B;�1��V�_GŹT�8(���� (P�5i��X�
�~�ݼ���ڕ.��t\/j"�h��S��D��2����z%�\%C�d��o�v����ĬX��'��㧆0��u�5�|�;$����(=W��24��w��,��� ���,��?��mf�Į���'
x��Z�ɻKf�ı�a]�v��3�`�o��OeN����ԃ8���78�O`��/e����+]Pp(O�����b��v]��ӭ��^���1	/�ã5���VJ,�� +c�iǂ,��T��F�7�'�>�X��\irS䈪�C�.R-�x�w��=�J�������j���U�5��,���g~pf�pbJ�L�<2c�E�q��%1 ���ԍ�R��pb����a���n�,=�Oì�Ďn�25��v���Q�6m�"t��9zY%7��x�nW��F��$���?+*����R����KH�ݟ��_V������AWq*�V�I�)���'Q����� E�5(����QEl%55���f�(�>de,U�u�#�7x��ܓ�`�{��)-Y���R��!�Yx�UM�;�`�Xib����'�N$6fbGZ�d���s�u�/}�|sΰ�d�N��^D��Y�WTL~��u�{��1���
6��!.��Kr/�6�}��n�=�����)��&�7��'����`8�֯��nX�#[C��o×��*�n�_��O-��|?�ao�cY���d�Pl�ٜ4��M�ˡx@i�����%����^���)Jʨ��ڮC���>v/V�5"5%��N�����S�oJo����������Ny��(X6���ŚmD�Q��W�e��Li�=<�ʦ�e�����e��Ʋ�/{���qk`Ȉ�UVò�5<���~�$%�ڞUbg(6�J���g�m[��ěQ0i��������t�'gqv�O��<#:��G�ؑ�q�h103),X��<��\]�x�o-��ı*�N4�쎒n
��c��6C���SW��J�'�U��ӱ@�!@��O$���m.!�ơ��.���ﴦ��q�0!]XQ�8�Ǩ0���K�ax���n�Yh	�wՍf��-��o��'I�'܅�}�.)�m	1�x���|Z��f]<�އR�Ғ��*�W
��j<�#%H��rx��ͪ����������{�18���(�k)�*�%q9�4�"��m��f���j���T��%֊�����i�Z\g�;�Õ���Ϳ�uX���y�(C:��	���pk��v/�]�u�aHo�"����PH�8��拸�B�p��|��5�>%Ч�o'n�A����,�	� %g�W����T�խ���*6N}w�K\½���r�?X������p��g����U�<����~=��z�b��u�����d��gsx��(�EdS�|
�5w�-����vY��է�F����f�3�Y.��Lg�YJ�ڋ}�B�QHC�ǘw��F�&}ȹ�Y�&N!H�ط��q��vzUKz��2gL~Y����>����<I��m�A�/��
�G�9��D�;��ԩ0զ���j�K�m�ބ����z}r�O(�{<ݵ�ҧ�쟬�A�!����d�?�l�S��f����R���aX��Ra�C9�"��~&�O�u��#�ׂ�%f3a`@ct
%�Ʒ+����\��� N�.�R�*�H�����Q�(+�~���^��|L9kYY��^ ���&��:������MxB���O�-�����r�����#����!2��P�)R5`���0��R~ڏNw�W���`{��jg��#=67o-6��8��Ѱ;,�YɣC�o�j���Gxoz����?�`x��G��T"��|n�P�ίV/�����qePM�H5	�U�L\�d���Z�q��(���6Q�Q��p�5�t���ɍ ߠC�2c��C��w���7�|O<8+/+%e���)�d���#���J��b�<�*�=!j��"��K�z��D���S����'��}~��C��H�S���9!�
M�"��P���E���C��c�.�]2,{t��X���`��8�k��C��v�\d�Ⱥ��#'�$2�;������S��!҄�������!�6�?�6���x�wE!Y~�:1��sK�!��"�<k��$����������Ko�D� f�=��p�����۽n�qn8ֺJm�_��� i��      y   �   x�m�Mo�0����*U�
�1q�Rw���U�0���R	�i�i�Ć8�y�W~9���������n�n����_0���c�>���=��f:i�"��L2����9��Ap��y���J��8�<��51bE���1_�:h�3:�U��\�!)ЧH��^~�o��y�T���]ɯh>;%�Y=�,�������V����2�e
L����h���X*C��$I~�GY�      t   �  x�͜�r�H������;�"�i	���W	���T&Ȗo&f�k&*�S��(�����L�di�+Su��*:�e����rnz#�4�����?��/|���/��������ӯ�	?��
���_>���U�ӧ/��������U��������>����_��ӗw�Q��4?��17��!�����Q��G9�ꛩ[>��_��m߭0��j�{B�HF@NU+/����m�V�A�dI�B[
M��oխ}a����|���#�r�?WP�@$�#��J"���=E��Dk@�H�nI�q�uTq@j@,t�U ( �| ]�,�}�����o��l�%�@eSVR7�"2(�	��� ��o{�n��r+�\�-�Yw��};U���ͅ�Whr�`�e_�C��AsS�=�H����>(T�o�b�Sz5�M_������7�@�t�(����uV���姷/�y��GA�K��"�3�ڼ��޲�j�ʚ)!Ft���'lj3j2�:�q�Ƞ<c��2�����2���G���X��0cS���������e~c�˱����)
�*
��B?hԠE ��m��F1��Pw�����	kGI;>"�Clꆳ�vVh@'�M����mxA(�@$(>,�z�S�������} n��Ád��d����m�c�K;����c���>�Yj�"/fڦ�5�v�s�b@�ء6�.��`����xKg�rF$.�,�^Rk˟����*[�&�h#�Y6=̕�s���_�*Y3bh���ʮ��K�����T5IK��I���埽ң|GXD#���Ũ�D�	%��.&c�����́�@̠���XֲJM3�\cN��<�1�bP�B���B9�=ۃ��
a���g��N2����^h��t��(l*JFW�kJ�-�S�qۊaI2����>�(��Z��4r�kt�q�RW��z��xF�L]'�UQS��U`�^v4ҕ�p�o�!=ܿ��)u�W�s���H2��E�J]	VʞFf$U�*�\V�j�O�<2W	�ui�m�q�3W34b��Q�*�i�#*�QӢ�g� b��nq{3Wѿo4ez��̕�A��sb���8�\j�39���U�Av����!s��YC�4-Z�B�rX��{H�����Ξ����]��s؋Jh<�j"ѱ�4��U1��cc�v�SGD]%b$�ۻ*4���ς|v��̐#����� 5����\9������]E�^@?�W�f����cf�q�8���h#z�h�
��V�l>c��۸���I7tsGF��gk��y�h�y��j���\i��{�����D6�Dl�f�O��c�Vƕ�O�ǜ��Uǂ��z2�?2��xV�<��Fa@�6�B^NN-N�Q�*DT��w�Eu���m��:�q�B��CW�3jIK�-n[�
s	Ϋy'ED]U^P���Z6\H��ГٟI{�Z�)��]u��1��dٗ�6�ݝ���� \���b�0��l�Uv�UNxO��^��+^�U�r�[]BĎ"W��w+iW\��S��I̐.Z�
����T�+r�e3a.4���"O��=:����C-[WSWn���)r�a�*�#-f���t5���x��l�w����_O\<��HK�b_||Z�`�f��p��b_�����Q���B�*��9j���^�nh�F'{"u��ԥYa�;d]�	�Wؙ,�q���g�#�j�
G�?#�j�f&>Y�#��+� �+���P������lW-<��,�}c�2�QN}5�Z�O K=�4���y���$3��4m��h� ��Ҳ�5���xp���=%��������m�}*��uJ\f�O׏��WK���c�R�w���C�-�z���o���8��6ޡ�_W��E�}�x(e�G�"��(������k	&/;�c��D;��"�U�xlT;�?�9t����	ϱ@G�Cm�:k̼�7!�*s.E6E�h�8��$k�'�����U訅M�F�W#�eQ�籶kXh�\��K���*ʦ,[y
r�|c�OZ	���P-G���;(�=һ��'��q�H9��
d)K,�F	*㭇���S+N�+T�~Y�[�}��9Ee��80�ޚ�i^�o�o�ҍg�s��la�R�4����D�N#/�x@��4���D�K�^0��bӝ��.7ޯ ��4�*�䊼�����l�j�\�\����� ��2�v=��+���/!��F���ճ���.F�̯�\���N1�e~�X�mŝ��ء,���F�,N�Cg���s�wO�������Q旐O9�2�r���d_�s�F������rl%�&dw��/�Z�{
}��x��\�?��N�/X#���'����]
ޔ2H�^�!c��!u����-;�7t��N#���g�m�x2S�3�:u��k|� ^gfxvV���c=���T�_	��۠&
n��JmB֖>�x�-n{��Z�/��~��-ԲKo���&�#�&nr{��t�Wя6%9e{�L<`a݂�b�r�N=�7������a�k�`�ޮ��[z�p㎔޳��gz�7=�}�m؀�=�S�c]��J4�p�e�X���g �p��\ܕ�����t%I�
�%��Y�3LW�D;(&DU ��D|��K[��`D;J�@N��`о�}�#�=s(����49n���Xk���0�V#���<L�=�;?��ˣT��ϧw�g�S?�f�s�Qv�����x���; ��pS���xG-�\_q���u�Ȅw��8򓘁LLp��O�b�I�t@�ߑ1�d:`�ߑ���t@���֑+���:��D����,-�3u��<��vv�vYoݭ�-d5����
ka1+��[��͏!Ep�Y���Ĕ��L�e"dp�X����,Aϖ ��˩h,��~n<��0�,,x\���d�^^#�^��-���-e��ы�^��N�]���/xJ���>jP]�[�����5F�gm���x)�S���Z��~QQw�D�i�|�q���b3'��:f-K����KE����R��C����b(Z���I9��Jעږ���?G�'|ѫ`^i�����R��\�7��>�2�e��G������q�8Ⴞ]��ʛ���r9(��3.q�ew1������L�H�
V�?�r80f�	W�R	��ϕ|�\|���g9T@µw�]��e�	��t�e��r�]Y;-���|��]	�>9��}�6����V%�Z�7{Z��&���1�\�VוT-Mv��p`�r��/-���+i΅�4���^�-�)W�q-�3J�/
q�\`�ux���k���#�B�w�&�r)^�F[yQ�A��G�
NW��#����(��q��l�W�F_�q�Z颖6Y�����}�%D�Q�^:�;4��� ^��ׇW��P'[UJ�k��͏�gA`;��8��&i�Y��
g"�3l'�dT�����WҚ+Eͷ�i�Q�g�k.�A��K)��໶k�����Cq�J��e8�V����B�KohF{Z�,߯ܮ��,�.i��֜K���k4�5�ݍ;{����"��4��I��O�5W������B���F_�,C��n�@	<��y���pnW`���"��sZfB�x�w��r��`�C�x�y�q��<���芠niKl�y+��l7���$wz`[쨋�|��G\[Fh=�f�a�rU�9�3����n/�꽎��'����C��KH����B㖆\�@S1���\��,�%V�����-�����T��⊆K9�2/��B�h�{�5��<�5�;����.Cߎ�{��/�uN.�vx}����Cq慉����:�j^�Σ���تyA[��"�7S}/�BS�=ʮ����ܰn���ƌK���Y���U�n�n��7��=�nh�}Cù@�.o/�MEthdK��������R��ú}@�� ���~��]C3i      |   �   x�ōQK�0�����o� �|P|[��&�6�T�4H�IG�"�{��*��p��.�|��8@��p���Q�_K�:��V;3S!���To���^�TSi��Tk�4A�[#�p���W7JV�oC�{��S[���V�TsxZ�Σ��+����MA��x��Sm������"+(fr�3��z��`���_{�����̫?`&����5d2���	�{Ѐ�`��}J�6�m�(z����      ~   
   x���          h   
   x���          l   
   x���          j   
   x���          f   �  x���MO�@�s�+�f"�jg�[=U���"[*�W�j#�s�o
x=��*���;nڋ�okմ�N=<���n����qP'��Zm�����^]������Ǜ�K������b���תB��Té��V�j�^�V���<�<O3�� N�d�����h�����0������)�`��@���ERT�,��\r��&�-� *�(cF��H���FR`ǋ4v �����������ݮZ��Ug]�y՜�էN���k�~��h����8<4�M�=e��3 c(+jd�ʘ�1/cAƢ��R�$��xVJ���=�R�*e��R�����I��s�v�&I�N�H��T,))#R��<�X�DʋT�(Ri������� R8U����2�Y�(�(G���
�D�ܛ�U�d�:E�j�-�0jF�@t2�:F�ТUt��^�A�WU�fO*&2{nR6{_��P��HeS�I$�(zV�8W��V��T�0      ^   �   x�E��
�0е��ٵ�"|����v�L���]���7����s/3HNWHl��>��y�������0n�k�@-�^;1��)D�}���$�`�C��*u5�20Rj�j�H��/Z�HYc<!7#��� �k6��_ʆ�~�ٳ����n��!�@�K�b#�� !B3�      p      x�ܽ�rK�-���+�:f�4̃�Y(j�Rj��}�~�2�@���7�x��#��ڇ�!2Ia���T�9-dd������ܾ�z�{s����W�r�4�=gi���g����8�V2�g/)����?{k��o�����🽝H���w	U���OO�U�t�ϞK�٣����v��_on���������`6��y�U�2~��޵H����?�t�/Xn���#<�@��Si��M�ԛ[���_�>���O��"�|<��]�<���3��lP3��g3DX�m/}-��������e�-��Gf2���<vt��#�6�9�̛ �����, d��N$�db��O�8�?t쩨�J����O�P�J��<r� ��@�}_-������40��1�������#�s�}q)"��x	SV�^"˹�L&*�5�s%��uV�P�\zH��W�p��$��>}�K��I3�*����ܝ��NP���m�u8a�i���c�i\g ��5/�	����W�dB�O����0�j�D|/�W\�e;�Dzr5�5#�>~܏��c�7QD_y��lg'����_��S�<g��?��s������q������)P��F�q<�КO�Oo�U���?���d,T��d"R�D:�Tɵx\X��4n ݪ��J��d ��4j��J�c��d�	�!�o˘D�`x>$(�>!�~���*�h��)���HB�eR�-Ѭ=�1'@�i��ǐ6��b� ���tM�=����6@���U��̈$7�!_\�x>л݈��r�*P�Y%���M�8�ڢ�� z�oz��o�~zy�{��w�����ͻ������5��Z���_��g��u�������_� V4�)W�\��&�F�+8��*��!	7L�3Q	�_���*�%Ox���c���/�"���?6��L����oz\�g^ǹ��nJ𜝜k�X�:ֻ����OűM�1�,�y���{W"�h�>���T}��}R����=�<��M��L�ɰ?,C���i,�����T����k}�)��Op��y��u%�~�&�Ƹ���m�5M��'^��[���>�G���$S�#����#�D���O�i������/�cX��p|��֖(�0�ʕ�´�"�J�[�x�ǫ<�)�9Q��'����O6Q6���M�	�33��o�2��x�bu��-w����|�
�cKu��'�ƨ_���f_�Hb���D:�Qxr���Й��v˄�.�/i�@��A���N�����wm�I�\*����`���qW�l5LF�9�0߄�^�d�z�/`Zߓ���bo�hJ�M�72D�+�ӥ`ۘ��)	��d�0.Y�WF�����Nf*c��X~���Ѥ���V�K����o�0S�5!����<ǟ��~��J)����q��d]X����b�M��L�Cy���Y����UȐ!8�O���Z	�UbZ�>���@�`����q�b�b��K�/���_C5��t��y��2L�p��O�ǻR-W������L�l��֗����M@$Ǵ��[-��|�h�xǵ�N>�c����/&�Λ}}�{*�m����<�&�G��W~Rz�L}�i���W���?Д̿��� hؙ��|�\U����UVF��9����m��koU���������[V�E�g�Y�Y}�[(4.�՚d6K[V�ra���Ǘє켁�N%Ɵ����S0��AVӘ���D��,�A�`E��;E
�Q(�� ��e��zW�+�<r6|{����p�F��
�#9n�ZU#��̂����ݟ��"����D����2��|�� ]��`l�7�)>C���<�A�O����+_'�����&���,O��͌����P��6��b}���[���!�����06�0�9=&��=�1}����ػ�7�1�4�9���_�2�t*��L{�}��j�Z+�T��km�^�zFԃ��@�(���M�L�ެ7�)d�����K��p�@��E0�e7k.��9{���u���J2�I���r�>Z?i�g����u�í��1Os8<�+R~N�G�V��|AA'Rq�ڈ�~�L�#o���f8l��xij9a]���B�	|�0)�T����~��ٗ.A�u��Nvi1V|�� ���9�a�������=�c)2�����75\�'��R���Y�_u|�X0�\��m�����1Ҋ$t��2�3̢�N¸T�'��^g�f8�s��Z*E��hlR���Ldt�����9���H��#��,�٢	t�c ��=��q����ڍ���ϬH�ӌ1B��- �Tz�
�I�7)�R	��k�=.M̕�>�\���8��?Ŝ0椁y�s��6��b�.ԟ�u��� V ��}�>�A�(���P�P/w�L�NY��A&��J�:|F��҇/�\f4I��OV����dK���nxd�g�4�˥O2'o��\�i�~cR>gN&���S�p�+���%KE��t)�"p�y,��I=/]k-�>;���Һ�Q?�� �.$����#����$Bd &��Y%.�t@.���� ��!��˝�\$#�h8�W`X����eZ�9i�3_�ǀ���>!)b3�}q��}��#v�k�!]	�4�%�B��h��������g4AOp���P�T�'c���bκ-~�;�f^Z��i��{�׾��Tx��F�-ݑ��9�;�fޑL�11)�5�Gh�ч|���VA��(��Լ���F
��މ�������A�|��!��]_����P�Ӓ����$ۊ֖�tX�H���O�0[�M�O����bqX��8�0�=�F�i�}�ȫ$�N[�Z�~.tS��2��O��Y��H�_��������⇂��̸��*���
lTն�@�D"u�:v|zD�W���{��N��.J}�S�J�Df�pB���q؎�������L6�@�ERy�ω	`�Y�OjrrXU�)���r$�u����6Os���B^��?4�.B��T�LX����L��Ӈgl�`H�2Ae�1_PG�T�3�C�i0�eߟc���ԝX���Xŀ���1�ٹ��XNi)^"�C)yL����kӆ��s��_$皱f���|�B8�*�ʕ;Pu#��<�yv��ȡ1\����VlH'��T-3��@��/u��Z�UN7��`�f"�ѺD�a�.&��x��������aR���6��\����9���e�phw>�p�D��R\�	f��� �$��Z�)"LLI�2&%L��[�8(��Hmr�t�3�0;�d�.ff23�� �=I�B��d&�]Ҳ7���Jmv:�|�ᐹ�8o]?R^��޻C��n���k=gcΦ2��4��X�-\�E&��?fga�_�fm8,s��q�D��}�� ��v�V��]:��VlX�F2� �%$�l<���g�׋He�SK'�\oAQ����	��X����8`��nL�^�$��b�B{��Ζ���]5[6̠��u�������R0�|Q+ #U�]F�	�l��B�e蚣�BxW�!�C�!
��d�0�j�ʓ�}1skg:�׬?'�w��1�����g�#����'� ��ϩ�k�Tڎ0�x�X�AZ�X���N�0�p�j-��V��x6W"����f��ߎ��t`J��X�+wj�������'?;g��5�'�Eq�._iY�`R��b��@M�w����X�ړ��.S�|��y狎�l�k�O����"��=Q�x�l�[�� ѓ]<��Р��Dt�ixh@����Y��M2��O�ȯ�|��g���ؠ�tñqʸz�k�����9�`�I��f�����IS�R���Q����A{S�@p��,^�b�2�姸;���
�^��Q�y������^w'�C�<�~8?�N̾��������j��y�(���!^�t=�A�����	�P�]��<VZ�~���[&����	;̀��D�E�])�K��-��gK�v���C�z���'����7c"����?��4��?��+�o�q�    �-{��p*���Y��lՀ�EV��σ4f�E�}&���S��s�MS7��hB�ơ���>�`t�8�Cx�,-���c��Ĕ�A畊+f蓁���;�yr���(C�Q�i/��|X�-ud^�>��a+3e�\�u4Шk^�s�O�?$��}Os�HUX����QK�XZǏ�Ã)�t��L(E���4�P]%�e��5"�����^�U&�Bf�09)�.?�'cD���ﴷ6��W2��p��F#���l&��g������0p��4���|&�3�_x���< I��k���P<j}1yuN��T�� H}�s��,	�/�y+�g]܃ɽBy�C���Vm�F�(�q�p��3�U���2ԑ=جm�Rz����{���x�;갅�*%n�@���j�>�4a_��iV��C]c��eI����՚.o���W'˹VG�&����o���Jl�h}�lo]DsW'dw��7(�"�m�z_��I�_�c2HsE�N�}���(�v�����Z��U7�RN~o/�l�Ӂmd>�qͽ��a��)ˀITM:����^Xٔ`2�%��&���w�M/����0�6�a���\��²/L�S������"P���tͫX���Ap�6�h$6�pV���I���2o(��J���<��>�Ei�m���&��#!ڕ�J�rԄv9����M��:��g�X3�l���P<U)�OC�~��6r��P|Μ�f�N�yr��Hz>�	M�r�(t����7�6խ]@I�g��%�9�K��MŲƻJs�\sA�.s��'�����wk�'ƍz�oWN���Wk��j��А@�tq��Z���������ĵ�Qm"�9?�����r��3>��3�rDjF�����Eb��*�Oj��sn�#���D�S`�t�T�S9#f���D�#
:s��*MX�l�^��9:�O	��.�8.��(ؿD\S,����҈l��:7c$_��$[|�j�Ph�j��ස�_�cGP�0J�1�9�D��V�G����h]�|���Ԥ0����?�{L�ʑr�s���� �*�g/�.��BU���	�XdӢBbxrq����L�$�T��[�-ߩ�z��֗��07[H���U#�nU�/A/��斋R������e�l����V����J^`�t���j���bSZ���[;�-�3`^C���7�|?�"JС���|�Z��L��H0o���&bb��7R�a0�Ѭ�efLi�g��_�Dݘ8�Я�(�<Ү��#�HV�'�� 3����=��G�����띌AkH�u�dNA�L�ڊE�]��$���o�u
(-����	vIT�����}q֦��_�ԉ����܉F(D����AXa�e��r0p�t<?}��δ�)�K�W���Jr?�>-�7��}�^�&��8�s���|����F����	�?�D��Ƕ��D�Et��K��-��|؄��o�K�W�3�/��n�z��b�z���W�=_����d�#O�ֈ#����JD!�5���q�NYp����֫X�ZÃs�2��SX�g	���L�����N|�_<�U�tG�#a���d�Q\PؤR߆�e��,��*�a�5_o�QbH�氽�+ų���r�>��2s�i�r8`���b~��/)͊g*����5"ٞ(�o�ϻ��1�g��~%҃aF��P�/��Ls�=�Ohѿ��6�S�L��k�έo��{ѻ�6�}�O�����lߔO�}�w��p<|��==�SE1������s_��x�d��T�0�P.�<&�b*`N�2d�xg;Ȏ7c<"�e/�'�k9������a�3i��ꝯ�©�Dj~�Ĭ�~�YC��|r���C#WBE��c/��y^��0��љ08����o"���T�J����}W}iH���׿aQ&��@����q�|�Y�qk=jG�0ʼ��e�\�B8<Д+QEh�z{"zI����TY�r9㗀���_p�c��fY��Ze��Lp�����,�OoԼn�jbb��`)��|`#&�m1�RfL]�Vf9��He�p����Zyh���úA��Zxw���<��ES�wje��y���N�!{�9�j�'��W6t[��T��7�.r�W����S����<�V�l�w~���+�EmOWx�9NX������ئ��1��bؗ��Bbӫ�LI�U-F�.w�nl����7f�a�]��3�LX�a'R�(���mH��2C�V*�C#sU�����C�y���������P\��P;�B0�^�t�2�LYǃ~���X��D��Cհ��^d�B�^���`џ��;+���xpj�XES�sF��>��?V���Yצ!tS�Λԗ�d灨��7���,9b2Z��V����A��l��y�V�����A�,kc�#EA���y;�֎��*8!*P�!��+}37r#�T�v�(����}V*W�<��}D�r��=���LqO.S���~��T���q�
�����s���DŸڢ/2����������Z�G�Ga���¸�H�SG�� l�T�{1�[�r¤�^!�<�]Kŉ;����Q�'�l�oM�@�̗>����F(��+pd//1JO����C6��U`܏.j�/p�v�.�l���Jl/Ӿ ���]�D��+��usРe�Db��?³`L��J��3S�sU��F�N��I��	+�q3J¹���"�[f�p�?���I�{�0E�MF�X��i�m0��7|`)i��i�����u���沗��@gh*NP�n�P<�V�X �NTx���/��-V��2RA�R:;z����U��jl�.�̅�P��p�\�uZ���8){p�$�X�;��|�*�DB��(����*1]"}N��n�d$��1���ff_����I�X0Cv���z�DO&2X&"r�����K�2�]"��򦨆X�����'���A1g����Tg�,5�X'筦�,�6Ԅ��pI����NËa
W�5aР��p�A����3�R�����&��h8l8o[���v�����v0&���'`*�F��`���>+}.�\��p;Oj�3�!4|"�������Jр� �eEJ�en�B1�[Яb�C8\���ǈ���]�1���V��Gt� L�'��G�YZ�X(K�w��Y
�3^�܉0��6΋`�M7|��ı�Ӕ�\��g͒�6%3,v�[�K���N��q}6� E1��R��e��f��y�t����_Jq|�It�{�]������|�ǭ�,	xd�܄϶�"�z�EΘ�lh+ 98��o����l��8��)��|w����I��Pd���D��
�.��Oj�C���"î8]Z&1EyLe�0b�V�*H
�Z�]f`I8)�J����k��r�8�(]��VAA^��n\ө	q_t|4�_�*�5�������c�\�gH��?���!9�`�\���������	��V5R�8��mV�| ����N�CN�c���.��M���=:��ų�
.�2����Ap!�+q��=~�
�&m#y(�Vz���5A��EA�\�y��.[����rW5��1`0�[6J�m �b�M9�6:1����y΋I�Ąꩽ��N�!��D�¼ss Zڸ%��ܨd/���*E�*K�X���өڐ�O������)�u�!ֈP/Wp��	#�N�
�ء���h�/��,��Yd��]
!`��ETS�^[�XU;.=&g��0%�"9o7�)0h�JvQ&څ�ߜ
7��XΗD��%�Z���$}��D�����K�K�����o;�#�ň��V'ED���q@�^��7���+õn;��o�`)գ�P�X,V���v�T�]�?�Al�D�
��?!$����ɤ6���KV8��-���c������e���\�״��0�ڊ⠱� �V���iZS��Iv"qnK� �%�βC����aN�|ƕB�HC����c/�7�ySC�sK���s��a|):5��vw���X�w���M�&�E2�67"����'ͥr/|7�r_�B�>X0���`D    ��/���IW#���,=�yQ���OX�V�#�mR�$ҷT���j-�$=i�K��QˆY��Ѡ�v�Q������a�8h�ڤ2'��>"�E2����]�0�沈�z8�JG���,�(�0����ޢR�� Z�;�E�ڊ}P��%�H�yV۳�җ��3
��&�qa��Z����AP�0����X��� �Ze�� �6���M��b=��A�*-��)�Y�К29���#��/6�L[�O.Af�b/�U8/ZnRy�
78���Cߜ�ҍ]�h�2;�D3������kI�XjJ2��������������M�,�;L�B+3���0��w��]��u=�z�7�J������N5���.�lN�%Ɣ��`� �+G�]�%�6b�����V~گ L�ޝ���	����[��極1ݖ"�u _�;���z��i������("4�"�H�	o�_�mJ�J�.���<�Eݝ\��&]�	qm*��s'H��s�������R-����ј�i��ٔO�$}&w>Vf7'��2Bg"vdZ�Om �iN�d���։�ӽ�1����O�)yKЖb��T�`���sx	r�芬�شΔ�i=�_�J�^���C�^���\gv�DGl���Em�_����������҆����zr~\���-'`cNX��b��{��X&'��]�?�\�����R5WX��6͟4 �	�-���}��I��0�}��wfׯ��ty�v�㏬�}!��7$��L.JEs�i� cX`�v�S��׽���z�Y��R8ꈷ0-#]��J?�j|PkkM�1�!�AQ,��>fG ���/C�\ŋ/��u�=٪0t��+N��Xz���(�*F���:"|#� ޅ_���f*T�����y&"����c�f�v�#��hȪ=�0��q&��h����r�\*x\���I��vr�Y���+_5��
�7����=>�!�2"�k��m΂/"�&]��~������۫������������t�խ���ۋ��Z���#q~Q�?��q���}*�+�o'�Mt?ɒ���W�G\,xL�V9�oTP�x�a6�CB���$г)��a� �g��k��� �T-�w ��Ɋ�ՎNxy��(����ïg��qi�^X/p���B���d���7�<�����'�)��H����W��c����8��'���1�J�{�L.�\?�Wt�>rbY�E�q��ӳ���r[-Tri�27�R���q����<��H�>��.�C���*Z���g�$���F�UvR��E��Ҕ�3�e57��	�d����"3-�xK���(��n�5�^�gۑc�ne}5��3ü�ۚ�OSAG#�T��R_̗���e����l��r����E-앂���vWa�C�f���]�gu��H��VHu��y`X!�k;�'�j��i��H$풍X�@ti�;qXuZ���ڭJ	?ª���(q̿I,��;=���Pl�O�H;,n��Cg��W�ux'������"��yB>+K��|����\X���Ҟ{D$�a�a��ع��WɄ��/T���*�M��Q� ����?f�py�>��̿���
/�3�x4!F��"�~͎��6�f&(e�����DK�M�	���|�1��l�e����Q�Ӗ��rnֿ`l�	��yN��&_�Taѫ�2U{<�!ex8�(�y��ꃡ�z0�.��u7Z�A���EO:=��/Ȝ���.����ö�狴��Gl�>U�� n}��͟�`�2�P9��W_Y��A��ąyiO�v���Y�� #0ZZ�.�lF丆[����jX��������E3�w��1tbжb)���l��
�&�N�x��R�>\�ʜ��n�����w.��Kk���HM�L������i�2�N*H!�z�^�j>6Ø��M�a&y[�����>m6_K�������':z��0m�Ԛړ����leJ������t[���a��-d|_�rU���ۇ�I��ϯ
��~8eB��&�6���S$���F�iQ����#F�<��~D�J�<�ܨ4?�>&*�K�ɋ�F$'�L���9;*'���t���NEUN��@H�O�%�SV͉4�'�ML�T�:25a̋��Wۼ�ޅ�s47vy�)s�)�'�&����|� �/��WL��R�{�D
�ځ�4b�ℸ\�4��ɽX��w*1?��;��r�g���z��x>q����>��c�=�-��r_#�}�.�>o`�_�ފ��i7Ik#RYQ�l���7����A;Ȑ�7��Ot;R��d��}Zl���~Q�ׯ�c����k�}���Xd��:�.N�b�2�^�p��Թǅ4�YHXIT/��,�Dc?ʀK��	�(Z��Z�o,L��|���LEK����mƽ)��.�uDV�������'�=P.�:�v:�q�;�^����3�g~�Nr�W2��>�ïŏcT��|�9ቀ��e�b�����gݦ~/Ui�Y��t�6`[2�����w�L�|z6k*��xgNv��s��p�v�H��j��99υ��6�8߽���+�:�G K^����cY�V���|w)�<��J>���$�4� �.*
�2�+F�E��ű�"L�S��ќ+
�5�%�c���2��d4jgN/C��Ζ�b�'�I$�dQ��wb+���3�U縆ԑQ��_�ӛo�.�-��������ҜkW� -K�x���s78�ƭ�?�܍��4x��������%�{���}uh��a���Sa�_�p#9{t��l@7گ�+����Ns��wv)�0Z0�{0lA^D�P��o��M�u�Ա��0G�9f�[���Mh��`�q��4���G#����EIz�+��y�Q6����.�Q���_m��o�d�AnN8Kz��"�I룹4@Ѩ���;k�j<X�A�<��{�3q�oAR��4"C)1�R�MO��Eaf�,�ʤjbp�nl�ĸ�yiw0��|�����<+5���E\��=�����aq�%D����f�a������Џ�;���*~���cv�\�:�r�n�>�c���8/p�`˂��kz�8�iu�萜FŹv�6�ɨ��[�Q����t�׬�s �X�5��}�S������;�j�T/�4�{�}��힌��H�3K���d:� �����1��/+0�s�.j�Mǽ�,9ہ��C\���p@�M��6�}x[O�(1����t)B+�y��b�ݫ�Ο�A`tP�*�����cYj�8����e�W�@r����Nܧ��;���֚x��j�]_+��������|��ś%l�i^1s�o΁3���Đ:P�����`,�Cr�I��c��fI�j��q�7mh�b�*�"^�ZМ/��F���5-e^�/�?f��:��{���� ��#��!Gp�4�F���`j��{k0Sj��Q��.3�35iG(�މ0��A�����c��;��g,�q(�m�-����M�ɶ��>�.�+kc��&��]"��l�X}/Eb��ZߊRU���`���v)½�[����I�j��V�A�oy�����)�ͦf�)���v��\WxB�IZR�k~��7q�>p6�j��C� nװ���BN38X��cɮ*�pSf^ĩ��\5r�D��81]/ ��R���s�UA]��V�B��R��DN)��� mQ�/G��J�U��m_����'�2<�3~�Ͷ֢[�%��ՇT��^��ŋ��2�D&��1f������(�I�s��0[T�K˓)L�_�8��c�M�厙>�����d�������������2޴ڟ>�s9dno	���-��³���Jx��Bv��U5��d��){���l��uRO4�d~X��pvb#���Ķ��#:�M��+���{aDha$��vE�a3����Tt}Sȍf����Y�.�p����3ooR�d-����C��g�S�ҫ<�d�%�]���rڤNy�	�Hx����Y�Ę1�|�@�Y7��2�}xy93_Q��MV��3
`�]N:��-q#�b��    b0��>�ˢ���Ȩ��O���
��q$Q�(B'��a'������_�ҷ`�P�C���%[yZփ=~+��z;�$I�� �|�?F��0��g�d�J3�vN	�x<��4v�ZG��M¯����Po��4��g^�xQ���3�M��3�0��rn.@Ӏ}���T��F\�)Z��A�UjDd�<�m���غ �a�U�����<��3��9<�b���ŷR�E^Nܭ����|��1��#\~�v���-;]��U�9���0��Ĥd
O!)�ca�0������ALu~/rk<��2)y1�����+e��RpI���w�bK��S�ɉ/�:{�� _C,��ݕ�,D�7cF�?k"���6�����M���D�\9�0]φ8ef�1W+Xڬ�֙���ig:�{�����:�*�
K�r����3kB���EX��`����i,h+�����>��'s#a3[�%(�&�a
S��x��)i'�dܻ0t�k���Mo��.�V(�<<�tA����^�zֲ�σ�E���mA��?ʺ��N�;����uSզ融ܴx�Ux���D�sx�a��Aڿ7`�ΌZ��=h����`O�0���U���� y�.9�_�tK�����Db�щѕ˞�έ�V`ϸM�aK�(�g�E]"�,@��P*�-�� �&;��FDƅyI&�O��y$-q��4#���6�g1�h�z�r�f�~�������%��M�IPު(�K.���q7 ��"�|Ӵ~�>�='�~�P����c�i�º�+r�( q0�5�<�[���v�)���S�V�Q��m����<�?ip-]�1��[C���,��=�ƙK0bz?<���N��Z&\yT1����G����˛�60�&���2���y��<u���~�Jڧx56)��譏��I+=�0�[5XA�� Ms�;l<LC�fW�����I}�w۠���U����s8>޷ܨ{��i�w����hQ�dh����?�t��Z}�H����P#�ll��qڳ�'Ѣ�Z��|x�������v��c\��uG��Ɍ�4ҩ.}��=r�}��J'��q� !)Qm������ǭs��I�xkp�y6aE�y2�ug����	vs,�������ķs
A�\z��{��z[�~��OZ\עe띹�Cɠ11�t��x��o���>�i�2IQ[ `�F��-r�,n���~8!�ڵ����5ӝ��	$�b���\Tp�w"�7'��3f�h���tR%A<��r34RW���L��6����D�F�5ϥ�6�#�Q�mЧ�P�X\�%ތ�����&�eB]ſ�Y�	���<���M��5)�FĘ������������	�u�H7����^Dg[jIV�Q���.�n�BC/�����[���x��-G7�~Ml���zf�t�ݧ��
�"6mLh��P�������"�U���E9_�Y�D�η8[\�re9eGc����f�&��R%#�Dm���1�xK .�H�﷠$xƠ{���9�u+�k٬�l|��Y`��u/��K�S�v�}(��dK懡>z�L��`�>qK���Z&�o�b�W�A&��2{��|��)��M��9Wd���@���c5/��h}E&�S���;Ud���J��J,��� R��}��qc��_�DiEN�c\��>�.��@1�/H"��,R�v�sĶ'���ʴ��i�Gf���,ǆ�Oq�O�U׫�� S���J`*��/hc�y�; �~S���z��IΧٔ)Cqjx5��;������l:��5���NO�Bv$��j�Y�_oB�2���U�-��Q&Y��a:ي��v� ����Oкҹ��`̖�6́��4UMv��;hƌ�X�����c/�[�G"����\��動���Gs�zE�t���I2���F�jڀ�M��S�li���9m�eVAG��5Y
��^����%�m+�ӱ�ô�:(�'����5�WT��	�٨�9=a
/Wή�^�ߋ��k��`�c�����+��\Oe�zKK��"��˒Tl�g��C}�g�e��(5iVx��/��#ή���!IP;���cR<�['����8jWT�6T��)N
�CuⰢ㫶̲��*�"���^�rn�~-~`)�j<#s2�)n�G3��l���oD(=�KO�'�'�J�/*W>�Ѽ�N��͞��0Ֆf
X�k&ě�u���,�T�k�@��������L�@p`�.ږ�9�%蘕_�b�'�������%r^jАxv�52Q��)ɵ{B%R2t�.�h���H��?�o�k=��	��Ʉ�4!h8�}���ƿ�����d �i;4�N�|�����'D�� \W�"����7H��C���ˏ:˿�R�PF��o'�a���V)��C��2e�.�Cq��Q�8�d�I�P��أm���4�p<gnz�5*�'S*�K�>�D},͑n��cs�V`<0��G�Vl,£X܏ۉ_G:�tAP���3{T�n8�ɍ�������i�������F����.Hͩ��2�2���פNR<�y���$2������-�/K�+G!�O�c�%��Kb�E+�֒��P�D��/5r�+q�ު��?�ݻ{�|�sS���/��B��h���&�� ��L1��w�<q��&vv�4U��]*�����8翿o�VACl24�Ksҫ��1��DT?2凒���et�w\"�I"��Yk�3	����+��oa���"�A��T�`�v�+ ���sd�&ۀBQ����h���_����M���e쀚`�8��>p�:�#���(EDv�U����;�7TPU��Ŭ�=��.2��u}���"�6����5�� T��O��B�˕�`�%u�B�ʏ+�ۑ�u��*�` D�	�V����=]>�����|�\qm����D�/O�+�S�fϻ��#v�pfԶh��2�@�
`rjX1]�J��c�fn���xSQ�
��2Y��3A����|Ѐ���Y=/��`�AsQ�E����T��r�Ħ�boK�I���g m�w�ZiO
��Z�͍L��q�_�+�YqӃ���T�A��Z���mڻ��*a�����W]�vX����iE�F���b�H���\q��	ezۆs�t�3����7��3r��Pr��F%""Ӧt�����/��uR�` O��ߡO�d�<�p��p�g�H��"�� �5�U��!i��������4=�m4}5ߵ��tP���0����!M"ϥPՄe�\�i�J�(4���Q�o2�\6"נާ�D]/Au&8�4�9���%���f_+%����8ǹ�c%�jNؿ=W�'��U��=uUU)sn�bǧ[�%T��X���O�Ճ`$�Y�=��·5c�Y��c�>�>9�O��+0GxfԜ��j�r0]h'��*K^5����`铮c��$-�?Y4�)T���*�u��Z��i�D��h4X�F!m�2��
@c�۶��n���¶SjwU�|�u��0��b�|�L}�}N��/�s�p����� 	ۅR�\�5Gm���Ζ)�3��_@]�zI³A�`�1%ԫ���:>+�0Sbl�ы}�����T������Ƃe��t�!�`�D�!U9���*-Z���z�'�%8�1!ҧ��gE�Z9$�D5*%�e|�q���Ղ���+V$����ZʷXѩ~K	�>��Y0�r���\�"e�c������x%��qd�d����/F��t�A;ڥ>(,�G���U�^mT��[G��t��C��	��'��QoU���yp��2�ِe)���J��V�q�c6�~ښ ���}]G��Ѵ�o�����ŴO�F�,���$��Z}��lY��]�Z��;>�W�P/|�lB�;�`�(�(�uW�ّi�q���W'����?�;r<l��~�dή2
�}�	�T��>ֲ�2Ƥ�a+y*0�;.��U󇉅3�L6�����<����@�NS���w"�wn��_��e����5�k��J��a�+&��5���
d��.o�>q�i�<�+��L���\HہkG���7�ܘ�' q.k����gI��)�    �V^�í6u��X�l�-�=ANT��e�H����t	vC��/	_(�ع+�?�#�2�;�|g��T�<von:�M(Q�O�ϋ�rí�򘙵���ر����9\ح�k��?$K�r��K�[�o<���@�g�7X�¸C瀄�-D[����yZ���t�7�W��gќ��DX��x�<��c�<s�8�	S��p�S.��i�	�U�r�e;�DnE�э��?�0�uN��-�7��983"׮#��G��B>�0UUT[���N@�[{4\���C2ڄKU�CnW�Ɲ��9n��2}y��M���f�"�m��ӑ�ұ9=aM2bgj�f�1</܄�F'p7�g�������C�`�i�$����!��HG������%��vʎ��6h�Wxo�Z1�gZ�<�m)#�X$1\��"����N�br4�a�����,�8J�����LR���[S.�;'M���|����3�l�oʴ��]���ܱ�H���p%݀�p5K�b�/l�p�p0��b��-~��es����hAymu�F���	���ʩ)u�g�?w}��{6�7�D��	�+Z�[�Rs~~��{E��k�_�gLK�����O�3�wX-�7�΋4�a~����'�F�����{�'Edl+c����d�D� \���0�k%�ɯ�t���UƩ.�(9�8k{�C�Q��?�9+�k�7�l�ߑOa�/�Q�n�R��o)9�4,։Fe{��A���W�J��W 	�A8�U(S0�w�p���?�
��t��!.�<���(I�=-)tK���<>1��s�i�}�n��Lv��U�5��O��嘝%9b�i�ZՊY>��̂Rn��)ڥ�jI�[�Zx'Y't��^�Ί�]F���^8q�sT�@S
�}�����`?���P��psI�}�G�9e�Y�h���g��&�V�[/�z�ήW� MqIJ̒�.�Rs�G2��������^�'��m}������5���'�y�[��[d����$}��5��l�WI�`՛r�E�O�x�����q�V�-��b;�q�|���"��Z�*Pm�ũV 6%��Mԁ
7e��t6kC���me=�*��1����{ɵ2�0O/O2�}�״&�/֠�v�e�Es8�r %�[L� �	gJuL�*�k�ĺr���qsl�����l��.ꐡgrSu'�{U�>�:��9"o����ѾQ��ʩ���;lG�F�Ix{�pmr�!`đId�4�>�X��b��2��q)�)�q?��轖=,4+L�b��j��?=XK�Mtq˅�`�a���aV�t8%�gŮ8��sC�/�<C7*��k~EKR��RH�t(�a#A@�ԉ��.x�6�.
<���R@�n�p�8ő��yራ� i�V&�t�\��vS�L�O�X	Z��uq��-?�M��:'>�+�$X1�w�׉���T0����Xh�Nʗ��� �{�rNM����Pߙ8�茘c�s��2?�$�3%���n�T��Im��.VØ��I���2���t ��粳�!W-�A06vQ�����^�3]?27qO˟WОr���p�B�$dTw��e+Vt���x����]9F���wB)��Z�[�=S<m�����N�����cx�DO�0��'����Ŝ���uW��v��p���OD����3F^��0rߴ-߈H��	N�l[���P���2?��ê�/H(>S�r�T�s�m��[)���VL��Ω�R�/�߄H�Ɉ�O�`~���c��J5&i�-8�I���YQ��b�O�V�<ܪw���N)�v0'�0U���z�� d���)�S뎂���..<ahQmgknwd���`T�xjq�i�v�2k�WX;�f�8����<�:k�^[Es�G#ҳA�f�[����i��׹ߞ�]���hݱ�>2�$
��}��e��(��P��k߄k�VU$`xd(">�|�������4kb}�����Ҫ�ҙ 9 E���������T{$�ͤs0W�l�"C�z�.�ؠ%��u~��h���*�P殯*o�w��*e�D��.�m6�l�ea��߂��mf]�d/�hs���!	k�Z����ζv�Y��q�]P����P_a��c�0�j]:L���{_L�jk�5��r܉ o�%x�f�n����=�!3���	�(Z�����E�t%�~��0�����7C5극~?=aGcer�o�]`�ª�ӹиE�h�h�J�v�<0���eϕSE���X�9�A��\��۫6�]��w d���e��o�����JS'UA�Z�XIq8l׈��;w��[���$57j
',�z!l|�r�k�{Pӛq�5R���)��쨗sΎ�A�ڒS���I<"o�8����x��*�4�Y4f�Q�/��Xs	����쟗��%�@��5z*C�x`i��~��K؃�z�i�U�w��?e�����\���ݲ� 7"w�k�N�b����m�h�G��:/ ��j�p��#C����I��<]�P�T�
����|�Ú]�:<)@�|y����h���.�)����3�j��a8����h��N�]�XO�A�N�b��W(fm�����Kޠ�"=���^��*���26
=;U��9��(�mr[���� ���͔��^��\��%Q-����������l���Ae�~�_R�0��޵���Ц��kl�h��9�
�{��7b�Em�4M����YPg,!Q�-`��ǃ�LU�����[ٸ|�]��Î��&�%&�/u.,CZq�nW�c�����@m�#D([�XND�v0�x�*U�h���֓i.��J��_KyO��\�x�$i&�ǫEL�<���@_�1�gt>�*R��	"��Wɢ�k���$Wq�v���q/�������4#f��<:�E�P����YUX.�3��1�9w��������<��Z��MP�m7m�����Θ�I�ދw>�X�|-]�I�O�v����x����[l�zf��.�%��Nr/3�C�8�/����PD"tj'�wg\uF1��e[h��P1@�mD;K,��D0}t�ϊ��D`Q�'�U�xe�5
�f3oe�b�?�`͊��:���è|�_�`R8��u��"Dm���F��0�Z��z�Dt_0���#�fڣ�b�Z�|[Y���+�BFD)��X��Y�v�1l�-���.>�$�hUT	�K<p�1u�֚{�������j_�83�S�@H��T�x�K�V����+�lw�����Gb�4'�ݎN�?�i�t��b��Ja:M��Ҵ�ð��q�V�WR���hr.
󁉾�7E}��W�P"�
T�hY���ٸ"�ZXď\��=�i�|L���9@��v�k�$���;�,��-'��v���e6�:�~n�*���܏��ʛN����*˰��Hi����:�C�	�c��ߊLφ�Fo*���^��� ��;��8Ʌ�D6f[
�gh(���4yi�:��M9'As��CbO�O�\o�C)�x����1�y>�4���q�N����2��_��;�,�L"����GJ:
/h�b>�E�r�\x�C�r,��s!1㉴�?��dM�jS�c��/,x�d�S���Y���|��t��,�	X���F;:�?���lAطI��|�vvtc4br�iO�d��u��O+�W�gv
$U�� �*>q��� �@,������-I�a�?j��\��k<�PE�a��`��m���U�b�8�P�x%��]4ܗH��fz�f�\�˖��8ȕ�E���Au�Ҏ\mC������e�Bnr������'����"�&u��ժ�8;��yk���;���ZsC/�h@F�-�Yˊ9�e�X�ǜvP����S:л$��b�E	R~�XakWs�%A��JGE/��B�ѧv+/��4�/"Y�Λ��4����z"����0��S���kP�#7�6?��G�AK(�u%������?>d�	����q[_��'���3P�o�<����V�t�LD�Ta���k��|��K,�f:�}�;����ρ"��������@de
�?=�[�V9%�z�Ǘ�t��    ?��W3&��O�4Z�l�Tx:Y�B%h�Fk�j�ë�>!Y �=����O��[��u(X�t���H��r`��j�;(�ԣ�-�,ÿ	��Y���I�/U999G��d��X�:�r�����vD�T���x�¼2O�i_��'�p߻DŞi�rS]���\���33Q�&Q��3f�sP��R���s��Y�"W?�:V�\��2�Yji��!Q\�Z)�	�v�∾3����|+�o������4��I���i�'�*���]^�Y���_m4��ف���+���+��)������2���}�Jѻ�@a�;$�͘�N�U�gMl*#�Fk`��{lY�n�gl���kG��_�m+Z_5�vݻ�����x��Z{����/^0"A�pRA��[��X�7�'����wyaλ#5��%\3��٘V!�E���1),��8jCO�n3 �9�n��}�1�(_�$�ހ ӵ^�����I�/K��Q����G)H�q��+��:Z1���Hw���X&̥��vu�<�;�!.�(��=3���l��1���-�"{���l��\a�y������7K@�*T�Ͱ?���js	�M��]Cob�|.��^Ube��L[H\삶R+�����Vx�� b֌���~�H`*��}��"js�S���o�h&��P9��6v��S?����z��a[�Sq�|g�i̔)�?�`�iNp��E�6�ۑ�ȝ(n5�r�H�S4k�S�2���s���9�w1g������D��u�M �0Ʋ'���$��{��C�Xȓ�S���_+���ep�Ge����YZ�����ӽ;�$�5�%=��~ŀ�Y�;��e�i�%�Ǆ�4�_�+ηc�`;�����r"ɷ v+�LWHT���جďm%�̭]M<��r#9ȭ�z<8��P�䉷O���.w��%PEe��H'�ʞAW���R_�;�:�j��������8������3�Lϩ7�5��,�Ц :6�uW�%Q8뇬+�)Ҝ=��<r�����p�D��/2'ʃL���=���(8���g\B�[�TX+6�gυ����X���H�B5��&�8e�id4m��YJ)RG��a隟����d��p��
.�B���ɦBu���㣼��*���?�����ts?���v��'���gX����Z���߽�Gt���ւ�.u,w2�IS���R:��gB�{���Z��@i2,]�V��*�{�Y��y�ѽ��I_{p��^��pMuZ>�����6(ڠ�n��r"L�U�C���T��T�"ځ���@cn����3%�R��׬O,r����7'�4tSs߱/MC��ł������A
�7�'aO=q�DRf`��v�W�D�I� �������T`&o
����gXU@=��4�9�,*@M-�8	���~��e�z���o����ۜ��w�HXq0��|� ��YE�?�:h!Ǜ��%��C��2hn�)T1Oe��C_u�D��P߭�~Ϗ��
ʬ�؏*	z�2>�.��p�{S���P9,z���H�dP5�L;���0l1����E�d�)������J�7X���-�v��Fg��-��H,8)�_A���Q'i�&9����n�t���w�1zά�X?��Z�`P�I�AA]��R�nP���ΌR�M���r��c�P�� a%�U�v.4�'�{sr���j$�DI��7�r�-�U�_��X�X��?4��2Nny�e�Ѳ(�e�Mm]:Z�U�q��њ���L_����h��B��w]X+�h�2_�� ���!�;��I���C��<��+�w�B� =Pmڠ؊�����卩���=�]��Ex�t���^��V�)�FT�c��'�࡞�x굏شğ�胊[����V`v>n~��Ƌ@L+��egA������]DE9eʨr8|��mUMl��e<���h�,� �2�ٝ3��/	|�ZVv~%���7'��zH�Ss�ɤ�!�I��گ'ڦ��a�zx�T>�
Px��J��I�}�kmXicjC����U��.�^��()/(^PTB�6���2w�Ց)lq��������R:��=�(�e�'`Ez/��acaN����5�[_텪���ϸd��N�LW�O�zV�nʨh}L�j�?�L͉�?P�O�s��v��ɹ�8g�5S�5ܔ�Mѝ{4%�dk��7`�v�#��П/��e�v��
��e¦�n��݄�0%u�\_>���|L����Ŵ~EO�,Z��]��U&*2�
.��
Ha˓r�5SH���˵�i"�:�� Q}� ��<R��w��6�IR����+�h�|4:G�-��m:ފk,�*�y/�48�mE V? �j	��g5�!�H1�?ntxi�~�<,P�6���̜I�3�a�J�W䨉z�/���HWj��\y
64Gz?�B����?��&͂�b�Բ"���p؜���c��-n|\A��>}����ߋz��g �_���'�#/M�U�UT	��x7�׊Ǫ �*SO��J]�3�yA�뼴l��B.�
W$!h�0.��K���A?Y
�` |�|���VPX��]Ƌ�@�?5o�Z]��,����:'(Q�Ѝ��܀[!�2�\sb<]Ye	 CfrIb�D��z�x;v�_�_�2JsP�#��Zo�(J�awg^�bRǺ��#����x*���X���
��;�V��]LT-{���(kl]�"�MF�L���0יX�XP,1D��kW��}�֥��K�f5�:��χ��3�t�2�V����uV*3n�%-�H]_-��j��0 ���y0�����]nr�-Ab�T�ܦtu3�ab�Tgw�̛���h�9�hPZ�+B��A��?M����*�
g�f��i|V9egC���VV��
�.��T�e�et�İ��OJ%Z�F�}֢	w'8����p�^�ۉcg�K��nU�d:S�(ށ��-����K���4B9�rP���^ՠfO���-��<'g�+���Ǻ�#��>4�h`1ưp3���桓�}��}q�`ܑ�>�s�q#V6,pV�&��{�H#V\(�v�J�W����{��t �e�H,{;�Hg��l���F��!���І�f��F�i�=���9��<�~[&�:�j�m�:e�Ӧ�M2{�卒�)��)�����`�%"��R��V�R����{=8���8�`P�
/}�G0]��h�:!l�-0�C�H��I��?���\$��lW8�@�p|��%ʔ��9�.���Xm�"u�Wd��@Ju^��P|�3O�-7<�ܳ(R?���-�CNi �ۋ�<��;���Y�`�|6^)���*!7��,?a��%yJ?�E���L)R��7H�Q�Ñxjv�����'�Ex�3|I[$�W�\�I[l5��3��x�o&�����Q.ɃZ�Y��S��C����s�9�����ke�]�Ā'�{�[�i�/���O�3-y255WY"�{�b:��9)�f�����{��Μ��Cv��8u�PgE���G݉~��Y[�2UH�.n��U��r�~L�W2	t~`堖hE#��J�vz`2]wv:L�&���g�ʰ�s�K��I=�<�<�x�x��A���EMX��2��+����3m�}2}s�=1ٯ��ȃ�6�R�a��7��dk˱��N@��T�
%SP�=���@���4}�&6y�?F�q�k�lKa�p�K�ѓ	F���z<<͢�#�X!*�e��yէ��F��FZ.�l�y�;�lg~o���T�	Ƅ�1P%����Jz(O�/��L����bx�����b�z�k���V�o��A�_�-�򗠭R���ܛ�s��Q�d�[��XP����aZ&����\�yN���@�D��廭�a��l�E�˕.-[,KT�b/�8O;}V�V&>��Rz�W�䜸�Pk,WzKH���mǃV.\��K�c([�;SF��c�

G��.�Q�X�o��h��0���ҽ˭�������J��5����#jt\O�d�C,��]����[�2VON�$:s	v��c��t(�{1���uo�����x�@R�`ޟ�[*j&"���E�������j    �UH�{Qu :�!N���%��9;�i�NV�e7�u5'$��S�`㆓�!GmV�(����=R�k>3�rKz*㙁���/f�Ѽo.n^|w���W�?;���:��9����d�M<,���0��D���+��^��:��B����I���6U�iqObL��M0MC��q����X��D��1�>OG��U���J͞i��U���ə܊���kinI����y6b�%Q/��n۲��<��(
@�(�E�A��E;�`���6_ � (�j����mHf�P���/�kOm�y��G�'���$Sw�7e�0$����Q�p�^�MU]���5���lL1�ߍW����hr�*3��~��`E���
Y�*?lյY$,��U�G�J�d]=�65��N�Fw
�z�.���I��������w~!���d�\bߐ���̎w�=��B'��2��N���v@p�J�"	����Ja�4�|���Ɖ�~�W��� �91��J-fo����c�b?��Է*.�ZlV)�]�Mj�	�9>֒B�ѫ^�.��YP�Aiz~$R;p�7l��U~���.iN�%�W������&�
0�8T��tB�}�>{����S�>f����i޷�t�@���Y���[�y�w���Te��U��W/���^���8�ia2�P��3�U0�$�����]u�6�����#�pv>m���ib|v���%�+J�V�*���+�iW�r�-�f�n��+�u��U��<�Ԡ�9�J@In�b���{/)����ȹo�p�`���t�M�	(�m#� 9?eE�6�*,s#u�&ϭ��	�Rtw�7)�`m"0�G�����q*`���yP$��h`g�EY3�;&u��3P8�C&s*P�a2#���KP��*掀���:�P���ׄf��9s�Sz_����?��a7�×4��g���)�kO�@��gҁ�ɭ�)��H9�
Z����\m���I����F��i�\K���-]���)aÙbЧ�2�q��M1��j곚�&��O޿ay�P�_}r���ty���9��`�<{�[RV���O%! ���-��7�s����BsP�-����m�D5v7s��ٚESvU}�K㧣�m�eǩ��cU���Uw.�3ʤ5_t�Zx�/����dEw4SN�&<�8��8Px5ǒ�6*���]:P�'̎Xq[���M�\��Q*�Ժ݅<�qH������D��R	O<h���X���ÿ�
ө��#Q7Rѻ�"}J��<��3���j��:�1*�+'Q����]�9cE^_t�Õ�(O�N�q1�9�԰��h����L�d<LHS��`f��Y�T'o�\1�|���=��̌���J
�7������e�
6�0kqM��W�}/m_K�hS�j��Ui��Ը\����P!�������zzq�=�>zk,epYf+��{-e)��Uߍ~N �`�|�^��`5�T3W-�L��:��~���r���dLSh�����R[��qر�Ie�L^�	�>�*�����L��ၐ����Fi��1�fa���P.?���	��9 ڜ�P�V;�XS�^ւ��ݺ^����<%���&������c�yq ������DC,�)'3O)��fv�~�J�Ϋw;
R3�`���s��B�q#������婤,SP�S�����g�5���Ô�0�F\��^0CC���t��L�ǆ�@1����N8U��<��bcBFz:QZ�m�Օ!����é!�+аJFK��+�ՊWd�0��x+���'����!�O���'6͇]�[�>����1{_CR�����Y�+C�PK�4�������w��q�昳^3X�aN�]�J4o\H1�ݥ�Z>��p�og6��<ʎ~�؏t���M�t��)Ў�m�����\K�]đ�m,�o
sK�ɳ��k����{o��c���f����ԯ��Y�ii$[�0������P�S��Ҵ�!�K��V�Sv��cJEl-M���!\�����wv���O��'OqK�W���xp�㋪f(9��*Gm`���ؤe2�j�ˊ����!LY;� TD����n:6dh�qZ���M	J�v�����i�"B���.XU!��6���V��w����*k�mԲҮ��g#p�K`}G��e���ҁ.��&�h�{y�1�����<�S���X
��z2��%�4� 5�^'!�?���#-s./`���1@��N�QWT�?0{(��0��Rgs�}��V��/aK*�L�Vף�	��7���W�>4����N�H7&����@Ǔ�����E��O�OC�I���{���B:���� U��[-�Pw�?�i����� �)1�	�K��?�l�2�$ﵱ�
��.Z�~�i�4r2q��#gx�LF&X��P�e�|�n,�����z<�m�l���%q`��:R�v�C��l�`�3aɹ�o���+�H��C����:J�$L�vk>��O�I�h�{>ץI�9�Ƭ712c��v�c�s�i�X|�xA�j�gsE3H�K�9���^�����q�0�N�4�u�|���,��M�A)�S�;&����)�*!�4�H��YW�ԐVlq�i��X`��nL�7�%I�σ����V1�gG����JȆ|;.q ��M��4C���jf!bgG
�#ryw~9v�H����%{�MK���7-Ձ7e��ծf<�4���^j��f��v/�s�$/LQ�B�F�����������0�uH�+�.wz���3.+��v������.�8#f�����G�MxEʢ-Y���L���t��s�[��|NE/��'X[O'�2�3(��
����y�,ͼk�VL<��`z)�(J/���w�]�#kg�lfP-$t��Qy��@�O�/1��l>+���`À@T�M�4`)/Tlw2M]�h,�k�K*��i��~n$ϸ����p>�l+@G�Yi�?�\ bᰩ���t2 yzZ�AS ��e�4��k�mS:=S�9��4C�pY���3X�`��,ޮp_�]�v2���f/�G$|��i�Jm{���<��J���1�s�C�	�G-/G��W:��c$#�\6��>	
��o9z&�Y�/u;ur�F9	�B-^��M�;%g,M�<��*Sg���#�\<Έ|����ʲ8��ls"��^¬������Q>��ܧ��v����"�M���<o�,�B3�g��HVW���\��o����^ғ��ūF�*a���6T0�u�A�c�B�ט�u��u�a��H�^ɹ	�9�1~"��g6:���m�<C<�� �ƛ&OU�ӃY�[�\��b�W��p��Z����������'D��Ѽ��;(�΁u�!|��E^��O�?q�D�?��\��H7�x�H��z�-���0��;�_�sYSK3�f��7֪�A�e�o6��̘�FDF���xXb7R�)Qh��f ��i4��k�kA�?���i7Wh$�O$������<jr���R`m�. 4�?r�5�e����d��gD��x:�j� ���Y��7͠�yB��z�q�KM|�����T�tuN�N���m�.3����>�`�/@ˠ�0M?wc��x�˱<C1���\��}���|cng3IKt����RP_k���r��gd��]���e��OKq��Da�mQ��2�n���o��OR�\�c��}=#%��Bw:��S��P���-=-�Ls�EB��X���#t�}̩ԛ�N�ιoomY�W�v�}nP	S���
�F�|����I |�Oč���#�퓧�t|�9��,�h�� �I\��k��IN�����!1�e[���d�U���9+��Y����ӗ%�� '�(�|�D"�����*@`w�������z?��=!�ꌳ.ɔ}j�x�M(54�4�+d{�ˬ�5b<���i
�>p���C�ݑq��h��������<Q�ivf����o-N�� �w�`�ˌzF3�,:����6y,FӗO�M#)
�sl4� ~�J���Jח��YEٓ�{%����.Eۊl��xI-�ޱ���;�K�T�����*�4�Um�+g:ºҖ.�3��ӵ¾�g���o�꽲D�AXV{�4w�Y¼z �  �,ȾVαO%�
i<�e��[�Uf6�2wo�D�=��J���`��+��D}w�,zP߭5�陪�<�i����:����$~=��@Fʾ��2+8=�Vj���"��2qc����\�$�ɁuQv6e��1!�ٹ_uo��xY�׳����߸ce��lh�d/�ߞq�i����.I4�..IX�a��Ү�/��wp���ɛ4*A��y�7���㼽�y������o>�	n����)�P>��蜒*�G	ʂ�t����Ԥr�w)�0Ne�l��0��	-���H�Mٳ�NŁD�e�Ʈ����E$X��#S\��&c&� +3,�[��\�Y5���F��C՘��T���,���]w�y�7X�Q��(<"<h�4��)^�Oө�V��zW���wbJ��H��7��򇍃@fz����=:��՚��i�}P�Z<g��$R���چ{�5R]���3������TUbE���T��op����̔'�t,����Қ�{t(8Ͱ6LU��{�{*�<�Tf�ᡥIn����K��:5��ޝE�X��^Y�}�l���H�<fܒC 3�Ӱ�	�0��.Zn|y3`�7�������Wu��0���:��ӰV��,����)7-�
W�G#N�ss�ө���v
�>�M"�q?P~���^��4`O��U�@�}I�֗}�n��ú0�G$MO�?Ŕ=��Q�ɷz�y��>`5^���Tc��N_K2�wcϨr��	��Kj����Ax���FW�vI���^zF7P�tO�*)N/���>���^�y�`V��T�9}��=�-XS4xtIi\_��_P�����P�>�n��v�_�O�./ǃ��!��(~.3���ф�>�e"�h�]�y\�[Hn�$�cU��Q+C������hDeկnayk�9���c5o�/����Y��������a,�ф��k��{j"�1��9ط�;��xU�#�r{jl���B�;��Z��R�!BGL^I�tF�ǟ�Sc��xC���P��/gD:xTB���z�ϔg�̤[,�W2���sDA�pV���.+L����{���͂���fj'�Ee�j�L@gV;�c��d�j��F��)�B��O�S�#n"���v��������+�"�I�
�e5+���,��5�8
%.���j��^W��cӲ�1�Px�;題
k�)�c�k3��w��p��;����]`��w�O9����?��{�%(	6e��RO�������c-L'9�)PȜpwTȂF�7_Y�E+c)e�-vz�B6e�"ff=�2[�TS������ c���z$�#.�l�6����K{�7OL�7*��!��3bi1�Q�z��q�`�?���#-����Vs��cr��oL\_Fd��D�Rt��lT�K����q2��c�ytU�A?ҳ��[S��%�o��P-U�X�/*!�g4�}sF^&0g�s�_������R�ݛ=&�k���fd{k��/�ǸDTO�������]�$>(q�[�u��T:3�B)0Ww�{�'ǣ�{'��������Q8�����O죟
�U�Z)��h6�KR��Iw!�ۈ�w:a��늇���u��[}:]�8�=�w/+"�]��Uo�����,�&�q�?ku&T��Eˊs�P�$�)z�7�[Gܪ|��A���L�1*�&rh�m_��¼x���L6��޸7T�h%�h����BJ��*/l�%��t��BKS�:��7�kFjn��\�KT��!�jV��P�*��M':]��u�ʸ	g�S��Κ*l��y�W��eU�MX�S�e-�\Uw�d0�y�=!j��E���p��d9D�w�f�(h��D��5ɋ3�A�׭M�w|o�|2��%�/�*X�R�]�.�eEFj�Y�l
po�DC
�����]�--{9���j��wI�I�Xy��Ԍ�V+��
��/U��io�m��0%C�E�b7��<��vG-���7 D��A+v�^�7ǭh������4�������-+��@��:U�����G{��ίsm�Ǽ2^y��┿��fi�O�Z睇�����y��cF
0�%߭�I;L&�Y�d�'�������M�4���k�O,w����F0����眤وB��_���9,".Nh�#� ~���#B���������p^	U�7�Io��1?^P���Ǣ(��.�3#yo��B��\�NF��ei�i�{r���������z�9�zA��)�F���].�1GhP��j�z����[}"fï� #5������'�� �ӱ�w�| �����A�w}'��D�`[����b^�������kt4�� (+�.;-_G��)��Td�{c}�]����{On�~�K]�M$lb1s��9Lk�ʆ�]��6i����G"�g��WP65�#��S�m)��<i:�1u<8��ˑݣ���'�>���2��%�k,-��L�ou���[Ǆ~�&�z6M�ת@�Xj�T��867�3�OQ���r��7��0�\�F6���T�B���k���������� Wܒ?�ar�ƽ� x=����9�of�D=�wpl��QUHץ�����?�f4:墦Kj���|�?�n�fb�`��-q�9x�:OB8�[3�㈰�l]L���zX��4��d�F^lbR*�����'N�^���Zpù������
%�9����a�0E���vu'��p�Sزx�%a)�鹳�{�y+2t��F��Ņv0��.6���aM�\-La�i�/�Gײ����q��w� �������� F�@ou�}��uG!��G��\�)��:ˉ?���~&;IG/��Xj����7��!d�e��/�'�my_-��� ��P�u˯�;� ���w�gw/�8ᦧ5���2й	���/At���!�I��
�b�c�o`�vv}�)����ߩ��"X� �<�Z�,����]7 �_��ݽ�Ձ;g,���ESB�����L&`;�h�G��ڹ���k�d�Vy�M�.��������(;X�����	�W8��t��T�F�
n{�J]�O+ǣ�XE΀�X�I:FSE��F+m�� F��HeB�w7ya$�����߉�;-!=OM��.�ݨ�k|X�3�d{J����wQn���P�����O/��ۄ���w~�~֔�:�{��{���l~�'��^����"�ۇKgt4�5У���t�Jya@�m��,)�������KE�w�U>�I�w@���Z�����9Ӭv�G?��rt����u�H�43V�y��f��a�O���������|��+��.�3n�j�e1=�۲�}��zx����U�ɭN��7�΍�XL�+]%�ؠ�D��fC_��h�~I��X��ə�:ӹW��ϴ�
���V���YXKc���pI۱�M�;���;�Q��{T�/RI�L��˰�5o��;�����J,�XR��v>�`�6:�˄|�(� ���v�Nz%7M�.�'7e^��B�V�ʶ��M�(ݴ#_;x��83��C��]K�Q�Nҥ��e��<��Q<V;~��H�5^�V�"��a���ͽ6��S�=�7�����x����F�+�E���yzҀ7R��橱�WԖū�V�N�g��RR���o����ı�(C����fM�"�������/��ݰ��˓��;7F��5WB�lk�t)L͸X�Y����dZ�hN�~#04�Z�2��Byj�!��y�Σ�c�&[��o�,/"�竈�u֫r}̕[w}<;��u�%8�Y�I��}P����۰D���k�¨'�}M�=l,�<��Ê1�.&-��wH�҆�u�ܟ]�VyWd}N9B��.��z&�����#\�Q���|N(�N�Me�6��bw+�R4�ɶ�sWz�:9���Xc�\���Xw����qI�B-�T�q�+���3�|??�&�?����@      `      x�ս�r��.���)�c�ұ�k�kDI�&Yҕ6�@D"S'I�6���m���:�=���p�km֬�,I1=��>���_ߞ��M�_�}�|f���s�e�O~S��'���7��k����C���}ҵ����3��>Yvb!�g-����zT�j�G�����i�����������~K��'G�U��Ӷ��#��M���<v�(���W���������g�w�0�,6����V�{����ީG��]_%���j�,frS��=ݢ��9�K<�J�u�,7���y9�^)4gVB�?<���I��.ea2z�ݹx}/���6(d�n཭{s�{]Q���˝�.���}|¯�Nt���Q[���
Y0~�ݹ���崖�f���]��Q��;�����0E0��~8�]3��q"*��$6�6����w� ϣѫ�S�
�Ϊ^�����YR�aTx^\��;+~Ya�\{�ܼ��a�j�q,ֵh��9�g��
�<�B{g�K��u'�*)�����7{7g������݅�{{[k�̕�w�,T�4G�}�.(qw���v��ms�Δ��|�.�;���Y�w�EѸx9��%�K���@̥����]��x��EQ��������٦]5�a1(�Nb�~������6�lǏ�'����Z8�n���F_��\{��|��V4�͏�cb6��X�q�Ë�J�Nڦia��m;?��^�Y���g��80���R�Z�To����{�(K�5��dw!�!ފͰ��t'jP[�}��a����t�#����-��ּZ+*�/�r��?&�''��^�?���~�\�{����������q
�j��-6����WKƗ�i�ij4祪�����i��������Be2~������.�l;�f�}���^�
��&���ݹ�"%����#���k�]'{g�e��������w���5��ȳ���+��t-�5�կ�3я/�����@1n���+%��ҧj�O�����E��{��Z�C�s�e���J>��F�&�x��;�2}�����
s��q⿘=n�V_�?^���g}��7_'W������N�����n�n���:��}�"�>\a��:����q9��Y'�;N�m�=�I7_�r��x�������D��NuW�������d���6G~#��/3w�������m[�����k�x��t���46�囜�n��u"֪��j�s<���"}M/'��h���o�|���z}�4whv��k��tމ9��~Ц��l�лO""�؝뮁�e�׿A�[�=���ɴ��W�`7ڶ=KQ/�7ޫ���U�]s񏵶�p�]��B�¼���NuW���P��N�E���O>��+�ܻ_?��z��"���؛ kt�V5��_�f�֪��'��wU&Q1��{g�J�%�x#e���F>Ç�:}�{b���C{�}�h[��d7�w	�mS���?����v����<���ԛS9�.6��K���Ο;��s'�
q�7Z�\���i�R�}�}Ēx��L��G)m�۶�u)AԢ�~�Y4��Vza��+ѷ(��ڢU
"���c�R�ǵ����:F�ߩ�`��n�qYl6���y:~w*�/���ў|v6�z4G�J���Tw��ߊ�[m�5�?�/��뉽�ݕ�t6��:�|j11'�O>���qy�tw���0C�o��:wg޸-#2&{g��Ȩګ�dl@�v�E�=3�v|=��l��K����h�㾩����ɗ��EP�u�Q���]��p�_	D�tw��8�B�L��F~�d�Ū�?x�����ݥ�{1�o;�T3��6�w&������N���凌�v�twU��P�Q���A�Q�j���x3%�����2F7\����8�+�zh-��D�۝�.b���e#�
ޱ�-�n5�c��������BF;�萳�!tz'��Z!�U���!���ٯ�c)!��!��Eɍ���O��=��se{g�m�Շ��ɐS5�m"�a����Yy9�^#	�����\kg�"W˙�M���#2�~�I����_�w�M�`xc��J����T'?��/�NӺ����J��K��~^Nv��A��W����m:�k��7R)�q�w����U������m;��,�9��`|w��uW1���,9t���]��1��x�ŝ� ���b��\j=)�'�m=<�`�^N~3���lWC����A5����dw}��^ҥ�0���]k��j�LJ����(�]TGg���aӮg�t\���%����dw�&��x2lj��л3�ٝk/�=,���E�L=*9�C�O@��ݹ6�i�����NZ����薕9��}�h��w��jjaV�$-�P�1�M��/'ﲊ���_�������jZs��~��t�?�o����qw��m��X�;�^�,�wf��}�s���8��{7�wYO�xhfh���%�/�?g#�2o�l:&�� �.��^٩xB���]rr������W�>�8տ}���b�c����@/�������z�zǍi�Y��?U��de�O�w'�S��Q-	Yi�R�	ܟw�S��QAi�[��ܪ��	��ϱ�$�����9'˳<쀗���_����s��$%��O䛨lD�=��X^i�z�"�����oz�R�!�����}�4N��(��T��^D�%����')(����`�-���O�;1�d����Ȓ��i$���¿��zm��9QF^��8���TO�.��ִ'$�輑�L�WL��%��(r�"):�
���1y	���w��e�ޣ	���%$�h��g4��R�=ص���|�WhzR�ϵ������o���%�����\�%�3+���(��8a�mBj3B��t6�N��R��kW~�,�K&y�C���A���dDL�N����v���N�XS��D�7&�����Fa!�G��S�1���혙�q�Xfq�6ϊxS:���w��n�y�,�c��������E��h����T_a�cFo
S�bgF?�ﵣT��+Zs�~g)7���]�%��Կ�s��?������&vQ��L�������k?GW*Z4�����P�(�����4?n6Zon�bC|�ت
�!��F�KWy<��E��;�u�Il:�Y �,f�A�����PkLK�>bI�c��Aa�I���]�C��,�ɩ�|����rr`H���g�T�8Pj��8�N*�����vA��y�4�n���Z5
�����[�gr'`����y%jAEy�Q)�X��t���
�C��GgT������"�e���S��|L	i���
�I��_U��K�/���y2u:}�c�I�@bc�u���2��a�h���+�7�!ʃ ����k�i7�,��WWBD�'f1o�"t���/\��ie����A+b�E{�V	�������$�n��l�i�	�Q�¯;���U�5d�.*K�� �ֺ��J�@z�f���6Kȭ(A	
"�Ziּ��NNA{���LA��x����mH���G^ސ�x�bf���-t��! K����_���y�V�Z5��A�E�QN�X�vWZ�V|��v$�h��0(n�%i�����F��nj�ʦ���W2i�₥]+}��J�}JV�
҃Ԟ�َ�6��*J�o�����(/�I�fw~� �q����ϰ�N�/����DTo\����F�mk�2`�EA1^��'�쒏�\`���͌�gq�ta�7&�����H��B�o['��E���fc�U�;��{C���Vg�lh�Ƨv�=ކ��3�*hef�Zo4���K5#7F��s�Ȋ�s�:��M>��;�u@ہ^�z'�;%�1#%��z>V4�W-�%c�0�[-�ߠe��͟P�&۬����,v)L�+�,�:FFW�x[�$���O�'����V��@�ƗV��`�Mh��Bk��8a)�D�6<����>?S�X�،}�2Ľ�ڗ�ѷ�1�0F7a������OԱ����X6�����K��=F���n��8k��VP�'LYu(    ���a�O��g�'��a��C����w�cV0�bk���P63
F���DA���j��	��ַ=a��@>z�����b���@�[�m]��@%"ӂ3�� ]+U-q�I�֙��|rcf[ &|#���S�S!m06��C#��9����bZ}���I�mK���^`�:�����՛`֩S��Ԅت��>�-�kW\��"�y6���P���s}�c߲,�����a�v�ă$Wo�Ĕ�^���0��Q�4�_����4p_���ur-eX�;�۰'7�v���9���[+źߞM(�7��|O��0PAsX"A���?���ɇ����� `2ta��*.w
��$4�ɛɴ#Mb���q ��S�ʵ���&���9��@��66b�\���"}�G7���a�K�J��b��B�k��OT�cw;�����N
��!UTP�7��>�̝��+�e���i3؞�+�P�~���Ҩ��N�4������FSe��ƺn=��i���^xb՚dEqKp�S���{R�;��H�!��ݓ�������'����+��MP[m��#A$�� �?��6 ���7d�C�/?
ÿP���lV:n�RZ�������w�\b>f4����e��q�6O[^��� ̑
e�l�W�g���\�)r��4(�fX���#,

�n�,5@�/m����W�br;�>�q��e���MJ|w�j-)�7͙��_c6*>�3�ؘ�:`�_��Zu|���Q�H�y��]�����&b_���jI^术P�~���<�R|�~��!�د��3xng]Ci�8@���Ra=������g@ ��k�|ݒ�{IkX`� ^�Y?M���m���B���*��m�'���0C@���~�-Z�f�R�����}���4�������*�L��l&@���}bS0&7DAV��/<6��уdq`ӧ�|��vg�A!R>��B��ا��$��0�`��ߦ������#�!��7[4��C�P���L�=���N��l#�Xl���%�\V��4dX�[����`Ud�6Y��	# �ow>��k���XQs�ՍD ����_��d�N���� ��j��E���Q��+��5f�:�X�An���]����i���Fr=���X[
KH3*��3d��LE�M_ml��x�x���������v�k��mz9��s����iZ2�/�^��WBئ�v��HP^�0�Q�B�agk�p����J*���d����59b��l�����I��T�V�bB��i Y�F��Z,&�Dg`����2���kS�a��vؐ5ρ�&�R��?xWkr=��3UR����+xjV��|V�2R�}z/=�e�h�Gٴ4,�t8D!�6[	�8OĽ����Tܣ0O��_�?{���{�B������|�-�/������N:җm.B,ا]�J�\w�GV�$������Yُ%�.�(gv������1�����I��Y��OI�=��TՇ�K��|��*	n����s�L��T��2����`���/!������׶@H��mc���Ih�m ��S[g�.�$K�لC���q�4T�����_T�Ji�%_�O�[Tܪ6BˊΈ�?Ԋb�'���1$��&ܽ���~m��#D]\$�
����_�i��>A��x�]R+W��	L��Y��r���چL�F\
.J���RZ_����?�Z�j[C{��2�׬D?��o�薟4��,���U�h����=�v( ���sZJ��70� ֻ^SyE.�"f\@�?�xl	�Go*��;4[����ԩ�|3�-�����7��Sj�]�eY�G�(�� ?�pk�FPl�1E� �7����2�; �o��<-�P�hZ���K�۷��{�	�<(7�0�k>g:2# �oۊ�ԡ����2{�^*XysM+�k`� $?�m�-�@��8�`�o���	[9F#@��d'wD�^q\���p�ٵ��uO�߄���2�T�j�8��Kbm-��hGο5�����Ӗ�J�\�������#Ior�k:}��v�+Ҥqݓ Ӯ�c�h5�|�P��|0� #q�� ˙\ �О���[�Dיi����1��Q���UKaa��g�/�5Z!�ǿ����lq�D�9�q-�jr����6�W�$� &��Zz=����
d�p ��蕯&wC����#��-���\�9G���o/RFOA��(`T���7�z��#e�#�s$�S�֎˅�h(�8Km����/ϔ�]�z��E�J�,B4Uϗ�Z4onں����B�xW�k^a4}�HfaXKb�A�J�%3E�/������i5��(�3.�	��H��ڮ�ښ�
�R<�rۍ|���a7$`�b�C^[kP�kLv��� ����Fd���P�1�c�a1���Z6
ʴ�Ӟ���:��BQ�q���ɼ۾<�2�a���*(:pDt�ퟤ�B�z�O�C�=_�h��g�B�K�n���t��2Ʃ�:�k���*_~)A�F��20��Ṽ\H5�G�To�j��P_p[u�Ѣ5����m\�7�O��e���&�>�z��>�#�G�Wn��Y[�_T;��w����,]�瑔�Ӣ1�ۗ�ZO0k�Iu���G�m�m��OC���~[�T��ui)DGOd����Ŵ���闄[�q��R����X��N3[h�N� V���g3Y��N�ClXz _�B�ײ6N̕��d��o�c��w�d���ۻ��;�?�C?oK&�S�c�
�TصI\YX�IR	�(��9|������<���c3qh{mɈ
B� 4���R.��QBY1�dqhӿ�E�+A����@�q^Ь]�
�Ь����j�&x���8B�(��mj�xԼd������ȴ�x�?s�Þ8�v��W�I�2�E���9�J,鞃"e������0� /F'��I2[��+�}�J&SB|2l�`�<$��Bƃ�!�4��������coSف�{�(G���۟k�{�����q]b�]��s�Y�ǭ�j������ƈ띺V����Gu�d��vl*�]ێ*�{��|��
������ʎm�2�3V� g_�T��݋��;Ɔ�n�TZ�UH��ǁ��~��v�B�0`@����`
8���j�T��0��q�u����rIʊK0FNt��+�d'�����=����]�y��KE�j��K����!�b�# V��4�YJ��6��w� &t��A��v�֮'�P�/;��$.��x���XY|�S=4+I��)�m!�|�6\;�F-�ɒҔa�q��4]�f��</RNk{_^I̎��|���S������$�P6�3�ZmH�E���0�|���m�4&VN�����`�4?#`�m��L~3��У�7�Q%Ty_��Qg�5کI��m+��$��1�{	)�=�`ی2�/���P�+�j����ѐ��2��aҘ�F�Tz)L�<�S���8��mW�ثttk�͍�р��(�F:��M'�6G9���pe�΀֕Z��L�Q �U=�������/�ܼ{��޵]Ӓ���)��}[��HY~SӃ�:��"�|c1���C<��ǋcz��3�zʸІnt�
h����6c�q��u%.s�mgtgƔŀ�Z:�soO�
�H��Q?���q�`�S�(��:j���Թ���&�I2q�ĬnT�2Ôj�{�v���]�����h� T�6�m���-�����oɖ�3���p��_D�m�e)S�ȟ��]W�I�D��3%�1���ZYF�[��N{�$2{ �K�s�����|��*���R�6���뉶�â�=:�8��$`Ĵ^Wn3�k 	܃��
ܮY�\l���~Ԋ1mT1�O7�o��g6�@������"e*��R'���;���p��L�F������F��Kd"8 u_:��vKҷ��D/\�����F7����G5{������lz�C�"��?L��և� Y�!6q��<�}粛�=.�f    �N�+�P��',eh�ch��ZBr��%��`�Sm^,݈��E����ي%z�Z��E67�"�l��}(rȲ}�b�%�_�0�' �kQ����x����I���L���S9G)_JL���<76y���p<r_&��\�fiq���O� ��Vl�� i�� �Ǐˉc��$@կ����ځ�Jfr" �/a*'��&��ߵ3�H~C� �����r�y�q�-D����f2����6�f�K �?�>�_Z�0M�	@�.��HKCf|%@�ӵCv�HD+)���!��a��?Ad]�H���Q#U]OLDH$+��	 �;n��#��0�=y��h� �c�Gc0� u�fo՚�L��C'��3��ʵu�d3�N�B:E�_`��$�1�ڏ��!��N޶d�@T?�T��C��X#�`� �[�y��=�n�����qYe\f��F~< ������3�F�C��$Y�'xI~4<`��c��IJ��'�!���V���0MI��@>&��i% �_��YkG��Tj9,~�0����WC�}-y�8�T����yn�����Z_�����.�JHS<1���Q͉7��Z(��F����M�;��vh�-Ŗ�FL$� ����w�����Mt���4��&���[�84���I�5�j�'��8��C|��+�	�����h	ct a�=���DG��VCG-�4�� �_vǕ�F��Zd��z�F�;fw�_|5��xH�No�o��^Q\�q�cS�'IQh�E�P�$���٭i4'Yy��~,�غ��SrA�y".l�ڔ�|��RG��)��sI�C/.��&�k%)�<c�����;9�,2�֯%t��7���&��m"I���&�|�B�\�=E"*�ӫ$�B�ZR��.��)�)�R?�zM�?@����_|��8��2+6=�U�y�}�ҙ?��\��'�3�I�`��[��0�7�Ji��!K�Ä��F#5әZڙdw��)��(cҺ	�8\�za\�J\],�m�x ����`�|����2�2fY��z~�i���`�	����p Qp�y��>V;~2S7T,���� �.}�I}��ƜY�qw�iY��᳚�id�I=�ע�د���^^���y���9�ܧ�"�i#�e�iR�mUv��w�;�̢�Ӷi+j�Rc����H�n�!��m�)O`�y����߇��L�+u���F+2
��ܒ9�Y}m'���z_	7�:ɱ!wS8�RQ����%��B8|�W����5�-�U��7X�Y���˺�R��ē0x��
��ۅ�Vu��{2�'�hr~b��J�ҽ�n:��1\^t���I��D�ϵ탸��%��E�<`~���ՌT 9C?� 6+���B������i��IV��g�\%�9 ��jm�h��B�I	+�"���=��65a���&��A�Sdv�Z�h�'3����-l����ݰ��Ye	����n�T�~����1�s�����"��.)�m�� (�Vx���-���!��t��z!v�n�f�B
*�������KS����C��q�&��:�2����*�W���gR�V� r�"p�� �b�E~:ő�v��t�0z�$�ʸ�0i��9�%�����Y��ĬWh�� �@&:!�t?V�g�K�G�sq�8&N�?{���M�V�n�RO���O�>LQ-E���,m�p�(?Do��8Q~�)
�ߵ���y�̟�Km#������a�H×�@HcډR��1ϩ�sI"�,��쥎��Q�� ����rA����*Y�B�������"xE���R���7�W��j
8��QZ�j��1���=)t��|�;�ͨ�EQ�����K�3�M�cՕ�q�+��d���{�Rlw��3���c���pW
��U�P���H��^��ʀw��A5ܓ1M�)wA�m7��
g�(=K
��b#vU�~q�w��.܇+�}�!��3|&�B�����4M�*qo)G��"�;��$���D&L��x0�V��	J8��j���/ڮY��Q�`�ilGk��̀�V�?Q�b�~-��Y�gw���@�F�9��.�M�F�4V4�G��OS�(?Xǌ�̣Mc1�c�����������@Pj�����'b�ji��R����{�/�4�;ӅOy����)��g6�:D`�<�����1���@��a柃�&8��1��e���4�L��|hٿ�>���`�<��P�BA7/-�{Qܦ��_�
��x<f�#f��j�łD-A	��R�=��E%�^���1���F�_�8��UGw(
?�d�"i�-���J����6OtE����<��G�ݣr5��d��y :�s�/�a^�N<�4hLt
���~O����� ��l����ؒ�#��/������C�q�& �ۦ���@E�є.ۉPc�;
P�Oն�\o�j�_��w���l2`�7m��a���½q�������~S���0)q:�\�QS\0� �W��1���R��-�böDׯE�b4D6v ݍ�Z���VT�����&@���iK��=���.p\���U���B�8�w.�����P Z'/%uS	S���3:���"1J��
�|t:r��9& 
R.X�M�v�Y�(O%�M�x�>L���1�  Ớ�/�&gP�	�f���]�e���WQ,�h���bh]S@��d����Bh��5ϰft�x����x]
=��D+��(XG�.K�7�fr*'��U,�-���'���|�`�L�_Z ��c��V����{�6L^�^\��.0L�&�9i��P|�^��f0{�R̔e�-S��o�tÙE�	ӗs��w-E�1]��T����aϘ3�?)|Qu����eh"R������~a)�r���-�騈�d)\
٭�A���Ī.!'�����t�3��٩P]0}Ë�?\
���ip��5n[*]GqP
�P�}4�;��+������\�J��N��B?ez
�72�p�$�Am����ۣ�������fVڅ�6.;�q2�x�22@�ߊΚ�;m)�?�c��� ��C+�gq�0�V��G����W��j�V�"���cce/��������� ��=���h��L�p{!��7�]Ϫk������SV�ty�H:S�
�V> ��=ݣ�&��,	#3H_`���X�z�L�+H��z���?��f��5#upp����$?�aP����;��=	��o��d��~�C�}�2�!}���?��V�?�aǽ�����$�O�3��`����0��ʎ�d��>?�]<5c5*9�.\�0���������8`
W���m�8���o�� ��&VU'�/dl�E��~��x�ť��,���z�r�>R�V1=s��;v��%���W���2;������%�#q��|$b���:�l��jj�GMK��ƿ43�b�l}*�D\�~�mê}�;3����qљ��h�b�^[���R!Y��Ag �_s�t����}r�.ۺ�[�@%dݲ���L��`6��T�9� �BQ��*��If�4北�Ttg�OĲW�y�D>&�����Oj"Q�яm��E����[����eй�Il]�WV��'�ڿ\���J��e|$(E�6��7���{�l��>@)�{���a%��X�"JZ/A!�.un&G6�ͩ�z8j��~�?K�3G�����o�bE��EYɨ��h5"+��s�ǉ��
v<��JV�SR���x�	���s�9�H�n�v�j��v�BJ4����~Q�?���?����W[K(iE%��F���T���b]S��lA=��vY�+h������I���!]�Zs�E��F���#*�_�~Q�Z�
 
܍�����L25����6d\r�&�j���|ENz+�Xp����{E�;����?�� ��"���e��
[^�2t�a�m��"��B4�g��_Ʒ�ȉcQ����̵����@�nh���+@�w��[����T�z�0�#ζ��s�A� ?�y�ɺeL!M��Å�N����1F    ���l�^�GV�`&����;���Wu�>ZY�˾'��6%����60q�͂Φā���5Z���l�S>�5���O��M=?�4<a+�2Mv��oY �V��[#���Ǖ��<�qr�P�f ��4?�s��(+�:�^�58m���NoL�r��ɧ�"���?,,��k��2~�W�7��n4�"ϋ�܍�|�W����� ^�(غ.Q���w�d�l7��7�Ʋe2�@q�u�j�<�bf�`RJ�%� �,$�h�@�Ye��D������5c6k��dQ�'�t$+ђ��B��j _i&�%a���M��l��e�Z{q�P�u-Ѩm*(��!~]�5�:ELơ�,X�c�mHn��䲘 BO�F����iײk'���ͼ��o�4$���[��>��'&{[�'��%�`�Z,��\��x76���ԞF~-�9�����q_"?�w[5�E�p��H�k����,c��������em%'uĎ�Q��YL�XtT��ޚ�6����.O���b�������4Z?c�{�tl��1(�j]��m7lH�}m���'��z����lZ�]�=D�Y�Z��0.� y��y�Ȅy�P�����E;�����%��	�����[�����V��[�-�G�5p��A�5i�2��'8�Lm�d����W��p������lbx��p���!C����°Se��k�=W��|r@�tkÂor�P�����)���[�J����	���$2���I�]�
�Tp�0��@
y�|Is;&�\h�h�	ͱ���.s��/�II>��{24ϰ��8؀��6>Y��E�r�ի{�J��v�m�3����m�5�mW��m(q�l�<B^�	�q�dC�hbk��G�ޑ�y�I��7�O�M6�����8!�ߥ-���Hxa-#�jImc�Qۮ��������F���"�S=�ت����m=`��K-s���k�9y�MA9��R�?��X9r���$]�����T�h;0���5�����y��Z�Z-&�@�ob��n-�)�q��T�1��/�f����%3l:���W �ڐ�ޱ���5�$��9��	��q������>��I�1�����͘�`�>���
�qش&K�aB��R���eB�.&K�@/�-��tG�`)�
��;���z�ILBf�A��N?�bviY0�y9�����ӄ�:��\w7��9�2���z�� +�_�����R>��aO�D��z�lU>ia��)�r �wc�n7����ܓbVa��1�ę)怎�-�CsM�iJ�?O� �]�EF:&��.���'�;��;���6���Á9��/L��Bѳ���1� �����f��Beȑ�2^�Ԟ�3���������pݽF�8�����Z�#�2L�6>ź�j�j�)�#�S��)O�q�CQ'U�d&��!"c]�����yڤ2��y��?S3�f��گC�ؿ�3S!l����st�8]�. �i��Ic|���ۍ�ar�T]\갠�C�햄�s:7������&���G����'����/�a�%B�HԮ/�- ��`�fc�����y�u9�Rv�[�,��Wl�E�����Gu��(���ɫ�\L>�Dȱj&wH�<���j��[�[p9�q�s@���'q�L?O��ɕ�&_���%N��\f��������L�< Ўm��m�͵v��1%EI�X�F������`��Y�C��A���q{�;���\���7KtQ�m)��v�/�� Pl�i�$5\�>?j���}܉�����ʀ5�G��7��d�r��",ּ�T8�[?�lӑ�d�^Q �X��k������	���fy�m�H�Xv�vx��(�X�?�}4�0�=#�X��{g�)ٽ�6�V��b^2 h�C4v!zI�z_pq'`�0��~��@�K�E�6z�i���}R ����,��I�>��J��e�xwe,ZPsQ_�ɽZ �kFHcG+Ο1/�z1X�@0W ��2��GE�}��|��������s����ӨY$t��+4\B�ra٪�������fC����(��mN�l���X>��A�y�<f� �߉�?��5B��]�t��yELN0�9���ꕠR���`�_�����!��XP��Ũ@���|�B���OՂ�mQ�G!N|�Z>�%6@����o��츓*^
-.����@�6	��h?��EynX^�L|�2�{��ś��}�����A�u�}V0w<4$�{0���ݓJԶ9oZu�Ђ�ݗ��_�����i�Kv��I�fJ�a�lDl�{�._�vU�$1qZrkζw��VX���nI�+�[ufR4J[V�<��9� �y��@��KO���_�Eسg�lY�9�9Kw�EGEFQ��&D81�'�{�D�Kf|�T7ˉ�T: g����c��d�*g�V`{���^^IY�粅�9m\�ᧁf�?&[��0m�W���6���UZǋ��c`\��t��wbM�:��7􍡃��xǌ�����e���5�⍁-m]�Bk.2�d�72��:v��T�����cAY��=Xa!�7̞:��ܱܶթ���afZX��/0���<�E��n���fb>���,��_����K�P���}���V%Kd�j�dq{Z��r���j{��X=,��o
��x�F��WP@>*���B�K�TD�h��ys5h����ʰ���ȡ��"�s�-��n
��'�`oق��H1	��L�G�VN�/ڞr���V@�¥%�4�m�W5f�]��u�A�~8�د�p­-.�Ok0�F$�l�p"���ߩ���R?�B�����f��@���`oi��jĜ ����R��U���<�A�Ak��z%��� TSA�XZ�����V���dqQ��a

s���n��>&ҿ�*t�M�%-�5�,��$��Q�l�ΐ���N��	�[��k�@��n��+3B�vv��+�pd�8�g�J����u�/5�GC�Q��U�����Ӗ:���F����{���t�wӿ��{��x���〾N����NvJA+�W"bp������/�r�ݹ��Y�#�O*��!*�o���P`�f��0{��k�`Q�
p��S��á�26���ev�k@�c�Yjg�sd�G�����/!_¯�� �dQ�P�fa��Lo0�#�%	��Vi������yZ�~�`�}�;ւb��G"T�L����3T.����f��3�����7Z�C]�Q
@P�L�n�p��ם��cq�6�Z6���i�* D}�ֈ�M�jC� c��Ghe3�VҒ^��'_����7��J��._�|V�e�A���c�hq�о� ��F�+�x��/���ʶ��?���yr։��a�3``̓]�?���`ο�J�x��ۻ��W� ������-��5W0�^J�y/�\_�oT���K R�fV:���Y���J O��z��Yɏ8�ht�G��f� j�X޶���2��%@�ߜpa0�s�~��@O�tm?���L*��H���D*j}{�{�1@M���`9O�]��8���H=��v!�呩M���v�:
���>��X*�<�cP����r2U��V�)��\�8]��`y~ߢD��:R�J�B�����55�)���ł����R��8[��w��/#�%���]� ���׬��~?=G�������׶�]nߤ�(�>g��߆� -�^I�a	�V�I���laS���7W���d+Ű�n�5��Ǔ/��G֓cY��-qd��2c
Az#��%�\=ff�*,#��������L9~��|g)h=�G��P���̛�k�᳟�o6k�*��%�1c=��;��\e���9�s ܕcM������9~ <}�!핧����ޔI�xX���I/ ϑdӒ��8�Ko��23o���3Nd�.mM橜���dY(R�R$D��^�� ��B��H���S[5���:���ѡ�� s �  ��݈�Gcf��(˓�]jp�n�׵>@T�����ݨ~�=@T�5;ྙ�������K;���=.����"EF,�=:o�sUc�(��R[7�h��O����0�뻰�tV��h�X�o���m�WJ�\����创
h)}o)�7_TQ��E���-Rl��5(�1��3�|�6�O�����A�^D�l?.*H,*���0dt��wPG���ƁӋc�K��{�Ȑ�tX`�U�Êndk�Ź7��+.�9���8�ۅ��Bj$�Ѓ.ί��ɕwö_��y1�
�8?�9N�b�����y�o���6�����j���L)2$y�!��EexK�Gc
�
h)���,�,έ�~�B51m����a�@fyA��N�N���v��jDi��;��}�ܱ�x����-����]VX�a&�9:�g^�U")S�.�1f���o)$;O���x��l��7��XJ�(�%_ꬵ*�� �����ߑ:�)�ϑEno��IJk/�3�'aD"�(��I@�E� oMk3�����Nm6�R�k�;����WN�ZQ�}X0�] ��6�b���.qz)f������T�o��2� ��]E���򐷕����e�#�:���v�Q�^Y9
u�Ex >���'�#��2�ߘf4���l��w�֯�<��B�{<=���R��a2Z,���p��j�tC�*�0ӊ2:��T�_TJ�6t��-�3hq��{�[��E���i��LjqX"��C'��R�y��`���X��Ѣp�k�pr�5���p�8ȹ\�j�K��p���)0Z�َHhf�耒2� `-�>u���q�t$�-"+l�Z���6�N����C�O�FR�6a�D�8���f`{�����iy�����fx+jH4��g�S5�2�������c0�A�@�4���DZ��w�Rk���f.�h���
�?�e��wx�]m<��Ձv�������b��ʔ��Z��a?�N?䫴X Y�8���`Z�7di:�$���{ʗ�~~.-��J��b1����x,V�޹��<�Ov�b��d#쐄"?�i6�k��E3�|�$Q./�d��٩��b������� `6� �z�T�df�H�	2-9��V�:�� `F��广�!b�}B���ٌܬ�,��ݫ�FoNeO1+�A�
6[�^4¨���̉�G5s:�n�W�WzR\�"+ҪRߖ�(.�#��:��u�ų�m9���%)Oʂɼ�c�t^���s\X`ɤ}����������z�N�wh��[U[�}�?��J�<�ScMQ�(an<[�1��0�֟�a���e�'���'V�
{�<������Ӄ�*�[��*��%���wOuM΁�� i1��&2幔ݛ;���K�FKF��Na/��Z'�n�Thi?���>;-7��m�m%���1ݟ��}��#�@o,s����vh��H�4e��̸���x�za�RECO�NS�y���R����ۤ�� ��/ba������y�Ty��O�&c-u`��ʇ����}!�)��W���n� ����ۂ�k�f-M��0Z(diM��m�����F�:j�m��,�W*$jw��?��[�k(a�qT�E�����YJ���iٷ_���|��lP�N-+�L�������r���Hq1ݐ�l_�ߥQ?�n�:���"jǞ"K��`��O������Ђm��@2��>�+�͔�D��A�)a:z�H�¸ڎ�x�^�8[������-#��!��\b���,��N���4�2�aa `�~��n�m��0*<w�x���#w�p�?�}�����p���������u8�[���+}�ۻ�7g{bl;Cm;����&ڐ�.o��������VL�A�|nv�Y�a yX�bIǯL�uoY��g0on�P;�Lkt˾�p����]��j=����:	\����u��*-��NZ�����1U�G�'�a�4��7��"î������<�i5s��[C��Y�6S{��k4�%���r�Pv��\�������8�Q���d�J��5+^��C��ҫjm�X˅��u��vW�ɋ�n7-�U�{s�_$�#w�:�fw��u��������v-�f�`����O܅!�)��x=Z�~��g�����~dw����qh�;��}d�;��}מ�(��δ������ӧ)C�0G>��d�:�S�������7m+y����0�pg:�PLm=6 A�u$Wp�{=a�B�/�+�0�����?*<� ��ǰy�_cw������0w�C��c%�۲���[	��ҫ���y^�ʾ�{Y٣��?���ȷt� �7~]�/g�+���3T���_��#S��?���+����ŠWOl���URG�+8�n�,'؝�.aٱ���N��l����~��"�s�E0U-�'�e<����k8�^&��/�;�]�s�����>G���G��IǗ���&k����Wnx�Aݬ�Ы����˵v��� ���f�ӷߋ{$��'�r��h������9D��cOе<���ȿ"�^��'r��N���n������c��W����}�� ���������:���:�B�ώ�������x?��DX�7�k�+L��˱�h4@<���;�9��I� ���㗳������E�.E���enڥUSu���������YI��^����,����u����嬐��Z�ɔyԸB�&���rM���!w��}���������r��|%����+v.V�qr^�>����pثy*'���cnmG�����F�]v�:�@� �-Mf����M[���㷪�7�ƻ��r���g�`@U�F"o��8]����7'�c�w��P:d����6����xz���5�91x�}*������c������Hp��蠧�V�+��-������VE:���ζ���O��u�� ���a� �%S�6��/01,%Z���8c�[�0�X�n,�	[ǐ"��s�̅qD��o�������z     