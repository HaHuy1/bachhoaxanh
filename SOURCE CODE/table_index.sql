
DROP DATABASE IF EXISTS mini_netflix;
CREATE DATABASE mini_netflix CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mini_netflix;

-- 1. Bảng SUBSCRIPTION_PLAN (Gói cước)
CREATE TABLE SUBSCRIPTION_PLAN (
    plan_id INT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL UNIQUE,
    price INT NOT NULL CHECK (price >= 0),
    video_quality VARCHAR(50) NOT NULL,
    max_profiles INT NOT NULL CHECK (max_profiles > 0),
    early_access_days INT NOT NULL DEFAULT 0, -- Dương: xem sớm, 0: đúng ngày, Âm: xem trễ
    max_devices INT NOT NULL CHECK (max_devices > 0)
);

-- 2. Bảng USER (Tài khoản người dùng)
CREATE TABLE USER (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    birth_day DATE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    plan_id INT ,
    plan_start_date DATE,
    plan_end_date DATE,
    CONSTRAINT chk_user_plan_dates CHECK (
        (plan_start_date IS NULL AND plan_end_date IS NULL)
        OR (plan_start_date IS NOT NULL
            AND plan_end_date IS NOT NULL
            AND plan_end_date >= plan_start_date)
    ),
    CONSTRAINT fk_user_plan FOREIGN KEY (plan_id) 
        REFERENCES SUBSCRIPTION_PLAN(plan_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 3. Bảng PROFILE (Hồ sơ người xem)
CREATE TABLE PROFILE (
    profile_id INT AUTO_INCREMENT PRIMARY KEY,
    profile_name VARCHAR(255) NOT NULL,
    avatar VARCHAR(255),
    user_id INT NOT NULL,
    CONSTRAINT fk_profile_user FOREIGN KEY (user_id) 
        REFERENCES USER(user_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 4. Bảng CONTENT (Thực thể cha trừu tượng)
CREATE TABLE CONTENT (
    content_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    release_date DATE NOT NULL,
    duration INT NOT NULL CHECK (duration > 0) -- Thời lượng tính bằng giây
);

-- 5. Bảng GENRE (Thực thể yếu lưu thể loại)
CREATE TABLE GENRE (
    content_id INT NOT NULL,
    genre_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (content_id, genre_name),
    CONSTRAINT fk_genre_content FOREIGN KEY (content_id) 
        REFERENCES CONTENT(content_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 6. Bảng MOVIE (Thực thể con - Phim lẻ)
CREATE TABLE MOVIE (
    content_id INT PRIMARY KEY,
    video_url VARCHAR(500) NOT NULL,
    CONSTRAINT fk_movie_content FOREIGN KEY (content_id) 
        REFERENCES CONTENT(content_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 7. Bảng TV_SERIES (Bộ phim nhiều tập)
CREATE TABLE TV_SERIES (
    series_id INT AUTO_INCREMENT PRIMARY KEY,
    series_title VARCHAR(255) NOT NULL,
    release_year INT
);

-- 8. Bảng SEASON (Mùa phim)
CREATE TABLE SEASON (
    season_id INT AUTO_INCREMENT PRIMARY KEY,
    season_name VARCHAR(100) NOT NULL,
    series_id INT NOT NULL,
    CONSTRAINT fk_season_series FOREIGN KEY (series_id) 
        REFERENCES TV_SERIES(series_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 9. Bảng EPISODE (Thực thể con - Tập phim)
CREATE TABLE EPISODE (
    content_id INT PRIMARY KEY,
    season_id INT NOT NULL,
    episode_number INT NOT NULL CHECK (episode_number > 0),
    video_url VARCHAR(500) NOT NULL,
    CONSTRAINT uq_season_episode UNIQUE (season_id, episode_number),
    CONSTRAINT fk_episode_content FOREIGN KEY (content_id) 
        REFERENCES CONTENT(content_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_episode_season FOREIGN KEY (season_id) 
        REFERENCES SEASON(season_id) 
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 10. Bảng WATCH_LIST (Danh sách theo dõi)
CREATE TABLE WATCH_LIST (
    list_id INT AUTO_INCREMENT PRIMARY KEY,
    profile_id INT NOT NULL,
    content_id INT NOT NULL,
    added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_watchlist_profile_content UNIQUE (profile_id, content_id),
    CONSTRAINT fk_watchlist_profile FOREIGN KEY (profile_id) 
        REFERENCES PROFILE(profile_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_watchlist_content FOREIGN KEY (content_id) 
        REFERENCES CONTENT(content_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 11. Bảng WATCH_HISTORY (Lịch sử xem)
CREATE TABLE WATCH_HISTORY (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    profile_id INT NOT NULL,
    content_id INT NOT NULL,
    watched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    progress INT DEFAULT 0 CHECK (progress >= 0), -- Giây đã xem
    CONSTRAINT uq_history_profile_content UNIQUE (profile_id, content_id),
    CONSTRAINT fk_history_profile FOREIGN KEY (profile_id) 
        REFERENCES PROFILE(profile_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_history_content FOREIGN KEY (content_id) 
        REFERENCES CONTENT(content_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);


-- TẠO INDEX TỐI ƯU TRUY VẤN

CREATE INDEX idx_user_plan_end ON USER(plan_end_date);
CREATE INDEX idx_content_title ON CONTENT(title);
CREATE INDEX idx_content_release_date ON CONTENT(release_date);
CREATE INDEX idx_genre_name ON GENRE(genre_name);
CREATE INDEX idx_tvseries_title ON TV_SERIES(series_title);
CREATE INDEX idx_history_watched_at ON WATCH_HISTORY(watched_at);