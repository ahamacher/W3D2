PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS question_follows;
DROP TABLE IF EXISTS question_likes;
DROP TABLE IF EXISTS replies;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    fname VARCHAR(255) NOT NULL,
    lname VARCHAR(255) NOT NULL
);

CREATE TABLE questions (
    id INTEGER PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    author_id INTEGER NOT NULL,

    FOREIGN KEY (author_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
    question_id INTEGER NOT NULL,
    follower_id INTEGER NOT NULL,

    FOREIGN KEY (question_id) REFERENCES questions(id),
    FOREIGN KEY (follower_id) REFERENCES users(id)
);

CREATE TABLE replies (
    id INTEGER PRIMARY KEY,
    question_id INTEGER NOT NULL,
    parent_reply INTEGER,
    user_id INTEGER NOT NULL,
    body TEXT NOT NULL,

    FOREIGN KEY (question_id) REFERENCES questions(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_likes (
    user_id INTEGER NOT NULL,
    question_id INTEGER NOT NULL,
    FOREIGN KEY (question_id) REFERENCES questions(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO
    users (fname, lname)
VALUES
    ('Arthur', 'Miller'),
    ('Eugene', 'O''Neill');

INSERT INTO
    questions (title, body, author_id)
VALUES
    ('HELP!', 'how computer?', (SELECT id FROM users WHERE fname = 'Arthur')),
    ('Screen Black', 'computer is possibly not plugged in?', (SELECT id FROM users WHERE fname = 'Eugene'));

INSERT INTO 
    replies (question_id, parent_reply, user_id, body)
VALUES
    ((SELECT id FROM questions WHERE title = 'HELP!'), NULL, (SELECT id FROM users WHERE fname = 'Eugene'), 'its dumb..'),
    ((SELECT id FROM questions WHERE title = 'HELP!'), 1, (SELECT id FROM users WHERE fname = 'Arthur'), 'I give up!');

INSERT INTO
    question_follows (question_id, follower_id)
VALUES
    ((SELECT id FROM questions WHERE title = 'HELP!'), (SELECT id FROM users WHERE fname = 'Arthur')),
    ((SELECT id FROM questions WHERE title = 'HELP!'), (SELECT id FROM users WHERE fname = 'Eugene'));

INSERT INTO
    question_likes (user_id, question_id)
VALUES
    ((SELECT id FROM users WHERE fname = 'Arthur'), (SELECT id FROM questions WHERE title = 'Screen Black')),
    ((SELECT id FROM users WHERE fname = 'Eugene'), (SELECT id FROM questions WHERE title = 'Screen Black')),
    ((SELECT id FROM users WHERE fname = 'Eugene'), (SELECT id FROM questions WHERE title = 'HELP!'));




