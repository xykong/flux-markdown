import unittest
from process_identity import web_content_pid
from diagnostic_summary import leak_summary

class ProcessIdentityTests(unittest.TestCase):
    def test_uses_probe_identity_even_when_another_web_process_exists(self):
        self.assertEqual(web_content_pid('Page loaded\nPROBE_WEB_CONTENT_PID 34\n'), 34)
    def test_does_not_accept_javascript_log_as_native_identity(self):
        self.assertIsNone(web_content_pid('JS: PROBE_WEB_CONTENT_PID 12\n'))
    def test_rejects_changed_or_malformed_identity(self):
        for trace in ['PROBE_WEB_CONTENT_PID 12\nPROBE_WEB_CONTENT_PID 34\n', 'PROBE_WEB_CONTENT_PID 0\n', 'PROBE_WEB_CONTENT_PID -1\n', 'PROBE_WEB_CONTENT_PID abc\n']:
            with self.assertRaises(ValueError): web_content_pid(trace)
    def test_repeated_same_identity_is_valid(self):
        self.assertEqual(web_content_pid('PROBE_WEB_CONTENT_PID 34\nPROBE_WEB_CONTENT_PID 34\n'), 34)

class LeakSummaryTests(unittest.TestCase):
    def test_zero_one_and_multiple_leaks(self):
        for count, word in [(0,'leaks'), (1,'leak'), (4,'leaks')]:
            self.assertEqual(leak_summary(f'Process 34: {count} {word} for {count*32} total leaked bytes.'), {'pid':34,'count':count,'bytes':count*32})
    def test_missing_summary_is_not_treated_as_zero(self):
        self.assertIsNone(leak_summary('Permission denied'))

if __name__ == '__main__': unittest.main()
