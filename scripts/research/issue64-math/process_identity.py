"""Read only native PID markers emitted by the owned diagnostic WKWebView."""
import re

def web_content_pid(trace):
    values = set()
    for line in trace.splitlines():
        if not line.startswith('PROBE_WEB_CONTENT_PID '):
            continue
        match = re.fullmatch(r'PROBE_WEB_CONTENT_PID ([1-9][0-9]*)', line)
        if not match:
            raise ValueError('Invalid native WebContent identity')
        values.add(int(match.group(1)))
    if len(values) > 1:
        raise ValueError('WebContent identity changed during measurement')
    return next(iter(values), None)
