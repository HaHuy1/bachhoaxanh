CREATE DATABASE IF NOT EXISTS mininetflix;
USE mininetflix;
-- =============================================================================
-- PHẦN 1: DDL SCRIPT - TẠO CẤU TRÚC BẢNG (DATA DEFINITION LANGUAGE)
-- =============================================================================

-- Xóa bảng cũ nếu đã tồn tại (theo thứ tự ngược lại với ràng buộc khóa ngoại)
DROP TABLE IF EXISTS WATCH_HISTORY;
DROP TABLE IF EXISTS WATCHLIST;
DROP TABLE IF EXISTS CONTENT_GENRE;
DROP TABLE IF EXISTS GENRE;
DROP TABLE IF EXISTS EPISODE;
DROP TABLE IF EXISTS SEASON;
DROP TABLE IF EXISTS TV_SERIES;
DROP TABLE IF EXISTS MOVIE;
DROP TABLE IF EXISTS CONTENT;
DROP TABLE IF EXISTS PROFILE;
DROP TABLE IF EXISTS `USER`;
DROP TABLE IF EXISTS SUBSCRIPTION_PLAN;

-- 1. Bảng SUBSCRIPTION_PLAN
CREATE TABLE SUBSCRIPTION_PLAN (
    plan_id INT AUTO_INCREMENT PRIMARY KEY,
    planname VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    videoquality VARCHAR(50),
    maxprofiles INT NOT NULL CHECK (maxprofiles > 0),
    earlyaccessdays INT DEFAULT 0
);

-- 2. Bảng USER
CREATE TABLE `USER` (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    fullname VARCHAR(255) NOT NULL,
    birth_day DATE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    plan_id INT,
    FOREIGN KEY (plan_id) REFERENCES SUBSCRIPTION_PLAN(plan_id) ON DELETE SET NULL
);

-- 3. Bảng PROFILE
-- Tự động xóa PROFILE khi USER bị xóa (ON DELETE CASCADE) theo quy tắc nghiệp vụ
CREATE TABLE PROFILE (
    profile_id INT AUTO_INCREMENT PRIMARY KEY,
    profilename VARCHAR(100) NOT NULL,
    avatar VARCHAR(255),
    user_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES `USER`(user_id) ON DELETE CASCADE
);

-- 4. Bảng CONTENT
CREATE TABLE CONTENT (
    contentid INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    releasedate DATE,
    duration INT CHECK (duration > 0)
);

-- 5. Bảng MOVIE (Thực thể con kế thừa từ CONTENT)
CREATE TABLE MOVIE (
    contentid INT PRIMARY KEY,
    video_url VARCHAR(500) NOT NULL,
    FOREIGN KEY (contentid) REFERENCES CONTENT(contentid) ON DELETE CASCADE
);

-- 6. Bảng TV_SERIES
CREATE TABLE TV_SERIES (
    seriesid INT AUTO_INCREMENT PRIMARY KEY,
    seriestitle VARCHAR(255) NOT NULL,
    releaseyear INT
);

-- 7. Bảng SEASON
CREATE TABLE SEASON (
    season_id INT AUTO_INCREMENT PRIMARY KEY,
    season_name VARCHAR(100) NOT NULL,
    seriesid INT NOT NULL,
    FOREIGN KEY (seriesid) REFERENCES TV_SERIES(seriesid) ON DELETE CASCADE
);

-- 8. Bảng EPISODE (Thực thể con kế thừa từ CONTENT)
CREATE TABLE EPISODE (
    contentid INT PRIMARY KEY,
    seriesid INT NOT NULL,
    season_id INT NOT NULL,
    episodenumber INT NOT NULL,
    FOREIGN KEY (contentid) REFERENCES CONTENT(contentid) ON DELETE CASCADE,
    FOREIGN KEY (seriesid) REFERENCES TV_SERIES(seriesid) ON DELETE CASCADE,
    FOREIGN KEY (season_id) REFERENCES SEASON(season_id) ON DELETE CASCADE
);

-- 9. Bảng GENRE
CREATE TABLE GENRE (
    genreid INT AUTO_INCREMENT PRIMARY KEY,
    genrename VARCHAR(100) NOT NULL
);

-- 10. Bảng CONTENT_GENRE (Quan hệ M:N giữa CONTENT và GENRE)
CREATE TABLE CONTENT_GENRE (
    contentid INT NOT NULL,
    genreid INT NOT NULL,
    PRIMARY KEY (contentid, genreid),
    FOREIGN KEY (contentid) REFERENCES CONTENT(contentid) ON DELETE CASCADE,
    FOREIGN KEY (genreid) REFERENCES GENRE(genreid) ON DELETE CASCADE
);

