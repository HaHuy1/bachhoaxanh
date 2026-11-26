
USE mini_netflix;

-- 1. v_content_all: Gộp CONTENT với MOVIE/EPISODE kèm video_url và thể loại
CREATE OR REPLACE VIEW v_content_all AS
SELECT 
    c.content_id,
    c.title,
    CASE 
        WHEN m.content_id IS NOT NULL THEN 'MOVIE'
        WHEN e.content_id IS NOT NULL THEN 'EPISODE'
        ELSE 'UNKNOWN'
    END AS content_type,
    c.releasedate,
    c.duration,
    COALESCE(m.video_url, e.video_url) AS video_url,
    GROUP_CONCAT(g.genrename ORDER BY g.genrename SEPARATOR ', ') AS genres
FROM CONTENT c
LEFT JOIN MOVIE m ON c.content_id = m.content_id
LEFT JOIN EPISODE e ON c.content_id = e.content_id
LEFT JOIN GENRE g ON c.content_id = g.content_id
GROUP BY 
    c.content_id, c.title, c.releasedate, c.duration, 
    m.content_id, e.content_id, m.video_url, e.video_url;

-- 2. v_episode_detail: Nối 3 cấp TV_SERIES -> SEASON -> EPISODE -> CONTENT
CREATE OR REPLACE VIEW v_episode_detail AS
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
    c.releasedate,
    e.video_url
FROM TV_SERIES ts
JOIN SEASON s ON ts.series_id = s.series_id
JOIN EPISODE e ON s.season_id = e.season_id
JOIN CONTENT c ON e.content_id = c.content_id;

-- 3. v_user_subscription_status: Trạng thái gói cước và số ngày còn lại
CREATE OR REPLACE VIEW v_user_subscription_status AS
SELECT 
    u.user_id,
    u.fullname,
    u.email,
    sp.planname,
    sp.price,
    sp.maxprofiles,
    sp.maxdevices,
    sp.earlyaccessdays,
    u.plan_start_date,
    u.plan_end_date,
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
LEFT JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id;

-- 4. v_continue_watching: Nội dung xem dở (0 < progress < 90% thời lượng)
CREATE OR REPLACE VIEW v_continue_watching AS
SELECT 
    wh.historyid,
    wh.profile_id,
    p.profilename,
    wh.content_id,
    c.title,
    wh.progress,
    c.duration,
    ROUND((wh.progress / c.duration) * 100, 2) AS watch_percent,
    wh.watchedat
FROM WATCH_HISTORY wh
JOIN PROFILE p ON wh.profile_id = p.profile_id
JOIN CONTENT c ON wh.content_id = c.content_id
WHERE wh.progress > 0 AND wh.progress < (0.9 * c.duration)
ORDER BY wh.watchedat DESC;

-- 5. v_user_accessible_content: Nội dung từng tài khoản được phép xem hôm nay
CREATE OR REPLACE VIEW v_user_accessible_content AS
SELECT 
    u.user_id,
    u.fullname,
    sp.planname,
    c.content_id,
    c.title,
    c.releasedate,
    DATE_SUB(c.releasedate, INTERVAL sp.earlyaccessdays DAY) AS unlock_date
FROM USER u
JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
CROSS JOIN CONTENT c
WHERE u.plan_end_date >= CURDATE()
  AND CURDATE() >= DATE_SUB(c.releasedate, INTERVAL sp.earlyaccessdays DAY);

DELIMITER //

-- 1. fn_is_plan_active: Kiểm tra tài khoản có gói còn hiệu lực không (1: Đúng, 0: Sai)
DROP FUNCTION IF EXISTS fn_is_plan_active //
CREATE FUNCTION fn_is_plan_active(p_user_id INT)
RETURNS TINYINT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_end_date DATE;

    SELECT plan_end_date INTO v_end_date
    FROM USER
    WHERE user_id = p_user_id;

    IF v_end_date IS NOT NULL AND v_end_date >= CURDATE() THEN
        RETURN 1;
    END IF;
    RETURN 0;
END //

-- 2. fn_can_watch: Kiểm tra Profile có quyền xem Content tại thời điểm hiện tại không
DROP FUNCTION IF EXISTS fn_can_watch //
CREATE FUNCTION fn_can_watch(p_profile_id INT, p_content_id INT)
RETURNS TINYINT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_user_id INT;
    DECLARE v_early_days INT;
    DECLARE v_release_date DATE;

    SELECT p.user_id, sp.earlyaccessdays
    INTO v_user_id, v_early_days
    FROM PROFILE p
    JOIN USER u ON p.user_id = u.user_id
    LEFT JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
    WHERE p.profile_id = p_profile_id;

    -- Chặn nếu không tìm thấy profile hoặc gói hết hạn
    IF v_user_id IS NULL OR fn_is_plan_active(v_user_id) = 0 THEN
        RETURN 0;
    END IF;

    SELECT releasedate INTO v_release_date
    FROM CONTENT
    WHERE content_id = p_content_id;

    IF v_release_date IS NULL THEN
        RETURN 0;
    END IF;

    IF CURDATE() >= DATE_SUB(v_release_date, INTERVAL v_early_days DAY) THEN
        RETURN 1;
    END IF;
    RETURN 0;
END //

-- 3. fn_watch_percent: Tính % tiến độ xem của một hồ sơ với một nội dung
DROP FUNCTION IF EXISTS fn_watch_percent //
CREATE FUNCTION fn_watch_percent(p_profile_id INT, p_content_id INT)
RETURNS DECIMAL(5,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_percent DECIMAL(5,2);

    SELECT ROUND((wh.progress / c.duration) * 100, 2)
    INTO v_percent
    FROM WATCH_HISTORY wh
    JOIN CONTENT c ON wh.content_id = c.content_id
    WHERE wh.profile_id = p_profile_id AND wh.content_id = p_content_id;

    RETURN IFNULL(v_percent, 0.00);
END //

-- 4. fn_content_type: Trả về loại nội dung ('MOVIE' hoặc 'EPISODE')
DROP FUNCTION IF EXISTS fn_content_type //
CREATE FUNCTION fn_content_type(p_content_id INT)
RETURNS VARCHAR(20)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    IF EXISTS (SELECT 1 FROM MOVIE WHERE content_id = p_content_id) THEN
        RETURN 'MOVIE';
    ELSEIF EXISTS (SELECT 1 FROM EPISODE WHERE content_id = p_content_id) THEN
        RETURN 'EPISODE';
    END IF;
    RETURN 'UNKNOWN';
END //

-- 5. fn_new_end_date: Tính ngày hết hạn mới khi gia hạn (30 ngày / chu kỳ)
DROP FUNCTION IF EXISTS fn_new_end_date //
CREATE FUNCTION fn_new_end_date(p_user_id INT, p_cycles INT)
RETURNS DATE
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_curr_end DATE;
    DECLARE v_days INT;

    SET v_days = IF(p_cycles IS NULL OR p_cycles <= 0, 1, p_cycles) * 30;

    SELECT plan_end_date INTO v_curr_end
    FROM USER
    WHERE user_id = p_user_id;

    -- Nếu còn hạn -> cộng nối tiếp; nếu hết hạn/chưa mua -> tính từ hôm nay
    IF v_curr_end IS NOT NULL AND v_curr_end >= CURDATE() THEN
        RETURN DATE_ADD(v_curr_end, INTERVAL v_days DAY);
    ELSE
        RETURN DATE_ADD(CURDATE(), INTERVAL v_days DAY);
    END IF;
END //

DELIMITER ;