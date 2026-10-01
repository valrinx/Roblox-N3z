import urllib.request
import urllib.parse

with open("tools/n3z_standalone.lua", "r", encoding="utf-8") as f:
    code = f.read()

data = urllib.parse.urlencode({"content": code, "syntax": "lua", "expiry_days": 365}).encode("utf-8")
req = urllib.request.Request("https://dpaste.org/api/", data=data, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req) as resp:
    url = resp.read().decode("utf-8").strip().strip('"')
    print("Raw URL:", url + "/raw")