-- 11. Bảng WATCHLIST
CREATE TABLE WATCHLIST (
    profileid INT NOT NULL,
    contentid INT NOT NULL,
    addedat DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (profileid, contentid),
    FOREIGN KEY (profileid) REFERENCES PROFILE(profile_id) ON DELETE CASCADE,
    FOREIGN KEY (contentid) REFERENCES CONTENT(contentid) ON DELETE CASCADE
);

-- 12. Bảng WATCH_HISTORY
CREATE TABLE WATCH_HISTORY (
    profileid INT NOT NULL,
    contentid INT NOT NULL,
    watchedat DATETIME DEFAULT CURRENT_TIMESTAMP,
    progress INT DEFAULT 0 CHECK (progress >= 0),
    PRIMARY KEY (profileid, contentid),
    FOREIGN KEY (profileid) REFERENCES PROFILE(profile_id) ON DELETE CASCADE,
    FOREIGN KEY (contentid) REFERENCES CONTENT(contentid) ON DELETE CASCADE
);


-- =============================================================================
-- PHẦN 2: DML SCRIPT - NHẬP DỮ LIỆU MẪU (MOCK DATA)
-- =============================================================================

-- Nhập dữ liệu Gói cước
INSERT INTO SUBSCRIPTION_PLAN (plan_id, planname, price, videoquality, maxprofiles, earlyaccessdays) VALUES
(1, 'Basic', 49000.00, 'HD 720p', 1, 0),
(2, 'Plus', 79000.00, 'Full HD 1080p', 3, 2),
(3, 'Pro', 119000.00, 'Ultra HD 4K', 5, 4);

-- Nhập dữ liệu Người dùng
INSERT INTO `USER` (user_id, fullname, birth_day, email, password, plan_id) VALUES
(1, 'Nguyen Huy Hoang', '2002-05-15', 'hoang@student.ptithcm.edu.vn', 'hash_pass_1', 3),
(2, 'Ha Quoc Huy', '2003-08-20', 'ha.huy@student.ptithcm.edu.vn', 'hash_pass_2', 2),
(3, 'Le Quoc Huy', '2001-11-10', 'le.huy@student.ptithcm.edu.vn', 'hash_pass_3', 1),
(4, 'Tran Van A', '2008-01-01', 'trana@gmail.com', 'hash_pass_4', 3);

-- Nhập dữ liệu Profile
INSERT INTO PROFILE (profile_id, profilename, avatar, user_id) VALUES
(1, 'Hoang Main', 'avatar1.png', 1),
(2, 'Hoang Kids', 'avatar2.png', 1),
(3, 'Huy Ha', 'avatar3.png', 2),
(4, 'Huy Le', 'avatar4.png', 3),
(5, 'An Active', 'avatar5.png', 4);

-- Nhập dữ liệu Thể loại
INSERT INTO GENRE (genreid, genrename) VALUES
(1, 'Action'), (2, 'Drama'), (3, 'Sci-Fi'), (4, 'Animation'), (5, 'Comedy');

-- Nhập dữ liệu Nội dung (Chung cho Movie và Episode)
INSERT INTO CONTENT (contentid, title, description, releasedate, duration) VALUES
(1, 'Stranger Things S1E1', 'Tập 1 Mùa 1', '2016-07-15', 50),
(2, 'Stranger Things S1E2', 'Tập 2 Mùa 1', '2016-07-15', 55),
(3, 'Inception', 'Kẻ Đánh Cắp Giấc Mơ', '2010-07-16', 148),
(4, 'Interstellar', 'Hố Đen Vũ Trụ', '2014-11-07', 169),
(5, 'Avenger Endgame', 'Hồi Kết Biệt Đội Siêu Anh Hùng', '2019-04-26', 181);

-- Phim lẻ (Movie)
INSERT INTO MOVIE (contentid, video_url) VALUES
(3, 'https://cdn.netflix.com/movies/inception.mp4'),
(4, 'https://cdn.netflix.com/movies/interstellar.mp4'),
(5, 'https://cdn.netflix.com/movies/endgame.mp4');

-- Phim bộ & Tập phim
INSERT INTO TV_SERIES (seriesid, seriestitle, releaseyear) VALUES
(1, 'Stranger Things', 2016);

INSERT INTO SEASON (season_id, season_name, seriesid) VALUES
(1, 'Season 1', 1);

