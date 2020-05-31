CREATE USER gpb WITH password '123456';

CREATE database gpb
  WITH owner = gpb
       encoding = 'UTF8'
       tablespace = pg_default
       lc_collate = 'en_US.UTF-8'
       lc_ctype = 'en_US.UTF-8'
       template template0
       connection limit = -1;
GRANT connect, temporary on database gpb to public;

GRANT ALL ON DATABASE gpb TO gpb;

\connect gpb;


CREATE TABLE message (
	created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
	id		VARCHAR NOT NULL,
	int_id  CHAR(16) NOT NULL,
	str 	VARCHAR NOT NULL,
	status 	BOOL,
	CONSTRAINT message_id_pk PRIMARY KEY(id)
);

CREATE INDEX message_created_idx ON message (created);

CREATE INDEX message_int_id_idx ON message (int_id);

ALTER TABLE message OWNER TO gpb;

CREATE TABLE log (
	created TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
	int_id  CHAR(16) NOT NULL,
	str     VARCHAR,
	address VARCHAR
);

CREATE INDEX log_address_idx ON log USING hash (address);

ALTER TABLE log OWNER TO gpb;




