create table users
(
    id              integer     not null
        primary key autoincrement,
    username        varchar     not null,
    password_digest varchar     not null,
    created_at      datetime(6) not null,
    updated_at      datetime(6) not null
);

create table conversations
(
    id         integer     not null
        primary key autoincrement,
    created_at datetime(6) not null,
    updated_at datetime(6) not null,
    user_id    integer     not null
        constraint fk_rails_7c15d62a0a
            references users
);

create index index_conversations_on_user_id
    on conversations (user_id);

create table messages
(
    id              integer     not null
        primary key autoincrement,
    user            varchar,
    text            varchar,
    conversation_id integer     not null
        constraint fk_rails_7f927086d2
            references conversations,
    created_at      datetime(6) not null,
    updated_at      datetime(6) not null,
    user_id         integer
        constraint fk_rails_273a25a7a6
            references users
);

create index index_messages_on_conversation_id
    on messages (conversation_id);

create unique index index_users_on_username
    on users (username);


