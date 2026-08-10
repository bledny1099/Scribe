import json

log_path = "/Users/aleksei/.gemini/antigravity-ide/brain/4e8a8164-1226-4a0f-9139-327cba9e748a/.system_generated/logs/transcript_full.jsonl"
with open(log_path, 'r') as f:
    lines = f.readlines()

for line in lines:
    data = json.loads(line)
    if data.get('type') == 'TOOL_RESPONSE':
        if 'diff --git' in data.get('content', ''):
            print("Found diff output")
            with open('full_diff.txt', 'w') as out:
                out.write(data['content'])

