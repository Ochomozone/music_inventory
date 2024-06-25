Restoring backup on the server 'PostgreSQL 15 (localhost:5434)'
Running command:
/Library/PostgreSQL/15/pgAdmin 4.app/Contents/SharedSupport/pg_restore --host "localhost" --port "5434" --username "postgres" --no-password --dbname "music_inventory" --data-only --verbose "/Users/nochomo/Development/fullstack/music_inventory_backend/june_inventory_backup2.sql"
 Start time: Mon Jun 24 2024 13:46:45 GMT+0300 (East Africa Time)
-- pg_restore: connecting to database for restore
-- pg_restore: processing data for table "public.class"
-- pg_restore: processing data for table "public.dispatches"
-- pg_restore: while PROCESSING TOC:
-- pg_restore: from TOC entry 3933; 0 16585 TABLE DATA dispatches postgres
-- pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
-- LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
-- ^
-- QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
-- CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
-- Command was: 
INSERT INTO public.dispatches VALUES
(19, '2024-01-31', 1072, 2129, 'postgres', NULL),
(23, '2024-01-31', 1072, 2129, 'postgres', NULL),
(24, '2024-02-01', 1072, 4166, 'postgres', NULL),
(25, '2024-02-01', 1072, 4166, 'postgres', NULL),
(26, '2024-02-01', 1072, 4166, NULL, NULL),
(32, '2024-02-01', 1072, 4166, NULL, NULL),
(35, '2024-02-01', 1072, 4166, 'postgres', NULL),
(45, '2024-02-23', 1074, 2129, 'nochomo', NULL),
(47, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(48, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(50, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(52, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(53, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(54, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(55, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(56, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(58, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(59, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(60, '2024-02-23', 1074, 4166, 'nochomo', NULL),
(64, '2024-02-23', 1074, 4166, 'nochomo', NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(65, '2024-03-01', 1074, 4166, 'nochomo', NULL),
(66, '2024-03-01', 1074, 4166, 'nochomo', NULL),
(67, '2024-03-01', 1074, 4166, 'nochomo', NULL),
(68, '2024-03-01', 1074, 4166, 'nochomo', NULL),
(69, '2024-03-02', 1074, 4166, 'nochomo', NULL),
(82, '2024-03-03', 1074, 4166, 'nochomo', NULL),
(83, '2024-03-03', 1074, 4166, 'nochomo', NULL),
(87, '2024-03-03', 1072, 4166, 'nochomo', NULL),
(88, '2024-03-03', 1074, 4165, 'nochomo', NULL),
(90, '2024-03-03', 1074, 4164, 'nochomo', NULL),
(91, '2024-03-03', 1074, 2129, 'nochomo', NULL),
(93, '2024-03-03', 1072, 4166, 'nochomo', NULL),
(95, '2024-03-03', 1072, 4165, 'nochomo', NULL),
(96, '2024-03-04', 1072, 4164, 'nochomo', NULL),
(97, '2024-03-04', 1074, 4164, 'nochomo', NULL),
(98, '2024-03-04', 1074, 4163, 'nochomo', NULL),
(99, '2024-03-04', 1074, 4164, 'nochomo', NULL),
(100, '2024-03-04', 1074, 4163, 'nochomo', NULL),
(101, '2024-03-04', 1072, 4166, 'nochomo', NULL),
(102, '2024-03-04', 1072, 2129, 'nochomo', NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(103, '2024-03-04', 1074, 4163, 'nochomo', NULL),
(104, '2024-03-04', 1074, 4165, 'nochomo', NULL),
(105, '2024-03-04', 1074, 4166, 'nochomo', NULL),
(106, '2024-03-05', 1072, 4166, 'nochomo', NULL),
(107, '2024-03-05', 1074, 4165, 'nochomo', NULL),
(108, '2024-03-06', 1074, 2129, 'nochomo', NULL),
(111, '2024-03-06', 1074, 4166, 'nochomo', NULL),
(112, '2024-03-06', 1074, 4166, 'nochomo', NULL),
(120, '2024-03-07', 1074, 4166, 'postgres', NULL),
(124, '2024-03-07', 1074, 4165, 'nochomo', NULL),
(125, '2024-03-07', 1074, 4166, 'nochomo', NULL),
(126, '2024-03-07', 1074, 4164, 'nochomo', NULL),
(127, '2024-03-07', 1072, 4166, 'nochomo', NULL),
(128, '2024-03-17', 1074, 4165, 'postgres', NULL),
(130, '2024-03-17', 1074, 4165, 'postgres', NULL),
(129, '2024-03-17', 1074, 4165, 'postgres', NULL),
(132, '2024-03-17', 1074, 4165, 'postgres', NULL),
(131, '2024-03-17', 1074, 4165, 'postgres', NULL),
(133, '2024-03-17', 1072, 4163, 'postgres', NULL),
(134, '2024-03-17', 1072, 4166, 'postgres', NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(138, '2024-03-17', 1074, 4165, 'nochomo', NULL),
(139, '2024-03-19', 1074, 4163, NULL, NULL),
(140, '2024-03-19', 1074, 4166, NULL, NULL),
(141, '2024-03-20', 1074, 2129, NULL, NULL),
(142, '2024-03-20', 1074, 4164, NULL, NULL),
(143, '2024-03-20', 1072, 4166, NULL, NULL),
(144, '2024-03-21', 1072, 4163, NULL, NULL),
(145, '2024-03-22', 1074, 4163, NULL, NULL),
(146, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(147, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(148, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(149, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(150, '2024-03-23', 1071, 1999, NULL, NULL),
(151, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(152, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(153, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(154, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(155, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(156, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(157, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(158, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(159, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(160, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(161, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(162, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(163, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(164, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(165, '2024-03-23', 1071, 1999, NULL, NULL),
(166, '2024-03-23', 1071, 4208, 'Noah Ochomo', 1071),
(167, '2024-03-23', 1071, 4209, 'Noah Ochomo', 1071),
(168, '2024-03-23', 1071, 1999, NULL, NULL),
(169, '2024-03-23', 1071, 1999, 'nochomo', 1071),
(170, '2024-03-23', 1071, 1999, 'Noah Ochomo', 1071),
(171, '2024-04-19', 1071, 1676, 'Noah Ochomo', 1071),
(172, '2024-04-19', 1071, 4164, 'Noah Ochomo', 1071),
(173, '2024-04-19', 1071, 4165, 'Noah Ochomo', 1071),
(175, '2024-04-19', 1071, 1925, 'Noah Ochomo', 1071),
(176, '2024-04-19', 1071, 1971, 'Noah Ochomo', 1071),
(177, '2024-04-19', 1071, 4164, 'Noah Ochomo', 1071),
(178, '2024-04-19', 1071, 4165, 'Noah Ochomo', 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(179, '2024-04-19', 1071, 1928, 'Noah Ochomo', 1071),
(180, '2024-04-19', 1071, 4164, 'Noah Ochomo', 1071),
(181, '2024-04-19', 1071, 4166, 'Noah Ochomo', 1071),
(182, '2024-04-19', 1071, 2129, 'Noah Ochomo', 1071),
(183, '2024-04-19', 1071, 2034, 'Noah Ochomo', 1071),
(184, '2024-04-19', 1071, 1928, 'Noah Ochomo', 1071),
(185, '2024-04-19', 1071, 2014, 'Noah Ochomo', 1071),
(186, '2024-04-19', 1071, 1615, 'Noah Ochomo', 1071),
(187, '2024-04-19', 1071, 1582, 'Noah Ochomo', 1071),
(188, '2024-04-19', 1071, 1954, 'Noah Ochomo', 1071),
(189, '2024-04-19', 1071, 1926, 'Noah Ochomo', 1071),
(190, '2024-04-19', 1071, 1943, 'Noah Ochomo', 1071),
(191, '2024-04-19', 1071, 1676, 'Noah Ochomo', 1071),
(192, '2024-04-19', 1071, 1675, 'Noah Ochomo', 1071),
(193, '2024-04-19', 1071, 1545, 'Noah Ochomo', 1071),
(194, '2024-04-19', 1071, 1577, 'Noah Ochomo', 1071),
(195, '2024-04-19', 1071, 1665, 'Noah Ochomo', 1071),
(196, '2024-04-19', 1071, 2016, 'Noah Ochomo', 1071),
(197, '2024-04-19', 1071, 1798, 'Noah Ochomo', 1071),
(198, '2024-04-19', 1071, 1971, 'Noah Ochomo', 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(199, '2024-04-19', 1071, 1925, 'Noah Ochomo', 1071),
(200, '2024-04-19', 1071, 1818, 'Noah Ochomo', 1071),
(201, '2024-04-21', 1071, 4164, 'Noah Ochomo', 1071),
(202, '2024-04-21', 1071, 4165, 'Noah Ochomo', 1071),
(203, '2024-04-21', 1071, 2129, 'Noah Ochomo', 1071),
(205, '2024-04-21', 1071, 2091, 'Noah Ochomo', 1071),
(206, '2024-04-21', 1071, 1928, 'Noah Ochomo', 1071),
(207, '2024-04-21', 1071, 2014, 'Noah Ochomo', 1071),
(208, '2024-04-21', 1071, 1615, 'Noah Ochomo', 1071),
(209, '2024-05-06', 947, 2047, 'Noah Ochomo', 1071),
(210, '2024-05-06', 947, 2047, 'Noah Ochomo', 1071),
(211, '2024-05-06', 1071, 1818, 'Noah Ochomo', 1071),
(212, '2024-05-06', 1071, 1856, 'Noah Ochomo', 1071),
(213, '2024-05-06', 1071, 1873, 'Noah Ochomo', 1071),
(214, '2024-05-06', 1071, 1496, 'Noah Ochomo', 1071),
(215, '2024-05-31', 926, 2115, 'Noah Ochomo', 1071),
(216, '2024-05-31', 926, 2115, 'Noah Ochomo', 1071),
(217, '2024-06-03', 926, 2115, 'Noah Ochomo', 1071),
(218, '2024-06-03', 926, 2115, 'Noah Ochomo', 1071),
(219, '2024-06-03', 926, 2115, 'Seya Chandaria', 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(220, '2024-06-03', 935, 1522, 'Mikael Eshetu', 1071),
(221, '2024-06-03', 176, 2060, 'Lucile Bamlango', 1071),
(222, '2024-06-03', 928, 1900, 'Lilla Vestergaard', 1071),
(223, '2024-06-03', 929, 1806, 'Moussa Sangare', 1071),
(224, '2024-06-03', 539, 1716, 'Fatima Zucca', 1071),
(225, '2024-06-03', 480, 1861, 'Kai O''Bra', 1071),
(226, '2024-06-03', 981, 1714, 'Lauren Mucci', 1071),
(227, '2024-06-03', 945, 1704, 'Eliana Hodge', 1071),
(228, '2024-06-03', 984, 1531, 'Nirvi Joymungul', 1071),
(229, '2024-06-03', 979, 1756, 'Anastasia Mulema', 1071),
(230, '2024-06-04', 960, 1738, 'Aisha Awori', 1071),
(231, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(232, '2024-06-04', 953, 2050, 'Yoonseo Choi', 1071),
(233, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(234, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(235, '2024-06-04', 953, 2050, 'Yoonseo Choi', 1071),
(236, '2024-06-04', 974, 2057, 'Tanay Cherickel', 1071),
(237, '2024-06-04', 929, 1806, 'Moussa Sangare', 1071),
(238, '2024-06-04', 960, 1833, 'Aisha Awori', 1071),
(239, '2024-06-04', 980, 1754, 'Etienne Carlevato', 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(240, '2024-06-04', 928, 1900, 'Lilla Vestergaard', 1071),
(241, '2024-06-04', 176, 2060, 'Lucile Bamlango', 1071),
(242, '2024-06-04', 926, 2115, 'Seya Chandaria', 1071),
(243, '2024-06-04', 935, 1522, 'Mikael Eshetu', 1071),
(244, '2024-06-04', 942, 2116, 'Saqer Alnaqbi', 1071),
(245, '2024-06-04', 981, 1714, 'Lauren Mucci', 1071),
(246, '2024-06-04', 945, 1704, 'Eliana Hodge', 1071),
(247, '2024-06-04', 984, 1531, 'Nirvi Joymungul', 1071),
(248, '2024-06-04', 979, 1756, 'Anastasia Mulema', 1071),
(249, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(250, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(251, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(252, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(253, '2024-06-04', 846, 2105, 'Sadie Szuchman', 1071),
(254, '2024-06-04', 846, 2105, 'nochomo', 1071),
(255, '2024-06-04', 846, 2105, 'nochomo', 1071),
(256, '2024-06-04', 846, 2105, 'nochomo', 1071),
(257, '2024-06-04', 846, 2105, 'nochomo', 1071),
(258, '2024-06-04', 960, 1738, 'nochomo', 1071),
(259, '2024-06-04', 979, 1756, 'nochomo', 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "equipment" does not exist
LINE 1: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN...
^
QUERY: (SELECT family FROM equipment WHERE id = NEW.item_id) NOT IN ('STRING', 'WOODWIND', 'BRASS', 'PERCUSSION', 'ELECTRIC', 'KEYBOARD')
CONTEXT: PL/pgSQL function public.dispatch() line 7 at IF
Command was: INSERT INTO public.dispatches VALUES
(260, '2024-06-04', 945, 1891, 'nochomo', 1071),
(261, '2024-06-04', 980, 1754, 'nochomo', 1071),
(262, '2024-06-04', 981, 1714, 'nochomo', 1071),
(263, '2024-06-04', 928, 1900, 'nochomo', 1071),
(264, '2024-06-04', 176, 2060, 'nochomo', 1071),
(265, '2024-06-04', 935, 1522, 'nochomo', 1071),
(266, '2024-06-04', 929, 1806, 'nochomo', 1071),
(267, '2024-06-04', 929, 1806, 'nochomo', 1071),
(268, '2024-06-04', 984, 1790, 'nochomo', 1071),
(269, '2024-06-04', 846, 2105, 'nochomo', 1071),
(270, '2024-06-04', 942, 2116, 'nochomo', 1071),
(271, '2024-06-04', 926, 2115, 'nochomo', 1071),
(272, '2024-06-04', 953, 2050, 'nochomo', 1071),
(273, '2024-06-04', 974, 2057, 'nochomo', 1071),
(274, '2024-06-04', 1075, 1598, 'kwando', 1082),
(275, '2024-06-04', 967, 2046, 'kwando', 1082),
(276, '2024-06-04', 1075, 1809, 'kwando', 1082) ON CONFLICT DO NOTHING;
pg_restore: processing data for table "public.duplicate_instruments"
pg_restore: processing data for table "public.equipment"
pg_restore: processing data for table "public.hardware_and_equipment"
pg_restore: processing data for table "public.instrument_conditions"
pg_restore: processing data for table "public.instrument_history"
pg_restore: from TOC entry 3939; 0 16606 TABLE DATA instrument_history postgres
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4163) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(11, 'Instrument Created', '2024-02-01 00:00:00+03', 4163, NULL, NULL, 'postgres', NULL, NULL, NULL),
(12, 'Instrument Created', '2024-02-01 00:00:00+03', 4164, NULL, NULL, 'postgres', NULL, NULL, NULL),
(13, 'Instrument Created', '2024-02-01 00:00:00+03', 4165, NULL, NULL, 'postgres', NULL, NULL, NULL),
(14, 'Instrument Created', '2024-02-01 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2987, 'Details Updated', '2024-02-23 00:00:00+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(16, 'Instrument Out', '2024-02-01 00:00:00+03', 4166, NULL, '1072', 'postgres', NULL, NULL, NULL),
(2988, 'Instrument Out', '2024-02-23 00:00:00+03', 2129, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(18, 'Instrument Out', '2024-02-01 00:00:00+03', 4166, NULL, '1072', 'postgres', NULL, NULL, NULL),
(3055, 'Instrument Returned', '2024-03-01 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(20, 'Instrument Out', '2024-02-01 00:00:00+03', 4166, NULL, '1072', 'postgres', NULL, NULL, NULL),
(3103, 'Instrument Out', '2024-03-04 00:00:00+03', 4163, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3142, 'Instrument Returned', '2024-03-07 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(23, 'Instrument Out', '2024-02-01 00:00:00+03', 4166, NULL, '1072', 'postgres', NULL, NULL, NULL),
(26, 'Instrument Out', '2024-02-01 00:00:00+03', 4166, NULL, '1072', 'postgres', NULL, NULL, NULL),
(27, 'Instrument Returned', '2024-02-01 00:00:00+03', 2129, NULL, NULL, 'postgres', NULL, NULL, NULL),
(30, 'Instrument Returned', '2024-02-01 00:00:00+03', 2129, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2989, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(2990, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3056, 'Instrument Out', '2024-03-01 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3104, 'Instrument Returned', '2024-03-04 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4165) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3105, 'Instrument Returned', '2024-03-04 00:00:00+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3106, 'Instrument Returned', '2024-03-04 00:00:00+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3143, 'Instrument Returned', '2024-03-07 00:00:00+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(2991, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2992, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2993, 'Details Updated', '2024-02-23 00:00:00+03', 2129, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2994, 'Instrument Returned', '2024-02-23 00:00:00+03', 2129, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2997, 'Details Updated', '2024-02-23 00:00:00+03', 2129, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2998, 'Instrument Returned', '2024-02-23 00:00:00+03', 2129, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2999, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3000, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3003, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3004, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3007, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3008, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3011, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3012, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3015, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3016, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3019, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4166) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3020, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3023, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3024, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3028, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3029, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3032, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3033, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3036, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3037, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3057, 'Instrument Returned', '2024-03-01 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3107, 'Instrument Out', '2024-03-04 00:00:00+03', 4166, NULL, '1072', 'nochomo', NULL, NULL, NULL),
(3144, 'Instrument Out', '2024-03-07 00:00:00+03', 4166, NULL, '1072', 'nochomo', NULL, NULL, NULL),
(2995, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(2996, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3058, 'Instrument Out', '2024-03-01 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3108, 'Instrument Out', '2024-03-04 00:00:00+03', 2129, NULL, '1072', 'nochomo', NULL, NULL, NULL),
(3001, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3002, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3059, 'Instrument Returned', '2024-03-01 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3109, 'Instrument Returned', '2024-03-04 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4163) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3110, 'Instrument Returned', '2024-03-04 00:00:00+03', 4163, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3005, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3006, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3060, 'Instrument Out', '2024-03-01 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3061, 'Instrument Returned', '2024-03-01 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3062, 'Instrument Returned', '2024-03-01 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3111, 'Instrument Out', '2024-03-04 00:00:00+03', 4163, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3009, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3010, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3063, 'Instrument Out', '2024-03-02 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3112, 'Instrument Out', '2024-03-04 00:00:00+03', 4165, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3013, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3014, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3064, 'Instrument Returned', '2024-03-02 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3113, 'Instrument Returned', '2024-03-04 00:00:00+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3017, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3018, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3076, 'Instrument Out', '2024-03-03 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3114, 'Instrument Out', '2024-03-04 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3021, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4166) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3022, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3077, 'Instrument Returned', '2024-03-03 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3115, 'Instrument Returned', '2024-03-04 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3026, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3027, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3078, 'Instrument Out', '2024-03-03 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3116, 'Instrument Returned', '2024-03-04 00:00:00+03', 4163, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3030, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3031, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3082, 'Instrument Returned', '2024-03-03 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3117, 'Instrument Returned', '2024-03-04 00:00:00+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3034, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3035, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3083, 'Instrument Out', '2024-03-03 00:00:00+03', 4166, NULL, '1072', 'nochomo', NULL, NULL, NULL),
(3118, 'Instrument Out', '2024-03-05 00:00:00+03', 4166, NULL, '1072', 'nochomo', NULL, NULL, NULL),
(3038, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3039, 'Instrument Out', '2024-02-23 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3084, 'Instrument Out', '2024-03-03 00:00:00+03', 4165, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3119, 'Instrument Out', '2024-03-05 00:00:00+03', 4165, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3040, 'Details Updated', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4166) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3041, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3085, 'Instrument Out', '2024-03-03 00:00:00+03', 4164, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3120, 'Instrument Out', '2024-03-06 00:00:00+03', 2129, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3042, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3043, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3044, 'Instrument Returned', '2024-02-23 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3086, 'Instrument Out', '2024-03-03 00:00:00+03', 2129, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3121, 'Instrument Returned', '2024-03-06 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3045, 'Instrument Returned', '2024-02-25 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3087, 'Instrument Returned', '2024-03-03 00:00:00+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3088, 'Instrument Returned', '2024-03-03 00:00:00+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3089, 'Instrument Returned', '2024-03-03 00:00:00+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3090, 'Instrument Returned', '2024-03-03 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3122, 'Instrument Out', '2024-03-06 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3046, 'Instrument Returned', '2024-02-25 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3091, 'Instrument Out', '2024-03-03 00:00:00+03', 4166, NULL, '1072', 'nochomo', NULL, NULL, NULL),
(3123, 'Instrument Returned', '2024-03-06 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3047, 'Instrument Returned', '2024-02-25 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3048, 'Instrument Returned', '2024-02-25 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3092, 'Instrument Out', '2024-03-03 00:00:00+03', 4165, NULL, '1072', 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4166) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3124, 'Instrument Out', '2024-03-06 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(2264, 'Instrument Returned', '2024-02-01 00:00:00+03', 1731, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2266, 'Instrument Returned', '2024-02-01 00:00:00+03', 1768, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2268, 'Instrument Returned', '2024-02-01 00:00:00+03', 2072, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2270, 'Instrument Returned', '2024-02-01 00:00:00+03', 1595, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2272, 'Instrument Returned', '2024-02-01 00:00:00+03', 1618, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2274, 'Instrument Returned', '2024-02-01 00:00:00+03', 2072, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2276, 'Instrument Returned', '2024-02-01 00:00:00+03', 2072, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2278, 'Instrument Returned', '2024-02-01 00:00:00+03', 1768, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2280, 'Instrument Returned', '2024-02-01 00:00:00+03', 1618, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2282, 'Instrument Returned', '2024-02-01 00:00:00+03', 1731, NULL, NULL, 'postgres', NULL, NULL, NULL),
(2284, 'Instrument Returned', '2024-02-01 00:00:00+03', 1595, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3049, 'Instrument Returned', '2024-02-25 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3093, 'Instrument Returned', '2024-03-03 00:00:00+03', 1757, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3125, 'Instrument Returned', '2024-03-06 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3050, 'Instrument Returned', '2024-02-25 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3094, 'Instrument Returned', '2024-03-03 00:00:00+03', 1566, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3126, 'Instrument Returned', '2024-03-07 00:00:00+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3051, 'Instrument Returned', '2024-02-28 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3095, 'Instrument Returned', '2024-03-03 00:00:00+03', 2098, NULL, NULL, 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4166) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3134, 'Instrument Out', '2024-03-07 00:00:00+03', 4166, NULL, '1074', 'postgres', NULL, NULL, NULL),
(3052, 'Instrument Returned', '2024-02-28 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3096, 'Instrument Out', '2024-03-04 00:00:00+03', 4164, NULL, '1072', 'nochomo', NULL, NULL, NULL),
(3097, 'Instrument Returned', '2024-03-04 00:00:00+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3098, 'Instrument Out', '2024-03-04 00:00:00+03', 4164, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3138, 'Instrument Out', '2024-03-07 00:00:00+03', 4165, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3053, 'Instrument Returned', '2024-02-28 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3099, 'Instrument Out', '2024-03-04 00:00:00+03', 4163, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3139, 'Instrument Returned', '2024-03-07 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3140, 'Instrument Out', '2024-03-07 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3054, 'Instrument Out', '2024-03-01 00:00:00+03', 4166, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3100, 'Instrument Returned', '2024-03-04 00:00:00+03', 4163, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3101, 'Instrument Returned', '2024-03-04 00:00:00+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3102, 'Instrument Out', '2024-03-04 00:00:00+03', 4164, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(3141, 'Instrument Out', '2024-03-07 00:00:00+03', 4164, NULL, '1074', 'nochomo', NULL, NULL, NULL),
(2977, 'Instrument Returned', '2024-02-15 00:00:00+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3145, 'Instrument Found', '2024-03-15 00:00:00+03', 1906, NULL, NULL, 'Ochomo', 'Music Office', '0720808052', NULL),
(3146, 'Instrument Found', '2024-03-15 00:00:00+03', 1906, NULL, NULL, 'Ochomo', 'Music Office', '0720808052', NULL),
(3147, 'Instrument Found', '2024-03-16 00:00:00+03', 1894, NULL, NULL, 'Noah Ochomo', 'My car', '0720808052', NULL),
(3148, 'Instrument Found', '2024-03-16 00:00:00+03', 1994, NULL, NULL, 'Noah Ochomo', 'Home', '0720808052', NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(1994) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3149, 'Instrument Found', '2024-03-16 00:00:00+03', 1994, NULL, NULL, 'Noah', 'home', '0720808052', NULL),
(3150, 'Instrument Found', '2024-03-16 00:00:00+03', 1686, NULL, NULL, 'Noah Ochomo', 'Home', '0720808052', NULL),
(3151, 'Instrument Found', '2024-03-16 00:00:00+03', 1994, NULL, NULL, 'Noah Ochomo', 'Home', '0720808052', NULL),
(3152, 'Instrument Found', '2024-03-16 00:00:00+03', 1994, NULL, NULL, 'Noah Ochomo', 'Home again', '0720808052', NULL),
(3153, 'Instrument Out', '2024-03-17 00:00:00+03', 4165, NULL, '1074', 'postgres', NULL, NULL, NULL),
(3154, 'Instrument Out', '2024-03-17 00:00:00+03', 4165, NULL, '1074', 'postgres', NULL, NULL, NULL),
(3155, 'Instrument Out', '2024-03-17 00:00:00+03', 4165, NULL, '1074', 'postgres', NULL, NULL, NULL),
(3156, 'Instrument Out', '2024-03-17 00:00:00+03', 4165, NULL, '1074', 'postgres', NULL, NULL, NULL),
(3157, 'Instrument Out', '2024-03-17 00:00:00+03', 4165, NULL, '1074', 'postgres', NULL, NULL, NULL),
(3158, 'Instrument Out', '2024-03-17 00:00:00+03', 4163, NULL, '1072', 'postgres', NULL, NULL, NULL),
(3159, 'Instrument Returned', '2024-03-17 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3160, 'Instrument Returned', '2024-03-17 00:00:00+03', 4165, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3161, 'Instrument Out', '2024-03-17 00:00:00+03', 4166, NULL, '1072', 'postgres', NULL, NULL, NULL),
(3162, 'Instrument Out', '2024-03-17 00:00:00+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3163, 'Instrument Returned', '2024-03-17 00:00:00+03', 4166, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3164, 'Instrument Returned', '2024-03-17 00:00:00+03', 4165, NULL, NULL, 'postgres', NULL, NULL, NULL),
(3167, 'Instrument Returned', '2024-03-18 00:00:00+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3184, 'New Instrument', '2024-03-19 00:00:00+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3185, 'New Instrument', '2024-03-19 00:00:00+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3186, 'New Instrument', '2024-03-19 00:00:00+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4209) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3187, 'New Instrument', '2024-03-19 00:00:00+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3188, 'Instrument Returned', '2024-03-19 20:45:17.052984+03', 4163, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3189, 'Instrument Out', '2024-03-19 23:03:04.561623+03', 4163, NULL, NULL, NULL, NULL, NULL, NULL),
(3190, 'Instrument Out', '2024-03-19 23:17:40.012708+03', 4166, NULL, NULL, NULL, NULL, NULL, NULL),
(3191, 'Instrument Returned', '2024-03-20 18:20:53.296019+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3192, 'Instrument Returned', '2024-03-20 18:37:57.203193+03', 4163, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3193, 'Instrument Returned', '2024-03-20 18:38:44.142515+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3194, 'Instrument Out', '2024-03-20 18:40:14.786945+03', 2129, NULL, NULL, NULL, NULL, NULL, NULL),
(3195, 'Instrument Out', '2024-03-20 18:44:15.749167+03', 4164, NULL, NULL, NULL, NULL, NULL, NULL),
(3196, 'Instrument Out', '2024-03-20 18:44:45.498436+03', 4166, NULL, NULL, NULL, NULL, NULL, NULL),
(3197, 'Instrument Returned', '2024-03-20 18:50:32.894474+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, NULL),
(3198, 'Instrument Returned', '2024-03-20 18:57:33.623435+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, 1072),
(3199, 'Instrument Returned', '2024-03-21 22:52:51.525032+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, 1074),
(3200, 'Instrument Out', '2024-03-21 22:53:23.894338+03', 4163, NULL, NULL, NULL, NULL, NULL, NULL),
(3201, 'Instrument Returned', '2024-03-22 02:16:21.909458+03', 4163, NULL, NULL, 'nochomo', NULL, NULL, 1072),
(3202, 'Instrument Out', '2024-03-22 02:16:47.296747+03', 4163, NULL, NULL, NULL, NULL, NULL, NULL),
(3203, 'Instrument Out', '2024-03-23 13:56:34.738568+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3204, 'Instrument Out', '2024-03-23 13:56:34.857935+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3205, 'Instrument Returned', '2024-03-23 13:58:10.736355+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3206, 'Instrument Returned', '2024-03-23 13:58:26.354852+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4208) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3207, 'Instrument Out', '2024-03-23 14:00:30.121025+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3208, 'Instrument Out', '2024-03-23 14:00:30.156016+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3209, 'Instrument Returned', '2024-03-23 14:13:33.750753+03', 1999, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3210, 'Instrument Returned', '2024-03-23 14:13:51.263676+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3211, 'Instrument Returned', '2024-03-23 14:13:56.560707+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3212, 'Instrument Out', '2024-03-23 14:14:30.592451+03', 1999, NULL, NULL, NULL, NULL, NULL, NULL),
(3213, 'Instrument Out', '2024-03-23 14:15:24.756148+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3214, 'Instrument Out', '2024-03-23 14:15:24.793395+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3215, 'Instrument Returned', '2024-03-23 14:34:28.231111+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3216, 'Instrument Returned', '2024-03-23 14:34:34.422605+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3217, 'Instrument Out', '2024-03-23 14:37:59.736868+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3218, 'Instrument Out', '2024-03-23 14:37:59.774627+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3219, 'Instrument Returned', '2024-03-23 14:38:49.423055+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3220, 'Instrument Returned', '2024-03-23 14:38:54.437827+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3221, 'Instrument Out', '2024-03-23 14:45:24.943643+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3222, 'Instrument Out', '2024-03-23 14:45:24.978953+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3223, 'Instrument Returned', '2024-03-23 14:46:20.605426+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3224, 'Instrument Returned', '2024-03-23 14:46:28.289105+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3225, 'Instrument Out', '2024-03-23 14:46:34.49957+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3226, 'Instrument Out', '2024-03-23 14:46:34.50893+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4208) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3227, 'Instrument Returned', '2024-03-23 14:46:53.186023+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3228, 'Instrument Returned', '2024-03-23 14:46:58.154198+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3229, 'Instrument Out', '2024-03-23 14:47:21.612437+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3230, 'Instrument Out', '2024-03-23 14:47:21.624566+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3231, 'Instrument Returned', '2024-03-23 14:48:05.085921+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3232, 'Instrument Returned', '2024-03-23 14:48:14.250238+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3233, 'Instrument Out', '2024-03-23 14:48:30.92444+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3234, 'Instrument Out', '2024-03-23 14:48:30.944137+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3235, 'Instrument Returned', '2024-03-23 14:49:45.372975+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3236, 'Instrument Returned', '2024-03-23 14:49:50.172083+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3237, 'Instrument Out', '2024-03-23 14:50:35.239066+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3238, 'Instrument Out', '2024-03-23 14:50:35.263464+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3239, 'Instrument Returned', '2024-03-23 14:58:11.853714+03', 1999, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3240, 'Instrument Returned', '2024-03-23 14:58:16.082702+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3241, 'Instrument Returned', '2024-03-23 14:58:20.182505+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3242, 'Instrument Out', '2024-03-23 14:58:37.918141+03', 1999, NULL, NULL, NULL, NULL, NULL, NULL),
(3243, 'Instrument Out', '2024-03-23 15:04:34.97011+03', 4208, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3244, 'Instrument Out', '2024-03-23 15:04:34.984955+03', 4209, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3245, 'Instrument Returned', '2024-03-23 15:09:07.584011+03', 1999, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3246, 'Instrument Out', '2024-03-23 15:09:43.437983+03', 1999, NULL, NULL, NULL, NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(1999) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3247, 'Instrument Returned', '2024-03-23 15:11:14.326678+03', 1999, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3248, 'Instrument Out', '2024-03-23 15:11:48.239819+03', 1999, NULL, '1071', 'nochomo', NULL, NULL, NULL),
(3249, 'Instrument Returned', '2024-03-23 15:13:22.455621+03', 1999, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3250, 'Instrument Out', '2024-03-23 15:13:42.858048+03', 1999, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3251, 'Instrument Out', '2024-04-19 07:16:49.873627+03', 1676, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3252, 'Instrument Out', '2024-04-19 07:40:47.533423+03', 4164, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3253, 'Instrument Out', '2024-04-19 07:40:47.556126+03', 4165, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3254, 'Instrument Out', '2024-04-19 11:09:40.721755+03', 1925, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3255, 'Instrument Out', '2024-04-19 11:09:40.933327+03', 1971, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3256, 'Instrument Returned', '2024-04-19 11:13:25.283893+03', 1925, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3257, 'Instrument Returned', '2024-04-19 11:13:41.473022+03', 1971, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3258, 'Instrument Returned', '2024-04-19 11:13:50.199534+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3259, 'Instrument Returned', '2024-04-19 11:13:59.611988+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3260, 'Instrument Returned', '2024-04-19 11:14:11.265522+03', 4208, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3261, 'Instrument Returned', '2024-04-19 11:14:15.80887+03', 4209, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3262, 'Instrument Returned', '2024-04-19 11:14:24.032935+03', 1676, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3263, 'Instrument Out', '2024-04-19 11:22:35.352443+03', 4164, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3264, 'Instrument Out', '2024-04-19 11:22:35.458814+03', 4165, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3265, 'Instrument Out', '2024-04-19 11:26:53.55581+03', 1928, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3266, 'Instrument Returned', '2024-04-19 11:32:23.920116+03', 1928, NULL, NULL, 'nochomo', NULL, NULL, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(4165) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3267, 'Instrument Returned', '2024-04-19 11:32:34.01174+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3268, 'Instrument Returned', '2024-04-19 11:32:42.707323+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3269, 'Instrument Out', '2024-04-19 11:39:47.593397+03', 4164, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3270, 'Instrument Out', '2024-04-19 11:39:47.728112+03', 4166, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3271, 'Instrument Out', '2024-04-19 11:39:47.731247+03', 2129, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3272, 'Instrument Out', '2024-04-19 11:45:24.274821+03', 2034, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3273, 'Instrument Out', '2024-04-19 11:45:24.362147+03', 1928, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3274, 'Instrument Out', '2024-04-19 11:48:12.461741+03', 2014, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3275, 'Instrument Out', '2024-04-19 11:48:12.512797+03', 1615, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3276, 'Instrument Out', '2024-04-19 12:32:41.005489+03', 1582, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3277, 'Instrument Out', '2024-04-19 12:32:41.132215+03', 1954, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3278, 'Instrument Out', '2024-04-19 12:32:41.141415+03', 1926, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3279, 'Instrument Out', '2024-04-19 12:35:43.626738+03', 1943, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3280, 'Instrument Out', '2024-04-19 12:35:43.694605+03', 1676, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3281, 'Instrument Out', '2024-04-19 12:35:43.697815+03', 1675, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3282, 'Instrument Out', '2024-04-19 12:37:46.850023+03', 1545, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3283, 'Instrument Out', '2024-04-19 12:37:46.890824+03', 1577, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3284, 'Instrument Out', '2024-04-19 12:37:46.895112+03', 1665, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3285, 'Instrument Out', '2024-04-19 12:38:56.917308+03', 2016, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3286, 'Instrument Out', '2024-04-19 12:38:56.957434+03', 1798, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(1971) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3287, 'Instrument Out', '2024-04-19 12:41:17.218996+03', 1971, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3288, 'Instrument Out', '2024-04-19 12:41:17.273268+03', 1925, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3289, 'Instrument Out', '2024-04-19 15:31:15.435804+03', 1818, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3290, 'Instrument Returned', '2024-04-19 15:34:14.44586+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3291, 'Instrument Returned', '2024-04-19 15:34:22.850714+03', 1818, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3292, 'Instrument Returned', '2024-04-19 15:34:28.63109+03', 1926, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3293, 'Instrument Returned', '2024-04-19 15:34:34.199532+03', 1798, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3294, 'Instrument Returned', '2024-04-19 15:34:38.781458+03', 1925, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3295, 'Instrument Returned', '2024-04-19 15:34:46.055931+03', 1971, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3296, 'Instrument Returned', '2024-04-19 15:34:51.482082+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3297, 'Instrument Returned', '2024-04-19 15:34:58.40014+03', 4166, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3298, 'Instrument Returned', '2024-04-19 15:35:05.711899+03', 1665, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3299, 'Instrument Returned', '2024-04-19 15:35:11.485412+03', 1577, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3300, 'Instrument Returned', '2024-04-19 15:35:15.697832+03', 1675, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3301, 'Instrument Returned', '2024-04-19 15:35:22.348844+03', 1676, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3302, 'Instrument Returned', '2024-04-19 15:35:26.597389+03', 1954, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3303, 'Instrument Returned', '2024-04-19 15:35:30.765752+03', 1582, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3304, 'Instrument Returned', '2024-04-19 15:35:36.215817+03', 2034, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3305, 'Instrument Returned', '2024-04-19 15:35:55.126184+03', 1615, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3306, 'Instrument Returned', '2024-04-19 15:36:02.631111+03', 1943, NULL, NULL, 'nochomo', NULL, NULL, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(2014) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3307, 'Instrument Returned', '2024-04-19 15:36:08.147832+03', 2014, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3308, 'Instrument Returned', '2024-04-19 15:36:24.180589+03', 1545, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3309, 'Instrument Returned', '2024-04-19 15:36:32.49465+03', 1928, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3310, 'Instrument Returned', '2024-04-19 15:36:36.181881+03', 2016, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3311, 'Instrument Out', '2024-04-21 16:13:35.849118+03', 4164, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3312, 'Instrument Out', '2024-04-21 16:13:35.95195+03', 4165, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3313, 'Instrument Out', '2024-04-21 16:13:35.954231+03', 2129, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3314, 'Instrument Out', '2024-04-21 16:18:39.873914+03', 2091, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3315, 'Instrument Out', '2024-04-21 16:18:39.918192+03', 1928, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3316, 'Instrument Out', '2024-04-21 16:26:10.778082+03', 2014, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3317, 'Instrument Out', '2024-04-21 16:26:10.81694+03', 1615, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3318, 'Instrument Returned', '2024-04-21 16:41:04.006431+03', 2129, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3319, 'Instrument Returned', '2024-05-06 12:55:17.144255+03', 2047, NULL, NULL, 'nochomo', NULL, NULL, 947),
(3320, 'Instrument Out', '2024-05-06 13:06:37.252995+03', 2047, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3321, 'Instrument Returned', '2024-05-06 13:08:10.213191+03', 2047, NULL, NULL, 'nochomo', NULL, NULL, 947),
(3322, 'Instrument Out', '2024-05-06 13:08:32.798875+03', 2047, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3323, 'Instrument Returned', '2024-05-06 13:08:55.079898+03', 4164, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3324, 'Instrument Returned', '2024-05-06 13:23:34.486909+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3325, 'Instrument Returned', '2024-05-06 13:23:54.134568+03', 1615, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3326, 'Instrument Returned', '2024-05-06 13:23:58.58394+03', 2014, NULL, NULL, 'nochomo', NULL, NULL, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(2091) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3327, 'Instrument Returned', '2024-05-06 13:24:03.78523+03', 2091, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3328, 'Instrument Returned', '2024-05-06 13:24:06.918071+03', 4165, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3329, 'Instrument Returned', '2024-05-06 13:24:11.051263+03', 1928, NULL, NULL, 'nochomo', NULL, NULL, 1071),
(3330, 'Instrument Out', '2024-05-06 13:27:42.215241+03', 1818, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3331, 'Instrument Out', '2024-05-06 13:34:23.449744+03', 1856, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3332, 'Instrument Out', '2024-05-06 13:41:25.088197+03', 1873, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3333, 'Instrument Out', '2024-05-06 13:41:25.119678+03', 1496, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3334, 'Instrument Returned', '2024-05-29 09:17:14.180829+03', 2093, NULL, NULL, 'nochomo', NULL, NULL, 954),
(3335, 'Instrument Returned', '2024-05-29 09:17:24.996534+03', 2095, NULL, NULL, 'nochomo', NULL, NULL, 955),
(3336, 'Instrument Returned', '2024-05-29 09:17:29.735537+03', 2093, NULL, NULL, 'nochomo', NULL, NULL, 954),
(3337, 'Instrument Returned', '2024-05-29 09:18:20.360764+03', 1848, NULL, NULL, 'nochomo', NULL, NULL, 115),
(3338, 'Instrument Returned', '2024-05-29 09:20:31.368676+03', 1710, NULL, NULL, 'nochomo', NULL, NULL, 481),
(3339, 'Instrument Returned', '2024-05-29 09:21:00.538337+03', 2122, NULL, NULL, 'nochomo', NULL, NULL, 114),
(3340, 'Instrument Returned', '2024-05-29 09:21:44.647905+03', 2041, NULL, NULL, 'nochomo', NULL, NULL, 240),
(3341, 'Instrument Returned', '2024-05-29 09:23:10.461736+03', 1698, NULL, NULL, 'nochomo', NULL, NULL, 601),
(3342, 'Instrument Returned', '2024-05-29 09:23:57.030373+03', 1744, NULL, NULL, 'nochomo', NULL, NULL, 300),
(3343, 'Instrument Returned', '2024-05-30 09:04:43.128243+03', 1790, NULL, NULL, 'nochomo', NULL, NULL, 662),
(3344, 'Instrument Returned', '2024-05-30 09:04:55.599993+03', 1699, NULL, NULL, 'nochomo', NULL, NULL, 482),
(3345, 'Instrument Returned', '2024-05-30 09:05:09.399669+03', 1993, NULL, NULL, 'nochomo', NULL, NULL, 361),
(3346, 'Instrument Returned', '2024-05-30 09:05:22.949572+03', 1703, NULL, NULL, 'nochomo', NULL, NULL, 911) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(2111) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3347, 'Instrument Returned', '2024-05-30 09:05:36.15039+03', 2111, NULL, NULL, 'nochomo', NULL, NULL, 117),
(3348, 'Instrument Returned', '2024-05-30 09:06:00.532144+03', 1819, NULL, NULL, 'nochomo', NULL, NULL, 179),
(3349, 'Instrument Returned', '2024-05-30 09:06:31.166263+03', 1701, NULL, NULL, 'nochomo', NULL, NULL, 962),
(3350, 'Instrument Returned', '2024-05-30 09:06:48.313145+03', 2109, NULL, NULL, 'nochomo', NULL, NULL, 302),
(3351, 'Instrument Returned', '2024-05-30 09:09:25.068981+03', 1700, NULL, NULL, 'nochomo', NULL, NULL, 959),
(3352, 'Instrument Returned', '2024-05-30 09:09:32.781595+03', 1700, NULL, NULL, 'nochomo', NULL, NULL, 959),
(3353, 'Instrument Returned', '2024-05-30 09:09:55.528704+03', 2112, NULL, NULL, 'nochomo', NULL, NULL, 961),
(3354, 'Instrument Returned', '2024-05-30 09:10:40.113498+03', 1756, NULL, NULL, 'nochomo', NULL, NULL, 979),
(3355, 'Instrument Returned', '2024-05-30 12:44:53.66717+03', 1746, NULL, NULL, 'nochomo', NULL, NULL, 358),
(3356, 'Instrument Returned', '2024-05-30 12:45:15.629474+03', 1787, NULL, NULL, 'nochomo', NULL, NULL, 299),
(3357, 'Instrument Returned', '2024-05-30 12:48:08.968554+03', 2110, NULL, NULL, 'nochomo', NULL, NULL, 356),
(3358, 'Instrument Returned', '2024-05-30 12:49:23.087004+03', 2047, NULL, NULL, 'nochomo', NULL, NULL, 947),
(3359, 'Instrument Returned', '2024-05-30 12:52:41.965928+03', 2097, NULL, NULL, 'nochomo', NULL, NULL, 788),
(3360, 'Instrument Returned', '2024-05-30 12:52:53.567851+03', 2055, NULL, NULL, 'nochomo', NULL, NULL, 357),
(3361, 'Instrument Returned', '2024-05-30 13:12:38.353165+03', 2107, NULL, NULL, 'nochomo', NULL, NULL, 59),
(3362, 'Instrument Returned', '2024-05-30 13:14:02.654981+03', 1918, NULL, NULL, 'nochomo', NULL, NULL, 973),
(3363, 'Instrument Returned', '2024-05-31 07:32:42.859919+03', 1785, NULL, NULL, 'nochomo', NULL, NULL, 927),
(3364, 'Instrument Returned', '2024-05-31 07:34:29.12025+03', 1718, NULL, NULL, 'nochomo', NULL, NULL, 976),
(3365, 'Instrument Returned', '2024-05-31 07:34:49.76911+03', 1740, NULL, NULL, 'nochomo', NULL, NULL, 975),
(3366, 'Instrument Returned', '2024-05-31 07:35:07.138927+03', 2114, NULL, NULL, 'nochomo', NULL, NULL, 977) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(2101) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3367, 'Instrument Returned', '2024-05-31 07:35:27.083+03', 2101, NULL, NULL, 'nochomo', NULL, NULL, 934),
(3368, 'Instrument Returned', '2024-05-31 07:35:42.818178+03', 2100, NULL, NULL, 'nochomo', NULL, NULL, 239),
(3369, 'Instrument Returned', '2024-05-31 07:35:58.184502+03', 1733, NULL, NULL, 'nochomo', NULL, NULL, 933),
(3370, 'Instrument Returned', '2024-05-31 07:46:30.712912+03', 1674, NULL, NULL, 'nochomo', NULL, NULL, 240),
(3371, 'Instrument Returned', '2024-05-31 07:47:24.064056+03', 1996, NULL, NULL, 'nochomo', NULL, NULL, 941),
(3372, 'Instrument Returned', '2024-05-31 07:47:52.61421+03', 1715, NULL, NULL, 'nochomo', NULL, NULL, 925),
(3373, 'Instrument Returned', '2024-05-31 07:48:12.763353+03', 2115, NULL, NULL, 'nochomo', NULL, NULL, 926),
(3374, 'Instrument Returned', '2024-05-31 07:49:42.109761+03', 2060, NULL, NULL, 'nochomo', NULL, NULL, 176),
(3375, 'Instrument Returned', '2024-05-31 07:50:19.417907+03', 1900, NULL, NULL, 'nochomo', NULL, NULL, 928),
(3376, 'Instrument Returned', '2024-05-31 07:50:52.215821+03', 1861, NULL, NULL, 'nochomo', NULL, NULL, 480),
(3377, 'Instrument Returned', '2024-05-31 07:51:48.798328+03', 2053, NULL, NULL, 'nochomo', NULL, NULL, 944),
(3378, 'Instrument Returned', '2024-05-31 07:52:06.775095+03', 1716, NULL, NULL, 'nochomo', NULL, NULL, 539),
(3379, 'Instrument Out', '2024-05-31 07:58:40.882651+03', 2115, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3380, 'Instrument Returned', '2024-05-31 07:59:01.829229+03', 2115, NULL, NULL, 'nochomo', NULL, NULL, 926),
(3381, 'Instrument Returned', '2024-05-31 08:57:37.581899+03', 2115, NULL, NULL, 'nochomo', NULL, NULL, 926),
(3382, 'Instrument Out', '2024-05-31 08:58:07.578447+03', 2115, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3383, 'Instrument Returned', '2024-05-31 08:58:53.706805+03', 2115, NULL, NULL, 'nochomo', NULL, NULL, 926),
(3384, 'Instrument Returned', '2024-06-03 10:28:52.812081+03', 2006, NULL, NULL, 'nochomo', NULL, NULL, 932),
(3385, 'Instrument Returned', '2024-06-03 10:47:16.065706+03', 2040, NULL, NULL, 'nochomo', NULL, NULL, 602),
(3386, 'Instrument Out', '2024-06-03 10:50:33.783588+03', 2115, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(2115) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3387, 'Instrument Returned', '2024-06-03 10:58:38.611573+03', 2115, NULL, NULL, 'nochomo', NULL, NULL, 926),
(3388, 'Instrument Out', '2024-06-03 11:02:14.987411+03', 2115, NULL, '1071', 'Noah Ochomo', NULL, NULL, NULL),
(3389, 'Instrument Returned', '2024-06-03 11:15:52.85403+03', 2115, NULL, NULL, 'nochomo', NULL, NULL, 926),
(3390, 'Instrument Out', '2024-06-03 11:16:10.553559+03', 2115, NULL, '1071', 'Seya Chandaria', NULL, NULL, NULL),
(3391, 'Instrument Out', '2024-06-03 11:20:24.093458+03', 1522, NULL, '1071', 'Mikael Eshetu', NULL, NULL, NULL),
(3392, 'Instrument Out', '2024-06-03 11:21:31.38848+03', 2060, NULL, '1071', 'Lucile Bamlango', NULL, NULL, NULL),
(3393, 'Instrument Out', '2024-06-03 11:22:07.947706+03', 1900, NULL, '1071', 'Lilla Vestergaard', NULL, NULL, NULL),
(3394, 'Instrument Returned', '2024-06-03 11:22:57.98366+03', 1806, NULL, NULL, 'nochomo', NULL, NULL, 935),
(3395, 'Instrument Out', '2024-06-03 11:23:15.676293+03', 1806, NULL, '1071', 'Moussa Sangare', NULL, NULL, NULL),
(3396, 'Instrument Out', '2024-06-03 11:26:22.311277+03', 1716, NULL, '1071', 'Fatima Zucca', NULL, NULL, NULL),
(3397, 'Instrument Out', '2024-06-03 11:27:52.941693+03', 1861, NULL, '1071', 'Kai O''Bra', NULL, NULL, NULL),
(3398, 'Instrument Returned', '2024-06-03 11:34:31.956002+03', 1754, NULL, NULL, 'nochomo', NULL, NULL, 942),
(3399, 'Instrument Returned', '2024-06-03 11:34:59.858418+03', 1714, NULL, NULL, 'nochomo', NULL, NULL, 981),
(3400, 'Instrument Out', '2024-06-03 11:35:17.664365+03', 1714, NULL, '1071', 'Lauren Mucci', NULL, NULL, NULL),
(3401, 'Instrument Returned', '2024-06-03 11:35:52.938266+03', 1704, NULL, NULL, 'nochomo', NULL, NULL, 945),
(3402, 'Instrument Out', '2024-06-03 11:36:15.812574+03', 1704, NULL, '1071', 'Eliana Hodge', NULL, NULL, NULL),
(3403, 'Instrument Returned', '2024-06-03 11:36:36.71177+03', 1531, NULL, NULL, 'nochomo', NULL, NULL, 984),
(3404, 'Instrument Out', '2024-06-03 11:36:54.47896+03', 1531, NULL, '1071', 'Nirvi Joymungul', NULL, NULL, NULL),
(3405, 'Instrument Out', '2024-06-03 11:37:30.516854+03', 1756, NULL, '1071', 'Anastasia Mulema', NULL, NULL, NULL),
(3406, 'Instrument Returned', '2024-06-03 12:45:58.139744+03', 1876, NULL, NULL, 'nochomo', NULL, NULL, 958) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(2045) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3407, 'Instrument Returned', '2024-06-03 12:51:42.851022+03', 2045, NULL, NULL, 'nochomo', NULL, NULL, 940),
(3408, 'Instrument Returned', '2024-06-03 13:07:06.046592+03', 1712, NULL, NULL, 'nochomo', NULL, NULL, 659),
(3409, 'Instrument Returned', '2024-06-03 13:08:09.79996+03', 1878, NULL, NULL, 'nochomo', NULL, NULL, 956),
(3410, 'Instrument Returned', '2024-06-03 13:12:00.767599+03', 1880, NULL, NULL, 'nochomo', NULL, NULL, 931),
(3411, 'Instrument Returned', '2024-06-03 13:13:24.475615+03', 2120, NULL, NULL, 'nochomo', NULL, NULL, 538),
(3412, 'Instrument Returned', '2024-06-03 13:25:14.878331+03', 1716, NULL, NULL, 'nochomo', NULL, NULL, 539),
(3413, 'Instrument Returned', '2024-06-03 13:26:48.604971+03', 1716, NULL, NULL, 'nochomo', NULL, NULL, 539),
(3414, 'Instrument Returned', '2024-06-03 13:28:06.735386+03', 2067, NULL, NULL, 'nochomo', NULL, NULL, 360),
(3415, 'Instrument Returned', '2024-06-03 13:58:29.663701+03', 1702, NULL, NULL, 'nochomo', NULL, NULL, 980),
(3416, 'Instrument Returned', '2024-06-03 14:09:10.111869+03', 1755, NULL, NULL, 'nochomo', NULL, NULL, 929),
(3417, 'Instrument Returned', '2024-06-04 09:41:47.775032+03', 1924, NULL, NULL, 'nochomo', NULL, NULL, 952),
(3418, 'Instrument Returned', '2024-06-04 09:42:02.473086+03', 2046, NULL, NULL, 'nochomo', NULL, NULL, 967),
(3419, 'Instrument Returned', '2024-06-04 09:49:49.651175+03', 1738, NULL, NULL, 'nochomo', NULL, NULL, 960),
(3420, 'Instrument Out', '2024-06-04 10:06:28.072871+03', 1738, NULL, '1071', 'Aisha Awori', NULL, NULL, NULL),
(3421, 'Instrument Returned', '2024-06-04 10:13:18.073188+03', 2099, NULL, NULL, 'nochomo', NULL, NULL, 1070),
(3422, 'Instrument Returned', '2024-06-04 10:13:38.024594+03', 2074, NULL, NULL, 'nochomo', NULL, NULL, 359),
(3423, 'Instrument Returned', '2024-06-04 10:13:57.87677+03', 1995, NULL, NULL, 'nochomo', NULL, NULL, 847),
(3424, 'Instrument Returned', '2024-06-04 10:17:21.887096+03', 2105, NULL, NULL, 'nochomo', NULL, NULL, 846),
(3478, 'Instrument Returned', '2024-06-04 14:42:42.108399+03', 1861, NULL, NULL, 'nochomo', NULL, NULL, 480),
(3479, 'Instrument Returned', '2024-06-04 14:43:28.66041+03', 2057, NULL, NULL, 'nochomo', NULL, NULL, 974) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(1833) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3480, 'Instrument Returned', '2024-06-04 14:43:53.211107+03', 1833, NULL, NULL, 'nochomo', NULL, NULL, 960),
(3481, 'Instrument Returned', '2024-06-04 14:43:55.943619+03', 1756, NULL, NULL, 'nochomo', NULL, NULL, 979),
(3482, 'Instrument Returned', '2024-06-04 14:43:58.490047+03', 1704, NULL, NULL, 'nochomo', NULL, NULL, 945),
(3483, 'Instrument Returned', '2024-06-04 14:44:01.411134+03', 1754, NULL, NULL, 'nochomo', NULL, NULL, 980),
(3484, 'Instrument Returned', '2024-06-04 14:44:03.674494+03', 1714, NULL, NULL, 'nochomo', NULL, NULL, 981),
(3485, 'Instrument Returned', '2024-06-04 14:44:06.678734+03', 1900, NULL, NULL, 'nochomo', NULL, NULL, 928),
(3486, 'Instrument Returned', '2024-06-04 14:44:13.527601+03', 2060, NULL, NULL, 'nochomo', NULL, NULL, 176),
(3487, 'Instrument Returned', '2024-06-04 14:44:15.76129+03', 1522, NULL, NULL, 'nochomo', NULL, NULL, 935),
(3488, 'Instrument Returned', '2024-06-04 14:44:18.361414+03', 1806, NULL, NULL, 'nochomo', NULL, NULL, 929),
(3489, 'Instrument Returned', '2024-06-04 14:44:20.728758+03', 1531, NULL, NULL, 'nochomo', NULL, NULL, 984),
(3490, 'Instrument Returned', '2024-06-04 14:44:23.410053+03', 1531, NULL, NULL, 'nochomo', NULL, NULL, 984),
(3491, 'Instrument Returned', '2024-06-04 14:44:26.143726+03', 2105, NULL, NULL, 'nochomo', NULL, NULL, 846),
(3492, 'Instrument Returned', '2024-06-04 14:44:32.495491+03', 2116, NULL, NULL, 'nochomo', NULL, NULL, 942),
(3493, 'Instrument Returned', '2024-06-04 14:44:34.558574+03', 2115, NULL, NULL, 'nochomo', NULL, NULL, 926),
(3494, 'Instrument Returned', '2024-06-04 14:44:36.727866+03', 2050, NULL, NULL, 'nochomo', NULL, NULL, 953),
(3495, 'Instrument Out', '2024-06-04 14:45:00.46659+03', 1738, NULL, '960', 'nochomo', NULL, NULL, NULL),
(3496, 'Instrument Out', '2024-06-04 14:45:25.280415+03', 1756, NULL, '979', 'nochomo', NULL, NULL, NULL),
(3497, 'Instrument Out', '2024-06-04 14:45:45.797525+03', 1891, NULL, '945', 'nochomo', NULL, NULL, NULL),
(3498, 'Instrument Out', '2024-06-04 14:46:20.048765+03', 1754, NULL, '980', 'nochomo', NULL, NULL, NULL),
(3499, 'Instrument Out', '2024-06-04 14:46:40.215798+03', 1714, NULL, '981', 'nochomo', NULL, NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(1900) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3500, 'Instrument Out', '2024-06-04 14:47:00.891648+03', 1900, NULL, '928', 'nochomo', NULL, NULL, NULL),
(3501, 'Instrument Out', '2024-06-04 14:47:24.452545+03', 2060, NULL, '176', 'nochomo', NULL, NULL, NULL),
(3502, 'Instrument Out', '2024-06-04 14:47:43.671107+03', 1522, NULL, '935', 'nochomo', NULL, NULL, NULL),
(3503, 'Instrument Out', '2024-06-04 14:50:01.813753+03', 1806, NULL, '929', 'nochomo', NULL, NULL, NULL),
(3504, 'Instrument Returned', '2024-06-04 14:59:12.758238+03', 1806, NULL, NULL, 'nochomo', NULL, NULL, 929),
(3505, 'Instrument Out', '2024-06-04 14:59:28.010613+03', 1806, NULL, '929', 'nochomo', NULL, NULL, NULL),
(3506, 'Instrument Out', '2024-06-04 14:59:50.527222+03', 1790, NULL, '984', 'nochomo', NULL, NULL, NULL),
(3507, 'Instrument Out', '2024-06-04 15:00:45.458748+03', 2105, NULL, '846', 'nochomo', NULL, NULL, NULL),
(3508, 'Instrument Out', '2024-06-04 15:01:25.709028+03', 2116, NULL, '942', 'nochomo', NULL, NULL, NULL),
(3509, 'Instrument Out', '2024-06-04 15:02:46.464635+03', 2115, NULL, '926', 'nochomo', NULL, NULL, NULL),
(3510, 'Instrument Out', '2024-06-04 15:03:20.76348+03', 2050, NULL, '953', 'nochomo', NULL, NULL, NULL),
(3511, 'Instrument Out', '2024-06-04 15:05:11.150118+03', 2057, NULL, '974', 'nochomo', NULL, NULL, NULL),
(3512, 'Instrument Returned', '2024-06-04 15:22:35.567052+03', 1598, NULL, NULL, 'kwando', NULL, NULL, 1075),
(3513, 'Instrument Out', '2024-06-04 15:23:38.355326+03', 1598, NULL, '1075', 'kwando', NULL, NULL, NULL),
(3514, 'Instrument Out', '2024-06-04 15:27:17.274611+03', 2046, NULL, '967', 'kwando', NULL, NULL, NULL),
(3515, 'Instrument Returned', '2024-06-04 15:29:02.272585+03', 2063, NULL, NULL, 'kwando', NULL, NULL, 541),
(3516, 'Instrument Returned', '2024-06-04 15:30:49.207902+03', 1550, NULL, NULL, 'kwando', NULL, NULL, 1075),
(3517, 'Instrument Out', '2024-06-04 15:32:24.864884+03', 1809, NULL, '1075', 'kwando', NULL, NULL, NULL),
(3518, 'Instrument Returned', '2024-06-05 14:57:35.512335+03', 1902, NULL, NULL, 'kwando', NULL, NULL, 948),
(3519, 'Instrument Returned', '2024-06-07 10:52:52.88319+03', 1906, NULL, NULL, 'kwando', NULL, NULL, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_history" violates foreign key constraint "instrument_history_item_id_fkey"
DETAIL: Key (item_id)=(1818) is not present in table "instruments".
Command was: INSERT INTO public.instrument_history VALUES
(3520, 'Instrument Returned', '2024-06-07 10:53:04.070285+03', 1818, NULL, NULL, 'kwando', NULL, NULL, 1071),
(3521, 'Instrument Returned', '2024-06-07 10:53:06.401796+03', 1873, NULL, NULL, 'kwando', NULL, NULL, 1071),
(3522, 'Instrument Returned', '2024-06-07 10:53:22.087919+03', 1856, NULL, NULL, 'kwando', NULL, NULL, 1071),
(3523, 'Instrument Returned', '2024-06-07 10:53:25.683323+03', 1496, NULL, NULL, 'kwando', NULL, NULL, 1071) ON CONFLICT DO NOTHING;
pg_restore: processing data for table "public.instrument_requests"
pg_restore: from TOC entry 3965; 0 17153 TABLE DATA instrument_requests postgres
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_requests" violates foreign key constraint "requests_attended_by_id_fkey"
DETAIL: Key (attended_by_id)=(1071) is not present in table "users".
Command was: INSERT INTO public.instrument_requests VALUES
(55, '2024-03-26 06:41:35.078091+03', 1071, 'SAXOPHONE, BARITONE', 1, NULL, NULL, '1071438891921', '', 'Noah Ochomo', 1071, NULL, '2024-04-09 06:46:52.51629+03'),
(56, '2024-03-26 06:41:35.078091+03', 1071, 'TUBA', 1, NULL, NULL, '1071438891921', '', 'Noah Ochomo', 1071, NULL, '2024-04-09 06:46:52.51629+03'),
(57, '2024-03-26 06:41:35.078091+03', 1071, 'WOOD BLOCK', 12, NULL, NULL, '1071438891921', '', 'Noah Ochomo', 1071, NULL, '2024-04-09 06:46:52.51629+03'),
(72, '2024-03-26 06:49:38.327606+03', 1071, 'BASSOON', 1, NULL, NULL, '1071470254811', 'None whatsoever', 'Noah Ochomo', 1071, NULL, '2024-04-09 07:38:27.446676+03'),
(81, '2024-03-26 06:51:26.47596+03', 1071, 'MELLOPHONE', 1, NULL, NULL, '1071752994307', 'Just trying this out', 'Noah Ochomo', 1071, NULL, '2024-04-09 07:46:33.445574+03'),
(71, '2024-03-26 06:49:21.613348+03', 1071, 'BASSOON', 1, 'Pending', 'Yes', '1071742081697', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1798}', '2024-04-19 12:38:56.960054+03'),
(63, '2024-03-26 06:42:49.866508+03', 1071, 'TAMBOURINE, 10 INCH', 4, NULL, NULL, '107151156448', 'None whatsoever', 'Noah Ochomo', 1071, '{1943}', '2024-04-21 16:27:24.088335+03'),
(64, '2024-03-26 06:42:49.866508+03', 1071, 'GUITAR, ACOUSTIC', 3, NULL, NULL, '107151156448', 'None whatsoever', 'Noah Ochomo', 1071, '{1676,1675}', '2024-04-21 16:27:24.088335+03'),
(65, '2024-03-26 06:42:49.866508+03', 1071, 'BELLS, TUBULAR', 1, NULL, NULL, '107151156448', 'None whatsoever', 'Noah Ochomo', 1071, NULL, '2024-04-21 16:27:24.088335+03'),
(67, '2024-03-26 06:43:04.384032+03', 1071, 'GUITAR, ACOUSTIC', 1, NULL, NULL, '1071292403354', 'None whatsoever', 'Noah Ochomo', 1071, NULL, '2024-04-21 16:29:23.74188+03'),
(66, '2024-03-26 06:43:04.384032+03', 1071, 'CLARINET, ALTO IN E FLAT', 1, NULL, NULL, '1071292403354', 'None whatsoever', 'Noah Ochomo', 1071, NULL, '2024-04-21 16:29:23.74188+03'),
(80, '2024-03-26 06:51:18.639686+03', 1071, 'CONGA', 1, 'Resolved', 'Yes', '1071435734281', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1818}', '2024-05-06 13:27:42.2568+03'),
(78, '2024-03-26 06:50:43.40365+03', 1071, 'COWBELL', 1, NULL, NULL, '1071742084060', 'No particular reason', 'Noah Ochomo', 1071, '{1971}', '2024-05-06 13:28:13.292782+03'),
(79, '2024-03-26 06:50:43.40365+03', 1071, 'CASTANETS', 1, NULL, NULL, '1071742084060', 'No particular reason', 'Noah Ochomo', 1071, '{1925}', '2024-05-06 13:28:13.292782+03'),
(68, '2024-03-26 06:49:06.726904+03', 1071, 'CASTANETS', 1, '', '', '1071500878904', '', 'Noah Ochomo', 1071, '{1925}', '2024-04-19 11:09:40.947135+03'),
(69, '2024-03-26 06:49:06.726904+03', 1071, 'COWBELL', 2, '', '', '1071500878904', '', 'Noah Ochomo', 1071, '{1971}', '2024-04-19 11:09:40.947135+03'),
(75, '2024-03-26 06:50:32.054348+03', 1071, 'TRUMPET, B FLAT', 4, 'Resolved', 'Partial', '1071778108781', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1856}', '2024-05-06 13:34:23.476552+03'),
(76, '2024-03-26 06:50:32.054348+03', 1071, 'SAXOPHONE, ALTO', 4, 'Resolved', 'Partial', '1071778108781', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, NULL, '2024-05-06 13:34:23.476552+03'),
(77, '2024-03-26 06:50:32.054348+03', 1071, 'FLUTE', 31, 'Resolved', 'Partial', '1071778108781', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1577,1665}', '2024-05-06 13:34:23.476552+03'),
(82, '2024-03-26 06:55:00.651911+03', 1071, 'CONGA', 1, 'Resolved', 'Partial', '1071450394256', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1873}', '2024-05-06 13:41:25.122106+03') ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: insert or update on table "instrument_requests" violates foreign key constraint "requests_attended_by_id_fkey"
DETAIL: Key (attended_by_id)=(1071) is not present in table "users".
Command was: INSERT INTO public.instrument_requests VALUES
(70, '2024-03-26 06:49:21.613348+03', 1071, 'WIND CHIMES', 1, 'Pending', 'Yes', '1071742081697', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{2016}', '2024-04-19 12:38:56.960054+03'),
(83, '2024-03-26 06:55:00.651911+03', 1071, 'TRUMPET, B FLAT', 5, 'Resolved', 'Partial', '1071450394256', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1496}', '2024-05-06 13:41:25.122106+03'),
(73, '2024-03-26 06:49:55.459052+03', 1071, 'MICROPHONE', 6, 'Pending', 'Partial', '1071195789690', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1582,1954}', '2024-04-19 12:32:41.154093+03'),
(74, '2024-03-26 06:49:55.459052+03', 1071, 'AMPLIFIER', 1, 'Pending', 'Partial', '1071195789690', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1926}', '2024-04-19 12:32:41.154093+03'),
(58, '2024-03-26 06:41:47.15963+03', 1071, 'DUMMY 1', 4, 'Resolved', 'Partial', '1071697457668', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{4164,4165,2129}', '2024-04-21 16:13:35.958068+03'),
(59, '2024-03-26 06:42:00.542338+03', 1071, 'PIANO, ELECTRIC', 1, 'Resolved', 'Yes', '1071200919025', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{2091}', '2024-04-21 16:18:39.919911+03'),
(60, '2024-03-26 06:42:00.542338+03', 1071, 'VIBRASLAP', 1, 'Resolved', 'Yes', '1071200919025', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1928}', '2024-04-21 16:18:39.919911+03'),
(61, '2024-03-26 06:42:15.759578+03', 1071, 'TOM, MARCHING', 1, 'Resolved', 'Partial', '1071353939397', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{2014}', '2024-04-21 16:26:10.819915+03'),
(62, '2024-03-26 06:42:15.759578+03', 1071, 'TALKING DRUM', 3, 'Resolved', 'Partial', '1071353939397', 'We do not have enough instruments to service your request at this time', 'Noah Ochomo', 1071, '{1615}', '2024-04-21 16:26:10.819915+03') ON CONFLICT DO NOTHING;








-- INSERT INTO public.returns VALUES
-- (6, '2024-01-31', 2129, NULL, NULL, NULL),
-- (8, '2024-01-31', 2129, NULL, NULL, NULL),
-- (9, '2024-01-31', 2129, NULL, NULL, NULL),
-- (11, '2024-01-31', 2129, NULL, NULL, NULL),
-- (12, '2024-01-31', 1494, NULL, NULL, NULL),
-- (13, '2024-01-31', 1494, NULL, NULL, NULL),
-- (14, '2024-02-01', 2129, NULL, NULL, NULL),
-- (15, '2024-02-01', 2129, 'postgres', NULL, NULL),
-- (16, '2024-02-01', 1731, 'postgres', NULL, NULL),
-- (17, '2024-02-01', 1768, 'postgres', NULL, NULL),
-- (18, '2024-02-01', 2072, 'postgres', NULL, NULL),
-- (19, '2024-02-01', 1595, 'postgres', NULL, NULL),
-- (20, '2024-02-01', 1618, 'postgres', NULL, NULL),
-- (21, '2024-02-01', 2072, 'postgres', NULL, NULL),
-- (22, '2024-02-01', 2072, 'postgres', NULL, NULL),
-- (23, '2024-02-01', 1768, 'postgres', NULL, NULL),
-- (24, '2024-02-01', 1618, 'postgres', NULL, NULL),
-- (25, '2024-02-01', 1731, 'postgres', NULL, NULL),
-- (26, '2024-02-01', 1595, 'postgres', NULL, NULL),
-- (27, '2024-02-15', 4166, 'nochomo', NULL, NULL) ON CONFLICT DO NOTHING;
-- pg_restore: error: could not execute query: ERROR: relation "users" does not exist
-- LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
-- ^
-- QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
-- CONTEXT: PL/pgSQL function public.return() line 4 at IF
-- Command was: INSERT INTO public.returns VALUES
-- (29, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (30, '2024-02-23', 2129, 'postgres', NULL, NULL),
-- (31, '2024-02-23', 2129, 'postgres', NULL, NULL),
-- (32, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (33, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (34, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (35, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (36, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (37, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (38, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (39, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (40, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (41, '2024-02-23', 4166, 'postgres', NULL, NULL),
-- (42, '2024-02-23', 4166, 'nochomo', NULL, NULL),
-- (43, '2024-02-23', 4166, 'nochomo', NULL, NULL),
-- (44, '2024-02-23', 4166, 'nochomo', NULL, NULL),
-- (45, '2024-02-23', 4166, 'nochomo', NULL, NULL),
-- (46, '2024-02-25', 4166, 'nochomo', NULL, NULL),
-- (47, '2024-02-25', 4166, 'nochomo', NULL, NULL),
-- (48, '2024-02-25', 4166, 'nochomo', NULL, NULL) ON CONFLICT DO NOTHING;
-- pg_restore: error: could not execute query: ERROR: relation "users" does not exist
-- LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
-- ^
-- QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
-- CONTEXT: PL/pgSQL function public.return() line 4 at IF
-- Command was: 
INSERT INTO public.returns VALUES
(49, '2024-02-25', 4166, 'nochomo', NULL, NULL),
(50, '2024-02-25', 4166, 'nochomo', NULL, NULL),
(51, '2024-02-25', 4166, 'nochomo', NULL, NULL),
(61, '2024-02-28', 4166, 'nochomo', NULL, NULL),
(62, '2024-02-28', 4166, 'nochomo', NULL, NULL),
(63, '2024-02-28', 4166, 'nochomo', NULL, NULL),
(64, '2024-03-01', 4166, 'nochomo', NULL, NULL),
(65, '2024-03-01', 4166, 'nochomo', NULL, NULL),
(66, '2024-03-01', 4166, 'nochomo', NULL, NULL),
(67, '2024-03-01', 4166, 'nochomo', NULL, NULL),
(68, '2024-03-01', 4166, 'nochomo', NULL, NULL),
(69, '2024-03-02', 4166, 'nochomo', NULL, NULL),
(70, '2024-03-03', 4166, 'nochomo', NULL, NULL),
(71, '2024-03-03', 4166, 'nochomo', NULL, NULL),
(72, '2024-03-03', 2129, 'nochomo', NULL, NULL),
(73, '2024-03-03', 4164, 'nochomo', NULL, NULL),
(74, '2024-03-03', 4165, 'nochomo', NULL, NULL),
(75, '2024-03-03', 4166, 'nochomo', NULL, NULL),
(76, '2024-03-03', 1757, 'nochomo', NULL, NULL),
(77, '2024-03-03', 1566, 'nochomo', NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(78, '2024-03-03', 2098, 'nochomo', NULL, NULL),
(79, '2024-03-04', 4164, 'nochomo', NULL, NULL),
(80, '2024-03-04', 4163, 'nochomo', NULL, NULL),
(81, '2024-03-04', 4164, 'nochomo', NULL, NULL),
(82, '2024-03-04', 4166, 'nochomo', NULL, NULL),
(83, '2024-03-04', 4165, 'nochomo', NULL, NULL),
(84, '2024-03-04', 4164, 'nochomo', NULL, NULL),
(85, '2024-03-04', 4166, 'nochomo', NULL, NULL),
(86, '2024-03-04', 4163, 'nochomo', NULL, NULL),
(87, '2024-03-04', 4165, 'nochomo', NULL, NULL),
(88, '2024-03-04', 4166, 'nochomo', NULL, NULL),
(89, '2024-03-04', 4163, 'nochomo', NULL, NULL),
(90, '2024-03-04', 2129, 'nochomo', NULL, NULL),
(91, '2024-03-06', 4166, 'nochomo', NULL, NULL),
(92, '2024-03-06', 4166, 'nochomo', NULL, NULL),
(93, '2024-03-06', 4166, 'nochomo', NULL, NULL),
(95, '2024-03-07', 4165, 'nochomo', NULL, NULL),
(96, '2024-03-07', 4166, 'nochomo', NULL, NULL),
(97, '2024-03-07', 4166, 'nochomo', NULL, NULL),
(98, '2024-03-07', 4165, 'nochomo', NULL, NULL) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(103, '2024-03-17', 4166, 'nochomo', 1071, NULL),
(104, '2024-03-17', 4165, 'nochomo', 1071, NULL),
(105, '2024-03-17', 4166, 'nochomo', 1071, NULL),
(106, '2024-03-17', 4165, 'nochomo', 1071, NULL),
(107, '2024-03-18', 4164, 'nochomo', 1071, NULL),
(108, '2024-03-19', 4163, 'nochomo', 1071, NULL),
(109, '2024-03-20', 4166, 'nochomo', 1071, NULL),
(110, '2024-03-20', 4163, 'nochomo', 1071, NULL),
(111, '2024-03-20', 2129, 'nochomo', 1071, NULL),
(112, '2024-03-20', 2129, 'nochomo', 1071, 1074),
(114, '2024-03-20', 4166, 'nochomo', 1071, 1072),
(115, '2024-03-21', 4164, 'nochomo', 1071, 1074),
(116, '2024-03-22', 4163, 'nochomo', 1071, 1072),
(117, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(118, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(119, '2024-03-23', 1999, 'nochomo', 1071, 1071),
(120, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(121, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(122, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(123, '2024-03-23', 4209, 'nochomo', 1071, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(124, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(125, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(126, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(127, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(128, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(129, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(130, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(131, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(132, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(133, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(134, '2024-03-23', 1999, 'nochomo', 1071, 1071),
(135, '2024-03-23', 4208, 'nochomo', 1071, 1071),
(136, '2024-03-23', 4209, 'nochomo', 1071, 1071),
(137, '2024-03-23', 1999, 'nochomo', 1071, 1071),
(138, '2024-03-23', 1999, 'nochomo', 1071, 1071),
(139, '2024-03-23', 1999, 'nochomo', 1071, 1071),
(140, '2024-04-19', 1925, 'nochomo', 1071, 1071),
(141, '2024-04-19', 1971, 'nochomo', 1071, 1071),
(142, '2024-04-19', 4164, 'nochomo', 1071, 1071),
(143, '2024-04-19', 4165, 'nochomo', 1071, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(144, '2024-04-19', 4208, 'nochomo', 1071, 1071),
(145, '2024-04-19', 4209, 'nochomo', 1071, 1071),
(146, '2024-04-19', 1676, 'nochomo', 1071, 1071),
(147, '2024-04-19', 1928, 'nochomo', 1071, 1071),
(148, '2024-04-19', 4165, 'nochomo', 1071, 1071),
(149, '2024-04-19', 4164, 'nochomo', 1071, 1071),
(150, '2024-04-19', 2129, 'nochomo', 1071, 1071),
(151, '2024-04-19', 1818, 'nochomo', 1071, 1071),
(152, '2024-04-19', 1926, 'nochomo', 1071, 1071),
(153, '2024-04-19', 1798, 'nochomo', 1071, 1071),
(154, '2024-04-19', 1925, 'nochomo', 1071, 1071),
(155, '2024-04-19', 1971, 'nochomo', 1071, 1071),
(156, '2024-04-19', 4164, 'nochomo', 1071, 1071),
(157, '2024-04-19', 4166, 'nochomo', 1071, 1071),
(158, '2024-04-19', 1665, 'nochomo', 1071, 1071),
(159, '2024-04-19', 1577, 'nochomo', 1071, 1071),
(160, '2024-04-19', 1675, 'nochomo', 1071, 1071),
(161, '2024-04-19', 1676, 'nochomo', 1071, 1071),
(162, '2024-04-19', 1954, 'nochomo', 1071, 1071),
(163, '2024-04-19', 1582, 'nochomo', 1071, 1071) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(164, '2024-04-19', 2034, 'nochomo', 1071, 1071),
(165, '2024-04-19', 1615, 'nochomo', 1071, 1071),
(166, '2024-04-19', 1943, 'nochomo', 1071, 1071),
(167, '2024-04-19', 2014, 'nochomo', 1071, 1071),
(168, '2024-04-19', 1545, 'nochomo', 1071, 1071),
(169, '2024-04-19', 1928, 'nochomo', 1071, 1071),
(170, '2024-04-19', 2016, 'nochomo', 1071, 1071),
(171, '2024-04-21', 2129, 'nochomo', 1071, 1071),
(172, '2024-05-06', 2047, 'nochomo', 1071, 947),
(173, '2024-05-06', 2047, 'nochomo', 1071, 947),
(174, '2024-05-06', 4164, 'nochomo', 1071, 1071),
(175, '2024-05-06', 4165, 'nochomo', 1071, 1071),
(176, '2024-05-06', 1615, 'nochomo', 1071, 1071),
(177, '2024-05-06', 2014, 'nochomo', 1071, 1071),
(178, '2024-05-06', 2091, 'nochomo', 1071, 1071),
(179, '2024-05-06', 4165, 'nochomo', 1071, 1071),
(180, '2024-05-06', 1928, 'nochomo', 1071, 1071),
(181, '2024-05-29', 2093, 'nochomo', 1071, 954),
(182, '2024-05-29', 2095, 'nochomo', 1071, 955),
(183, '2024-05-29', 2093, 'nochomo', 1071, 954) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(184, '2024-05-29', 1848, 'nochomo', 1071, 115),
(185, '2024-05-29', 1710, 'nochomo', 1071, 481),
(186, '2024-05-29', 2122, 'nochomo', 1071, 114),
(187, '2024-05-29', 2041, 'nochomo', 1071, 240),
(188, '2024-05-29', 1698, 'nochomo', 1071, 601),
(189, '2024-05-29', 1744, 'nochomo', 1071, 300),
(190, '2024-05-30', 1790, 'nochomo', 1071, 662),
(191, '2024-05-30', 1699, 'nochomo', 1071, 482),
(192, '2024-05-30', 1993, 'nochomo', 1071, 361),
(193, '2024-05-30', 1703, 'nochomo', 1071, 911),
(194, '2024-05-30', 2111, 'nochomo', 1071, 117),
(195, '2024-05-30', 1819, 'nochomo', 1071, 179),
(196, '2024-05-30', 1701, 'nochomo', 1071, 962),
(197, '2024-05-30', 2109, 'nochomo', 1071, 302),
(198, '2024-05-30', 1700, 'nochomo', 1071, 959),
(199, '2024-05-30', 1700, 'nochomo', 1071, 959),
(200, '2024-05-30', 2112, 'nochomo', 1071, 961),
(201, '2024-05-30', 1756, 'nochomo', 1071, 979),
(202, '2024-05-30', 1746, 'nochomo', 1071, 358),
(203, '2024-05-30', 1787, 'nochomo', 1071, 299) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(204, '2024-05-30', 2110, 'nochomo', 1071, 356),
(205, '2024-05-30', 2047, 'nochomo', 1071, 947),
(206, '2024-05-30', 2097, 'nochomo', 1071, 788),
(207, '2024-05-30', 2055, 'nochomo', 1071, 357),
(208, '2024-05-30', 2107, 'nochomo', 1071, 59),
(209, '2024-05-30', 1918, 'nochomo', 1071, 973),
(210, '2024-05-31', 1785, 'nochomo', 1071, 927),
(211, '2024-05-31', 1718, 'nochomo', 1071, 976),
(212, '2024-05-31', 1740, 'nochomo', 1071, 975),
(213, '2024-05-31', 2114, 'nochomo', 1071, 977),
(214, '2024-05-31', 2101, 'nochomo', 1071, 934),
(215, '2024-05-31', 2100, 'nochomo', 1071, 239),
(216, '2024-05-31', 1733, 'nochomo', 1071, 933),
(217, '2024-05-31', 1674, 'nochomo', 1071, 240),
(218, '2024-05-31', 1996, 'nochomo', 1071, 941),
(219, '2024-05-31', 1715, 'nochomo', 1071, 925),
(220, '2024-05-31', 2115, 'nochomo', 1071, 926),
(221, '2024-05-31', 2060, 'nochomo', 1071, 176),
(222, '2024-05-31', 1900, 'nochomo', 1071, 928),
(223, '2024-05-31', 1861, 'nochomo', 1071, 480) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(224, '2024-05-31', 2053, 'nochomo', 1071, 944),
(225, '2024-05-31', 1716, 'nochomo', 1071, 539),
(226, '2024-05-31', 2115, 'nochomo', 1071, 926),
(227, '2024-05-31', 2115, 'nochomo', 1071, 926),
(228, '2024-05-31', 2115, 'nochomo', 1071, 926),
(229, '2024-06-03', 2006, 'nochomo', 1071, 932),
(230, '2024-06-03', 2040, 'nochomo', 1071, 602),
(231, '2024-06-03', 2115, 'nochomo', 1071, 926),
(232, '2024-06-03', 2115, 'nochomo', 1071, 926),
(233, '2024-06-03', 1806, 'nochomo', 1071, 935),
(234, '2024-06-03', 1754, 'nochomo', 1071, 942),
(235, '2024-06-03', 1714, 'nochomo', 1071, 981),
(236, '2024-06-03', 1704, 'nochomo', 1071, 945),
(237, '2024-06-03', 1531, 'nochomo', 1071, 984),
(238, '2024-06-03', 1876, 'nochomo', 1071, 958),
(239, '2024-06-03', 2045, 'nochomo', 1071, 940),
(240, '2024-06-03', 1712, 'nochomo', 1071, 659),
(241, '2024-06-03', 1878, 'nochomo', 1071, 956),
(242, '2024-06-03', 1880, 'nochomo', 1071, 931),
(243, '2024-06-03', 2120, 'nochomo', 1071, 538) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(244, '2024-06-03', 1716, 'nochomo', 1071, 539),
(245, '2024-06-03', 1716, 'nochomo', 1071, 539),
(246, '2024-06-03', 2067, 'nochomo', 1071, 360),
(247, '2024-06-03', 1702, 'nochomo', 1071, 980),
(248, '2024-06-03', 1755, 'nochomo', 1071, 929),
(249, '2024-06-04', 1924, 'nochomo', 1071, 952),
(250, '2024-06-04', 2046, 'nochomo', 1071, 967),
(251, '2024-06-04', 1738, 'nochomo', 1071, 960),
(252, '2024-06-04', 2099, 'nochomo', 1071, 1070),
(253, '2024-06-04', 2074, 'nochomo', 1071, 359),
(254, '2024-06-04', 1995, 'nochomo', 1071, 847),
(255, '2024-06-04', 2105, 'nochomo', 1071, 846),
(256, '2024-06-04', 2050, 'nochomo', 1071, 953),
(257, '2024-06-04', 2105, 'nochomo', 1071, 846),
(258, '2024-06-04', 2105, 'nochomo', 1071, 846),
(259, '2024-06-04', 2050, 'nochomo', 1071, 953),
(260, '2024-06-04', 2057, 'nochomo', 1071, 974),
(261, '2024-06-04', 1806, 'nochomo', 1071, 929),
(262, '2024-06-04', 1738, 'nochomo', 1071, 960),
(263, '2024-06-04', 1900, 'nochomo', 1071, 928) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(264, '2024-06-04', 2060, 'nochomo', 1071, 176),
(265, '2024-06-04', 2115, 'nochomo', 1071, 926),
(266, '2024-06-04', 1522, 'nochomo', 1071, 935),
(267, '2024-06-04', 2102, 'nochomo', 1071, 935),
(268, '2024-06-04', 2116, 'nochomo', 1071, 942),
(269, '2024-06-04', 1714, 'nochomo', 1071, 981),
(270, '2024-06-04', 1704, 'nochomo', 1071, 945),
(271, '2024-06-04', 1531, 'nochomo', 1071, 984),
(272, '2024-06-04', 1756, 'nochomo', 1071, 979),
(273, '2024-06-04', 2105, 'nochomo', 1071, 846),
(274, '2024-06-04', 2105, 'nochomo', 1071, 846),
(275, '2024-06-04', 2105, 'nochomo', 1071, 846),
(276, '2024-06-04', 2105, 'nochomo', 1071, 846),
(277, '2024-06-04', 2105, 'nochomo', 1071, 846),
(278, '2024-06-04', 2105, 'nochomo', 1071, 846),
(279, '2024-06-04', 2105, 'nochomo', 1071, 846),
(280, '2024-06-04', 2105, 'nochomo', 1071, 846),
(281, '2024-06-04', 2105, 'nochomo', 1071, 846),
(282, '2024-06-04', 1861, 'nochomo', 1071, 480),
(283, '2024-06-04', 2057, 'nochomo', 1071, 974) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(284, '2024-06-04', 1833, 'nochomo', 1071, 960),
(285, '2024-06-04', 1756, 'nochomo', 1071, 979),
(286, '2024-06-04', 1704, 'nochomo', 1071, 945),
(287, '2024-06-04', 1754, 'nochomo', 1071, 980),
(288, '2024-06-04', 1714, 'nochomo', 1071, 981),
(289, '2024-06-04', 1900, 'nochomo', 1071, 928),
(290, '2024-06-04', 2060, 'nochomo', 1071, 176),
(291, '2024-06-04', 1522, 'nochomo', 1071, 935),
(292, '2024-06-04', 1806, 'nochomo', 1071, 929),
(293, '2024-06-04', 1531, 'nochomo', 1071, 984),
(294, '2024-06-04', 1531, 'nochomo', 1071, 984),
(295, '2024-06-04', 2105, 'nochomo', 1071, 846),
(296, '2024-06-04', 2116, 'nochomo', 1071, 942),
(297, '2024-06-04', 2115, 'nochomo', 1071, 926),
(298, '2024-06-04', 2050, 'nochomo', 1071, 953),
(299, '2024-06-04', 1806, 'nochomo', 1071, 929),
(300, '2024-06-04', 1598, 'kwando', 1082, 1075),
(301, '2024-06-04', 2063, 'kwando', 1082, 541),
(302, '2024-06-04', 1550, 'kwando', 1082, 1075),
(303, '2024-06-05', 1902, 'kwando', 1082, 948) ON CONFLICT DO NOTHING;
pg_restore: error: could not execute query: ERROR: relation "users" does not exist
LINE 1: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
^
QUERY: (SELECT room FROM users WHERE id = NEW.user_id) IS NOT NULL
CONTEXT: PL/pgSQL function public.return() line 4 at IF
Command was: INSERT INTO public.returns VALUES
(304, '2024-06-07', 1906, 'kwando', 1082, 1071),
(305, '2024-06-07', 1818, 'kwando', 1082, 1071),
(306, '2024-06-07', 1873, 'kwando', 1082, 1071),
(307, '2024-06-07', 1856, 'kwando', 1082, 1071),
(308, '2024-06-07', 1496, 'kwando', 1082, 1071) ON CONFLICT DO NOTHING;
pg_restore: processing data for table "public.roles"
pg_restore: processing data for table "public.students"
pg_restore: processing data for table "public.users"
pg_restore: executing SEQUENCE SET all_instruments_id_seq
pg_restore: executing SEQUENCE SET class_id_seq
pg_restore: executing SEQUENCE SET dispatches_id_seq
pg_restore: executing SEQUENCE SET duplicate_instruments_id_seq
pg_restore: executing SEQUENCE SET hardware_and_equipment_id_seq
pg_restore: executing SEQUENCE SET instrument_conditions_id_seq
pg_restore: executing SEQUENCE SET instrument_history_id_seq
pg_restore: executing SEQUENCE SET instrument_requests_id_seq
pg_restore: executing SEQUENCE SET instruments_id_seq
pg_restore: executing SEQUENCE SET legacy_database_id_seq
pg_restore: executing SEQUENCE SET locations_id_seq
pg_restore: executing SEQUENCE SET lost_and_found_id_seq
pg_restore: executing SEQUENCE SET music_instruments_id_seq
pg_restore: executing SEQUENCE SET new_instrument_id_seq
pg_restore: executing SEQUENCE SET repairs_id_seq
pg_restore: executing SEQUENCE SET resolve_id_seq
pg_restore: executing SEQUENCE SET returns_id_seq
pg_restore: executing SEQUENCE SET roles_id_seq
pg_restore: executing SEQUENCE SET students_id_seq
pg_restore: executing SEQUENCE SET users_id_seq
pg_restore: warning: errors ignored on restore: 85
Failed (exit code: 1).
Execution time: 0.29 seconds