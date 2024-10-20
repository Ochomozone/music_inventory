PGDMP         "        	    	    |            music_inventory    15.6 (Postgres.app)    15.6 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    30562    music_inventory    DATABASE     q   CREATE DATABASE music_inventory WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'C';
    DROP DATABASE music_inventory;
                postgres    false                        2615    30684    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                pg_database_owner    false            �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                   pg_database_owner    false    6            �           0    0    SCHEMA public    ACL     +   REVOKE USAGE ON SCHEMA public FROM PUBLIC;
                   pg_database_owner    false    6            :           1255    31724    advance_school_year()    FUNCTION     �   CREATE FUNCTION public.advance_school_year() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE public.students
    SET grade_level = (grade_level::integer + 1)::integer
    WHERE  grade_level::integer <= 12;
END;
$$;
 ,   DROP FUNCTION public.advance_school_year();
       public          postgres    false    6            U           1255    30685    check_teacher_role()    FUNCTION     '  CREATE FUNCTION public.check_teacher_role() RETURNS trigger
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
       public          postgres    false    6            F           1255    30686    create_roles()    FUNCTION     �  CREATE FUNCTION public.create_roles() RETURNS void
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
       public          postgres    false    6            G           1255    30687 
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
       public          postgres    false    6            H           1255    30688    get_division(character varying)    FUNCTION     �  CREATE FUNCTION public.get_division(grade_level character varying) RETURNS character varying
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
       public          postgres    false    6            9           1255    30912 *   get_instruments_by_name(character varying)    FUNCTION     �  CREATE FUNCTION public.get_instruments_by_name(p_name character varying) RETURNS TABLE(description public.citext, make public.citext, number integer, username character varying)
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
       public          postgres    false    6    6    6    6    6    6    6    6    6    6    6            I           1255    30689 /   get_item_id_by_code(character varying, integer)    FUNCTION       CREATE FUNCTION public.get_item_id_by_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
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
       public          postgres    false    6            J           1255    30690 6   get_item_id_by_description(character varying, integer)    FUNCTION     Q  CREATE FUNCTION public.get_item_id_by_description(p_description character varying, p_number integer) RETURNS integer
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
       public          postgres    false    6            K           1255    30691 3   get_item_id_by_old_code(character varying, integer)    FUNCTION     !  CREATE FUNCTION public.get_item_id_by_old_code(p_code character varying, p_number integer, OUT item_id integer) RETURNS integer
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
       public          postgres    false    6            L           1255    30692 (   get_item_id_by_serial(character varying)    FUNCTION     �   CREATE FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO item_id
    FROM all_instruments_view
    WHERE "serial" = p_serial;
END;
$$;
 ]   DROP FUNCTION public.get_item_id_by_serial(p_serial character varying, OUT item_id integer);
       public          postgres    false    6            M           1255    30693 (   get_user_id_by_number(character varying)    FUNCTION     �   CREATE FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM all_users_view
    WHERE "number" = p_number;
END;
$$;
 ]   DROP FUNCTION public.get_user_id_by_number(p_number character varying, OUT user_id integer);
       public          postgres    false    6            N           1255    30694 &   get_user_id_by_role(character varying)    FUNCTION     �   CREATE FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id INTO user_id
    FROM users
    WHERE "username" = p_role;
