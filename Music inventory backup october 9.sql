PGDMP     4            	    	    |            music_inventory    15.6 (Postgres.app)    15.6 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'BIG5';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    30562    music_inventory    DATABASE     q   CREATE DATABASE music_inventory WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'C';
    DROP DATABASE music_inventory;
                postgres    false            �           0    0    SCHEMA public    ACL     +   REVOKE USAGE ON SCHEMA public FROM PUBLIC;
                   pg_database_owner    false    6                        3079    30807    citext 	   EXTENSION     :   CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;
    DROP EXTENSION citext;
                   false            �           0    0    EXTENSION citext    COMMENT     S   COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';
                        false    2            :           1255    31724    advance_school_year()    FUNCTION     �   CREATE FUNCTION public.advance_school_year() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE public.students
    SET grade_level = (grade_level::integer + 1)::integer
    WHERE  grade_level::integer <= 12;
END;
$$;
 ,   DROP FUNCTION public.advance_school_year();
       public          postgres    false            U           1255    30685    check_teacher_role()    FUNCTION     '  CREATE FUNCTION public.check_teacher_role() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (SELECT role FROM users WHERE id = NEW.teacher_id) <> 'MUSIC TEACHER' THEN
    RAISE EXCEPTION 'Teacher_id must correspond to a user with the role "TEACHER".';
  END IF;
  RETURN NEW;
END;
$$;
 +   DROP FUNCTION public.check_teacher_role();
       public          postgres    false            F           1255    30686    create_roles()    FUNCTION     �  CREATE FUNCTION public.create_roles() RETURNS void
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
       public          postgres    false            G           1255    30687 
   dispatch()    FUNCTION     �  CREATE FUNCTION public.dispatch() RETURNS trigger
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
 !   DROP FUNCTION public.dispatch();
       public          postgres    false            H           1255    30688    get_division(character varying)    FUNCTION     �  CREATE FUNCTION public.get_division(grade_level character varying) RETURNS character varying
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
       public          postgres    false            9           1255    30912 *   get_instruments_by_name(character varying)    FUNCTION     �  CREATE FUNCTION public.get_instruments_by_name(p_name character varying) RETURNS TABLE(description public.citext, make public.citext, number integer, username character varying)
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
       public          postgres    false    2    2    2    2    2            I           1255    30689 /   get_item_id_by_code(character varying, integer)    FUNCTION       CREATE FUNCTION public.get_item_id_by_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
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
       public          postgres    false            J           1255    30690 6   get_item_id_by_description(character varying, integer)    FUNCTION     Q  CREATE FUNCTION public.get_item_id_by_description(p_description character varying, p_number integer) RETURNS integer
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
       public          postgres    false            K           1255    30691 3   get_item_id_by_old_code(character varying, integer)    FUNCTION     !  CREATE FUNCTION public.get_item_id_by_old_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
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
       public          postgres    false            L           1255    30692 (   get_item_id_by_serial(character varying)    FUNCTION     �   CREATE FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE "serial" = p_serial;
END;
$$;
 ]   DROP FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer);
       public          postgres    false            M           1255    30693 (   get_user_id_by_number(character varying)    FUNCTION     �   CREATE FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM all_users_view
    WHERE "number" = p_number;
END;
$$;
 ]   DROP FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer);
       public          postgres    false            N           1255    30694 &   get_user_id_by_role(character varying)    FUNCTION     �   CREATE FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM users
    WHERE "username" = p_role;
