
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE `sample` (
  `row_id` int PRIMARY KEY,
  `sample_id` int NOT NULL,
  `project_id` smallint NOT NULL DEFAULT '0',
  `ssid` mediumint unsigned DEFAULT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(40) NOT NULL DEFAULT '',
  `individual_id` int unsigned DEFAULT NULL,
  `note_id` mediumint unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `latest` tinyint DEFAULT '0'
);
INSERT INTO "sample" VALUES(1,1,0,NULL,'test2_1','test2_1',NULL,NULL,'2014-03-12 11:30:26',0);
INSERT INTO "sample" VALUES(2,1,2,NULL,'test2_1','test2_1',NULL,NULL,'2014-03-12 11:30:26',0);
INSERT INTO "sample" VALUES(3,3,0,NULL,'test1_1','test1_1',NULL,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "sample" VALUES(4,3,4,NULL,'test1_1','test1_1',NULL,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "sample" VALUES(5,3,4,1,'test1_1','test1_1',2,NULL,'2014-03-12 11:30:27',1);
INSERT INTO "sample" VALUES(6,1,2,1,'test2_1','test2_1',1,NULL,'2014-03-12 11:30:27',1);
INSERT INTO "sample" VALUES(7,7,0,NULL,'test1_2','test1_2',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(8,7,4,NULL,'test1_2','test1_2',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(9,9,0,NULL,'test2_2','test2_2',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(10,9,2,NULL,'test2_2','test2_2',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(11,7,4,2,'test1_2','test1_2',3,NULL,'2014-03-12 11:30:31',1);
INSERT INTO "sample" VALUES(12,9,2,2,'test2_2','test2_2',4,NULL,'2014-03-12 11:30:31',1);
INSERT INTO "sample" VALUES(13,13,0,NULL,'test1_3','test1_3',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(14,13,4,NULL,'test1_3','test1_3',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(15,13,4,3,'test1_3','test1_3',5,NULL,'2014-03-12 11:30:31',1);
INSERT INTO "sample" VALUES(16,16,0,NULL,'test2_3','test2_3',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(17,16,2,NULL,'test2_3','test2_3',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(18,16,2,3,'test2_3','test2_3',6,NULL,'2014-03-12 11:30:31',1);
INSERT INTO "sample" VALUES(19,19,0,NULL,'test1_4','test1_4',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(20,19,4,NULL,'test1_4','test1_4',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(21,19,4,4,'test1_4','test1_4',7,NULL,'2014-03-12 11:30:31',1);
INSERT INTO "sample" VALUES(22,22,0,NULL,'test2_4','test2_4',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(23,22,2,NULL,'test2_4','test2_4',NULL,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "sample" VALUES(24,22,2,4,'test2_4','test2_4',8,NULL,'2014-03-12 11:30:31',1);
INSERT INTO "sample" VALUES(25,25,0,NULL,'PB_Mtuberculosis','PB_Mtuberculosis',NULL,NULL,'2014-04-29 11:11:23',0);
INSERT INTO "sample" VALUES(26,25,6,NULL,'PB_Mtuberculosis','PB_Mtuberculosis',NULL,NULL,'2014-04-29 11:11:23',0);
INSERT INTO "sample" VALUES(27,25,6,1680184,'PB_Mtuberculosis','PB_Mtuberculosis',9,NULL,'2014-04-29 11:11:23',1);
CREATE TABLE `lane` (
  `row_id` int unsigned NOT NULL PRIMARY KEY,
  `lane_id` int unsigned NOT NULL,
  `library_id` int unsigned NOT NULL,
  `seq_request_id` mediumint unsigned NOT NULL DEFAULT '0',
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `acc` varchar(40) DEFAULT NULL,
  `readlen` smallint unsigned DEFAULT NULL,
  `paired` tinyint DEFAULT NULL,
  `raw_reads` bigint unsigned DEFAULT NULL,
  `raw_bases` bigint unsigned DEFAULT NULL,
  `npg_qc_status` varchar(255) DEFAULT 'pending',
  `processed` int DEFAULT '0',
  `auto_qc_status` varchar(255) DEFAULT 'no_qc',
  `qc_status` varchar(255) DEFAULT 'no_qc',
  `gt_status` varchar(255) DEFAULT 'unchecked',
  `submission_id` smallint unsigned DEFAULT NULL,
  `withdrawn` tinyint DEFAULT NULL,
  `note_id` mediumint unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `run_date` datetime DEFAULT NULL,
  `storage_path` varchar(255) DEFAULT NULL,
  `latest` tinyint DEFAULT '0',
  `manually_withdrawn` tinyint DEFAULT NULL
);
INSERT INTO "lane" VALUES(1,1,0,0,'5477_6#1','5477_6_1',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(2,2,0,0,'6578_4#1','6578_4_1',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(3,1,1,0,'5477_6#1','5477_6_1',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(4,2,2,0,'6578_4#1','6578_4_1',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(5,1,1,0,'5477_6#1','5477_6#1',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(6,2,2,0,'6578_4#1','6578_4#1',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(7,7,0,0,'5477_6#2','5477_6_2',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(8,7,9,0,'5477_6#2','5477_6_2',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(9,9,0,0,'6578_4#2','6578_4_2',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(10,7,9,0,'5477_6#2','5477_6#2',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(11,9,11,0,'6578_4#2','6578_4_2',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(12,9,11,0,'6578_4#2','6578_4#2',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(13,13,0,0,'5477_6#3','5477_6_3',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(14,13,17,0,'5477_6#3','5477_6_3',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(15,15,0,0,'6578_4#3','6578_4_3',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(16,13,17,0,'5477_6#3','5477_6#3',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(17,15,18,0,'6578_4#3','6578_4_3',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(18,15,18,0,'6578_4#3','6578_4#3',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(19,19,0,0,'5477_6#4','5477_6_4',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(20,19,25,0,'5477_6#4','5477_6_4',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(21,19,25,0,'5477_6#4','5477_6#4',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(22,22,0,0,'6578_4#4','6578_4_4',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','passed','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(23,22,29,0,'6578_4#4','6578_4_4',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(24,22,29,0,'6578_4#4','6578_4#4',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:30:31',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(25,13,17,0,'5477_6#3','5477_6#3',NULL,76,1,9656422,733888072,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:34:00',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(26,19,25,0,'5477_6#4','5477_6#4',NULL,76,1,7803096,593035296,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:34:04',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(27,1,1,0,'5477_6#1','5477_6#1',NULL,76,1,7067462,537127112,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:34:05',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(28,7,9,0,'5477_6#2','5477_6#2',NULL,76,1,7108898,540276248,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:34:06',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(29,15,18,0,'6578_4#3','6578_4#3',NULL,75,1,4872748,365456100,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:35:49',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(30,9,11,0,'6578_4#2','6578_4#2',NULL,75,1,8286578,621493350,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:35:59',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(31,2,2,0,'6578_4#1','6578_4#1',NULL,75,1,9208112,690608400,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:35:59',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(32,22,29,0,'6578_4#4','6578_4#4',NULL,75,1,10409566,780717450,'-',1,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:36:03',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(33,22,29,0,'6578_4#4','6578_4#4',NULL,75,1,10409566,780717450,'-',513,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 11:36:03',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(34,1,1,0,'5477_6#1','5477_6#1',NULL,76,1,7067462,537127112,'-',1,'passed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:06',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(35,1,1,0,'5477_6#1','5477_6#1',NULL,76,1,7067462,537127112,'-',3,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:07',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(36,7,9,0,'5477_6#2','5477_6#2',NULL,76,1,7108898,540276248,'-',1,'failed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:07',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(37,7,9,0,'5477_6#2','5477_6#2',NULL,76,1,7108898,540276248,'-',3,'failed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:08',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(38,13,17,0,'5477_6#3','5477_6#3',NULL,76,1,9656422,733888072,'-',1,'passed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:08',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(39,13,17,0,'5477_6#3','5477_6#3',NULL,76,1,9656422,733888072,'-',3,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:08',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(40,19,25,0,'5477_6#4','5477_6#4',NULL,76,1,7803096,593035296,'-',1,'passed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:09',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(41,19,25,0,'5477_6#4','5477_6#4',NULL,76,1,7803096,593035296,'-',3,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:30:09',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(42,7,9,0,'5477_6#2','5477_6#2',NULL,76,1,7108898,540276248,'-',11,'failed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:56:31',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/7/4/9/5477_6#2',0,NULL);
INSERT INTO "lane" VALUES(43,1,1,0,'5477_6#1','5477_6#1',NULL,76,1,7067462,537127112,'-',11,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:56:35',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/1/f/f/5477_6#1',0,NULL);
INSERT INTO "lane" VALUES(44,19,25,0,'5477_6#4','5477_6#4',NULL,76,1,7803096,593035296,'-',11,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:56:49',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/c/6/f/5477_6#4',0,NULL);
INSERT INTO "lane" VALUES(45,13,17,0,'5477_6#3','5477_6#3',NULL,76,1,9656422,733888072,'-',11,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 18:56:53',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/a/2/8/e/5477_6#3',0,NULL);
INSERT INTO "lane" VALUES(46,2,2,0,'6578_4#1','6578_4#1',NULL,75,1,9208112,690608400,'-',1,'failed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 19:30:06',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(47,2,2,0,'6578_4#1','6578_4#1',NULL,75,1,9208112,690608400,'-',3,'failed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 19:30:06',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(48,9,11,0,'6578_4#2','6578_4#2',NULL,75,1,8286578,621493350,'-',1,'passed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 19:30:07',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(49,9,11,0,'6578_4#2','6578_4#2',NULL,75,1,8286578,621493350,'-',3,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 19:30:07',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(50,15,18,0,'6578_4#3','6578_4#3',NULL,75,1,4872748,365456100,'-',1,'passed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-12 19:30:08',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(51,15,18,0,'6578_4#3','6578_4#3',NULL,75,1,4872748,365456100,'-',3,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 19:30:08',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(52,2,2,0,'6578_4#1','6578_4#1',NULL,75,1,9208112,690608400,'-',11,'failed','passed','unchecked',NULL,NULL,NULL,'2014-03-12 19:56:45',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/8/4/b/6578_4#1',0,NULL);
INSERT INTO "lane" VALUES(53,15,18,0,'6578_4#3','6578_4#3',NULL,75,1,4872748,365456100,'-',1035,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 19:56:55',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/8/9/8/6578_4#3',0,NULL);
INSERT INTO "lane" VALUES(54,9,11,0,'6578_4#2','6578_4#2',NULL,75,1,8286578,621493350,'-',1035,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-12 19:57:15',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/7/9/0/6578_4#2',0,NULL);
INSERT INTO "lane" VALUES(55,22,29,0,'6578_4#4','6578_4#4',NULL,75,1,10409566,780717450,'-',513,'passed','no_qc','unchecked',NULL,NULL,NULL,'2014-03-14 11:30:06',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(56,22,29,0,'6578_4#4','6578_4#4',NULL,75,1,10409566,780717450,'-',515,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-14 11:30:08',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(57,22,29,0,'6578_4#4','6578_4#4',NULL,75,1,10409566,780717450,'-',523,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-14 13:36:45',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/a/7/0/8/6578_4#4',0,NULL);
INSERT INTO "lane" VALUES(58,13,17,0,'5477_6#3','5477_6#3',NULL,76,1,9656422,733888072,'-',15,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-19 19:27:03',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/a/2/8/e/5477_6#3',0,NULL);
INSERT INTO "lane" VALUES(59,1,1,0,'5477_6#1','5477_6#1',NULL,76,1,7067462,537127112,'-',15,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-19 19:27:06',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/1/f/f/5477_6#1',0,NULL);
INSERT INTO "lane" VALUES(60,19,25,0,'5477_6#4','5477_6#4',NULL,76,1,7803096,593035296,'-',15,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-19 19:27:08',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/c/6/f/5477_6#4',0,NULL);
INSERT INTO "lane" VALUES(61,7,9,0,'5477_6#2','5477_6#2',NULL,76,1,7108898,540276248,'-',15,'failed','pending','unchecked',NULL,NULL,NULL,'2014-03-19 19:27:10',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/7/4/9/5477_6#2',0,NULL);
INSERT INTO "lane" VALUES(62,1,1,0,'5477_6#1','5477_6#1','ERR028809',76,1,7067462,537127112,'-',783,'passed','passed','unchecked',NULL,NULL,NULL,'2014-03-20 02:10:06',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/1/f/f/5477_6#1',1,NULL);
INSERT INTO "lane" VALUES(63,7,9,0,'5477_6#2','5477_6#2','ERR028812',76,1,7108898,540276248,'-',3343,'failed','pending','unchecked',NULL,NULL,NULL,'2014-03-20 02:10:07',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/7/4/9/5477_6#2',0,NULL);
INSERT INTO "lane" VALUES(64,13,17,0,'5477_6#3','5477_6#3','ERR028813',76,1,9656422,733888072,'-',783,'passed','failed','unchecked',NULL,NULL,NULL,'2014-03-20 02:10:09',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/a/2/8/e/5477_6#3',1,NULL);
INSERT INTO "lane" VALUES(65,19,25,0,'5477_6#4','5477_6#4','ERR028814',76,1,7803096,593035296,'-',783,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-20 02:10:10',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/c/6/f/5477_6#4',0,NULL);
INSERT INTO "lane" VALUES(66,22,29,0,'6578_4#4','6578_4#4',NULL,75,1,10409566,780717450,'-',527,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-20 03:27:06',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/a/7/0/8/6578_4#4',0,NULL);
INSERT INTO "lane" VALUES(67,22,29,0,'6578_4#4','6578_4#4','ERR047291',75,1,10409566,780717450,'-',783,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-20 07:10:06',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/a/7/0/8/6578_4#4',1,NULL);
INSERT INTO "lane" VALUES(68,15,18,0,'6578_4#3','6578_4#3',NULL,75,1,4872748,365456100,'-',1039,'passed','failed','unchecked',NULL,NULL,NULL,'2014-03-20 14:52:07',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/8/9/8/6578_4#3',0,NULL);
INSERT INTO "lane" VALUES(69,9,11,0,'6578_4#2','6578_4#2',NULL,75,1,8286578,621493350,'-',1039,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-20 15:52:03',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/7/9/0/6578_4#2',0,NULL);
INSERT INTO "lane" VALUES(70,2,2,0,'6578_4#1','6578_4#1',NULL,75,1,9208112,690608400,'-',15,'failed','passed','unchecked',NULL,NULL,NULL,'2014-03-20 15:52:05',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/8/4/b/6578_4#1',0,NULL);
INSERT INTO "lane" VALUES(71,15,18,0,'6578_4#3','6578_4#3','ERR047290',75,1,4872748,365456100,'-',3343,'passed','failed','unchecked',NULL,NULL,NULL,'2014-03-20 22:10:07',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/8/9/8/6578_4#3',1,NULL);
INSERT INTO "lane" VALUES(72,2,2,0,'6578_4#1','6578_4#1','ERR047288',75,1,9208112,690608400,'-',783,'failed','passed','unchecked',NULL,NULL,NULL,'2014-03-20 23:10:08',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/8/4/b/6578_4#1',1,NULL);
INSERT INTO "lane" VALUES(73,9,11,0,'6578_4#2','6578_4#2','ERR047289',75,1,8286578,621493350,'-',3343,'passed','pending','unchecked',NULL,NULL,NULL,'2014-03-20 23:10:09',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/7/9/0/6578_4#2',1,NULL);
INSERT INTO "lane" VALUES(74,7,9,0,'5477_6#2','5477_6#2','ERR028812',76,1,7108898,540276248,'-',3343,'failed','failed','unchecked',NULL,NULL,NULL,'2014-04-09 14:34:14',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/7/4/9/5477_6#2',0,NULL);
INSERT INTO "lane" VALUES(75,19,25,0,'5477_6#4','5477_6#4','ERR028814',76,1,7803096,593035296,'-',783,'passed','failed','unchecked',NULL,NULL,NULL,'2014-04-09 14:34:14',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/c/6/f/5477_6#4',0,NULL);
INSERT INTO "lane" VALUES(76,7,9,0,'5477_6#2','5477_6#2','ERR028812',76,1,7108898,540276248,'-',3343,'failed','pending','unchecked',NULL,NULL,NULL,'2014-04-09 14:37:08',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/4/7/4/9/5477_6#2',1,NULL);
INSERT INTO "lane" VALUES(77,19,25,0,'5477_6#4','5477_6#4','ERR028814',76,1,7803096,593035296,'-',783,'passed','pending','unchecked',NULL,NULL,NULL,'2014-04-09 14:37:08',NULL,'t/data/07_finder/hashed_lanes/pathogen_test_pathfind/2/c/6/f/5477_6#4',1,NULL);
INSERT INTO "lane" VALUES(78,78,0,0,'22693_E01','22693_E01',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(79,78,49,0,'22693_E01','22693_E01',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(80,78,49,0,'22693_E01','22693_E01',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,1,NULL);
INSERT INTO "lane" VALUES(81,81,0,0,'22873_H01','22873_H01',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(82,81,49,0,'22873_H01','22873_H01',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(83,81,49,0,'22873_H01','22873_H01',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,1,NULL);
INSERT INTO "lane" VALUES(84,84,0,0,'22893_A01','22893_A01',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(85,84,49,0,'22893_A01','22893_A01',NULL,NULL,NULL,NULL,NULL,'pending',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,0,NULL);
INSERT INTO "lane" VALUES(86,84,49,0,'22893_A01','22893_A01',NULL,NULL,1,0,0,'-',0,'no_qc','no_qc','unchecked',NULL,NULL,NULL,'2014-04-29 11:11:30',NULL,NULL,1,NULL);
CREATE TABLE `library` (
  `row_id` int unsigned NOT NULL PRIMARY KEY,
  `library_id` int unsigned NOT NULL,
  `library_request_id` mediumint unsigned NOT NULL DEFAULT '0',
  `sample_id` int unsigned NOT NULL,
  `ssid` mediumint unsigned DEFAULT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `prep_status` varchar(255) DEFAULT 'unknown',
  `auto_qc_status` varchar(255) DEFAULT 'no_qc',
  `qc_status` varchar(255) DEFAULT 'no_qc',
  `fragment_size_from` mediumint unsigned DEFAULT NULL,
  `fragment_size_to` mediumint unsigned DEFAULT NULL,
  `library_type_id` smallint unsigned DEFAULT NULL,
  `library_tag` smallint unsigned DEFAULT NULL,
  `library_tag_group` smallint unsigned DEFAULT NULL,
  `library_tag_sequence` varchar(1024) DEFAULT NULL,
  `seq_centre_id` smallint unsigned DEFAULT NULL,
  `seq_tech_id` smallint unsigned DEFAULT NULL,
  `open` tinyint DEFAULT '1',
  `note_id` mediumint unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `latest` tinyint DEFAULT '0'
);
INSERT INTO "library" VALUES(1,1,0,0,NULL,'test1_1','test1_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "library" VALUES(2,2,0,0,NULL,'test2_1','test2_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "library" VALUES(3,1,0,3,NULL,'test1_1','test1_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "library" VALUES(4,2,0,1,NULL,'test2_1','test2_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "library" VALUES(5,2,0,1,1,'test2_1','test2_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "library" VALUES(6,1,0,3,1,'test1_1','test1_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:27',0);
INSERT INTO "library" VALUES(7,1,0,3,1,'test1_1','test1_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:30',0);
INSERT INTO "library" VALUES(8,2,0,1,1,'test2_1','test2_1','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:30',0);
INSERT INTO "library" VALUES(9,9,0,0,NULL,'test1_2','test1_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(10,9,0,7,NULL,'test1_2','test1_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(11,11,0,0,NULL,'test2_2','test2_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(12,9,0,7,2,'test1_2','test1_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(13,11,0,9,NULL,'test2_2','test2_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(14,11,0,9,2,'test2_2','test2_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(15,9,0,7,2,'test1_2','test1_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(16,11,0,9,2,'test2_2','test2_2','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(17,17,0,0,NULL,'test1_3','test1_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(18,18,0,0,NULL,'test2_3','test2_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(19,17,0,13,NULL,'test1_3','test1_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(20,17,0,13,3,'test1_3','test1_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(21,18,0,16,NULL,'test2_3','test2_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(22,18,0,16,3,'test2_3','test2_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(23,17,0,13,3,'test1_3','test1_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(24,18,0,16,3,'test2_3','test2_3','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(25,25,0,0,NULL,'test1_4','test1_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(26,25,0,19,NULL,'test1_4','test1_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(27,25,0,19,4,'test1_4','test1_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(28,25,0,19,4,'test1_4','test1_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(29,29,0,0,NULL,'test2_4','test2_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(30,29,0,22,NULL,'test2_4','test2_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(31,29,0,22,4,'test2_4','test2_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(32,29,0,22,4,'test2_4','test2_4','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 11:30:31',0);
INSERT INTO "library" VALUES(33,1,0,3,1,'test1_1','test1_1','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:06',0);
INSERT INTO "library" VALUES(34,1,0,3,1,'test1_1','test1_1','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:07',1);
INSERT INTO "library" VALUES(35,9,0,7,2,'test1_2','test1_2','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:07',0);
INSERT INTO "library" VALUES(36,9,0,7,2,'test1_2','test1_2','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:08',1);
INSERT INTO "library" VALUES(37,17,0,13,3,'test1_3','test1_3','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:08',0);
INSERT INTO "library" VALUES(38,17,0,13,3,'test1_3','test1_3','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:08',1);
INSERT INTO "library" VALUES(39,25,0,19,4,'test1_4','test1_4','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:09',0);
INSERT INTO "library" VALUES(40,25,0,19,4,'test1_4','test1_4','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 18:30:09',1);
INSERT INTO "library" VALUES(41,2,0,1,1,'test2_1','test2_1','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 19:30:06',0);
INSERT INTO "library" VALUES(42,2,0,1,1,'test2_1','test2_1','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 19:30:06',1);
INSERT INTO "library" VALUES(43,11,0,9,2,'test2_2','test2_2','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 19:30:07',0);
INSERT INTO "library" VALUES(44,11,0,9,2,'test2_2','test2_2','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 19:30:07',1);
INSERT INTO "library" VALUES(45,18,0,16,3,'test2_3','test2_3','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 19:30:08',0);
INSERT INTO "library" VALUES(46,18,0,16,3,'test2_3','test2_3','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-12 19:30:08',1);
INSERT INTO "library" VALUES(47,29,0,22,4,'test2_4','test2_4','unknown','failed','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-14 11:30:05',0);
INSERT INTO "library" VALUES(48,29,0,22,4,'test2_4','test2_4','unknown','failed','pending',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-03-14 11:30:08',1);
INSERT INTO "library" VALUES(49,49,0,0,NULL,'PB_Mtuberculosis','PB_Mtuberculosis','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-04-29 11:11:24',0);
INSERT INTO "library" VALUES(50,49,0,25,NULL,'PB_Mtuberculosis','PB_Mtuberculosis','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-04-29 11:11:24',0);
INSERT INTO "library" VALUES(51,49,0,25,7958208,'PB_Mtuberculosis','PB_Mtuberculosis','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'2014-04-29 11:11:24',0);
INSERT INTO "library" VALUES(52,49,0,25,7958208,'PB_Mtuberculosis','PB_Mtuberculosis','unknown','no_qc','no_qc',NULL,NULL,NULL,NULL,NULL,NULL,1,1,1,NULL,'2014-04-29 11:11:29',1);
CREATE TABLE `project` (
  `row_id` int unsigned NOT NULL PRIMARY KEY,
  `project_id` smallint unsigned NOT NULL DEFAULT '0',
  `ssid` mediumint unsigned DEFAULT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `study_id` smallint DEFAULT NULL,
  `note_id` mediumint unsigned DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `latest` tinyint DEFAULT '0'
);
INSERT INTO "project" VALUES(1,1,1,'Study','Study',1,NULL,'2014-03-03 14:02:25',1);
INSERT INTO "project" VALUES(2,2,NULL,'Test Study 2','Test_Study_2',NULL,NULL,'2014-03-12 11:30:24',0);
INSERT INTO "project" VALUES(3,2,2,'Test Study 2','Test_Study_2',NULL,NULL,'2014-03-12 11:30:24',1);
INSERT INTO "project" VALUES(4,4,NULL,'Test Study 1','Test_Study_1',NULL,NULL,'2014-03-12 11:30:26',0);
INSERT INTO "project" VALUES(5,4,3,'Test Study 1','Test_Study_1',NULL,NULL,'2014-03-12 11:30:26',1);
INSERT INTO "project" VALUES(6,6,NULL,'Pacbio_pathogens','Pacbio_pathogens',NULL,NULL,'2014-04-29 11:04:47',0);
INSERT INTO "project" VALUES(7,6,2745,'Pacbio_pathogens','Pacbio_pathogens',NULL,NULL,'2014-04-29 11:04:47',1);
INSERT INTO "project" VALUES(8,8,NULL,'ILB 1075 100 Year Genomic Evolution of M1 strains of Streptococcus pyogenes (JP)','ILB_1075_100_Year_Genomic_Evolution_of_M1_strains_of_Streptococcus_pyogenes_JP_',NULL,NULL,'2014-04-29 11:05:28',0);
INSERT INTO "project" VALUES(9,8,2699,'ILB 1075 100 Year Genomic Evolution of M1 strains of Streptococcus pyogenes (JP)','ILB_1075_100_Year_Genomic_Evolution_of_M1_strains_of_Streptococcus_pyogenes_JP_',NULL,NULL,'2014-04-29 11:05:28',0);
INSERT INTO "project" VALUES(10,8,2699,'ILB 1075 100 Year Genomic Evolution of M1 strains of Streptococcus pyogenes (JP)','ILB_1075_100_Year_Genomic_Evolution_of_M1_strains_of_Streptococcus_pyogenes_JP_',2,NULL,'2014-04-29 11:05:28',1);
CREATE TABLE `individual` (
 `individual_id` int NOT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) NOT NULL DEFAULT '',
  `alias` varchar(40) NOT NULL DEFAULT '',
  `sex` varchar(40) DEFAULT 'unknown',
  `acc` varchar(40) DEFAULT NULL,
  `species_id` int DEFAULT NULL,
  `population_id` int DEFAULT NULL
);
INSERT INTO "individual" VALUES(1,'test2_1','test2_1','','unknown','ERS031943',2,1);
INSERT INTO "individual" VALUES(2,'test1_1','test1_1','','unknown','ERS015862',1,1);
INSERT INTO "individual" VALUES(3,'test1_2','test1_2','','unknown','ERS015863',1,1);
INSERT INTO "individual" VALUES(4,'test2_2','test2_2','','unknown','ERS031944',2,1);
INSERT INTO "individual" VALUES(5,'test1_3','test1_3','','unknown','ERS015864',1,1);
INSERT INTO "individual" VALUES(6,'test2_3','test2_3','','unknown','ERS031945',2,1);
INSERT INTO "individual" VALUES(7,'test1_4','test1_4','','unknown','ERS015865',1,1);
INSERT INTO "individual" VALUES(8,'test2_4','test2_4','','unknown','ERS031946',2,1);
INSERT INTO "individual" VALUES(9,'PB_Mtuberculosis','PB_Mtuberculosis','','unknown',NULL,3,1);
CREATE TABLE `species` (
  `species_id` mediumint NOT NULL,
  `name` varchar(255) NOT NULL,
  `taxon_id` mediumint(8) NOT NULL
);
INSERT INTO "species" VALUES(1,'Streptococcus pneumoniae',1313);
INSERT INTO "species" VALUES(2,'Shigella flexneri',623);
INSERT INTO "species" VALUES(3,'Mycobacterium tuberculosis',0);
INSERT INTO "species" VALUES(57,'Neisseria gonorrhoeae',485);
CREATE TABLE `seq_tech` (
  `seq_tech_id` smallint(5) NOT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`seq_tech_id`)
);
INSERT INTO "seq_tech" VALUES(1,'SLX');
CREATE TABLE `file` (
  `row_id` int(10) NOT NULL,
  `file_id` mediumint(8) NOT NULL DEFAULT '0',
  `lane_id` int(10) NOT NULL,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hierarchy_name` varchar(255) DEFAULT NULL,
  `processed` int(10) DEFAULT '0',
  `type` tinyint(4) DEFAULT NULL,
  `readlen` smallint(5) DEFAULT NULL,
  `raw_reads` bigint(20) DEFAULT NULL,
  `raw_bases` bigint(20) DEFAULT NULL,
  `mean_q` float DEFAULT NULL,
  `md5` char(32) DEFAULT NULL,
  `note_id` mediumint(8) DEFAULT NULL,
  `changed` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `latest` tinyint(1) DEFAULT '0',
  `reference` varchar(255) DEFAULT NULL
);
INSERT INTO "file" VALUES(1,1,0,'6578_4#1_1.fastq.gz','6578_4_1_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(2,1,2,'6578_4#1_1.fastq.gz','6578_4_1_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(3,1,2,'6578_4#1_1.fastq.gz','6578_4_1_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(4,4,0,'5477_6#1_1.fastq.gz','5477_6_1_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(5,4,1,'5477_6#1_1.fastq.gz','5477_6_1_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(6,6,0,'6578_4#1_2.fastq.gz','6578_4_1_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(7,4,1,'5477_6#1_1.fastq.gz','5477_6_1_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(8,6,2,'6578_4#1_2.fastq.gz','6578_4_1_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(9,9,0,'5477_6#1_2.fastq.gz','5477_6_1_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(10,9,1,'5477_6#1_2.fastq.gz','5477_6_1_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(11,9,1,'5477_6#1_2.fastq.gz','5477_6_1_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(12,6,2,'6578_4#1_2.fastq.gz','6578_4_1_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(13,13,0,'5477_6#2_1.fastq.gz','5477_6_2_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(14,13,7,'5477_6#2_1.fastq.gz','5477_6_2_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(15,13,7,'5477_6#2_1.fastq.gz','5477_6_2_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(16,16,0,'6578_4#2_1.fastq.gz','6578_4_2_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(17,17,0,'5477_6#2_2.fastq.gz','5477_6_2_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(18,16,9,'6578_4#2_1.fastq.gz','6578_4_2_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(19,16,9,'6578_4#2_1.fastq.gz','6578_4_2_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(20,17,7,'5477_6#2_2.fastq.gz','5477_6_2_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(21,17,7,'5477_6#2_2.fastq.gz','5477_6_2_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(22,22,0,'6578_4#2_2.fastq.gz','6578_4_2_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(23,22,9,'6578_4#2_2.fastq.gz','6578_4_2_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(24,22,9,'6578_4#2_2.fastq.gz','6578_4_2_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(25,25,0,'5477_6#3_1.fastq.gz','5477_6_3_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(26,25,13,'5477_6#3_1.fastq.gz','5477_6_3_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(27,25,13,'5477_6#3_1.fastq.gz','5477_6_3_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(28,28,0,'5477_6#3_2.fastq.gz','5477_6_3_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(29,28,13,'5477_6#3_2.fastq.gz','5477_6_3_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(30,28,13,'5477_6#3_2.fastq.gz','5477_6_3_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(31,31,0,'6578_4#3_1.fastq.gz','6578_4_3_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(32,31,15,'6578_4#3_1.fastq.gz','6578_4_3_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(33,31,15,'6578_4#3_1.fastq.gz','6578_4_3_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(34,34,0,'6578_4#3_2.fastq.gz','6578_4_3_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(35,34,15,'6578_4#3_2.fastq.gz','6578_4_3_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(36,34,15,'6578_4#3_2.fastq.gz','6578_4_3_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(37,37,0,'5477_6#4_1.fastq.gz','5477_6_4_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(38,37,19,'5477_6#4_1.fastq.gz','5477_6_4_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(39,37,19,'5477_6#4_1.fastq.gz','5477_6_4_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(40,40,0,'5477_6#4_2.fastq.gz','5477_6_4_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(41,40,19,'5477_6#4_2.fastq.gz','5477_6_4_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(42,40,19,'5477_6#4_2.fastq.gz','5477_6_4_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(43,43,0,'6578_4#4_1.fastq.gz','6578_4_4_1_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(44,43,22,'6578_4#4_1.fastq.gz','6578_4_4_1.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(45,43,22,'6578_4#4_1.fastq.gz','6578_4_4_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(46,46,0,'6578_4#4_2.fastq.gz','6578_4_4_2_fastq_gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(47,46,22,'6578_4#4_2.fastq.gz','6578_4_4_2.fastq.gz',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(48,46,22,'6578_4#4_2.fastq.gz','6578_4_4_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,NULL,NULL,'2014-03-12 11:30:31',0,NULL);
INSERT INTO "file" VALUES(49,4,1,'5477_6#1_1.fastq.gz','5477_6#1_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'b88c43287180c68a9fd3ef4990a79d97',NULL,'2014-03-12 11:30:39',1,NULL);
INSERT INTO "file" VALUES(50,1,2,'6578_4#1_1.fastq.gz','6578_4#1_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'04d7513b165eb8510a2647afd79f843c',NULL,'2014-03-12 11:30:47',1,NULL);
INSERT INTO "file" VALUES(51,9,1,'5477_6#1_2.fastq.gz','5477_6#1_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'0362a04167f50602e3013f282aedd266',NULL,'2014-03-12 11:30:47',1,NULL);
INSERT INTO "file" VALUES(52,13,7,'5477_6#2_1.fastq.gz','5477_6#2_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'60bb6999fbd69bd26abd8869ebf6f3ef',NULL,'2014-03-12 11:30:55',1,NULL);
INSERT INTO "file" VALUES(53,6,2,'6578_4#1_2.fastq.gz','6578_4#1_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'b9a48f3ee0a4d279149a0ae0316783b3',NULL,'2014-03-12 11:31:02',1,NULL);
INSERT INTO "file" VALUES(54,17,7,'5477_6#2_2.fastq.gz','5477_6#2_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'8b71fe6d8fa625fe89a49a23392e2b64',NULL,'2014-03-12 11:31:02',1,NULL);
INSERT INTO "file" VALUES(55,25,13,'5477_6#3_1.fastq.gz','5477_6#3_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'d5e2448779a42225da515e230d1e2215',NULL,'2014-03-12 11:31:13',1,NULL);
INSERT INTO "file" VALUES(56,16,9,'6578_4#2_1.fastq.gz','6578_4#2_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'caf24c383e0ac73dd0a15fc1aae76ea0',NULL,'2014-03-12 11:31:16',1,NULL);
INSERT INTO "file" VALUES(57,28,13,'5477_6#3_2.fastq.gz','5477_6#3_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'65853f394e1a303f0417f4c883e8aef1',NULL,'2014-03-12 11:31:23',1,NULL);
INSERT INTO "file" VALUES(58,22,9,'6578_4#2_2.fastq.gz','6578_4#2_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'18d30e3090da0547d0788773a8e61ff6',NULL,'2014-03-12 11:31:29',1,NULL);
INSERT INTO "file" VALUES(59,37,19,'5477_6#4_1.fastq.gz','5477_6#4_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'59cd455752436e62dcd39494b9ca0815',NULL,'2014-03-12 11:31:32',1,NULL);
INSERT INTO "file" VALUES(60,31,15,'6578_4#3_1.fastq.gz','6578_4#3_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'7e5ddabf1e01dc27472ae01971c7e0d5',NULL,'2014-03-12 11:31:37',1,NULL);
INSERT INTO "file" VALUES(61,40,19,'5477_6#4_2.fastq.gz','5477_6#4_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'b30823f177d2c828d01dd07109f091e3',NULL,'2014-03-12 11:31:40',1,NULL);
INSERT INTO "file" VALUES(62,34,15,'6578_4#3_2.fastq.gz','6578_4#3_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'4565883ccc32588076d12eafeeebcb42',NULL,'2014-03-12 11:31:45',1,NULL);
INSERT INTO "file" VALUES(63,43,22,'6578_4#4_1.fastq.gz','6578_4#4_1.fastq.gz',0,1,NULL,NULL,NULL,NULL,'df3e8aa150110c059535597c2735abc6',NULL,'2014-03-12 11:32:03',1,NULL);
INSERT INTO "file" VALUES(64,46,22,'6578_4#4_2.fastq.gz','6578_4#4_2.fastq.gz',0,2,NULL,NULL,NULL,NULL,'4394a1915be4c1bb10a8a4746ff524ea',NULL,'2014-03-12 11:32:19',1,NULL);
INSERT INTO "file" VALUES(65,65,0,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.1.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0_1_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(66,65,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.1.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.1.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(67,65,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.1.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.1.bax.h5',0,5,NULL,NULL,NULL,NULL,'bb0271c1a3e78b85d92150f2d061df70',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(68,68,0,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.2.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0_2_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(69,68,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.2.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.2.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(70,68,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.2.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.2.bax.h5',0,5,NULL,NULL,NULL,NULL,'3af44ced49e5ea55a9ff26eb280cb43a',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(71,71,0,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.3.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0_3_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(72,71,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.3.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.3.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(73,71,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.3.bax.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.3.bax.h5',0,5,NULL,NULL,NULL,NULL,'06e35800d8823fc821e9b4652e817198',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(74,74,0,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.bas.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0_bas_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(75,74,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.bas.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.bas.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(76,74,78,'/seq/pacbio/22693_592/E01_1/Analysis_Results/m130816_110851_00127_c100563742550000001823084212221347_s1_p0.bas.h5','_seq_pacbio_22693_592_E01_1_Analysis_Results_m130816_110851_00127_c100563742550000001823084212221347_s1_p0.bas.h5',0,5,NULL,NULL,NULL,NULL,'175efff6ba8240d0fd7e793a7394600f',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(77,77,0,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.1.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0_1_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(78,77,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.1.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.1.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(79,77,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.1.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.1.bax.h5',0,5,NULL,NULL,NULL,NULL,'afa20c76319374ffb2fe6e143a6a2bea',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(80,80,0,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.2.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0_2_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(81,80,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.2.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.2.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(82,80,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.2.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.2.bax.h5',0,5,NULL,NULL,NULL,NULL,'c42aa049c51bceb540a7738c02e84bba',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(83,83,0,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.3.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0_3_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(84,83,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.3.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.3.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(85,83,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.3.bax.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.3.bax.h5',0,5,NULL,NULL,NULL,NULL,'bbe6377311a086e8862cc7a474e51b4c',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(86,86,0,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.bas.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0_bas_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(87,86,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.bas.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.bas.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(88,86,81,'/seq/pacbio/22873_595/H01_1/Analysis_Results/m130828_085204_00127_c100546122550000001823085811241357_s1_p0.bas.h5','_seq_pacbio_22873_595_H01_1_Analysis_Results_m130828_085204_00127_c100546122550000001823085811241357_s1_p0.bas.h5',0,5,NULL,NULL,NULL,NULL,'cb2d2b15a33a034890088217606c79e9',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(89,89,0,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.1.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0_1_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(90,89,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.1.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.1.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(91,89,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.1.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.1.bax.h5',0,5,NULL,NULL,NULL,NULL,'6f567422771541cf852939a8b78933e4',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(92,92,0,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.2.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0_2_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(93,92,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.2.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.2.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(94,92,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.2.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.2.bax.h5',0,5,NULL,NULL,NULL,NULL,'13b0f5133bcd05b692679874bc47d62c',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(95,95,0,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.3.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0_3_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(96,95,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.3.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.3.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(97,95,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.3.bax.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.3.bax.h5',0,5,NULL,NULL,NULL,NULL,'91382ec166232826f8309b80b720c866',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(98,98,0,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.bas.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0_bas_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(99,98,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.bas.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.bas.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(100,98,84,'/seq/pacbio/22893_596/A01_1/Analysis_Results/m130828_181148_00127_c100548032550000001823084311241317_s1_p0.bas.h5','_seq_pacbio_22893_596_A01_1_Analysis_Results_m130828_181148_00127_c100548032550000001823084311241317_s1_p0.bas.h5',0,5,NULL,NULL,NULL,NULL,'f5a666526dcb7bf3bf719f9fe86d624c',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(101,101,0,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.1.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0_1_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(102,101,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.1.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.1.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(103,101,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.1.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.1.bax.h5',0,5,NULL,NULL,NULL,NULL,'fa7d7b45a25039e232e5ef09f4df9dfc',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(104,104,0,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.2.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0_2_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(105,104,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.2.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.2.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(106,104,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.2.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.2.bax.h5',0,5,NULL,NULL,NULL,NULL,'b34d2da42dc8f614e6eb5a0776fd83f8',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(107,107,0,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.3.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0_3_bax_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(108,107,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.3.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.3.bax.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(109,107,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.3.bax.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.3.bax.h5',0,5,NULL,NULL,NULL,NULL,'d958eb201bb301978f53b852657a63fa',NULL,'2014-04-29 11:11:30',1,NULL);
INSERT INTO "file" VALUES(110,110,0,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.bas.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0_bas_h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(111,110,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.bas.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.bas.h5',0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2014-04-29 11:11:30',0,NULL);
INSERT INTO "file" VALUES(112,110,84,'/seq/pacbio/22893_596/A01_2/Analysis_Results/m130828_202755_00127_c100563622550000001823084212221394_s1_p0.bas.h5','_seq_pacbio_22893_596_A01_2_Analysis_Results_m130828_202755_00127_c100563622550000001823084212221394_s1_p0.bas.h5',0,5,NULL,NULL,NULL,NULL,'d90e599656d89efb3bcd9a11f26fad64',NULL,'2014-04-29 11:11:30',1,NULL);
CREATE VIEW latest_lane AS SELECT * FROM lane WHERE latest=1;
CREATE VIEW latest_project AS SELECT * FROM project WHERE latest=1;
CREATE VIEW latest_library AS SELECT * FROM library WHERE latest=1;
CREATE VIEW latest_sample AS SELECT * FROM sample WHERE latest=1;
CREATE VIEW latest_file AS SELECT * FROM file WHERE latest=1;
COMMIT;
