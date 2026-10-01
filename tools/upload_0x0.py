import urllib.request

with open("tools/n3z_standalone.lua", "rb") as f:
    content = f.read()

boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
body = (
    f"--{boundary}\r\n"
    f'Content-Disposition: form-data; name="file"; filename="n3z.lua"\r\n'
    f"Content-Type: text/plain\r\n\r\n"
).encode("utf-8") + content + f"\r\n--{boundary}--\r\n".encode("utf-8")

req = urllib.request.Request(
    "https://0x0.st",
    data=body,
    headers={
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "User-Agent": "curl/7.68.0",
    },
)

try:
    with urllib.request.urlopen(req) as resp:
        url = resp.read().decode("utf-8").strip()
        print("0x0 URL:", url)
except Exception as e:
    print("0x0 error:", e)
