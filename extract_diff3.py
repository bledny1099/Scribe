import json

log_path = "/Users/aleksei/.gemini/antigravity-ide/brain/4e8a8164-1226-4a0f-9139-327cba9e748a/.system_generated/logs/transcript_full.jsonl"
with open(log_path, 'r') as f:
    lines = f.readlines()

for line in lines:
    data = json.loads(line)
    if 'tool_calls' in data:
        for call in data['tool_calls']:
            if call['name'] == 'multi_replace_file_content':
                args = call['args']
                if 'case replacements' in args.get('Instruction', '') or 'case replacements' in str(args.get('ReplacementChunks', '')):
                    print("Found modification")
                    with open('full_diff.txt', 'w') as out:
                        out.write(json.dumps(args, indent=2))