INSERT INTO EPISODE (contentid, seriesid, season_id, episodenumber) VALUES
(1, 1, 1, 1),
(2, 1, 1, 2);

-- Phân loại Thể loại cho Content
INSERT INTO CONTENT_GENRE (contentid, genreid) VALUES
(1, 2), (1, 3), -- Stranger Things S1E1: Drama, Sci-Fi
(3, 1), (3, 3), -- Inception: Action, Sci-Fi
(4, 3),         -- Interstellar: Sci-Fi
(5, 1), (5, 3); -- Endgame: Action, Sci-Fi

-- Lịch sử xem (WATCH_HISTORY)
INSERT INTO WATCH_HISTORY (profileid, contentid, watchedat, progress) VALUES
(1, 3, '2026-10-01 10:00:00', 8000), -- Hoang xem Inception gần xong
(1, 5, '2026-10-02 14:30:00', 10800),-- Hoang xem Endgame
(3, 1, '2026-10-03 20:00:00', 3000), -- Huy Ha xem Stranger Things
(4, 4, '2026-10-04 21:15:00', 500);  -- Huy Le xem Interstellar (dở dở)

-- Danh sách yêu thích (WATCHLIST)
INSERT INTO WATCHLIST (profileid, contentid, addedat) VALUES
(1, 4, '2026-09-28 08:00:00'),
(1, 5, '2026-09-29 09:30:00'),
(2, 1, '2026-10-01 12:00:00'),
(3, 3, '2026-10-02 15:00:00');


-- =============================================================================
-- PHẦN 3: VIEWS & TRIGGERS (YÊU CẦU MIN 2 VIEWS & 2 TRIGGERS)
-- =============================================================================

-- VIEW 1: Tổng hợp danh sách phim lẻ kèm URL và các thể loại
CREATE OR REPLACE VIEW vw_movie_details AS
SELECT 
    c.contentid,
    c.title,
    c.duration,
    m.video_url,
    GROUP_CONCAT(g.genrename SEPARATOR ', ') AS genres
FROM CONTENT c
JOIN MOVIE m ON c.contentid = m.contentid
LEFT JOIN CONTENT_GENRE cg ON c.contentid = cg.contentid
LEFT JOIN GENRE g ON cg.genreid = g.genreid
GROUP BY c.contentid, c.title, c.duration, m.video_url;

-- VIEW 2: Thống kê tình trạng sử dụng Hồ sơ của người dùng so với giới hạn Gói cước
CREATE OR REPLACE VIEW vw_user_profile_usage AS
SELECT 
    u.user_id,
    u.fullname,
    u.email,
    p.planname,
    p.maxprofiles,
    COUNT(pr.profile_id) AS current_profiles_count
FROM `USER` u
JOIN SUBSCRIPTION_PLAN p ON u.plan_id = p.plan_id
LEFT JOIN PROFILE pr ON u.user_id = pr.user_id
GROUP BY u.user_id, u.fullname, u.email, p.planname, p.maxprofiles;


-- TRIGGER 1: Kiểm tra ràng buộc giới hạn số lượng Profile trước khi thêm mới
DELIMITER //
CREATE TRIGGER trg_check_max_profiles
BEFORE INSERT ON PROFILE
FOR EACH ROW
BEGIN
    DECLARE current_count INT;
    DECLARE max_allowed INT;

    -- Lấy số lượng profile hiện tại
    SELECT COUNT(*) INTO current_count 
    FROM PROFILE 
    WHERE user_id = NEW.user_id;

    -- Lấy giới hạn tối đa từ gói cước dịch vụ
    SELECT sp.maxprofiles INTO max_allowed
    FROM `USER` u
    JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
    WHERE u.user_id = NEW.user_id;

    -- Nếu vượt quá giới hạn thì chặn lại và báo lỗi
    IF current_count >= max_allowed THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Số lượng Profile đã đạt mức tối đa cho phép của gói cước hiện tại!';
    END IF;
END //
DELIMITER ;


-- TRIGGER 2: Tự động cập nhật mốc thời gian xem khi có thay đổi tiến trình progress
DELIMITER //
CREATE TRIGGER trg_auto_update_watchedat
BEFORE UPDATE ON WATCH_HISTORY
FOR EACH ROW
BEGIN
    IF NEW.progress <> OLD.progress THEN
        SET NEW.watchedat = CURRENT_TIMESTAMP();
    END IF;
END //
DELIMITER ;


-- =============================================================================
-- PHẦN 4: 10+ CÂU TRUY VẤN PHỨC TẠP (COMPLEX QUERIES)
-- =============================================================================

