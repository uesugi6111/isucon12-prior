USE `isucon2021_prior`;

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id`         int PRIMARY KEY NOT NULL AUTO_INCREMENT,
  `email`      VARCHAR(255) NOT NULL DEFAULT '',
  `nickname`   VARCHAR(120) NOT NULL DEFAULT '',
  `staff`      BOOLEAN NOT NULL DEFAULT false,
  `created_at` DATETIME(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4;

DROP TABLE IF EXISTS `schedules`;
CREATE TABLE `schedules` (
  `id`         int PRIMARY KEY NOT NULL,
  `title`      VARCHAR(255) NOT NULL DEFAULT '',
  `capacity`   INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4;

DROP TABLE IF EXISTS `reservations`;
CREATE TABLE `reservations` (
  `id`          int PRIMARY KEY NOT NULL ,
  `schedule_id` int NOT NULL,
  `user_id`     int NOT NULL,
  `created_at`  DATETIME(6) NOT NULL,
  KEY `reservations_schedule_id` (`schedule_id`)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4;
