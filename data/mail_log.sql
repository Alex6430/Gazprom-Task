CREATE DATABASE IF NOT EXISTS `mail_log`;
USE mail_log;
DROP TABLE IF EXISTS `message`;
CREATE TABLE message (
    created TIMESTAMP(0) NOT NULL,
    id VARCHAR(1020) NOT NULL,
    int_id CHAR(16) NOT NULL,
    str VARCHAR(1020) NOT NULL,
    status BOOL,
    CONSTRAINT message_id_pk PRIMARY KEY(id)
);

CREATE INDEX message_created_idx ON message (created);

CREATE INDEX message_int_id_idx ON message (int_id);

DROP TABLE IF EXISTS `log`;
CREATE TABLE log (
    created TIMESTAMP(0) NOT NULL,
    int_id CHAR(16) NOT NULL,
    str VARCHAR(1020),
    address VARCHAR(1020)
);

CREATE INDEX log_address_idx USING HASH ON log (address);