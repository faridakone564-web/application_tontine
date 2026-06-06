-- Exécuter dans phpMyAdmin si les groupes ne se chargent pas (colonne status manquante)
USE onetap_tontine;

ALTER TABLE `groups` ADD COLUMN status VARCHAR(50) DEFAULT 'recrutement';

UPDATE `groups` SET status = 'recrutement' WHERE status IS NULL;
