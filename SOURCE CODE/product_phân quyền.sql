USE mini_netflix;
DELIMITER //

-- 1. Xem thông tin tài khoản & trạng thái gói của chính mình
DROP PROCEDURE IF EXISTS sp_get_my_account //
CREATE PROCEDURE sp_get_my_account(IN p_user_id INT)
SQL SECURITY DEFINER
BEGIN
    SELECT
        u.user_id, u.fullname, u.birth_day, u.email,
        sp.plan_id, sp.planname, sp.price, sp.videoquality,
        sp.maxprofiles, sp.maxdevices, sp.earlyaccessdays,
        u.plan_start_date, u.plan_end_date,
        CASE
            WHEN u.plan_id IS NULL OR u.plan_end_date < CURDATE() THEN 0
            ELSE DATEDIFF(u.plan_end_date, CURDATE())
        END AS days_remaining,
        CASE
            WHEN u.plan_id IS NULL THEN 'Chưa mua gói'
            WHEN u.plan_end_date >= CURDATE() THEN 'Còn hạn'
            ELSE 'Hết hạn'
        END AS subscription_status
    FROM USER u
    LEFT JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
    WHERE u.user_id = p_user_id;
END //

-- 2. Cập nhật thông tin cá nhân & mật khẩu của chính mình
DROP PROCEDURE IF EXISTS sp_update_my_account //
CREATE PROCEDURE sp_update_my_account(
    IN p_user_id      INT,
    IN p_fullname     VARCHAR(255),
    IN p_birth_day    DATE,
    IN p_new_password VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (SELECT 1 FROM USER WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Tài khoản người dùng không tồn tại!';
    END IF;

    UPDATE USER
    SET fullname  = COALESCE(NULLIF(p_fullname, ''), fullname),
        birth_day = COALESCE(p_birth_day, birth_day),
        password  = COALESCE(NULLIF(p_new_password, ''), password)
    WHERE user_id = p_user_id;
END //

-- 3. Quản lý PROFILE của chính user_id
DROP PROCEDURE IF EXISTS sp_get_my_profiles //
CREATE PROCEDURE sp_get_my_profiles(IN p_user_id INT)
SQL SECURITY DEFINER
BEGIN
    SELECT profile_id, profilename, avatar, user_id
    FROM PROFILE
    WHERE user_id = p_user_id;
END //

DROP PROCEDURE IF EXISTS sp_create_profile //
CREATE PROCEDURE sp_create_profile(
    IN p_user_id     INT,
    IN p_profilename VARCHAR(255),
    IN p_avatar      VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
    INSERT INTO PROFILE (profilename, avatar, user_id)
    VALUES (p_profilename, p_avatar, p_user_id);
END //

DROP PROCEDURE IF EXISTS sp_update_profile //
CREATE PROCEDURE sp_update_profile(
    IN p_user_id     INT,
    IN p_profile_id  INT,
    IN p_profilename VARCHAR(255),
    IN p_avatar      VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    UPDATE PROFILE
    SET profilename = COALESCE(NULLIF(p_profilename, ''), profilename),
        avatar      = COALESCE(p_avatar, avatar)
    WHERE profile_id = p_profile_id AND user_id = p_user_id;
END //

DROP PROCEDURE IF EXISTS sp_delete_profile //
CREATE PROCEDURE sp_delete_profile(
    IN p_user_id    INT,
    IN p_profile_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    DELETE FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id;
END //

-- 4. Danh sách nội dung được mở khóa hôm nay & phát video an toàn
DROP PROCEDURE IF EXISTS sp_get_accessible_content //
CREATE PROCEDURE sp_get_accessible_content(IN p_user_id INT)
SQL SECURITY DEFINER
BEGIN
    SELECT
        c.content_id, c.title, fn_content_type(c.content_id) AS content_type,
        c.description, c.releasedate, c.duration,
        DATE_SUB(c.releasedate, INTERVAL sp.earlyaccessdays DAY) AS unlock_date
    FROM USER u
    JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
    CROSS JOIN CONTENT c
    WHERE u.user_id = p_user_id
      AND u.plan_end_date >= CURDATE()
      AND CURDATE() >= DATE_SUB(c.releasedate, INTERVAL sp.earlyaccessdays DAY)
    ORDER BY c.releasedate DESC;
END //

DROP PROCEDURE IF EXISTS sp_play_content //
CREATE PROCEDURE sp_play_content(
    IN p_user_id    INT,
    IN p_profile_id INT,
    IN p_content_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    IF fn_can_watch(p_profile_id, p_content_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Không có quyền xem nội dung này (gói hết hạn hoặc chưa đến ngày mở khóa)!';
    END IF;

    SELECT
        c.content_id, c.title, fn_content_type(c.content_id) AS content_type,
        c.duration, COALESCE(m.video_url, e.video_url) AS video_url
    FROM CONTENT c
    LEFT JOIN MOVIE m   ON c.content_id = m.content_id
    LEFT JOIN EPISODE e ON c.content_id = e.content_id
    WHERE c.content_id = p_content_id;
END //

-- 5. Quản lý WATCH_HISTORY & Tiếp tục xem
DROP PROCEDURE IF EXISTS sp_upsert_watch_history //
CREATE PROCEDURE sp_upsert_watch_history(
    IN p_user_id    INT,
    IN p_profile_id INT,
    IN p_content_id INT,
    IN p_progress   INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    INSERT INTO WATCH_HISTORY (profile_id, content_id, progress)
    VALUES (p_profile_id, p_content_id, p_progress)
    ON DUPLICATE KEY UPDATE progress = p_progress;
END //

DROP PROCEDURE IF EXISTS sp_get_watch_history //
CREATE PROCEDURE sp_get_watch_history(
    IN p_user_id    INT,
    IN p_profile_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    SELECT
        wh.historyid, wh.content_id, c.title,
        fn_content_type(c.content_id) AS content_type,
        wh.progress, c.duration,
        ROUND((wh.progress / c.duration) * 100, 2) AS watch_percent,
        wh.watchedat
    FROM WATCH_HISTORY wh
    JOIN CONTENT c ON wh.content_id = c.content_id
    WHERE wh.profile_id = p_profile_id
    ORDER BY wh.watchedat DESC;
END //

DROP PROCEDURE IF EXISTS sp_get_continue_watching //
CREATE PROCEDURE sp_get_continue_watching(
    IN p_user_id    INT,
    IN p_profile_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    SELECT
        wh.historyid, wh.profile_id, wh.content_id, c.title,
        wh.progress, c.duration,
        ROUND((wh.progress / c.duration) * 100, 2) AS watch_percent,
        wh.watchedat
    FROM WATCH_HISTORY wh
    JOIN CONTENT c ON wh.content_id = c.content_id
    WHERE wh.profile_id = p_profile_id
      AND wh.progress > 0 AND wh.progress < (0.9 * c.duration)
    ORDER BY wh.watchedat DESC;
END //

DROP PROCEDURE IF EXISTS sp_delete_watch_history //
CREATE PROCEDURE sp_delete_watch_history(
    IN p_user_id    INT,
    IN p_profile_id INT,
    IN p_content_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    DELETE FROM WATCH_HISTORY
    WHERE profile_id = p_profile_id AND content_id = p_content_id;
END //

-- 6. Quản lý WATCHLIST
DROP PROCEDURE IF EXISTS sp_get_watchlist //
CREATE PROCEDURE sp_get_watchlist(
    IN p_user_id    INT,
    IN p_profile_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    SELECT
        w.listid, w.content_id, c.title,
        fn_content_type(c.content_id) AS content_type, w.addedat
    FROM WATCHLIST w
    JOIN CONTENT c ON w.content_id = c.content_id
    WHERE w.profile_id = p_profile_id
    ORDER BY w.addedat DESC;
END //

DROP PROCEDURE IF EXISTS sp_add_to_watchlist //
CREATE PROCEDURE sp_add_to_watchlist(
    IN p_user_id    INT,
    IN p_profile_id INT,
    IN p_content_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    INSERT INTO WATCHLIST (profile_id, content_id)
    VALUES (p_profile_id, p_content_id);
END //

DROP PROCEDURE IF EXISTS sp_remove_from_watchlist //
CREATE PROCEDURE sp_remove_from_watchlist(
    IN p_user_id    INT,
    IN p_profile_id INT,
    IN p_content_id INT
)
SQL SECURITY DEFINER
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM PROFILE WHERE profile_id = p_profile_id AND user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không thuộc quyền sở hữu của tài khoản này!';
    END IF;

    DELETE FROM WATCHLIST
    WHERE profile_id = p_profile_id AND content_id = p_content_id;
END //
-- 4b. Xem danh sách mùa & tập của một bộ phim (ẩn video_url)
DROP PROCEDURE IF EXISTS sp_get_series_episodes //
CREATE PROCEDURE sp_get_series_episodes(IN p_series_id INT)
SQL SECURITY DEFINER
BEGIN
    SELECT
        ts.series_id,
        ts.seriestitle,
        ts.releaseyear,
        s.season_id,
        s.seasonname,
        e.content_id,
        e.episodenumber,
        c.title AS episode_title,
        c.duration,
        c.releasedate
    FROM TV_SERIES ts
    JOIN SEASON s  ON ts.series_id = s.series_id
    JOIN EPISODE e ON s.season_id  = e.season_id
    JOIN CONTENT c ON e.content_id = c.content_id
    WHERE ts.series_id = p_series_id
    ORDER BY s.season_id ASC, e.episodenumber ASC;
END //

DELIMITER ;
