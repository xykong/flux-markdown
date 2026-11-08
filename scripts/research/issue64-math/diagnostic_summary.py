"""Parse the bounded numeric summary emitted by macOS leaks."""
import re

def leak_summary(text):
    match = re.search(r'^Process ([0-9]+): ([0-9]+) leaks? for ([0-9]+) total leaked bytes\.$', text, re.MULTILINE)
    if match is None:
        return None
    pid, count, size = map(int, match.groups())
    return {'pid': pid, 'count': count, 'bytes': size}