-- Query 1: Lấy danh sách phim lẻ (Movie) có thời lượng trên 120 phút kèm theo tên các thể loại
SELECT c.title, c.duration, GROUP_CONCAT(g.genrename) AS genres
FROM CONTENT c
JOIN MOVIE m ON c.contentid = m.contentid
JOIN CONTENT_GENRE cg ON c.contentid = cg.contentid
JOIN GENRE g ON cg.genreid = g.genreid
WHERE c.duration > 120
GROUP BY c.contentid, c.title, c.duration;

-- Query 2: Liệt kê thông tin người dùng và tổng số lượt xem nội dung của từng hồ sơ trực thuộc
SELECT u.fullname, u.email, p.profilename, COUNT(wh.contentid) AS total_watched_contents
FROM `USER` u
JOIN PROFILE p ON u.user_id = p.user_id
LEFT JOIN WATCH_HISTORY wh ON p.profile_id = wh.profileid
GROUP BY u.user_id, p.profile_id, u.fullname, u.email, p.profilename;

-- Query 3: Tìm các bộ phim (TV_SERIES) có số lượng tập phim (EPISODE) lớn hơn 1
SELECT s.seriesid, s.seriestitle, COUNT(e.contentid) AS total_episodes
FROM TV_SERIES s
JOIN EPISODE e ON s.seriesid = e.seriesid
GROUP BY s.seriesid, s.seriestitle
HAVING COUNT(e.contentid) >= 1;

-- Query 4: Tìm danh sách các Hồ sơ (PROFILE) chưa từng thêm bất kỳ nội dung nào vào WATCHLIST (Subquery)
SELECT profile_id, profilename 
FROM PROFILE
WHERE profile_id NOT IN (
    SELECT DISTINCT profileid FROM WATCHLIST
);

-- Query 5: Tính tổng doanh thu hiện tại của hệ thống phân theo từng loại gói cước (Aggregation)
SELECT sp.planname, sp.price, COUNT(u.user_id) AS total_subscribers, (sp.price * COUNT(u.user_id)) AS revenue
FROM SUBSCRIPTION_PLAN sp
LEFT JOIN `USER` u ON sp.plan_id = u.plan_id
GROUP BY sp.plan_id, sp.planname, sp.price;

-- Query 6: Tìm các nội dung (CONTENT) xuất hiện nhiều nhất trong danh sách yêu thích (Top Favorite Content)
SELECT c.contentid, c.title, COUNT(w.profileid) AS watchlist_count
FROM CONTENT c
JOIN WATCHLIST w ON c.contentid = w.contentid
GROUP BY c.contentid, c.title
ORDER BY watchlist_count DESC
LIMIT 5;

-- Query 7: Tìm người dùng đang sử dụng gói 'Pro' và có độ tuổi dưới 25 (Tính theo năm 2026)
SELECT u.fullname, u.email, u.birth_day, sp.planname
FROM `USER` u
JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
WHERE sp.planname = 'Pro' AND (2026 - YEAR(u.birth_day)) < 25;

-- Query 8: Lấy danh sách các tập phim thuộc Series 'Stranger Things', hiển thị thông tin Mùa và Số tập
SELECT c.title, ts.seriestitle, s.season_name, e.episodenumber, c.duration
FROM EPISODE e
JOIN CONTENT c ON e.contentid = c.contentid
JOIN TV_SERIES ts ON e.seriesid = ts.seriesid
JOIN SEASON s ON e.season_id = s.season_id
WHERE ts.seriestitle = 'Stranger Things'
ORDER BY s.season_id, e.episodenumber;

-- Query 9: Tìm các Hồ sơ đã hoàn tất xem phim (Tiến trình tiến gần bằng thời lượng video - đổi từ giây sang phút)
SELECT p.profilename, c.title, wh.progress, (c.duration * 60) AS total_seconds
FROM WATCH_HISTORY wh
JOIN PROFILE p ON wh.profileid = p.profile_id
JOIN CONTENT c ON wh.contentid = c.contentid
WHERE wh.progress >= (c.duration * 60 * 0.9); -- Tiến trình xem >= 90%

-- Query 10: Thống kê số lượng nội dung thuộc về từng thể loại (GENRE), chỉ hiển thị các thể loại có ít nhất 1 nội dung
SELECT g.genrename, COUNT(cg.contentid) AS content_count
FROM GENRE g
JOIN CONTENT_GENRE cg ON g.genreid = cg.genreid
GROUP BY g.genreid, g.genrename
HAVING COUNT(cg.contentid) > 0
ORDER BY content_count DESC;