END;
$$;
 Y   DROP FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer);
       public          postgres    false                       1255    30695 1   insert_type(character varying, character varying)    FUNCTION     �   CREATE FUNCTION public.insert_type(p_code character varying, p_description character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO types (code, description) VALUES (UPPER(p_code), UPPER(p_description));
END;
$$;
 ]   DROP FUNCTION public.insert_type(p_code character varying, p_description character varying);
       public          postgres    false            W           1255    30696    log_transaction()    FUNCTION     x  CREATE FUNCTION public.log_transaction() RETURNS trigger
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
 (   DROP FUNCTION public.log_transaction();
       public          postgres    false            O           1255    30697    new_instr_function()    FUNCTION     �  CREATE FUNCTION public.new_instr_function() RETURNS trigger
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
 +   DROP FUNCTION public.new_instr_function();
       public          postgres    false            T           1255    31646    new_student_function()    FUNCTION     /  CREATE FUNCTION public.new_student_function() RETURNS trigger
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
 -   DROP FUNCTION public.new_student_function();
       public          postgres    false            P           1255    30698    return()    FUNCTION     �  CREATE FUNCTION public.return() RETURNS trigger
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
    DROP FUNCTION public.return();
       public          postgres    false            Q           1255    30699 &   search_user_by_name(character varying)    FUNCTION     �  CREATE FUNCTION public.search_user_by_name(p_name character varying, OUT user_id integer, OUT full_name text, OUT grade_level character varying) RETURNS SETOF record
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
       public          postgres    false            S           1255    31721 $   set_user_role_based_on_grade_level()    FUNCTION     �  CREATE FUNCTION public.set_user_role_based_on_grade_level() RETURNS trigger
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
 ;   DROP FUNCTION public.set_user_role_based_on_grade_level();
       public          postgres    false            R           1255    31521    swap_cases_trigger()    FUNCTION       CREATE FUNCTION public.swap_cases_trigger() RETURNS trigger
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
 +   DROP FUNCTION public.swap_cases_trigger();
       public          postgres    false            V           1255    31529 K   swap_instrument_numbers(public.citext, integer, integer, character varying)    FUNCTION     �  CREATE FUNCTION public.swap_instrument_numbers(instr_code public.citext, item_id_1 integer, item_id_2 integer, created_by character varying) RETURNS void
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
 �   DROP FUNCTION public.swap_instrument_numbers(instr_code public.citext, item_id_1 integer, item_id_2 integer, created_by character varying);
       public          postgres    false    2    2    2    2    2            X           1255    31719    update_students()    FUNCTION     �  CREATE FUNCTION public.update_students() RETURNS trigger
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
 (   DROP FUNCTION public.update_students();
       public          postgres    false            �            1259    30913 	   equipment    TABLE     �   CREATE TABLE public.equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);
    DROP TABLE public.equipment;
       public         heap    postgres    false    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    30918    all_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.all_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    235            �            1259    30919    instruments    TABLE     �  CREATE TABLE public.instruments (
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
    DROP TABLE public.instruments;
       public         heap    postgres    false    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    30926    users    TABLE     x  CREATE TABLE public.users (
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
    DROP TABLE public.users;
       public         heap    postgres    false    2    2    2    2    2            �            1259    30932    all_instruments_view    VIEW     "  CREATE VIEW public.all_instruments_view AS
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
       public          postgres    false    237    237    237    237    237    237    237    237    237    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    238    238    238    237    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    30937    students    TABLE     0  CREATE TABLE public.students (
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
    DROP TABLE public.students;
       public         heap    postgres    false                       1259    39772    all_users_view    VIEW     �  CREATE VIEW public.all_users_view AS
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
 !   DROP VIEW public.all_users_view;
       public          postgres    false    238    238    238    238    238    238    238    238    238    240    240    238    238    2    2    2    2    2            �            1259    30700    class    TABLE     z   CREATE TABLE public.class (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    class_name character varying
);
    DROP TABLE public.class;
       public         heap    postgres    false            �            1259    30705    class_id_seq    SEQUENCE     �   ALTER TABLE public.class ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    215            	           1259    39811    class_students    TABLE     �   CREATE TABLE public.class_students (
    class_id integer NOT NULL,
    user_id integer NOT NULL,
    primary_instrument character varying(255)
);
 "   DROP TABLE public.class_students;
       public         heap    postgres    false            
           1259    39830    class_students_view    VIEW     ?  CREATE VIEW public.class_students_view AS
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
 &   DROP VIEW public.class_students_view;
       public          postgres    false    215    215    238    238    238    238    265    265    265            �            1259    30948    dispatched_instruments_view    VIEW     W  CREATE VIEW public.dispatched_instruments_view AS
 SELECT all_instruments_view.id,
    all_instruments_view.description,
    all_instruments_view.number,
    all_instruments_view.make,
    all_instruments_view.serial,
    all_instruments_view.user_name
   FROM public.all_instruments_view
  WHERE (all_instruments_view.user_name IS NOT NULL);
 .   DROP VIEW public.dispatched_instruments_view;
       public          postgres    false    239    239    239    239    239    239    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    30706 
   dispatches    TABLE     �   CREATE TABLE public.dispatches (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    user_id integer,
    item_id integer,
    created_by character varying,
    profile_id integer
);
    DROP TABLE public.dispatches;
       public         heap    postgres    false            �            1259    30712    dispatches_id_seq    SEQUENCE     �   ALTER TABLE public.dispatches ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dispatches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    217            �            1259    30713    duplicate_instruments    TABLE        CREATE TABLE public.duplicate_instruments (
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
       public         heap    postgres    false            �            1259    30720    duplicate_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.duplicate_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.duplicate_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    219            �            1259    30952    hardware_and_equipment    TABLE     �   CREATE TABLE public.hardware_and_equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);
 *   DROP TABLE public.hardware_and_equipment;
       public         heap    postgres    false    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    30957    hardware_and_equipment_id_seq    SEQUENCE     �   ALTER TABLE public.hardware_and_equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.hardware_and_equipment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    242            �            1259    30721    instrument_history    TABLE     x  CREATE TABLE public.instrument_history (
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
 &   DROP TABLE public.instrument_history;
       public         heap    postgres    false                       1259    31547    history_view    VIEW     �  CREATE VIEW public.history_view AS
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
    DROP VIEW public.history_view;
       public          postgres    false    221    238    238    238    238    237    237    237    221    221    221    221    221    221    221            �            1259    30727    instrument_conditions    TABLE     h   CREATE TABLE public.instrument_conditions (
    id integer NOT NULL,
    condition character varying
);
 )   DROP TABLE public.instrument_conditions;
       public         heap    postgres    false            �            1259    30732    instrument_conditions_id_seq    SEQUENCE     �   ALTER TABLE public.instrument_conditions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_conditions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    222            �            1259    30963    instrument_distribution_view    VIEW     �  CREATE VIEW public.instrument_distribution_view AS
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
       public          postgres    false    237    237    237    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    237    2    2    2    2    2    237    237    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    30733    instrument_history_id_seq    SEQUENCE     �   ALTER TABLE public.instrument_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    221                       1259    31155    instrument_placeholder_seq    SEQUENCE     �   CREATE SEQUENCE public.instrument_placeholder_seq
    START WITH -1
    INCREMENT BY -1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.instrument_placeholder_seq;
       public          postgres    false            �            1259    30968    instrument_requests    TABLE       CREATE TABLE public.instrument_requests (
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
 '   DROP TABLE public.instrument_requests;
       public         heap    postgres    false    2    2    2    2    2            �            1259    30976    instrument_requests_id_seq    SEQUENCE     �   ALTER TABLE public.instrument_requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    245            �            1259    30977    instruments_id_seq    SEQUENCE     �   ALTER TABLE public.instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    237            �            1259    30978    legacy_database    TABLE     S  CREATE TABLE public.legacy_database (
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
       public         heap    postgres    false    2    2    2    2    2            �            1259    30985    legacy_database_id_seq    SEQUENCE     �   ALTER TABLE public.legacy_database ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.legacy_database_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    248            �            1259    30986 	   locations    TABLE     \   CREATE TABLE public.locations (
    room public.citext NOT NULL,
    id integer NOT NULL
);
    DROP TABLE public.locations;
       public         heap    postgres    false    2    2    2    2    2            �            1259    30991    locations_id_seq    SEQUENCE     �   ALTER TABLE public.locations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    250            �            1259    30734    lost_and_found    TABLE     �   CREATE TABLE public.lost_and_found (
    id integer NOT NULL,
    item_id integer NOT NULL,
    finder_name character varying,
    date date DEFAULT CURRENT_DATE,
    location text,
    contact text
);
 "   DROP TABLE public.lost_and_found;
       public         heap    postgres    false            �            1259    30740    lost_and_found_id_seq    SEQUENCE     �   ALTER TABLE public.lost_and_found ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.lost_and_found_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    225            �            1259    30992    music_instruments    TABLE     �  CREATE TABLE public.music_instruments (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext NOT NULL,
    notes character varying,
    CONSTRAINT music_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text])))
);
 %   DROP TABLE public.music_instruments;
       public         heap    postgres    false    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    30998    music_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.music_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.music_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    252            �            1259    30999    new_instrument    TABLE     /  CREATE TABLE public.new_instrument (
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
 "   DROP TABLE public.new_instrument;
       public         heap    postgres    false    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �            1259    31005    new_instrument_id_seq    SEQUENCE     �   ALTER TABLE public.new_instrument ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.new_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    254            �            1259    30741    repair_request    TABLE     �   CREATE TABLE public.repair_request (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    complaint text NOT NULL
);
 "   DROP TABLE public.repair_request;
       public         heap    postgres    false            �            1259    30747    repairs_id_seq    SEQUENCE     �   ALTER TABLE public.repair_request ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.repairs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    227            �            1259    30748    resolve    TABLE     �   CREATE TABLE public.resolve (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    "case" integer,
    notes text
);
    DROP TABLE public.resolve;
       public         heap    postgres    false            �            1259    30754    resolve_id_seq    SEQUENCE     �   ALTER TABLE public.resolve ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.resolve_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    229            �            1259    30755    returns    TABLE     �   CREATE TABLE public.returns (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    created_by character varying,
    user_id integer,
    former_user_id integer
);
    DROP TABLE public.returns;
       public         heap    postgres    false            �            1259    30761    returns_id_seq    SEQUENCE     �   ALTER TABLE public.returns ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.returns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    231            �            1259    30762    roles    TABLE     }   CREATE TABLE public.roles (
    id integer NOT NULL,
    role_name character varying DEFAULT 'STUDENT'::character varying
);
    DROP TABLE public.roles;
       public         heap    postgres    false            �            1259    30768    roles_id_seq    SEQUENCE     �   ALTER TABLE public.roles ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    233                        1259    31006    students_id_seq    SEQUENCE     �   ALTER TABLE public.students ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.students_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    240                       1259    31502 
   swap_cases    TABLE     �   CREATE TABLE public.swap_cases (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    instr_code public.citext,
    item_id_1 integer,
    item_id_2 integer,
    created_by character varying
);
    DROP TABLE public.swap_cases;
       public         heap    postgres    false    2    2    2    2    2                       1259    31501    swap_cases_id_seq    SEQUENCE     �   ALTER TABLE public.swap_cases ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.swap_cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    260                       1259    31538 
   take_stock    TABLE     0  CREATE TABLE public.take_stock (
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
    DROP TABLE public.take_stock;
       public         heap    postgres    false    2    2    2    2    2    2    2    2    2    2                       1259    31537    take_stock_id_seq    SEQUENCE     �   ALTER TABLE public.take_stock ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.take_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    262                       1259    31007    users_id_seq    SEQUENCE     �   ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    238            �          0    30700    class 
   TABLE DATA                 public          postgres    false    215            �          0    39811    class_students 
   TABLE DATA                 public          postgres    false    265            �          0    30706 
   dispatches 
   TABLE DATA                 public          postgres    false    217            �          0    30713    duplicate_instruments 
   TABLE DATA                 public          postgres    false    219            �          0    30913 	   equipment 
   TABLE DATA                 public          postgres    false    235            �          0    30952    hardware_and_equipment 
   TABLE DATA                 public          postgres    false    242            �          0    30727    instrument_conditions 
   TABLE DATA                 public          postgres    false    222            �          0    30721    instrument_history 
   TABLE DATA                 public          postgres    false    221            �          0    30968    instrument_requests 
   TABLE DATA                 public          postgres    false    245            �          0    30919    instruments 
   TABLE DATA                 public          postgres    false    237            �          0    30978    legacy_database 
   TABLE DATA                 public          postgres    false    248            �          0    30986 	   locations 
   TABLE DATA                 public          postgres    false    250            �          0    30734    lost_and_found 
   TABLE DATA                 public          postgres    false    225            �          0    30992    music_instruments 
   TABLE DATA                 public          postgres    false    252            �          0    30999    new_instrument 
   TABLE DATA                 public          postgres    false    254            �          0    30741    repair_request 
   TABLE DATA                 public          postgres    false    227            �          0    30748    resolve 
   TABLE DATA                 public          postgres    false    229            �          0    30755    returns 
   TABLE DATA                 public          postgres    false    231            �          0    30762    roles 
   TABLE DATA                 public          postgres    false    233            �          0    30937    students 
   TABLE DATA                 public          postgres    false    240            �          0    31502 
   swap_cases 
   TABLE DATA                 public          postgres    false    260            �          0    31538 
   take_stock 
   TABLE DATA                 public          postgres    false    262            �          0    30926    users 
   TABLE DATA                 public          postgres    false    238            �           0    0    all_instruments_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.all_instruments_id_seq', 350, true);
          public          postgres    false    236            �           0    0    class_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.class_id_seq', 14, true);
          public          postgres    false    216            �           0    0    dispatches_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.dispatches_id_seq', 284, true);
          public          postgres    false    218            �           0    0    duplicate_instruments_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.duplicate_instruments_id_seq', 96, true);
          public          postgres    false    220            �           0    0    hardware_and_equipment_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.hardware_and_equipment_id_seq', 20, true);
          public          postgres    false    243            �           0    0    instrument_conditions_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.instrument_conditions_id_seq', 6, true);
          public          postgres    false    223            �           0    0    instrument_history_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.instrument_history_id_seq', 3578, true);
          public          postgres    false    224            �           0    0    instrument_placeholder_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.instrument_placeholder_seq', -1, false);
          public          postgres    false    258            �           0    0    instrument_requests_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.instrument_requests_id_seq', 91, true);
          public          postgres    false    246            �           0    0    instruments_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.instruments_id_seq', 4215, true);
          public          postgres    false    247            �           0    0    legacy_database_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.legacy_database_id_seq', 669, true);
          public          postgres    false    249            �           0    0    locations_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.locations_id_seq', 16, true);
          public          postgres    false    251            �           0    0    lost_and_found_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.lost_and_found_id_seq', 15, true);
          public          postgres    false    226            �           0    0    music_instruments_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.music_instruments_id_seq', 544, true);
          public          postgres    false    253            �           0    0    new_instrument_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.new_instrument_id_seq', 44, true);
          public          postgres    false    255            �           0    0    repairs_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.repairs_id_seq', 1, false);
          public          postgres    false    228            �           0    0    resolve_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.resolve_id_seq', 1, false);
          public          postgres    false    230            �           0    0    returns_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.returns_id_seq', 315, true);
          public          postgres    false    232            �           0    0    roles_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.roles_id_seq', 14, true);
          public          postgres    false    234            �           0    0    students_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.students_id_seq', 1088, true);
          public          postgres    false    256            �           0    0    swap_cases_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.swap_cases_id_seq', 50, true);
          public          postgres    false    259            �           0    0    take_stock_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.take_stock_id_seq', 10, true);
          public          postgres    false    261            �           0    0    users_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.users_id_seq', 1099, true);
          public          postgres    false    257            �           2606    31008 &   equipment all_instruments_family_check    CHECK CONSTRAINT       ALTER TABLE public.equipment
    ADD CONSTRAINT all_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text, 'SOUND'::text]))) NOT VALID;
 K   ALTER TABLE public.equipment DROP CONSTRAINT all_instruments_family_check;
       public          postgres    false    235    235            �           2606    31010    equipment all_instruments_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT all_instruments_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.equipment DROP CONSTRAINT all_instruments_pkey;
       public            postgres    false    235            �           2606    30770    class class_class_name_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_class_name_key UNIQUE (class_name);
 D   ALTER TABLE ONLY public.class DROP CONSTRAINT class_class_name_key;
       public            postgres    false    215            �           2606    30772    class class_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.class DROP CONSTRAINT class_pkey;
       public            postgres    false    215            �           2606    39815 "   class_students class_students_pkey 
   CONSTRAINT     o   ALTER TABLE ONLY public.class_students
    ADD CONSTRAINT class_students_pkey PRIMARY KEY (class_id, user_id);
 L   ALTER TABLE ONLY public.class_students DROP CONSTRAINT class_students_pkey;
       public            postgres    false    265    265            �           2606    30774    dispatches dispatches_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.dispatches DROP CONSTRAINT dispatches_pkey;
       public            postgres    false    217            �           2606    30776 0   duplicate_instruments duplicate_instruments_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.duplicate_instruments
    ADD CONSTRAINT duplicate_instruments_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.duplicate_instruments DROP CONSTRAINT duplicate_instruments_pkey;
       public            postgres    false    219            �           2606    31012    equipment equipment_code_key 
   CONSTRAINT     f   ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_code_key UNIQUE (code) INCLUDE (code);
 F   ALTER TABLE ONLY public.equipment DROP CONSTRAINT equipment_code_key;
       public            postgres    false    235            �           2606    31014 #   equipment equipment_description_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.equipment
    ADD CONSTRAINT equipment_description_key UNIQUE (description);
 M   ALTER TABLE ONLY public.equipment DROP CONSTRAINT equipment_description_key;
       public            postgres    false    235            �           2606    31016 =   hardware_and_equipment hardware_and_equipment_description_key 
   CONSTRAINT        ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_description_key UNIQUE (description);
 g   ALTER TABLE ONLY public.hardware_and_equipment DROP CONSTRAINT hardware_and_equipment_description_key;
       public            postgres    false    242            �           2606    31017 :   hardware_and_equipment hardware_and_equipment_family_check    CHECK CONSTRAINT     �   ALTER TABLE public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_family_check CHECK ((upper((family)::text) = ANY (ARRAY['MISCELLANEOUS'::text, 'SOUND'::text]))) NOT VALID;
 _   ALTER TABLE public.hardware_and_equipment DROP CONSTRAINT hardware_and_equipment_family_check;
       public          postgres    false    242    242            �           2606    31019 2   hardware_and_equipment hardware_and_equipment_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.hardware_and_equipment
    ADD CONSTRAINT hardware_and_equipment_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.hardware_and_equipment DROP CONSTRAINT hardware_and_equipment_pkey;
       public            postgres    false    242            �           2606    30778 9   instrument_conditions instrument_conditions_condition_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.instrument_conditions
    ADD CONSTRAINT instrument_conditions_condition_key UNIQUE (condition);
 c   ALTER TABLE ONLY public.instrument_conditions DROP CONSTRAINT instrument_conditions_condition_key;
       public            postgres    false    222            �           2606    30780 0   instrument_conditions instrument_conditions_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.instrument_conditions
    ADD CONSTRAINT instrument_conditions_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.instrument_conditions DROP CONSTRAINT instrument_conditions_pkey;
       public            postgres    false    222            �           2606    30782 *   instrument_history instrument_history_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.instrument_history DROP CONSTRAINT instrument_history_pkey;
       public            postgres    false    221            �           2606    31153 '   instruments instruments_code_number_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_number_key UNIQUE (code, number) DEFERRABLE INITIALLY DEFERRED;
 Q   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_code_number_key;
       public            postgres    false    237    237            �           2606    31023    instruments instruments_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_pkey;
       public            postgres    false    237            �           2606    31025 "   instruments instruments_serial_key 
   CONSTRAINT     _   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_serial_key UNIQUE (serial);
 L   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_serial_key;
       public            postgres    false    237            �           2606    31027 $   legacy_database legacy_database_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.legacy_database
    ADD CONSTRAINT legacy_database_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.legacy_database DROP CONSTRAINT legacy_database_pkey;
       public            postgres    false    248            �           2606    31029    locations locations_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.locations DROP CONSTRAINT locations_pkey;
       public            postgres    false    250            �           2606    30784 "   lost_and_found lost_and_found_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.lost_and_found
    ADD CONSTRAINT lost_and_found_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.lost_and_found DROP CONSTRAINT lost_and_found_pkey;
       public            postgres    false    225            �           2606    31031 ,   music_instruments music_instruments_code_key 
   CONSTRAINT     v   ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_code_key UNIQUE (code) INCLUDE (code);
 V   ALTER TABLE ONLY public.music_instruments DROP CONSTRAINT music_instruments_code_key;
       public            postgres    false    252            �           2606    31033 3   music_instruments music_instruments_description_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_description_key UNIQUE (description);
 ]   ALTER TABLE ONLY public.music_instruments DROP CONSTRAINT music_instruments_description_key;
       public            postgres    false    252            �           2606    31035 (   music_instruments music_instruments_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.music_instruments
    ADD CONSTRAINT music_instruments_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.music_instruments DROP CONSTRAINT music_instruments_pkey;
       public            postgres    false    252            �           2606    31037 "   new_instrument new_instrument_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.new_instrument
    ADD CONSTRAINT new_instrument_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.new_instrument DROP CONSTRAINT new_instrument_pkey;
       public            postgres    false    254            �           2606    30786    repair_request repairs_pkey 
   CONSTRAINT     Y   ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_pkey PRIMARY KEY (id);
 E   ALTER TABLE ONLY public.repair_request DROP CONSTRAINT repairs_pkey;
       public            postgres    false    227            �           2606    31039 !   instrument_requests requests_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);
 K   ALTER TABLE ONLY public.instrument_requests DROP CONSTRAINT requests_pkey;
       public            postgres    false    245            �           2606    30788    resolve resolve_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.resolve DROP CONSTRAINT resolve_pkey;
       public            postgres    false    229            �           2606    30790    returns returns_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.returns DROP CONSTRAINT returns_pkey;
       public            postgres    false    231            �           2606    30792    roles roles_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.roles DROP CONSTRAINT roles_pkey;
       public            postgres    false    233            �           2606    30794    roles roles_role_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_role_name_key UNIQUE (role_name);
 C   ALTER TABLE ONLY public.roles DROP CONSTRAINT roles_role_name_key;
       public            postgres    false    233            �           2606    31041    locations room 
   CONSTRAINT     I   ALTER TABLE ONLY public.locations
    ADD CONSTRAINT room UNIQUE (room);
 8   ALTER TABLE ONLY public.locations DROP CONSTRAINT room;
       public            postgres    false    250            �           2606    31683    students students_email_key 
   CONSTRAINT     W   ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_email_key UNIQUE (email);
 E   ALTER TABLE ONLY public.students DROP CONSTRAINT students_email_key;
       public            postgres    false    240            �           2606    31043    students students_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.students DROP CONSTRAINT students_pkey;
       public            postgres    false    240            �           2606    31685 $   students students_student_number_key 
   CONSTRAINT     i   ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_student_number_key UNIQUE (student_number);
 N   ALTER TABLE ONLY public.students DROP CONSTRAINT students_student_number_key;
       public            postgres    false    240            �           2606    31509    swap_cases swap_cases_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.swap_cases
    ADD CONSTRAINT swap_cases_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.swap_cases DROP CONSTRAINT swap_cases_pkey;
       public            postgres    false    260            �           2606    31545    take_stock take_stock_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.take_stock
    ADD CONSTRAINT take_stock_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.take_stock DROP CONSTRAINT take_stock_pkey;
       public            postgres    false    262            �           2606    31045    users users_email_key 
   CONSTRAINT     Q   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);
 ?   ALTER TABLE ONLY public.users DROP CONSTRAINT users_email_key;
       public            postgres    false    238            �           2606    31049    users users_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public            postgres    false    238            �           1259    31050    fki_instruments_code_fkey    INDEX     Q   CREATE INDEX fki_instruments_code_fkey ON public.instruments USING btree (code);
 -   DROP INDEX public.fki_instruments_code_fkey;
       public            postgres    false    237    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �           1259    31051     fki_instruments_description_fkey    INDEX     _   CREATE INDEX fki_instruments_description_fkey ON public.instruments USING btree (description);
 4   DROP INDEX public.fki_instruments_description_fkey;
       public            postgres    false    237    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �           2620    30795    dispatches assign_user    TRIGGER     o   CREATE TRIGGER assign_user BEFORE INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.dispatch();
 /   DROP TRIGGER assign_user ON public.dispatches;
       public          postgres    false    327    217                       2620    31528 #   swap_cases before_swap_cases_insert    TRIGGER     �   CREATE TRIGGER before_swap_cases_insert AFTER INSERT ON public.swap_cases FOR EACH ROW EXECUTE FUNCTION public.swap_cases_trigger();
 <   DROP TRIGGER before_swap_cases_insert ON public.swap_cases;
       public          postgres    false    338    260            �           2620    30796    lost_and_found log_instrument    TRIGGER     |   CREATE TRIGGER log_instrument AFTER INSERT ON public.lost_and_found FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 6   DROP TRIGGER log_instrument ON public.lost_and_found;
       public          postgres    false    343    225            �           2620    30797    returns log_return    TRIGGER     q   CREATE TRIGGER log_return AFTER INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 +   DROP TRIGGER log_return ON public.returns;
       public          postgres    false    231    343                       2620    31546    take_stock log_take_stock    TRIGGER     x   CREATE TRIGGER log_take_stock AFTER INSERT ON public.take_stock FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 2   DROP TRIGGER log_take_stock ON public.take_stock;
       public          postgres    false    262    343            �           2620    30798    dispatches log_transaction    TRIGGER     y   CREATE TRIGGER log_transaction AFTER INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 3   DROP TRIGGER log_transaction ON public.dispatches;
       public          postgres    false    343    217                       2620    31052    new_instrument log_transaction    TRIGGER     �   CREATE TRIGGER log_transaction AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.log_transaction();