END;
$$;
 Y   DROP FUNCTION public.get_user_id_by_role(p_role character varying, OUT user_id integer);
       public          postgres    false    6                       1255    30695 1   insert_type(character varying, character varying)    FUNCTION     �   CREATE FUNCTION public.insert_type(p_code character varying, p_description character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO types (code, description) VALUES (UPPER(p_code), UPPER(p_description));
END;
$$;
 ]   DROP FUNCTION public.insert_type(p_code character varying, p_description character varying);
       public          postgres    false    6            W           1255    30696    log_transaction()    FUNCTION     x  CREATE FUNCTION public.log_transaction() RETURNS trigger
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
       public          postgres    false    6            O           1255    30697    new_instr_function()    FUNCTION     �  CREATE FUNCTION public.new_instr_function() RETURNS trigger
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
       public          postgres    false    6            T           1255    31646    new_student_function()    FUNCTION     /  CREATE FUNCTION public.new_student_function() RETURNS trigger
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
       public          postgres    false    6            P           1255    30698    return()    FUNCTION     �  CREATE FUNCTION public.return() RETURNS trigger
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
       public          postgres    false    6            Q           1255    30699 &   search_user_by_name(character varying)    FUNCTION     �  CREATE FUNCTION public.search_user_by_name(p_name character varying, OUT user_id integer, OUT full_name text, OUT grade_level character varying) RETURNS SETOF record
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
       public          postgres    false    6            S           1255    31721 $   set_user_role_based_on_grade_level()    FUNCTION     �  CREATE FUNCTION public.set_user_role_based_on_grade_level() RETURNS trigger
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
       public          postgres    false    6            R           1255    31521    swap_cases_trigger()    FUNCTION       CREATE FUNCTION public.swap_cases_trigger() RETURNS trigger
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
       public          postgres    false    6            V           1255    31529 K   swap_instrument_numbers(public.citext, integer, integer, character varying)    FUNCTION     �  CREATE FUNCTION public.swap_instrument_numbers(instr_code public.citext, item_id_1 integer, item_id_2 integer, created_by character varying) RETURNS void
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
       public          postgres    false    6    6    6    6    6    6    6    6    6    6    6            X           1255    31719    update_students()    FUNCTION     �  CREATE FUNCTION public.update_students() RETURNS trigger
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
       public          postgres    false    6            �            1259    30913 	   equipment    TABLE     �   CREATE TABLE public.equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);
    DROP TABLE public.equipment;
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    30918    all_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.all_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    235            �            1259    30919    instruments    TABLE     �  CREATE TABLE public.instruments (
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
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    30926    users    TABLE     x  CREATE TABLE public.users (
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
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6            �            1259    30932    all_instruments_view    VIEW     "  CREATE VIEW public.all_instruments_view AS
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
       public          postgres    false    237    237    237    237    237    237    237    237    237    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    238    238    238    237    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    30937    students    TABLE     0  CREATE TABLE public.students (
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
       public         heap    postgres    false    6                       1259    39772    all_users_view    VIEW     �  CREATE VIEW public.all_users_view AS
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
       public          postgres    false    238    238    238    238    238    238    238    238    238    240    240    238    238    6    6    6    6    6    6    6    6    6    6    6            �            1259    30700    class    TABLE     z   CREATE TABLE public.class (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    class_name character varying
);
    DROP TABLE public.class;
       public         heap    postgres    false    6            �            1259    30705    class_id_seq    SEQUENCE     �   ALTER TABLE public.class ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    215    6            	           1259    39811    class_students    TABLE     �   CREATE TABLE public.class_students (
    class_id integer NOT NULL,
    user_id integer NOT NULL,
    primary_instrument character varying(255)
);
 "   DROP TABLE public.class_students;
       public         heap    postgres    false    6            
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
       public          postgres    false    215    215    238    238    238    238    265    265    265    6            �            1259    30948    dispatched_instruments_view    VIEW     W  CREATE VIEW public.dispatched_instruments_view AS
 SELECT all_instruments_view.id,
    all_instruments_view.description,
    all_instruments_view.number,
    all_instruments_view.make,
    all_instruments_view.serial,
    all_instruments_view.user_name
   FROM public.all_instruments_view
  WHERE (all_instruments_view.user_name IS NOT NULL);
 .   DROP VIEW public.dispatched_instruments_view;
       public          postgres    false    239    239    239    239    239    239    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    30706 
   dispatches    TABLE     �   CREATE TABLE public.dispatches (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    user_id integer,
    item_id integer,
    created_by character varying,
    profile_id integer
);
    DROP TABLE public.dispatches;
       public         heap    postgres    false    6            �            1259    30712    dispatches_id_seq    SEQUENCE     �   ALTER TABLE public.dispatches ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.dispatches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    217            �            1259    30713    duplicate_instruments    TABLE        CREATE TABLE public.duplicate_instruments (
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
       public         heap    postgres    false    6            �            1259    30720    duplicate_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.duplicate_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.duplicate_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    219            �            1259    30952    hardware_and_equipment    TABLE     �   CREATE TABLE public.hardware_and_equipment (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext,
    notes character varying
);
 *   DROP TABLE public.hardware_and_equipment;
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    30957    hardware_and_equipment_id_seq    SEQUENCE     �   ALTER TABLE public.hardware_and_equipment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.hardware_and_equipment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    242    6            �            1259    30721    instrument_history    TABLE     x  CREATE TABLE public.instrument_history (
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
       public         heap    postgres    false    6                       1259    31547    history_view    VIEW     �  CREATE VIEW public.history_view AS
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
       public          postgres    false    221    238    238    238    238    237    237    237    221    221    221    221    221    221    221    6            �            1259    30727    instrument_conditions    TABLE     h   CREATE TABLE public.instrument_conditions (
    id integer NOT NULL,
    condition character varying
);
 )   DROP TABLE public.instrument_conditions;
       public         heap    postgres    false    6            �            1259    30732    instrument_conditions_id_seq    SEQUENCE     �   ALTER TABLE public.instrument_conditions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_conditions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    222            �            1259    30963    instrument_distribution_view    VIEW     �  CREATE VIEW public.instrument_distribution_view AS
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
       public          postgres    false    237    237    237    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    237    6    6    6    6    6    6    6    6    6    6    237    237    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    30733    instrument_history_id_seq    SEQUENCE     �   ALTER TABLE public.instrument_history ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    221                       1259    31155    instrument_placeholder_seq    SEQUENCE     �   CREATE SEQUENCE public.instrument_placeholder_seq
    START WITH -1
    INCREMENT BY -1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.instrument_placeholder_seq;
       public          postgres    false    6            �            1259    30968    instrument_requests    TABLE       CREATE TABLE public.instrument_requests (
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
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6            �            1259    30976    instrument_requests_id_seq    SEQUENCE     �   ALTER TABLE public.instrument_requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrument_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    245    6            �            1259    30977    instruments_id_seq    SEQUENCE     �   ALTER TABLE public.instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    237    6            �            1259    30978    legacy_database    TABLE     S  CREATE TABLE public.legacy_database (
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
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6            �            1259    30985    legacy_database_id_seq    SEQUENCE     �   ALTER TABLE public.legacy_database ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.legacy_database_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    248    6            �            1259    30986 	   locations    TABLE     \   CREATE TABLE public.locations (
    room public.citext NOT NULL,
    id integer NOT NULL
);
    DROP TABLE public.locations;
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6            �            1259    30991    locations_id_seq    SEQUENCE     �   ALTER TABLE public.locations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    250            �            1259    30734    lost_and_found    TABLE     �   CREATE TABLE public.lost_and_found (
    id integer NOT NULL,
    item_id integer NOT NULL,
    finder_name character varying,
    date date DEFAULT CURRENT_DATE,
    location text,
    contact text
);
 "   DROP TABLE public.lost_and_found;
       public         heap    postgres    false    6            �            1259    30740    lost_and_found_id_seq    SEQUENCE     �   ALTER TABLE public.lost_and_found ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.lost_and_found_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    225    6            �            1259    30992    music_instruments    TABLE     �  CREATE TABLE public.music_instruments (
    id integer NOT NULL,
    family public.citext NOT NULL,
    description public.citext,
    legacy_code public.citext,
    code public.citext NOT NULL,
    notes character varying,
    CONSTRAINT music_instruments_family_check CHECK ((upper((family)::text) = ANY (ARRAY['STRING'::text, 'WOODWIND'::text, 'BRASS'::text, 'PERCUSSION'::text, 'MISCELLANEOUS'::text, 'ELECTRIC'::text, 'KEYBOARD'::text])))
);
 %   DROP TABLE public.music_instruments;
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    30998    music_instruments_id_seq    SEQUENCE     �   ALTER TABLE public.music_instruments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.music_instruments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    252    6            �            1259    30999    new_instrument    TABLE     /  CREATE TABLE public.new_instrument (
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
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �            1259    31005    new_instrument_id_seq    SEQUENCE     �   ALTER TABLE public.new_instrument ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.new_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    254            �            1259    30741    repair_request    TABLE     �   CREATE TABLE public.repair_request (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    complaint text NOT NULL
);
 "   DROP TABLE public.repair_request;
       public         heap    postgres    false    6            �            1259    30747    repairs_id_seq    SEQUENCE     �   ALTER TABLE public.repair_request ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.repairs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    227    6            �            1259    30748    resolve    TABLE     �   CREATE TABLE public.resolve (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    "case" integer,
    notes text
);
    DROP TABLE public.resolve;
       public         heap    postgres    false    6            �            1259    30754    resolve_id_seq    SEQUENCE     �   ALTER TABLE public.resolve ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.resolve_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    229    6            �            1259    30755    returns    TABLE     �   CREATE TABLE public.returns (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    item_id integer,
    created_by character varying,
    user_id integer,
    former_user_id integer
);
    DROP TABLE public.returns;
       public         heap    postgres    false    6            �            1259    30761    returns_id_seq    SEQUENCE     �   ALTER TABLE public.returns ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.returns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    231            �            1259    30762    roles    TABLE     }   CREATE TABLE public.roles (
    id integer NOT NULL,
    role_name character varying DEFAULT 'STUDENT'::character varying
);
    DROP TABLE public.roles;
       public         heap    postgres    false    6            �            1259    30768    roles_id_seq    SEQUENCE     �   ALTER TABLE public.roles ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    233                        1259    31006    students_id_seq    SEQUENCE     �   ALTER TABLE public.students ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.students_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    240                       1259    31502 
   swap_cases    TABLE     �   CREATE TABLE public.swap_cases (
    id integer NOT NULL,
    created_at date DEFAULT CURRENT_DATE,
    instr_code public.citext,
    item_id_1 integer,
    item_id_2 integer,
    created_by character varying
);
    DROP TABLE public.swap_cases;
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6                       1259    31501    swap_cases_id_seq    SEQUENCE     �   ALTER TABLE public.swap_cases ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.swap_cases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    260                       1259    31538 
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
       public         heap    postgres    false    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6                       1259    31537    take_stock_id_seq    SEQUENCE     �   ALTER TABLE public.take_stock ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.take_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    262    6                       1259    31007    users_id_seq    SEQUENCE     �   ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          postgres    false    6    238            �          0    30700    class 
   TABLE DATA                 public          postgres    false    215   �o      �          0    39811    class_students 
   TABLE DATA                 public          postgres    false    265   �p      �          0    30706 
   dispatches 
   TABLE DATA                 public          postgres    false    217   q      �          0    30713    duplicate_instruments 
   TABLE DATA                 public          postgres    false    219   �q      �          0    30913 	   equipment 
   TABLE DATA                 public          postgres    false    235   Zv      �          0    30952    hardware_and_equipment 
   TABLE DATA                 public          postgres    false    242   ��      �          0    30727    instrument_conditions 
   TABLE DATA                 public          postgres    false    222   ��      �          0    30721    instrument_history 
   TABLE DATA                 public          postgres    false    221   O�      �          0    30968    instrument_requests 
   TABLE DATA                 public          postgres    false    245   G�      �          0    30919    instruments 
   TABLE DATA                 public          postgres    false    237   ��      �          0    30978    legacy_database 
   TABLE DATA                 public          postgres    false    248   -�      �          0    30986 	   locations 
   TABLE DATA                 public          postgres    false    250   _      �          0    30734    lost_and_found 
   TABLE DATA                 public          postgres    false    225   A      �          0    30992    music_instruments 
   TABLE DATA                 public          postgres    false    252   [      �          0    30999    new_instrument 
   TABLE DATA                 public          postgres    false    254   �      �          0    30741    repair_request 
   TABLE DATA                 public          postgres    false    227   �      �          0    30748    resolve 
   TABLE DATA                 public          postgres    false    229   �      �          0    30755    returns 
   TABLE DATA                 public          postgres    false    231   �      �          0    30762    roles 
   TABLE DATA                 public          postgres    false    233   �      �          0    30937    students 
   TABLE DATA                 public          postgres    false    240   �      �          0    31502 
   swap_cases 
   TABLE DATA                 public          postgres    false    260   ��      �          0    31538 
   take_stock 
   TABLE DATA                 public          postgres    false    262   ��      �          0    30926    users 
   TABLE DATA                 public          postgres    false    238   E�      �           0    0    all_instruments_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.all_instruments_id_seq', 350, true);
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
       public            postgres    false    237    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �           1259    31051     fki_instruments_description_fkey    INDEX     _   CREATE INDEX fki_instruments_description_fkey ON public.instruments USING btree (description);
 4   DROP INDEX public.fki_instruments_description_fkey;
       public            postgres    false    237    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �           2620    30795    dispatches assign_user    TRIGGER     o   CREATE TRIGGER assign_user BEFORE INSERT ON public.dispatches FOR EACH ROW EXECUTE FUNCTION public.dispatch();
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
       public          postgres    false    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    3763    235    237    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �           2606    31080 (   instruments instruments_description_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_description_fkey FOREIGN KEY (description) REFERENCES public.equipment(description) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 R   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_description_fkey;
       public          postgres    false    235    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    3765    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    237            �           2606    31085 %   instruments instruments_location_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
    ADD CONSTRAINT instruments_location_fkey FOREIGN KEY (location) REFERENCES public.locations(room) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;
 O   ALTER TABLE ONLY public.instruments DROP CONSTRAINT instruments_location_fkey;
       public          postgres    false    237    3795    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    250    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �           2606    31090 "   instruments instruments_state_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instruments
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
       public          postgres    false    245    3765    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    235    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �           2606    31115 )   instrument_requests requests_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.instrument_requests
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
       public          postgres    false    238    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    250    3795    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6    6            �           2606    31140    users users_role_fkey    FK CONSTRAINT     x   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.roles(role_name);
 ?   ALTER TABLE ONLY public.users DROP CONSTRAINT users_role_fkey;
       public          postgres    false    3759    233    238            �   �   x���v
Q���W((M��L�K�I,.V��L�Q(IML�H-�����y����
a�>���\�:
��f:
�N��yy�y�
N�y)
�:
FF&�@�T]S���Rs����Z`�5��u��KN-*��4�TiW�ZQ�Z����W��񘺦5 ��E�      �   ~   x���v
Q���W((M��L�K�I,.�/.)MI�+)VЀ�3StJ�S�������Ģ��̼⒢�\�:M�0G�P�`.NSsuG�����:a�pH������+\���Eؚ�� ��*�      �   �   x�}�A�0�s���Vmn��ԡC
Y]e��A5Q;��S#�]ߗ���;D��t�Ct��zew���T��K��J�Z�V�l�U�}�[�H�m�FP����]�}�,V4,)���£b����!`D�]�4yi�$� d �k"#K�'�f�Q���Ϯ	#�k���1�k���iF	���~�`����'����o�� a�{�      �   T  x�Ś[o�6ǟ�O�7����~���X��ʒ!������s�̗���q��U�	@�!e���qx�T��N�eES�����������]�Mw5_�7��M�ܬћ�,A����n��E������v�g{3_�'��g;���'���s���n��u����z�h���w��Ҳ�q�X_�u{��ZonW�w��6���b�ޢ�m>M볟ސ1� B�bp^ٺ�ESMǓ�I�9z����ySnUL���Kb������M��G0'�Թ��k�r�1+� �>�6),.�q�#[w(ZO���HB�A� +j��iѠ�)�t���y"2O�-�1Չ-�d�vdw��B�11x�8����u��u��u�'��/'��K�����?�ߤ�
��$�k��aq0<ƹǐ�O��y��uV\>RF�bμ(2
���5aL�f������"M�u��ɘ�,Y/���1q8G�H��2��b�5^��	��u}q!�!��V2��
�������U'A�iPu�^h09�%�m�B����c����4��`=vj��P�r7��q������po`��`4���B���M�:�0�BT@X��c/F��߬���k��o�pϵf��:�QEcGB,�k��XTL	�e��g!�!����S[�?Ѡ��b������H��"qt$���8A�0ߠ1D2�'NC�CY��
��g�����gd}
�B���y� G5��|:L��YsB𑓾��������n�������L^�{M^���8'Oa\�/�p,(U^��`D�w�6ӟ�L!��������^�`̍W�H�咀�v�?\-(k�7KIN[9�@�.��!l�6?$2B�3���IE"q��!����5�(EJ�=�q������2O���va�1W~�*�8X��'9仸��<�>�3M^��	����MAsr�0�3�O珞_jL�Sf��y0e�����SM���,4�^Y���#0Lx����F�%�]9g�/���x搜��s>���^�ٰ���ጀA�4���a�\N��V	rvrc����͉��0�wH�o��[�Uw��W�?e\���)���5�.h(Bއ!��/���g�٢DUY��1~=;;�G�߻      �      x���K���מSp�=�V��*��H�H�� ���7Y;&B�dK^�(>�/�d��O�f�P��1�H�g"� ���S������?���?~��?�����?�<~��)�����ӿ��?���?�����_~~
~�����ן~����O����_~�����E�Y�x����\c�o�JI�M?+��X����d[n���S�ʣ,)�RdG���r��pk]�x�k���A��B9�?UP��@��sI��O(p�@�bн�W��m趵c;E��T�RO�����}��@M0P���^����	�XM0V!��l�J���˪ L/��f�n�%>x�mnG����2�JQo8�����wU ���e_�# ���KKk5��{�(t�mʊ�����R�2�s�I�4��oް�;�z��`O�	|0�3`���L[�0<�m߭��~s��n�~hl�bP�@+q���0j��(���$�AS
�����ER��=Rs7���y��3N��{z�����,C���f���п����F��6�2z��>RJ{)���g@�ۭ�rm<���8�V��#��H�����T�+ m^��]*�/ ��b�d1�f����F�z�Qb��G�g<�.�Vsc�DQHv�}��� tIaL	�A'�\�Ŏ&kT�Ik[����ͣn��L]#��]�Â���aГ�HPJ�7��a�`�����v���� �dK�w�<A�e)l+3�I4�]6���K���~�fC��������i�~Ռ�����0 ���!l��R���A�ar�'�!����W�
�{��>s�B؛�,�x�l<�n��M��BCdKB���H�
�d������%�'�z��6
�U�u	;pt `�W����Z�ٽ+��hSJ@<L\��dG��� ��J��	���k�J-�zo�F��U
T��
���NL�U"H]T�U��O(�Եm�tib�F:uͿ0� ڬGHwR���Z�F�i���2h�ʑ)@�USW��?5�"=�5u�Њ����.�Z�KM�T�C���:he'zAܬ��/s%��  ��4�+s�����8�g��;� �5;z�L�ڿ��"x\�I潾�1�\v����ش�-K��+�QL��N��"0�B��|q?"n��h��Բ���ʹ�\�l�=ՠ�3W�p�I�q�`&)��������$r�UN?��jl��b�3��{�*&�Cìj׉Q�$�E�J�K�F	C�4u��\YLC�l���"��Շͼ��iIk��ȸ��	�%gO�cŌ�f	er��:�I�7
g�0t�vt�oȸ
�`S�lEU!��dC�PLZ��������D���
Yg���f��p?�J��<ΨQ���nV�?��'�.�fEW<�b:�ާ<dͷGٗ��4h��t��X<)�zۅe����W�;W9�U"O�^���;^ŕȚ�RS�-"�<Έo�S�X�\�Ȫ
L-l&�[V8h�+�L��r5��"W!v�6o���*r��h�1ˠm肑��+�+7
�>�"d�J�Y,�(�����Tb�ص���=��k�e�Zn��<�f��Į�Ψ�S�yK{�v�'�mdn�����n��i��l�]��O�eؕv�p����x׼�*Js��MG������l������Z~��Rh���Ş��:�>�9�1Şi��<zL�)v�Nq6&�^�z?M���q��]�[�f8�S�����[W�7�yX�e[O�t�3��$M8��aO�4t>��&t��'y�s�P�d]u5���e`o���+��Y�dl�^�� ʹ��[kQbz��?Is9(�^�9G��GԘͭP�Ӏ@=�.�Z�VZ���%�m���p��R��Df��6���k �qZ��y
���_]9L�N��s;�3�)rqn��Pt�0�9,�0������e��j�%>p\� (�}BA�R��U�Ov\+��L�
s�=
�����W{�ƪ�����2MڟȲ��(��|���Q�(��cg���p�"ܣD�J]S�-�/����EpS����aS�I�7P�M�=ʢЯSm��N���G:�(�=��l�R�c��7�,Q�{�e�Tːds��e��~ާ=	p��NP �
��P�X�T���)ۧ>V٭P�u4o�%N�	*�db��ֽL�N����0�{�%�qƲb)i����C��%��L< ���!�x��b�KC/(
��NT+��I0��
>�j�4�si쿂M?�a�vH�^.��K�F)�>y��+���/!t�J��~��{=��ũ+�+�.-�n��I�׏�6�*�D�Q�_@�<�Wq�F�̯�S�y�%�!*�	3��|������sP��}A���c��A�II�&�;�_:�P
aJ��u�Ԟ_@nb~��5�>�`F�����l)��u�±��R��:p3;H��`7��A�i$BN@��m#����_�z��Ƨ�w������Wjt�h���g]���0�w��v�"6R	kKh��E����ω�h��V3����bn���Ԅ����q٥ɏ�b)��#
�����?E���~h�o'O�0潡�tĞ��l�\8Et%{֝K�u^W��½��m���Sua�iO�^X ۧ����z��VW�!��c]��J��h�e��J�Ý�(
��c�r@0��]�^���$Ba�����(BI�N1EP�L���s[��h��$=���(B)t`�dQ�B�i��szPM�����g|�[�h���m���s�Η�~~�G�Ƒ�O����~��Ag���=��e��SNm|n1^����])�#��Yכg�H���O�\?��Ję�Rb���ܲ��w��ϧ�-��;:r�e�-:�����`٢n���B^`~a�v�N���񰴣0�;���|��^�NX��X����.���(��fe����w�d^&FG��^/�gؑwV��<tV�=5^vgF���k�z�%�ջ�k��k8N��>��b�m�������xz^(vz~ǈ\Tc3���
e��"a�@O�A�h��R������z_�2)g�X�|���	V��;0L�k}����rI��&XK�~�2��5����Z*��!�P3�ܔ7�|�~��:�㠃�,�B��V�]�ߚ���z9��لh�%p�e���dηwdp��oH}��	s�=W�Z���J����X��_� +�*��%\zWЙM,�c�p�]Y6�X8�+���A0P%\b��Tc��B|T��́V0=K�T��*9(:�S�pօ�m2z'�3O���b����)7�BZ8�>S��pP�r��� ���Sn�3�hk8�5�qS_�3�aYN�����i��N@��XG��	^6ˉe���S,=袖vn�5̺�E]�%D�I�^U�;t�������o�q	uR��Q�Ó�Q���"`<�e\4v�)'����i|�4ʸ�eo�����I�M?�>8�xD?ϸ��$���yd�ƍ46�Mc1�1�ȸm�,]�l�%�p�\ �⸊�7�B7�����6�\7���=�X�7��oh����ٍ+���o�u�'0�G��'���_��p��]��_X!�7\@�rIlR�q��������<�-�x��|��x�#]�]�k�jc��pᑽ\�H��N��������M�Ǜ�k��gÏ�6�!7�����G5oG$�}Yk�<�k�����H/�Yq{���a3o����=�y{G���|��]/�<�/ǭH.wY<.Wl��yc/��^�.��8����F%F��m-X���0�K�n̴�]hm��^���,�(I-`�l�>O���b����s�v=
�vs؟���Kd���၇��~0�'o9����C�$ye���|�����#r}#�aZ���1{����9�>���S�!����<���Prv��
�1�_bb���N�������S���%m����p�
��/���A���;�}[O�=�Y�x��Bɪ����]Ȝ��~��<h� O_���5M�?1�0�O|%]�%��xCamy��u*��4��n�eB}��(:+|�s���
��5��w����m��x��    �dA���>�*��>�J��~      �   (  x�}�[k�0���S�7�PwgOizа4�\�>��Ͷ�V�᷷�ch|	'��;!�p�Q��$�޿,���=���ƥYU��c_����A�,�f�rq P�m�)׻rUX��,?���pNk�ڹm�������p@��+�N]�|��.���ξ�i�ÿ�)=�cT�>��D��]Ot������\��+�
A%&V7nB�D���M1�uJ[m(�^{�fk"#c�U^z{��Vs�w�r�QD^s�f�z���1���'4���B���1E#�X"Y���<����<�O� 8DH��      �   �   x���v
Q���W((M��L���+.)*�M�+�O��K�,���+V��L�Q��5�}B]��85u��R��5u�# �=??�3���� < �%171=*m
�.�,IU�OK���|�K�5���� ��*�      �   �  x����n�8�ϛ���-�!8rH����!��$�^�Q�Fkɰy�����Z�M�(�d�㌆�������Ô�N��l����b�eݬߖE�<�uS��ه�˘5뼬�Y�����}U]Y,��ɗ�1[4��}�����������sS��l]������}�fy���Z����1[�ۺ���?��������������~q�a�Ց�,�Tׂ��b�2i2P:��@��1�<���>G�~��K5��*���46�����4��INS.���h:CD�����q*�j6��=<��i��/y]Ԭ���V�{]WKfYS1�U3���7$Җ*�����;*�SMK����"=O5)T�	�@re���XmJ���X]"������X�H�p59V�Tj�`2!9�B^���p���ݿ5]�Ln	m��0j��(
���(�.�Z (���!ڇ&U>g��:�(�Q��m��8��R紳?#��@	$.J��y�4�0�L�VB\���V�]��Q��Զ@%ȁ�P4�݈Ѕ#dRs+�m� YH݈: :�S����dl@u����&��~�^���h;�AIV�X�b]�G���:���Hx��Lx��%�q�E�i/��)
��vPA\Q8Z�>���Jh� �E�h;�!I�T����8�6��-�jT;$�tR��������n��dgD���SQ'S
�z����W��HT ����4��󚍿��\Xo��p�M�s[����#���*_���(���$x�@�]�s�M�_ou�r6��o�zeͼ`�{��Q�BF�������7�){��?܌��増����m��ҙ߽,P8)�����e2%�w�n�KV8P�M��"
k�Iƞ=���t˳���p::�;82gϠy~�&g@ug�h��S��\	i�gV���r睡L=�8�Q
��2����3�<ﮀ[K躓X4����Zl:��ݏ��8�S����B��3�OWWW�Po�      �   d  x��T�O�0^�
��`����i�x@�����SR���&#q��i�����RR�Jh/v|9�g��nN�o������j�E΋�	u��e����Mh�Q1IX^�,��8	k_���&;a�mV�",ք,�M��<�M�h�"�Z�(��c$���X�a�j�S�O�X��`�j��p̾=�;�|:�.aCH'B��a �P)(��X���&��������A����zq9��M7uy�X@"�x���l��e��@�ɒ��j�W��CQ�]��f�2�U�js�ot�} %re��؁<N:2��Gb�Jq�@����*+M��٤��g���3_V�t��5��>�gˎ�sDX������h���f�St)h������MEې#�ÙD2��� ���!C:�%9aᅌ}�R$��;�������k:��5�(z9݇�y�ι:�5��r#��[ ���{����:���ᤰ�Sk�$Z"�-��A�n��ّF�J�Rr�Р;�Bd��˕%��w�뽘{܉(%��E�h�=����Jin�Tʾs�⣹n�-�R��`��5��q��}�@Щ��:2��BB�"i?�Ƈ���5'c�]��e0�\��$      �      x��}[S#I���7�"�[�ՌY1�qˋ�SJJ@��H����15hm����=5�~�=�L�{��z�1�j�yFd�_����lƋI���/�뫿�7�O�w���c������v�}y����_V�����է�z�x����i}��=���[�ߧ�������������;�����~��Ӟ���}��[m����������7�>Ër����g�*�)�"��/��OQg�(��O���`Q�:�}rm��Σ��|Ѓ�/��������ܟ��-���O(*��L���/|���2��N�姨.&�W��/NUީ����Ũ/��b2+����E��=^��~-5-ZY�D;���?Gf�
�YH�tVk�s���K���.lQgq�-Ɠ����*[:+Gnt��\ݼ�0)'�aS�$��2�S�M%_g&�?�,�3<.f%��iY̆��h��d��~�i1����D��iא(��^��h����]L�w⬘G��;/{�H�r�g���F)��� ��%���h���0�
��+H�{ �ϱJ����T��=��@�� ~����!T�b��$&�'�HcRYf�����b��r6uQ��Of�Q4�^����jk��ݏN]��Nh�V���ϖO^��b�l��	Ls	F����o�� ����^}���Q�>�wv[@?�}�~�ڎ���~��jP��'Q�������e���QOf�������i���m0`r{�]�3���aA���կQw�|~��BT��8;h�5�Tܨ��c�2�\�����c.�="ݗ4�k4Ҿ��ٷ�Xb�f<��OQ��RX�����Ec��BSo�����_i#U���C���'�xd��ª�r�s��"l�[��2+N��ɕ:�d�\ZKe���AC���i��u��a�/�W̅1�A�z1��O~,c�s�l:��ϴu��J�����_����	�厈u��h�'�etF���p��B,���~�ۍ��0Fs��5Ԥ;qT)%��ĄW�1D����A�7nöت��P��9̝��V��;�=���K��R1'"����ϊ�`ƹ�B1�c������s���خ;Ļ	fnn�^t/����lR�tݟ�;��B,��s�U�%IR��]�\d.b�X��M�__%ۯ���J�C'[����ya���lP�~�<�������?6��~碅Wq� �3�p7�O>E����t�/w:+z�m+��d2���(��Z�Ǎ7���o�{9���^E	�?�����¡����.���hT�z��Fw����!�/㜶N�g�i~�����A~�N�ᱻ�Y���_b���	+B@-����}a���q2a�����I4?-��Y+�ڹ�2���ő4�)KAǍf��5�h#Ȇ�������p���):]n�oWm�b���Yx{~N�N���� �!�:p�!C�y���85��ϫ.A7��Xm�W�h����}|Z^?�&�eMy��jR>�b�J��/�ڦ�Ɛ�S1�&�]N&��;���y����h~Y���o�F�]��z�q��7IZ�<c���]E������y��I�+��9����7D�g?A��wo�׻�Ն��g��g�eߚ�h0�����ZJź�"Ww��`�?�Z��<\ݬ����|u����Odਈ��[l68�
>V�u���[����J֞�o���w�j�a!M�A�0H�d�_k.@+�J`p�$U�[��^�n�v�Q26m�؁��r#�1�^���9#���!1���p	��`~nOz�R���F��q4-g�OO�D	ٶ�{*��x�K�㈶�^�:Te3'\����󕉃��u�ņ�W��C�lZs���i��t���K��Tґ>m�;>��->/�v'Ŭ�7�T�z�c+z6c��L��>_b��?Q���5{����G�~[ �"(L��ы�}MQ�r��e
�^��R����#��^�R����H�yM�V�9��y,t�=�R�7��`���#f*�.�/�-�	�2[k�T��Z�����.z�&����+d��K��k�_��u�#�Z5�Ep�/՟�h�Y�n!}��ƞ���X�F��(~^G�L��r�������Մo���f�;⑟�s�'��5Ϙ�'�~�'�k��hm{��ҷ�G-������nF2(��S|ы�hZ�P�yuV�u=j�pU��9��?<�k��w�zҺ��e��Lw槃r���y2����4|stҟ�6k��<fJPٿ����ֶSƌ4�X \�韡i9+G�@�ɚ��d�A�\�I�w� MJ*QBy�3�=�p��`pü�h+	�K��	�koX@��V�ȳ<S������I�����^��T�<����%�_!9���A/9��բ���O��J�d�F���3�%{�����A@A�L��'2U�2Q�x��	~��S�Y0z�_�$MӃ�D��V��n�dK����:9�:א��:�$��2��x�iwFb���Ki�8>�`הo��'�����~�HqТ��о2����$�R�����w��]ev�u����^3����g�����f��c�i�$}׻&��a�����*�A39��{hU�lGݳ<��A�OS���}��h��Zh�}���t
>Ϝf�� 8;c�s>�S��a�M�����L�������3��`�>̣#�n������� �z	P~�"��&�s�"�ȃ@��*¼�����ܬ�v�4����x�Ǌ#���?E���wN3˵+M?��O���L?��O:ja�A�T�t"DCF��' ���t�F�_��cR���|#ܶ�`:a�ЅP�,�㕃~���� C��c�P#�e7��?cz��`2�� l��=��[*��YY�#��E����������|Y�˗A%y�/�_�0g�Trf�Q?��a��X�� @�j�鸾��u�ʺ�d	�u���\`�\�p�*%����Π��
�g')%wW�=~��<�-7�0��Ob��.19�\���F�Y�;�h�Ŭ����Z�,/'�s,;/.���F��
�4h�`�^��\����=�O4�C�%�����XF�Q�����3������;l�TG�{OOKaP�UuQ% l ��"�*���{Y�(���M�Y��?�����=F�(s	%͍m��G�Җ�B���:Igڤ	���h@��D����u���������S���'�I����W���&mD̟[=DV�nQ��!9#1�:�ʛU�jSW1X�S�V�]��p�	6M�I<���a`IŰG�]?�����h�������� � ��f��O�/���D�<9"���p{�����c\���t�X�O|v�u�j��Ѿ�`kBbc�M��8,������˱Qi~P>��V��u�3#p�4F���f2\��ANz��HĻ�����g��j��!ֹ��,��;����j���@"���:�D�ˎQ��K_�ng4��(;�E�^l�aa"�D��ҏr+hk�b�5Oo�_�h4���<%f��'���c��v���\9�grH�(P$�����~Z�l��w$������/��H�,0�Np����^�L�F[�d���1�\X�p�D�V��ЇPB�����daK�p��[g��y5ͼ�lo������f�����=o�?�v@�D�/�>��B>����>
�{F\^,��;���G!�Ľ�ߣ�=���{a2�i�݅�����WF�������N�PoQ����v��WA�R�g:g���=�n��O��T��^-�1Y-OR�zs=�-*����J̝t�UMm����]�ŅT���a��k��Vԩ�q��f��ɬ%��Kns&)k�������cp���$�
�!�Hkou�Ā(�bX��j���EG�D�3�(#����/J]�nP�A�b�o��x2ۺ��>\3�?��ſ-������`��y�]�C�`�hpT1���J��w�Y��
�
�dW��G�6^��U.a�`i����    2�����@�ml�9q����$jKb�4�?���^��������]��o�M�?˫Ua���:}���"U����yǻ���QW��9�z���E�;�������^���z���V�m�P�

n������c�'�fj��W+�bi(55"SS�,F$�v�S���������N���f
-���!}[3
�W���uV�.�%�+q:;km˪	.���ҡ�~R����2�n�#ƉI�M:�3�tQ#C��:N(q��[lU�&KJ%c@	��Ӳb��.����FV��<��^1��v�R*з�:?�iR:z"�_S�9sw{c^��mzA�@�=��Vl�E��\�k��Mns*mO�����ؚ��.�FYN�[��%��y�D�,�uU�KS�6+T�I�b��8��!l��/��~�	g���0C�=��2i��|�&�a��R�T���n+`2q��Y�ݻ8SFO��Z�p�n��<K��J��G�����`Q��{,1U��u��@�j#c]������coHƒ~c�a���S�a�4�<�b*�X�M����ϓ�|{�����d��b�C��D�8���-fP�ƛ�N7]H���=���|�x�C��e�ޮ�ĘÙ]##*xB���e&ܙ�Y0�_K1�-�$��u���D�P�s���pҳԐ���^��Qj%�� ��x��4R�i@�m�n��Se�
S��: :]��B�;~A�bbl�c�74����`�x I�y����=������0�d�cVӜ*�¿�X2$�b�Kݢ��d�>����)��iv@OSU4	��0����ɨ�[�D�b��]<
���a++�/\f0�GV��&�{ '%�j- P�-ѵ5��6�y�]S�o���@�S��]��&��q�_�K��M�Aۚ�[De�ⷵ��io6N�9+8ͳ0�*�&�����uZ���p�Q�貗A�_�����٘��@ۯ��N�;���R��Jk���J��L�d�!D���X/P�����^��3T"�N�1O3Z�~�*D�-�O��Mt�~^��&n1��Ljx�Y�I��*�		I�D�0�!��eo�d�k�� Z��/��psPA�Ь�n�ea�t�5���P�ؽOck&g��R*0Id���U��Q:��./v����b��A�q������VNK-�yx�3��q�|�"�^�1'N���"'1�t�*�X�Wy�{�`�Fi>�{YF�D�8�� ���9�sn*��,:��{((��D�����y�Ŭ�޼�r2��-����6I[p����	R���6]��P�Q;^>=�-��+(a�"��d�e�P���]-�<�{K�x��ג���~�$�΅��>����w~m�x�><f3 )Z�4��,��J����s�'F}�'����a�*@;��$T���p"��Ę6fH$�$�p�ڒ�z���9%x����ר�\�7�;�9��O2���u�o�Վ@v�y>۶G�e�*���<����$�u����~1b�d�k�H�(9*�ʗ���X7��I�( p���M�h�u�(G��㣭�бYR��-O�e;qw���M��-�r��ŭ*�=Ls��+� SeI�<!�w��߿��O�R���ٽw�p��!��eЗ�ܰ�7��J��K��i9��6o��5�vZel�߫uE�׫�f�����0�>b\�[A_�u�Ⲃ��n�
Go72D��Ǌ�og��?0����G4b�ef����2!h�`�C\��yv�^4����������a-U��`Gm"�>Ի8���eɤ��1�7i�J,C�8V����Ȇ
&nxX�/��E��r0��3r.eCtN���6�e4z��Y>�W�L�� B�����p�$�&��i�i�_���/�l�\��8�)'^Ƙ���W]�_5���QYq�j��������Oq�$�j��Y�4�W�}����r�W���5$�����p��؊���2�����}).����:��Y�u`�eZwQ��"Y��`מ���
��c�S�~��Dm�g���6��[ζ��f)�$p�Uw�0Ӯ ۑ�����,�e��Ҵϡ��4�H�D'�l�J]EЛ������f���l��+w��4'T�$o3��	u�����a�M�/7�K��kb�g�ςD���9�#j�{C���C0XB�Es{�2�f�C:XG<&�>�>�2�0	�Q$�����iX�Plm�X��H��!�D!�8*�*��n�\�w����mR�y�nq'abQ�&Ӭ\ȉ�=��~|�I]���Ì/�0.Ue�+�-fC/*����.`�R�QeiZ]:A��̹�]��'? ��f2�/�C bEb�ɗO7���B��Ɖ}� �v[��^Pئa��ae���\�P#P��!�.jʔF��;N�!�9����+�\X�>m� �0m'�w�]��i��Y|J��n	�D���X����:8�͟����k��kh���S=�5�NL��V"�a�f�Z���(����O `�T,�帽��/ʈh7�t�m�����S�:"��?��]�̩tdb�c�h��x�̡����*�W���������_g��y�U%r:�U�-�I���<D|=���*N�,����ޮ� �A��r�����Z�/n�v���8[/�tw��8�nޭ.�Ap�uP�j�8�8؝GbKΏA�D2�!R�����tw2��_���N����1������,�c���Nt#���M$�-g���%���lmdb|��:�$���2:��}�����Q<k">�ӗ�����-?Qi{_g}x��z�eudU^�eW3�U(���<G�	3c#s2���I�/��2rg�I�-V��z�F��j^)X�Z���m��~�g�������k���;N����C�&���bA�Nw���ne�F�����C��s U�����N���\�!qN�;G1"�ڝ�_��N��������Fx����}�-Ь���~�x��!,��;���;U�9J���ʥ���	�w��f+~ǀ��ז����r!`|�$���"�.��w�t_f��+[��8Gvd8dA���`�9,�{�j�����̳�}^Egϛu����qM�V4���o�~�O_��UI�s2�m%㤀Ul�$f+�QQv�58B�}�V��止�݅D)����2rS��3B3���Jz%	 ]�C��-˓�v�I�+J�&�/r`��j�~�Lm$
t<6� O�:f�N):MKo��qzڨ��O5�@��a������y���	 ]��Z�E_0���,`	�����G� ����l0?uS ::����Y�U u�9C�w��?Θ^�D���l��ɗa,D܂�`t"�
̟�		N�Ҏ��[�r/�t`Ƃn/����X��z�?��ut������XzG�s��S��͊�p7��m�4i3[9��k��;�vg�g9]�?zX>M=��{Ŭ���x��j��ME-����0�'�"{�����E�\�0�=!s���N[J�B�,e,E��6np�O~ ڥ�������*Gz�n�H?U>���A��|��#�pdp��? ��<ö��o^-�1� �Fڶ��f��S����y����B��g82>���g�v͘8@O|��#�} !m�P��|'��Z{#�J��m|�cTeT<�U������N�Ʃ��ִӄ9%G��>���y��o��<�n�����AkH/&?[;HZ;���o�lhsV!a��n��+!������h<�k��T ���BEZ^c�SJ���� �z�h&d�5I��&�~R0�+	���\�P��+��"�S^'��v��S��+�,PP����q�x�����F�zǢ}pc�i��y�Do���-���l�w�HZ琥�5r��\�� ��h�8�tJ#��+��>(]q@2�v��]�_,�ΥyU�!03��g���e��S�/o������P��V�-c��3�����wa�H%7��[����N�?��OP��UZ�kO����*UlgL�-�(�CN����t    M*���0�*��c���	z�yi�(
�8���qИt4�8�9i����L4<�$�Q��@��6�*��D��|fr�ɉ��������&W�njݔ�H�%�ܲk�JY/4��N�򝺧[� ؐxH��A��f��xBb��;ܶE#��6]�CHa�\i�|��H��͟�w�awK�`ϐ_�M?��~�� p�e�'�v�!�"wU�w�t��a�bc��s��p�Z'zP���acJ��!$��
�ΰ�iX��~���2x�°}|�B$�:@t�l1{a�s�I?Ȁ�-���+��}XO[�L3�����a�"��^��n��>v�w��Ї\Z�to2�&��a��kV�"-y�����}
<���G0��؝;�[.��-��=�ͱ��rU�YZo��Kj���y�C��h.�K��Y/^=������Ϣ{#���Oj#<?T*�K �j�Z��3�W�����U�W�oTކ�] 5c�u3��7
&�B��W��ї�D
}�F7_/���@j�SF}�G��Q�������v�����,����2�{(��Ƌ�t�H0R���f�����t��|�����=�#��$�^Ex7a�l�n�SiB�_~��T_/ȃ�n�Gæ�9@��kX���x���F�v�T��B�W��P`�O�fz*i�d�L��t��=^2?�����Ge����v;�N*v|�L�
���|���P�H%p�.�:�c��%��W2}��k�_e��`��L_�]B��B�,=�7U5��O�%�Pâ�8�GٓJ��$�4��Eqز
�~� :�2a=�C|���Fo8��d\���7d�m���aYr ����D3�i�W��%*�ڽ��N��4��,�EC�S9��|��{'ie� �Xz��Yt�t�
H!��'��D�\�M]�)�҃���mq��,�!ā�x"d�ܷ�h��a���r�8ܒ�,���B�=uț���P��T�r�)@��^�;Wo2��T�sp��`�lҝ���t�]��~�dr²��
9q���2�^o2ܒ� vW�mC ~3�MB��^~��M�y �N(6C�� ��$K�.��P�5!.yYh�3O�d��Z��*@��gE�*�8
��ٝtg���(-"��/��'�O \��y��~=�ܒ����Xc���;_o�a
n`y�ǟ����R�3S㰕6f����!w��V���h	a��H���ά�vh�Y�IЭX|�u�z/��Ĉ�5�Y��Q�	�$�e��@���9L�8���t�K/N�! I+�#���:�e"3ϑ�C��{Y*����_��+Y����5X�����~��?-RY��3��(����4A���CW��_��	oƨ,Ly���dz�a�F���'���6���=���$���G@j��V��˪�����~�����XU�y��	��D;��
��86y��ɢ����ÌQ@J߅���d�����d&�)0�$o��Q����k$_ݑ=����^�͝�z�ƿ@$�7�xK���9��UT��sе-����m8`��k�l��ڱ���:���[9��'�êM��ɡ)`��w�n�R��v�û��fv�	�j4��2&��GH�l桻�yf�E�`����������&Q�th�g����pT��?nV������q��t��UÔ8����sD ��K;_/7���y�/Dnm��Ҕ�7� ��o�`8�����7��<�'�I:��w��þi :W�M� �i�V�i���Sf�G��:z��$�X�m�x�ՒX;ǁ��E~%��0Y+7&�6�;L=�%�I��ӹ48�������@��L틑C,t��R�y�Ǽ,a0d���ct���}�y���5�)� �
���<	\�y�lq��f��X.��;V"�\7/�7\�o˻��!/7��E��n�
���:6"Lt�1��;�|Z��?]#֙jAP�/�g.���O<�(�a��{h���������|&������2:^������
��P�Km���=�㗾=�i`D��[�q��&׫�eu7
�9�(�]Kֶ�W�x�9]�THa�Ҟ�ͱ��!���Ym�����[���t]�F@?j����U8� "�� �g���X4?�(�3�y�.�l�f��5�I�sS��H:xa��;�42�F�z�pY�{ �Z:��Q)�c-y�Z.�.�<��QB����A�\J� `N��}*#�pU�8���U���/�`���#�(v�U�/� 4� �jci^��O.��OdZ��I%�Ɔ�0K��5f=�SeL����e��a�./��HJiׄ���vkr��
��?����ǠS3������kE�RN,�������C�E���,R'j���C�l��t�����N'�s\�=V��н�~� !+�CEA�-�m�5���m��͘�$������}�(���_�Mz�7�b�`!�Z�]Pf�Ȟ����v��r�cM�O+��Ե�)4�9A(��z��&����7�W����r�����nI��8l��tYԋ7	����P<ڽ��N�\!F4&��4�Eu�O�!���'�9�L�t���t�uj����S�Q��ݭ~.�;'�w1�K� �$7;ʾ���y��|�0x/#2�$�U��=cFsr�0J�H%K�]���-�>!�H7��~Bƃa���Ri�	X/��2��&2�.= aIWR���rI�g�ty�R�g��(�p�n�[>ܮ~_>AБ�<���i�IK��k�bꠞ�f���y�C�J'�Q�f�$�ji������2*�pe�<�?Ǻo�C��	jن��{�oo�����������y�Yh>����͞A4��!���ւ�i�95�c����w�zX_��v>��v����YC�� ���Z�@�)g��c��S�^n��[��\�I�3�����g�0�����a��Ǹ���|@{�0��*�G��$q����׷�Mtf����^��)�i�, � ���Ɲ����������=��sfR�rp� d�F����?��H-o�x��A���qƛ�!�A��֤�ŰN#B3P@���+B���2��y�ig�f.����=e�}���|���m{P�JS�3�<�a�$u���ИY�/�����1iZ���\9Ze���f���~~�Mf�s�χM��=J�JW3T� }r��F���Uo1w���s8�CI�{��Yd���b��΂@po�.�T����/������9y4(b$�{�q"󷭎���,�:��8L|�W�G��/
0)�kQ��L��t�HC�o_W"dPӖ�N�'Z*�o�,<����Y8�0��=��Ήv�N��t�f��4�S��Ρg��7˫�}�]/�����&JmYB�) �����&�����������/�.9���&>�>���"@A�|�p߇�����t���2��_��<j�:B���
q��{L�y�� 6!�voq`�E��k� �b��p/�������8���܈�`���گǱ�|/x1�n��/��y�Y>D��kHu�:�
"v��Cj�����V�#ɮ�w��=B�ScjAb���p�8��6=/\��b���*�lC�Ǩ���~�kbYUg�焚[FI.}e���8]�s
�m��Z'��QF�q����Wg�]����*����x�zB��!��5��9K �?��:��t8A�l��[d�����3�A�Y�������0�F�'��C�Q�-P����3��>����'<�y�$���Ѥ-tE�q���a����_p|EMQ�Y� R'Q>f{�2���ˇ����_=D����5�DT.R����:�����y&��ABkWSǫ�����I`�e9�N����8R������w������Mt�ZmV�}�V���=@b�мM[����oO7K��}����ww����K�?*U?�Zl���st߼J��A.��Ss!/Qx0<�	���P&��@��ZV-�^��3ɀ�i��S��Sb�(�~�P��|YH���*�K��� S  w@�&g�ͻ��4IA�c�$��ǢO ��No{�t,W��2n6�ՁϮ�H33���kƜ2����2��T�N����2IS��I�ey�6d������ٻ�d �C"�ۚ�V�m�g�
�WAu���J�Id�0i�Yr"����9V��]>F���Oע�
�Ba��T���"�j������:;��ůH%��Z�]r���,�c{P�Y��T��E`�@q44��~1���^���j/*���D�@������|�n�
o��^�*g�b����+H�:�WN�� S��/��t{~=��n_[(��ܡ&�;���������fz;�dŐ�N>��A�v��~�nRhKg�eUǚ����uA�����z:�%V�U��9=�Ɖ�3�p�1�����.������Ƀ���RI`�(��(�=��؜8Z>�����_W��E�0n`�H{_Г�$�y�p^_�!��Ĥ����`XpZ��洆μە����e8t����;�02��Ƈ�Z�4�'�G^�%t��q�n,��$�h,}��@~Ia�0|O���=�x����|���i���<�Ȭ��VJ�u��pi�KQ���߃���H���ANB%z��v����z7���&b6@��x���c��f���7s�%���X竸�,����j����D� *��(a���v|�}���~Y=`�+��ڐ�9o1s������)nW�\n���g�����3���
^<o�f�t��pW���{�>!�p`2&?��rQ�0�#=�#<ŭ)@��Ib2�v�U��UZ�8��S�,+Aoø�и��}|ޜP��������+�ZՅ��Ԉ�T����*� � &�ŵ(셼��/�> ��{��)���f����:�v�WV��=��m������d�e��9k�I���vA`��𵟘�ܛ r2��� AJI� ����m��K�:��5�t[��c�h��;���8��z�{�FQ#!��%]Uk�2�hQ��x�>y�b�(�#����p@�C'x+E-}���CK� } �V�:��F/�ۥ3�c9���a�W�?�n|GnH��C�"5�e7���o:CR��&u����׃�Fc���Jѵ�<h�$�����˸	O_H�:�����}�~���#s��x�\6����jmmFwyw��|G��	O�oaخ�^!L��h&s��_��ۨ|�Y==�V(o�C�]����^��1�3�u{��z�/(��}X:����H^$�He�i劗h�~�}mc�wϛ��ε���؋g�����=�Ֆ��U���w*$�/!�:�4N}㕛nG��t	?w������ڃ0�N�8� ����˨w�36�K<�-�7�<�n�=p���������t7��f�u�ۀT?|h	)�Dz�휍�P�}�Q��	��2A ���B&�2(!I,���n�&��os� �s������E�b|��)8�x���f��H�h����M c3v�[��,L3i]r��~5g������E��U�;��_~����1R�p�f���n���b�y�b4���4�E�I��B�X$���i=G��lv�P$�^_m䆺�/F���x�r����GFŹ�c��~et��}��6�VU�֓�F�Е�%=����Yt.}�2�8�7:�o>���HOS�uu�7��"Wi��o����풧��92H��HK�rj��[6p5lO�	�2X,�L��)���A�Uy&$^��{������|�?~ˋO�ϐ��*}\�E|oCHN|��y����~�+I	�!��c��{T3�Q�Z����O���#вr      �      x��}�r9�����8q8au%�@^�<�H�)�oMR�헎��%�M��Y.������̏썼1�d�,;f��ڗj	l���k���`�2F������y�~��&z
���1<���������;c{|����_&��5|Yo��3�׿�D��;�%�����;�5گC��������-
�t�l��_Ŀ����m��z���'��}t8���&��_���G��=���W�?���_��
�q����bp�\�fӞ������;c�/ף�U��_���M��~AM�0K�jz7���7Y���hP����{}'V��w,����˩�N�~,������!�.X��r1���;����^��be��܄o��͆���~���n��\�`4�����r�u�ٖ��y4]�w�`�2���"(.9��sN�w�w8���_.�G��I6_�
���qa���r��ћ�ߜ��[XMW���6"N�c����̃�;�o\�}��?��+9������~}|5,�ol���8��#�
����
��:Gl�A����̦�^&S�-Z�����
q �Xݭ��q �|��� �1����Vǋ` �¤M�1�o�y��K($
�aV�f�6��;�	��$P�୷A�G:n���.l��l$*���d���J�Sx?�yr�HA,��n��U���o:��Q(-E��>�K�c�;g��)O�"�ؐ��N�g�AHs����-mh&� ���q����YGy��P�́��6�Q=qx� �Ī�X�P��^pA/�#eUɀv�z.zp���(����!f�؀m����'�!GG��� g��	xB�9�.��cО !�#�>,o�Z�;�����2�h��ڿ��F/�agA�2��P��.l��|(��?��ר���b��&��Ɠ�9b�NKm��oC��b 
E�P}}���ew�	� \�E���wT6�6�k��mԞ �:jd��6�׷I���;&���p�듴���:^�0va�V׳��m�N��u:��R#�*����׷Q�mئ�q\h��\G���^��L4�)"��vb�ao �[q�K%�Ǹn�j�/��i0��mPS�����mp��h�9唉M�m���,,ȴ
�CQc�I��<�$���yY�}*���če�+�Mo����v�F���I�\А�����4���㥐j慂Z�P�#{�����q���r�>7�m�a^%�TN�~�j���O��ȸ�w<d�س�I���D*��&g����y��<>m�;��y�aD��:2f��>��.�-�[ᠤ�n%X�s_/�'j3���|��$C]�e�d��o����S�D]����IhM�P[W�x<[�y�I�I[:��Z@�	>��*��L$�iS�2��ĕ[�򩡡�ŗ������zgR	�3����KpW2���N<	�=��<7'����m1\ݹ:�t�m��1c�}ira�;���.A/p��)�m�2-�݆,gE�Ycy�u\�F��۵��r��M�!w��bHM�Tkb�Mg(��`�ꑘ�h��|�f�V�V�i\��(�n��s�#�-⒮�*>zx��EN��p���N�/��8��ZĶ;f�0n�p��V�R�5m����!䳄���?6�j����,ST�W�p)4&9{י��=���K�]���������j�c���xl�8��g���xt9
���-fc?����х��?yW��J�r���'i�E�Ø�=\ݍV>�e0ʃY������7��W�ɗ��*V� $��9f^(���MK����ǖ,3^|&ZGE�.���=p�����*%�椥�HŒ��W�)1e�ӰZ���ixr�*:�5�4�Zf|R��-Y�c�����`o�6ѽ�ё���(�R�^>
-9^�3��b��C���4����?�e,����qζ�<ɲ?L>&�ԔQ/amʆ�n+�YQ=X�jޙN&��;�*��.���-��C�Ա����Ʊ~��dfYۀ*u,�#I(�c��k��T�L�/��s��m\-�R޶�I�l�A ��;��ߏf���W4��S�0ng���'��蜽���/��}\o��M:�ؿ䜾���-:[EN�׳���qY�׋�k�00E�@z�˗Z���e�� �5Ӆ�.���N�cΉ�A����尮xE(������j�g�[���)�"��$F�8�6�	&}�L�٤R�JW�$�.^Uj_<������,��v�i2��@Œ{=E�}�'���\�D}�#���J�n%z� �v�vہS�U� f(T�G��D��1+w��45�P���J���{���t4�f��^$�8GB���,a�:���k����q�լ���	�v u"!7�h����`��~><u\ݭ
!������R�;Ĵ:�!7�Q ;4�{��=�"�A�@I�.�H�zV���@��PIx�
K����c&�>���e�Q���#�2IY�<��V������N�d4X�3�����a9��lC��)+X� �����z���-�܊H����**V��C)WA����BL	�W���_��"���W�$v˸j���j6���0bN��M��-�� <�3Y�gLy�$�;	V�H�lqyY���Y��`5KͮS㥈7ra��+JK���RA���_B��O��~�r%b�w�щ��*cqS�N��K)�'4��@��ɠRt��5[ ����]}����ͷm1ҫf�s����z6�6�wM]�K6�8f�J����������N�n��b>���`̞��cEy��y�X�n��r#�S����b%�=����h���l�mv�����4�
�\i-�Ws+9?n�z!I��W�a�}����U�l>�"c���m���_�zv�T��w����%�#���y�W���)`�0�*��/}�n�0�HɊU�RnG��u�g�[�4u�A�Q��&Y����;u�>K��7�ȸ9n׻=���ab3zW���3P�fj�;]B�����8���1���p�?w&W�$=-X�t�`�*�y�́�Z��L�H��&�ʲU��N�s�NvW�iʊPY|���>~+Q4e����'�(��+���$|�����M������.�mƄ�x̀V/���(m(�4�wFP���+���Yu�ʳ[F�Y�
<��0���ھ�����%� yg6�2�������-��)�� ,�Z#����m�'����?� �j�[��l���8s� �ʃ���T�z��&q��e2���m�/a��U�V�$�J<0��=%jn�4�~Q�+�{ɒi�b1K�}�p<F�뉬K�Ww!���e�"h��	����ʳ��I��]��Cܿ���/M�����e �k�<�E����x_#����ָ>��F�^,���,�� uK���\��Bca)ҩ.�]Y����"����Շ�I�Y"�er6��5�`��Zs�y1�\����6��UZ����.ǌv7��J�t� �K�[��Y��n$�5�=�]G��M�t�&ܤ&���ɂe~�H�5$.�15��< wp�2d-�9��8~.�7N�b�:�� :@o���;�j��G�J����b�af�A����cw�
<�B��m�f�E���"e7cd��3�A}���~�&@2��֩_��L�Q-WC��j���E�0�r�\�� ��^��@�F)�M�X-��bؑ���.����)�tL�Lb�b��1f�7�ܬ����P� 'W�������O��;���`�֛��u���ګ}Oi����9�	����� ��П�	ƈ���J$�^�|�e�sd���L�m���[�������	����,��ԓ!�0�lK���Ұ���y)�6���ȫ�`v��n+L�Pe��-W2��j��p4}���-WI΅Hρ)�T]|�|*�<Z��Z2@�A��P���jP�k��:��+]��0���Pf�����4ݢM}�g�*��#p�{�o�a���4�R�zh��:^?+X�^�_�Ֆ!�1�W}�W
�    �K��	����5zk�2˦�q��'���>B����|�5]5�<�J��F��	h�e-�I)���z���I;�Z9�2P�J���U�;n�v�ly[.�M�p��L�0�mŝԱ���H�F�K� �`��`a�[�ڨw�`|�F��9��5�����3��7���ڭ��p
A��hy� %	��f�:��m]��y�̱C�X��ӷԶ�3+͙�4ǔ�K������$a?���-�?J$��u0����Ŋ��iS�'z�1�!U�{�Ѕ��:�	�7�#VD���i�%�D���0f9nG�bc�9�j K��}p��/�y�����]���U|��4��E�G���[��{��{Ң��f�f��]���N�,7����ɸ١K�lDx�ϧ;aEL�e��޶eޖo�8���:��t�U�_��?_�����/���NiJ��Z���<�*��K�#��4?R��v@��r�*3.�r}����n��n�2L�X�H[������l�F���aZ��ZF����u_�������OkPO�`��񱗣�i��,�&L���`Gx5��WsJ����h������~��ʖ�S�X�@�;>Rd���љ�k�y�=j�2�[��g-�� ���=X�`	X�e:)i�n��4 �Y!k4�O����
��4iWD�h\ �j��u���d�!�'��E$�>e*�k0�^��$�)���z���ϝ�� g�H)�¤�త������r��זJ8������{5R���0�e�{+���C�<�b�Y���m�*k��_9y(fiA�Uԛ�xS�=*0�*t|����c��TJ�2Z���ߨ�;,������0i&4%�)��^	wz��,�gؽ�f��:4��!RLMI��%M��$�� ����|�v�o_��I�|(�u	ۃi1��2yI��D"(�����_o_7�7�z�/"�P�ϑ!�xVu���/M�//��[�v�r�� Ҵ�6�F�Jx���f��,�u��F� �o���C�I�ǅ�lYuɍ�i
�Qj�q=I�ݟ�И����X&�U�NW��s��Q���8�i�~��:܆����I��[9�IL	k��J�N4��*�H���שvfT�<&�-�(6Vߥ͏��,�����X��6,�N���y8)�pR#���	O��+ �+|�,S��%Y=��~$��������Wd�����P��g0���8q�j�2�Y�K���ٙ )��$��7jbH/t�S�-��Ș�zסB�+��m �"H����?���e�7oy5�6΀)�T,����:2�ׇËxLʙ04�ٙ@!�	�^�� ����>k�N��U��9���"Tz)����lS&�Hq���F�]buR���Hm|4i-��-��IWA�SVh�{����G,�ىm��m�^7����f�����#I{
$��m0K.�	�cH��Y�2<�%�$�Au��m�l2�!"���k�sŀ��Ьa�\2�0�ٱN5�r��C釛��W�!~����K-��TF\�u�"ݮUF�j|u�#�v�ҵ�Ϡ�{�
�n�xf[�Gz  ���-c��������4T�Ua���?I?W�o���R���!�읶Re- �]?X���d{�eS�?���?s. ~<s�@Y⭝��?ZN�>��8�������uݬ?×^�*�-��#N5|ղ���i�h��0��L������e�j�X0h-������T���:�Isg9�bo�f�o����<��ڤF���/����qB�r�ř���"�A59DM�$ �h�-������Fc�n�>IM3�٩k��K�(��wc��b�/���B񧃦$�S���Q�P~똸��a��N��&I��"e!6�� ��	K	lW���ׯϡ�U�?�)9RW�_�3��
y6��
���Yx�GᕯTR B�e2��*C�:�R�ʍ��z��S�mk�>��Bq�F�	��Qe���ַ�]R%�q��}�G_����y����te�����Ɣ*GáC��E�YmB�������$�:	_w�Gc�y>�_�,��rYel��A�uR��YP&��d&�$�>�����f����#q郫��X����N�n�Z�۔K SxN�e��v���P��m�t�����Vl�<ծ�F��?��Ik?)�vo|�dԺ�_[6m�v��'W��6�T�>|��7N�� q7���h��%�~��1�r8��@'᭘����rL���/FӋx�~pN���`��9�c�xI��I\����5d&��̯�_`��(��d�]�'�~b��⩟���S��s�bc9FW(���{��k��9P�����",�P ��8_�Fb�*����Z\��.�E{��l�}VӉ~]�;&[��!h5M��R�6&;Ȯ�p���>����(�c`��.Qs�*1R�6|=��Hܲ�^��"��@���;�3p�${���	b���H�'l�ǭ��9� ��3�˂N`�R�%k$5�#)�Ū�ь�qS�i4���e��������oϻ���x�E���X��Q��_�&cEV�ZZi0��܇#��B�)MD|��ﱻ�<�dͼ�}��c���眼Ͳ�~�E^)RG�I�R�� 3n��N��d�:.e�?�m/�`{0�Pi� �`����fȔ��*�&���VC��@J��c>a�c'v�)�m�����+!Z�t>	K�@�K4��9��:ܬ/n�ۢy*�	�Rr�.�URc-�U��E�Qt�J,0!E��w/�Ѱ, ����M3.���� h�� AH���s�4���j�sb]�jqH��� �-&\T��t-7!�,�H|]V��=��t��M��	]���j���\
$�+�g�/|� �<S��Y��(��,N[w�$�s��Z>J?�u ��V�W���k�ؑ�9���wh\9�/[�6�Kk��M����J�y������G[�v�_�_�H�� j�#Ş�3(L��	���_ν�J0�`B�Pw�O�泑�Y#k�/OI�)-��'�&����o*f̔s�3�*Y7�P��m(��8$.�W��/���N��Z�\W�������n������P< bc�a����<S�O�?
�yb�>�4W'mV��F�;耊��'�4r��3L�� ���Ò��u�1��#!��a� nGM�ؒ�8q��
�1*,E�(��Q.=�~��Gv�����xPtb2����$��J\���W�'���d� GC=J���58*Mn@�͔' P!�c�$��E��sqi7��J����'4�� ?�I�JcX-�t2�ҕ������lp+�XEe�"��
�wmӘ��Ă!��ɵ.h&__1)$B���Aɀ��C�s���5���=<C��L[�"%.���ˤ��b�����orR��F�DIY��[H�(z|-����z��b
�f
IG͖q�<e���k�����[�N�Q )�L�u��S�\ϵ:rK>ED�W<��3�p�/�g�p�d�%�@��������M�[@�+c�uɛe0���y�*��P?ecp� �y�RYkz��0��c˓[�����}�g[��\�-���ja^�G��ODV�\u�vӡU�	N��*����\[J��vN�[�]�B�$9P&���ف�(�	8�+�V��4Z�mO��x�A��)�:^�4]Z5�QS��걄)ݡ15US+ ��ij�	�Tf�t�ñ���X�ӫs�i�{Kh8���ov�#c%më��u�j\��Gߊ�PL�� ,���JR�%���iK�N�faH�٨��IS��mg���C[��؎㴬�d<�DNc� �Fi���ʨ�dNc
v�Q=���n�5�e2�co�3���i#��n�
_k��rڕH��:?n�4kqfy�#�3&�@&������u�ېbD�T:k+��[V�!~������D�p��t�-�P���p^
4(W�v�>?���m���F:3�`� 1.W�ꃰ8�j�@"!��yC.cX�YY�Њ�8&����*ٶ!0gN-iؙ�z�'Z1�3ȕV�Vzp�1�z]G��x1ش���ܴ�w�d��Vf�    4ىm���Y�X<|O������Fjc9~L��H���5�����$�-W�*��`v@�l��&|�b���x(:�����<�@a�w&���ŝd��i��åɽ2��A��l6QO���i*'aU�-Z� �V-ds����Dt�U<3���z޽��z����*��a'u8ǁ���Iv�
~���.ן���o[�2>����U�}��8|VG�r7_���e���ʿ�<�^"	'
��QT��]|,�/���/���l�tўeK;�D)0���	���Qb����k������G~Hzh��㨕ؿ���ӱ��L�~|���W��ˮ��I'�O�Sshg`5�N�<I����j�ɜ��q��bG�M��S)�ؤR8����X^���"��֥�o�3�Yz��U�#�ұ����O�疜�w��h��}5���v8o�P׊�'�\al�	���߇�T���AS���GUY�V��j!̽l����5S�C��ݚ��B�\�uۆi)ђ�D<����J3�����z�n��?�ǿ����sy̦m�k!�Ɵ�Y�����8�^�f�9�`~(��I�F'�r�R�OFcr�qˎ�w����0(�H������>��h=ֻ���H�k(gb�dEN�Z�5�$Ux��1���%oh��Hǫ? �eI����n�5��54f:|)9A�e 	�7�(�T���.�E�:І��R_T�E^�|W�����H�j�zfؼJ��� �Ϣf�S=���{Kp�$n0�Q�����{�a�c?G
Rr�6��d\,)h]8�����-o��?,	�1Y3�&)p�`;�k���aؙoz�o���ԵJ�,��F�ڈr~f~�q�����`�}����ڂ�����M���H��r�qc��;e�,ܻ	_֯�b��Jst���YH�����*�yo=����;�Mb�N�S�a�0���!�^輑�m��N׍��A�����3�*�\��c�Z�R��Ӭv� Z$	2�4�[��hG��ИD�W�^�∝�q)� um�.�Î휺F��5�NH�SZ[��F;"elݓ�cy�)IB�ӝ � �+�R�[���s�^��)�>*��Г=Y�LWs%	P��어�Ow{h��D�B�B%�m�!��nŒV�����^J	$ OH��fѶ�$��j��<���ɐ��Wᴷё���5�~"Nj�x:�����eBN�;��3����x<�'�8�-��c������Y����W�h�D
��~]�5��'B�\7�M�#D"��AL	��v�Ѱ���&�2,~�gJR%2��̲n�r�[
>g1���!g)>�OQ����GI*���%n�L^�-y�]H���O�D�������82#��R0�B�`���qN:H.��αwj/�؞�G�b��r0fO(�r&!�4�$�v�+@8.ԅ]2�</���h(G�w�r�5�AhH�wB��9	�O ��Bs���p���|� ���9�I���|CMAlb�<�j��<z�pL6��>���Șc	�v�Z9�!ᄒ���sR�\�H����s�
7��\�^�KK��9���ģ�ډԓ\.猸��F&����r	#��Et�	��Oa�_B�a_(���=��bJ�FCtO	��x�ل����	]�Ց���6Ƶ����9����2�(|�k��Vї�߅ގ����6��M�ޏ�_�}���3|�0��ԗ	u���Pdqx48P\�6*��f�j-v��{h������,����,I�U��)+N0�-�$�������0���*�8��ޒMxR�bZ��`\rAu�ˎ��o��%��V���.|6f��x�ghs�w׊���#�����`Д��!��= '�gg��U��yo�0m}�b�'b2�ʕ��ce�٩A$X�Fk�J��v��Q��P�S�х�E��c>8�x�L��=���ș]�LTß���`��#�Z������q��R:L8a�,.k\[&��H �N{jՠ>�)��87����3NS�c�L51��c� �_�j��୏!O9��QFM6�<+:�x#tAc�ے���B�ؠ�^֮[�/��"S�P�V�nG'	�2�2������F6{������N���2:n���oǭ15$�������dH���txL�膋?\)���>��3@rV���b\�1)SXl�IЂv��c���tɴ����	u�l� �Z��!�.S:���w܈�����j'�p�}��o����t��9Y�ֈyeD@�� �J��}�m�C�5�wB��h><G_A	E��H�}�����A	X���>+TIC:��X��89S���L�5�4o�4�խw��"Fl���a��Q-)`�����$�p���>%�� ��P�{0�˱��@B%�[�_�_����	Jƒ�9����\?X2ȵ,����~�$|²T�m&H�+����+���>�TC��+����H�^��P�=@uW��8�|�D��%V}""sۣ���T�3��N��sӺ��E T�����C%OmR��Waa�o}�$:c��
���[��/��q@�X�����$8��'�LJ��q*M��������G�sD�����';�%3A8z��fS�2���09� �*'�&�[�x����š�F3Nfwӕ�&C� oo0�E����~��������=�՗Q�?֊�Ĭ=wGfqxM�;JȾ��8{��ijJ�&�Ryƻ>�A�,v_�"��3O��x	�x��F�+{s��;��Њ�$�]�SH��<#K}�ol�\�y٣=y��#*|�Yq���M�g�MҜ7X2 �w�%n���&�x��熣�W�v�&��'7~9�4Y��<�h���v6�����`�۝�m�M�0��3�j粉n[N�t �K�[���Mhz9] }�5K�z'b�p�A����(������ɜ�3��D��`�-����8��$Ot�~�`�'���_�<����R�u	��iWS<��VOZ8�Y����[�7��9ƞ�_�--#x4��*�o�O����d��"52�5t}��Ji�;���6lI�mѮl�idɢ6E<)��rЂѝZ�-7�Cן^�����?5|!��&�t�h����5��F�x���[���ȥ�)6�+x�-�S$J�
���̩]2֦b&g<Gx�t�;��0���F�f��-_
K�W<���JW�y~:di!d
n�����%FL�2DgJ�|�+e�V��mzf<X���	��yW��fG6�*���ZV��sJ������zg���;��5����^l멮y�mDst�2��>f����S8��K?��.m9$A��EZ�b�,�����3*y2����i�UѴF��]sy���^��M#���vv!B��wuӿ����f�h���Q[�a�|��\���s`������Y��ǋ#��t�=0K�\^��w�8�4&��>,�R���/"	UpJ3�Y�-�`��L�ӗ�ly�{��o����M�w������w�4M��VLib���ܑ��w��[Sc����f��7��!�4X-���d�S�)Z̤|2��e�+F<#�#�n�*�J|}En�Ii+����>�}���r����\��U��9��k����j�!L�X�H;�K�l+@�f��?N�8k)����e�G��t�/D4�D1)�L��$
d���
�F����p��6>�CH[���uN�ų�,	[��٨�Ţ�ג������yR@��ۘ/�0K߰ c�S����O��/ӷ�Y�<���x�)hp{|}6V�Nԉ�&���+��T�Ⱒ��~����*�ne��D�<���m��<I��%8�H�	�����ݥZ
3buOz,bh����N�Ej�J���B"����E�B|�%_��Hb�&(���,⚄�Ěe�/
���6ه#9�H�<ΔuB�%�P�1���t�Sfd�� �ZC�w��akWA�7���4����ꯄ���e�Rn�r��y�;�x�~yv��2����ՙ�վ�v'��C�6ד���ա�k��L�C�X�ཾ����'0׵xI��6\�Fkcy�~{�   4��.�m��:d��&�韡��i���aÄ�׀K��*5㢌���_ͮf�ij�;�1ܷ"S��<���<����t|��hk�>�b�K�:�,�XX$V�
�����3M]��r�~
��bz5�x�j���Xr��X��5�RS40�'M쏗	:<�9jx��M�T��,s$�$����%��	���b�=h�^�z��~4�3�g;���XH�$���|}��v��>ᦴx�PPӌ�e��(�*^,\�i�d�|Q�uj����I� ���� � �b�$��m��n�qI]��&h]�s4�R�{�^�T8x���44$\"zO����J˼%⟖�����@�(g[ot+�����<�C�2-�V<a�^ �u.�X��\�斎 PI4<�����X�ÖqDH��}�ŔSBݮ-��fc���xX�����JS21��V�*�	�u�GJ��10l��p\}F�ͷ��H87VP�Iq�ۗr�5e�!��3P��{�a#�1Y���>���Mɩ�܊+��袐|�����WK�������I9f|���?u!�?�+¹	���1����u�j�O��^-&�]8r�3�̿T���$�r�ȱsf�UQN��̶���X�% n	�}�4��[�����bp{k�4���7e�./ES&\��鍶a����sH);S��)B&��n�0� ��I���IbA������ɏa���s�Z"�#�-�
I�ɴ+��+?�tp�%|����M�S�p�qdJ�y-��¯5�p�B�<>�~�ո	�ׇ�/�r� Q��;"�ʫ%��c17K�u��?_��Z%�q�=�~s���J���i[���FM���z�	��@��k��s�r�sZ?��9C��\�[kM��ܥ���>�/Q�7�����N(��H�$��:��.�Ȗr�%��*
���w�܇�agQ:3
�ܱ���Z>��ǭ�����h'����Z���c�S6̌H�%I�ۚ�Q}p�ވ��	��{��d��;��,�a�*�23��q)������[h�>??<?Rx��$L���A�2�F�-a� < ў��q�����T�Rl���jF�6���p�Tz()v���bE;cp<l�� b�(���� H�[�c��T�2�q�۾��wʕ���d0D�4�
;�J]�dn�������Fu�E���O�r������7�X$��e�)���q��pkǈ���>B�R�J@��6ӟ��~��Q�z���O(@�Ȱ&�TL	���k���å	f�̱,�Hm\����P�`��Z2{a����z�q!N��^f��ͷ��52V���V�� ���8��/)v(��N����VS��_w�Gc�y>�5+�I�V���%��SY�[������K��#Ͻ#6e�P_0ے�5���*�U�Z�J�b���l�M����>���L�T��9����C��FP��`�Չ�g��v����`��L B8���/�'�L���Md��a���?Ṝ��r҄e�+��Qai�tf��j�>G�]��e�/�_���*k!��`eT��[
�9����b������7��s�;�*N��i�ӌ1qja��$J��3]� ��������W��Q���i������ؖ4��3hov[ݹ+\�w���SX2��0"��=C������4�:|:��01�Y���l	����l�E����z5����O����&�b��:���-~k���� ���z�\�)�{k5�'j�v����Q�ܙ���-p�Mf�M�эq��i\�b�T��u8d5�3�f.[�}���]G�����q�tT����V<_�]�L	/����Y������	 �����YB379������8<GIY2&�Mhw�G�n��,����n�<���9�#�3�=��!V�_Cq@_Љ��Y���3Cղ��CV\J_e��)�����XiRj��`O�[���&[�rP�����C,,t��8��`X�q��i�Bo�$z�`��ST�_~؏��hO���y�8�����/pxD/�/�q�b�/ǋ�>|�T側v�p�'4L����9W">�䙐f�G���V�R�q�7��]InTZi��#�'�ų�'5D���^!\SO$�}.!�à� �!�Ԟ�7Zӎ��i������l0{M�j�t�<!��)��M�"��CZ6f۲��r�[����{^O���pS��/�<bȉxE?�^�/l��xB�O��b%%��
*��� ,뢣^9.����Ь�KK
ݫ��_-�_.gՎ�4d����������LBw���F;c���*ޣ$�θy����Գ7�(�:��wH
�kMo��}�k��ǈ�V��3܂���x�afotP{�=�d&�eҵ�B![a��_���h����������"�o���. dn���)g��_r&�p}ج�jnX&�������R�p�8�c2����Z���yR�z��Bd6#��Asn?���SU���7�!��_ayx���|��4D=�-g�D���v�-5��h���G����g�r	�'SW��?^����[J
��C�k1�8������=�#p�!f�@]��f�<��5X�Ix��j�G���b$�TV���|&�"i61Y	���>��l�FG/kg�E�*��D�?Z���x�"���c�K���ن����@=�d+.��.��� ����l�����j{��%��ecןu]w��3ӓܓ��+;�Sj�h���Sq-�g�{
��h� �Hj#�-��  {{[�(/���_Ü���-v�q0?��P�pD��ֽj��-�S9�����<W ��Y��ML6aXL?�-ɨ@+���l>�6<��@��y[��CW1�^QO�8��Wv71�b���&r�iZLǖ9 �l�����
���� |^�����+Gd����}�G�E�ʏ�&�qG�����3ȧ��f;yo�#j�L�Yl0.�"gų
S������C�<�5O�<y��s$=	S����y���y>?
yy6&�m}V�\7�+AY��6=��M���DBb��F^xNlY<�#/+%���ƹ�d"��!���oi�<�:�0��
	W"�jp�K�s��e���9D����߽�����Z�2���Ē��8��J����&qPh_^Eػ}��LaŻK�^��_�Wc��k�$�q �-`�`nG�E���L[�KS�KgAUuv�B��le0�p�:�[�=���V����V�n�]K)�����dV�)A,����ó��29�Ȩ#���8���ܡ�n"�ҹ�����f�T��@�i����*�S      �   �   x�m�ˊ�@E��+j�����I*�`�Bw����&�L�o'-� �:��RW*��A*&�������[Y�]�w����S��h�N�[H�4Qލ`F5�ʰ�9*äљ�7�	��91iC'�^�.�g�i��@n�L�{ތ@Y�]x�z��?٢��c/x��52ڡ������l�
��5lSI5n��f�]���p���S�      �   
   x���          �   3  x���ߒ�8��7O�]w��;6`�Wd D$p��fj6��J������>�>ľ�>�
���H����tҎ>�H�t����c���
~���?}��ן������_~��������?��_~\����/?�k����߿��Ǘ_Y?}�������_��
�?����_�G�NҼ��cnV�C��1�_�nF����4Ԫo�n����짶}�Z����W:���	9"9U�����k�mc�m�
�$K��R�h���U����|�WA�[1R,G.�sE
DR?"�SI�2?����h�IO�Cm�ƶ�U�]l
"@;l��b ������F�$(����)Ѡ�J$�:.�dw�x��~+Ք[Qsٶ�f���T��2o.ľ�)�{-���D�M��#鄺�n�7.���Ѳ���������<�� ����"
�wl^�-oYs5je�!F�����'l�n�d�����#���0�����ׁx��y{�+qv���fl
< �x��!?r������n����j��B?hԠE .���.��bH�ߠ�t[��[�!lx<Jz�#b;Ħn8/�N��m/h}�g^J=�N�M=�[������g��n}�eTf��B��a����B/��(�N#y1�6%ܙ��d�0���ܡ$��<��B���N��H\�YT�����Ȁ��8�ʖ�WG�u7�`�\	= ��q��J֌�A����D�3�d㧦A7UM���i���q�c��(���J��b�I+rI�|��ɘF-��0us �9e�u;��l�R�!�哝�3�SJ\H��Z(�S޳1H��t4#���$� ��a���B�LJ�Ȍ�&g��
�If�q�V�"} T����>�(�ZT>�\�v�����PϘ��8KRW��d��`�*�dG�����V�����gׂ������$�W��x�P)�Ȏ��*G2W�J]՜c�f�	�][�'�Zc�g�34"j=`���&4��{bwԴ83W��X@�j�8��+�A�M�8s�8�����y\)2��,^�f�q����w�e�\:�0��u.-Z�"t9t@�#����]��������rM�E%��a%�4����Q����l����Jb$�ۻ:�EW�Y���n�/������́ݛ�͈��5hz�v�0���Ӹ^�Q��!���(r�����DW�W<4}��g,��6���Oj�ܑQ��z+��DDc�Ī�c��1�����/ٸ�ش��Obc�z�U�g�1gw�ڱ`��n�B��J�g}oF�h��rr���ɉB�Q)��`�����V��Z�k�Z�:d����,�j�Ԣ��W ��qAM+�k�g!��CO�y&�Vaj��(�����{���/elҠ�rE�.���|{	s�ek��s�r£x�R�(�Q\��t�u	1,�\�.�o�P$Ү\��S���[V�i�+X554>W��r�X+lNM� Zy�El2-�CC�[�O\��� ��E�
�q�*�WZ�M�>"�:�Eӳ�_����<������3�^�a	L�To�cl���Q㬋}a���2j4'�V�Z|�����E���.\cO�j:̛UF��,ǉ=�
;7˄�]�np��=®TW8
�aW.�}~�#��uk.��
j<x�[ש�/{���b�Q�k�
�\σ(���n�E��p)���R�6��˫&�]Ԙ�,�WM�B�1 V-�_s �\�{�h)�R��@��6޹��b~�@�O�ˬ����ѕÌc)�:���a0[
���p(�RXu8,�0��m�L;�J3m؅>pXBԝ>���Ǳ:|�W��b�^���@a8ߡ�[liޡ����بv��7��\�v�vS�c�+�%)j1�ms�KVX1�v��\�j�ZђkqD������#�*	�a�⨅M3F�V#;jQ�籶}Xh�\��]��&hEٔe+OA��oLY��	J��D����⛗e�Gzw���z9t���S[�ՙte�ż(A3���[:Ǌ;ڱ_z��|_b�Lь�����e�Wz��ؑn<��8}Y��+�d�!q����L< �g{���DH�^0�֥;/(
5]�^A�i�M�ɵ������~�j�\�\���^�� ���$�<�4��_!�ƕ�y���Y{�zCW�7(ע��N2�?v!�YWA���/d~��i��D9\3�?�穗4BT�T(��
����#�oE'��n15.��_���c+q4!߉�~uj��)4"��f��A7���#���g��~s��$�R(����ԁ�0�n9ة��cPw�' �ƶ��6���G��:u�S5>�י����8i�ZQO�<=U�O���mЉ��#�S�����,е{����$��x�����[��3��n�=͏%�ӫ�G�ё,�=�&���S�@��H9Eo���f��¥�Ô,�.��c]y����k��/���ƽ$�$�+[���Ӿ�)��#o��� g�Օ���=֝�]��0�z�'�c��q��v%��a�a2t%ΆU�%��6�3L T�^3NDh���"t���U�hGI_�}Y�
'��gBq�"�t[霾'�ٕ��OOx�k��=��:r���M�t�#���<�%~>��?#��y7���e�H�.|))��~�)O\ ��]���I_���;�'|vǑ�Ę?0��c?Պ��1�����O���yF|�#絸逓)�#��."1z3�oD���#�q����q?��0�۵�zk?-!+��X��Y����n��)���ʯ7&��Gdb/!���j�o��z�(/��da��s��u���=����?$c�*����$�9��d�'�sa}�I�-q�b�/�XJ���> �p�,�X$�Q�-9|�.^j�(�0$��u�LęV��~��k�6�p�*´]���C�^^ʣX$������8o .�Km�>)����/�Y?^���K[�2��x\�vB��s�/�t/׿�^�tP�b)>�n��`�5���8.���+�'\��\hzڟl�'�z�^��~Gj�L`̯n�R������|���rh@�ݻ��dܲ|1��]A'�Y��-��ʲ fI��\��u�ߎ#.�	WL�U����+)wi��iES�b��ji����Dq�M�_� �/ן�97bin�7�2��Z�)�b��{�*�܉�F��Z�r!.�w!ٷ���������;qamǙbb܌�B��,Jd\�+b��֪P'�;�Ќ{B�_.F��Ch��Z��M˭u��Ό+D�Q��@Sw8�2.�A�ү�^�ɸB�lU)�׵���?Á�P�����h�E)�8YG:�F�+�r%�^���5?4�q@��ڮ�(��=��="\�ۗ����� ܇9��&T4N
��Ќ6���+�]�ײP���(�y>�o _Ap�]sn�y�8�n�/�)DOVc|*�]snh��M؉+��7��xB�v�M!������Ź�ES|V��p��在�	�m| ��p��k��)>��n�ސ��%=��9^�-��������V�v�EP'��b�.B�!�q���z2��^�z9�V�_��vO�5�"�/̊��^p\B�!ɰ<��6�MGż���*���q
��J�y���Cq��P��\zB��=�yyE��E�N�����%�o��=����G���z�����;�Y��w=�ge3/hTtWBϤ1/8i�o��6gƋQ8g"�G�5���67����1�R^�5�gvF����:p�öKy�T�D7�;�qU��KUԋ�"��>ۥ*z����D��m���aݯ��۷����ݻ�A0�4      �   
   x���          �   
   x���          �   
   x���          �   �   x���=k�0���%9�ɲdѩC�@I�I��V�ImŦ���i	��,��Ez��lW�;XovO��>�liM����"g�Y�6&ߧ��1��2<|3hO��[m��x�������w��G.B�!��(����Vy���~*Z�AĎH(�
�
y�rE�o�8Bh����� ٷ���.G�h�b$�D��#�����	"��;��b�$� �O�� ��_�5r�B���      �   �   x�U�M�@�s���� �}C�M�Zp�؝�<E����7�݆g^��-�)���������T/�K�x��U��ZoL#�-�5�a�0cP��E�E��Y�c�)A	-6�ՂWI��Ӓʎ�ѯE����ڒ$G��M�Jji���c����MfNig{i?�=��ey�\��<���;�      �      x�̽ɖ�8�6���)l��ƣy8�1�y2�h7ψ����HH�8@�A沷�e�z��|��(	W�g�E-��L���H�����?߿������o_�v�*7qT7m�˦����z����^�B�z�6�����w](�w�u�t���T���z����˶X��׫�\���o?������?�c>�z���*i+��2����:�[��DW7m�jC�Pyt6x�����8��FƃSg���L������r �ǧO��Wx��d�ϐ�������+ݤ��hx�����[�^Wx����A��v#QGso��狎�w���j^�O[���[&��z�s��r�U޴E�d������_���k�n9��1��Xμ���§x���{ܚ:U�GY�2Z��r�L�*o�rHm��^⺃�|�W��e����<��h0�B�1��wya�v�^U��jפ�ꭩ੐ �ܔ&Ja����}�Rɯ�Y��|)��`�}|'/Uajz���a�q+��K�]�����ѕ����C�|939�A�����6s|u����W�W��4z��)L;��K��H��6JgQb`?Z�H���4e<��c��t>��~��q���ee�^�S��@�-SU�i\|�燘f�k����#���*��6�����LR�^_}P��S������{I����uw�|�MjUG[73�7�mrk��;N��-�'[�G�~���|�;[��bF�����^ml��r�迌-0�:*h�`cL~����`�	���vg�R�&孲)mίg��Te�`�F.Tg�n9��'����c��3|�L�z��`�Ӎivpj*G�l��9�M��1�<�.ϗYg�5�[z�o+�*>c��
gi������Au��?8r�s��co#N&�sI��]Y��Ɋ�eE�׎s��.�~�uCg϶��w��R{wr��p6�{�����l���f���l67������VE�4��/�Gsw���9��-���y��#��"����?�͉�[t�D��,o�Z�+�C�!g�1F_[���b۫w
�)���wajV�{Jc�\��fHtm6�8����Mn��x
�3�[�$�h>�����-	l��ݥ�����R�wj��Uei[�g�m�]��sq,d%=�b9��bv���W������7<J��7�
q��rv�T�%�R�S��b6���̛�ҾhPf�w;x
���K�m��.��%Yy��v�YH�f礱Ϳ+�Q�-�Q�Ho���C^3�G���Ǎ.m�`���c�;���`b��ꦄ��x0\�D΍&��o�B'��׬+=��R�k���9��0�Ux�?�-��S���I��Z�h^�C� ��]*W#b��y����[�u���[.��f?y����i�_�)^��)T���Am��Gc�!X:�	�ʊF�Ae�������y�����ߨe�����]-�򜺡����*l-}I7����o�B��y����A��dCb�I�T�(�l� Y�<�5\<D�U��=D�"^��,7�Иr�r~�%�g��(�܂J3��(�{7���L��!z��$~ ����][�)퐿۬5�4R<.�!m�&��Gw�5����|᳡I�ʲ��NU`2��L��Vp�Ju��"��VU8�4�?BJ�Zq�����iR'���lJp`ӧ�%�-"��nL;&9�'&��r�iR�1���� (�>U�v,R8�ޖ����[�?@��z���ތ��s_�"W��Omlr�B�V+7 � 5�ȡ�?X�C�7^�{���c�soA1�i�ʍ\p���M7�𳡧d��K^�Rpή�����C��bˍ�M�����k��m�݌�֗ϱ�y�{���󞤖OT;�ޓL��;4����5<����y%�ȣ��n$��'s_0NGb���T�Z�v#��0�=�3�#�{VsN/�9��m��:�!w��7u�w�a�j���a\�gt���2�_:U������+�,z�t�GL~��)����Cr��c�nn9��m�:NᬰC�]��7^�+�~�n�6�x�Ph��S��Be�E��Φ��4��_\ą��첂��Z���M򇲎bEC����=�n}���S>�|�Jw˪R�=�nU��<�sds.'H�)�6!��P�[���E[���L¿���+��ߑ�s�/�՞!�=S�|Q �%l��3_�5�okU=��3���yd��P�)A�?�s�s�?���M�Z4(�NY�!Ϝ��I̷��c�^�G������%/:�����*I���!�~D&�����'V�c�w��7)�cx��7'��ej����ټR��}a�ٍF��/[Pϫ�q7�M����Fי��}��p�[�{jS�(w�q�����#�]X��p?������$u�>tL�X�3���X��3=lnL��=Z��{�6΅�:1n{�wت8��-
�UU�1�����?[��\��-8�`�����������N���LB^35� ��|x��كL'�7^��Q1��ݴ����'�7Iܡ:��b����G0�BL���v����翳9>�+��տ��v��Qe�K�,�b�w��bUS�&R�	<�լ��lݷ�$f��]z������`�t9$�W�,r?���j�K�(�!���3$�E�C��n���L�H-�h蓿Ƙ-n��Hu��԰��f!awyP���{�� 	��lf��)���h��u�tX�Qð3_\c8x�$Ŵ`	S�w�z0r��\�R��F׺P��D��6��������q��m�$�?����pr]E�|���ޫ��d�Qa �v9�����.�Ms��u�6�PD�y>�-��'?u+L�:f`���W��0�C�u��aO["��_01�Y|'�tI/�&�S�\�����i�����]�Uh(gbؚ��/B䷕.\�����,�4��
�����Q�k�O�%��_�ָW𜥻	AY;^���#��`o���E?�7���`��FūFޜ\n��,l��
֘´���+���e��W�1u�7{��\�uZ����`�(�f�q��#1|�#��1��5�K�ئH�vY�r��<�oH��MX_�Y�7�:�y���ZWW�� �ĎrWi�d�z���&�I��g�a�;����&�F�|�+���W��5�{�.�(�J���2&W4MH[�池M;��dc�O�Q?��ɼ	����gQ~A6�p�� ��ۀ]Ŷ�nl�'`jg�^ۦ8ax9�i��}��}���[XxmA˟�52�nV�.m��Dq �~z����z�=Fq6ַC/�J>M{��������E�Ȃ��
-��e.?ס�6 F�9��� x_����!�uTD�Ƅ�m��L����5�T<)|D�tZ~�4܃1gΙ������G�j�TvS�U�IG��o�C�#Vt�ᛄ�K���J���8�t˙gp ���C�W�<E�(i	�@�k9N�阖+��U.^yk��jE�A�[�lo��,�G�n����y[kF*��K���-��F9���NV�Se�Z�g���ga$�)�-z�p@a���ᡯ_��cX�D��d�h��%7Z�<�mew*� �6JpڍO�3�i4(�A��!�	<�]·��"�z��|��9�'�6�t�^~Sz��k��[����-��[y�J1z=�Z�9A�f�����
�I��������e�C25}M��E�BG��*K_�[��	�ȿ�,B��HE�Y[)�P�Ϲ���]��V���hث�+�Ř��P�4&�^}S�&q�Wl4>i�n��N��Lۆ&��tvy���c�K��?��C|ᯃS�2�8"�G���?�	�44��Ġ*8��K#���QY�	�k^���'�}L�Mj�CF"��0=��x�9��5\���,~6Yj8����n�C2��=o,;rON��Sx���9�.w�̀��uǠ,meQ�R���'���k�tn��~�/q?��^�HM���f��݈з�R�?:ײP	�9!�4�,��o��oi͏� ��
�q�]���/��*82��@��(�    �gx۠d���9e+}�]n��L���x�:���"��6�-A|�J?�]��D����˛'��㌿��α�)�8 \�U31�X�̗��wj�@n�l�߮�J5��^QZ�Gk��2����*�7
+Z�ƻ���㶵�>.I�-"]�X�!�N����&^>�������c
,܁#��Tk���7��)p��wA��vo�}#s9�Thդ��x�7U��e�_�Q��ெ�dȼs�w�l4�-�l_�>�[�-�����Sw�Ѭ�<��� �7�kO�tiq�hء1
~�;�7e�*�G��V��iL�^�z��o��k�щ�f��Q0=���F䰿ӹ�N���Bw�0Ó�"�U[t���&b�F���K�;�������ƀ�,hP�^��-(iI�m�<���������4`֍J8��AùqgӔ���C/ l4��<���8�'�(���~5���;|����.W����dR��A�m���+N��i�w6ύ��_��W��č%F��,C�"��
�Y�Aw\�+��*m7�>z���A�}꟩�lI�:s��{������`����j4,��A�m��TK��wi��+����W�]�E�� ���9��ߕ�[�z���C�){���?����8�����4R�;Z�$�:DRpYPK=�<�ixc�����m~�6U�%9�I��?��oJ������>��i�4�T����h|�m1 �0��?��П��q4��E��"�<��PFc�Ԃo֗}�uL����V�3��B%W���	*�7  J���5U	l�ȑob�;Ī�T�=Y/n0X�$s��x@���#��X�N�~�f�*��eH
���	���,'4.|	_`�o[]���];g:9���Dl"�<E2�x���j�K�-�,B��~\z��6��Ҁ.�'y<���;��S*.�YtxAJ��n�0|(+[�0i7�G��e%-*�'����t��c����K*�'kK̊�a�qs���a�����]t4X�=&��t;\�T-˻��������r��k�M�H^�h�1R�߽$��ofk��
nQAgK������fXx���#jǷ
�A��ME*y�,�L7\]���0̀3�s#��R�����TJewi�e��MC����V	����l\���ԩ�9������p���"Z8�͗3��j�e8ȝJ���[�������>L3�h�n�(�ly�Q�eD_����^����������u���WWN�(t՘���"P��W���&���*G�\|۠}�����X�9}�nZ'�-����<g�bt��p�:����.&�b=C�WP��k��$�)��nL\�T� �v�຃����#�����,-�UD׷�NK�K���U"رB%�?	L<��+Ŵ�����-�G���l�_Fq�5@���ˡ�_���D��k�IX�[�^ �(��S�{�p8����(�|Lݾ(��`VV麩B�8������a|�a�2�d�&��ө���PG��J�Q��k7?���}�v<E�w����U%\�Pi�ͣqbM�D���7�'&bTǠ(� �!*��_wy��mم{R\x�ŬFPPE����7��l�\�4��:�Mr�<�l>���Q��i@_�]΃����;P�+�0�t҅��I��}��v܂��L�����(�@��T��Y:�[)�q�X�	�\.��7ݭ�u�Q5I��3+P�]��m��4�o�=B3�U�V+Aa��dٖ<�gmߒ'QsoQk�%�A�X#l���_^���/�NC�(�\�Zq��6�NQU͖}ܘq�k��8���6�~�Y_gĂ�AUz:\�5UM|�C���4`�d=e�����'Ț��㑚�.�9Up+vA�QM����s�3�t�+�G�I=�������Jg.�n����tݦң�Е��-���c?y�2��a�U�ݮ�Fq�a�L�c2j4���!��a��o .�g���dɽ�0���?Њ��,.3
L�F#����Unx��Ӹ����M>,�Iȭ�[z�W�`!�"-G�a������6ߤm8��)s�mߪ�u~J��Nu����f�~\�?����Aݑ�2t�}�^~G.�
4����28J0�gg/�I��{7I�6UG��~��`���R��
�����_��W��Pp����y���h�-�-�?�$�>�f��4�\.�Y�G_�m��|�����R��(���e'0��x�Җݐ��8�˝ї@ �)=%�������c �Me�R�=��4M�;�>]ē�o%���Q��.��lw����G�#g���Xi��S!�*��f�o�4��K�"(3��t�7��q'd׬s��A��ړ��G��d;�a�~��e����@o�}#n)�J�����a������o�-9{��r9��C[.}���"�6(0��� �m����).��F�����ei�Wt֨h�F�}��Gm1���d��@���
�9%J�=.=�٫���~X�b�-(u.4���w�1Յ�A�Y-�����8c?=�ҡ?o�����6��-�4��JUT���ؚiI�����d�o��1��z�o<IHx�|�%�Y|¬E����+��4��H���Q{p�B�sÌns]Ў��[z Lf4H�2�(�u` ��p��Z���U�q�&WP��V�����"�j�Wc�s��bJ%��M��#}����M~�-�Ap�Z�p�h!�j�.�]U���L��UD[H�prX��ʃg4͔`�`9�Dނ�A��}�Cx���j�y����M3U�%�
�1�)t�4�+۝ms+�b7�'79��`�5��_EM�g��2���$�GzX�Y�DTj�B}��_�
~��'�@6E��D���\&g����f
�0g�)1�+E8 �Ң���UiN`�u����,s��X�
&��p�gh8����h����:A��:�?�����K}����X��Ȃ��8�{{:i#@�B�s�N\صv���Td���.�"�ʔ)�Į��$51"�C�5m��t����H�%�ʯ�G>���H\
�<���,U�]��@�9�#�&��2���}��)nl�F�hy̾ƴԨ�o*]ǭ>ڕ����q�����
?G]��{|yg��p�i	��{�(/�E[qR��.Uv���`R/�A�=HX$����W�I�yiw�tvN������s� �ux����/0�����J���	&�ޫr��O��y��pÚ�C�X�1���'�{\��7�^���~A�<ؓ�?�]dd)��.��%,Q�[�q1=��cUQ�������T �)x��\=���p���]pp;L}�݄�_���;���g�&X��4m�tQ�"�����1�ݷX�<j5MJ�y�Pa��^�������޾����ݗ/��/w�7�}?QX�\�Y&�뿫�:5�f��|�2ц���P��X�&J�R�a;"1��@���R�^�l�X>�4��\@e��ʝꧣ�_��q	����@�~����6�L:��=7�o�$ق�^n�� L��.]X��ItG6jKBc����'Қ/
W���9�<Щyw�[v@V�ހ)��E;z�i�%JϯY�� ��׮��9���sSLƱ����n@�,f+�`a�%�=IyR�	�����c����|_��)ҍ�0����:i1z��b�d|��I����0}���9�!س�p��=�3�GM��Vj2��2||F3񍗴�u9
���( +��>D.]2J"E�Ď.��I �2�����f����1g��= V� 	�;#tn^��
�������H�-/f�8�An�k_2,K]tD)�
�85�xu�n ��#Ng�*�W����`�C�]:@����ë7�NpB5��2ql��dnm��vL��JQ�ɷ�C}���İl��)}}�ծz���G���[�J𝭕Z��m�.*WP����;woB��le��앋���C�M�$�.H�E�^���S|�b��9�T��KQA�Ϭ��)=��	����_���tj�L�Mg+��f�T�ʶ����4[�x    &�CL���~�脂�i�=��k�N�-*���ÆY�M�
�H�a2��wB!��tS1��/�1�����a2�@cSf� a&r�mila*�qS�3a�����)Q��*�G���!A��f��R�qU��(S�������y7"0���~�׈U��O�������A�8���:��y|�5"��ז>~�5��/�C]��Ѭ">9��˃�Y�,�{��ǩ�@5�|������(C��<c|����-�l����tg@���[;�,���hp)m���>-b�h�Iq9�M�wI���k�S5��+2m)'�3�s�ϗ�z�X������v�lB�O���_j��I-�Gc*���2�^iA|�2t��ʨv3<����ü��)KStI&l�<`e@S�j��U�p�9U#�G@�̈���7���1y�_Je��:;w6�n��M�h�'��=��l?}�^鷶���#���!$q���z׏��8�ӥ&T��*�^����ܰ��m�cr�PǕF퓽�B .]��za���@�H�Y#��H���mڬ�Z�|�NR�Ѹ<�8�	F&Ԯ=C��e�w�.�u7Գ�|@ܑ���`���.��P&0�U7<�G��%{#�d�á!0�ɔ����(	x�NN
5l��@N�S�X��Y�H����]�al���7�b�)�/W_%ߨ���#�X�P���Φ*U������R��kߣ����ru�~��z�d(}��5���3�Z��lEg��p4��nz��Ց�*�~.��3G����ʄ��QҨ�(���&RiˮW9 ���y�����i����PP�/�"@�sH�W$G�y�trD�����?�*f���*m�ؔ:U�JT��:2P-ԞBȎ�A��Ž0���~2�V vR�4�����(~��_�-�9��F3���[[���i���O;~7r������D?	����|^2b�3 �{�:�=��>��S��`BF��v���8���߃�X8�	nA@��rG��BAߛ�:�,�NK�~�ܷ��1�u��*�i��Ŝ����'�N��,��ݼ`&�BhF�+:!�~Ҍv�,�՜��l��\,��u.�ےqT����?+x߇�|e�K�̏M�(4�֬rWٮ0������$1��^���T��գY�01�_��I�	úmNY�_53�gC�U'(�`���/JR��]
�3IS��v���b�:��1eQ�<E�>��`x���>�ԟ.f�d\��	W*��8��ט���vŧ�t��������:�l_���*��f�M~>����#1�hWئ�Sq����lf��_�6�^�D�bq�L����15���k��QƟ ��v�p�����QS/1XG2Z��´g�~p���W��|՟���	���!�\#�|փԎ��eq2��`�����덁�t[b[*�-e*��p�43�$�&]��vaύ�pD>ʻ�|���<6�n\ �����<��h��c$xL�z>+��M�ؙ239"��`iۨ��it����cb�}V�70�v�c!�)��s�3�B�0z��X�������� MS���]&ԑ\�Uhⷎ8G��X��|��s��������KIW:_l%=e<R������%C��_H�<�O^�����������13��GM-�"X#7�)H�@��4F3��ʜr�[R�6��D�Z�࿔���ȷ�#�v�'��:���D+������&�s�{p_M|i:{����]��"w���:����p����~��O��R�$�����`$�s��rf��q�Z��� q2�b�/��(���O#������:�t�����H�\v(�m�-���:��f����w�L�}ELjb��c�ae+"��*I��ebO�K?;�~�-,;�j�-@�:���W���Ղ�31��>��xL�����9&�|5�7	�L���G��I�l�����t �-����G�9ြ{QO���fԝ��7Uq����ܿ{����ͻ/��n���>���>�s��7o��;��\�e�`��K�c�m�S7J!���W
��z���'l��x#�ws�v����k�] ��h&y�t(�2'���2�8x��zM�ERO�(��O.󸗪pH�	�֗�?c���*���Eq�ԇ�g"kaq�쩉���ҲA�Q�@��$��6f67{�Cg�3���B$�m�Q�2�FjP]�&��9Rp����Kf�P�:ݯP�JJl�v��<�u8	�~�*I��� ��@0�,L��l��e�@G�6 ,ꦙ�T�n'��O8*|�����"Z��\��\N�+��[?�p0X�Caܪ���?$���3�&闔������#�H�A�*��u׆僈\r�΁NyH���4z�f�~Ny�_�F��E�2��?���"}����A)/�P�?-����O^1�nɐ��E'R��o���K�O ��;��90�����3���B�p�Dg'b���I2�d�ҏ)��w�ǁ%h�B7n�s�T���rs����#�-���cL�F/���D�qn��{y"�˨}�9���[{�ؘuszP`2,�{�r��m�	�sI���R�&�/����L!������*�^\��h~N/��h=lSX����ׂ��΃g9l��t��%�#*;9�k�?�_v��b*J�~�o`t�:�i�G\�o��|�����םMC���U~c�x�V������S�NЬ�,b���A�ȣq?��]֓<��=��f?�����]_V����(�4����oqrlK����K-�����c*�z_n\i�'�3�F~F�y��,I֧;���P>�x��S����gar�ڂ�#�(�y�<U������95�gt޶9⼍��|"�� ��hS��E���::��˹(S"�)l��.=
��M��c����nb{�1vW�?���<?&p��.^��=���ԩF/��lT��r�e ����r,FRx�����/Ӝ��@�c4=��"e�|2e'�CM�aT�ȢY&Y��U9�j��ѝ�^�����볤�;�Y?-�8e}?�P�8�'l��k� >~֮u*��V��V섎܃����/
?\�����[t�7��ztB���GL���-Z�輖���K�TW%��0"�@}Bv=���j�4�g���k9$���\Q�ϓc�+�Ss��e���ɣX[�ܺp���_XcCU`��7�?yUU�dե�d�nIJǟ��Rv��=�9���T��[��~䅰V:�R���E1��!^�tޢ2)i�}�A�8�^�)����F��lYt�k1���|��U�o�aG�	z��c��?�����7��S��&�l���ٍAP/���1�פ�h�<����AC?y4[�Yx�ϖ�i���Uv�]5
�ЁT���M���S�r�|����m��n������O9s�_��I�w�L��}�v�'������j�1FT[��^��`�+��_�bB.}�1Aguk}Rί�r���Y>H�h�2�W��ʗ8�q�+��A�HV�7�G���@��}{�/F$TU���{,[u�(T&BpC��{+�	-��"���=m�|6��vw���,��~���і�Z��-�\a�H$��A
}��_�9�3T�m@���r�-\H�Q�Cb[8�]�
e΅�}Ӹ{�3F�"���@��`�����lewd-�U��.�������d�:�E������:������G|�p��_�D����xw�Z6�Oꄣ��yT�8М�&*�чӌ ��}vF���>+��Q�$�#&x��]����(�ag�rwLy���U����?ʩ�C�.Tz���Αv_�r��I����&ъ���B'�:�.m��m�
�_�L��#Nx��f�ƛ(&����aI��c�ou[Y|ػ2�ͩ�j���fa+(���xJ���{�BS�M��1i��g��g���ݝI��Pfs��6�M�w��vRN7y�!Ys�,]�,��J�t}��Ӊ��� �����YI�ǋ��srb����^�`µ�B��.Nү��GË2Y�`�!�Uv*u�OO�n�%���e%?���@8    [�-HH��_�RVzE$�296���A|�{z&�F4�#/tyu�dy�����?��?�G�O�\�P�u4�μ�q!��ԫp��������E�r|q6FqX1]�H�zp�:j��
dBa�-��J2�ĩ͕#զ����yT�^�hy	{�|�>�俗
�_���'�E{���E*7?@չvc��W���%&���LͦM��|�

]`����).��/�����gw,��_ڇ�Fw���} ɕ�({r*�u���Fw�EQ��{2�����V���� ֯^�:��C��i&�ٻ)B?�{^��5!?��|^��F�WX��.0��4r)�:w��$⑯�ؓ��cP��[]q	�o�j�m�h�t�,E�u���g�L�����|�Sv��VTLa|Nf�ݢF�k��:������RB�6�E|�2Jq���<:��a=d�'Mf��5?��������=4Ɍy�+�{B�'0�Ϣz�6�V+�x�WU�r��lle}PM���<K0mG�$��Ɉ�!���ҿͭ�
�nV	
;�<[u�Ub��[�D��8�[�N�yj�{��	4�1���!�z������Զ�2��WP���ssz��+�����⇯���&&�/DQ2�Ę	�bص�`�1Fw�pt�;��CWқ���˯���>���I��HD�b}0���R֞�
�|$��[���q2>����x�����#��P[���|B�:C>��Լ��	}�9B��t`��i��\F���g�!~��_����&�s��_�iU9����m�$�	� �'7E]���/�5�2�b+Q]�������@i�TbrOD��3�s,�Dk�&� ��-����n�`���<�T�^������[�!��H	���2a'���6^!�L�Q��M���FKuw��6؝� ��qBwA���Jv9����ͳ����������q��@�2�� �7���S~]����$�u��nՍ*j�>�9�T�?�j\�jS�}�M{��4�˥@TO�l:���$I�%w?��=��[N\.�k�����Q���k��|�;�	F�����*u�ȫTQvƍV�����K䪷���O@�P��qI�r7��bد8�t��^8dhD�&�aw:��Ndzv�;�8�/ǈ��,>F���-��#�;�c��#�F0��&�4(|;�9a����Q��y ���/O�#�]!�YN�][�ɀ[��5�T��or�~���m[P£���������������CN�.ָ|`�b��у�F��49��g$_�py?�0�́g���>�eypW��T���Yb�tS��p��)�N�y�t���ڦ���U(;������T�(9�I����R�=;!$�?��'��6.�6�h���"����ZٹsK3������p�y^�������j����Z./jTxh<�8F�º��w�O��l�[ƪ{��ʭ�[
�����N,�쏠�kF�Q��o��GH��]��\��>uF�4��2v�Z�k>oø�������I����gz_�@�L���A�Өu����`��u,�m��2K���?bJ��W�õ��f��&��$��$)$��9&K�	�W��~������$��>׍*�����J'z%"	9��.}	��
�-m�P/�͑�̶=��J�r|�0�0�Q{||r|ǯy�+����59�,qaM��uhKm��:���A�r�8�UЄ�J���.��z}E�4����O���y������H7l���r��Z�}^��^������wP聓�J;�#R�
�b��P���+w�����!jOA��
�'T�Nu����~�;�;���wC)�7��O��^,𱰳�*�>����o�]����~Н��;�Ώ�6���9?QŁ��i\.�1��Y����5����x���n�� �7���XP�\�w4��/^Ђ+����h��}��ӽ�5��ą�L�3G�)��y�`�9��%��ԘP����K�Q��
�eU�6Jb���l�r�8jd��ڤUmZv�ˏ��+�[����-��"m
e�^��<%���f�������V�A^���[�D9������5�5.B:��v�<�T��ϻŃ	'��KX�7$���'G��<r�iG1&G틈�♜
�r{�_�:w��;ee#S���m�gC.�|�������àB�;f��N�W��b]Ѐ 6G������iA�5��\�d��a�2�����_�IwQ0�L�晠}<�Bq�����'��y�Ѭڌ1���k �T�Rv.����~xy:�e�5��+�oש��:~'8J���i�❮-00-�o�@c7�ޫ�9~RE�0���g)oB����;�oT� �Ьhk�?��Ğ��l����z9��5�.Oh樻f��%}<�	aa�9>^��}m��ƅ���Y����h}a��?�B>e7�O^������i��VS>%/6,�Ys*�H<�x�%��,�G�ډ���٥ﵟL��r`�]�T��j\�v)����ј"��eN]�C=y�~�z�ߨ�7�k��+�,�����:b���49)u�r=ຫ�Y�ț ���T�e�hg0av��]7(d��������V7?������
�;|�[�����D��$����)'g���h���S鲞Z!h]�?עa��Q����vC0�����偕J%�(_�̷ۦ�"~���^�2e̗N��k��9�z��!k�V�q�B�n~"�K{j�W�?�o5[�]��5�'�Ҟ�Dzťlq�c�M*|�q�F"��3�=�3@O�q�'��T�8g}>"����e�3�v,�6]/ûK��N�}�-5+�h�2s�,]a�`���A��i����H�d�_3��\ ��c������s@��69�N��*[Ƴ�Mg�E����Y�x���M�����8��o���僂JtS�"��[��t �O��+���$��r�?o���;�øl(*�CGlI��Um+�$S�n�,B�T�\kf����Z�=]��7!���*�u��o��Ǒ�cH��q��ɪm�������U3G/-�|
����w�_��-��d|��>�	_T-�݂9���\�k:WX�u-�)������0�a�;SS�!�J��-S�!	$�����ľТ�b���q9/���5k�f�k��(���1�~e�-�86�ۃ�4Y3�$���i��H47҃g%�7�CK��u�/5.�L�Z���)�>Q�c:K����a	��"���V���Q���w/�/��5���znŲ�>G�ehyk�w���hG�pb��I0%/�q�yצ���x�p�'�d��DD��	�R宫�Ѓ�.�G]۝�c�#YS{����_�Mխk�R�N_��� ��5b����-��u�]����}`���!ڬJ�*8c�V����9oS*�<u���^R��V6sme{����;pY��������Z`�}�mm�T_d ���cóf��s7����1fd��=����Z�o���Z	��i��M�]���,X*������mh^�c/����[`zZz]΃W5���҆���4�Rerׇ��i6�.' f��+g�������\r\8܉.�	������V5�e�6�R���p\'�)�љfZ��0q�d��P5)y��T�X�꒤����1o��L���	k�/��9�	R7�sHjtJ!�F&Ir�"P��xR�oO -.8��R����y�! љ�L2%�̳8R׆��$</��9a<��8Lܳ������C_�����)��� M�Ɓ��c!ʕ��S�s�o��)�y:��I~0��.zj��-v��̄��\䏪j�L��5рcR�(�!���F��P�3w}8E�W�(W�����=#���u����у.��.���]� &VB:w�a�܏��(U�mAUjϬSU:��
�d�A�Qu	\�Wħ��?f �2�OXM�Q��|�=��"�X�/mC纡)2��x |䄚�`x18�mW�uo�٪R�^VI^S��8��4�F�[�    ���Nյz���3x2��*�PJ�Ӳ��/�X=��N�:yH�U�~���Gj�	�q=t&/<@��u
���2��)$� ND:��W/�ɡ�>1�-��2��������S�������Bsط�t.M�]U'�h��A��(l^��:�g�z�!%7�i���V�_De�U�Ee\���e�.(�B#$Ղ�_-���s����M�ʦ��Pi&���}c��.T���-��(S��*��~�;��[�e`*�ܨ��Qӎd����A��sx�6{��%f�%$AӍ�L���iå�wRD�I�;�\6�힙e��$�s�Z��A^����l&����K.Q�X)9��6��_fW�F�0�(v1_Q���*>f�(7�u��ӈj,��P�[�o��"Qa4	_g��rC�/D4'�`����LU㥲C�#Q���_P2���{�4�rAM��w����N`X҂�y�e��ҍՒ���� 6�k�2ѱ/�
c�E��ۍ�u���]��!v9�or2b�>������>n�� ZL-Tڃ����ݤ�d�u?�l��76k��h��+�lrx>�N�y��:��c��(����*l#J;�nA��b�f��<�I�p�UL�عo���]�;WW�<ᴴ��A��Kn�~�?Z���E���</���q�gS}崏{j�H��h���{��q��đ �Z
w�}�im�$�o�B��u�V6V��Ӻ-�*D�o���>�ӌ��b���e��`�_dC�)_)l5G	���q�8�VWq�q����M�܌ҡ�?��,g��\,���uwz��m�rx-�+�2����ە�(n�w]1�'����^23��ߧ53���p࿚C�`K{y��I/�"UD����z����R��y򊏼b��4�|y6b<	�}�QK�׬��A�޽)m�m��]aJ���I���ԣ����t�h��hË�j��ǌ*�>���Fܼg�D�kR�b��b=0�� b�9�ּSM���%�IS�N�{�~�rBlt��c�&�P�C��VߴE������c��T�s�g�t^��A;M�{��-��xՖ�.��vdY�c0�)r����Bw6�?/�L}����#M��L����Y�{;rO�t �y���G�����L���\��ƿJgڝ5���s���p���������@�e_�ǷJ��6�v�pѬ.�	�-��ͳ�p&Q�����E���+�|x! ��_�3�06�:&T}R�b���P�-�J�p3nr�����'��|��'�NmZ��`k��3 ��*xP�X��W��<xS?�j��p������n�p����2V�2���ju���<ɸ+�U��@D��]E��9��r�pu��)��#5�`���|.qk�|�P������ci����v&��-��)%a��J=�%�c��6�A�On�:YA�
w����M�fT���4���]����AwWfs�U�n�**y�x&G�&r����Ɩ{�`��P��[�i��R>(��pa����JK
d)ޢG��h�3ʱ:���˗|LP8��+TEu�H�S?�?ݑZt�ԠG�����4Ej] �m[��%�$�S���������������p6���~�C�x��T����=#���&0���M�6�?(���֝x:+�[=���o��
, �6q;����h(j�D�����j��>�ݶr#aea*V��sn��Τ-�ޯ�0�q=%��z�U}�5��ҕ�Q�3}
���T��])���L�α��m����Ƶ��>�Ó�V���'U����qs/�w����Cf�r�fۊ����.����תXy<X���&\��,Q�5�"j��49�������,0���
�4��ڊ�V�jJ���_ӕa�B�sFI�ǅO��ZW�An�#qN������<�A��.)ɨ���/�?���R�)��2그�����*R^�܅W�<J|�G	�o��[�W�Gǹ�M���w�^W�c�F�L�,h$�������ͦ��Ix�.��ӡ,��5\d�? ���ܑ�����P�[�0a}�)��/D�䚆�dr>:j8���yW�وSx�l�;W.�T�8^i��.��W�n��S~���1���)�P�׈F�r�:+w��f��*�t\�~�AJ\<>aG��T�	��w`���r�?���î���Z����[�}������P��S�v��|�	<#����`��Џ��\?(��<�������{QHw��{�����J�9��5��p�������d�Nej��~�kN޾W��䪾~��sc˫�,W^��<si.j�nj��"R�KSw�eO�;Z��na���/��.��a#j��{�Slu2D�B�2��Z4����-��ꄒA� �LQT�\�*�:5�\䘀Y���n�[��A�n��9u�y�0�,~�c4��|t�j�c�%'|�y�2w���C���2�˃m�����Z��9��9i^oA%]�����`�[7 ���آ���Gj8�-R�({�QvH,��P�\�r���hg���#ea��'G��1��p.j�O�1ft�Ý��>)dĴ�Vf���9U����m�1Y6��\�v��긹���D[�/fܥ��&k:bH����I�}����ջ+:i�k=�K[,+����1����] ���t[��z�U}9��>�"�3ǡp�X�ψ�L�f�ꕾB�Ź~ޑ���4�{r�2��_dl�-([V�p��V|Ϟ��5�B
>�)-�y�S��	����;�ZΜ�]��S���Q{,v�d�8S�IR��u�o+���]�Ss�a���}�g�
����T�cXOAZ;jP]-�g��9�:���F�Ɩ�K�g.�XՉ�vWwvc��:���]B�/�.��&tȎ�M
�@��,cv�r���쿑��Z��Lf�{x�pbi9��Qo6�lv�`ϔ%4G�5&���F�)Rv�u��5ov�oE`��h3�$�h$N�*���܉��9�į;��P.V,�Ѱ]}��g?"�K(�Gld����o>�0��Es�J��Xrt�3�۷��#pg�d�������İh b4�պI-C�~յ�صnbH
��s2#H�����MO�ſ(�6��������M1*��kA��˴�5�P.��P ��>�V��[��]�d����=�bLyDO�c��>M�?M���w̇܃�itu�
l��X�u���:��vݜ���O#������Ñ| �><}}	����;[R�C?r�i��m´�����2_nWH
'R�Ыs��j���ޮ���
���8�SRI+C ChRƮ`	1��s1�~J/��[�{��t�
� 2I>a� �K�z��1��H��.����}5��7�s�S�C^���)2@�F~�ˎ��L���W؉���oTc�B5.3��5{�����8_��ʵ�yi����`��C�Gj���H��a�M$�P��wq.F:M�dW�ԉ�t;����sp�H�c'���������z����,d���gb۫w�H��u�I�J}OQQ*���{�k�)����F��5̣cn����I~�*%�師�v]����}��H 0�&���T�ds8�Qm�L�5G#����Ư=��}��ۏX�Z��|�����V��sN9w�T���Xqכ^m*{
�f��]J-\/8>���r_���?i���ؼ�H%���#�%f�/z�7v~�����9%ս2:%_���)r��,dQ�׉ͣ�N��T{\�N�͋��V�j�
o��,�5�L���H��j���I�H���8jj��;	;��F���������sr˽I�6nӾS�뒁�W�~&�h�&�!��Mw�p4�O��S�[����{P���Vo�(���x�oJPe�aO�����o�0���Xy'����5���0���JF���� �����xϗ�����T�%CUiKY�A�<����晕�ѿ�`��\��O���]��۔n�F7��"[Sr�>5{���    ���i�>�E��*��ܐZ��%З�����А`��0pAdzZ��<)܆Yl6ʞz8��0e�a�G�]$�1Y:��h�=6s�hP�5��Xx�<j���-�����q���ز,���|�9y?8�[�&�4Ij6"c`��P��*ܼ���0D״	u3'-��"8/]7$�_�HG��Ђ]���Ԑ��1���A�G���E��BRO����q�i�������v�Mz(V�I��'F� �B�S��i==���2��p�V<�$Jo;�޽�,��e܀aT�a8�
�ō��=3�/$�i�e
R[���'�.P�j�������u�7��J?>�b�+�}N*әl� �]dL)|m<���V�V$�+��$B���>�lo8�ס�`[n8�8+s�P�c�j�Vu���Mq40���FU���H?��v>dgv��K�ʥ\������ޅ�%�a!v���v�|�.���S��`M
�]c�=L�8��3��oK�Ʊ�jc�uv��d�`��rI(:/r$K��
-��V7`{U,�
�
��Ewמp�/�� �}�ͪB�a۔��ah6 q�7�� 2g��r$��襯\����G�lyh�y�����^!�z�	�%�Ĝ�o�u���
6.T�x�Io����+����q0��
�I({�%w�J���׵���U�����s.���X��P���/�k���K�=8;�F�3�����MĎYG;�#>{�%�g����x��K��sܴ���E�~�E:���S����d�����Ң�k/�Չړ��9�5w:9ہ06J��6��YiU�?ِ�+�Ap��}قj��ÜˌM��Ի,�dxP�n�Q�J��0��(���)	�k��KnY�.�A蓟w�礪n{��.|L���|����w�����I���%��W��2������ґ9��@�j�_�����E���F5^~�5X����uI����i߷='/�q�ۜ����U�n8��gJ9t_���~gޖ�8�mT�����L��aS6�x�G1����[���c̸iu9x��,ee������ɦ�fP���r]�8u�_U��Ⱥ�-$8�^��Ʉ�Y5gw����b�Cm\-�u�Bp�T�0AUs�L�z�:rW9�����S�\�����V���G/�Ӣ��!�a"lzj��-V���U��� HJL?/z�q�����l�6��]����/E'��?�E"����Uu`��HX����s^�ܸ҈{�����w��U�^וGԊf�O�T����^��M�d�8.�`{s�:Ǳ�u�XR��0�j�6p(�~r��q!63%��@ݸp��qѴ�lP`��b[��_�L+���PXy>W��]9�.��r!+츎��T�1m�s�G'Z��abT&�W�\ߔ۴���u`�qJ��4j �I�)raPw�n����CP)�K|�s�y�*��
��+������Uν ��8���8d��
a�Vt���ǔ&�aH��DhF�Z5�2��9B�őU����MD;�n �y�>ʂ��ˊa :�΍xs0"�x!7��3c7Źq.�� _\�IՋ�B<6�tus�)l7N����iΟ�z8��yu|�pͿ�^P��V~_��3���Hn]L�1�C���P�G�'����Z��9)+�x^��P(8ӂ����R���l��;6tǞ�H��Qs�<s��;�e�Y���`���Fa��l����ۄY�@�A�&�K\;G���o��1��_�.#�2&frO;{�W)q�M�̨�~���;J��W��P�2��*�~���ȱ����ޖQJ��ۀ���c���޿r;���^9l�p����P��;])��TW�"a���&�~0�R�d�S���N�~H�L�߰23���_z}��O�w݈�S���n�?��hl6w�Z-������?~\�NZ�+�����h�XLO�Ebhy6�d�CEq�w-�������n���3��ݥѣ٭a/��twyXCnD�f�t�b,/��!M�j�`";h�ғiʢLy�8n�N.�����J8��̖�DX<12��c�j%#sS��y�h�<OhN�c���������r����C��~T�޻� ����*�h@��Aנ�U{̥�>�I�J������2t����p;x���˗^%f���#|�p�����S,8D�#[�w'���ѶR�A�q뜦�����!�����p�-7#�`*������`]�d���`F��[�*"�9I8-̯��:��c����'��%��Ff����:o;r�������S��"O]��[7�����S�����������n*�	{eT�z.<o�Q�z�����H��a���?'�@�}2��N!�mT���qB82���Z_4PE�|����]ܥU�&��cl����rhO����s�i�v�N�.�#��mrs�C׋&û�����U��ȟ�Mr�w�gI�WY�`8�Z��Qw�{��d��6Ns-�f��i���'��-#bOn��"��uN�W��A��ɻ{jv:)�1 [oVv�T��������O�ZPB�=���Կ�8f?��_�1mk�P�-�α��i��W��ۭ�y��R'=�1���OX�
_&�ڔm}a�m�;�-T!L�y�2��ڀ�$����5��R쫚�m�-͂9[��x�3�Ѻ��_�^@c�9­<���N�������ʀ%V�H�o(ʗ<�M�|v�,�� @�7<	f�4�YJ���
�6�T�o�!'��O���H��5(9�Ӑnv�浠"�|uS)����π�J4�G{U>$���8C���4���k�vD�\?�-��Z�o���C7&�h`L�;�/��qJ�P�'�p��}����O���v���1��x�xEyp/|�$��O��ٺ¢oa��Z􀤰r�w^���`P�v�ʹaU�
��Ӷy�)=8�wJ��\ʞ�WGHt娑ͭX����@a�!"yݜp��y_pa@����!��7�y�����2(��BXg��#y,qș���뻶�9�ۿ��e*�K��q����� �8�n<�a �-)��R�o�v˵�V�z(թQ}d\m������O�#��n�/7r=@Y���/u�zX��4R4 8�-�#��aep8�T�%�o���u$��K�A�.(wD�ڹ�pazGT��Whi�^[�(�� �X�`�
��׫�a��ܶܙ+7t���7�����M9e��*���WnL�l�:���
]�6��&�Os���#�aK��oR�jFW׷ec�'���ݸdع�3Y�B�lF8��i���z��<���>ˉ4M�k����X�ɽ>����tE�#0����N+��0$�|,�x�
��\��3�A�n��K�B�~ݬ����R1o�G�f���!{-�q�pB01���,���~��<�I�qN�`R�X���ި�r��VO3Ss��5��x&QͿu��db_��7>9�����!7�CL��	K�Cb��oQ������m������z��f�3��R��;xO��z��ݎ�6�����M��7�]��e)!S��c�R"}�N�����{��x$�`�F[U����xL�m���ߨO��w{��7ȹT��$��f�����V��6\b*���_xK����n�0S���r�e�:qȥT��E�R�P��{�_ؿ݄o��T-��֙��}A:�S�i�<�}�t}s���:��'�V�Hu
� �
�D* �e6N���>:�u�%�t~L�2�^��L�jG(�\c"z#�%�ݢIK���䰪�6-�}���m��W���'E��JEǧ�/=�'�ԣgA�8W0�����&v"*2��u�l��.�p���KJP.X�Q�����
WhEX���<��������C�Ow�s�ޢ��
"��?<N[GnD�}�����yH5,�e)M����n�����|�z,(}�β��R�󬛺C7�:,� ��Y�*����/X�L����?j��=y��
���G�콲�b    �p�|�ִ�8��Q!�Y��pd�wo.��xg��WecWB7X�qjנ����~�M�g^����!�(���M�y�M◗�;0ف�d!kXUÌ�x���l���S�(�t8Z��p��IR���ͧ8*^����Qd?)�r�>o��[����i%�nv����<�e���HvE۞��O�Y3?>���ǳ�a��o��qC���|�_���$C� 5�L_�a��|S�rz�X��8E�fD"',�.K.U�5�X��@��a�^|B� ��7ĩS�s��9̓.���2q�6(�	������ܗ,�md���)j��dq����`�%;T�|�"&�$&
)��~�~�{��<H�\����.�D"A �3~���fy]F��tL�~i�\b��F�O/����7�ɹ�T�t�]4��?� ��l��&�F���T���+zegd=,��*�*v���F���b?>#����n�Xx����I��xP?U�XlQ4�&�b��Iׁ%/�g�K;���z�T݈����C���]>Ǚ~���Q6bPz�Gq\�TY����~�U�@w�U�+t��J��6F{�[OE��ǭzYP�j�D�,��>Җ��n������,����f����8
"$��Ѝb?p�Q�14�-�r؃0��m^����v��I�oI����[;e������?��xf0�Ezh����qo��]�����]�s>�	�Z'����d�� k<��ߎ��{r7|*��Lu������"P��R�����A�0d���V��nX26Sb���\�V�6$\fীp#���X��5��z��͞'IDݓ*�|�uN��v�[�7a�3�Kk<n����~n7�B6����XO�]�sߎD:��(�"Nq��U3�Y�W�R,���\R4r��EXR:�K����6[�1�>>]\4�o���,ìU�F���Җm ̃U^Vp��k�����bpx��ٽ�ȍH�G�~~��A���]�_I'�4x#�&[ڡ9?ɒ��
~ִt��N�xG^��'-؍l�*
��㳰��&UP`��p$�T���k�#h�X����1
������Ȟ달p��F�l�Z�����ݝu���� & +s\�;0)bz���c]ֱDt�MY���k~�c����~�`fLu�o��jB���$��X����=u.�����b`f����?UV�`�*%� 1�3��������>��[]2HZ��ۦ�!��(@Fv	q`8���l>�_����ٽ�dm��,:�g܁�gy��S�M�|�Ź�����pQZ�?(�r�,'<6�^o-=�"�P���QM]�S�ݚ��/oxu*�� ��k���q�~D�@��Ot�f֍�,n�Ւ|/e�<f:��*�dOy��R'��J�)��2$�)���~9�	j��s]�h:�=�Y:*���޺#��}�%c�<k�����]R�҇�E���y����p�0#��+O���Q���*t�I���u��<�p��4�Ҧ��=�R����_,8��qx�P:ix���Hc�M��ߚ���76銜�RU�X��r��ĵ)g��@�Y��g&-�lj
�;�r�}į��;������%�|��O�h몁M�u�u�����
s1����\8(��o��Z�d|k\jr�6�g�1���b&5k�c�9��9�ƞ�3w��of�Pkݫ�E��V�"D,���߲��wWa���S��}��k��a�2�d[��R�!���sN)m�12���3i/��iA�	V��a)o���\(m��t2ev̇3˱}��R*+�7��UYi��j���_����5p �R�{�`��{m5Du���԰��}�i�����\��a�O�	����~�87N#����@���ګi�A�Q;�H1�40���O����;��mZ�G��	�|h,V���Л�	�޸y�n~��zTh���*��0GЗ�%ɼ|�����\�����M����˺�UJ����Sq�\��V�P��/�d��:�a|�zU(�ݹ{��p��U��l�z�~��<��B�����a_R�d�)Z
�;D��!�[y����N�]6V�̷��~����]R	�����)���ˊt�ݭ�i�K�̖G�<���)jo���]��չ"�HP�o���U�܍dW�E�{�<3q<\�Ǣ�X0��c&?�p�.`��u�-	?�mXQ�}���t�<�S����Ӗ�=`�KD��$=��;ݦ<.��S/&|D�1(��im�y�yM��X����c��_�O�^lQ��5��U�A����`�.G��P�/�K���"�{U�U����;h��T� v���z��ͻ+�O��#�q��Ƙ�e^�7�Z�4*�	6}�l�V���S���$����[m}����13��
NF��a���H����;�ҍi������U�,4�%8��:t\�6M{�iJI�g���8�?w�����{��9����=8�T�������j�6�t 6�侄��� k��Ts*|��zIi����i�y�èV~^]�Mm�x-�v�E�v�&ܠ�V����8�yZ��o�>��l�~"1׋4�$�QN��O,�ez�2:~s0�2�?;���1U��:�#����?=�(�;"W��l5(,��_�u%`��6w��m���C�YP����~N��y�,�<c*$Q��*TJ�U�6�I����k���%E/s�[7�r��q�)��6�FCR�@�|�u��M~�z�e&6�-J�ו��e�ݮ�8�~����ϸ���[�(� hʟ@3�44�z��B�;e��U�K�aY��|4�\H����W��uhz���b��<��0U�)`�:�
�&e��{jY�6�b�_� �#r>r:v���S�g��S(���-xL��*v���d	c2����"�RY#��#�m�w+��| �nz	��]d�ЬV?>3>i2��agwN	-��ٻ�x}p��t����P9��x�F��B�UL2��Xy�U�Fݬ�@�Fsl ���J0��.��p�Hh9���r{�HD�j�T7P\=���;���z<T��zz�����G^TX����q�+���aM��o���`���X܅O�`��D��%2�o�z�RX�?��j|�%��Y=2iБ�r��E�g�h��_E�55[���[O|�K��z� =t� ����ø� nEm�sԷo��6�X��p�f�G�}T!���Xh�,������r��PN'��*6��&��r���gB��{��4-@m]��F ���r�uL}}_e�ޤޕ@��ȝwu۞�w�*(�(T���C�j@}��B8�R��u	?_�[I�$|��@�[�|���M(ʟ�jf����ΊG���s(��(��.�*`c���$�N.���}M&R��$/O���*� �ﻟ���K�`�۩�dJ�w���o?O��S�?T*��X�)w����9�D��Ŭ����we���,�4�5S�=�(��M���A�GX
�&{M(�vC~T�ls%���]\S	�o0OᔩX�TQ���ma6=�dߢp*9�ͥ=�K.}Ry>��@�4��#L|�FrN��g7,l�l�=4/s��ğlB��w���*J����E��6�My�[�N:��;<��K1�I�wY��L�71�H���Ԭ@��z������
Rm�P"W�d�P�q@�[����o/����ݨ�o:�xX�����ծ[y?ȵ�q7���s��d�V�*��;��Tڄz�@�B]Wp&����h8w��Gā������?�Eo�]5��� �C�!,F.4oѴ��_�7"����?ԡ�b|��I��9E�A��N-;):��������Ѿ�zk��9�>�6�J�'[u������%
q���d錻d� (�� ;l�2�Ձ.7��x��:bD�$uZ.vpV۝���Ŭ�U�80�]��Fǆ���.��3��h,���@	}]`q�)O��\B1hz��Y�b�T3a�p��[�݊V�Ep|�Y�(P����Te���:�    ?�@���N�D e���
]]� e�����[4t8�����.|���r1I���'����Jm4�U���>r��4X���5�)0�:.,�ч�$��]n{���X�q�����ѥQpЄx=�տ�<�?�6+5앾4ôi���Kf��/��.���i#�)q��1�1��r�٤�*{��j�ߌ��Ӵu���t�X�y���_�w�h��iN?���~^?7����(���.g�.��'�u<�)UKS�ȃ�.��_i�x+�'�dL}���i�nm����4���L*RC�:�#o4sS��T_ގ�^�G�`�4V�]��/�d��cYZo
��tP��G��L��W��pDGT<�6�(]\�ʆ</�`U��L�^7����`��q��f���uF�W�S/�����A�(�뗼����fTE����>_Ӆ�0d��}�b�(��u�������y`���Xm�E,E�Ҧ�eC���r��h�  ��R_.��2��iOX��f��#:C_�9m]d���d��`/0g�ݜ*P�MY��Z���~�,1�I{i�|��O��A{昫����r���ŷ����P�nq��y߬(l���b<[?����J����������,ɞ��`ڍf��2�)��c��%�ʶ�
e(ؼG�8�Y"mIe� ���x�Rg?�u�&�� Rb��Ox���#�����ߖv�[�28a�����j4r'�IEz5�M5��B������e�d
�6�p�#'<6�l��{O��nB��P`2vG�Lx��� D�r��W��k&m����uN\;x"�թ�H�' �ф��e>y�B���p�#��q�}�V�|2�/�ʟx�܎�働!>/���A5�h��E35}1*�y�1������Ca҈@]�/F�����\���-m�&�ᄃ'��O�ҏT�K�(�ܧ1b���>=�:b���T���Umʨ�+��-:������kQV�M����c����5�Mgŉ,��Y 9Z���XP���է�Q,5��΄^=rF�To���ı;���a�M�@�	��*?����,���0q9q�˭R��)��F�9=\.��L5C0q7�n�/uP�8��A"�5V��]v��"�`if��UG�m�|&I�է�d�:;���Q������[{)6���n�vD�gr�O�h�W�|���	������e`��7,+O	���ЈoSY�"r��-Q��b�]�rS�e�$f����8ಲ�������WV1ZNİg�&	�)�&vX���M��S�S���AQ�~g�/����flu���[{��]̀ҍ���������Ҽ�b�hJ��t�A���I[�Xscq.j��1E�k��,�#a(�L)��v��;`�-j�����j�t����8��������·����WYٔ��mPW�M�ϳ��=E��g��9_�^��y�۰u�g�p�=(�)���#N���0���1�V͠ޒ�JF��}qF�	1>���N�����c��Nb�.��M�aN^~��ix*�����3�	�=�%�¬�0����w� ��M.H�]:�A@Pn-��f��������;�|1���h�����_j��'i��<A�ꢰ$�{��=e�@�������-��� M�8����y��C1��ѵ|�_`���#�Ϗ�%mp1ؗ�-,[uQYK����3Q��.������$am��W$�>v���#2�v" 	I�Ɇ"�qH
s;�o�im7����:&����"���&*����]�	�� ����(�p�.GC7���zf�.��M��]�BY��9s�:�d������
��Q!B
�Z��s)�:c��hL����T�إ��Tχͥb��b8�ȁ�g�sb&���lGW��(vb�FN!6�N��Zz@��0��C.A(R.R�����
5��wu��Nb�%Y��]�#p���!~"�,�æ�[�m��XWu2�eO,�6BsN�/�Q���k�T��:FvPW������J�#� �+��=W\$��������������c���J鞯vQ�ӫ?-��O�śZ�H;�*?mW�SS�"������)����	Y��l��;J5�O	"�������b��2�HJ|��G��D�dqO�D��*M�DN�����V�4��K^4��fu�����Z¦���R�x�Q�u5Υ�qHl��B��?���)es�!����v��,���ߟaIp =Nr�\6�fC=���^5t9sʩ�A����C�"��p)|�	I�
d�j�p����ǌW�x=���R���r���iVJ�,	F-�&m�W�f�`�b�f�=#���\��x�1{�93�y�����xt��S��J�����#O�c.
nq��AY������JD"�]~L�ٌ���2�,�,,��5W]l�˝��}+����ph��Wxvؽ�r���&�8e@W[E���]7V�3��b*S��X��.��/�)pa������O',M:��0����{�Tj��Ajݘ�Ѷ�,�|��7��+S�A�4�ߌb9����>�����h#0r^W���$6��M�����<�4�����낫�>7��zUìR�4HN�q2l��:�����C�-bP�s����{���O�'�;=_.�o�};ϩ���5<(x̶����@ޣ� ��R>�����v���K���c_*��y�-?��mfo�_isAN1֏���#�ц`Ae�%���/Ba���[��b�2E����V�&[a�2Di��ե��ݪCm��Ǣ~�^M2���͉xL"��Dv��<r�����c������Q�!h����T�������%S$�#=�~qCb�D��J���D.p�߁jِ�أs��%����[�>�b?U���SN�}��B�uu�שּׂV�&�kU5�}T)�2��^�6c�N5+��7�����ځI|b�Ww��Ħ�z���e�|0�	~�����0<!q��)��JVX�[�W�A��_�>ˏ��
�|>޶h�j�����c����ɰq'#�+������x�)5��6�תF�J�q�u�RO.���	�ܦ��K�.b+m$�U������_:���{����.<��$�?�K�p�Ga6{WӴUU	�5urN�5�>�P�	�����H�G�z��Vg�]��sVr>8�>b�7�]�YR3rA��',�v���$��&��J9D��x����tQ��c���>=�论KX�gJ�ym��x
�ib9M�I7wYR�ɥ�:���x�׉�rؠ����c���H�v��������Q7�"�cR�ϥ�E�L#��C5B��!��*���ƀ�=�h�d}���Ω�n�������� ����|)0����w�Z��9��5�Wo���z��ŃH<�jg`�ˌ:�e���CY��M��4Ga8f���J���R։��B���įyO�NGpR�a&�W����*�G��j�-B��ڿ��%!�3���3v�q଎9����x�(���Ǟ+e���9\�}i�R]�rW��̉?��6���E�4����U��6����q�kY�k�=��=�bw8�?WS�������g�΅�v�ϐG�����Õ�'��:��0�B�"˗as�>.*7�D���M�KQ�T"��~
�:E���~U$�����?�t_��~�I�n5Ɉj�_� 3ce�"w��^R|�H�L',�9��o�"��d2�6�9-C��s�m�!?·nHjJA�w:�� g���9����`K�a�#�%e����<�+֐ԓ�v`��C~��M~J������I[����z��C�֘���r����TlW
��	�S���.��2�����5��S
7\О�*R����tcE=�nrJ������]z�s�]�Ш"��5�^�|EC�]�����]Pu��W�pgQ�v�@�*;��2���E��Џ���:�Q��d�=���3�FrЛ�����X�|��p��V�'��a�kR�ta�saM#�H�W�G+�N��H��,[�ԒGUv�&�4HI.6DP���_���&%+;�*�q'-�'    C��s�79�޾�;^ps�4���nt�y:�HT<oS�ZV�$����_��myx��b�
�`϶��˶�R�e��]#��~��/5�?6��|(�HݱU�
��$GDN����l�w|"��bov$7��z�kزП�<�U�kn}����K)(�7�J���(-�%�%�{}?p$�IȦ��g
[:o�D�lR�WY���E�F�v�|�mk��m�� �Ҟ�%S�D��n����!�.�w�G�#�@�O�_,d1��s����=WV�ah�U���[����ICt���3��n��-�2�+̥��L�*1�|���ҡ���}��l�P�唢��:������f� F$7Ս�=д-��yU� _p���'{~��S:b�����Y�
��zPr��B�a���m+��B��c�VY��V<#��佺a���"�>�/zK��t2�0#>ܕQ~�z��	�S�P�pF#�����e�T�̱vg	�эV��M�׭2�z�:�-��Z��4oZ�uCE���8�!��Vt,w�
S}{r�F#G��f"[[�r[�����]�5X'�d�J� Ǜ���{���opM�,p#��:Q�J�:��2����ғN�nUs���=�Y�y���U�`�@+�B�ʮ��r?9�ę�����t0[�Mre�ƽl�t�C��vȂ*���.=Q��v�1�' P}�e-�4u3���ŧ��&��m-a���]QmϾ�K�v'؛��I��t�e=�ޗ2{�j#��O�&r.`{[qV�j�XՊr�̉R���\c��{)E!(���X�D���;d
KN��[��M=��rO��[И�M�_������Ǘ��~���͟�o~�u���;:���e��\�BGZR�\�p1A��qs�/v��%~��k�;�������	��ۇP��̙%DNb~������m�gX��U�M��X��}��xm���5�8���|D�M����c��ٻ����.~����:]��9��V��J��G~ ��%n'I��Cc�r�!����	�g6����Th�i�\|�[�Z�}( �8�Q3*�_�t�(R=@.��,� ��
�����ٜċ�M�vm���L�ȉ�a�?0I�g����U(��R��XՁ>r���$��F��c���H���
+�@��N� ��p����\�"�|�"?��40�������n���<�3Vn�K���
���y��U����7�M����ݾ�����۷�v��w��>~�Č�xQ������Y�2�϶h�+����#�H�E�� �%#U�����[�k�/����d,�H�^��k�|iz��j�D�]��y���ו�z0���`G_k���(���B*������\�&W�#�׍6����қ�d��!�!����5�LF2�zt���<P���U�-N�
�v���PX\Dׅ���5TI�6��!�2?��l�v�%��,h���THY�5I���ͥ�5e,����_��K�z�+��;��?��)�pE^�^޵�Yޗ���c���A�[]���O�lz{�V��^��O1K6��.��{=�#ܫ;m�}�ރ^u�����$�cm�HG��0,��~������&GT�-������gĜ� -q^o�Dgy�X%8��o"��ɿ1,\g���D*�eQ�H����L�3ԯ��������M������6����V5 �ζ�9���r
�� ����a_�E��GR���"=ώO��ok�G��{t`���� 0x��Ww-�F��xg��R#����+/S���b��w���-����l�͂ca�>/��;�M��Ə�,�Ε~p݇,����9�������V%1��|��_�T\�Z�����k�`F@�8G_�k���B�[�#�SLD3M�&�����[�7���Ds�����&\�M`��ď�#Ƣ:���"����gK@?^s`&S�(t���N�fqBDo��sd%�K���w��o���蕮%J:�]� Y̱��F&cD��}_(�6�_j�m���ܛh��X*sa�_>�iޓ�)��3���KX�9G4������yJ��8��M�KQ�b�\]����p���'�'�Hr�SBQ'!܎ҟ��y�����z�����>���p�!����zD�nc#w��l�`�rIS�L�}o��0Oa�.-��oS����ȳ���e�X�Z�_;��p,���;��j
������޶�w�o�'������۬�@�������%�����b�hQ$��y^��1e��C.��p?�b�8n�k*vo� �@g`�s�&���a�
z!xљň"��sׅ�$5��}z�AdJ�>�?EY�"���ޭ4��}�7I%8-�+�(�Lfcw�$���M�E���?U�k�"&R�m�g�!�Gë��,��ğ��>=	�2���>s,���||�6�����:�n�;�����Y�����c����4�<>C���ׯLܣa�0D*�z��]e7,&��y��a+��g{L��^7�ɂ����B7�ߴ`���+�!�VW�jC:�}����İ�0�d��*�����e7�Q@]F�	e��&��p}����
i�Uu�����o�t=����|'�<��	
���&
����sruP�8�ˤ�t��Q�ew︾�$����s�С��F`D��+q߆�Վ,o,�ih���+]�����]^'��L����t�F�3��<nKZ�/	8���3�L�u��r��_�՝E`���'p?���5Ͼ�>6E?@�[A�xԝ4	���4����{,�콌4�!����c��Fv�Ǝȍ&���RE�����K5��_�����_�gj�ޞ�H	?RO5�K�2��G�`�|����1t�����:6�.��Ժ�{��]\����>xD힙`4()�Dc*�,��N}A缙�C4�Қ��ƽT�f��+��	�r��2=���s`�`��(��r�R6wq+� AIt*<{A���Jm�^���;[pR���S���؄�R�0�B`���I&#pOQ�ӈ�N~3m��&�>Ţ��˝i�����&�퍪�	�qG6�g�~�������p�eu=g�'�1����G�}Зg`�*;�i{���O�p��ܥ[8�I�\!�i��q�@�P1���{�W�\��}���<,���Ŕ�� e�����߄Q]�Q��.��ۆP�E���d��3bX�=���=���jQ����2��G�e���0��G˨
?�ظS�W��_������8}ה�|��?�6_}6������X[�����b?]�l�}�ה5�Z�����tM��cջĈ�B���LvV���E�Z���ş�2E�^6"]�Tæ�7�����0$+yU���s�qR�-�	&ׂl���
�U��nWh]��d2K�"ߛj$mPl���'"�i�ǞB%��0��M@�~-7����=�?VS�g�4<=k��KǢ�L��Y�k!�+A��aZr�SL�?N'Y�w��aݒ!�7�4'L��B�ϥZ4�H��]FC��_q�4r��덦)p�s�|'�e�ٓX�����;��9�Ė{��c*9s�(!R�3òƶ�c�ҿ���[����W<�^5�t`�Z����6q:����Hփh�!�J��ֺ�ۮ���O�f��R��s�8��Z�1)
�����C��b������|_sy�~W�H��0�7�4�$�j�C����$_0�tȾ ��T1y��X�C�x����׈�Ko>�����N�t	�w�V?6#2��z�����rF�*���/�.0��E���}1H�2N#`��O��
�K��T��AJ�{���4�ݤ�1��?�H�oW�Y���А�6m:&'\Z�f�U9Р��Ԁ�A��6�� �F�ȷD4����%1E"�t�	O,��ߓr�.���n2�G��[���#��zx6ϩF�9(�6����(-|�HL\���@~y��� \��1E۟��h��dds-$�&�pS���]�-{᮰q��   ݪAH0����lѷ�ՊӶ�<e�7�7.~����E��D�=��${#�b���g9-EP��t�]�bs@LFT�� $�4��
��=kG�f�\ߨc����S�8�dĶ�Ad/���P{݊��4�]��� s»z[FL�V��R��Lҿ�����I�ݩ�� �$����j|4�&i���9/#'K�|O��74~ ���9�:vG<�o�`�5�Xأ9��cL���BEf�U� #V *Q�ϵ.�*�]���[���Φ)1��!�?L�$�1�R�8Nq��P���,�K߳�_jLOr�v�s$V��p�=��U��Z�d�V꘏��i<��{YR��Cڐ?�.mCD�5HC�[�y��p�{	� �zp�'���;�B�u�S���l ���I|ΉmJ�߄�/�0(�ꢳ�?y���NEXUG��PA��WCg�+����c�9֏�ǌ�z���=��p�S.�̈́��駏iv�B%{V�[���w���?6iHW�
&����D�S�i{���s���@	-��`�k�:��sf�=�R[�q��g�����1�E#��FYcD�h�*%`>؟���E���Ƴ��#����$h!��1�Vˡ��*n^��un��&�x�Hܩ;��s�t� ;����3z�ї�g<�!�df���-W���+��j��=�@��OBu����ς�3���#��Z��m}^&��܂�kc��/yv���H�D5�1�	9��A��=(Tu�{M7�fn�n�?�����_���l      �   �   x���͎�0 �<Eoh��Ph�'u=�M�5�,M$Q1�f���bH\�L�?_f&]���6�u����)�_|�"�e�ibq�q!H/yq�"K��y�i�Q�����>���g�1�01Į=S���`�VCVF��.�8f�̜Xڠ0N�x�3n����W*"����EK�n�|�t��4��E��� ~�h�X��dV�S�$� Ҟ��7����&�Ge��A�u�i�T�Y      �   6  x���Ao�0����MͰ�_[���%dq�0�� �Hkl9��W��x�־ߛ�i�΋l[�:/7p���&�:�u�>ümB��r��W.���+ך�zx��:��j�m}oo�k��=�*�[�7N����vY��i3��/�x�	P�h��$S����������l�!���d:�Tb�Uw���v8꽲��O?�i��goTP����9�;i��ųE�8R0�hB
���왃�wD�t
>V�b��IO�cW�DDI�'|�x��K"��sȱC*��R�b:��F#�@�c%�D��/R$G�      �      x����v��&����e��� �pjS�H��$5ɔJ��q ND 10c |���]����b�nf��7M�}��摿Aw����w�����w��&���ȗ��[ݴ�_�ջ�S޴���T��M
5��Ty�n�ԅ���.�M֍Z��Y�m�C՗ݼ������&_�7��?����5J�w�_�˼��/��/u���]h�V������j��-��=<�vv~�hȻ�nn�M<�<���z����3�g��7�z��Be9�����Mg��-�3��w�9o[eɕB�O�=��7��&�e{���Rķn3Ke
H?�\�.���������� �΋��rd�3���,Ĺoԛ��/n7�:���7��'�tj��-�y05�ou߶�	����R�+�;v�,3��m�����v��Qk�y�{ޒ-7��C�^d�y��u�2`�( ��o�w
L�(8d�<ˬ1l��LU�%溷��D�g`��p���v.�}��ɼ��j�Ԝ{����C��>�Pt�C���[��B���,,Y*�����M,�i4���lfO��j�Η�jv��J!-b�'�w�֛��#E������������6nw:ٹ����Ԗ�	Y�����R�����l|�8 �1��&_���P��"��+�UO���ا7�/�'u	G�P�
��0B��[�����\�-����UHw!<ޅpjE���%J��R�/r�jH�_:eb4�F��T;ՎY;΢c�N���|\�{1�V�2j��G�J�i|�%��������?�? ;ͳ��:s���o���^}���s����ᡋ@�9W��׺Z���T�>����^�?'�Mi�d�7�����͉����m�J��Q	�d�6N&�<�za�w���nִ[���h���j�Lߦn
nK	o�O��:7�e�J��W�ܕ�"�%S��g�ݢ�]UM.;�O_�Q�B���ӀK����yg�I��T�u�J�\ -�b/d[�'�}O��ͩ�t\ E;<�Mp;ĉ��4_�\��Q�]�n�0���I���ߘ�F�pOܡKAn]���B�U�] )��M~�3�Za�^/�Z�Z�y�\�Bf�MSn:͒䉮*z�QkUM�'s���=l���	<~��6~0{LOu���xp�n%��R�?�#��*�&�sg�c���y��9�������"Zq�����G��i�"�j���L�M��;��p0�����0��J��~��\�[E���b�Y�I7�_�#������z��Lg>�ʾ�Cj����ee~�yA`����T�3��Z���U_�˴Zk#�E�|:�)�Գ��,G���h��<_U$�V�@�Z&=�����gO�g�g4ȿ�=z^XJv�|/�Ͼ�K�x.��L�xL���j�.�?�e���}ZXJ��R�w��e��j��~�r�������,L����� ;�Y៾YXJ�Φ�y X�w�5�
ܴfa)��l^t|��о�}�¿{o}�2�Og|lt\����gB[1
�6'���va�~��r	��z�9�l������1m�5/Vh�.�����M�)s������N'_,K\���Ԋ�΅��o3���@V�t5r���V�Jy� ��u�_�0<c������=2G�V�D\�Sx���{#4��X/-%�b/N��-�A�ܚ�A��Vud��iI���qx�P��N$֯����R���^r��κف~_�M�\B贅�Qh�O�W����W�&_��I۹�p?�c7���y�M�e��s�/��9����6�(��09� �t���_`4$�#�FH�7��G�h����Y�#S����!���:�2����Iuk)qL�?�	�-��x��� ;�{EZ�=���9�#�+�?s<5��r	�P"y��K�3��5y_7<)�H��NCf�%��ٸ<��ֆ^�Bf�$1s��g*���i�F_&�=��CT30�͛6����-d��p��ʿ��E�>V�"�3\�@ʢ�^�� ��kB�\4�$WO���)� ����s�/'�
6�n���7�+ �� !���m좮PR��R2�+	��&��n�:C�X.��gL#�  �]�mLk�T�G�-��}�)-� "��R~�h ?�7K��Ng��A}>�H�#�uh)� �Eё���ޫ�tѥd�q³�<Q�Pz��@��0�%�(�Xx���RB���H.z��N�p�{E�DA�8a�Է?E��F�9�Q���w0����;w����j�Nu�줟1��7�����5�*�R�0���,�؄�*G������Qb�3H+i {v�/>\�����ךL�b���1� %�P?��k�N�W�.i!䞦ǯ�*�{�w�#�Ha|&���&
7�L���(W��W��Mao��S�8����Ls���p;fɏN7J~���r�=���?��_U�j`���IO�g���05�@��t���{粘mĵL�[dEI�󂴷��<齟FG�ǘ�� S_��r�ڟ��Cj~��8<��A�ʦ���Ĭ09��d)�?�����ه޸�-����Ҡ��H\� ����Km5*�s�fk ���?ڕ .ֽ��]��.l��Z�V�T�4e� ��iݓ{ic���iq����B��}����q���Y�˺7��ٖ�]�_w)�~-�R�spH ||�����L�����!�|CE*�H�~ e��M�kr겭!�.bttj��^��C�u���%�MT�����0���<�l���u�B�mk�	�#ch�e.�m��җ|���{zlj����n̟_`��L��eY?a�(�TХ��ѫ5���@Z��e�����)N�$���|�����$�&��[|WKI��88k��M�T @n�g�6���(�T�"֋g,�n.����u�M߽���
CH�b�������[U����\�X�n%U�����j�zE��-��m/`Y�d��7�̷�hȅ,�����#B�Ӽ�$�ok�F�����K�c�	כ#wuCEEE����X2��e|�fߧ_l��R�ڸ�2�7Y�V��J����+�HyN#����7�4�����O��������(�dT8�(A��Ût�gա5��l)�3n���T�|�(x�,̓���2���q�*
�)}�Q�!D�K�Y�0k��T�yIzd��
]g0ǿ����w2����yX
c:=�j�W2�����k�����H=#�8���p�c9�1Y�e_�]l��~-VI?z�D=��RU���EZ�D�4t� њ\��<{�J�^K�� �f�k.��ʃ�֮������ј�[L�T��9�C�N\4z	n���3�L�9���/�Mx�k�_�G�4O���z�M����/}�o�NR�B���������|ߌV���wH�B[^�R��i�0���7��w����B�n�����$���0�'��O��S{]>. 
�\����UdJKty$�4E9�<����6�XA#��6h�²�l����V��0���0g�/d*�
�����ϔ�_42��Y���E)�pH���R;�"E������<c6\�c{f�/E�?,�;��ԉ�f!+����l�S��x��@
KC9� $wdW"�F�eX�f�\`!�&�6?D��#g�w��|%,��)� ��������<p�z��b�/�x�<�U}r��}����z���)�R"aw;W�>���
\�DZx��b4��TC����1pˌ9���q�aca-h0�<��pF�P�8J����t;y_����m�Zװ��v+ii��otjm��u������x^[J����i�m���b���U�U�9=ʿ.\�U���g�Y]��:�&v.�(,�y|% ���������*��7a�Eog�A��??GU���߫���o���{=�m6H�dx������}�jg��rKA��i�&���\��$w�0ë6��]�(f�փ0�,g'��xEl0�_�/���1\C��$y�C]_oLCxEi]B�U�ͧ�#[{�o@�\�e��RU'����l�'�V�3^9a�@C�f�r��]+/fU�>���rn��    �g���ɇ�j�RM�g�q��fr�Jl�[?�j�i���B?�OI?�&�KK	�q0�(��yPO�CvC6L�����]}T��+J�.k�;�*J��dzolނ�����RvZ�i�O�}��Yo��������&@晱�&���������BZ(8<�<H���]oK��mF���:x �wi�M��>�޻`��[^�7}����v��͆H�'JN}�um)��À�=�����'�}5���g�	/�I�.x{� z�{6��]�%���84r1���S6c$I0���&>��%�VV����e�i�^6-�G��K��������{��,��̸���wuFU�E��T���B����N@��lE~�X��]	#��M���;d\�,c~���!_�2�t2/)�h$�%ex^»�(�X�� u��vh�☎lk��*Z]ٮ;�^hi!5X����Ÿ�x�]��273�� ��nYk�cu�2k��AD���~(s�n��R�S�� @>ڒ4Y:sz�;�[�eQ)?��x����NL~�˗5�x�Z�5:Z�2=^�
�/��c����v�Ji�:(d�V I�G�i֭q��u���אg����k��bߛ�ӚZOG�w4懢�U(�������-d=5�C�룹ύ�2��92�e���w��D:�\�j�U˷��z��"��t�P읏��`z�:�Qb�[M��]-��:�[	Ǻ߀���쉆�yR���}������0�Ȁ�]��{F�G�7K	��#r��]��p��I�ޤ�+�3M�uȢ��ڛ����9= |hB��$LX�p�*�
N~+!�F�{pu��Q���Յ�o)/�����+[�
��W\c{���`�Oue\�!_]����!��CfχSd�|[�++��y�#J����#e�}S���36j�+�`Tӗb����&c]�e�|C���˅9V	��[
LY��wzsı�q�"޲���v8�y�RYsV�ĴF���Y8!Oozj���
�b�0�p �Y�r���+J�ri)�,
8:��v%�hԨ�!��!�?�AV��Zo��gz���&L��>oPX+�b�)|$Q��Xu �3B����9pY���z`�\!--��BX�����}�!o����d^L.2U�����U��'2S�KY�L8C��|����۬!����d�G%�~$�XZ��8���^�ʼ$1748)hpb���e
�m8Cᗪ"�Tf@
+�"&#fНhSV�W槭^]털>ӫa�!�.�@�eN���Z�8G
�^��~~���d�'�O��o���TE�
١f�p�>�p������]�B���l!�_Q-ޕ����n��y�1�����M.SQgqV��W)�8�!DK�ێ�°���[h��Y!M� �2z�=��`(d���2K�#'!�e�� �{�Z��}P[ZH��|�����nT���e��0��?�\وE0.c�S0�}�P���ɫ��(��b�f��	�E��qS�;xk��%y�n�>���
�*��I�Q�g�JHH��*c��1^�HK�ixL3��;c%`���z��ֽ0.�{���5��sȻ�i���!axg#,ϴ�}��5�6��Z�~W㼯r�_�\;�Q-����C�ڃZ!�����n�
Haq��g|,�p8�_�P�,�G�C��a&�T��d�YR�����M�ükF|�4�C�FF�B�g�1�"�����%��e�l\d!M^�2��������������0���������Z��a�n%K/N������RWM��ҙ*��*kh!�G�dyn�l�NŽڠ�i!��[��U�c�����4�T50��u�(i6>����H/�LWT�l�#��m:Ɛ�C�</�`�HF |D��y��)t����[�fB����6O�	�l<g��+��jB��]�C^���k-%�m�qv�!V9�ڇ�����B�>���O�9^��iw�e�U�b(���N�B��[�k��q�
��̯(��U.^��,_�+�a��s+aPy��� �w�o�Bm�����";�zٯ����r�]o�D�e*'��=!��
U�<��R�ϋ��V�W�ݫ�~z�\)�.3�T=��z*3$��~��6$�kL��8<����7����fU��i���Tl~���}�q���Bt3���ك�%/J59�	@d��/ �e /�C��r���� �.��b����zT����#0q)�3tf��� �[@�4�����X��r_�/�p~�jߠr�<�V��/��d̓p�:=���&*��G#�vPwJSi�1��z��*���Q�T���F�/�)��H�	0B�r�R�r�T�.�3�<��y��}�\�s�R:� �\��FP(�".A���c�}h�2o������l�D�Kg"�R�(���W��,W���n��u @��\w�Z��[� ���V��=f�k���mN�%p
i�;7�As\�e� ��)J��ii�Ќ�o��7[s��Ȼݯ�H�'3XfPT�
�/�A�k �����]�����jr�E2(�F���,7��^�f��L�)��
8V���P)�K&b�\�L���y���X�{Y+���4�4�����{�
�
KP8�[D�A攢$�����[J8-bdIa����)g\߀�t�ژ!��^fxZ���XJz�p��-���jHѼn��"��F��.W-�Z��ږ�����K�a�x��הЎ��Hahz�Aĝ�З��
�������k�r:��$��p��Z�U��uvU���lj���F�pԯuѢ�VM����H!�c��.���g�F|���kP�4[ZH�1�vs��뙡T8d]�,k�`�A��v�`m�jM�rK�#�җ+��Zd(��s��a)t�y�bԷu����y�g.���N�636���ш���B7a�EZ���,��po�n��*5��tƅT��ܰ;�������n�&ߺDZ�ݳ�ǘ���WHp�g�U5����i�ǕF�`U"-,��5C�HN���ۺ��d�����M=~���ԝx�)]jD��p�	:�M���J��U����a��'�z6.;Bx1���H[	Cq�A�J�07b�`����8��)���'����"����%�;Xu��(\C$���C���U:��w�]]Ƴ��
!�P������Pw,��R(!y'�,F-R�a��CND8����-;���=��M&}/a���Ӧ�Ɵ���Z4�-��^B�r0b�qE����3�s� ��jި�]U�yꀔ	���҃��Mq�=q��(�Z�>��I��c�7�@�;C
�@�s�����!ӯ�����WK	�C�~� /�� x`���,�r�"�C��׼3ڪr5񸐺�<�E����"Ӆ���؎xx�5=[�3a 8f�h�'����2Q���E�l�̡1�kC�\��(Zao��y���]��l�(�@9@�.ş����!d,S���3�WY�H2�A�2qF�l��	a��,�g1�*��y�?���1Ҧ"����Y� ��o�j��U.h!S97�c(��M44/q?��	��IG��
�q�؍�*9����U���Mq#�����t�.@�T�;�2��a�R�c�d��cZ,�R�3U�g���F̮V@���(�\��1�s��.��dW�)/ՋBD�(�u��,�ַ�,%--dL�fl��ϗ�rA3i����²/�h)�����Ơ�4��=��8�͑b1Ec��_]�o��4O#[����(K"��Wk��X��n2/[�({)��ɫ��5-d�#�r��:��(ƅ��VNG�[I�b������8/E��=��<>�0�f�ap�G�~k�)������pCa�=ςx�T���g�ݡ��f�}�[J:��7a��V�~����o7@ʘFO+�\:�$8���s����3DϹ�ʯ�ɲ�)�#�ctE���jwF-l�5yT=�I�����������#�`��/ݷ[���K    �
Fy����zˁU+ �f�x�\`�&q�~������.�5������la�,���#�Lܩ�����9�>��� *�AW��m^`I�z9�,�c�8���!�칆뛼|�"��3\ZZ���^����øv��OT.ہ��%����V�vU7ϓ�z]���%=jyޙA��]�p�[��J eF~�������V��V�x��M֊!(y� ����!��:(�R�ѩ��#��K;��U� -L�s#\���~E��H�j�V���9�<��S6̞�Bl�!��0b�u[)�?È'��W;r`������ ^)��,���؇W�E�>/K�Mj��Ha4dʅ�׭^�O�Ø�m�e5B�6%�Rܤ�3C��9�|k�Wv��\S>t]�v���N7�B�X�Z�Dc���!�kǕ�$�Ē��О��!T�������s�ں~�G<�S�W@��|��jA�1�Hi87�fκ�]�nJ'��V����G��?�Iu!���PFj݀_m�[L�4H�i�SU0��MĹ���e��j+���j�����\��u��O��a.����V����Nx<ְm�w�C� ��H�ō@�j�� ]���Ʒ2�w���8�)[���z[�r_h|��q�0?b�S��W#�������`�>���o��9U�U���SB��p��̚���r�,e����?��A}j�)���.xׯ@
�$�}A̕�և`�v.:q!�r1T��v#ae]Yh��pq���ۺ�?� ��̑�������w�w?�*����t��v��n�TX����H���A�8>(k���M�R~�h!�J�N���N�%ớ���@+�F&y�)���j*�����*~��1���0���WM�t��� �V�C+�{\�i �E�3�L�������S����j)�W+ ��y�'�-
�!M�!½0z�˝bD�W�_�T5�"���pSV�G��:�Ͷ�_Q!ظ#�����8��<�ԫɕ9� N�j�H�ij�W��eb+�W��ĝ�q?�.,�K������]Nm�ɝ�#*7,��'R���?C�;�N�r��@��#YJ��3�By��Y�j[����n%�)?*�9ҹ1��/�uE�����E��.��J�҄'�p�v�fm˼ЄɔFj����x��8xr7�c�Q;�a��<_ZJ�4�Y'�EhQ�[�GZk �ȧ��Y�������=�1���;2������$��C6�@����,���b�y�CE��ԞoN|eZ�7�{M�15�_�C�l�@
��,5?@�����j{���6�X�fl��c�Y�����.�ִJK~�<�F����R5M�N>b�$�U.DG0�$�p1��\+;sl��Z�/�6��Kf)a�)�
��vL��I|�P��`(�0���"�SP��.����Nk�AXK�|��1�I}��s\�*���b��N5�̖�̖՛g�b����_�C�������P�p�"�f��Cq� ��/�%fC&�V�������H �E1p~i1T�W��R�y^�@��O�F�(7��"�����H�!����9����xv������O��R
�����ۖ���l��V4�0�NG�&���k�_Z�����AY����*��~P	�e�3:!�]5q�#���c��,�˻|�����T��Ќ1�hiU7�!�~cVK?W���Z��NV�L���A����A��,p��P�G|
J�#�GC${�}���ǯB��Vy�@˷�"�Ha�y:���\��0�+!�[J�����1B�f44�EqW��峐_(N�;,�P�Mf	/�����7r~�l$�!n_�C�&_��oZ �E,\�a_%�k��ka��H6�^���VQ�'�z? ~�v+Y�5	y\g�f�5W��-Eǅ���9��m]������h�G�"-�׌sЭx# ������R�x���U��S�'C<��7Gs���+���� ���R�qOY�I"�Rw�R�~�7{��V��r_3Y��'�B��O`�!�	��6����/��p�0�FŸ�,W�9��b�`�*��z��3��R����u��|W�n��Jmn�����*�kG�Tn%��(@������o=�+�<����1�9���ZE��C�ً��u���OBDa ��×m��
GܐI�0�T�d������"h�d}
���7�,�-��',�`��)$x��-6��+�Q�"-�(	9�c
��h@'7H��Ha@�r���/���/p�ּ*�d C��W�"F��6�	����ug^ʙ�-��gc�����(M�j�.�qX���=E��2���%�Ǹ�7q�y���Imk3�Jh�{�(xS�|w��毵���]0�,	Ļi(���,�r������{ܫ�����P���끽%�	�t�(�͎f��,�{����Q{)H!jGsJN�f=�竊RFAS�"xIA
E�4�wĽ�������ϛr��8����Y��~g$;��,��p�h��@���M\�V���_���c�L�j-)�*����(��g`�Vv� �}����.��'P�d�X༝�ʝ5U�iZ����0J!Fw�s!w��e*��8��|��`�?XL+ ��<)�NG�#EfϬ��(�Ӛ�@H4ʏ 4�K�]�|�v�z�h!�h�Hak4��!��񕎻dwڃ�\��5\^�F�W���3�e�F�T�c������z���3KIg��@��jK)_��v�1,��h!TP�*�y�H���r ��À�f`�a�h;{2ϑ�;Θ�L�j��
��JW��m����<��`Ұ�.
<FiW�r�`�K�S�&ߝ�v��e��_R�
�_<�;�z�L��h�R
/���еv������	�b����j��S��=_�m��0�j��4��l�O�M?�z�B�,����G0�.�wC��B+i�%70CQ^+,7���-%��䡲Z���}�Y�[]mu��8�!�JX!2�N1����v��5������g뒞,�i��!H�~ɗ]���7^�oBR^c HП���.K � �<iO�EU�+ĵ��wh������呚���v(����[�����	/=OR������@%�b�t�n%��M���xj�����z-eֆBk�ܿ���y�e�;^Wz@h��Tt��[Q��������|UKi�1;P�3oب<�.2 b��HRD��Vt�9o��"-{ϔ�^&0$̢��+���]n����6��x�A��9��^��9+n��}��5�x��U�q��d>t̑� 2��!���(�й�_.�fA�f���{��&��)_����#�x ?� ��ہ1���Y\oc��9ϩ���u5�\XQqr�l2�4jN�3<͆�B��w�&PgA�K��p_]gL�
-1�h w�@sc�b�������S]mY�_u�����R�t8R� ����纳`�޾�B�W6� �P����������!-�N��0���i��
i�����8�'WՏ�&�>���y^����F�	};��"��A�e�0�z�O��֥���W�Ҩ�Y���.�aۃ�p�ϑS�͝Sh�}�Q��^)&�~o���W��^�֍zʐ�"��w�`,��J8Q�T���GZ/�!k��:cj�{n����f������X����E��Pfs[�i�_����?��n��V@
D��(�7E�sJΜڌ"���u�"ϼ���ΩQH��丳z�V�+O�#�ը9L��yc�7�dW�Ű�Vg�v�_w��$SL/���Ä�̮�y�GPwT�������'�يF_�Z�N�[n�*m�t+i��z����lI0/htS�,����)�|)�<������'�mv!�wU��q�
���������T��7�h�)|gzr���zY����\�}��i�e�,S����A?qE8��Joj� ?�NG���=��.Q�p�D�$���f�������@/'��@U����َ	��b>K�C�ʟ�7��    -%�]�J]��g`�E���8� ���!�����x�p��On%�f�����8f���vr�?"#dBb~��,���¢�Y�3���rCw:(����sR��������A�n�FZVbD8s{x=���;2�.�nr�6�t[�\�B,���v�6���f������B�7ʆ����p�9�������|�"���H���ш�<�{7��^,0�YJZ^;��$�5.�o�T�9$�_,$�/�1K�Wzc)�'rs��O����zW#˝�V8�n��LT���Ԩ�Dl�����z��-�]ia��F�O�A޺$G���%ţ{���*�Ӧ�h��9��i��s�pj]��S?��|�*� ���3�G�*�F@���C��J���az3.jnt^�ÔY�*ȿ+����Q��G�`+�9�,��� �1:<ޑ`?KI�JzGi��R����I)"r�A�q��gյ�)�b�s�/E3����o���c�J��\Px0���:ꍸnz�Q)�r�n���P����O�I�4���3�
snw��ZS��[E��H��C߾��q�6�������=�3\=�������5��[ؒ�3>h�Z���d�$�(d�~�
Q�T�pN&��0'k. �ͽ*��[^5�����^�C����u�{5��v]��+�v�+ύ!�f�H���,W�@��x�����h��j����m-ZM|��0���R�=�	�j0
�s�Y�����\���
Ϧu��z���|�rU.�TW�d��Rf��y��
y	.��j0��^,%۟xʍ�����Vu�ھ��4Oˏc�FH�|1_���iiZ��G���U�n�����o7ڸ�x.�H����5U�\��;���3��,_!�r �|���_�|�a��HaA@����.V}qrc�~���E����IO~�4�%��۾B@�BZ:��]��������6C���Rz:ا�@3��=��Ö["ŏ�^Д:"����>(}�T�,�����C���G�~A�R)�3��Wg�ﲞ�P��"`u�� ��>���T��o�F,�S�[�k�@Z�q4
�cIe8l)�V8�ּ�%e���k���A����\�M��S�w�t�n���],!���uf�az�A1gw9���Q�������aԑ�9E��� ����_E���������kp`��S,Yߟ"�SL����'���h���Zh�ģ�iH����?L(�W���ݎB}Œ���L�>��S"�AMh�;^G���t$�h�=��M~������>���ji)iw�(�1E�-���n���K �����5"���>�0� 5VhZX���g$��{�3Ш�Ǝ��ƻxk�L�G�k���F�
�irDYo
^�=M��A�����9d�:�|�U�f=F������C�8��^�A�A��Xn�,%��5eG����Z��~�a�d���sؽ���X��$�fX�E���2�<2��z����9{k����Gs�ph�E� 3q�R���"��w5��0ķ�!��2�)���殆�r�ae!�)ϩ��o����M��v�k-)<�A����es��W���BZ�˪�������X�۠6HKgf0c*L)oG�r���+��*�Sӑr�,��f&ί�]iGE���l�J*ӑf ���k_��ՠ��[���!�.�{x�t�g�uZj,'��
!��Wr�ڨ��GݳEZ:o��i>(a�x]7�a�7��V���6ŉ;�s�n��7��"-�⧣*�)�Gx?�����B(9��%�����,��f	H[�8�����.G��*�g�F5B���qm!W����*��tO��ԥ�A���R�ɼo��μ�3o*Z�J�g5�)�TXo�-�T@
E���ߣ;[V���JUY\N�$.�����3m����ʬl��,��=	��)Nmd��~R�y���$�a�h��De�?�"S#Y���d����b�rn�M���-WnCXS4���.�F�<Ŝ,2�h��h�̇��%s����Ŋ����9 e���]�ä[�����ޮ��������s��>����+*���>��(@�������A2�ZZ���F*���Î"����T-�Fj�GK����,��넷�������fW��I+�ˎ��1:��m��b�[J��o1�~�b�����v^�X�/n�e�9�T��P/TLj���H�?�ZH�7��@�{��Bh��|R�r�#���u��b��o�_�;5֙��P�}D[SD[��;*��-x�5E��� ���}���~]7H������;C���Q�������v���de�,+��HN)\�����������
ia$�c��!f1�y�,���N�MI����ª`EX#����e����cu�0������F�-��H���X�!�N����m�%L��6��~���B�O���J-ѯ8�Փ3KH�{�HAP��6`H�����H��B��|�A���=��Q�?G8�73� ư�A�A����
i�,�QG	���[؀�Yn�r��u�v�sD�7����r��$%�B��0����`џi �Ha	o�H!�~[����`�w�-�����By#y�W�r���i��ƣv� �Pj�*(N[�@JM�Ѯ��^��C�=lv��N��[D�|��sFPۖ���K�������DZ(f#Q5��(]�\��[gHӀr�P���j=���T�߮����R�i*	f0��\Z��.�n��������ƾ�)�����N8����*�U	
G�pk$F����U	�.�[�@
%��ʉq��*H6���!���F���֗j�H9;
��%e#��S@�xШ�P/Z�z!L��l��K����O�W����R���*͈�'E��8�÷EZ��5��:k)[-eR�ׂ��4]��[b��]XJ</��Ȅ�K���A���d�)�g�P!�
}O{��{[B:%����iG��/��	�dA5 
KR�Q�9�\�m��/��n��a�Oc^�B*���٧���F�Y�s��C���綐����f��X�(��|���7��P��<f8�)8[����si�K�bi������y^M,�%L(��'x�RW<�ݷ�5��p�r�:nhb@���8��#���n���wƼ�<�6 ���5<�E��Jf�ߣy"4P��sU�[M	�<��]�G�#𻧵���ق��dlGc[B���Մ�֯3�V̀�)C�䌠��ZW�ƙ���msKI%�Ǿ_�q���̈́�8^��ͫ�=�	Kж��8����0L�1�`�R�&Y�?�3�>�3-���Y��9���q�����'Uұ�^<�|	s�*�.�:�.,�=����gRd�P��)�'b�c��2N���g�P��\�4S:Ø5�}��;>��W�j��6O��@
�<Q
��v��~ں&�U�Pm�x��� �j����[=�xȍZ!"���-b��"T���s�L3H�-%Mp J�����7(6Գ��C�Bޕ3��X�)�G�Z5F��P�#�Tv�ڧu�L�0�!0�om6����q������� �seL��g�d���(v�l�o�S��<Փ�z��CZ
���D8z�0�����Yf3���^d�S<��1f��m�끔&�����}SͶƦ�r��œc�{ {�k��J�-�,叮���ۻ����8����K�JT�x<͆j��XK�c-E��p6�_Ї��k*����*vɺ>�1r���NqW�zp�G܌np3D���>�x�P��=���B
k����O�!�ܰ���P;8�cX�9�c%�����.�b���L�1�+K	�x��oT�r�l��m�$5yPզǃh� �^���C��:|�8 MC��b}bDSNP5+x��)�!�kf���pYj�3��d2o� E�;�j����2�~qY8Egzr��[��J/`!��k�V��_�}�N��>o(���/�ى�gRa3;�	b�}��nr�n����W�s��,O^�R88$��m��]S��Y��z�f�T�q    O܃��$��� rf#�)B���y��Ѝ_@�e�바�	��\�e+�-+��ʕi��)��x�nLA��%�����7��L��C*�7�\�f�!�-���|�<�铑�M��� ��B���D<�NU����~{��x��P�Q�!�Ч�-�(�jb!Uv��� �s޸N6)���������o ��WM�[c����R�8��T�����Ş��E���E�Ox"k���wp��	%���'Z�B v@�=�5��1hg@
��C�48��;;- ��'c!������?�~1��������������$��ɳ�no�M���у�����솃��W� 9�j)�g~��bX~��6����/�������o��?L����Q�TGu����	;%,2��f��8Hll(�!������}]Q��IYBO�,]��PD�>-3���$w9�u��4��0sm���,�ߍ�Z�BVX��,D0���7<�r�H�u=;�� �ܩCF��O���$D�ฑ!5�����g���n�����+���89�Q���b����ׅjO.mw\g�y�����ⶊq�-T����s^�+f�i!,;�S޽)�N_�2~Kx�U�F�Wt��kpV�.�8��}��ع;u;�Q���\Y�̕q���;�ʈ0��}D� �)˙R�0�ŦpeS��=KD�]K��KNA��������������|�
�On%Ӟ7j�Q�������G�|R��8���r���5x lA/���7�:B�������,ͻ�Pc�|h��l��G��bȻ1 �zS�U5�q�oj�V�d)a_�l���n2B*�	Ac@5��`9$�����U��E��Os�֕v�\�B�� ��f�m�	��B5��ܝ5Ҳ�^��, '�����������Gu����>�Ȩ�ii&�wI�@����}/��^P��
GT�%��M6�QX��odu\�uѨ
�k ��P��16Ϲ|�E3��-��� �y���6���\W�״�E�K4�{�kmQ�(Ұ�O2~��J<ˌ�u��,��mْ�Y%
�l���Xz!�������˞����YJ��̗�1���l��H2ZH;�xgD���%���������,@��*��+��&�1�2%8�Ubвx��0�2�,2�Y�r\2�^��0�;�,�'/����``e���$����1G����mM�3�ʈ�
`���%�{8d���,W���9T2��B��Q�م��M��2� �s0}@�85�$�uL�-�F�^� �̢t����M�T�냓�Y��0�G��}�A�:��S�5���.h!,��U����M�q;0�n�R�CG˭�0��O�ŔӀ�3)�T��~¹�)?���R��f3�����<ix���8j7���m^����:_�r=®P�]!�V#�B���E��N��olӰ�%<�3�Q�o5�#-V{��:`����~�Z�/�[J8;��#'�Uk�G�X�	�����y�| d4C �Rm�<�|K��]Na���Ԛ;O�:ǆ;w��sK�l�`:��+�yu��D��w��XJ�;ϕI ��EQӝ3L�1"�� -��x�a��9+�����X���d���V~���+c�Y�Jz���j./8o��y��j�[h�Z� 
?+ ����&Ok"�l�����O\�A���#���6́���=���C���3��[m�g+�Lz�ǣR���5�����pB���!�2_R�gn��"�����V����q�5��6���]�qvW��k��O��}3��:�+�a��_���/��J��˝(y~W$ꯕq���m���p̞Y�`���<�[ �������J/�	C��Z?QRΘE����A,�5��_��;��e���s꼿9>�L0��R>b���6>/*�[�ŵ� |7��GMW��3���@��Nu�3=��(����6OWZ�3���86m�Z�?f����4pX��y�f��$�;r���mΫNn�e���R����I�"^ ��t��7۶k�$�ÎJ���<XH0QE8��u��Q�Ҥ�ȥ%�(
�_�C9�ӭ[	��,�7�/GMx�q��5S��1o��p�9���^gU�-�R(�Q�q)�y�7�_����p�F�=��Yw�`��v�������d�����LAy}ɫ�1#��w��;���(�4���1�K51�ۺ0���q�|(v��-U�'�݀ؒ�Bv肩��� �J��Éy�Z7(�UAY�*5�!:yF��;�5Yf��� �-4|7�(n睪64J�R�"����$�k5^���>�<t���� g�ʊ�m�=��"L����28�YZUô���˺��;È��+ e.���� ���u�{�� ;����1=�IX�A<�(��)��!�q�b2�
��mc�����#�Z���}����M�,��s,Q����л9ںRV�@�&{�T,�BS�Gmj�Þ��Y�t�~"d'����j[ ���\�����\�Om�}��=��C8}���������W�e�i����S,7(WΈ%Ȗ�2�:�����8$n���Ċژ�W �����XM^����h%��	+P�< q����?
]�~a����p@{�{{��ُ�	���h#S�j���=o^S$/�C)�ר2 �ڲ2'������,Y�;A��e3k�,;`)ka��y�c�@hE ��h3j�F�Θ�{����J��"��8/Z47n�r�.�.�2��"P�E�PN��5�ضuO��rX�n��ș� ����[e�!DZ�J��#�a�\���B&�ycC�6#�Sf
r2�K�7T1b�Ti)�2��T��7_,v���/�k�Q��}qK-F�S���	bD5M^#�B^�BܔuN�S�m0��]��L�yS��G�5��y50~��lH��Y�4�bd���[��/z�wP�B<��ɡ��C��vA��[�"�k0�K i�j���.��� D۲��q��2��x��!���
z����t_�����i -�'C�'��)>p��Y*M	���*9�C��zW�pkmk,pݔHCc�����ӳ��+�Xo�u^T�3D�rX
���Y�	�y�y��[ۉ����0c=���+{^h2X���.���=&�b(	y�5�~pǹ�Ӡ/�DZz����}�v{`�� C��ʻ�A���mo�����DZ�G��[������o��6zϙ��<|"����pT�:Z�-ǣ���g6;
�xS��`ߨJ�A����B�Is+��-Np��BoU6��=����=��|�.���o����w�p��
Hai4����6��U@
MP�yp��uYw��.T?��V.�i�
���H�MG!v,�m�Xx�[�5�����������P�4`����RIʇ���U�>�b�G� �u��/�]H��\]�Oq#��'C6�9�S����>>_�u?_T�<�[� ��}�v�h�~y0�T�"I�II ���4��Tf/����<y����(.�R\L$���w�M��*ߐt��pT���Bm��� GPPxh��k�^z �aw�6CԞ�g�<e~��q��j���
��BS�'/D`�'���xxms8�V�e�!��P���'�vW�~�g�N��X��#2�/ky�L�g ��ׯ��ݺ��g��_��!����4[����s�^��D�3��`i�J�Ä&�֙���8�q�/����� f������9�ǌ�nji���pc΃	�wa��ƒ�᥼�4�y�Љ�k;vn����ug���ɭ���?ى���g�|B2�J��VM��[u�uk��V��#v�g�0�P�(�y����M8(_����ko���8�oh�#o{��3@���H`��l��O.�Զ5���d�9����h/�Kt�_u֗��o�a)��/ ��Ն���V����g�5�~fۺ���T�P�3D>"��T�`�H踴@��ǃI	��ϊF=���1
�-����<H@\�j��P�X�n^�P�)6   c�୫�;(Q��W[~=BP��%����2�m�������)tm�?Y��d�ֶ~����B��%�軼y!��`�*�͒�~q|T��Fr���nq��}�s�<#�0b�e	���{�I��%��!ǭ����Q�AJ0-|+1G;��cNAR�6_���$���HY���g-<9��ZQ��0# 3��W�CX8�x��Fr�@�?8D�ZJhV����(	�j�T�T{r����Y�ڭ�������C]�o�8���Rؕ��\$  �i��C]/k����K)^��S𢇱���>&�i��7ފ:�Ӕ�?�/`{a��YDP�<8��؏g�!��z�0K���'�.��RR��� �|�1?��C���5�T�����Q���DW�h-%�ӣQ�18FĜz/-d�A����)N��W;���@r^6+`�:��6� ��hG��Ih:Z;VFCz�[{ȷp|e�)�����3"��b;C�j}F]^3`���KK�S f�'�u��?�3L�d�|Q��q6�e����/�S� '~�"�P��7�ɩ��1���vn�X\�7��/��oX7]P����6s��������m�H���f��q�}?мص�_
F��W�eM��l<����BZ����L1�����@��p���*����.ݷ$�z;����i��Jx�H���a�}�N3J� e�&L>���GX�h]�z�x��B^إ4��7���G��_�*�k��|��[�ǥ�濂.�x9`^�̓(o[T�J����&)���)�t�n%��3^H��B�����T����Pp�$����kn����@J�Ex��j;ËZ��m�
>�WZ�k��JI�6�)*.�JPݫ�b��FR���w��i?�^�[�&^�8��ouO��;K	[��,T �:��%�K����9�'ZH�8�(����J1_��qU"-����;.-���r3���I9xtI�)�<G�Pu��%�����Õ�i��-�R��B~�"c5/���V?h2��K�
TLה�`��~�������<.�O9(ʗ��_",RM�L�!A���fH�@<�U��G8�p�o�]�� R�T<>�
oAy�����a|�,�k����@��X���[W�a(q����=����9)�l���=��@-ͽZe�\� �#D�͉\J�[�q�3�(ޱ��\�G���u�u��Ĉ;�a�՚���V�����x��N�.�v���A+ˎ�h�����+\0�s¬��r2��B�t@�s��q�)�Q#k�uP��۴5�i�4�|a4T6�x���J��y5h o�jj_�&,E�C�<���N7v^�h�R:xb䶆}����9(y���&�br��S+�9޴*��D�0ϭ ~�=nx;�iɆҒ�8̔��Cp�W�c��rY�Lr4(��  ���5���_�9�W�qnv�?�歂gR\G0�c��c֧_a�Z���&yy\��ٮ���t^���������L8[>���N�n���!��S�_�Y�ЋC��ʯ�FHҐ�Q2s�}2�v�6c5�YX�d6�*t���0�0NA�t5�S՘YՉ�v]�7�Miy'&���o�>xo�R�q>�i���r�( ��w��a0D��!D,�ۗ�BуK��:C�ne)ٟ�p��d�^�U�͡���<�C\�w���B�-$ۃQ�B�ռJOF�!ˍ���;�	ތ��?������_b7d�Sw��<�)�z�e��'�#R����ʗv�;��;�{�+�3�˳�U
-6���h�}��D����B�"��+]��aR�yHJ�ډ����h�� �+���;8ʹ�8Um�Oˬ����������8y(���"��Z�	{�[�8[�U�!��9�`�����<;�zh�z��W�B�Z��x���M��T|�m��;�we�5���vN�]�ܮ�'vRHĜ�2R45-�~�̆^��0���=PS
�F)��%�D��&�Gv=����WO4��[#-���Q] u�f4��@tN�N]�'�C�UM������+YO<j�:�~Ib�*��"%�:Mc��	�����w��we_��d�ڸ�4=9b�T���~�(-%Zr��=�`n��^,p�Jf)���\�.Ž2F%���FR4�>Iq����������K��7����O�&�_�JN�u��Wn�"�ͯ�����W(��C�@��]�fY�����o ���Մɵ��k����\��o`����K�ۿg�K��ȍi�c�u]��w���?�<�w��k�����&����*;g�3�ÜM{l���[��������.��((���x��!;t�\�G���{1;.����|��E_m5*��gZk�g\CA��]�ܺɞ��P�S�!���ʪQ���f��j
��80�ر3��nr�=�տR�VR?���)v����S��L�r�����u$��I{��k�&}n�v���f�`���0�"���	���0��x�[CHw�9�1���μ��g;޳���1/w�S����r�Ķ��,d��I���(�>�W�>#-|S�{�a]u��#�C�m��9꣑��^4=��fXJ�;.v���j�A�+�%{�����R[����)�j�K�A��!��>ϩa�
��R�8��w�	�.�r��R�+��%��A4l�Ǧ����uG)g�H���6�R���|.T���Ke��K*5m��i6<��r�ߋ ��_�.�	's��x�e��ҽn���?����a     