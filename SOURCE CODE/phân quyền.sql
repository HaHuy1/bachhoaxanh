USE mini_netflix;

-- Dọn dẹp User & Role cũ
DROP USER IF EXISTS 'netflix_visitor'@'localhost';
DROP USER IF EXISTS 'netflix_free_user'@'localhost';
DROP USER IF EXISTS 'netflix_subscriber'@'localhost';
DROP USER IF EXISTS 'netflix_user'@'localhost';
DROP USER IF EXISTS 'netflix_content_admin'@'localhost';
DROP USER IF EXISTS 'netflix_dba'@'localhost';

DROP ROLE IF EXISTS 'visitor_role', 'unsubscribed_user_role', 'subscribed_user_role', 
                    'authenticated_user_role', 'content_admin_role', 'system_dba_role';

-- 1. Tạo 5 nhóm quyền (Roles)
CREATE ROLE 'visitor_role', 'unsubscribed_user_role', 'subscribed_user_role', 
            'content_admin_role', 'system_dba_role';

-- 2. Khách vãng lai (visitor_role):
--    Chỉ xem bảng giá gói cước công khai; không truy vấn danh mục phim, user, lịch sử xem hay thực thi thủ tục
GRANT SELECT ON mini_netflix.SUBSCRIPTION_PLAN TO 'visitor_role';

-- 3. Người dùng đã đăng ký nhưng CHƯA MUA GÓI hoặc HẾT HẠN (unsubscribed_user_role):
--    - Kế thừa visitor_role (xem bảng giá SUBSCRIPTION_PLAN)
--    - Xem danh mục giới thiệu (CONTENT, TV_SERIES, SEASON, GENRE), KHÔNG xem được luồng video (MOVIE, EPISODE)
--    - Xem được thông tin tài khoản & các PROFILE đã tạo trước đó của chính mình (chỉ đọc), bị chặn sửa/xóa PROFILE
--    - Cập nhật thông tin cá nhân & đăng ký/gia hạn gói qua thủ tục lọc theo p_user_id (không truy cập trực tiếp USER)
GRANT 'visitor_role' TO 'unsubscribed_user_role';
GRANT SELECT ON mini_netflix.CONTENT   TO 'unsubscribed_user_role';
GRANT SELECT ON mini_netflix.TV_SERIES TO 'unsubscribed_user_role';
GRANT SELECT ON mini_netflix.SEASON    TO 'unsubscribed_user_role';
GRANT SELECT ON mini_netflix.GENRE     TO 'unsubscribed_user_role';

GRANT EXECUTE ON FUNCTION  mini_netflix.fn_is_plan_active          TO 'unsubscribed_user_role';
GRANT EXECUTE ON FUNCTION  mini_netflix.fn_content_type            TO 'unsubscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_get_my_account          TO 'unsubscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_update_my_account       TO 'unsubscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_get_my_profiles         TO 'unsubscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_subscribe_or_renew_plan TO 'unsubscribed_user_role';

-- 4. Người dùng ĐÃ MUA GÓI CÒN HẠN (subscribed_user_role):
--    - Kế thừa unsubscribed_user_role
--    - Toàn quyền CRUD trên PROFILE, WATCH_HISTORY, WATCHLIST của chính mình thông qua Stored Procedures
--      (kiểm tra user_id sở hữu profile_id; thu hồi CRUD toàn bảng và 3 view không lọc theo user)
--    - Phát video qua sp_play_content (thu hồi SELECT trực tiếp trên MOVIE, EPISODE, v_content_all, v_episode_detail)
--    - Bị chặn UPDATE trực tiếp cột gói cước trên bảng USER và không xem được dữ liệu gói cước của user khác
GRANT 'unsubscribed_user_role' TO 'subscribed_user_role';

GRANT EXECUTE ON FUNCTION  mini_netflix.fn_can_watch              TO 'subscribed_user_role';
GRANT EXECUTE ON FUNCTION  mini_netflix.fn_watch_percent          TO 'subscribed_user_role';
GRANT EXECUTE ON FUNCTION  mini_netflix.fn_new_end_date           TO 'subscribed_user_role';

GRANT EXECUTE ON PROCEDURE mini_netflix.sp_create_profile         TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_update_profile         TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_delete_profile         TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_get_accessible_content TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_play_content           TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_upsert_watch_history   TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_get_watch_history      TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_get_continue_watching  TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_delete_watch_history   TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_get_watchlist          TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_add_to_watchlist       TO 'subscribed_user_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_remove_from_watchlist  TO 'subscribed_user_role';

-- 5. Quản trị viên Nội dung (content_admin_role):
--    - Quản lý kho phim & thể loại; bỏ DELETE trực tiếp trên MOVIE, EPISODE, SEASON, TV_SERIES
--      (xóa phim lẻ/tập lẻ qua DELETE FROM CONTENT; xóa trọn bộ/mùa qua thủ tục chống CONTENT mồ côi)
--    - Không có quyền truy cập USER, PROFILE, WATCH_HISTORY, WATCHLIST
GRANT SELECT, INSERT, UPDATE, DELETE ON mini_netflix.CONTENT   TO 'content_admin_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON mini_netflix.GENRE     TO 'content_admin_role';
GRANT SELECT, INSERT, UPDATE         ON mini_netflix.MOVIE     TO 'content_admin_role';
GRANT SELECT, INSERT, UPDATE         ON mini_netflix.EPISODE   TO 'content_admin_role';
GRANT SELECT, INSERT, UPDATE         ON mini_netflix.SEASON    TO 'content_admin_role';
GRANT SELECT, INSERT, UPDATE         ON mini_netflix.TV_SERIES TO 'content_admin_role';
GRANT SELECT ON mini_netflix.v_content_all    TO 'content_admin_role';
GRANT SELECT ON mini_netflix.v_episode_detail TO 'content_admin_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_delete_tv_series TO 'content_admin_role';
GRANT EXECUTE ON PROCEDURE mini_netflix.sp_delete_season    TO 'content_admin_role';

-- 6. Quản trị viên Hệ thống (system_dba_role): Toàn quyền trên CSDL
GRANT ALL PRIVILEGES ON mini_netflix.* TO 'system_dba_role' WITH GRANT OPTION;

-- 7. Tạo tài khoản đại diện và gán Role tương ứng
CREATE USER 'netflix_visitor'@'localhost'       IDENTIFIED BY 'Visitor@2026!';
CREATE USER 'netflix_free_user'@'localhost'     IDENTIFIED BY 'FreeUser@2026!';
CREATE USER 'netflix_subscriber'@'localhost'    IDENTIFIED BY 'SubUser@2026App!';
CREATE USER 'netflix_content_admin'@'localhost' IDENTIFIED BY 'ContentAdmin@2026!';
CREATE USER 'netflix_dba'@'localhost'           IDENTIFIED BY 'Admin@2026Strong!';

GRANT 'visitor_role'           TO 'netflix_visitor'@'localhost';
GRANT 'unsubscribed_user_role' TO 'netflix_free_user'@'localhost';
GRANT 'subscribed_user_role'   TO 'netflix_subscriber'@'localhost';
GRANT 'content_admin_role'     TO 'netflix_content_admin'@'localhost';
GRANT 'system_dba_role'        TO 'netflix_dba'@'localhost';

SET DEFAULT ROLE ALL TO 
    'netflix_visitor'@'localhost',
    'netflix_free_user'@'localhost',
    'netflix_subscriber'@'localhost',
    'netflix_content_admin'@'localhost',
    'netflix_dba'@'localhost';

FLUSH PRIVILEGES;