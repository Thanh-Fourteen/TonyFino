#!/usr/bin/env python3
"""Kéo dữ liệu Rolly về raw_rolly/ từ một lệnh 'Copy as cURL' đã lưu.

Dùng:
  1. Đăng nhập app.rollyapp.ai trên Firefox, mở Network (xem docs/rolly-extraction.md)
  2. Copy as cURL một request tới ilcayaumqidkbjpecfhq.supabase.co -> raw_rolly/rolly-curl.txt
  3. python3 tool/pull_rolly.py

Token Supabase hết hạn sau ~1 giờ; lấy curl mới rồi chạy lại là được.
Chỉ dùng apikey + Authorization + user_id trong curl; không gửi gì đi ngoài Supabase.
"""
import re, json, sys, os, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CURL = os.path.join(ROOT, 'raw_rolly', 'rolly-curl.txt')
OUT  = os.path.join(ROOT, 'raw_rolly')
BASE = "https://ilcayaumqidkbjpecfhq.supabase.co/rest/v1/"

# bảng -> có lọc user_id không
TABLES = {
    'input': True, 'category_view': True, 'wallet_view': True,
    'monthly_category_sums_with_total': True, 'chat_history_with_input_view': True,
    'input_savings_view': True, 'savings': True, 'savings_with_total': True,
    'budget': True, 'debt_with_total': True, 'recurring_transactions_view': True,
    'categorisation_rule': False, 'subcategory': True,
}

def parse_curl(path):
    s = open(path, encoding='utf-8', errors='replace').read()
    H = {m.group(1).strip().lower(): m.group(2).strip()
         for m in re.finditer(r"-H\s+'([^:]+):\s*([^']*)'", s)}
    if 'apikey' not in H or 'authorization' not in H:
        sys.exit("❌ curl thiếu apikey/authorization — copy lại 'Copy as cURL' cho đúng request Supabase")
    uid = None
    m = re.search(r"user_id=eq\.([0-9a-f-]{36})", s)
    if m: uid = m.group(1)
    if not uid:
        import base64
        tok = H['authorization'].replace('Bearer ', '')
        p = tok.split('.')[1]; p += '=' * (-len(p) % 4)
        uid = json.loads(base64.urlsafe_b64decode(p)).get('sub')
    return H, uid

def fetch(table, use_uid, H, uid):
    url = f"{BASE}{table}?select=*" + (f"&user_id=eq.{uid}" if use_uid else "") + "&limit=100000"
    hdr = {'apikey': H['apikey'], 'Authorization': H['authorization'],
           'Accept': 'application/json', 'Accept-Profile': 'public', 'Prefer': 'count=exact'}
    req = urllib.request.Request(url, headers=hdr)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def main():
    H, uid = parse_curl(CURL)
    print(f"user_id = {uid}\n")
    for t, use_uid in TABLES.items():
        try:
            data = fetch(t, use_uid, H, uid)
        except urllib.error.HTTPError as e:
            print(f"  ✗ {t}: HTTP {e.code}"); continue
        except Exception as e:
            print(f"  ✗ {t}: {e}"); continue
        json.dump(data, open(os.path.join(OUT, f'{t}.json'), 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=2)
        print(f"  ✓ {t:<38} {len(data):>5} bản ghi")

if __name__ == '__main__':
    main()
