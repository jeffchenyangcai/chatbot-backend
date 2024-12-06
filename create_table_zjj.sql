CREATE TABLE knowledge_bases (
                                 id INTEGER PRIMARY KEY AUTOINCREMENT,  -- 知识库唯一 ID
                                 name VARCHAR NOT NULL,  -- 知识库名称
                                 user_id INTEGER NOT NULL,  -- 关联的用户 ID
                                 created_at DATETIME(6) NOT NULL,  -- 创建时间
                                 updated_at DATETIME(6) NOT NULL,  -- 更新时间
                                 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE  -- 外键关联，用户删除时也删除相关知识库
);
CREATE TABLE files (
                       id INTEGER PRIMARY KEY AUTOINCREMENT,  -- 文件唯一 ID
                       knowledge_base_id INTEGER NOT NULL,  -- 关联的知识库 ID
                       file_name VARCHAR NOT NULL,  -- 文件名
                       file_content TEXT NOT NULL,  -- 文件的文本内容
                       created_at DATETIME(6) NOT NULL,  -- 创建时间
                       updated_at DATETIME(6) NOT NULL,  -- 更新时间
                       FOREIGN KEY (knowledge_base_id) REFERENCES knowledge_bases(id) ON DELETE CASCADE  -- 外键关联，知识库删除时删除文件
);
CREATE TABLE chat_history (
                              id INTEGER PRIMARY KEY AUTOINCREMENT,  -- 聊天记录唯一 ID
                              user_id INTEGER NOT NULL,  -- 关联的用户 ID
                              knowledge_base_id INTEGER NOT NULL,  -- 关联的知识库 ID
                              sender VARCHAR NOT NULL,  -- 发送者 ('User' 或 'GPT')
                              message TEXT NOT NULL,  -- 聊天消息内容
                              created_at DATETIME(6) NOT NULL,  -- 发送时间
                              FOREIGN KEY (user_id) REFERENCES users(id),  -- 外键关联用户
                              FOREIGN KEY (knowledge_base_id) REFERENCES knowledge_bases(id)  -- 外键关联知识库
);