ALTER TABLE public.new_instrument DISABLE TRIGGER log_transaction;
 7   DROP TRIGGER log_transaction ON public.new_instrument;
       public          postgres    false    254    343            �           2620    31053    instruments new_instr    TRIGGER     ~   CREATE TRIGGER new_instr AFTER INSERT OR UPDATE ON public.instruments FOR EACH ROW EXECUTE FUNCTION public.log_transaction();
 .   DROP TRIGGER new_instr ON public.instruments;
       public          postgres    false    343    237                       2620    31054 %   new_instrument new_instrument_trigger    TRIGGER     �   CREATE TRIGGER new_instrument_trigger AFTER INSERT ON public.new_instrument FOR EACH ROW EXECUTE FUNCTION public.new_instr_function();
 >   DROP TRIGGER new_instrument_trigger ON public.new_instrument;
       public          postgres    false    254    335                       2620    31716    students new_student_trigger    TRIGGER     �   CREATE TRIGGER new_student_trigger BEFORE INSERT ON public.students FOR EACH ROW EXECUTE FUNCTION public.new_student_function();
 5   DROP TRIGGER new_student_trigger ON public.students;
       public          postgres    false    240    340            �           2620    30799    returns return_trigger    TRIGGER     m   CREATE TRIGGER return_trigger BEFORE INSERT ON public.returns FOR EACH ROW EXECUTE FUNCTION public.return();
 /   DROP TRIGGER return_trigger ON public.returns;
       public          postgres    false    231    336            �           2620    30800    class trg_check_teacher_role    TRIGGER     �   CREATE TRIGGER trg_check_teacher_role BEFORE INSERT OR UPDATE ON public.class FOR EACH ROW EXECUTE FUNCTION public.check_teacher_role();
 5   DROP TRIGGER trg_check_teacher_role ON public.class;
       public          postgres    false    341    215                        2620    31722    users update_role_trigger    TRIGGER     �   CREATE TRIGGER update_role_trigger AFTER INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_user_role_based_on_grade_level();
 2   DROP TRIGGER update_role_trigger ON public.users;
       public          postgres    false    339    238                       2620    31720    students update_student_trigger    TRIGGER     ~   CREATE TRIGGER update_student_trigger AFTER UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.update_students();
 8   DROP TRIGGER update_student_trigger ON public.students;
       public          postgres    false    344    240            �           2606    39816 +   class_students class_students_class_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.class_students
    ADD CONSTRAINT class_students_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.class(id) ON DELETE CASCADE;
 U   ALTER TABLE ONLY public.class_students DROP CONSTRAINT class_students_class_id_fkey;
       public          postgres    false    3737    265    215            �           2606    39821 *   class_students class_students_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.class_students
    ADD CONSTRAINT class_students_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
 T   ALTER TABLE ONLY public.class_students DROP CONSTRAINT class_students_user_id_fkey;
       public          postgres    false    265    3777    238            �           2606    31055    class class_teacher_id_fkey    FK CONSTRAINT     }   ALTER TABLE ONLY public.class
    ADD CONSTRAINT class_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);
 E   ALTER TABLE ONLY public.class DROP CONSTRAINT class_teacher_id_fkey;
       public          postgres    false    238    3777    215            �           2606    31060 "   dispatches dispatches_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);
 L   ALTER TABLE ONLY public.dispatches DROP CONSTRAINT dispatches_item_id_fkey;
       public          postgres    false    217    3771    237            �           2606    31065 %   dispatches dispatches_profile_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.dispatches
    ADD CONSTRAINT dispatches_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;
 O   ALTER TABLE ONLY public.dispatches DROP CONSTRAINT dispatches_profile_id_fkey;
       public          postgres    false    3777    238    217            �           2606    31070 2   instrument_history instrument_history_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instrument_history
    ADD CONSTRAINT instrument_history_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id);
 \   ALTER TABLE ONLY public.instrument_history DROP CONSTRAINT instrument_history_item_id_fkey;
       public          postgres    false    221    237    3771            �           2606    31075 !   instruments instruments_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_code_fkey FOREIGN KEY (code) REFERENCES public.equipment(code) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 K   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_code_fkey;
       public          postgres    false    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    3763    235    237    2    2    2    2    2    2    2    2    2    2    2    2            �           2606    31080 (   instruments instruments_description_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_description_fkey FOREIGN KEY (description) REFERENCES public.equipment(description) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 R   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_description_fkey;
       public          postgres    false    235    2    2    2    2    2    2    2    2    2    2    2    2    3765    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    237            �           2606    31085 %   instruments instruments_location_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_location_fkey FOREIGN KEY (location) REFERENCES public.locations(room) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 O   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_location_fkey;
       public          postgres    false    237    3795    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    250    2    2    2    2    2    2    2    2    2    2    2    2            �           2606    31090 "   instruments instruments_state_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_state_fkey FOREIGN KEY (state) REFERENCES public.instrument_conditions(condition) ON UPDATE CASCADE NOT VALID;
 L   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_state_fkey;
       public          postgres    false    222    3745    237            �           2606    31095 *   lost_and_found lost_and_found_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.lost_and_found
    ADD CONSTRAINT lost_and_found_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE;
 T   ALTER TABLE ONLY public.lost_and_found DROP CONSTRAINT lost_and_found_item_id_fkey;
       public          postgres    false    225    3771    237            �           2606    31100 #   repair_request repairs_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.repair_request
    ADD CONSTRAINT repairs_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;
 M   ALTER TABLE ONLY public.repair_request DROP CONSTRAINT repairs_item_id_fkey;
       public          postgres    false    3771    237    227            �           2606    31105 0   instrument_requests requests_attended_by_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_attended_by_id_fkey FOREIGN KEY (attended_by_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;
 Z   ALTER TABLE ONLY public.instrument_requests DROP CONSTRAINT requests_attended_by_id_fkey;
       public          postgres    false    245    238    3777            �           2606    31110 ,   instrument_requests requests_instrument_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_instrument_fkey FOREIGN KEY (instrument) REFERENCES public.equipment(description);
 V   ALTER TABLE ONLY public.instrument_requests DROP CONSTRAINT requests_instrument_fkey;
       public          postgres    false    245    3765    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    235    2    2    2    2    2    2    2    2    2    2    2    2            �           2606    31115 )   instrument_requests requests_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instrument_requests
    ADD CONSTRAINT requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);
 S   ALTER TABLE ONLY public.instrument_requests DROP CONSTRAINT requests_user_id_fkey;
       public          postgres    false    3777    238    245            �           2606    30801    resolve resolve_case_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.resolve
    ADD CONSTRAINT resolve_case_fkey FOREIGN KEY ("case") REFERENCES public.repair_request(id);
 C   ALTER TABLE ONLY public.resolve DROP CONSTRAINT resolve_case_fkey;
       public          postgres    false    229    227    3751            �           2606    31120    returns returns_former_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_former_user_id FOREIGN KEY (former_user_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;
 H   ALTER TABLE ONLY public.returns DROP CONSTRAINT returns_former_user_id;
       public          postgres    false    3777    231    238            �           2606    31510 !   swap_cases returns_item_id_1_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.swap_cases
    ADD CONSTRAINT returns_item_id_1_fkey FOREIGN KEY (item_id_1) REFERENCES public.instruments(id) ON UPDATE CASCADE;
 K   ALTER TABLE ONLY public.swap_cases DROP CONSTRAINT returns_item_id_1_fkey;
       public          postgres    false    260    237    3771            �           2606    31515 !   swap_cases returns_item_id_2_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.swap_cases
    ADD CONSTRAINT returns_item_id_2_fkey FOREIGN KEY (item_id_2) REFERENCES public.instruments(id) ON UPDATE CASCADE;
 K   ALTER TABLE ONLY public.swap_cases DROP CONSTRAINT returns_item_id_2_fkey;
       public          postgres    false    3771    237    260            �           2606    31125    returns returns_item_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.instruments(id) ON UPDATE CASCADE NOT VALID;
 F   ALTER TABLE ONLY public.returns DROP CONSTRAINT returns_item_id_fkey;
       public          postgres    false    237    231    3771            �           2606    31130    returns returns_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.returns
    ADD CONSTRAINT returns_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE NOT VALID;
 F   ALTER TABLE ONLY public.returns DROP CONSTRAINT returns_user_id_fkey;
       public          postgres    false    3777    238    231            �           2606    31135    users user_room_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users
    ADD CONSTRAINT user_room_fk FOREIGN KEY (room) REFERENCES public.locations(room) ON UPDATE CASCADE NOT VALID;
 <   ALTER TABLE ONLY public.users DROP CONSTRAINT user_room_fk;
       public          postgres    false    238    2    2    2    2    2    2    2    2    2    2    2    2    250    3795    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2    2            �           2606    31140    users users_role_fkey    FK CONSTRAINT     x   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.roles(role_name);
 ?   ALTER TABLE ONLY public.users DROP CONSTRAINT users_role_fkey;
       public          postgres    false    3759    233    238            �   �   x�u�A�0�s~��M�j�F�4��l��U�6�%j���������<L���&��u�$_�u�@���Ϳ�7���>�Ʃ�0��o�(�RR�2U����w9���h��9�O�m��`j�=m?Jo*ݿ�ߍhe-TϪ�n%QrLp�������NӴVtK�      �   �   x���v
Q���W((M��L�K�I,.�/.)MI�+)VЀ�3StJ�S�������Ģ��̼⒢�\�:M�0G�P�`.NSsuG�����:a�pH������+\���EX��O�������9D��_��?����ݚ�� ��0�      �   �   x�}�O��@�u~���`��qF�Vџ�3P�VL'�F��ۧ=�l�����P���BI(^׻Ng����NsU�Dg�R%���F�T����#��_Ein���|
���=9�	c�)s��R����!`����i��<�_L��C�=�|oa�d[0�6ǃk����5��h��5fc^?��Zoc��`����'���߃��bw�l$�C�t��]��      �   f  x�Ś[s�Fǟ�O�o$3J����imd�FH�$��ɣ�j�c�Kf���71�!�=������g�uEV�iՠ�hJt��<�]���ܹC��.g��z����z3�N�bs�[&h�}i��/�]������	�������	�i�����u7OЪ[�Zw����U���}h�޸w������_�ַ����^v��rqI1eo�6����/oH��J��dpZٺ�����'i��St��^�yS湻��p��_�~�8�`Nީs���>���cVA�<�6)�\��4+F�nQ���ბ��AV��ӢAuSV�`��#�Dd�tK�e�#K�Ɏ��nϚ
Q���aᨒ�Ǫ��������� ����/��ʊ����B*���104����8�vCJ>�z�yZ�Yq�H1�9��(H�ׄ1=����r2*�4A��}&c���d�8:���P�C"qh$���_��C�xax �X�,��BJC���dPuT]U7!��N��Ӡ���2`r<K��ʅ��3��	�L�E�QiP��z�ؠ���n6��H��90�����#9�hjw�����u(aP�����y�c�F��_/����v9۬��k̈́�u������X��ԃ�����h[7
&�B�CXCi#ǖ���A���(�������82GE��H�#p$�;��a�Ac�d�O����-���5	g�����-��`AjR��t���;}}}X_�ׁ��
C';K/��8���$��!q0N�¸*_��XP��0,����8(��m�?Q�B.2[;ϳ�������*"�%�|�:XP$��o��&��r���]<�C��(m~Hd�g ���D�C��/L1�kQ,�<���{��J�7/*�e�B���c���UHq�L�Or�wq[5y:}g�*&��(R]�Λ���az{��I/��$�2�̂)�`�����ǚ�'Yh&�*��*CG`��Q��Kn�rδ^��!9��|:i+ν��a!����iP7��=��f�������3�Ë[�aVo���06��n���];[>~�q��S�0؅�׀���yo�h׿�+�$�E���c��@geq�gg��(���]���������      �  