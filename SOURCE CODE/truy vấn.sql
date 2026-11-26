USE mini_netflix;


-- Câu 1: Kiểm tra các nội dung mà một tài khoản (user_id = 1) được phép xem hôm nay
SELECT 
    c.content_id,
    c.title,
    fn_content_type(c.content_id) AS content_type,
    c.releasedate,
    DATE_SUB(c.releasedate, INTERVAL sp.earlyaccessdays DAY) AS unlock_date
FROM USER u
JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
CROSS JOIN CONTENT c
WHERE u.user_id = 1
  AND u.plan_end_date >= CURDATE()
  AND CURDATE() >= DATE_SUB(c.releasedate, INTERVAL sp.earlyaccessdays DAY)
ORDER BY c.releasedate DESC;

-- Câu 2: Lọc danh sách nội dung theo thể loại ('Hành động') và năm phát hành
SELECT 
    c.content_id,
    c.title,
    fn_content_type(c.content_id) AS content_type,
    c.releasedate,
    c.duration
FROM CONTENT c
JOIN GENRE g ON c.content_id = g.content_id
WHERE g.genrename = 'Hành động'
    AND c.releasedate BETWEEN '2026-01-01' AND '2026-12-31'
ORDER BY c.releasedate DESC;

-- Câu 3: Hiển thị danh sách mùa và tập phim của một bộ phim bộ (series_id = 1) theo đúng thứ tự
SELECT 
    ts.seriestitle,
    s.seasonname,
    e.episodenumber,
    c.title AS episode_title,
    c.duration,
    e.video_url
FROM TV_SERIES ts
JOIN SEASON s ON ts.series_id = s.series_id
JOIN EPISODE e ON s.season_id = e.season_id
JOIN CONTENT c ON e.content_id = c.content_id
WHERE ts.series_id = 1
ORDER BY s.season_id ASC, e.episodenumber ASC;

-- Câu 4: Danh sách "Tiếp tục xem" (Continue Watching) của hồ sơ (profile_id = 1)
-- (Tiến trình > 0 và < 90% thời lượng, sắp xếp theo lần xem gần nhất)
SELECT 
    content_id,
    title,
    progress,
    duration,
    watch_percent,
    watchedat
FROM v_continue_watching
WHERE profile_id = 1
ORDER BY watchedat DESC;

-- Câu 5: Danh sách nội dung đã xem xong (>= 90% thời lượng) để hỗ trợ tính năng "Xem lại"
SELECT 
    wh.content_id,
    c.title,
    fn_content_type(c.content_id) AS content_type,
    ROUND((wh.progress / c.duration) * 100, 1) AS watch_percent,
    wh.watchedat
FROM WATCH_HISTORY wh
JOIN CONTENT c ON wh.content_id = c.content_id
WHERE wh.profile_id = 1
  AND wh.progress >= (0.9 * c.duration)
ORDER BY wh.watchedat DESC;

-- Câu 6: Tìm tập tiếp theo cần xem của bộ phim (series_id = 1) cho hồ sơ (profile_id = 1)
WITH ordered_episodes AS (
    SELECT 
        e.content_id,
        s.seasonname,
        e.episodenumber,
        c.title,
        c.duration,
        ROW_NUMBER() OVER (ORDER BY s.season_id ASC, e.episodenumber ASC) AS seq_no
    FROM SEASON s
    JOIN EPISODE e ON s.season_id = e.season_id
    JOIN CONTENT c ON e.content_id = c.content_id
    WHERE s.series_id = 1
),
last_finished AS (
    SELECT IFNULL(MAX(oe.seq_no), 0) AS max_seq
    FROM ordered_episodes oe
    JOIN WATCH_HISTORY wh ON oe.content_id = wh.content_id
    WHERE wh.profile_id = 1
      AND wh.progress >= (0.9 * oe.duration)
)
SELECT 
    oe.content_id,
    oe.seasonname,
    oe.episodenumber,
    oe.title AS next_episode_title
FROM ordered_episodes oe
JOIN last_finished lf ON oe.seq_no = lf.max_seq + 1;

-- Câu 7: Lấy danh sách nội dung đã lưu trong Watchlist nhưng hồ sơ (profile_id = 1) chưa xem
SELECT 
    w.listid,
    c.content_id,
    c.title,
    fn_content_type(c.content_id) AS content_type,
    w.addedat
