# RAIFIRST AI — ai.raifirst.si

Bản triển khai GoClaw Standard, nhánh ổn định `main` (v3.14.0), nhận diện trắng đen và logo RAIFIRST. Giữ nguyên bản quyền và giấy phép GoClaw trong repository.

## Phạm vi server

- Mã nguồn: `/opt/raifirst-ai/source`.
- Dữ liệu: `/opt/raifirst-ai/state/{postgres,data,workspace}`.
- Bí mật: `/etc/raifirst-ai/runtime.env` (quyền 600); không commit.
- Docker Compose project: `raifirst-ai`; chỉ gateway mở `127.0.0.1:18790`. PostgreSQL chỉ trong mạng Docker riêng, không mở cổng host.
- Nginx: chỉ file `/etc/nginx/sites-available/ai.raifirst.si` và symlink tương ứng. HTTPS do Certbot webroot tự gia hạn; hook `raifirst-ai-nginx` reload sau gia hạn.
- Các dự án `raifirst.si`, `jcibinhthuan.org`, `striverle.com` không thuộc phạm vi quản lý của các script này.

## Đăng nhập

Mở https://ai.raifirst.si, chọn Token, User ID `system`, Gateway Token lấy từ file bàn giao riêng hoặc `/etc/raifirst-ai/runtime.env`. Bạn tự nhập API key nhà cung cấp trong wizard/Providers. Khi chưa có API key, dashboard vẫn hoạt động nhưng AI chưa trả lời.

## Đồng bộ và cập nhật

`raifirst-ai-sync.timer` chạy mỗi phút: commit thay đổi mã nguồn trên server và push lên `origin/main`. Không tự kéo và chạy code mới từ upstream. Nếu GitHub có commit mới gây phân kỳ, job dừng và ghi lỗi thay vì ghi đè lịch sử.

Sau khi sửa mã nguồn hoặc đưa thay đổi đã kiểm tra lên GitHub, chạy:

```sh
cd /opt/raifirst-ai/source
./deploy/raifirst/deploy.sh
```

Script lưu thay đổi, nhận commit GitHub bằng fast-forward, sao lưu dữ liệu, build image, push source rồi thay gateway và kiểm tra `/health`. Ảnh Docker trước được giữ để quay lại khi health check lỗi. Migration cơ sở dữ liệu cần xem xét riêng trước khi downgrade.

Để cập nhật GoClaw: `git fetch upstream`, xem diff/changelog, merge phiên bản ổn định phù hợp vào nhánh làm việc, giữ tùy biến RAIFIRST, xử lý xung đột và chạy kiểm tra/build trước khi `deploy.sh`. Không dùng `git reset --hard upstream/main`, không chạy `make reset` hoặc `docker compose down -v` trên production.

## Sao lưu dữ liệu

`raifirst-ai-backup.timer` chạy mỗi 15 phút. Mỗi bản gồm PostgreSQL dump nhất quán, config, skills, media, workspace, `runtime.env` và commit mã nguồn. Các cache thư viện có thể tạo lại được loại bỏ.

- Mã hóa bằng age trên server trước khi gửi GitHub.
- Nhánh `encrypted-backups` chứa bản mã hóa mới nhất, không có private key. Các file lớn được chia nhỏ dưới giới hạn 100 MB của GitHub.
- Nhánh backup được thay bằng một commit độc lập sau mỗi lần chạy để tránh tăng lịch sử mã hóa vô hạn. Nhánh `main` vẫn giữ đầy đủ lịch sử code.
- Server giữ 4 bản gần nhất và tối đa 1 bản/ngày trong 7 ngày tại `/var/backups/raifirst-ai`, giới hạn tổng archive 8 GiB (luôn giữ bản mới nhất). Cần theo dõi dung lượng và chuyển archive lớn sang object storage.
- `RAIFIRST-backup-recovery.agekey` được bàn giao riêng trên máy quản trị. Cất file này ở nơi an toàn ngoài server; mất khóa sẽ không giải mã được backup.
- Backup file trong lúc app đang chạy có thể khác thời điểm snapshot DB; cơ chế retry phát hiện file đang thay đổi. Với khôi phục giao dịch chứa nhiều file quan trọng, tạm dừng gateway trước khi sao lưu thủ công.

Kiểm tra vận hành:

```sh
systemctl list-timers 'raifirst-ai-*'
journalctl -u raifirst-ai-sync.service -u raifirst-ai-backup.service --since today
cd /opt/raifirst-ai/source
./deploy/raifirst/compose.sh ps
./deploy/raifirst/compose.sh logs --tail 100 gateway
```

## Khôi phục trên máy/DB riêng

1. Clone `main` để có mã nguồn và nhánh `encrypted-backups` để lấy archive. Nếu có các phần: `cat latest.tar.age.part-* > latest.tar.age`.
2. `age -d -i /duong-dan/RAIFIRST-backup-recovery.agekey -o backup.tar latest.tar.age`.
3. Trong thư mục riêng quyền 700, giải nén `backup.tar`, rồi `files.tar`. Không giải nén vào production đang chạy.
4. `source-commit.txt` chỉ commit tương ứng. Checkout commit đó, chuẩn bị Docker, cấu hình riêng và quyền dữ liệu UID/GID 1000:1000 cho `data` và `workspace`.
5. Đưa `runtime.env` vào `/etc/raifirst-ai/runtime.env`, chmod 600. Tạo PostgreSQL 18 pgvector mới, khôi phục `database.dump` bằng `pg_restore --no-owner --no-privileges --exit-on-error -U raifirst -d TEN_DB_MOI`.
6. Build/khởi động gateway và kiểm tra health, đăng nhập, agents, dữ liệu. Chỉ chuyển DNS sau khi xác minh hoàn tất. Cấp deploy key mới nếu server cũ mất; không cần PAT để chạy các job hằng ngày.

Surface parity: Web UI được đổi theme/logo/favicon. Gateway/API/CLI N/A vì không sửa hành vi hoặc hợp đồng API. Desktop N/A vì không triển khai ứng dụng desktop.
