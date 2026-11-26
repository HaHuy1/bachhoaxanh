
USE mini_netflix;

DELIMITER //


-- Thủ tục đăng ký mới, gia hạn hoặc nâng cấp gói cước (chu kỳ 30 ngày)
DROP PROCEDURE IF EXISTS sp_subscribe_or_renew_plan //
CREATE PROCEDURE sp_subscribe_or_renew_plan(
    IN p_user_id     INT,
    IN p_new_plan_id INT,
    IN p_cycles      INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_curr_plan_id INT;
    DECLARE v_is_active    TINYINT;
    DECLARE v_days         INT;

    -- 1. Kiểm tra p_cycles trong khoảng 1–12 chu kỳ
    IF p_cycles IS NULL OR p_cycles < 1 OR p_cycles > 12 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Số chu kỳ đăng ký/gia hạn (p_cycles) phải nằm trong khoảng từ 1 đến 12!';
    END IF;

    -- 2. Kiểm tra user phải tồn tại
    IF NOT EXISTS (SELECT 1 FROM USER WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Tài khoản người dùng (user_id) không tồn tại!';
    END IF;

    -- 3. Kiểm tra gói cước phải tồn tại
    IF NOT EXISTS (SELECT 1 FROM SUBSCRIPTION_PLAN WHERE plan_id = p_new_plan_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Gói cước (plan_id) không tồn tại!';
    END IF;

    SET v_days = p_cycles * 30;
    SET v_is_active = fn_is_plan_active(p_user_id);

    SELECT plan_id INTO v_curr_plan_id
    FROM USER
    WHERE user_id = p_user_id;

    -- TH1: Chưa có gói hoặc gói đã hết hạn -> Mua mới tính từ hôm nay
    IF v_curr_plan_id IS NULL OR v_is_active = 0 THEN
        UPDATE USER
        SET plan_id         = p_new_plan_id,
            plan_start_date = CURDATE(),
            plan_end_date   = DATE_ADD(CURDATE(), INTERVAL v_days DAY)
        WHERE user_id = p_user_id;

    -- TH2: Gia hạn cùng gói đang còn hạn -> Cộng nối tiếp ngày hết hạn
    ELSEIF v_curr_plan_id = p_new_plan_id THEN
        UPDATE USER
        SET plan_end_date = fn_new_end_date(p_user_id, p_cycles)
        WHERE user_id = p_user_id;

    -- TH3: Đổi gói khi còn hạn -> Tính lại từ hôm nay (Trigger chặn nếu hạ cấp)
    ELSE
        UPDATE USER
        SET plan_id         = p_new_plan_id,
            plan_start_date = CURDATE(),
            plan_end_date   = DATE_ADD(CURDATE(), INTERVAL v_days DAY)
        WHERE user_id = p_user_id;
    END IF;
END //

-- 1. Giới hạn số hồ sơ theo maxprofiles & kiểm tra gói còn hiệu lực
DROP TRIGGER IF EXISTS trg_profile_before_insert //
CREATE TRIGGER trg_profile_before_insert
BEFORE INSERT ON PROFILE
FOR EACH ROW
BEGIN
    DECLARE v_current_count INT;
    DECLARE v_max_profiles INT;

    IF fn_is_plan_active(NEW.user_id) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Tài khoản chưa mua gói cước hoặc gói đã hết hạn, không thể tạo hồ sơ!';
    END IF;

    SELECT COUNT(*) INTO v_current_count FROM PROFILE WHERE user_id = NEW.user_id;

    SELECT sp.maxprofiles INTO v_max_profiles
    FROM USER u
    JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
    WHERE u.user_id = NEW.user_id;

    IF v_current_count >= v_max_profiles THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Đã đạt giới hạn số lượng hồ sơ tối đa (maxprofiles) của gói cước!';
    END IF;
END //

-- 2. Tự động tạo 1 hồ sơ mặc định khi tài khoản lần đầu đăng ký gói cước
DROP TRIGGER IF EXISTS trg_user_auto_default_profile //
CREATE TRIGGER trg_user_auto_default_profile
AFTER UPDATE ON USER
FOR EACH ROW
BEGIN
    IF (OLD.plan_id IS NULL OR OLD.plan_end_date < CURDATE())
       AND NEW.plan_id IS NOT NULL
       AND NEW.plan_end_date >= CURDATE() THEN
        IF NOT EXISTS (SELECT 1 FROM PROFILE WHERE user_id = NEW.user_id) THEN
            INSERT INTO PROFILE (profilename, avatar, user_id)
            VALUES (NEW.fullname , 'default_avatar.png', NEW.user_id);
        END IF;
    END IF;
END //
-- 3. Chặn hạ cấp gói khi còn hạn & đảm bảo tính lại thời hạn khi nâng cấp
DROP TRIGGER IF EXISTS trg_user_plan_update_check //
CREATE TRIGGER trg_user_plan_update_check
BEFORE UPDATE ON USER
FOR EACH ROW
BEGIN
    DECLARE v_old_price INT;
    DECLARE v_new_price INT;

    IF OLD.plan_id IS NOT NULL
       AND NEW.plan_id IS NOT NULL
       AND OLD.plan_id <> NEW.plan_id THEN
        IF OLD.plan_end_date >= CURDATE() THEN
            SELECT price INTO v_old_price FROM SUBSCRIPTION_PLAN WHERE plan_id = OLD.plan_id;
            SELECT price INTO v_new_price FROM SUBSCRIPTION_PLAN WHERE plan_id = NEW.plan_id;

            IF v_new_price < v_old_price THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Lỗi: Không hỗ trợ hạ cấp gói cước khi gói hiện tại vẫn còn hiệu lực!';
            END IF;

            IF NEW.plan_end_date = OLD.plan_end_date OR NEW.plan_end_date IS NULL THEN
                SET NEW.plan_start_date = CURDATE();
                SET NEW.plan_end_date   = DATE_ADD(CURDATE(), INTERVAL 30 DAY);
            END IF;
        END IF;
    END IF;
END //

-- 4a & 4b. Đảm bảo tính rời rạc (Disjoint) giữa MOVIE và EPISODE
DROP TRIGGER IF EXISTS trg_movie_disjoint_insert //
CREATE TRIGGER trg_movie_disjoint_insert
BEFORE INSERT ON MOVIE
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM EPISODE WHERE content_id = NEW.content_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi Disjoint: content_id này đã thuộc bảng EPISODE!';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_episode_disjoint_insert //
CREATE TRIGGER trg_episode_disjoint_insert
BEFORE INSERT ON EPISODE
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM MOVIE WHERE content_id = NEW.content_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi Disjoint: content_id này đã thuộc bảng MOVIE!';
    END IF;
END //

-- 5a & 5b. Kiểm tra lịch sử xem (quyền xem, progress hợp lệ, tự gán watchedat)
DROP TRIGGER IF EXISTS trg_watch_history_before_insert //
CREATE TRIGGER trg_watch_history_before_insert
BEFORE INSERT ON WATCH_HISTORY
FOR EACH ROW
BEGIN
    DECLARE v_duration INT;

    IF fn_can_watch(NEW.profile_id, NEW.content_id) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không có quyền xem nội dung này (gói hết hạn hoặc chưa đến ngày mở khóa)!';
    END IF;

    SELECT duration INTO v_duration FROM CONTENT WHERE content_id = NEW.content_id;
    IF NEW.progress < 0 OR NEW.progress > v_duration THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Tiến trình xem (progress) phải nằm trong khoảng từ 0 đến thời lượng video!';
    END IF;

    SET NEW.watchedat = NOW();
END //

DROP TRIGGER IF EXISTS trg_watch_history_before_update //
CREATE TRIGGER trg_watch_history_before_update
BEFORE UPDATE ON WATCH_HISTORY
FOR EACH ROW
BEGIN
    DECLARE v_duration INT;

    IF fn_can_watch(NEW.profile_id, NEW.content_id) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Hồ sơ không có quyền xem nội dung này!';
    END IF;

    SELECT duration INTO v_duration FROM CONTENT WHERE content_id = NEW.content_id;
    IF NEW.progress < 0 OR NEW.progress > v_duration THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Tiến trình xem (progress) không được âm hoặc vượt quá thời lượng video!';
    END IF;

    SET NEW.watchedat = NOW();
END //

-- 6. Kiểm tra điều kiện thêm vào WATCHLIST và tự gán thời gian addedat
DROP TRIGGER IF EXISTS trg_watchlist_before_insert //
CREATE TRIGGER trg_watchlist_before_insert
BEFORE INSERT ON WATCHLIST
FOR EACH ROW
BEGIN
    DECLARE v_user_id INT;

    SELECT user_id INTO v_user_id FROM PROFILE WHERE profile_id = NEW.profile_id;

    IF fn_is_plan_active(v_user_id) = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Chỉ tài khoản có gói cước còn hiệu lực mới được thêm vào danh sách theo dõi!';
    END IF;

    SET NEW.addedat = NOW();
END //

-- 7. Giữ ít nhất 1 thể loại cho mỗi nội dung (chặn xóa thể loại cuối cùng)
DROP TRIGGER IF EXISTS trg_genre_keep_min_one //
CREATE TRIGGER trg_genre_keep_min_one
BEFORE DELETE ON GENRE
FOR EACH ROW
BEGIN
    DECLARE v_genre_count INT;

    SELECT COUNT(*) INTO v_genre_count
    FROM GENRE
    WHERE content_id = OLD.content_id;

    IF v_genre_count <= 1 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Mỗi nội dung bắt buộc phải có ít nhất 1 thể loại, không thể xóa thể loại cuối cùng!';
    END IF;
END //

DELIMITER ;
DELIMITER //

-- Thủ tục xóa trọn bộ phim (xóa CONTENT của các tập trước -> xóa SEASON -> xóa TV_SERIES)
DROP PROCEDURE IF EXISTS sp_delete_tv_series //
CREATE PROCEDURE sp_delete_tv_series(
    IN p_series_id INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM TV_SERIES WHERE series_id = p_series_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Bộ phim (series_id) không tồn tại!';
    END IF;

    START TRANSACTION;
        -- Bước 1: Xóa CONTENT của tất cả tập thuộc bộ phim
        -- (ON DELETE CASCADE tự động xóa EPISODE, GENRE, WATCHLIST, WATCH_HISTORY)
        DELETE FROM CONTENT
        WHERE content_id IN (
            SELECT content_id FROM (
                SELECT e.content_id
                FROM EPISODE e
                JOIN SEASON s ON e.season_id = s.season_id
                WHERE s.series_id = p_series_id
            ) AS tmp_ep
        );

        -- Bước 2: Xóa các mùa phim của bộ phim
        DELETE FROM SEASON WHERE series_id = p_series_id;

        -- Bước 3: Xóa bộ phim
        DELETE FROM TV_SERIES WHERE series_id = p_series_id;
    COMMIT;
END //

-- Thủ tục xóa trọn một mùa phim (xóa CONTENT của các tập trong mùa trước -> xóa SEASON)
DROP PROCEDURE IF EXISTS sp_delete_season //
CREATE PROCEDURE sp_delete_season(
    IN p_season_id INT
)
SQL SECURITY DEFINER
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM SEASON WHERE season_id = p_season_id) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lỗi: Mùa phim (season_id) không tồn tại!';
    END IF;

    START TRANSACTION;
        DELETE FROM CONTENT
        WHERE content_id IN (
            SELECT content_id FROM (
                SELECT content_id
                FROM EPISODE
                WHERE season_id = p_season_id
            ) AS tmp_ep
        );

        DELETE FROM SEASON WHERE season_id = p_season_id;
    COMMIT;
END //

DELIMITER ;