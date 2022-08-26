-- Schema Design

-- Lists and Todos

-- Lists has a one-to-many relationship with Todos
-- - A list can have many todos; A todo can belong to only one list

-- Lists:
-- id: primary key
-- name: text UNIQUE NOT NULL

-- Todo
-- id: primary key
-- name: NOT NULL
-- list_id : FOREIGN KEY REFERENCES lists(id)
-- is_completed: boolean not null default: false

CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text UNIQUE NOT NULL
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name text NOT NULL,
  completed boolean DEFAULT false NOT NULL,
  list_id int REFERENCES lists(id) ON DELETE CASCADE NOT NULL
);