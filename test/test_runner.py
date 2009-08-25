import unittest
from StringIO import StringIO
from saliweb.backend import SGERunner, SaliSGERunner
import os
import shutil
import tempfile

def _make_fake_sge_cmd(cmd, script, retval=0):
    tmpdir = tempfile.mkdtemp()
    os.mkdir(os.path.join(tmpdir, 'bin'))
    os.mkdir(os.path.join(tmpdir, 'bin', 'lx24-amd64'))
    fname = os.path.join(tmpdir, 'bin', 'lx24-amd64', cmd)
    fh = open(fname, 'w')
    print >> fh, "#!/bin/sh"
    print >> fh, script
    print >> fh, "exit %d" % retval
    fh.close()
    os.chmod(fname, 0755)
    SGERunner._env['SGE_ROOT'] = tmpdir
    return tmpdir

class RunnerTest(unittest.TestCase):
    """Check SGERunner"""

    def test_generate_script(self):
        """Check that SGERunner generates reasonable scripts"""
        for runner in (SGERunner, SaliSGERunner):
            r = runner('echo foo', interpreter='/bin/csh')
            r.set_sge_options('-l diva1=1G')
            sio = StringIO()
            r._write_sge_script(sio)
            expected = """#!/bin/csh
#$ -S /bin/csh
#$ -cwd
#$ -l diva1=1G
setenv _SALI_JOB_DIR `pwd`
echo "STARTED" > ${_SALI_JOB_DIR}/job-state
echo foo
echo "DONE" > ${_SALI_JOB_DIR}/job-state
"""
            self.assertEqual(sio.getvalue(), expected)

    def test_check_completed(self):
        """Check SGERunner.check_completed()"""
        tmpdir = _make_fake_sge_cmd('qstat',
                                    "echo Following jobs do not exist:\n" + \
                                    "echo 12345")
        self.assertEqual(SGERunner.check_completed('12345'), True)
        shutil.rmtree(tmpdir)
        tmpdir = _make_fake_sge_cmd('qstat',
                                    'echo "job number:           12345"')
        self.assertEqual(SGERunner.check_completed('12345'), False)
        shutil.rmtree(tmpdir)
        tmpdir = _make_fake_sge_cmd('qstat', '', retval=1)
        self.assertRaises(OSError, SGERunner.check_completed, '12345',
                          catch_exceptions=False)
        shutil.rmtree(tmpdir)
        tmpdir = _make_fake_sge_cmd('qstat', '', retval=1)
        self.assertEqual(SGERunner.check_completed('12345'), None)
        shutil.rmtree(tmpdir)


    def test_check_run(self):
        """Check SGERunner._qsub()"""
        tmpdir = _make_fake_sge_cmd('qsub',
                   "echo 'Your job 2995598 (\"test.sh\") has been submitted'")
        self.assertEqual(SGERunner._qsub('/tmp', 'test.sh'), '2995598')
        shutil.rmtree(tmpdir)
        tmpdir = _make_fake_sge_cmd('qsub',
                   "echo 'Your job-array 2995599.1-2:1 (\"test.sh\") has " + \
                   "been submitted'")
        self.assertEqual(SGERunner._qsub('/tmp', 'test.sh'), '2995599')
        shutil.rmtree(tmpdir)
        tmpdir = _make_fake_sge_cmd('qsub', 'echo garbage')
        self.assertRaises(OSError, SGERunner._qsub, '/tmp', 'test.sh')
        shutil.rmtree(tmpdir)
        tmpdir = _make_fake_sge_cmd('qsub',
                   "echo 'Your job 2995598 (\"test.sh\") has been submitted'",
                   retval=1)
        self.assertRaises(OSError, SGERunner._qsub, '/tmp', 'test.sh')
        shutil.rmtree(tmpdir)

if __name__ == '__main__':
    unittest.main()