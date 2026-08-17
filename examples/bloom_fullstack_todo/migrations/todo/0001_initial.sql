-- up
CREATE TABLE IF NOT EXISTS todo_users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS todo_lists (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    owner_id BIGINT NOT NULL REFERENCES todo_users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS todo_tasks (
    id BIGSERIAL PRIMARY KEY,
    list_id BIGINT NOT NULL REFERENCES todo_lists(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    done BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS todo_lists_owner_id_idx ON todo_lists(owner_id);
CREATE INDEX IF NOT EXISTS todo_tasks_list_id_idx ON todo_tasks(list_id);

-- down
DROP TABLE IF EXISTS todo_tasks;
DROP TABLE IF EXISTS todo_lists;
DROP TABLE IF EXISTS todo_users;