FROM WATCHLIST w
JOIN CONTENT c ON w.content_id = c.content_id
WHERE w.profile_id = 1
  AND NOT EXISTS (
      SELECT 1 
      FROM WATCH_HISTORY wh 
      WHERE wh.profile_id = w.profile_id 
        AND wh.content_id = w.content_id
  )
ORDER BY w.addedat DESC;

-- Câu 8: Gợi ý nội dung cho hồ sơ (profile_id = 1) dựa trên thể loại của các phim đã xem xong
WITH favorite_genres AS (
    SELECT DISTINCT g.genrename
    FROM WATCH_HISTORY wh
    JOIN CONTENT c ON wh.content_id = c.content_id
    JOIN GENRE g ON c.content_id = g.content_id
    WHERE wh.profile_id = 1
      AND wh.progress >= (0.9 * c.duration)
)
SELECT 
    c.content_id,
    c.title,
    fn_content_type(c.content_id) AS content_type,
    GROUP_CONCAT(DISTINCT g.genrename ORDER BY g.genrename SEPARATOR ', ') AS matched_genres
FROM CONTENT c
JOIN GENRE g ON c.content_id = g.content_id
JOIN favorite_genres fg ON g.genrename = fg.genrename
WHERE c.releasedate IS NOT NULL
    AND c.releasedate <= CURDATE()
    NOT EXISTS (
    SELECT 1 
    FROM WATCH_HISTORY wh 
    WHERE wh.profile_id = 1 AND wh.content_id = c.content_id
)
GROUP BY c.content_id, c.title, c.releasedate
ORDER BY COUNT(DISTINCT g.genrename) DESC, c.releasedate DESC
LIMIT 10;


-- Câu 9: Kiểm tra số lượng hồ sơ hiện có và số hồ sơ còn được phép tạo thêm của mỗi tài khoản
SELECT 
    u.user_id,
    u.fullname,
    sp.planname,
    COUNT(p.profile_id) AS current_profiles,
    sp.maxprofiles,
    (sp.maxprofiles - COUNT(p.profile_id)) AS remaining_slots
FROM USER u
JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
LEFT JOIN PROFILE p ON u.user_id = p.user_id
WHERE u.plan_end_date >= CURDATE()
GROUP BY u.user_id, u.fullname, sp.planname, sp.maxprofiles
ORDER BY remaining_slots ASC;

-- Câu 10: Danh sách tài khoản có gói cước sắp hết hạn trong vòng 7 ngày tới (nhắc gia hạn)
SELECT 
    u.user_id,
    u.fullname,
    u.email,
    sp.planname,
    u.plan_end_date,
    DATEDIFF(u.plan_end_date, CURDATE()) AS days_left
FROM USER u
JOIN SUBSCRIPTION_PLAN sp ON u.plan_id = sp.plan_id
WHERE u.plan_end_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)
ORDER BY u.plan_end_date ASC;

-- Câu 11: Thống kê số tài khoản đang hoạt động và doanh thu ước tính theo từng gói cước
SELECT 
    sp.planname,
    sp.price,
    COUNT(u.user_id) AS active_users,
    COUNT(u.user_id) * sp.price AS estimated_revenue
FROM SUBSCRIPTION_PLAN sp
LEFT JOIN USER u ON sp.plan_id = u.plan_id AND u.plan_end_date >= CURDATE()
GROUP BY sp.plan_id, sp.planname, sp.price
ORDER BY estimated_revenue DESC;

-- Câu 12: Top 10 nội dung phổ biến nhất dựa trên số lượt xem và lượt lưu Watchlist
SELECT 
    c.content_id,
    c.title,
    fn_content_type(c.content_id) AS content_type,
    COUNT(DISTINCT wh.profile_id) AS total_views,
    COUNT(DISTINCT w.profile_id) AS total_watchlists
FROM CONTENT c
LEFT JOIN WATCH_HISTORY wh ON c.content_id = wh.content_id
LEFT JOIN WATCHLIST w ON c.content_id = w.content_id
GROUP BY c.content_id, c.title
ORDER BY total_views DESC, total_watchlists DESC
LIMIT 10;